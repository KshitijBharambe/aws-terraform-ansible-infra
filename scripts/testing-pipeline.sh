#!/bin/bash

# =============================================================================
# Automated Testing Pipeline
# =============================================================================
# This script runs the complete automated testing pipeline for the
# infrastructure automation project, including local development,
# CI/CD validation, and multi-cloud testing.
# =============================================================================

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/reports"
TEST_RESULTS_FILE="$REPORTS_DIR/test-results.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create necessary directories
mkdir -p "$LOG_DIR" "$REPORTS_DIR"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        *)       echo -e "${NC}[LOG]${NC}   $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/testing-pipeline-$TIMESTAMP.log"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Progress indicator
progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${PURPLE}[PROGRESS]${NC} %s: [" "$description"
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%%" $percent
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# Initialize test results JSON
init_test_results() {
    cat > "$TEST_RESULTS_FILE" << EOF
{
  "pipeline_run": {
    "timestamp": "$(date -Iseconds)",
    "pipeline_version": "1.0.0",
    "environment": "${ENVIRONMENT:-local}",
    "total_tests": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0
  },
  "test_suites": []
}
EOF
}

# Update test results
update_test_results() {
    local suite_name=$1
    local test_name=$2
    local status=$3
    local details=${4:-""}
    local duration=${5:-0}
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg suite "$suite_name" \
       --arg test "$test_name" \
       --arg status "$status" \
       --arg details "$details" \
       --arg duration "$duration" \
       '.test_suites += [{
         "suite_name": $suite,
         "test_name": $test,
         "status": $status,
         "details": $details,
         "duration": $duration,
         "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%S%z"))
       }] | 
       if $status == "passed" then .pipeline_run.passed += 1
       elif $status == "failed" then .pipeline_run.failed += 1
       else .pipeline_run.skipped += 1 end |
       .pipeline_run.total_tests += 1' \
       "$TEST_RESULTS_FILE" > "$temp_file"
    
    mv "$temp_file" "$TEST_RESULTS_FILE"
}

# Run command with timing and error handling
run_test_command() {
    local suite_name=$1
    local test_name=$2
    local command=$3
    local description=$4
    
    log "INFO" "Running: $description"
    local start_time
    start_time=$(date +%s)
    
    if eval "$command" >> "$LOG_DIR/testing-pipeline-$TIMESTAMP.log" 2>&1; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "INFO" "✅ $description - PASSED (${duration}s)"
        update_test_results "$suite_name" "$test_name" "passed" "$description" "$duration"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "ERROR" "❌ $description - FAILED (${duration}s)"
        update_test_results "$suite_name" "$test_name" "failed" "$description" "$duration"
        return 1
    fi
}

# Code quality and validation tests
run_quality_tests() {
    log "INFO" "Starting Code Quality and Validation Tests"
    local total_tests=8
    local current_test=0
    
    # Terraform format check
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "terraform_format" \
        "cd '$PROJECT_ROOT/terraform' && terraform fmt -check -recursive" \
        "Terraform Format Check" || true
    
    # Terraform validation
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "terraform_validation" \
        "'$PROJECT_ROOT/tests/terraform/validate.sh'" \
        "Terraform Validation" || true
    
    # Security scanning
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "security_scan" \
        "'$PROJECT_ROOT/tests/terraform/security-scan.sh'" \
        "Security Scanning" || true
    
    # Ansible syntax check
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "ansible_syntax" \
        "'$PROJECT_ROOT/tests/ansible/syntax-check.sh'" \
        "Ansible Syntax Check" || true
    
    # Ansible linting
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "ansible_lint" \
        "'$PROJECT_ROOT/tests/ansible/lint.sh'" \
        "Ansible Linting" || true
    
    # YAML linting
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "yaml_lint" \
        "find '$PROJECT_ROOT' -name '*.yml' -o -name '*.yaml' | grep -v '.git' | xargs yamllint" \
        "YAML Linting" || true
    
    # Shell script linting
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "shell_lint" \
        "find '$PROJECT_ROOT' -name '*.sh' | grep -v '.git' | xargs shellcheck" \
        "Shell Script Linting" || true
    
    # Markdown linting
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Quality Tests"
    run_test_command "quality" "markdown_lint" \
        "find '$PROJECT_ROOT' -name '*.md' | grep -v '.git' | xargs markdownlint" \
        "Markdown Linting" || true
    
    log "INFO" "Code Quality and Validation Tests completed"
}

# LocalStack integration tests
run_localstack_tests() {
    log "INFO" "Starting LocalStack Integration Tests"
    local total_tests=4
    local current_test=0
    
    # Start LocalStack
    current_test=$((current_test + 1))
    progress $current_test $total_tests "LocalStack Tests"
    if run_test_command "localstack" "start_localstack" \
        "cd '$PROJECT_ROOT' && make local-start" \
        "Start LocalStack"; then
        
        # Deploy to LocalStack
        current_test=$((current_test + 1))
        progress $current_test $total_tests "LocalStack Tests"
        run_test_command "localstack" "deploy_localstack" \
            "cd '$PROJECT_ROOT/terraform/localstack' && terraform init && terraform apply -auto-approve -var='create_aws_resources=true'" \
            "Deploy to LocalStack" || true
        
        # Run smoke tests
        current_test=$((current_test + 1))
        progress $current_test $total_tests "LocalStack Tests"
        run_test_command "localstack" "smoke_tests" \
            "'$PROJECT_ROOT/tests/integration/smoke-test.sh'" \
            "Smoke Tests" || true
        
        # Run security compliance tests
        current_test=$((current_test + 1))
        progress $current_test $total_tests "LocalStack Tests"
        run_test_command "localstack" "compliance_tests" \
            "'$PROJECT_ROOT/tests/security/compliance-test.sh'" \
            "Security Compliance Tests" || true
        
        # Cleanup LocalStack
        log "INFO" "Cleaning up LocalStack..."
        cd "$PROJECT_ROOT/terraform/localstack"
        terraform destroy -auto-approve >> "$LOG_DIR/testing-pipeline-$TIMESTAMP.log" 2>&1 || true
        cd "$PROJECT_ROOT"
        make local-stop >> "$LOG_DIR/testing-pipeline-$TIMESTAMP.log" 2>&1 || true
    fi
    
    log "INFO" "LocalStack Integration Tests completed"
}

# Performance and load tests
run_performance_tests() {
    log "INFO" "Starting Performance Tests"
    local total_tests=3
    local current_test=0
    
    # Terraform plan performance
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Performance Tests"
    run_test_command "performance" "terraform_plan_performance" \
        "cd '$PROJECT_ROOT/terraform/localstack' && time terraform plan -var='create_aws_resources=true'" \
        "Terraform Plan Performance" || true
    
    # Ansible playbook performance
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Performance Tests"
    run_test_command "performance" "ansible_performance" \
        "cd '$PROJECT_ROOT' && time ansible-playbook --inventory=ansible/inventory/localstack.ini ansible/playbooks/site.yml --check" \
        "Ansible Playbook Performance" || true
    
    # Resource cleanup performance
    current_test=$((current_test + 1))
    progress $current_test $total_tests "Performance Tests"
    run_test_command "performance" "cleanup_performance" \
        "cd '$PROJECT_ROOT' && time scripts/cleanup-demo.sh --project test-performance" \
        "Resource Cleanup Performance" || true
    
    log "INFO" "Performance Tests completed"
}

# Multi-cloud tests (if OCI is configured)
run_multicloud_tests() {
    if [[ -n "${OCI_CONFIGURED:-}" ]] && [[ "$OCI_CONFIGURED" == "true" ]]; then
        log "INFO" "Starting Multi-Cloud Tests (OCI)"
        local total_tests=2
        local current_test=0
        
        # OCI Terraform validation
        current_test=$((current_test + 1))
        progress $current_test $total_tests "Multi-Cloud Tests"
        run_test_command "multicloud" "oci_terraform_validation" \
            "cd '$PROJECT_ROOT/terraform/oci' && terraform fmt -check && terraform validate" \
            "OCI Terraform Validation" || true
        
        # Cross-cloud deployment test
        current_test=$((current_test + 1))
        progress $current_test $total_tests "Multi-Cloud Tests"
        run_test_command "multicloud" "cross_cloud_test" \
            "'$PROJECT_ROOT/tests/multicloud/cross-cloud-test.sh'" \
            "Cross-Cloud Deployment Test" || true
        
        log "INFO" "Multi-Cloud Tests completed"
    else
        log "WARN" "OCI not configured, skipping multi-cloud tests"
        update_test_results "multicloud" "oci_tests" "skipped" "OCI not configured"
    fi
}

# Disaster recovery tests
run_dr_tests() {
    log "INFO" "Starting Disaster Recovery Tests"
    local total_tests=3
    local current_test=0
    
    # Backup procedures test
    current_test=$((current_test + 1))
    progress $current_test $total_tests "DR Tests"
    run_test_command "dr" "backup_procedures" \
        "'$PROJECT_ROOT/tests/disaster-recovery/dr-test.sh' --test-backup" \
        "Backup Procedures Test" || true
    
    # Restore procedures test
    current_test=$((current_test + 1))
    progress $current_test $total_tests "DR Tests"
    run_test_command "dr" "restore_procedures" \
        "'$PROJECT_ROOT/tests/disaster-recovery/dr-test.sh' --test-restore" \
        "Restore Procedures Test" || true
    
    # Infrastructure reproducibility test
    current_test=$((current_test + 1))
    progress $current_test $total_tests "DR Tests"
    run_test_command "dr" "infrastructure_reproducibility" \
        "'$PROJECT_ROOT/tests/disaster-recovery/dr-test.sh' --test-reproducibility" \
        "Infrastructure Reproducibility Test" || true
    
    log "INFO" "Disaster Recovery Tests completed"
}

# Generate comprehensive test report
generate_report() {
    log "INFO" "Generating Test Report"
    
    local report_file="$REPORTS_DIR/test-report-$TIMESTAMP.html"
    
    # Extract statistics from JSON
    local total_tests passed failed
    total_tests=$(jq -r '.pipeline_run.total_tests' "$TEST_RESULTS_FILE")
    passed=$(jq -r '.pipeline_run.passed' "$TEST_RESULTS_FILE")
    failed=$(jq -r '.pipeline_run.failed' "$TEST_RESULTS_FILE")
    skipped=$(jq -r '.pipeline_run.skipped' "$TEST_RESULTS_FILE")
    
    local success_rate
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$((passed * 100 / total_tests))
    else
        success_rate=0
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Infrastructure Automation Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; font-size: 18px; }
        .metric .value { font-size: 36px; font-weight: bold; margin: 0; }
        .test-suite { margin-bottom: 30px; }
        .test-suite h2 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        .test-item { display: flex; justify-content: space-between; align-items: center; padding: 10px; border-left: 4px solid #ddd; margin-bottom: 5px; background-color: #f8f9fa; }
        .test-item.passed { border-left-color: #28a745; }
        .test-item.failed { border-left-color: #dc3545; }
        .test-item.skipped { border-left-color: #ffc107; }
        .test-name { font-weight: bold; }
        .test-status { padding: 4px 8px; border-radius: 4px; color: white; font-size: 12px; font-weight: bold; }
        .test-status.passed { background-color: #28a745; }
        .test-status.failed { background-color: #dc3545; }
        .test-status.skipped { background-color: #ffc107; color: #000; }
        .progress-bar { width: 100%; height: 20px; background-color: #e9ecef; border-radius: 10px; overflow: hidden; margin: 10px 0; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #28a745 0%, #20c997 100%); transition: width 0.3s ease; }
        .timestamp { text-align: center; color: #666; margin-top: 30px; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Infrastructure Automation Test Report</h1>
            <p>Comprehensive testing pipeline execution results</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <h3>Total Tests</h3>
                <div class="value">$total_tests</div>
            </div>
            <div class="metric">
                <h3>Passed</h3>
                <div class="value">$passed</div>
            </div>
            <div class="metric">
                <h3>Failed</h3>
                <div class="value">$failed</div>
            </div>
            <div class="metric">
                <h3>Success Rate</h3>
                <div class="value">$success_rate%</div>
            </div>
        </div>
        
        <div class="progress-bar">
            <div class="progress-fill" style="width: $success_rate%"></div>
        </div>
        
EOF

    # Add test suites to report
    jq -r '.test_suites | group_by(.suite_name) | .[] | .[0].suite_name' "$TEST_RESULTS_FILE" | while read -r suite_name; do
        echo "<div class='test-suite'>" >> "$report_file"
        echo "<h2>$(echo "$suite_name" | sed 's/_/ /g' | sed 's/\b\w/\u&/g')</h2>" >> "$report_file"
        
        jq -r ".test_suites[] | select(.suite_name == \"$suite_name\") | 
               \"<div class=\\\"test-item \\(.status)\\\">
                    <span class=\\\"test-name\\\">\\(.test_name)</span>
                    <span class=\\\"test-status \\(.status)\\\">\\(.status | ascii_upcase)</span>
               </div>\"" "$TEST_RESULTS_FILE" >> "$report_file"
        
        echo "</div>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
        
        <div class="timestamp">
            <p>Generated on $(date)</p>
            <p>Environment: ${ENVIRONMENT:-local}</p>
            <p>Log file: testing-pipeline-$TIMESTAMP.log</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log "INFO" "Test report generated: $report_file"
    
    # Display summary
    echo ""
    echo "🎯 TEST SUMMARY"
    echo "================"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo "Skipped: $skipped"
    echo "Success Rate: $success_rate%"
    echo ""
    
    if [[ $failed -gt 0 ]]; then
        log "WARN" "Some tests failed. Check the report and logs for details."
        return 1
    else
        log "INFO" "All tests passed successfully!"
        return 0
    fi
}

# Main execution function
main() {
    log "INFO" "🚀 Starting Automated Testing Pipeline"
    log "INFO" "Project Root: $PROJECT_ROOT"
    log "INFO" "Log Directory: $LOG_DIR"
    log "INFO" "Reports Directory: $REPORTS_DIR"
    log "INFO" "Timestamp: $TIMESTAMP"
    
    # Parse command line arguments
    local skip_localstack=false
    local skip_performance=false
    local skip_multicloud=false
    local skip_dr=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-localstack)
                skip_localstack=true
                shift
                ;;
            --skip-performance)
                skip_performance=true
                shift
                ;;
            --skip-multicloud)
                skip_multicloud=true
                shift
                ;;
            --skip-dr)
                skip_dr=true
                shift
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -h|--help)
                cat << EOF
Usage: $0 [OPTIONS]

Automated Testing Pipeline for Infrastructure Automation

OPTIONS:
    --skip-localstack     Skip LocalStack integration tests
    --skip-performance    Skip performance tests
    --skip-multicloud     Skip multi-cloud tests
    --skip-dr            Skip disaster recovery tests
    --environment ENV    Set environment (local, staging, production)
    -h, --help          Show this help message

EXAMPLES:
    $0                                    # Run all tests
    $0 --skip-localstack                  # Skip LocalStack tests
    $0 --environment production           # Run in production mode

EOF
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Initialize test results
    init_test_results
    
    # Run test suites
    log "INFO" "Running test suites..."
    
    run_quality_tests
    
    if [[ "$skip_localstack" != "true" ]]; then
        run_localstack_tests
    else
        log "INFO" "Skipping LocalStack tests"
    fi
    
    if [[ "$skip_performance" != "true" ]]; then
        run_performance_tests
    else
        log "INFO" "Skipping performance tests"
    fi
    
    if [[ "$skip_multicloud" != "true" ]]; then
        run_multicloud_tests
    else
        log "INFO" "Skipping multi-cloud tests"
    fi
    
    if [[ "$skip_dr" != "true" ]]; then
        run_dr_tests
    else
        log "INFO" "Skipping disaster recovery tests"
    fi
    
    # Generate final report
    generate_report
    
    log "INFO" "✅ Testing Pipeline completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
