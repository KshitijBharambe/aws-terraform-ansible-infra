# Rollback Runbook

## Overview

This runbook provides procedures for rolling back infrastructure changes and recovering from failed deployments.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed and configured
- Access to the Git repository
- Backup of previous working state (if available)

## Rollback Scenarios

### Scenario 1: Terraform Apply Failed

#### Symptoms

- Terraform apply fails partway through deployment
- Resources are in inconsistent state
- Subsequent terraform operations fail

#### Rollback Procedure

1. **Check Current State**

   ```bash
   cd terraform/aws
   terraform show
   terraform plan
   ```

2. **Attempt to Fix State**

   ```bash
   terraform refresh
   terraform plan -destroy
   ```

3. **If Fails, Destroy and Recreate**

   ```bash
   terraform destroy -auto-approve
   terraform apply -auto-approve
   ```

4. **Restore from Backup** (if available)
   ```bash
   # Restore previous state file
   cp terraform.tfstate.backup terraform.tfstate
   terraform plan
   ```

### Scenario 2: Application Deployment Failed

#### Symptoms

- Infrastructure deployed successfully
- Ansible playbook fails
- Applications not functioning correctly

#### Rollback Procedure

1. **Check Ansible Status**

   ```bash
   cd ansible
   ansible-playbook --list-tasks playbooks/site.yml
   ```

2. **Rollback Application Configuration**

   ```bash
   # Run with rollback tags
   ansible-playbook -i inventory/aws_ec2.yml playbooks/rollback.yml
   ```

3. **Revert to Previous Configuration**
   ```bash
   git checkout <previous-working-commit>
   ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
   ```

### Scenario 3: Configuration Change Caused Issues

#### Symptoms

- Recent infrastructure changes cause service disruption
- Performance degradation
- Security issues detected

#### Rollback Procedure

1. **Identify Problematic Change**

   ```bash
   git log --oneline -10
   terraform plan
   ```

2. **Revert Terraform Configuration**

   ```bash
   git checkout <previous-working-commit>
   terraform plan
   terraform apply
   ```

3. **Rollback Ansible Configuration**
   ```bash
   cd ansible
   git checkout <previous-working-commit>
   ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
   ```

### Scenario 4: Database or Data Issues

#### Symptoms

- Data corruption detected
- Database not accessible
- Application errors related to data

#### Rollback Procedure

1. **Check Backup Status**

   ```bash
   aws backup list-backup-jobs --by-resource-arn <database-arn>
   aws backup list-recovery-points --by-resource-arn <database-arn>
   ```

2. **Restore from Backup**

   ```bash
   aws backup start-restore-job \
     --recovery-point-arn <recovery-point-arn> \
     --metadata file://restore-metadata.json
   ```

3. **Verify Data Integrity**
   ```bash
   # Application-specific data verification
   ansible-playbook -i inventory/aws_ec2.yml playbooks/verify-data.yml
   ```

## Emergency Rollback Procedures

### Complete Infrastructure Rollback

1. **Stop All Deployments**

   ```bash
   # Cancel any running deployments
   pkill -f terraform
   pkill -f ansible-playbook
   ```

2. **Destroy Current Infrastructure**

   ```bash
   cd terraform/aws
   terraform destroy -auto-approve
   ```

3. **Restore from Known Good State**
   ```bash
   git checkout <known-good-commit>
   terraform apply -auto-approve
   ```

### Service-Specific Rollback

#### Web Server Rollback

```bash
# Restart web services
ansible webservers -i inventory/aws_ec2.yml -m service -a "name=httpd state=restarted"

# Revert configuration
ansible webservers -i inventory/aws_ec2.yml -m copy -a "src=backup/httpd.conf dest=/etc/httpd/conf/httpd.conf"
ansible webservers -i inventory/aws_ec2.yml -m service -a "name=httpd state=restarted"
```

#### Application Server Rollback

```bash
# Restart application
ansible appservers -i inventory/aws_ec2.yml -m service -a "name=app state=restarted"

# Revert to previous version
ansible appservers -i inventory/aws_ec2.yml -m git -a "repo=/opt/app dest=/opt/app version=<previous-commit>"
ansible appservers -i inventory/aws_ec2.yml -m service -a "name=app state=restarted"
```

## Rollback Validation

### Infrastructure Validation

```bash
# Check Terraform state
terraform show
terraform validate

# Verify resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=infra-demo"
aws elb describe-load-balancers
```

### Application Validation

```bash
# Health checks
ansible all -i inventory/aws_ec2.yml -m uri -a "url=http://localhost:8080/health"

# Service status
ansible all -i inventory/aws_ec2.yml -m service -a "name=app state=started"
```

### End-to-End Validation

```bash
# Integration tests
./tests/integration/smoke-test.sh

# Security scans
./tests/security/compliance-test.sh
```

## Rollback Communication

### Team Notification

1. **Alert Team**: Send notification via Slack/Email
2. **Update Status**: Update incident management system
3. **Document**: Record rollback in runbook log

### Stakeholder Communication

1. **Service Status**: Update status page
2. **Impact Assessment**: Communicate affected services
3. **ETA**: Provide estimated resolution time

## Rollback Prevention

### Pre-Deployment Checks

1. **Test in Staging**: Always test in non-production environment
2. **Backup State**: Create terraform state backup before changes
3. **Rollback Plan**: Document rollback procedure before deployment
4. **Rollback Window**: Schedule maintenance window if needed

### Monitoring During Deployment

1. **Real-time Monitoring**: Monitor all critical metrics
2. **Automated Rollback**: Configure automatic rollback triggers
3. **Health Checks**: Continuous health verification
4. **Rollback Ready**: Keep rollback procedures ready

## Rollback Documentation

### Required Information

- Deployment timestamp
- Changes made
- Rollback reason
- Rollback steps taken
- Validation results
- Lessons learned

### Template

```markdown
## Rollback - [Date]

**Reason**: [Why rollback was necessary]
**Changes Made**: [List of changes that caused issues]
**Rollback Time**: [Start and end time]
**Rollback Steps**: [Detailed rollback procedure]
**Validation**: [How rollback was verified]
**Impact**: [Service impact during rollback]
**Lessons Learned**: [What could be improved]
```

## Contacts and Escalation

### Primary Contacts

- **Infrastructure Lead**: [Contact information]
- **Application Lead**: [Contact information]
- **Security Team**: [Contact information]

### Escalation Path

1. **Level 1**: On-call engineer
2. **Level 2**: Team lead
3. **Level 3**: Engineering manager
4. **Level 4**: CTO/VP Engineering

## Rollback Tools and Scripts

### Automated Rollback Script

```bash
#!/bin/bash
# rollback.sh - Automated rollback script

set -euo pipefail

ENVIRONMENT=${1:-"production"}
ROLLBACK_REASON=${2:-"Manual rollback"}

echo "Starting rollback for $ENVIRONMENT"
echo "Reason: $ROLLBACK_REASON"

# Backup current state
cp terraform/aws/terraform.tfstate terraform/aws/terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# Perform rollback
cd terraform/aws
terraform destroy -auto-approve
git checkout HEAD~1  # Previous commit
terraform apply -auto-approve

echo "Rollback completed for $ENVIRONMENT"
```

### Rollback Validation Script

```bash
#!/bin/bash
# validate-rollback.sh - Validate rollback success

set -euo pipefail

echo "Validating rollback..."

# Check infrastructure
terraform show
aws ec2 describe-instances --filters "Name=tag:Project,Values=infra-demo"

# Check applications
curl -f http://<load-balancer-dns>/health || exit 1

echo "Rollback validation successful"
```

## Rollback Success Criteria

### Infrastructure Success

- [ ] All Terraform resources in desired state
- [ ] No Terraform drift detected
- [ ] All security groups correctly configured
- [ ] Load balancer health checks passing

### Application Success

- [ ] All services running correctly
- [ ] Health checks passing
- [ ] No application errors in logs
- [ ] Database connectivity working

### Monitoring Success

- [ ] No critical alarms triggered
- [ ] Normal performance metrics
- [ ] Log volumes within expected ranges
- [ ] User experience not degraded
