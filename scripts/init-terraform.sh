#!/bin/bash

# Terraform LocalStack Initialization Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

cd "$(dirname "$0")/../terraform/localstack"

echo ""
echo "════════════════════════════════════════"
print_header "Terraform LocalStack Initialization"
echo "════════════════════════════════════════"
echo ""

# Check if LocalStack is running
print_header "Step 1: Checking LocalStack..."
if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    print_success "LocalStack is running"
else
    print_error "LocalStack is not running"
    echo ""
    echo "Start LocalStack first:"
    echo "  cd docker && docker-compose up -d"
    echo "Or use: make local-start"
    exit 1
fi

echo ""
print_header "Step 2: Cleaning previous state..."
# Remove old state and cache
rm -rf .terraform terraform.tfstate* .terraform.lock.hcl 2>/dev/null
print_success "Cleaned"

echo ""
print_header "Step 3: Initializing Terraform..."

# Set environment variables to help with AWS provider
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Initialize with retry
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if terraform init -upgrade; then
        print_success "Terraform initialized successfully"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_info "Retry $RETRY_COUNT of $MAX_RETRIES..."
            sleep 2
        else
            print_error "Terraform initialization failed after $MAX_RETRIES attempts"
            echo ""
            echo "Troubleshooting:"
            echo "1. Check LocalStack is running: docker-compose ps"
            echo "2. Check port 4566: curl http://localhost:4566/_localstack/health"
            echo "3. Try manually: cd terraform/localstack && terraform init"
            exit 1
        fi
    fi
done

echo ""
print_header "Step 4: Validating configuration..."
if terraform validate; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform validation failed"
    exit 1
fi

echo ""
print_header "Step 5: Formatting code..."
terraform fmt
print_success "Code formatted"

echo ""
echo "════════════════════════════════════════"
print_success "Initialization Complete!"
echo "════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Review the plan: terraform plan"
echo "  2. Deploy: terraform apply"
echo "  3. Or use: make local-apply"
echo ""
