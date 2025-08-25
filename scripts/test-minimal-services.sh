#!/bin/bash
#
# Minimal System Services Testing Script
# Tests attack surface reduction configuration
#
# Part of Task 10: Implement minimal system services and attack surface reduction
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
LOG_FILE="$WORK_DIR/minimal-services-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize test logging
init_test_logging() {
    mkdir -p "$WORK_DIR"
    echo "=== Minimal System Services Testing Log - $(date) ===" > "$LOG_FILE"
}

# Test 1: Verify unnecessary services are disabled
test_service_minimization() {
    log_test "Testing system service minimization..."
    
    # Services that should be disabled
    local services_should_be_disabled=(
        "bluetooth.service"
        "cups.service"
        "avahi-daemon.service"
        "whoopsie.service"
        "apport.service"
        "snapd.service"
    )
    
    local disabled_count=0
    local total_tests=0
    
    for service in "${services_should_be_disabled[@]}"; do
        total_tests=$((total_tests + 1))
        
        if systemctl is-enabled "$service" &>/dev/null; then
            log_warn "Service $service is still enabled (should be disabled)"
        else
            log_info "✓ Service $service is disabled"
            disabled_count=$((disabled_count + 1))
        fi
    done
    
    # Check if service is also stopped
    local stopped_count=0
    for service in "${services_should_be_disabled[@]}"; do
        if ! systemctl is-active "$service" &>/dev/null; then
            stopped_count=$((stopped_count + 1))
        fi
    done
    
    log_info "Service minimization results: $disabled_count/$total_tests disabled, $stopped_count/$total_tests stopped"
    
    if [ $disabled_count -eq $total_tests ]; then
        log_info "✓ Service minimization test PASSED"
        return 0
    else
        log_warn "Service minimization test PARTIAL - some services still enabled"
        return 1
    fi
}

# Test 2: Verify essential services are still running
test_essential_services() {
    log_test "Testing essential services are running..."
    
    # Services that should remain enabled/running
    local essential_services=(
        "systemd-logind.service"
        "dbus.service"
        "ssh.service"
        "cron.service"
        "rsyslog.service"
    )
    
    local running_count=0
    local total_tests=0
    
    for service in "${essential_services[@]}"; do
        total_tests=$((total_tests + 1))
        
        if systemctl is-active "$service" &>/dev/null; then
            log_info "✓ Essential service $service is running"
            running_count=$((running_count + 1))
        else
            log_warn "Essential service $service is not running"
        fi
    done
    
    log_info "Essential services results: $running_count/$total_tests running"
    
    if [ $running_count -ge $((total_tests * 3 / 4)) ]; then
        log_info "✓ Essential services test PASSED"
        return 0
    else
        log_error "✗ Essential services test FAILED - too many essential services down"
        return 1
    fi
}

# Test 3: Verify SUID/SGID binary minimization
test_suid_sgid_minimization() {
    log_test "Testing SUID/SGID binary minimization..."
    
    # Binaries that should NOT have SUID bit
    local should_not_be_suid=(
        "/bin/ping"
        "/bin/ping6"
        "/usr/bin/traceroute6.iputils"
    )
    
    local correct_count=0
    local total_tests=0
    
    for binary in "${should_not_be_suid[@]}"; do
        if [ -f "$binary" ]; then
            total_tests=$((total_tests + 1))
            
            if [ -u "$binary" ]; then
                log_warn "Binary $binary still has SUID bit (should be removed)"
            else
                log_info "✓ Binary $binary SUID bit removed"
                correct_count=$((correct_count + 1))
                
                # Check if capability was added instead
                if command -v getcap &>/dev/null; then
                    local caps=$(getcap "$binary" 2>/dev/null || echo "")
                    if [[ "$caps" == *"cap_net_raw"* ]]; then
                        log_info "  ✓ Capability cap_net_raw added to $binary"
                    fi
                fi
            fi
        fi
    done
    
    # Count remaining SUID binaries
    local suid_count=$(find /usr -type f -perm -4000 2>/dev/null | wc -l)
    local sgid_count=$(find /usr -type f -perm -2000 2>/dev/null | wc -l)
    
    log_info "SUID/SGID results: $correct_count/$total_tests corrected, $suid_count SUID binaries, $sgid_count SGID binaries remaining"
    
    # Test ping functionality with capabilities
    if command -v ping &>/dev/null; then
        if ping -c 1 -W 2 127.0.0.1 &>/dev/null; then
            log_info "✓ Ping functionality working with capabilities"
        else
            log_warn "Ping functionality may be broken"
        fi
    fi
    
    if [ $total_tests -eq 0 ] || [ $correct_count -eq $total_tests ]; then
        log_info "✓ SUID/SGID minimization test PASSED"
        return 0
    else
        log_warn "SUID/SGID minimization test PARTIAL"
        return 1
    fi
}

# Test 4: Verify kernel module blacklisting
test_kernel_module_blacklist() {
    log_test "Testing kernel module blacklisting..."
    
    # Modules that should be blacklisted
    local blacklisted_modules=(
        "dccp"
        "sctp"
        "rds"
        "tipc"
        "cramfs"
        "freevxfs"
    )
    
    local blacklisted_count=0
    local total_tests=0
    
    # Check if blacklist file exists
    if [ ! -f /etc/modprobe.d/hardened-blacklist.conf ]; then
        log_error "✗ Kernel module blacklist file not found"
        return 1
    fi
    
    log_info "✓ Kernel module blacklist file exists"
    
    for module in "${blacklisted_modules[@]}"; do
        total_tests=$((total_tests + 1))
        
        # Check if module is blacklisted in configuration
        if grep -q "blacklist $module" /etc/modprobe.d/hardened-blacklist.conf 2>/dev/null; then
            log_info "✓ Module $module is blacklisted in configuration"
            blacklisted_count=$((blacklisted_count + 1))
            
            # Try to load the module (should fail)
            if ! sudo modprobe "$module" 2>/dev/null; then
                log_info "  ✓ Module $module correctly blocked from loading"
            else
                log_warn "  Module $module loaded despite blacklist"
                # Unload it if it loaded
                sudo modprobe -r "$module" 2>/dev/null || true
            fi
        else
            log_warn "Module $module not found in blacklist"
        fi
    done
    
    log_info "Module blacklist results: $blacklisted_count/$total_tests blacklisted"
    
    if [ $blacklisted_count -eq $total_tests ]; then
        log_info "✓ Kernel module blacklist test PASSED"
        return 0
    else
        log_warn "Kernel module blacklist test PARTIAL"
        return 1
    fi
}

# Test 5: Verify secure sysctl configuration
test_secure_sysctl() {
    log_test "Testing secure sysctl configuration..."
    
    # Key security settings to verify
    local sysctl_tests=(
        "kernel.randomize_va_space:2"
        "kernel.kptr_restrict:2"
        "kernel.dmesg_restrict:1"
        "net.ipv4.ip_forward:0"
        "net.ipv4.conf.all.accept_source_route:0"
        "net.ipv4.conf.all.accept_redirects:0"
        "net.ipv4.conf.all.rp_filter:1"
        "net.ipv4.tcp_syncookies:1"
        "fs.suid_dumpable:0"
        "kernel.yama.ptrace_scope:1"
    )
    
    local correct_count=0
    local total_tests=0
    
    # Check if sysctl file exists
    if [ ! -f /etc/sysctl.d/99-hardened-security.conf ]; then
        log_error "✗ Secure sysctl configuration file not found"
        return 1
    fi
    
    log_info "✓ Secure sysctl configuration file exists"
    
    for test_case in "${sysctl_tests[@]}"; do
        local setting=$(echo "$test_case" | cut -d: -f1)
        local expected=$(echo "$test_case" | cut -d: -f2)
        
        total_tests=$((total_tests + 1))
        
        # Get current value
        local current=$(sysctl -n "$setting" 2>/dev/null || echo "unknown")
        
        if [ "$current" = "$expected" ]; then
            log_info "✓ $setting = $current (correct)"
            correct_count=$((correct_count + 1))
        else
            log_warn "$setting = $current (expected $expected)"
        fi
    done
    
    log_info "Sysctl security results: $correct_count/$total_tests correct"
    
    if [ $correct_count -ge $((total_tests * 4 / 5)) ]; then
        log_info "✓ Secure sysctl test PASSED"
        return 0
    else
        log_warn "Secure sysctl test PARTIAL - some settings incorrect"
        return 1
    fi
}

# Test 6: Verify network security settings
test_network_security() {
    log_test "Testing network security configuration..."
    
    local tests_passed=0
    local total_tests=0
    
    # Test IP forwarding is disabled
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "0" ]; then
        log_info "✓ IP forwarding disabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "IP forwarding not disabled"
    fi
    
    # Test source routing is disabled
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null)" = "0" ]; then
        log_info "✓ Source routing disabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Source routing not disabled"
    fi
    
    # Test ICMP redirects are disabled
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null)" = "0" ]; then
        log_info "✓ ICMP redirects disabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "ICMP redirects not disabled"
    fi
    
    # Test reverse path filtering is enabled
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null)" = "1" ]; then
        log_info "✓ Reverse path filtering enabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Reverse path filtering not enabled"
    fi
    
    # Test TCP SYN cookies are enabled
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)" = "1" ]; then
        log_info "✓ TCP SYN cookies enabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "TCP SYN cookies not enabled"
    fi
    
    log_info "Network security results: $tests_passed/$total_tests passed"
    
    if [ $tests_passed -eq $total_tests ]; then
        log_info "✓ Network security test PASSED"
        return 0
    else
        log_warn "Network security test PARTIAL"
        return 1
    fi
}

# Test 7: Verify memory protection settings
test_memory_protection() {
    log_test "Testing memory protection configuration..."
    
    local tests_passed=0
    local total_tests=0
    
    # Test ASLR is at maximum
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n kernel.randomize_va_space 2>/dev/null)" = "2" ]; then
        log_info "✓ ASLR at maximum level (2)"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "ASLR not at maximum level"
    fi
    
    # Test kernel pointer restriction
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n kernel.kptr_restrict 2>/dev/null)" = "2" ]; then
        log_info "✓ Kernel pointer restriction at maximum (2)"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Kernel pointer restriction not at maximum"
    fi
    
    # Test dmesg restriction
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n kernel.dmesg_restrict 2>/dev/null)" = "1" ]; then
        log_info "✓ Dmesg access restricted"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Dmesg access not restricted"
    fi
    
    # Test SUID core dumps disabled
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n fs.suid_dumpable 2>/dev/null)" = "0" ]; then
        log_info "✓ SUID core dumps disabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "SUID core dumps not disabled"
    fi
    
    # Test ptrace scope restriction
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null)" = "1" ]; then
        log_info "✓ Ptrace scope restricted"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Ptrace scope not restricted"
    fi
    
    log_info "Memory protection results: $tests_passed/$total_tests passed"
    
    if [ $tests_passed -eq $total_tests ]; then
        log_info "✓ Memory protection test PASSED"
        return 0
    else
        log_warn "Memory protection test PARTIAL"
        return 1
    fi
}

# Test 8: Verify file system protections
test_filesystem_protection() {
    log_test "Testing file system protection configuration..."
    
    local tests_passed=0
    local total_tests=0
    
    # Test protected hardlinks
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n fs.protected_hardlinks 2>/dev/null)" = "1" ]; then
        log_info "✓ Protected hardlinks enabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Protected hardlinks not enabled"
    fi
    
    # Test protected symlinks
    total_tests=$((total_tests + 1))
    if [ "$(sysctl -n fs.protected_symlinks 2>/dev/null)" = "1" ]; then
        log_info "✓ Protected symlinks enabled"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Protected symlinks not enabled"
    fi
    
    # Test protected FIFOs
    total_tests=$((total_tests + 1))
    local protected_fifos=$(sysctl -n fs.protected_fifos 2>/dev/null || echo "0")
    if [ "$protected_fifos" -ge "1" ]; then
        log_info "✓ Protected FIFOs enabled (level $protected_fifos)"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Protected FIFOs not enabled"
    fi
    
    # Test protected regular files
    total_tests=$((total_tests + 1))
    local protected_regular=$(sysctl -n fs.protected_regular 2>/dev/null || echo "0")
    if [ "$protected_regular" -ge "1" ]; then
        log_info "✓ Protected regular files enabled (level $protected_regular)"
        tests_passed=$((tests_passed + 1))
    else
        log_warn "Protected regular files not enabled"
    fi
    
    log_info "File system protection results: $tests_passed/$total_tests passed"
    
    if [ $tests_passed -eq $total_tests ]; then
        log_info "✓ File system protection test PASSED"
        return 0
    else
        log_warn "File system protection test PARTIAL"
        return 1
    fi
}

# Test 9: Overall attack surface assessment
test_attack_surface_reduction() {
    log_test "Assessing overall attack surface reduction..."
    
    # Count running services
    local running_services=$(systemctl list-units --type=service --state=running --no-pager | grep -c "\.service" || echo "0")
    
    # Count enabled services
    local enabled_services=$(systemctl list-unit-files --type=service --state=enabled --no-pager | grep -c "\.service" || echo "0")
    
    # Count SUID binaries
    local suid_binaries=$(find /usr -type f -perm -4000 2>/dev/null | wc -l)
    
    # Count SGID binaries
    local sgid_binaries=$(find /usr -type f -perm -2000 2>/dev/null | wc -l)
    
    # Count loaded modules
    local loaded_modules=$(lsmod | wc -l)
    
    log_info "Attack surface metrics:"
    log_info "  Running services: $running_services"
    log_info "  Enabled services: $enabled_services"
    log_info "  SUID binaries: $suid_binaries"
    log_info "  SGID binaries: $sgid_binaries"
    log_info "  Loaded kernel modules: $loaded_modules"
    
    # Assessment criteria (these are rough guidelines)
    local score=0
    local max_score=5
    
    # Service count assessment
    if [ "$running_services" -le 30 ]; then
        score=$((score + 1))
        log_info "✓ Service count acceptable ($running_services <= 30)"
    else
        log_warn "Service count high ($running_services > 30)"
    fi
    
    # SUID binary assessment
    if [ "$suid_binaries" -le 15 ]; then
        score=$((score + 1))
        log_info "✓ SUID binary count acceptable ($suid_binaries <= 15)"
    else
        log_warn "SUID binary count high ($suid_binaries > 15)"
    fi
    
    # Security settings assessment
    local security_score=0
    [ "$(sysctl -n kernel.randomize_va_space 2>/dev/null)" = "2" ] && security_score=$((security_score + 1))
    [ "$(sysctl -n kernel.kptr_restrict 2>/dev/null)" = "2" ] && security_score=$((security_score + 1))
    [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "0" ] && security_score=$((security_score + 1))
    
    if [ $security_score -eq 3 ]; then
        score=$((score + 1))
        log_info "✓ Key security settings configured"
    else
        log_warn "Some key security settings missing"
    fi
    
    # Module blacklist assessment
    if [ -f /etc/modprobe.d/hardened-blacklist.conf ]; then
        score=$((score + 1))
        log_info "✓ Kernel module blacklist configured"
    else
        log_warn "Kernel module blacklist not configured"
    fi
    
    # Configuration files assessment
    if [ -f /etc/sysctl.d/99-hardened-security.conf ]; then
        score=$((score + 1))
        log_info "✓ Hardened sysctl configuration present"
    else
        log_warn "Hardened sysctl configuration missing"
    fi
    
    log_info "Attack surface reduction score: $score/$max_score"
    
    if [ $score -ge 4 ]; then
        log_info "✓ Attack surface reduction EXCELLENT"
        return 0
    elif [ $score -ge 3 ]; then
        log_info "✓ Attack surface reduction GOOD"
        return 0
    else
        log_warn "Attack surface reduction NEEDS IMPROVEMENT"
        return 1
    fi
}

# Generate comprehensive test report
generate_test_report() {
    log_test "Generating minimal services test report..."
    
    local report_file="$WORK_DIR/minimal-services-test-report.md"
    
    cat > "$report_file" << EOF
# Minimal System Services Test Report

**Generated:** $(date)
**Task:** 10. Implement minimal system services and attack surface reduction - Testing

## Test Summary

This report documents the testing of minimal system services and attack surface reduction configuration.

## System Information

**Hostname:** $(hostname)
**Kernel:** $(uname -r)
**OS:** $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")

EOF
    
    # Run tests and capture results
    local total_tests=0
    local passed_tests=0
    
    echo "## Test Results" >> "$report_file"
    echo "" >> "$report_file"
    
    local test_functions=(
        "test_service_minimization"
        "test_essential_services"
        "test_suid_sgid_minimization"
        "test_kernel_module_blacklist"
        "test_secure_sysctl"
        "test_network_security"
        "test_memory_protection"
        "test_filesystem_protection"
        "test_attack_surface_reduction"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        echo "### Test: $test_func" >> "$report_file"
        if $test_func >> "$report_file" 2>&1; then
            passed_tests=$((passed_tests + 1))
            echo "**Result: PASSED**" >> "$report_file"
        else
            echo "**Result: FAILED**" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    # Add current system state
    cat >> "$report_file" << EOF

## Current System State

### Running Services (Top 10)
\`\`\`
$(systemctl list-units --type=service --state=running --no-pager | head -10)
\`\`\`

### SUID/SGID Binaries
\`\`\`
$(find /usr -type f -perm -4000 -o -perm -2000 2>/dev/null | head -10)
\`\`\`

### Key Security Settings
\`\`\`
kernel.randomize_va_space = $(sysctl -n kernel.randomize_va_space 2>/dev/null || echo "unknown")
kernel.kptr_restrict = $(sysctl -n kernel.kptr_restrict 2>/dev/null || echo "unknown")
net.ipv4.ip_forward = $(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "unknown")
net.ipv4.conf.all.rp_filter = $(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo "unknown")
\`\`\`

## Overall Results

- **Total Tests:** $total_tests
- **Passed:** $passed_tests
- **Failed:** $((total_tests - passed_tests))
- **Success Rate:** $(( passed_tests * 100 / total_tests ))%

## Recommendations

EOF
    
    if [ $passed_tests -eq $total_tests ]; then
        echo "✅ **All tests passed!** Attack surface reduction is properly configured." >> "$report_file"
    else
        echo "⚠️  **Some tests failed.** Review the failed tests and configuration." >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Manual Verification Procedures

### Service Status Check
\`\`\`bash
# Check disabled services
systemctl list-unit-files --type=service --state=disabled | grep -E "(bluetooth|cups|avahi)"

# Check running services count
systemctl list-units --type=service --state=running --no-pager | wc -l
\`\`\`

### SUID/SGID Verification
\`\`\`bash
# Check SUID binaries
find /usr -type f -perm -4000 2>/dev/null

# Test ping with capabilities
ping -c 1 127.0.0.1

# Check capabilities
getcap /bin/ping 2>/dev/null
\`\`\`

### Kernel Module Verification
\`\`\`bash
# Check blacklist configuration
cat /etc/modprobe.d/hardened-blacklist.conf

# Try loading blacklisted module (should fail)
sudo modprobe dccp 2>&1 || echo "Correctly blacklisted"
\`\`\`

### Security Settings Verification
\`\`\`bash
# Check key security settings
sysctl kernel.randomize_va_space kernel.kptr_restrict
sysctl net.ipv4.ip_forward net.ipv4.conf.all.rp_filter
sysctl fs.protected_hardlinks fs.protected_symlinks
\`\`\`

## Next Steps

1. **Address any failed tests**
2. **Reboot to ensure all settings are persistent**
3. **Monitor system functionality**
4. **Proceed to Task 11 (userspace hardening)**

## Files

- Test log: \`$LOG_FILE\`
- This report: \`$report_file\`

EOF
    
    log_info "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting minimal system services testing..."
    
    init_test_logging
    
    # Run all tests
    local total_tests=0
    local passed_tests=0
    
    local test_functions=(
        "test_service_minimization"
        "test_essential_services"
        "test_suid_sgid_minimization"
        "test_kernel_module_blacklist"
        "test_secure_sysctl"
        "test_network_security"
        "test_memory_protection"
        "test_filesystem_protection"
        "test_attack_surface_reduction"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
        echo # Add spacing between tests
    done
    
    generate_test_report
    
    log_info "=== Minimal System Services Testing Completed ==="
    log_info "Results: $passed_tests/$total_tests tests passed"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_info "✅ All tests PASSED!"
    else
        log_warn "⚠️  Some tests FAILED - review configuration"
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--quick|--services-only|--security-only]"
        echo "Tests minimal system services and attack surface reduction"
        echo ""
        echo "Options:"
        echo "  --help           Show this help"
        echo "  --quick          Run only basic tests"
        echo "  --services-only  Test only service configuration"
        echo "  --security-only  Test only security settings"
        exit 0
        ;;
    --quick)
        init_test_logging
        test_service_minimization
        test_secure_sysctl
        test_attack_surface_reduction
        exit 0
        ;;
    --services-only)
        init_test_logging
        test_service_minimization
        test_essential_services
        exit 0
        ;;
    --security-only)
        init_test_logging
        test_secure_sysctl
        test_network_security
        test_memory_protection
        test_filesystem_protection
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac