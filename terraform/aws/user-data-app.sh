#!/bin/bash
# User data script for application servers
# Sets up basic application server environment

set -euo pipefail

# Update system
yum update -y

# Install basic packages for application server
yum install -y python3 python3-pip nodejs npm git wget curl unzip htop

# Install basic monitoring and logging tools
pip3 install --upgrade pip
pip3 install psutil requests boto3

# Create application directory
mkdir -p /opt/app
mkdir -p /var/log/app
mkdir -p /opt/app/scripts

# Create a simple Python application for demo
cat > /opt/app/app.py << 'EOF'
#!/usr/bin/env python3
"""
Simple application server for demo purposes
Provides health check and basic monitoring endpoints
"""

import json
import time
import psutil
import platform
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
import socket

class AppHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_health_response()
        elif self.path == '/metrics':
            self.send_metrics_response()
        elif self.path == '/info':
            self.send_info_response()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

    def send_health_response(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        
        health_data = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'uptime': time.time() - psutil.boot_time()
        }
        self.wfile.write(json.dumps(health_data).encode())

    def send_metrics_response(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        
        metrics_data = {
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'disk_percent': psutil.disk_usage('/').percent,
            'load_average': psutil.getloadavg() if hasattr(psutil, 'getloadavg') else [0, 0, 0],
            'timestamp': datetime.now().isoformat()
        }
        self.wfile.write(json.dumps(metrics_data).encode())

    def send_info_response(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        
        info_data = {
            'hostname': socket.gethostname(),
            'platform': platform.platform(),
            'python_version': platform.python_version(),
            'app_version': '1.0.0',
            'timestamp': datetime.now().isoformat()
        }
        self.wfile.write(json.dumps(info_data).encode())

    def log_message(self, format, *args):
        """Override to log to file instead of stderr"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"[{timestamp}] {format % args}\n"
        with open('/var/log/app/access.log', 'a') as f:
            f.write(log_entry)

def run_server():
    server_address = ('', 8080)
    httpd = HTTPServer(server_address, AppHandler)
    print(f"Application server starting on port 8080...")
    with open('/var/log/app/startup.log', 'a') as f:
        f.write(f"{datetime.now().isoformat()}: Application server started\n")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        with open('/var/log/app/startup.log', 'a') as f:
            f.write(f"{datetime.now().isoformat()}: Application server stopped\n")

if __name__ == '__main__':
    run_server()
EOF

chmod +x /opt/app/app.py

# Create systemd service for the application
cat > /etc/systemd/system/app.service << 'EOF'
[Unit]
Description=Demo Application Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create monitoring script
cat > /opt/app/scripts/monitor.sh << 'EOF'
#!/bin/bash
# Monitoring script for application server

LOG_FILE="/var/log/app/monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Get system metrics
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

# Log metrics
echo "[$TIMESTAMP] CPU: ${CPU_USAGE}% Memory: ${MEMORY_USAGE}% Disk: ${DISK_USAGE}%" >> $LOG_FILE

# Check application health
if curl -s http://localhost:8080/health > /dev/null; then
    echo "[$TIMESTAMP] Application health: HEALTHY" >> $LOG_FILE
else
    echo "[$TIMESTAMP] Application health: UNHEALTHY" >> $LOG_FILE
    # Restart application if unhealthy
    systemctl restart app
    echo "[$TIMESTAMP] Application restarted due to health check failure" >> $LOG_FILE
fi
EOF

chmod +x /opt/app/scripts/monitor.sh

# Create log rotation for application logs
cat > /etc/logrotate.d/app << 'EOF'
/var/log/app/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

# Set proper permissions
chown -R root:root /opt/app
chown -R root:root /var/log/app

# Start and enable the application service
systemctl daemon-reload
systemctl start app
systemctl enable app

# Create cron job for monitoring
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/app/scripts/monitor.sh") | crontab -

# Configure firewall to allow application traffic
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --reload
fi

# Create startup completion marker
echo "$(date): Application server setup completed successfully" >> /var/log/app/setup.log

# Test the application
sleep 5
if curl -s http://localhost:8080/health > /dev/null; then
    echo "$(date): Application health check passed" >> /var/log/app/setup.log
else
    echo "$(date): Application health check failed" >> /var/log/app/setup.log
fi

# Log completion to cloud-init log
echo "$(date): Application server bootstrap completed" >> /var/log/cloud-init-output.log
