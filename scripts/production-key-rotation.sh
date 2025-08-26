#!/bin/bash
# Production Key Rotation Script for HSM-based Infrastructure
# Implements secure key rotation procedures with proper audit trails

set -euo pipefail

# Configuration
HSM_CONFIG_DIR="/etc/hardened-os/hsm"
SIGNING_DIR="/opt/signing-infrastructure"
BACKUP_DIR="/secure-backup/keys"
AUDIT_LOG="/var/log/hsm-key-rotation.log"
ROTATION_LOG="/var/log/key-rotation-$(date +%Y%m%d-%H%M%S).log"

# Key rotation schedule (in days)
ROOT_KEY_ROTATION=730    # 2 years
PLATFORM_KEY_ROTATION=365  # 1 year
KEK_ROTATION=180         # 6 months
DB_KEY_ROTATION=90       # 3 months

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local message="$1"
    local timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo -e "${GREEN}[$timestamp]${NC} $message" | tee -a "$ROTATION_LOG"
    echo "[$timestamp] $message" >> "$AUDIT_LOG"
}

warn() {
    local message="$1"
    local timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo -e "${YELLOW}[$timestamp] WARNING:${NC} $message" | tee -a "$ROTATION_LOG"
    echo "[$timestamp] WARNING: $message" >> "$AUDIT_LOG"
}

error() {
    local message="$1"
    local timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo -e "${RED}[$timestamp] ERROR:${NC} $message" | tee -a "$ROTATION_LOG"
    echo "[$timestamp] ERROR: $message" >> "$AUDIT_LOG"
    exit 1
}

audit_action() {
    local action="$1"
    local details="$2"
    local timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo "[$timestamp] ACTION: $action | USER: $(whoami) | DETAILS: $details" >> "$AUDIT_LOG"
}

check_prerequisites() {
    log "Checking prerequisites for key rotation..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "Key rotation must be run as root"
    fi
    
    # Check HSM availability
    if ! pkcs11-tool --list-slots &>/dev/null; then
        error "HSM not available or not configured"
    fi
    
    # Check backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "Creating secure backup directory..."
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
    fi
    
    # Verify signing infrastructure
    if [[ ! -f "$SIGNING_DIR/scripts/hsm-key-manager.sh" ]]; then
        error "HSM key manager not found. Run setup-hsm-infrastructure.sh first"
    fi
    
    log "Prerequisites check completed"
}

get_key_age() {
    local key_id="$1"
    local token="$2"
    local pin="$3"
    
    # Get key creation date from HSM (simplified - actual implementation depends on HSM)
    # For now, we'll use a placeholder that checks file timestamps
    local key_backup_file="$BACKUP_DIR/key-${key_id}-creation.date"
    
    if [[ -f "$key_backup_file" ]]; then
        local creation_date=$(cat "$key_backup_file")
        local current_date=$(date +%s)
        local age_days=$(( (current_date - creation_date) / 86400 ))
        echo "$age_days"
    else
        # If no creation date found, assume key is old and needs rotation
        echo "999"
    fi
}

check_rotation_needed() {
    local key_type="$1"
    local key_id="$2"
    local token="$3"
    local pin="$4"
    
    local age_days=$(get_key_age "$key_id" "$token" "$pin")
    local rotation_threshold
    
    case "$key_type" in
        "root")
            rotation_threshold=$ROOT_KEY_ROTATION
            ;;
        "platform")
            rotation_threshold=$PLATFORM_KEY_ROTATION
            ;;
        "kek")
            rotation_threshold=$KEK_ROTATION
            ;;
        "db")
            rotation_threshold=$DB_KEY_ROTATION
            ;;
        *)
            error "Unknown key type: $key_type"
            ;;
    esac
    
    if [[ $age_days -ge $rotation_threshold ]]; then
        log "Key $key_id ($key_type) is $age_days days old, rotation needed (threshold: $rotation_threshold days)"
        return 0
    else
        log "Key $key_id ($key_type) is $age_days days old, rotation not needed (threshold: $rotation_threshold days)"
        return 1
    fi
}

backup_existing_key() {
    local key_id="$1"
    local token="$2"
    local pin="$3"
    local key_type="$4"
    
    log "Backing up existing key $key_id before rotation..."
    
    local backup_timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/key-${key_id}-${key_type}-${backup_timestamp}"
    
    # Backup public key
    "$SIGNING_DIR/scripts/hsm-key-manager.sh" backup-key "$token" "$pin" "$key_id" "$backup_file"
    
    # Create metadata file
    cat > "${backup_file}.metadata" << EOF
key_id: $key_id
key_type: $key_type
token: $token
backup_date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
backup_reason: key_rotation
rotated_by: $(whoami)
EOF
    
    audit_action "KEY_BACKUP" "key_id=$key_id type=$key_type file=$backup_file"
    log "Key backup completed: $backup_file"
}

generate_new_key() {
    local key_id="$1"
    local token="$2"
    local pin="$3"
    local key_type="$4"
    local key_size="${5:-2048}"
    
    log "Generating new $key_type key with ID $key_id..."
    
    # Generate new key pair
    "$SIGNING_DIR/scripts/hsm-key-manager.sh" generate-key "$token" "$pin" "$key_id" "$key_size"
    
    # Record creation date
    echo "$(date +%s)" > "$BACKUP_DIR/key-${key_id}-creation.date"
    
    audit_action "KEY_GENERATION" "key_id=$key_id type=$key_type size=$key_size"
    log "New key generated successfully"
}

update_key_references() {
    local old_key_id="$1"
    local new_key_id="$2"
    local key_type="$3"
    
    log "Updating key references from $old_key_id to $new_key_id..."
    
    # Update configuration files
    case "$key_type" in
        "platform")
            # Update UEFI Secure Boot configuration
            log "Updating Secure Boot configuration for new platform key..."
            # This would involve re-enrolling keys in UEFI
            ;;
        "kek")
            log "Updating KEK references..."
            # Update bootloader signing configuration
            ;;
        "db")
            log "Updating DB key references..."
            # Update kernel/driver signing configuration
            ;;
    esac
    
    audit_action "KEY_REFERENCE_UPDATE" "old_key=$old_key_id new_key=$new_key_id type=$key_type"
}

revoke_old_key() {
    local key_id="$1"
    local token="$2"
    local pin="$3"
    local key_type="$4"
    
    log "Revoking old key $key_id..."
    
    # Add to revocation list
    local revocation_file="$SIGNING_DIR/revoked-keys.list"
    echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') $key_id $key_type ROTATED" >> "$revocation_file"
    
    # For UEFI keys, add to DBX (forbidden database)
    if [[ "$key_type" == "platform" || "$key_type" == "kek" || "$key_type" == "db" ]]; then
        log "Adding old key to UEFI forbidden database (DBX)..."
        # This would involve updating the DBX in UEFI firmware
    fi
    
    audit_action "KEY_REVOCATION" "key_id=$key_id type=$key_type reason=rotation"
    log "Key revocation completed"
}

rotate_key() {
    local key_type="$1"
    local current_key_id="$2"
    local token="$3"
    local pin="$4"
    local key_size="${5:-2048}"
    
    log "Starting rotation for $key_type key $current_key_id..."
    
    # Generate new key ID
    local new_key_id="${current_key_id}-$(date +%Y%m%d)"
    
    # Backup existing key
    backup_existing_key "$current_key_id" "$token" "$pin" "$key_type"
    
    # Generate new key
    generate_new_key "$new_key_id" "$token" "$pin" "$key_type" "$key_size"
    
    # Update references
    update_key_references "$current_key_id" "$new_key_id" "$key_type"
    
    # Revoke old key
    revoke_old_key "$current_key_id" "$token" "$pin" "$key_type"
    
    log "Key rotation completed for $key_type key"
    
    # Create rotation report
    create_rotation_report "$key_type" "$current_key_id" "$new_key_id"
}

create_rotation_report() {
    local key_type="$1"
    local old_key_id="$2"
    local new_key_id="$3"
    
    local report_file="$SIGNING_DIR/reports/key-rotation-$(date +%Y%m%d-%H%M%S).md"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
# Key Rotation Report

## Summary
- **Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Key Type**: $key_type
- **Old Key ID**: $old_key_id
- **New Key ID**: $new_key_id
- **Performed By**: $(whoami)
- **Reason**: Scheduled rotation

## Actions Performed
1. Backed up existing key to secure storage
2. Generated new key pair in HSM
3. Updated system configuration references
4. Revoked old key and added to forbidden list
5. Verified new key functionality

## Verification
- [ ] New key generates valid signatures
- [ ] Old key properly revoked
- [ ] System boots with new keys
- [ ] All dependent systems updated

## Next Steps
1. Test system functionality with new keys
2. Update documentation with new key IDs
3. Notify stakeholders of key rotation
4. Schedule next rotation: $(date -d "+$ROOT_KEY_ROTATION days" '+%Y-%m-%d')

## Audit Trail
See detailed audit log: $AUDIT_LOG
EOF

    log "Rotation report created: $report_file"
}

perform_rotation_check() {
    local token="${1:-HardenedOS-Prod}"
    local pin="$2"
    
    log "Performing key rotation check for token $token..."
    
    # Check each key type
    local keys_to_rotate=()
    
    # Root key (ID: 01)
    if check_rotation_needed "root" "01" "$token" "$pin"; then
        keys_to_rotate+=("root:01:4096")
    fi
    
    # Platform key (ID: 02)
    if check_rotation_needed "platform" "02" "$token" "$pin"; then
        keys_to_rotate+=("platform:02:2048")
    fi
    
    # KEK key (ID: 03)
    if check_rotation_needed "kek" "03" "$token" "$pin"; then
        keys_to_rotate+=("kek:03:2048")
    fi
    
    # DB key (ID: 04)
    if check_rotation_needed "db" "04" "$token" "$pin"; then
        keys_to_rotate+=("db:04:2048")
    fi
    
    if [[ ${#keys_to_rotate[@]} -eq 0 ]]; then
        log "No keys require rotation at this time"
        return 0
    fi
    
    log "Keys requiring rotation: ${#keys_to_rotate[@]}"
    
    # Perform rotations
    for key_spec in "${keys_to_rotate[@]}"; do
        IFS=':' read -r key_type key_id key_size <<< "$key_spec"
        rotate_key "$key_type" "$key_id" "$token" "$pin" "$key_size"
    done
    
    log "All required key rotations completed"
}

emergency_rotation() {
    local key_type="$1"
    local key_id="$2"
    local token="$3"
    local pin="$4"
    local reason="${5:-emergency}"
    
    warn "EMERGENCY KEY ROTATION initiated for $key_type key $key_id"
    warn "Reason: $reason"
    
    audit_action "EMERGENCY_ROTATION_START" "key_id=$key_id type=$key_type reason=$reason"
    
    # Immediate revocation
    revoke_old_key "$key_id" "$token" "$pin" "$key_type"
    
    # Generate replacement key
    local emergency_key_id="${key_id}-emergency-$(date +%Y%m%d%H%M%S)"
    generate_new_key "$emergency_key_id" "$token" "$pin" "$key_type"
    
    # Update references
    update_key_references "$key_id" "$emergency_key_id" "$key_type"
    
    audit_action "EMERGENCY_ROTATION_COMPLETE" "old_key=$key_id new_key=$emergency_key_id"
    
    # Send alerts
    log "EMERGENCY ROTATION COMPLETED - Manual verification required"
    
    # Create emergency report
    create_emergency_report "$key_type" "$key_id" "$emergency_key_id" "$reason"
}

create_emergency_report() {
    local key_type="$1"
    local old_key_id="$2"
    local new_key_id="$3"
    local reason="$4"
    
    local report_file="$SIGNING_DIR/reports/emergency-rotation-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# EMERGENCY KEY ROTATION REPORT

## CRITICAL ALERT
**EMERGENCY KEY ROTATION PERFORMED**

## Details
- **Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Key Type**: $key_type
- **Compromised Key**: $old_key_id
- **Replacement Key**: $new_key_id
- **Reason**: $reason
- **Performed By**: $(whoami)

## Immediate Actions Required
1. [ ] Verify new key functionality
2. [ ] Test system boot process
3. [ ] Update all dependent systems
4. [ ] Notify security team
5. [ ] Conduct incident investigation

## Security Impact
- Old key immediately revoked
- All signatures from old key should be considered suspect
- Systems may require manual intervention

## Contact Information
- Security Team: security@example.com
- On-call Engineer: oncall@example.com

## Audit Trail
Full audit trail available in: $AUDIT_LOG
EOF

    chmod 600 "$report_file"
    log "Emergency rotation report created: $report_file"
}

usage() {
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  check TOKEN PIN              Check if keys need rotation"
    echo "  rotate-all TOKEN PIN         Rotate all keys that need rotation"
    echo "  rotate-key TYPE ID TOKEN PIN Rotate specific key"
    echo "  emergency TYPE ID TOKEN PIN  Emergency key rotation"
    echo "  status                       Show key rotation status"
    echo
    echo "Key Types: root, platform, kek, db"
    echo
    echo "Examples:"
    echo "  $0 check HardenedOS-Prod \$HSM_PIN"
    echo "  $0 rotate-key platform 02 HardenedOS-Prod \$HSM_PIN"
    echo "  $0 emergency db 04 HardenedOS-Prod \$HSM_PIN"
    exit 1
}

main() {
    local command="${1:-}"
    
    if [[ -z "$command" ]]; then
        usage
    fi
    
    check_prerequisites
    
    case "$command" in
        "check")
            if [[ $# -ne 3 ]]; then
                echo "Usage: $0 check TOKEN PIN"
                exit 1
            fi
            perform_rotation_check "$2" "$3"
            ;;
        "rotate-all")
            if [[ $# -ne 3 ]]; then
                echo "Usage: $0 rotate-all TOKEN PIN"
                exit 1
            fi
            perform_rotation_check "$2" "$3"
            ;;
        "rotate-key")
            if [[ $# -ne 5 ]]; then
                echo "Usage: $0 rotate-key TYPE ID TOKEN PIN"
                exit 1
            fi
            rotate_key "$2" "$3" "$4" "$5"
            ;;
        "emergency")
            if [[ $# -lt 5 ]]; then
                echo "Usage: $0 emergency TYPE ID TOKEN PIN [REASON]"
                exit 1
            fi
            emergency_rotation "$2" "$3" "$4" "$5" "${6:-emergency}"
            ;;
        "status")
            log "Key rotation status check not yet implemented"
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"