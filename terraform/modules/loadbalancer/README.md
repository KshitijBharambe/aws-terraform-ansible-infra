# Load Balancer Module

This module creates an Application Load Balancer with target groups and listeners.

## Features

- Application Load Balancer
- Target groups with health checks
- HTTP and HTTPS listeners
- SSL/TLS certificate support
- Cross-zone load balancing

## Usage

```hcl
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_name    = "myproject"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  security_group_ids = [module.security.web_security_group_id]
  
  target_port     = 80
  health_check_path = "/"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 4.0 |

## Outputs

| Name | Description |
|------|-------------|
| load_balancer_arn | ARN of the load balancer |
| load_balancer_dns_name | DNS name of the load balancer |
| target_group_arn | ARN of the target group |
