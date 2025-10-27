# 🚀 n8n on Raspberry Pi with Cloudflare Tunnel

Complete automation setup with n8n running on Raspberry Pi with secure external access via Cloudflare Tunnel.

## 📚 Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete setup guide from zero (Docker, Cloudflare Tunnel, n8n)

## 🎯 What You'll Get

- ✅ n8n running with secure external access
- ✅ Cloudflare Tunnel (no Port Forwarding needed)
- ✅ Portainer for Docker management
- ✅ Web dashboard for system monitoring
- ✅ SMTP configured for sending emails
- ✅ Resource monitoring (CPU, RAM, Disk)

## 🔧 Requirements

- Raspberry Pi 4
- Ubuntu 24.04
- Docker + Docker Compose
- Free Cloudflare account
- Domain (optional)

## 📖 How to Use

1. Read [SETUP_GUIDE.md](SETUP_GUIDE.md)
2. Follow the steps in order (Step 1 to Step 9)
3. Configure Cloudflare Tunnel
4. Access n8n via HTTPS
5. In case of problems, check the "Troubleshooting" section

## ⚠️ Important

This guide assumes you have a working `docker-compose.yml`. If starting from scratch:
- Follow Step 1 of SETUP_GUIDE.md to create a basic one
- Adapt to your environment
- **NEVER** commit `.env` or passwords!

## 📊 Architecture

```
Internet (HTTPS)
    ↓
Cloudflare (SSL + Tunnel)
    ↓
Traefik (Reverse Proxy)
    ↓
┌─────────────────┐
│   n8n (automation)
│   Portainer (management)
│   Dashboard (status)
└─────────────────┘
```

## 📝 License

Feel free to use for your personal projects.

## 💡 Tips

- Make regular backups of n8n workflows
- Use Cloudflare Tunnel for secure external access
- Monitor resources via Portainer
- Configure SMTP for email notifications

---

**Author:** Based on implementation by @robson  
**Domain:** viajandoeimigrando.com.br
