#!/bin/bash
# Setup script for tamper-evident logging with cryptographic integrity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="/etc/systemd/journal-sign"
LOG_SERVER_CERTS="/etc/ssl/certs"
LOG_SERVER_KEYS="/etc/ssl/private"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

setup_journal_signing_keys() {
    log_info "Setting up journal signing keys..."
    
    # Create keys directory
    mkdir -p "$KEYS_DIR"
    chmod 700 "$KEYS_DIR"
    
    # Generate signing key if it doesn't exist
    if [[ ! -f "$KEYS_DIR/journal-sign.key" ]]; then
        log_info "Generating journal signing key..."
        openssl genpkey -algorithm RSA -pkcs8 -out "$KEYS_DIR/journal-sign.key" -pkeyopt rsa_keygen_bits:4096
        chmod 600 "$KEYS_DIR/journal-sign.key"
        
        # Generate corresponding public key
        openssl pkey -in "$KEYS_DIR/journal-sign.key" -pubout -out "$KEYS_DIR/journal-sign.pub"
        chmod 644 "$KEYS_DIR/journal-sign.pub"
        
        log_info "Journal signing keys generated successfully"
    else
        log_info "Journal signing keys already exist"
    fi
}

setup_log_forwarding_certs() {
    log_info "Setting up log forwarding certificates..."
    
    # Create certificate directories
    mkdir -p "$LOG_SERVER_CERTS" "$LOG_SERVER_KEYS"
    
    # Generate client certificate for log forwarding if it doesn't exist
    if [[ ! -f "$LOG_SERVER_KEYS/journal-upload.key" ]]; then
        log_info "Generating client certificate for log forwarding..."
        
        # Generate private key
        openssl genpkey -algorithm RSA -out "$LOG_SERVER_KEYS/journal-upload.key" -pkeyopt rsa_keygen_bits:4096
        chmod 600 "$LOG_SERVER_KEYS/journal-upload.key"
        
        # Generate certificate signing request
        openssl req -new -key "$LOG_SERVER_KEYS/journal-upload.key" \
            -out "/tmp/journal-upload.csr" \
            -subj "/C=US/ST=Security/L=Hardened/O=HardenedOS/OU=Logging/CN=journal-client"
        
        # Self-sign certificate (in production, use proper CA)
        openssl x509 -req -in "/tmp/journal-upload.csr" \
            -signkey "$LOG_SERVER_KEYS/journal-upload.key" \
            -out "$LOG_SERVER_CERTS/journal-upload.crt" \
            -days 365
        
        chmod 644 "$LOG_SERVER_CERTS/journal-upload.crt"
        rm "/tmp/journal-upload.csr"
        
        log_info "Client certificate generated successfully"
    else
        log_info "Client certificate already exists"
    fi
}

configure_systemd_journal() {
    log_info "Configuring systemd journal for signing..."
    
    # Create journal configuration directory
    mkdir -p /etc/systemd/journald.conf.d
    
    # Configure journal with signing enabled
    cat > /etc/systemd/journald.conf.d/99-hardened-signing.conf << 'EOF'
[Journal]
# Enable journal sealing (cryptographic signing)
Seal=yes

# Persistent storage
Storage=persistent

# Compress journal files
Compress=yes

# Forward to syslog for additional processing
ForwardToSyslog=no

# Maximum journal size (1GB)
SystemMaxUse=1G
SystemMaxFileSize=100M

# Keep journals for 30 days
MaxRetentionSec=30d

# Sync journal to disk frequently for integrity
SyncIntervalSec=5m
EOF

    log_info "Journal configuration updated"
}

setup_audit_system() {
    log_info "Setting up audit system..."
    
    # Install audit rules
    cp "$SCRIPT_DIR/audit-rules.conf" /etc/audit/rules.d/99-hardened-os.rules
    
    # Configure auditd
    cat > /etc/audit/auditd.conf << 'EOF'
# Audit daemon configuration for hardened OS

# Log file location
log_file = /var/log/audit/audit.log

# Log file permissions
log_format = ENRICHED
log_group = adm
priority_boost = 4
flush = INCREMENTAL_ASYNC
freq = 50
num_logs = 5
disp_qos = lossy
dispatcher = /sbin/audispd
name_format = HOSTNAME
max_log_file = 100
max_log_file_action = ROTATE
space_left = 500
space_left_action = SYSLOG
verify_email = yes
action_mail_acct = root
admin_space_left = 100
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
use_libwrap = yes
tcp_listen_queue = 5
tcp_max_per_addr = 1
tcp_client_max_idle = 0
enable_krb5 = no
krb5_principal = auditd
EOF

    # Enable and start auditd
    systemctl enable auditd
    
    log_info "Audit system configured"
}

setup_log_integrity_verification() {
    log_info "Setting up log integrity verification..."
    
    # Create verification script
    cat > /usr/local/bin/verify-journal-integrity << 'EOF'
#!/bin/bash
# Script to verify journal integrity and detect tampering

set -euo pipefail

JOURNAL_DIR="/var/log/journal"
VERIFICATION_LOG="/var/log/journal-verification.log"

log_result() {
    echo "$(date -Iseconds): $1" >> "$VERIFICATION_LOG"
    echo "$1"
}

verify_journal_seals() {
    local exit_code=0
    
    log_result "Starting journal integrity verification..."
    
    # Find all journal files
    find "$JOURNAL_DIR" -name "*.journal" -type f | while read -r journal_file; do
        if journalctl --verify --file="$journal_file" >/dev/null 2>&1; then
            log_result "PASS: $journal_file - integrity verified"
        else
            log_result "FAIL: $journal_file - integrity check failed"
            exit_code=1
        fi
    done
    
    if [[ $exit_code -eq 0 ]]; then
        log_result "Journal integrity verification completed successfully"
    else
        log_result "Journal integrity verification FAILED - potential tampering detected"
        # Send alert (implement notification mechanism)
        logger -p auth.crit "SECURITY ALERT: Journal tampering detected"
    fi
    
    return $exit_code
}

# Run verification
verify_journal_seals
EOF

    chmod +x /usr/local/bin/verify-journal-integrity
    
    # Create systemd timer for regular verification
    cat > /etc/systemd/system/journal-integrity-check.service << 'EOF'
[Unit]
Description=Journal Integrity Verification
After=systemd-journald.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/verify-journal-integrity
User=root
Group=systemd-journal
EOF

    cat > /etc/systemd/system/journal-integrity-check.timer << 'EOF'
[Unit]
Description=Run journal integrity check every hour
Requires=journal-integrity-check.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl enable journal-integrity-check.timer
    
    log_info "Log integrity verification configured"
}

setup_remote_logging() {
    log_info "Setting up remote logging..."
    
    # Copy journal upload configuration
    cp "$SCRIPT_DIR/journal-upload.conf" /etc/systemd/journal-upload.conf
    
    # Enable journal upload service
    systemctl enable systemd-journal-upload.service
    
    log_info "Remote logging configured"
}

create_log_analysis_tools() {
    log_info "Creating log analysis tools..."
    
    # Create security event analyzer
    cat > /usr/local/bin/analyze-security-events << 'EOF'
#!/bin/bash
# Analyze security events from journal and audit logs

set -euo pipefail

TIMEFRAME="${1:-1h}"

echo "Security Event Analysis - Last $TIMEFRAME"
echo "========================================"

# Authentication failures
echo -e "\n[Authentication Failures]"
journalctl --since="$TIMEFRAME ago" -u ssh.service -u systemd-logind.service | \
    grep -i "failed\|failure\|invalid" | tail -10

# SELinux denials
echo -e "\n[SELinux Denials]"
ausearch -ts recent -m avc 2>/dev/null | tail -10 || echo "No recent SELinux denials"

# Privilege escalation attempts
echo -e "\n[Privilege Escalation]"
ausearch -ts recent -k privileged 2>/dev/null | tail -10 || echo "No recent privilege escalation attempts"

# Network connections
echo -e "\n[Network Activity]"
journalctl --since="$TIMEFRAME ago" -u systemd-networkd.service | \
    grep -E "(up|down|configured)" | tail -10

# TPM events
echo -e "\n[TPM Events]"
journalctl --since="$TIMEFRAME ago" | grep -i tpm | tail -5 || echo "No recent TPM events"

# File system changes
echo -e "\n[File System Changes]"
ausearch -ts recent -k identity -k MAC-policy 2>/dev/null | tail -10 || echo "No recent critical file changes"
EOF

    chmod +x /usr/local/bin/analyze-security-events
    
    log_info "Log analysis tools created"
}

main() {
    log_info "Starting tamper-evident logging setup..."
    
    check_root
    setup_journal_signing_keys
    setup_log_forwarding_certs
    configure_systemd_journal
    setup_audit_system
    setup_log_integrity_verification
    setup_remote_logging
    create_log_analysis_tools
    
    log_info "Tamper-evident logging setup completed successfully!"
    log_info "Next steps:"
    log_info "1. Restart systemd-journald: systemctl restart systemd-journald"
    log_info "2. Start audit daemon: systemctl start auditd"
    log_info "3. Start integrity check timer: systemctl start journal-integrity-check.timer"
    log_info "4. Configure remote log server details in /etc/systemd/journal-upload.conf"
    log_info "5. Test log forwarding: systemctl start systemd-journal-upload"
}

main "$@"