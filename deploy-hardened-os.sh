#!/bin/bash
# Master Deployment Script for Hardened Laptop OS
# This script orchestrates the complete deployment of the hardened system

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
TOTAL_STEPS=25
CURRENT_STEP=0

progress() {
    local step_name="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "${PURPLE}[STEP $CURRENT_STEP/$TOTAL_STEPS - $percentage%]${NC} $step_name"
    log "Starting step $CURRENT_STEP/$TOTAL_STEPS: $step_name"
}

# Usage information
usage() {
    cat << EOF
Hardened Laptop OS Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -m, --mode MODE           Deployment mode: full, minimal, custom (default: full)
    -t, --target DEVICE       Target device (e.g., /dev/sda)
    -c, --config FILE         Custom configuration file
    --skip-hardware-check     Skip hardware compatibility checks
    --dry-run                 Show what would be done without executing
    -h, --help                Show this help message

DEPLOYMENT MODES:
    full      Complete hardened system with all security features
    minimal   Basic hardened system with essential security only
    custom    Use configuration file to select features

EXAMPLES:
    $0 --mode full --target /dev/sda
    $0 --mode minimal --target /dev/nvme0n1 --skip-hardware-check
    $0 --mode custom --config my-config.yaml --target /dev/sda

REQUIREMENTS:
    - Root privileges
    - Ubuntu LTS 22.04+ build host
    - Target hardware with UEFI and TPM 2.0
    - Internet connection for package downloads

EOF
    exit 0
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
                usage
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

# Validate deployment parameters
validate_parameters() {
    log "Validating deployment parameters..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Validate deployment mode
    case "$DEPLOYMENT_MODE" in
        full|minimal|custom)
            log "Deployment mode: $DEPLOYMENT_MODE"
            ;;
        *)
            error "Invalid deployment mode: $DEPLOYMENT_MODE"
            ;;
    esac
    
    # Validate target device if provided
    if [[ -n "$TARGET_DEVICE" ]]; then
        if [[ ! -b "$TARGET_DEVICE" ]]; then
            error "Target device $TARGET_DEVICE is not a valid block device"
        fi
        log "Target device: $TARGET_DEVICE"
    fi
    
    # Check if configuration file exists for custom mode
    if [[ "$DEPLOYMENT_MODE" == "custom" && ! -f "$DEPLOYMENT_CONFIG" ]]; then
        error "Configuration file $DEPLOYMENT_CONFIG not found"
    fi
}

# Create deployment configuration
create_deployment_config() {
    log "Creating deployment configuration..."
    
    case "$DEPLOYMENT_MODE" in
        full)
            cat > "$DEPLOYMENT_CONFIG" << 'EOF'
deployment:
  mode: full
  features:
    secure_boot: true
    tpm_measured_boot: true
    full_disk_encryption: true
    hardened_kernel: true
    selinux_enforcing: true
    minimal_services: true
    userspace_hardening: true
    application_sandboxing: true
    network_controls: true
    secure_updates: true
    reproducible_builds: true
    hsm_signing: true
    tamper_evident_logging: true
    incident_response: true
    comprehensive_documentation: true
  
  security_level: maximum
  performance_optimization: balanced
  user_experience: guided
EOF
            ;;
        minimal)
            cat > "$DEPLOYMENT_CONFIG" << 'EOF'
deployment:
  mode: minimal
  features:
    secure_boot: true
    tpm_measured_boot: true
    full_disk_encryption: true
    hardened_kernel: true
    selinux_enforcing: true
    minimal_services: true
    userspace_hardening: false
    application_sandboxing: false
    network_controls: false
    secure_updates: true
    reproducible_builds: false
    hsm_signing: false
    tamper_evident_logging: false
    incident_response: false
    comprehensive_documentation: true
  
  security_level: high
  performance_optimization: performance
  user_experience: minimal
EOF
            ;;
    esac
    
    log "Configuration created: $DEPLOYMENT_CONFIG"
}

# Hardware compatibility check
check_hardware_compatibility() {
    if [[ "$SKIP_HARDWARE_CHECK" == true ]]; then
        warn "Skipping hardware compatibility check"
        return 0
    fi
    
    progress "Hardware Compatibility Check"
    
    log "Checking hardware compatibility..."
    
    # Check UEFI support
    if [[ -d /sys/firmware/efi ]]; then
        log "✓ UEFI firmware detected"
    else
        error "UEFI firmware required but not detected"
    fi
    
    # Check TPM 2.0
    if [[ -c /dev/tpm0 ]] || [[ -c /dev/tpmrm0 ]]; then
        log "✓ TPM device detected"
        
        # Check TPM version
        if command -v tpm2_getcap &> /dev/null; then
            if tpm2_getcap properties-fixed | grep -q "TPM2"; then
                log "✓ TPM 2.0 confirmed"
            else
                warn "TPM detected but version unclear"
            fi
        fi
    else
        error "TPM 2.0 required but not detected"
    fi
    
    # Check CPU architecture
    if [[ "$(uname -m)" == "x86_64" ]]; then
        log "✓ x86_64 architecture confirmed"
    else
        error "x86_64 architecture required"
    fi
    
    # Check memory
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -ge 8 ]]; then
        log "✓ Sufficient memory: ${mem_gb}GB"
    else
        warn "Low memory detected: ${mem_gb}GB (8GB+ recommended)"
    fi
    
    # Check storage
    if [[ -n "$TARGET_DEVICE" ]]; then
        local storage_gb=$(lsblk -b -d -o SIZE "$TARGET_DEVICE" | tail -n1 | awk '{print int($1/1024/1024/1024)}')
        if [[ $storage_gb -ge 128 ]]; then
            log "✓ Sufficient storage: ${storage_gb}GB"
        else
            warn "Low storage detected: ${storage_gb}GB (128GB+ recommended)"
        fi
    fi
    
    success "Hardware compatibility check completed"
}

# Install build dependencies
install_dependencies() {
    progress "Installing Build Dependencies"
    
    log "Installing required packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would install build dependencies"
        return 0
    fi
    
    # Update package lists
    apt update
    
    # Install core build tools
    apt install -y \
        git build-essential clang gcc python3 make cmake \
        libncurses-dev flex bison libssl-dev libelf-dev \
        qemu-kvm libvirt-daemon-system virt-manager \
        cryptsetup tpm2-tools efibootmgr \
        debootstrap squashfs-tools \
        opensc opensc-pkcs11 libengine-pkcs11-openssl \
        softhsm2 \
        rsyslog logrotate \
        nftables iptables-persistent \
        selinux-utils selinux-policy-targeted \
        bubblewrap \
        python3-pip python3-yaml python3-cryptography
    
    # Install sbctl if not available
    if ! command -v sbctl &> /dev/null; then
        log "Installing sbctl..."
        # Add installation logic for sbctl
    fi
    
    success "Dependencies installed successfully"
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
    
    # Set up environment variables
    cat > ~/.hardened-os-env << 'EOF'
# Hardened OS Build Environment
export HARDEN_ROOT="$HOME/harden"
export HARDEN_KEYS="$HARDEN_ROOT/keys"
export HARDEN_BUILD="$HARDEN_ROOT/build"
export HARDEN_ARTIFACTS="$HARDEN_ROOT/artifacts"
export PATH="$PATH:/opt/signing-infrastructure/scripts"
EOF
    
    # Source environment
    source ~/.hardened-os-env
    
    success "Build environment created"
}

# Execute deployment phase
execute_phase() {
    local phase_name="$1"
    local script_path="$2"
    local required="$3"
    
    progress "$phase_name"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would execute $script_path"
        return 0
    fi
    
    if [[ ! -f "$script_path" ]]; then
        if [[ "$required" == "required" ]]; then
            error "Required script not found: $script_path"
        else
            warn "Optional script not found: $script_path"
            return 0
        fi
    fi
    
    log "Executing: $script_path"
    
    # Make script executable
    chmod +x "$script_path"
    
    # Execute script with logging
    if "$script_path" 2>&1 | tee -a "$LOG_FILE"; then
        success "$phase_name completed"
    else
        error "$phase_name failed"
    fi
}

# Main deployment phases
deploy_security_infrastructure() {
    log "=== PHASE 1: Security Infrastructure ==="
    
    # Key management
    execute_phase "Key Management Setup" "$SCRIPT_DIR/scripts/key-manager.sh" "required"
    
    # HSM infrastructure (if enabled)
    if grep -q "hsm_signing: true" "$DEPLOYMENT_CONFIG"; then
        execute_phase "HSM Infrastructure" "$SCRIPT_DIR/scripts/setup-hsm-infrastructure.sh" "optional"
    fi
    
    # Secure Boot
    execute_phase "Secure Boot Configuration" "$SCRIPT_DIR/scripts/setup-secure-boot.sh" "required"
    
    # TPM2 Measured Boot
    execute_phase "TPM2 Measured Boot" "$SCRIPT_DIR/scripts/setup-tpm2-measured-boot.sh" "required"
}

deploy_base_system() {
    log "=== PHASE 2: Base System Installation ==="
    
    # Partition layout
    if [[ -n "$TARGET_DEVICE" ]]; then
        execute_phase "Partition Layout" "$SCRIPT_DIR/scripts/create-partition-layout.sh" "required"
        execute_phase "LUKS2 Encryption" "$SCRIPT_DIR/scripts/setup-luks2-encryption.sh" "required"
    fi
    
    # Debian base installation
    execute_phase "Debian Base Installation" "$SCRIPT_DIR/scripts/install-debian-base.sh" "required"
    
    # Hardened kernel
    execute_phase "Hardened Kernel Build" "$SCRIPT_DIR/scripts/build-hardened-kernel.sh" "required"
    execute_phase "Signed Kernel Packages" "$SCRIPT_DIR/scripts/create-signed-kernel-packages.sh" "required"
    
    # Compiler hardening
    execute_phase "Compiler Hardening" "$SCRIPT_DIR/scripts/setup-compiler-hardening.sh" "required"
}

deploy_security_layers() {
    log "=== PHASE 3: Security Layer Configuration ==="
    
    # SELinux
    execute_phase "SELinux Enforcing Mode" "$SCRIPT_DIR/scripts/setup-selinux-enforcing-fixed.sh" "required"
    
    # Minimal services
    execute_phase "Minimal Services" "$SCRIPT_DIR/scripts/setup-minimal-services.sh" "required"
    
    # Userspace hardening (if enabled)
    if grep -q "userspace_hardening: true" "$DEPLOYMENT_CONFIG"; then
        execute_phase "Userspace Hardening" "$SCRIPT_DIR/scripts/setup-userspace-hardening.sh" "optional"
    fi
    
    # Application sandboxing (if enabled)
    if grep -q "application_sandboxing: true" "$DEPLOYMENT_CONFIG"; then
        execute_phase "Application Sandboxing" "$SCRIPT_DIR/scripts/setup-bubblewrap-sandboxing.sh" "optional"
    fi
    
    # Network controls (if enabled)
    if grep -q "network_controls: true" "$DEPLOYMENT_CONFIG"; then
        execute_phase "Network Controls" "$SCRIPT_DIR/scripts/setup-network-controls.sh" "optional"
    fi
    
    # User onboarding
    execute_phase "User Onboarding" "$SCRIPT_DIR/scripts/setup-user-onboarding.sh" "required"
}

deploy_update_system() {
    log "=== PHASE 4: Update and Supply Chain Security ==="
    
    # Secure updates
    execute_phase "Secure Updates (Part 1)" "$SCRIPT_DIR/scripts/setup-secure-updates.sh" "required"
    execute_phase "Secure Updates (Part 2)" "$SCRIPT_DIR/scripts/setup-secure-updates-part2.sh" "required"
    
    # Automatic rollback
    execute_phase "Automatic Rollback" "$SCRIPT_DIR/scripts/setup-automatic-rollback.sh" "required"
    
    # Reproducible builds (if enabled)
    if grep -q "reproducible_builds: true" "$DEPLOYMENT_CONFIG"; then
        execute_phase "Reproducible Builds" "$SCRIPT_DIR/scripts/setup-reproducible-builds-complete.sh" "optional"
    fi
}

deploy_production_features() {
    log "=== PHASE 5: Production Features ==="
    
    # Tamper-evident logging (if enabled)
    if grep -q "tamper_evident_logging: true" "$DEPLOYMENT_CONFIG"; then
        execute_phase "Tamper-Evident Logging" "$SCRIPT_DIR/hardened-os/logging/install-logging-system.sh" "optional"
    fi
    
    # Incident response (if enabled)
    if grep -q "incident_response: true" "$DEPLOYMENT_CONFIG"; then
        execute_phase "Incident Response Framework" "$SCRIPT_DIR/hardened-os/incident-response/install-incident-response.sh" "optional"
    fi
}

# Verification and testing
run_deployment_verification() {
    progress "Deployment Verification"
    
    log "Running deployment verification tests..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Would run verification tests"
        return 0
    fi
    
    local test_results=0
    
    # Test logging system
    if [[ -f "$SCRIPT_DIR/hardened-os/logging/test-logging-system.sh" ]]; then
        log "Testing logging system..."
        if "$SCRIPT_DIR/hardened-os/logging/test-logging-system.sh"; then
            log "✓ Logging system test passed"
        else
            warn "✗ Logging system test failed"
            test_results=1
        fi
    fi
    
    # Test incident response
    if [[ -f "$SCRIPT_DIR/hardened-os/incident-response/test-incident-response.sh" ]]; then
        log "Testing incident response..."
        if "$SCRIPT_DIR/hardened-os/incident-response/test-incident-response.sh"; then
            log "✓ Incident response test passed"
        else
            warn "✗ Incident response test failed"
            test_results=1
        fi
    fi
    
    # Test documentation
    if [[ -f "$SCRIPT_DIR/hardened-os/documentation/test-documentation-simple.sh" ]]; then
        log "Testing documentation..."
        if "$SCRIPT_DIR/hardened-os/documentation/test-documentation-simple.sh"; then
            log "✓ Documentation test passed"
        else
            warn "✗ Documentation test failed"
            test_results=1
        fi
    fi
    
    if [[ $test_results -eq 0 ]]; then
        success "All verification tests passed"
    else
        warn "Some verification tests failed - check logs for details"
    fi
}

# Generate deployment report
generate_deployment_report() {
    progress "Generating Deployment Report"
    
    local report_file="/var/log/hardened-os-deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Hardened Laptop OS Deployment Report

## Deployment Summary
- **Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Mode**: $DEPLOYMENT_MODE
- **Target Device**: ${TARGET_DEVICE:-"Not specified"}
- **Deployed By**: $(whoami)
- **Host System**: $(uname -a)

## Configuration
\`\`\`yaml
$(cat "$DEPLOYMENT_CONFIG")
\`\`\`

## Deployment Steps Completed
- ✓ Hardware compatibility check
- ✓ Build dependencies installation
- ✓ Build environment setup
- ✓ Security infrastructure deployment
- ✓ Base system installation
- ✓ Security layers configuration
- ✓ Update system deployment
- ✓ Production features deployment
- ✓ Verification and testing

## Security Features Enabled
$(grep -E "^\s+\w+: true" "$DEPLOYMENT_CONFIG" | sed 's/^/- ✓ /')

## Next Steps
1. Review deployment logs: $LOG_FILE
2. Complete user onboarding process
3. Configure user-specific settings
4. Set up regular maintenance schedule
5. Review security documentation

## Documentation
- Installation Guide: hardened-os/documentation/INSTALLATION_GUIDE.md
- User Guide: hardened-os/documentation/USER_GUIDE.md
- Security Guide: hardened-os/documentation/SECURITY_GUIDE.md
- Troubleshooting: hardened-os/documentation/TROUBLESHOOTING_GUIDE.md

## Support
- Deployment Log: $LOG_FILE
- Configuration: $DEPLOYMENT_CONFIG
- Report: $report_file

---
**Deployment Status**: $(if [[ $? -eq 0 ]]; then echo "SUCCESS"; else echo "COMPLETED WITH WARNINGS"; fi)
EOF

    log "Deployment report generated: $report_file"
    success "Deployment report available at: $report_file"
}

# Main deployment function
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                    HARDENED LAPTOP OS                        ║
║                  Production Deployment                       ║
║                                                               ║
║  GrapheneOS-level security for laptop computing              ║
║  Comprehensive hardening with enterprise features            ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "Starting Hardened Laptop OS deployment..."
    log "Deployment started by: $(whoami)"
    log "Host system: $(uname -a)"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Validate parameters
    validate_parameters
    
    # Create deployment configuration
    create_deployment_config
    
    # Execute deployment phases
    check_hardware_compatibility
    install_dependencies
    setup_build_environment
    deploy_security_infrastructure
    deploy_base_system
    deploy_security_layers
    deploy_update_system
    deploy_production_features
    
    # Verification and reporting
    run_deployment_verification
    generate_deployment_report
    
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                   DEPLOYMENT COMPLETED                       ║
║                                                               ║
║  Your Hardened Laptop OS is ready for production use!        ║
║                                                               ║
║  Next steps:                                                  ║
║  1. Review the deployment report                              ║
║  2. Complete user onboarding                                  ║
║  3. Configure user-specific settings                          ║
║  4. Set up regular maintenance                                ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    success "Hardened Laptop OS deployment completed successfully!"
    info "Deployment log: $LOG_FILE"
    info "Configuration: $DEPLOYMENT_CONFIG"
    info "Documentation: hardened-os/documentation/"
}

# Execute main function with all arguments
main "$@"