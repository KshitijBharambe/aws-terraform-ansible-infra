# 🚀 Enterprise Multi-Cloud Infrastructure Provisioner

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-%3E%3D2.15-EE0000?logo=ansible)](https://www.ansible.com/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![LocalStack](https://img.shields.io/badge/LocalStack-Dev-00A4EF?logo=localstack)](https://localstack.cloud/)

A production-ready, automated infrastructure provisioning framework demonstrating Infrastructure as Code (IaC), Configuration Management, and DevSecOps best practices.

## 🎯 Overview

This project provides a complete infrastructure automation solution that can be developed locally with **zero cost** using LocalStack, then deployed to AWS with minimal expenses (~$1-2/month).

### Key Features

- **Zero-Cost Development**: Full AWS emulation with LocalStack
- **Minimal Production Costs**: <$2/month with on-demand deployment
- **Production-Ready**: Security hardening, monitoring, best practices built-in
- **Multi-Cloud Ready**: Extensible to Oracle Cloud Infrastructure
- **Portfolio-Worthy**: Demonstrates advanced DevOps skills

## 📦 Prerequisites

### Required Tools

- **Docker Desktop** (with Docker Compose v2.0+)
- **Terraform** >= 1.5.0
- **Ansible** >= 2.15
- **AWS CLI** >= 2.0
- **Python** >= 3.8
- **Git**

### Installation (macOS)

```bash
# Core tools
brew install terraform ansible awscli docker python

# Optional tools
brew install terraform-docs tfsec
pip3 install awscli-local ansible-lint

# Verify installations
terraform version
ansible --version
docker --version
aws --version
```

## 🚀 Quick Start

### Step 1: Start LocalStack

```bash
cd docker
docker-compose up -d
```

Wait 15-30 seconds for LocalStack to initialize.

### Step 2: Initialize Terraform

```bash
cd terraform/localstack
terraform init
```

### Step 3: Deploy Infrastructure

```bash
# Review what will be created
terraform plan

# Deploy resources
terraform apply
```

### Step 4: Verify Deployment

```bash
# View outputs
terraform output

# Check resources with AWS CLI
awslocal s3 ls
awslocal ec2 describe-security-groups
```

### Step 5: Clean Up

```bash
terraform destroy
cd ../../docker
docker-compose down
```

## 📁 Project Structure

```
aws-terraform-ansible-infra/
├── docker/                  # LocalStack configuration
│   ├── docker-compose.yml
│   └── localstack-init.sh
├── terraform/
│   └── localstack/          # LocalStack environment
│       ├── providers.tf
│       ├── backend.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── main.tf
│       └── outputs.tf
├── scripts/                 # Automation scripts
├── ansible/                 # Configuration management (Phase 3)
└── README.md               # This file
```

## 💰 Cost Management

### LocalStack Development
- **Cost**: $0/month
- **Use**: Development, testing, learning

### AWS On-Demand Strategy
- **Fixed Costs**: ~$0.10/month (S3 state storage)
- **Per Demo Session** (3 hours): ~$0.15-0.20
- **Monthly Total** (3 demos): ~$1-2/month

## 🎓 Learning Outcomes

This project demonstrates:
- ✅ Infrastructure as Code (Terraform)
- ✅ Configuration Management (Ansible)
- ✅ Cloud Architecture (AWS)
- ✅ DevOps Automation
- ✅ Security Best Practices
- ✅ Cost Optimization
- ✅ Technical Documentation

## 📚 Next Steps

### Current Status: Phase 1 Complete ✅
- LocalStack environment configured
- Terraform test resources deployed
- Automation scripts created

### Coming Next: Phase 2
- Create VPC module
- Implement compute resources
- Add security module
- Build load balancer module

## 🔧 Troubleshooting

### LocalStack Won't Start

```bash
# Check Docker
docker ps

# Restart LocalStack
cd docker
docker-compose restart
```

### Terraform Errors

```bash
# Clean and reinitialize
cd terraform/localstack
rm -rf .terraform
terraform init
```

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- [Terraform](https://www.terraform.io/) by HashiCorp
- [Ansible](https://www.ansible.com/) by Red Hat
- [LocalStack](https://localstack.cloud/) for local AWS emulation

---

**Built for learning and demonstration purposes** 🚀

⭐ If you find this project helpful, please star it!
