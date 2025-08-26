#!/bin/bash
# Fix Python environment issues in Debian

echo "🐍 Fixing Python environment for Debian..."

# Install Python packages via apt (Debian way)
sudo apt install -y \
    python3-yaml \
    python3-cryptography \
    python3-requests \
    python3-jinja2 \
    python3-setuptools \
    python3-wheel \
    python3-full \
    python3-venv

echo "✅ Python environment fixed!"
echo "📋 Now you can continue with the deployment:"
echo "sudo ./deploy-hardened-os-debian-fix.sh --mode full --target /dev/sda --skip-hardware-check"