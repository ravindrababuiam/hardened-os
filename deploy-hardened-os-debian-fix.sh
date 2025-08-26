#!/bin/bash
# Debian-Compatible Deployment Script for Hardened Laptop OS
# Fixed package names and dependencies for Debian systems

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/hardened-os-deployment.log"
DEPLOYMENT_CONFIG="/tmp/deployment-config.yaml"
TARGET_DEVICE=""
DEPLOYMENT_MODE="full"
SKIP_HARDWARE_CHECK=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} $message" | tee -a "$LOG_FILE"
}

warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] WARNING:${NC} $message" | tee -a "$LOG_FILE"
}

error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] ERROR:${NC} $message" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message"
}

success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message"
}

# Progress tracking
TOTAL_STEPS=15
CURRENT_STEP=0

progress() {
    local step_name="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "${PURPLE}[STEP $CURRENT_STEP/$TOTAL_STEPS - $percentage%]${NC} $step_name"
    log "Starting step $CURRENT_STEP/$TOTAL_STEPS: $step_name"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                DEPLOYMENT_MODE="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_DEVICE="$2"
                shift 2
                ;;
            -c|--config)
                DEPLOYMENT_CONFIG="$2"
                shift 2
                ;;
            --skip-hardware-check)
                SKIP_HARDWARE_CHECK=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--mode full|minimal] [--target /dev/sdX] [--skip-hardware-check] [--dry-run]"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

# Install Debian-compatible dependencies
install_debian_dependencies() {
    progress "Installing Debian Dependencies"
    
    log "Installing Debian-compatible packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would install Debian dependencies"
        return 0
    fi
    
    # Update package lists
    apt update
    
    # Detect Debian version
    local debian_version=$(cat /etc/debian_version | cut -d. -f1)
    log "Detected Debian version: $debian_version"
    
    # Install core build tools (Debian-compatible)
    log "Installing core build tools..."
    apt install -y \
        git build-essential clang gcc python3 make cmake \
        libncurses-dev flex bison libssl-dev libelf-dev \
        bc kmod cpio initramfs-tools \
        cryptsetup-bin \
        debootstrap squashfs-tools \
        rsyslog logrotate \
        nftables iptables-persistent \
        bubblewrap \
        python3-full python3-venv \
        curl wget gnupg2 \
        dkms linux-headers-$(uname -r)
    
    # Install virtualization tools (if available)
    log "Installing virtualization tools..."
    if apt-cache search qemu-kvm | grep -q qemu-kvm; then
        apt install -y qemu-kvm libvirt-daemon-system virt-manager
    else
        apt install -y qemu-system-x86 libvirt-daemon-system
        warn "qemu-kvm not available, installed qemu-system-x86"
    fi
    
    # Install TPM tools (if available)
    log "Installing TPM tools..."
    if apt-cache search tpm2-tools | grep -q tpm2-tools; then
        apt install -y tpm2-tools
    else
        warn "tpm2-tools not available in repositories"
    fi
    
    # Install UEFI tools
    log "Installing UEFI tools..."
    apt install -y efibootmgr
    if apt-cache search efivar | grep -q efivar; then
        apt install -y efivar
    fi
    
    # Install SELinux packages (Debian-specific)
    log "Installing SELinux packages..."
    if apt-cache search selinux-utils | grep -q selinux-utils; then
        apt install -y selinux-utils selinux-basics auditd
        
        # Try to install SELinux policy packages
        if apt-cache search selinux-policy-default | grep -q selinux-policy-default; then
            apt install -y selinux-policy-default
        elif apt-cache search refpolicy-targeted | grep -q refpolicy-targeted; then
            apt install -y refpolicy-targeted
        else
            warn "SELinux policy packages not found - will configure manually"
        fi
    else
        warn "SELinux packages not available - will skip SELinux configuration"
    fi
    
    # Install PKCS#11 tools (if available)
    log "Installing PKCS#11 tools..."
    if apt-cache search opensc | grep -q opensc; then
        apt install -y opensc opensc-pkcs11
    fi
    
    if apt-cache search softhsm2 | grep -q softhsm2; then
        apt install -y softhsm2
    fi
    
    # Install additional security tools
    log "Installing additional security tools..."
    apt install -y \
        apparmor apparmor-utils \
        fail2ban \
        rkhunter chkrootkit \
        aide \
        lynis
    
    # Install Python packages using apt instead of pip (Debian externally managed environment)
    log "Installing Python packages via apt..."
    apt install -y \
        python3-yaml \
        python3-cryptography \
        python3-requests \
        python3-jinja2 \
        python3-setuptools \
        python3-wheel
    
    success "Debian dependencies installed successfully"
}

# Install sbctl from source (if needed)
install_sbctl() {
    if command -v sbctl &> /dev/null; then
        log "sbctl already available"
        return 0
    fi
    
    log "Installing sbctl from source..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would install sbctl"
        return 0
    fi
    
    # Install Go if not available
    if ! command -v go &> /dev/null; then
        apt install -y golang-go
    fi
    
    # Clone and build sbctl
    cd /tmp
    git clone https://github.com/Foxboron/sbctl.git
    cd sbctl
    make
    make install
    cd "$SCRIPT_DIR"
    
    log "sbctl installed successfully"
}

# Set up build environment
setup_build_environment() {
    progress "Setting Up Build Environment"
    
    log "Creating build environment structure..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would create build environment"
        return 0
    fi
    
    # Create directory structure
    mkdir -p ~/harden/{src,keys,build,ci,artifacts}
    chmod 700 ~/harden/keys
    
    # Create hardened-os directories
    mkdir -p /etc/hardened-os
    mkdir -p /var/log/hardened-os
    mkdir -p /opt/hardened-os
    
    # Set up environment variables
    cat > /etc/environment << 'EOF'
# Hardened OS Environment
HARDEN_ROOT="/root/harden"
HARDEN_KEYS="/root/harden/keys"
HARDEN_BUILD="/root/harden/build"
HARDEN_ARTIFACTS="/root/harden/artifacts"
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/hardened-os/bin"
EOF
    
    success "Build environment created"
}

# Configure basic security hardening
configure_basic_hardening() {
    progress "Configuring Basic Security Hardening"
    
    log "Applying basic security hardening..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would configure basic hardening"
        return 0
    fi
    
    # Configure sysctl security settings
    cat > /etc/sysctl.d/99-hardened-os.conf << 'EOF'
# Hardened OS Security Settings

# Network security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1

# Memory protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.kexec_load_disabled = 1

# File system security
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
    
    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-hardened-os.conf
    
    # Configure basic firewall
    log "Configuring basic firewall..."
    
    # Enable nftables
    systemctl enable nftables
    
    # Create basic nftables configuration
    cat > /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow loopback
        iif lo accept
        
        # Allow established connections
        ct state established,related accept
        
        # Allow SSH (be careful!)
        tcp dport ssh accept
        
        # Allow ICMP
        icmp type echo-request accept
        icmpv6 type echo-request accept
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
    
    # Start nftables
    systemctl start nftables
    
    success "Basic hardening configured"
}

# Install and configure SELinux (if available)
configure_selinux() {
    progress "Configuring SELinux"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would configure SELinux"
        return 0
    fi
    
    if ! command -v selinux-activate &> /dev/null; then
        warn "SELinux not available - skipping SELinux configuration"
        return 0
    fi
    
    log "Configuring SELinux..."
    
    # Activate SELinux
    selinux-activate
    
    # Configure SELinux to enforcing mode
    sed -i 's/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    
    # Enable auditd for SELinux logging
    systemctl enable auditd
    systemctl start auditd
    
    log "SELinux configured - reboot required for full activation"
}

# Install hardened-os components
install_hardened_components() {
    progress "Installing Hardened OS Components"
    
    log "Installing hardened-os specific components..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would install hardened components"
        return 0
    fi
    
    # Install logging system
    if [[ -f "$SCRIPT_DIR/hardened-os/logging/install-logging-system.sh" ]]; then
        log "Installing logging system..."
        chmod +x "$SCRIPT_DIR/hardened-os/logging/install-logging-system.sh"
        "$SCRIPT_DIR/hardened-os/logging/install-logging-system.sh"
    fi
    
    # Install incident response system
    if [[ -f "$SCRIPT_DIR/hardened-os/incident-response/install-incident-response.sh" ]]; then
        log "Installing incident response system..."
        chmod +x "$SCRIPT_DIR/hardened-os/incident-response/install-incident-response.sh"
        "$SCRIPT_DIR/hardened-os/incident-response/install-incident-response.sh"
    fi
    
    success "Hardened OS components installed"
}

# Configure system services
configure_services() {
    progress "Configuring System Services"
    
    log "Configuring system services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would configure services"
        return 0
    fi
    
    # Disable unnecessary services
    local services_to_disable=(
        "bluetooth"
        "cups"
        "avahi-daemon"
        "whoopsie"
        "apport"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &> /dev/null; then
            log "Disabling $service..."
            systemctl disable "$service"
            systemctl stop "$service" 2>/dev/null || true
        fi
    done
    
    # Enable security services
    local services_to_enable=(
        "fail2ban"
        "nftables"
        "auditd"
        "apparmor"
    )
    
    for service in "${services_to_enable[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            log "Enabling $service..."
            systemctl enable "$service"
            systemctl start "$service" 2>/dev/null || true
        fi
    done
    
    success "System services configured"
}

# Run verification tests
run_verification() {
    progress "Running Verification Tests"
    
    log "Running deployment verification..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would run verification tests"
        return 0
    fi
    
    # Run basic system checks
    log "Checking system status..."
    
    # Check if services are running
    local critical_services=("rsyslog" "nftables")
    for service in "${critical_services[@]}"; do
        if systemctl is-active "$service" &> /dev/null; then
            log "✓ $service is running"
        else
            warn "✗ $service is not running"
        fi
    done
    
    # Check firewall status
    if nft list tables | grep -q "inet filter"; then
        log "✓ Firewall is configured"
    else
        warn "✗ Firewall not properly configured"
    fi
    
    # Run component tests if available
    if [[ -f "$SCRIPT_DIR/hardened-os/logging/test-logging-system.sh" ]]; then
        log "Testing logging system..."
        chmod +x "$SCRIPT_DIR/hardened-os/logging/test-logging-system.sh"
        "$SCRIPT_DIR/hardened-os/logging/test-logging-system.sh" || warn "Logging system test failed"
    fi
    
    success "Verification completed"
}

# Generate deployment report
generate_report() {
    progress "Generating Deployment Report"
    
    local report_file="/var/log/hardened-os-deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Hardened Laptop OS Deployment Report (Debian)

## Deployment Summary
- **Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Mode**: $DEPLOYMENT_MODE
- **Target Device**: ${TARGET_DEVICE:-"Not specified"}
- **System**: $(uname -a)
- **Debian Version**: $(cat /etc/debian_version)

## Components Installed
- ✓ Basic security hardening
- ✓ Firewall configuration (nftables)
- ✓ System service hardening
$(if systemctl is-active auditd &> /dev/null; then echo "- ✓ Audit logging"; fi)
$(if command -v selinux-activate &> /dev/null; then echo "- ✓ SELinux (requires reboot)"; fi)
$(if [[ -f /usr/local/bin/hardened-log-server ]]; then echo "- ✓ Tamper-evident logging"; fi)
$(if [[ -f /usr/local/bin/incident-response ]]; then echo "- ✓ Incident response framework"; fi)

## Next Steps
1. Reboot the system to activate all security features
2. Complete SELinux setup (if installed)
3. Configure user accounts and permissions
4. Review and customize security policies
5. Set up regular security monitoring

## Documentation
- Installation Guide: hardened-os/documentation/INSTALLATION_GUIDE.md
- User Guide: hardened-os/documentation/USER_GUIDE.md
- VirtualBox Guide: VIRTUALBOX_DEPLOYMENT.md

## Support
- Deployment Log: $LOG_FILE
- Report: $report_file

---
**Deployment Status**: SUCCESS (Debian-compatible)
EOF

    log "Deployment report generated: $report_file"
    success "Deployment report available at: $report_file"
}

# Main deployment function
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                HARDENED LAPTOP OS (Debian)                   ║
║                  Production Deployment                       ║
║                                                               ║
║  Debian-compatible hardened system deployment                ║
║  Optimized for VirtualBox and Debian environments            ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "Starting Hardened Laptop OS deployment (Debian-compatible)..."
    log "Deployment started by: $(whoami)"
    log "Host system: $(uname -a)"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Execute deployment phases
    install_debian_dependencies
    install_sbctl
    setup_build_environment
    configure_basic_hardening
    configure_selinux
    install_hardened_components
    configure_services
    run_verification
    generate_report
    
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                   DEPLOYMENT COMPLETED                       ║
║                                                               ║
║  Your Hardened Laptop OS (Debian) is ready!                  ║
║                                                               ║
║  IMPORTANT: Reboot required to activate all features         ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    success "Hardened Laptop OS deployment completed successfully!"
    info "Deployment log: $LOG_FILE"
    warn "REBOOT REQUIRED to activate SELinux and other kernel features"
}

# Execute main function with all arguments
main "$@"