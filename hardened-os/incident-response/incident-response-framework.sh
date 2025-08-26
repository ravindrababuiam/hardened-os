#!/bin/bash
# Automated Incident Response Framework for Hardened OS
# Provides automated detection, containment, and recovery procedures

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/etc/hardened-os/incident-response.conf"
LOG_FILE="/var/log/incident-response.log"
QUARANTINE_DIR="/var/quarantine"
BACKUP_DIR="/var/backups/incident-recovery"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Incident severity levels
SEVERITY_LOW=1
SEVERITY_MEDIUM=2
SEVERITY_HIGH=3
SEVERITY_CRITICAL=4

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Default configuration
        ALERT_EMAIL="${ALERT_EMAIL:-root@localhost}"
        ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
        AUTO_CONTAINMENT="${AUTO_CONTAINMENT:-true}"
        AUTO_RECOVERY="${AUTO_RECOVERY:-false}"
        FORENSIC_MODE="${FORENSIC_MODE:-false}"
    fi
}

log_incident() {
    local severity="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] [SEVERITY:$severity] $message" >> "$LOG_FILE"
    
    # Also log to syslog
    case $severity in
        $SEVERITY_CRITICAL) logger -p auth.crit "INCIDENT_CRITICAL: $message" ;;
        $SEVERITY_HIGH) logger -p auth.err "INCIDENT_HIGH: $message" ;;
        $SEVERITY_MEDIUM) logger -p auth.warning "INCIDENT_MEDIUM: $message" ;;
        $SEVERITY_LOW) logger -p auth.info "INCIDENT_LOW: $message" ;;
    esac
}

send_alert() {
    local severity="$1"
    local incident_type="$2"
    local message="$3"
    local timestamp=$(date -Iseconds)
    
    local subject="[HARDENED-OS] Incident Alert - Severity $severity - $incident_type"
    local body="Incident Response Alert

Timestamp: $timestamp
Severity: $severity
Type: $incident_type
Host: $(hostname)
User: $(whoami)

Details:
$message

Automated Response Status:
- Containment: $([[ "$AUTO_CONTAINMENT" == "true" ]] && echo "ENABLED" || echo "DISABLED")
- Recovery: $([[ "$AUTO_RECOVERY" == "true" ]] && echo "ENABLED" || echo "DISABLED")
- Forensic Mode: $([[ "$FORENSIC_MODE" == "true" ]] && echo "ENABLED" || echo "DISABLED")

Next Steps:
1. Review incident details in $LOG_FILE
2. Check system status: systemctl status hardened-os-monitor
3. Review security logs: journalctl -u hardened-os-monitor --since '1 hour ago'
4. If needed, run manual recovery: $SCRIPT_DIR/recovery-procedures.sh

This is an automated alert from the Hardened OS Incident Response System."

    # Send email alert
    if command -v mail >/dev/null 2>&1 && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$body" | mail -s "$subject" "$ALERT_EMAIL"
    fi
    
    # Send webhook alert if configured
    if [[ -n "$ALERT_WEBHOOK" ]] && command -v curl >/dev/null 2>&1; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"timestamp\": \"$timestamp\",
                \"severity\": $severity,
                \"type\": \"$incident_type\",
                \"host\": \"$(hostname)\",
                \"message\": \"$message\"
            }" 2>/dev/null || true
    fi
}

detect_rootkit() {
    log_incident $SEVERITY_HIGH "Starting rootkit detection scan"
    
    local suspicious_files=()
    local suspicious_processes=()
    
    # Check for suspicious SUID files
    while IFS= read -r -d '' file; do
        if [[ ! -f "/etc/hardened-os/known-suid.list" ]] || ! grep -Fxq "$file" "/etc/hardened-os/known-suid.list"; then
            suspicious_files+=("$file")
        fi
    done < <(find /usr /bin /sbin -perm -4000 -type f -print0 2>/dev/null)
    
    # Check for suspicious network connections
    if command -v netstat >/dev/null 2>&1; then
        while IFS= read -r line; do
            if [[ "$line" =~ :([0-9]+) ]]; then
                local port="${BASH_REMATCH[1]}"
                # Check for suspicious high ports
                if [[ $port -gt 49152 ]] && [[ $port -lt 65535 ]]; then
                    suspicious_processes+=("$line")
                fi
            fi
        done < <(netstat -tlnp 2>/dev/null | grep LISTEN)
    fi
    
    # Check for kernel module anomalies
    local loaded_modules=$(lsmod | tail -n +2 | awk '{print $1}')
    local suspicious_modules=()
    
    for module in $loaded_modules; do
        if [[ ! -f "/lib/modules/$(uname -r)/kernel/"*"/$module.ko"* ]] && \
           [[ ! -f "/lib/modules/$(uname -r)/extra/$module.ko" ]]; then
            suspicious_modules+=("$module")
        fi
    done
    
    # Report findings
    if [[ ${#suspicious_files[@]} -gt 0 ]] || [[ ${#suspicious_processes[@]} -gt 0 ]] || [[ ${#suspicious_modules[@]} -gt 0 ]]; then
        local message="Rootkit detection found suspicious activity:
Suspicious SUID files: ${suspicious_files[*]:-none}
Suspicious network connections: ${suspicious_processes[*]:-none}
Suspicious kernel modules: ${suspicious_modules[*]:-none}"
        
        log_incident $SEVERITY_CRITICAL "Potential rootkit detected"
        send_alert $SEVERITY_CRITICAL "ROOTKIT_DETECTION" "$message"
        
        if [[ "$AUTO_CONTAINMENT" == "true" ]]; then
            contain_threat "rootkit" "${suspicious_files[*]} ${suspicious_processes[*]} ${suspicious_modules[*]}"
        fi
        
        return 1
    else
        log_incident $SEVERITY_LOW "Rootkit detection scan completed - no threats found"
        return 0
    fi
}

detect_intrusion() {
    log_incident $SEVERITY_MEDIUM "Starting intrusion detection scan"
    
    local intrusion_indicators=()
    
    # Check for failed authentication attempts
    local failed_logins=$(journalctl --since "1 hour ago" | grep -c "authentication failure" || echo "0")
    if [[ $failed_logins -gt 10 ]]; then
        intrusion_indicators+=("High number of failed logins: $failed_logins")
    fi
    
    # Check for privilege escalation attempts
    local priv_escalation=$(ausearch -ts recent -k privileged 2>/dev/null | wc -l || echo "0")
    if [[ $priv_escalation -gt 20 ]]; then
        intrusion_indicators+=("High privilege escalation attempts: $priv_escalation")
    fi
    
    # Check for SELinux denials
    local selinux_denials=$(ausearch -ts recent -m avc 2>/dev/null | wc -l || echo "0")
    if [[ $selinux_denials -gt 50 ]]; then
        intrusion_indicators+=("High SELinux denials: $selinux_denials")
    fi
    
    # Check for unusual network activity
    if command -v ss >/dev/null 2>&1; then
        local connections=$(ss -tuln | wc -l)
        if [[ $connections -gt 100 ]]; then
            intrusion_indicators+=("High number of network connections: $connections")
        fi
    fi
    
    # Check for file integrity violations
    if [[ -f "/var/log/aide/aide.log" ]]; then
        local integrity_violations=$(grep -c "CHANGED\|ADDED\|REMOVED" /var/log/aide/aide.log 2>/dev/null || echo "0")
        if [[ $integrity_violations -gt 5 ]]; then
            intrusion_indicators+=("File integrity violations: $integrity_violations")
        fi
    fi
    
    if [[ ${#intrusion_indicators[@]} -gt 0 ]]; then
        local message="Intrusion detection found suspicious activity:
$(printf '%s\n' "${intrusion_indicators[@]}")"
        
        log_incident $SEVERITY_HIGH "Potential intrusion detected"
        send_alert $SEVERITY_HIGH "INTRUSION_DETECTION" "$message"
        
        if [[ "$AUTO_CONTAINMENT" == "true" ]]; then
            contain_threat "intrusion" "$(printf '%s; ' "${intrusion_indicators[@]}")"
        fi
        
        return 1
    else
        log_incident $SEVERITY_LOW "Intrusion detection scan completed - no threats found"
        return 0
    fi
}

detect_malware() {
    log_incident $SEVERITY_MEDIUM "Starting malware detection scan"
    
    local malware_indicators=()
    
    # Check for suspicious processes
    local suspicious_procs=()
    while IFS= read -r line; do
        local proc_name=$(echo "$line" | awk '{print $11}')
        local proc_path=$(echo "$line" | awk '{print $12}')
        
        # Check for processes running from unusual locations
        if [[ "$proc_path" =~ ^/tmp/ ]] || [[ "$proc_path" =~ ^/var/tmp/ ]] || [[ "$proc_path" =~ ^/dev/shm/ ]]; then
            suspicious_procs+=("$proc_name ($proc_path)")
        fi
        
        # Check for processes with suspicious names
        if [[ "$proc_name" =~ (bitcoin|miner|cryptonight|xmrig) ]]; then
            suspicious_procs+=("$proc_name (potential cryptominer)")
        fi
    done < <(ps aux)
    
    # Check for suspicious files in common malware locations
    local suspicious_files=()
    local malware_locations=("/tmp" "/var/tmp" "/dev/shm" "/home/*/.cache")
    
    for location in "${malware_locations[@]}"; do
        if [[ -d "$location" ]]; then
            while IFS= read -r -d '' file; do
                if [[ -x "$file" ]] && [[ ! -d "$file" ]]; then
                    # Check file age (recently created executable files are suspicious)
                    local file_age=$(stat -c %Y "$file")
                    local current_time=$(date +%s)
                    local age_hours=$(( (current_time - file_age) / 3600 ))
                    
                    if [[ $age_hours -lt 24 ]]; then
                        suspicious_files+=("$file (created $age_hours hours ago)")
                    fi
                fi
            done < <(find "$location" -type f -executable -print0 2>/dev/null)
        fi
    done
    
    # Check for unusual CPU usage patterns
    local high_cpu_procs=()
    while IFS= read -r line; do
        local cpu_usage=$(echo "$line" | awk '{print $3}' | sed 's/%//')
        local proc_name=$(echo "$line" | awk '{print $11}')
        
        if (( $(echo "$cpu_usage > 80" | bc -l) )); then
            high_cpu_procs+=("$proc_name ($cpu_usage% CPU)")
        fi
    done < <(ps aux --sort=-%cpu | head -20)
    
    # Compile results
    if [[ ${#suspicious_procs[@]} -gt 0 ]]; then
        malware_indicators+=("Suspicious processes: $(printf '%s, ' "${suspicious_procs[@]}")")
    fi
    
    if [[ ${#suspicious_files[@]} -gt 0 ]]; then
        malware_indicators+=("Suspicious files: $(printf '%s, ' "${suspicious_files[@]}")")
    fi
    
    if [[ ${#high_cpu_procs[@]} -gt 0 ]]; then
        malware_indicators+=("High CPU usage processes: $(printf '%s, ' "${high_cpu_procs[@]}")")
    fi
    
    if [[ ${#malware_indicators[@]} -gt 0 ]]; then
        local message="Malware detection found suspicious activity:
$(printf '%s\n' "${malware_indicators[@]}")"
        
        log_incident $SEVERITY_HIGH "Potential malware detected"
        send_alert $SEVERITY_HIGH "MALWARE_DETECTION" "$message"
        
        if [[ "$AUTO_CONTAINMENT" == "true" ]]; then
            contain_threat "malware" "$(printf '%s; ' "${malware_indicators[@]}")"
        fi
        
        return 1
    else
        log_incident $SEVERITY_LOW "Malware detection scan completed - no threats found"
        return 0
    fi
}

contain_threat() {
    local threat_type="$1"
    local threat_details="$2"
    
    log_incident $SEVERITY_CRITICAL "Initiating automated threat containment for: $threat_type"
    
    # Create quarantine directory
    mkdir -p "$QUARANTINE_DIR"
    chmod 700 "$QUARANTINE_DIR"
    
    case "$threat_type" in
        "rootkit")
            # Network isolation
            log_incident $SEVERITY_HIGH "Implementing network isolation"
            iptables -I INPUT 1 -j DROP
            iptables -I OUTPUT 1 -j DROP
            iptables -I FORWARD 1 -j DROP
            
            # Allow only essential local services
            iptables -I INPUT 1 -i lo -j ACCEPT
            iptables -I OUTPUT 1 -o lo -j ACCEPT
            
            # Stop non-essential services
            systemctl stop NetworkManager || true
            systemctl stop ssh || true
            ;;
            
        "intrusion")
            # Lock user accounts except root
            log_incident $SEVERITY_HIGH "Locking user accounts"
            while IFS=: read -r username _ uid _; do
                if [[ $uid -ge 1000 ]] && [[ "$username" != "nobody" ]]; then
                    passwd -l "$username" || true
                fi
            done < /etc/passwd
            
            # Increase authentication requirements
            echo "auth required pam_tally2.so deny=1 unlock_time=3600" >> /etc/pam.d/common-auth
            ;;
            
        "malware")
            # Kill suspicious processes
            log_incident $SEVERITY_HIGH "Terminating suspicious processes"
            pkill -f "/tmp/" || true
            pkill -f "/var/tmp/" || true
            pkill -f "/dev/shm/" || true
            
            # Mount filesystems read-only where possible
            mount -o remount,ro /tmp || true
            mount -o remount,ro /var/tmp || true
            ;;
    esac
    
    # Create incident snapshot
    create_forensic_snapshot "$threat_type" "$threat_details"
    
    log_incident $SEVERITY_CRITICAL "Threat containment completed for: $threat_type"
    send_alert $SEVERITY_CRITICAL "CONTAINMENT_ACTIVATED" "Automated containment activated for $threat_type: $threat_details"
}

create_forensic_snapshot() {
    local incident_type="$1"
    local incident_details="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local snapshot_dir="$BACKUP_DIR/forensic_$incident_type_$timestamp"
    
    log_incident $SEVERITY_MEDIUM "Creating forensic snapshot: $snapshot_dir"
    
    mkdir -p "$snapshot_dir"
    
    # System information
    {
        echo "=== FORENSIC SNAPSHOT ==="
        echo "Timestamp: $(date -Iseconds)"
        echo "Incident Type: $incident_type"
        echo "Incident Details: $incident_details"
        echo "Host: $(hostname)"
        echo "Kernel: $(uname -a)"
        echo "Uptime: $(uptime)"
        echo ""
        
        echo "=== RUNNING PROCESSES ==="
        ps auxf
        echo ""
        
        echo "=== NETWORK CONNECTIONS ==="
        netstat -tulnp 2>/dev/null || ss -tulnp
        echo ""
        
        echo "=== LOADED MODULES ==="
        lsmod
        echo ""
        
        echo "=== MOUNT POINTS ==="
        mount
        echo ""
        
        echo "=== DISK USAGE ==="
        df -h
        echo ""
        
        echo "=== MEMORY USAGE ==="
        free -h
        echo ""
        
        echo "=== RECENT LOGINS ==="
        last -20
        echo ""
        
        echo "=== CRON JOBS ==="
        crontab -l 2>/dev/null || echo "No crontab for root"
        echo ""
        
        echo "=== SYSTEMD SERVICES ==="
        systemctl list-units --type=service --state=running
        echo ""
        
    } > "$snapshot_dir/system_snapshot.txt"
    
    # Copy critical log files
    cp /var/log/auth.log "$snapshot_dir/" 2>/dev/null || true
    cp /var/log/syslog "$snapshot_dir/" 2>/dev/null || true
    cp /var/log/audit/audit.log "$snapshot_dir/" 2>/dev/null || true
    cp "$LOG_FILE" "$snapshot_dir/" 2>/dev/null || true
    
    # Export journal logs
    journalctl --since "24 hours ago" > "$snapshot_dir/journal_24h.log" 2>/dev/null || true
    
    # Network configuration
    ip addr show > "$snapshot_dir/network_config.txt" 2>/dev/null || true
    ip route show >> "$snapshot_dir/network_config.txt" 2>/dev/null || true
    
    # File system information
    find /tmp /var/tmp /dev/shm -type f -ls > "$snapshot_dir/temp_files.txt" 2>/dev/null || true
    
    # Set appropriate permissions
    chmod -R 600 "$snapshot_dir"
    
    log_incident $SEVERITY_MEDIUM "Forensic snapshot created: $snapshot_dir"
}

run_incident_scan() {
    local scan_type="${1:-all}"
    
    log_incident $SEVERITY_LOW "Starting incident response scan: $scan_type"
    
    local threats_detected=0
    
    case "$scan_type" in
        "rootkit"|"all")
            if ! detect_rootkit; then
                ((threats_detected++))
            fi
            ;;& # Continue to next case
        "intrusion"|"all")
            if ! detect_intrusion; then
                ((threats_detected++))
            fi
            ;;& # Continue to next case
        "malware"|"all")
            if ! detect_malware; then
                ((threats_detected++))
            fi
            ;;
        *)
            echo "Unknown scan type: $scan_type"
            echo "Valid types: rootkit, intrusion, malware, all"
            exit 1
            ;;
    esac
    
    if [[ $threats_detected -eq 0 ]]; then
        log_incident $SEVERITY_LOW "Incident response scan completed - no threats detected"
        echo -e "${GREEN}✓ No threats detected${NC}"
    else
        log_incident $SEVERITY_CRITICAL "Incident response scan completed - $threats_detected threats detected"
        echo -e "${RED}⚠ $threats_detected threats detected - check logs for details${NC}"
    fi
    
    return $threats_detected
}

show_status() {
    echo -e "${BLUE}Hardened OS Incident Response Status${NC}"
    echo "===================================="
    echo ""
    
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Alert Email: ${ALERT_EMAIL:-not configured}"
    echo "  Alert Webhook: ${ALERT_WEBHOOK:-not configured}"
    echo "  Auto Containment: ${AUTO_CONTAINMENT:-false}"
    echo "  Auto Recovery: ${AUTO_RECOVERY:-false}"
    echo "  Forensic Mode: ${FORENSIC_MODE:-false}"
    echo ""
    
    echo -e "${YELLOW}Recent Incidents (last 24h):${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        local recent_incidents=$(grep "$(date -d '24 hours ago' +%Y-%m-%d)" "$LOG_FILE" 2>/dev/null | wc -l)
        echo "  Total incidents: $recent_incidents"
        
        local critical_incidents=$(grep "SEVERITY:$SEVERITY_CRITICAL" "$LOG_FILE" 2>/dev/null | grep "$(date -d '24 hours ago' +%Y-%m-%d)" | wc -l)
        echo "  Critical incidents: $critical_incidents"
        
        if [[ $critical_incidents -gt 0 ]]; then
            echo -e "${RED}  ⚠ Critical incidents detected - review logs immediately${NC}"
        fi
    else
        echo "  No incident log found"
    fi
    echo ""
    
    echo -e "${YELLOW}System Status:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p)"
    echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
    echo ""
    
    echo -e "${YELLOW}Security Services:${NC}"
    local services=("auditd" "systemd-journald" "hardened-log-server" "fail2ban")
    for service in "${services[@]}"; do
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
        "scan")
            run_incident_scan "${2:-all}"
            ;;
        "contain")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 contain <threat_type> <threat_details>"
                exit 1
            fi
            contain_threat "$2" "$3"
            ;;
        "snapshot")
            create_forensic_snapshot "${2:-manual}" "${3:-Manual snapshot requested}"
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            echo "Hardened OS Incident Response Framework"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  scan [type]           Run incident detection scan (rootkit|intrusion|malware|all)"
            echo "  contain <type> <details>  Manually trigger threat containment"
            echo "  snapshot [type] [details] Create forensic snapshot"
            echo "  status                Show system and incident response status"
            echo "  help                  Show this help message"
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