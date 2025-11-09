#!/bin/bash

# Ansible Syntax Checking Script
# Validates all Ansible playbooks, roles, and configurations

set -e

echo "🔍 Starting Ansible Syntax Check..."
echo "==================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track validation results
SYNTAX_ERRORS=0
SYNTAX_WARNINGS=0

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
            ((SYNTAX_WARNINGS++))
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ((SYNTAX_ERRORS++))
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
            "ansible")
                echo "  macOS: brew install ansible"
                echo "  Linux: pip3 install ansible"
                ;;
            "ansible-playbook")
                echo "  Part of ansible package"
                ;;
            "ansible-inventory")
                echo "  Part of ansible package"
                ;;
        esac
        return 1
    else
        print_status "PASS" "$tool is installed"
        return 0
    fi
}

# Function to check playbook syntax
check_playbook_syntax() {
    local playbook=$1
    local inventory_file=$2
    
    print_status "INFO" "Checking syntax of $(basename "$playbook")..."
    
    # Check if file exists
    if [ ! -f "$playbook" ]; then
        print_status "WARN" "Playbook $playbook does not exist, skipping..."
        return
    fi
    
    # Run ansible-playbook syntax check
    if ansible-playbook --syntax-check -i "$inventory_file" "$playbook" 2>/dev/null; then
        print_status "PASS" "Syntax check passed for $(basename "$playbook")"
    else
        print_status "FAIL" "Syntax check failed for $(basename "$playbook")"
        echo "  Running with verbose output for details:"
        ansible-playbook --syntax-check -i "$inventory_file" "$playbook" -v
        ((SYNTAX_ERRORS++))
    fi
}

# Function to check YAML syntax
check_yaml_syntax() {
    local file=$1
    local file_type=$2
    
    print_status "INFO" "Checking YAML syntax of $(basename "$file")..."
    
    if [ ! -f "$file" ]; then
        print_status "WARN" "File $file does not exist, skipping..."
        return
    fi
    
    # Check YAML syntax using Python
    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        print_status "PASS" "YAML syntax valid for $(basename "$file")"
    else
        print_status "FAIL" "YAML syntax error in $(basename "$file")"
        python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1 | head -10
        ((SYNTAX_ERRORS++))
    fi
}

# Function to check inventory syntax
check_inventory_syntax() {
    local inventory=$1
    local inventory_type=$(basename "$inventory" | cut -d'.' -f1)
    
    print_status "INFO" "Checking inventory syntax for $(basename "$inventory")..."
    
    if [ ! -f "$inventory" ]; then
        print_status "WARN" "Inventory $inventory does not exist, skipping..."
        return
    fi
    
    case $inventory_type in
        "localstack"|"*.ini")
            # Check INI-style inventory
            if ansible-inventory -i "$inventory" --list >/dev/null 2>&1; then
                print_status "PASS" "Inventory syntax valid for $(basename "$inventory")"
            else
                print_status "FAIL" "Inventory syntax error in $(basename "$inventory")"
                ansible-inventory -i "$inventory" --list 2>&1 | head -10
                ((SYNTAX_ERRORS++))
            fi
            ;;
        "aws_ec2"|"*.yml"|"*.yaml")
            # Check YAML-style inventory
            check_yaml_syntax "$inventory" "inventory"
            # Try to parse it as inventory if credentials are available
            if AWS_ACCESS_KEY_ID="" AWS_SECRET_ACCESS_KEY="" ansible-inventory -i "$inventory" --list >/dev/null 2>&1; then
                print_status "PASS" "Dynamic inventory structure valid for $(basename "$inventory")"
            else
                print_status "INFO" "Dynamic inventory requires AWS credentials to fully validate"
            fi
            ;;
    esac
}

# Function to check role structure
check_role_structure() {
    local role_dir=$1
    local role_name=$(basename "$role_dir")
    
    print_status "INFO" "Checking structure of role '$role_name'..."
    
    if [ ! -d "$role_dir" ]; then
        print_status "WARN" "Role directory $role_dir does not exist, skipping..."
        return
    fi
    
    # Check required directories
    local required_dirs=("tasks" "handlers" "templates" "files" "defaults" "vars")
    local missing_dirs=()
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$role_dir/$dir" ]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [ ${#missing_dirs[@]} -eq 0 ]; then
        print_status "PASS" "Role '$role_name' has all required directories"
    else
        print_status "WARN" "Role '$role_name' missing directories: ${missing_dirs[*]}"
        ((SYNTAX_WARNINGS++))
    fi
    
    # Check main tasks file
    if [ -f "$role_dir/tasks/main.yml" ]; then
        check_yaml_syntax "$role_dir/tasks/main.yml" "tasks"
    else
        print_status "WARN" "Role '$role_name' missing tasks/main.yml"
        ((SYNTAX_WARNINGS++))
    fi
    
    # Check main handlers file
    if [ -f "$role_dir/handlers/main.yml" ]; then
        check_yaml_syntax "$role_dir/handlers/main.yml" "handlers"
    fi
    
    # Check defaults file
    if [ -f "$role_dir/defaults/main.yml" ]; then
        check_yaml_syntax "$role_dir/defaults/main.yml" "defaults"
    fi
    
    # Check vars file
    if [ -f "$role_dir/vars/main.yml" ]; then
        check_yaml_syntax "$role_dir/vars/main.yml" "vars"
    fi
    
    # Check all YAML files in the role
    find "$role_dir" -name "*.yml" -o -name "*.yaml" | while read -r yaml_file; do
        if [ ! -f "$yaml_file" ] || [[ "$yaml_file" =~ (main\.yml) ]]; then
            continue # Skip files already checked
        fi
        check_yaml_syntax "$yaml_file" "yaml"
    done
}

# Function to check variable files
check_variable_files() {
    local var_dir=$1
    
    print_status "INFO" "Checking variable files in $(basename "$var_dir")..."
    
    if [ ! -d "$var_dir" ]; then
        print_status "WARN" "Variable directory $var_dir does not exist, skipping..."
        return
    fi
    
    # Check all YAML variable files
    find "$var_dir" -name "*.yml" -o -name "*.yaml" | while read -r var_file; do
        check_yaml_syntax "$var_file" "variables"
    done
}

# Function to check ansible.cfg
check_ansible_config() {
    local config_file="ansible/ansible.cfg"
    
    print_status "INFO" "Checking Ansible configuration..."
    
    if [ ! -f "$config_file" ]; then
        print_status "WARN" "ansible.cfg not found"
        ((SYNTAX_WARNINGS++))
        return
    fi
    
    # Basic validation of ansible.cfg structure
    if grep -q "\[defaults\]" "$config_file"; then
        print_status "PASS" "ansible.cfg has [defaults] section"
    else
        print_status "WARN" "ansible.cfg missing [defaults] section"
        ((SYNTAX_WARNINGS++))
    fi
    
    # Check for common configuration issues
    if grep -q "host_key_checking.*=.*False" "$config_file"; then
        print_status "INFO" "host_key_checking is disabled (appropriate for development)"
    fi
    
    if grep -q "inventory.*=" "$config_file"; then
        print_status "PASS" "inventory path is configured"
    else
        print_status "INFO" "inventory path not specified in ansible.cfg"
    fi
}

# Function to check requirements.yml
check_requirements() {
    local req_file="ansible/requirements.yml"
    
    print_status "INFO" "Checking Ansible requirements..."
    
    if [ ! -f "$req_file" ]; then
        print_status "WARN" "requirements.yml not found"
        ((SYNTAX_WARNINGS++))
        return
    fi
    
    check_yaml_syntax "$req_file" "requirements"
    
    # Check for valid collections
    if grep -q "collections:" "$req_file"; then
        print_status "PASS" "Collections section found in requirements.yml"
    fi
    
    if grep -q "roles:" "$req_file"; then
        print_status "PASS" "Roles section found in requirements.yml"
    fi
}

# Main execution
echo ""
print_status "INFO" "Checking required tools..."
TOOLS_OK=true

if ! check_tool "ansible"; then
    TOOLS_OK=false
fi

if ! check_tool "ansible-playbook"; then
    TOOLS_OK=false
fi

if ! check_tool "ansible-inventory"; then
    TOOLS_OK=false
fi

if [ "$TOOLS_OK" = false ]; then
    print_status "FAIL" "Required Ansible tools are not installed"
    exit 1
fi

echo ""
print_status "INFO" "Starting comprehensive Ansible syntax validation..."

# Change to ansible directory for relative paths
cd ansible

# Check ansible.cfg
check_ansible_config

# Check inventory files
print_status "INFO" "Checking inventory files..."
for inventory_file in inventory/*; do
    if [ -f "$inventory_file" ]; then
        check_inventory_syntax "$inventory_file"
    fi
done

# Check variable files
print_status "INFO" "Checking variable files..."
check_variable_files "inventory/group_vars"

# Check playbooks
print_status "INFO" "Checking playbooks..."
for playbook in playbooks/*.yml; do
    if [ -f "$playbook" ]; then
        # Use a minimal inventory for syntax checking
        check_playbook_syntax "$playbook" "inventory/localstack.ini"
    fi
done

# Check roles
print_status "INFO" "Checking role structures..."
for role_dir in roles/*/; do
    if [ -d "$role_dir" ]; then
        check_role_structure "$role_dir"
    fi
done

# Check requirements.yml
check_requirements

# Return to original directory
cd - >/dev/null

# Summary
echo ""
echo "==================================="
echo "🏁 Ansible Syntax Check Summary"
echo "==================================="

if [ $SYNTAX_ERRORS -eq 0 ]; then
    print_status "PASS" "All critical syntax checks passed!"
else
    print_status "FAIL" "Found $SYNTAX_ERRORS syntax error(s)"
fi

if [ $SYNTAX_WARNINGS -gt 0 ]; then
    print_status "WARN" "Found $SYNTAX_WARNINGS warning(s)"
fi

echo ""
echo "📊 Syntax Check Results:"
echo "   Errors: $SYNTAX_ERRORS"
echo "   Warnings: $SYNTAX_WARNINGS"

echo ""
echo "💡 Ansible Best Practices:"
echo "   1. Use consistent YAML indentation (2 spaces)"
echo "   2. Always quote variables that start with variables: {{ \${var} }}"
echo "   3. Use proper role structure with all required directories"
echo "   4. Include meaningful names for all tasks and plays"
echo "   5. Use tags for better playbook organization"
echo "   6. Implement proper error handling and failure scenarios"
echo "   7. Use become: yes only when necessary"
echo "   8. Keep playbooks idempotent"

# Exit with error code if there are syntax errors
if [ $SYNTAX_ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
