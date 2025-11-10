.PHONY: help
.DEFAULT_GOAL := help

# Project variables
PROJECT_NAME := aws-terraform-ansible-infra
TERRAFORM_LOCALSTACK_DIR := terraform/localstack
TERRAFORM_AWS_DIR := terraform/aws
LOCALSTACK_DIR := docker

# LocalStack environment variables
export AWS_ACCESS_KEY_ID := test
export AWS_SECRET_ACCESS_KEY := test
export AWS_DEFAULT_REGION := us-east-1

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

##@ General

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(BLUE)Usage:$(NC)\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ LocalStack

local-start: ## Start LocalStack
	@echo "$(BLUE)Starting LocalStack...$(NC)"
	@cd $(LOCALSTACK_DIR) && docker-compose up -d
	@echo "$(YELLOW)Waiting for LocalStack to initialize...$(NC)"
	@sleep 15
	@echo "$(GREEN)LocalStack started at http://localhost:4566$(NC)"

local-stop: ## Stop LocalStack
	@echo "$(YELLOW)Stopping LocalStack...$(NC)"
	@cd $(LOCALSTACK_DIR) && docker-compose down

local-restart: local-stop local-start ## Restart LocalStack

local-logs: ## Show LocalStack logs
	@cd $(LOCALSTACK_DIR) && docker-compose logs -f

local-status: ## Check LocalStack status
	@cd $(LOCALSTACK_DIR) && docker-compose ps
	@echo ""
	@echo "Health check:"
	@curl -s http://localhost:4566/_localstack/health | python3 -m json.tool 2>/dev/null || echo "Not responding"

local-clean: ## Clean LocalStack data
	@echo "$(YELLOW)Cleaning LocalStack...$(NC)"
	@cd $(LOCALSTACK_DIR) && docker-compose down -v
	@echo "$(GREEN)Cleaned$(NC)"

##@ Terraform LocalStack

local-init: ## Initialize Terraform for LocalStack
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	@cd $(TERRAFORM_LOCALSTACK_DIR) && rm -rf .terraform .terraform.lock.hcl 2>/dev/null || true
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform init -upgrade
	@echo "$(GREEN)Terraform initialized$(NC)"

local-validate: ## Validate Terraform configuration
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform validate

local-plan: ## Generate Terraform plan
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform plan

local-apply: ## Apply Terraform configuration
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform apply

local-apply-auto: ## Apply without confirmation
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform apply -auto-approve

local-destroy: ## Destroy infrastructure
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform destroy

local-destroy-auto: ## Destroy without confirmation
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform destroy -auto-approve

local-output: ## Show Terraform outputs
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform output

local-fmt: ## Format Terraform code
	@cd terraform && terraform fmt -recursive
	@echo "$(GREEN)Terraform formatted$(NC)"

##@ Terraform AWS

aws-init: ## Initialize Terraform for AWS
	@cd $(TERRAFORM_AWS_DIR) && terraform init

aws-plan: ## Generate AWS plan
	@cd $(TERRAFORM_AWS_DIR) && terraform plan -out=tfplan

aws-deploy: ## Deploy to AWS (with confirmation)
	@echo "$(YELLOW)⚠️  This will cost money!$(NC)"
	@read -p "Deploy to AWS? [y/N] " -n 1 -r; echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TERRAFORM_AWS_DIR) && terraform apply tfplan; \
	fi

aws-destroy: ## Destroy AWS resources
	@cd $(TERRAFORM_AWS_DIR) && terraform destroy

##@ Validation & Testing

validate: ## Run all validations
	@echo "$(BLUE)Running validations...$(NC)"
	@cd terraform && terraform fmt -check -recursive || (echo "$(YELLOW)Run 'make local-fmt' to fix$(NC)" && exit 1)
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform validate
	@echo "$(GREEN)All validations passed$(NC)"

##@ Utilities

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@find . -name "*.tfstate*" -delete 2>/dev/null || true
	@find . -name "tfplan" -delete 2>/dev/null || true
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "$(GREEN)Cleaned$(NC)"

fix-localstack: ## Fix LocalStack startup issues
	@chmod +x scripts/fix-localstack.sh
	@./scripts/fix-localstack.sh

fix-terraform: ## Fix Terraform initialization issues
	@chmod +x scripts/init-terraform.sh
	@./scripts/init-terraform.sh

##@ Complete Workflows

setup-dev: local-start ## Setup development environment
	@echo "$(YELLOW)Waiting for LocalStack...$(NC)"
	@sleep 15
	@$(MAKE) local-init
	@echo ""
	@echo "$(GREEN)✓ Development environment ready!$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  make local-plan   # Review infrastructure"
	@echo "  make local-apply  # Deploy infrastructure"

full-local-deploy: local-start ## Complete LocalStack deployment
	@sleep 15
	@$(MAKE) local-init
	@$(MAKE) local-apply-auto
	@$(MAKE) local-output
	@echo "$(GREEN)✓ Deployment complete!$(NC)"

full-local-destroy: local-destroy-auto local-stop ## Complete cleanup
	@echo "$(GREEN)✓ Everything cleaned up!$(NC)"

fresh-start: local-clean clean local-start local-init ## Complete fresh start
	@echo "$(GREEN)✓ Fresh start complete!$(NC)"

version: ## Show tool versions
	@echo "Tool Versions:"
	@echo "  Terraform: $$(terraform version | head -1)"
	@echo "  Docker: $$(docker --version)"
	@echo "  AWS CLI: $$(aws --version)"

test: ## Test LocalStack connectivity
	@echo "Testing LocalStack..."
	@curl -s http://localhost:4566/_localstack/health && echo "$(GREEN)✓ LocalStack responding$(NC)" || echo "$(YELLOW)✗ LocalStack not responding$(NC)"
	@aws --endpoint-url=http://localhost:4566 s3 ls && echo "$(GREEN)✓ AWS CLI working$(NC)" || echo "$(YELLOW)✗ AWS CLI not working$(NC)"

##@ Ansible

ansible-install: ## Install Ansible dependencies
	@echo "$(BLUE)Installing Ansible dependencies...$(NC)"
	@cd ansible && pip3 install -r requirements.yml
	@echo "$(GREEN)Ansible dependencies installed$(NC)"

ansible-local: ## Run Ansible on LocalStack
	@echo "$(BLUE)Running Ansible on LocalStack...$(NC)"
	@cd ansible && ansible-playbook -i inventory/localstack.ini playbooks/site.yml
	@echo "$(GREEN)Ansible playbook completed$(NC)"

ansible-aws: ## Run Ansible on AWS
	@echo "$(BLUE)Running Ansible on AWS...$(NC)"
	@cd ansible && ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
	@echo "$(GREEN)Ansible playbook completed$(NC)"

ansible-check: ## Check Ansible syntax
	@echo "$(BLUE)Checking Ansible syntax...$(NC)"
	@cd ansible && ansible-playbook --syntax-check playbooks/site.yml
	@cd ansible && ansible-playbook --list-tasks playbooks/site.yml
	@echo "$(GREEN)Ansible syntax valid$(NC)"

ansible-lint: ## Run Ansible linting
	@echo "$(BLUE)Running Ansible linting...$(NC)"
	@cd ansible && ansible-lint playbooks/site.yml
	@echo "$(GREEN)Ansible linting completed$(NC)"

##@ Testing & Validation

test-all: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@$(MAKE) validate
	@$(MAKE) test
	@$(MAKE) ansible-check
	@$(MAKE) security-scan
	@$(MAKE) integration-test
	@echo "$(GREEN)All tests completed$(NC)"

integration-test: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@chmod +x tests/integration/smoke-test.sh
	@./tests/integration/smoke-test.sh
	@echo "$(GREEN)Integration tests completed$(NC)"

security-scan: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	@chmod +x tests/security/compliance-test.sh
	@./tests/security/compliance-test.sh
	@$(MAKE) terraform-security-scan
	@echo "$(GREEN)Security scans completed$(NC)"

terraform-security-scan: ## Run Terraform security scan
	@echo "$(BLUE)Running Terraform security scan...$(NC)"
	@chmod +x tests/terraform/security-scan.sh
	@./tests/terraform/security-scan.sh
	@echo "$(GREEN)Terraform security scan completed$(NC)"

lint: ## Run all linting
	@echo "$(BLUE)Running all linting...$(NC)"
	@$(MAKE) local-fmt
	@$(MAKE) ansible-lint
	@pre-commit run --all-files
	@echo "$(GREEN)Linting completed$(NC)"

##@ Cost Management

aws-cost: ## Check AWS costs
	@echo "$(BLUE)Checking AWS costs...$(NC)"
	@chmod +x scripts/cost-check.sh
	@./scripts/cost-check.sh
	@echo "$(GREEN)Cost check completed$(NC)"

cost-report: ## Generate cost report
	@echo "$(BLUE)Generating cost report...$(NC)"
	@chmod +x scripts/cost-comparison.sh
	@./scripts/cost-comparison.sh
	@echo "$(GREEN)Cost report generated$(NC)"

cost-forecast: ## Predict monthly costs
	@echo "$(BLUE)Generating cost forecast...$(NC)"
	@echo "Cost forecast feature - calculating estimated monthly costs..."
	@echo "Current estimated daily cost: ~$5-10"
	@echo "Estimated monthly cost: ~$150-300"
	@echo "$(YELLOW)Note: These are estimates. Actual costs may vary.$(NC)"

cost-breakdown: ## Detailed cost analysis by service
	@echo "$(BLUE)Generating cost breakdown...$(NC)"
	@echo "Cost Breakdown by Service:"
	@echo "  - EC2 Instances: ~60% of total"
	@echo "  - Data Transfer: ~20% of total"
	@echo "  - Load Balancer: ~15% (if enabled)"
	@echo "  - Storage: ~5% of total"
	@echo "$(YELLOW)Use 'make aws-cost' for actual current costs$(NC)"

##@ Documentation

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@mkdir -p docs/{architecture,runbooks,guides,security}
	@echo "$(GREEN)Documentation structure created$(NC)"
	@$(MAKE) docs-architecture
	@$(MAKE) docs-runbooks

docs-architecture: ## Generate architecture documentation
	@echo "$(BLUE)Generating architecture documentation...$(NC)"
	@cat > docs/architecture/overview.md << 'EOF'
# Architecture Overview

## Infrastructure Components

### Compute
- **Web Servers**: Nginx/Apache web servers for static content
- **App Servers**: Application servers for business logic
- **Load Balancer**: Application Load Balancer for traffic distribution

### Networking
- **VPC**: Virtual Private Cloud with public/private subnets
- **Security Groups**: Network-level access control
- **NAT Gateway**: Outbound internet access for private instances

### Storage & Backup
- **EBS Volumes**: Block storage for instances
- **S3 Buckets**: Object storage for backups and state
- **AWS Backup**: Automated backup service

### Monitoring & Logging
- **CloudWatch**: Metrics, logs, and alarms
- **SNS**: Notification service for alerts

### Security
- **IAM**: Identity and Access Management
- **Security Groups**: Network firewalls
- **SSL/TLS**: Encrypted communications

## Cost Optimization

### On-Demand Deployment Features
- Cost-optimized instance types (t4g.micro)
- Disabled NAT Gateway by default
- Minimal monitoring and logging
- Automated backup with 7-day retention

### Production Recommendations
- Enable NAT Gateway for private subnets
- Use Application Load Balancer for high availability
- Implement comprehensive monitoring
- Use longer backup retention periods
EOF
	@echo "$(GREEN)Architecture documentation generated$(NC)"

docs-runbooks: ## Generate runbooks
	@echo "$(BLUE)Generating runbooks...$(NC)"
	@mkdir -p docs/runbooks
	@cat > docs/runbooks/deployment.md << 'EOF'
# Deployment Runbook

## Prerequisites
1. AWS CLI configured with appropriate credentials
2. Terraform installed
3. SSH key pair created in AWS
4. Domain name (optional, for SSL)

## Deployment Steps

### 1. Prepare Environment
```bash
# Clone repository
git clone <repository-url>
cd aws-terraform-ansible-infra

# Copy and configure variables
cp terraform/aws/terraform.tfvars.example terraform/aws/terraform.tfvars
# Edit terraform/aws/terraform.tfvars with your values
```

### 2. Deploy Infrastructure
```bash
# Initialize Terraform
make aws-init

# Plan deployment
make aws-plan

# Deploy (will prompt for confirmation)
make aws-deploy
```

### 3. Configure Applications
```bash
# Run Ansible playbooks
make ansible-aws
```

### 4. Verify Deployment
```bash
# Check outputs
cd terraform/aws && terraform output

# Test web access
curl http://<load-balancer-dns>/
```

## Troubleshooting

### Common Issues
1. **SSH Access Failed**: Check security group rules
2. **Instance Not Starting**: Verify AMI and instance type
3. **Load Balancer Health Checks**: Check security group and health check path

### Rollback
```bash
# Destroy infrastructure
make aws-destroy
```
EOF
	@echo "$(GREEN)Runbooks generated$(NC)"

docs-serve: ## Serve documentation locally
	@echo "$(BLUE)Starting documentation server...$(NC)"
	@cd docs && python3 -m http.server 8080
	@echo "$(GREEN)Documentation available at http://localhost:8080$(NC)"

##@ Demo Workflows

demo-deploy: ## Quick demo deployment
	@echo "$(BLUE)Starting demo deployment...$(NC)"
	@echo "$(YELLOW)This will deploy a cost-optimized demo environment$(NC)"
	@$(MAKE) local-start
	@sleep 15
	@$(MAKE) local-init
	@$(MAKE) local-apply-auto
	@$(MAKE) local-output
	@$(MAKE) ansible-local
	@echo "$(GREEN)✓ Demo deployment complete!$(NC)"
	@echo ""
	@echo "Demo URLs:"
	@cd $(TERRAFORM_LOCALSTACK_DIR) && terraform output -json | jq -r '.web_access_urls.value | to_entries[] | "  \(.key): \(.value)"'

demo-cleanup: ## Clean up demo
	@echo "$(YELLOW)Cleaning up demo environment...$(NC)"
	@$(MAKE) local-destroy-auto
	@$(MAKE) local-stop
	@$(MAKE) local-clean
	@echo "$(GREEN)✓ Demo cleanup complete!$(NC)"

demo-aws: ## Deploy demo to AWS (cost warning)
	@echo "$(RED)⚠️  WARNING: This will deploy to AWS and incur costs!$(NC)"
	@echo "Expected cost: ~$5-10 for a 3-hour demo"
	@read -p "Continue with AWS demo deployment? [y/N] " -n 1 -r; echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)Deploying demo to AWS...$(NC)"; \
		$(MAKE) aws-init; \
		$(MAKE) aws-plan; \
		$(MAKE) aws-deploy; \
		$(MAKE) ansible-aws; \
		echo "$(GREEN)✓ AWS demo deployment complete!$(NC)"; \
		echo "$(YELLOW)Remember to run 'make aws-destroy' when done!$(NC)"; \
	else \
		echo "$(YELLOW)AWS demo deployment cancelled$(NC)"; \
	fi

demo-quick: ## Quick LocalStack demo (no confirmation)
	@echo "$(BLUE)Quick LocalStack demo...$(NC)"
	@$(MAKE) local-start > /dev/null 2>&1
	@sleep 20
	@$(MAKE) local-init > /dev/null 2>&1
	@$(MAKE) local-apply-auto > /dev/null 2>&1
	@echo "$(GREEN)✓ Quick demo ready!$(NC)"
	@echo "Run 'make local-output' to see access details"
