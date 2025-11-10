# Disaster Recovery Runbook

## Overview

This runbook provides procedures for recovering from major infrastructure disasters, including complete region outages, data corruption, and security breaches.

## Prerequisites

- AWS CLI with administrative permissions
- Access to backup systems
- Communication channels established
- Disaster recovery team assembled

## Disaster Scenarios

### Scenario 1: Complete Region Outage

#### Symptoms

- No access to AWS services in primary region
- All instances unreachable
- Applications completely unavailable
- Monitoring systems offline

#### Recovery Procedure

1. **Activate Incident Response**

   ```bash
   # Declare disaster
   echo "DISASTER DECLARED: Region outage in $(aws configure get region)"
   # Notify team
   slack-cli send "#infrastructure-alerts" "🚨 Region outage detected"
   ```

2. **Assess Impact Scope**

   ```bash
   # Check multiple regions
   for region in us-east-1 us-west-2 eu-west-1; do
       aws --region $region sts get-caller-identity --output text || echo "$region: Unavailable"
   done

   # Check service health dashboard
   curl -s "https://status.aws.amazon.com/api/v1/events.json" | jq '.'
   ```

3. **Initiate Failover**

   ```bash
   # Deploy to backup region
   export AWS_DEFAULT_REGION=us-west-2
   cd terraform/aws
   terraform apply -var="enable_multi_region=true" -var="backup_region=us-west-2"

   # Update DNS to point to backup region
   ./scripts/update-dns-failover.sh us-west-2
   ```

4. **Validate Recovery**

   ```bash
   # Test backup infrastructure
   aws --region us-west-2 ec2 describe-instances --filters "Name=tag:Environment,Values=disaster-recovery"
   curl -f https://backup.infra.company.com/health
   ```

5. **Communicate Status**
   ```bash
   # Update stakeholders
   slack-cli send "#stakeholders" "Infrastructure recovered in backup region"
   # Update status page
   ./scripts/update-status-page.sh "Infrastructure operational in backup region"
   ```

#### Post-Recovery Actions

1. **Monitor Performance**

   ```bash
   # Watch for issues in backup region
   watch -n 60 'aws --region us-west-2 cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization'
   ```

2. **Plan Return to Primary**

   ```bash
   # Monitor primary region recovery
   while ! aws --region us-east-1 sts get-caller-identity; do
       sleep 300  # Check every 5 minutes
   done

   # Plan failback when primary is stable
   ```

### Scenario 2: Data Corruption or Loss

#### Symptoms

- Database corruption detected
- Critical data missing
- Application data inconsistency
- Backup verification failures

#### Recovery Procedure

1. **Isolate Affected Systems**

   ```bash
   # Stop applications to prevent further corruption
   ansible all -i inventory/aws_ec2.yml -m service -a "name=app state=stopped"

   # Take filesystem snapshots
   aws ec2 create-snapshot --volume-id <volume-id> --description "Disaster recovery snapshot"
   ```

2. **Assess Data Integrity**

   ```bash
   # Check backup integrity
   aws backup list-recovery-points --by-resource-arn <database-arn>

   # Verify backup chain
   ./scripts/verify-backup-chain.sh <database-arn>
   ```

3. **Restore from Backup**

   ```bash
   # Identify last known good backup
   GOOD_BACKUP=$(aws backup list-recovery-points --by-resource-arn <database-arn> \
     --query "RecoveryPoints[?CreationDate<=\`$(date -d '24 hours ago' --iso-8601)\`] | sort_by(CreationDate) | [-1].RecoveryPointArn" \
     --output text)

   # Initiate restore
   aws backup start-restore-job \
     --recovery-point-arn $GOOD_BACKUP \
     --metadata '{"restoreType":"full","targetDatabase":"infrastructure-restored"}'
   ```

4. **Validate Restored Data**

   ```bash
   # Data integrity checks
   ansible appservers -i inventory/aws_ec2.yml -m script -a "scripts/validate-restored-data.sh"

   # Application-specific validation
   ./scripts/run-data-validation-tests.sh
   ```

5. **Resume Operations**

   ```bash
   # Restart applications
   ansible all -i inventory/aws_ec2.yml -m service -a "name=app state=started"

   # Monitor for issues
   ./scripts/monitor-post-restore.sh
   ```

#### Post-Restore Actions

1. **Root Cause Analysis**

   ```bash
   # Analyze corruption source
   ./scripts/analyze-data-corruption.sh

   # Review recent changes
   git log --oneline -20
   ansible all -i inventory/aws_ec2.yml -m shell -a "find /var/log -name '*.log' -mtime -2"
   ```

2. **Implement Preventive Measures**

   ```bash
   # Increase backup frequency
   aws backup put-backup-plan \
     --backup-plan-name enhanced-plan \
     --backup-rule '{"ruleName":"hourly-backup","scheduleExpression":"rate(1 hour)"}'

   # Implement data validation
   ./scripts/setup-data-validation.sh
   ```

### Scenario 3: Security Breach

#### Symptoms

- Unauthorized access detected
- Malware or ransomware present
- Data exfiltration detected
- Security alerts triggered

#### Recovery Procedure

1. **Immediate Containment**

   ```bash
   # Isolate affected systems
   aws ec2 revoke-security-group-ingress --group-id <sg-id> --protocol all --port all --source 0.0.0.0/0

   # Stop compromised instances
   aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Status,Values=compromised" --query "Instances[*].InstanceId" --output text)

   # Change all credentials
   ./scripts/rotate-all-credentials.sh
   ```

2. **Assess Breach Scope**

   ```bash
   # Security investigation
   aws guardd get-findings --severity HIGH,CRITICAL

   # Check CloudTrail logs
   aws cloudtrail lookup-events --start-time $(date -d '24 hours ago' --iso-8601) \
     --lookup-attributes AttributeKey=EventName,AttributeValues=RunInstances,TerminateInstances

   # Analyze access patterns
   ./scripts/analyze-security-logs.sh
   ```

3. **Eradicate Threats**

   ```bash
   # Deploy clean infrastructure
   cd terraform/aws
   terraform apply -var="security_profile=hardened" -var="enable_security_monitoring=true"

   # Restore from clean backup
   aws backup start-restore-job \
     --recovery-point-arn <clean-backup-arn> \
     --metadata '{"restoreType":"full","securityScan":true}'
   ```

4. **Recover and Secure**

   ```bash
   # Enhanced security configuration
   ansible-playbook -i inventory/aws_ec2.yml playbooks/security-hardening.yml

   # Deploy monitoring
   ansible-playbook -i inventory/aws_ec2.yml playbooks/security-monitoring.yml

   # Validate security posture
   ./tests/security/compliance-test.sh
   ```

5. **Post-Incident Response**

   ```bash
   # Forensic analysis
   ./scripts/forensic-analysis.sh

   # Document lessons learned
   ./scripts/create-incident-report.sh

   # Update security policies
   ./scripts/update-security-policies.sh
   ```

### Scenario 4: Multi-Cloud Disaster

#### Symptoms

- Primary cloud provider completely unavailable
- Cross-cloud replication failed
- No access to management interfaces
- Complete service outage

#### Recovery Procedure

1. **Activate Backup Cloud Provider**

   ```bash
   # Switch to backup provider (OCI)
   cd terraform/oci
   terraform apply -var="disaster_recovery=true"

   # Update DNS to point to OCI infrastructure
   ./scripts/update-dns-multi-cloud.sh oci
   ```

2. **Data Synchronization**

   ```bash
   # Initiate cross-cloud data sync
   ./scripts/cross-cloud-sync.sh aws oci

   # Validate data integrity
   ./scripts/validate-cross-cloud-data.sh
   ```

3. **Service Restoration**

   ```bash
   # Update application configuration for new provider
   ansible-playbook -i inventory/oci.yml playbooks/site.yml

   # Test functionality
   ./tests/integration/smoke-test.sh --provider=oci
   ```

## Recovery Tools and Scripts

### Automated Disaster Recovery Script

```bash
#!/bin/bash
# disaster-recovery.sh - Automated disaster recovery

set -euo pipefail

DISASTER_TYPE=${1:-"region"}
BACKUP_REGION=${2:-"us-west-2"}

echo "=== DISASTER RECOVERY INITIATED ==="
echo "Disaster Type: $DISASTER_TYPE"
echo "Backup Region: $BACKUP_REGION"
echo "Time: $(date)"

case $DISASTER_TYPE in
    "region")
        echo "Initiating region failover..."
        ./scripts/region-failover.sh $BACKUP_REGION
        ;;
    "data")
        echo "Initiating data recovery..."
        ./scripts/data-recovery.sh
        ;;
    "security")
        echo "Initiating security incident response..."
        ./scripts/security-incident-response.sh
        ;;
    "multi-cloud")
        echo "Initiating multi-cloud failover..."
        ./scripts/multi-cloud-failover.sh
        ;;
    *)
        echo "Unknown disaster type: $DISASTER_TYPE"
        exit 1
        ;;
esac

echo "Disaster recovery procedures initiated"
```

### Health Validation Script

```bash
#!/bin/bash
# validate-recovery.sh - Validate disaster recovery success

set -euo pipefail

echo "=== RECOVERY VALIDATION ==="

# Check infrastructure status
echo "Checking infrastructure status..."
terraform show > /dev/null && echo "✓ Terraform state valid" || echo "✗ Terraform state invalid"

# Check service availability
echo "Checking service availability..."
if curl -f https://infra.company.com/health; then
    echo "✓ Services accessible"
else
    echo "✗ Services not accessible"
    exit 1
fi

# Check data integrity
echo "Checking data integrity..."
./scripts/verify-data-integrity.sh && echo "✓ Data integrity verified" || echo "✗ Data integrity compromised"

# Check security posture
echo "Checking security posture..."
./tests/security/compliance-test.sh && echo "✓ Security posture acceptable" || echo "✗ Security issues detected"

echo "=== RECOVERY VALIDATION COMPLETE ==="
```

### Communication Script

```bash
#!/bin/bash
# notify-stakeholders.sh - Notify stakeholders of disaster status

set -euo pipefail

STATUS=${1:-"disaster_declared"}
MESSAGE=${2:-"Disaster recovery procedures initiated"}
CHANNEL=${3:-"#infrastructure-alerts"}

echo "Notifying stakeholders: $STATUS"

# Slack notification
slack-cli send "$CHANNEL" "$MESSAGE"

# Email notification
echo "$MESSAGE" | mail -s "Infrastructure Alert: $STATUS" stakeholders@company.com

# Status page update
curl -X POST https://status.company.com/api/update \
  -H "Content-Type: application/json" \
  -d "{\"status\":\"$STATUS\",\"message\":\"$MESSAGE\",\"timestamp\":\"$(date -Iseconds)\"}"

echo "Stakeholders notified"
```

## Recovery Time Objectives (RTO/RPO)

### Service Recovery Objectives

| Service              | RTO (Recovery Time) | RPO (Recovery Point) | Priority |
| -------------------- | ------------------- | -------------------- | -------- |
| Web Services         | 4 hours             | 1 hour               | Critical |
| Application Services | 2 hours             | 15 minutes           | Critical |
| Database             | 2 hours             | 15 minutes           | Critical |
| Authentication       | 1 hour              | 5 minutes            | Critical |
| Monitoring           | 1 hour              | 5 minutes            | High     |

### Infrastructure Recovery Objectives

| Component       | RTO     | RPO    | Backup Strategy      |
| --------------- | ------- | ------ | -------------------- |
| EC2 Instances   | 4 hours | 1 hour | AMI backups          |
| VPC/Networking  | 1 hour  | N/A    | IaC repository       |
| Load Balancer   | 2 hours | N/A    | Configuration backup |
| Security Groups | 1 hour  | N/A    | IaC repository       |
| IAM Roles       | 2 hours | N/A    | Configuration backup |

## Testing and Drills

### Regular Disaster Recovery Tests

#### Monthly Tabletop Exercises

- Review disaster recovery procedures
- Test communication channels
- Validate team roles and responsibilities
- Update contact information

#### Quarterly Failover Tests

- Test actual failover to backup region
- Validate data synchronization
- Test DNS failover procedures
- Measure actual RTO/RPO

#### Annual Full-Scale Drill

- Complete disaster simulation
- End-to-end recovery test
- Multi-cloud failover validation
- Stakeholder communication test

### Test Validation Checklist

```markdown
## Disaster Recovery Test - [Date]

### Pre-Test Preparation

- [ ] Stakeholders notified of test window
- [ ] Backup systems verified
- [ ] Communication channels tested
- [ ] Recovery team assembled

### Test Execution

- [ ] Disaster scenario initiated
- [ ] Recovery procedures followed
- [ ] Systems failed over successfully
- [ ] Services restored in backup environment

### Post-Test Validation

- [ ] All services operational
- [ ] Data integrity verified
- [ ] Performance acceptable
- [ ] Security posture maintained
- [ ] RTO objectives met
- [ ] RPO objectives met

### Test Documentation

- [ ] Lessons learned documented
- [ ] Procedures updated
- [ ] Team feedback collected
- [ ] Stakeholder debrief completed
```

## Contact Information

### Disaster Recovery Team

| Role                | Name   | Contact       | Backup           |
| ------------------- | ------ | ------------- | ---------------- |
| Incident Commander  | [Name] | [Phone/Email] | [Backup Contact] |
| Technical Lead      | [Name] | [Phone/Email] | [Backup Contact] |
| Communications Lead | [Name] | [Phone/Email] | [Backup Contact] |
| Security Lead       | [Name] | [Phone/Email] | [Backup Contact] |

### Escalation Contacts

| Level | Contact             | Trigger            | Response Time |
| ----- | ------------------- | ------------------ | ------------- |
| 1     | On-call Engineer    | Initial incident   | 15 minutes    |
| 2     | Team Lead           | Level 1 escalation | 1 hour        |
| 3     | Engineering Manager | Level 2 escalation | 2 hours       |
| 4     | CTO/VP Engineering  | Major incident     | 30 minutes    |

## Documentation and Reporting

### Incident Report Template

```markdown
# Disaster Recovery Incident Report

## Incident Summary

- **Incident ID**: [Unique identifier]
- **Start Time**: [Date and time]
- **End Time**: [Date and time]
- **Duration**: [Total time]
- **Severity**: [Critical/High/Medium/Low]
- **Impact**: [Description of impact]

## Root Cause Analysis

- **Primary Cause**: [Root cause description]
- **Contributing Factors**: [Additional factors]
- **Timeline**: [Detailed event timeline]

## Recovery Actions

- **Immediate Actions**: [Actions taken in first hour]
- **Recovery Procedures**: [Procedures followed]
- **Challenges**: [Difficulties encountered]
- **Workarounds**: [Temporary solutions used]

## Post-Incident Actions

- **Preventive Measures**: [Actions to prevent recurrence]
- **Procedure Updates**: [Changes to disaster recovery procedures]
- **Team Training**: [Training conducted]
- **Tool Improvements**: [Tools or automation added]

## Lessons Learned

- **What Went Well**: [Positive aspects of response]
- **What Could Be Improved**: [Areas for improvement]
- **Recommendations**: [Specific recommendations]
- **Follow-up Actions**: [Items requiring follow-up]
```

## Continuous Improvement

### Metrics to Track

1. **Recovery Time Objectives**

   - Actual RTO vs. Target RTO
   - Actual RPO vs. Target RPO
   - Time to detect incidents
   - Time to initiate recovery

2. **Service Availability**

   - Uptime percentage during disaster
   - Services affected by disaster
   - Customer impact assessment
   - Financial impact measurement

3. **Process Effectiveness**
   - Procedure completion rates
   - Team response times
   - Communication effectiveness
   - Tool and automation usage

### Review Schedule

- **Weekly**: Review disaster recovery drills
- **Monthly**: Update contact information and procedures
- **Quarterly**: Full procedure review and updates
- **Annually**: Comprehensive disaster recovery planning review

### Automation Opportunities

1. **Automated Detection**

   - Real-time monitoring integration
   - Automated failure detection
   - Predictive failure analysis

2. **Automated Response**

   - Self-healing capabilities
   - Automated failover procedures
   - Automatic notification systems

3. **Automated Recovery**
   - One-click recovery procedures
   - Automated infrastructure provisioning
   - Automated data restoration
