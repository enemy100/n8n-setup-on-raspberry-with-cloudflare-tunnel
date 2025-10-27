# 🚀 n8n no Raspberry Pi com Cloudflare Tunnel

Setup completo de automação com n8n rodando no Raspberry Pi com acesso externo seguro via Cloudflare Tunnel.

## 📚 Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete setup guide from zero (Docker, Cloudflare Tunnel, n8n)

## 🎯 O que você vai ter

- ✅ n8n rodando com acesso externo seguro
- ✅ Cloudflare Tunnel (sem Port Forwarding necessário)
- ✅ Portainer para gerenciamento Docker
- ✅ Dashboard web de status do sistema
- ✅ SMTP configurado para envio de emails
- ✅ Monitoramento de recursos (CPU, RAM, Disco)

## 🔧 Requisitos

- Raspberry Pi 4
- Ubuntu 24.04
- Docker + Docker Compose
- Conta Cloudflare gratuita
- Domínio (opcional)

## 📖 How to Use

1. Read [SETUP_GUIDE.md](SETUP_GUIDE.md)
2. Follow the steps in order (Step 1 to Step 9)
3. Configure Cloudflare Tunnel
4. Access n8n via HTTPS
5. In case of problems, check the "Troubleshooting" section

## ⚠️ Importante

This guide assumes you have a working `docker-compose.yml`. If starting from scratch:
- Follow Step 1 of SETUP_GUIDE.md to create a basic one
- Adapt to your environment
- **NEVER** commit `.env` or passwords!

## 📊 Arquitetura

```
Internet (HTTPS)
    ↓
Cloudflare (SSL + Tunnel)
    ↓
Traefik (Reverse Proxy)
    ↓
┌─────────────────┐
│   n8n (automação)
│   Portainer (gestão)
│   Dashboard (status)
└─────────────────┘
```

## 📝 Licença

Use livremente para seus projetos pessoais.

## 💡 Tips

- Faça backup regular dos workflows do n8n
- Use Cloudflare Tunnel para acesso externo seguro
- Monitore recursos via Portainer
- Configure SMTP para notificações por email

---

**Autor:** Baseado na implementação de @robson  
**Domínio:** viajandoeimigrando.com.br

