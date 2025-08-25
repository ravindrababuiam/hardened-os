#!/bin/bash
#
# Automatic Rollback and Recovery Setup Script
# Implements boot counting and automatic rollback mechanisms
# Task 16: Configure automatic rollback and recovery mechanisms
#

set -euo pipefail

# Configuration
ROLLBACK_DIR="$HOME/harden/rollback"
BUILD_DIR="$HOME/harden/build"
KEYS_DIR="$HOME/harden/keys"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check dependencies
check_dependencies() {
    local deps=("systemctl" "grub-editenv" "grub-reboot")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install systemd grub2-common"
        exit 1
    fi
}

# Setup rollback directory structure
setup_rollback_directories() {
    log_step "Setting up rollback directory structure..."
    
    mkdir -p "$ROLLBACK_DIR"/{configs,scripts,kernels,health-checks}
    mkdir -p "$BUILD_DIR/rollback"
    
    # Set secure permissions
    chmod 755 "$ROLLBACK_DIR"
    chmod 755 "$ROLLBACK_DIR"/{configs,scripts,kernels,health-checks}
    
    log_info "Rollback directories created"
}

# Create boot counting service
create_boot_counting_service() {
    log_step "Creating boot counting service..."
    
    # Create boot counter script
    cat > "$ROLLBACK_DIR/scripts/boot-counter.sh" << 'EOF'
#!/bin/bash
#
# Boot Counter Script
# Tracks successful boots and triggers rollback on failures
#

set -euo pipefail

BOOT_COUNT_FILE="/var/lib/boot-counter/boot_count"
MAX_BOOT_ATTEMPTS=3
GRUB_ENV_FILE="/boot/grub/grubenv"

# Ensure directory exists
mkdir -p "$(dirname "$BOOT_COUNT_FILE")"

# Read current boot count
if [ -f "$BOOT_COUNT_FILE" ]; then
    CURRENT_COUNT=$(cat "$BOOT_COUNT_FILE")
else
    CURRENT_COUNT=0
fi

# Increment boot count
NEW_COUNT=$((CURRENT_COUNT + 1))
echo "$NEW_COUNT" > "$BOOT_COUNT_FILE"

echo "Boot attempt: $NEW_COUNT/$MAX_BOOT_ATTEMPTS"

# Check if we've exceeded max attempts
if [ "$NEW_COUNT" -ge "$MAX_BOOT_ATTEMPTS" ]; then
    echo "Maximum boot attempts reached. Triggering rollback..."
    
    # Set GRUB to boot previous kernel
    if command -v grub-reboot &> /dev/null; then
        # Get previous kernel entry
        PREV_KERNEL=$(grep "^menuentry" /boot/grub/grub.cfg | head -2 | tail -1 | cut -d"'" -f2)
        if [ -n "$PREV_KERNEL" ]; then
            grub-reboot "$PREV_KERNEL"
            echo "Set GRUB to boot: $PREV_KERNEL"
        fi
    fi
    
    # Reset boot count for next attempt
    echo "0" > "$BOOT_COUNT_FILE"
    
    # Log rollback event
    logger -t boot-counter "Automatic rollback triggered after $NEW_COUNT failed boot attempts"
    
    # Reboot to previous kernel
    systemctl reboot
fi
EOF

    chmod +x "$ROLLBACK_DIR/scripts/boot-counter.sh"
    
    # Create systemd service
    sudo tee /etc/systemd/system/boot-counter.service > /dev/null << EOF
[Unit]
Description=Boot Counter Service
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=$ROLLBACK_DIR/scripts/boot-counter.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create boot success service
    sudo tee /etc/systemd/system/boot-success.service > /dev/null << EOF
[Unit]
Description=Boot Success Marker
After=graphical.target
Wants=graphical.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "0" > /var/lib/boot-counter/boot_count'
ExecStart=/usr/bin/logger -t boot-success "Successful boot completed"
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

    # Enable services
    sudo systemctl daemon-reload
    sudo systemctl enable boot-counter.service
    sudo systemctl enable boot-success.service
    
    log_info "Boot counting services created and enabled"
}

# Create recovery partition configuration
create_recovery_partition_config() {
    log_step "Creating recovery partition configuration..."
    
    # Create recovery kernel signing script
    cat > "$ROLLBACK_DIR/scripts/sign-recovery-kernel.sh" << 'EOF'
#!/bin/bash
#
# Recovery Kernel Signing Script
# Signs recovery kernel with development keys
#

set -euo pipefail

KEYS_DIR="$HOME/harden/keys"
RECOVERY_DIR="$HOME/harden/rollback"

# Check for signing keys
if [ ! -f "$KEYS_DIR/dev/DB/DB.key" ] || [ ! -f "$KEYS_DIR/dev/DB/DB.crt" ]; then
    echo "Error: DB signing keys not found"
    echo "Run generate-dev-keys.sh first"
    exit 1
fi

# Sign recovery kernel
if [ -f "/boot/vmlinuz" ]; then
    echo "Signing recovery kernel..."
    
    # Copy current kernel as recovery kernel
    cp /boot/vmlinuz "$RECOVERY_DIR/kernels/vmlinuz-recovery"
    cp /boot/initrd.img "$RECOVERY_DIR/kernels/initrd-recovery"
    
    # Sign the recovery kernel
    sbsign --key "$KEYS_DIR/dev/DB/DB.key" \
           --cert "$KEYS_DIR/dev/DB/DB.crt" \
           --output "$RECOVERY_DIR/kernels/vmlinuz-recovery.signed" \
           "$RECOVERY_DIR/kernels/vmlinuz-recovery"
    
    echo "Recovery kernel signed successfully"
else
    echo "Warning: No kernel found to sign"
fi
EOF

    chmod +x "$ROLLBACK_DIR/scripts/sign-recovery-kernel.sh"
    
    # Create GRUB recovery entry
    cat > "$ROLLBACK_DIR/configs/grub-recovery.cfg" << 'EOF'
# GRUB Recovery Configuration
# Add this to /etc/grub.d/40_custom

menuentry 'Hardened OS - Recovery Mode' --class recovery {
    load_video
    insmod gzio
    insmod part_gpt
    insmod fat
    insmod ext2
    
    echo 'Loading recovery kernel...'
    linux /recovery/vmlinuz-recovery.signed root=/dev/mapper/root ro recovery single
    echo 'Loading recovery initramfs...'
    initrd /recovery/initrd-recovery
}

menuentry 'Hardened OS - Safe Mode (Previous Kernel)' --class recovery {
    load_video
    insmod gzio
    insmod part_gpt
    insmod fat
    insmod ext2
    
    echo 'Loading previous kernel in safe mode...'
    linux /vmlinuz.old root=/dev/mapper/root ro single
    echo 'Loading previous initramfs...'
    initrd /initrd.img.old
}
EOF

    # Install GRUB recovery configuration
    if [ -d "/etc/grub.d" ]; then
        sudo cp "$ROLLBACK_DIR/configs/grub-recovery.cfg" /etc/grub.d/40_recovery
        sudo chmod +x /etc/grub.d/40_recovery
        log_info "GRUB recovery configuration installed"
    else
        log_warn "GRUB directory not found, recovery entries not installed"
    fi
    
    log_info "Recovery partition configuration created"
}

# Create rollback documentation
create_rollback_documentation() {
    log_step "Creating rollback documentation..."
    
    cat > "$ROLLBACK_DIR/ROLLBACK_PROCEDURES.md" << 'EOF'
# Automatic Rollback and Recovery Procedures

## Overview

This document describes the automatic rollback and recovery mechanisms implemented for the Hardened OS system.

## Boot Counting System

### How It Works
1. **Boot Counter Service**: Tracks boot attempts in `/var/lib/boot-counter/boot_count`
2. **Maximum Attempts**: System allows 3 boot attempts before triggering rollback
3. **Success Marker**: `boot-success.service` resets counter when system reaches graphical target
4. **Automatic Rollback**: After 3 failed attempts, system boots previous kernel

### Boot Counter Files
- `/var/lib/boot-counter/boot_count`: Current boot attempt count
- `/var/log/boot-counter.log`: Boot counting events
- `/etc/systemd/system/boot-counter.service`: Boot counting service
- `/etc/systemd/system/boot-success.service`: Success marker service

## System Health Monitoring

### Health Checks Performed
1. **Critical Services**: systemd-logind, dbus, NetworkManager
2. **Filesystem Integrity**: ext4 filesystem state check
3. **Memory Usage**: Alert if >90% memory used
4. **Disk Space**: Alert if >95% disk used
5. **SELinux Status**: Verify enforcing mode
6. **TPM2 Status**: Verify TPM2 communication

### Health Check Files
- `/var/lib/boot-counter/health_status`: Current health status (HEALTHY/UNHEALTHY)
- `/var/log/system-health.log`: Health check results
- `/etc/systemd/system/system-health-check.service`: Health check service
- `/etc/systemd/system/system-health-check.timer`: Periodic health checks (every 5 minutes)

## Rollback Trigger System

### Rollback Conditions
1. **Boot Failures**: 3 consecutive failed boot attempts
2. **Health Failures**: 3 consecutive unhealthy system states
3. **Manual Trigger**: Administrator can manually trigger rollback

### Rollback Process
1. Identify previous kernel from GRUB menu
2. Set GRUB to boot previous kernel on next reboot
3. Reset boot and health counters
4. Log rollback event
5. Reboot system

### Rollback Files
- `/var/lib/boot-counter/unhealthy_count`: Consecutive unhealthy checks
- `/var/log/rollback.log`: Rollback events and decisions
- `/etc/systemd/system/rollback-trigger.service`: Rollback trigger service
- `/etc/systemd/system/rollback-trigger.timer`: Periodic rollback checks

## Recovery Partition

### Recovery Options
1. **Recovery Mode**: Minimal system with recovery tools
2. **Safe Mode**: Previous kernel with reduced security
3. **Manual Recovery**: Emergency shell access

### Recovery Files
- `/recovery/vmlinuz-recovery.signed`: Signed recovery kernel
- `/recovery/initrd-recovery`: Recovery initramfs
- `/etc/grub.d/40_recovery`: GRUB recovery menu entries

## Manual Operations

### Check System Status
```bash
# Check boot count
cat /var/lib/boot-counter/boot_count

# Check health status
cat /var/lib/boot-counter/health_status

# Check unhealthy count
cat /var/lib/boot-counter/unhealthy_count

# View recent health checks
tail -20 /var/log/system-health.log

# View rollback events
tail -20 /var/log/rollback.log
```

### Manual Rollback
```bash
# Trigger immediate rollback
sudo /home/user/harden/rollback/scripts/rollback-trigger.sh

# Set GRUB to boot previous kernel
sudo grub-reboot "Previous Kernel Entry Name"
sudo reboot
```

### Reset Counters
```bash
# Reset boot count
echo "0" | sudo tee /var/lib/boot-counter/boot_count

# Reset unhealthy count
echo "0" | sudo tee /var/lib/boot-counter/unhealthy_count

# Mark system as healthy
echo "HEALTHY" | sudo tee /var/lib/boot-counter/health_status
```

### Service Management
```bash
# Check service status
sudo systemctl status boot-counter.service
sudo systemctl status system-health-check.timer
sudo systemctl status rollback-trigger.timer

# Start/stop services
sudo systemctl start system-health-check.service
sudo systemctl stop rollback-trigger.timer

# View service logs
sudo journalctl -u boot-counter.service
sudo journalctl -u system-health-check.service
sudo journalctl -u rollback-trigger.service
```

## Troubleshooting

### Boot Counter Not Working
1. Check if services are enabled: `systemctl is-enabled boot-counter.service`
2. Check service logs: `journalctl -u boot-counter.service`
3. Verify file permissions on `/var/lib/boot-counter/`

### Health Checks Failing
1. Run manual health check: `/home/user/harden/rollback/scripts/system-health-check.sh`
2. Check individual health components
3. Review health check logs: `/var/log/system-health.log`

### Rollback Not Triggering
1. Check rollback trigger service: `systemctl status rollback-trigger.service`
2. Verify GRUB configuration: `grep menuentry /boot/grub/grub.cfg`
3. Check rollback logs: `/var/log/rollback.log`

### Recovery Boot Issues
1. Verify recovery kernel exists: `ls -la /recovery/`
2. Check GRUB recovery entries: `grep -A 10 "Recovery Mode" /boot/grub/grub.cfg`
3. Verify kernel signatures: `sbverify --cert /path/to/cert /recovery/vmlinuz-recovery.signed`

## Security Considerations

1. **Signed Kernels**: All recovery kernels are cryptographically signed
2. **Secure Logs**: Rollback events are logged for audit purposes
3. **Limited Rollback**: Only rolls back to previous known-good kernel
4. **Health Validation**: Multiple health checks prevent false positives
5. **Manual Override**: Administrators can override automatic decisions

## Testing Recommendations

1. **Monthly**: Test manual rollback procedures
2. **Quarterly**: Simulate boot failures and verify automatic rollback
3. **Annually**: Full disaster recovery testing with recovery partition
4. **After Updates**: Verify rollback works after kernel updates

EOF

    chmod 644 "$ROLLBACK_DIR/ROLLBACK_PROCEDURES.md"
    log_info "Rollback documentation created"
}

main() {
    log_info "Setting up automatic rollback and recovery mechanisms..."
    
    check_dependencies
    setup_rollback_directories
    create_boot_counting_service
    create_health_checks
    create_rollback_trigger
    create_recovery_partition_config
    create_rollback_documentation
    
    log_info "✅ Automatic rollback and recovery setup completed successfully!"
    log_info "📁 Configuration location: $ROLLBACK_DIR"
    log_warn "⚠️  Start services with: sudo systemctl start system-health-check.timer rollback-trigger.timer"
    log_warn "⚠️  Update GRUB config with: sudo update-grub"
    log_info "📖 Documentation: $ROLLBACK_DIR/ROLLBACK_PROCEDURES.md"
}

main "$@"# Create
 system health check scripts
create_health_checks() {
    log_step "Creating system health check scripts..."
    
    # Create main health check script
    cat > "$ROLLBACK_DIR/scripts/system-health-check.sh" << 'EOF'
#!/bin/bash
#
# System Health Check Script
# Performs comprehensive system health validation
#

set -euo pipefail

HEALTH_LOG="/var/log/system-health.log"
HEALTH_STATUS_FILE="/var/lib/boot-counter/health_status"

# Ensure directories exist
mkdir -p "$(dirname "$HEALTH_LOG")"
mkdir -p "$(dirname "$HEALTH_STATUS_FILE")"

log_health() {
    echo "$(date -Iseconds) $1" | tee -a "$HEALTH_LOG"
}

# Check critical services
check_critical_services() {
    local services=("systemd-logind" "dbus" "NetworkManager")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_health "✓ All critical services running"
        return 0
    else
        log_health "✗ Failed services: ${failed_services[*]}"
        return 1
    fi
}

# Check filesystem integrity
check_filesystem_integrity() {
    local root_fs=$(findmnt -n -o FSTYPE /)
    
    if [ "$root_fs" = "ext4" ]; then
        # Check for filesystem errors
        if tune2fs -l /dev/mapper/root 2>/dev/null | grep -q "Filesystem state:.*clean"; then
            log_health "✓ Root filesystem is clean"
            return 0
        else
            log_health "✗ Root filesystem has errors"
            return 1
        fi
    else
        log_health "✓ Filesystem check skipped (not ext4)"
        return 0
    fi
}

# Check memory usage
check_memory_usage() {
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    
    if [ "$mem_usage" -lt 90 ]; then
        log_health "✓ Memory usage OK ($mem_usage%)"
        return 0
    else
        log_health "✗ High memory usage ($mem_usage%)"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    local root_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$root_usage" -lt 95 ]; then
        log_health "✓ Disk space OK ($root_usage% used)"
        return 0
    else
        log_health "✗ Low disk space ($root_usage% used)"
        return 1
    fi
}

# Check SELinux status
check_selinux_status() {
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce)
        if [ "$selinux_status" = "Enforcing" ]; then
            log_health "✓ SELinux enforcing"
            return 0
        else
            log_health "✗ SELinux not enforcing ($selinux_status)"
            return 1
        fi
    else
        log_health "✓ SELinux check skipped (not available)"
        return 0
    fi
}

# Check TPM2 status
check_tpm2_status() {
    if command -v tpm2_getcap &> /dev/null; then
        if tpm2_getcap properties-fixed >/dev/null 2>&1; then
            log_health "✓ TPM2 communication OK"
            return 0
        else
            log_health "✗ TPM2 communication failed"
            return 1
        fi
    else
        log_health "✓ TPM2 check skipped (not available)"
        return 0
    fi
}

# Main health check
main() {
    log_health "=== System Health Check Started ==="
    
    local checks=(
        "check_critical_services"
        "check_filesystem_integrity"
        "check_memory_usage"
        "check_disk_space"
        "check_selinux_status"
        "check_tpm2_status"
    )
    
    local failed_checks=0
    
    for check in "${checks[@]}"; do
        if ! $check; then
            ((failed_checks++))
        fi
    done
    
    if [ $failed_checks -eq 0 ]; then
        log_health "=== System Health Check PASSED ==="
        echo "HEALTHY" > "$HEALTH_STATUS_FILE"
        exit 0
    else
        log_health "=== System Health Check FAILED ($failed_checks checks) ==="
        echo "UNHEALTHY" > "$HEALTH_STATUS_FILE"
        exit 1
    fi
}

main "$@"
EOF

    chmod +x "$ROLLBACK_DIR/scripts/system-health-check.sh"
    
    # Create health check service
    sudo tee /etc/systemd/system/system-health-check.service > /dev/null << EOF
[Unit]
Description=System Health Check
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$ROLLBACK_DIR/scripts/system-health-check.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create health check timer for periodic checks
    sudo tee /etc/systemd/system/system-health-check.timer > /dev/null << EOF
[Unit]
Description=Run System Health Check every 5 minutes
Requires=system-health-check.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable system-health-check.service
    sudo systemctl enable system-health-check.timer
    
    log_info "System health check scripts created and enabled"
}

# Create rollback trigger script
create_rollback_trigger() {
    log_step "Creating rollback trigger script..."
    
    cat > "$ROLLBACK_DIR/scripts/rollback-trigger.sh" << 'EOF'
#!/bin/bash
#
# Rollback Trigger Script
# Monitors system health and triggers rollback when needed
#

set -euo pipefail

HEALTH_STATUS_FILE="/var/lib/boot-counter/health_status"
ROLLBACK_LOG="/var/log/rollback.log"
MAX_UNHEALTHY_CHECKS=3
UNHEALTHY_COUNT_FILE="/var/lib/boot-counter/unhealthy_count"

# Ensure directories exist
mkdir -p "$(dirname "$ROLLBACK_LOG")"
mkdir -p "$(dirname "$UNHEALTHY_COUNT_FILE")"

log_rollback() {
    echo "$(date -Iseconds) $1" | tee -a "$ROLLBACK_LOG"
}

# Check if system is healthy
is_system_healthy() {
    if [ -f "$HEALTH_STATUS_FILE" ]; then
        local status=$(cat "$HEALTH_STATUS_FILE")
        [ "$status" = "HEALTHY" ]
    else
        # Assume healthy if no status file
        return 0
    fi
}

# Get unhealthy count
get_unhealthy_count() {
    if [ -f "$UNHEALTHY_COUNT_FILE" ]; then
        cat "$UNHEALTHY_COUNT_FILE"
    else
        echo "0"
    fi
}

# Set unhealthy count
set_unhealthy_count() {
    echo "$1" > "$UNHEALTHY_COUNT_FILE"
}

# Trigger rollback
trigger_rollback() {
    log_rollback "Triggering automatic rollback due to persistent health issues"
    
    # Get list of available kernels
    local kernels=($(grep "^menuentry" /boot/grub/grub.cfg | cut -d"'" -f2))
    
    if [ ${#kernels[@]} -gt 1 ]; then
        # Boot the second kernel (previous version)
        local prev_kernel="${kernels[1]}"
        log_rollback "Rolling back to kernel: $prev_kernel"
        
        grub-reboot "$prev_kernel"
        
        # Reset counters
        set_unhealthy_count 0
        echo "0" > /var/lib/boot-counter/boot_count
        
        # Reboot
        systemctl reboot
    else
        log_rollback "No previous kernel available for rollback"
    fi
}

# Main rollback logic
main() {
    if is_system_healthy; then
        # System is healthy, reset unhealthy count
        set_unhealthy_count 0
        log_rollback "System health OK"
    else
        # System is unhealthy, increment counter
        local count=$(get_unhealthy_count)
        count=$((count + 1))
        set_unhealthy_count "$count"
        
        log_rollback "System unhealthy (count: $count/$MAX_UNHEALTHY_CHECKS)"
        
        if [ "$count" -ge "$MAX_UNHEALTHY_CHECKS" ]; then
            trigger_rollback
        fi
    fi
}

main "$@"
EOF

    chmod +x "$ROLLBACK_DIR/scripts/rollback-trigger.sh"
    
    # Create rollback trigger service
    sudo tee /etc/systemd/system/rollback-trigger.service > /dev/null << EOF
[Unit]
Description=Rollback Trigger Service
After=system-health-check.service
Requires=system-health-check.service

[Service]
Type=oneshot
ExecStart=$ROLLBACK_DIR/scripts/rollback-trigger.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create rollback trigger timer
    sudo tee /etc/systemd/system/rollback-trigger.timer > /dev/null << EOF
[Unit]
Description=Run Rollback Trigger every 5 minutes
Requires=rollback-trigger.service

[Timer]
OnBootSec=6min
OnUnitActiveSec=5min
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable rollback-trigger.service
    sudo systemctl enable rollback-trigger.timer
    
    log_info "Rollback trigger scripts created and enabled"
}