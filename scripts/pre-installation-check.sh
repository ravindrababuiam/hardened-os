#!/bin/bash
#
# Pre-Installation Check Script
# Verifies system readiness for Hardened OS installation
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_check() { echo -e "${BLUE}[CHECK]${NC} $1"; }

# Check results
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

check_result() {
    if [ "$1" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((CHECKS_FAILED++))
    fi
}

warn_result() {
    echo -e "${YELLOW}⚠ WARN${NC}"
    ((CHECKS_WARNED++))
}

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    HARDENED OS PRE-INSTALLATION CHECK                       ║
║                                                                              ║
║  This script verifies system readiness for Hardened OS installation         ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check 1: Hardware Requirements
log_check "Checking hardware requirements..."

# UEFI Support
echo -n "  UEFI firmware support: "
if [ -d "/sys/firmware/efi" ]; then
    check_result 0
else
    check_result 1
    log_error "UEFI firmware required. Legacy BIOS not supported."
fi

# TPM2 Support
echo -n "  TPM2 device availability: "
if [ -c "/dev/tpm0" ] || [ -c "/dev/tpmrm0" ]; then
    check_result 0
else
    warn_result
    log_warn "TPM2 not detected. Some security features may not work."
fi

# Memory Check
echo -n "  Memory (8GB+ recommended): "
mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
mem_gb=$((mem_kb / 1024 / 1024))
if [ "$mem_gb" -ge 8 ]; then
    check_result 0
    echo "    Available: ${mem_gb}GB"
else
    warn_result
    log_warn "Only ${mem_gb}GB RAM available. 8GB+ recommended."
fi

# Architecture Check
echo -n "  x86_64 architecture: "
if [ "$(uname -m)" = "x86_64" ]; then
    check_result 0
else
    check_result 1
    log_error "x86_64 architecture required. Found: $(uname -m)"
fi

# Check 2: Required Tools
log_check "Checking required tools..."

required_tools=(
    "git" "wget" "curl" "cryptsetup" "parted" "mkfs.ext4" 
    "mkfs.fat" "debootstrap" "chroot" "mount" "umount"
)

for tool in "${required_tools[@]}"; do
    echo -n "  $tool: "
    if command -v "$tool" &> /dev/null; then
        check_result 0
    else
        check_result 1
        log_error "Missing required tool: $tool"
    fi
done

# Check 3: Development Environment
log_check "Checking development environment..."

# Project directory
echo -n "  Project directory structure: "
if [ -d "scripts" ] && [ -d "configs" ] && [ -f "scripts/install-hardened-os.sh" ]; then
    check_result 0
else
    check_result 1
    log_error "Project directory structure incomplete"
fi

# Key infrastructure
echo -n "  Signing key infrastructure: "
if [ -f "scripts/generate-dev-keys.sh" ]; then
    check_result 0
else
    check_result 1
    log_error "Key generation infrastructure missing"
fi

# Installation scripts
echo -n "  Installation scripts: "
installation_scripts=(
    "scripts/install-hardened-os.sh"
    "scripts/create-partition-layout.sh"
    "scripts/setup-luks2-encryption.sh"
    "scripts/install-debian-base.sh"
)

missing_scripts=()
for script in "${installation_scripts[@]}"; do
    if [ ! -f "$script" ]; then
        missing_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -eq 0 ]; then
    check_result 0
else
    check_result 1
    log_error "Missing installation scripts: ${missing_scripts[*]}"
fi

# Check 4: System Permissions
log_check "Checking system permissions..."

# Root access
echo -n "  Sudo access: "
if sudo -n true 2>/dev/null; then
    check_result 0
else
    echo -n ""
    if sudo true 2>/dev/null; then
        check_result 0
    else
        check_result 1
        log_error "Sudo access required for installation"
    fi
fi

# Check 5: Network Connectivity
log_check "Checking network connectivity..."

# Internet access
echo -n "  Internet connectivity: "
if ping -c 1 8.8.8.8 &> /dev/null; then
    check_result 0
else
    check_result 1
    log_error "Internet connectivity required for package downloads"
fi

# Package repositories
echo -n "  Debian package repositories: "
if wget -q --spider http://deb.debian.org/debian/; then
    check_result 0
else
    warn_result
    log_warn "Debian repositories may not be accessible"
fi

# Check 6: Available Storage Devices
log_check "Checking available storage devices..."

echo "  Available block devices:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "(disk|nvme)" | while read -r line; do
    echo "    $line"
done

echo -n "  Suitable installation targets found: "
suitable_devices=$(lsblk -d -o NAME,SIZE -n | awk '$2 ~ /[0-9]+G/ && $2 !~ /^[0-9]G$/ {print $1}' | wc -l)
if [ "$suitable_devices" -gt 0 ]; then
    check_result 0
    echo "    Found $suitable_devices suitable device(s)"
else
    warn_result
    log_warn "No devices with sufficient storage (>10GB) found"
fi

# Check 7: Firmware Configuration
log_check "Checking firmware configuration..."

# Secure Boot status
echo -n "  Secure Boot status: "
if command -v mokutil &> /dev/null; then
    sb_state=$(mokutil --sb-state 2>/dev/null | grep -o "SecureBoot [a-zA-Z]*" | awk '{print $2}' || echo "unknown")
    if [ "$sb_state" = "enabled" ] || [ "$sb_state" = "disabled" ]; then
        check_result 0
        echo "    Status: $sb_state"
    else
        warn_result
        log_warn "Secure Boot status unknown"
    fi
else
    warn_result
    log_warn "mokutil not available - cannot check Secure Boot status"
fi

# TPM2 tools
echo -n "  TPM2 tools availability: "
if command -v tpm2_getcap &> /dev/null; then
    check_result 0
else
    warn_result
    log_warn "TPM2 tools not installed (will be installed during setup)"
fi

# Summary
echo ""
log_check "Pre-installation check summary:"
echo "  ✓ Passed: $CHECKS_PASSED"
echo "  ⚠ Warnings: $CHECKS_WARNED"
echo "  ✗ Failed: $CHECKS_FAILED"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo ""
    log_info "🎉 System is ready for Hardened OS installation!"
    echo ""
    log_info "Next steps:"
    log_info "1. Backup any important data on target device"
    log_info "2. Identify target installation device (e.g., /dev/sda)"
    log_info "3. Run: sudo bash scripts/install-hardened-os.sh /dev/TARGET_DEVICE"
    echo ""
    log_warn "⚠️ WARNING: Installation will completely wipe the target device!"
    exit 0
else
    echo ""
    log_error "❌ System is NOT ready for installation"
    log_error "Please resolve the failed checks before proceeding"
    echo ""
    log_info "Common solutions:"
    log_info "• Install missing tools: sudo apt install <missing-tools>"
    log_info "• Ensure UEFI boot mode is enabled in firmware"
    log_info "• Verify project directory is complete"
    log_info "• Check network connectivity"
    exit 1
fi