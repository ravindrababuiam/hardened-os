#!/bin/bash
#
# Development Signing Key Generation Script
# Generates Platform Keys (PK), Key Exchange Keys (KEK), and Database (DB) keys for development
# 
# WARNING: These are DEVELOPMENT keys only - NOT for production use
#

set -euo pipefail

# Configuration
KEYS_DIR="$HOME/harden/keys"
KEY_SIZE=2048
VALIDITY_DAYS=3650  # 10 years for development keys

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check dependencies
check_dependencies() {
    local deps=("openssl" "sbctl" "efitools")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install openssl sbctl efi-tools"
        exit 1
    fi
}

# Create key directory structure
setup_key_directories() {
    log_info "Setting up key directory structure..."
    
    mkdir -p "$KEYS_DIR"/{dev,recovery,backup}
    mkdir -p "$KEYS_DIR"/dev/{PK,KEK,DB}
    
    # Set restrictive permissions
    chmod 700 "$KEYS_DIR"
    chmod 700 "$KEYS_DIR"/{dev,recovery,backup}
    chmod 700 "$KEYS_DIR"/dev/{PK,KEK,DB}
    
    log_info "Key directories created with secure permissions"
}

# Generate Platform Key (PK) - Root of trust
generate_platform_key() {
    local pk_dir="$KEYS_DIR/dev/PK"
    
    log_info "Generating Platform Key (PK)..."
    
    # Generate private key
    openssl genrsa -out "$pk_dir/PK.key" $KEY_SIZE
    chmod 600 "$pk_dir/PK.key"
    
    # Create certificate
    openssl req -new -x509 -key "$pk_dir/PK.key" \
        -out "$pk_dir/PK.crt" \
        -days $VALIDITY_DAYS \
        -subj "/CN=Hardened OS Development Platform Key/O=Development/C=US" \
        -sha256
    
    # Convert to DER format for UEFI
    openssl x509 -in "$pk_dir/PK.crt" -out "$pk_dir/PK.der" -outform DER
    
    # Create EFI signature list
    cert-to-efi-sig-list -g "$(uuidgen)" "$pk_dir/PK.crt" "$pk_dir/PK.esl"
    
    # Sign the signature list (self-signed for PK)
    sign-efi-sig-list -k "$pk_dir/PK.key" -c "$pk_dir/PK.crt" PK "$pk_dir/PK.esl" "$pk_dir/PK.auth"
    
    log_info "Platform Key generated successfully"
}

# Generate Key Exchange Key (KEK)
generate_kek() {
    local kek_dir="$KEYS_DIR/dev/KEK"
    local pk_dir="$KEYS_DIR/dev/PK"
    
    log_info "Generating Key Exchange Key (KEK)..."
    
    # Generate private key
    openssl genrsa -out "$kek_dir/KEK.key" $KEY_SIZE
    chmod 600 "$kek_dir/KEK.key"
    
    # Create certificate
    openssl req -new -x509 -key "$kek_dir/KEK.key" \
        -out "$kek_dir/KEK.crt" \
        -days $VALIDITY_DAYS \
        -subj "/CN=Hardened OS Development KEK/O=Development/C=US" \
        -sha256
    
    # Convert to DER format
    openssl x509 -in "$kek_dir/KEK.crt" -out "$kek_dir/KEK.der" -outform DER
    
    # Create EFI signature list
    cert-to-efi-sig-list -g "$(uuidgen)" "$kek_dir/KEK.crt" "$kek_dir/KEK.esl"
    
    # Sign with Platform Key
    sign-efi-sig-list -k "$pk_dir/PK.key" -c "$pk_dir/PK.crt" KEK "$kek_dir/KEK.esl" "$kek_dir/KEK.auth"
    
    log_info "Key Exchange Key generated successfully"
}

# Generate Database Key (DB)
generate_db_key() {
    local db_dir="$KEYS_DIR/dev/DB"
    local kek_dir="$KEYS_DIR/dev/KEK"
    
    log_info "Generating Database Key (DB)..."
    
    # Generate private key
    openssl genrsa -out "$db_dir/DB.key" $KEY_SIZE
    chmod 600 "$db_dir/DB.key"
    
    # Create certificate
    openssl req -new -x509 -key "$db_dir/DB.key" \
        -out "$db_dir/DB.crt" \
        -days $VALIDITY_DAYS \
        -subj "/CN=Hardened OS Development DB/O=Development/C=US" \
        -sha256
    
    # Convert to DER format
    openssl x509 -in "$db_dir/DB.crt" -out "$db_dir/DB.der" -outform DER
    
    # Create EFI signature list
    cert-to-efi-sig-list -g "$(uuidgen)" "$db_dir/DB.crt" "$db_dir/DB.esl"
    
    # Sign with KEK
    sign-efi-sig-list -k "$kek_dir/KEK.key" -c "$kek_dir/KEK.crt" db "$db_dir/DB.esl" "$db_dir/DB.auth"
    
    log_info "Database Key generated successfully"
}

# Create key backup
create_key_backup() {
    local backup_dir="$KEYS_DIR/backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/dev_keys_backup_$timestamp.tar.gz"
    
    log_info "Creating encrypted key backup..."
    
    # Create encrypted backup
    tar -czf - -C "$KEYS_DIR" dev | gpg --symmetric --cipher-algo AES256 --output "$backup_file.gpg"
    
    # Create unencrypted backup for development convenience (with warning)
    tar -czf "$backup_file" -C "$KEYS_DIR" dev
    
    chmod 600 "$backup_file"*
    
    log_warn "Backup created at: $backup_file"
    log_warn "Encrypted backup: $backup_file.gpg"
    log_warn "DEVELOPMENT ONLY - Store production backups securely offline"
}

# Generate key fingerprints and metadata
generate_key_metadata() {
    local metadata_file="$KEYS_DIR/dev/key_metadata.json"
    
    log_info "Generating key metadata..."
    
    cat > "$metadata_file" << EOF
{
  "generated": "$(date -Iseconds)",
  "purpose": "development",
  "warning": "DEVELOPMENT KEYS ONLY - NOT FOR PRODUCTION",
  "keys": {
    "PK": {
      "subject": "$(openssl x509 -in "$KEYS_DIR/dev/PK/PK.crt" -noout -subject)",
      "fingerprint": "$(openssl x509 -in "$KEYS_DIR/dev/PK/PK.crt" -noout -fingerprint -sha256)",
      "expires": "$(openssl x509 -in "$KEYS_DIR/dev/PK/PK.crt" -noout -enddate)"
    },
    "KEK": {
      "subject": "$(openssl x509 -in "$KEYS_DIR/dev/KEK/KEK.crt" -noout -subject)",
      "fingerprint": "$(openssl x509 -in "$KEYS_DIR/dev/KEK/KEK.crt" -noout -fingerprint -sha256)",
      "expires": "$(openssl x509 -in "$KEYS_DIR/dev/KEK/KEK.crt" -noout -enddate)"
    },
    "DB": {
      "subject": "$(openssl x509 -in "$KEYS_DIR/dev/DB/DB.crt" -noout -subject)",
      "fingerprint": "$(openssl x509 -in "$KEYS_DIR/dev/DB/DB.crt" -noout -fingerprint -sha256)",
      "expires": "$(openssl x509 -in "$KEYS_DIR/dev/DB/DB.crt" -noout -enddate)"
    }
  }
}
EOF
    
    chmod 600 "$metadata_file"
    log_info "Key metadata saved to: $metadata_file"
}

# Main execution
main() {
    log_info "Starting development key generation..."
    log_warn "This will generate DEVELOPMENT keys only - NOT for production use"
    
    check_dependencies
    setup_key_directories
    generate_platform_key
    generate_kek
    generate_db_key
    generate_key_metadata
    create_key_backup
    
    log_info "Development signing keys generated successfully!"
    log_info "Keys location: $KEYS_DIR/dev/"
    log_warn "Remember: These are DEVELOPMENT keys - use HSM-backed keys for production"
}

# Run main function
main "$@"