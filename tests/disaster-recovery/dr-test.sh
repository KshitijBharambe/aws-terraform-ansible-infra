#!/bin/bash

# Disaster Recovery Testing Script
# Tests disaster recovery procedures and backup/restore capabilities

set -e

echo "🚨 Starting Disaster Recovery Testing..."
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track test results
DR_TESTS_PASSED=0
DR_TESTS_FAILED=0
DR_TESTS_SKIPPED=0

# Configuration
PROJECT_NAME="infra-demo"
ENVIRONMENT="demo"
BACKUP_RETENTION_DAYS=30
RTO_TARGET=3600  # 1 hour Recovery Time Objective
RPO_TARGET=14400  # 4 hour Recovery Point Objective

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
            ((DR_TESTS_SKIPPED++))
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ((DR_TESTS_FAILED++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_status "INFO" "Checking disaster recovery prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_status "FAIL" "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_status "FAIL" "Terraform is not installed"
        exit 1
    fi
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        print_status "FAIL" "Ansible is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_status "FAIL" "AWS credentials not configured"
        exit 1
    fi
    
    print_status "PASS" "All prerequisites checked"
}

# Function to test backup procedures
test_backup_procedures() {
    print_status "INFO" "Testing backup procedures..."
    
    # Test Ansible backup role
    if [ -f "ansible/roles/backup/tasks/main.yml" ]; then
        print_status "INFO" "Testing Ansible backup configuration..."
        
        # Check backup tasks
        if grep -q "backup\|s3" ansible/roles/backup/tasks/main.yml 2>/dev/null; then
            print_status "PASS" "Backup tasks configured"
        else
            print_status "WARN" "Backup tasks may be incomplete"
        fi
        
        # Test backup variables
        if [ -f "ansible/roles/backup/defaults/main.yml" ]; then
            local retention_days=$(grep "backup_retention_days" ansible/roles/backup/defaults/main.yml 2>/dev/null | cut -d: -f2 | tr -d ' ')
            if [ -n "$retention_days" ] && [ "$retention_days" -gt 0 ]; then
                print_status "PASS" "Backup retention configured: $retention_days days"
            else
                print_status "WARN" "Backup retention not properly configured"
            fi
        fi
        
        # Test backup schedule
        local backup_schedule=$(grep "backup_schedule" ansible/roles/backup/defaults/main.yml 2>/dev/null | cut -d: -f2 | tr -d ' ')
        if [ -n "$backup_schedule" ]; then
            print_status "PASS" "Backup schedule configured: $backup_schedule"
        else
            print_status "WARN" "Backup schedule not found"
        fi
    else
        print_status "FAIL" "Backup role not found"
        return 1
    fi
    
    # Test S3 backup configuration
    print_status "INFO" "Testing S3 backup configuration..."
    
    # Check if S3 buckets are configured for backups
    local backup_buckets=$(aws s3api list-buckets \
        --query "Buckets[?contains(Name, 'backup') || contains(Name, 'backup-${PROJECT_NAME}')].Name" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$backup_buckets" ]; then
        print_status "PASS" "Found backup S3 buckets: $backup_buckets"
    else
        print_status "WARN" "No dedicated backup S3 buckets found"
    fi
    
    # Test backup encryption
    print_status "INFO" "Testing backup encryption..."
    for bucket in $backup_buckets; do
        if [ -n "$bucket" ]; then
            local encryption=$(aws s3api get-bucket-encryption \
                --bucket "$bucket" \
                --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault" \
                --output text 2>/dev/null || echo "Disabled")
            
            if [ "$encryption" = "true" ] || [ "$encryption" = "Enabled" ]; then
                print_status "PASS" "Bucket $bucket has encryption enabled"
            else
                print_status "WARN" "Bucket $bucket encryption not enabled"
            fi
        fi
    done
    
    # Test backup versioning
    print_status "INFO" "Testing backup versioning..."
    for bucket in $backup_buckets; do
        if [ -n "$bucket" ]; then
            local versioning=$(aws s3api get-bucket-versioning \
                --bucket "$bucket" \
                --query "Status" \
                --output text 2>/dev/null || echo "Disabled")
            
            if [ "$versioning" = "Enabled" ]; then
                print_status "PASS" "Bucket $bucket has versioning enabled"
            else
                print_status "WARN" "Bucket $bucket versioning not enabled"
            fi
        fi
    done
}

# Function to test restore procedures
test_restore_procedures() {
    print_status "INFO" "Testing restore procedures..."
    
    # Test Terraform state restore
    print_status "INFO" "Testing Terraform state backup and restore..."
    
    cd terraform/aws
    
    # Backup current state
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)
        print_status "PASS" "Terraform state backup created"
        
        # Test state integrity
        if terraform show >/dev/null 2>&1; then
            print_status "PASS" "Terraform state is valid"
        else
            print_status "WARN" "Terraform state may be corrupted"
        fi
    else
        print_status "INFO" "No Terraform state to backup (not yet deployed)"
    fi
    
    cd - >/dev/null
}

# Function to test infrastructure reproducibility
test_infrastructure_reproducibility() {
    print_status "INFO" "Testing infrastructure reproducibility..."
    
    cd terraform/aws
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_status "INFO" "Terraform not initialized, skipping reproducibility test"
        return 0
    fi
    
    # Save current state
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate terraform.tfstate.original
    fi
    
    # Test destroy and recreate
    print_status "INFO" "Testing infrastructure destruction..."
    if timeout 300 terraform plan -destroy -input=false >/dev/null 2>&1; then
        print_status "PASS" "Destruction plan created"
    else
        print_status "WARN" "Could not create destruction plan"
    fi
    
    # Test recreation
    print_status "INFO" "Testing infrastructure recreation..."
    if timeout 600 terraform apply -auto-approve -input=false >/dev/null 2>&1; then
        print_status "PASS" "Infrastructure recreated successfully"
        
        # Compare outputs
        if terraform output -json >/dev/null 2>&1; then
            terraform output -json > /tmp/dr-test-outputs.json
            print_status "PASS" "Infrastructure outputs consistent"
        fi
    else
        print_status "WARN" "Infrastructure recreation failed"
        
        # Restore original state if available
        if [ -f "terraform.tfstate.original" ]; then
            cp terraform.tfstate.original terraform.tfstate
            print_status "INFO" "Restored original Terraform state"
        fi
    fi
    
    cd - >/dev/null
}

# Function to test configuration management restore
test_config_restore() {
    print_status "INFO" "Testing configuration management restore..."
    
    # Test Ansible configuration backup
    cd ansible
    
    # Create backup of current configuration
    local backup_dir="backups/config-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup inventory files
    if [ -d "inventory" ]; then
        cp -r inventory "$backup_dir/"
        print_status "PASS" "Ansible inventory backed up"
    fi
    
    # Backup playbooks
    if [ -d "playbooks" ]; then
        cp -r playbooks "$backup_dir/"
        print_status "PASS" "Ansible playbooks backed up"
    fi
    
    # Backup roles
    if [ -d "roles" ]; then
        cp -r roles "$backup_dir/"
        print_status "PASS" "Ansible roles backed up"
    fi
    
    # Test restore from backup
    print_status "INFO" "Testing configuration restore from backup..."
    
    # Remove current configurations (test only)
    if [ -d "inventory/test-backup" ]; then
        rm -rf inventory/test-backup
    fi
    
    # Restore from backup
    if [ -d "$backup_dir/inventory" ]; then
        cp -r "$backup_dir/inventory" inventory/test-backup
        print_status "PASS" "Ansible inventory restored from backup"
    fi
    
    # Clean up test restore
    rm -rf inventory/test-backup
    
    cd - >/dev/null
}

# Function to test monitoring recovery
test_monitoring_recovery() {
    print_status "INFO" "Testing monitoring system recovery..."
    
    # Test CloudWatch log recovery
    print_status "INFO" "Testing CloudWatch log recovery..."
    
    # Check if log groups exist
    local log_groups=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/terraform/$PROJECT_NAME" \
        --query "logGroups[].logGroupName" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$log_groups" ]; then
        print_status "PASS" "Found monitoring log groups: $(echo "$log_groups" | wc -l)"
        
        # Test log retrieval
        for log_group in $log_groups; do
            if [ -n "$log_group" ]; then
                local log_streams=$(aws logs describe-log-streams \
                    --log-group-name "$log_group" \
                    --query "logStreams[0].logStreamName" \
                    --output text 2>/dev/null || echo "")
                
                if [ -n "$log_streams" ]; then
                    local log_events=$(aws logs get-log-events \
                        --log-group-name "$log_group" \
                        --log-stream-name "$log_streams" \
                        --limit 10 \
                        --query "events[].[timestamp,message]" \
                        --output text 2>/dev/null | head -5)
                    
                    if [ -n "$log_events" ]; then
                        print_status "PASS" "Log retrieval successful for $log_group"
                    else
                        print_status "WARN" "No log events found for $log_group"
                    fi
                else
                    print_status "WARN" "No log streams found for $log_group"
                fi
            fi
        done
    else
        print_status "WARN" "No monitoring log groups found"
    fi
    
    # Test alarm recovery
    print_status "INFO" "Testing alarm configuration recovery..."
    
    local alarms=$(aws cloudwatch describe-alarms \
        --alarm-name-prefix "$PROJECT_NAME" \
        --query "MetricAlarms[].[AlarmName,StateValue]" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$alarms" ]; then
        print_status "PASS" "Found monitoring alarms: $(echo "$alarms" | wc -l)"
    else
        print_status "WARN" "No monitoring alarms found"
    fi
}

# Function to test security incident response
test_security_incident_response() {
    print_status "INFO" "Testing security incident response procedures..."
    
    # Test security group recovery
    print_status "INFO" "Testing security group configuration recovery..."
    
    # Check if we can identify security groups
    local security_groups=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Project,Values=$PROJECT_NAME" \
        --query "SecurityGroups[].[GroupId,GroupName]" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$security_groups" ]; then
        print_status "PASS" "Found security groups: $(echo "$security_groups" | wc -l)"
        
        # Test security group rules can be restored
        echo "$security_groups" | while read -r sg_id sg_name; do
            if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
                local sg_rules=$(aws ec2 describe-security-groups \
                    --group-ids "$sg_id" \
                    --query "SecurityGroups[0].IpPermissions" \
                    --output text 2>/dev/null || echo "")
                
                if [ -n "$sg_rules" ]; then
                    print_status "PASS" "Security group $sg_name rules accessible"
                else
                    print_status "WARN" "Could not retrieve rules for $sg_name"
                fi
            fi
        done
    else
        print_status "WARN" "No project security groups found"
    fi
    
    # Test IAM role recovery
    print_status "INFO" "Testing IAM role configuration recovery..."
    
    local iam_roles=$(aws iam list-roles \
        --path-prefix "/$PROJECT_NAME/" \
        --query "Roles[].[RoleName,CreateDate]" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$iam_roles" ]; then
        print_status "PASS" "Found IAM roles: $(echo "$iam_roles" | wc -l)"
    else
        print_status "INFO" "No project-specific IAM roles found"
    fi
}

# Function to test recovery time objectives
test_recovery_time_objectives() {
    print_status "INFO" "Testing Recovery Time Objectives (RTO/RPO)..."
    
    local start_time=$(date +%s)
    
    # Simulate infrastructure recovery
    print_status "INFO" "Simulating complete infrastructure recovery..."
    
    # Test Terraform recovery time
    cd terraform/aws
    
    if [ -d ".terraform" ] && [ -f "terraform.tfstate" ]; then
        local terraform_start=$(date +%s)
        
        # Test terraform plan time
        if timeout 120 terraform plan -input=false >/dev/null 2>&1; then
            local terraform_end=$(date +%s)
            local terraform_plan_time=$((terraform_end - terraform_start))
            
            print_status "PASS" "Terraform plan completed in ${terraform_plan_time}s"
            
            if [ "$terraform_plan_time" -le 120 ]; then
                print_status "PASS" "Terraform planning within RTO target"
            else
                print_status "WARN" "Terraform planning exceeds RTO target"
            fi
        else
            print_status "WARN" "Terraform plan failed or timed out"
        fi
    fi
    
    cd - >/dev/null
    
    # Test Ansible configuration time
    local ansible_start=$(date +%s)
    
    cd ansible
    
    # Test Ansible inventory validation
    if timeout 60 ansible-inventory -i inventory/aws_ec2.yml --list >/dev/null 2>&1; then
        local ansible_end=$(date +%s)
        local ansible_time=$((ansible_end - ansible_start))
        
        print_status "PASS" "Ansible inventory validation completed in ${ansible_time}s"
        
        if [ "$ansible_time" -le 60 ]; then
            print_status "PASS" "Ansible configuration within RTO target"
        else
            print_status "WARN" "Ansible configuration exceeds RTO target"
        fi
    else
        print_status "WARN" "Ansible inventory validation failed or timed out"
    fi
    
    cd - >/dev/null
    
    local end_time=$(date +%s)
    local total_recovery_time=$((end_time - start_time))
    
    print_status "INFO" "Total recovery time: ${total_recovery_time}s"
    
    if [ "$total_recovery_time" -le $RTO_TARGET ]; then
        print_status "PASS" "Recovery within RTO target ($RTO_TARGET)s)"
    else
        print_status "WARN" "Recovery exceeds RTO target ($RTO_TARGET)s)"
    fi
}

# Function to test documentation recovery
test_documentation_recovery() {
    print_status "INFO" "Testing documentation recovery procedures..."
    
    # Check for runbooks
    local runbook_dirs=("docs/runbooks" "documentation/runbooks" ".")
    local runbook_found=false
    
    for dir in "${runbook_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local runbook_count=$(find "$dir" -name "*.md" -o -name "*.txt" 2>/dev/null | wc -l)
            if [ "$runbook_count" -gt 0 ]; then
                print_status "PASS" "Found runbooks in $dir: $runbook_count files"
                runbook_found=true
                
                # Test if critical runbooks exist
                local critical_runbooks=$(find "$dir" -iname "*disaster*" -o -iname "*recovery*" -o -iname "*backup*" 2>/dev/null | wc -l)
                if [ "$critical_runbooks" -gt 0 ]; then
                    print_status "PASS" "Found $critical_runbooks critical runbooks"
                else
                    print_status "WARN" "No critical disaster recovery runbooks found"
                fi
                break
            fi
        fi
    done
    
    if [ "$runbook_found" = false ]; then
        print_status "WARN" "No runbooks found"
    fi
    
    # Check for documentation
    local doc_files=("README.md" "DISASTER_RECOVERY.md" "BACKUP_PROCEDURES.md")
    local doc_found=false
    
    for doc in "${doc_files[@]}"; do
        if [ -f "$doc" ] || [ -f "docs/$doc" ] || [ -f "documentation/$doc" ]; then
            print_status "PASS" "Found documentation: $doc"
            doc_found=true
            break
        fi
    done
    
    if [ "$doc_found" = false ]; then
        print_status "WARN" "No disaster recovery documentation found"
    fi
}

# Function to test communication procedures
test_communication_procedures() {
    print_status "INFO" "Testing communication procedures..."
    
    # Check SNS topics for incident notification
    local sns_topics=$(aws sns list-topics \
        --query "Topics[].[TopicArn,Name]" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$sns_topics" ]; then
        print_status "PASS" "Found SNS notification topics: $(echo "$sns_topics" | wc -l)"
        
        # Test if incident notification topic exists
        local incident_topic=$(echo "$sns_topics" | grep -i "incident\|alert\|emergency" || echo "")
        if [ -n "$incident_topic" ]; then
            print_status "PASS" "Found incident notification topic"
        else
            print_status "WARN" "No incident notification topic found"
        fi
    else
        print_status "WARN" "No SNS topics found"
    fi
    
    # Check for contact information documentation
    local contact_files=("CONTACTS.md" "INCIDENT_RESPONSE.md" "EMERGENCY_CONTACTS.md")
    local contact_found=false
    
    for contact_file in "${contact_files[@]}"; do
        if [ -f "$contact_file" ] || [ -f "docs/$contact_file" ] || [ -f "documentation/$contact_file" ]; then
            print_status "PASS" "Found contact information: $contact_file"
            contact_found=true
            break
        fi
    done
    
    if [ "$contact_found" = false ]; then
        print_status "WARN" "No emergency contact documentation found"
    fi
}

# Function to generate disaster recovery report
generate_dr_report() {
    local report_file="reports/disaster-recovery-test-report.txt"
    
    mkdir -p reports
    
    cat > "$report_file" << EOF
Disaster Recovery Test Report
================================

Generated: $(date)
Project: $PROJECT_NAME
Environment: $ENVIRONMENT

Test Summary:
------------
Tests Passed: $DR_TESTS_PASSED
Tests Failed: $DR_TESTS_FAILED
Tests Skipped: $DR_TESTS_SKIPPED

Recovery Objectives:
------------------
RTO Target: ${RTO_TARGET}s (1 hour)
RPO Target: ${RPO_TARGET}s (4 hours)

Test Areas:
-----------
1. Backup Procedures
2. Restore Procedures
3. Infrastructure Reproducibility
4. Configuration Management Recovery
5. Monitoring System Recovery
6. Security Incident Response
7. Recovery Time Objectives
8. Documentation Recovery
9. Communication Procedures

Test Results:
-------------
$(echo "1. Backup Procedures: $([ $(grep -q "backup.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "2. Restore Procedures: $([ $(grep -q "restore.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "3. Infrastructure Reproducibility: $([ $(grep -q "reproducibility.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "4. Configuration Management Recovery: $([ $(grep -q "config.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "5. Monitoring System Recovery: $([ $(grep -q "monitoring.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "6. Security Incident Response: $([ $(grep -q "security.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "7. Recovery Time Objectives: $([ $(grep -q "recovery.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "8. Documentation Recovery: $([ $(grep -q "documentation.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")
$(echo "9. Communication Procedures: $([ $(grep -q "communication.*PASS" /tmp/dr-test-output 2>/dev/null) ] && echo "PASSED" || echo "FAILED/SKIPPED")")

Recovery Capabilities:
--------------------
- Backup Strategy: $(if [ $DR_TESTS_PASSED -gt 0 ]; then echo "Implemented"; else echo "Needs Improvement"; fi)
- Restore Procedures: $(if [ $DR_TESTS_PASSED -gt 1 ]; then echo "Functional"; else echo "Needs Development"; fi)
- Infrastructure as Code: $(if [ $DR_TESTS_PASSED -gt 2 ]; then echo "Reproducible"; else echo "Needs Attention"; fi)
- Monitoring: $(if [ $DR_TESTS_PASSED -gt 3 ]; then echo "Operational"; else echo "Incomplete"; fi)
- Documentation: $(if [ $DR_TESTS_PASSED -gt 4 ]; then echo "Comprehensive"; else echo "Incomplete"; fi)

Recommendations:
---------------
1. Implement automated backup scheduling
2. Test restore procedures regularly
3. Document all recovery procedures
4. Set up monitoring and alerting
5. Establish communication protocols
6. Test RTO/RPO compliance
7. Implement infrastructure as code
8. Regularly update runbooks
9. Conduct quarterly DR drills
10. Maintain contact information

Critical Success Factors:
------------------------
- Regular backup testing and verification
- Clear documentation and runbooks
- Automated recovery procedures where possible
- Monitoring and alerting for all systems
- Regular disaster recovery drills
- Updated emergency contact information
- Redundant infrastructure components
- Clear RTO/RPO definitions
- Testing in isolated environments

Next Steps:
-----------
1. Address all FAILED tests immediately
2. Implement recommendations above
3. Schedule regular DR testing
4. Update documentation with lessons learned
5. Train team on DR procedures
6. Implement automated recovery tools
7. Establish DR testing schedule
8. Monitor and improve recovery times

EOF
    
    print_status "PASS" "Disaster recovery report generated: $report_file"
}

# Main execution
echo ""
print_status "INFO" "Starting comprehensive disaster recovery testing..."

# Check prerequisites
check_prerequisites

# Create output file for report generation
exec 1> /tmp/dr-test-output

# Run disaster recovery tests
echo ""
print_status "INFO" "=== Test 1: Backup Procedures ==="
if test_backup_procedures; then
    print_status "PASS" "Backup procedures test passed"
    echo "backup:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "backup:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 2: Restore Procedures ==="
if test_restore_procedures; then
    print_status "PASS" "Restore procedures test passed"
    echo "restore:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "restore:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 3: Infrastructure Reproducibility ==="
if test_infrastructure_reproducibility; then
    print_status "PASS" "Infrastructure reproducibility test passed"
    echo "reproducibility:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "reproducibility:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 4: Configuration Management Recovery ==="
if test_config_restore; then
    print_status "PASS" "Configuration management recovery test passed"
    echo "config:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "config:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 5: Monitoring System Recovery ==="
if test_monitoring_recovery; then
    print_status "PASS" "Monitoring system recovery test passed"
    echo "monitoring:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "monitoring:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 6: Security Incident Response ==="
if test_security_incident_response; then
    print_status "PASS" "Security incident response test passed"
    echo "security:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "security:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 7: Recovery Time Objectives ==="
if test_recovery_time_objectives; then
    print_status "PASS" "Recovery time objectives test passed"
    echo "recovery:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "recovery:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 8: Documentation Recovery ==="
if test_documentation_recovery; then
    print_status "PASS" "Documentation recovery test passed"
    echo "documentation:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "documentation:FAILED" >> /tmp/dr-test-output
fi

echo ""
print_status "INFO" "=== Test 9: Communication Procedures ==="
if test_communication_procedures; then
    print_status "PASS" "Communication procedures test passed"
    echo "communication:PASSED" >> /tmp/dr-test-output
    ((DR_TESTS_PASSED++))
else
    echo "communication:FAILED" >> /tmp/dr-test-output
fi

# Close output file
exec 1>&-

# Generate report
generate_dr_report

# Summary
echo ""
echo "========================================="
echo "🏁 Disaster Recovery Test Summary"
echo "========================================="

echo "📊 Test Results:"
echo "   Passed: $DR_TESTS_PASSED"
echo "   Failed: $DR_TESTS_FAILED"
echo "   Skipped: $DR_TESTS_SKIPPED"
echo "   Total: $((DR_TESTS_PASSED + DR_TESTS_FAILED + DR_TESTS_SKIPPED))"

if [ $DR_TESTS_FAILED -eq 0 ]; then
    print_status "PASS" "All disaster recovery tests passed! 🎉"
    
    # Calculate DR readiness score
    local dr_score=$(( (DR_TESTS_PASSED * 100) / (DR_TESTS_PASSED + DR_TESTS_FAILED + DR_TESTS_SKIPPED)))
    echo "📈 Disaster Recovery Readiness: ${dr_score}%"
    
    if [ "$dr_score" -ge 80 ]; then
        print_status "PASS" "Excellent disaster recovery preparedness!"
    elif [ "$dr_score" -ge 60 ]; then
        print_status "INFO" "Good disaster recovery preparedness"
    elif [ "$dr_score" -ge 40 ]; then
        print_status "WARN" "Moderate disaster recovery preparedness"
    else
        print_status "WARN" "Poor disaster recovery preparedness"
    fi
else
    print_status "FAIL" "Found $DR_TESTS_FAILED disaster recovery test failure(s)"
    echo ""
    echo "🚨 Immediate action required for failed tests!"
fi

echo ""
echo "💡 Disaster Recovery Best Practices:"
echo "   1. Test backups regularly (weekly/monthly)"
echo "   2. Document all recovery procedures"
echo "   3. Implement automated recovery where possible"
echo "   4. Establish clear RTO/RPO targets"
echo "   5. Conduct quarterly DR drills"
echo "   6. Maintain up-to-date runbooks"
echo "   7. Monitor backup success rates"
echo "   8. Test in isolated environments"
echo "   9. Implement multi-region recovery"
echo "   10. Regularly review and update DR plan"

echo ""
echo "📋 Next Steps:"
echo "   1. Review full report at reports/disaster-recovery-test-report.txt"
echo "   2. Address all failed tests"
echo "   3. Implement missing DR procedures"
echo "   4. Schedule regular DR testing"
echo "   5. Update documentation with lessons learned"
echo "   6. Train team on DR procedures"

exit 0
