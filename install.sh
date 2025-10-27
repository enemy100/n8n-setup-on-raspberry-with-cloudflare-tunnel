#!/bin/bash
# Auto-installation script for n8n on Raspberry Pi

set -e

echo "🚀 Starting automated installation..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Please run as root: sudo bash install.sh"
  exit 1
fi

# Update system
echo "📦 Updating system..."
apt update && apt upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
else
    echo "✓ Docker already installed"
fi

# Install Docker Compose
echo "📋 Installing Docker Compose..."
apt install docker-compose-plugin -y

# Download and configure cloudflared
echo "☁️  Installing Cloudflare Tunnel..."
if ! command -v cloudflared &> /dev/null; then
    wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
    chmod +x cloudflared
    mv cloudflared /usr/local/bin/
    echo "✓ Cloudflared installed"
else
    echo "✓ Cloudflared already installed"
fi

# Create project directory
PROJECT_DIR="$HOME/Downloads"
mkdir -p "$PROJECT_DIR"

# Create dashboard directory
mkdir -p "$PROJECT_DIR/dashboard"

# Instructions for manual steps
echo ""
echo "✅ Automated installation complete!"
echo ""
echo "📝 Next steps (manual):"
echo "1. Configure .env file with your domain and passwords"
echo "2. Create docker-compose.yml"
echo "3. Setup Cloudflare Tunnel"
echo "4. See SETUP_GUIDE.md for detailed instructions"
echo ""
echo "Run: cd $PROJECT_DIR && nano .env"

