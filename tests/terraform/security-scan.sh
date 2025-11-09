#!/bin/bash

# Terraform Security Scanning Script
# Runs tfsec and Checkov on all Terraform configurations

set -e

echo "🔒 Starting Terraform Security Scan..."
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track scan results
SECURITY_ERRORS=0
SECURITY_WARNINGS=0
SECURITY_INFO=0

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
            ((SECURITY_WARNINGS++))
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ((SECURITY_ERRORS++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ((SECURITY_INFO++))
            ;;
    esac
}

# Function to check if tool is installed
check_tool() {
    local tool=$1
    if ! command -v "$tool" &> /dev/null; then
        print_status "FAIL" "$tool is not installed. Please install it first."
        echo "Installation instructions:"
        case $tool in
            "tfsec")
                echo "  macOS: brew install tfsec"
                echo "  Linux: curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash"
                ;;
            "checkov")
                echo "  macOS: pip3 install checkov"
                echo "  Linux: pip3 install checkov"
                ;;
        esac
        return 1
    else
        print_status "PASS" "$tool is installed"
        return 0
    fi
}

# Function to run tfsec
run_tfsec() {
    local dir=$1
    local dir_name=$(basename "$dir")
    
    print_status "INFO" "Running tfsec on $dir_name..."
    
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
    
    # Run tfsec
    if tfsec --format json --tfvars-file *.tfvars 2>/dev/null > tfsec_results.json; then
        local result_count=$(jq '.results | length' tfsec_results.json 2>/dev/null || echo "0")
        if [ "$result_count" -eq 0 ]; then
            print_status "PASS" "tfsec found no security issues in $dir_name"
        else
            local high_count=$(jq '[.results[] | select(.severity == "HIGH")] | length' tfsec_results.json 2>/dev/null || echo "0")
            local medium_count=$(jq '[.results[] | select(.severity == "MEDIUM")] | length' tfsec_results.json 2>/dev/null || echo "0")
            local low_count=$(jq '[.results[] | select(.severity == "LOW")] | length' tfsec_results.json 2>/dev/null || echo "0")
            
            if [ "$high_count" -gt 0 ]; then
                print_status "FAIL" "tfsec found $high_count HIGH severity issues in $dir_name"
                ((SECURITY_ERRORS += high_count))
            fi
            
            if [ "$medium_count" -gt 0 ]; then
                print_status "WARN" "tfsec found $medium_count MEDIUM severity issues in $dir_name"
                ((SECURITY_WARNINGS += medium_count))
            fi
            
            if [ "$low_count" -gt 0 ]; then
                print_status "INFO" "tfsec found $low_count LOW severity issues in $dir_name"
                ((SECURITY_INFO += low_count))
            fi
            
            # Show summary of issues
            echo "  Summary: $high_count HIGH, $medium_count MEDIUM, $low_count LOW"
        fi
    else
        print_status "WARN" "tfsec encountered errors scanning $dir_name"
    fi
    
    # Clean up
    rm -f tfsec_results.json
    cd - >/dev/null
}

# Function to run checkov
run_checkov() {
    local dir=$1
    local dir_name=$(basename "$dir")
    
    print_status "INFO" "Running checkov on $dir_name..."
    
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
    
    # Run checkov
    if checkov --directory . --framework terraform --output json 2>/dev/null > checkov_results.json; then
        local failed_checks=$(jq '.results.failed_checks | length' checkov_results.json 2>/dev/null || echo "0")
        local passed_checks=$(jq '.results.passed_checks | length' checkov_results.json 2>/dev/null || echo "0")
        
        if [ "$failed_checks" -eq 0 ]; then
            print_status "PASS" "checkov found no failed checks in $dir_name ($passed_checks passed)"
        else
            local high_severity=$(jq '[.results.failed_checks[] | select(.severity == "HIGH")] | length' checkov_results.json 2>/dev/null || echo "0")
            local medium_severity=$(jq '[.results.failed_checks[] | select(.severity == "MEDIUM")] | length' checkov_results.json 2>/dev/null || echo "0")
            local low_severity=$(jq '[.results.failed_checks[] | select(.severity == "LOW")] | length' checkov_results.json 2>/dev/null || echo "0")
            
            if [ "$high_severity" -gt 0 ]; then
                print_status "FAIL" "checkov found $high_severity HIGH severity failures in $dir_name"
                ((SECURITY_ERRORS += high_severity))
            fi
            
            if [ "$medium_severity" -gt 0 ]; then
                print_status "WARN" "checkov found $medium_severity MEDIUM severity failures in $dir_name"
                ((SECURITY_WARNINGS += medium_severity))
            fi
            
            if [ "$low_severity" -gt 0 ]; then
                print_status "INFO" "checkov found $low_severity LOW severity failures in $dir_name"
                ((SECURITY_INFO += low_severity))
            fi
            
            echo "  Summary: $failed_checks failed ($high_severity HIGH, $medium_severity MEDIUM, $low_severity LOW), $passed_checks passed"
        fi
    else
        print_status "WARN" "checkov encountered errors scanning $dir_name"
    fi
    
    # Clean up
    rm -f checkov_results.json
    cd - >/dev/null
}

# Function to check for common security issues
check_security_best_practices() {
    print_status "INFO" "Checking security best practices..."
    
    # Check for hardcoded credentials
    print_status "INFO" "Checking for hardcoded credentials..."
    if grep -r -i "password\|secret\|key\|token" terraform/ --include="*.tf" --include="*.tfvars" | grep -v "\${\|var\." >/dev/null 2>&1; then
        print_status "WARN" "Potential hardcoded credentials found"
        echo "  Found instances of password/secret/key/token without variable interpolation"
    else
        print_status "PASS" "No obvious hardcoded credentials found"
    fi
    
    # Check for open security groups
    print_status "INFO" "Checking for overly permissive security groups..."
    if grep -r "0.0.0.0/0\|::/0" terraform/ --include="*.tf" | grep -i "cidr_block" >/dev/null 2>&1; then
        print_status "WARN" "Found CIDR blocks with 0.0.0.0/0 - review if these are intentional"
    else
        print_status "PASS" "No obvious CIDR 0.0.0.0/0 entries found"
    fi
    
    # Check for encryption settings
    print_status "INFO" "Checking for encryption settings..."
    if grep -r "encrypted.*true\|kms_key_id" terraform/ --include="*.tf" >/dev/null 2>&1; then
        print_status "PASS" "Encryption settings found"
    else
        print_status "INFO" "Consider adding encryption for sensitive resources"
    fi
    
    # Check for tagging
    print_status "INFO" "Checking for resource tagging..."
    if grep -r "tags.*=" terraform/ --include="*.tf" >/dev/null 2>&1; then
        print_status "PASS" "Resource tagging found"
    else
        print_status "INFO" "Consider adding tags for resource management"
    fi
}

# Main execution
echo ""
print_status "INFO" "Checking required tools..."
TOOLS_OK=true

if ! check_tool "tfsec"; then
    TOOLS_OK=false
fi

if ! check_tool "checkov"; then
    TOOLS_OK=false
fi

if [ "$TOOLS_OK" = false ]; then
    print_status "FAIL" "Required security tools are not installed"
    exit 1
fi

echo ""
print_status "INFO" "Running security scans on Terraform configurations..."

# Scan modules
print_status "INFO" "Scanning Terraform modules..."
for module_dir in terraform/modules/*/; do
    if [ -d "$module_dir" ]; then
        run_tfsec "$module_dir"
        run_checkov "$module_dir"
    fi
done

# Scan environments
print_status "INFO" "Scanning Terraform environments..."
run_tfsec "terraform/localstack"
run_checkov "terraform/localstack"

if [ -d "terraform/aws" ]; then
    run_tfsec "terraform/aws"
    run_checkov "terraform/aws"
fi

if [ -d "terraform/oci" ]; then
    run_tfsec "terraform/oci"
    run_checkov "terraform/oci"
fi

# Check security best practices
echo ""
check_security_best_practices

# Summary
echo ""
echo "====================================="
echo "🏁 Security Scan Summary"
echo "====================================="

if [ $SECURITY_ERRORS -eq 0 ]; then
    print_status "PASS" "No critical security issues found!"
else
    print_status "FAIL" "Found $SECURITY_ERRORS critical security issue(s)"
fi

if [ $SECURITY_WARNINGS -gt 0 ]; then
    print_status "WARN" "Found $SECURITY_WARNINGS security warning(s)"
fi

if [ $SECURITY_INFO -gt 0 ]; then
    print_status "INFO" "Found $SECURITY_INFO informational security item(s)"
fi

echo ""
echo "📊 Security Scan Results:"
echo "   Critical Issues: $SECURITY_ERRORS"
echo "   Warnings: $SECURITY_WARNINGS"
echo "   Informational: $SECURITY_INFO"

echo ""
echo "💡 Security Recommendations:"
echo "   1. Review and fix all HIGH severity issues"
echo "   2. Address MEDIUM severity issues for production"
echo "   3. Consider LOW severity issues for best practices"
echo "   4. Implement secrets management for sensitive data"
echo "   5. Enable encryption for all storage resources"
echo "   6. Use least-privilege IAM policies"
echo "   7. Implement network segmentation and firewall rules"

# Exit with error code if there are critical security issues
if [ $SECURITY_ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
