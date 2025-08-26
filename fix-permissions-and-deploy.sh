#!/bin/bash
# Fix permissions and run deployment

echo "🔧 Fixing script permissions..."

# Make deployment script executable
chmod +x deploy-hardened-os.sh
chmod +x scripts/verify-deployment.sh

# Make all scripts in the scripts directory executable
find scripts/ -name "*.sh" -exec chmod +x {} \;

# Make hardened-os component scripts executable
find hardened-os/ -name "*.sh" -exec chmod +x {} \;

echo "✅ Permissions fixed!"

echo "📋 Available deployment options:"
echo "1. Full deployment (recommended): sudo ./deploy-hardened-os.sh --mode full --target /dev/sda"
echo "2. Minimal deployment: sudo ./deploy-hardened-os.sh --mode minimal --target /dev/sda"
echo "3. Dry run (test): sudo ./deploy-hardened-os.sh --mode full --target /dev/sda --dry-run"
echo "4. Skip hardware check: sudo ./deploy-hardened-os.sh --mode full --target /dev/sda --skip-hardware-check"

echo ""
echo "⚠️  IMPORTANT: Replace /dev/sda with your actual target device!"
echo "   Use 'lsblk' to see available devices"
echo ""

echo "🚀 For VirtualBox deployment, run:"
echo "sudo ./deploy-hardened-os.sh --mode full --target /dev/sda --skip-hardware-check"
echo ""
echo "💡 VirtualBox-specific tips:"
echo "- Use --skip-hardware-check to bypass TPM/UEFI checks"
echo "- TPM 2.0 will be simulated in VirtualBox"
echo "- Some hardware features may be limited"
echo "- See VIRTUALBOX_DEPLOYMENT.md for detailed guide"