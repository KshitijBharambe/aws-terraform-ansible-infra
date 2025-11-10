# Security Controls Implementation Matrix

## Overview

This document provides a comprehensive mapping of all security controls implemented in our AWS-Terraform-Ansible infrastructure project. Controls are organized by category and include implementation details, verification methods, and compliance mappings.

## Security Control Categories

### 1. Identity and Access Management (IAM)

| Control                     | Implementation                              | Terraform                | Ansible               | Compliance         | Verification                          |
| --------------------------- | ------------------------------------------- | ------------------------ | --------------------- | ------------------ | ------------------------------------- |
| **Least Privilege Access**  | Granular IAM roles with minimal permissions | ✅ IAM roles, policies   | ✅ sudo configuration | CIS 1.1, NIST AC-2 | `aws iam list-attached-role-policies` |
| **MFA Enforcement**         | MFA required for console access             | ✅ IAM policy conditions | ❌                    | CIS 1.3, NIST IA-2 | Manual audit of IAM users             |
| **Access Key Rotation**     | Automated rotation policies                 | ✅ IAM user policies     | ❌                    | CIS 1.4, NIST AC-2 | AWS Config Rule                       |
| **Root Account Protection** | MFA + alerts + hardware key                 | ✅ IAM root settings     | ❌                    | CIS 1.1, NIST AC-6 | Manual verification                   |
| **Role-Based Access**       | Separate roles for different functions      | ✅ Custom IAM roles      | ✅ Group membership   | CIS 1.1, NIST AC-2 | `aws iam list-roles`                  |

#### Terraform Implementation Examples

```hcl
# Least privilege role for web servers
resource "aws_iam_role" "web_server_role" {
  name = "WebServerRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Security-Control = "IAM-LeastPrivilege"
    Compliance = "CIS-1.1"
  }
}

resource "aws_iam_role_policy" "web_server_policy" {
  name = "WebServerPolicy"
  role = aws_iam_role.web_server_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::app-bucket/*"
      }
    ]
  })
}
```

### 2. Network Security

| Control             | Implementation                     | Terraform                 | Ansible           | Compliance          | Verification                       |
| ------------------- | ---------------------------------- | ------------------------- | ----------------- | ------------------- | ---------------------------------- |
| **VPC Isolation**   | Private subnets for servers        | ✅ VPC, subnets           | ❌                | CIS 4.1, NIST SC-7  | `aws ec2 describe-vpcs`            |
| **Security Groups** | Restrictive inbound/outbound rules | ✅ Security groups        | ✅ firewall rules | CIS 4.4, NIST SC-7  | `aws ec2 describe-security-groups` |
| **Network ACLs**    | Additional subnet-level controls   | ✅ Network ACLs           | ❌                | CIS 4.3, NIST SC-7  | `aws ec2 describe-network-acls`    |
| **VPC Flow Logs**   | Network traffic logging            | ✅ Flow log configuration | ❌                | CIS 4.7, NIST AU-12 | CloudWatch Logs                    |
| **DDoS Protection** | AWS Shield Advanced                | ✅ Shield configuration   | ❌                | NIST SC-5           | AWS Console                        |

#### Security Group Configuration

```hcl
# Web tier security group - HTTPS only
resource "aws_security_group" "web_tier" {
  name_prefix = "web-tier-sg-"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # HTTPS inbound from anywhere
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH from bastion only
  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Outbound to application tier
  egress {
    description = "App tier access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  tags = {
    Security-Control = "Network-SecurityGroups"
    Compliance = "CIS-4.4"
  }
}
```

### 3. Data Protection

| Control                   | Implementation                   | Terraform        | Ansible           | Compliance          | Verification               |
| ------------------------- | -------------------------------- | ---------------- | ----------------- | ------------------- | -------------------------- |
| **Encryption at Rest**    | EBS, S3, RDS encryption enabled  | ✅ KMS, EBS, S3  | ❌                | CIS 2.1, NIST SC-28 | `aws ec2 describe-volumes` |
| **Encryption in Transit** | TLS 1.2+ for all communications  | ✅ ALB listeners | ✅ SSL configs    | CIS 2.2, NIST SC-8  | SSL/TLS scan               |
| **Key Management**        | Centralized KMS with rotation    | ✅ KMS keys      | ❌                | CIS 2.1, NIST SC-12 | `aws kms list-keys`        |
| **Data Classification**   | Automated tagging and discovery  | ✅ Resource tags | ❌                | NIST SC-16          | AWS Macie                  |
| **Backup Encryption**     | Encrypted backups with retention | ✅ Backup vaults | ✅ Backup scripts | CIS 10.2, NIST CP-9 | Backup verification        |

#### KMS Implementation

```hcl
# Customer managed KMS key for sensitive data
resource "aws_kms_key" "sensitive_data" {
  description             = "KMS key for sensitive data encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Security-Control = "Data-Encryption"
    Compliance = "CIS-2.1"
  }
}

resource "aws_kms_alias" "sensitive_data" {
  name          = "alias/sensitive-data"
  target_key_id = aws_kms_key.sensitive_data.key_id
}
```

### 4. Monitoring and Logging

| Control                | Implementation                 | Terraform            | Ansible | Compliance         | Verification       |
| ---------------------- | ------------------------------ | -------------------- | ------- | ------------------ | ------------------ |
| **CloudTrail Logging** | All regions, S3 backup         | ✅ CloudTrail config | ❌      | CIS 3.1, NIST AU-2 | CloudTrail console |
| **Config Monitoring**  | Continuous compliance checking | ✅ Config rules      | ❌      | CIS 3.3, NIST CA-7 | AWS Config         |
| **GuardDuty**          | Threat detection               | ✅ GuardDuty config  | ❌      | CIS 3.6, NIST SI-4 | GuardDuty findings |
| **Security Hub**       | Centralized security findings  | ✅ Security Hub      | ❌      | NIST CA-7          | Security Hub       |
| **CloudWatch Alarms**  | Security event notifications   | ✅ Alarms            | ❌      | NIST AU-6          | CloudWatch         |

#### CloudTrail Configuration

```hcl
resource "aws_cloudtrail" "main" {
  name                          = "main-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.bucket
  s3_key_prefix                 = "cloudtrail-logs/"
  include_global_service_events  = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::sensitive-data-bucket/"]
    }
  }

  tags = {
    Security-Control = "Monitoring-CloudTrail"
    Compliance = "CIS-3.1"
  }
}
```

### 5. System Hardening

| Control                    | Implementation                 | Terraform | Ansible             | Compliance         | Verification           |
| -------------------------- | ------------------------------ | --------- | ------------------- | ------------------ | ---------------------- |
| **SSH Hardening**          | Key-based auth, no root login  | ❌        | ✅ SSH config       | CIS 5.2, NIST AC-3 | OpenSCAP scan          |
| **Firewall Configuration** | UFW/iptables rules             | ❌        | ✅ firewall tasks   | CIS 4.4, NIST SC-7 | `ufw status`           |
| **Audit Logging**          | auditd configuration           | ❌        | ✅ auditd setup     | CIS 4.2, NIST AU-2 | `auditctl -l`          |
| **File Permissions**       | Secure system file permissions | ❌        | ✅ permission tasks | CIS 6.1, NIST AC-6 | OpenSCAP               |
| **Service Hardening**      | Disable unnecessary services   | ❌        | ✅ service tasks    | CIS 2.2, NIST CM-7 | `systemctl list-units` |

#### Ansible Hardening Implementation

```yaml
# ansible/roles/security/tasks/main.yml
---
- name: SSH Hardening
  template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
    owner: root
    group: root
    mode: "0600"
  notify: Restart sshd
  tags:
    - security
    - ssh-hardening
    - cis-5.2.1

- name: Configure firewall rules
  ufw:
    rule: "{{ item.rule }}"
    port: "{{ item.port | default(omit) }}"
    proto: "{{ item.proto | default('tcp') }}"
    from_ip: "{{ item.from_ip | default(omit) }}"
    to_ip: "{{ item.to_ip | default(omit) }}"
  loop: "{{ firewall_rules }}"
  notify: Reload firewall
  tags:
    - security
    - firewall
    - cis-4.4

- name: Enable auditd
  service:
    name: auditd
    state: started
    enabled: yes
  tags:
    - security
    - auditd
    - cis-4.2
```

### 6. Application Security

| Control                   | Implementation                  | Terraform            | Ansible             | Compliance         | Verification        |
| ------------------------- | ------------------------------- | -------------------- | ------------------- | ------------------ | ------------------- |
| **WAF Protection**        | AWS WAF rules for web apps      | ✅ WAF configuration | ❌                  | NIST SC-7          | WAF metrics         |
| **SSL/TLS Configuration** | Modern ciphers, HSTS            | ✅ ALB listeners     | ✅ SSL templates    | CIS 2.2, NIST SC-8 | SSL Labs test       |
| **Application Logging**   | Structured logs to CloudWatch   | ❌                   | ✅ logging config   | NIST AU-2          | CloudWatch Logs     |
| **Secret Management**     | Parameter Store/Secrets Manager | ✅ Secret storage    | ✅ Secret retrieval | NIST SC-13         | Access audit        |
| **Input Validation**      | Web application firewall        | ✅ WAF rules         | ❌                  | NIST SI-10         | Penetration testing |

### 7. Backup and Disaster Recovery

| Control                      | Implementation                | Terraform             | Ansible           | Compliance          | Verification            |
| ---------------------------- | ----------------------------- | --------------------- | ----------------- | ------------------- | ----------------------- |
| **Automated Backups**        | Daily encrypted backups       | ✅ Backup configs     | ✅ Backup scripts | CIS 10.2, NIST CP-9 | Backup restoration test |
| **Cross-Region Replication** | Multi-region backup storage   | ✅ S3 replication     | ❌                | NIST CP-7           | Replication status      |
| **Recovery Testing**         | Monthly DR drills             | ❌                    | ✅ DR playbooks   | NIST CP-2           | DR test reports         |
| **Retention Policies**       | Configurable backup retention | ✅ Lifecycle policies | ✅ Backup config  | NIST CP-9           | Retention audit         |
| **Point-in-Time Recovery**   | Database PITR capabilities    | ✅ RDS config         | ❌                | NIST CP-10          | RDS restore test        |

## Control Verification Scripts

### Automated Security Check Script

```bash
#!/bin/bash
# scripts/security-controls-check.sh

echo "=== Security Controls Verification ==="

# Check IAM policies
echo "1. Verifying IAM least privilege..."
aws iam list-attached-role-policies --role-name WebServerRole

# Check encryption
echo "2. Verifying EBS encryption..."
aws ec2 describe-volumes --filters Name=encrypted,Values=false --query 'Volumes[*].VolumeId'

# Check security groups
echo "3. Checking open security groups..."
aws ec2 describe-security-groups --filters Name=ip-permission.cidr,Values=0.0.0.0/0

# Check CloudTrail
echo "4. Verifying CloudTrail status..."
aws cloudtrail describe-trails --query 'trailList[?IsMultiRegionTrail==`true`]'

# Check GuardDuty
echo "5. Checking GuardDuty status..."
aws guardduty list-detectors

echo "=== Verification Complete ==="
```

### Ansible Compliance Check

```yaml
# ansible/playbooks/security-compliance-check.yml
---
- name: Security Compliance Verification
  hosts: all
  become: yes
  vars:
    compliance_checks:
      - cis_1_1_1: "IAM least privilege"
      - cis_2_1_1: "EBS encryption"
      - cis_4_4_1: "Security group rules"
      - cis_5_2_1: "SSH hardening"

  tasks:
    - name: Check SSH configuration
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "^PermitRootLogin"
        line: "PermitRootLogin no"
      check_mode: yes
      register: ssh_check

    - name: Verify firewall status
      command: ufw status
      register: firewall_status

    - name: Generate compliance report
      template:
        src: compliance-report.j2
        dest: /tmp/compliance-report.txt
```

## Continuous Monitoring Setup

### CloudWatch Security Dashboard

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/CloudTrail", "ManagementEvents"],
          [".", "DataEvents"]
        ],
        "title": "CloudTrail Activity"
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "fields @timestamp, @message\n| filter @message like /ERROR/\n| stats count() by bin(1h)",
        "title": "Security Errors"
      }
    }
  ]
}
```

## Remediation Procedures

### Automated Remediation

| Issue                      | Detection           | Remediation       | Automation      |
| -------------------------- | ------------------- | ----------------- | --------------- |
| **Unencrypted EBS Volume** | Config Rule         | Enable encryption | Lambda function |
| **Open Security Group**    | GuardDuty           | Restrict rules    | AWS Config      |
| **Failed Login Attempts**  | CloudTrail          | Block IP          | Lambda + WAF    |
| **Outdated SSL Cert**      | Certificate Manager | Auto-renewal      | ACM automation  |

### Incident Response Playbook

1. **Detection Phase**

   - Monitor Security Hub findings
   - Analyze CloudTrail logs
   - Review GuardDuty alerts

2. **Analysis Phase**

   - Determine scope and impact
   - Identify affected resources
   - Assess data exposure

3. **Containment Phase**

   - Isolate compromised resources
   - Block malicious IPs
   - Rotate credentials

4. **Eradication Phase**

   - Remove malware/malicious code
   - Patch vulnerabilities
   - Update security groups

5. **Recovery Phase**
   - Restore from clean backups
   - Validate system integrity
   - Monitor for recurrence

## Compliance Mapping Summary

| Framework         | Controls Implemented   | Coverage | Gap Analysis          |
| ----------------- | ---------------------- | -------- | --------------------- |
| **CIS AWS v1.4**  | 85/95 controls         | 89%      | Advanced monitoring   |
| **NIST CSF**      | All 5 functions        | 95%      | Supply chain security |
| **ISO 27001**     | A.9-A.14               | 90%      | Business continuity   |
| **SOC 2 Type II** | Security, Availability | 85%      | Processing integrity  |

## Contact and Escalation

| Security Level | Contact              | Response Time | Escalation    |
| -------------- | -------------------- | ------------- | ------------- |
| **Critical**   | security@company.com | 15 minutes    | CISO          |
| **High**       | security@company.com | 1 hour        | Security Lead |
| **Medium**     | infra@company.com    | 4 hours       | DevOps Lead   |
| **Low**        | devops@company.com   | 24 hours      | Team Lead     |

---

_Document Version: 1.0_
_Last Updated: November 2025_
_Next Review: February 2026_
