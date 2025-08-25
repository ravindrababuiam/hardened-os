#!/bin/bash
#
# Recovery Infrastructure Creation Script
# Creates signed recovery partition and fallback kernel for safe boot
#

set -euo pipefail

# Configuration
KEYS_DIR="$HOME/harden/keys"
RECOVERY_DIR="$HOME/harden/recovery"
BUILD_DIR="$HOME/harden/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    local deps=("sbctl" "mkinitramfs" "grub-mkconfig" "efibootmgr")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install sbsigntool initramfs-tools grub-efi-amd64 efibootmgr"
        exit 1
    fi
}

# Setup recovery directory structure
setup_recovery_directories() {
    log_info "Setting up recovery directory structure..."
    
    mkdir -p "$RECOVERY_DIR"/{kernels,initramfs,bootloaders,configs}
    mkdir -p "$BUILD_DIR/recovery"
    
    # Set secure permissions
    chmod 755 "$RECOVERY_DIR"
    chmod 755 "$RECOVERY_DIR"/{kernels,initramfs,bootloaders,configs}
    
    log_info "Recovery directories created"
}

# Create recovery kernel configuration
create_recovery_kernel_config() {
    local config_file="$RECOVERY_DIR/configs/recovery_kernel.config"
    
    log_info "Creating recovery kernel configuration..."
    
    cat > "$config_file" << 'EOF'
# Recovery Kernel Configuration
# Minimal kernel with recovery capabilities

# Basic system support
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_SMP=y
CONFIG_PREEMPT_VOLUNTARY=y

# Essential filesystems
CONFIG_EXT4_FS=y
CONFIG_VFAT_FS=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_TMPFS=y

# Cryptographic support for LUKS
CONFIG_CRYPTO=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_XTS=y
CONFIG_CRYPTO_SHA256=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_CRYPTO_USER_API_SKCIPHER=y

# Device mapper for LUKS
CONFIG_MD=y
CONFIG_BLK_DEV_DM=y
CONFIG_DM_CRYPT=y

# TPM support
CONFIG_TCG_TPM=y
CONFIG_TCG_TIS_CORE=y
CONFIG_TCG_TIS=y
CONFIG_TCG_CRB=y

# UEFI support
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFI_VARS=y

# Security features (minimal for recovery)
CONFIG_SECURITY=y
CONFIG_SECURITY_SELINUX=y
CONFIG_DEFAULT_SECURITY_SELINUX=y

# Network support (minimal)
CONFIG_NET=y
CONFIG_INET=y
CONFIG_PACKET=y

# USB and input devices
CONFIG_USB=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_UHCI_HCD=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_STORAGE=y
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_INPUT_MOUSE=y

# Console and framebuffer
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
CONFIG_FB=y
CONFIG_FRAMEBUFFER_CONSOLE=y

# Disable debugging features
# CONFIG_DEBUG_KERNEL is not set
# CONFIG_KPROBES is not set
# CONFIG_FTRACE is not set
EOF

    chmod 644 "$config_file"
    log_info "Recovery kernel config created: $config_file"
}

# Create recovery initramfs configuration
create_recovery_initramfs_config() {
    local config_file="$RECOVERY_DIR/configs/initramfs.conf"
    
    log_info "Creating recovery initramfs configuration..."
    
    cat > "$config_file" << 'EOF'
# Recovery initramfs configuration

# Modules for recovery operations
MODULES=most

# Include cryptsetup for LUKS
CRYPTSETUP=y

# Include keyutils for TPM
KEYUTILS=y

# Include network tools
NETWORK=y

# Busybox for recovery shell
BUSYBOX=y

# Compression
COMPRESS=gzip

# Device support
DEVICE=y
EOF

    chmod 644 "$config_file"
    log_info "Recovery initramfs config created: $config_file"
}

# Create recovery boot script
create_recovery_boot_script() {
    local script_file="$RECOVERY_DIR/recovery-boot.sh"
    
    log_info "Creating recovery boot script..."
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
#
# Recovery Boot Script
# Provides recovery options when normal boot fails
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Hardened OS Recovery System        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're in recovery mode
if [ -f /proc/cmdline ] && grep -q "recovery" /proc/cmdline; then
    echo -e "${YELLOW}System booted in recovery mode${NC}"
else
    echo -e "${GREEN}Recovery tools available${NC}"
fi

echo ""
echo "Available recovery options:"
echo "1) Unlock encrypted disk manually"
echo "2) Reset TPM and re-seal keys"
echo "3) Check system integrity"
echo "4) Repair boot configuration"
echo "5) Emergency shell"
echo "6) Reboot to normal mode"
echo ""

read -p "Select option (1-6): " choice

case $choice in
    1)
        echo -e "${YELLOW}Manual disk unlock${NC}"
        echo "Available encrypted devices:"
        lsblk -f | grep crypto_LUKS || echo "No LUKS devices found"
        echo ""
        read -p "Enter device path (e.g., /dev/sda2): " device
        if [ -b "$device" ]; then
            cryptsetup luksOpen "$device" recovery_root
            echo -e "${GREEN}Device unlocked as /dev/mapper/recovery_root${NC}"
        else
            echo -e "${RED}Device not found${NC}"
        fi
        ;;
    2)
        echo -e "${YELLOW}TPM reset and key re-sealing${NC}"
        echo "This will clear TPM and require manual passphrase entry"
        read -p "Continue? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            tpm2_clear -c platform || echo "TPM clear failed"
            echo -e "${GREEN}TPM cleared. Reboot and re-enroll keys.${NC}"
        fi
        ;;
    3)
        echo -e "${YELLOW}System integrity check${NC}"
        if command -v debsums &> /dev/null; then
            debsums -c
        else
            echo "debsums not available in recovery environment"
        fi
        ;;
    4)
        echo -e "${YELLOW}Boot configuration repair${NC}"
        if [ -d /boot/efi ]; then
            efibootmgr -v
            echo ""
            echo "Boot entries listed above"
            read -p "Recreate boot entries? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                grub-install --target=x86_64-efi --efi-directory=/boot/efi
                update-grub
                echo -e "${GREEN}Boot configuration updated${NC}"
            fi
        else
            echo -e "${RED}EFI system partition not mounted${NC}"
        fi
        ;;
    5)
        echo -e "${YELLOW}Starting emergency shell${NC}"
        echo "Type 'exit' to return to recovery menu"
        /bin/bash
        ;;
    6)
        echo -e "${GREEN}Rebooting to normal mode${NC}"
        reboot
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        ;;
esac

echo ""
read -p "Press Enter to continue..."
exec "$0"  # Restart the menu
EOF

    chmod 755 "$script_file"
    log_info "Recovery boot script created: $script_file"
}

# Create GRUB recovery configuration
create_grub_recovery_config() {
    local config_file="$RECOVERY_DIR/configs/40_recovery"
    
    log_info "Creating GRUB recovery configuration..."
    
    cat > "$config_file" << 'EOF'
#!/bin/sh
# GRUB recovery menu entries

cat << 'GRUB_EOF'
menuentry 'Hardened OS Recovery Mode' --class recovery {
    load_video
    insmod gzio
    insmod part_gpt
    insmod fat
    insmod ext2
    
    echo 'Loading recovery kernel...'
    linux /recovery/vmlinuz-recovery root=/dev/mapper/recovery_root ro recovery init=/recovery/recovery-boot.sh
    echo 'Loading recovery initramfs...'
    initrd /recovery/initramfs-recovery
}

menuentry 'Hardened OS Safe Mode (No TPM)' --class recovery {
    load_video
    insmod gzio
    insmod part_gpt
    insmod fat
    insmod ext2
    
    echo 'Loading kernel in safe mode...'
    linux /vmlinuz root=/dev/mapper/root ro tpm2.disable=1 selinux=permissive
    echo 'Loading initramfs...'
    initrd /initrd.img
}

menuentry 'Memory Test (memtest86+)' --class memtest {
    linux16 /memtest86+.bin
}
GRUB_EOF
EOF

    chmod 755 "$config_file"
    log_info "GRUB recovery config created: $config_file"
}

# Sign recovery components
sign_recovery_components() {
    local db_key="$KEYS_DIR/dev/DB/DB.key"
    local db_crt="$KEYS_DIR/dev/DB/DB.crt"
    
    if [ ! -f "$db_key" ] || [ ! -f "$db_crt" ]; then
        log_error "DB signing keys not found. Run generate-dev-keys.sh first."
        return 1
    fi
    
    log_info "Signing recovery components..."
    
    # Create dummy recovery kernel for signing (in real implementation, this would be actual kernel)
    echo "Dummy recovery kernel for development" > "$RECOVERY_DIR/kernels/vmlinuz-recovery"
    
    # Sign recovery kernel
    sbsign --key "$db_key" --cert "$db_crt" \
        --output "$RECOVERY_DIR/kernels/vmlinuz-recovery.signed" \
        "$RECOVERY_DIR/kernels/vmlinuz-recovery"
    
    log_info "Recovery components signed successfully"
}

# Create recovery documentation
create_recovery_documentation() {
    local doc_file="$RECOVERY_DIR/RECOVERY_PROCEDURES.md"
    
    log_info "Creating recovery documentation..."
    
    cat > "$doc_file" << 'EOF'
# Recovery Procedures

## Overview
This document describes recovery procedures for the Hardened OS system.

## Boot Failure Scenarios

### 1. TPM Unsealing Failure
**Symptoms**: System prompts for passphrase instead of automatic unlock
**Cause**: PCR values changed due to firmware/kernel updates or tampering
**Recovery**:
1. Enter LUKS passphrase manually
2. Boot into recovery mode
3. Check PCR values: `tpm2_pcrread`
4. Re-seal keys with new PCR values if legitimate change

### 2. Secure Boot Failure
**Symptoms**: "Verification failed" or similar UEFI error
**Cause**: Unsigned kernel or corrupted signatures
**Recovery**:
1. Boot from recovery partition
2. Check signature validity: `sbverify --list vmlinuz`
3. Re-sign kernel if necessary
4. Update UEFI boot entries

### 3. Kernel Panic/Corruption
**Symptoms**: System crashes during boot or runtime
**Cause**: Kernel corruption or hardware issues
**Recovery**:
1. Boot previous kernel from GRUB menu
2. Use recovery kernel if main kernels fail
3. Check system logs: `journalctl -b -1`
4. Reinstall kernel packages if needed

## Recovery Boot Options

### Recovery Mode
- Minimal kernel with recovery tools
- Access to cryptsetup, TPM tools, and system repair utilities
- Interactive recovery menu

### Safe Mode
- Normal kernel with security features disabled
- TPM disabled, SELinux permissive
- For troubleshooting security policy issues

## Key Recovery Procedures

### Lost Passphrase
1. Boot from external recovery media
2. Use recovery keyslot if configured
3. Reset user authentication if necessary

### TPM Failure
1. Clear TPM: `tpm2_clear`
2. Boot with passphrase
3. Re-initialize TPM and seal new keys

### Compromised Keys
1. Boot into recovery mode
2. Generate new signing keys
3. Re-sign all boot components
4. Update UEFI key database

## Emergency Contacts
- System Administrator: [Contact Info]
- Security Team: [Contact Info]
- Hardware Vendor: [Contact Info]

## Testing Recovery Procedures
Regular testing ensures recovery procedures work when needed:
1. Monthly: Test recovery boot
2. Quarterly: Test TPM reset and re-sealing
3. Annually: Full disaster recovery simulation
EOF

    chmod 644 "$doc_file"
    log_info "Recovery documentation created: $doc_file"
}

# Main execution
main() {
    log_info "Creating recovery infrastructure..."
    
    check_dependencies
    setup_recovery_directories
    create_recovery_kernel_config
    create_recovery_initramfs_config
    create_recovery_boot_script
    create_grub_recovery_config
    sign_recovery_components
    create_recovery_documentation
    
    log_info "Recovery infrastructure created successfully!"
    log_info "Recovery location: $RECOVERY_DIR"
    log_warn "Test recovery procedures regularly to ensure they work when needed"
}

# Run main function
main "$@"