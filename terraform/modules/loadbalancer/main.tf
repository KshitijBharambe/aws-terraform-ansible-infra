# Load Balancer Module - Main Resources

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Module      = "loadbalancer"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # Determine if HTTPS is enabled
  https_enabled = var.enable_https && var.certificate_arn != null
}

#===============================================================================
# Application Load Balancer
#===============================================================================

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "${local.name_prefix}-alb-logs"
      enabled = true
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

#===============================================================================
# Target Groups
#===============================================================================

resource "aws_lb_target_group" "main" {
  name     = "${local.name_prefix}-tg"
  port     = var.target_port
  protocol = var.target_protocol
  vpc_id   = var.vpc_id

  target_type = var.target_type

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = var.health_check_protocol
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.unhealthy_threshold
  }

  deregistration_delay = var.deregistration_delay

  stickiness {
    enabled = var.enable_stickiness
    type    = var.stickiness_type
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-tg"
    }
  )
}

#===============================================================================
# Listeners
#===============================================================================

# HTTP Listener (always created)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-http-listener"
    }
  )
}

# HTTPS Listener (created only if HTTPS is enabled)
resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-https-listener"
    }
  )
}

#===============================================================================
# Listener Rules (Optional)
#===============================================================================

resource "aws_lb_listener_rule" "priority" {
  count = length(var.listener_rules) > 0 ? length(var.listener_rules) : 0

  listener_arn = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = var.listener_rules[count.index].priority

  condition {
    path_pattern {
      values = var.listener_rules[count.index].path_patterns
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rule-${count.index + 1}"
    }
  )
}

#===============================================================================
# Target Group Attachments (for instance targets)
#===============================================================================

resource "aws_lb_target_group_attachment" "instances" {
  count = var.target_type == "instance" ? length(var.target_ids) : 0

  target_group_arn = aws_lb_target_group.main.arn
  target_id        = var.target_ids[count.index]
  port             = var.target_port
}
