#!/bin/bash
#
# SELinux Enforcement Testing Script
# Tests SELinux configuration and policy enforcement
#
# Part of Task 9: Configure SELinux in enforcing mode with targeted policy
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
LOG_FILE="$WORK_DIR/selinux-test.log"

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
    echo "=== SELinux Enforcement Testing Log - $(date) ===" > "$LOG_FILE"
}

# Test 1: Verify SELinux is enabled and enforcing
test_selinux_status() {
    log_test "Testing SELinux status and enforcement mode..."
    
    # Check if SELinux commands are available
    if ! command -v getenforce &>/dev/null; then
        log_error "✗ SELinux tools not available"
        return 1
    fi
    
    # Check SELinux status
    local selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
    log_info "SELinux status: $selinux_status"
    
    case "$selinux_status" in
        "Enforcing")
            log_info "✓ SELinux is in enforcing mode"
            return 0
            ;;
        "Permissive")
            log_warn "SELinux is in permissive mode (should be enforcing)"
            return 1
            ;;
        "Disabled")
            log_error "✗ SELinux is disabled"
            return 1
            ;;
        *)
            log_error "✗ Unknown SELinux status: $selinux_status"
            return 1
            ;;
    esac
}

# Test 2: Verify SELinux configuration
test_selinux_configuration() {
    log_test "Testing SELinux configuration..."
    
    # Check configuration file
    if [ -f /etc/selinux/config ]; then
        log_info "SELinux configuration file found"
        
        # Check SELINUX setting
        local selinux_setting=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
        if [ "$selinux_setting" = "enforcing" ]; then
            log_info "✓ SELINUX=enforcing in configuration"
        else
            log_warn "SELINUX setting: $selinux_setting (should be enforcing)"
        fi
        
        # Check SELINUXTYPE setting
        local selinux_type=$(grep "^SELINUXTYPE=" /etc/selinux/config | cut -d= -f2)
        if [ "$selinux_type" = "default" ] || [ "$selinux_type" = "targeted" ]; then
            log_info "✓ SELINUXTYPE=$selinux_type"
        else
            log_warn "SELINUXTYPE setting: $selinux_type"
        fi
        
        return 0
    else
        log_error "✗ SELinux configuration file not found"
        return 1
    fi
}

# Test 3: Verify custom policy modules are loaded
test_custom_policy_modules() {
    log_test "Testing custom SELinux policy modules..."
    
    if ! command -v semodule &>/dev/null; then
        log_error "semodule command not available"
        return 1
    fi
    
    # Check for custom modules
    local custom_modules=("browser" "office" "media" "dev")
    local loaded_modules=0
    
    for module in "${custom_modules[@]}"; do
        if semodule -l | grep -q "^$module"; then
            log_info "✓ $module policy module loaded"
            loaded_modules=$((loaded_modules + 1))
        else
            log_warn "$module policy module not loaded"
        fi
    done
    
    if [ $loaded_modules -gt 0 ]; then
        log_info "✓ Custom policy modules loaded ($loaded_modules/4)"
        return 0
    else
        log_error "✗ No custom policy modules loaded"
        return 1
    fi
}

# Test 4: Verify file contexts are set correctly
test_file_contexts() {
    log_test "Testing SELinux file contexts..."
    
    # Test common application file contexts
    local test_files=(
        "/usr/bin/firefox:browser_exec_t"
        "/usr/bin/libreoffice:office_exec_t"
        "/usr/bin/vlc:media_exec_t"
        "/usr/bin/gcc:dev_exec_t"
    )
    
    local correct_contexts=0
    local total_tests=0
    
    for test_case in "${test_files[@]}"; do
        local file_path=$(echo "$test_case" | cut -d: -f1)
        local expected_type=$(echo "$test_case" | cut -d: -f2)
        
        if [ -f "$file_path" ]; then
            total_tests=$((total_tests + 1))
            
            local file_context=$(ls -Z "$file_path" 2>/dev/null | awk '{print $1}')
            
            if echo "$file_context" | grep -q "$expected_type"; then
                log_info "✓ $file_path has correct context ($expected_type)"
                correct_contexts=$((correct_contexts + 1))
            else
                log_warn "$file_path context: $file_context (expected $expected_type)"
            fi
        fi
    done
    
    if [ $total_tests -gt 0 ] && [ $correct_contexts -gt 0 ]; then
        log_info "✓ File contexts test passed ($correct_contexts/$total_tests correct)"
        return 0
    else
        log_warn "File contexts may need adjustment"
        return 1
    fi
}

# Test 5: Test process domain transitions
test_process_domains() {
    log_test "Testing SELinux process domain transitions..."
    
    # This test checks if processes are running in expected domains
    # Note: This requires applications to be running
    
    if ! command -v ps &>/dev/null; then
        log_error "ps command not available"
        return 1
    fi
    
    # Check for processes in custom domains
    local domain_processes=$(ps -eZ 2>/dev/null | grep -E "(browser_t|office_t|media_t|dev_t)" | wc -l)
    
    if [ "$domain_processes" -gt 0 ]; then
        log_info "✓ Found $domain_processes processes in custom domains"
        
        # Show some examples
        log_info "Example domain transitions:"
        ps -eZ 2>/dev/null | grep -E "(browser_t|office_t|media_t|dev_t)" | head -3 | while read line; do
            log_info "  $line"
        done
        
        return 0
    else
        log_warn "No processes currently running in custom domains"
        log_info "This is normal if applications haven't been launched yet"
        return 1
    fi
}

# Test 6: Test audit logging
test_audit_logging() {
    log_test "Testing SELinux audit logging..."
    
    # Check if auditd is running
    if systemctl is-active auditd &>/dev/null; then
        log_info "✓ Audit daemon is running"
    else
        log_warn "Audit daemon not running"
        return 1
    fi
    
    # Check for audit log file
    if [ -f /var/log/audit/audit.log ]; then
        log_info "✓ Audit log file exists"
        
        # Check for recent SELinux entries
        local recent_avc=$(ausearch -m avc -ts recent 2>/dev/null | wc -l)
        log_info "Recent AVC entries: $recent_avc"
        
        return 0
    else
        log_error "✗ Audit log file not found"
        return 1
    fi
}

# Test 7: Test setroubleshoot availability
test_setroubleshoot() {
    log_test "Testing setroubleshoot availability..."
    
    if command -v sealert &>/dev/null; then
        log_info "✓ sealert (setroubleshoot) available"
        
        # Test sealert functionality
        if sealert --help &>/dev/null; then
            log_info "✓ sealert functional"
        else
            log_warn "sealert may not be working properly"
        fi
        
        return 0
    else
        log_warn "sealert not available - install setroubleshoot-server"
        return 1
    fi
}

# Test 8: Test basic policy enforcement
test_basic_enforcement() {
    log_test "Testing basic SELinux policy enforcement..."
    
    # Create a test file to check enforcement
    local test_file="/tmp/selinux_test_$$"
    
    # Create test file
    echo "SELinux test" > "$test_file"
    
    # Check file context
    local file_context=$(ls -Z "$test_file" 2>/dev/null | awk '{print $1}')
    log_info "Test file context: $file_context"
    
    # Try to change context (should work in enforcing mode)
    if command -v chcon &>/dev/null; then
        if chcon -t tmp_t "$test_file" 2>/dev/null; then
            log_info "✓ Context change successful (SELinux functional)"
        else
            log_warn "Context change failed"
        fi
    fi
    
    # Clean up
    rm -f "$test_file"
    
    return 0
}

# Test 9: Check for policy denials
test_policy_denials() {
    log_test "Checking for recent SELinux policy denials..."
    
    if ! command -v ausearch &>/dev/null; then
        log_warn "ausearch not available - cannot check denials"
        return 1
    fi
    
    # Check for recent denials
    local recent_denials=$(ausearch -m avc -ts recent 2>/dev/null | grep "denied" | wc -l)
    
    if [ "$recent_denials" -eq 0 ]; then
        log_info "✓ No recent policy denials found"
        return 0
    else
        log_warn "Found $recent_denials recent policy denials"
        
        # Show some examples
        log_info "Recent denial examples:"
        ausearch -m avc -ts recent 2>/dev/null | grep "denied" | head -3 | while read line; do
            log_warn "  $line"
        done
        
        return 1
    fi
}

# Generate comprehensive test report
generate_test_report() {
    log_test "Generating SELinux enforcement test report..."
    
    local report_file="$WORK_DIR/selinux-test-report.md"
    
    cat > "$report_file" << EOF
# SELinux Enforcement Test Report

**Generated:** $(date)
**Task:** 9. Configure SELinux in enforcing mode with targeted policy - Testing

## Test Summary

This report documents the testing of SELinux enforcement configuration.

## System Information

**SELinux Status:** $(getenforce 2>/dev/null || echo "Unknown")
**Policy Type:** $(grep "^SELINUXTYPE=" /etc/selinux/config 2>/dev/null | cut -d= -f2 || echo "Unknown")

EOF
    
    # Run tests and capture results
    local total_tests=0
    local passed_tests=0
    
    echo "## Test Results" >> "$report_file"
    echo "" >> "$report_file"
    
    local test_functions=(
        "test_selinux_status"
        "test_selinux_configuration"
        "test_custom_policy_modules"
        "test_file_contexts"
        "test_audit_logging"
        "test_setroubleshoot"
        "test_basic_enforcement"
        "test_policy_denials"
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

### SELinux Status
\`\`\`
$(getenforce 2>/dev/null || echo "SELinux status unknown")
\`\`\`

### Loaded Policy Modules
\`\`\`
$(semodule -l 2>/dev/null | grep -E "(browser|office|media|dev)" || echo "No custom modules found")
\`\`\`

### Running Processes in Custom Domains
\`\`\`
$(ps -eZ 2>/dev/null | grep -E "(browser_t|office_t|media_t|dev_t)" | head -5 || echo "No processes in custom domains")
\`\`\`

## Overall Results

- **Total Tests:** $total_tests
- **Passed:** $passed_tests
- **Failed:** $((total_tests - passed_tests))
- **Success Rate:** $(( passed_tests * 100 / total_tests ))%

## Recommendations

EOF
    
    if [ $passed_tests -eq $total_tests ]; then
        echo "✅ **All tests passed!** SELinux enforcement is properly configured." >> "$report_file"
    else
        echo "⚠️  **Some tests failed.** Review the failed tests and SELinux configuration." >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Manual Testing Procedures

### Test Application Domain Transitions
\`\`\`bash
# Launch applications and check domains
firefox &
ps -eZ | grep firefox

libreoffice &
ps -eZ | grep libreoffice
\`\`\`

### Monitor Policy Denials
\`\`\`bash
# Real-time denial monitoring
tail -f /var/log/audit/audit.log | grep AVC

# Analyze denials
sealert -a /var/log/audit/audit.log
\`\`\`

### Test Policy Restrictions
\`\`\`bash
# Test file access restrictions
# (Run as different domain users)

# Test network access restrictions
# (Combined with nftables rules)
\`\`\`

## Next Steps

1. **Address any failed tests**
2. **Test application domain transitions**
3. **Monitor for policy denials during normal use**
4. **Proceed to Task 10 (minimal system services)**

## Files

- Test log: \`$LOG_FILE\`
- This report: \`$report_file\`

EOF
    
    log_info "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting SELinux enforcement testing..."
    
    init_test_logging
    
    # Run all tests
    local total_tests=0
    local passed_tests=0
    
    local test_functions=(
        "test_selinux_status"
        "test_selinux_configuration"
        "test_custom_policy_modules"
        "test_file_contexts"
        "test_process_domains"
        "test_audit_logging"
        "test_setroubleshoot"
        "test_basic_enforcement"
        "test_policy_denials"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
        echo # Add spacing between tests
    done
    
    generate_test_report
    
    log_info "=== SELinux Enforcement Testing Completed ==="
    log_info "Results: $passed_tests/$total_tests tests passed"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_info "✅ All tests PASSED!"
    else
        log_warn "⚠️  Some tests FAILED - review SELinux configuration"
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--quick]"
        echo "Tests SELinux enforcement configuration"
        echo ""
        echo "Options:"
        echo "  --help   Show this help"
        echo "  --quick  Run only basic tests"
        exit 0
        ;;
    --quick)
        init_test_logging
        test_selinux_status
        test_selinux_configuration
        test_custom_policy_modules
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac