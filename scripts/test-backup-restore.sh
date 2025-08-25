#!/bin/bash
#
# Backup and Restore Testing Script
# Tests encrypted key backup creation and restoration
#

set -euo pipefail

# Configuration
KEYS_DIR="$HOME/harden/keys"
TEST_DIR="$HOME/harden/test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }

# Test backup creation and restoration
test_backup_restore_cycle() {
    log_test "Testing complete backup and restore cycle..."
    
    # Setup test environment
    mkdir -p "$TEST_DIR"
    
    # Create test keys if they don't exist
    if [ ! -d "$KEYS_DIR/dev" ]; then
        log_info "Creating test keys for backup testing..."
        "$SCRIPT_DIR/generate-dev-keys.sh"
    fi
    
    # Create original fingerprints
    local original_fingerprints="$TEST_DIR/original_fingerprints.txt"
    for key_type in PK KEK DB; do
        if [ -f "$KEYS_DIR/dev/$key_type/$key_type.crt" ]; then
            openssl x509 -in "$KEYS_DIR/dev/$key_type/$key_type.crt" -noout -fingerprint -sha256 >> "$original_fingerprints"
        fi
    done
    
    # Create backup
    log_info "Creating encrypted backup..."
    local backup_dir="$KEYS_DIR/backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/test_backup_$timestamp.tar.gz"
    
    mkdir -p "$backup_dir"
    
    # Create backup with known passphrase for testing
    echo "test_passphrase_123" | tar -czf - -C "$KEYS_DIR" dev | \
        gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 \
        --output "$backup_file.gpg"
    
    if [ $? -eq 0 ]; then
        log_info "✓ Backup created successfully"
    else
        log_error "✗ Backup creation failed"
        return 1
    fi
    
    # Create checksum
    sha256sum "$backup_file.gpg" > "$backup_file.gpg.sha256"
    
    # Backup original keys
    mv "$KEYS_DIR/dev" "$TEST_DIR/original_keys"
    
    # Test restore
    log_info "Testing backup restoration..."
    echo "test_passphrase_123" | gpg --batch --yes --passphrase-fd 0 --decrypt "$backup_file.gpg" | \
        tar -xzf - -C "$KEYS_DIR/"
    
    if [ $? -eq 0 ]; then
        log_info "✓ Restore completed successfully"
    else
        log_error "✗ Restore failed"
        return 1
    fi
    
    # Verify restored fingerprints match original
    local restored_fingerprints="$TEST_DIR/restored_fingerprints.txt"
    for key_type in PK KEK DB; do
        if [ -f "$KEYS_DIR/dev/$key_type/$key_type.crt" ]; then
            openssl x509 -in "$KEYS_DIR/dev/$key_type/$key_type.crt" -noout -fingerprint -sha256 >> "$restored_fingerprints"
        fi
    done
    
    if diff "$original_fingerprints" "$restored_fingerprints" > /dev/null; then
        log_info "✓ Key fingerprints match after restore"
    else
        log_error "✗ Key fingerprints don't match after restore"
        return 1
    fi
    
    # Test permissions after restore
    for key_type in PK KEK DB; do
        local key_file="$KEYS_DIR/dev/$key_type/$key_type.key"
        if [ -f "$key_file" ]; then
            local perms=$(stat -c "%a" "$key_file")
            if [ "$perms" = "600" ]; then
                log_info "✓ Correct permissions on $key_type.key ($perms)"
            else
                log_error "✗ Incorrect permissions on $key_type.key ($perms, expected 600)"
                return 1
            fi
        fi
    done
    
    # Cleanup
    rm -f "$backup_file.gpg" "$backup_file.gpg.sha256"
    rm -f "$original_fingerprints" "$restored_fingerprints"
    
    log_info "✓ Backup and restore cycle test completed successfully"
}

# Test backup integrity verification
test_backup_integrity() {
    log_test "Testing backup integrity verification..."
    
    local backup_dir="$KEYS_DIR/backup"
    local test_backup="$backup_dir/integrity_test_$(date +%Y%m%d_%H%M%S).tar.gz.gpg"
    
    # Create a test backup
    echo "test_passphrase" | tar -czf - -C "$KEYS_DIR" dev | \
        gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 \
        --output "$test_backup"
    
    # Create checksum
    sha256sum "$test_backup" > "$test_backup.sha256"
    
    # Verify integrity
    if sha256sum -c "$test_backup.sha256" > /dev/null 2>&1; then
        log_info "✓ Backup integrity verification works"
    else
        log_error "✗ Backup integrity verification failed"
        return 1
    fi
    
    # Test corrupted backup detection
    echo "corrupted_data" >> "$test_backup"
    
    if ! sha256sum -c "$test_backup.sha256" > /dev/null 2>&1; then
        log_info "✓ Corrupted backup detected correctly"
    else
        log_error "✗ Corrupted backup not detected"
        return 1
    fi
    
    # Cleanup
    rm -f "$test_backup" "$test_backup.sha256"
    
    log_info "✓ Backup integrity test completed successfully"
}

# Main test execution
main() {
    log_test "Starting backup and restore testing..."
    
    test_backup_restore_cycle
    test_backup_integrity
    
    log_info "All backup and restore tests completed successfully!"
}

main "$@"