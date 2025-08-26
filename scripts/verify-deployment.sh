#!/bin/bash
# Comprehensive Deployment Verification Script
# Verifies all security features and system integrity after deployment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/hardened-os-verification.log"
REPORT_FILE="/var/log/verification-report-$(date +%Y%m%d-%H%M%S).md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} $message" | tee -a "$LOG_FILE"
}

warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] WARNING:${NC} $message" | tee -a "$LOG_FILE"
    TESTS_WARNINGS=$((TESTS_WARNINGS + 1))
}

error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] ERROR:${NC} $message" | tee -a "$LOG_FILE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        log "TEST PASS: $test_name $details"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$result" == "FAIL" ]]; then
        echo -e "${RED}✗${NC} $test_name"
        error "TEST FAIL: $test_name $details"
    elif [[ "$result" == "WARN" ]]; then
        echo -e "${YELLOW}⚠${NC} $test_name"
        warn "TEST WARN: $test_name $details"
    fi
}

# Boot Security Verification
verify_boot_security() {
    echo -e "${BLUE}=== Boot Security Verification ===${NC}"
    
    # UEFI Secure Boot
    if [[ -d /sys/firmware/efi ]]; then
        test_result "UEFI Firmware" "PASS" "UEFI detected"
        
        # Check Secure Boot status
        if command -v mokutil &> /dev/null; then
            if mokutil --sb-state | grep -q "SecureBoot enabled"; then
                test_result "Secure Boot Status" "PASS" "Enabled"
            else
                test_result "Secure Boot Status" "FAIL" "Disabled or not configured"
            fi
        else
            test_result "Secure Boot Tools" "WARN" "mokutil not available"
        fi
        
        # Check custom keys
        if command -v sbctl &> /dev/null; then
            if sbctl status | grep -q "Setup Mode: Disabled"; then
                test_result "Custom Secure Boot Keys" "PASS" "Custom keys enrolled"
            else
                test_result "Custom Secure Boot Keys" "WARN" "May be using default keys"
            fi
        else
            test_result "sbctl Tool" "WARN" "sbctl not available"
        fi
    else
        test_result "UEFI Firmware" "FAIL" "Legacy BIOS detected"
    fi
    
    # TPM 2.0 Verification
    if [[ -c /dev/tpm0 ]] || [[ -c /dev/tpmrm0 ]]; then
        test_result "TPM Device" "PASS" "TPM device detected"
        
        # Check TPM version
        if command -v tpm2_getcap &> /dev/null; then
            if tpm2_getcap properties-fixed | grep -q "TPM2"; then
                test_result "TPM Version" "PASS" "TPM 2.0 confirmed"
            else
                test_result "TPM Version" "WARN" "TPM version unclear"
            fi
            
            # Check PCR measurements
            if tpm2_pcrread sha256:0,1,2,3,4,5,6,7 &> /dev/null; then
                test_result "TPM PCR Measurements" "PASS" "PCRs readable"
            else
                test_result "TPM PCR Measurements" "FAIL" "Cannot read PCRs"
            fi
        else
            test_result "TPM Tools" "FAIL" "tpm2-tools not available"
        fi
    else
        test_result "TPM Device" "FAIL" "No TPM device detected"
    fi
    
    # Measured Boot
    if [[ -f /sys/kernel/security/tpm0/binary_bios_measurements ]]; then
        test_result "Measured Boot" "PASS" "Boot measurements available"
    else
        test_result "Measured Boot" "WARN" "Boot measurements not found"
    fi
}

# Disk Encryption Verification
verify_disk_encryption() {
    echo -e "${BLUE}=== Disk Encryption Verification ===${NC}"
    
    # Check for LUKS devices
    local luks_devices=$(lsblk -f | grep -c "crypto_LUKS" || true)
    if [[ $luks_devices -gt 0 ]]; then
        test_result "LUKS Encryption" "PASS" "$luks_devices encrypted device(s)"
        
        # Check LUKS version and configuration
        for device in $(lsblk -f | grep "crypto_LUKS" | awk '{print $1}' | sed 's/[├└─│]//g' | tr -d ' '); do
            if cryptsetup luksDump "/dev/$device" | grep -q "Version:.*2"; then
                test_result "LUKS Version (/dev/$device)" "PASS" "LUKS2 detected"
                
                # Check key derivation function
                if cryptsetup luksDump "/dev/$device" | grep -q "argon2id"; then
                    test_result "Key Derivation (/dev/$device)" "PASS" "Argon2id KDF"
                else
                    test_result "Key Derivation (/dev/$device)" "WARN" "Non-Argon2id KDF"
                fi
            else
                test_result "LUKS Version (/dev/$device)" "WARN" "LUKS1 or unknown version"
            fi
        done
    else
        test_result "LUKS Encryption" "FAIL" "No encrypted devices found"
    fi
    
    # Check swap encryption
    if swapon --show | grep -q "/dev/mapper/"; then
        test_result "Encrypted Swap" "PASS" "Swap appears encrypted"
    else
        test_result "Encrypted Swap" "WARN" "Swap encryption unclear"
    fi
    
    # Check TPM2 key sealing
    if command -v systemd-cryptenroll &> /dev/null; then
        local tpm_sealed=false
        for device in $(lsblk -f | grep "crypto_LUKS" | awk '{print $1}' | sed 's/[├└─│]//g' | tr -d ' '); do
            if systemd-cryptenroll "/dev/$device" | grep -q "tpm2"; then
                tpm_sealed=true
                break
            fi
        done
        
        if [[ "$tpm_sealed" == true ]]; then
            test_result "TPM2 Key Sealing" "PASS" "Keys sealed to TPM2"
        else
            test_result "TPM2 Key Sealing" "WARN" "No TPM2-sealed keys found"
        fi
    else
        test_result "systemd-cryptenroll" "WARN" "Tool not available"
    fi
}

# Kernel Security Verification
verify_kernel_security() {
    echo -e "${BLUE}=== Kernel Security Verification ===${NC}"
    
    # Check kernel version and configuration
    local kernel_version=$(uname -r)
    test_result "Kernel Version" "PASS" "$kernel_version"
    
    # Check for hardening features in kernel config
    if [[ -f /proc/config.gz ]]; then
        local config_file="/tmp/kernel-config-$$"
        zcat /proc/config.gz > "$config_file"
        
        # Check key hardening options
        local hardening_options=(
            "CONFIG_SECURITY_DMESG_RESTRICT=y"
            "CONFIG_SECURITY_KEXEC_VERIFY_SIG=y"
            "CONFIG_SECURITY_LOCKDOWN_LSM=y"
            "CONFIG_VMAP_STACK=y"
            "CONFIG_RANDOMIZE_BASE=y"
            "CONFIG_HARDENED_USERCOPY=y"
            "CONFIG_FORTIFY_SOURCE=y"
            "CONFIG_STACKPROTECTOR_STRONG=y"
        )
        
        local hardening_enabled=0
        for option in "${hardening_options[@]}"; do
            if grep -q "^$option" "$config_file"; then
                hardening_enabled=$((hardening_enabled + 1))
            fi
        done
        
        if [[ $hardening_enabled -ge 6 ]]; then
            test_result "Kernel Hardening Options" "PASS" "$hardening_enabled/8 enabled"
        elif [[ $hardening_enabled -ge 4 ]]; then
            test_result "Kernel Hardening Options" "WARN" "$hardening_enabled/8 enabled"
        else
            test_result "Kernel Hardening Options" "FAIL" "$hardening_enabled/8 enabled"
        fi
        
        rm -f "$config_file"
    else
        test_result "Kernel Config" "WARN" "/proc/config.gz not available"
    fi
    
    # Check runtime security features
    if dmesg | grep -q "KASLR"; then
        test_result "KASLR" "PASS" "Kernel Address Space Layout Randomization active"
    else
        test_result "KASLR" "WARN" "KASLR status unclear"
    fi
    
    if dmesg | grep -q "SMEP"; then
        test_result "SMEP" "PASS" "Supervisor Mode Execution Prevention active"
    else
        test_result "SMEP" "WARN" "SMEP status unclear"
    fi
    
    if dmesg | grep -q "SMAP"; then
        test_result "SMAP" "PASS" "Supervisor Mode Access Prevention active"
    else
        test_result "SMAP" "WARN" "SMAP status unclear"
    fi
}

# SELinux Verification
verify_selinux() {
    echo -e "${BLUE}=== SELinux Verification ===${NC}"
    
    if command -v sestatus &> /dev/null; then
        local selinux_status=$(sestatus | grep "SELinux status:" | awk '{print $3}')
        local selinux_mode=$(sestatus | grep "Current mode:" | awk '{print $3}')
        
        if [[ "$selinux_status" == "enabled" ]]; then
            test_result "SELinux Status" "PASS" "Enabled"
            
            if [[ "$selinux_mode" == "enforcing" ]]; then
                test_result "SELinux Mode" "PASS" "Enforcing"
            elif [[ "$selinux_mode" == "permissive" ]]; then
                test_result "SELinux Mode" "WARN" "Permissive (should be enforcing)"
            else
                test_result "SELinux Mode" "FAIL" "Unknown mode: $selinux_mode"
            fi
            
            # Check policy type
            local policy_type=$(sestatus | grep "Loaded policy name:" | awk '{print $4}')
            if [[ "$policy_type" == "targeted" ]]; then
                test_result "SELinux Policy" "PASS" "Targeted policy"
            else
                test_result "SELinux Policy" "WARN" "Non-targeted policy: $policy_type"
            fi
        else
            test_result "SELinux Status" "FAIL" "Disabled"
        fi
    else
        test_result "SELinux Tools" "FAIL" "SELinux tools not available"
    fi
    
    # Check for recent denials
    if command -v ausearch &> /dev/null; then
        local recent_denials=$(ausearch -m avc -ts recent 2>/dev/null | wc -l || echo "0")
        if [[ $recent_denials -eq 0 ]]; then
            test_result "SELinux Denials" "PASS" "No recent denials"
        elif [[ $recent_denials -lt 10 ]]; then
            test_result "SELinux Denials" "WARN" "$recent_denials recent denials"
        else
            test_result "SELinux Denials" "FAIL" "$recent_denials recent denials (high)"
        fi
    fi
}

# Service Security Verification
verify_service_security() {
    echo -e "${BLUE}=== Service Security Verification ===${NC}"
    
    # Check running services
    local running_services=$(systemctl list-units --type=service --state=running --no-pager --no-legend | wc -l)
    if [[ $running_services -lt 50 ]]; then
        test_result "Running Services" "PASS" "$running_services services (minimal)"
    elif [[ $running_services -lt 100 ]]; then
        test_result "Running Services" "WARN" "$running_services services (moderate)"
    else
        test_result "Running Services" "FAIL" "$running_services services (too many)"
    fi
    
    # Check for unnecessary services
    local unnecessary_services=("telnet" "ftp" "rsh" "rlogin" "tftp" "xinetd" "cups" "avahi-daemon")
    local found_unnecessary=0
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-active "$service" &> /dev/null; then
            found_unnecessary=$((found_unnecessary + 1))
        fi
    done
    
    if [[ $found_unnecessary -eq 0 ]]; then
        test_result "Unnecessary Services" "PASS" "No unnecessary services running"
    else
        test_result "Unnecessary Services" "WARN" "$found_unnecessary unnecessary services found"
    fi
    
    # Check SSH configuration
    if systemctl is-active ssh &> /dev/null; then
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
            test_result "SSH Root Login" "PASS" "Root login disabled"
        else
            test_result "SSH Root Login" "WARN" "Root login may be enabled"
        fi
        
        if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
            test_result "SSH Password Auth" "PASS" "Password authentication disabled"
        else
            test_result "SSH Password Auth" "WARN" "Password authentication may be enabled"
        fi
    fi
}

# Network Security Verification
verify_network_security() {
    echo -e "${BLUE}=== Network Security Verification ===${NC}"
    
    # Check firewall status
    if command -v nft &> /dev/null; then
        if nft list tables | grep -q "inet filter"; then
            test_result "nftables Firewall" "PASS" "nftables configured"
            
            # Check default policies
            if nft list chain inet filter input | grep -q "policy drop"; then
                test_result "Input Policy" "PASS" "Default drop"
            else
                test_result "Input Policy" "WARN" "Default policy not drop"
            fi
            
            if nft list chain inet filter output | grep -q "policy drop"; then
                test_result "Output Policy" "PASS" "Default drop"
            else
                test_result "Output Policy" "WARN" "Default policy not drop"
            fi
        else
            test_result "nftables Firewall" "WARN" "nftables not configured"
        fi
    else
        test_result "nftables" "WARN" "nftables not available"
    fi
    
    # Check for open ports
    local open_ports=$(ss -tuln | grep LISTEN | wc -l)
    if [[ $open_ports -lt 5 ]]; then
        test_result "Open Ports" "PASS" "$open_ports listening ports"
    elif [[ $open_ports -lt 10 ]]; then
        test_result "Open Ports" "WARN" "$open_ports listening ports"
    else
        test_result "Open Ports" "FAIL" "$open_ports listening ports (too many)"
    fi
    
    # Check DNS configuration
    if systemctl is-active systemd-resolved &> /dev/null; then
        if systemd-resolve --status | grep -q "DNS over TLS"; then
            test_result "DNS over TLS" "PASS" "Configured"
        else
            test_result "DNS over TLS" "WARN" "Not configured"
        fi
    fi
}

# Application Security Verification
verify_application_security() {
    echo -e "${BLUE}=== Application Security Verification ===${NC}"
    
    # Check for sandboxing tools
    if command -v bwrap &> /dev/null; then
        test_result "Bubblewrap Sandboxing" "PASS" "Available"
        
        # Check for sandbox services
        local sandbox_services=$(systemctl list-units --type=service --all | grep -c "sandbox" || true)
        if [[ $sandbox_services -gt 0 ]]; then
            test_result "Sandbox Services" "PASS" "$sandbox_services sandbox services"
        else
            test_result "Sandbox Services" "WARN" "No sandbox services found"
        fi
    else
        test_result "Bubblewrap Sandboxing" "FAIL" "Not available"
    fi
    
    # Check SUID/SGID binaries
    local suid_count=$(find /usr -perm -4000 -type f 2>/dev/null | wc -l)
    local sgid_count=$(find /usr -perm -2000 -type f 2>/dev/null | wc -l)
    
    if [[ $suid_count -lt 20 ]]; then
        test_result "SUID Binaries" "PASS" "$suid_count SUID binaries"
    elif [[ $suid_count -lt 50 ]]; then
        test_result "SUID Binaries" "WARN" "$suid_count SUID binaries"
    else
        test_result "SUID Binaries" "FAIL" "$suid_count SUID binaries (too many)"
    fi
    
    if [[ $sgid_count -lt 10 ]]; then
        test_result "SGID Binaries" "PASS" "$sgid_count SGID binaries"
    else
        test_result "SGID Binaries" "WARN" "$sgid_count SGID binaries"
    fi
}

# Logging and Monitoring Verification
verify_logging_monitoring() {
    echo -e "${BLUE}=== Logging and Monitoring Verification ===${NC}"
    
    # Check systemd journal
    if systemctl is-active systemd-journald &> /dev/null; then
        test_result "systemd Journal" "PASS" "Active"
        
        # Check journal signing
        if journalctl --verify &> /dev/null; then
            test_result "Journal Integrity" "PASS" "Verification successful"
        else
            test_result "Journal Integrity" "WARN" "Verification failed or not configured"
        fi
    else
        test_result "systemd Journal" "FAIL" "Not active"
    fi
    
    # Check audit daemon
    if systemctl is-active auditd &> /dev/null; then
        test_result "Audit Daemon" "PASS" "Active"
        
        # Check audit rules
        if auditctl -l | grep -q "syscall"; then
            test_result "Audit Rules" "PASS" "Syscall auditing configured"
        else
            test_result "Audit Rules" "WARN" "Limited audit rules"
        fi
    else
        test_result "Audit Daemon" "WARN" "Not active"
    fi
    
    # Check log forwarding
    if systemctl is-active systemd-journal-upload &> /dev/null; then
        test_result "Log Forwarding" "PASS" "Configured"
    else
        test_result "Log Forwarding" "WARN" "Not configured"
    fi
}

# Update System Verification
verify_update_system() {
    echo -e "${BLUE}=== Update System Verification ===${NC}"
    
    # Check package manager security
    if command -v apt &> /dev/null; then
        if apt-config dump | grep -q "APT::Get::AllowUnauthenticated.*false"; then
            test_result "Package Authentication" "PASS" "Unauthenticated packages blocked"
        else
            test_result "Package Authentication" "WARN" "Package authentication unclear"
        fi
    fi
    
    # Check for custom update system
    if [[ -f /usr/local/bin/hardened-update ]]; then
        test_result "Hardened Update System" "PASS" "Custom update system installed"
    else
        test_result "Hardened Update System" "WARN" "Custom update system not found"
    fi
    
    # Check automatic updates
    if systemctl is-enabled unattended-upgrades &> /dev/null; then
        test_result "Automatic Updates" "PASS" "Enabled"
    else
        test_result "Automatic Updates" "WARN" "Not enabled"
    fi
}

# Generate verification report
generate_verification_report() {
    cat > "$REPORT_FILE" << EOF
# Hardened Laptop OS Verification Report

## Summary
- **Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **System**: $(uname -a)
- **Verified By**: $(whoami)

## Test Results
- **Total Tests**: $TESTS_TOTAL
- **Passed**: $TESTS_PASSED
- **Failed**: $TESTS_FAILED
- **Warnings**: $TESTS_WARNINGS

## Success Rate
$(( TESTS_PASSED * 100 / TESTS_TOTAL ))% of tests passed

## Security Status
$(if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✅ **SECURE** - All critical tests passed"
elif [[ $TESTS_FAILED -lt 3 ]]; then
    echo "⚠️ **MOSTLY SECURE** - Minor issues detected"
else
    echo "❌ **SECURITY ISSUES** - Multiple failures detected"
fi)

## Recommendations
$(if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "- Review failed tests and address security issues"
fi)
$(if [[ $TESTS_WARNINGS -gt 5 ]]; then
    echo "- Consider addressing warning conditions"
fi)
- Regularly run verification checks
- Keep system updated
- Monitor security logs

## Detailed Results
See full verification log: $LOG_FILE

---
**Verification completed**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
EOF

    log "Verification report generated: $REPORT_FILE"
}

# Main verification function
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              HARDENED LAPTOP OS VERIFICATION                 ║
║                                                               ║
║  Comprehensive security verification and testing             ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "Starting Hardened Laptop OS verification..."
    
    # Run verification tests
    verify_boot_security
    verify_disk_encryption
    verify_kernel_security
    verify_selinux
    verify_service_security
    verify_network_security
    verify_application_security
    verify_logging_monitoring
    verify_update_system
    
    # Generate report
    generate_verification_report
    
    # Summary
    echo -e "\n${BLUE}=== Verification Summary ===${NC}"
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Warnings: ${YELLOW}$TESTS_WARNINGS${NC}"
    
    local success_rate=$(( TESTS_PASSED * 100 / TESTS_TOTAL ))
    echo "Success Rate: $success_rate%"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ VERIFICATION PASSED${NC}"
        echo "Your Hardened Laptop OS is properly configured and secure!"
    elif [[ $TESTS_FAILED -lt 3 ]]; then
        echo -e "\n${YELLOW}⚠️ VERIFICATION COMPLETED WITH WARNINGS${NC}"
        echo "Minor security issues detected. Review the report for details."
    else
        echo -e "\n${RED}❌ VERIFICATION FAILED${NC}"
        echo "Multiple security issues detected. Immediate attention required."
    fi
    
    echo -e "\nDetailed report: $REPORT_FILE"
    echo -e "Verification log: $LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script should be run as root for complete verification"
    echo "Some tests may be skipped or show warnings"
fi

# Execute main function
main "$@"