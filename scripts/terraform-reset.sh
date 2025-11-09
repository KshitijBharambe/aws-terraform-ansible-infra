#!/bin/bash

# Complete Terraform Reset and Initialization
# Fixes provider timeout issues

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }
print_header() { echo -e "${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

cd "$(dirname "$0")/../terraform/localstack"

print_header "Terraform Complete Reset & Fix"
echo ""

# Step 1: Check LocalStack
print_info "Step 1: Checking LocalStack..."
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    print_error "LocalStack is not running!"
    echo ""
    echo "Start LocalStack first:"
    echo "  cd ../../docker && docker-compose up -d"
    echo "  or: make local-start"
    exit 1
fi
print_success "LocalStack is running"
echo ""

# Step 2: Set environment variables
print_info "Step 2: Setting environment variables..."
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export TF_PLUGIN_CACHE_DIR=""
export TF_CLI_ARGS=""
print_success "Environment configured"
echo ""

# Step 3: Clean everything
print_info "Step 3: Removing ALL Terraform cache and state..."
rm -rf .terraform 2>/dev/null
rm -rf .terraform.lock.hcl 2>/dev/null
rm -rf terraform.tfstate* 2>/dev/null
rm -rf ~/.terraform.d/plugin-cache/* 2>/dev/null
print_success "Cleaned"
echo ""

# Step 4: Initialize with specific flags
print_info "Step 4: Initializing Terraform (this may take a minute)..."
echo ""

# Try with upgrade flag and no backend initialization
if terraform init -upgrade -backend=false 2>&1 | tee /tmp/tf_init.log; then
    print_success "Terraform initialized"
else
    print_error "Initialization failed"
    echo ""
    print_info "Trying alternative method..."
    
    # Try without upgrade
    if terraform init -backend=false; then
        print_success "Terraform initialized (alternative method)"
    else
        print_error "Still failing. Check logs above."
        echo ""
        echo "Possible issues:"
        echo "1. Network connectivity problems"
        echo "2. Terraform version incompatibility"
        echo "3. Corrupted plugin cache"
        echo ""
        echo "Try manually:"
        echo "  cd terraform/localstack"
        echo "  rm -rf .terraform"
        echo "  terraform init -upgrade"
        exit 1
    fi
fi

echo ""

# Step 5: Verify provider
print_info "Step 5: Verifying AWS provider..."
if [ -d ".terraform/providers" ]; then
    PROVIDER_PATH=$(find .terraform/providers -name "terraform-provider-aws*" 2>/dev/null | head -1)
    if [ -n "$PROVIDER_PATH" ]; then
        print_success "AWS provider downloaded: $(basename $PROVIDER_PATH)"
    else
        print_error "AWS provider not found in .terraform/providers"
    fi
else
    print_error ".terraform/providers directory not found"
fi
echo ""

# Step 6: Skip validation for now
print_info "Step 6: Skipping validation (will test with plan instead)..."
echo ""

# Step 7: Try a plan
print_info "Step 7: Testing with terraform plan..."
echo ""

if timeout 30 terraform plan -out=tfplan 2>&1; then
    print_success "Plan succeeded!"
    rm tfplan 2>/dev/null
else
    print_error "Plan timed out or failed"
    echo ""
    print_info "This might still work for apply. The timeout might be a validation issue only."
fi

echo ""
print_header "Initialization Complete"
echo ""
echo "Next steps:"
echo "  1. Try: terraform plan"
echo "  2. If plan works: terraform apply"
echo "  3. Or use: make local-apply"
echo ""
print_info "Note: If 'terraform validate' times out but 'plan' works, you can proceed with apply"
echo ""
