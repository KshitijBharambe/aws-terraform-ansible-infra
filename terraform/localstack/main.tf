# LocalStack Infrastructure - Complete Setup with All Modules

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      Project     = var.project_name
      Terraform   = "true"
      Platform    = "LocalStack"
    }
  )
}

#===============================================================================
# SSH Key Pair
#===============================================================================

resource "aws_key_pair" "instance_key" {
  key_name   = "${local.name_prefix}-key"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-key"
    }
  )
}

#===============================================================================
# VPC Module
#===============================================================================

module "vpc" {
  source = "../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  # Disable NAT Gateway for LocalStack (faster setup)
  enable_nat_gateway = false
  enable_flow_logs   = false

  tags = local.common_tags
}

#===============================================================================
# Security Module
#===============================================================================

module "security" {
  source = "../modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  # Web tier security
  web_ingress_ports = [80, 443]

  # App tier security
  app_ingress_ports = [8080, 8081]

  # SSH access (allow all for LocalStack testing)
  enable_ssh_access       = true
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  # IAM permissions
  enable_cloudwatch_access      = var.enable_monitoring
  enable_s3_access              = true
  enable_secrets_manager_access = false
  enable_ssm_access             = false

  # Disable KMS for LocalStack (not fully supported)
  enable_kms = false

  tags = local.common_tags
}

#===============================================================================
# Compute Module - Web Tier
#===============================================================================

module "web_servers" {
  source = "../modules/compute"

  project_name = var.project_name
  environment  = var.environment

  # Instance configuration
  ami_id        = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.instance_key.key_name

  # Networking
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_ids  = [module.security.web_security_group_id]
  associate_public_ip = true
  iam_instance_profile = ""  # Disabled for LocalStack compatibility

  # Scaling configuration (disabled for LocalStack)
  enable_auto_scaling = false
  instance_count      = var.web_instance_count

  # User data for web server initialization
  user_data_script = <<-EOF
    #!/bin/bash
    echo "Initializing web server..."
    yum update -y || apt-get update -y
    yum install -y nginx || apt-get install -y nginx
    systemctl start nginx || service nginx start
    systemctl enable nginx || true
    
    # Create simple health check endpoint
    echo "OK" > /usr/share/nginx/html/health
    
    # Custom landing page
    cat > /usr/share/nginx/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Welcome to ${var.project_name}</title>
        <style>
            body { font-family: Arial; text-align: center; padding: 50px; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <h1>🚀 ${var.project_name} - ${var.environment}</h1>
        <p>Web Server is running!</p>
        <p>Powered by LocalStack</p>
    </body>
    </html>
    HTML
    
    echo "Web server initialization complete"
  EOF

  # Storage
  root_volume_size      = 8
  root_volume_type      = "gp3"
  enable_ebs_encryption = false # LocalStack limitation

  # Monitoring
  enable_monitoring = false

  tags = merge(
    local.common_tags,
    {
      Tier = "Web"
      Role = "WebServer"
    }
  )

  depends_on = [module.vpc, module.security]
}

#===============================================================================
# Compute Module - App Tier (Optional)
#===============================================================================

module "app_servers" {
  source = "../modules/compute"
  count  = var.enable_app_tier ? 1 : 0

  project_name = var.project_name
  environment  = var.environment

  # Instance configuration
  ami_id        = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.instance_key.key_name

  # Networking - use public subnets for LocalStack (no NAT)
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_ids  = [module.security.app_security_group_id]
  associate_public_ip = true
  iam_instance_profile = ""  # Disabled for LocalStack compatibility

  # Scaling configuration
  enable_auto_scaling = false
  instance_count      = var.app_instance_count

  # User data for app server initialization
  user_data_script = <<-EOF
    #!/bin/bash
    echo "Initializing application server..."
    yum update -y || apt-get update -y
    echo "Application server initialization complete"
  EOF

  # Storage
  root_volume_size      = 8
  root_volume_type      = "gp3"
  enable_ebs_encryption = false

  # Monitoring
  enable_monitoring = false

  tags = merge(
    local.common_tags,
    {
      Tier = "Application"
      Role = "AppServer"
    }
  )

  depends_on = [module.vpc, module.security]
}

#===============================================================================
# Load Balancer Module (Optional - Limited LocalStack Support)
#===============================================================================

module "loadbalancer" {
  source = "../modules/loadbalancer"
  count  = var.enable_load_balancer ? 1 : 0

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  # Must be in public subnets
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security.web_security_group_id]

  # Target configuration
  target_port     = 80
  target_protocol = "HTTP"

  # Health check
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5

  # HTTPS disabled for LocalStack
  enable_https = false

  # Deletion protection disabled for easy cleanup
  enable_deletion_protection = false

  tags = local.common_tags

  depends_on = [module.vpc, module.security]
}

#===============================================================================
# Monitoring Module
#===============================================================================

module "monitoring" {
  source = "../modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0

  project_name = var.project_name
  environment  = var.environment

  # Instances to monitor
  instance_ids = concat(
    module.web_servers.instance_ids,
    var.enable_app_tier ? module.app_servers[0].instance_ids : []
  )

  # Log configuration
  log_groups = [
    "webserver",
    "application",
    "system",
    "security"
  ]
  log_retention_days = 7

  # Alarm configuration
  alarm_emails = [var.alarm_email]

  # Thresholds
  cpu_threshold    = var.cpu_alarm_threshold
  memory_threshold = var.memory_alarm_threshold
  disk_threshold   = var.disk_alarm_threshold

  # Advanced monitoring (disabled for LocalStack)
  enable_memory_monitoring = false
  enable_disk_monitoring   = false
  enable_dashboard         = var.enable_monitoring_dashboard

  tags = local.common_tags

  depends_on = [module.web_servers]
}

#===============================================================================
# Test Resources (Optional)
#===============================================================================

# S3 Bucket for testing
resource "aws_s3_bucket" "test" {
  count = var.create_test_resources ? 1 : 0

  bucket = "${local.name_prefix}-test-bucket"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-test-bucket"
      Description = "Test S3 bucket for LocalStack validation"
    }
  )
}

resource "aws_s3_bucket_versioning" "test" {
  count = var.create_test_resources ? 1 : 0

  bucket = aws_s3_bucket.test[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB Table for testing
resource "aws_dynamodb_table" "test" {
  count = var.create_test_resources ? 1 : 0

  name         = "${local.name_prefix}-test-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-test-table"
      Description = "Test DynamoDB table"
    }
  )
}
