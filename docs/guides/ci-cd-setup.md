# CI/CD Setup Guide

This guide provides comprehensive instructions for setting up and configuring CI/CD pipelines for the AWS Terraform Ansible infrastructure project.

## Prerequisites

- Git repository with appropriate access
- AWS account with necessary permissions
- CI/CD platform (GitHub Actions, GitLab CI, Jenkins, etc.)
- Docker registry (Docker Hub, AWS ECR, etc.)
- Terraform Cloud/Remote state backend
- Ansible Tower/AWX or suitable automation

## GitHub Actions Setup

### 1. Repository Structure

```
.github/
├── workflows/
│   ├── ci.yml                    # Main CI pipeline
│   ├── deploy-dev.yml            # Development deployment
│   ├── deploy-staging.yml         # Staging deployment
│   ├── deploy-prod.yml           # Production deployment
│   ├── security-scan.yml          # Security scanning
│   └── infra-validate.yml        # Infrastructure validation
├── scripts/
│   ├── setup.sh                  # Environment setup
│   ├── test.sh                   # Test execution
│   └── deploy.sh                 # Deployment automation
└── environments/
    ├── dev.yml                   # Development environment
    ├── staging.yml                # Staging environment
    └── prod.yml                   # Production environment
```

### 2. Main CI Pipeline

**File: `.github/workflows/ci.yml`**

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_DEFAULT_REGION: us-east-1

jobs:
  # Infrastructure validation
  validate-terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: "1.5.*"

      - name: Terraform format check
        run: terraform fmt -recursive -check

      - name: Terraform init (AWS)
        run: |
          cd terraform/aws
          terraform init -backend-config=backend.tf

      - name: Terraform validate (AWS)
        run: |
          cd terraform/aws
          terraform validate

      - name: Terraform init (OCI)
        run: |
          cd terraform/oci
          terraform init -backend-config=backend.tf

      - name: Terraform validate (OCI)
        run: |
          cd terraform/oci
          terraform validate

  # Ansible validation
  validate-ansible:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.9"

      - name: Install dependencies
        run: |
          pip install ansible ansible-lint

      - name: Ansible syntax check
        run: |
          ansible-playbook --syntax-check ansible/playbooks/*.yml

      - name: Ansible lint
        run: |
          ansible-lint ansible/playbooks/

  # Security scanning
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: "fs"
          scan-ref: "."
          format: "sarif"
          output: "trivy-results.sarif"

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: "trivy-results.sarif"

  # Build and test
  build-and-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        cloud: [aws, oci]
        environment: [dev, staging]

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: "1.21"

      - name: Build Go applications
        run: |
          # Build CLI tools
          cd scripts
          go build -o multicloud-deploy .
          go build -o cost-comparison .
          go build -o cross-cloud-dr .

      - name: Run tests
        run: |
          cd scripts
          go test -v ./...

      - name: Test Terraform modules
        run: |
          cd terraform/${{ matrix.cloud }}
          terraform test

      - name: Validate Ansible playbooks
        run: |
          ansible-playbook --syntax-check ansible/playbooks/site.yml

  # Container security scan
  container-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run container security scan
        run: |
          # Build Docker images
          docker build -t test-web-app .
          docker build -t test-app-app .

          # Run Trivy on containers
          trivy image --format json --output trivy-container.json test-web-app
          trivy image --format json --output trivy-app.json test-app-app

      - name: Upload scan results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: container-scan-results
          path: trivy-*.json
```

### 3. Deployment Pipeline

**File: `.github/workflows/deploy-dev.yml`**

```yaml
name: Deploy Development

on:
  push:
    branches: [develop]
  workflow_dispatch:
    inputs:
      cloud:
        description: "Cloud provider (aws/oci)"
        required: true
        default: aws

env:
  AWS_DEFAULT_REGION: us-east-1
  TF_VAR_environment: dev

jobs:
  deploy-infrastructure:
    runs-on: ubuntu-latest
    outputs:
      web_server_public_ip: ${{ steps.deploy.outputs.web_server_public_ip }}
      app_server_public_ip: ${{ steps.deploy.outputs.app_server_public_ip }}
      db_endpoint: ${{ steps.deploy.outputs.db_endpoint }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: "1.5.*"

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}

      - name: Terraform init
        run: |
          cd terraform/${{ github.event.inputs.cloud }}
          terraform init -backend-config=backend.tf

      - name: Terraform plan
        run: |
          cd terraform/${{ github.event.inputs.cloud }}
          terraform plan -out=tfplan -var-file=terraform.tfvars.dev

      - name: Terraform apply
        run: |
          cd terraform/${{ github.event.inputs.cloud }}
          terraform apply -auto-approve -var-file=terraform.tfvars.dev
        id: deploy

      - name: Configure OCI credentials
        if: github.event.inputs.cloud == 'oci'
        run: |
          # Configure OCI CLI
          mkdir -p ~/.oci
          echo "${{ secrets.OCI_PRIVATE_KEY }}" > ~/.oci/oci_api_key.pem
          echo "${{ secrets.OCI_CONFIG_CONTENT }}" > ~/.oci/config
          chmod 600 ~/.oci/oci_api_key.pem

      - name: Deploy with Ansible
        run: |
          if [ "${{ github.event.inputs.cloud }}" = "oci" ]; then
            ansible-playbook -i ansible/inventory/oci/hosts \
                          ansible/playbooks/site.yml \
                          -e "environment=dev" \
                          -e "cloud=oci"
          else
            ansible-playbook -i ansible/inventory/aws/hosts \
                          ansible/playbooks/site.yml \
                          -e "environment=dev" \
                          -e "cloud=aws" \
                          -e "aws_region=${{ env.AWS_DEFAULT_REGION }}"
          fi

      - name: Wait for services
        run: |
          sleep 60  # Wait for services to start

      - name: Run health checks
        run: |
          if [ "${{ github.event.inputs.cloud }}" = "oci" ]; then
            # Check OCI resources
            ansible-playbook -i ansible/inventory/oci/hosts \
                              ansible/playbooks/health-check.yml
          else
            # Check AWS resources
            ansible-playbook -i ansible/inventory/aws/hosts \
                              ansible/playbooks/health-check.yml \
                              -e "aws_region=${{ env.AWS_DEFAULT_REGION }}"
          fi

  run-tests:
    needs: deploy-infrastructure
    runs-on: ubuntu-latest
    strategy:
      matrix:
        test_type: [integration, security, performance]

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure test environment
        run: |
          # Set up test configuration based on deployment outputs
          cat > test-config.yml << EOF
          web_server_ip: ${{ needs.deploy-infrastructure.outputs.web_server_public_ip }}
          app_server_ip: ${{ needs.deploy-infrastructure.outputs.app_server_public_ip }}
          db_endpoint: ${{ needs.deploy-infrastructure.outputs.db_endpoint }}
          environment: dev
          cloud: ${{ github.event.inputs.cloud }}
          aws_region: ${{ env.AWS_DEFAULT_REGION }}
          EOF

      - name: Run integration tests
        if: matrix.test_type == 'integration'
        run: |
          python tests/integration/test_deployment.py --config test-config.yml

      - name: Run security tests
        if: matrix.test_type == 'security'
        run: |
          python tests/security/test_security.py --config test-config.yml

      - name: Run performance tests
        if: matrix.test_type == 'performance'
        run: |
          python tests/performance/test_performance.py --config test-config.yml

      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results-${{ matrix.test_type }}
          path: test-results/

  notify-success:
    needs: [deploy-infrastructure, run-tests]
    runs-on: ubuntu-latest
    if: success()
    steps:
      - name: Send success notification
        uses: 8398a7/action-slack@v3
        with:
          status: success
          channel: "#dev-deploys"
          text: "Development deployment completed successfully for ${{ github.event.inputs.cloud }}"

      - name: Update deployment status
        run: |
          # Update deployment tracking system
          curl -X POST "${{ secrets.DEPLOYMENT_API_URL }}/deployment" \
               -H "Authorization: Bearer ${{ secrets.DEPLOYMENT_API_TOKEN }}" \
               -H "Content-Type: application/json" \
               -d '{"status": "success", "environment": "dev", "cloud": "${{ github.event.inputs.cloud }}"}' \
               || true

  notify-failure:
    needs: [deploy-infrastructure, run-tests]
    runs-on: ubuntu-latest
    if: failure()
    steps:
      - name: Send failure notification
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          channel: "#dev-deploys"
          text: "Development deployment failed for ${{ github.event.inputs.cloud }}"

      - name: Rollback deployment
        run: |
          echo "Rolling back deployment..."
          # Implement rollback logic
          if [ "${{ github.event.inputs.cloud }}" = "aws" ]; then
            aws s3 ls "s3://${{ secrets.AWS_S3_BUCKET }}/backups/dev-" --recursive || true
            # Restore from latest backup
          fi

      - name: Update deployment status
        run: |
          curl -X POST "${{ secrets.DEPLOYMENT_API_URL }}/deployment" \
               -H "Authorization: Bearer ${{ secrets.DEPLOYMENT_API_TOKEN }}" \
               -H "Content-Type: application/json" \
               -d '{"status": "failed", "environment": "dev", "cloud": "${{ github.event.inputs.cloud }}", "rollback": true}' \
               || true
```

## GitLab CI/CD Setup

### 1. GitLab CI Configuration

**File: `.gitlab-ci.yml`**

```yaml
stages:
  - validate
  - test
  - build
  - deploy-dev
  - deploy-staging
  - deploy-prod

variables:
  AWS_DEFAULT_REGION: us-east-1
  DOCKER_REGISTRY: $CI_REGISTRY_IMAGE
  TERRAFORM_VERSION: "1.5.*"

cache:
  paths:
    - .terraform/
    - .go/pkg/
  key: "$CI_COMMIT_REF_SLUG"

before_script:
  - echo "Starting CI/CD pipeline"
  - apt-get update -y
  - apt-get install -y curl unzip

# Infrastructure validation
validate:terraform:
  stage: validate
  image: hashicorp/terraform:$TERRAFORM_VERSION
  script:
    - terraform fmt -recursive -check
    - cd terraform/aws && terraform init -backend-config=backend.tf && terraform validate
    - cd terraform/oci && terraform init -backend-config=backend.tf && terraform validate
  cache:
    key: validate-terraform-$CI_COMMIT_REF_SLUG

validate:ansible:
  stage: validate
  image: python:3.9-slim
  script:
    - pip install ansible ansible-lint
    - ansible-playbook --syntax-check ansible/playbooks/*.yml
    - ansible-lint ansible/playbooks/
  cache:
    key: validate-ansible-$CI_COMMIT_REF_SLUG

# Security scanning
security:scan:
  stage: test
  image: aquasec/trivy:latest
  script:
    - trivy fs --format json --output trivy-results.json .
    - trivy image --format json --output trivy-container.json $CI_REGISTRY_IMAGE:latest
  artifacts:
    reports:
      trivy-results: gl-sast-report.json
      trivy-container: gl-container-scanning-report.json
    expire_in: 1 week
  only:
    - main
    - develop

# Build applications
build:go:
  stage: build
  image: golang:1.21
  script:
    - cd scripts
    - go mod download
    - go build -o multicloud-deploy .
    - go build -o cost-comparison .
    - go build -o cross-cloud-dr .
  artifacts:
    paths:
      - scripts/multicloud-deploy
      - scripts/cost-comparison
      - scripts/cross-cloud-dr
    expire_in: 1 week
  cache:
    key: build-go-$CI_COMMIT_REF_SLUG

# Development deployment
deploy:dev:
  stage: deploy-dev
  script:
    - apt-get update -y && apt-get install -y openssh-client
    - mkdir -p ~/.ssh
    - echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    - echo "$SSH_KNOWN_HOSTS" > ~/.ssh/known_hosts
    - chmod 644 ~/.ssh/known_hosts
    - cd terraform/aws
    - terraform init -backend-config=backend.tf
    - terraform plan -out=tfplan -var-file=terraform.tfvars.dev
    - terraform apply -auto-approve -var-file=terraform.tfvars.dev
    - ansible-playbook -i ansible/inventory/aws/hosts ansible/playbooks/site.yml -e "environment=dev"
    - sleep 60
    - ansible-playbook -i ansible/inventory/aws/hosts ansible/playbooks/health-check.yml
  environment:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION
  only:
    - develop
  when: manual

# Staging deployment
deploy:staging:
  stage: deploy-staging
  script:
    - echo "Deploying to staging environment"
    # Add staging deployment logic
  only:
    - main
  when: manual
  dependencies:
    - deploy:dev

# Production deployment
deploy:prod:
  stage: deploy-prod
  script:
    - echo "Deploying to production environment"
    - cd terraform/aws
    - terraform init -backend-config=backend.tf
    - terraform plan -out=tfplan -var-file=terraform.tfvars.prod
    - terraform apply -auto-approve -var-file=terraform.tfvars.prod
    - ansible-playbook -i ansible/inventory/aws/hosts ansible/playbooks/site.yml -e "environment=prod"
    - sleep 120
    - ansible-playbook -i ansible/inventory/aws/hosts ansible/playbooks/health-check.yml
    - ansible-playbook -i ansible/inventory/aws/hosts ansible/playbooks/load-test.yml
  environment:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION
  only:
    - main
  when: manual
  dependencies:
    - deploy:staging
    - security:scan

# Integration tests
test:integration:
  stage: test
  script:
    - python -m venv .venv && source .venv/bin/activate
    - pip install -r requirements.txt
    - python tests/integration/test_deployment.py
  artifacts:
    reports:
      junit: test-results.xml
    expire_in: 1 week
  dependencies:
    - deploy:staging
```

## Jenkins Pipeline Setup

### 1. Jenkinsfile Configuration

**File: `Jenkinsfile`**

```groovy
pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        DOCKER_REGISTRY = 'your-registry.com'
    }

    stages {
        stage 'Checkout'
        stage 'Validate'
        stage 'Test'
        stage 'Build'
        stage 'Deploy'
        stage 'Integration Test'
    }

    stage('Checkout') {
        steps {
            checkout scm
        stash includes: '**/*.tf', '**/*.yml', '**/*.go', '**/requirements.txt', name: 'source-code'
        }
    }

    stage('Validate') {
        parallel {
            stage('Validate Terraform') {
                steps {
                    unstash 'source-code'
                    sh 'terraform fmt -recursive -check'
                    sh 'cd terraform/aws && terraform init -backend-config=backend.tf && terraform validate'
                    sh 'cd terraform/oci && terraform init -backend-config=backend.tf && terraform validate'
                }
            }
            stage('Validate Ansible') {
                steps {
                    unstash 'source-code'
                    sh 'ansible-lint ansible/playbooks/'
                    sh 'ansible-playbook --syntax-check ansible/playbooks/*.yml'
                }
            }
        }
    }

    stage('Test') {
        steps {
            unstash 'source-code'
            sh 'python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
            sh 'python tests/unit/*.py --junitxml=unit-test-results.xml'
            sh 'trivy fs --format json --output trivy-results.json . || true'
            publishTestResults testResultsMode: 'ALWAYS'
            archiveArtifacts artifacts: '**/trivy-*.json', fingerprint: true
        }
        post {
            always {
                publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'security-reports',
                        reportFiles: '**/trivy-results.json',
                        reportName: 'Security Scan Report'
                ])
            }
        }
    }

    stage('Build') {
        steps {
            unstash 'source-code'
            sh 'cd scripts && go mod download'
            sh 'cd scripts && go build -o multicloud-deploy .'
            sh 'cd scripts && go build -o cost-comparison .'
            sh 'cd scripts && go build -o cross-cloud-dr .'
            archiveArtifacts artifacts: 'scripts/*', fingerprint: true
        }
    }

    stage('Deploy') {
        parallel {
            stage('Deploy AWS Dev') {
                when { env.BRANCH_NAME == 'develop' }
                steps {
                    unstash 'source-code'
                    withCredentials(['aws-credentials']) {
                        sh '''
                            cd terraform/aws
                            terraform init -backend-config=backend.tf
                            terraform plan -out=tfplan -var-file=terraform.tfvars.dev
                            terraform apply -auto-approve -var-file=terraform.tfvars.dev
                        '''
                    }
                    withCredentials(['ansible-credentials']) {
                        sh '''
                            ansible-playbook -i ansible/inventory/aws/hosts ansible/playbooks/site.yml -e "environment=dev"
                        '''
                    }
                }
            }
            stage('Deploy AWS Staging') {
                when { env.BRANCH_NAME == 'staging' }
                steps {
                    unstash 'source-code'
                    // Add staging deployment logic
                }
            }
        }
    }

    stage('Integration Test') {
        steps {
            unstash 'source-code'
            sh 'python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
            sh 'python tests/integration/test_deployment.py --env dev --cloud aws'
            junit 'integration-test-results.xml'
        }
        post {
            always {
                publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'integration-test-reports',
                        reportFiles: '**/integration-test-results.xml',
                        reportName: 'Integration Test Report'
                ])
            }
        }
    }
}
```

### 2. Jenkins Multi-branch Pipeline

**File: `Jenkinsfile.multibranch`**

```groovy
properties([
    buildDiscarder(logRotator(numToKeepStr:'30'), daysToKeepStr:'30'))
])

pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        DOCKER_REGISTRY = 'your-registry.com'
    }

    triggers {
        pollSCM('*/develop', '*/main', branches: [all])
    }

    stages {
        stage('Build')
        stage('Test')
        stage('Deploy')
        stage('Integration Test')
    }

    stage('Build') {
        steps {
            checkout scm
            sh 'docker build -t $DOCKER_REGISTRY/multicloud-deploy:$BUILD_NUMBER .'
            sh 'docker push $DOCKER_REGISTRY/multicloud-deploy:$BUILD_NUMBER'
        }
    }

    stage('Test') {
        parallel {
            stage('Unit Tests') {
                    steps {
                        sh 'python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
                        sh 'python tests/unit/*.py --junitxml=unit-test-$BRANCH_NAME-$BUILD_NUMBER.xml'
                    }
                }
            stage('Security Scan') {
                    steps {
                        sh 'trivy image --format json --output trivy-$BRANCH_NAME-$BUILD_NUMBER.json $DOCKER_REGISTRY/multicloud-deploy:$BUILD_NUMBER'
                        archiveArtifacts artifacts: '**/trivy-*.json', fingerprint: true
                    }
                }
            }
        }
    }

    stage('Deploy') {
        when { env.BRANCH_NAME == 'develop' || env.BRANCH_NAME == 'main' }
        steps {
            // Deploy logic based on branch
            sh 'echo "Deploying $BRANCH_NAME to appropriate environment"'
        }
    }

    stage('Integration Test') {
        when { env.BRANCH_NAME == 'develop' || env.BRANCH_NAME == 'main' }
        steps {
            sh 'python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
            sh 'python tests/integration/test_deployment.py --env $BRANCH_NAME'
            junit 'integration-test-$BRANCH_NAME-$BUILD_NUMBER.xml'
        }
    }
}
```

## Environment Configuration

### 1. GitHub Secrets

Configure the following repository secrets:

| Secret                  | Description                                  | Required |
| ----------------------- | -------------------------------------------- | -------- |
| `AWS_ACCESS_KEY_ID`     | AWS access key for infrastructure deployment | Yes      |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for infrastructure deployment | Yes      |
| `AWS_S3_BUCKET`         | S3 bucket for state files and artifacts      | Yes      |
| `DEPLOYMENT_API_TOKEN`  | Token for deployment status API              | Yes      |
| `SSH_PRIVATE_KEY`       | Private key for SSH access to resources      | Yes      |
| `OCI_PRIVATE_KEY`       | OCI private key for infrastructure access    | No       |
| `OCI_CONFIG_CONTENT`    | OCI configuration content                    | No       |
| `SLACK_WEBHOOK`         | Slack webhook for notifications              | No       |

### 2. Environment Variables

**GitHub Actions:**

```yaml
# Development environment
AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
AWS_DEFAULT_REGION: us-east-1
TF_VAR_environment: dev
TF_VAR_vpc_cidr: 10.0.0.0/16

# Production environment
AWS_ACCESS_KEY_ID: ${{ secrets.AWS_PROD_ACCESS_KEY_ID }}
AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_PROD_SECRET_ACCESS_KEY }}
AWS_DEFAULT_REGION: us-east-1
TF_VAR_environment: prod
TF_VAR_vpc_cidr: 10.1.0.0/16
```

**GitLab CI/CD:**

```yaml
# Variables
variables:
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
  AWS_DEFAULT_REGION: us-east-1
  TERRAFORM_VERSION: "1.5.*"
  DOCKER_REGISTRY: ${CI_REGISTRY_IMAGE}
```

**Jenkins:**

```groovy
// Global environment
environment {
    AWS_DEFAULT_REGION = 'us-east-1'
    DOCKER_REGISTRY = 'your-registry.com'
}

// Branch-specific configuration
if (env.BRANCH_NAME == 'main') {
    // Production settings
} else if (env.BRANCH_NAME == 'develop') {
    // Development settings
}
```

## Security and Compliance

### 1. Security Best Practices

- **Credential Management**

  - Use repository secrets for sensitive data
  - Rotate credentials regularly
  - Implement least privilege access

- **Code Scanning**

  - Static analysis with SAST tools
  - Dependency scanning
  - Container vulnerability scanning

- **Infrastructure Security**

  - Use IAM roles with minimal permissions
  - Enable MFA for admin access
  - Encrypt all data in transit and at rest

- **Network Security**
  - Use private VPCs for all resources
  - Implement proper security groups
  - Use WAF and DDoS protection

### 2. Compliance Requirements

- **SOC 2 Compliance**

  - Enable CloudTrail logging
  - Implement S3 bucket policies
  - Use AWS Config Rules

- **GDPR Compliance**

  - Data encryption at rest
  - Data retention policies
  - Right to be forgotten

- **PCI DSS Compliance**
  - Secure payment processing
  - Network segmentation
  - Regular vulnerability scanning

## Monitoring and Observability

### 1. Pipeline Monitoring

**GitHub Actions Metrics**

```yaml
# Add to workflows
- name: GitHub metrics
  uses: actions/github-script-action@v6
  with:
    script: |
      echo "Workflow duration: ${{ job.status }}"
      echo "Build time: ${{ job.status }}"
```

**Custom Dashboards**

- **Grafana**: Infrastructure metrics visualization
- **Kibana**: Log aggregation and analysis
- **Prometheus**: Metrics collection
- **ELK Stack**: Centralized logging

### 2. Alerting Configuration

**Slack Integration**

```yaml
# Slack notification step
- name: Send Slack notification
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    channel: "#deployments"
    text: |
      Deployment Status: ${{ job.status }}
      Branch: ${{ github.ref }}
      Commit: ${{ github.sha }}
      Environment: ${{ environment }}
```

**Email Notifications**

```yaml
# Email notification step
- name: Send email notification
  if: always()
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 587
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    from: ${{ secrets.EMAIL_FROM }}
    to: ${{ secrets.EMAIL_TO }}
    subject: "Deployment: ${{ job.status }}"
    body: |
      Deployment Status: ${{ job.status }}
      Branch: ${{ github.ref }}
      Commit: ${{ github.sha }}
      Environment: ${{ environment }}
```

## Testing Strategy

### 1. Test Types

- **Unit Tests**

  - Test individual functions
  - Mock external dependencies
  - Achieve >80% code coverage

- **Integration Tests**

  - Test component interactions
  - Use test environments
  - Validate end-to-end functionality

- **Performance Tests**

  - Load testing
  - Stress testing
  - Response time validation

- **Security Tests**
  - Vulnerability scanning
  - Penetration testing
  - Security configuration validation

### 2. Test Automation

**Pytest Configuration**

```ini
# pytest.ini
[tool:pytest]
testpaths = tests
python_files = pytest.ini
addopts = -v --junitxml=test-results.xml
markers =
    unit: Unit tests
    integration: Integration tests
    security: Security tests
    performance: Performance tests
```

**Test Execution Script**

```bash
#!/bin/bash
# test.sh

set -e

# Environment
TEST_TYPE=${1:-all}
ENVIRONMENT=${2:-dev}
CLOUD=${3:-aws}

echo "Running tests: $TEST_TYPE for $ENVIRONMENT on $CLOUD"

# Activate virtual environment
python -m venv .venv && source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run tests based on type
case $TEST_TYPE in
    unit)
        pytest tests/unit/ --junitxml=unit-test-results.xml
        ;;
    integration)
        pytest tests/integration/test_deployment.py \
            --env $ENVIRONMENT \
            --cloud $CLOUD \
            --junitxml=integration-test-results.xml
        ;;
    security)
        pytest tests/security/ --junitxml=security-test-results.xml
        ;;
    performance)
        pytest tests/performance/ --junitxml=performance-test-results.xml
        ;;
    all)
        pytest tests/unit/ tests/integration/ --junitxml=all-tests-results.xml
        ;;
    *)
        echo "Unknown test type: $TEST_TYPE"
        exit 1
        ;;
esac

echo "Tests completed successfully"
```

### 3. Test Data Management

**Test Data Generation**

```python
# tests/fixtures/data_generator.py
import faker
import random
import json

class DataGenerator:
    def __init__(self, seed=42):
        self.fake = Faker(seed)
        self.random = random.Random(seed)

    def generate_user_data(self, count=100):
        users = []
        for _ in range(count):
            user = {
                'id': self.random.randint(1000, 9999),
                'name': self.fake.name(),
                'email': self.fake.email(),
                'address': self.fake.address(),
                'phone': self.fake.phone_number(),
                'created_at': self.fake.date_time().isoformat(),
                'active': self.fake.boolean()
            }
            users.append(user)
        return users

    def generate_order_data(self, count=200):
        orders = []
        for _ in range(count):
            order = {
                'id': self.random.randint(1000, 9999),
                'user_id': self.random.randint(1000, 9999),
                'product_id': self.random.randint(1, 100),
                'quantity': self.random.randint(1, 10),
                'total': self.random.uniform(10, 1000),
                'status': random.choice(['pending', 'completed', 'shipped']),
                'created_at': self.fake.date_time().isoformat(),
                'updated_at': self.fake.date_time().isoformat()
            }
            orders.append(order)
        return orders

    def generate_order_items(self, order_data):
        order_items = []
        for order in order_data:
            for i in range(random.randint(1, 5)):
                item = {
                    'id': f"{order['id']}-{i}",
                    'order_id': order['id'],
                    'product_name': self.fake.catch_phrase(),
                    'quantity': random.randint(1, 5),
                    'price': round(random.uniform(10, 100), 2),
                    'created_at': self.fake.date_time().isoformat()
                }
                order_items.append(item)
        return order_items

    def save_fixtures(self, output_dir='tests/fixtures'):
        import os
        os.makedirs(output_dir, exist_ok=True)

        # Generate test data
        users = self.generate_user_data()
        orders = self.generate_order_data()
        order_items = self.generate_order_items(orders)

        # Save to JSON files
        with open(os.path.join(output_dir, 'users.json'), 'w') as f:
            json.dump(users, f, indent=2)

        with open(os.path.join(output_dir, 'orders.json'), 'w') as f:
            json.dump(orders, f, indent=2)

        with open(os.path.join(output_dir, 'order_items.json'), 'w') as f:
            json.dump(order_items, f, indent=2)

        print(f"Test fixtures generated in {output_dir}")

if __name__ == '__main__':
    generator = DataGenerator()
    generator.save_fixtures()
```

**Database Seeding**

```python
# tests/database/seeder.py
import psycopg2
import json
from datetime import datetime

class DatabaseSeeder:
    def __init__(self, db_config):
        self.db_config = db_config
        self.conn = self.connect()

    def connect(self):
        """Connect to database"""
        conn = psycopg2.connect(
            host=self.db_config['host'],
            database=self.db_config['database'],
            user=self.db_config['user'],
            password=self.db_config['password'],
            port=self.db_config.get('port', 5432)
        )
        return conn

    def seed_users(self, users_data):
        """Seed users table"""
        with self.conn.cursor() as cursor:
            for user in users_data:
                cursor.execute("""
                    INSERT INTO users (id, name, email, address, phone, active, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (
                    user['id'], user['name'], user['email'], user['address'],
                    user['phone'], user['active'], user['created_at'], user['updated_at']
                ))

            self.conn.commit()
            print(f"Seeded {len(users_data)} users")

    def seed_orders(self, orders_data):
        """Seed orders table"""
        with self.conn.cursor() as cursor:
            for order in orders_data:
                cursor.execute("""
                    INSERT INTO orders (id, user_id, total, status, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (
                    order['id'], order['user_id'], order['total'], order['status'],
                    order['created_at'], order['updated_at']
                ))

            self.conn.commit()
            print(f"Seeded {len(orders_data)} orders")

    def seed_order_items(self, items_data):
        """Seed order_items table"""
        with self.conn.cursor() as cursor:
            for item in items_data:
                cursor.execute("""
                    INSERT INTO order_items (id, order_id, product_name, quantity, price, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (
                    item['id'], item['order_id'], item['product_name'],
                    item['quantity'], item['price'], item['created_at']
                ))

            self.conn.commit()
            print(f"Seeded {len(items_data)} order items")

    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()

if __name__ == '__main__':
    # Example usage
    db_config = {
        'host': 'localhost',
        'database': 'test_db',
        'user': 'postgres',
        'password': 'password'
    }

    seeder = DatabaseSeeder(db_config)

    # Load and seed test data
    with open('tests/fixtures/users.json', 'r') as f:
        users = json.load(f)

    with open('tests/fixtures/orders.json', 'r') as f:
        orders = json.load(f)

    with open('tests/fixtures/order_items.json', 'r') as f:
        items = json.load(f)

    try:
        seeder.seed_users(users)
        seeder.seed_orders(orders)
        seeder.seed_order_items(items)
        print("Database seeding completed successfully")
    except Exception as e:
        print(f"Error seeding database: {e}")
    finally:
        seeder.close()
```

## Deployment Strategies

### 1. Blue-Green Deployment

**Strategy Overview**

```mermaid
graph TD
    A[Blue Environment] -->|Deploy|
    B[Green Environment] -->|Validate|
    A -->|Rollback|
    B -->|Success|
```

**Implementation**

```bash
# blue-green-deploy.sh
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
NEW_VERSION=${2:-latest}
CURRENT_ENVIRONMENT=${3:-blue}

echo "Starting blue-green deployment: $CURRENT_ENVIRONMENT -> $NEW_VERSION"

# Switch environment label
echo "Switching to green environment"

# Deploy new version
echo "Deploying version $NEW_VERSION"
./deploy.sh $ENVIRONMENT $NEW_VERSION

# Health checks
echo "Running health checks"
./health-check.sh $ENVIRONMENT

if [ $? -eq 0 ]; then
    echo "Deployment successful, switching DNS"
    ./switch-dns.sh green
    echo "Deployment completed successfully"
else
    echo "Health checks failed, rolling back"
    ./rollback.sh $CURRENT_ENVIRONMENT
    echo "Rollback completed"
fi
```

### 2. Canary Deployment

**Canary Strategy**

```yaml
# canary-deployment.yml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
      version: canary
  template:
    metadata:
      labels:
        app: web-app
        version: canary
    spec:
      containers:
        - name: web-app
          image: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
          ports:
            - containerPort: 80
          env:
            - name: ENVIRONMENT
              value: canary
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 5m }
        - setWeight: 25
        - pause: { duration: 10m }
        - setWeight: 50
        - pause: { duration: 10m }
        - setWeight: 100
```

### 3. Progressive Delivery

**Progressive Deployment Pipeline**

```yaml
# progressive-deploy.yml
stages:
  - validate
  - deploy-1%
  - test-1%
  - deploy-10%
  - test-10%
  - deploy-50%
  - test-50%
  - deploy-100%
  - test-100%

validate:
  script:
    - echo "Validating deployment readiness"

deploy-1%:
  needs: validate
  script:
    - echo "Deploying 1% to production"
    - ./deploy.sh prod --traffic-percentage=1

test-1%:
  needs: deploy-1%
  script:
    - echo "Testing 1% deployment"
    - ./integration-tests.sh prod --traffic-percentage=1

deploy-10%:
  needs: test-1%
  script:
    - echo "Deploying 10% to production"
    - ./deploy.sh prod --traffic-percentage=10

test-10%:
  needs: deploy-10%
  script:
    - echo "Testing 10% deployment"
    - ./integration-tests.sh prod --traffic-percentage=10
# Continue with other stages...
```

## Rollback and Recovery

### 1. Automated Rollback

**Rollback Strategy**

```bash
# rollback.sh
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
ROLLBACK_VERSION=${2:-previous}

echo "Rolling back environment: $ENVIRONMENT to $ROLLBACK_VERSION"

# Get previous deployment state
echo "Retrieving deployment state from backup"
aws s3 cp "s3://$BACKUP_BUCKET/backups/$ENVIRONMENT/$ROLLBACK_VERSION/terraform-state.tar.gz" \
    ./terraform-state-backup.tar.gz

# Restore infrastructure state
echo "Restoring infrastructure state"
cd terraform/aws
tar -xzf terraform-state-backup.tar.gz
terraform init -reconfigure -backend-config=backend.tf

# Rollback infrastructure
echo "Rolling back infrastructure"
terraform apply -auto-approve -var-file=terraform.tfvars.$ROLLBACK_VERSION

# Rollback application
echo "Rolling back application"
ansible-playbook -i ansible/inventory/aws/hosts \
              ansible/playbooks/rollback.yml \
              -e "environment=$ENVIRONMENT" \
              -e "version=$ROLLBACK_VERSION"

# Validate rollback
echo "Validating rollback"
./health-check.sh $ENVIRONMENT

if [ $? -eq 0 ]; then
    echo "Rollback completed successfully"
else
    echo "Rollback validation failed"
    exit 1
fi
```

### 2. Disaster Recovery

**Recovery Procedures**

```bash
# disaster-recovery.sh
#!/bin/bash

set -e

echo "Starting disaster recovery process"

# Step 1: Assess damage
echo "Assessing infrastructure damage"
./assess-damage.sh

# Step 2: Restore from last known good backup
echo "Restoring from backup"
aws s3 cp "s3://$BACKUP_BUCKET/disaster-recovery/latest/complete-backup.tar.gz" \
    ./disaster-recovery.tar.gz

# Step 3: Deploy infrastructure
echo "Deploying infrastructure from backup"
cd disaster-recovery
terraform init -reconfigure -backend-config=backend.tf
terraform apply -auto-approve -var-file=terraform.tfvars.recovery

# Step 4: Deploy application
echo "Deploying application from backup"
ansible-playbook -i ansible/inventory/recovery/hosts \
              ansible/playbooks/deploy-from-backup.yml

# Step 5: Validate recovery
echo "Validating recovery"
./comprehensive-health-check.sh

# Step 6: Update DNS and load balancer
echo "Updating DNS and load balancer"
./update-dns.sh recovery
./update-load-balancer.sh recovery

echo "Disaster recovery process completed"
```

## Monitoring and Alerting

### 1. CI/CD Monitoring Dashboard

**Grafana Dashboard Configuration**

```json
{
  "dashboard": {
    "id": null,
    "title": "CI/CD Pipeline Dashboard",
    "tags": ["ci", "cd", "devops"],
    "timezone": "browser",
    "panels": [
      {
        "id": "deployment-status",
        "gridPos": {
          "h": 1,
          "w": 12,
          "x": 0,
          "y": 8
        },
        "type": "stat",
        "targets": [
          {
            "expr": "last(deployment_status, deployment_id)",
            "refId": "deployment-stats",
            "series": "Deployment Status",
            "target": "deployment-stats",
            "fields": [
              { "name": "Time", "type": "time" },
              { "name": "Status", "type": "number" },
              { "name": "Environment", "type": "string" },
              { "name": "Duration", "type": "number" }
            ]
          }
        ],
        "title": "Deployment Status",
        "fieldConfig": {
          "defaults": { "custom": {} },
          "overrides": {
            "Time": { "custom": { "displayMode": "calendar" } },
            "Status": { "custom": { "colorMode": "value" } }
          }
        },
        "options": {
          "legend": { "displayMode": "hidden" },
          "reduceOptions": false
        }
      },
      {
        "id": "test-results",
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 8
        },
        "type": "table",
        "targets": [
          {
            "expr": "test_results",
            "refId": "test-results",
            "format": "table",
            "table": "test_results",
            "transform": [
              {
                "id": "type",
                "type": "string"
              },
              {
                "id": "tests",
                "type": "number"
              },
              {
                "id": "failures",
                "type": "number"
              },
              {
                "id": "pass_rate",
                "type": "number",
                "format": "percentunit"
              }
            ]
          }
        ],
        "title": "Test Results",
        "options": {
          "showHeader": true
        }
      }
    ],
    "time": {
      "from": "now-30d",
      "to": "now",
      "refresh": "1m"
    },
    "schemaVersion": 27
  }
}
```

### 2. Alerting Rules

**Prometheus Alerting Configuration**

```yaml
# prometheus-rules.yml
groups:
  - name: cicd.alerts
    rules:
      - alert: DeploymentFailed
        expr: last(deployment_status, deployment_id) != 0
        for: 1m
        labels:
          severity: critical
          team: devops
          service: deployment

      - alert: TestFailureRate
        expr: (last(test_results.pass_rate, test_results.test_suite, 5m) < 80)
        for: 5m
        labels:
          severity: warning
          team: testing
          service: tests

      - alert: SlowDeployment
        expr: last(deployment_status, deployment_duration, deployment_id) > 10m
        for: 10m
        labels:
          severity: warning
          team: devops
          service: deployment
```

## Best Practices

### 1. Pipeline Optimization

- **Parallel Execution**

  - Run independent stages in parallel when possible
  - Use Docker layer caching
  - Implement smart artifact caching

- **Resource Management**

  - Use appropriate runner sizes
  - Implement auto-scaling for CI/CD runners
  - Clean up artifacts and temporary resources

- **Dependency Management**
  - Use dependency caching
  - Pin critical dependencies
  - Regular security scanning

### 2. Security Considerations

- **Pipeline Security**

  - Use encrypted secrets management
  - Implement branch protection rules
  - Require signed commits
  - Use security scanning at multiple stages

- **Infrastructure Security**

  - Use temporary credentials
  - Implement proper IAM policies
  - Regular security audits

- **Application Security**
  - Container scanning in pipeline
  - Dynamic Application Security Testing (DAST)
  - Runtime protection in production

This CI/CD setup guide provides a comprehensive framework for implementing robust, secure, and efficient deployment pipelines for your AWS infrastructure project.
