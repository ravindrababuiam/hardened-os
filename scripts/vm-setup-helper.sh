#!/bin/bash
# VM Setup Helper Script
# Prepares Debian VM for Hardened OS testing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

check_vm_environment() {
    header "Checking VM environment..."
    
    # Check if running in VM
    if systemd-detect-virt &>/dev/null; then
        local virt_type=$(systemd-detect-virt)
        log "Running in virtual machine: $virt_type"
    else
        warn "Not detected as virtual machine - this script is designed for VM testing"
    fi
    
    # Check system resources
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local disk_gb=$(df -BG / | awk 'NR==2{print $2}' | sed 's/G//')
    
    log "System resources: ${ram_gb}GB RAM, ${disk_gb}GB disk"
    
    if [[ $ram_gb -lt 4 ]]; then
        warn "Low RAM detected. Recommend 8GB+ for full testing"
    fi
    
    if [[ $disk_gb -lt 40 ]]; then
        warn "Low disk space. Recommend 80GB+ for full testing"
    fi
}

update_system() {
    header "Updating Debian system..."
    
    sudo apt update
    sudo apt upgrade -y
    
    log "System updated successfully"
}

install_essential_tools() {
    header "Installing essential development tools..."
    
    local packages=(
        git
        wget
        curl
        sudo
        vim
        build-essential
        python3
        python3-pip
        bash-completion
        htop
        tree
        unzip
        rsync
    )
    
    sudo apt install -y "${packages[@]}"
    
    log "Essential tools installed"
}

install_security_tools() {
    header "Installing security and testing tools..."
    
    local security_packages=(
        # Secure Boot tools
        sbsigntool
        efitools
        
        # TPM2 tools
        tpm2-tools
        
        # SELinux tools
        selinux-utils
        selinux-policy-default
        auditd
        
        # Sandboxing tools
        bubblewrap
        
        # Network tools
        nftables
        iptables
        
        # Cryptographic tools
        openssl
        cryptsetup
        
        # Build tools
        clang
        gcc
        make
        cmake
        
        # Testing tools
        stress-ng
        sysbench
    )
    
    sudo apt install -y "${security_packages[@]}" || {
        warn "Some security packages may not be available in standard repos"
        log "This is normal - we'll handle missing packages in individual tests"
    }
    
    log "Security tools installation completed"
}

setup_working_directory() {
    header "Setting up working directory..."
    
    local work_dir="$HOME/hardened-os-test"
    
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Create directory structure
    mkdir -p {scripts,docs,configs,logs,keys,build}
    
    log "Working directory created: $work_dir"
    echo "export HARDENED_OS_DIR=$work_dir" >> ~/.bashrc
}

install_virtualbox_additions() {
    header "Installing VirtualBox Guest Additions..."
    
    if lsmod | grep -q vboxguest; then
        log "VirtualBox Guest Additions already installed"
        return 0
    fi
    
    # Install kernel headers and build tools
    sudo apt install -y linux-headers-$(uname -r) dkms
    
    # Try to install guest additions
    if sudo apt install -y virtualbox-guest-additions-iso; then
        log "VirtualBox Guest Additions installed via package"
    else
        warn "Could not install Guest Additions via package"
        log "You may need to install manually from VirtualBox menu"
    fi
}

setup_shared_folder() {
    header "Setting up shared folder access..."
    
    # Add user to vboxsf group for shared folder access
    sudo usermod -aG vboxsf "$USER"
    
    # Create mount point
    sudo mkdir -p /mnt/shared
    
    log "Shared folder setup completed"
    warn "You need to logout/login for group changes to take effect"
    warn "Configure shared folder in VirtualBox settings, then mount with:"
    warn "sudo mount -t vboxsf YourSharedFolderName /mnt/shared"
}

create_test_runner() {
    header "Creating test runner script..."
    
    cat > ~/run-hardened-tests.sh << 'EOF'
#!/bin/bash
# Hardened OS Test Runner for VM
set -euo pipefail

HARDENED_OS_DIR="${HARDENED_OS_DIR:-$HOME/hardened-os-test}"
cd "$HARDENED_OS_DIR"

echo "=== Hardened OS VM Test Runner ==="
echo "Working directory: $HARDENED_OS_DIR"
echo

# Check if scripts are available
if [[ ! -d "scripts" ]]; then
    echo "❌ Scripts directory not found!"
    echo "Please copy Hardened OS files to $HARDENED_OS_DIR"
    echo
    echo "Options:"
    echo "1. Use shared folder: sudo mount -t vboxsf SharedFolder /mnt/shared && cp -r /mnt/shared/* ."
    echo "2. Use git clone: git clone <repository-url> ."
    echo "3. Use SCP/SFTP to transfer files"
    exit 1
fi

# Make all scripts executable
find scripts -name "*.sh" -exec chmod +x {} \;

echo "Available test phases:"
echo "1. Environment Setup (Tasks 1-3)"
echo "2. Boot Security (Tasks 4-5)"
echo "3. Kernel Hardening (Tasks 6-8)"
echo "4. Access Control (Tasks 9-11)"
echo "5. Application Security (Tasks 12-14)"
echo "6. Updates & Supply Chain (Tasks 15-17)"
echo "7. Production Infrastructure (Task 18)"
echo "8. Run All Tests"
echo

read -p "Select test phase (1-8): " phase

case $phase in
    1)
        echo "Running Environment Setup tests..."
        bash scripts/setup-environment.sh
        bash scripts/generate-dev-keys.sh
        bash scripts/validate-debian-installation.sh
        ;;
    2)
        echo "Running Boot Security tests..."
        sudo bash scripts/setup-secure-boot.sh --vm-mode || true
        sudo bash scripts/setup-tpm2-measured-boot.sh --vm-mode || true
        bash scripts/validate-task-4.sh || true
        bash scripts/validate-task-5.sh || true
        ;;
    3)
        echo "Running Kernel Hardening tests..."
        echo "⚠️  Warning: Kernel compilation takes significant time!"
        read -p "Continue? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            sudo bash scripts/build-hardened-kernel.sh || true
            bash scripts/validate-task-6.sh || true
        fi
        ;;
    4)
        echo "Running Access Control tests..."
        sudo bash scripts/setup-selinux-enforcing.sh || true
        sudo bash scripts/minimize-services.sh || true
        sudo bash scripts/setup-userspace-hardening.sh || true
        ;;
    5)
        echo "Running Application Security tests..."
        sudo bash scripts/setup-bubblewrap-sandboxing.sh || true
        sudo bash scripts/setup-network-controls.sh || true
        bash scripts/validate-task-12.sh || true
        bash scripts/validate-task-13.sh || true
        ;;
    6)
        echo "Running Updates & Supply Chain tests..."
        sudo bash scripts/setup-secure-updates.sh || true
        bash scripts/validate-task-15.sh || true
        bash scripts/validate-task-17.sh || true
        ;;
    7)
        echo "Running Production Infrastructure tests..."
        sudo bash scripts/setup-hsm-infrastructure.sh || true
        bash scripts/validate-task-18.sh || true
        ;;
    8)
        echo "Running ALL tests..."
        echo "⚠️  This will take considerable time!"
        read -p "Continue? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            bash ~/test-all-components.sh || true
        fi
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

echo
echo "Test phase completed!"
echo "Check logs in $HARDENED_OS_DIR/logs/ for detailed results"
EOF

    chmod +x ~/run-hardened-tests.sh
    
    log "Test runner created: ~/run-hardened-tests.sh"
}

create_quick_status_check() {
    header "Creating system status checker..."
    
    cat > ~/check-hardened-status.sh << 'EOF'
#!/bin/bash
# Quick Hardened OS Status Check
echo "=== Hardened OS Status Check ==="

echo "🖥️  System Info:"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo "  Virtualization: $(systemd-detect-virt 2>/dev/null || echo 'none')"
echo

echo "🔒 Security Status:"
echo "  SELinux: $(getenforce 2>/dev/null || echo 'not installed')"
echo "  TPM2: $(ls /dev/tpm* 2>/dev/null | wc -l) device(s)"
echo "  Secure Boot: $(mokutil --sb-state 2>/dev/null || echo 'not available')"
echo

echo "🛡️  Hardening Features:"
echo "  ASLR: $(cat /proc/sys/kernel/randomize_va_space)"
echo "  Stack Protection: $(gcc -v 2>&1 | grep -o 'enable-default-ssp' || echo 'unknown')"
echo "  Bubblewrap: $(which bwrap >/dev/null && echo 'installed' || echo 'not installed')"
echo

echo "🌐 Network Security:"
echo "  nftables: $(systemctl is-active nftables 2>/dev/null || echo 'inactive')"
echo "  Firewall rules: $(nft list tables 2>/dev/null | wc -l) table(s)"
echo

echo "📦 Services:"
echo "  Running services: $(systemctl list-units --type=service --state=running | grep -c '\.service')"
echo "  Failed services: $(systemctl list-units --type=service --state=failed | grep -c '\.service')"
echo

echo "💾 Resources:"
echo "  Memory: $(free -h | awk '/^Mem:/{print $3"/"$2}')"
echo "  Disk: $(df -h / | awk 'NR==2{print $3"/"$2" ("$5" used)"}')"
echo

echo "📊 Recent Logs:"
echo "  Errors: $(journalctl --since '1 hour ago' -p err | wc -l)"
echo "  Warnings: $(journalctl --since '1 hour ago' -p warning | wc -l)"
EOF

    chmod +x ~/check-hardened-status.sh
    
    log "Status checker created: ~/check-hardened-status.sh"
}

main() {
    echo "=== Hardened OS VM Setup Helper ==="
    echo "This script prepares your Debian VM for testing"
    echo
    
    check_vm_environment
    update_system
    install_essential_tools
    install_security_tools
    setup_working_directory
    install_virtualbox_additions
    setup_shared_folder
    create_test_runner
    create_quick_status_check
    
    echo
    echo "=== Setup Complete! ==="
    echo
    log "✅ VM is ready for Hardened OS testing"
    echo
    echo "Next steps:"
    echo "1. Logout/login to activate group changes"
    echo "2. Configure shared folder in VirtualBox settings"
    echo "3. Copy Hardened OS files to ~/hardened-os-test/"
    echo "4. Run: ~/run-hardened-tests.sh"
    echo
    echo "Quick commands:"
    echo "  Status check: ~/check-hardened-status.sh"
    echo "  Test runner: ~/run-hardened-tests.sh"
    echo "  Working dir: cd ~/hardened-os-test"
    echo
    warn "Reboot recommended after setup completion"
}

main "$@"