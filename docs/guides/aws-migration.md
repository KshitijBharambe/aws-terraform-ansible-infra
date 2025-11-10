# AWS Migration Guide

This guide provides comprehensive instructions for migrating infrastructure and applications from on-premises or other cloud providers to AWS.

## Migration Strategy

### 1. Assessment and Planning

#### Current State Analysis

- **Infrastructure Inventory**: Document all servers, networks, storage, and applications
- **Application Dependencies**: Map service relationships and data flows
- **Performance Requirements**: Define baseline performance metrics
- **Security and Compliance**: Identify current security controls and compliance requirements
- **Cost Analysis**: Calculate current TCO and establish AWS migration budget

#### Migration Phases

1. **Discovery and Assessment** (2-4 weeks)
2. **Proof of Concept** (2-4 weeks)
3. **Pilot Migration** (4-8 weeks)
4. **Full Migration** (8-16 weeks)
5. **Optimization and Decomissioning** (4-8 weeks)

### 2. Infrastructure Migration

#### Compute Migration

**From Physical/Other Cloud to AWS EC2**

```bash
# Assess current infrastructure
#!/bin/bash

# Collect server specifications
for server in $(cat servers.txt); do
    echo "=== $server ==="
    ssh "$server" "lscpu | grep '^CPU(s):' | sed 's/.*, //g'"
    ssh "$server" "free -h | grep '^Mem:'"
    ssh "$server" "df -h | grep '^/dev/'"
    ssh "$server" "uname -a"
done

# Generate migration plan
cat > migration-plan.md << EOF
## Server Migration Plan

### Source Infrastructure Analysis
| Server | CPU | Memory | Storage | OS | Role |
|--------|-----|--------|--------|----|------|
| web-01 | 8 cores | 16GB | 200GB | CentOS 7 | Web server |
| db-01 | 4 cores | 32GB | 500GB | Ubuntu 18.04 | Database |
| app-01 | 2 cores | 8GB | 100GB | Ubuntu 16.04 | Application |

### AWS Target Configuration
| Role | Instance Type | vCPUs | Memory | Storage |
|------|-------------|-------|--------|---------|
| Web server | t3.medium | 4 | 16GB | 200GB gp3 |
| Database | r5.large | 4 | 32GB | 500GB gp3 |
| Application | t3.small | 2 | 8GB | 100GB gp3 |

### Migration Timeline
- Week 1-2: Database migration
- Week 3-4: Application migration
- Week 5-6: Web server migration
- Week 7-8: Testing and cutover
EOF
```

**AWS EC2 Instance Selection**

| Workload         | Recommended Instance | Use Case          | Key Features                       |
| ---------------- | -------------------- | ----------------- | ---------------------------------- |
| Web server       | t3.medium/t3.large   | General purpose   | Balanced CPU/memory                |
| Database         | r5.large/r5.xlarge   | Database          | Enhanced networking, EBS-optimized |
| Application      | t3.small/t3.medium   | Application       | Cost-optimized                     |
| High performance | c5/c5d.large         | Compute-intensive | High CPU, local storage            |

#### Storage Migration

**EBS Volumes Configuration**

```json
{
  "MigrationStrategy": {
    "Database": {
      "Source": "On-premises SAN",
      "Target": "AWS EBS",
      "VolumeType": "gp3",
      "VolumeSize": "500GB",
      "IOPS": "3000",
      "MigrationMethod": "AWS DMS"
    },
    "FileStorage": {
      "Source": "NAS/SAN",
      "Target": "AWS EFS",
      "Performance": "standard",
      "Capacity": "10TB",
      "MigrationMethod": "AWS DataSync"
    },
    "BackupStorage": {
      "Source": "Tape/Offsite",
      "Target": "AWS S3",
      "StorageClass": "IA",
      "Capacity": "50TB",
      "MigrationMethod": "Snowball Edge"
    }
  }
}
```

#### Network Migration

**VPC Design**

```hcl
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
    Environment = "production"
  }

  # Public subnets
  resource "aws_subnet" "public_subnet_a" {
    vpc_id            = aws_vpc.main_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip   = true

    tags = {
      Name = "public-subnet-a"
      Type = "public"
    }
  }

  # Private subnets
  resource "aws_subnet" "private_subnet_a" {
    vpc_id            = aws_vpc.main_vpc.id
    cidr_block        = "10.0.10.0/24"
    availability_zone = "us-east-1a"

    tags = {
      Name = "private-subnet-a"
      Type = "private"
    }
  }
}
```

### 3. Data Migration

#### Database Migration

**Using AWS Database Migration Service (DMS)**

```bash
# Create DMS replication instance
aws dms create-replication-instance \
  --replication-instance-identifier my-migration-instance \
  --replication-instance-class dms.c5.large \
  --engine mysql \
  --engine-version 8.0.28 \
  --allocated-storage 1000 \
  --vpc-security-group-ids sg-12345678 \
  --availability-zone us-east-1a \
  --publicly-accessible \
  --tags Key=Migration,Environment=prod

# Create source endpoint
aws dms create-endpoint \
  --endpoint-identifier source-db-endpoint \
  --endpoint-type source \
  --engine-name mysql \
  --username admin \
  --password $(aws secretsmanager get-secret-value --secret-id db-source-password) \
  --server-name source-db.company.com \
  --port 3306 \
  --ssl-external-ca file://path/to/ca-cert.pem

# Create target endpoint
aws dms create-endpoint \
  --endpoint-identifier target-db-endpoint \
  --endpoint-type target \
  --engine-name mysql \
  --username admin \
  --password $(aws secretsmanager get-secret-value --secret-id db-target-password) \
  --server-name target-db.cluster-xxxxxxx.us-east-1.rds.amazonaws.com \
  --port 3306

# Create replication task
aws dms create-replication-task \
  --replication-task-identifier mysql-migration \
  --source-endpoint-arn source-db-endpoint-arn \
  --target-endpoint-arn target-db-endpoint-arn \
  --migration-type full-load \
  --table-mappings name=employees,source-table-name=employees,target-table-name=employees \
  --replication-task-settings '{"TargetMetadataMode": "NONE", "FullLoadSettings": {"TargetTablePrepMode": "DROP_AND_CREATE", "CreatePkAfterFullLoad": false, "MaxFileSize": 1048576, "ParallelLoadThreads": 5, "CommitRate": 10000}}'
```

**Data Validation**

```python
#!/usr/bin/env python3
import mysql.connector
import psycopg2
import hashlib

def validate_migration():
    """Validate data integrity between source and target"""

    # Source database connection
    source_conn = mysql.connector.connect(
        host='source-db.company.com',
        user='admin',
        password='source_password',
        database='app_db'
    )

    # Target database connection
    target_conn = mysql.connector.connect(
        host='target-db.cluster-xxxxxxx.us-east-1.rds.amazonaws.com',
        user='admin',
        password='target_password',
        database='app_db'
    )

    # Compare row counts and checksums
    validation_results = {}

    tables = ['users', 'orders', 'products', 'transactions']

    for table in tables:
        # Source data
        source_cursor = source_conn.cursor()
        source_cursor.execute(f"SELECT COUNT(*), MD5(GROUP_CONCAT(CAST(id AS CHAR))) FROM {table}")
        source_count, source_checksum = source_cursor.fetchone()

        # Target data
        target_cursor = target_conn.cursor()
        target_cursor.execute(f"SELECT COUNT(*), MD5(GROUP_CONCAT(CAST(id AS CHAR))) FROM {table}")
        target_count, target_checksum = target_cursor.fetchone()

        validation_results[table] = {
            'source_count': source_count[0],
            'target_count': target_count[0],
            'source_checksum': source_checksum[0],
            'target_checksum': target_checksum[0],
            'match': source_count[0] == target_count[0] and source_checksum[0] == target_checksum[0]
        }

        print(f"Table {table}: {'✓' if validation_results[table]['match'] else '✗'} "
              f"Source: {source_count[0]}, Target: {target_count[0]}, "
              f"Checksum: {'Match' if validation_results[table]['match'] else 'Mismatch'}")

    source_conn.close()
    target_conn.close()

    return validation_results

if __name__ == '__main__':
    validate_migration()
```

#### File Migration

**AWS DataSync Configuration**

```bash
# Create DataSync location
aws datasync create-location \
  --location-identifier on-premises-file-share \
  --location-type s3 \
  --s3-bucket-name migration-backup-bucket \
  --s3-prefix file-backups/

# Create DataSync task
aws datasync create-task \
  --task-identifier file-migration-task \
  --source-location-arn arn:aws:datasync:us-east-1:123456789012:location/on-premises-file-share \
  --destination-location-arn arn:aws:datasync:us-east-1:123456789012:location/aws-s3-backup-bucket \
  --cloud-watch-log-group-arn arn:aws:logs:us-east-1:123456789012:log-group:/aws/datasync/file-migration-task \
  --name "On-premises File Share Migration" \
  --options '{"VerifyMode": "ONLY_FILES_TRANSFERRED","FileSize": "ALL","PreserveDeletedFiles": "REMOVE","PreservePosix": "NONE"}' \
  --schedule-expression "rate(12 hours)"

# Monitor migration progress
aws datasync describe-task-execution \
  --task-arn file-migration-task-arn
```

### 4. Application Migration

#### Container Migration

**Docker to ECS Migration**

```yaml
# ECS Task Definition
{
  "family": "web-app",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecs-task-role",
  "containerDefinitions":
    [
      {
        "name": "web-app",
        "image": "your-registry/web-app:latest",
        "portMappings":
          [{ "containerPort": 80, "hostPort": 80, "protocol": "tcp" }],
        "environment":
          [
            {
              "name": "DATABASE_HOST",
              "value": "database.cluster-xxxxxxx.us-east-1.rds.amazonaws.com",
            },
            {
              "name": "REDIS_HOST",
              "value": "redis-cache.xxxxxx.clustercfg.use1.cache.amazonaws.com",
            },
            { "name": "ENVIRONMENT", "value": "production" },
          ],
        "logConfiguration":
          {
            "logDriver": "awslogs",
            "options":
              {
                "awslogs-group": "/ecs/web-app",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs",
              },
          },
      },
    ],
}
```

#### Load Balancer Configuration

```hcl
resource "aws_lb" "web_app_lb" {
  name               = "web-app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets           = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]

  target_group_arns = [aws_lb_target_group.web_app_tg.arn]

  tags = {
    Name = "web-app-alb"
    Environment = "production"
  }
}

resource "aws_lb_target_group" "web_app_tg" {
  name     = "web-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    enabled = true
    healthy_threshold   = 2
    interval           = 30
    matcher            = "200"
    path               = "/health"
    timeout            = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "web-app-tg"
    Environment = "production"
  }
}
```

### 5. Security Migration

#### Identity and Access Management

**AWS IAM Configuration**

```json
{
  "IAMStrategy": {
    "Centralized": {
      "Directory": "AWS Managed Microsoft AD",
      "Integration": "AWS AD Connector",
      "SSO": "AWS SSO",
      "MFA": "Enabled"
    },
    "Hybrid": {
      "Directory": "On-premises AD",
      "Integration": "AD Connector",
      "SSO": "SAML 2.0",
      "MFA": "Enabled"
    },
    "AWS Native": {
      "Directory": "AWS IAM Identity Center",
      "SSO": "AWS SSO",
      "MFA": "Enabled"
    }
  }
}
```

**Security Groups and NACLs**

```hcl
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "web-sg"
    Environment = "production"
  }
}
```

### 6. Monitoring and Logging

#### AWS CloudWatch Setup

```bash
# Create CloudWatch log groups
aws logs create-log-group \
  --log-group-name /aws/ec2/web-app \
  --retention-days 30

aws logs create-log-group \
  --log-group-name /aws/rds/web-db \
  --retention-days 30

# Create CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name web-app-cpu-high \
  --alarm-description "Web app CPU utilization > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:web-app-alerts \
  --dimensions Name=web-app-instance-1

# Create custom metrics
aws cloudwatch put-metric-data \
  --namespace "WebApp" \
  --metric-data "OrdersPerMinute" \
  --timestamp $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --value 42 \
  --unit "Count"
```

#### Application Performance Monitoring

**AWS X-Ray Configuration**

```yaml
# application.properties
logging:
  factory: io.opentelemetry.opentelemetry.Slf4j2.LoggerFactory
  loggers:
    io.opentelemetry:
      level: INFO

  instrumentation:
    exporter:
      jaeger:
        endpoint: http://localhost:14268/api/traces
        serviceName: web-app

# AWS X-Ray SDK integration
aws:
  xray:
    # Automatic segment discovery
    # Service map configuration
    # Anomaly detection
    # Centralized configuration
```

### 7. Cost Optimization

#### Right-Sizing Strategy

```bash
#!/bin/bash

# Instance cost optimization script
instances=$(aws ec2 describe-instances --filters Name=tag:Environment,Values=production --query 'Reservations[*].Instances[*]' --output text)

for instance_id in $instances; do
    echo "=== Analyzing $instance_id ==="

    # Get instance details
    instance_type=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[*].Instances[*].InstanceType' --output text)
    instance_state=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[*].Instances[*].State.Name' --output text)

    if [ "$instance_state" = "running" ]; then
        # Get CloudWatch metrics
        cpu_avg=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/EC2 \
            --metric-name CPUUtilization \
            --dimensions Name=$instance_id \
            --statistics Average \
            --period 86400 \
            --query Datapoints[0].Average \
            --output text)

        memory_avg=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/EC2 \
            --metric-name MemoryUtilization \
            --dimensions Name=$instance_id \
            --statistics Average \
            --period 86400 \
            --query Datapoints[0].Average \
            --output text)

        echo "Current CPU: ${cpu_avg}%"
        echo "Current Memory: ${memory_avg}%"

        # Optimization recommendations
        if [ "${cpu_avg%.*}" -lt 30 ] && [ "${memory_avg%.*}" -lt 30 ]; then
            echo "RECOMMENDATION: Consider downgrading to t3.small (${instance_type} is over-provisioned)"
        elif [ "${cpu_avg%.*}" -gt 80 ] || [ "${memory_avg%.*}" -gt 80 ]; then
            echo "RECOMMENDATION: Consider upgrading to larger instance type"
        fi
    fi
done
```

#### Storage Cost Optimization

```python
# S3 storage optimization script
import boto3
import datetime

def optimize_s3_storage():
    """Analyze and optimize S3 storage costs"""

    s3 = boto3.client('s3')

    # Analyze storage classes
    bucket_stats = {}

    for bucket in s3.buckets.all():
        bucket_name = bucket.name
        total_size = 0
        object_count = 0

        storage_classes = {'STANDARD': 0, 'INTELLIGENT_TIERING': 0, 'GLACIER': 0, 'DEEP_ARCHIVE': 0}

        for obj in bucket.objects.all():
            size = obj.size
            storage_class = obj.storage_class

            total_size += size
            object_count += 1
            storage_classes[storage_class] += size

        # Calculate cost optimization
        total_size_gb = total_size / (1024**3)

        bucket_stats[bucket_name] = {
            'total_size_gb': total_size_gb,
            'object_count': object_count,
            'storage_classes': storage_classes,
            'monthly_cost': calculate_monthly_cost(storage_classes)
        }

        # Provide recommendations
        print(f"Bucket: {bucket_name}")
        print(f"  Total Size: {total_size_gb:.2f} GB")
        print(f"  Object Count: {object_count}")
        print(f"  Estimated Monthly Cost: ${bucket_stats[bucket_name]['monthly_cost']:.2f}")
        print(f"  Optimization: {get_storage_optimization(storage_classes)}")

    return bucket_stats

def calculate_monthly_cost(storage_classes):
    """Calculate monthly cost based on storage classes"""
    # Pricing (US-East-1)
    pricing = {
        'STANDARD': 0.023,      # $0.023 per GB
        'INTELLIGENT_TIERING': 0.0125,  # $0.0125 per GB
        'GLACIER': 0.004,      # $0.004 per GB
        'DEEP_ARCHIVE': 0.00099   # $0.00099 per GB
    }

    total_cost = 0
    for storage_class, size_gb in storage_classes.items():
        size_gb = size_gb / (1024**3)  # Convert to GB
        total_cost += size_gb * pricing.get(storage_class, 0)

    return total_cost * 730  # 30 days

def get_storage_optimization(storage_classes):
    """Get storage optimization recommendations"""
    total_size = sum(storage_classes.values())

    # Calculate optimal distribution
    recommendations = []

    if storage_classes.get('STANDARD', 0) > total_size * 0.6:
        recommendations.append("Move 40% of frequently accessed data to Intelligent-Tiering")

    if storage_classes.get('GLACIER', 0) > total_size * 0.3:
        recommendations.append("Archive cold data to Glacier Deep Archive")

    if storage_classes.get('INTELLIGENT_TIERING', 0) < total_size * 0.2:
        recommendations.append("Use Intelligent-Tiering for infrequently accessed data")

    return "\n".join(recommendations) if recommendations else "Storage is already optimized"

if __name__ == '__main__':
    optimize_s3_storage()
```

### 8. Validation and Testing

#### Migration Testing Framework

```python
#!/usr/bin/env python3
import requests
import time
import json

class MigrationTester:
    def __init__(self, config):
        self.config = config
        self.test_results = {}

    def test_connectivity(self, service):
        """Test service connectivity"""
        try:
            response = requests.get(
                f"{service['url']}/health",
                timeout=10,
                verify=service.get('verify_ssl', True)
            )
            response.raise_for_status()

            self.test_results[service['name']] = {
                'status': 'pass',
                'response_time': response.elapsed.total_seconds(),
                'status_code': response.status_code
            }
        except Exception as e:
            self.test_results[service['name']] = {
                'status': 'fail',
                'error': str(e),
                'response_time': None
            }

    def test_functionality(self, service):
        """Test service functionality"""
        tests = service.get('tests', [])

        for test in tests:
            try:
                response = requests.request(
                    test['method'],
                    f"{service['url']}{test['endpoint']}",
                    headers=test.get('headers', {}),
                    json=test.get('data', {}),
                    timeout=30,
                    verify=service.get('verify_ssl', True)
                )

                expected_status = test['expected_status']
                response_time = response.elapsed.total_seconds()

                if response.status_code == expected_status:
                    self.test_results[f"{service['name']}_{test['name']}"] = {
                        'status': 'pass',
                        'response_time': response_time,
                        'status_code': response.status_code
                    }
                else:
                    self.test_results[f"{service['name']}_{test['name']}"] = {
                        'status': 'fail',
                        'response_time': response_time,
                        'status_code': response.status_code,
                        'expected_status': expected_status
                    }

            except Exception as e:
                self.test_results[f"{service['name']}_{test['name']}"] = {
                    'status': 'fail',
                    'error': str(e),
                    'response_time': None
                }

    def generate_report(self):
        """Generate test report"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results.values() if result['status'] == 'pass')

        report = {
            'summary': {
                'total_tests': total_tests,
                'passed_tests': passed_tests,
                'failed_tests': total_tests - passed_tests,
                'success_rate': (passed_tests / total_tests * 100) if total_tests > 0 else 0
            },
            'results': self.test_results
        }

        return report

# Migration test configuration
migration_config = {
    'services': [
        {
            'name': 'web-app',
            'url': 'https://web-app.example.com',
            'verify_ssl': True,
            'tests': [
                {
                    'name': 'health_check',
                    'method': 'GET',
                    'endpoint': '/health',
                    'expected_status': 200
                },
                {
                    'name': 'login_test',
                    'method': 'POST',
                    'endpoint': '/api/login',
                    'data': {'username': 'test', 'password': 'test'},
                    'expected_status': 200
                }
            ]
        },
        {
            'name': 'database',
            'url': 'https://api.example.com',
            'verify_ssl': True,
            'tests': [
                {
                    'name': 'connection_test',
                    'method': 'GET',
                    'endpoint': '/db/health',
                    'expected_status': 200
                }
            ]
        }
    ]
}

# Run migration tests
if __name__ == '__main__':
    tester = MigrationTester(migration_config)

    # Test all services
    for service in migration_config['services']:
        tester.test_connectivity(service)
        tester.test_functionality(service)
        time.sleep(2)  # Wait between tests

    # Generate report
    report = tester.generate_report()

    print(f"Migration Test Results:")
    print(f"Total Tests: {report['summary']['total_tests']}")
    print(f"Passed: {report['summary']['passed_tests']}")
    print(f"Failed: {report['summary']['failed_tests']}")
    print(f"Success Rate: {report['summary']['success_rate']}%")

    # Save detailed results
    with open('migration-test-results.json', 'w') as f:
        json.dump(report, f, indent=2)
```

### 9. Cut-over and Decomissioning

#### Cut-over Planning

```bash
#!/bin/bash

# DNS cut-over script
DOMAIN="example.com"
NEW_IP="3.15.23.45"
TTL=300

# Update A record
aws route53 change-resource-record-sets \
  --hosted-zone-id $(aws route53 list-hosted-zones --query 'HostedZones[?Name=='${DOMAIN}'].Id' --output text) \
  --change-batch '{"Changes": [{"Action": "UPSERT", "ResourceRecordSet": "www.'${DOMAIN}'", "ResourceRecords": [{"ResourceRecord": [{"Value": "'${NEW_IP}'"}]}]}]}' \
  --comment "DNS migration cut-over"

# Update MX record
aws route53 change-resource-record-sets \
  --hosted-zone-id $(aws route53 list-hosted-zones --query 'HostedZones[?Name=='${DOMAIN}'].Id' --output text) \
  --change-batch '{"Changes": [{"Action": "UPSERT", "ResourceRecordSet": "'${DOMAIN}'", "ResourceRecords": [{"ResourceRecord": [{"Value": "mail.'${DOMAIN}'"}]}]}]}' \
  --comment "MX record migration"

# Verify DNS propagation
echo "Waiting for DNS propagation..."
for i in {1..10}; do
    resolved_ip=$(dig +short www.${DOMAIN})
    if [ "$resolved_ip" = "$NEW_IP" ]; then
        echo "DNS propagated successfully after ${i} checks"
        break
    fi
    sleep 30
done
```

#### Data Validation

```python
#!/usr/bin/env python3
import hashlib
import requests

def validate_data_consistency():
    """Validate data consistency after migration"""

    # Compare source and target data
    source_data = get_source_data()
    target_data = get_target_data()

    validation_results = {}

    for table_name in source_data.keys():
        source_records = source_data[table_name]
        target_records = target_data[table_name]

        # Compare record counts
        source_count = len(source_records)
        target_count = len(target_records)

        # Compare checksums
        source_checksum = calculate_checksum(source_records)
        target_checksum = calculate_checksum(target_records)

        validation_results[table_name] = {
            'source_count': source_count,
            'target_count': target_count,
            'count_match': source_count == target_count,
            'source_checksum': source_checksum,
            'target_checksum': target_checksum,
            'checksum_match': source_checksum == target_checksum,
            'validation_status': 'pass' if source_count == target_count and source_checksum == target_checksum else 'fail'
        }

        print(f"Table {table_name}: {validation_results[table_name]['validation_status'].upper()}")
        print(f"  Count: {source_count} -> {target_count} ({'✓' if validation_results[table_name]['count_match'] else '✗'})")
        print(f"  Checksum: {validation_results[table_name]['source_checksum']} ({'✓' if validation_results[table_name]['checksum_match'] else '✗'})")

    return validation_results

def calculate_checksum(records):
    """Calculate checksum for record set"""
    data = str(sorted([str(r['id']) + str(r.get('created_at', '')) for r in records]))
    return hashlib.md5(data.encode()).hexdigest()

def get_source_data():
    """Get data from source system"""
    # Implement source system connection
    pass

def get_target_data():
    """Get data from target AWS system"""
    # Implement target system connection
    pass

if __name__ == '__main__':
    validation_results = validate_data_consistency()
```

This migration guide provides a comprehensive framework for moving infrastructure and applications to AWS. Adapt the specific configurations, scripts, and timelines to match your organization's requirements and constraints.
