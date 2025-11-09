#!/bin/bash

# LocalStack Setup and Validation Script

set -e

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

echo "=========================================="
print_header "LocalStack Setup Script"
echo "=========================================="
echo ""

# Check prerequisites
print_header "Checking prerequisites..."
echo ""

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi
print_success "Docker is installed"

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi
print_success "Terraform is installed"

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi
print_success "AWS CLI is installed"

echo ""
print_header "Starting LocalStack..."
echo ""

cd "$(dirname "$0")/../docker"

if docker-compose ps | grep -q "localstack-main.*Up"; then
    print_info "LocalStack is already running"
else
    docker-compose up -d
    print_info "Waiting for LocalStack to initialize..."
    sleep 15
    print_success "LocalStack started"
fi

echo ""
print_header "Validating LocalStack..."
echo ""

if curl -s http://localhost:4566/_localstack/health &> /dev/null; then
    print_success "LocalStack is responding"
else
    print_error "LocalStack health check failed"
    exit 1
fi

echo ""
print_header "Initializing Terraform..."
echo ""

cd ../terraform/localstack

if terraform init; then
    print_success "Terraform initialized"
else
    print_error "Terraform initialization failed"
    exit 1
fi

if terraform validate; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform validation failed"
    exit 1
fi

echo ""
echo "=========================================="
print_success "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. cd terraform/localstack"
echo "  2. terraform plan"
echo "  3. terraform apply"
echo ""
echo "Or use: make full-local-deploy"
echo ""
