# VPC Module

This module creates a complete VPC infrastructure with public and private subnets across multiple availability zones, Internet Gateway, optional NAT Gateways, and VPC Flow Logs.

## Features

- ✅ Multi-AZ deployment for high availability
- ✅ Public and private subnet tiers
- ✅ Internet Gateway for public internet access
- ✅ Optional NAT Gateway (disabled by default for cost optimization)
- ✅ Configurable VPC CIDR and subnet CIDRs
- ✅ VPC Flow Logs support (AWS only)
- ✅ DNS support and DNS hostnames enabled
- ✅ Comprehensive resource tagging

## Cost Considerations

**NAT Gateway**: ~$33/month per gateway + data transfer costs
- **Disabled by default** to minimize costs
- Enable only when private instances need internet access
- Use `single_nat_gateway = true` to share one NAT across all AZs

**VPC Flow Logs**: Minimal CloudWatch Logs costs
- Disabled by default
- Enable for security monitoring in production

## Usage

### Basic Usage (No NAT Gateway - Recommended for Development)

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "myproject"
  environment  = "dev"
  
  vpc_cidr               = "10.0.0.0/16"
  availability_zones     = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs   = ["10.0.11.0/24", "10.0.12.0/24"]
  
  # Cost optimization - no NAT Gateway
  enable_nat_gateway     = false
  
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "Engineering"
  }
}
```

### Production Usage (With NAT Gateway)

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "myproject"
  environment  = "prod"
  
  vpc_cidr               = "10.0.0.0/16"
  availability_zones     = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs   = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  
  # Enable NAT Gateway for private subnet internet access
  enable_nat_gateway     = true
  single_nat_gateway     = true  # Use one NAT for all AZs (cost optimization)
  
  # Enable flow logs for security monitoring
  enable_flow_logs       = true
  flow_logs_retention_days = 30
  
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "Engineering"
  }
}
```

### LocalStack Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "localstack-test"
  environment  = "local"
  
  vpc_cidr               = "10.0.0.0/16"
  availability_zones     = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs   = ["10.0.11.0/24", "10.0.12.0/24"]
  
  # LocalStack doesn't support these features
  enable_nat_gateway     = false
  enable_flow_logs       = false
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| vpc_cidr | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| availability_zones | List of availability zones | `list(string)` | `["us-east-1a", "us-east-1b"]` | no |
| public_subnet_cidrs | CIDR blocks for public subnets | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | no |
| private_subnet_cidrs | CIDR blocks for private subnets | `list(string)` | `["10.0.11.0/24", "10.0.12.0/24"]` | no |
| enable_nat_gateway | Enable NAT Gateway ($33/month) | `bool` | `false` | no |
| single_nat_gateway | Use single NAT Gateway for all AZs | `bool` | `true` | no |
| enable_dns_hostnames | Enable DNS hostnames in VPC | `bool` | `true` | no |
| enable_dns_support | Enable DNS support in VPC | `bool` | `true` | no |
| enable_flow_logs | Enable VPC Flow Logs (AWS only) | `bool` | `false` | no |
| flow_logs_retention_days | Flow logs retention period | `number` | `7` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr | The CIDR block of the VPC |
| vpc_arn | The ARN of the VPC |
| internet_gateway_id | The ID of the Internet Gateway |
| public_subnet_ids | List of public subnet IDs |
| public_subnet_cidrs | List of public subnet CIDR blocks |
| public_subnet_azs | List of public subnet availability zones |
| private_subnet_ids | List of private subnet IDs |
| private_subnet_cidrs | List of private subnet CIDR blocks |
| private_subnet_azs | List of private subnet availability zones |
| nat_gateway_ids | List of NAT Gateway IDs |
| nat_gateway_public_ips | List of NAT Gateway public IPs |
| public_route_table_id | ID of public route table |
| private_route_table_ids | List of private route table IDs |
| nat_gateway_enabled | Whether NAT Gateway is enabled |
| flow_logs_enabled | Whether VPC Flow Logs are enabled |
| flow_logs_log_group_name | CloudWatch Log Group name for Flow Logs |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     VPC (10.0.0.0/16)                       │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │            Public Subnets (Multi-AZ)                │  │
│  │                                                     │  │
│  │  [10.0.1.0/24]             [10.0.2.0/24]          │  │
│  │      AZ-1                      AZ-2                │  │
│  │       │                         │                  │  │
│  └───────┼─────────────────────────┼──────────────────┘  │
│          │                         │                      │
│          └────────┬────────────────┘                      │
│                   │                                        │
│         ┌─────────▼─────────┐                             │
│         │ Internet Gateway  │                             │
│         └───────────────────┘                             │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │           Private Subnets (Multi-AZ)                │  │
│  │                                                     │  │
│  │  [10.0.11.0/24]            [10.0.12.0/24]         │  │
│  │      AZ-1                      AZ-2                │  │
│  │       │                         │                  │  │
│  └───────┼─────────────────────────┼──────────────────┘  │
│          │                         │                      │
│          └────────┬────────────────┘                      │
│                   │                                        │
│         ┌─────────▼─────────┐                             │
│         │  NAT Gateway      │ (Optional)                  │
│         └───────────────────┘                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Notes

- **Default Configuration**: Optimized for LocalStack and cost-effective AWS development
- **NAT Gateway**: Disabled by default. Enable only when required for private subnet internet access
- **Multi-AZ**: Subnets are distributed across availability zones for high availability
- **DNS**: DNS support and hostnames enabled by default for service discovery
- **Tagging**: All resources tagged with Module, Project, Environment, and ManagedBy
- **LocalStack**: Flow Logs and some advanced features not supported

## Examples

See the `examples/` directory for complete usage examples:
- `examples/basic/` - Simple VPC without NAT Gateway
- `examples/production/` - Full production setup with NAT Gateway and Flow Logs
- `examples/localstack/` - LocalStack development environment
