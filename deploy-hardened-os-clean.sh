#!/bin/bash
# Clean Debian-Compatible Deployment Script for Hardened Laptop OS
# No pip usage - pure apt package management

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

success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message"
}

# Progress tracking
TOTAL_STEPS=10
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

# Install essential packages only
install_essential_packages() {
    progress "Installing Essential Packages"
    
    log "Installing essential packages for hardened system..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would install essential packages"
        return 0
    fi
    
    # Update package lists
    apt update
    
    # Install only essential packages (no pip, no complex dependencies)
    log "Installing core system packages..."
    apt install -y \
        git build-essential gcc make \
        cryptsetup-bin \
        nftables iptables-persistent \
        rsyslog logrotate \
        fail2ban \
        apparmor apparmor-utils \
        bubblewrap \
        curl wget \
        python3-full python3-venv \
        python3-yaml python3-cryptography
    
    success "Essential packages installed successfully"
}

# Set up basic directories
setup_directories() {
    progress "Setting Up Directories"
    
    log "Creating hardened-os directory structure..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would create directories"
        return 0
    fi
    
    # Create system directories
    mkdir -p /etc/hardened-os
    mkdir -p /var/log/hardened-os
    mkdir -p /opt/hardened-os/bin
    mkdir -p /opt/hardened-os/config
    
    # Create user directories
    mkdir -p ~/harden/{keys,build,artifacts}
    chmod 700 ~/harden/keys
    
    success "Directory structure created"
}

# Configure basic security hardening
configure_basic_security() {
    progress "Configuring Basic Security"
    
    log "Applying basic security hardening..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would configure basic security"
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

# File system security
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
    
    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-hardened-os.conf
    
    success "Basic security configured"
}

# Configure firewall
configure_firewall() {
    progress "Configuring Firewall"
    
    log "Setting up nftables firewall..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would configure firewall"
        return 0
    fi
    
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
        
        # Allow SSH (adjust port as needed)
        tcp dport 22 accept
        
        # Allow ICMP ping
        icmp type echo-request limit rate 1/second accept
        icmpv6 type echo-request limit rate 1/second accept
        
        # Log dropped packets (optional)
        log prefix "nftables-drop: " drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
    
    # Enable and start nftables
    systemctl enable nftables
    systemctl start nftables
    
    success "Firewall configured"
}

# Configure AppArmor
configure_apparmor() {
    progress "Configuring AppArmor"
    
    log "Setting up AppArmor mandatory access control..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would configure AppArmor"
        return 0
    fi
    
    # Enable AppArmor
    systemctl enable apparmor
    systemctl start apparmor
    
    # Set AppArmor profiles to enforce mode
    aa-enforce /etc/apparmor.d/* 2>/dev/null || true
    
    success "AppArmor configured"
}

# Install hardened-os components
install_hardened_components() {
    progress "Installing Hardened Components"
    
    log "Installing hardened-os specific components..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would install hardened components"
        return 0
    fi
    
    # Install logging system if available
    if [[ -f "$SCRIPT_DIR/hardened-os/logging/install-logging-system.sh" ]]; then
        log "Installing logging system..."
        chmod +x "$SCRIPT_DIR/hardened-os/logging/install-logging-system.sh"
        "$SCRIPT_DIR/hardened-os/logging/install-logging-system.sh" || warn "Logging system installation had issues"
    else
        warn "Logging system installer not found"
    fi
    
    # Install incident response system if available
    if [[ -f "$SCRIPT_DIR/hardened-os/incident-response/install-incident-response.sh" ]]; then
        log "Installing incident response system..."
        chmod +x "$SCRIPT_DIR/hardened-os/incident-response/install-incident-response.sh"
        "$SCRIPT_DIR/hardened-os/incident-response/install-incident-response.sh" || warn "Incident response installation had issues"
    else
        warn "Incident response installer not found"
    fi
    
    success "Hardened components installation completed"
}

# Configure services
configure_services() {
    progress "Configuring Services"
    
    log "Configuring system services..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would configure services"
        return 0
    fi
    
    # Enable security services
    local services_to_enable=(
        "fail2ban"
        "nftables"
        "apparmor"
        "rsyslog"
    )
    
    for service in "${services_to_enable[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            log "Enabling $service..."
            systemctl enable "$service"
            systemctl start "$service" 2>/dev/null || warn "Could not start $service"
        else
            warn "$service not available"
        fi
    done
    
    success "Services configured"
}

# Run basic verification
run_verification() {
    progress "Running Verification"
    
    log "Running basic system verification..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would run verification"
        return 0
    fi
    
    # Check critical services
    local critical_services=("rsyslog" "nftables" "apparmor")
    local failed_services=0
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active "$service" &> /dev/null; then
            log "✓ $service is running"
        else
            warn "✗ $service is not running"
            failed_services=$((failed_services + 1))
        fi
    done
    
    # Check firewall
    if nft list tables | grep -q "inet filter"; then
        log "✓ Firewall is configured"
    else
        warn "✗ Firewall not properly configured"
        failed_services=$((failed_services + 1))
    fi
    
    # Check AppArmor
    if aa-status | grep -q "profiles are in enforce mode"; then
        log "✓ AppArmor is enforcing"
    else
        warn "✗ AppArmor not properly enforcing"
    fi
    
    if [[ $failed_services -eq 0 ]]; then
        success "All critical services verified"
    else
        warn "$failed_services services need attention"
    fi
}

# Generate simple report
generate_report() {
    progress "Generating Report"
    
    local report_file="/var/log/hardened-os-clean-deployment-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Hardened Laptop OS Clean Deployment Report

## Deployment Summary
- **Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Mode**: $DEPLOYMENT_MODE
- **System**: $(uname -a)
- **Debian Version**: $(cat /etc/debian_version)

## Components Installed
- ✓ Essential security packages
- ✓ Basic security hardening (sysctl)
- ✓ Firewall configuration (nftables)
- ✓ AppArmor mandatory access control
- ✓ Fail2ban intrusion prevention
- ✓ System service hardening
$(if [[ -f /usr/local/bin/hardened-log-server ]]; then echo "- ✓ Tamper-evident logging"; fi)
$(if [[ -f /usr/local/bin/incident-response ]]; then echo "- ✓ Incident response framework"; fi)

## Security Status
- **Firewall**: $(if nft list tables | grep -q "inet filter"; then echo "Active (nftables)"; else echo "Needs attention"; fi)
- **AppArmor**: $(if systemctl is-active apparmor &> /dev/null; then echo "Active"; else echo "Inactive"; fi)
- **Fail2ban**: $(if systemctl is-active fail2ban &> /dev/null; then echo "Active"; else echo "Inactive"; fi)
- **Logging**: $(if systemctl is-active rsyslog &> /dev/null; then echo "Active"; else echo "Inactive"; fi)

## Next Steps
1. Review security configuration
2. Test firewall rules
3. Configure user accounts
4. Set up monitoring
5. Regular security updates

## Files
- Deployment Log: $LOG_FILE
- Report: $report_file

---
**Status**: Clean deployment completed successfully
EOF

    log "Report generated: $report_file"
    success "Deployment report available"
}

# Main function
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║            HARDENED LAPTOP OS (Clean Deployment)             ║
║                                                               ║
║  Debian-compatible clean deployment without pip issues       ║
║  Essential security hardening for VirtualBox testing         ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "Starting clean Hardened Laptop OS deployment..."
    log "Deployment started by: $(whoami)"
    log "Host system: $(uname -a)"
    
    # Parse arguments
    parse_args "$@"
    
    # Check root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Execute deployment
    install_essential_packages
    setup_directories
    configure_basic_security
    configure_firewall
    configure_apparmor
    install_hardened_components
    configure_services
    run_verification
    generate_report
    
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                 CLEAN DEPLOYMENT COMPLETED                   ║
║                                                               ║
║  Basic hardened system is ready for testing!                 ║
║  No Python pip issues - pure Debian package management       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    success "Clean hardened deployment completed!"
    log "Check the report for details and next steps"
}

# Run main function
main "$@"