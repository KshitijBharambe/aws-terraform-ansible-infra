#!/bin/bash

# Validation Script - Run all checks

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo "=========================================="
echo "Running Validations"
echo "=========================================="
echo ""

VALIDATION_FAILED=0

# Terraform Format Check
echo "1. Terraform Format Check"
echo "----------------------------------------"
cd "$(dirname "$0")/../terraform"

if terraform fmt -check -recursive; then
    print_success "Terraform format check passed"
else
    print_error "Terraform format check failed"
    VALIDATION_FAILED=1
fi

# Terraform Validation
echo ""
echo "2. Terraform Validation"
echo "----------------------------------------"

cd localstack
if [ -d ".terraform" ]; then
    if terraform validate; then
        print_success "Terraform validation passed"
    else
        print_error "Terraform validation failed"
        VALIDATION_FAILED=1
    fi
else
    echo "Skipping validation (not initialized)"
fi

echo ""
echo "=========================================="
if [ $VALIDATION_FAILED -eq 0 ]; then
    print_success "All validations passed!"
else
    print_error "Some validations failed"
    exit 1
fi
echo "=========================================="
