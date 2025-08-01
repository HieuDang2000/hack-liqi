# AOV External Map System

Hệ thống bản đồ ngoài cho Arena of Valor sử dụng WebSocket và Node.js.

## 🌟 Tính năng

- **Real-time Map Rendering**: Hiển thị bản đồ game real-time
- **WebSocket Communication**: Giao tiếp hai chiều với hack module
- **External Rendering**: Không can thiệp trực tiếp vào game
- **SSL Security**: HTTPS/WSS encryption
- **Auto-scaling**: Hỗ trợ nhiều client đồng thời
- **Health Monitoring**: Theo dõi trạng thái hệ thống

## 🏗️ Kiến trúc

```
┌─────────────────┐    WebSocket    ┌─────────────────┐    WebSocket    ┌─────────────────┐
│   AOV Game      │ ──────────────► │  Node.js Server │ ──────────────► │  Web Browser    │
│  (Hack Module)  │                 │   (Port 8080)   │                 │   (Port 8082)   │
└─────────────────┘                 └─────────────────┘                 └─────────────────┘
                                              │
                                              ▼
                                    ┌─────────────────┐
                                    │   Nginx Proxy   │
                                    │  (Port 80/443)  │
                                    └─────────────────┘
```

## 🚀 Cài đặt

### Yêu cầu hệ thống
- Ubuntu 20.04+ hoặc Debian 11+
- Node.js 18+
- Nginx
- SSL Certificate (Let's Encrypt)

### Deploy tự động
```bash
# Clone repository
git clone https://github.com/your-repo/ZYGISK-AOV-AUTO-UPDATE.git
cd ZYGISK-AOV-AUTO-UPDATE/web

# Chạy script deploy (cần quyền root)
sudo bash deploy.sh
```

### Deploy thủ công
```bash
# 1. Cài đặt Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt install -y nodejs

# 2. Cài đặt dependencies
npm install --production

# 3. Cấu hình Nginx
sudo cp nginx.conf /etc/nginx/sites-available/map.meonohehe.men
sudo ln -s /etc/nginx/sites-available/map.meonohehe.men /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 4. Khởi động service
sudo systemctl start aov-map-system
sudo systemctl enable aov-map-system
```

## 📋 Cấu hình

### Ports
- **8080**: WebSocket cho game data (từ hack module)
- **8081**: HTTP server cho web interface
- **8082**: WebSocket cho web clients
- **80/443**: Nginx proxy với SSL

### Environment Variables
```bash
NODE_ENV=production
PORT=8081
DOMAIN=map.meonohehe.men
```

## 🔧 Quản lý

### Systemd Commands
```bash
# Khởi động service
sudo systemctl start aov-map-system

# Dừng service
sudo systemctl stop aov-map-system

# Restart service
sudo systemctl restart aov-map-system

# Xem status
sudo systemctl status aov-map-system

# Xem logs
sudo journalctl -u aov-map-system -f
```

### Management Script
```bash
# Sử dụng script quản lý
sudo aov-map-manage start    # Khởi động
sudo aov-map-manage stop     # Dừng
sudo aov-map-manage restart  # Restart
sudo aov-map-manage status   # Xem status
sudo aov-map-manage logs     # Xem logs
sudo aov-map-manage update   # Cập nhật
```

## 🌐 Truy cập

- **Web Interface**: https://map.meonohehe.men
- **Health Check**: https://map.meonohehe.men/health
- **Game WebSocket**: ws://map.meonohehe.men:8080
- **Web WebSocket**: ws://map.meonohehe.men:8082

## 📊 Monitoring

### Health Check
```bash
curl https://map.meonohehe.men/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "gameClients": 1,
  "webClients": 5,
  "domain": "map.meonohehe.men"
}
```

### Logs
```bash
# Nginx logs
sudo tail -f /var/log/nginx/map.meonohehe.men.access.log
sudo tail -f /var/log/nginx/map.meonohehe.men.error.log

# Application logs
sudo journalctl -u aov-map-system -f
```

## 🔒 Bảo mật

### SSL/TLS
- Tự động cấu hình SSL với Let's Encrypt
- HSTS headers
- Modern cipher suites
- Auto-renewal certificates

### Security Headers
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block
- Strict-Transport-Security

### Firewall
- UFW enabled
- Only necessary ports open
- SSH access restricted

## 🛠️ Troubleshooting

### Common Issues

**1. Service không khởi động**
```bash
# Kiểm tra logs
sudo journalctl -u aov-map-system -n 50

# Kiểm tra port
sudo netstat -tlnp | grep :8080
sudo netstat -tlnp | grep :8081
```

**2. WebSocket connection failed**
```bash
# Kiểm tra firewall
sudo ufw status

# Kiểm tra nginx config
sudo nginx -t
```

**3. SSL certificate issues**
```bash
# Renew certificate
sudo certbot renew

# Check certificate status
sudo certbot certificates
```

### Performance Tuning

**1. Increase Node.js memory**
```bash
# Edit service file
sudo systemctl edit aov-map-system

# Add environment variable
[Service]
Environment=NODE_OPTIONS="--max-old-space-size=2048"
```

**2. Nginx optimization**
```bash
# Edit nginx.conf
worker_processes auto;
worker_connections 1024;
```

## 📈 Scaling

### Load Balancing
```nginx
upstream aov_backend {
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
    server 127.0.0.1:8083;
}
```

### Multiple Instances
```bash
# Clone service for multiple instances
sudo cp /etc/systemd/system/aov-map-system.service /etc/systemd/system/aov-map-system-2.service
sudo systemctl edit aov-map-system-2
# Change port and working directory
```

## 🔄 Updates

### Auto Update
```bash
# Setup cron job for auto updates
echo "0 2 * * * /usr/local/bin/aov-map-manage update" | sudo crontab -
```

### Manual Update
```bash
cd /var/www/map.meonohehe.men
git pull
npm install --production
sudo systemctl restart aov-map-system
```

## 📞 Support

- **Email**: admin@meonohehe.men
- **Issues**: GitHub Issues
- **Documentation**: README.md

## 📄 License

MIT License - Xem file LICENSE để biết thêm chi tiết.

---

**Lưu ý**: Hệ thống này chỉ dành cho mục đích giáo dục và nghiên cứu. Sử dụng có trách nhiệm và tuân thủ luật pháp địa phương. 