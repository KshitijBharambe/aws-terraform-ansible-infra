#!/bin/bash

# AWS Cost Monitoring Script
# Monitors and reports on AWS infrastructure costs

set -e

echo "💰 Starting AWS Cost Monitoring..."
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="infra-demo"
ENVIRONMENT="demo"
AWS_REGION="us-east-1"
BUDGET_LIMIT=15
ALERT_THRESHOLD=80

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
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_status "INFO" "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_status "FAIL" "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_status "FAIL" "AWS credentials not configured"
        exit 1
    fi
    
    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        print_status "WARN" "jq is not installed, some features may be limited"
    fi
    
    print_status "PASS" "All prerequisites checked"
}

# Function to get current month costs
get_current_month_costs() {
    print_status "INFO" "Getting current month costs..."
    
    local current_month=$(date +%Y-%m)
    local start_date="${current_month}-01"
    local end_date=$(date +%Y-%m-%d)
    
    # Get total cost
    local total_cost=$(aws ce get-cost-and-usage \
        --time-period "Start=$start_date,End=$end_date" \
        --granularity MONTHLY \
        --metrics "UnblendedCost" \
        --query "ResultsByTime[0].Total.Amount" \
        --output text 2>/dev/null || echo "0")
    
    if [ -n "$total_cost" ] && [ "$total_cost" != "None" ]; then
        print_status "INFO" "Current month total cost: \$$total_cost"
        
        # Check against budget
        local budget_percentage=$(echo "scale=2; $total_cost * 100 / $BUDGET_LIMIT" | bc 2>/dev/null || echo "0")
        
        if (( $(echo "$budget_percentage >= $ALERT_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
            print_status "WARN" "Cost is ${budget_percentage}% of budget (\$$total_cost / \$$BUDGET_LIMIT)"
        else
            print_status "PASS" "Cost is ${budget_percentage}% of budget (\$$total_cost / \$$BUDGET_LIMIT)"
        fi
    else
        print_status "INFO" "No costs found for current month"
    fi
    
    echo "$total_cost"
}

# Function to get costs by service
get_costs_by_service() {
    print_status "INFO" "Getting costs by service..."
    
    local current_month=$(date +%Y-%m)
    local start_date="${current_month}-01"
    local end_date=$(date +%Y-%m-%d)
    
    # Get costs by service
    if command -v jq &> /dev/null; then
        local service_costs=$(aws ce get-cost-and-usage \
            --time-period "Start=$start_date,End=$end_date" \
            --granularity MONTHLY \
            --group-by Type=DIMENSION,Key=SERVICE \
            --metrics "UnblendedCost" \
            --query "ResultsByTime[0].Groups" \
            --output json 2>/dev/null)
        
        if [ -n "$service_costs" ]; then
            echo ""
            echo "💰 Costs by Service:"
            echo "==================="
            
            echo "$service_costs" | jq -r '.[] | select(.Keys.Service != null) | "\(.Keys.Service): $\(.Metrics.UnblendedCost.Amount | round(2))"' | while read -r line; do
                local service=$(echo "$line" | cut -d: -f1)
                local cost=$(echo "$line" | cut -d: -f2)
                local cost_num=$(echo "$cost" | sed 's/[^0-9.]//g')
                
                if [ -n "$cost_num" ] && [ "$(echo "$cost_num > 0" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
                    printf "%-20s \$%8s\n" "$service" "$cost"
                fi
            done
        else
            print_status "WARN" "Could not get service costs"
        fi
    fi
}

# Function to get daily costs for the week
get_daily_costs() {
    print_status "INFO" "Getting daily costs for the past week..."
    
    echo ""
    echo "📅 Daily Costs (Past 7 Days):"
    echo "==============================="
    
    for i in {7..1}; do
        local check_date=$(date -d "$i days ago" +%Y-%m-%d)
        local day_name=$(date -d "$i days ago" +%a)
        local formatted_date=$(date -d "$i days ago" +%m/%d)
        
        local day_cost=$(aws ce get-cost-and-usage \
            --time-period "Start=$check_date,End=$check_date" \
            --granularity DAILY \
            --metrics "UnblendedCost" \
            --query "ResultsByTime[0].Total.Amount" \
            --output text 2>/dev/null || echo "0")
        
        if [ -n "$day_cost" ] && [ "$day_cost" != "None" ]; then
            printf "%-12s \$%8s\n" "$formatted_date ($day_name)" "$day_cost"
        else
            printf "%-12s \$%8s\n" "$formatted_date ($day_name)" "\$0.00"
        fi
    done
}

# Function to get project-specific costs
get_project_costs() {
    print_status "INFO" "Getting project-specific costs..."
    
    local current_month=$(date +%Y-%m)
    local start_date="${current_month}-01"
    local end_date=$(date +%Y-%m-%d)
    
    # Get costs with project tag
    if command -v jq &> /dev/null; then
        local project_costs=$(aws ce get-cost-and-usage \
            --time-period "Start=$start_date,End=$end_date" \
            --granularity MONTHLY \
            --filter "Dimensions={Key=Project,Values=[$PROJECT_NAME]}" \
            --metrics "UnblendedCost" \
            --query "ResultsByTime[0].Total.Amount" \
            --output json 2>/dev/null)
        
        if [ -n "$project_costs" ]; then
            local cost=$(echo "$project_costs" | jq -r '.Amount // 0')
            if [ -n "$cost" ] && [ "$cost" != "0" ]; then
                print_status "INFO" "Project '$PROJECT_NAME' cost: \$$cost"
            else
                print_status "INFO" "No costs found for project '$PROJECT_NAME'"
            fi
        else
            print_status "WARN" "Could not get project costs"
        fi
    fi
}

# Function to get EC2 instance costs
get_ec2_costs() {
    print_status "INFO" "Getting EC2 instance costs..."
    
    # Get running instances with project tags
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]" \
        --output json 2>/dev/null)
    
    if [ -n "$instances" ] && [ "$instances" != "[]" ]; then
        echo ""
        echo "🖥️ Running EC2 Instances:"
        echo "========================="
        printf "%-20s %-15s %-20s %s\n" "Instance ID" "Type" "Launch Time" "Running Hours"
        
        echo "$instances" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r instance_id instance_type launch_time; do
            local launch_timestamp=$(date -d "$launch_time" +%s)
            local current_timestamp=$(date +%s)
            local running_hours=$(echo "scale=1; ($current_timestamp - $launch_timestamp) / 3600" | bc 2>/dev/null || echo "0")
            
            # Estimate hourly cost for instance type
            local hourly_cost=0
            case $instance_type in
                "t4g.micro") hourly_cost=0.008 ;;
                "t4g.small") hourly_cost=0.016 ;;
                "t4g.medium") hourly_cost=0.032 ;;
                "t3.micro") hourly_cost=0.0104 ;;
                "t3.small") hourly_cost=0.0208 ;;
                "t3.medium") hourly_cost=0.0416 ;;
                "m5.large") hourly_cost=0.096 ;;
                "c5.large") hourly_cost=0.085 ;;
                *) hourly_cost=0.05 ;; # Default estimate
            esac
            
            local total_cost=$(echo "scale=2; $running_hours * $hourly_cost" | bc 2>/dev/null || echo "0")
            
            printf "%-20s %-15s %-20s %5.1h (\$%6.2)\n" "$instance_id" "$instance_type" "$(date -d "$launch_time" '+%Y-%m-%d %H:%M')" "$running_hours" "$total_cost"
        done
    else
        print_status "INFO" "No running EC2 instances found"
    fi
}

# Function to get EBS costs
get_ebs_costs() {
    print_status "INFO" "Getting EBS storage costs..."
    
    # Get EBS volumes with project tags
    local volumes=$(aws ec2 describe-volumes \
        --filters "Name=tag:Project,Values=$PROJECT_NAME" \
        --query "Volumes[].[VolumeId,Size,VolumeType,State]" \
        --output json 2>/dev/null)
    
    if [ -n "$volumes" ] && [ "$volumes" != "[]" ]; then
        echo ""
        echo "💾 EBS Volumes:"
        echo "==============="
        printf "%-20s %-10s %-15s %-10s %s\n" "Volume ID" "Size (GB)" "Type" "State" "Monthly Cost"
        
        echo "$volumes" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r volume_id size type state; do
            # Estimate monthly cost based on volume type
            local gb_cost=0
            case $type in
                "gp2") gb_cost=0.08 ;;
                "gp3") gb_cost=0.08 ;;
                "io1") gb_cost=0.125 ;;
                "st1") gb_cost=0.045 ;;
                *) gb_cost=0.08 ;; # Default to gp3
            esac
            
            local monthly_cost=$(echo "scale=2; $size * $gb_cost" | bc 2>/dev/null || echo "0")
            
            printf "%-20s %-10s %-15s %-10s \$%8.2\n" "$volume_id" "$size" "$type" "$state" "$monthly_cost"
        done
    else
        print_status "INFO" "No EBS volumes found"
    fi
}

# Function to get data transfer costs
get_data_transfer_costs() {
    print_status "INFO" "Getting data transfer costs..."
    
    local current_month=$(date +%Y-%m)
    local start_date="${current_month}-01"
    local end_date=$(date +%Y-%m-%d)
    
    # Get data transfer costs
    local transfer_cost=$(aws ce get-cost-and-usage \
        --time-period "Start=$start_date,End=$end_date" \
        --granularity MONTHLY \
        --filter "Dimensions={Key=SERVICE,Values=[AWS Data Transfer]}" \
        --metrics "UnblendedCost" \
        --query "ResultsByTime[0].Total.Amount" \
        --output text 2>/dev/null || echo "0")
    
    if [ -n "$transfer_cost" ] && [ "$transfer_cost" != "None" ] && [ "$transfer_cost" != "0" ]; then
        print_status "INFO" "Data transfer costs: \$$transfer_cost"
    else
        print_status "INFO" "No data transfer costs found"
    fi
}

# Function to check cost alerts
check_cost_alerts() {
    print_status "INFO" "Checking cost alerts..."
    
    # Check CloudWatch billing alarms
    local alarms=$(aws cloudwatch describe-alarms \
        --alarm-name-prefix "Demo" \
        --query "MetricAlarms[].[AlarmName,StateValue,StateReason]" \
        --output json 2>/dev/null)
    
    if [ -n "$alarms" ] && [ "$alarms" != "[]" ]; then
        echo ""
        echo "🚨 Cost Alerts:"
        echo "==============="
        
        echo "$alarms" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r alarm_name state reason; do
            case $state in
                "ALARM")
                    printf "%-30s %-10s %s\n" "$alarm_name" "🔴 ALARM" "$reason"
                    ;;
                "OK")
                    printf "%-30s %-10s %s\n" "$alarm_name" "✅ OK" "Normal"
                    ;;
                "INSUFFICIENT_DATA")
                    printf "%-30s %-10s %s\n" "$alarm_name" "⚠️  INSUFFICIENT" "Insufficient data"
                    ;;
                *)
                    printf "%-30s %-10s %s\n" "$alarm_name" "❓ $state" "$reason"
                    ;;
            esac
        done
    else
        print_status "INFO" "No cost alerts found"
    fi
}

# Function to check AWS budgets
check_aws_budgets() {
    print_status "INFO" "Checking AWS budgets..."
    
    if command -v aws budgets &> /dev/null; then
        local budgets=$(aws budgets describe-budgets \
            --query "Budgets[].[BudgetName,BudgetLimit.Amount,CalculatedSpend.Amount,TimeUnit]" \
            --output json 2>/dev/null)
        
        if [ -n "$budgets" ] && [ "$budgets" != "[]" ]; then
            echo ""
            echo "📊 AWS Budgets:"
            echo "==============="
            
            echo "$budgets" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r name limit spent unit; do
                local percentage=$(echo "scale=1; $spent * 100 / $limit" | bc 2>/dev/null || echo "0")
                printf "%-30s \$%10s \$%10s (%3s%%)\n" "$name" "$limit" "$spent" "$percentage"
            done
        else
            print_status "INFO" "No AWS budgets found"
        fi
    else
        print_status "INFO" "AWS Budgets service not available"
    fi
}

# Function to get cost forecast
get_cost_forecast() {
    print_status "INFO" "Getting cost forecast..."
    
    # Get forecast for current month
    local current_month=$(date +%Y-%m)
    local start_date="${current_month}-01"
    local end_date=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%Y-%m-%d)
    
    local forecast=$(aws ce get-cost-and-usage \
        --time-period "Start=$start_date,End=$end_date" \
        --granularity MONTHLY \
        --metric "BLENDED_COST" \
        --prediction-interval-days 30 \
        --query "ResultsByTime[0].MeanValue" \
        --output text 2>/dev/null || echo "0")
    
    if [ -n "$forecast" ] && [ "$forecast" != "None" ] && [ "$forecast" != "0" ]; then
        print_status "INFO" "Month-end forecast: \$$forecast"
        
        # Check if forecast exceeds budget
        if (( $(echo "$forecast > $BUDGET_LIMIT" | bc -l 2>/dev/null || echo "0") )); then
            print_status "WARN" "Forecast exceeds budget by \$$(echo "scale=2; $forecast - $BUDGET_LIMIT" | bc 2>/dev/null || echo "0")"
        else
            print_status "PASS" "Forecast within budget"
        fi
    else
        print_status "INFO" "No forecast available"
    fi
}

# Function to generate cost report
generate_cost_report() {
    print_status "INFO" "Generating comprehensive cost report..."
    
    local report_file="reports/cost-monitoring-report.txt"
    mkdir -p reports
    
    cat > "$report_file" << EOF
AWS Cost Monitoring Report
========================

Generated: $(date)
Project: $PROJECT_NAME
Environment: $ENVIRONMENT
Region: $AWS_REGION
Budget Limit: \$$BUDGET_LIMIT

Cost Summary:
-------------
$(get_current_month_costs 2>/dev/null | tail -1)

Service Breakdown:
----------------
$(get_costs_by_service 2>/dev/null | tail -n +2)

Running Instances:
-----------------
$(get_ec2_costs 2>/dev/null | tail -n +2)

Storage Costs:
-------------
$(get_ebs_costs 2>/dev/null | tail -n +2)

Data Transfer:
-------------
$(get_data_transfer_costs 2>/dev/null | tail -1)

Cost Alerts:
------------
$(check_cost_alerts 2>/dev/null | tail -n +2)

Budget Status:
-------------
$(check_aws_budgets 2>/dev/null | tail -n +2)

Cost Forecast:
--------------
$(get_cost_forecast 2>/dev/null | tail -1)

Recommendations:
---------------
1. Monitor costs daily to avoid surprises
2. Set up budget alerts for early warning
3. Use cost allocation tags for better tracking
4. Regularly review and clean up unused resources
5. Consider using Savings Plans for predictable workloads
6. Enable cost anomaly detection
7. Use AWS Cost Explorer for detailed analysis
8. Implement automated cleanup for temporary resources

Cost Optimization Tips:
-----------------------
- Use t4g.micro instances for demos (60% cheaper than x86)
- Disable NAT Gateway when not needed (saves \$33/month)
- Use public subnets for temporary deployments
- Choose gp3 storage over gp2 for better performance
- Clean up resources promptly after demos
- Use spot instances for fault-tolerant workloads
- Implement automated cost monitoring

Next Steps:
-----------
1. Review current spending patterns
2. Set up additional cost alerts if needed
3. Plan resource cleanup for end of month
4. Update budgets based on actual usage
5. Implement automated cost monitoring

EOF
    
    print_status "PASS" "Cost report generated: $report_file"
}

# Function to show interactive cost menu
show_cost_menu() {
    echo ""
    echo "💰 AWS Cost Monitoring Menu"
    echo "==========================="
    echo "1. Current month costs"
    echo "2. Costs by service"
    echo "3. Daily costs (past week)"
    echo "4. Project-specific costs"
    echo "5. EC2 instance costs"
    echo "6. EBS storage costs"
    echo "7. Data transfer costs"
    echo "8. Cost alerts status"
    echo "9. AWS budgets"
    echo "10. Cost forecast"
    echo "11. Generate full report"
    echo "12. Exit"
    echo ""
    
    read -p "Select option (1-12): " choice
    
    case $choice in
        1)
            get_current_month_costs
            ;;
        2)
            get_costs_by_service
            ;;
        3)
            get_daily_costs
            ;;
        4)
            get_project_costs
            ;;
        5)
            get_ec2_costs
            ;;
        6)
            get_ebs_costs
            ;;
        7)
            get_data_transfer_costs
            ;;
        8)
            check_cost_alerts
            ;;
        9)
            check_aws_budgets
            ;;
        10)
            get_cost_forecast
            ;;
        11)
            generate_cost_report
            ;;
        12)
            print_status "INFO" "Exiting cost monitoring"
            exit 0
            ;;
        *)
            print_status "WARN" "Invalid option: $choice"
            ;;
    esac
    
    echo ""
    echo "Press Enter to continue..."
    read
    show_cost_menu
}

# Main execution
echo ""
print_status "INFO" "Starting AWS cost monitoring..."

# Parse command line arguments
INTERACTIVE_MODE=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --budget)
            BUDGET_LIMIT="$2"
            shift 2
            ;;
        --report)
            INTERACTIVE_MODE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --project NAME       Project name (default: infra-demo)"
            echo "  --environment NAME   Environment (default: demo)"
            echo "  --region REGION      AWS region (default: us-east-1)"
            echo "  --budget AMOUNT     Budget limit (default: 15)"
            echo "  --report            Generate report and exit"
            echo "  --help              Show this help"
            exit 0
            ;;
        *)
            print_status "WARN" "Unknown option: $1"
            shift
            ;;
    esac
done

# Run prerequisite checks
check_prerequisites

# Execute based on mode
if [ "$INTERACTIVE_MODE" = true ]; then
    show_cost_menu
else
    # Generate full report
    get_current_month_costs >/dev/null
    get_costs_by_service >/dev/null
    get_daily_costs >/dev/null
    get_project_costs >/dev/null
    get_ec2_costs >/dev/null
    get_ebs_costs >/dev/null
    get_data_transfer_costs >/dev/null
    check_cost_alerts >/dev/null
    check_aws_budgets >/dev/null
    get_cost_forecast >/dev/null
    generate_cost_report
    
    echo ""
    print_status "PASS" "💰 Cost monitoring report completed!"
    echo "Report saved to: reports/cost-monitoring-report.txt"
fi

exit 0
