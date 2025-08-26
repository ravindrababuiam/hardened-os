#!/bin/bash
# Key Rotation and Compromise Response Procedures for Hardened OS
# Handles rotation of cryptographic keys and response to key compromise

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/etc/hardened-os/key-rotation.conf"
LOG_FILE="/var/log/key-rotation.log"
KEY_BACKUP_DIR="/var/backups/keys"
TEMP_KEY_DIR="/tmp/key-rotation-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Key types
KEY_TYPE_SECURE_BOOT="secure-boot"
KEY_TYPE_LUKS="luks"
KEY_TYPE_TPM="tpm"
KEY_TYPE_SSH="ssh"
KEY_TYPE_TLS="tls"
KEY_TYPE_JOURNAL="journal"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Default configuration
        KEY_ROTATION_INTERVAL_DAYS="${KEY_ROTATION_INTERVAL_DAYS:-90}"
        EMERGENCY_ROTATION_ENABLED="${EMERGENCY_ROTATION_ENABLED:-true}"
        KEY_BACKUP_RETENTION_DAYS="${KEY_BACKUP_RETENTION_DAYS:-365}"
        REQUIRE_CONFIRMATION="${REQUIRE_CONFIRMATION:-true}"
        HSM_ENABLED="${HSM_ENABLED:-false}"
        HSM_SLOT="${HSM_SLOT:-0}"
    fi
}

log_key_operation() {
    local level="$1"
    local operation="$2"
    local key_type="$3"
    local message="$4"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] [$level] [$operation] [$key_type] $message" >> "$LOG_FILE"
    echo -e "${BLUE}[$level]${NC} $operation ($key_type): $message"
    
    # Log to syslog with appropriate priority
    case "$level" in
        "CRITICAL") logger -p auth.crit "KEY_ROTATION_CRITICAL: $operation $key_type - $message" ;;
        "ERROR") logger -p auth.err "KEY_ROTATION_ERROR: $operation $key_type - $message" ;;
        "WARN") logger -p auth.warning "KEY_ROTATION_WARN: $operation $key_type - $message" ;;
        "INFO") logger -p auth.info "KEY_ROTATION_INFO: $operation $key_type - $message" ;;
    esac
}

create_key_backup() {
    local key_type="$1"
    local key_path="$2"
    local backup_reason="${3:-scheduled}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$KEY_BACKUP_DIR/$key_type/$timestamp"
    
    log_key_operation "INFO" "BACKUP" "$key_type" "Creating backup: $backup_reason"
    
    mkdir -p "$backup_dir"
    chmod 700 "$backup_dir"
    
    # Copy key files
    if [[ -f "$key_path" ]]; then
        cp "$key_path" "$backup_dir/"
        # Also backup related files (certificates, public keys, etc.)
        local key_dir=$(dirname "$key_path")
        local key_name=$(basename "$key_path" .key)
        
        for ext in .pub .crt .pem .p12 .pfx; do
            if [[ -f "$key_dir/$key_name$ext" ]]; then
                cp "$key_dir/$key_name$ext" "$backup_dir/"
            fi
        done
    elif [[ -d "$key_path" ]]; then
        cp -r "$key_path"/* "$backup_dir/"
    else
        log_key_operation "ERROR" "BACKUP" "$key_type" "Key path not found: $key_path"
        return 1
    fi
    
    # Create backup metadata
    cat > "$backup_dir/backup_metadata.json" << EOF
{
    "timestamp": "$timestamp",
    "key_type": "$key_type",
    "original_path": "$key_path",
    "backup_reason": "$backup_reason",
    "hostname": "$(hostname)",
    "created_by": "$(whoami)",
    "backup_path": "$backup_dir"
}
EOF
    
    # Set secure permissions
    chmod -R 600 "$backup_dir"/*
    
    log_key_operation "SUCCESS" "BACKUP" "$key_type" "Backup created: $backup_dir"
    echo "$backup_dir"
}

rotate_secure_boot_keys() {
    local force_rotation="${1:-false}"
    
    log_key_operation "INFO" "ROTATE" "$KEY_TYPE_SECURE_BOOT" "Starting Secure Boot key rotation"
    
    local key_dir="/etc/systemd/boot/keys"
    local current_keys_backup
    
    # Check if rotation is needed
    if [[ "$force_rotation" != "true" ]]; then
        if [[ -f "$key_dir/PK.key" ]]; then
            local key_age_days=$(( ($(date +%s) - $(stat -c %Y "$key_dir/PK.key")) / 86400 ))
            if [[ $key_age_days -lt $KEY_ROTATION_INTERVAL_DAYS ]]; then
                log_key_operation "INFO" "ROTATE" "$KEY_TYPE_SECURE_BOOT" "Keys are recent ($key_age_days days), skipping rotation"
                return 0
            fi
        fi
    fi
    
    # Create backup of current keys
    if [[ -d "$key_dir" ]]; then
        current_keys_backup=$(create_key_backup "$KEY_TYPE_SECURE_BOOT" "$key_dir" "pre-rotation")
    fi
    
    # Create temporary directory for new keys
    mkdir -p "$TEMP_KEY_DIR/secure-boot"
    cd "$TEMP_KEY_DIR/secure-boot"
    
    # Generate new Platform Key (PK)
    log_key_operation "INFO" "GENERATE" "$KEY_TYPE_SECURE_BOOT" "Generating new Platform Key"
    openssl genpkey -algorithm RSA -out PK.key -pkeyopt rsa_keygen_bits:4096
    openssl req -new -x509 -key PK.key -out PK.crt -days 3650 -subj "/CN=Hardened OS Platform Key/O=HardenedOS/C=US"
    
    # Generate new Key Exchange Key (KEK)
    log_key_operation "INFO" "GENERATE" "$KEY_TYPE_SECURE_BOOT" "Generating new Key Exchange Key"
    openssl genpkey -algorithm RSA -out KEK.key -pkeyopt rsa_keygen_bits:4096
    openssl req -new -x509 -key KEK.key -out KEK.crt -days 3650 -subj "/CN=Hardened OS Key Exchange Key/O=HardenedOS/C=US"
    
    # Generate new Database Key (DB)
    log_key_operation "INFO" "GENERATE" "$KEY_TYPE_SECURE_BOOT" "Generating new Database Key"
    openssl genpkey -algorithm RSA -out DB.key -pkeyopt rsa_keygen_bits:4096
    openssl req -new -x509 -key DB.key -out DB.crt -days 3650 -subj "/CN=Hardened OS Database Key/O=HardenedOS/C=US"
    
    # Set secure permissions
    chmod 600 *.key
    chmod 644 *.crt
    
    # Install new keys
    mkdir -p "$key_dir"
    cp *.key *.crt "$key_dir/"
    
    # Sign bootloader and kernel with new keys
    if command -v sbctl >/dev/null 2>&1; then
        log_key_operation "INFO" "SIGN" "$KEY_TYPE_SECURE_BOOT" "Signing bootloader and kernel with new keys"
        sbctl create-keys --database-key "$key_dir/DB.key" --database-cert "$key_dir/DB.crt"
        sbctl sign-all
    fi
    
    # Clean up temporary directory
    cd /
    rm -rf "$TEMP_KEY_DIR"
    
    log_key_operation "SUCCESS" "ROTATE" "$KEY_TYPE_SECURE_BOOT" "Secure Boot key rotation completed"
    
    # Create post-rotation backup
    create_key_backup "$KEY_TYPE_SECURE_BOOT" "$key_dir" "post-rotation"
    
    echo -e "${GREEN}✓ Secure Boot keys rotated successfully${NC}"
    echo -e "${YELLOW}⚠ System reboot required to activate new keys${NC}"
}

rotate_luks_keys() {
    local device="${1:-/dev/sda2}"
    local force_rotation="${2:-false}"
    
    log_key_operation "INFO" "ROTATE" "$KEY_TYPE_LUKS" "Starting LUKS key rotation for $device"
    
    # Check if device exists and is LUKS encrypted
    if ! cryptsetup isLuks "$device"; then
        log_key_operation "ERROR" "ROTATE" "$KEY_TYPE_LUKS" "Device is not LUKS encrypted: $device"
        return 1
    fi
    
    # Get current keyslot information
    local keyslot_info=$(cryptsetup luksDump "$device" | grep "Key Slot")
    log_key_operation "INFO" "ROTATE" "$KEY_TYPE_LUKS" "Current keyslots: $keyslot_info"
    
    # Generate new passphrase
    local new_passphrase=$(openssl rand -base64 32)
    local temp_passphrase_file="$TEMP_KEY_DIR/luks_passphrase"
    
    mkdir -p "$TEMP_KEY_DIR"
    echo "$new_passphrase" > "$temp_passphrase_file"
    chmod 600 "$temp_passphrase_file"
    
    # Add new keyslot
    log_key_operation "INFO" "ADD_KEY" "$KEY_TYPE_LUKS" "Adding new keyslot"
    if ! cryptsetup luksAddKey "$device" "$temp_passphrase_file"; then
        log_key_operation "ERROR" "ADD_KEY" "$KEY_TYPE_LUKS" "Failed to add new keyslot"
        rm -f "$temp_passphrase_file"
        return 1
    fi
    
    # Update TPM2 sealing with new passphrase if TPM is available
    if command -v systemd-cryptenroll >/dev/null 2>&1 && [[ -c /dev/tpm0 ]]; then
        log_key_operation "INFO" "TPM_SEAL" "$KEY_TYPE_LUKS" "Updating TPM2 sealing"
        systemd-cryptenroll --wipe-slot=tpm2 "$device" || true
        systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4+7 "$device" || true
    fi
    
    # Store new passphrase securely
    local passphrase_backup_dir="$KEY_BACKUP_DIR/$KEY_TYPE_LUKS/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$passphrase_backup_dir"
    chmod 700 "$passphrase_backup_dir"
    cp "$temp_passphrase_file" "$passphrase_backup_dir/passphrase"
    
    # Create recovery information
    cat > "$passphrase_backup_dir/recovery_info.txt" << EOF
LUKS Key Rotation Recovery Information
=====================================
Date: $(date -Iseconds)
Device: $device
New Passphrase: $new_passphrase
Hostname: $(hostname)

Recovery Instructions:
1. Boot from recovery media
2. Use this passphrase to unlock the device:
   cryptsetup luksOpen $device root --key-file=passphrase
3. If TPM unsealing fails, use manual passphrase entry

KEEP THIS INFORMATION SECURE AND OFFLINE
EOF
    
    chmod 600 "$passphrase_backup_dir"/*
    
    # Clean up temporary files
    rm -f "$temp_passphrase_file"
    
    log_key_operation "SUCCESS" "ROTATE" "$KEY_TYPE_LUKS" "LUKS key rotation completed"
    
    echo -e "${GREEN}✓ LUKS keys rotated successfully${NC}"
    echo -e "${YELLOW}⚠ New passphrase stored in: $passphrase_backup_dir${NC}"
    echo -e "${YELLOW}⚠ Test the new passphrase before removing old keyslots${NC}"
}

rotate_ssh_host_keys() {
    local force_rotation="${1:-false}"
    
    log_key_operation "INFO" "ROTATE" "$KEY_TYPE_SSH" "Starting SSH host key rotation"
    
    local ssh_key_dir="/etc/ssh"
    local key_types=("rsa" "ecdsa" "ed25519")
    
    # Create backup of current keys
    local current_keys_backup=$(create_key_backup "$KEY_TYPE_SSH" "$ssh_key_dir" "pre-rotation")
    
    # Generate new host keys
    for key_type in "${key_types[@]}"; do
        local key_file="$ssh_key_dir/ssh_host_${key_type}_key"
        
        log_key_operation "INFO" "GENERATE" "$KEY_TYPE_SSH" "Generating new $key_type host key"
        
        # Remove old key
        rm -f "$key_file" "$key_file.pub"
        
        # Generate new key
        case "$key_type" in
            "rsa")
                ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "$(hostname)-$key_type-$(date +%Y%m%d)"
                ;;
            "ecdsa")
                ssh-keygen -t ecdsa -b 521 -f "$key_file" -N "" -C "$(hostname)-$key_type-$(date +%Y%m%d)"
                ;;
            "ed25519")
                ssh-keygen -t ed25519 -f "$key_file" -N "" -C "$(hostname)-$key_type-$(date +%Y%m%d)"
                ;;
        esac
        
        # Set proper permissions
        chmod 600 "$key_file"
        chmod 644 "$key_file.pub"
    done
    
    # Restart SSH service
    log_key_operation "INFO" "RESTART" "$KEY_TYPE_SSH" "Restarting SSH service"
    systemctl restart ssh
    
    # Create post-rotation backup
    create_key_backup "$KEY_TYPE_SSH" "$ssh_key_dir" "post-rotation"
    
    log_key_operation "SUCCESS" "ROTATE" "$KEY_TYPE_SSH" "SSH host key rotation completed"
    
    echo -e "${GREEN}✓ SSH host keys rotated successfully${NC}"
    echo -e "${YELLOW}⚠ Update known_hosts files on client systems${NC}"
    
    # Display new key fingerprints
    echo -e "${BLUE}New SSH host key fingerprints:${NC}"
    for key_type in "${key_types[@]}"; do
        local key_file="$ssh_key_dir/ssh_host_${key_type}_key.pub"
        if [[ -f "$key_file" ]]; then
            echo "  $key_type: $(ssh-keygen -lf "$key_file")"
        fi
    done
}

rotate_tls_certificates() {
    local cert_path="${1:-/etc/ssl/certs/hardened-os.crt}"
    local key_path="${2:-/etc/ssl/private/hardened-os.key}"
    local force_rotation="${3:-false}"
    
    log_key_operation "INFO" "ROTATE" "$KEY_TYPE_TLS" "Starting TLS certificate rotation"
    
    # Check certificate expiration
    if [[ -f "$cert_path" ]] && [[ "$force_rotation" != "true" ]]; then
        local expiry_date=$(openssl x509 -in "$cert_path" -noout -enddate | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [[ $days_until_expiry -gt 30 ]]; then
            log_key_operation "INFO" "ROTATE" "$KEY_TYPE_TLS" "Certificate valid for $days_until_expiry days, skipping rotation"
            return 0
        fi
    fi
    
    # Create backup of current certificate
    if [[ -f "$cert_path" ]] && [[ -f "$key_path" ]]; then
        local cert_dir=$(dirname "$cert_path")
        create_key_backup "$KEY_TYPE_TLS" "$cert_dir" "pre-rotation"
    fi
    
    # Generate new private key
    log_key_operation "INFO" "GENERATE" "$KEY_TYPE_TLS" "Generating new TLS private key"
    mkdir -p "$(dirname "$key_path")"
    openssl genpkey -algorithm RSA -out "$key_path" -pkeyopt rsa_keygen_bits:4096
    chmod 600 "$key_path"
    
    # Generate new certificate
    log_key_operation "INFO" "GENERATE" "$KEY_TYPE_TLS" "Generating new TLS certificate"
    openssl req -new -x509 -key "$key_path" -out "$cert_path" -days 365 \
        -subj "/CN=$(hostname)/O=HardenedOS/C=US" \
        -addext "subjectAltName=DNS:$(hostname),DNS:localhost,IP:127.0.0.1"
    chmod 644 "$cert_path"
    
    # Restart services that use TLS certificates
    local tls_services=("apache2" "nginx" "hardened-log-server")
    for service in "${tls_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_key_operation "INFO" "RESTART" "$KEY_TYPE_TLS" "Restarting service: $service"
            systemctl restart "$service" || true
        fi
    done
    
    log_key_operation "SUCCESS" "ROTATE" "$KEY_TYPE_TLS" "TLS certificate rotation completed"
    
    echo -e "${GREEN}✓ TLS certificate rotated successfully${NC}"
    echo -e "${BLUE}New certificate details:${NC}"
    openssl x509 -in "$cert_path" -noout -subject -dates -fingerprint
}

emergency_key_revocation() {
    local key_type="$1"
    local revocation_reason="${2:-compromise}"
    
    log_key_operation "CRITICAL" "REVOKE" "$key_type" "Emergency key revocation initiated: $revocation_reason"
    
    case "$key_type" in
        "$KEY_TYPE_SECURE_BOOT")
            # Rotate Secure Boot keys immediately
            rotate_secure_boot_keys "true"
            
            # Add old keys to forbidden database if possible
            log_key_operation "CRITICAL" "REVOKE" "$key_type" "Secure Boot keys revoked and rotated"
            ;;
            
        "$KEY_TYPE_LUKS")
            # This requires manual intervention as we need the current passphrase
            log_key_operation "CRITICAL" "REVOKE" "$key_type" "LUKS key revocation requires manual intervention"
            echo -e "${RED}CRITICAL: LUKS key compromise detected${NC}"
            echo -e "${YELLOW}Manual steps required:${NC}"
            echo "1. Boot from recovery media"
            echo "2. Remove compromised keyslots: cryptsetup luksRemoveKey /dev/sda2"
            echo "3. Add new keyslot: cryptsetup luksAddKey /dev/sda2"
            echo "4. Update TPM sealing: systemd-cryptenroll --tpm2-device=auto /dev/sda2"
            ;;
            
        "$KEY_TYPE_SSH")
            # Rotate SSH keys and disable old ones
            rotate_ssh_host_keys "true"
            
            # Revoke user SSH keys if needed
            log_key_operation "CRITICAL" "REVOKE" "$key_type" "SSH host keys revoked and rotated"
            ;;
            
        "$KEY_TYPE_TLS")
            # Rotate TLS certificates immediately
            rotate_tls_certificates "" "" "true"
            log_key_operation "CRITICAL" "REVOKE" "$key_type" "TLS certificates revoked and rotated"
            ;;
            
        *)
            log_key_operation "ERROR" "REVOKE" "$key_type" "Unknown key type for revocation"
            return 1
            ;;
    esac
    
    # Create incident report
    local incident_report="/var/log/key-revocation-$(date +%Y%m%d_%H%M%S).txt"
    cat > "$incident_report" << EOF
EMERGENCY KEY REVOCATION REPORT
===============================
Timestamp: $(date -Iseconds)
Key Type: $key_type
Revocation Reason: $revocation_reason
Hostname: $(hostname)
Initiated By: $(whoami)

Actions Taken:
- Emergency key rotation performed
- Old keys backed up to: $KEY_BACKUP_DIR
- Services restarted as needed
- Incident logged to: $LOG_FILE

Next Steps:
1. Verify new keys are working correctly
2. Update client configurations if needed
3. Monitor for any authentication issues
4. Review security logs for compromise indicators
5. Consider forensic analysis if compromise suspected

This incident requires immediate attention and follow-up.
EOF
    
    chmod 600 "$incident_report"
    
    log_key_operation "CRITICAL" "REVOKE" "$key_type" "Emergency revocation completed. Report: $incident_report"
    
    echo -e "${RED}EMERGENCY KEY REVOCATION COMPLETED${NC}"
    echo -e "${YELLOW}Incident report: $incident_report${NC}"
}

check_key_expiration() {
    log_key_operation "INFO" "CHECK" "ALL" "Checking key expiration status"
    
    local expiring_keys=()
    local expired_keys=()
    
    # Check TLS certificates
    local cert_files=(
        "/etc/ssl/certs/hardened-os.crt"
        "/etc/ssl/certs/log-server.crt"
        "/etc/ssl/certs/journal-upload.crt"
    )
    
    for cert_file in "${cert_files[@]}"; do
        if [[ -f "$cert_file" ]]; then
            local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
            if [[ -n "$expiry_date" ]]; then
                local expiry_epoch=$(date -d "$expiry_date" +%s)
                local current_epoch=$(date +%s)
                local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
                
                if [[ $days_until_expiry -lt 0 ]]; then
                    expired_keys+=("$cert_file (expired $((days_until_expiry * -1)) days ago)")
                elif [[ $days_until_expiry -lt 30 ]]; then
                    expiring_keys+=("$cert_file (expires in $days_until_expiry days)")
                fi
            fi
        fi
    done
    
    # Check SSH host keys (by age, not expiration)
    local ssh_keys=("/etc/ssh/ssh_host_"*"_key")
    for ssh_key in "${ssh_keys[@]}"; do
        if [[ -f "$ssh_key" ]]; then
            local key_age_days=$(( ($(date +%s) - $(stat -c %Y "$ssh_key")) / 86400 ))
            if [[ $key_age_days -gt $KEY_ROTATION_INTERVAL_DAYS ]]; then
                expiring_keys+=("$ssh_key (age: $key_age_days days)")
            fi
        fi
    done
    
    # Report findings
    if [[ ${#expired_keys[@]} -gt 0 ]]; then
        log_key_operation "CRITICAL" "CHECK" "EXPIRED" "Found expired keys: ${expired_keys[*]}"
        echo -e "${RED}EXPIRED KEYS FOUND:${NC}"
        printf '%s\n' "${expired_keys[@]}"
        echo ""
    fi
    
    if [[ ${#expiring_keys[@]} -gt 0 ]]; then
        log_key_operation "WARN" "CHECK" "EXPIRING" "Found expiring keys: ${expiring_keys[*]}"
        echo -e "${YELLOW}EXPIRING KEYS:${NC}"
        printf '%s\n' "${expiring_keys[@]}"
        echo ""
    fi
    
    if [[ ${#expired_keys[@]} -eq 0 ]] && [[ ${#expiring_keys[@]} -eq 0 ]]; then
        log_key_operation "INFO" "CHECK" "ALL" "All keys are current"
        echo -e "${GREEN}✓ All keys are current${NC}"
    fi
    
    return $(( ${#expired_keys[@]} + ${#expiring_keys[@]} ))
}

cleanup_old_key_backups() {
    local retention_days="${1:-$KEY_BACKUP_RETENTION_DAYS}"
    
    log_key_operation "INFO" "CLEANUP" "BACKUPS" "Cleaning up key backups older than $retention_days days"
    
    if [[ ! -d "$KEY_BACKUP_DIR" ]]; then
        return 0
    fi
    
    local deleted_count=0
    
    find "$KEY_BACKUP_DIR" -type d -name "20*" -mtime +$retention_days | while read -r old_backup; do
        log_key_operation "INFO" "CLEANUP" "BACKUPS" "Removing old backup: $old_backup"
        rm -rf "$old_backup"
        ((deleted_count++))
    done
    
    log_key_operation "INFO" "CLEANUP" "BACKUPS" "Cleanup completed: $deleted_count backups removed"
}

show_key_status() {
    echo -e "${BLUE}Key Management Status${NC}"
    echo "====================="
    echo ""
    
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Rotation Interval: ${KEY_ROTATION_INTERVAL_DAYS} days"
    echo "  Emergency Rotation: ${EMERGENCY_ROTATION_ENABLED}"
    echo "  Backup Retention: ${KEY_BACKUP_RETENTION_DAYS} days"
    echo "  HSM Enabled: ${HSM_ENABLED}"
    echo ""
    
    echo -e "${YELLOW}Key Status:${NC}"
    check_key_expiration >/dev/null
    
    echo -e "${YELLOW}Backup Status:${NC}"
    if [[ -d "$KEY_BACKUP_DIR" ]]; then
        local backup_count=$(find "$KEY_BACKUP_DIR" -type d -name "20*" | wc -l)
        echo "  Total backups: $backup_count"
        
        if [[ $backup_count -gt 0 ]]; then
            local latest_backup=$(find "$KEY_BACKUP_DIR" -type d -name "20*" | sort | tail -1)
            local backup_age_days=$(( ($(date +%s) - $(stat -c %Y "$latest_backup")) / 86400 ))
            echo "  Latest backup: $backup_age_days days ago"
        fi
    else
        echo "  No backup directory found"
    fi
}

main() {
    load_config
    
    case "${1:-status}" in
        "help"|"-h"|"--help")
            echo "Hardened OS Key Rotation and Management"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  rotate <type> [force]    Rotate keys (secure-boot|luks|ssh|tls|all)"
            echo "  revoke <type> [reason]   Emergency key revocation"
            echo "  check                    Check key expiration status"
            echo "  backup <type> <path>     Create key backup"
            echo "  cleanup [days]           Remove old key backups"
            echo "  status                   Show key management status"
            echo "  help                     Show this help message"
            echo ""
            echo "Key Types:"
            echo "  secure-boot - UEFI Secure Boot keys (PK, KEK, DB)"
            echo "  luks        - LUKS disk encryption keys"
            echo "  ssh         - SSH host keys"
            echo "  tls         - TLS/SSL certificates"
            echo ""
            echo "Configuration file: $CONFIG_FILE"
            echo "Log file: $LOG_FILE"
            return 0
            ;;
    esac
    
    # Create necessary directories (only for non-help commands)
    mkdir -p "$KEY_BACKUP_DIR"
    chmod 700 "$KEY_BACKUP_DIR"
    
    case "${1:-status}" in
        "rotate")
            case "${2:-all}" in
                "secure-boot") rotate_secure_boot_keys "${3:-false}" ;;
                "luks") rotate_luks_keys "${3:-/dev/sda2}" "${4:-false}" ;;
                "ssh") rotate_ssh_host_keys "${3:-false}" ;;
                "tls") rotate_tls_certificates "${3:-}" "${4:-}" "${5:-false}" ;;
                "all")
                    rotate_secure_boot_keys "${3:-false}"
                    rotate_luks_keys "/dev/sda2" "${3:-false}"
                    rotate_ssh_host_keys "${3:-false}"
                    rotate_tls_certificates "" "" "${3:-false}"
                    ;;
                *) echo "Unknown key type: $2"; exit 1 ;;
            esac
            ;;
        "revoke")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 revoke <key_type> [reason]"
                exit 1
            fi
            emergency_key_revocation "$2" "${3:-compromise}"
            ;;
        "check")
            check_key_expiration
            ;;
        "backup")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 backup <key_type> <key_path> [reason]"
                exit 1
            fi
            create_key_backup "$2" "$3" "${4:-manual}"
            ;;
        "cleanup")
            cleanup_old_key_backups "${2:-$KEY_BACKUP_RETENTION_DAYS}"
            ;;
        "status")
            show_key_status
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"