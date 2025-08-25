#!/bin/bash
# setup-environment.sh - Complete development environment setup for Hardened Laptop OS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Hardened Laptop OS Development Environment Setup ==="
echo

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo "Warning: This script is designed for Ubuntu LTS"
    echo "Other distributions may require different package names"
    echo
fi

# Create directory structure
echo "1. Creating directory structure..."
mkdir -p ~/harden/{src,keys,build,ci,artifacts}

# Set proper permissions for keys directory
chmod 700 ~/harden/keys
echo "   ✓ Created ~/harden/ workspace with secure keys directory"

# Update package lists
echo
echo "2. Updating package lists..."
sudo apt update

# Install core development tools
echo
echo "3. Installing core development tools..."
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
    libtool \
    curl \
    wget

echo "   ✓ Core development tools installed"

# Install kernel build dependencies
echo
echo "4. Installing kernel build dependencies..."
sudo apt install -y \
    libncurses-dev \
    flex \
    bison \
    libssl-dev \
    libelf-dev \
    bc \
    kmod \
    cpio \
    rsync \
    dwarves \
    zstd

echo "   ✓ Kernel build dependencies installed"

# Install virtualization tools
echo
echo "5. Installing virtualization tools..."
sudo apt install -y \
    qemu-kvm \
    qemu-utils \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    ovmf

echo "   ✓ Virtualization tools installed"

# Install cryptographic and security tools
echo
echo "6. Installing cryptographic and security tools..."
sudo apt install -y \
    cryptsetup \
    cryptsetup-bin \
    tpm2-tools \
    libtss2-dev \
    efibootmgr \
    mokutil \
    shim-signed

echo "   ✓ Cryptographic and security tools installed"

# Install sbctl (Secure Boot management)
echo
echo "7. Installing sbctl..."
if ! command -v sbctl >/dev/null 2>&1; then
    # Try snap first
    if command -v snap >/dev/null 2>&1; then
        sudo snap install sbctl --classic 2>/dev/null || {
            echo "   ! sbctl snap installation failed, will need manual installation"
            echo "   See: https://github.com/Foxboron/sbctl"
        }
    else
        echo "   ! sbctl requires manual installation"
        echo "   See: https://github.com/Foxboron/sbctl"
    fi
else
    echo "   ✓ sbctl already installed"
fi

# Install container and build tools
echo
echo "8. Installing container and build tools..."
sudo apt install -y \
    docker.io \
    docker-compose \
    debootstrap \
    squashfs-tools \
    genisoimage \
    syslinux-utils \
    isolinux \
    xorriso

echo "   ✓ Container and build tools installed"

# Install additional security tools
echo
echo "9. Installing additional security tools..."
sudo apt install -y \
    checksec \
    strace \
    ltrace \
    gdb \
    valgrind \
    binutils \
    objdump

echo "   ✓ Additional security tools installed"

# Add user to required groups
echo
echo "10. Configuring user permissions..."
current_user=$(whoami)

# Add to libvirt group for VM management
if getent group libvirt >/dev/null; then
    sudo usermod -a -G libvirt "$current_user"
    echo "   ✓ Added $current_user to libvirt group"
fi

# Add to docker group for container management
if getent group docker >/dev/null; then
    sudo usermod -a -G docker "$current_user"
    echo "   ✓ Added $current_user to docker group"
fi

# Add to kvm group if it exists
if getent group kvm >/dev/null; then
    sudo usermod -a -G kvm "$current_user"
    echo "   ✓ Added $current_user to kvm group"
fi

# Enable and start services
echo
echo "11. Enabling required services..."
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
sudo systemctl enable docker
sudo systemctl start docker

echo "   ✓ Services enabled and started"

# Create useful aliases and environment setup
echo
echo "12. Creating development environment configuration..."
cat > ~/harden/.env << 'EOF'
# Hardened Laptop OS Development Environment
export HARDEN_ROOT="$HOME/harden"
export HARDEN_SRC="$HARDEN_ROOT/src"
export HARDEN_KEYS="$HARDEN_ROOT/keys"
export HARDEN_BUILD="$HARDEN_ROOT/build"
export HARDEN_CI="$HARDEN_ROOT/ci"
export HARDEN_ARTIFACTS="$HARDEN_ROOT/artifacts"

# Build configuration
export MAKEFLAGS="-j$(nproc)"
export KBUILD_BUILD_USER="harden-dev"
export KBUILD_BUILD_HOST="harden-build"

# Security-focused compiler flags
export CFLAGS="-O2 -fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-z,relro,-z,now -pie"

# Aliases for common tasks
alias harden-build="cd $HARDEN_BUILD"
alias harden-src="cd $HARDEN_SRC"
alias harden-check="$HARDEN_ROOT/../scripts/check-all.sh"

echo "Hardened Laptop OS development environment loaded"
EOF

echo "   ✓ Environment configuration created at ~/harden/.env"

# Make scripts executable
echo
echo "13. Making verification scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh
echo "   ✓ Verification scripts are executable"

# Create a master verification script
cat > "$SCRIPT_DIR/check-all.sh" << 'EOF'
#!/bin/bash
# check-all.sh - Run all hardware and environment verification checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Complete System Verification for Hardened Laptop OS ==="
echo

# Run all verification scripts
"$SCRIPT_DIR/check-resources.sh"
echo
"$SCRIPT_DIR/check-uefi.sh"
echo
"$SCRIPT_DIR/check-tpm2.sh"

echo
echo "=== Verification Summary ==="
echo "If all checks passed, the system is ready for hardened OS development."
echo "If any checks failed, address the issues before proceeding."
EOF

chmod +x "$SCRIPT_DIR/check-all.sh"

echo
echo "=== Setup Complete! ==="
echo
echo "✓ Development environment successfully configured"
echo
echo "Next steps:"
echo "1. Log out and back in to apply group membership changes"
echo "2. Source the environment: source ~/harden/.env"
echo "3. Run verification: ./scripts/check-all.sh"
echo "4. Proceed to task 2: Create development signing keys"
echo
echo "Workspace created at: ~/harden/"
echo "Environment config: ~/harden/.env"
echo "Verification scripts: ./scripts/"
echo
echo "To load the development environment in future sessions:"
echo "  source ~/harden/.env"