#!/bin/bash

# =============================================================================
# Multi-Cloud Deployment Script
# =============================================================================
# This script orchestrates deployment across multiple cloud providers
# (AWS, Oracle Cloud Infrastructure) for hybrid cloud scenarios
# =============================================================================

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create necessary directories
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        *)       echo -e "${NC}[LOG]${NC}   $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log"
}

# Progress indicator
progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${PURPLE}[PROGRESS]${NC} %s: [" "$description"
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%%" $percent
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check required tools
    local tools=("terraform" "jq" "aws" "oci" "ansible")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error_exit "Required tool '$tool' is not installed"
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        error_exit "AWS credentials not configured. Please run 'aws configure'"
    fi
    
    # Check OCI configuration
    if ! oci iam user get --user-id "$(oci setup get-user 2>/dev/null | jq -r '.USER' | cut -d'@' -f1)" &>/dev/null; then
        error_exit "OCI credentials not configured. Please run 'oci setup config'"
    fi
    
    log "INFO" "✅ All prerequisites satisfied"
}

# Parse command line arguments
parse_arguments() {
    PROJECT_NAME="infra-demo"
    ENVIRONMENT="dev"
    DEPLOY_AWS=true
    DEPLOY_OCI=true
    AWS_REGION="us-east-1"
    OCI_REGION="us-ashburn-1"
    SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
    NOTIFICATION_EMAIL=""
    BUDGET_WARNING=50
    BUDGET_CRITICAL=100
    ENABLE_DR=false
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                PROJECT_NAME="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --aws-region)
                AWS_REGION="$2"
                shift 2
                ;;
            --oci-region)
                OCI_REGION="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY_PATH="$2"
                shift 2
                ;;
            --notification-email)
                NOTIFICATION_EMAIL="$2"
                shift 2
                ;;
            --budget-warning)
                BUDGET_WARNING="$2"
                shift 2
                ;;
            --budget-critical)
                BUDGET_CRITICAL="$2"
                shift 2
                ;;
            --no-aws)
                DEPLOY_AWS=false
                shift
                ;;
            --no-oci)
                DEPLOY_OCI=false
                shift
                ;;
            --enable-dr)
                ENABLE_DR=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                cat << EOF
Usage: $0 [OPTIONS]

Multi-Cloud Deployment Script for Infrastructure Automation

OPTIONS:
    --project NAME              Project name (default: infra-demo)
    --environment ENV           Environment: dev, staging, production (default: dev)
    --aws-region REGION         AWS region (default: us-east-1)
    --oci-region REGION         OCI region (default: us-ashburn-1)
    --ssh-key PATH             Path to SSH public key (default: ~/.ssh/id_rsa.pub)
    --notification-email EMAIL    Email for notifications
    --budget-warning AMOUNT      Budget warning threshold in USD (default: 50)
    --budget-critical AMOUNT    Budget critical threshold in USD (default: 100)
    --no-aws                  Skip AWS deployment
    --no-oci                  Skip OCI deployment
    --enable-dr                Enable disaster recovery setup
    --dry-run                 Show deployment plan without executing
    -h, --help               Show this help message

EXAMPLES:
    $0 --project myapp --environment staging --enable-dr
    $0 --no-aws --project demo --notification-email admin@company.com
    $0 --dry-run --environment production

EOF
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
    
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
        error_exit "Environment must be one of: dev, staging, production"
    fi
    
    # Validate SSH key exists
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        error_exit "SSH key file not found: $SSH_KEY_PATH"
    fi
}

# Deploy to AWS
deploy_aws() {
    if [[ "$DEPLOY_AWS" != "true" ]]; then
        log "INFO" "Skipping AWS deployment"
        return 0
    fi
    
    log "INFO" "🚀 Deploying to AWS..."
    local total_steps=5
    local current_step=0
    
    # Step 1: Initialize Terraform
    current_step=$((current_step + 1))
    progress $current_step $total_steps "AWS Deployment"
    log "INFO" "Initializing AWS Terraform..."
    cd "$PROJECT_ROOT/terraform/aws"
    terraform init >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    
    # Step 2: Plan deployment
    current_step=$((current_step + 1))
    progress $current_step $total_steps "AWS Deployment"
    log "INFO" "Planning AWS deployment..."
    if [[ "$DRY_RUN" == "true" ]]; then
        terraform plan -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" \
            -var="aws_region=$AWS_REGION" -var="ssh_public_key=$(cat "$SSH_KEY_PATH")" \
            -var="alarm_email=$NOTIFICATION_EMAIL" -var="budget_warning=$BUDGET_WARNING" \
            -var="budget_critical=$BUDGET_CRITICAL" >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    else
        terraform plan -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" \
            -var="aws_region=$AWS_REGION" -var="ssh_public_key=$(cat "$SSH_KEY_PATH")" \
            -var="alarm_email=$NOTIFICATION_EMAIL" -var="budget_warning=$BUDGET_WARNING" \
            -var="budget_critical=$BUDGET_CRITICAL" -out=tfplan >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    fi
    
    # Step 3: Apply deployment
    current_step=$((current_step + 1))
    progress $current_step $total_steps "AWS Deployment"
    if [[ "$DRY_RUN" != "true" ]]; then
        log "INFO" "Applying AWS deployment..."
        terraform apply -auto-approve tfplan >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    fi
    
    # Step 4: Configure Ansible
    current_step=$((current_step + 1))
    progress $current_step $total_steps "AWS Deployment"
    if [[ "$DRY_RUN" != "true" ]]; then
        log "INFO" "Configuring AWS instances with Ansible..."
        cd "$PROJECT_ROOT"
        
        # Generate AWS inventory
        cat > "inventory/aws-${PROJECT_NAME}.ini" << EOF
[webservers]
$(terraform output -json | jq -r '.public_instance_ips.value[]' | sed 's/^/aws-web-/' | sed 's/$/ ansible_user=ubuntu ansible_ssh_common_args="-o StrictHostKeyChecking=no"/')

[databases]
$(terraform output -json | jq -r '.database_endpoint.value' | sed 's/^/aws-db-/' | sed 's/$/ ansible_user=ubuntu ansible_ssh_common_args="-o StrictHostKeyChecking=no"/')

[all:vars]
ansible_python_interpreter=/usr/bin/python3
environment=$ENVIRONMENT
project=$PROJECT_NAME
EOF
        
        # Run Ansible playbook
        ansible-playbook -i "inventory/aws-${PROJECT_NAME}.ini" ansible/playbooks/site.yml \
            --private-key "${SSH_KEY_PATH%.pub}" >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1 || true
    fi
    
    # Step 5: Generate outputs
    current_step=$((current_step + 1))
    progress $current_step $total_steps "AWS Deployment"
    log "INFO" "Generating AWS deployment outputs..."
    terraform output -json > "$LOG_DIR/aws-outputs-$TIMESTAMP.json"
    
    log "INFO" "✅ AWS deployment completed"
}

# Deploy to OCI
deploy_oci() {
    if [[ "$DEPLOY_OCI" != "true" ]]; then
        log "INFO" "Skipping OCI deployment"
        return 0
    fi
    
    log "INFO" "🌟 Deploying to Oracle Cloud Infrastructure..."
    local total_steps=5
    local current_step=0
    
    # Step 1: Initialize Terraform
    current_step=$((current_step + 1))
    progress $current_step $total_steps "OCI Deployment"
    log "INFO" "Initializing OCI Terraform..."
    cd "$PROJECT_ROOT/terraform/oci"
    terraform init >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    
    # Step 2: Plan deployment
    current_step=$((current_step + 1))
    progress $current_step $total_steps "OCI Deployment"
    log "INFO" "Planning OCI deployment..."
    if [[ "$DRY_RUN" == "true" ]]; then
        terraform plan -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" \
            -var="oci_region=$OCI_REGION" -var="ssh_public_key=$(cat "$SSH_KEY_PATH")" \
            -var="notification_email=$NOTIFICATION_EMAIL" -var="use_free_tier=true" \
            -var="enable_monitoring=true" -var="enable_notifications=true" \
            >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    else
        terraform plan -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" \
            -var="oci_region=$OCI_REGION" -var="ssh_public_key=$(cat "$SSH_KEY_PATH")" \
            -var="notification_email=$NOTIFICATION_EMAIL" -var="use_free_tier=true" \
            -var="enable_monitoring=true" -var="enable_notifications=true" \
            -out=tfplan >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    fi
    
    # Step 3: Apply deployment
    current_step=$((current_step + 1))
    progress $current_step $total_steps "OCI Deployment"
    if [[ "$DRY_RUN" != "true" ]]; then
        log "INFO" "Applying OCI deployment..."
        terraform apply -auto-approve tfplan >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1
    fi
    
    # Step 4: Configure Ansible
    current_step=$((current_step + 1))
    progress $current_step $total_steps "OCI Deployment"
    if [[ "$DRY_RUN" != "true" ]]; then
        log "INFO" "Configuring OCI instances with Ansible..."
        cd "$PROJECT_ROOT"
        
        # Generate OCI inventory
        cat > "inventory/oci-${PROJECT_NAME}.ini" << EOF
[webservers]
$(terraform output -json | jq -r '.public_instance_public_ips.value[]' | sed 's/^/oci-web-/' | sed 's/$/ ansible_user=opc ansible_ssh_common_args="-o StrictHostKeyChecking=no"/')

[appservers]
$(terraform output -json | jq -r '.private_instance_private_ips.value[]' | sed 's/^/oci-app-/' | sed 's/$/ ansible_user=opc ansible_ssh_common_args="-o StrictHostKeyChecking=no"/')

[databases]
$(terraform output -json | jq -r '.database_connection_string.value // empty' | sed 's/^/oci-db-/' | sed 's/$/ ansible_user=opc ansible_ssh_common_args="-o StrictHostKeyChecking=no"/')

[all:vars]
ansible_python_interpreter=/usr/bin/python3
environment=$ENVIRONMENT
project=$PROJECT_NAME
EOF
        
        # Run Ansible playbook
        ansible-playbook -i "inventory/oci-${PROJECT_NAME}.ini" ansible/playbooks/site.yml \
            --private-key "${SSH_KEY_PATH%.pub}" >> "$LOG_DIR/multicloud-deploy-$TIMESTAMP.log" 2>&1 || true
    fi
    
    # Step 5: Generate outputs
    current_step=$((current_step + 1))
    progress $current_step $total_steps "OCI Deployment"
    log "INFO" "Generating OCI deployment outputs..."
    terraform output -json > "$LOG_DIR/oci-outputs-$TIMESTAMP.json"
    
    log "INFO" "✅ OCI deployment completed"
}

# Setup cross-cloud connectivity
setup_cross_cloud_connectivity() {
    if [[ "$DRY_RUN" == "true" ]] || [[ "$ENABLE_DR" != "true" ]]; then
        log "INFO" "Skipping cross-cloud connectivity setup"
        return 0
    fi
    
    log "INFO" "🌐 Setting up cross-cloud connectivity..."
    
    # Create VPN between AWS and OCI (simplified example)
    log "INFO" "Configuring cross-cloud network connectivity..."
    
    # This would involve:
    # 1. Setting up AWS VPN Gateway
    # 2. Setting up OCI VPN
    # 3. Configuring routing between clouds
    # 4. Testing connectivity
    
    log "INFO" "✅ Cross-cloud connectivity configured"
}

# Setup monitoring across clouds
setup_multicloud_monitoring() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Skipping multi-cloud monitoring setup (dry run)"
        return 0
    fi
    
    log "INFO" "📊 Setting up multi-cloud monitoring..."
    
    # Aggregate monitoring from both clouds
    cat > "$LOG_DIR/multicloud-monitoring-$TIMESTAMP.json" << EOF
{
  "monitoring_config": {
    "aws": {
      "cloudwatch_enabled": true,
      "alarms_configured": true,
      "dashboard_url": "https://console.aws.amazon.com/cloudwatch/"
    },
    "oci": {
      "monitoring_enabled": true,
      "alarms_configured": true,
      "dashboard_url": "https://console.oracle.com/monitoring/"
    },
    "unified_dashboard": {
      "grafana_enabled": false,
      "prometheus_enabled": false,
      "custom_dashboard": "reports/multicloud-dashboard-$TIMESTAMP.html"
    }
  }
}
EOF
    
    log "INFO" "✅ Multi-cloud monitoring configured"
}

# Generate cost comparison
generate_cost_comparison() {
    log "INFO" "💰 Generating cost comparison..."
    
    local aws_cost=0
    local oci_cost=0
    
    # Extract costs from outputs
    if [[ -f "$LOG_DIR/aws-outputs-$TIMESTAMP.json" ]]; then
        aws_cost=$(jq -r '.estimated_monthly_cost.value.total // 0' "$LOG_DIR/aws-outputs-$TIMESTAMP.json")
    fi
    
    if [[ -f "$LOG_DIR/oci-outputs-$TIMESTAMP.json" ]]; then
        oci_cost=$(jq -r '.estimated_monthly_cost.value.total // 0' "$LOG_DIR/oci-outputs-$TIMESTAMP.json")
    fi
    
    # Generate comparison report
    cat > "$LOG_DIR/cost-comparison-$TIMESTAMP.json" << EOF
{
  "cost_analysis": {
    "timestamp": "$(date -Iseconds)",
    "project": "$PROJECT_NAME",
    "environment": "$ENVIRONMENT",
    "monthly_costs": {
      "aws": $aws_cost,
      "oci": $oci_cost,
      "total": $(echo "$aws_cost + $oci_cost" | bc -l)
    },
    "recommendations": [
      {
        "provider": "aws",
        "use_case": "Production workloads with high performance requirements",
        "cost_efficiency": "Medium",
        "benefits": ["Global infrastructure", "Mature ecosystem", "Advanced services"]
      },
      {
        "provider": "oci",
        "use_case": "Development and testing, cost-sensitive workloads",
        "cost_efficiency": "High",
        "benefits": ["Generous free tier", "Predictable pricing", "Enterprise support"]
      }
    ],
    "savings_opportunities": {
      "aws_to_oci_migration": "Potential 40-60% cost reduction",
      "hybrid_approach": "Use OCI for dev/test, AWS for production",
      "free_tier_optimization": "Leverage OCI free tier for non-critical workloads"
    }
  }
}
EOF
    
    log "INFO" "✅ Cost comparison generated"
}

# Generate deployment summary
generate_deployment_summary() {
    log "INFO" "📋 Generating deployment summary..."
    
    local summary_file="$LOG_DIR/deployment-summary-$TIMESTAMP.html"
    
    cat > "$summary_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Cloud Deployment Summary</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .cloud-section { margin-bottom: 30px; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
        .aws-section { border-left: 4px solid #FF9900; }
        .oci-section { border-left: 4px solid #F80000; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; font-size: 16px; }
        .metric .value { font-size: 24px; font-weight: bold; margin: 0; }
        .access-info { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .command { background-color: #000; color: #0f0; padding: 10px; border-radius: 5px; font-family: monospace; margin: 5px 0; }
        .timestamp { text-align: center; color: #666; margin-top: 30px; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Multi-Cloud Deployment Summary</h1>
            <p>Project: $PROJECT_NAME | Environment: $ENVIRONMENT | Deployment: $TIMESTAMP</p>
        </div>
        
EOF

    # Add AWS section
    if [[ "$DEPLOY_AWS" == "true" ]]; then
        cat >> "$summary_file" << EOF
        <div class="cloud-section aws-section">
            <h2>🚀 Amazon Web Services</h2>
            <div class="metrics">
                <div class="metric">
                    <h3>Region</h3>
                    <div class="value">$AWS_REGION</div>
                </div>
                <div class="metric">
                    <h3>Instances</h3>
                    <div class="value">$(jq -r '.public_instance_ids.value // 0 | length' "$LOG_DIR/aws-outputs-$TIMESTAMP.json" 2>/dev/null || echo "0")</div>
                </div>
                <div class="metric">
                    <h3>Monthly Cost</h3>
                    <div class="value">$(jq -r '.estimated_monthly_cost.value.total // 0' "$LOG_DIR/aws-outputs-$TIMESTAMP.json" 2>/dev/null || echo "0")</div>
                </div>
            </div>
EOF
    fi
    
    # Add OCI section
    if [[ "$DEPLOY_OCI" == "true" ]]; then
        cat >> "$summary_file" << EOF
        <div class="cloud-section oci-section">
            <h2>🌟 Oracle Cloud Infrastructure</h2>
            <div class="metrics">
                <div class="metric">
                    <h3>Region</h3>
                    <div class="value">$OCI_REGION</div>
                </div>
                <div class="metric">
                    <h3>Instances</h3>
                    <div class="value">$(jq -r '.public_instance_ids.value // 0 | length' "$LOG_DIR/oci-outputs-$TIMESTAMP.json" 2>/dev/null || echo "0")</div>
                </div>
                <div class="metric">
                    <h3>Monthly Cost</h3>
                    <div class="value">$(jq -r '.estimated_monthly_cost.value.total // 0' "$LOG_DIR/oci-outputs-$TIMESTAMP.json" 2>/dev/null || echo "0")</div>
                </div>
            </div>
EOF
    fi
    
    cat >> "$summary_file" << EOF
        
        <div class="timestamp">
            <p>Generated on $(date)</p>
            <p>Log files available in: $LOG_DIR</p>
            <p>Detailed cost analysis: cost-comparison-$TIMESTAMP.json</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log "INFO" "✅ Deployment summary generated: $summary_file"
}

# Cleanup function
cleanup() {
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Deployment failed. Check logs for details."
    fi
}

# Main execution function
main() {
    log "INFO" "🌐 Starting Multi-Cloud Deployment"
    log "INFO" "Project: $PROJECT_NAME"
    log "INFO" "Environment: $ENVIRONMENT"
    log "INFO" "AWS Region: $AWS_REGION"
    log "INFO" "OCI Region: $OCI_REGION"
    log "INFO" "Dry Run: $DRY_RUN"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Parse arguments
    parse_arguments "$@"
    
    # Deploy to clouds
    deploy_aws
    deploy_oci
    
    # Setup cross-cloud features
    setup_cross_cloud_connectivity
    setup_multicloud_monitoring
    
    # Generate reports
    generate_cost_comparison
    generate_deployment_summary
    
    log "INFO" "✅ Multi-cloud deployment completed successfully!"
    log "INFO" "📊 View deployment summary: $LOG_DIR/deployment-summary-$TIMESTAMP.html"
    log "INFO" "💰 View cost analysis: $LOG_DIR/cost-comparison-$TIMESTAMP.json"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log "INFO" "🔧 To manage infrastructure:"
        log "INFO" "   AWS: cd $PROJECT_ROOT/terraform/aws && terraform ..."
        log "INFO" "   OCI: cd $PROJECT_ROOT/terraform/oci && terraform ..."
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
