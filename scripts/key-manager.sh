#!/bin/bash
#
# Key Management Utility
# Provides unified interface for key operations
#

set -euo pipefail

# Configuration
KEYS_DIR="$HOME/harden/keys"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}$1${NC}"
}

# Show usage information
show_usage() {
    cat << EOF
Key Management Utility for Hardened OS

Usage: $0 <command> [options]

Commands:
  generate        Generate new development keys
  status          Show key status and information
  backup          Create encrypted key backup
  restore         Restore keys from backup
  enroll          Enroll keys in UEFI firmware
  sign            Sign boot components
  verify          Verify signatures
  rotate          Rotate keys (emergency procedure)
  clean           Clean up old keys and backups

Options:
  -h, --help      Show this help message
  -v, --verbose   Enable verbose output
  -f, --force     Force operation without confirmation

Examples:
  $0 generate                    # Generate new development keys
  $0 status                      # Show current key status
  $0 backup                      # Create encrypted backup
  $0 sign /boot/vmlinuz         # Sign kernel
  $0 verify /boot/vmlinuz       # Verify kernel signature
EOF
}

# Check if keys exist
check_keys_exist() {
    if [ ! -d "$KEYS_DIR/dev" ]; then
        log_error "Development keys not found. Run '$0 generate' first."
        log_warn "DEVELOPMENT KEYS ONLY - NOT FOR PRODUCTION USE"
        return 1
    fi
    
    local required_files=(
        "$KEYS_DIR/dev/PK/PK.key"
        "$KEYS_DIR/dev/KEK/KEK.key"
        "$KEYS_DIR/dev/DB/DB.key"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required key file missing: $file"
            return 1
        fi
    done
    
    return 0
}

# Generate keys
cmd_generate() {
    log_header "Generating Development Keys"
    
    if [ -d "$KEYS_DIR/dev" ] && [ "$FORCE" != "true" ]; then
        log_warn "Development keys already exist!"
        read -p "Overwrite existing keys? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Key generation cancelled"
            return 0
        fi
        
        # Backup existing keys
        local backup_dir="$KEYS_DIR/backup/replaced_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        mv "$KEYS_DIR/dev" "$backup_dir/"
        log_info "Existing keys backed up to: $backup_dir"
    fi
    
    "$SCRIPT_DIR/generate-dev-keys.sh"
}

# Show key status
cmd_status() {
    log_header "Key Status Information"
    
    if ! check_keys_exist; then
        return 1
    fi
    
    echo ""
    log_info "Key Directory: $KEYS_DIR/dev"
    echo ""
    
    # Show key metadata if available
    if [ -f "$KEYS_DIR/dev/key_metadata.json" ]; then
        log_info "Key Metadata:"
        cat "$KEYS_DIR/dev/key_metadata.json" | jq '.' 2>/dev/null || cat "$KEYS_DIR/dev/key_metadata.json"
        echo ""
    fi
    
    # Show key file information
    log_info "Key Files:"
    for key_type in PK KEK DB; do
        local key_dir="$KEYS_DIR/dev/$key_type"
        if [ -d "$key_dir" ]; then
            echo "  $key_type:"
            ls -la "$key_dir"/ | grep -E '\.(key|crt|der|esl|auth)$' | while read -r line; do
                echo "    $line"
            done
            echo ""
        fi
    done
    
    # Check UEFI enrollment status
    log_info "UEFI Enrollment Status:"
    if command -v efi-readvar &> /dev/null; then
        for var in PK KEK db; do
            echo -n "  $var: "
            if efi-readvar -v "$var" &> /dev/null; then
                echo -e "${GREEN}Enrolled${NC}"
            else
                echo -e "${RED}Not enrolled${NC}"
            fi
        done
    else
        echo "  efi-readvar not available (install efitools)"
    fi
    echo ""
    
    # Show Secure Boot status
    log_info "Secure Boot Status:"
    if command -v mokutil &> /dev/null; then
        mokutil --sb-state 2>/dev/null || echo "  Unable to determine Secure Boot state"
    else
        echo "  mokutil not available (install mokutil)"
    fi
}

# Create backup
cmd_backup() {
    log_header "Creating Key Backup"
    
    if ! check_keys_exist; then
        return 1
    fi
    
    local backup_dir="$KEYS_DIR/backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/dev_keys_backup_$timestamp.tar.gz"
    
    mkdir -p "$backup_dir"
    
    log_info "Creating encrypted backup..."
    
    # Create encrypted backup
    tar -czf - -C "$KEYS_DIR" dev | \
        gpg --symmetric --cipher-algo AES256 \
        --output "$backup_file.gpg"
    
    if [ $? -eq 0 ]; then
        log_info "Encrypted backup created: $backup_file.gpg"
        
        # Create checksum
        sha256sum "$backup_file.gpg" > "$backup_file.gpg.sha256"
        log_info "Checksum created: $backup_file.gpg.sha256"
    else
        log_error "Backup creation failed"
        return 1
    fi
}

# Restore from backup
cmd_restore() {
    log_header "Restoring Keys from Backup"
    
    local backup_dir="$KEYS_DIR/backup"
    
    if [ ! -d "$backup_dir" ]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    # List available backups
    log_info "Available backups:"
    ls -la "$backup_dir"/*.tar.gz.gpg 2>/dev/null | nl || {
        log_error "No encrypted backups found"
        return 1
    }
    
    echo ""
    read -p "Enter backup filename: " backup_file
    
    if [ ! -f "$backup_dir/$backup_file" ]; then
        log_error "Backup file not found: $backup_dir/$backup_file"
        return 1
    fi
    
    # Verify checksum if available
    if [ -f "$backup_dir/$backup_file.sha256" ]; then
        log_info "Verifying backup integrity..."
        if ! sha256sum -c "$backup_dir/$backup_file.sha256"; then
            log_error "Backup integrity check failed!"
            return 1
        fi
        log_info "Backup integrity verified"
    fi
    
    # Backup existing keys if they exist
    if [ -d "$KEYS_DIR/dev" ]; then
        local old_backup="$KEYS_DIR/backup/replaced_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$old_backup"
        mv "$KEYS_DIR/dev" "$old_backup/"
        chmod 600 "$old_backup"/* 2>/dev/null || true
        log_info "Existing keys backed up to: $old_backup"
    fi
    
    # Restore from backup
    log_info "Restoring keys..."
    gpg --decrypt "$backup_dir/$backup_file" | tar -xzf - -C "$KEYS_DIR/"
    
    if [ $? -eq 0 ]; then
        # Fix permissions
        chmod -R 600 "$KEYS_DIR/dev/"
        chmod 700 "$KEYS_DIR/dev/"*/
        log_info "Keys restored successfully"
    else
        log_error "Key restoration failed"
        return 1
    fi
}

# Enroll keys in UEFI
cmd_enroll() {
    log_header "Enrolling Keys in UEFI"
    
    if ! check_keys_exist; then
        return 1
    fi
    
    log_warn "This operation requires root privileges and physical presence"
    log_warn "Ensure you have access to recovery media before proceeding"
    
    if [ "$FORCE" != "true" ]; then
        read -p "Continue with key enrollment? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Key enrollment cancelled"
            return 0
        fi
    fi
    
    # Check if efi-updatevar is available
    if ! command -v efi-updatevar &> /dev/null; then
        log_error "efi-updatevar not found. Install efitools package."
        return 1
    fi
    
    log_info "Enrolling Platform Key (PK)..."
    sudo efi-updatevar -f "$KEYS_DIR/dev/PK/PK.auth" PK
    
    log_info "Enrolling Key Exchange Key (KEK)..."
    sudo efi-updatevar -f "$KEYS_DIR/dev/KEK/KEK.auth" KEK
    
    log_info "Enrolling Database Key (DB)..."
    sudo efi-updatevar -f "$KEYS_DIR/dev/DB/DB.auth" db
    
    log_info "Key enrollment completed"
    log_info "Verify enrollment with: $0 status"
}

# Sign boot components
cmd_sign() {
    local target_file="$1"
    
    if [ -z "$target_file" ]; then
        log_error "No file specified for signing"
        echo "Usage: $0 sign <file>"
        return 1
    fi
    
    if [ ! -f "$target_file" ]; then
        log_error "File not found: $target_file"
        return 1
    fi
    
    if ! check_keys_exist; then
        return 1
    fi
    
    log_header "Signing Boot Component"
    log_info "Target file: $target_file"
    
    local db_key="$KEYS_DIR/dev/DB/DB.key"
    local db_crt="$KEYS_DIR/dev/DB/DB.crt"
    local output_file="${target_file}.signed"
    
    # Check if sbsign is available
    if ! command -v sbsign &> /dev/null; then
        log_error "sbsign not found. Install sbsigntool package."
        return 1
    fi
    
    log_info "Signing with DB key..."
    sbsign --key "$db_key" --cert "$db_crt" \
           --output "$output_file" \
           "$target_file"
    
    if [ $? -eq 0 ]; then
        log_info "File signed successfully: $output_file"
    else
        log_error "Signing failed"
        return 1
    fi
}

# Verify signatures
cmd_verify() {
    local target_file="$1"
    
    if [ -z "$target_file" ]; then
        log_error "No file specified for verification"
        echo "Usage: $0 verify <file>"
        return 1
    fi
    
    if [ ! -f "$target_file" ]; then
        log_error "File not found: $target_file"
        return 1
    fi
    
    if ! check_keys_exist; then
        return 1
    fi
    
    log_header "Verifying Signature"
    log_info "Target file: $target_file"
    
    local db_crt="$KEYS_DIR/dev/DB/DB.crt"
    
    # Check if sbverify is available
    if ! command -v sbverify &> /dev/null; then
        log_error "sbverify not found. Install sbsigntool package."
        return 1
    fi
    
    log_info "Verifying signature..."
    if sbverify --cert "$db_crt" "$target_file"; then
        log_info "Signature verification successful"
    else
        log_error "Signature verification failed"
        return 1
    fi
}

# Rotate keys (emergency procedure)
cmd_rotate() {
    log_header "Emergency Key Rotation"
    
    log_warn "This is an EMERGENCY procedure that will:"
    log_warn "1. Backup existing keys"
    log_warn "2. Generate new keys"
    log_warn "3. Require re-enrollment in UEFI"
    log_warn "4. Require re-signing all boot components"
    
    if [ "$FORCE" != "true" ]; then
        read -p "Are you sure you want to rotate keys? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Key rotation cancelled"
            return 0
        fi
    fi
    
    # Backup existing keys
    if [ -d "$KEYS_DIR/dev" ]; then
        local backup_dir="$KEYS_DIR/backup/rotated_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        mv "$KEYS_DIR/dev" "$backup_dir/"
        log_info "Existing keys backed up to: $backup_dir"
    fi
    
    # Generate new keys
    "$SCRIPT_DIR/generate-dev-keys.sh"
    
    log_warn "Key rotation completed"
    log_warn "Next steps:"
    log_warn "1. Enroll new keys: $0 enroll"
    log_warn "2. Re-sign all boot components"
    log_warn "3. Test boot process"
}

# Clean up old keys and backups
cmd_clean() {
    log_header "Cleaning Up Old Keys and Backups"
    
    local backup_dir="$KEYS_DIR/backup"
    
    if [ ! -d "$backup_dir" ]; then
        log_info "No backup directory found"
        return 0
    fi
    
    log_info "Backup directory contents:"
    ls -la "$backup_dir"
    echo ""
    
    log_warn "This will remove old backups and rotated keys"
    
    if [ "$FORCE" != "true" ]; then
        read -p "Continue with cleanup? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            return 0
        fi
    fi
    
    # Remove backups older than 30 days
    find "$backup_dir" -name "*.tar.gz*" -mtime +30 -delete
    find "$backup_dir" -name "rotated_*" -type d -mtime +30 -exec rm -rf {} +
    find "$backup_dir" -name "replaced_*" -type d -mtime +30 -exec rm -rf {} +
    
    log_info "Cleanup completed"
}

# Parse command line arguments
VERBOSE=false
FORCE=false
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        generate|status|backup|restore|enroll|sign|verify|rotate|clean)
            COMMAND="$1"
            shift
            break
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Execute command
case "$COMMAND" in
    generate)
        cmd_generate
        ;;
    status)
        cmd_status
        ;;
    backup)
        cmd_backup
        ;;
    restore)
        cmd_restore
        ;;
    enroll)
        cmd_enroll
        ;;
    sign)
        cmd_sign "$@"
        ;;
    verify)
        cmd_verify "$@"
        ;;
    rotate)
        cmd_rotate
        ;;
    clean)
        cmd_clean
        ;;
    "")
        log_error "No command specified"
        show_usage
        exit 1
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac