#!/bin/bash
# Debian Base System Installation with Custom Partitioning
# Orchestrates the complete installation process for Task 3
# Requirements: 3.1, 3.2, 3.3, 3.4

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:-/dev/sda}"
MOUNT_ROOT="/mnt/hardened"

echo "=== Hardened Debian Base Installation ==="
echo "Target device: ${DEVICE}"
echo "Mount root: ${MOUNT_ROOT}"
echo

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "✗ ERROR: This script must be run as root"
        exit 1
    fi
    
    # Check required tools
    local tools=("parted" "cryptsetup" "lvm2" "debootstrap" "wget" "gpg")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "✗ ERROR: Required tool '$tool' not found"
            exit 1
        fi
    done
    
    # Check target device
    if [[ ! -b "${DEVICE}" ]]; then
        echo "✗ ERROR: Device ${DEVICE} not found"
        exit 1
    fi
    
    echo "✓ Prerequisites check passed"
}

# Function to download and verify Debian ISO
download_debian() {
    echo "Step 1: Downloading and verifying Debian ISO..."
    "${SCRIPT_DIR}/download-debian-iso.sh"
    echo "✓ Debian ISO ready"
}

# Function to create partition layout
create_partitions() {
    echo "Step 2: Creating partition layout..."
    "${SCRIPT_DIR}/create-partition-layout.sh" "${DEVICE}"
    echo "✓ Partition layout created"
}

# Function to setup LUKS2 encryption
setup_encryption() {
    echo "Step 3: Setting up LUKS2 encryption..."
    "${SCRIPT_DIR}/setup-luks2-encryption.sh" "${DEVICE}3"
    echo "✓ LUKS2 encryption configured"
}

# Function to mount filesystems
mount_filesystems() {
    echo "Step 4: Mounting filesystems..."
    
    # Mount root filesystem
    mount "/dev/hardened-vg/root" "${MOUNT_ROOT}"
    
    # Create and mount boot directories
    mkdir -p "${MOUNT_ROOT}/boot/efi"
    mkdir -p "${MOUNT_ROOT}/recovery"
    mkdir -p "${MOUNT_ROOT}/home"
    
    # Mount EFI partition
    mount "${DEVICE}1" "${MOUNT_ROOT}/boot/efi"
    
    # Mount recovery partition
    mount "${DEVICE}2" "${MOUNT_ROOT}/recovery"
    
    # Mount home partition
    mount "/dev/hardened-vg/home" "${MOUNT_ROOT}/home"
    
    # Enable swap
    swapon "/dev/hardened-vg/swap"
    
    echo "✓ Filesystems mounted"
    
    # Display mount status
    echo "Mount status:"
    df -h | grep -E "(${MOUNT_ROOT}|hardened-vg)"
}

# Function to install base system
install_base_system() {
    echo "Step 5: Installing Debian base system..."
    
    # Install base system using debootstrap
    debootstrap --arch=amd64 --include=systemd,systemd-sysv,dbus \
        bookworm "${MOUNT_ROOT}" http://deb.debian.org/debian/
    
    echo "✓ Base system installed"
}

# Function to configure system
configure_system() {
    echo "Step 6: Configuring system..."
    
    # Copy configuration templates
    cp /tmp/fstab.template "${MOUNT_ROOT}/etc/fstab"
    cp /tmp/crypttab.template "${MOUNT_ROOT}/etc/crypttab"
    
    # Configure hostname
    echo "hardened-laptop" > "${MOUNT_ROOT}/etc/hostname"
    
    # Configure hosts file
    cat > "${MOUNT_ROOT}/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   hardened-laptop.localdomain hardened-laptop
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

    # Configure sources.list
    cat > "${MOUNT_ROOT}/etc/apt/sources.list" << EOF
deb http://deb.debian.org/debian bookworm main contrib non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware
EOF

    # Configure locale
    echo "en_US.UTF-8 UTF-8" > "${MOUNT_ROOT}/etc/locale.gen"
    
    # Configure timezone
    ln -sf /usr/share/zoneinfo/UTC "${MOUNT_ROOT}/etc/localtime"
    
    echo "✓ Basic system configuration completed"
}

# Function to install essential packages
install_essential_packages() {
    echo "Step 7: Installing essential packages..."
    
    # Chroot and install packages
    chroot "${MOUNT_ROOT}" /bin/bash << 'EOF'
# Update package lists
apt-get update

# Install essential packages for hardened system
apt-get install -y \
    linux-image-amd64 \
    linux-headers-amd64 \
    firmware-linux \
    grub-efi-amd64 \
    grub-efi-amd64-signed \
    shim-signed \
    cryptsetup \
    cryptsetup-initramfs \
    lvm2 \
    tpm2-tools \
    systemd-cryptsetup \
    initramfs-tools \
    openssh-server \
    sudo \
    vim \
    curl \
    wget \
    gnupg \
    ca-certificates \
    fail2ban \
    ufw \
    rng-tools \
    haveged

# Generate locale
locale-gen

# Update initramfs
update-initramfs -u -k all

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck
update-grub
EOF

    echo "✓ Essential packages installed"
}

# Function to create user account
create_user_account() {
    echo "Step 8: Creating user account..."
    
    chroot "${MOUNT_ROOT}" /bin/bash << 'EOF'
# Create user account
useradd -m -s /bin/bash -G sudo huser

# Set temporary password (should be changed on first login)
echo "huser:changeme123" | chpasswd

# Force password change on first login
chage -d 0 huser

echo "User 'huser' created with temporary password 'changeme123'"
echo "Password change will be required on first login"
EOF

    echo "✓ User account created"
}

# Function to cleanup and unmount
cleanup() {
    echo "Step 9: Cleanup and unmount..."
    
    # Sync filesystems
    sync
    
    # Unmount filesystems in reverse order
    swapoff "/dev/hardened-vg/swap" || true
    umount "${MOUNT_ROOT}/home" || true
    umount "${MOUNT_ROOT}/recovery" || true
    umount "${MOUNT_ROOT}/boot/efi" || true
    umount "${MOUNT_ROOT}" || true
    
    # Close LUKS container
    cryptsetup luksClose hardened-crypt || true
    
    echo "✓ Cleanup completed"
}

# Function to display installation summary
display_summary() {
    echo
    echo "=== Installation Summary ==="
    echo "Device: ${DEVICE}"
    echo "Partitions:"
    echo "  - ${DEVICE}1: EFI System Partition (512MB)"
    echo "  - ${DEVICE}2: Recovery Partition (1GB)"
    echo "  - ${DEVICE}3: LUKS2 Encrypted Container"
    echo
    echo "LVM Layout:"
    echo "  - /dev/hardened-vg/root: Root filesystem"
    echo "  - /dev/hardened-vg/home: Home filesystem"
    echo "  - /dev/hardened-vg/swap: Swap space"
    echo
    echo "Encryption:"
    echo "  - LUKS2 with Argon2id KDF"
    echo "  - 1GB memory, 4 iterations"
    echo "  - AES-256-XTS cipher"
    echo
    echo "User Account:"
    echo "  - Username: huser"
    echo "  - Temporary password: changeme123"
    echo "  - Groups: sudo"
    echo
    echo "Next Steps:"
    echo "1. Reboot the system"
    echo "2. Change the user password on first login"
    echo "3. Proceed with Task 4: UEFI Secure Boot setup"
    echo
    echo "Installation completed successfully!"
}

# Main execution with error handling
main() {
    # Set up error handling
    trap cleanup EXIT
    
    echo "Starting Debian base system installation..."
    echo "This process will:"
    echo "1. Download and verify Debian ISO"
    echo "2. Create custom partition layout"
    echo "3. Setup LUKS2 encryption with Argon2id"
    echo "4. Install base Debian system"
    echo "5. Configure essential packages"
    echo
    echo "WARNING: This will destroy all data on ${DEVICE}"
    echo "Press Enter to continue or Ctrl+C to abort..."
    read -r
    
    check_prerequisites
    download_debian
    create_partitions
    setup_encryption
    mount_filesystems
    install_base_system
    configure_system
    install_essential_packages
    create_user_account
    
    display_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi