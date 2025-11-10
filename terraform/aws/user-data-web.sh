#!/bin/bash
# User data script for web servers
# Installs and configures basic web server stack

set -euo pipefail

# Update system
yum update -y

# Install basic packages
yum install -y httpd php php-mysqlnd wget curl unzip

# Start and enable web server
systemctl start httpd
systemctl enable httpd

# Create basic web page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Infrastructure Demo - Web Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            color: #333;
            border-bottom: 2px solid #007acc;
            padding-bottom: 10px;
        }
        .info {
            margin: 20px 0;
            padding: 15px;
            background-color: #e7f3ff;
            border-radius: 5px;
        }
        .status {
            color: #28a745;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="header">AWS Infrastructure Demo</h1>
        <div class="info">
            <h2>Web Server Status: <span class="status">ONLINE</span></h2>
            <p><strong>Server Information:</strong></p>
            <ul>
                <li>Instance ID: <span id="instance-id">Loading...</span></li>
                <li>Region: <span id="region">Loading...</span></li>
                <li>Availability Zone: <span id="az">Loading...</span></li>
                <li>Public IP: <span id="public-ip">Loading...</span></li>
                <li>Deployment Time: <span id="deploy-time">$(date)</span></li>
            </ul>
        </div>
        <p><em>This web server was deployed using Terraform and configured via user data.</em></p>
    </div>

    <script>
        // Fetch instance metadata
        fetch('http://169.254.169.254/latest/meta-data/instance-id')
            .then(response => response.text())
            .then(data => document.getElementById('instance-id').textContent = data);
        
        fetch('http://169.254.169.254/latest/meta-data/placement/region')
            .then(response => response.text())
            .then(data => document.getElementById('region').textContent = data);
        
        fetch('http://169.254.169.254/latest/meta-data/placement/availability-zone')
            .then(response => response.text())
            .then(data => document.getElementById('az').textContent = data);
        
        fetch('http://169.254.169.254/latest/meta-data/public-ipv4')
            .then(response => response.text())
            .then(data => document.getElementById('public-ip').textContent = data);
    </script>
</body>
</html>
EOF

# Create PHP info page for testing
cat > /var/www/html/info.php << 'EOF'
<?php
phpinfo();
?>
EOF

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Create log directory for application
mkdir -p /var/log/webapp
touch /var/log/webapp/access.log
touch /var/log/webapp/error.log
chown -R apache:apache /var/log/webapp

# Configure firewall to allow web traffic
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
fi

# Create startup log
echo "$(date): Web server setup completed successfully" >> /var/log/webapp/setup.log

# Health check endpoint
cat > /var/www/html/health << 'EOF'
#!/bin/bash
echo "Content-Type: text/plain"
echo ""
echo "OK"
echo "$(date): Health check passed"
EOF

chmod +x /var/www/html/health

# Create a simple health check CGI script if needed
mkdir -p /var/www/cgi-bin
cat > /var/www/cgi-bin/health.sh << 'EOF'
#!/bin/bash
echo "Content-Type: application/json"
echo ""
echo "{\"status\":\"healthy\",\"timestamp\":\"$(date -Iseconds)\"}"
EOF

chmod +x /var/www/cgi-bin/health.sh

# Restart web server to apply changes
systemctl restart httpd

# Log completion
echo "$(date): Web server bootstrap completed" >> /var/log/cloud-init-output.log
