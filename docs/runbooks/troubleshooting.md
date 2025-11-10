# Troubleshooting Runbook

## Overview

This runbook provides systematic troubleshooting procedures for common infrastructure and application issues.

## Prerequisites

- Access to AWS Console and CLI
- Terraform and Ansible installed
- Monitoring dashboards available
- Access to logs and metrics

## Common Issues and Solutions

### Issue 1: Infrastructure Deployment Failures

#### Symptom: Terraform Apply Fails

**Possible Causes:**

- Insufficient permissions
- Resource limits exceeded
- Configuration errors
- Network issues
- Resource conflicts

**Troubleshooting Steps:**

1. **Check Terraform Error Message**

   ```bash
   cd terraform/aws
   terraform plan
   terraform apply -detailed-exitcode
   ```

2. **Verify Permissions**

   ```bash
   aws sts get-caller-identity
   aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query User.UserName --output text)
   ```

3. **Check Service Limits**

   ```bash
   aws service-quotas list-service-quotas --service-code ec2
   aws service-quotas list-service-quotas --service-code vpc
   ```

4. **Validate Configuration**
   ```bash
   terraform validate
   terraform fmt -check
   ```

**Solutions:**

- Request limit increases through AWS Support
- Fix configuration errors
- Update IAM permissions
- Use different resource names

#### Symptom: Module Not Found

**Possible Causes:**

- Incorrect module path
- Missing module files
- Git submodule issues

**Troubleshooting Steps:**

1. **Check Module Structure**

   ```bash
   find terraform/modules -name "*.tf" -type f
   ls -la terraform/modules/
   ```

2. **Verify Module References**

   ```bash
   grep -r "source.*modules" terraform/
   ```

3. **Reinitialize Terraform**
   ```bash
   rm -rf .terraform .terraform.lock.hcl
   terraform init
   ```

**Solutions:**

- Fix module paths in configuration
- Reinitialize Terraform
- Check Git repository integrity

### Issue 2: Instance Access Problems

#### Symptom: Cannot SSH to Instances

**Possible Causes:**

- Security group rules
- SSH key issues
- Instance not running
- Network problems

**Troubleshooting Steps:**

1. **Check Instance Status**

   ```bash
   aws ec2 describe-instances --filters "Name=tag:Project,Values=infra-demo" --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]"
   ```

2. **Verify Security Groups**

   ```bash
   aws ec2 describe-security-groups --filters "Name=tag:Project,Values=infra-demo"
   ```

3. **Check SSH Key**

   ```bash
   aws ec2 describe-key-pairs --key-names <your-key-name>
   ```

4. **Test Network Connectivity**
   ```bash
   # Test basic connectivity
   ping <instance-public-ip>
   telnet <instance-public-ip> 22
   ```

**Solutions:**

- Add SSH rule to security group
- Use correct SSH key
- Check instance state
- Verify network configuration

#### Symptom: Instance Not Accessible via HTTP/HTTPS

**Possible Causes:**

- Web server not running
- Security group blocking ports
- Load balancer misconfiguration
- DNS issues

**Troubleshooting Steps:**

1. **Check Web Server Status**

   ```bash
   ansible webservers -i inventory/aws_ec2.yml -m service -a "name=httpd state=started"
   ```

2. **Verify Security Group Rules**

   ```bash
   aws ec2 describe-security-groups --filters "Name=tag:Project,Values=infra-demo" --query "SecurityGroups[*].IpPermissions"
   ```

3. **Check Load Balancer**

   ```bash
   aws elbv2 describe-load-balancers --names <load-balancer-name>
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   ```

4. **Test Local Connectivity**
   ```bash
   # From within instance
   curl -I http://localhost:80
   curl -I http://localhost:443
   ```

**Solutions:**

- Start web server service
- Add HTTP/HTTPS rules to security group
- Fix load balancer configuration
- Check DNS resolution

### Issue 3: Application Performance Issues

#### Symptom: Slow Response Times

**Possible Causes:**

- High CPU usage
- Memory constraints
- Network latency
- Database performance
- Load balancer issues

**Troubleshooting Steps:**

1. **Check Instance Metrics**

   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/EC2 \
     --metric-name CPUUtilization \
     --dimensions Name=InstanceId,Value=<instance-id> \
     --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --period 300
   ```

2. **Check Memory Usage**

   ```bash
   ansible all -i inventory/aws_ec2.yml -m shell -a "free -h"
   ```

3. **Monitor Network Performance**

   ```bash
   ansible all -i inventory/aws_ec2.yml -m shell -a "ss -tuln"
   ```

4. **Check Application Logs**
   ```bash
   ansible all -i inventory/aws_ec2.yml -m shell -a "tail -100 /var/log/httpd/access_log"
   ```

**Solutions:**

- Scale up instance type
- Optimize application code
- Add caching
- Use load balancer

#### Symptom: High Error Rates

**Possible Causes:**

- Application bugs
- Resource exhaustion
- Database connection issues
- Configuration errors

**Troubleshooting Steps:**

1. **Check Error Logs**

   ```bash
   ansible all -i inventory/aws_ec2.yml -m shell -a "tail -50 /var/log/httpd/error_log"
   ```

2. **Monitor Application Health**

   ```bash
   curl -f http://localhost:8080/health || echo "Health check failed"
   ```

3. **Check Database Connectivity**
   ```bash
   ansible appservers -i inventory/aws_ec2.yml -m shell -a "mysql -h localhost -u root -p -e 'SELECT 1'"
   ```

**Solutions:**

- Fix application bugs
- Increase resources
- Fix database configuration
- Update application settings

### Issue 4: Security Issues

#### Symptom: Security Violations Detected

**Possible Causes:**

- Open security groups
- Unencrypted data
- Weak passwords
- Outdated software

**Troubleshooting Steps:**

1. **Run Security Scan**

   ```bash
   ./tests/security/compliance-test.sh
   ```

2. **Check Security Groups**

   ```bash
   aws ec2 describe-security-groups --filters "Name=tag:Project,Values=infra-demo"
   ```

3. **Verify Encryption**

   ```bash
   aws ec2 describe-volumes --filters "Name=tag:Project,Values=infra-demo" --query "Volumes[*].Encrypted"
   ```

4. **Check for Vulnerabilities**
   ```bash
   ansible all -i inventory/aws_ec2.yml -m shell -a "yum updateinfo summary security"
   ```

**Solutions:**

- Restrict security group rules
- Enable encryption
- Update software
- Implement security best practices

#### Symptom: Authentication Failures

**Possible Causes:**

- Expired credentials
- Incorrect permissions
- MFA issues
- Account lockout

**Troubleshooting Steps:**

1. **Test AWS Credentials**

   ```bash
   aws sts get-caller-identity
   aws s3 ls
   ```

2. **Check IAM Permissions**

   ```bash
   aws iam simulate-principal-policy \
     --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
     --policy-document file://test-policy.json
   ```

3. **Verify MFA Status**
   ```bash
   aws iam get-user --user-name $(aws sts get-caller-identity --query User.UserName --output text)
   ```

**Solutions:**

- Refresh credentials
- Update IAM permissions
- Configure MFA
- Unlock account

### Issue 5: Cost and Billing Issues

#### Symptom: Unexpected High Costs

**Possible Causes:**

- Overprovisioned resources
- Data transfer costs
- Unused resources
- Pricing tier changes

**Troubleshooting Steps:**

1. **Check Cost Explorer**

   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '1 month ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
     --granularity MONTHLY \
     --group-by Type=DIMENSION,Key=SERVICE
   ```

2. **Analyze Resource Usage**

   ```bash
   aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]"
   ```

3. **Check Data Transfer**
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '1 month ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
     --filter "Type=DIMENSION,Key=SERVICE,Values=AmazonEC2" \
     --group-by Type=DIMENSION,Key=USAGE_TYPE
   ```

**Solutions:**

- Downsize resources
- Use Reserved Instances
- Optimize data transfer
- Clean up unused resources

#### Symptom: Budget Alerts Triggered

**Possible Causes:**

- Increased usage
- New services deployed
- Price changes
- Forecasting errors

**Troubleshooting Steps:**

1. **Check Budget Status**

   ```bash
   aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text)
   ```

2. **Review Recent Changes**

   ```bash
   git log --oneline -10
   terraform show
   ```

3. **Analyze Cost Drivers**
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
     --granularity DAILY
   ```

**Solutions:**

- Scale back resources
- Implement cost controls
- Review deployment changes
- Adjust budget thresholds

## Diagnostic Tools and Scripts

### Health Check Script

```bash
#!/bin/bash
# health-check.sh - Comprehensive health check

echo "=== Infrastructure Health Check ==="

# Check Terraform state
echo "Checking Terraform state..."
cd terraform/aws
terraform show > /dev/null 2>&1 && echo "✓ Terraform state valid" || echo "✗ Terraform state invalid"

# Check AWS connectivity
echo "Checking AWS connectivity..."
aws sts get-caller-identity > /dev/null 2>&1 && echo "✓ AWS connectivity OK" || echo "✗ AWS connectivity failed"

# Check instances
echo "Checking instances..."
INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=infra-demo" --query "Reservations[*].Instances[*].[InstanceId,State.Name]" --output text)
echo "$INSTANCES" | while read instance state; do
    echo "Instance $instance: $state"
done

# Check load balancer
echo "Checking load balancer..."
LB_DNS=$(terraform output -raw load_balancer_dns_name 2>/dev/null)
if [ -n "$LB_DNS" ]; then
    curl -f http://$LB_DNS/health > /dev/null 2>&1 && echo "✓ Load balancer healthy" || echo "✗ Load balancer unhealthy"
fi

echo "=== Health Check Complete ==="
```

### Log Collection Script

```bash
#!/bin/bash
# collect-logs.sh - Collect logs from all instances

LOG_DIR="logs/$(date +%Y%m%d_%H%M%S)"
mkdir -p $LOG_DIR

echo "Collecting logs to $LOG_DIR..."

# Collect system logs
ansible all -i inventory/aws_ec2.yml -m fetch -a "src=/var/log/messages dest=$LOG_DIR/{{ inventory_hostname }}-messages.log flat=yes"

# Collect application logs
ansible all -i inventory/aws_ec2.yml -m fetch -a "src=/var/log/httpd/ dest=$LOG_DIR/{{ inventory_hostname }}-apache/ flat=yes"

# Collect CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/infra-demo" --query "logGroups[*].logGroupName" --output text | while read log_group; do
    aws logs filter-log-events --log-group-name "$log_group" --start-time $(date -d '1 hour ago' +%s)000 > "$LOG_DIR/$(basename $log_group).log"
done

echo "Logs collected to $LOG_DIR"
```

### Performance Test Script

```bash
#!/bin/bash
# performance-test.sh - Basic performance testing

LB_DNS=$(cd terraform/aws && terraform output -raw load_balancer_dns_name)
TEST_URL="http://$LB_DNS"

echo "Testing performance of $TEST_URL"

# Response time test
echo "=== Response Time Test ==="
for i in {1..10}; do
    response_time=$(curl -o /dev/null -s -w "%{time_total}" $TEST_URL)
    echo "Request $i: ${response_time}s"
done

# Concurrent connections test
echo "=== Concurrent Connections Test ==="
for concurrent in 1 5 10 20; do
    echo "Testing $concurrent concurrent connections..."
    ab -n 100 -c $concurrent $TEST_URL | grep "Requests per second"
done

# Load test
echo "=== Load Test ==="
hey -n 1000 -c 10 $TEST_URL
```

## Escalation Procedures

### Level 1: Basic Issues

- **Response Time**: Within 1 hour
- **Tools Available**: Basic diagnostics, logs
- **Escalation**: Team lead if not resolved in 1 hour

### Level 2: Complex Issues

- **Response Time**: Within 4 hours
- **Tools Available**: Advanced diagnostics, performance analysis
- **Escalation**: Engineering manager if not resolved in 4 hours

### Level 3: Critical Issues

- **Response Time**: Within 30 minutes
- **Tools Available**: Full system access, emergency procedures
- **Escalation**: CTO/VP Engineering immediately

## Contact Information

### On-Call Rotation

- **Primary**: [Contact information]
- **Secondary**: [Contact information]
- **Escalation**: [Contact information]

### Support Channels

- **Slack**: #infrastructure-alerts
- **Email**: infrastructure@company.com
- **Phone**: [Emergency phone number]

## Prevention and Monitoring

### Proactive Monitoring

1. **Set up Alerts**: Configure CloudWatch alarms for critical metrics
2. **Regular Health Checks**: Implement automated health checks
3. **Log Monitoring**: Set up log aggregation and alerting
4. **Performance Monitoring**: Monitor response times and error rates

### Regular Maintenance

1. **Security Updates**: Schedule regular patch updates
2. **Capacity Planning**: Review resource utilization monthly
3. **Cost Review**: Analyze costs and optimize spending
4. **Documentation**: Keep runbooks up to date

### Testing and Validation

1. **Staging Environment**: Test all changes in staging
2. **Rollback Tests**: Regularly test rollback procedures
3. **Disaster Recovery**: Test disaster recovery plans
4. **Performance Testing**: Regular performance benchmarks
