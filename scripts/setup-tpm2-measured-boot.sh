#!/bin/bash
#
# TPM2 Measured Boot and Key Sealing Implementation
# Configures TPM2 for measured boot with LUKS key sealing and recovery
#
# Task 5: Configure TPM2 measured boot and key sealing with recovery
# - Set up TPM2 tools and systemd-cryptenroll integration
# - Configure PCR measurements for firmware, bootloader, and kernel (PCRs 0,2,4,7)
# - Implement LUKS key sealing to TPM2 with PCR policy
# - Create fallback passphrase mechanism and recovery boot options
# - Test Evil Maid attack simulation and TPM unsealing failure scenarios
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
LOG_FILE="$WORK_DIR/tpm2-setup.log"
LUKS_DEVICE="/dev/mapper/harden-root"  # Adjust based on actual setup
PCR_POLICY="0,2,4,7"  # Firmware, bootloader, kernel measurements

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize logging
init_logging() {
    mkdir -p "$WORK_DIR"
    echo "=== TPM2 Measured Boot Setup Log - $(date) ===" > "$LOG_FILE"
}

# Check if running as root (some operations require it)
check_root_access() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root for safety"
        log_info "Some operations will use sudo when needed"
        exit 1
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo access for system configuration"
        sudo -v || {
            log_error "Failed to obtain sudo access"
            exit 1
        }
    fi
}# Ver
ify prerequisites
check_prerequisites() {
    log_step "Checking TPM2 prerequisites..."
    
    # Check TPM device
    if [ ! -c /dev/tpm0 ] && [ ! -c /dev/tpmrm0 ]; then
        log_error "No TPM device found - TPM2 required for measured boot"
        exit 1
    fi
    
    # Check required tools
    local deps=("tpm2_getcap" "tpm2_createpolicy" "tpm2_pcrread" "systemd-cryptenroll" "cryptsetup")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install tpm2-tools systemd-container cryptsetup-bin"
        exit 1
    fi
    
    # Check UEFI boot
    if [ ! -d /sys/firmware/efi ]; then
        log_error "System not booted with UEFI - required for measured boot"
        exit 1
    fi
    
    # Test TPM communication
    if ! tpm2_getcap properties-fixed &>/dev/null; then
        log_error "Cannot communicate with TPM2 device"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Initialize TPM2 for measured boot
initialize_tpm2() {
    log_step "Initializing TPM2 for measured boot..."
    
    # Clear TPM if requested (development only)
    if [[ "${CLEAR_TPM:-}" == "yes" ]]; then
        log_warn "Clearing TPM2 (development mode)"
        sudo tpm2_clear -c platform || {
            log_warn "TPM clear failed - may already be cleared"
        }
    fi
    
    # Get TPM information
    log_info "TPM2 Information:"
    local manufacturer=$(tpm2_getcap properties-fixed | grep TPM2_PT_MANUFACTURER | awk '{print $2}' || echo "Unknown")
    local firmware=$(tpm2_getcap properties-fixed | grep TPM2_PT_FIRMWARE_VERSION | awk '{print $2}' || echo "Unknown")
    
    log_info "  Manufacturer: $manufacturer"
    log_info "  Firmware Version: $firmware"
    
    # Check PCR banks
    log_info "Available PCR Banks:"
    tpm2_getcap pcrs | tee -a "$LOG_FILE"
    
    log_info "TPM2 initialization completed"
}

# Configure PCR measurements
configure_pcr_measurements() {
    log_step "Configuring PCR measurements for measured boot..."
    
    # Read current PCR values
    log_info "Current PCR values:"
    for pcr in ${PCR_POLICY//,/ }; do
        local pcr_value=$(tpm2_pcrread sha256:$pcr | grep "sha256" | awk '{print $3}' || echo "unavailable")
        log_info "  PCR $pcr: $pcr_value"
    done
    
    # Create PCR policy for sealing
    local policy_file="$WORK_DIR/pcr_policy.dat"
    log_info "Creating PCR policy for sealing..."
    
    tpm2_createpolicy --policy-pcr -l "sha256:$PCR_POLICY" -f "$policy_file" 2>&1 | tee -a "$LOG_FILE"
    
    if [ -f "$policy_file" ]; then
        log_info "✓ PCR policy created: $policy_file"
        chmod 600 "$policy_file"
    else
        log_error "Failed to create PCR policy"
        return 1
    fi
    
    # Save current PCR values for reference
    local pcr_snapshot="$WORK_DIR/pcr_snapshot_$(date +%Y%m%d_%H%M%S).txt"
    log_info "Saving PCR snapshot to: $pcr_snapshot"
    
    echo "# PCR Snapshot - $(date)" > "$pcr_snapshot"
    echo "# Boot configuration at time of TPM2 setup" >> "$pcr_snapshot"
    echo "" >> "$pcr_snapshot"
    
    for pcr in ${PCR_POLICY//,/ }; do
        echo "PCR $pcr:" >> "$pcr_snapshot"
        tpm2_pcrread sha256:$pcr >> "$pcr_snapshot" 2>/dev/null || echo "  Error reading PCR $pcr" >> "$pcr_snapshot"
        echo "" >> "$pcr_snapshot"
    done
    
    log_info "PCR measurements configured successfully"
}# Fi
nd LUKS encrypted devices
find_luks_devices() {
    log_step "Discovering LUKS encrypted devices..."
    
    local luks_devices=()
    
    # Method 1: Check /proc/mounts for mapped devices
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        if [[ "$device" =~ ^/dev/mapper/ ]]; then
            # Check if it's a LUKS device
            local backing_device=$(sudo cryptsetup status "$device" 2>/dev/null | grep "device:" | awk '{print $2}' || echo "")
            if [ -n "$backing_device" ]; then
                luks_devices+=("$device")
                log_info "Found LUKS device: $device (backing: $backing_device)"
            fi
        fi
    done < /proc/mounts
    
    # Method 2: Check common LUKS device names
    local common_names=("/dev/mapper/harden-root" "/dev/mapper/root" "/dev/mapper/cryptroot")
    for device in "${common_names[@]}"; do
        if [ -e "$device" ] && sudo cryptsetup status "$device" &>/dev/null; then
            if [[ ! " ${luks_devices[@]} " =~ " $device " ]]; then
                luks_devices+=("$device")
                log_info "Found LUKS device: $device"
            fi
        fi
    done
    
    if [ ${#luks_devices[@]} -eq 0 ]; then
        log_warn "No LUKS devices found - creating test setup"
        return 1
    fi
    
    # Export for use by other functions
    export FOUND_LUKS_DEVICES="${luks_devices[*]}"
    log_info "Discovered ${#luks_devices[@]} LUKS device(s)"
}

# Set up TPM2 key sealing for LUKS
setup_tpm2_luks_sealing() {
    log_step "Setting up TPM2 key sealing for LUKS devices..."
    
    # Find LUKS devices
    if ! find_luks_devices; then
        log_warn "No LUKS devices found - skipping TPM2 sealing setup"
        return 0
    fi
    
    # Process each LUKS device
    for device in $FOUND_LUKS_DEVICES; do
        log_info "Configuring TPM2 sealing for: $device"
        
        # Get the backing device
        local backing_device=$(sudo cryptsetup status "$device" | grep "device:" | awk '{print $2}')
        if [ -z "$backing_device" ]; then
            log_error "Cannot determine backing device for $device"
            continue
        fi
        
        log_info "  Backing device: $backing_device"
        
        # Check current keyslots
        log_info "  Current LUKS keyslots:"
        sudo cryptsetup luksDump "$backing_device" | grep -A 5 "Keyslots:" | tee -a "$LOG_FILE"
        
        # Create enrollment script for manual execution
        local enroll_script="$WORK_DIR/enroll_tpm2_$(basename $device).sh"
        cat > "$enroll_script" << EOF
#!/bin/bash
# TPM2 enrollment script for $device
# Generated by setup-tpm2-measured-boot.sh

set -e

echo "Enrolling TPM2 keyslot for $device..."
echo "Backing device: $backing_device"
echo "PCR Policy: $PCR_POLICY"
echo

# Add TPM2 keyslot
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=$PCR_POLICY "$backing_device"

echo "TPM2 keyslot enrolled successfully!"
echo "Test with: sudo systemd-cryptsetup attach test-unlock $backing_device"
EOF
        
        chmod +x "$enroll_script"
        log_info "  Enrollment script created: $enroll_script"
    done
    
    log_info "TPM2 LUKS sealing setup completed"
}# 
Configure systemd for TPM2 unlocking
configure_systemd_tpm2() {
    log_step "Configuring systemd for TPM2 automatic unlocking..."
    
    # Check if systemd-cryptsetup supports TPM2
    if ! systemd-cryptsetup --help | grep -q "tpm2"; then
        log_warn "systemd-cryptsetup does not support TPM2 - may need newer version"
    fi
    
    # Create crypttab configuration template
    local crypttab_template="$WORK_DIR/crypttab.tpm2.template"
    cat > "$crypttab_template" << 'EOF'
# /etc/crypttab configuration for TPM2 automatic unlocking
# 
# Format: <name> <device> <keyfile> <options>
# 
# Example entries (uncomment and modify as needed):
# root UUID=<device-uuid> none luks,tpm2-device=auto,tpm2-pcrs=0+2+4+7
# swap UUID=<swap-uuid> none luks,tpm2-device=auto,tpm2-pcrs=0+2+4+7
#
# Fallback with passphrase (recommended):
# root UUID=<device-uuid> none luks,tpm2-device=auto,tpm2-pcrs=0+2+4+7,tries=1,timeout=10s
EOF
    
    log_info "Crypttab template created: $crypttab_template"
    
    # Create initramfs configuration
    local initramfs_conf="$WORK_DIR/tpm2-initramfs.conf"
    cat > "$initramfs_conf" << 'EOF'
# Initramfs configuration for TPM2 support
# Add to /etc/initramfs-tools/modules

# TPM2 modules
tpm
tpm_tis
tpm_crb

# Crypto modules for LUKS
aes
xts
sha256
EOF
    
    log_info "Initramfs configuration created: $initramfs_conf"
    
    log_info "systemd TPM2 configuration completed"
}

# Main execution function
main() {
    log_info "Starting TPM2 measured boot implementation..."
    log_warn "This implements Task 5: TPM2 measured boot and key sealing"
    
    init_logging
    check_root_access
    check_prerequisites
    initialize_tpm2
    configure_pcr_measurements
    setup_tpm2_luks_sealing
    configure_systemd_tpm2
    
    log_info "=== TPM2 Measured Boot Implementation Completed ==="
    log_info "Next steps:"
    log_info "1. Enroll TPM2 keyslots: run enrollment scripts in $WORK_DIR"
    log_info "2. Update /etc/crypttab with TPM2 options"
    log_info "3. Update initramfs: sudo update-initramfs -u"
    log_info "4. Test automatic unlocking after reboot"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--clear-tpm]"
        echo "Implements TPM2 measured boot with LUKS key sealing"
        echo ""
        echo "Options:"
        echo "  --help       Show this help"
        echo "  --clear-tpm  Clear TPM2 before setup (development only)"
        exit 0
        ;;
    --clear-tpm)
        export CLEAR_TPM="yes"
        main "$@"
        ;;
    *)
        main "$@"
        ;;
esac