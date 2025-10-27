# 🚀 Complete Guide - n8n on Raspberry Pi with Cloudflare Tunnel

This guide walks you through setting up n8n on Raspberry Pi with external access via Cloudflare Tunnel.

---

## 📋 Prerequisites

1. **Raspberry Pi 4** with Ubuntu 24.04
2. **Docker and Docker Compose** installed
3. **Domain** on Cloudflare (`your-domain.com`)
4. **Cloudflare** free account

---

## 📁 Required Files

**IMPORTANT:** You need to create the `docker-compose.yml` file before continuing. See Step 1 below to create from scratch or adapt an existing one.

**Files that will be created during the guide:**
- `.env` - Environment variables (created in Step 2)
- `docker-compose.yml` - Orchestration (need it before)
- `dashboard/` - Web dashboard (will be created automatically)
  - `app.py` - Python API
  - `index.html` - Web interface

---

## 🔧 Step 1: Create docker-compose.yml (if you don't have it)

**IMPORTANT:** If you already have a working `docker-compose.yml`, you can skip to Step 2.

### Check if it exists:
```bash
ls ~/Downloads/docker-compose.yml
```

### If it doesn't exist, create a new one:

```bash
cd ~/Downloads
nano docker-compose.yml
```

Paste this complete content:

```yaml
version: "3.8"

services:
  # Traefik - Reverse Proxy
  traefik:
    image: traefik:v2.11
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - network_public

  # PostgreSQL - Database
  postgres:
    image: postgres:14
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=n8n
    networks:
      - network_public
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # Redis - Queue & Cache
  redis:
    image: redis:latest
    container_name: redis
    restart: unless-stopped
    networks:
      - network_public
    volumes:
      - redis_data:/data

  # Portainer - Docker Management
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    networks:
      - network_public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`${DOMINIO_PORTAINER}`)"
      - "traefik.http.routers.portainer.entrypoints=web"

  # n8n Editor - Workflow Editor
  n8n_editor:
    image: n8nio/n8n:latest
    container_name: n8n_editor
    restart: unless-stopped
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=${N8N_KEY}
      - N8N_HOST=${DOMINIO_N8N}
    networks:
      - network_public
    volumes:
      - n8n_data:/home/node/.n8n
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n_editor.rule=Host(`${DOMINIO_N8N}`)"
      - "traefik.http.routers.n8n_editor.entrypoints=web"

  # n8n Worker - Background Processing
  n8n_worker:
    image: n8nio/n8n:latest
    container_name: n8n_worker
    restart: unless-stopped
    command: worker
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - QUEUE_BULL_REDIS_HOST=redis
    networks:
      - network_public
    volumes:
      - n8n_data:/home/node/.n8n

  # n8n Webhook - Webhook Handler
  n8n_webhook:
    image: n8nio/n8n:latest
    container_name: n8n_webhook
    restart: unless-stopped
    command: webhook
    environment:
      - N8N_HOST=${WEBHOOK_N8N}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    networks:
      - network_public
    volumes:
      - n8n_data:/home/node/.n8n
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n_webhook.rule=Host(`${WEBHOOK_N8N}`)"
      - "traefik.http.routers.n8n_webhook.entrypoints=web"

  # Dashboard Stats API
  raspberry_stats_api:
    image: python:3.11-slim
    container_name: raspberry_stats_api
    restart: unless-stopped
    volumes:
      - ./dashboard:/app
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    working_dir: /app
    command: sh -c "pip install -q flask flask-cors && python app.py"
    networks:
      - network_public

  # Dashboard HTML
  raspberry_stats:
    image: nginx:alpine
    container_name: raspberry_stats
    restart: unless-stopped
    volumes:
      - ./dashboard:/usr/share/nginx/html:ro
    networks:
      - network_public

networks:
  network_public:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  portainer_data:
  n8n_data:
```

Save the file (Ctrl+O, Enter, Ctrl+X).

---

## 🎨 Create Dashboard Files (Optional)

The dashboard monitors your Raspberry Pi status in real-time. Create the files:

### Create app.py

```bash
mkdir -p ~/Downloads/dashboard
cd ~/Downloads/dashboard
nano app.py
```

Paste this complete content:

```python
#!/usr/bin/env python3
import os
import subprocess
import json
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

def get_temp():
    try:
        temp = subprocess.check_output(['cat', '/host/sys/class/thermal/thermal_zone0/temp']).decode().strip()
        return float(temp) / 1000
    except:
        return 0

def get_memory():
    try:
        meminfo = subprocess.check_output(['cat', '/host/proc/meminfo']).decode()
        mem_total = int([line for line in meminfo.split('\n') if 'MemTotal:' in line][0].split()[1]) / 1024 / 1024
        mem_avail = int([line for line in meminfo.split('\n') if 'MemAvailable:' in line][0].split()[1]) / 1024 / 1024
        mem_used = mem_total - mem_avail
        return {'total': round(mem_total, 2), 'used': round(mem_used, 2), 'avail': round(mem_avail, 2), 'percent': round((mem_used / mem_total) * 100, 1)}
    except:
        return {'total': 0, 'used': 0, 'avail': 0, 'percent': 0}

def get_disk():
    try:
        output = subprocess.check_output(['df', '-BG', '/']).decode()
        parts = output.split('\n')[1].split()
        used_gb = float(parts[2].replace('G', ''))
        avail_gb = float(parts[3].replace('G', ''))
        total_gb = used_gb + avail_gb
        return {'used': round(used_gb, 1), 'avail': round(avail_gb, 1), 'total': round(total_gb, 1), 'percent': round((used_gb / total_gb) * 100, 1)}
    except:
        return {'used': 0, 'avail': 0, 'total': 0, 'percent': 0}

def get_uptime():
    try:
        uptime_seconds = float(subprocess.check_output(['cat', '/host/proc/uptime']).decode().split()[0])
        hours = int(uptime_seconds / 3600)
        return f"{hours} hours"
    except:
        return "N/A"

def get_load():
    try:
        load = subprocess.check_output(['cat', '/host/proc/loadavg']).decode().strip()
        return load.split()[0]
    except:
        return "0.00"

def get_containers():
    try:
        ps = subprocess.check_output(['docker', 'ps', '--format', '{{.Names}}']).decode()
        return len(ps.strip().split('\n'))
    except:
        return 0

@app.route('/')
def stats():
    return jsonify({
        'temp': get_temp(),
        'memory': get_memory(),
        'disk': get_disk(),
        'uptime': get_uptime(),
        'load': get_load(),
        'containers': get_containers()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

Save (Ctrl+O, Enter, Ctrl+X).

### Create index.html

```bash
nano index.html
```

Paste this simplified dashboard HTML:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raspberry Pi Status</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 { color: white; text-align: center; margin-bottom: 30px; font-size: 2.5em; }
        .cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .card h2 {
            color: #333;
            margin-bottom: 15px;
            font-size: 1.2em;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .stat {
            display: flex;
            justify-content: space-between;
            margin: 15px 0;
            padding: 10px;
            background: #f5f5f5;
            border-radius: 8px;
        }
        .stat-label { font-weight: 600; color: #555; }
        .stat-value { font-weight: bold; color: #667eea; }
        .progress-bar {
            width: 100%;
            height: 25px;
            background: #e0e0e0;
            border-radius: 15px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea, #764ba2);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }
        .refresh-btn {
            background: white;
            border: none;
            padding: 15px 30px;
            border-radius: 50px;
            cursor: pointer;
            margin: 20px auto;
            display: block;
            font-weight: bold;
            color: #667eea;
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        .refresh-btn:hover { transform: scale(1.05); }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Raspberry Pi Status</h1>
        <button class="refresh-btn" onclick="updateStats()">🔄 Refresh</button>
        
        <div class="cards">
            <div class="card">
                <h2>🌡️ Temperature</h2>
                <div class="stat">
                    <span class="stat-label">CPU:</span>
                    <span class="stat-value" id="temp">-</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="temp-bar" style="width: 0%">-</div>
                </div>
            </div>
            
            <div class="card">
                <h2>💾 Memory RAM</h2>
                <div class="stat">
                    <span class="stat-label">Used:</span>
                    <span class="stat-value" id="ram-used">-</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Available:</span>
                    <span class="stat-value" id="ram-avail">-</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="ram-bar">-</div>
                </div>
            </div>
            
            <div class="card">
                <h2>💿 Disk</h2>
                <div class="stat">
                    <span class="stat-label">Used:</span>
                    <span class="stat-value" id="disk-used">-</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Free:</span>
                    <span class="stat-value" id="disk-avail">-</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="disk-bar">-</div>
                </div>
            </div>
            
            <div class="card">
                <h2>🔧 System</h2>
                <div class="stat">
                    <span class="stat-label">Uptime:</span>
                    <span class="stat-value" id="uptime">-</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Load:</span>
                    <span class="stat-value" id="load">-</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Containers:</span>
                    <span class="stat-value" id="containers">-</span>
                </div>
            </div>
        </div>
    </div>

    <script>
        async function updateStats() {
            try {
                const response = await fetch('https://' + window.location.hostname + '/api/stats');
                const data = await response.json();
                
                document.getElementById('temp').textContent = data.temp.toFixed(1) + '°C';
                const tempPercent = ((data.temp - 30) / 50 * 100);
                document.getElementById('temp-bar').style.width = Math.min(100, tempPercent) + '%';
                document.getElementById('temp-bar').textContent = data.temp.toFixed(1) + '°C';
                
                document.getElementById('ram-used').textContent = data.memory.used.toFixed(1) + ' GiB';
                document.getElementById('ram-avail').textContent = data.memory.avail.toFixed(1) + ' GiB';
                document.getElementById('ram-bar').style.width = data.memory.percent + '%';
                document.getElementById('ram-bar').textContent = data.memory.percent.toFixed(1) + '%';
                
                document.getElementById('disk-used').textContent = data.disk.used.toFixed(1) + ' GB';
                document.getElementById('disk-avail').textContent = data.disk.avail.toFixed(1) + ' GB';
                document.getElementById('disk-bar').style.width = data.disk.percent + '%';
                document.getElementById('disk-bar').textContent = data.disk.percent.toFixed(1) + '%';
                
                document.getElementById('uptime').textContent = data.uptime;
                document.getElementById('load').textContent = data.load;
                document.getElementById('containers').textContent = data.containers + ' active';
            } catch (error) {
                console.error('Error fetching data:', error);
            }
        }
        
        updateStats();
        setInterval(updateStats, 30000); // Update every 30 seconds
    </script>
</body>
</html>
```

Save (Ctrl+O, Enter, Ctrl+X).

**After creating both files, proceed to the next step.**

---

## 🔧 Step 2: Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Reboot to apply permissions
sudo reboot
```

After rebooting, reconnect and test:

```bash
docker --version
docker compose version
```

---

## 📝 Step 3: Configure Variables

Create the `.env` file:

```bash
cd ~/Downloads
nano .env
```

Paste this content (adapt to your domain):

```env
# Domains
DOMINIO_N8N=app.your-domain.com
WEBHOOK_N8N=hook.your-domain.com
DOMINIO_PORTAINER=central.your-domain.com

# SSL Email
SSL_EMAIL=your-email@gmail.com

# PostgreSQL Password
POSTGRES_PASSWORD=YourStrongPassword123

# n8n Encryption Key (generate with: openssl rand -base64 32)
N8N_KEY=your-random-key-here

# SMTP (optional - use Gmail app password)
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-gmail-app-password
N8N_SMTP_SENDER=your-email@gmail.com
N8N_SMTP_SSL=false
N8N_SMTP_SECURE=false
```

**Important:**
- Generate `N8N_KEY` with: `openssl rand -base64 32`
- Use strong password for PostgreSQL
- For Gmail SMTP: generate an app password at https://myaccount.google.com/apppasswords

---

## 🌐 Step 4: Configure Cloudflare DNS

### Get Zone ID

1. Access https://dash.cloudflare.com
2. Enter your domain
3. On the **Overview** page, copy the **Zone ID**

### Create API Token

1. Access: https://dash.cloudflare.com/profile/api-tokens
2. Click: **Create Token**
3. Use template: **Edit zone DNS**
4. Authorize: Zone → your domain
5. Click **Continue** → **Create Token**
6. **COPY THE TOKEN** (it appears only once!)

**Note down:**
- Zone ID: `abc123def456`
- API Token: `very-long-token`

---

## 🔗 Step 5: Install and Configure Cloudflare Tunnel

### Install cloudflared

```bash
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
chmod +x cloudflared-linux-arm64
sudo mv cloudflared-linux-arm64 /usr/local/bin/cloudflared
cloudflared --version
```

### Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

Opens in the browser: login and authorize access.

### Create Tunnel

```bash
cloudflared tunnel create n8n-raspberry
```

Save the tunnel ID that appears (e.g., `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)

### Configure DNS Routes

```bash
cloudflared tunnel route dns n8n-raspberry central.your-domain.com
cloudflared tunnel route dns n8n-raspberry app.your-domain.com
cloudflared tunnel route dns n8n-raspberry hook.your-domain.com
```

**What it does:** creates CNAME records in Cloudflare pointing to the tunnel.

### Create Configuration File

```bash
vi ~/.cloudflared/config.yml
```

Paste this content (replace YOUR_ID_HERE with your tunnel ID):

```yaml
tunnel: YOUR_ID_HERE
credentials-file: /home/robson/.cloudflared/YOUR_ID_HERE.json

ingress:
  - hostname: central.your-domain.com
    service: http://localhost:80
  - hostname: app.your-domain.com
    service: http://localhost:80
  - hostname: hook.your-domain.com
    service: http://localhost:80
  - service: http_status:404
```

Save the file.

### Test the Tunnel

```bash
cloudflared tunnel run n8n-raspberry
```

Leave it running in a terminal (or Ctrl+C to stop temporarily).

---

## 🐳 Step 6: Start Containers

```bash
cd ~/Downloads

# Create certificates directory
mkdir -p letsencrypt

# Start containers
docker compose up -d

# Check status
docker compose ps
```

**Should show:**
```
NAME            STATUS
traefik         Up
postgres        Up
redis           Up
n8n_editor      Up
n8n_worker      Up
n8n_webhook     Up
portainer       Up
```

---

## 🔄 Step 7: Configure Tunnel as Service

So the tunnel runs automatically in the background:

```bash
# IMPORTANT: Copy files to /etc/cloudflared
# systemd needs to find files in this directory
sudo mkdir -p /etc/cloudflared
sudo cp ~/.cloudflared/config.yml /etc/cloudflared/config.yml

# Copy credentials file (replace with your tunnel ID!)
# EXAMPLE: sudo cp ~/.cloudflared/a1b2c3d4-e5f6-7890-abcd-ef1234567890.json /etc/cloudflared/
# Or copy all .json files:
sudo cp ~/.cloudflared/*.json /etc/cloudflared/

# Now install as service (will look in /etc/cloudflared)
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared

# Enable on boot
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

**Now the tunnel runs automatically!**

---

## 🌐 Step 8: Access Services

Wait a few minutes and access:

- **n8n**: https://app.your-domain.com
- **Portainer**: https://central.your-domain.com
- **Webhooks**: https://hook.your-domain.com

---

## 📝 Step 9: Configure Users

### Configure n8n

1. Access: https://app.your-domain.com
2. Fill in the setup form
3. Configure workflows

### Configure Portainer

1. Access: https://central.your-domain.com
2. Create admin user (password with 12+ characters)
3. Select environment: **Docker Standalone**

---

## 🛠️ Useful Commands

### Manage Containers

```bash
# View all containers
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f traefik
docker compose logs -f n8n_editor

# Restart a service
docker compose restart n8n_editor

# Stop everything
docker compose down

# Recreate everything
docker compose down && docker compose up -d
```

### Manage Tunnel

```bash
# View tunnel status
sudo systemctl status cloudflared

# View tunnel logs
sudo journalctl -u cloudflared -f

# Restart tunnel
sudo systemctl restart cloudflared

# Stop tunnel
sudo systemctl stop cloudflared
```

---

## ⚠️ Troubleshooting

### "Cannot GET /" on n8n

Recreate the containers:

```bash
docker compose down
docker compose up -d
```

### Tunnel doesn't connect

Check if tunnel is running:

```bash
ps aux | grep cloudflared
```

Restart:

```bash
sudo systemctl restart cloudflared
```

---

## 🎉 Done!

Now you have n8n running on Raspberry Pi with:
- ✅ Cloudflare Tunnel (bypasses CGNAT)
- ✅ Automatic SSL
- ✅ Secure external access
- ✅ Portainer for management
- ✅ Status monitoring dashboard
- ✅ SMTP configured for sending emails
- ✅ System monitoring
- ✅ Memory and CPU optimizations

---

**Developed for @robson - viajandoeimigrando.com.br**

