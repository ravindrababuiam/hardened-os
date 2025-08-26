#!/bin/bash
# Installation script for the Incident Response and Recovery System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

check_requirements() {
    log_step "Checking system requirements..."
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check for required packages
    local required_packages=(
        "systemd"
        "openssl"
        "cryptsetup"
        "openssh-server"
        "auditd"
        "bc"
        "jq"
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
    
    log_info "System requirements satisfied"
}

install_incident_response_framework() {
    log_step "Installing incident response framework..."
    
    # Create directories
    mkdir -p /opt/hardened-os/incident-response
    mkdir -p /etc/hardened-os
    mkdir -p /var/log
    mkdir -p /var/backups/incident-recovery
    mkdir -p /var/recovery-points
    mkdir -p /var/quarantine
    mkdir -p /var/forensic
    mkdir -p /var/backups/keys
    
    # Copy scripts
    cp "$SCRIPT_DIR/incident-response-framework.sh" /opt/hardened-os/incident-response/
    cp "$SCRIPT_DIR/recovery-procedures.sh" /opt/hardened-os/incident-response/
    cp "$SCRIPT_DIR/key-rotation-procedures.sh" /opt/hardened-os/incident-response/
    
    # Make scripts executable
    chmod +x /opt/hardened-os/incident-response/*.sh
    
    # Create symlinks for easy access
    ln -sf /opt/hardened-os/incident-response/incident-response-framework.sh /usr/local/bin/incident-response
    ln -sf /opt/hardened-os/incident-response/recovery-procedures.sh /usr/local/bin/recovery-procedures
    ln -sf /opt/hardened-os/incident-response/key-rotation-procedures.sh /usr/local/bin/key-rotation
    
    log_info "Incident response framework installed"
}

create_configuration_files() {
    log_step "Creating configuration files..."
    
    # Incident response configuration
    cat > /etc/hardened-os/incident-response.conf << 'EOF'
# Incident Response Configuration
ALERT_EMAIL="root@localhost"
ALERT_WEBHOOK=""
AUTO_CONTAINMENT="true"
AUTO_RECOVERY="false"
FORENSIC_MODE="false"
EOF
    
    # Recovery configuration
    cat > /etc/hardened-os/recovery.conf << 'EOF'
# Recovery Configuration
BACKUP_RETENTION_DAYS="30"
AUTO_BACKUP_ENABLED="true"
RECOVERY_VERIFICATION="true"
FORENSIC_PRESERVATION="true"
EOF
    
    # Key rotation configuration
    cat > /etc/hardened-os/key-rotation.conf << 'EOF'
# Key Rotation Configuration
KEY_ROTATION_INTERVAL_DAYS="90"
EMERGENCY_ROTATION_ENABLED="true"
KEY_BACKUP_RETENTION_DAYS="365"
REQUIRE_CONFIRMATION="true"
HSM_ENABLED="false"
HSM_SLOT="0"
EOF
    
    # Set secure permissions
    chmod 600 /etc/hardened-os/*.conf
    
    log_info "Configuration files created"
}

setup_systemd_services() {
    log_step "Setting up systemd services..."
    
    # Incident response monitoring service
    cat > /etc/systemd/system/hardened-os-monitor.service << 'EOF'
[Unit]
Description=Hardened OS Security Monitoring
After=multi-user.target
Wants=network.target

[Service]
Type=simple
ExecStart=/opt/hardened-os/incident-response/incident-response-framework.sh scan all
Restart=always
RestartSec=300
User=root
Group=root

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log /var/quarantine /var/backups/incident-recovery

[Install]
WantedBy=multi-user.target
EOF
    
    # Incident response monitoring timer
    cat > /etc/systemd/system/hardened-os-monitor.timer << 'EOF'
[Unit]
Description=Run security monitoring every 15 minutes
Requires=hardened-os-monitor.service

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Recovery point creation service
    cat > /etc/systemd/system/recovery-point-create.service << 'EOF'
[Unit]
Description=Create System Recovery Point
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/hardened-os/incident-response/recovery-procedures.sh create "Scheduled recovery point"
User=root
Group=root

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/recovery-points /var/log
EOF
    
    # Recovery point creation timer (daily)
    cat > /etc/systemd/system/recovery-point-create.timer << 'EOF'
[Unit]
Description=Create daily recovery point
Requires=recovery-point-create.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Key expiration check service
    cat > /etc/systemd/system/key-expiration-check.service << 'EOF'
[Unit]
Description=Check Key Expiration Status
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/hardened-os/incident-response/key-rotation-procedures.sh check
User=root
Group=root

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log /var/backups/keys
EOF
    
    # Key expiration check timer (weekly)
    cat > /etc/systemd/system/key-expiration-check.timer << 'EOF'
[Unit]
Description=Check key expiration weekly
Requires=key-expiration-check.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable hardened-os-monitor.timer
    systemctl enable recovery-point-create.timer
    systemctl enable key-expiration-check.timer
    
    log_info "Systemd services configured"
}

create_incident_response_tools() {
    log_step "Creating incident response tools..."
    
    # Emergency lockdown script
    cat > /usr/local/bin/emergency-lockdown << 'EOF'
#!/bin/bash
# Emergency system lockdown
set -euo pipefail

echo "EMERGENCY LOCKDOWN INITIATED"
logger -p auth.crit "EMERGENCY_LOCKDOWN: System lockdown initiated by $(whoami)"

# Network isolation
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Stop non-essential services
systemctl stop NetworkManager || true
systemctl stop apache2 || true
systemctl stop nginx || true
systemctl stop mysql || true
systemctl stop postgresql || true

# Lock user accounts
while IFS=: read -r username _ uid _; do
    if [[ $uid -ge 1000 ]] && [[ "$username" != "nobody" ]]; then
        passwd -l "$username" || true
    fi
done < /etc/passwd

# Create forensic snapshot
/opt/hardened-os/incident-response/incident-response-framework.sh snapshot emergency "Emergency lockdown"

echo "EMERGENCY LOCKDOWN COMPLETED"
echo "System secured. Manual intervention required to restore normal operations."
EOF
    
    chmod +x /usr/local/bin/emergency-lockdown
    
    # System health check script
    cat > /usr/local/bin/system-health-check << 'EOF'
#!/bin/bash
# Quick system health check
set -euo pipefail

echo "System Health Check"
echo "==================="
echo ""

echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  Uptime: $(uptime -p)"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "  Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2 " (" int($3/$2*100) "% used)"}')"
echo "  Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo ""

echo "Security Services:"
local services=("auditd" "systemd-journald" "ssh" "hardened-os-monitor")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "  ✓ $service: active"
    else
        echo "  ✗ $service: inactive"
    fi
done
echo ""

echo "Recent Security Events:"
/opt/hardened-os/incident-response/incident-response-framework.sh status | tail -10
EOF
    
    chmod +x /usr/local/bin/system-health-check
    
    # Forensic collection script
    cat > /usr/local/bin/collect-forensics << 'EOF'
#!/bin/bash
# Collect forensic evidence
set -euo pipefail

FORENSIC_DIR="/var/forensic/collection_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$FORENSIC_DIR"

echo "Collecting forensic evidence to: $FORENSIC_DIR"

# System state
ps auxf > "$FORENSIC_DIR/processes.txt"
netstat -tulnp > "$FORENSIC_DIR/network.txt" 2>/dev/null || ss -tulnp > "$FORENSIC_DIR/network.txt"
lsof > "$FORENSIC_DIR/open_files.txt" 2>/dev/null || true
mount > "$FORENSIC_DIR/mounts.txt"
lsmod > "$FORENSIC_DIR/modules.txt"

# Logs
cp /var/log/auth.log "$FORENSIC_DIR/" 2>/dev/null || true
cp /var/log/syslog "$FORENSIC_DIR/" 2>/dev/null || true
cp /var/log/audit/audit.log "$FORENSIC_DIR/" 2>/dev/null || true
journalctl --since "24 hours ago" > "$FORENSIC_DIR/journal_24h.log"

# Network configuration
ip addr show > "$FORENSIC_DIR/ip_config.txt"
ip route show >> "$FORENSIC_DIR/ip_config.txt"
iptables -L -n -v > "$FORENSIC_DIR/iptables.txt" 2>/dev/null || true

# File system
find /tmp /var/tmp /dev/shm -type f -ls > "$FORENSIC_DIR/temp_files.txt" 2>/dev/null || true

# Set permissions
chmod -R 600 "$FORENSIC_DIR"

echo "Forensic collection completed: $FORENSIC_DIR"
logger -p auth.info "FORENSIC_COLLECTION: Evidence collected to $FORENSIC_DIR"
EOF
    
    chmod +x /usr/local/bin/collect-forensics
    
    log_info "Incident response tools created"
}

setup_log_rotation() {
    log_step "Setting up log rotation..."
    
    # Incident response logs
    cat > /etc/logrotate.d/incident-response << 'EOF'
/var/log/incident-response.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}

/var/log/recovery.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}

/var/log/key-rotation.log {
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

create_documentation() {
    log_step "Creating documentation..."
    
    # Quick reference guide
    cat > /opt/hardened-os/incident-response/QUICK_REFERENCE.md << 'EOF'
# Incident Response Quick Reference

## Emergency Commands

### Immediate Response
```bash
# Emergency system lockdown
emergency-lockdown

# Check system health
system-health-check

# Collect forensic evidence
collect-forensics

# Run security scan
incident-response scan all
```

### Recovery Operations
```bash
# Create recovery point
recovery-procedures create "Emergency backup"

# List recovery points
recovery-procedures list

# Restore from recovery point (safe mode)
recovery-procedures restore /var/recovery-points/recovery_YYYYMMDD_HHMMSS safe
```

### Key Management
```bash
# Check key expiration
key-rotation check

# Emergency key revocation
key-rotation revoke ssh compromise

# Rotate all keys
key-rotation rotate all
```

## Service Management

### Start/Stop Monitoring
```bash
# Start monitoring
systemctl start hardened-os-monitor.timer

# Check monitoring status
systemctl status hardened-os-monitor.timer

# View monitoring logs
journalctl -u hardened-os-monitor.service -f
```

## Log Locations

- Incident Response: `/var/log/incident-response.log`
- Recovery Operations: `/var/log/recovery.log`
- Key Management: `/var/log/key-rotation.log`
- Forensic Evidence: `/var/forensic/`
- Recovery Points: `/var/recovery-points/`

## Configuration Files

- Incident Response: `/etc/hardened-os/incident-response.conf`
- Recovery: `/etc/hardened-os/recovery.conf`
- Key Rotation: `/etc/hardened-os/key-rotation.conf`
EOF
    
    log_info "Documentation created"
}

start_services() {
    log_step "Starting incident response services..."
    
    # Start timers
    systemctl start hardened-os-monitor.timer
    systemctl start recovery-point-create.timer
    systemctl start key-expiration-check.timer
    
    # Create initial recovery point
    /opt/hardened-os/incident-response/recovery-procedures.sh create "Initial installation recovery point"
    
    log_info "Services started and initial recovery point created"
}

verify_installation() {
    log_step "Verifying installation..."
    
    local failed_checks=()
    
    # Check scripts
    local scripts=(
        "/opt/hardened-os/incident-response/incident-response-framework.sh"
        "/opt/hardened-os/incident-response/recovery-procedures.sh"
        "/opt/hardened-os/incident-response/key-rotation-procedures.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            failed_checks+=("Script not executable: $script")
        fi
    done
    
    # Check services
    local services=(
        "hardened-os-monitor.timer"
        "recovery-point-create.timer"
        "key-expiration-check.timer"
    )
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            failed_checks+=("Service not active: $service")
        fi
    done
    
    # Check directories
    local directories=(
        "/var/recovery-points"
        "/var/backups/incident-recovery"
        "/var/quarantine"
        "/var/forensic"
        "/var/backups/keys"
    )
    
    for directory in "${directories[@]}"; do
        if [[ ! -d "$directory" ]]; then
            failed_checks+=("Directory missing: $directory")
        fi
    done
    
    if [[ ${#failed_checks[@]} -gt 0 ]]; then
        log_error "Installation verification failed:"
        printf '%s\n' "${failed_checks[@]}"
        return 1
    fi
    
    log_info "Installation verification passed"
    return 0
}

print_summary() {
    log_step "Installation Summary"
    
    echo -e "${GREEN}Incident Response and Recovery System installed successfully!${NC}"
    echo ""
    echo "Components installed:"
    echo "  ✓ Incident Response Framework"
    echo "  ✓ Recovery Procedures"
    echo "  ✓ Key Rotation Management"
    echo "  ✓ Automated Monitoring"
    echo "  ✓ Emergency Response Tools"
    echo "  ✓ Forensic Collection Tools"
    echo ""
    echo "Services running:"
    echo "  ✓ Security monitoring (every 15 minutes)"
    echo "  ✓ Daily recovery point creation"
    echo "  ✓ Weekly key expiration checks"
    echo ""
    echo "Quick commands:"
    echo "  incident-response scan     - Run security scan"
    echo "  recovery-procedures list   - List recovery points"
    echo "  key-rotation check         - Check key expiration"
    echo "  emergency-lockdown         - Emergency system lockdown"
    echo "  system-health-check        - Quick health check"
    echo "  collect-forensics          - Collect forensic evidence"
    echo ""
    echo "Configuration files:"
    echo "  /etc/hardened-os/incident-response.conf"
    echo "  /etc/hardened-os/recovery.conf"
    echo "  /etc/hardened-os/key-rotation.conf"
    echo ""
    echo "Documentation:"
    echo "  /opt/hardened-os/incident-response/QUICK_REFERENCE.md"
}

main() {
    log_info "Starting Incident Response and Recovery System installation..."
    
    check_requirements
    install_incident_response_framework
    create_configuration_files
    setup_systemd_services
    create_incident_response_tools
    setup_log_rotation
    create_documentation
    start_services
    
    if verify_installation; then
        print_summary
    else
        log_error "Installation verification failed. Please check the logs and fix any issues."
        exit 1
    fi
}

main "$@"