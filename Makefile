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
