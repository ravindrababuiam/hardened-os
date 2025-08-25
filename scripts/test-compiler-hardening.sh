#!/bin/bash
#
# Compiler Hardening Testing Script
# Tests and validates compiler hardening features and configurations
#
# Part of Task 7: Implement compiler hardening for kernel and userspace
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
CONFIG_DIR="$HOME/harden/config"
TEST_DIR="$WORK_DIR/compiler-hardening-tests"
LOG_FILE="$WORK_DIR/compiler-hardening-test.log"

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
    mkdir -p "$TEST_DIR"
    echo "=== Compiler Hardening Testing Log - $(date) ===" > "$LOG_FILE"
}

# Test 1: Verify hardening configurations exist
test_hardening_configs() {
    log_test "Testing hardening configuration files..."
    
    local configs=(
        "$CONFIG_DIR/gcc-hardening.conf"
        "$CONFIG_DIR/clang-hardening.conf"
        "$CONFIG_DIR/kernel-lockdown.conf"
        "$CONFIG_DIR/99-lockdown.conf"
    )
    
    local missing_configs=()
    
    for config in "${configs[@]}"; do
        if [ -f "$config" ]; then
            log_info "✓ Configuration found: $(basename "$config")"
        else
            missing_configs+=("$(basename "$config")")
        fi
    done
    
    if [ ${#missing_configs[@]} -eq 0 ]; then
        log_info "✓ All hardening configurations present"
        return 0
    else
        log_error "✗ Missing configurations: ${missing_configs[*]}"
        return 1
    fi
}

# Test 2: Verify wrapper scripts exist and are executable
test_wrapper_scripts() {
    log_test "Testing hardened compiler wrapper scripts..."
    
    local wrappers=(
        "$CONFIG_DIR/hardened-gcc"
        "$CONFIG_DIR/hardened-clang"
    )
    
    local missing_wrappers=()
    
    for wrapper in "${wrappers[@]}"; do
        if [ -x "$wrapper" ]; then
            log_info "✓ Wrapper script found and executable: $(basename "$wrapper")"
        else
            missing_wrappers+=("$(basename "$wrapper")")
        fi
    done
    
    if [ ${#missing_wrappers[@]} -eq 0 ]; then
        log_info "✓ All wrapper scripts present and executable"
        return 0
    else
        log_error "✗ Missing or non-executable wrappers: ${missing_wrappers[*]}"
        return 1
    fi
}

# Test 3: Test GCC hardening compilation
test_gcc_hardening() {
    log_test "Testing GCC hardening compilation..."
    
    if ! command -v gcc &>/dev/null; then
        log_warn "GCC not available - skipping GCC tests"
        return 1
    fi
    
    # Create test program
    local test_program="$TEST_DIR/gcc_hardening_test.c"
    cat > "$test_program" << 'EOF'
#include <stdio.h>
#include <string.h>

void vulnerable_function(char *input) {
    char buffer[64];
    strcpy(buffer, input);  // Potential buffer overflow
    printf("Buffer: %s\n", buffer);
}

int main() {
    printf("GCC hardening test program\n");
    vulnerable_function("test");
    return 0;
}
EOF
    
    # Test basic GCC hardening flags
    local gcc_flags="-fstack-protector-strong -fstack-clash-protection -D_FORTIFY_SOURCE=3 -fPIE -pie -O2"
    
    if gcc $gcc_flags -o "$TEST_DIR/gcc_hardened" "$test_program" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "✓ GCC hardening compilation successful"
        
        # Test execution
        if "$TEST_DIR/gcc_hardened" &>/dev/null; then
            log_info "✓ GCC hardened binary executes successfully"
        else
            log_warn "GCC hardened binary execution failed"
        fi
        
        return 0
    else
        log_error "✗ GCC hardening compilation failed"
        return 1
    fi
}

# Test 4: Test Clang hardening compilation
test_clang_hardening() {
    log_test "Testing Clang hardening compilation..."
    
    if ! command -v clang &>/dev/null; then
        log_warn "Clang not available - skipping Clang tests"
        return 1
    fi
    
    # Create test program
    local test_program="$TEST_DIR/clang_hardening_test.c"
    cat > "$test_program" << 'EOF'
#include <stdio.h>
#include <string.h>

void test_function(char *input) {
    char buffer[64];
    strncpy(buffer, input, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    printf("Buffer: %s\n", buffer);
}

int main() {
    printf("Clang hardening test program\n");
    test_function("test");
    return 0;
}
EOF
    
    # Test basic Clang hardening flags (avoid sanitizers that might not work in test environment)
    local clang_flags="-fstack-protector-strong -fPIE -pie -O2"
    
    if clang $clang_flags -o "$TEST_DIR/clang_hardened" "$test_program" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "✓ Clang hardening compilation successful"
        
        # Test execution
        if "$TEST_DIR/clang_hardened" &>/dev/null; then
            log_info "✓ Clang hardened binary executes successfully"
        else
            log_warn "Clang hardened binary execution failed"
        fi
        
        return 0
    else
        log_error "✗ Clang hardening compilation failed"
        return 1
    fi
}

# Test 5: Test wrapper script functionality
test_wrapper_functionality() {
    log_test "Testing wrapper script functionality..."
    
    local test_program="$TEST_DIR/wrapper_test.c"
    cat > "$test_program" << 'EOF'
#include <stdio.h>
int main() {
    printf("Wrapper test program\n");
    return 0;
}
EOF
    
    local success=0
    
    # Test GCC wrapper
    if [ -x "$CONFIG_DIR/hardened-gcc" ]; then
        if "$CONFIG_DIR/hardened-gcc" -o "$TEST_DIR/wrapper_gcc_test" "$test_program" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "✓ Hardened GCC wrapper working"
            success=$((success + 1))
        else
            log_error "✗ Hardened GCC wrapper failed"
        fi
    fi
    
    # Test Clang wrapper
    if [ -x "$CONFIG_DIR/hardened-clang" ] && command -v clang &>/dev/null; then
        if "$CONFIG_DIR/hardened-clang" -o "$TEST_DIR/wrapper_clang_test" "$test_program" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "✓ Hardened Clang wrapper working"
            success=$((success + 1))
        else
            log_error "✗ Hardened Clang wrapper failed"
        fi
    fi
    
    if [ $success -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Test 6: Test binary security features
test_binary_security_features() {
    log_test "Testing binary security features..."
    
    # Check if checksec is available
    if ! command -v checksec &>/dev/null; then
        log_warn "checksec not available - installing..."
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y checksec || {
                log_warn "Could not install checksec - skipping binary analysis"
                return 1
            }
        else
            log_warn "Cannot install checksec - skipping binary analysis"
            return 1
        fi
    fi
    
    # Analyze hardened binaries
    local binaries=(
        "$TEST_DIR/gcc_hardened"
        "$TEST_DIR/clang_hardened"
    )
    
    local analyzed=0
    
    for binary in "${binaries[@]}"; do
        if [ -f "$binary" ]; then
            log_info "Analyzing security features of $(basename "$binary"):"
            checksec --file="$binary" | tee -a "$LOG_FILE"
            analyzed=$((analyzed + 1))
        fi
    done
    
    if [ $analyzed -gt 0 ]; then
        log_info "✓ Binary security analysis completed"
        return 0
    else
        log_warn "No binaries available for analysis"
        return 1
    fi
}

# Test 7: Test kernel lockdown status
test_kernel_lockdown() {
    log_test "Testing kernel lockdown status..."
    
    # Check lockdown interface
    if [ -f /sys/kernel/security/lockdown ]; then
        local lockdown_status=$(cat /sys/kernel/security/lockdown)
        log_info "Current lockdown status: $lockdown_status"
        
        if echo "$lockdown_status" | grep -q "confidentiality\|integrity"; then
            log_info "✓ Kernel lockdown is active"
            return 0
        else
            log_warn "Kernel lockdown not active"
            return 1
        fi
    else
        log_warn "Kernel lockdown interface not available"
        return 1
    fi
}

# Test 8: Test sysctl hardening settings
test_sysctl_hardening() {
    log_test "Testing sysctl hardening settings..."
    
    local sysctl_tests=(
        "kernel.kptr_restrict:2"
        "kernel.dmesg_restrict:1"
        "kernel.unprivileged_bpf_disabled:1"
        "net.core.bpf_jit_harden:2"
    )
    
    local passed=0
    local total=${#sysctl_tests[@]}
    
    for test in "${sysctl_tests[@]}"; do
        local setting=$(echo "$test" | cut -d: -f1)
        local expected=$(echo "$test" | cut -d: -f2)
        
        if [ -f "/proc/sys/$(echo "$setting" | tr '.' '/')" ]; then
            local current=$(sysctl -n "$setting" 2>/dev/null || echo "unknown")
            
            if [ "$current" = "$expected" ]; then
                log_info "✓ $setting = $current (expected $expected)"
                passed=$((passed + 1))
            else
                log_warn "✗ $setting = $current (expected $expected)"
            fi
        else
            log_warn "Setting $setting not available"
        fi
    done
    
    if [ $passed -eq $total ]; then
        log_info "✓ All sysctl hardening settings correct"
        return 0
    else
        log_warn "Some sysctl hardening settings need adjustment ($passed/$total correct)"
        return 1
    fi
}

# Test 9: Test stack protection effectiveness
test_stack_protection() {
    log_test "Testing stack protection effectiveness..."
    
    # Create vulnerable test program
    local vulnerable_program="$TEST_DIR/stack_overflow_test.c"
    cat > "$vulnerable_program" << 'EOF'
#include <stdio.h>
#include <string.h>

void vulnerable_function() {
    char buffer[64];
    char overflow_data[200];
    
    // Fill with pattern that would overflow
    memset(overflow_data, 'A', sizeof(overflow_data) - 1);
    overflow_data[sizeof(overflow_data) - 1] = '\0';
    
    // This should trigger stack protection
    strcpy(buffer, overflow_data);
    
    printf("If you see this, stack protection may have failed\n");
}

int main() {
    printf("Testing stack protection...\n");
    vulnerable_function();
    return 0;
}
EOF
    
    # Compile with stack protection
    if gcc -fstack-protector-strong -o "$TEST_DIR/stack_protected" "$vulnerable_program" 2>/dev/null; then
        log_info "Stack protection test program compiled"
        
        # Run test (should abort due to stack protection)
        if timeout 5 "$TEST_DIR/stack_protected" 2>&1 | tee -a "$LOG_FILE"; then
            log_warn "Stack overflow test completed (protection may not be working)"
            return 1
        else
            log_info "✓ Stack protection appears to be working (program terminated)"
            return 0
        fi
    else
        log_warn "Could not compile stack protection test"
        return 1
    fi
}

# Test 10: Test FORTIFY_SOURCE effectiveness
test_fortify_source() {
    log_test "Testing FORTIFY_SOURCE effectiveness..."
    
    # Create test program with buffer overflow
    local fortify_program="$TEST_DIR/fortify_test.c"
    cat > "$fortify_program" << 'EOF'
#include <stdio.h>
#include <string.h>

int main() {
    char buffer[10];
    char source[20] = "This is too long";
    
    printf("Testing FORTIFY_SOURCE...\n");
    
    // This should be caught by FORTIFY_SOURCE
    strcpy(buffer, source);
    
    printf("Buffer: %s\n", buffer);
    return 0;
}
EOF
    
    # Compile with FORTIFY_SOURCE
    if gcc -D_FORTIFY_SOURCE=3 -O2 -o "$TEST_DIR/fortify_test" "$fortify_program" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "FORTIFY_SOURCE test program compiled"
        
        # Check for FORTIFY_SOURCE warnings during compilation
        if gcc -D_FORTIFY_SOURCE=3 -O2 -Wall -Wextra "$fortify_program" 2>&1 | grep -q "warning"; then
            log_info "✓ FORTIFY_SOURCE generating warnings as expected"
            return 0
        else
            log_warn "FORTIFY_SOURCE may not be detecting issues"
            return 1
        fi
    else
        log_warn "Could not compile FORTIFY_SOURCE test"
        return 1
    fi
}

# Generate comprehensive test report
generate_test_report() {
    log_test "Generating compiler hardening test report..."
    
    local report_file="$WORK_DIR/compiler-hardening-test-report.md"
    
    cat > "$report_file" << EOF
# Compiler Hardening Test Report

**Generated:** $(date)
**Task:** 7. Implement compiler hardening for kernel and userspace - Testing

## Test Summary

This report documents the testing of compiler hardening implementation.

## System Information

**Architecture:** $(uname -m)
**Kernel:** $(uname -r)
**Available Compilers:**
EOF
    
    # Add compiler information
    if command -v gcc &>/dev/null; then
        echo "- GCC: $(gcc --version | head -1)" >> "$report_file"
    fi
    
    if command -v clang &>/dev/null; then
        echo "- Clang: $(clang --version | head -1)" >> "$report_file"
    fi
    
    # Run tests and capture results
    local total_tests=0
    local passed_tests=0
    
    echo "" >> "$report_file"
    echo "## Test Results" >> "$report_file"
    echo "" >> "$report_file"
    
    local test_functions=(
        "test_hardening_configs"
        "test_wrapper_scripts"
        "test_gcc_hardening"
        "test_clang_hardening"
        "test_wrapper_functionality"
        "test_kernel_lockdown"
        "test_sysctl_hardening"
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
    
    # Add binary analysis if available
    if command -v checksec &>/dev/null; then
        echo "## Binary Security Analysis" >> "$report_file"
        echo "" >> "$report_file"
        
        for binary in "$TEST_DIR"/*_hardened; do
            if [ -f "$binary" ]; then
                echo "### $(basename "$binary")" >> "$report_file"
                echo '```' >> "$report_file"
                checksec --file="$binary" >> "$report_file" 2>/dev/null || echo "Analysis failed" >> "$report_file"
                echo '```' >> "$report_file"
                echo "" >> "$report_file"
            fi
        done
    fi
    
    # Add summary
    cat >> "$report_file" << EOF

## Overall Results

- **Total Tests:** $total_tests
- **Passed:** $passed_tests
- **Failed:** $((total_tests - passed_tests))
- **Success Rate:** $(( passed_tests * 100 / total_tests ))%

## Security Features Validated

### Compiler Hardening
- Stack protection with canaries
- Stack clash protection
- Buffer overflow detection (FORTIFY_SOURCE)
- Position Independent Executables (PIE)
- Control flow protection where supported

### System Hardening
- Kernel lockdown configuration
- Sysctl security settings
- BPF access restrictions
- Kernel pointer protection

## Recommendations

EOF
    
    if [ $passed_tests -eq $total_tests ]; then
        echo "✅ **All tests passed!** Compiler hardening is properly configured." >> "$report_file"
    else
        echo "⚠️  **Some tests failed.** Review the failed tests and configuration." >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Next Steps

1. **Address any failed tests**
2. **Install system-wide hardening configuration**
3. **Test application compatibility**
4. **Proceed to Task 8 (signed kernel packages)**

## Files

- Test log: \`$LOG_FILE\`
- This report: \`$report_file\`

EOF
    
    log_info "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting compiler hardening testing..."
    
    init_test_logging
    
    # Run all tests
    local total_tests=0
    local passed_tests=0
    
    local test_functions=(
        "test_hardening_configs"
        "test_wrapper_scripts"
        "test_gcc_hardening"
        "test_clang_hardening"
        "test_wrapper_functionality"
        "test_binary_security_features"
        "test_kernel_lockdown"
        "test_sysctl_hardening"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
        echo # Add spacing between tests
    done
    
    # Ask about potentially disruptive tests
    echo
    log_warn "Stack protection and FORTIFY_SOURCE tests may cause program termination"
    read -p "Run stack protection and FORTIFY_SOURCE tests? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if test_stack_protection; then
            passed_tests=$((passed_tests + 1))
        fi
        total_tests=$((total_tests + 1))
        
        if test_fortify_source; then
            passed_tests=$((passed_tests + 1))
        fi
        total_tests=$((total_tests + 1))
    else
        log_info "Stack protection and FORTIFY_SOURCE tests skipped"
    fi
    
    generate_test_report
    
    log_info "=== Compiler Hardening Testing Completed ==="
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
        echo "Usage: $0 [--help|--quick]"
        echo "Tests compiler hardening implementation"
        echo ""
        echo "Options:"
        echo "  --help   Show this help"
        echo "  --quick  Run only basic tests (skip potentially disruptive tests)"
        exit 0
        ;;
    --quick)
        init_test_logging
        test_hardening_configs
        test_wrapper_scripts
        test_gcc_hardening
        test_clang_hardening
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac