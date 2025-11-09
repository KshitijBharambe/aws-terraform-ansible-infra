#!/bin/bash

# Terraform Validation Script
# Validates all Terraform configurations in the project

set -e

echo "🔍 Starting Terraform Validation..."
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

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
            ((VALIDATION_WARNINGS++))
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ((VALIDATION_ERRORS++))
            ;;
        "INFO")
            echo -e "ℹ️  $message"
            ;;
    esac
}

# Function to validate Terraform code
validate_terraform() {
    local dir=$1
    local dir_name=$(basename "$dir")
    
    print_status "INFO" "Validating $dir_name..."
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        print_status "WARN" "Directory $dir does not exist, skipping..."
        return
    fi
    
    cd "$dir"
    
    # Check for .tf files
    if ! ls *.tf >/dev/null 2>&1; then
        print_status "WARN" "No .tf files found in $dir"
        cd - >/dev/null
        return
    fi
    
    # Initialize Terraform (skip backend configuration)
    print_status "INFO" "Running terraform init..."
    if terraform init -backend=false -input=false >/dev/null 2>&1; then
        print_status "PASS" "terraform init successful for $dir_name"
    else
        print_status "FAIL" "terraform init failed for $dir_name"
        cd - >/dev/null
        return
    fi
    
    # Validate Terraform syntax
    print_status "INFO" "Running terraform validate..."
    if terraform validate >/dev/null 2>&1; then
        print_status "PASS" "terraform validate successful for $dir_name"
    else
        print_status "FAIL" "terraform validate failed for $dir_name"
        terraform validate
        cd - >/dev/null
        return
    fi
    
    # Check formatting
    print_status "INFO" "Checking Terraform formatting..."
    if terraform fmt -check -recursive >/dev/null 2>&1; then
        print_status "PASS" "Terraform formatting is correct for $dir_name"
    else
        print_status "WARN" "Terraform formatting issues found in $dir_name"
        terraform fmt -check -recursive
        ((VALIDATION_WARNINGS++))
    fi
    
    cd - >/dev/null
}

# Validate main Terraform directories
print_status "INFO" "Validating Terraform modules..."

# Validate modules
for module_dir in terraform/modules/*/; do
    if [ -d "$module_dir" ]; then
        validate_terraform "$module_dir"
    fi
done

# Validate environments
validate_terraform "terraform/localstack"

# Check for AWS environment (might not exist yet)
if [ -d "terraform/aws" ]; then
    validate_terraform "terraform/aws"
fi

# Check for OCI environment (might not exist yet)
if [ -d "terraform/oci" ]; then
    validate_terraform "terraform/oci"
fi

# Validate variable files
print_status "INFO" "Validating variable files..."

for var_file in $(find terraform -name "*.tfvars" -o -name "terraform.tfvars"); do
    print_status "INFO" "Checking $var_file..."
    if python3 -c "import json; exec(open('$var_file').read())" 2>/dev/null; then
        print_status "PASS" "Variable file $var_file is syntactically correct"
    else
        print_status "WARN" "Variable file $var_file may have syntax issues"
    fi
done

# Check for required files in modules
print_status "INFO" "Checking module structure..."
for module_dir in terraform/modules/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        required_files=("main.tf" "variables.tf" "outputs.tf" "README.md")
        
        for file in "${required_files[@]}"; do
            if [ -f "$module_dir$file" ]; then
                print_status "PASS" "$module_name/$file exists"
            else
                print_status "WARN" "$module_name/$file missing"
            fi
        done
    fi
done

# Summary
echo ""
echo "=================================="
echo "🏁 Terraform Validation Summary"
echo "=================================="

if [ $VALIDATION_ERRORS -eq 0 ]; then
    print_status "PASS" "All critical validations passed!"
else
    print_status "FAIL" "Found $VALIDATION_ERRORS validation error(s)"
fi

if [ $VALIDATION_WARNINGS -gt 0 ]; then
    print_status "WARN" "Found $VALIDATION_WARNINGS warning(s)"
fi

echo ""
echo "📊 Validation Results:"
echo "   Errors: $VALIDATION_ERRORS"
echo "   Warnings: $VALIDATION_WARNINGS"

# Exit with error code if there are validation errors
if [ $VALIDATION_ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
