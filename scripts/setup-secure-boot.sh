#!/bin/bash
#
# UEFI Secure Boot Implementation Script
# Implements custom key enrollment and bootloader signing for hardened OS
#
# Task 4: Implement UEFI Secure Boot with custom keys
# - Install and configure sbctl for Secure Boot management
# - Enroll custom Platform Keys, KEK, and DB keys in UEFI firmware
# - Sign shim bootloader, GRUB2, and recovery kernel with custom keys
# - Test Secure Boot enforcement and unauthorized kernel rejection
#

set -euo pipefail

# Configuration
KEYS_DIR="$HOME/harden/keys"
WORK_DIR="$HOME/harden/build"
LOG_FILE="$WORK_DIR/secure-boot-setup.log"

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
    echo "=== Secure Boot Setup Log - $(date) ===" > "$LOG_FILE"
}

# Check if running as root (required for some operations)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root for safety"
        log_info "Some operations will use sudo when needed"
        exit 1
    fi
}

# Verify prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check UEFI boot
    if [ ! -d /sys/firmware/efi ]; then
        log_error "System not booted with UEFI - Secure Boot requires UEFI"
        exit 1
    fi
    
    # Check EFI variables access
    if [ ! -d /sys/firmware/efi/efivars ]; then
        log_warn "EFI variables not accessible, attempting to mount..."
        sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars || {
            log_error "Failed to mount efivarfs"
            exit 1
        }
    fi
    
    # Check required tools
    local deps=("sbctl" "efibootmgr" "openssl" "mokutil")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install missing tools and run again"
        exit 1
    fi
    
    # Check for development keys
    if [ ! -f "$KEYS_DIR/dev/PK/PK.key" ]; then
        log_error "Development keys not found at $KEYS_DIR/dev/"
        log_info "Run scripts/generate-dev-keys.sh first"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Configure sbctl with custom keys
configure_sbctl() {
    log_step "Configuring sbctl for custom key management..."
    
    # Initialize sbctl if not already done
    if [ ! -d ~/.local/share/sbctl ]; then
        log_info "Initializing sbctl..."
        sbctl create-keys
    fi
    
    # Check sbctl status
    log_info "Current sbctl status:"
    sbctl status | tee -a "$LOG_FILE"
    
    # Backup existing sbctl keys if they exist
    if [ -d ~/.local/share/sbctl/keys ]; then
        local backup_dir="$WORK_DIR/sbctl_backup_$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up existing sbctl keys to $backup_dir"
        cp -r ~/.local/share/sbctl/keys "$backup_dir"
    fi
    
    log_info "sbctl configured successfully"
}

# Prepare custom keys for enrollment
prepare_custom_keys() {
    log_step "Preparing custom keys for UEFI enrollment..."
    
    local uefi_keys_dir="$WORK_DIR/uefi_keys"
    mkdir -p "$uefi_keys_dir"
    
    # Copy development keys to working directory
    cp "$KEYS_DIR/dev/PK/PK.auth" "$uefi_keys_dir/"
    cp "$KEYS_DIR/dev/KEK/KEK.auth" "$uefi_keys_dir/"
    cp "$KEYS_DIR/dev/DB/DB.auth" "$uefi_keys_dir/"
    
    # Also copy certificates for verification
    cp "$KEYS_DIR/dev/PK/PK.crt" "$uefi_keys_dir/"
    cp "$KEYS_DIR/dev/KEK/KEK.crt" "$uefi_keys_dir/"
    cp "$KEYS_DIR/dev/DB/DB.crt" "$uefi_keys_dir/"
    
    # Verify key files
    for key_type in PK KEK DB; do
        if [ ! -f "$uefi_keys_dir/${key_type}.auth" ]; then
            log_error "Missing ${key_type}.auth file"
            exit 1
        fi
        log_info "✓ ${key_type} key prepared"
    done
    
    log_info "Custom keys prepared for enrollment"
}

# Check current Secure Boot state
check_secure_boot_state() {
    log_step "Checking current Secure Boot state..."
    
    # Check Secure Boot status
    local sb_var=$(find /sys/firmware/efi/efivars -name "SecureBoot-*" 2>/dev/null | head -1)
    if [ -n "$sb_var" ]; then
        local sb_status=$(od -An -t u1 "$sb_var" 2>/dev/null | awk '{print $NF}')
        if [ "$sb_status" = "1" ]; then
            log_info "Secure Boot is currently ENABLED"
        else
            log_info "Secure Boot is currently DISABLED"
        fi
    fi
    
    # Check Setup Mode
    local setup_var=$(find /sys/firmware/efi/efivars -name "SetupMode-*" 2>/dev/null | head -1)
    if [ -n "$setup_var" ]; then
        local setup_status=$(od -An -t u1 "$setup_var" 2>/dev/null | awk '{print $NF}')
        if [ "$setup_status" = "1" ]; then
            log_info "System is in Setup Mode (ready for key enrollment)"
        else
            log_warn "System is in User Mode (may need to clear existing keys)"
        fi
    fi
    
    # Show current boot entries
    log_info "Current boot entries:"
    efibootmgr | tee -a "$LOG_FILE"
}

# Enroll custom keys (requires Setup Mode)
enroll_custom_keys() {
    log_step "Enrolling custom Secure Boot keys..."
    
    local uefi_keys_dir="$WORK_DIR/uefi_keys"
    
    # Check if we're in Setup Mode
    local setup_var=$(find /sys/firmware/efi/efivars -name "SetupMode-*" 2>/dev/null | head -1)
    if [ -n "$setup_var" ]; then
        local setup_status=$(od -An -t u1 "$setup_var" 2>/dev/null | awk '{print $NF}')
        if [ "$setup_status" != "1" ]; then
            log_warn "System not in Setup Mode - may need to clear existing keys first"
            log_info "To enter Setup Mode:"
            log_info "1. Reboot and enter UEFI setup"
            log_info "2. Clear all Secure Boot keys (delete PK)"
            log_info "3. Save and reboot"
            
            # Ask user if they want to continue anyway
            read -p "Continue with key enrollment attempt? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Key enrollment cancelled by user"
                return 1
            fi
        fi
    fi
    
    log_info "Attempting to enroll custom keys..."
    
    # Method 1: Try direct enrollment via efi-updatevar (if available)
    if command -v efi-updatevar &> /dev/null; then
        log_info "Attempting direct key enrollment..."
        
        # Enroll DB key first
        sudo efi-updatevar -f "$uefi_keys_dir/DB.auth" db 2>&1 | tee -a "$LOG_FILE" || {
            log_warn "Direct DB enrollment failed"
        }
        
        # Enroll KEK
        sudo efi-updatevar -f "$uefi_keys_dir/KEK.auth" KEK 2>&1 | tee -a "$LOG_FILE" || {
            log_warn "Direct KEK enrollment failed"
        }
        
        # Enroll PK (this exits Setup Mode)
        sudo efi-updatevar -f "$uefi_keys_dir/PK.auth" PK 2>&1 | tee -a "$LOG_FILE" || {
            log_warn "Direct PK enrollment failed"
        }
    fi
    
    # Method 2: Use sbctl for key enrollment
    log_info "Using sbctl for key management..."
    
    # Import our custom keys into sbctl
    if [ -f "$KEYS_DIR/dev/DB/DB.key" ] && [ -f "$KEYS_DIR/dev/DB/DB.crt" ]; then
        # Copy our keys to sbctl directory
        mkdir -p ~/.local/share/sbctl/keys
        cp "$KEYS_DIR/dev/DB/DB.key" ~/.local/share/sbctl/keys/db.key
        cp "$KEYS_DIR/dev/DB/DB.crt" ~/.local/share/sbctl/keys/db.crt
        cp "$KEYS_DIR/dev/KEK/KEK.key" ~/.local/share/sbctl/keys/KEK.key
        cp "$KEYS_DIR/dev/KEK/KEK.crt" ~/.local/share/sbctl/keys/KEK.crt
        cp "$KEYS_DIR/dev/PK/PK.key" ~/.local/share/sbctl/keys/PK.key
        cp "$KEYS_DIR/dev/PK/PK.crt" ~/.local/share/sbctl/keys/PK.crt
        
        log_info "Custom keys imported to sbctl"
    fi
    
    # Method 3: Prepare keys for manual enrollment
    log_info "Preparing keys for manual UEFI enrollment..."
    
    # Copy keys to EFI System Partition for manual enrollment
    local esp_mount=$(findmnt -n -o TARGET -t vfat | grep -E "(boot/efi|efi)" | head -1)
    if [ -n "$esp_mount" ]; then
        local keys_esp_dir="$esp_mount/EFI/keys"
        sudo mkdir -p "$keys_esp_dir"
        sudo cp "$uefi_keys_dir"/*.auth "$keys_esp_dir/"
        sudo cp "$uefi_keys_dir"/*.crt "$keys_esp_dir/"
        log_info "Keys copied to ESP at $keys_esp_dir for manual enrollment"
    fi
    
    log_info "Key enrollment preparation completed"
    log_warn "If automatic enrollment failed, manually enroll keys via UEFI setup:"
    log_info "1. Reboot and enter UEFI setup"
    log_info "2. Navigate to Secure Boot settings"
    log_info "3. Enroll keys from $esp_mount/EFI/keys/"
    log_info "4. Enable Secure Boot"
}

# Find and sign bootloader components
sign_bootloader_components() {
    log_step "Signing bootloader components..."
    
    local esp_mount=$(findmnt -n -o TARGET -t vfat | grep -E "(boot/efi|efi)" | head -1)
    if [ -z "$esp_mount" ]; then
        log_error "EFI System Partition not found"
        return 1
    fi
    
    log_info "EFI System Partition: $esp_mount"
    
    # Find bootloader files to sign
    local files_to_sign=()
    
    # Common bootloader locations
    local bootloader_paths=(
        "$esp_mount/EFI/BOOT/BOOTX64.EFI"
        "$esp_mount/EFI/debian/grubx64.efi"
        "$esp_mount/EFI/debian/shimx64.efi"
        "$esp_mount/EFI/ubuntu/grubx64.efi"
        "$esp_mount/EFI/ubuntu/shimx64.efi"
    )
    
    for file in "${bootloader_paths[@]}"; do
        if [ -f "$file" ]; then
            files_to_sign+=("$file")
            log_info "Found bootloader: $file"
        fi
    done
    
    # Find kernel files
    local kernel_files=($(find /boot -name "vmlinuz-*" -type f 2>/dev/null))
    for kernel in "${kernel_files[@]}"; do
        files_to_sign+=("$kernel")
        log_info "Found kernel: $kernel"
    done
    
    # Sign files using sbctl
    for file in "${files_to_sign[@]}"; do
        log_info "Signing: $file"
        if sudo sbctl sign "$file" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "✓ Successfully signed: $file"
        else
            log_warn "Failed to sign: $file"
        fi
    done
    
    # Sign with our custom keys as backup
    if [ -f "$KEYS_DIR/dev/DB/DB.key" ]; then
        log_info "Creating additional signatures with custom DB key..."
        for file in "${files_to_sign[@]}"; do
            if [ -f "$file" ]; then
                local signed_file="${file}.signed"
                if sbsign --key "$KEYS_DIR/dev/DB/DB.key" --cert "$KEYS_DIR/dev/DB/DB.crt" --output "$signed_file" "$file" 2>&1 | tee -a "$LOG_FILE"; then
                    log_info "✓ Custom signature created: $signed_file"
                else
                    log_warn "Failed to create custom signature for: $file"
                fi
            fi
        done
    fi
    
    log_info "Bootloader signing completed"
}

# Create test unsigned kernel for validation
create_test_kernel() {
    log_step "Creating test unsigned kernel for Secure Boot validation..."
    
    local test_kernel_dir="$WORK_DIR/test_kernel"
    mkdir -p "$test_kernel_dir"
    
    # Create a simple test "kernel" (actually just a script)
    cat > "$test_kernel_dir/test-unsigned-kernel" << 'EOF'
#!/bin/bash
echo "This is a test unsigned kernel - should be rejected by Secure Boot"
exit 0
EOF
    
    chmod +x "$test_kernel_dir/test-unsigned-kernel"
    
    # Copy to EFI partition for testing
    local esp_mount=$(findmnt -n -o TARGET -t vfat | grep -E "(boot/efi|efi)" | head -1)
    if [ -n "$esp_mount" ]; then
        sudo cp "$test_kernel_dir/test-unsigned-kernel" "$esp_mount/EFI/test-unsigned.efi"
        log_info "Test unsigned kernel created at $esp_mount/EFI/test-unsigned.efi"
    fi
    
    log_info "Test kernel created for Secure Boot validation"
}

# Verify Secure Boot configuration
verify_secure_boot() {
    log_step "Verifying Secure Boot configuration..."
    
    # Check sbctl status
    log_info "sbctl verification status:"
    sbctl verify 2>&1 | tee -a "$LOG_FILE" || {
        log_warn "Some files failed sbctl verification"
    }
    
    # Check current Secure Boot state
    local sb_var=$(find /sys/firmware/efi/efivars -name "SecureBoot-*" 2>/dev/null | head -1)
    if [ -n "$sb_var" ]; then
        local sb_status=$(od -An -t u1 "$sb_var" 2>/dev/null | awk '{print $NF}')
        if [ "$sb_status" = "1" ]; then
            log_info "✓ Secure Boot is ENABLED"
        else
            log_warn "Secure Boot is still DISABLED"
            log_info "Enable Secure Boot in UEFI setup to complete configuration"
        fi
    fi
    
    # Check Setup Mode
    local setup_var=$(find /sys/firmware/efi/efivars -name "SetupMode-*" 2>/dev/null | head -1)
    if [ -n "$setup_var" ]; then
        local setup_status=$(od -An -t u1 "$setup_var" 2>/dev/null | awk '{print $NF}')
        if [ "$setup_status" = "0" ]; then
            log_info "✓ System is in User Mode (keys enrolled)"
        else
            log_warn "System still in Setup Mode (keys may not be enrolled)"
        fi
    fi
    
    # List signed files
    log_info "Signed files in sbctl database:"
    sbctl list-files 2>&1 | tee -a "$LOG_FILE" || {
        log_warn "No files in sbctl database"
    }
    
    log_info "Secure Boot verification completed"
}

# Generate summary report
generate_report() {
    log_step "Generating Secure Boot setup report..."
    
    local report_file="$WORK_DIR/secure-boot-report.md"
    
    cat > "$report_file" << EOF
# Secure Boot Setup Report

**Generated:** $(date)
**Task:** 4. Implement UEFI Secure Boot with custom keys

## Summary

This report documents the implementation of UEFI Secure Boot with custom development keys.

## Key Information

**Key Location:** $KEYS_DIR/dev/
**Working Directory:** $WORK_DIR

### Platform Key (PK)
- Subject: $(openssl x509 -in "$KEYS_DIR/dev/PK/PK.crt" -noout -subject 2>/dev/null || echo "Not available")
- Fingerprint: $(openssl x509 -in "$KEYS_DIR/dev/PK/PK.crt" -noout -fingerprint -sha256 2>/dev/null || echo "Not available")

### Key Exchange Key (KEK)
- Subject: $(openssl x509 -in "$KEYS_DIR/dev/KEK/KEK.crt" -noout -subject 2>/dev/null || echo "Not available")
- Fingerprint: $(openssl x509 -in "$KEYS_DIR/dev/KEK/KEK.crt" -noout -fingerprint -sha256 2>/dev/null || echo "Not available")

### Database Key (DB)
- Subject: $(openssl x509 -in "$KEYS_DIR/dev/DB/DB.crt" -noout -subject 2>/dev/null || echo "Not available")
- Fingerprint: $(openssl x509 -in "$KEYS_DIR/dev/DB/DB.crt" -noout -fingerprint -sha256 2>/dev/null || echo "Not available")

## Current Status

EOF
    
    # Add current Secure Boot status
    echo "### Secure Boot Status" >> "$report_file"
    echo '```' >> "$report_file"
    sbctl status >> "$report_file" 2>/dev/null || echo "sbctl status not available" >> "$report_file"
    echo '```' >> "$report_file"
    
    # Add signed files
    echo "" >> "$report_file"
    echo "### Signed Files" >> "$report_file"
    echo '```' >> "$report_file"
    sbctl list-files >> "$report_file" 2>/dev/null || echo "No signed files" >> "$report_file"
    echo '```' >> "$report_file"
    
    # Add next steps
    cat >> "$report_file" << EOF

## Next Steps

1. **Enable Secure Boot in UEFI:**
   - Reboot and enter UEFI setup
   - Navigate to Secure Boot settings
   - Enable Secure Boot
   - Save and exit

2. **Test Secure Boot Enforcement:**
   - Boot with Secure Boot enabled
   - Verify signed kernels boot successfully
   - Test that unsigned kernels are rejected

3. **Verify Configuration:**
   - Run: \`sbctl status\`
   - Run: \`sbctl verify\`
   - Check boot logs for Secure Boot messages

## Manual Key Enrollment (if needed)

If automatic key enrollment failed, manually enroll keys:

1. Copy keys from EFI System Partition
2. Enter UEFI setup
3. Navigate to Secure Boot > Key Management
4. Enroll keys in order: DB → KEK → PK
5. Enable Secure Boot

## Security Notes

⚠️  **DEVELOPMENT KEYS ONLY**
These keys are for development and testing only. Production systems must use HSM-backed keys.

## Files Created

- Keys: \`$KEYS_DIR/dev/\`
- Working files: \`$WORK_DIR/\`
- Log file: \`$LOG_FILE\`
- This report: \`$report_file\`

EOF
    
    log_info "Report generated: $report_file"
}

# Main execution function
main() {
    log_info "Starting UEFI Secure Boot implementation..."
    log_warn "This implements Task 4: UEFI Secure Boot with custom keys"
    
    init_logging
    check_root
    check_prerequisites
    check_secure_boot_state
    configure_sbctl
    prepare_custom_keys
    enroll_custom_keys
    sign_bootloader_components
    create_test_kernel
    verify_secure_boot
    generate_report
    
    log_info "=== Secure Boot Implementation Completed ==="
    log_info "Next steps:"
    log_info "1. Reboot and enable Secure Boot in UEFI setup"
    log_info "2. Test boot with Secure Boot enabled"
    log_info "3. Run verification: sbctl status && sbctl verify"
    log_warn "Remember: These are DEVELOPMENT keys only!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--verify-only]"
        echo "Implements UEFI Secure Boot with custom development keys"
        echo ""
        echo "Options:"
        echo "  --help        Show this help"
        echo "  --verify-only Only verify current Secure Boot status"
        exit 0
        ;;
    --verify-only)
        init_logging
        check_prerequisites
        verify_secure_boot
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac