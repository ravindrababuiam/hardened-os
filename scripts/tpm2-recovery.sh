#!/bin/bash
#
# TPM2 Recovery Script
# Handles TPM2 unsealing failures and recovery procedures
#
# Part of Task 5: Configure TPM2 measured boot and key sealing with recovery
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo "=== TPM2 Recovery Utility ==="
echo

# Check TPM2 status
check_tpm2_status() {
    log_step "Checking TPM2 status..."
    
    if ! command -v tpm2_getcap >/dev/null 2>&1; then
        log_error "TPM2 tools not available"
        return 1
    fi
    
    if ! tpm2_getcap properties-fixed >/dev/null 2>&1; then
        log_error "Cannot communicate with TPM2"
        return 1
    fi
    
    log_info "TPM2 communication OK"
    
    # Show TPM info
    local manufacturer=$(tpm2_getcap properties-fixed | grep TPM2_PT_MANUFACTURER | awk '{print $2}' || echo "Unknown")
    local firmware=$(tpm2_getcap properties-fixed | grep TPM2_PT_FIRMWARE_VERSION | awk '{print $2}' || echo "Unknown")
    
    log_info "Manufacturer: $manufacturer"
    log_info "Firmware: $firmware"
}

# Read current PCR values
read_pcr_values() {
    log_step "Reading current PCR values..."
    
    for pcr in 0 2 4 7; do
        local value=$(tpm2_pcrread sha256:$pcr 2>/dev/null | grep "sha256" | awk '{print $3}' || echo "error")
        echo "  PCR $pcr: $value"
    done
}

# Compare PCR values with baseline
compare_pcr_baseline() {
    log_step "Comparing PCR values with baseline..."
    
    local baseline_file="$HOME/harden/build/pcr_snapshot_latest.txt"
    
    if [ ! -f "$baseline_file" ]; then
        log_warn "No PCR baseline found"
        log_info "Create baseline with: tpm2_pcrread sha256:0,2,4,7 > $baseline_file"
        return 1
    fi
    
    local current_file="/tmp/current_pcrs.txt"
    tpm2_pcrread sha256:0,2,4,7 > "$current_file" 2>/dev/null
    
    if diff -q "$baseline_file" "$current_file" >/dev/null 2>&1; then
        log_info "✓ PCR values match baseline"
        rm -f "$current_file"
        return 0
    else
        log_warn "✗ PCR values differ from baseline"
        echo "Differences:"
        diff "$baseline_file" "$current_file" || true
        rm -f "$current_file"
        return 1
    fi
}

# Test LUKS unlocking
test_luks_unlock() {
    local device="$1"
    log_step "Testing LUKS unlock for: $device"
    
    if [ ! -e "$device" ]; then
        log_error "Device not found: $device"
        return 1
    fi
    
    # Try TPM2 unlock first
    if sudo systemd-cryptsetup attach test-tpm2 "$device" 2>/dev/null; then
        log_info "✓ TPM2 unlock successful"
        sudo systemd-cryptsetup detach test-tpm2 2>/dev/null || true
        return 0
    else
        log_warn "✗ TPM2 unlock failed"
        return 1
    fi
}

# Re-enroll TPM2 keyslot
reenroll_tpm2() {
    local device="$1"
    log_step "Re-enrolling TPM2 keyslot for: $device"
    
    if [ ! -e "$device" ]; then
        log_error "Device not found: $device"
        return 1
    fi
    
    # Show current keyslots
    log_info "Current LUKS keyslots:"
    sudo cryptsetup luksDump "$device" | grep -A 10 "Keyslots:"
    
    # Confirm removal
    log_warn "This will remove existing TPM2 keyslots"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove existing TPM2 keyslots
        sudo systemd-cryptenroll --wipe-slot=tpm2 "$device" 2>/dev/null || {
            log_warn "No TPM2 slots to remove"
        }
        
        # Add new TPM2 keyslot
        log_info "Adding new TPM2 keyslot..."
        if sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0,2,4,7 "$device"; then
            log_info "✓ TPM2 re-enrollment completed"
        else
            log_error "✗ TPM2 re-enrollment failed"
            return 1
        fi
    else
        log_info "Re-enrollment cancelled"
    fi
}

# Clear TPM2 (development only)
clear_tpm2() {
    log_step "Clearing TPM2 (DEVELOPMENT ONLY)"
    
    log_error "WARNING: This will clear ALL TPM2 data!"
    log_warn "All sealed keys will be lost!"
    read -p "Are you sure? Type 'YES' to continue: " confirm
    
    if [ "$confirm" = "YES" ]; then
        if sudo tpm2_clear -c platform; then
            log_info "✓ TPM2 cleared successfully"
            log_warn "Reboot required to complete TPM2 reset"
        else
            log_error "✗ TPM2 clear failed"
        fi
    else
        log_info "TPM2 clear cancelled"
    fi
}

# Show recovery help
show_recovery_help() {
    cat << 'EOF'

=== TPM2 Recovery Help ===

Common Recovery Scenarios:

1. **Boot fails to auto-unlock after system update:**
   - Kernel or bootloader update changed PCR values
   - Solution: Re-enroll TPM2 keyslot with new PCR values
   - Command: systemd-cryptenroll --wipe-slot=tpm2 /dev/sdXY && systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0,2,4,7 /dev/sdXY

2. **Hardware changes (motherboard, TPM replacement):**
   - TPM2 chip changed, sealed keys lost
   - Solution: Use passphrase to unlock, then re-enroll
   - May need to clear TPM2 first: tpm2_clear -c platform

3. **Suspected Evil Maid attack:**
   - PCR values changed unexpectedly
   - Solution: Investigate changes, restore from backup if needed
   - Check: Compare current PCRs with known good baseline

4. **TPM2 communication errors:**
   - Check TPM2 is enabled in BIOS/UEFI
   - Verify TPM2 tools installed: apt install tpm2-tools
   - Check device permissions: ls -l /dev/tpm*

5. **systemd-cryptenroll errors:**
   - Ensure systemd version supports TPM2
   - Check for conflicting keyslots
   - Try manual cryptsetup with TPM2 plugin

Recovery Commands:

- Check TPM2 status: tpm2_getcap properties-fixed
- Read PCRs: tpm2_pcrread sha256:0,2,4,7
- List LUKS keyslots: cryptsetup luksDump /dev/sdXY
- Test unlock: systemd-cryptsetup attach test /dev/sdXY
- Remove TPM2 keyslot: systemd-cryptenroll --wipe-slot=tpm2 /dev/sdXY
- Add TPM2 keyslot: systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0,2,4,7 /dev/sdXY

EOF
}

# Main recovery menu
main() {
    check_tpm2_status
    echo
    
    while true; do
        echo "TPM2 Recovery Options:"
        echo "1. Check PCR values"
        echo "2. Compare PCRs with baseline"
        echo "3. Test LUKS unlock"
        echo "4. Re-enroll TPM2 keyslot"
        echo "5. Clear TPM2 (DEVELOPMENT ONLY)"
        echo "6. Show recovery help"
        echo "7. Exit"
        echo
        
        read -p "Select option (1-7): " choice
        
        case $choice in
            1)
                read_pcr_values
                ;;
            2)
                compare_pcr_baseline
                ;;
            3)
                read -p "Enter LUKS device path: " device
                if [ -n "$device" ]; then
                    test_luks_unlock "$device"
                else
                    log_error "No device specified"
                fi
                ;;
            4)
                read -p "Enter LUKS device path: " device
                if [ -n "$device" ]; then
                    reenroll_tpm2 "$device"
                else
                    log_error "No device specified"
                fi
                ;;
            5)
                clear_tpm2
                ;;
            6)
                show_recovery_help
                ;;
            7)
                log_info "Exiting recovery utility"
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        echo
    done
}

main "$@"