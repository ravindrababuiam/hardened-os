#!/bin/bash
# VM Bootstrap Script - Type this manually in VM
# This creates the essential files needed for testing

set -euo pipefail

echo "=== Hardened OS VM Bootstrap ==="
echo "Creating essential files for testing..."

# Create directory structure
mkdir -p ~/hardened-os-test/{scripts,docs,configs,logs}
cd ~/hardened-os-test

# Create basic setup script
cat > scripts/basic-setup.sh << 'EOF'
#!/bin/bash
# Basic setup for Hardened OS testing in VM
set -euo pipefail

echo "=== Basic Hardened OS Setup ==="

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y git wget curl sudo vim build-essential python3 python3-pip

# Install security tools
sudo apt install -y openssl cryptsetup tpm2-tools selinux-utils bubblewrap nftables

# Create working directories
mkdir -p ~/harden/{src,keys,build,ci,artifacts}
mkdir -p ~/.config/hardened-os

echo "✅ Basic setup completed!"
echo "System is ready for Hardened OS components"
EOF

# Create simple test script
cat > scripts/test-basic.sh << 'EOF'
#!/bin/bash
# Basic system test
echo "=== Basic System Test ==="

echo "🖥️  System Info:"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"

echo "🔧 Tools Check:"
which git && echo "  ✅ git installed" || echo "  ❌ git missing"
which openssl && echo "  ✅ openssl installed" || echo "  ❌ openssl missing"
which python3 && echo "  ✅ python3 installed" || echo "  ❌ python3 missing"

echo "💾 Resources:"
echo "  Memory: $(free -h | awk '/^Mem:/{print $3"/"$2}')"
echo "  Disk: $(df -h / | awk 'NR==2{print $3"/"$2" ("$5" used)"}')"

echo "✅ Basic test completed!"
EOF

# Create HSM test script (simplified)
cat > scripts/test-hsm-basic.sh << 'EOF'
#!/bin/bash
# Basic HSM functionality test using SoftHSM
set -euo pipefail

echo "=== Basic HSM Test ==="

# Install SoftHSM
sudo apt install -y softhsm2 opensc-pkcs11

# Initialize SoftHSM token
export SOFTHSM2_CONF=~/.config/softhsm2.conf
mkdir -p ~/.config/softhsm-tokens

cat > ~/.config/softhsm2.conf << 'SOFTHSM_EOF'
directories.tokendir = ~/.config/softhsm-tokens/
objectstore.backend = file
log.level = INFO
SOFTHSM_EOF

# Initialize token
softhsm2-util --init-token --slot 0 --label "TestToken" --so-pin 5678 --pin 1234

# Test key generation
pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
    --token-label "TestToken" \
    --pin 1234 \
    --keypairgen \
    --key-type RSA:2048 \
    --id 01 \
    --label "TestKey"

echo "✅ Basic HSM test completed!"
echo "SoftHSM token created and test key generated"
EOF

# Make scripts executable
chmod +x scripts/*.sh

echo "✅ Bootstrap completed!"
echo
echo "Files created:"
echo "  ~/hardened-os-test/scripts/basic-setup.sh"
echo "  ~/hardened-os-test/scripts/test-basic.sh"
echo "  ~/hardened-os-test/scripts/test-hsm-basic.sh"
echo
echo "Next steps:"
echo "1. Run: bash ~/hardened-os-test/scripts/basic-setup.sh"
echo "2. Run: bash ~/hardened-os-test/scripts/test-basic.sh"
echo "3. Run: bash ~/hardened-os-test/scripts/test-hsm-basic.sh"