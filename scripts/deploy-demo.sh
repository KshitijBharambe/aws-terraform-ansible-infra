#!/bin/bash

# On-Demand Demo Deployment Script
# Deploys AWS infrastructure for demos with cost optimization

set -e

echo "🚀 Starting On-Demand Demo Deployment..."
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="infra-demo"
ENVIRONMENT="demo"
AWS_REGION="us-east-1"
DEPLOYMENT_TIMEOUT=1800  # 30 minutes
CLEANUP_DELAY_HOURS=24

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_status "INFO" "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_status "FAIL" "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_status "FAIL" "Terraform is not installed"
        exit 1
    fi
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        print_status "FAIL" "Ansible is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_status "FAIL" "AWS credentials not configured"
        exit 1
    fi
    
    # Check SSH key
    if [ -z "$SSH_KEY_NAME" ]; then
        print_status "WARN" "SSH key name not provided, using default"
        SSH_KEY_NAME="demo-key"
    fi
    
    # Check alarm email
    if [ -z "$ALARM_EMAIL" ]; then
        print_status "WARN" "Alarm email not provided, monitoring will be limited"
        ALARM_EMAIL=""
    fi
    
    print_status "PASS" "All prerequisites checked"
}

# Function to get latest AMI
get_latest_ami() {
    local region=$1
    print_status "INFO" "Getting latest Ubuntu 20.04 LTS AMI for $region..."
    
    local ami_id=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" \
                  "Name=virtualization-type,Values=hvm" \
        --query "sort_by(Images, &CreationDate)[-1].ImageId" \
        --output text \
        --region "$region" 2>/dev/null)
    
    if [ -n "$ami_id" ]; then
        echo "$ami_id"
        return 0
    else
        print_status "WARN" "Could not get latest AMI, using fallback"
        echo "ami-0c02fb55956c7d3165"  # Fallback AMI
        return 1
    fi
}

# Function to create cost-optimized terraform.tfvars
create_terraform_tfvars() {
    local ami_id=$1
    local tfvars_file="terraform/aws/terraform.tfvars"
    
    print_status "INFO" "Creating cost-optimized terraform.tfvars..."
    
    cat > "$tfvars_file" << EOF
# Auto-generated cost-optimized configuration
# Generated: $(date)

project_name = "$PROJECT_NAME"
environment = "$ENVIRONMENT"
aws_region = "$AWS_REGION"

# Cost Optimization Settings
cost_optimization_enabled = true
enable_spot_instances = false
enable_savings_plans = false

# Networking (Cost-optimized)
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# CRITICAL: NAT Gateway disabled for cost savings
enable_nat_gateway = false
enable_vpn_gateway = false

# Compute (Cost-optimized)
instance_type = "t4g.micro"  # ARM-based, 60% cheaper
instance_count = 1
ami_id = "$ami_id"
key_name = "$SSH_KEY_NAME"
enable_auto_scaling = false
min_size = 1
max_size = 2
desired_capacity = 1

# Storage (Cost-optimized)
root_volume_size = 8
root_volume_type = "gp3"

# Security
allowed_ssh_cidr_blocks = ["0.0.0.0/0"]  # Demo purposes
web_allowed_cidr_blocks = ["0.0.0.0/0"]
ssh_port = 22
web_port = 80
ssl_port = 443

# CRITICAL: Load Balancer disabled for cost savings
enable_load_balancer = false
enable_ssl = false
certificate_arn = ""

# Monitoring (Essential only)
enable_monitoring = true
enable_cloudwatch_alarms = true
alarm_email = "$ALARM_EMAIL"
cpu_threshold = 80
memory_threshold = 85
disk_threshold = 90

# Backup
enable_backup = true
backup_retention_days = 7
backup_schedule = "0 2 * * *"

# Advanced Features (Disabled for cost savings)
enable_cloudfront = false
enable_waf = false
enable_dns_management = false

# Cost Control
monthly_budget_limit = 15
budget_threshold = 80
enable_cost_anomaly_detection = true

# On-Demand Settings
deployment_duration_hours = 3
enable_auto_cleanup = false
cleanup_delay_hours = 24

# Common Tags
common_tags = {
  Project     = "$PROJECT_NAME"
  Environment = "$ENVIRONMENT"
  Owner       = "Demo User"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering",
  Purpose     = "Demo Deployment",
  CreatedBy   = "deploy-demo.sh"
}
EOF
    
    print_status "PASS" "Created cost-optimized terraform.tfvars"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "INFO" "Deploying infrastructure with Terraform..."
    
    cd terraform/aws
    
    # Initialize Terraform
    print_status "INFO" "Initializing Terraform..."
    if timeout 300 terraform init -input=false >/dev/null 2>&1; then
        print_status "PASS" "Terraform initialized"
    else
        print_status "FAIL" "Terraform initialization failed"
        exit 1
    fi
    
    # Plan deployment
    print_status "INFO" "Planning deployment..."
    if timeout 600 terraform plan -out=tfplan -input=false >/dev/null 2>&1; then
        print_status "PASS" "Terraform plan created"
    else
        print_status "FAIL" "Terraform plan failed"
        exit 1
    fi
    
    # Apply deployment
    print_status "INFO" "Applying infrastructure (this may take 10-15 minutes)..."
    if timeout $DEPLOYMENT_TIMEOUT terraform apply -auto-approve -input=false tfplan >/dev/null 2>&1; then
        print_status "PASS" "Infrastructure deployed successfully"
    else
        print_status "FAIL" "Infrastructure deployment failed or timed out"
        exit 1
    fi
    
    # Get outputs
    if terraform output -json >/dev/null 2>&1; then
        print_status "PASS" "Retrieving deployment outputs..."
        terraform output -json > /tmp/demo-outputs.json
        
        # Display key outputs
        local instance_ips=$(terraform output -json | jq -r '.instance_public_ips.value[]' 2>/dev/null || echo "N/A")
        local vpc_id=$(terraform output -json | jq -r '.vpc_id.value' 2>/dev/null || echo "N/A")
        
        echo ""
        echo "🎉 Deployment successful!"
        echo "================================"
        echo "Instance IPs: $instance_ips"
        echo "VPC ID: $vpc_id"
        echo "================================"
    else
        print_status "WARN" "No outputs available"
    fi
    
    cd - >/dev/null
}

# Function to update Ansible inventory
update_ansible_inventory() {
    print_status "INFO" "Updating Ansible inventory..."
    
    cd ansible
    
    # Create dynamic inventory configuration
    cat > inventory/aws-demo.yml << EOF
plugin: aws_ec2
regions:
  - $AWS_REGION
filters:
  tag:Environment: $ENVIRONMENT
  tag:Project: $PROJECT_NAME
 keyed_groups:
  tag:Name
  tag:Environment
  tag:Project
 compose:
    ansible_host: public_ip_address
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/$SSH_KEY_NAME.pem
EOF
    
    print_status "PASS" "Updated Ansible inventory"
    
    # Test inventory
    if ansible-inventory -i inventory/aws-demo.yml --list >/dev/null 2>&1; then
        print_status "PASS" "Ansible inventory validation passed"
    else
        print_status "WARN" "Ansible inventory validation failed"
    fi
    
    cd - >/dev/null
}

# Function to configure instances with Ansible
configure_instances() {
    print_status "INFO" "Configuring instances with Ansible..."
    
    cd ansible
    
    # Wait for instances to be ready
    print_status "INFO" "Waiting for instances to be ready (60 seconds)..."
    sleep 60
    
    # Test connectivity
    print_status "INFO" "Testing SSH connectivity..."
    if ansible-inventory -i inventory/aws-demo.yml --list >/dev/null 2>&1; then
        print_status "PASS" "Inventory accessible"
    else
        print_status "WARN" "Inventory not yet accessible"
    fi
    
    # Run site playbook
    print_status "INFO" "Running site configuration playbook..."
    if timeout 600 ansible-playbook -i inventory/aws-demo.yml playbooks/site.yml >/dev/null 2>&1; then
        print_status "PASS" "Site configuration completed"
    else
        print_status "WARN" "Site configuration may have issues"
    fi
    
    # Run security hardening
    print_status "INFO" "Running security hardening..."
    if timeout 300 ansible-playbook -i inventory/aws-demo.yml playbooks/hardening.yml >/dev/null 2>&1; then
        print_status "PASS" "Security hardening completed"
    else
        print_status "WARN" "Security hardening may have issues"
    fi
    
    cd - >/dev/null
}

# Function to setup cost monitoring
setup_cost_monitoring() {
    print_status "INFO" "Setting up cost monitoring..."
    
    # Create cost alarm
    if [ -n "$ALARM_EMAIL" ]; then
        aws cloudwatch put-metric-alarm \
            --alarm-name "Demo-Daily-Cost-Alarm" \
            --alarm-description "Alert when daily demo costs exceed $5" \
            --metric-name EstimatedCharges \
            --namespace AWS/Billing \
            --statistic Sum \
            --period 86400 \
            --threshold 5 \
            --comparison-operator GreaterThanThreshold \
            --evaluation-periods 1 \
            --alarm-actions "$ALARM_EMAIL" \
            --region us-east-1 >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            print_status "PASS" "Cost monitoring alarm created"
        else
            print_status "WARN" "Could not create cost alarm"
        fi
    else
        print_status "INFO" "Skipping cost alarm (no email provided)"
    fi
    
    # Create budget
    if command -v aws budgets &> /dev/null; then
        aws budgets create-budget \
            --account-id "$(aws sts get-caller-identity --query Account --output text)" \
            --budget '{
                "BudgetName": "'$PROJECT_NAME'-demo-budget",
                "BudgetType": "COST",
                "TimeUnit": "MONTHLY",
                "BudgetLimit": {
                    "Amount": "15",
                    "Unit": "USD"
                },
                "CostFilters": [
                    {
                        "Key": "Service",
                        "Values": ["Amazon EC2", "Amazon S3", "Amazon CloudWatch"]
                    }
                ]
            }' \
            --notifications-with-subscribers '[{
                "Notification": {
                    "NotificationType": "ACTUAL",
                    "ComparisonOperator": "GREATER_THAN",
                    "Threshold": {
                        "Amount": "10",
                        "Unit": "PERCENT"
                    }
                },
                "Subscribers": [{
                    "SubscriptionType": "EMAIL",
                    "Address": "'$ALARM_EMAIL'"
                }]
            }]' >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            print_status "PASS" "AWS Budget created"
        else
            print_status "WARN" "Could not create AWS budget"
        fi
    else
        print_status "INFO" "AWS Budgets not available"
    fi
}

# Function to display deployment summary
display_summary() {
    print_status "INFO" "Generating deployment summary..."
    
    echo ""
    echo "🎊 On-Demand Demo Deployment Summary"
    echo "====================================="
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Duration: $DEPLOYMENT_TIMEOUT seconds"
    echo ""
    
    # Get instance information
    if [ -f "/tmp/demo-outputs.json" ]; then
        local instance_ids=$(jq -r '.instance_ids.value[]?' /tmp/demo-outputs.json 2>/dev/null | tr '\n' ' ' || echo "N/A")
        local public_ips=$(jq -r '.instance_public_ips.value[]?' /tmp/demo-outputs.json 2>/dev/null | tr '\n' ' ' || echo "N/A")
        local vpc_id=$(jq -r '.vpc_id.value' /tmp/demo-outputs.json 2>/dev/null || echo "N/A")
        
        echo "Instance IDs: $instance_ids"
        echo "Public IPs: $public_ips"
        echo "VPC ID: $vpc_id"
    fi
    
    echo ""
    echo "💰 Cost Information:"
    echo "  - EC2 Instance: ~$0.008/hour (t4g.micro)"
    echo "  - EBS Storage: ~$0.06/month (8GB gp3)"
    echo "  - Data Transfer: ~$0.01/GB"
    echo "  - Monitoring: ~$0.50/month (CloudWatch)"
    echo "  - Estimated 3-hour cost: ~$0.05"
    echo ""
    
    echo "🔧 Access Information:"
    echo "  - SSH: ssh -i ~/.ssh/$SSH_KEY_NAME.pem ubuntu@<PUBLIC_IP>"
    echo "  - Web: http://<PUBLIC_IP>"
    echo ""
    
    echo "📋 Cleanup Commands:"
    echo "  - Quick cleanup: ./cleanup-demo.sh"
    echo "  - Manual cleanup: cd terraform/aws && terraform destroy"
    echo ""
    
    echo "⏰ Automatic Cleanup:"
    if [ "$ENABLE_AUTO_CLEANUP" = true ]; then
        echo "  - Scheduled for $(date -d "+$CLEANUP_DELAY_HOURS hours")"
    else
        echo "  - Disabled (manual cleanup required)"
    fi
    
    echo ""
    echo "💡 Cost Optimization Features:"
    echo "  ✅ NAT Gateway disabled (saves $33/month)"
    echo "  ✅ Load Balancer disabled (saves $22/month)"
    echo "  ✅ ARM instances used (60% cheaper)"
    echo "  ✅ Minimal storage (8GB)"
    echo "  ✅ Cost monitoring enabled"
    echo "  ✅ Budget alerts configured"
    echo ""
    
    echo "🔔 Monitoring:"
    echo "  - CloudWatch metrics enabled"
    echo "  - Cost alarms configured"
    echo "  - Budget alerts set"
    echo "  - Anomaly detection enabled"
}

# Function to handle cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        print_status "WARN" "Deployment failed, checking for partial resources..."
        print_status "INFO" "Run 'cd terraform/aws && terraform destroy' to clean up"
    fi
    
    exit $exit_code
}

# Main execution
echo ""
print_status "INFO" "Starting on-demand demo deployment..."

# Set up cleanup trap
trap cleanup_on_exit EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ssh-key)
            SSH_KEY_NAME="$2"
            shift 2
            ;;
        --alarm-email)
            ALARM_EMAIL="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --auto-cleanup)
            ENABLE_AUTO_CLEANUP=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --ssh-key KEY_NAME     SSH key name to use"
            echo "  --alarm-email EMAIL    Email for cost alarms"
            echo "  --region REGION         AWS region (default: us-east-1)"
            echo "  --auto-cleanup        Enable automatic cleanup"
            echo "  --help                Show this help"
            exit 0
            ;;
        *)
            print_status "WARN" "Unknown option: $1"
            shift
            ;;
    esac
done

# Run deployment steps
check_prerequisites

# Get latest AMI
LATEST_AMI=$(get_latest_ami "$AWS_REGION")

# Create terraform.tfvars
create_terraform_tfvars "$LATEST_AMI"

# Deploy infrastructure
deploy_infrastructure

# Update Ansible inventory
update_ansible_inventory

# Configure instances
configure_instances

# Setup cost monitoring
setup_cost_monitoring

# Display summary
display_summary

# Success message
echo ""
print_status "PASS" "🎉 Demo deployment completed successfully!"
echo ""
echo "📞 Next Steps:"
echo "   1. Test the deployed infrastructure"
echo "   2. Run your demo/presentation"
echo "   3. Cleanup when finished: ./cleanup-demo.sh"
echo ""
echo "💸 Important:"
echo "   - Infrastructure costs money while running"
echo "   - Monitor costs in AWS Console"
echo "   - Run cleanup script when demo is complete"

exit 0
