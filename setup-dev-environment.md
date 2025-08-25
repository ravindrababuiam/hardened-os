# Hardened Laptop OS - Development Environment Setup

## Overview

This document provides instructions for setting up the development environment for the Hardened Laptop OS project. The development environment requires Ubuntu LTS with specific hardware requirements and tooling.

## Hardware Requirements

### Build Host Requirements
- **OS**: Ubuntu LTS (22.04 or later)
- **RAM**: 16-64GB (minimum 16GB for kernel compilation)
- **Storage**: 250+ GB SSD (for build artifacts and VM images)
- **CPU**: x86_64 with virtualization support (Intel VT-x or AMD-V)

### Target Laptop Requirements
- **Architecture**: x86_64 (Intel/AMD 64-bit)
- **UEFI**: UEFI firmware with Secure Boot support
- **TPM**: TPM 2.0 chip (required for measured boot and key sealing)
- **Storage**: NVMe SSD recommended for performance

## Directory Structure

The development workspace is organized as follows:

```
~/harden/
├── src/        # Source code repositories
├── keys/       # Signing keys (development and production)
├── build/      # Build outputs and temporary files
├── ci/         # CI/CD scripts and configurations
└── artifacts/  # Final build artifacts (ISOs, packages)
```

## Required Tooling Installation

### Core Development Tools
```bash
# Update package lists
sudo apt update

# Install core build tools
sudo apt install -y \
    git \
    build-essential \
    clang \
    gcc \
    python3 \
    python3-pip \
    make \
    cmake \
    pkg-config \
    autoconf \
    automake \
    libtool

# Install kernel build dependencies
sudo apt install -y \
    libncurses-dev \
    flex \
    bison \
    libssl-dev \
    libelf-dev \
    bc \
    kmod \
    cpio \
    rsync
```

### Virtualization and Testing Tools
```bash
# Install QEMU/KVM for testing
sudo apt install -y \
    qemu-kvm \
    qemu-utils \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager

# Add user to libvirt group
sudo usermod -a -G libvirt $USER
```

### Cryptographic and Security Tools
```bash
# Install cryptsetup for LUKS testing
sudo apt install -y \
    cryptsetup \
    cryptsetup-bin

# Install TPM2 tools
sudo apt install -y \
    tpm2-tools \
    libtss2-dev

# Install sbctl for Secure Boot management
# Note: sbctl may need to be built from source or installed via snap
sudo snap install sbctl --classic
```

### Container and Build Tools
```bash
# Install Docker for reproducible builds
sudo apt install -y \
    docker.io \
    docker-compose

# Add user to docker group
sudo usermod -a -G docker $USER

# Install additional build tools
sudo apt install -y \
    debootstrap \
    squashfs-tools \
    genisoimage \
    syslinux-utils
```

## Hardware Verification Scripts

### Check TPM2 Availability
```bash
#!/bin/bash
# check-tpm2.sh - Verify TPM2 chip availability

echo "Checking TPM2 availability..."

# Check if TPM device exists
if [ -c /dev/tpm0 ]; then
    echo "✓ TPM device found at /dev/tpm0"
else
    echo "✗ No TPM device found"
    exit 1
fi

# Check TPM2 tools
if command -v tpm2_getcap >/dev/null 2>&1; then
    echo "✓ TPM2 tools installed"
    
    # Get TPM capabilities
    echo "TPM2 Capabilities:"
    tpm2_getcap properties-fixed 2>/dev/null || echo "  Unable to read TPM properties"
else
    echo "✗ TPM2 tools not installed"
fi
```

### Check UEFI Secure Boot
```bash
#!/bin/bash
# check-uefi.sh - Verify UEFI and Secure Boot support

echo "Checking UEFI and Secure Boot..."

# Check if system booted with UEFI
if [ -d /sys/firmware/efi ]; then
    echo "✓ System booted with UEFI"
    
    # Check Secure Boot status
    if [ -f /sys/firmware/efi/efivars/SecureBoot-* ]; then
        sb_status=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | awk '{print $NF}')
        if [ "$sb_status" = "1" ]; then
            echo "✓ Secure Boot is enabled"
        else
            echo "! Secure Boot is disabled (can be enabled later)"
        fi
    else
        echo "? Secure Boot status unknown"
    fi
else
    echo "✗ System did not boot with UEFI (Legacy BIOS detected)"
    exit 1
fi
```

### Check System Resources
```bash
#!/bin/bash
# check-resources.sh - Verify system meets hardware requirements

echo "Checking system resources..."

# Check RAM
ram_gb=$(free -g | awk '/^Mem:/{print $2}')
if [ "$ram_gb" -ge 16 ]; then
    echo "✓ RAM: ${ram_gb}GB (meets 16GB minimum)"
else
    echo "✗ RAM: ${ram_gb}GB (below 16GB minimum)"
fi

# Check disk space
disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$disk_gb" -ge 250 ]; then
    echo "✓ Disk space: ${disk_gb}GB available (meets 250GB minimum)"
else
    echo "! Disk space: ${disk_gb}GB available (below 250GB recommended)"
fi

# Check CPU architecture
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    echo "✓ Architecture: $arch"
else
    echo "✗ Architecture: $arch (x86_64 required)"
fi

# Check virtualization support
if grep -q -E "(vmx|svm)" /proc/cpuinfo; then
    echo "✓ CPU virtualization support detected"
else
    echo "✗ No CPU virtualization support detected"
fi
```

## Environment Setup Script

Create and run the complete setup script:

```bash
#!/bin/bash
# setup-environment.sh - Complete development environment setup

set -e

echo "Setting up Hardened Laptop OS development environment..."

# Create directory structure
echo "Creating directory structure..."
mkdir -p ~/harden/{src,keys,build,ci,artifacts}

# Set proper permissions for keys directory
chmod 700 ~/harden/keys

# Install required packages
echo "Installing required packages..."
sudo apt update

# Core tools
sudo apt install -y git build-essential clang gcc python3 python3-pip make cmake

# Kernel build tools
sudo apt install -y libncurses-dev flex bison libssl-dev libelf-dev bc kmod cpio rsync

# Virtualization
sudo apt install -y qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients

# Security tools
sudo apt install -y cryptsetup tpm2-tools

# Container tools
sudo apt install -y docker.io debootstrap squashfs-tools genisoimage

# Add user to required groups
sudo usermod -a -G libvirt,docker $USER

echo "✓ Development environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Log out and back in to apply group membership"
echo "2. Run hardware verification scripts"
echo "3. Proceed to task 2: Create development signing keys"
```

## Verification Checklist

After setup, verify the following:

- [ ] Directory structure created at ~/harden/
- [ ] All required packages installed
- [ ] User added to libvirt and docker groups
- [ ] TPM2 device accessible
- [ ] UEFI firmware detected
- [ ] Sufficient RAM and disk space
- [ ] Virtualization support enabled

## Security Notes

- The `~/harden/keys` directory has restricted permissions (700)
- Development keys should never be used for production
- All build processes should be performed in isolated environments
- Regular backups of the development environment are recommended

## Troubleshooting

### Common Issues

1. **TPM not detected**: Ensure TPM is enabled in BIOS/UEFI settings
2. **Insufficient permissions**: Verify user is in required groups and re-login
3. **Build failures**: Check that all dependencies are installed
4. **Virtualization issues**: Enable VT-x/AMD-V in BIOS settings

For additional support, refer to the project documentation or create an issue in the project repository.