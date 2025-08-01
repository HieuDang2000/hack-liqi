#!/bin/bash

# AOV External Map System - Node.js Deployment Script
# Domain: map.meonohehe.men

set -e

# Configuration
DOMAIN="map.meonohehe.men"
WEB_ROOT="/var/www/map.meonohehe.men"
SERVICE_NAME="aov-map-system"
EMAIL="admin@meonohehe.men"

echo "🚀 Starting AOV External Map System deployment..."
echo "📍 Domain: $DOMAIN"
echo "📁 Web Root: $WEB_ROOT"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install Node.js and npm
echo "📦 Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install nginx
echo "📦 Installing nginx..."
apt install -y nginx

# Install certbot for SSL
echo "📦 Installing certbot..."
apt install -y certbot python3-certbot-nginx

# Create web directory
echo "📁 Creating web directory..."
mkdir -p $WEB_ROOT
chown -R www-data:www-data $WEB_ROOT

# Copy web files
echo "📋 Copying web files..."
cp -r . $WEB_ROOT/
cd $WEB_ROOT

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install --production

# Configure nginx
echo "⚙️ Configuring nginx..."
cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Web root
    root $WEB_ROOT;
    index index.html;
    
    # Static files
    location / {
        try_files \$uri \$uri/ /index.html;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
    
    # WebSocket proxy for game data (port 8080)
    location /ws/game {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # WebSocket proxy for web clients (port 8082)
    location /ws/web {
        proxy_pass http://localhost:8082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Logs
    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log /var/log/nginx/$DOMAIN.error.log;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "🔍 Testing nginx configuration..."
nginx -t

# Get SSL certificate
echo "🔒 Getting SSL certificate..."
certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

# Create systemd service
echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=AOV External Map System
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$WEB_ROOT
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=8081

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$WEB_ROOT

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
echo "🚀 Starting service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Start nginx
echo "🌐 Starting nginx..."
systemctl enable nginx
systemctl start nginx

# Setup firewall
echo "🔥 Configuring firewall..."
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 8080/tcp
ufw allow 8081/tcp
ufw allow 8082/tcp
ufw --force enable

# Create management script
echo "📝 Creating management script..."
cat > /usr/local/bin/aov-map-manage << 'EOF'
#!/bin/bash

SERVICE_NAME="aov-map-system"
WEB_ROOT="/var/www/map.meonohehe.men"

case "$1" in
    start)
        systemctl start $SERVICE_NAME
        systemctl start nginx
        echo "✅ Services started"
        ;;
    stop)
        systemctl stop $SERVICE_NAME
        systemctl stop nginx
        echo "⏹️ Services stopped"
        ;;
    restart)
        systemctl restart $SERVICE_NAME
        systemctl restart nginx
        echo "🔄 Services restarted"
        ;;
    status)
        systemctl status $SERVICE_NAME
        systemctl status nginx
        ;;
    logs)
        journalctl -u $SERVICE_NAME -f
        ;;
    update)
        cd $WEB_ROOT
        git pull
        npm install --production
        systemctl restart $SERVICE_NAME
        echo "✅ System updated"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/aov-map-manage

# Final status check
echo "🔍 Checking service status..."
sleep 5
systemctl status $SERVICE_NAME --no-pager -l

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 System Information:"
echo "   🌐 Domain: https://$DOMAIN"
echo "   🎮 Game WebSocket: ws://$DOMAIN:8080"
echo "   🌍 Web WebSocket: ws://$DOMAIN:8082"
echo "   📊 Health Check: https://$DOMAIN/health"
echo ""
echo "🔧 Management Commands:"
echo "   aov-map-manage start    - Start services"
echo "   aov-map-manage stop     - Stop services"
echo "   aov-map-manage restart  - Restart services"
echo "   aov-map-manage status   - Check status"
echo "   aov-map-manage logs     - View logs"
echo "   aov-map-manage update   - Update system"
echo ""
echo "📁 Files Location:"
echo "   Web Root: $WEB_ROOT"
echo "   Logs: /var/log/nginx/$DOMAIN.*.log"
echo "   Service: /etc/systemd/system/$SERVICE_NAME.service"
echo ""
echo "🔒 SSL Certificate will auto-renew"
echo "🌐 Nginx is configured with security headers"
echo "🔥 Firewall is configured and enabled" 