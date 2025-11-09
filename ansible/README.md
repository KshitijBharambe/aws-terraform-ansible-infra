# Ansible Configuration Management

This directory contains the complete Ansible configuration management system for the AWS Terraform Infrastructure project.

## 📁 Directory Structure

```
ansible/
├── ansible.cfg                 # Main Ansible configuration
├── inventory/
│   ├── localstack.ini         # Static inventory for LocalStack
│   ├── aws_ec2.yml           # Dynamic inventory for AWS EC2
│   └── group_vars/
│       ├── all.yml            # Global variables
│       ├── webservers.yml     # Web server specific variables
│       └── appservers.yml      # App server specific variables
├── playbooks/
│   ├── site.yml               # Master site playbook
│   ├── hardening.yml          # Security hardening playbook
│   ├── monitoring.yml          # Monitoring setup playbook
│   ├── webserver.yml           # Web server configuration
│   ├── backup.yml              # Backup configuration
│   └── update.yml              # System updates
├── roles/
│   ├── common/                # Common tasks for all servers
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   ├── defaults/main.yml
│   │   └── templates/
│   ├── security/              # Security hardening role
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── ssh.yml
│   │   │   ├── firewall.yml
│   │   │   ├── fail2ban.yml
│   │   │   └── auditd.yml
│   │   ├── handlers/main.yml
│   │   ├── defaults/main.yml
│   │   └── templates/
│   │       ├── sshd_config.j2
│   │       └── jail.local.j2
│   ├── monitoring/            # Monitoring and observability
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   └── cloudwatch.yml
│   │   ├── defaults/main.yml
│   │   └── handlers/main.yml
│   ├── webserver/            # Web server configuration
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── handlers/main.yml
│   └── backup/               # Backup automation
│       ├── tasks/main.yml
│       ├── defaults/main.yml
│       └── handlers/main.yml
└── requirements.yml            # Ansible Galaxy dependencies
```

## 🚀 Quick Start

### Prerequisites

1. **Install Ansible:**

   ```bash
   pip install ansible
   ```

2. **Install required collections:**

   ```bash
   ansible-galaxy install -r requirements.yml
   ```

3. **Configure SSH access:**
   ```bash
   # Add your SSH key to the instances
   ssh-copy-id -i ~/.ssh/id_rsa ubuntu@<instance-ip>
   ```

### Running Playbooks

#### 1. Full Site Configuration

Configure all servers with common settings, security, monitoring, and role-specific configurations:

```bash
# For LocalStack
ansible-playbook -i inventory/localstack.ini playbooks/site.yml

# For AWS
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
```

#### 2. Security Hardening

Apply comprehensive security hardening:

```bash
ansible-playbook -i inventory/aws_ec2.yml playbooks/hardening.yml --tags security,hardening
```

#### 3. Monitoring Setup

Configure monitoring and observability:

```bash
ansible-playbook -i inventory/aws_ec2.yml playbooks/monitoring.yml --tags monitoring,setup
```

#### 4. Web Server Configuration

Configure web servers only:

```bash
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml --tags web,webservers
```

#### 5. Backup Configuration

Setup backup automation:

```bash
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml --tags backup
```

## 🔧 Configuration

### Inventory Variables

Key variables defined in `inventory/group_vars/`:

- **`all.yml`**: Global settings for all hosts
- **`webservers.yml`**: Web server specific configurations
- **`appservers.yml`**: Application server specific configurations

### Role Variables

Each role includes comprehensive default variables that can be overridden:

#### Common Role

- System packages and utilities
- User management and SSH keys
- Timezone and hostname configuration
- Directory structure

#### Security Role

- SSH hardening (port, authentication, etc.)
- Firewall configuration (UFW)
- Fail2ban intrusion prevention
- Audit logging (auditd)
- System hardening parameters

#### Monitoring Role

- CloudWatch agent configuration
- System performance monitoring
- Log collection and forwarding
- Custom metrics and alerts
- Health checks and status pages

#### Web Server Role

- Nginx/Apache configuration
- SSL/TLS setup
- Virtual hosting
- Performance optimization
- Security headers and hardening

#### Backup Role

- Automated backup schedules
- S3 integration
- Backup verification
- Retention policies

## 🔒 Security Features

### SSH Hardening

- Disable root login
- Key-only authentication
- Custom SSH port
- Connection limits
- Security banners
- Session timeouts

### Firewall Configuration

- UFW with default deny policy
- Port-based access control
- Rate limiting
- ICMP ping allowed
- Comprehensive logging

### Intrusion Prevention

- Fail2ban with custom jails
- SSH brute force protection
- Web server attack prevention
- Email notifications
- IP whitelist/blacklist

### Audit Logging

- Comprehensive system audit rules
- File system change tracking
- User/group modification logging
- Network configuration monitoring
- Automated audit reports

## 📊 Monitoring Capabilities

### CloudWatch Integration

- Custom metrics collection
- Log forwarding to CloudWatch
- Automated alarms
- Dashboard integration
- Cost-optimized monitoring

### System Monitoring

- CPU, memory, disk usage
- Service health checks
- Process monitoring
- Network statistics
- Performance tuning

### Application Monitoring

- Custom application metrics
- Health check endpoints
- Error tracking
- Performance profiling

## 🔄 Backup & Recovery

### Automated Backups

- Scheduled system backups
- Database dumps (if applicable)
- Configuration backups
- Log backups
- Application data backups

### Cloud Storage

- S3 integration
- Cross-region replication
- Lifecycle policies
- Cost optimization

### Recovery Procedures

- Automated verification
- Point-in-time recovery
- Disaster recovery drills
- Restoration testing

## 🛠️ Customization

### Adding New Roles

1. Create role directory: `ansible-galaxy init <role-name>`
2. Add tasks, handlers, templates
3. Update requirements.yml
4. Test with specific playbook

### Custom Variables

- Environment-specific overrides
- Secret management with Ansible Vault
- Dynamic configuration generation
- Template-based customization

### Integration Points

- Custom monitoring agents
- Third-party security tools
- Additional backup destinations
- Custom alerting channels

## 📋 Best Practices

### Security

1. **Always use SSH keys, never passwords**
2. **Limit sudo access to necessary users**
3. **Regular security audits**
4. **Keep Ansible Vault for secrets**
5. **Monitor security logs**

### Performance

1. **Use idempotent playbooks**
2. **Limit task execution time**
3. **Implement proper error handling**
4. **Use appropriate connection methods**
5. **Monitor playbook execution**

### Maintenance

1. **Regular backup testing**
2. **Update dependencies**
3. **Clean up old configurations**
4. **Document customizations**
5. **Monitor system health**

## 🔍 Troubleshooting

### Common Issues

#### SSH Connection Problems

```bash
# Check connectivity
ansible <hostname> -m ping

# Test SSH specifically
ansible <hostname> -m command -a "echo 'SSH test'"

# Verbose output
ansible-playbook -i inventory <hostname> --verbose
```

#### Permission Issues

```bash
# Check become method
ansible-playbook -i inventory <hostname> --ask-become-pass

# Verify user permissions
ansible <hostname> -m command -a "whoami"
```

#### Module/Collection Issues

```bash
# Install missing collections
ansible-galaxy collection install community.general

# Check collection paths
ansible-galaxy collection list
```

### Debug Commands

```bash
# Dry run
ansible-playbook -i inventory <playbook> --check

# Step-by-step execution
ansible-playbook -i inventory <playbook> --step

# Variable debugging
ansible-playbook -i inventory <playbook> -e "var=value" --verbose
```

## 📚 Additional Resources

### Documentation

- [Ansible Official Documentation](https://docs.ansible.com/)
- [Best Practices Guide](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Security Hardening Guide](https://docs.ansible.com/ansible/latest/user_guide/security_best_practices.html)

### Community Resources

- [Ansible Galaxy](https://galaxy.ansible.com/)
- [Community Roles](https://github.com/ansible-community)
- [Security Hardening Roles](https://github.com/geerlingguy/security)

### Training and Certification

- [Ansible Certification](https://www.ansible.com/resources/certification/)
- [Ansible Workshops](https://github.com/ansible/workshops)
- [DevOps Tutorials](https://github.com/ansible/ansible-examples)

## 🤝 Contributing

### Development Guidelines

1. Follow Ansible best practices
2. Use descriptive variable names
3. Implement proper error handling
4. Add comprehensive testing
5. Document all customizations

### Testing

1. Use Molecule for role testing
2. Test with multiple OS versions
3. Validate syntax and lint
4. Security scan with ansible-lint
5. Integration testing

### Deployment

1. Use environment-specific inventories
2. Implement rolling updates
3. Test in staging first
4. Monitor deployment success
5. Have rollback procedures

## 📞 Support

For issues and questions:

1. Check troubleshooting section
2. Review Ansible documentation
3. Search existing issues
4. Ask in community forums
5. Create detailed bug reports

---

**This Ansible configuration provides enterprise-grade automation with comprehensive security, monitoring, and backup capabilities for your AWS infrastructure.**
