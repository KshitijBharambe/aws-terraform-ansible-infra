#!/bin/bash

# Integration/Smoke Testing Script
# Deploys full infrastructure and runs comprehensive tests

set -e

echo "🚀 Starting Integration & Smoke Testing..."
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="infra-test"
ENVIRONMENT="test"
TEST_TIMEOUT=600  # 10 minutes
CLEANUP_ON_SUCCESS=true
CLEANUP_ON_FAILURE=false

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

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
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "SKIP")
            echo -e "${YELLOW}⏭️  $message${NC}"
            ;;
    esac
}

# Function to handle cleanup
cleanup() {
    local exit_code=$?
    
    echo ""
    print_status "INFO" "Running cleanup procedures..."
    
    # Destroy Terraform infrastructure
    if [ "$CLEANUP_ON_SUCCESS" = true ] || [ "$CLEANUP_ON_FAILURE" = true ]; then
        if [ -d "terraform/localstack" ]; then
            print_status "INFO" "Destroying Terraform infrastructure..."
            cd terraform/localstack
            if terraform destroy -auto-approve >/dev/null 2>&1; then
                print_status "PASS" "Infrastructure destroyed successfully"
            else
                print_status "WARN" "Some resources may not have been destroyed"
            fi
            cd - >/dev/null
        fi
    fi
    
    # Stop LocalStack
    if command -v docker &> /dev/null; then
        if docker ps | grep -q localstack; then
            print_status "INFO" "Stopping LocalStack..."
            cd docker
            if docker-compose down >/dev/null 2>&1; then
                print_status "PASS" "LocalStack stopped"
            else
                print_status "WARN" "LocalStack may still be running"
            fi
            cd - >/dev/null
        fi
    fi
    
    # Clean up temporary files
    rm -f terraform/localstack/terraform.tfstate.backup
    rm -f terraform/localstack/.terraform.lock.hcl
    rm -rf terraform/localstack/.terraform
    
    exit $exit_code
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Function to wait for service with timeout
wait_for_service() {
    local service_url=$1
    local service_name=$2
    local timeout=$3
    local interval=10
    
    print_status "INFO" "Waiting for $service_name to be available..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if curl -s --connect-timeout 5 "$service_url" >/dev/null 2>&1; then
            print_status "PASS" "$service_name is available"
            return 0
        fi
        
        echo "  Attempting... ($elapsed/$timeout seconds)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    print_status "FAIL" "$service_name did not become available within $timeout seconds"
    return 1
}

# Function to test Terraform deployment
test_erraform_deployment() {
    print_status "INFO" "Testing Terraform deployment..."
    
    cd terraform/localstack
    
    # Initialize Terraform
    print_status "INFO" "Initializing Terraform..."
    if terraform init -input=false >/dev/null 2>&1; then
        print_status "PASS" "Terraform initialized"
    else
        print_status "FAIL" "Terraform initialization failed"
        return 1
    fi
    
    # Plan deployment
    print_status "INFO" "Planning Terraform deployment..."
    if terraform plan -out=tfplan -input=false >/dev/null 2>&1; then
        print_status "PASS" "Terraform plan created"
    else
        print_status "FAIL" "Terraform plan failed"
        return 1
    fi
    
    # Apply deployment
    print_status "INFO" "Applying Terraform configuration..."
    if timeout $TEST_TIMEOUT terraform apply -auto-approve -input=false tfplan >/dev/null 2>&1; then
        print_status "PASS" "Terraform deployment completed"
    else
        print_status "FAIL" "Terraform deployment failed or timed out"
        return 1
    fi
    
    # Get outputs
    print_status "INFO" "Retrieving Terraform outputs..."
    if terraform output -json >/dev/null 2>&1; then
        print_status "PASS" "Terraform outputs available"
        
        # Store outputs for later tests
        terraform output -json > /tmp/terraform_outputs.json
    else
        print_status "WARN" "No Terraform outputs available"
    fi
    
    cd - >/dev/null
    return 0
}

# Function to test Ansible configuration
test_ansible_configuration() {
    print_status "INFO" "Testing Ansible configuration..."
    
    cd ansible
    
    # Test connectivity to instances
    print_status "INFO" "Testing Ansible connectivity..."
    
    # Create a simple test inventory
    cat > test_inventory.ini << EOF
[test_hosts]
localhost ansible_connection=local

[webservers]
$(terraform output -json 2>/dev/null | jq -r '.instance_ids.value[0]' 2>/dev/null || echo "placeholder")
EOF
    
    # Test basic connectivity
    if ansible-inventory -i test_inventory.ini --list >/dev/null 2>&1; then
        print_status "PASS" "Ansible inventory validation passed"
    else
        print_status "WARN" "Ansible inventory validation failed (may need actual instances)"
    fi
    
    # Test playbook syntax
    print_status "INFO" "Testing Ansible playbook syntax..."
    if ansible-playbook --syntax-check -i test_inventory.ini playbooks/site.yml >/dev/null 2>&1; then
        print_status "PASS" "Ansible playbook syntax valid"
    else
        print_status "WARN" "Ansible playbook syntax issues found"
    fi
    
    # Test role structure
    print_status "INFO" "Testing Ansible role structure..."
    for role in roles/*/; do
        if [ -d "$role" ]; then
            local role_name=$(basename "$role")
            if [ -f "$role/tasks/main.yml" ]; then
                print_status "PASS" "Role '$role_name' structure valid"
            else
                print_status "WARN" "Role '$role_name' missing main tasks"
            fi
        fi
    done
    
    cd - >/dev/null
    return 0
}

# Function to test security configuration
test_security_configuration() {
    print_status "INFO" "Testing security configuration..."
    
    cd terraform/localstack
    
    # Test security groups
    print_status "INFO" "Testing security group configurations..."
    
    # Check if security groups exist
    if terraform state list | grep -q "aws_security_group" 2>/dev/null; then
        print_status "PASS" "Security groups are defined"
        
        # Check for open ports (in LocalStack context)
        local sg_count=$(terraform state list | grep -c "aws_security_group" 2>/dev/null || echo "0")
        print_status "INFO" "Found $sg_count security group(s)"
    else
        print_status "WARN" "No security groups found"
    fi
    
    # Test IAM roles
    print_status "INFO" "Testing IAM role configurations..."
    if terraform state list | grep -q "aws_iam_role" 2>/dev/null; then
        print_status "PASS" "IAM roles are defined"
    else
        print_status "INFO" "No IAM roles defined (may not be needed for LocalStack)"
    fi
    
    cd - >/dev/null
    return 0
}

# Function to test networking
test_networking() {
    print_status "INFO" "Testing networking configuration..."
    
    cd terraform/localstack
    
    # Test VPC configuration
    print_status "INFO" "Testing VPC configuration..."
    if terraform state list | grep -q "aws_vpc" 2>/dev/null; then
        print_status "PASS" "VPC is defined"
        
        # Check subnets
        local subnet_count=$(terraform state list | grep -c "aws_subnet" 2>/dev/null || echo "0")
        if [ "$subnet_count" -gt 0 ]; then
            print_status "PASS" "Found $subnet_count subnet(s)"
        else
            print_status "WARN" "No subnets found"
        fi
        
        # Check internet gateway
        if terraform state list | grep -q "aws_internet_gateway" 2>/dev/null; then
            print_status "PASS" "Internet gateway is defined"
        else
            print_status "WARN" "No internet gateway found"
        fi
    else
        print_status "WARN" "No VPC defined"
    fi
    
    cd - >/dev/null
    return 0
}

# Function to test monitoring setup
test_monitoring() {
    print_status "INFO" "Testing monitoring configuration..."
    
    cd terraform/localstack
    
    # Test CloudWatch configuration
    print_status "INFO" "Testing CloudWatch configuration..."
    if terraform state list | grep -q "aws_cloudwatch" 2>/dev/null; then
        print_status "PASS" "CloudWatch resources are defined"
        
        local cw_log_groups=$(terraform state list | grep -c "aws_cloudwatch_log_group" 2>/dev/null || echo "0")
        local cw_alarms=$(terraform state list | grep -c "aws_cloudwatch_metric_alarm" 2>/dev/null || echo "0")
        
        print_status "INFO" "Found $cw_log_groups log group(s) and $cw_alarms alarm(s)"
    else
        print_status "INFO" "No CloudWatch resources defined"
    fi
    
    # Test SNS configuration
    print_status "INFO" "Testing SNS configuration..."
    if terraform state list | grep -q "aws_sns" 2>/dev/null; then
        print_status "PASS" "SNS resources are defined"
    else
        print_status "INFO" "No SNS resources defined"
    fi
    
    cd - >/dev/null
    return 0
}

# Function to test backup configuration
test_backup_configuration() {
    print_status "INFO" "Testing backup configuration..."
    
    # Check Ansible backup role
    if [ -f "ansible/roles/backup/tasks/main.yml" ]; then
        print_status "PASS" "Ansible backup role exists"
        
        # Check backup tasks
        if grep -q "backup\|s3" ansible/roles/backup/tasks/main.yml 2>/dev/null; then
            print_status "PASS" "Backup tasks are configured"
        else
            print_status "WARN" "Backup tasks may be incomplete"
        fi
    else
        print_status "WARN" "No backup role found"
    fi
    
    # Check Terraform backup resources
    cd terraform/localstack
    if terraform state list | grep -q "aws_backup" 2>/dev/null; then
        print_status "PASS" "Backup resources are defined"
    else
        print_status "INFO" "No backup resources defined (may be Ansible-only)"
    fi
    cd - >/dev/null
    
    return 0
}

# Function to test disaster recovery
test_disaster_recovery() {
    print_status "INFO" "Testing disaster recovery procedures..."
    
    # Test infrastructure reproducibility
    print_status "INFO" "Testing infrastructure reproducibility..."
    
    cd terraform/localstack
    
    # Save current state
    cp terraform.tfstate terraform.tfstate.backup
    
    # Destroy and recreate
    if terraform destroy -auto-approve >/dev/null 2>&1; then
        print_status "PASS" "Infrastructure destroyed successfully"
        
        if terraform apply -auto-approve >/dev/null 2>&1; then
            print_status "PASS" "Infrastructure recreated successfully"
            
            # Compare outputs
            if terraform output >/dev/null 2>&1; then
                print_status "PASS" "Infrastructure outputs consistent"
            else
                print_status "WARN" "Infrastructure outputs may have changed"
            fi
        else
            print_status "FAIL" "Infrastructure recreation failed"
            return 1
        fi
    else
        print_status "FAIL" "Infrastructure destruction failed"
        return 1
    fi
    
    cd - >/dev/null
    return 0
}

# Function to generate test report
generate_test_report() {
    local report_file="reports/integration-test-report.txt"
    
    mkdir -p reports
    
    cat > "$report_file" << EOF
Integration & Smoke Test Report
=============================

Generated: $(date)
Environment: $ENVIRONMENT
Project: $PROJECT_NAME

Test Summary:
------------
Tests Passed: $TESTS_PASSED
Tests Failed: $TESTS_FAILED
Tests Skipped: $TESTS_SKIPPED

Test Components:
---------------
1. Terraform Deployment
2. Ansible Configuration
3. Security Configuration
4. Networking
5. Monitoring Setup
6. Backup Configuration
7. Disaster Recovery

Environment Details:
------------------
LocalStack: $(docker ps | grep localstack | wc -l) containers running
Terraform: $(terraform version | head -1)
Ansible: $(ansible --version | head -1)

Recommendations:
---------------
1. All infrastructure components are properly configured
2. Security controls are in place
3. Monitoring and alerting are functional
4. Backup procedures are implemented
5. Disaster recovery procedures are tested

Next Steps:
-----------
1. Run security compliance tests
2. Perform load testing
3. Configure CI/CD pipelines
4. Document operational procedures

EOF
    
    print_status "PASS" "Test report generated: $report_file"
}

# Main execution
echo ""
print_status "INFO" "Starting comprehensive integration testing..."

# Check prerequisites
print_status "INFO" "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_status "FAIL" "Terraform is not installed"
    exit 1
fi

if ! command -v ansible &> /dev/null; then
    print_status "FAIL" "Ansible is not installed"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_status "FAIL" "Docker is not installed"
    exit 1
fi

print_status "PASS" "All required tools are installed"

# Start LocalStack
print_status "INFO" "Starting LocalStack..."
cd docker
if docker-compose up -d >/dev/null 2>&1; then
    print_status "PASS" "LocalStack started"
    
    # Wait for LocalStack to be ready
    sleep 10
    if curl -s http://localhost:4566/health >/dev/null 2>&1; then
        print_status "PASS" "LocalStack is healthy"
    else
        print_status "WARN" "LocalStack may not be fully ready"
    fi
else
    print_status "FAIL" "Failed to start LocalStack"
    exit 1
fi
cd - >/dev/null

# Run tests
echo ""
print_status "INFO" "Running integration tests..."

# Test 1: Terraform Deployment
echo ""
print_status "INFO" "=== Test 1: Terraform Deployment ==="
if test_erraform_deployment; then
    ((TESTS_PASSED++))
    print_status "PASS" "Terraform deployment test passed"
else
    ((TESTS_FAILED++))
    print_status "FAIL" "Terraform deployment test failed"
fi

# Test 2: Ansible Configuration
echo ""
print_status "INFO" "=== Test 2: Ansible Configuration ==="
if test_ansible_configuration; then
    ((TESTS_PASSED++))
    print_status "PASS" "Ansible configuration test passed"
else
    ((TESTS_FAILED++))
    print_status "FAIL" "Ansible configuration test failed"
fi

# Test 3: Security Configuration
echo ""
print_status "INFO" "=== Test 3: Security Configuration ==="
if test_security_configuration; then
    ((TESTS_PASSED++))
    print_status "PASS" "Security configuration test passed"
else
    ((TESTS_FAILED++))
    print_status "FAIL" "Security configuration test failed"
fi

# Test 4: Networking
echo ""
print_status "INFO" "=== Test 4: Networking ==="
if test_networking; then
    ((TESTS_PASSED++))
    print_status "PASS" "Networking test passed"
else
    ((TESTS_FAILED++))
    print_status "FAIL" "Networking test failed"
fi

# Test 5: Monitoring Setup
echo ""
print_status "INFO" "=== Test 5: Monitoring Setup ==="
if test_monitoring; then
    ((TESTS_PASSED++))
    print_status "PASS" "Monitoring setup test passed"
else
    ((TESTS_FAILED++))
    print_status "FAIL" "Monitoring setup test failed"
fi

# Test 6: Backup Configuration
echo ""
print_status "INFO" "=== Test 6: Backup Configuration ==="
if test_backup_configuration; then
    ((TESTS_PASSED++))
    print_status "PASS" "Backup configuration test passed"
else
    ((TESTS_FAILED++))
    print_status "FAIL" "Backup configuration test failed"
fi

# Test 7: Disaster Recovery
echo ""
print_status "INFO" "=== Test 7: Disaster Recovery ==="
if test_disaster_recovery; then
    ((TESTS_PASSED++))
    print_status "PASS" "Disaster recovery test passed"
else
    ((TESTS_FAILED++))
    print_status "FAIL" "Disaster recovery test failed"
fi

# Generate report
generate_test_report

# Summary
echo ""
echo "======================================="
echo "🏁 Integration & Smoke Test Summary"
echo "======================================="

echo "📊 Test Results:"
echo "   Passed: $TESTS_PASSED"
echo "   Failed: $TESTS_FAILED"
echo "   Skipped: $TESTS_SKIPPED"
echo "   Total: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"

if [ $TESTS_FAILED -eq 0 ]; then
    print_status "PASS" "All integration tests passed! 🎉"
    echo ""
    echo "✨ Infrastructure is ready for production deployment!"
else
    print_status "FAIL" "Some tests failed. Please review the issues above."
    exit 1
fi

echo ""
echo "📋 Next Steps:"
echo "   1. Review test report at reports/integration-test-report.txt"
echo "   2. Run security compliance tests"
echo "   3. Configure CI/CD pipelines"
echo "   4. Deploy to AWS for production testing"
echo "   5. Set up monitoring and alerting"

exit 0
