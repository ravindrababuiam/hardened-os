#!/bin/bash
# Validate Debian Base Installation - Task 3 Verification
# Verifies all requirements for Task 3 are met
# Requirements: 3.1, 3.2, 3.3, 3.4

set -euo pipefail

DEVICE="${1:-/dev/sda}"
VALIDATION_LOG="/var/log/hardened-validation.log"

echo "=== Debian Installation Validation ==="
echo "Validating Task 3 requirements..."
echo "Logging to: ${VALIDATION_LOG}"
echo

# Function to log results
log_result() {
    local status="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "${status} ${message}"
    echo "[${timestamp}] ${status} ${message}" >> "${VALIDATION_LOG}"
}

# Function to validate partition layout (Requirement 3.4)
validate_partition_layout() {
    echo "Validating partition layout..."
    
    # Check GPT partition table
    if parted -s "${DEVICE}" print | grep -q "Partition Table: gpt"; then
        log_result "✓" "GPT partition table confirmed"
    else
        log_result "✗" "ERROR: GPT partition table not found"
        return 1
    fi
    
    # Check EFI partition (512MB)
    local efi_size=$(lsblk -b -n -o SIZE "${DEVICE}1" 2>/dev/null || echo "0")
    local efi_size_mb=$((efi_size / 1024 / 1024))
    
    if [[ ${efi_size_mb} -ge 500 && ${efi_size_mb} -le 600 ]]; then
        log_result "✓" "EFI partition size valid: ${efi_size_mb}MB"
    else
        log_result "✗" "ERROR: EFI partition size invalid: ${efi_size_mb}MB (expected ~512MB)"
        return 1
    fi
    
    # Check recovery partition (1GB)
    local recovery_size=$(lsblk -b -n -o SIZE "${DEVICE}2" 2>/dev/null || echo "0")
    local recovery_size_mb=$((recovery_size / 1024 / 1024))
    
    if [[ ${recovery_size_mb} -ge 900 && ${recovery_size_mb} -le 1100 ]]; then
        log_result "✓" "Recovery partition size valid: ${recovery_size_mb}MB"
    else
        log_result "✗" "ERROR: Recovery partition size invalid: ${recovery_size_mb}MB (expected ~1024MB)"
        return 1
    fi
    
    # Check LUKS partition exists
    if [[ -b "${DEVICE}3" ]]; then
        log_result "✓" "LUKS partition found: ${DEVICE}3"
    else
        log_result "✗" "ERROR: LUKS partition not found: ${DEVICE}3"
        return 1
    fi
}

# Function to validate LUKS2 configuration (Requirements 3.1, 3.2, 3.3)
validate_luks2_config() {
    echo "Validating LUKS2 configuration..."
    
    local luks_device="${DEVICE}3"
    
    # Check LUKS2 version
    if cryptsetup luksDump "${luks_device}" | grep -q "Version:.*2"; then
        log_result "✓" "LUKS2 version confirmed"
    else
        log_result "✗" "ERROR: LUKS2 not found, may be LUKS1 or not encrypted"
        return 1
    fi
    
    # Check Argon2id KDF (Requirement 3.3)
    if cryptsetup luksDump "${luks_device}" | grep -q "argon2id"; then
        log_result "✓" "Argon2id KDF confirmed"
    else
        log_result "✗" "ERROR: Argon2id KDF not found"
        return 1
    fi
    
    # Check memory parameter (1GB = 1048576 KB)
    local memory_kb=$(cryptsetup luksDump "${luks_device}" | grep "Memory:" | awk '{print $2}' | head -1)
    if [[ ${memory_kb:-0} -ge 1000000 ]]; then
        log_result "✓" "Memory parameter valid: ${memory_kb} KB (≥1GB)"
    else
        log_result "✗" "ERROR: Memory parameter too low: ${memory_kb} KB (expected ≥1GB)"
        return 1
    fi
    
    # Check iterations (minimum 4)
    local iterations=$(cryptsetup luksDump "${luks_device}" | grep "Iterations:" | awk '{print $2}' | head -1)
    if [[ ${iterations:-0} -ge 4 ]]; then
        log_result "✓" "Iterations parameter valid: ${iterations} (≥4)"
    else
        log_result "✗" "ERROR: Iterations too low: ${iterations} (expected ≥4)"
        return 1
    fi
    
    # Check cipher
    if cryptsetup luksDump "${luks_device}" | grep -q "aes-xts-plain64"; then
        log_result "✓" "AES-XTS cipher confirmed"
    else
        log_result "✗" "WARNING: Expected AES-XTS cipher not found"
    fi
}

# Function to validate LVM configuration
validate_lvm_config() {
    echo "Validating LVM configuration..."
    
    # Check volume group exists
    if vgdisplay hardened-vg &>/dev/null; then
        log_result "✓" "Volume group 'hardened-vg' found"
    else
        log_result "✗" "ERROR: Volume group 'hardened-vg' not found"
        return 1
    fi
    
    # Check logical volumes
    local required_lvs=("root" "swap" "home")
    for lv in "${required_lvs[@]}"; do
        if lvdisplay "/dev/hardened-vg/${lv}" &>/dev/null; then
            log_result "✓" "Logical volume '${lv}' found"
        else
            log_result "✗" "ERROR: Logical volume '${lv}' not found"
            return 1
        fi
    done
}

# Function to validate filesystem configuration
validate_filesystems() {
    echo "Validating filesystem configuration..."
    
    # Check EFI filesystem (FAT32)
    local efi_fs=$(lsblk -n -o FSTYPE "${DEVICE}1" 2>/dev/null || echo "unknown")
    if [[ "${efi_fs}" == "vfat" ]]; then
        log_result "✓" "EFI filesystem (FAT32) confirmed"
    else
        log_result "✗" "ERROR: EFI filesystem not FAT32: ${efi_fs}"
        return 1
    fi
    
    # Check recovery filesystem (ext4)
    local recovery_fs=$(lsblk -n -o FSTYPE "${DEVICE}2" 2>/dev/null || echo "unknown")
    if [[ "${recovery_fs}" == "ext4" ]]; then
        log_result "✓" "Recovery filesystem (ext4) confirmed"
    else
        log_result "✗" "ERROR: Recovery filesystem not ext4: ${recovery_fs}"
        return 1
    fi
    
    # Check root filesystem (ext4)
    local root_fs=$(lsblk -n -o FSTYPE "/dev/hardened-vg/root" 2>/dev/null || echo "unknown")
    if [[ "${root_fs}" == "ext4" ]]; then
        log_result "✓" "Root filesystem (ext4) confirmed"
    else
        log_result "✗" "ERROR: Root filesystem not ext4: ${root_fs}"
        return 1
    fi
    
    # Check swap
    local swap_fs=$(lsblk -n -o FSTYPE "/dev/hardened-vg/swap" 2>/dev/null || echo "unknown")
    if [[ "${swap_fs}" == "swap" ]]; then
        log_result "✓" "Swap filesystem confirmed"
    else
        log_result "✗" "ERROR: Swap filesystem not configured: ${swap_fs}"
        return 1
    fi
}

# Function to validate system configuration files
validate_system_config() {
    echo "Validating system configuration..."
    
    # Check fstab
    if [[ -f "/etc/fstab" ]]; then
        if grep -q "hardened-vg" /etc/fstab; then
            log_result "✓" "fstab contains LVM entries"
        else
            log_result "✗" "ERROR: fstab missing LVM entries"
            return 1
        fi
    else
        log_result "✗" "ERROR: /etc/fstab not found"
        return 1
    fi
    
    # Check crypttab
    if [[ -f "/etc/crypttab" ]]; then
        if grep -q "hardened-crypt" /etc/crypttab; then
            log_result "✓" "crypttab contains LUKS entry"
        else
            log_result "✗" "ERROR: crypttab missing LUKS entry"
            return 1
        fi
    else
        log_result "✗" "ERROR: /etc/crypttab not found"
        return 1
    fi
    
    # Check initramfs includes cryptsetup
    if lsinitramfs /boot/initrd.img-$(uname -r) | grep -q cryptsetup; then
        log_result "✓" "initramfs includes cryptsetup"
    else
        log_result "✗" "ERROR: initramfs missing cryptsetup support"
        return 1
    fi
}

# Function to validate essential packages
validate_packages() {
    echo "Validating essential packages..."
    
    local required_packages=(
        "cryptsetup"
        "lvm2"
        "tpm2-tools"
        "systemd-cryptsetup"
        "grub-efi-amd64"
        "linux-image-amd64"
    )
    
    for package in "${required_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*${package}"; then
            log_result "✓" "Package '${package}' installed"
        else
            log_result "✗" "ERROR: Package '${package}' not installed"
            return 1
        fi
    done
}

# Function to validate boot configuration
validate_boot_config() {
    echo "Validating boot configuration..."
    
    # Check GRUB installation
    if [[ -d "/boot/efi/EFI/debian" ]]; then
        log_result "✓" "GRUB EFI installation found"
    else
        log_result "✗" "ERROR: GRUB EFI installation not found"
        return 1
    fi
    
    # Check GRUB configuration includes cryptsetup
    if grep -q "cryptdevice\|luks" /boot/grub/grub.cfg 2>/dev/null; then
        log_result "✓" "GRUB configured for LUKS"
    else
        log_result "✗" "WARNING: GRUB may not be configured for LUKS"
    fi
}

# Function to generate validation report
generate_report() {
    local total_checks="$1"
    local passed_checks="$2"
    local failed_checks=$((total_checks - passed_checks))
    
    echo
    echo "=== Validation Report ==="
    echo "Total checks: ${total_checks}"
    echo "Passed: ${passed_checks}"
    echo "Failed: ${failed_checks}"
    echo
    
    if [[ ${failed_checks} -eq 0 ]]; then
        echo "✓ ALL VALIDATIONS PASSED"
        echo "Task 3 requirements successfully met:"
        echo "  - Debian stable base system installed"
        echo "  - Custom partition layout (512MB EFI + 1GB recovery + encrypted LVM)"
        echo "  - LUKS2 full disk encryption with Argon2id KDF"
        echo "  - 1GB memory, 4 iterations configuration"
        echo
        echo "System ready for Task 4: UEFI Secure Boot setup"
        return 0
    else
        echo "✗ VALIDATION FAILED"
        echo "Please review the errors above and fix before proceeding"
        echo "Check log file: ${VALIDATION_LOG}"
        return 1
    fi
}

# Main validation function
main() {
    local total_checks=0
    local passed_checks=0
    
    # Initialize log
    mkdir -p "$(dirname "${VALIDATION_LOG}")"
    echo "=== Debian Installation Validation - $(date) ===" > "${VALIDATION_LOG}"
    
    echo "Starting validation of Task 3 requirements..."
    echo
    
    # Run validation functions
    local validation_functions=(
        "validate_partition_layout"
        "validate_luks2_config"
        "validate_lvm_config"
        "validate_filesystems"
        "validate_system_config"
        "validate_packages"
        "validate_boot_config"
    )
    
    for func in "${validation_functions[@]}"; do
        echo "Running ${func}..."
        if ${func}; then
            ((passed_checks++))
        fi
        ((total_checks++))
        echo
    done
    
    # Generate final report
    generate_report "${total_checks}" "${passed_checks}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi