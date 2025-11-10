# Compute Module - Main Resources

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Module      = "compute"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # Default user data if none provided
  default_user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    yum update -y || apt-get update -y
    
    # Install basic utilities
    yum install -y curl wget vim htop || apt-get install -y curl wget vim htop
    
    # Configure timezone
    timedatectl set-timezone UTC || true
    
    echo "Instance initialized successfully" > /var/log/user-data.log
  EOF

  user_data = var.user_data_script != "" ? var.user_data_script : local.default_user_data
}

#===============================================================================
# Launch Template
#===============================================================================

resource "aws_launch_template" "main" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  vpc_security_group_ids = var.security_group_ids

  user_data = base64encode(local.user_data)

  # EBS volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = var.enable_ebs_encryption
      kms_key_id            = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null
    }
  }

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = var.metadata_options.http_endpoint
    http_tokens                 = var.metadata_options.http_tokens
    http_put_response_hop_limit = var.metadata_options.http_put_response_hop_limit
  }

  # Monitoring
  monitoring {
    enabled = var.enable_monitoring
  }

  # T instance credit specification
  dynamic "credit_specification" {
    for_each = substr(var.instance_type, 0, 2) == "t2" || substr(var.instance_type, 0, 2) == "t3" || substr(var.instance_type, 0, 3) == "t4g" ? [1] : []

    content {
      cpu_credits = var.cpu_credits
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      var.instance_tags,
      {
        Name = "${local.name_prefix}-instance"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-volume"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-launch-template"
    }
  )
}

#===============================================================================
# Auto Scaling Group (Optional)
#===============================================================================

resource "aws_autoscaling_group" "main" {
  count = var.enable_auto_scaling ? 1 : 0

  name_prefix               = "${local.name_prefix}-asg-"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_group_arns
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  termination_policies = ["OldestLaunchTemplate", "OldestInstance"]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

#===============================================================================
# Individual EC2 Instances (when not using ASG)
#===============================================================================

resource "aws_instance" "main" {
  count = var.enable_auto_scaling ? 0 : var.instance_count

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  user_data = local.user_data

  # Monitoring
  monitoring = var.enable_monitoring

  # Termination protection
  disable_api_termination = var.enable_termination_protection

  tags = merge(
    local.common_tags,
    var.instance_tags,
    {
      Name  = "${local.name_prefix}-instance-${count.index + 1}"
      Index = count.index + 1
    }
  )

  lifecycle {
    ignore_changes = [
      ami,      # Ignore AMI changes to prevent recreation
      user_data # Ignore user data changes after initial creation
    ]
  }
}

#===============================================================================
# Elastic IPs (Optional - for individual instances in public subnets)
#===============================================================================

resource "aws_eip" "instance" {
  count = var.enable_auto_scaling ? 0 : (var.associate_public_ip && var.enable_eip ? var.instance_count : 0)

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-eip-${count.index + 1}"
    }
  )
}

resource "aws_eip_association" "instance" {
  count = var.enable_auto_scaling ? 0 : (var.associate_public_ip && var.enable_eip ? var.instance_count : 0)

  instance_id   = aws_instance.main[count.index].id
  allocation_id = aws_eip.instance[count.index].id

  depends_on = [aws_instance.main, aws_eip.instance]
}

#===============================================================================
# Auto Scaling Policies (Optional)
#===============================================================================

# Scale Up Policy - CPU > 70%
resource "aws_autoscaling_policy" "scale_up" {
  count = var.enable_auto_scaling ? 1 : 0

  name                   = "${local.name_prefix}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.main[0].name
}

# Scale Down Policy - CPU < 30%
resource "aws_autoscaling_policy" "scale_down" {
  count = var.enable_auto_scaling ? 1 : 0

  name                   = "${local.name_prefix}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.main[0].name
}