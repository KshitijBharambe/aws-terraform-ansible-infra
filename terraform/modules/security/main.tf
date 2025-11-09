# Security Module - Main Resources

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Module      = "security"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

#===============================================================================
# Web Tier Security Group
#===============================================================================

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web tier (public-facing)"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-web-sg"
      Tier = "Web"
    }
  )
}

# Web ingress rules (HTTP/HTTPS)
resource "aws_security_group_rule" "web_ingress" {
  count = length(var.web_ingress_ports)

  type              = "ingress"
  from_port         = var.web_ingress_ports[count.index]
  to_port           = var.web_ingress_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "Allow ${var.web_ingress_ports[count.index]} from internet"
}

# SSH access to web tier
resource "aws_security_group_rule" "web_ssh" {
  count = var.enable_ssh_access ? 1 : 0

  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidr_blocks
  security_group_id = aws_security_group.web.id
  description       = "SSH access"
}

# Web egress - allow all outbound
resource "aws_security_group_rule" "web_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "Allow all outbound traffic"
}

#===============================================================================
# Application Tier Security Group
#===============================================================================

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Security group for application tier (internal)"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-sg"
      Tier = "Application"
    }
  )
}

# App ingress from web tier
resource "aws_security_group_rule" "app_from_web" {
  count = length(var.app_ingress_ports)

  type                     = "ingress"
  from_port                = var.app_ingress_ports[count.index]
  to_port                  = var.app_ingress_ports[count.index]
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow ${var.app_ingress_ports[count.index]} from web tier"
}

# SSH access to app tier
resource "aws_security_group_rule" "app_ssh" {
  count = var.enable_ssh_access ? 1 : 0

  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidr_blocks
  security_group_id = aws_security_group.app.id
  description       = "SSH access"
}

# App egress - allow all outbound
resource "aws_security_group_rule" "app_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic"
}

#===============================================================================
# Database Tier Security Group
#===============================================================================

resource "aws_security_group" "data" {
  name        = "${local.name_prefix}-data-sg"
  description = "Security group for database tier (internal only)"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-data-sg"
      Tier = "Data"
    }
  )
}

# Database ingress from app tier (PostgreSQL)
resource "aws_security_group_rule" "data_postgres_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.data.id
  description              = "PostgreSQL from app tier"
}

# Database ingress from app tier (MySQL/MariaDB)
resource "aws_security_group_rule" "data_mysql_from_app" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.data.id
  description              = "MySQL/MariaDB from app tier"
}

# SSH access to data tier (for maintenance)
resource "aws_security_group_rule" "data_ssh" {
  count = var.enable_ssh_access ? 1 : 0

  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidr_blocks
  security_group_id = aws_security_group.data.id
  description       = "SSH access for maintenance"
}

# Data egress - allow all outbound
resource "aws_security_group_rule" "data_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.data.id
  description       = "Allow all outbound traffic"
}

#===============================================================================
# IAM Role for EC2 Instances
#===============================================================================

resource "aws_iam_role" "instance_role" {
  name = "${local.name_prefix}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-instance-role"
    }
  )
}

#===============================================================================
# IAM Instance Profile
#===============================================================================

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.instance_role.name

  tags = local.common_tags
}

#===============================================================================
# CloudWatch Permissions
#===============================================================================

resource "aws_iam_role_policy" "cloudwatch_policy" {
  count = var.enable_cloudwatch_access ? 1 : 0

  name = "${local.name_prefix}-cloudwatch-policy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

#===============================================================================
# S3 Permissions
#===============================================================================

resource "aws_iam_role_policy" "s3_policy" {
  count = var.enable_s3_access && length(var.s3_bucket_arns) > 0 ? 1 : 0

  name = "${local.name_prefix}-s3-policy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      }
    ]
  })
}

#===============================================================================
# Secrets Manager Permissions
#===============================================================================

resource "aws_iam_role_policy" "secrets_manager_policy" {
  count = var.enable_secrets_manager_access && length(var.secrets_manager_arns) > 0 ? 1 : 0

  name = "${local.name_prefix}-secrets-manager-policy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secrets_manager_arns
      }
    ]
  })
}

#===============================================================================
# Systems Manager Session Manager Permissions
#===============================================================================

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count = var.enable_ssm_access ? 1 : 0

  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#===============================================================================
# KMS Keys (Optional - AWS only)
#===============================================================================

resource "aws_kms_key" "ebs" {
  count = var.enable_kms ? 1 : 0

  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ebs-kms-key"
    }
  )
}

resource "aws_kms_alias" "ebs" {
  count = var.enable_kms ? 1 : 0

  name          = "alias/${local.name_prefix}-ebs"
  target_key_id = aws_kms_key.ebs[0].key_id
}

resource "aws_kms_key" "s3" {
  count = var.enable_kms ? 1 : 0

  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-s3-kms-key"
    }
  )
}

resource "aws_kms_alias" "s3" {
  count = var.enable_kms ? 1 : 0

  name          = "alias/${local.name_prefix}-s3"
  target_key_id = aws_kms_key.s3[0].key_id
}
