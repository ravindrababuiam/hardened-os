#!/bin/bash
# Installation script for the complete tamper-evident logging system

set -euo pipefail

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_requirements() {
    log_step "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check for required packages
    local required_packages=(
        "systemd"
        "auditd"
        "openssl"
        "python3"
        "python3-pip"
    )
    
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_info "Installing missing packages: ${missing_packages[*]}"
        apt-get update
        apt-get install -y "${missing_packages[@]}"
    fi
    
    # Install Python dependencies for log server
    pip3 install aiohttp aiofiles cryptography
    
    log_info "System requirements satisfied"
}

install_logging_components() {
    log_step "Installing logging system components..."
    
    # Make setup script executable
    chmod +x "$SCRIPT_DIR/setup-journal-signing.sh"
    
    # Run the main setup script
    "$SCRIPT_DIR/setup-journal-signing.sh"
    
    log_info "Logging components installed successfully"
}

configure_log_server() {
    log_step "Configuring secure log server..."
    
    # Create log server directory
    mkdir -p /opt/hardened-os/log-server
    mkdir -p /etc/log-server/client-keys
    mkdir -p /var/log/remote
    
    # Copy log server script
    cp "$SCRIPT_DIR/log-server-config.py" /opt/hardened-os/log-server/
    chmod +x /opt/hardened-os/log-server/log-server-config.py
    
    # Create log server configuration
    cat > /etc/log-server/config.json << 'EOF'
{
    "host": "0.0.0.0",
    "port": 8443,
    "storage_path": "/var/log/remote",
    "cert_file": "/etc/ssl/certs/log-server.crt",
    "key_file": "/etc/ssl/private/log-server.key",
    "ca_file": "/etc/ssl/certs/ca.crt",
    "max_log_size": 104857600,
    "retention_days": 90
}
EOF
    
    # Create systemd service for log server
    cat > /etc/systemd/system/hardened-log-server.service << 'EOF'
[Unit]
Description=Hardened OS Secure Log Server
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/hardened-os/log-server/log-server-config.py
Restart=always
RestartSec=10
User=root
Group=root

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log/remote /etc/log-server

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable hardened-log-server.service
    
    log_info "Log server configured"
}

setup_log_rotation() {
    log_step "Setting up log rotation..."
    
    # Configure logrotate for journal files
    cat > /etc/logrotate.d/hardened-journal << 'EOF'
/var/log/journal/*/*.journal {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 systemd-journal systemd-journal
    postrotate
        systemctl reload systemd-journald
    endscript
}
EOF
    
    # Configure logrotate for audit logs
    cat > /etc/logrotate.d/hardened-audit << 'EOF'
/var/log/audit/audit.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
    postrotate
        /sbin/service auditd restart
    endscript
}
EOF
    
    # Configure logrotate for remote logs
    cat > /etc/logrotate.d/hardened-remote << 'EOF'
/var/log/remote/*/*.log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}
EOF
    
    log_info "Log rotation configured"
}

create_monitoring_scripts() {
    log_step "Creating monitoring and alerting scripts..."
    
    # Create log monitoring script
    cat > /usr/local/bin/monitor-log-integrity << 'EOF'
#!/bin/bash
# Monitor log integrity and send alerts on tampering detection

set -euo pipefail

ALERT_EMAIL="${ALERT_EMAIL:-root@localhost}"
LOG_FILE="/var/log/log-integrity-monitor.log"

log_alert() {
    local message="$1"
    echo "$(date -Iseconds): ALERT - $message" >> "$LOG_FILE"
    echo "$message" | mail -s "Log Integrity Alert" "$ALERT_EMAIL" 2>/dev/null || true
    logger -p auth.crit "LOG_INTEGRITY_ALERT: $message"
}

check_journal_integrity() {
    local failed_journals=()
    
    while IFS= read -r -d '' journal_file; do
        if ! journalctl --verify --file="$journal_file" >/dev/null 2>&1; then
            failed_journals+=("$journal_file")
        fi
    done < <(find /var/log/journal -name "*.journal" -type f -print0)
    
    if [[ ${#failed_journals[@]} -gt 0 ]]; then
        log_alert "Journal integrity check failed for: ${failed_journals[*]}"
        return 1
    fi
    
    return 0
}

check_audit_integrity() {
    # Check for audit log tampering indicators
    if ausearch -ts recent -m INTEGRITY_RULE >/dev/null 2>&1; then
        log_alert "Audit integrity violation detected"
        return 1
    fi
    
    return 0
}

main() {
    echo "$(date -Iseconds): Starting log integrity monitoring..." >> "$LOG_FILE"
    
    if check_journal_integrity && check_audit_integrity; then
        echo "$(date -Iseconds): Log integrity check passed" >> "$LOG_FILE"
    else
        echo "$(date -Iseconds): Log integrity check FAILED" >> "$LOG_FILE"
        exit 1
    fi
}

main "$@"
EOF
    
    chmod +x /usr/local/bin/monitor-log-integrity
    
    # Create systemd timer for monitoring
    cat > /etc/systemd/system/log-integrity-monitor.service << 'EOF'
[Unit]
Description=Log Integrity Monitoring
After=systemd-journald.service auditd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/monitor-log-integrity
User=root
Group=root
EOF
    
    cat > /etc/systemd/system/log-integrity-monitor.timer << 'EOF'
[Unit]
Description=Run log integrity monitoring every 30 minutes
Requires=log-integrity-monitor.service

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    systemctl enable log-integrity-monitor.timer
    
    log_info "Monitoring scripts created"
}

start_services() {
    log_step "Starting logging services..."
    
    # Restart systemd-journald with new configuration
    systemctl restart systemd-journald
    
    # Start and enable auditd
    systemctl enable auditd
    systemctl start auditd
    
    # Start integrity check timer
    systemctl start journal-integrity-check.timer
    
    # Start monitoring timer
    systemctl start log-integrity-monitor.timer
    
    # Start log server (if certificates are available)
    if [[ -f /etc/ssl/certs/log-server.crt ]] && [[ -f /etc/ssl/private/log-server.key ]]; then
        systemctl start hardened-log-server.service
        log_info "Log server started"
    else
        log_warn "Log server certificates not found. Configure certificates and start manually:"
        log_warn "systemctl start hardened-log-server.service"
    fi
    
    # Start journal upload (if configured)
    if [[ -f /etc/ssl/certs/journal-upload.crt ]] && [[ -f /etc/ssl/private/journal-upload.key ]]; then
        systemctl start systemd-journal-upload.service
        log_info "Journal upload started"
    else
        log_warn "Journal upload certificates not found. Configure certificates and start manually:"
        log_warn "systemctl start systemd-journal-upload.service"
    fi
    
    log_info "Logging services started"
}

verify_installation() {
    log_step "Verifying installation..."
    
    # Check service status
    local services=(
        "systemd-journald"
        "auditd"
        "journal-integrity-check.timer"
        "log-integrity-monitor.timer"
    )
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_error "Failed services: ${failed_services[*]}"
        return 1
    fi
    
    # Test journal signing
    if journalctl --verify >/dev/null 2>&1; then
        log_info "Journal signing verification: PASS"
    else
        log_warn "Journal signing verification: FAIL (may be normal for new installation)"
    fi
    
    # Test audit system
    if auditctl -l >/dev/null 2>&1; then
        log_info "Audit system: ACTIVE"
    else
        log_error "Audit system: INACTIVE"
        return 1
    fi
    
    log_info "Installation verification completed successfully"
    return 0
}

print_summary() {
    log_step "Installation Summary"
    
    echo -e "${GREEN}Tamper-evident logging system installed successfully!${NC}"
    echo ""
    echo "Components installed:"
    echo "  ✓ Systemd journal with cryptographic signing"
    echo "  ✓ Comprehensive audit rules"
    echo "  ✓ Log integrity verification"
    echo "  ✓ Secure remote log server"
    echo "  ✓ Automated monitoring and alerting"
    echo "  ✓ Log rotation and retention policies"
    echo ""
    echo "Next steps:"
    echo "  1. Configure log server certificates for remote logging"
    echo "  2. Set up client certificates for journal upload"
    echo "  3. Configure email alerts in /usr/local/bin/monitor-log-integrity"
    echo "  4. Test log forwarding: systemctl start systemd-journal-upload"
    echo "  5. Monitor logs: journalctl -f"
    echo ""
    echo "Useful commands:"
    echo "  - Verify journal integrity: journalctl --verify"
    echo "  - Check audit status: auditctl -s"
    echo "  - Analyze security events: /usr/local/bin/analyze-security-events"
    echo "  - Monitor integrity: /usr/local/bin/monitor-log-integrity"
}

main() {
    log_info "Starting tamper-evident logging system installation..."
    
    check_requirements
    install_logging_components
    configure_log_server
    setup_log_rotation
    create_monitoring_scripts
    start_services
    
    if verify_installation; then
        print_summary
    else
        log_error "Installation verification failed. Please check the logs and fix any issues."
        exit 1
    fi
}

main "$@"