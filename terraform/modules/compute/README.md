# Compute Module

This module creates EC2 instances with optional Auto Scaling capabilities.

## Features

- EC2 Launch Templates with IMDSv2
- Auto Scaling Groups (optional)
- Individual EC2 instances
- Elastic IPs (optional)
- Target group attachments
- EBS encryption support
- Detailed monitoring

## Usage

```hcl
module "compute" {
  source = "../../modules/compute"

  project_name    = "myproject"
  environment     = "dev"
  ami_id          = "ami-12345678"
  instance_type   = "t3.micro"
  subnet_ids      = module.vpc.public_subnet_ids
  security_group_ids = [module.security.web_security_group_id]
  iam_instance_profile = module.security.instance_profile_name
  
  instance_count  = 2
  enable_auto_scaling = false
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name | `string` | n/a | yes |
| ami_id | AMI ID for instances | `string` | n/a | yes |
| instance_type | Instance type | `string` | `"t3.micro"` | no |
| subnet_ids | List of subnet IDs | `list(string)` | n/a | yes |
| security_group_ids | List of security group IDs | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_ids | List of instance IDs |
| private_ips | List of private IP addresses |
| public_ips | List of public IP addresses |
