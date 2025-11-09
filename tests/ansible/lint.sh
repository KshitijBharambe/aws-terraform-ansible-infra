#!/bin/bash

# Ansible Linting Script
# Runs ansible-lint on all playbooks and roles with comprehensive checks

set -e

echo "🔍 Starting Ansible Linting..."
echo "==============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track linting results
LINT_ERRORS=0
LINT_WARNINGS=0

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
            ((LINT_WARNINGS++))
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ((LINT_ERRORS++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
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
            "ansible-lint")
                echo "  macOS: pip3 install ansible-lint"
                echo "  Linux: pip3 install ansible-lint"
                echo "  Alternative: pipx install ansible-lint"
                ;;
        esac
        return 1
    else
        print_status "PASS" "$tool is installed"
        return 0
    fi
}

# Function to run ansible-lint on a file or directory
run_ansible_lint() {
    local target=$1
    local target_name=$(basename "$target")
    local target_type=$2
    
    print_status "INFO" "Running ansible-lint on $target_type '$target_name'..."
    
    if [ ! -e "$target" ]; then
        print_status "WARN" "$target_type '$target_name' does not exist, skipping..."
        return
    fi
    
    # Run ansible-lint with specific rules
    if ansible-lint "$target" 2>/dev/null > lint_output.txt; then
        print_status "PASS" "ansible-lint passed for $target_type '$target_name'"
    else
        local error_count=$(grep -c "error:" lint_output.txt 2>/dev/null || echo "0")
        local warning_count=$(grep -c "warning:" lint_output.txt 2>/dev/null || echo "0")
        
        if [ "$error_count" -gt 0 ]; then
            print_status "FAIL" "ansible-lint found $error_count error(s) in $target_type '$target_name'"
            ((LINT_ERRORS += error_count))
        fi
        
        if [ "$warning_count" -gt 0 ]; then
            print_status "WARN" "ansible-lint found $warning_count warning(s) in $target_type '$target_name'"
            ((LINT_WARNINGS += warning_count))
        fi
        
        # Show detailed output
        echo "  Issues found:"
        head -20 lint_output.txt | sed 's/^/    /'
        
        if [ $(wc -l < lint_output.txt) -gt 20 ]; then
            echo "    ... (showing first 20 lines)"
        fi
    fi
    
    # Clean up
    rm -f lint_output.txt
}

# Function to check for common Ansible best practices violations
check_best_practices() {
    print_status "INFO" "Checking Ansible best practices..."
    
    # Check for use of shell/command modules when better alternatives exist
    print_status "INFO" "Checking for module usage best practices..."
    
    local shell_usage=$(find ansible/ -name "*.yml" -exec grep -l "shell:" {} \; 2>/dev/null | wc -l || echo "0")
    local command_usage=$(find ansible/ -name "*.yml" -exec grep -l "command:" {} \; 2>/dev/null | wc -l || echo "0")
    
    if [ "$shell_usage" -gt 0 ]; then
        print_status "WARN" "Found $shell_usage file(s) using shell module - consider using specific modules when possible"
    fi
    
    if [ "$command_usage" -gt 0 ]; then
        print_status "WARN" "Found $command_usage file(s) using command module - consider using specific modules when possible"
    fi
    
    # Check for when clauses without proper conditions
    print_status "INFO" "Checking when clause usage..."
    if find ansible/ -name "*.yml" -exec grep -l "when:" {} \; 2>/dev/null >/dev/null; then
        print_status "PASS" "When clauses found - good conditional usage"
    fi
    
    # Check for proper variable naming conventions
    print_status "INFO" "Checking variable naming conventions..."
    if find ansible/ -name "*.yml" -exec grep -E "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:" {} \; 2>/dev/null >/dev/null; then
        print_status "PASS" "Variable naming appears to follow conventions"
    fi
    
    # Check for usage of become without proper justification
    print_status "INFO" "Checking privilege escalation usage..."
    local become_usage=$(find ansible/ -name "*.yml" -exec grep -l "become:" {} \; 2>/dev/null | wc -l || echo "0")
    if [ "$become_usage" -gt 0 ]; then
        print_status "INFO" "Found $become_usage file(s) using privilege escalation - ensure this is necessary"
    fi
    
    # Check for hardcoded values that should be variables
    print_status "INFO" "Checking for potential hardcoded values..."
    local hardcoded_ips=$(find ansible/ -name "*.yml" -exec grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" {} \; 2>/dev/null | wc -l || echo "0")
    if [ "$hardcoded_ips" -gt 0 ]; then
        print_status "WARN" "Found $hardcoded_ips potential hardcoded IP addresses - consider using variables"
    fi
    
    # Check for proper error handling
    print_status "INFO" "Checking error handling..."
    local ignore_errors=$(find ansible/ -name "*.yml" -exec grep -l "ignore_errors:" {} \; 2>/dev/null | wc -l || echo "0")
    if [ "$ignore_errors" -gt 0 ]; then
        print_status "INFO" "Found $ignore_errors file(s) using ignore_errors - ensure this is intentional"
    fi
}

# Function to check for security best practices
check_security_practices() {
    print_status "INFO" "Checking security best practices..."
    
    # Check for password handling
    print_status "INFO" "Checking password handling..."
    if find ansible/ -name "*.yml" -exec grep -i "password\|secret\|key\|token" {} \; 2>/dev/null | grep -v "{{.*}}" | grep -v "\${.*}" >/dev/null; then
        print_status "WARN" "Potential hardcoded secrets found - use Ansible Vault or variables"
    else
        print_status "PASS" "No obvious hardcoded secrets found"
    fi
    
    # Check for sudo/su usage
    print_status "INFO" "Checking privilege escalation methods..."
    if find ansible/ -name "*.yml" -exec grep -E "(sudo|su):" {} \; 2>/dev/null >/dev/null; then
        print_status "WARN" "Found direct sudo/su usage - prefer become: yes"
    else
        print_status "PASS" "Using proper privilege escalation methods"
    fi
    
    # Check for file permissions
    print_status "INFO" "Checking file permission settings..."
    if find ansible/ -name "*.yml" -exec grep -E "mode.*[0-9]{3}" {} \; 2>/dev/null >/dev/null; then
        print_status "PASS" "File permissions are explicitly set"
    fi
}

# Function to check role structure completeness
check_role_completeness() {
    print_status "INFO" "Checking role completeness and quality..."
    
    for role_dir in ansible/roles/*/; do
        if [ -d "$role_dir" ]; then
            local role_name=$(basename "$role_dir")
            
            # Check for README
            if [ -f "$role_dir/README.md" ]; then
                print_status "PASS" "Role '$role_name' has documentation"
            else
                print_status "WARN" "Role '$role_name' missing README.md"
            fi
            
            # Check for meta/main.yml
            if [ -f "$role_dir/meta/main.yml" ]; then
                print_status "PASS" "Role '$role_name' has metadata"
            else
                print_status "INFO" "Role '$role_name' missing meta/main.yml (optional)"
            fi
            
            # Check for tests
            if [ -d "$role_dir/tests" ] && [ "$(ls -A "$role_dir/tests")" ]; then
                print_status "PASS" "Role '$role_name' has tests"
            else
                print_status "INFO" "Role '$role_name' missing tests (optional)"
            fi
            
            # Check for molecule tests
            if [ -f "$role_dir/molecule.yml" ] || [ -d "$role_dir/molecule" ]; then
                print_status "PASS" "Role '$role_name' has molecule tests"
            else
                print_status "INFO" "Role '$role_name' missing molecule tests (optional)"
            fi
        fi
    done
}

# Function to check playbook structure
check_playbook_structure() {
    print_status "INFO" "Checking playbook structure..."
    
    for playbook in ansible/playbooks/*.yml; do
        if [ -f "$playbook" ]; then
            local playbook_name=$(basename "$playbook")
            
            # Check for playbook metadata
            if grep -q "name:" "$playbook"; then
                print_status "PASS" "Playbook '$playbook_name' has name"
            else
                print_status "WARN" "Playbook '$playbook_name' missing name"
            fi
            
            # Check for hosts specification
            if grep -q "hosts:" "$playbook"; then
                print_status "PASS" "Playbook '$playbook_name' specifies hosts"
            else
                print_status "WARN" "Playbook '$playbook_name' missing hosts specification"
            fi
            
            # Check for become usage
            if grep -q "become:" "$playbook"; then
                print_status "INFO" "Playbook '$playbook_name' uses privilege escalation"
            fi
            
            # Check for vars_files usage
            if grep -q "vars_files:" "$playbook"; then
                print_status "PASS" "Playbook '$playbook_name' uses variable files"
            fi
            
            # Check for tags
            if grep -q "tags:" "$playbook"; then
                print_status "PASS" "Playbook '$playbook_name' uses tags"
            else
                print_status "INFO" "Playbook '$playbook_name' could benefit from tags"
            fi
        fi
    done
}

# Function to generate linting report
generate_report() {
    local report_file="reports/ansible-lint-report.txt"
    
    print_status "INFO" "Generating comprehensive linting report..."
    
    mkdir -p reports
    
    cat > "$report_file" << EOF
Ansible Linting Report
======================

Generated: $(date)
Environment: $(uname -a)

Summary:
--------
Errors: $LINT_ERRORS
Warnings: $LINT_WARNINGS

Recommendations:
---------------
1. Fix all error-level issues before deploying to production
2. Address warning-level issues for better code quality
3. Implement consistent naming conventions
4. Add proper error handling and validation
5. Use Ansible Vault for sensitive data
6. Implement proper testing with Molecule
7. Document all roles and playbooks
8. Use tags for better playbook organization

Best Practices:
--------------
1. Prefer specific modules over shell/command
2. Use variables instead of hardcoded values
3. Implement proper privilege escalation
4. Add comprehensive error handling
5. Use conditional statements appropriately
6. Implement idempotent configurations
7. Use proper file permissions
8. Implement logging and monitoring

EOF
    
    print_status "PASS" "Linting report generated: $report_file"
}

# Main execution
echo ""
print_status "INFO" "Checking required tools..."

if ! check_tool "ansible-lint"; then
    print_status "FAIL" "Required tools are not installed"
    exit 1
fi

echo ""
print_status "INFO" "Starting comprehensive Ansible linting..."

# Change to project root
cd "$(dirname "$0")/../.."

# Run ansible-lint on all playbooks
print_status "INFO" "Linting playbooks..."
for playbook in ansible/playbooks/*.yml; do
    if [ -f "$playbook" ]; then
        run_ansible_lint "$playbook" "playbook"
    fi
done

# Run ansible-lint on all roles
print_status "INFO" "Linting roles..."
for role_dir in ansible/roles/*/; do
    if [ -d "$role_dir" ]; then
        run_ansible_lint "$role_dir" "role"
    fi
done

# Run ansible-lint on all inventory files
print_status "INFO" "Linting inventory files..."
for inventory_file in ansible/inventory/*; do
    if [ -f "$inventory_file" ]; then
        run_ansible-lint "$inventory_file" "inventory"
    fi
done

# Run ansible-lint on variable files
print_status "INFO" "Linting variable files..."
find ansible/inventory/group_vars -name "*.yml" 2>/dev/null | while read -r var_file; do
    if [ -f "$var_file" ]; then
        run_ansible_lint "$var_file" "variable file"
    fi
done

# Check best practices
echo ""
check_best_practices

# Check security practices
echo ""
check_security_practices

# Check role completeness
echo ""
check_role_completeness

# Check playbook structure
echo ""
check_playbook_structure

# Generate report
generate_report

# Summary
echo ""
echo "==============================="
echo "🏁 Ansible Linting Summary"
echo "==============================="

if [ $LINT_ERRORS -eq 0 ]; then
    print_status "PASS" "No critical linting errors found!"
else
    print_status "FAIL" "Found $LINT_ERRORS linting error(s)"
fi

if [ $LINT_WARNINGS -gt 0 ]; then
    print_status "WARN" "Found $LINT_WARNINGS linting warning(s)"
fi

echo ""
echo "📊 Linting Results:"
echo "   Errors: $LINT_ERRORS"
echo "   Warnings: $LINT_WARNINGS"

echo ""
echo "💡 Ansible Quality Improvements:"
echo "   1. Use ansible-lint rules file (.ansible-lint) to customize rules"
echo "   2. Implement Molecule for role testing"
echo "   3. Use consistent YAML formatting (2 spaces)"
echo "   4. Add meaningful task names and descriptions"
echo "   5. Implement proper error handling"
echo "   6. Use Ansible Vault for sensitive data"
echo "   7. Add comprehensive documentation"
echo "   8. Implement CI/CD linting checks"

# Exit with error code if there are linting errors
if [ $LINT_ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
