#!/bin/bash
# System Recovery Procedures for Hardened OS
# Provides automated and manual recovery from security incidents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/etc/hardened-os/recovery.conf"
LOG_FILE="/var/log/recovery.log"
BACKUP_DIR="/var/backups/incident-recovery"
RECOVERY_POINT_DIR="/var/recovery-points"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Recovery modes
MODE_SAFE="safe"
MODE_FULL="full"
MODE_FORENSIC="forensic"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Default configuration
        BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
        AUTO_BACKUP_ENABLED="${AUTO_BACKUP_ENABLED:-true}"
        RECOVERY_VERIFICATION="${RECOVERY_VERIFICATION:-true}"
        FORENSIC_PRESERVATION="${FORENSIC_PRESERVATION:-true}"
    fi
}

log_recovery() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo -e "${BLUE}[$level]${NC} $message"
    
    # Also log to syslog
    logger -p auth.info "RECOVERY_$level: $message"
}

create_recovery_point() {
    local description="${1:-Manual recovery point}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local recovery_point="$RECOVERY_POINT_DIR/recovery_$timestamp"
    
    log_recovery "INFO" "Creating recovery point: $description"
    
    mkdir -p "$recovery_point"
    
    # System configuration backup
    mkdir -p "$recovery_point/config"
    
    # Critical configuration files
    local config_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/gshadow"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
        "/etc/systemd/system"
        "/etc/selinux/config"
        "/etc/audit/auditd.conf"
        "/etc/audit/rules.d"
        "/etc/hardened-os"
        "/etc/crypttab"
        "/etc/fstab"
        "/boot/grub/grub.cfg"
    )
    
    for config in "${config_files[@]}"; do
        if [[ -e "$config" ]]; then
            cp -r "$config" "$recovery_point/config/" 2>/dev/null || true
        fi
    done
    
    # Package list
    dpkg --get-selections > "$recovery_point/package_list.txt"
    
    # Service states
    systemctl list-units --type=service --all --no-pager > "$recovery_point/service_states.txt"
    
    # Network configuration
    ip addr show > "$recovery_point/network_config.txt"
    ip route show >> "$recovery_point/network_config.txt"
    
    # Firewall rules
    iptables-save > "$recovery_point/iptables_rules.txt" 2>/dev/null || true
    nft list ruleset > "$recovery_point/nftables_rules.txt" 2>/dev/null || true
    
    # SELinux status
    if command -v sestatus >/dev/null 2>&1; then
        sestatus > "$recovery_point/selinux_status.txt"
    fi
    
    # TPM status
    if command -v tpm2_getcap >/dev/null 2>&1; then
        tpm2_getcap properties-fixed > "$recovery_point/tpm_status.txt" 2>/dev/null || true
    fi
    
    # Create metadata
    cat > "$recovery_point/metadata.json" << EOF
{
    "timestamp": "$timestamp",
    "description": "$description",
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "created_by": "$(whoami)",
    "system_uptime": "$(uptime -p)",
    "recovery_point_path": "$recovery_point"
}
EOF
    
    # Set permissions
    chmod -R 600 "$recovery_point"
    
    log_recovery "SUCCESS" "Recovery point created: $recovery_point"
    echo "$recovery_point"
}

list_recovery_points() {
    log_recovery "INFO" "Listing available recovery points"
    
    if [[ ! -d "$RECOVERY_POINT_DIR" ]]; then
        echo -e "${YELLOW}No recovery points directory found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Available Recovery Points:${NC}"
    echo "=========================="
    
    local count=0
    for recovery_point in "$RECOVERY_POINT_DIR"/recovery_*; do
        if [[ -d "$recovery_point" ]] && [[ -f "$recovery_point/metadata.json" ]]; then
            ((count++))
            local basename=$(basename "$recovery_point")
            local timestamp=$(echo "$basename" | sed 's/recovery_//')
            local formatted_time=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$timestamp")
            
            if [[ -f "$recovery_point/metadata.json" ]]; then
                local description=$(grep '"description"' "$recovery_point/metadata.json" | cut -d'"' -f4)
                echo -e "${GREEN}$count.${NC} $formatted_time - $description"
                echo "    Path: $recovery_point"
            else
                echo -e "${GREEN}$count.${NC} $formatted_time - Recovery point"
                echo "    Path: $recovery_point"
            fi
            echo ""
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}No recovery points found${NC}"
        return 1
    fi
    
    return 0
}

restore_from_recovery_point() {
    local recovery_point="$1"
    local mode="${2:-$MODE_SAFE}"
    
    if [[ ! -d "$recovery_point" ]]; then
        log_recovery "ERROR" "Recovery point not found: $recovery_point"
        return 1
    fi
    
    log_recovery "INFO" "Starting system restore from: $recovery_point (mode: $mode)"
    
    # Verify recovery point integrity
    if [[ "$RECOVERY_VERIFICATION" == "true" ]]; then
        if ! verify_recovery_point "$recovery_point"; then
            log_recovery "ERROR" "Recovery point verification failed"
            return 1
        fi
    fi
    
    # Create backup of current state before restore
    local pre_restore_backup=$(create_recovery_point "Pre-restore backup $(date)")
    log_recovery "INFO" "Created pre-restore backup: $pre_restore_backup"
    
    case "$mode" in
        "$MODE_SAFE")
            restore_safe_mode "$recovery_point"
            ;;
        "$MODE_FULL")
            restore_full_mode "$recovery_point"
            ;;
        "$MODE_FORENSIC")
            restore_forensic_mode "$recovery_point"
            ;;
        *)
            log_recovery "ERROR" "Unknown restore mode: $mode"
            return 1
            ;;
    esac
    
    log_recovery "SUCCESS" "System restore completed from: $recovery_point"
}

restore_safe_mode() {
    local recovery_point="$1"
    
    log_recovery "INFO" "Performing safe mode restore (configuration only)"
    
    # Restore critical configuration files
    local safe_configs=(
        "passwd"
        "group"
        "sudoers"
        "ssh/sshd_config"
        "audit/auditd.conf"
        "hardened-os"
    )
    
    for config in "${safe_configs[@]}"; do
        if [[ -f "$recovery_point/config/$config" ]]; then
            log_recovery "INFO" "Restoring configuration: $config"
            cp "$recovery_point/config/$config" "/etc/$config"
        fi
    done
    
    # Restore service states (enable/disable only, don't start/stop)
    if [[ -f "$recovery_point/service_states.txt" ]]; then
        log_recovery "INFO" "Restoring service states"
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)\.service[[:space:]]+loaded[[:space:]]+active ]]; then
                local service="${BASH_REMATCH[1]}"
                systemctl enable "$service" 2>/dev/null || true
            fi
        done < "$recovery_point/service_states.txt"
    fi
    
    log_recovery "SUCCESS" "Safe mode restore completed"
}

restore_full_mode() {
    local recovery_point="$1"
    
    log_recovery "INFO" "Performing full system restore"
    
    # First do safe mode restore
    restore_safe_mode "$recovery_point"
    
    # Restore network configuration
    if [[ -f "$recovery_point/network_config.txt" ]]; then
        log_recovery "INFO" "Network configuration available for manual review"
        log_recovery "WARN" "Manual network reconfiguration may be required"
    fi
    
    # Restore firewall rules
    if [[ -f "$recovery_point/iptables_rules.txt" ]]; then
        log_recovery "INFO" "Restoring iptables rules"
        iptables-restore < "$recovery_point/iptables_rules.txt" 2>/dev/null || true
    fi
    
    if [[ -f "$recovery_point/nftables_rules.txt" ]]; then
        log_recovery "INFO" "Restoring nftables rules"
        nft -f "$recovery_point/nftables_rules.txt" 2>/dev/null || true
    fi
    
    # Restore SELinux configuration
    if [[ -f "$recovery_point/config/selinux/config" ]]; then
        log_recovery "INFO" "Restoring SELinux configuration"
        cp "$recovery_point/config/selinux/config" "/etc/selinux/config"
    fi
    
    # Restart critical services
    local critical_services=(
        "systemd-journald"
        "auditd"
        "ssh"
        "systemd-networkd"
    )
    
    for service in "${critical_services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            log_recovery "INFO" "Restarting service: $service"
            systemctl restart "$service" || true
        fi
    done
    
    log_recovery "SUCCESS" "Full system restore completed"
}

restore_forensic_mode() {
    local recovery_point="$1"
    
    log_recovery "INFO" "Performing forensic mode restore (read-only analysis)"
    
    # Create forensic analysis directory
    local forensic_dir="/var/forensic/analysis_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$forensic_dir"
    
    # Compare current system with recovery point
    log_recovery "INFO" "Performing forensic comparison"
    
    # Compare configuration files
    mkdir -p "$forensic_dir/config_diff"
    for config_file in "$recovery_point/config"/*; do
        if [[ -f "$config_file" ]]; then
            local basename=$(basename "$config_file")
            local current_file="/etc/$basename"
            
            if [[ -f "$current_file" ]]; then
                diff -u "$config_file" "$current_file" > "$forensic_dir/config_diff/$basename.diff" 2>/dev/null || true
            else
                echo "File missing: $current_file" > "$forensic_dir/config_diff/$basename.diff"
            fi
        fi
    done
    
    # Compare package lists
    dpkg --get-selections > "$forensic_dir/current_packages.txt"
    if [[ -f "$recovery_point/package_list.txt" ]]; then
        diff -u "$recovery_point/package_list.txt" "$forensic_dir/current_packages.txt" > "$forensic_dir/package_diff.txt" 2>/dev/null || true
    fi
    
    # Compare service states
    systemctl list-units --type=service --all --no-pager > "$forensic_dir/current_services.txt"
    if [[ -f "$recovery_point/service_states.txt" ]]; then
        diff -u "$recovery_point/service_states.txt" "$forensic_dir/current_services.txt" > "$forensic_dir/service_diff.txt" 2>/dev/null || true
    fi
    
    # Generate forensic report
    cat > "$forensic_dir/forensic_report.txt" << EOF
Forensic Analysis Report
========================
Analysis Date: $(date -Iseconds)
Recovery Point: $recovery_point
Current System: $(hostname)

Summary:
- Configuration differences: $(find "$forensic_dir/config_diff" -name "*.diff" -size +0 | wc -l) files changed
- Package differences: $(wc -l < "$forensic_dir/package_diff.txt" 2>/dev/null || echo "0") changes
- Service differences: $(wc -l < "$forensic_dir/service_diff.txt" 2>/dev/null || echo "0") changes

Review the individual diff files for detailed analysis.
EOF
    
    log_recovery "SUCCESS" "Forensic analysis completed: $forensic_dir"
    echo -e "${BLUE}Forensic analysis results: $forensic_dir${NC}"
}

verify_recovery_point() {
    local recovery_point="$1"
    
    log_recovery "INFO" "Verifying recovery point integrity: $recovery_point"
    
    # Check required files
    local required_files=(
        "metadata.json"
        "config"
        "package_list.txt"
        "service_states.txt"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "$recovery_point/$file" ]]; then
            log_recovery "ERROR" "Missing required file in recovery point: $file"
            return 1
        fi
    done
    
    # Verify metadata
    if ! python3 -m json.tool "$recovery_point/metadata.json" >/dev/null 2>&1; then
        log_recovery "ERROR" "Invalid metadata.json format"
        return 1
    fi
    
    # Check file permissions
    local perms=$(stat -c %a "$recovery_point")
    if [[ "$perms" != "700" ]]; then
        log_recovery "WARN" "Recovery point permissions are not secure: $perms"
    fi
    
    log_recovery "SUCCESS" "Recovery point verification passed"
    return 0
}

cleanup_old_recovery_points() {
    local retention_days="${1:-$BACKUP_RETENTION_DAYS}"
    
    log_recovery "INFO" "Cleaning up recovery points older than $retention_days days"
    
    if [[ ! -d "$RECOVERY_POINT_DIR" ]]; then
        return 0
    fi
    
    local deleted_count=0
    
    find "$RECOVERY_POINT_DIR" -name "recovery_*" -type d -mtime +$retention_days | while read -r old_recovery_point; do
        log_recovery "INFO" "Removing old recovery point: $old_recovery_point"
        rm -rf "$old_recovery_point"
        ((deleted_count++))
    done
    
    log_recovery "INFO" "Cleanup completed: $deleted_count recovery points removed"
}

emergency_recovery() {
    log_recovery "CRITICAL" "Starting emergency recovery procedure"
    
    # Stop non-essential services
    local non_essential_services=(
        "apache2"
        "nginx"
        "mysql"
        "postgresql"
        "docker"
        "NetworkManager"
    )
    
    for service in "${non_essential_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_recovery "INFO" "Stopping non-essential service: $service"
            systemctl stop "$service" || true
        fi
    done
    
    # Reset firewall to secure defaults
    log_recovery "INFO" "Resetting firewall to secure defaults"
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    
    # Allow only essential local traffic
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow SSH for recovery access (if configured)
    if [[ -n "${EMERGENCY_SSH_PORT:-}" ]]; then
        iptables -A INPUT -p tcp --dport "$EMERGENCY_SSH_PORT" -j ACCEPT
        iptables -A OUTPUT -p tcp --sport "$EMERGENCY_SSH_PORT" -j ACCEPT
    fi
    
    # Reset user passwords to force re-authentication
    log_recovery "INFO" "Forcing password reset for all users"
    while IFS=: read -r username _ uid _; do
        if [[ $uid -ge 1000 ]] && [[ "$username" != "nobody" ]]; then
            passwd -e "$username" 2>/dev/null || true
        fi
    done < /etc/passwd
    
    # Create emergency recovery point
    local emergency_point=$(create_recovery_point "Emergency recovery - $(date)")
    
    log_recovery "CRITICAL" "Emergency recovery completed. System secured. Recovery point: $emergency_point"
    
    echo -e "${RED}EMERGENCY RECOVERY COMPLETED${NC}"
    echo -e "${YELLOW}System has been secured with minimal services running${NC}"
    echo -e "${YELLOW}Recovery point created: $emergency_point${NC}"
    echo -e "${YELLOW}Manual intervention required to restore normal operations${NC}"
}

show_recovery_status() {
    echo -e "${BLUE}System Recovery Status${NC}"
    echo "======================"
    echo ""
    
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Backup Retention: ${BACKUP_RETENTION_DAYS:-30} days"
    echo "  Auto Backup: ${AUTO_BACKUP_ENABLED:-true}"
    echo "  Recovery Verification: ${RECOVERY_VERIFICATION:-true}"
    echo "  Forensic Preservation: ${FORENSIC_PRESERVATION:-true}"
    echo ""
    
    echo -e "${YELLOW}Recovery Points:${NC}"
    if [[ -d "$RECOVERY_POINT_DIR" ]]; then
        local point_count=$(find "$RECOVERY_POINT_DIR" -name "recovery_*" -type d | wc -l)
        echo "  Available recovery points: $point_count"
        
        if [[ $point_count -gt 0 ]]; then
            local latest=$(find "$RECOVERY_POINT_DIR" -name "recovery_*" -type d | sort | tail -1)
            local latest_time=$(basename "$latest" | sed 's/recovery_//')
            local formatted_time=$(date -d "${latest_time:0:8} ${latest_time:9:2}:${latest_time:11:2}:${latest_time:13:2}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$latest_time")
            echo "  Latest recovery point: $formatted_time"
        fi
    else
        echo "  No recovery points directory found"
    fi
    echo ""
    
    echo -e "${YELLOW}System Health:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p)"
    echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Root filesystem: $(df -h / | awk 'NR==2 {print $4 " available (" $5 " used)"}')"
    echo ""
    
    echo -e "${YELLOW}Critical Services:${NC}"
    local critical_services=("systemd-journald" "auditd" "ssh" "systemd-networkd")
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $service: active"
        else
            echo -e "  ${RED}✗${NC} $service: inactive"
        fi
    done
}

main() {
    load_config
    
    case "${1:-status}" in
        "create")
            create_recovery_point "${2:-Manual recovery point}"
            ;;
        "list")
            list_recovery_points
            ;;
        "restore")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 restore <recovery_point_path> [mode]"
                echo "Modes: safe, full, forensic"
                exit 1
            fi
            restore_from_recovery_point "$2" "${3:-safe}"
            ;;
        "verify")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 verify <recovery_point_path>"
                exit 1
            fi
            verify_recovery_point "$2"
            ;;
        "cleanup")
            cleanup_old_recovery_points "${2:-$BACKUP_RETENTION_DAYS}"
            ;;
        "emergency")
            emergency_recovery
            ;;
        "status")
            show_recovery_status
            ;;
        "help"|"-h"|"--help")
            echo "Hardened OS Recovery Procedures"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  create [description]     Create a new recovery point"
            echo "  list                     List available recovery points"
            echo "  restore <path> [mode]    Restore from recovery point (safe|full|forensic)"
            echo "  verify <path>            Verify recovery point integrity"
            echo "  cleanup [days]           Remove old recovery points"
            echo "  emergency                Emergency system lockdown and recovery"
            echo "  status                   Show recovery system status"
            echo "  help                     Show this help message"
            echo ""
            echo "Recovery Modes:"
            echo "  safe      - Restore configuration files only (default)"
            echo "  full      - Full system restore including services"
            echo "  forensic  - Read-only analysis and comparison"
            echo ""
            echo "Configuration file: $CONFIG_FILE"
            echo "Log file: $LOG_FILE"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"