#!/bin/bash

# =============================================================================
# Cost Comparison Analysis Script
# =============================================================================
# This script provides detailed cost analysis and comparison across
# AWS and Oracle Cloud Infrastructure deployments
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
REPORTS_DIR="$PROJECT_ROOT/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create necessary directories
mkdir -p "$REPORTS_DIR"

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
    
    echo "[$timestamp] [$level] $message" >> "$REPORTS_DIR/cost-analysis-$TIMESTAMP.log"
}

# Parse command line arguments
parse_arguments() {
    PROJECT_NAME="infra-demo"
    AWS_REGION="us-east-1"
    OCI_REGION="us-ashburn-1"
    ENVIRONMENT="dev"
    DURATION_HOURS=24
    INCLUDE_FREE_TIER=true
    OUTPUT_FORMAT="html"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                PROJECT_NAME="$2"
                shift 2
                ;;
            --aws-region)
                AWS_REGION="$2"
                shift 2
                ;;
            --oci-region)
                OCI_REGION="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --duration)
                DURATION_HOURS="$2"
                shift 2
                ;;
            --no-free-tier)
                INCLUDE_FREE_TIER=false
                shift
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -h|--help)
                cat << EOF
Usage: $0 [OPTIONS]

Cost Comparison Analysis for Multi-Cloud Infrastructure

OPTIONS:
    --project NAME           Project name (default: infra-demo)
    --aws-region REGION     AWS region (default: us-east-1)
    --oci-region REGION     OCI region (default: us-ashburn-1)
    --environment ENV       Environment: dev, staging, production (default: dev)
    --duration HOURS       Cost analysis duration in hours (default: 24)
    --no-free-tier        Exclude free tier resources from analysis
    --format FORMAT        Output format: html, json, csv (default: html)
    -h, --help           Show this help message

EXAMPLES:
    $0 --project myapp --duration 168 --format json
    $0 --environment production --no-free-tier
    $0 --aws-region us-west-2 --oci-region eu-frankfurt-1

EOF
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Get AWS pricing data
get_aws_pricing() {
    log "INFO" "Fetching AWS pricing data..."
    
    # AWS Pricing (simplified estimates - in production, this would use AWS Pricing API)
    cat > "$REPORTS_DIR/aws-pricing-$TIMESTAMP.json" << EOF
{
  "compute": {
    "t3_micro": {
      "hourly": 0.0104,
      "monthly": 7.50,
      "memory_gb": 1,
      "vcpu": 2,
      "instance_type": "General Purpose"
    },
    "t3_small": {
      "hourly": 0.0208,
      "monthly": 15.00,
      "memory_gb": 2,
      "vcpu": 2,
      "instance_type": "General Purpose"
    },
    "t3_medium": {
      "hourly": 0.0416,
      "monthly": 30.00,
      "memory_gb": 4,
      "vcpu": 2,
      "instance_type": "General Purpose"
    },
    "m5_large": {
      "hourly": 0.096,
      "monthly": 69.12,
      "memory_gb": 8,
      "vcpu": 2,
      "instance_type": "General Purpose"
    }
  },
  "storage": {
    "gp3": {
      "monthly_per_gb": 0.08,
      "provisioned_iops_cost": 0.005,
      "provisioned_throughput_cost": 0.04
    },
    "ebs_standard": {
      "monthly_per_gb": 0.05
    }
  },
  "network": {
    "data_transfer_out": {
      "first_10_gb": 0.0,
      "up_to_10_tb": 0.09,
      "over_10_tb": 0.085
    },
    "nat_gateway": {
      "hourly": 0.045,
      "data_processing": 0.00045
    },
    "load_balancer": {
      "application_lb": {
        "hourly": 0.0225,
        "lcu_hour": 0.008
      }
    }
  },
  "database": {
    "rds_t3_micro": {
      "hourly": 0.013,
      "monthly": 9.50,
      "memory_gb": 1,
      "vcpu": 2,
      "storage_gb": 20
    },
    "rds_t3_small": {
      "hourly": 0.026,
      "monthly": 18.75,
      "memory_gb": 2,
      "vcpu": 2,
      "storage_gb": 20
    }
  }
}
EOF
    
    log "INFO" "✅ AWS pricing data loaded"
}

# Get OCI pricing data
get_oci_pricing() {
    log "INFO" "Fetching OCI pricing data..."
    
    # OCI Pricing (simplified estimates - in production, this would use OCI Pricing API)
    cat > "$REPORTS_DIR/oci-pricing-$TIMESTAMP.json" << EOF
{
  "compute": {
    "vm_standard_e2_1_micro": {
      "hourly": 0.0135,
      "monthly": 9.74,
      "memory_gb": 1,
      "ocpus": 1,
      "instance_type": "Burstable",
      "free_tier": true
    },
    "vm_standard_a1_flex": {
      "hourly_per_ocpu": 0.0100,
      "memory_per_ocpu_gb": 6,
      "instance_type": "Ampere A1",
      "free_tier": {
        "ocpus": 4,
        "memory_gb": 24
      }
    },
    "vm_standard2_1": {
      "hourly": 0.047,
      "monthly": 33.84,
      "memory_gb": 8,
      "ocpus": 1,
      "instance_type": "Standard"
    }
  },
  "storage": {
    "block_volume": {
      "monthly_per_gb": 0.0255,
      "performance_levels": {
        "balanced": 0.0255,
        "higher_performance": 0.051,
        "ultra_high_performance": 0.102
      }
    },
    "object_storage": {
      "monthly_per_gb_first_10tb": 0.0255,
      "monthly_per_gb_next_90tb": 0.0245,
      "monthly_per_gb_over_100tb": 0.023
    }
  },
  "network": {
    "data_egress": {
      "monthly_first_10tb": 0.0085,
      "monthly_next_40tb": 0.007,
      "monthly_over_50tb": 0.005
    }
  },
  "load_balancer": {
    "flexible": {
      "minimum_monthly": 22.94,
      "per_10_mbps": 1.40
    },
    "100_mbps": {
      "monthly": 25.00
    }
  },
  "database": {
    "vm_standard2_1": {
      "hourly": 0.308,
      "monthly": 221.76,
      "memory_gb": 8,
      "ocpus": 1,
      "storage_per_gb": 0.188
    }
  }
}
EOF
    
    log "INFO" "✅ OCI pricing data loaded"
}

# Calculate AWS deployment cost
calculate_aws_cost() {
    log "INFO" "Calculating AWS deployment costs..."
    
    # Standard deployment configuration
    local instances=2
    local instance_type="t3_small"
    local storage_gb=100
    local load_balancer=true
    local nat_gateway=true
    local database=false
    
    # Get pricing
    local hourly_compute
    hourly_compute=$(jq -r ".compute.$instance_type.hourly" "$REPORTS_DIR/aws-pricing-$TIMESTAMP.json")
    
    local monthly_storage
    monthly_storage=$(jq -r ".storage.gp3.monthly_per_gb" "$REPORTS_DIR/aws-pricing-$TIMESTAMP.json")
    
    local hourly_lb
    hourly_lb=$(jq -r ".network.load_balancer.application_lb.hourly" "$REPORTS_DIR/aws-pricing-$TIMESTAMP.json")
    
    local hourly_nat
    hourly_nat=$(jq -r ".network.nat_gateway.hourly" "$REPORTS_DIR/aws-pricing-$TIMESTAMP.json")
    
    # Calculate costs
    local compute_cost=$((instances * hourly_compute * DURATION_HOURS))
    local storage_cost=$((storage_gb * monthly_storage / 30 / 24 * DURATION_HOURS))
    local lb_cost=$(echo "$load_balancer && $hourly_lb * $DURATION_HOURS" | bc -l)
    local nat_cost=$(echo "$nat_gateway && $hourly_nat * $DURATION_HOURS" | bc -l)
    
    local total_cost=$(echo "$compute_cost + $storage_cost + $lb_cost + $nat_cost" | bc -l)
    
    # Generate AWS cost breakdown
    cat > "$REPORTS_DIR/aws-cost-$TIMESTAMP.json" << EOF
{
  "deployment_config": {
    "provider": "AWS",
    "region": "$AWS_REGION",
    "environment": "$ENVIRONMENT",
    "duration_hours": $DURATION_HOURS,
    "instances": {
      "count": $instances,
      "type": "$instance_type",
      "hourly_cost": $hourly_compute,
      "total_compute_cost": $compute_cost
    },
    "storage": {
      "gb": $storage_gb,
      "monthly_per_gb": $monthly_storage,
      "total_storage_cost": $storage_cost
    },
    "network": {
      "load_balancer_enabled": $load_balancer,
      "load_balancer_hourly_cost": $hourly_lb,
      "load_balancer_cost": $lb_cost,
      "nat_gateway_enabled": $nat_gateway,
      "nat_gateway_hourly_cost": $hourly_nat,
      "nat_gateway_cost": $nat_cost
    },
    "database": {
      "enabled": $database,
      "cost": 0.0
    }
  },
  "cost_breakdown": {
    "compute": $compute_cost,
    "storage": $storage_cost,
    "network": $(echo "$lb_cost + $nat_cost" | bc -l),
    "database": 0.0,
    "total": $total_cost
  },
  "estimated_monthly": {
    "compute": $(echo "$hourly_compute * 24 * 30" | bc -l),
    "storage": $monthly_storage,
    "network": $(echo "($hourly_lb + $hourly_nat) * 24 * 30" | bc -l),
    "total": $(echo "$total_cost / $DURATION_HOURS * 24 * 30" | bc -l)
  }
}
EOF
    
    log "INFO" "✅ AWS cost calculation completed"
}

# Calculate OCI deployment cost
calculate_oci_cost() {
    log "INFO" "Calculating OCI deployment costs..."
    
    # Standard deployment configuration
    local instances=2
    local instance_type="vm_standard_e2_1_micro"
    local storage_gb=100
    local load_balancer=true
    local database=false
    
    if [[ "$INCLUDE_FREE_TIER" == "true" ]]; then
        # Use free tier eligible configuration
        instances=1
        instance_type="vm_standard_a1_flex"
    fi
    
    # Get pricing
    local hourly_compute
    hourly_compute=$(jq -r ".compute.$instance_type.hourly" "$REPORTS_DIR/oci-pricing-$TIMESTAMP.json")
    
    local monthly_storage
    monthly_storage=$(jq -r ".storage.block_volume.monthly_per_gb" "$REPORTS_DIR/oci-pricing-$TIMESTAMP.json")
    
    local monthly_lb
    if [[ "$INCLUDE_FREE_TIER" == "true" ]]; then
        monthly_lb=22.94  # Flexible minimum
    else
        monthly_lb=25.00  # 100Mbps
    fi
    
    # Calculate costs
    local compute_cost=$((instances * hourly_compute * DURATION_HOURS))
    local storage_cost=$((storage_gb * monthly_storage / 30 / 24 * DURATION_HOURS))
    local lb_cost=$(echo "$load_balancer && $monthly_lb / 30 / 24 * DURATION_HOURS" | bc -l)
    
    # Apply free tier discount
    if [[ "$INCLUDE_FREE_TIER" == "true" ]]; then
        compute_cost=0
        storage_cost=$(echo "max(0, $storage_cost - 10)" | bc -l)  # 10GB free
        lb_cost=0  # Load balancer not available in free tier
    fi
    
    local total_cost=$(echo "$compute_cost + $storage_cost + $lb_cost" | bc -l)
    
    # Generate OCI cost breakdown
    cat > "$REPORTS_DIR/oci-cost-$TIMESTAMP.json" << EOF
{
  "deployment_config": {
    "provider": "OCI",
    "region": "$OCI_REGION",
    "environment": "$ENVIRONMENT",
    "duration_hours": $DURATION_HOURS,
    "free_tier_enabled": $INCLUDE_FREE_TIER,
    "instances": {
      "count": $instances,
      "type": "$instance_type",
      "hourly_cost": $hourly_compute,
      "total_compute_cost": $compute_cost
    },
    "storage": {
      "gb": $storage_gb,
      "monthly_per_gb": $monthly_storage,
      "total_storage_cost": $storage_cost
    },
    "network": {
      "load_balancer_enabled": $load_balancer,
      "load_balancer_monthly_cost": $monthly_lb,
      "load_balancer_cost": $lb_cost
    },
    "database": {
      "enabled": $database,
      "cost": 0.0
    }
  },
  "cost_breakdown": {
    "compute": $compute_cost,
    "storage": $storage_cost,
    "network": $lb_cost,
    "database": 0.0,
    "total": $total_cost
  },
  "estimated_monthly": {
    "compute": $(echo "$hourly_compute * 24 * 30" | bc -l),
    "storage": $monthly_storage,
    "network": $(echo "$monthly_lb / 30 * 24 * 30" | bc -l),
    "total": $(echo "$total_cost / $DURATION_HOURS * 24 * 30" | bc -l)
  },
  "free_tier_benefits": {
    "compute_hours_free": $([[ "$INCLUDE_FREE_TIER" == "true" ]] && echo "720" || echo "0"),
    "storage_gb_free": $([[ "$INCLUDE_FREE_TIER" == "true" ]] && echo "10" || echo "0"),
    "estimated_savings": $([[ "$INCLUDE_FREE_TIER" == "true" ]] && echo "$(echo "$total_cost + $compute_cost" | bc -l)" || echo "0")
  }
}
EOF
    
    log "INFO" "✅ OCI cost calculation completed"
}

# Generate comparison report
generate_comparison() {
    log "INFO" "Generating cost comparison report..."
    
    # Load cost calculations
    local aws_monthly
    local oci_monthly
    aws_monthly=$(jq -r '.estimated_monthly.total' "$REPORTS_DIR/aws-cost-$TIMESTAMP.json")
    oci_monthly=$(jq -r '.estimated_monthly.total' "$REPORTS_DIR/oci-cost-$TIMESTAMP.json")
    
    local savings_percentage
    if [[ $(echo "$aws_monthly > 0" | bc -l) -eq 1 ]]; then
        savings_percentage=$(echo "scale=2; ($aws_monthly - $oci_monthly) / $aws_monthly * 100" | bc -l)
    else
        savings_percentage="0"
    fi
    
    # Generate comparison JSON
    cat > "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json" << EOF
{
  "analysis_metadata": {
    "timestamp": "$(date -Iseconds)",
    "project": "$PROJECT_NAME",
    "environment": "$ENVIRONMENT",
    "duration_hours": $DURATION_HOURS,
    "aws_region": "$AWS_REGION",
    "oci_region": "$OCI_REGION",
    "free_tier_enabled": $INCLUDE_FREE_TIER
  },
  "cost_comparison": {
    "aws": {
      "monthly_cost": $aws_monthly,
      "annual_cost": $(echo "$aws_monthly * 12" | bc -l)
    },
    "oci": {
      "monthly_cost": $oci_monthly,
      "annual_cost": $(echo "$oci_monthly * 12" | bc -l)
    },
    "savings": {
      "absolute_monthly": $(echo "$aws_monthly - $oci_monthly" | bc -l),
      "absolute_annual": $(echo "($aws_monthly - $oci_monthly) * 12" | bc -l),
      "percentage": $savings_percentage
    }
  },
  "recommendations": [
    {
      "scenario": "Development & Testing",
      "recommended_provider": "OCI",
      "reasoning": "Generous free tier, cost-effective for non-production workloads",
      "estimated_savings": "$savings_percentage%"
    },
    {
      "scenario": "Production - High Performance",
      "recommended_provider": "AWS",
      "reasoning": "Mature ecosystem, advanced services, global reach",
      "estimated_savings": "N/A - Focus on performance over cost"
    },
    {
      "scenario": "Hybrid Approach",
      "recommended_provider": "Both",
      "reasoning": "Use OCI free tier for dev/test, AWS for production",
      "estimated_savings": "30-50% vs AWS-only"
    }
  ],
  "break_even_analysis": {
    "months_to_payback_oci_migration": $(echo "scale=2; if ($aws_monthly - $oci_monthly) > 0 then 100 / $savings_percentage else 0 end" | bc -l),
    "total_savings_first_year": $(echo "($aws_monthly - $oci_monthly) * 12" | bc -l)
  }
}
EOF
    
    log "INFO" "✅ Cost comparison generated"
}

# Generate HTML report
generate_html_report() {
    log "INFO" "Generating HTML cost report..."
    
    local report_file="$REPORTS_DIR/cost-report-$TIMESTAMP.html"
    
    # Extract data for HTML
    local aws_monthly
    local oci_monthly
    local savings_percentage
    aws_monthly=$(jq -r '.cost_comparison.aws.monthly_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    oci_monthly=$(jq -r '.cost_comparison.oci.monthly_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    savings_percentage=$(jq -r '.cost_comparison.savings.percentage' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Cloud Cost Analysis Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; font-size: 16px; }
        .metric .value { font-size: 28px; font-weight: bold; margin: 0; }
        .metric .subtext { font-size: 14px; opacity: 0.8; }
        .comparison { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px; }
        .provider { border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
        .aws { border-left: 4px solid #FF9900; }
        .oci { border-left: 4px solid #F80000; }
        .chart-container { margin: 30px 0; height: 400px; }
        .recommendations { margin-top: 30px; }
        .recommendation { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .recommendation h4 { margin: 0 0 10px 0; color: #333; }
        .savings { color: #28a745; font-weight: bold; }
        .timestamp { text-align: center; color: #666; margin-top: 30px; font-size: 14px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; font-weight: bold; }
        .highlight { background-color: #fff3cd; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>💰 Multi-Cloud Cost Analysis</h1>
            <p>Project: $PROJECT_NAME | Environment: $ENVIRONMENT | Duration: $DURATION_HOURS hours</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <h3>AWS Monthly Cost</h3>
                <div class="value">$(echo "$aws_monthly" | bc -l)</div>
                <div class="subtext">USD per month</div>
            </div>
            <div class="metric">
                <h3>OCI Monthly Cost</h3>
                <div class="value">$(echo "$oci_monthly" | bc -l)</div>
                <div class="subtext">USD per month</div>
            </div>
            <div class="metric">
                <h3>Monthly Savings</h3>
                <div class="value savings">$(echo "$aws_monthly - $oci_monthly" | bc -l)</div>
                <div class="subtext">$savings_percentage% with OCI</div>
            </div>
            <div class="metric">
                <h3>Annual Savings</h3>
                <div class="value savings">$(echo "($aws_monthly - $oci_monthly) * 12" | bc -l)</div>
                <div class="subtext">USD per year</div>
            </div>
        </div>
        
        <div class="comparison">
            <div class="provider aws">
                <h2>🚀 Amazon Web Services</h2>
                <table>
                    <tr><th>Instance Type</th><td>t3.small</td></tr>
                    <tr><th>Storage</th><td>100 GB GP3</td></tr>
                    <tr><th>Network</th><td>NAT Gateway + ALB</td></tr>
                    <tr><th>Monthly Cost</th><td class="highlight">$(echo "$aws_monthly" | bc -l) USD</td></tr>
                </table>
            </div>
            
            <div class="provider oci">
                <h2>🌟 Oracle Cloud Infrastructure</h2>
                <table>
                    <tr><th>Instance Type</th><td>VM.Standard.E2.1.Micro $([[ "$INCLUDE_FREE_TIER" == "true" ]] && echo "(Free Tier)")</td></tr>
                    <tr><th>Storage</th><td>100 GB Block Volume $([[ "$INCLUDE_FREE_TIER" == "true" ]] && echo "(10GB Free)")</td></tr>
                    <tr><th>Network</th><td>Flexible Load Balancer $([[ "$INCLUDE_FREE_TIER" == "true" ]] && echo "(Not Available in Free Tier)")</td></tr>
                    <tr><th>Monthly Cost</th><td class="highlight">$(echo "$oci_monthly" | bc -l) USD</td></tr>
                </table>
            </div>
        </div>
        
        <div class="chart-container">
            <canvas id="costChart"></canvas>
        </div>
        
        <div class="recommendations">
            <h2>📋 Recommendations</h2>
            
            <div class="recommendation">
                <h4>🧪 Development & Testing</h4>
                <p><strong>Oracle Cloud Infrastructure</strong> - Leverage the generous free tier for development and testing environments. Perfect for cost-conscious teams.</p>
            </div>
            
            <div class="recommendation">
                <h4>🏭 Production Workloads</h4>
                <p><strong>Amazon Web Services</strong> - Use for production workloads requiring advanced services, global reach, and mature ecosystem.</p>
            </div>
            
            <div class="recommendation">
                <h4>🌐 Hybrid Strategy (Recommended)</h4>
                <p><strong>Use Both Clouds</strong> - Deploy dev/test environments on OCI (free tier) and production on AWS. This approach can reduce costs by 30-50% while maintaining production reliability.</p>
            </div>
        </div>
        
        <div class="timestamp">
            <p>Generated on $(date)</p>
            <p>Analysis duration: $DURATION_HOURS hours | Free tier: $INCLUDE_FREE_TIER</p>
        </div>
    </div>
    
    <script>
        // Cost comparison chart
        const ctx = document.getElementById('costChart').getContext('2d');
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['AWS', 'OCI'],
                datasets: [{
                    label: 'Monthly Cost (USD)',
                    data: [$aws_monthly, $oci_monthly],
                    backgroundColor: ['#FF9900', '#F80000'],
                    borderColor: ['#FF6600', '#CC0000'],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    title: {
                        display: true,
                        text: 'Monthly Cost Comparison'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Cost (USD)'
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
EOF
    
    log "INFO" "✅ HTML report generated: $report_file"
}

# Generate CSV report
generate_csv_report() {
    log "INFO" "Generating CSV cost report..."
    
    local report_file="$REPORTS_DIR/cost-report-$TIMESTAMP.csv"
    
    # CSV Header
    echo "Provider,Region,Instance Type,Storage GB,Load Balancer,Monthly Cost,Annual Cost,Free Tier Benefits" > "$report_file"
    
    # AWS Row
    local aws_monthly
    local aws_annual
    aws_monthly=$(jq -r '.cost_comparison.aws.monthly_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    aws_annual=$(jq -r '.cost_comparison.aws.annual_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    echo "AWS,$AWS_REGION,t3.small,100,Yes,$aws_monthly,$aws_annual,None" >> "$report_file"
    
    # OCI Row
    local oci_monthly
    local oci_annual
    local free_tier_benefits
    oci_monthly=$(jq -r '.cost_comparison.oci.monthly_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    oci_annual=$(jq -r '.cost_comparison.oci.annual_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    free_tier_benefits=$([[ "$INCLUDE_FREE_TIER" == "true" ]] && echo "720 hours compute + 10GB storage" || echo "None")
    echo "OCI,$OCI_REGION,VM.Standard.E2.1.Micro,100,No,$oci_monthly,$oci_annual,$free_tier_benefits" >> "$report_file"
    
    log "INFO" "✅ CSV report generated: $report_file"
}

# Main execution function
main() {
    log "INFO" "💰 Starting Multi-Cloud Cost Analysis"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Get pricing data
    get_aws_pricing
    get_oci_pricing
    
    # Calculate costs
    calculate_aws_cost
    calculate_oci_cost
    
    # Generate comparison
    generate_comparison
    
    # Generate reports
    case $OUTPUT_FORMAT in
        "html")
            generate_html_report
            ;;
        "json")
            log "INFO" "JSON report available: $REPORTS_DIR/cost-comparison-$TIMESTAMP.json"
            ;;
        "csv")
            generate_csv_report
            ;;
        *)
            log "ERROR" "Unsupported output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    # Display summary
    echo ""
    echo "📊 COST ANALYSIS SUMMARY"
    echo "========================"
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Duration: $DURATION_HOURS hours"
    echo ""
    
    local aws_monthly
    local oci_monthly
    local savings_percentage
    aws_monthly=$(jq -r '.cost_comparison.aws.monthly_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    oci_monthly=$(jq -r '.cost_comparison.oci.monthly_cost' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    savings_percentage=$(jq -r '.cost_comparison.savings.percentage' "$REPORTS_DIR/cost-comparison-$TIMESTAMP.json")
    
    echo "AWS Monthly Cost: \$$aws_monthly"
    echo "OCI Monthly Cost: \$$oci_monthly"
    echo "Monthly Savings: \$$(( $(echo "$aws_monthly - $oci_monthly" | bc -l) )) ($savings_percentage%)"
    echo ""
    
    if [[ "$OUTPUT_FORMAT" == "html" ]]; then
        echo "📈 Interactive Report: $REPORTS_DIR/cost-report-$TIMESTAMP.html"
    fi
    echo "📄 Data Files: $REPORTS_DIR/cost-comparison-$TIMESTAMP.json"
    echo ""
    
    log "INFO" "✅ Cost analysis completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
