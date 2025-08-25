#!/bin/bash
# LUKS2 Full Disk Encryption Setup with Argon2id KDF
# Part of hardened laptop OS setup - Task 3.3
# Requirements: 3.1, 3.2, 3.3, 3.4

set -euo pipefail

# Configuration for LUKS2 with Argon2id
LUKS_CIPHER="aes-xts-plain64"
LUKS_KEY_SIZE="512"
LUKS_HASH="sha256"
LUKS_KDF="argon2id"
LUKS_MEMORY="1048576"  # 1GB in KB
LUKS_ITERATIONS="4"
LUKS_PARALLEL="4"

# Device configuration (will be set during installation)
DEVICE="${1:-/dev/sda2}"  # Main encrypted partition
VG_NAME="hardened-vg"
ROOT_LV="root"
SWAP_LV="swap"
HOME_LV="home"

echo "=== LUKS2 Encryption Setup ==="
echo "Device: ${DEVICE}"
echo "Cipher: ${LUKS_CIPHER}"
echo "Key size: ${LUKS_KEY_SIZE} bits"
echo "KDF: ${LUKS_KDF}"
echo "Memory: ${LUKS_MEMORY} KB (1GB)"
echo "Iterations: ${LUKS_ITERATIONS}"
echo

# Function to setup LUKS2 encryption
setup_luks2() {
    local device="$1"
    local name="$2"
    
    echo "Setting up LUKS2 encryption on ${device}..."
    
    # Create LUKS2 container with Argon2id KDF
    cryptsetup luksFormat \
        --type luks2 \
        --cipher "${LUKS_CIPHER}" \
        --key-size "${LUKS_KEY_SIZE}" \
        --hash "${LUKS_hash}" \
        --pbkdf "${LUKS_KDF}" \
        --pbkdf-memory "${LUKS_MEMORY}" \
        --pbkdf-force-iterations "${LUKS_ITERATIONS}" \
        --pbkdf-parallel "${LUKS_PARALLEL}" \
        --use-urandom \
        --verify-passphrase \
        "${device}"
    
    echo "✓ LUKS2 container created successfully"
    
    # Open the encrypted container
    echo "Opening encrypted container..."
    cryptsetup luksOpen "${device}" "${name}"
    
    echo "✓ Encrypted container opened as /dev/mapper/${name}"
}

# Function to setup LVM inside LUKS
setup_lvm() {
    local luks_device="/dev/mapper/$1"
    
    echo "Setting up LVM inside encrypted container..."
    
    # Create physical volume
    pvcreate "${luks_device}"
    echo "✓ Physical volume created"
    
    # Create volume group
    vgcreate "${VG_NAME}" "${luks_device}"
    echo "✓ Volume group '${VG_NAME}' created"
    
    # Get available space
    local total_pe=$(vgdisplay "${VG_NAME}" | grep "Total PE" | awk '{print $3}')
    local root_size=$((total_pe * 40 / 100))  # 40% for root
    local swap_size=$((total_pe * 10 / 100))  # 10% for swap
    local home_size=$((total_pe - root_size - swap_size))  # Rest for home
    
    # Create logical volumes
    lvcreate -l "${root_size}" -n "${ROOT_LV}" "${VG_NAME}"
    lvcreate -l "${swap_size}" -n "${SWAP_LV}" "${VG_NAME}"
    lvcreate -l "${home_size}" -n "${HOME_LV}" "${VG_NAME}"
    
    echo "✓ Logical volumes created:"
    echo "  - Root: ${root_size} PE"
    echo "  - Swap: ${swap_size} PE" 
    echo "  - Home: ${home_size} PE"
}

# Function to format filesystems
format_filesystems() {
    echo "Formatting filesystems..."
    
    # Format root filesystem
    mkfs.ext4 -L "hardened-root" "/dev/${VG_NAME}/${ROOT_LV}"
    echo "✓ Root filesystem formatted (ext4)"
    
    # Format home filesystem
    mkfs.ext4 -L "hardened-home" "/dev/${VG_NAME}/${HOME_LV}"
    echo "✓ Home filesystem formatted (ext4)"
    
    # Setup swap
    mkswap -L "hardened-swap" "/dev/${VG_NAME}/${SWAP_LV}"
    echo "✓ Swap formatted"
}

# Function to verify LUKS2 configuration
verify_luks2_config() {
    local device="$1"
    
    echo "Verifying LUKS2 configuration..."
    
    # Check LUKS header
    cryptsetup luksDump "${device}" | grep -E "(Version|Cipher|Hash|PBKDF|Memory|Iterations)"
    
    # Verify Argon2id is being used
    if cryptsetup luksDump "${device}" | grep -q "argon2id"; then
        echo "✓ Argon2id KDF confirmed"
    else
        echo "✗ ERROR: Argon2id KDF not found"
        return 1
    fi
    
    # Check memory parameter
    if cryptsetup luksDump "${device}" | grep -q "Memory:.*1048576"; then
        echo "✓ 1GB memory parameter confirmed"
    else
        echo "✗ WARNING: Memory parameter may not be 1GB"
    fi
    
    # Check iterations
    if cryptsetup luksDump "${device}" | grep -q "Iterations:.*4"; then
        echo "✓ 4 iterations confirmed"
    else
        echo "✗ WARNING: Iterations may not be 4"
    fi
}

# Main execution
main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
    
    if [[ ! -b "${DEVICE}" ]]; then
        echo "Error: Device ${DEVICE} not found"
        exit 1
    fi
    
    echo "WARNING: This will destroy all data on ${DEVICE}"
    echo "Press Enter to continue or Ctrl+C to abort..."
    read -r
    
    # Setup LUKS2 encryption
    setup_luks2 "${DEVICE}" "hardened-crypt"
    
    # Setup LVM
    setup_lvm "hardened-crypt"
    
    # Format filesystems
    format_filesystems
    
    # Verify configuration
    verify_luks2_config "${DEVICE}"
    
    echo
    echo "=== LUKS2 Setup Complete ==="
    echo "Encrypted device: ${DEVICE}"
    echo "Mapper name: hardened-crypt"
    echo "Volume group: ${VG_NAME}"
    echo "Logical volumes:"
    echo "  - /dev/${VG_NAME}/${ROOT_LV} (root)"
    echo "  - /dev/${VG_NAME}/${SWAP_LV} (swap)"
    echo "  - /dev/${VG_NAME}/${HOME_LV} (home)"
    echo
    echo "Next steps:"
    echo "1. Mount filesystems for installation"
    echo "2. Install base system"
    echo "3. Configure crypttab and fstab"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi