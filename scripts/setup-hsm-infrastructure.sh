#!/bin/bash
# Production HSM-based signing infrastructure setup
# This script sets up Hardware Security Module integration for production signing

set -euo pipefail

# Configuration
HSM_CONFIG_DIR="/etc/hardened-os/hsm"
HSM_TOOLS_DIR="/opt/hsm-tools"
SIGNING_DIR="/opt/signing-infrastructure"
LOG_FILE="/var/log/hsm-setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_hsm_support() {
    log "Checking HSM support and available devices..."
    
    # Check for PKCS#11 support
    if ! command -v pkcs11-tool &> /dev/null; then
        log "Installing PKCS#11 tools..."
        apt-get update
        apt-get install -y opensc opensc-pkcs11 libengine-pkcs11-openssl
    fi
    
    # Check for available HSM devices
    log "Scanning for HSM devices..."
    pkcs11-tool --list-slots || warn "No HSM devices detected - will configure for future use"
    
    # Check for SoftHSM for testing/development
    if ! command -v softhsm2-util &> /dev/null; then
        log "Installing SoftHSM for development/testing..."
        apt-get install -y softhsm2
    fi
}

setup_hsm_directories() {
    log "Creating HSM infrastructure directories..."
    
    mkdir -p "$HSM_CONFIG_DIR"
    mkdir -p "$HSM_TOOLS_DIR"
    mkdir -p "$SIGNING_DIR"/{scripts,keys,policies,logs}
    
    # Set secure permissions
    chmod 700 "$HSM_CONFIG_DIR"
    chmod 700 "$SIGNING_DIR"
    chmod 755 "$HSM_TOOLS_DIR"
}

create_hsm_config() {
    log "Creating HSM configuration files..."
    
    cat > "$HSM_CONFIG_DIR/pkcs11.conf" << 'EOF'
# PKCS#11 Configuration for Production HSM
# Adjust paths and settings based on your HSM vendor

# SoftHSM configuration (for development/testing)
softhsm2 {
    library = /usr/lib/softhsm/libsofthsm2.so
    slot = 0
    pin = "1234"
    so_pin = "5678"
}

# Example: Nitrokey HSM configuration
# nitrokey {
#     library = /usr/lib/opensc-pkcs11.so
#     slot = 0
#     pin = "648219"
# }

# Example: YubiKey PIV configuration  
# yubikey {
#     library = /usr/lib/x86_64-linux-gnu/libykcs11.so
#     slot = 0
#     pin = "123456"
# }

# Example: AWS CloudHSM configuration
# cloudhsm {
#     library = /opt/cloudhsm/lib/libcloudhsm_pkcs11.so
#     slot = 0
#     pin = "user:password"
# }
EOF

    cat > "$HSM_CONFIG_DIR/signing-policy.yaml" << 'EOF'
# Production Signing Policy Configuration
signing_policy:
  # Key hierarchy and usage
  keys:
    root_key:
      type: "RSA-4096"
      usage: ["sign"]
      hsm_required: true
      backup_required: true
      rotation_period: "2 years"
      
    platform_key:
      type: "RSA-2048" 
      usage: ["sign"]
      hsm_required: true
      parent: "root_key"
      rotation_period: "1 year"
      
    kek_key:
      type: "RSA-2048"
      usage: ["sign"]
      hsm_required: true
      parent: "platform_key"
      rotation_period: "6 months"
      
    db_key:
      type: "RSA-2048"
      usage: ["sign"]
      hsm_required: true
      parent: "kek_key"
      rotation_period: "3 months"

  # Signing requirements
  signing_requirements:
    minimum_approvers: 2
    air_gap_required: true
    audit_logging: true
    timestamp_required: true
    
  # Emergency procedures
  emergency:
    revocation_threshold: 1
    emergency_contacts: []
    incident_response_plan: "/opt/signing-infrastructure/incident-response.md"
EOF

    chmod 600 "$HSM_CONFIG_DIR"/*
}

setup_softhsm_dev() {
    log "Setting up SoftHSM for development/testing..."
    
    # Initialize SoftHSM token
    export SOFTHSM2_CONF="$HSM_CONFIG_DIR/softhsm2.conf"
    
    cat > "$HSM_CONFIG_DIR/softhsm2.conf" << EOF
directories.tokendir = $HSM_CONFIG_DIR/tokens/
objectstore.backend = file
log.level = INFO
slots.removable = false
EOF

    mkdir -p "$HSM_CONFIG_DIR/tokens"
    chmod 700 "$HSM_CONFIG_DIR/tokens"
    
    # Initialize token
    softhsm2-util --init-token --slot 0 --label "HardenedOS-Dev" --so-pin 5678 --pin 1234
    
    log "SoftHSM development token initialized"
}

create_signing_scripts() {
    log "Creating production signing scripts..."
    
    cat > "$SIGNING_DIR/scripts/hsm-sign.sh" << 'EOF'
#!/bin/bash
# HSM-based signing script for production releases
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HSM_CONFIG="/etc/hardened-os/hsm/pkcs11.conf"
AUDIT_LOG="/var/log/hsm-signing.log"

usage() {
    echo "Usage: $0 [options] <file-to-sign>"
    echo "Options:"
    echo "  -k, --key-id ID     HSM key identifier"
    echo "  -t, --token TOKEN   HSM token name"
    echo "  -p, --pin PIN       HSM PIN (or use HSM_PIN env var)"
    echo "  -o, --output FILE   Output signature file"
    echo "  -h, --help          Show this help"
    exit 1
}

audit_log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" >> "$AUDIT_LOG"
}

# Parse arguments
KEY_ID=""
TOKEN=""
PIN="${HSM_PIN:-}"
OUTPUT=""
INPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--key-id)
            KEY_ID="$2"
            shift 2
            ;;
        -t|--token)
            TOKEN="$2"
            shift 2
            ;;
        -p|--pin)
            PIN="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$INPUT" ]]; then
                INPUT="$1"
            else
                echo "Error: Multiple input files specified"
                usage
            fi
            shift
            ;;
    esac
done

# Validate required parameters
if [[ -z "$INPUT" || -z "$KEY_ID" || -z "$TOKEN" ]]; then
    echo "Error: Missing required parameters"
    usage
fi

if [[ -z "$PIN" ]]; then
    echo "Error: HSM PIN required (use -p or HSM_PIN environment variable)"
    exit 1
fi

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT}.sig"
fi

# Verify input file exists
if [[ ! -f "$INPUT" ]]; then
    echo "Error: Input file '$INPUT' not found"
    exit 1
fi

# Log signing attempt
audit_log "SIGNING_ATTEMPT: user=$(whoami) file=$INPUT key_id=$KEY_ID token=$TOKEN"

# Perform HSM signing
echo "Signing $INPUT with HSM key $KEY_ID..."
pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
    --token-label "$TOKEN" \
    --pin "$PIN" \
    --id "$KEY_ID" \
    --sign \
    --mechanism RSA-PKCS \
    --input-file "$INPUT" \
    --output-file "$OUTPUT"

if [[ $? -eq 0 ]]; then
    audit_log "SIGNING_SUCCESS: file=$INPUT output=$OUTPUT"
    echo "Signature created: $OUTPUT"
else
    audit_log "SIGNING_FAILURE: file=$INPUT"
    echo "Error: Signing failed"
    exit 1
fi
EOF

    chmod +x "$SIGNING_DIR/scripts/hsm-sign.sh"
}

create_key_management_tools() {
    log "Creating HSM key management tools..."
    
    cat > "$SIGNING_DIR/scripts/hsm-key-manager.sh" << 'EOF'
#!/bin/bash
# HSM Key Management Tool
set -euo pipefail

HSM_CONFIG="/etc/hardened-os/hsm/pkcs11.conf"
AUDIT_LOG="/var/log/hsm-key-management.log"

audit_log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" >> "$AUDIT_LOG"
}

list_tokens() {
    echo "Available HSM tokens:"
    pkcs11-tool --list-slots
}

list_keys() {
    local token="$1"
    local pin="$2"
    
    echo "Keys in token '$token':"
    pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
        --token-label "$token" \
        --pin "$pin" \
        --list-objects --type privkey
}

generate_key() {
    local token="$1"
    local pin="$2"
    local key_id="$3"
    local key_size="${4:-2048}"
    
    audit_log "KEY_GENERATION_ATTEMPT: token=$token key_id=$key_id size=$key_size user=$(whoami)"
    
    echo "Generating RSA-$key_size key with ID $key_id in token $token..."
    pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
        --token-label "$token" \
        --pin "$pin" \
        --keypairgen \
        --key-type RSA:$key_size \
        --id "$key_id" \
        --label "HardenedOS-Key-$key_id"
    
    if [[ $? -eq 0 ]]; then
        audit_log "KEY_GENERATION_SUCCESS: token=$token key_id=$key_id"
        echo "Key generated successfully"
    else
        audit_log "KEY_GENERATION_FAILURE: token=$token key_id=$key_id"
        echo "Error: Key generation failed"
        exit 1
    fi
}

backup_key() {
    local token="$1"
    local pin="$2"
    local key_id="$3"
    local backup_file="$4"
    
    audit_log "KEY_BACKUP_ATTEMPT: token=$token key_id=$key_id file=$backup_file user=$(whoami)"
    
    echo "Backing up key $key_id to $backup_file..."
    # Note: This is a simplified backup - real HSM backup procedures vary by vendor
    pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
        --token-label "$token" \
        --pin "$pin" \
        --id "$key_id" \
        --read-object \
        --type pubkey \
        --output-file "$backup_file.pub"
    
    audit_log "KEY_BACKUP_SUCCESS: token=$token key_id=$key_id file=$backup_file"
    echo "Public key backed up to $backup_file.pub"
    echo "WARNING: Private key backup requires HSM-specific procedures"
}

usage() {
    echo "Usage: $0 <command> [options]"
    echo "Commands:"
    echo "  list-tokens                    List available HSM tokens"
    echo "  list-keys TOKEN PIN            List keys in token"
    echo "  generate-key TOKEN PIN ID SIZE Generate new key pair"
    echo "  backup-key TOKEN PIN ID FILE   Backup key (public part)"
    exit 1
}

case "${1:-}" in
    list-tokens)
        list_tokens
        ;;
    list-keys)
        if [[ $# -ne 3 ]]; then
            echo "Usage: $0 list-keys TOKEN PIN"
            exit 1
        fi
        list_keys "$2" "$3"
        ;;
    generate-key)
        if [[ $# -lt 4 ]]; then
            echo "Usage: $0 generate-key TOKEN PIN ID [SIZE]"
            exit 1
        fi
        generate_key "$2" "$3" "$4" "${5:-2048}"
        ;;
    backup-key)
        if [[ $# -ne 5 ]]; then
            echo "Usage: $0 backup-key TOKEN PIN ID FILE"
            exit 1
        fi
        backup_key "$2" "$3" "$4" "$5"
        ;;
    *)
        usage
        ;;
esac
EOF

    chmod +x "$SIGNING_DIR/scripts/hsm-key-manager.sh"
}

create_air_gap_procedures() {
    log "Creating air-gapped signing procedures..."
    
    cat > "$SIGNING_DIR/air-gap-signing-procedure.md" << 'EOF'
# Air-Gapped Signing Procedure

## Overview
This document describes the procedure for performing cryptographic signing operations in an air-gapped environment using HSM-protected keys.

## Prerequisites
- Air-gapped signing workstation with HSM support
- Production HSM device with signing keys
- Authorized signing personnel (minimum 2 approvers)
- Secure transfer media (encrypted USB drives)

## Procedure

### 1. Preparation Phase
1. Verify air-gap status of signing workstation
   ```bash
   # Ensure no network interfaces are active
   ip link show
   # Should show only loopback interface
   ```

2. Connect and verify HSM device
   ```bash
   # List available HSM tokens
   ./hsm-key-manager.sh list-tokens
   
   # Verify key availability
   ./hsm-key-manager.sh list-keys "HardenedOS-Prod" "$HSM_PIN"
   ```

3. Transfer files to be signed via secure media
   - Mount encrypted USB drive
   - Verify file integrity using checksums
   - Copy files to signing workstation

### 2. Signing Phase
1. Verify file integrity
   ```bash
   # Check SHA-256 checksums
   sha256sum -c files.sha256
   ```

2. Perform dual-person authorization
   - First approver: Verify signing request and file contents
   - Second approver: Independently verify and authorize
   - Both approvers must be present during signing

3. Execute signing operation
   ```bash
   # Sign with production HSM key
   ./hsm-sign.sh -t "HardenedOS-Prod" -k "01" -p "$HSM_PIN" \
                 -o "release.sig" "release-image.iso"
   ```

4. Verify signature
   ```bash
   # Verify signature was created correctly
   openssl dgst -sha256 -verify pubkey.pem -signature release.sig release-image.iso
   ```

### 3. Transfer Phase
1. Copy signed files and signatures to secure media
2. Generate transfer manifest
   ```bash
   # Create manifest of signed files
   find . -name "*.sig" -exec sha256sum {} \; > transfer-manifest.sha256
   ```

3. Securely erase temporary files
   ```bash
   # Secure deletion of temporary files
   shred -vfz -n 3 temp-files/*
   ```

4. Transfer signed artifacts to connected systems

## Security Controls
- All operations logged to tamper-evident audit log
- HSM PIN never stored on disk
- Dual-person authorization required
- Air-gap verified before each signing session
- Secure media encrypted with unique keys per session

## Emergency Procedures
- Key compromise: Follow key revocation procedure
- HSM failure: Use backup HSM with escrowed keys
- Personnel unavailable: Use emergency key holders (3 of 5 threshold)
EOF

    cat > "$SIGNING_DIR/incident-response.md" << 'EOF'
# HSM Incident Response Plan

## Incident Types

### 1. Key Compromise
**Indicators:**
- Unauthorized signatures detected
- HSM access logs show suspicious activity
- Key material potentially exposed

**Response:**
1. Immediately revoke compromised keys
2. Generate new key hierarchy
3. Re-sign all affected artifacts
4. Notify all stakeholders
5. Conduct forensic analysis

### 2. HSM Hardware Failure
**Indicators:**
- HSM device unresponsive
- Cryptographic operations failing
- Hardware error messages

**Response:**
1. Switch to backup HSM
2. Restore keys from secure backup
3. Verify key integrity
4. Resume signing operations
5. Replace failed HSM

### 3. Unauthorized Access Attempt
**Indicators:**
- Failed authentication attempts
- Physical security breach
- Unusual access patterns

**Response:**
1. Lock down HSM access
2. Review audit logs
3. Verify key integrity
4. Investigate access attempt
5. Update security procedures

## Emergency Contacts
- Security Team: security@example.com
- HSM Vendor Support: support@hsm-vendor.com
- Incident Commander: incident-commander@example.com

## Recovery Procedures
Detailed in `/opt/signing-infrastructure/recovery-procedures.md`
EOF
}

setup_audit_logging() {
    log "Setting up HSM audit logging..."
    
    # Create audit log directory
    mkdir -p /var/log/hsm
    chmod 750 /var/log/hsm
    
    # Create rsyslog configuration for HSM logging
    cat > /etc/rsyslog.d/50-hsm-audit.conf << 'EOF'
# HSM Audit Logging Configuration
# Log HSM operations to separate file with high security

# HSM signing operations
:programname, isequal, "hsm-sign" /var/log/hsm/signing.log
:programname, isequal, "hsm-key-manager" /var/log/hsm/key-management.log

# Stop processing these messages
:programname, isequal, "hsm-sign" stop
:programname, isequal, "hsm-key-manager" stop
EOF

    # Create logrotate configuration
    cat > /etc/logrotate.d/hsm-audit << 'EOF'
/var/log/hsm/*.log {
    daily
    rotate 365
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl reload rsyslog
    endscript
}
EOF

    systemctl restart rsyslog
}

create_validation_tests() {
    log "Creating HSM validation tests..."
    
    cat > "$SIGNING_DIR/scripts/test-hsm-infrastructure.sh" << 'EOF'
#!/bin/bash
# HSM Infrastructure Validation Tests
set -euo pipefail

TEST_DIR="/tmp/hsm-test-$$"
TOKEN="HardenedOS-Dev"
PIN="1234"
TEST_KEY_ID="99"

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "=== HSM Infrastructure Validation Tests ==="

# Test 1: HSM Token Detection
echo "Test 1: HSM Token Detection"
if pkcs11-tool --list-slots | grep -q "$TOKEN"; then
    echo "✓ HSM token detected"
else
    echo "✗ HSM token not found"
    exit 1
fi

# Test 2: Key Generation
echo "Test 2: Key Generation"
if /opt/signing-infrastructure/scripts/hsm-key-manager.sh generate-key "$TOKEN" "$PIN" "$TEST_KEY_ID" 2048; then
    echo "✓ Key generation successful"
else
    echo "✗ Key generation failed"
    exit 1
fi

# Test 3: Signing Operation
echo "Test 3: Signing Operation"
echo "Test data for HSM signing" > test-file.txt
if /opt/signing-infrastructure/scripts/hsm-sign.sh -t "$TOKEN" -p "$PIN" -k "$TEST_KEY_ID" -o test-file.sig test-file.txt; then
    echo "✓ Signing operation successful"
else
    echo "✗ Signing operation failed"
    exit 1
fi

# Test 4: Signature Verification
echo "Test 4: Signature Verification"
# Extract public key for verification
pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
    --token-label "$TOKEN" \
    --pin "$PIN" \
    --id "$TEST_KEY_ID" \
    --read-object \
    --type pubkey \
    --output-file test-pubkey.der

# Convert to PEM format
openssl rsa -pubin -inform DER -in test-pubkey.der -outform PEM -out test-pubkey.pem

# Verify signature
if openssl dgst -sha256 -verify test-pubkey.pem -signature test-file.sig test-file.txt; then
    echo "✓ Signature verification successful"
else
    echo "✗ Signature verification failed"
    exit 1
fi

# Test 5: Audit Logging
echo "Test 5: Audit Logging"
if grep -q "SIGNING_SUCCESS" /var/log/hsm-signing.log; then
    echo "✓ Audit logging working"
else
    echo "✗ Audit logging not working"
    exit 1
fi

# Cleanup test key
pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
    --token-label "$TOKEN" \
    --pin "$PIN" \
    --id "$TEST_KEY_ID" \
    --delete-object \
    --type privkey

echo "=== All HSM tests passed! ==="
EOF

    chmod +x "$SIGNING_DIR/scripts/test-hsm-infrastructure.sh"
}

main() {
    log "Starting HSM infrastructure setup..."
    
    check_root
    check_hsm_support
    setup_hsm_directories
    create_hsm_config
    setup_softhsm_dev
    create_signing_scripts
    create_key_management_tools
    create_air_gap_procedures
    setup_audit_logging
    create_validation_tests
    
    log "HSM infrastructure setup completed successfully!"
    log "Next steps:"
    log "1. Configure production HSM device"
    log "2. Generate production key hierarchy"
    log "3. Test signing procedures"
    log "4. Set up air-gapped signing workstation"
    
    echo
    echo "Configuration files created:"
    echo "- HSM config: $HSM_CONFIG_DIR/"
    echo "- Signing scripts: $SIGNING_DIR/scripts/"
    echo "- Documentation: $SIGNING_DIR/*.md"
    echo
    echo "To test the setup:"
    echo "sudo $SIGNING_DIR/scripts/test-hsm-infrastructure.sh"
}

main "$@"