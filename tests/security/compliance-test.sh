#!/bin/bash

# Security Compliance Testing Script
# Tests for CIS benchmarks and security compliance

set -e

echo "🔒 Starting Security Compliance Testing..."
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track compliance results
COMPLIANCE_PASSED=0
COMPLIANCE_FAILED=0
COMPLIANCE_WARNINGS=0

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
            ((COMPLIANCE_WARNINGS++))
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            ((COMPLIANCE_FAILED++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to test CIS Ubuntu 20.04 benchmarks
test_cis_ubuntu() {
    print_status "INFO" "Testing CIS Ubuntu 20.04 Benchmarks..."
    
    # Section 1: Initial Setup
    print_status "INFO" "Section 1: Initial Setup"
    
    # 1.1.1.1 Ensure mounting of cramfs filesystems is disabled
    if grep -q "install cramfs /bin/false" /etc/modprobe.d/*.conf 2>/dev/null || \
       grep -q "blacklist cramfs" /etc/modprobe.d/*.conf 2>/dev/null; then
        print_status "PASS" "1.1.1.1 cramfs filesystem disabled"
    else
        print_status "WARN" "1.1.1.1 cramfs filesystem not disabled"
    fi
    
    # 1.1.1.2 Ensure mounting of squashfs filesystems is disabled
    if grep -q "install squashfs /bin/false" /etc/modprobe.d/*.conf 2>/dev/null || \
       grep -q "blacklist squashfs" /etc/modprobe.d/*.conf 2>/dev/null; then
        print_status "PASS" "1.1.1.2 squashfs filesystem disabled"
    else
        print_status "WARN" "1.1.1.2 squashfs filesystem not disabled"
    fi
    
    # 1.1.1.3 Ensure mounting of udf filesystems is disabled
    if grep -q "install udf /bin/false" /etc/modprobe.d/*.conf 2>/dev/null || \
       grep -q "blacklist udf" /etc/modprobe.d/*.conf 2>/dev/null; then
        print_status "PASS" "1.1.1.3 udf filesystem disabled"
    else
        print_status "WARN" "1.1.1.3 udf filesystem not disabled"
    fi
    
    # Section 2: Services
    print_status "INFO" "Section 2: Services"
    
    # 2.2.1 Ensure time synchronization is in use
    if systemctl is-active --quiet chrony 2>/dev/null || \
       systemctl is-active --quiet ntp 2>/dev/null || \
       systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        print_status "PASS" "2.2.1 Time synchronization is active"
    else
        print_status "WARN" "2.2.1 Time synchronization not active"
    fi
    
    # 2.2.2 Ensure ntp is configured (if ntp is used)
    if [ -f "/etc/ntp.conf" ]; then
        if grep -q "^restrict.*-4.*default.*kod.*nomodify.*notrap.*nopeer.*noquery" /etc/ntp.conf 2>/dev/null; then
            print_status "PASS" "2.2.2 ntp restrict configured"
        else
            print_status "WARN" "2.2.2 ntp restrict not properly configured"
        fi
    fi
    
    # Section 3: Network Configuration
    print_status "INFO" "Section 3: Network Configuration"
    
    # 3.1.1 Ensure IP forwarding is disabled
    if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "0" ]; then
        print_status "PASS" "3.1.1 IP forwarding is disabled"
    else
        print_status "WARN" "3.1.1 IP forwarding is enabled"
    fi
    
    # 3.1.2 Ensure packet redirect sending is disabled
    if [ "$(sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null)" = "0" ]; then
        print_status "PASS" "3.1.2 Packet redirect sending is disabled"
    else
        print_status "WARN" "3.1.2 Packet redirect sending is enabled"
    fi
    
    # Section 4: Logging and Auditing
    print_status "INFO" "Section 4: Logging and Auditing"
    
    # 4.1.1.1 Ensure auditd is installed
    if command -v auditd >/dev/null 2>&1; then
        print_status "PASS" "4.1.1.1 auditd is installed"
    else
        print_status "WARN" "4.1.1.1 auditd is not installed"
    fi
    
    # 4.1.1.2 Ensure auditd service is enabled and running
    if systemctl is-enabled --quiet auditd 2>/dev/null && \
       systemctl is-active --quiet auditd 2>/dev/null; then
        print_status "PASS" "4.1.1.2 auditd service is enabled and running"
    else
        print_status "WARN" "4.1.1.2 auditd service is not enabled or running"
    fi
    
    # 4.2.1.1 Ensure logging is configured
    if [ -f "/etc/rsyslog.conf" ] || [ -f "/etc/syslog-ng/syslog-ng.conf" ]; then
        print_status "PASS" "4.2.1.1 Logging is configured"
    else
        print_status "WARN" "4.2.1.1 Logging is not configured"
    fi
    
    # Section 5: Access, Authentication and Authorization
    print_status "INFO" "Section 5: Access, Authentication and Authorization"
    
    # 5.2.1 Ensure sudoers file is configured
    if [ -f "/etc/sudoers" ]; then
        if grep -q "env_reset" /etc/sudoers 2>/dev/null; then
            print_status "PASS" "5.2.1 sudoers env_reset configured"
        else
            print_status "WARN" "5.2.1 sudoers env_reset not configured"
        fi
        
        if ! grep -q "!tty_tickets" /etc/sudoers 2>/dev/null; then
            print_status "PASS" "5.2.1 sudoers tty_tickets not disabled"
        else
            print_status "INFO" "5.2.1 sudoers tty_tickets disabled"
        fi
    fi
    
    # Section 6: System Maintenance
    print_status "INFO" "Section 6: System Maintenance"
    
    # 6.1.1 Ensure system-wide crypto policy is not set to LEGACY
    if command -v update-crypto-policies >/dev/null 2>&1; then
        if ! update-crypto-policies --show | grep -q "LEGACY" 2>/dev/null; then
            print_status "PASS" "6.1.1 Crypto policy not set to LEGACY"
        else
            print_status "WARN" "6.1.1 Crypto policy set to LEGACY"
        fi
    fi
}

# Function to test SSH hardening compliance
test_ssh_compliance() {
    print_status "INFO" "Testing SSH Security Compliance..."
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [ ! -f "$sshd_config" ]; then
        print_status "WARN" "SSH configuration file not found"
        return
    fi
    
    # Test SSH hardening settings
    # Protocol 2 only
    if grep -q "^Protocol.*2" "$sshd_config" 2>/dev/null || \
       ! grep -q "^Protocol" "$sshd_config" 2>/dev/null; then
        print_status "PASS" "SSH Protocol 2 enforced"
    else
        print_status "WARN" "SSH Protocol not properly configured"
    fi
    
    # Disable root login
    if grep -q "^PermitRootLogin.*no" "$sshd_config" 2>/dev/null; then
        print_status "PASS" "Root login via SSH disabled"
    else
        print_status "FAIL" "Root login via SSH not disabled"
    fi
    
    # Disable password authentication
    if grep -q "^PasswordAuthentication.*no" "$sshd_config" 2>/dev/null; then
        print_status "PASS" "SSH password authentication disabled"
    else
        print_status "WARN" "SSH password authentication not disabled"
    fi
    
    # Disable empty passwords
    if grep -q "^PermitEmptyPasswords.*no" "$sshd_config" 2>/dev/null || \
       ! grep -q "^PermitEmptyPasswords" "$sshd_config" 2>/dev/null; then
        print_status "PASS" "SSH empty passwords disabled"
    else
        print_status "FAIL" "SSH empty passwords not disabled"
    fi
    
    # Set MaxAuthTries
    if grep -q "^MaxAuthTries.*[1-4]" "$sshd_config" 2>/dev/null; then
        print_status "PASS" "SSH MaxAuthTries properly configured"
    else
        print_status "WARN" "SSH MaxAuthTries not properly configured"
    fi
    
    # Set ClientAliveInterval
    if grep -q "^ClientAliveInterval.*[1-9]" "$sshd_config" 2>/dev/null; then
        print_status "PASS" "SSH ClientAliveInterval configured"
    else
        print_status "WARN" "SSH ClientAliveInterval not configured"
    fi
    
    # Disable X11 forwarding
    if grep -q "^X11Forwarding.*no" "$sshd_config" 2>/dev/null; then
        print_status "PASS" "SSH X11 forwarding disabled"
    else
        print_status "INFO" "SSH X11 forwarding may be enabled"
    fi
}

# Function to test firewall configuration
test_firewall_compliance() {
    print_status "INFO" "Testing Firewall Compliance..."
    
    # Check if UFW is installed
    if command -v ufw >/dev/null 2>&1; then
        print_status "PASS" "UFW firewall is installed"
        
        # Check if UFW is active
        if ufw status | grep -q "Status: active"; then
            print_status "PASS" "UFW firewall is active"
        else
            print_status "WARN" "UFW firewall is not active"
        fi
        
        # Check default policies
        if ufw status verbose | grep -q "Default deny (incoming)"; then
            print_status "PASS" "UFW default deny incoming policy"
        else
            print_status "WARN" "UFW default deny incoming not set"
        fi
        
        # Check for open ports
        local open_ports=$(ufw status | grep -c "ALLOW.*Anywhere" 2>/dev/null || echo "0")
        if [ "$open_ports" -le 3 ]; then
            print_status "PASS" "Limited open ports ($open_ports)"
        else
            print_status "WARN" "Many open ports ($open_ports)"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        print_status "PASS" "firewalld firewall is installed"
        
        if firewall-cmd --state >/dev/null 2>&1; then
            print_status "PASS" "firewalld is running"
        else
            print_status "WARN" "firewalld is not running"
        fi
    else
        print_status "WARN" "No firewall management tool found"
    fi
}

# Function to test file system permissions
test_filesystem_permissions() {
    print_status "INFO" "Testing File System Permissions..."
    
    # Check /etc/shadow permissions
    if [ -f "/etc/shadow" ]; then
        local shadow_perms=$(stat -c "%a" /etc/shadow 2>/dev/null || echo "000")
        if [ "$shadow_perms" = "000" ] || [ "$shadow_perms" = "600" ]; then
            print_status "PASS" "/etc/shadow has proper permissions ($shadow_perms)"
        else
            print_status "WARN" "/etc/shadow has weak permissions ($shadow_perms)"
        fi
    fi
    
    # Check /etc/passwd permissions
    if [ -f "/etc/passwd" ]; then
        local passwd_perms=$(stat -c "%a" /etc/passwd 2>/dev/null || echo "644")
        if [ "$passwd_perms" = "644" ] || [ "$passwd_perms" = "640" ]; then
            print_status "PASS" "/etc/passwd has proper permissions ($passwd_perms)"
        else
            print_status "WARN" "/etc/passwd has unusual permissions ($passwd_perms)"
        fi
    fi
    
    # Check /etc/gshadow permissions
    if [ -f "/etc/gshadow" ]; then
        local gshadow_perms=$(stat -c "%a" /etc/gshadow 2>/dev/null || echo "000")
        if [ "$gshadow_perms" = "000" ] || [ "$gshadow_perms" = "600" ]; then
            print_status "PASS" "/etc/gshadow has proper permissions ($gshadow_perms)"
        else
            print_status "WARN" "/etc/gshadow has weak permissions ($gshadow_perms)"
        fi
    fi
    
    # Check world-writable files
    local writable_files=$(find / -type f -perm -002 2>/dev/null | wc -l || echo "0")
    if [ "$writable_files" -eq 0 ]; then
        print_status "PASS" "No world-writable files found"
    else
        print_status "WARN" "Found $writable_files world-writable files"
    fi
    
    # Check SUID/SGID files
    local suid_files=$(find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l || echo "0")
    if [ "$suid_files" -le 10 ]; then
        print_status "PASS" "Limited SUID/SGID files ($suid_files)"
    else
        print_status "WARN" "Many SUID/SGID files ($suid_files)"
    fi
}

# Function to test service hardening
test_service_hardening() {
    print_status "INFO" "Testing Service Hardening..."
    
    # Check unnecessary services
    local unnecessary_services=("telnet" "rsh" "rlogin" "ypbind" "tftp")
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            print_status "WARN" "Unnecessary service $service is enabled"
        else
            print_status "PASS" "Service $service is disabled"
        fi
    done
    
    # Check for cron daemon
    if systemctl is-active --quiet cron 2>/dev/null || \
       systemctl is-active --quiet crond 2>/dev/null; then
        print_status "PASS" "Cron daemon is running"
    else
        print_status "WARN" "Cron daemon is not running"
    fi
    
    # Check for fail2ban
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        print_status "PASS" "fail2ban is running"
    else
        print_status "WARN" "fail2ban is not running"
    fi
    
    # Check for AppArmor
    if command -v aa-status >/dev/null 2>&1; then
        print_status "PASS" "AppArmor is available"
        if aa-status --enabled >/dev/null 2>&1; then
            print_status "PASS" "AppArmor is enabled"
        else
            print_status "WARN" "AppArmor is not enabled"
        fi
    fi
}

# Function to test kernel security parameters
test_kernel_security() {
    print_status "INFO" "Testing Kernel Security Parameters..."
    
    # Check kernel parameters
    local sysctl_params=(
        "net.ipv4.conf.all.send_redirects:0"
        "net.ipv4.conf.default.send_redirects:0"
        "net.ipv4.conf.all.accept_source_route:0"
        "net.ipv4.conf.default.accept_source_route:0"
        "net.ipv4.conf.all.accept_redirects:0"
        "net.ipv4.conf.default.accept_redirects:0"
        "net.ipv4.conf.all.secure_redirects:0"
        "net.ipv4.conf.default.secure_redirects:0"
        "net.ipv4.conf.all.log_martians:1"
        "net.ipv4.conf.default.log_martians:1"
        "net.ipv4.icmp_echo_ignore_broadcasts:1"
        "net.ipv4.icmp_ignore_bogus_error_responses:1"
        "net.ipv4.tcp_syncookies:1"
    )
    
    for param in "${sysctl_params[@]}"; do
        local key=$(echo "$param" | cut -d: -f1)
        local expected=$(echo "$param" | cut -d: -f2)
        local current=$(sysctl -n "$key" 2>/dev/null || echo "N/A")
        
        if [ "$current" = "$expected" ]; then
            print_status "PASS" "Kernel parameter $key = $current"
        else
            print_status "WARN" "Kernel parameter $key = $current (expected $expected)"
        fi
    done
}

# Function to test Ansible security compliance
test_ansible_security() {
    print_status "INFO" "Testing Ansible Security Compliance..."
    
    # Check for Ansible Vault usage
    if find ansible/ -name "*.vault" 2>/dev/null | head -1 | grep -q .; then
        print_status "PASS" "Ansible Vault files found"
    else
        print_status "INFO" "No Ansible Vault files found"
    fi
    
    # Check for hardcoded secrets
    if grep -r -i "password\|secret\|key\|token" ansible/ --include="*.yml" --include="*.yaml" 2>/dev/null | \
       grep -v "{{.*}}" | grep -v "\${.*}" | grep -v "ansible_user" | head -1 | grep -q .; then
        print_status "WARN" "Potential hardcoded secrets in Ansible files"
    else
        print_status "PASS" "No obvious hardcoded secrets in Ansible files"
    fi
    
    # Check for privilege escalation usage
    local become_usage=$(find ansible/ -name "*.yml" -exec grep -l "become:" {} \; 2>/dev/null | wc -l || echo "0")
    if [ "$become_usage" -gt 0 ]; then
        print_status "INFO" "Found $become_usage files using privilege escalation"
    else
        print_status "INFO" "No privilege escalation usage found"
    fi
    
    # Check security role implementation
    if [ -f "ansible/roles/security/tasks/main.yml" ]; then
        print_status "PASS" "Security role exists"
        
        # Check for security tasks
        if grep -q "ufw\|firewall\|fail2ban\|auditd" ansible/roles/security/tasks/main.yml 2>/dev/null; then
            print_status "PASS" "Security role contains security tasks"
        else
            print_status "WARN" "Security role may be incomplete"
        fi
    else
        print_status "WARN" "Security role not found"
    fi
}

# Function to test Terraform security compliance
test_terraform_security() {
    print_status "INFO" "Testing Terraform Security Compliance..."
    
    # Check for encrypted resources
    if grep -r "encrypted.*true" terraform/ --include="*.tf" 2>/dev/null | head -1 | grep -q .; then
        print_status "PASS" "Encrypted resources found in Terraform"
    else
        print_status "INFO" "No encrypted resources specified in Terraform"
    fi
    
    # Check for security groups
    if grep -r "aws_security_group" terraform/ --include="*.tf" 2>/dev/null | head -1 | grep -q .; then
        print_status "PASS" "Security groups defined in Terraform"
    else
        print_status "WARN" "No security groups found in Terraform"
    fi
    
    # Check for IAM roles and policies
    if grep -r "aws_iam_role\|aws_iam_policy" terraform/ --include="*.tf" 2>/dev/null | head -1 | grep -q .; then
        print_status "PASS" "IAM resources defined in Terraform"
    else
        print_status "INFO" "No IAM resources found in Terraform"
    fi
    
    # Check for VPC configuration
    if grep -r "aws_vpc" terraform/ --include="*.tf" 2>/dev/null | head -1 | grep -q .; then
        print_status "PASS" "VPC configured in Terraform"
    else
        print_status "WARN" "No VPC configuration found in Terraform"
    fi
    
    # Check for resource tagging
    if grep -r "tags.*=" terraform/ --include="*.tf" 2>/dev/null | head -1 | grep -q .; then
        print_status "PASS" "Resource tagging implemented in Terraform"
    else
        print_status "WARN" "No resource tagging found in Terraform"
    fi
}

# Function to generate compliance report
generate_compliance_report() {
    local report_file="reports/security-compliance-report.txt"
    
    mkdir -p reports
    
    cat > "$report_file" << EOF
Security Compliance Test Report
=============================

Generated: $(date)
Environment: $(uname -a)

Compliance Summary:
------------------
Tests Passed: $COMPLIANCE_PASSED
Tests Failed: $COMPLIANCE_FAILED
Tests Warnings: $COMPLIANCE_WARNINGS

Compliance Areas Tested:
---------------------
1. CIS Ubuntu 20.04 Benchmarks
2. SSH Security Configuration
3. Firewall Configuration
4. File System Permissions
5. Service Hardening
6. Kernel Security Parameters
7. Ansible Security Practices
8. Terraform Security Practices

Security Recommendations:
-----------------------
1. Enable and configure firewalls on all systems
2. Use SSH key-based authentication only
3. Implement regular security updates
4. Enable and configure audit logging
5. Use least-privilege access controls
6. Encrypt all sensitive data at rest
7. Implement network segmentation
8. Regular security scanning and monitoring

Compliance Standards:
-------------------
- CIS Ubuntu 20.04 Benchmark
- NIST Cybersecurity Framework
- AWS Security Best Practices
- Industry Standard Hardening

Next Steps:
-----------
1. Address all FAILED compliance checks
2. Review and mitigate WARNING level issues
3. Implement continuous compliance monitoring
4. Schedule regular security assessments
5. Document security procedures and policies

EOF
    
    print_status "PASS" "Compliance report generated: $report_file"
}

# Function to check if running as root (required for some tests)
check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        print_status "WARN" "Some compliance checks require root privileges"
        print_status "INFO" "Running with limited privileges - some tests may be skipped"
        return 1
    else
        print_status "PASS" "Running with root privileges - all tests available"
        return 0
    fi
}

# Main execution
echo ""
print_status "INFO" "Starting comprehensive security compliance testing..."

# Check privileges
check_root_privileges

# Run compliance tests
echo ""
print_status "INFO" "=== CIS Ubuntu 20.04 Benchmarks ==="
if test_cis_ubuntu; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

echo ""
print_status "INFO" "=== SSH Security Compliance ==="
if test_ssh_compliance; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

echo ""
print_status "INFO" "=== Firewall Compliance ==="
if test_firewall_compliance; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

echo ""
print_status "INFO" "=== File System Permissions ==="
if test_filesystem_permissions; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

echo ""
print_status "INFO" "=== Service Hardening ==="
if test_service_hardening; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

echo ""
print_status "INFO" "=== Kernel Security Parameters ==="
if test_kernel_security; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

echo ""
print_status "INFO" "=== Ansible Security Compliance ==="
if test_ansible_security; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

echo ""
print_status "INFO" "=== Terraform Security Compliance ==="
if test_terraform_security; then
    ((COMPLIANCE_PASSED++))
else
    ((COMPLIANCE_FAILED++))
fi

# Generate report
generate_compliance_report

# Summary
echo ""
echo "======================================"
echo "🏁 Security Compliance Test Summary"
echo "======================================"

echo "📊 Compliance Results:"
echo "   Passed: $COMPLIANCE_PASSED"
echo "   Failed: $COMPLIANCE_FAILED"
echo "   Warnings: $COMPLIANCE_WARNINGS"
echo "   Total: $((COMPLIANCE_PASSED + COMPLIANCE_FAILED + COMPLIANCE_WARNINGS))"

if [ $COMPLIANCE_FAILED -eq 0 ]; then
    print_status "PASS" "No critical compliance failures found!"
    if [ $COMPLIANCE_WARNINGS -eq 0 ]; then
        print_status "PASS" "Excellent security compliance! 🎉"
    else
        print_status "INFO" "Some areas need attention for full compliance"
    fi
else
    print_status "FAIL" "Found $COMPLIANCE_FAILED critical compliance issue(s)"
    echo ""
    echo "🚨 Immediate action required for compliance failures!"
fi

echo ""
echo "📋 Security Compliance Score: $(( (COMPLIANCE_PASSED * 100) / (COMPLIANCE_PASSED + COMPLIANCE_FAILED) ))%"

echo ""
echo "🔧 Security Improvement Recommendations:"
echo "   1. Address all FAILED compliance checks immediately"
echo "   2. Review WARNING level issues for improvement"
echo "   3. Implement automated security monitoring"
echo "   4. Schedule regular security assessments"
echo "   5. Maintain security documentation and procedures"
echo "   6. Implement security training for team members"
echo "   7. Use security scanning tools in CI/CD pipeline"
echo "   8. Regularly update security patches and configurations"

exit 0
