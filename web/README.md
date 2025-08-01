# AOV External Map System

Hệ thống render bản đồ bên ngoài cho Arena of Valor, tránh hook trực tiếp vào game để giảm thiểu khả năng bị phát hiện.

**🌐 Live Demo:** https://map.meonohehe.men

## Cách hoạt động

1. **Hack Module**: Thu thập dữ liệu game thông qua Il2Cpp memory reading
2. **WebSocket Client**: Gửi dữ liệu realtime qua WebSocket
3. **WebSocket Server**: Nhận và phân phối dữ liệu
4. **Web App**: Render bản đồ với thông tin enemy positions

## 🚀 Deployment trên Server

### 1. Chuẩn bị Server
- Ubuntu 20.04+ hoặc Debian 11+
- Domain: `map.meonohehe.men` (đã trỏ về server)
- Root access

### 2. Chạy Deployment Script
```bash
# Clone repository
git clone <your-repo>
cd web

# Chạy deployment script
chmod +x deploy.sh
sudo ./deploy.sh
```

### 3. Kiểm tra Deployment
```bash
# Kiểm tra status
/usr/local/bin/aov-map-status.sh

# Xem logs
journalctl -u aov-map-server -f
```

## 📱 Cấu hình Hack Module

### Cập nhật hack.cpp
Hack module sẽ tự động kết nối với server:
```cpp
const char* SERVER_DOMAIN = "map.meonohehe.men";
const int SERVER_PORT = 8080;
```

### Build và Install
```bash
# Build hack module
ndk-build

# Install APK
adb install bin/ImGui_Zygisk.apk
```

## 🌐 Truy cập Web Interface

### URLs
- **Web Interface**: https://map.meonohehe.men
- **WebSocket (Game)**: wss://map.meonohehe.men/ws/game
- **WebSocket (Web)**: wss://map.meonohehe.men/ws/web

### Features
- ✅ Real-time map rendering
- ✅ Enemy position tracking
- ✅ HP bars và status
- ✅ Auto-reconnect
- ✅ Mobile responsive

## 📊 Cấu trúc dữ liệu

### Game Data Format
```json
{
  "type": "game_data",
  "timestamp": 1234567890,
  "my_data": {
    "position": {"x": 100.0, "y": 0.0, "z": 200.0},
    "camp": 1
  },
  "enemies": [
    {
      "position": {"x": 150.0, "y": 0.0, "z": 250.0},
      "camp": 2,
      "hp": 1500,
      "max_hp": 2000,
      "name": "Enemy Hero"
    }
  ]
}
```

## 🔧 Management Commands

### Service Management
```bash
# Start service
sudo systemctl start aov-map-server

# Stop service
sudo systemctl stop aov-map-server

# Restart service
sudo systemctl restart aov-map-server

# View logs
journalctl -u aov-map-server -f
```

### Nginx Management
```bash
# Reload Nginx
sudo systemctl reload nginx

# Test config
sudo nginx -t

# View logs
sudo tail -f /var/log/nginx/map.meonohehe.men.access.log
```

### SSL Certificate
```bash
# Renew SSL certificate
sudo certbot renew

# Check certificate status
sudo certbot certificates
```

## 🛡️ Security Features

### SSL/TLS
- HTTPS với Let's Encrypt certificate
- HTTP/2 support
- Security headers

### Firewall
- UFW enabled
- Only necessary ports open (22, 80, 443, 8080, 8081)

### Monitoring
- Auto-restart service nếu crash
- Health check endpoint
- Log monitoring

## 📈 Monitoring & Logs

### Log Locations
- **Service Logs**: `/var/log/aov-map-monitor.log`
- **Nginx Access**: `/var/log/nginx/map.meonohehe.men.access.log`
- **Nginx Error**: `/var/log/nginx/map.meonohehe.men.error.log`

### Health Check
```bash
# Check service health
curl https://map.meonohehe.men/health

# Monitor real-time
watch -n 5 '/usr/local/bin/aov-map-status.sh'
```

## 🔄 Update Process

### Update Web Interface
```bash
cd /var/www/map.meonohehe.men
git pull
sudo systemctl restart aov-map-server
```

### Update Server Code
```bash
cd /var/www/map.meonohehe.men
git pull
pip3 install -r requirements.txt
sudo systemctl restart aov-map-server
```

## 🚨 Troubleshooting

### Service không start
```bash
# Check service status
sudo systemctl status aov-map-server

# Check logs
journalctl -u aov-map-server -n 50

# Check dependencies
python3 -c "import websockets, asyncio"
```

### WebSocket không kết nối
```bash
# Check port status
sudo netstat -tlnp | grep :8081

# Test WebSocket
wscat -c wss://map.meonohehe.men/ws/web
```

### SSL Issues
```bash
# Check certificate
sudo certbot certificates

# Renew certificate
sudo certbot renew --force-renewal
```

## 📞 Support

- **Domain**: map.meonohehe.men
- **Email**: admin@meonohehe.men
- **Status Page**: https://map.meonohehe.men/health

## 🔒 Privacy & Legal

⚠️ **Disclaimer**: Hệ thống này chỉ dành cho mục đích giáo dục và nghiên cứu. Người dùng chịu trách nhiệm về việc sử dụng hợp pháp. 