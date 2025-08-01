#!/bin/bash

# AOV External Map Server Deployment Script
# Domain: map.meonohehe.men

set -e

echo "🚀 Starting AOV External Map Server Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="map.meonohehe.men"
WEB_ROOT="/var/www/map.meonohehe.men"
SERVICE_NAME="aov-map-server"

echo -e "${GREEN}📋 Configuration:${NC}"
echo "Domain: $DOMAIN"
echo "Web Root: $WEB_ROOT"
echo "Service Name: $SERVICE_NAME"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root${NC}"
   exit 1
fi

# Update system
echo -e "${YELLOW}📦 Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required packages
echo -e "${YELLOW}📦 Installing required packages...${NC}"
apt install -y python3 python3-pip nginx certbot python3-certbot-nginx git curl

# Create web directory
echo -e "${YELLOW}📁 Creating web directory...${NC}"
mkdir -p $WEB_ROOT
chown -R www-data:www-data $WEB_ROOT

# Install Python dependencies
echo -e "${YELLOW}🐍 Installing Python dependencies...${NC}"
pip3 install -r requirements.txt

# Copy files to web directory
echo -e "${YELLOW}📄 Copying web files...${NC}"
cp index.html $WEB_ROOT/
chown www-data:www-data $WEB_ROOT/index.html

# Create systemd service
echo -e "${YELLOW}⚙️ Creating systemd service...${NC}"
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=AOV External Map WebSocket Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/map.meonohehe.men
ExecStart=/usr/bin/python3 /var/www/map.meonohehe.men/server.py
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# Copy server.py to web directory
cp server.py $WEB_ROOT/
chown www-data:www-data $WEB_ROOT/server.py

# Setup Nginx
echo -e "${YELLOW}🌐 Setting up Nginx...${NC}"
cp nginx.conf /etc/nginx/sites-available/$DOMAIN
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Get SSL certificate
echo -e "${YELLOW}🔒 Getting SSL certificate...${NC}"
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@meonohehe.men

# Enable and start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME
systemctl reload nginx

# Setup firewall
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw allow 8081/tcp
ufw --force enable

# Create monitoring script
echo -e "${YELLOW}📊 Creating monitoring script...${NC}"
cat > /usr/local/bin/monitor-aov-map.sh << 'EOF'
#!/bin/bash
SERVICE_NAME="aov-map-server"

if ! systemctl is-active --quiet $SERVICE_NAME; then
    echo "$(date): $SERVICE_NAME is down, restarting..." >> /var/log/aov-map-monitor.log
    systemctl restart $SERVICE_NAME
fi

if ! systemctl is-active --quiet nginx; then
    echo "$(date): nginx is down, restarting..." >> /var/log/aov-map-monitor.log
    systemctl restart nginx
fi
EOF

chmod +x /usr/local/bin/monitor-aov-map.sh

# Setup cron job for monitoring
echo "*/5 * * * * /usr/local/bin/monitor-aov-map.sh" | crontab -

# Create status script
echo -e "${YELLOW}📈 Creating status script...${NC}"
cat > /usr/local/bin/aov-map-status.sh << 'EOF'
#!/bin/bash
echo "=== AOV External Map Server Status ==="
echo "Service Status:"
systemctl status aov-map-server --no-pager -l
echo ""
echo "Nginx Status:"
systemctl status nginx --no-pager -l
echo ""
echo "Recent Logs:"
tail -20 /var/log/aov-map-monitor.log
EOF

chmod +x /usr/local/bin/aov-map-status.sh

# Final status check
echo -e "${GREEN}✅ Deployment completed!${NC}"
echo ""
echo -e "${GREEN}🌐 Access URLs:${NC}"
echo "Web Interface: https://$DOMAIN"
echo "WebSocket (Game): wss://$DOMAIN/ws/game"
echo "WebSocket (Web): wss://$DOMAIN/ws/web"
echo ""
echo -e "${GREEN}🔧 Management Commands:${NC}"
echo "Check Status: /usr/local/bin/aov-map-status.sh"
echo "Restart Service: systemctl restart $SERVICE_NAME"
echo "View Logs: journalctl -u $SERVICE_NAME -f"
echo ""
echo -e "${GREEN}📊 Monitoring:${NC}"
echo "Service monitoring is active (checks every 5 minutes)"
echo "Logs: /var/log/aov-map-monitor.log"

# Show current status
echo ""
echo -e "${YELLOW}📊 Current Status:${NC}"
/usr/local/bin/aov-map-status.sh 