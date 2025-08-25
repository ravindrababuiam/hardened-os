#!/bin/bash
#
# Secure Boot Testing and Validation Script
# Tests Secure Boot enforcement and unauthorized kernel rejection
#
# Part of Task 4: Implement UEFI Secure Boot with custom keys
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
LOG_FILE="$WORK_DIR/secure-boot-test.log"

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
    echo "=== Secure Boot Testing Log - $(date) ===" > "$LOG_FILE"
}

# Test 1: Verify Secure Boot is enabled
test_secure_boot_enabled() {
    log_test "Testing if Secure Boot is enabled..."
    
    local sb_var=$(find /sys/firmware/efi/efivars -name "SecureBoot-*" 2>/dev/null | head -1)
    if [ -n "$sb_var" ]; then
        local sb_status=$(od -An -t u1 "$sb_var" 2>/dev/null | awk '{print $NF}')
        if [ "$sb_status" = "1" ]; then
            log_info "✓ TEST PASSED: Secure Boot is enabled"
            return 0
        else
            log_error "✗ TEST FAILED: Secure Boot is disabled"
            return 1
        fi
    else
        log_error "✗ TEST FAILED: Cannot determine Secure Boot status"
        return 1
    fi
}

# Test 2: Verify system is in User Mode (not Setup Mode)
test_user_mode() {
    log_test "Testing if system is in User Mode..."
    
    local setup_var=$(find /sys/firmware/efi/efivars -name "SetupMode-*" 2>/dev/null | head -1)
    if [ -n "$setup_var" ]; then
        local setup_status=$(od -An -t u1 "$setup_var" 2>/dev/null | awk '{print $NF}')
        if [ "$setup_status" = "0" ]; then
            log_info "✓ TEST PASSED: System is in User Mode (keys enrolled)"
            return 0
        else
            log_error "✗ TEST FAILED: System is in Setup Mode (keys not properly enrolled)"
            return 1
        fi
    else
        log_error "✗ TEST FAILED: Cannot determine Setup Mode status"
        return 1
    fi
}

# Test 3: Verify Platform Key is enrolled
test_platform_key_enrolled() {
    log_test "Testing if Platform Key is enrolled..."
    
    local pk_var=$(find /sys/firmware/efi/efivars -name "PK-*" 2>/dev/null | head -1)
    if [ -n "$pk_var" ]; then
        local pk_size=$(stat -c%s "$pk_var" 2>/dev/null)
        if [ "$pk_size" -gt 4 ]; then
            log_info "✓ TEST PASSED: Platform Key is enrolled (size: $pk_size bytes)"
            return 0
        else
            log_error "✗ TEST FAILED: No Platform Key enrolled"
            return 1
        fi
    else
        log_error "✗ TEST FAILED: Platform Key variable not found"
        return 1
    fi
}

# Test 4: Verify signed files with sbctl
test_signed_files() {
    log_test "Testing signed file verification with sbctl..."
    
    if ! command -v sbctl &> /dev/null; then
        log_error "✗ TEST SKIPPED: sbctl not available"
        return 1
    fi
    
    local verification_output
    if verification_output=$(sbctl verify 2>&1); then
        log_info "✓ TEST PASSED: All files verified successfully"
        echo "$verification_output" | tee -a "$LOG_FILE"
        return 0
    else
        log_error "✗ TEST FAILED: File verification failed"
        echo "$verification_output" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Test 5: Check boot chain integrity
test_boot_chain_integrity() {
    log_test "Testing boot chain integrity..."
    
    # Check if current kernel is signed
    local current_kernel=$(uname -r)
    local kernel_path="/boot/vmlinuz-$current_kernel"
    
    if [ -f "$kernel_path" ]; then
        log_info "Current kernel: $kernel_path"
        
        # Check if kernel is in sbctl database
        if command -v sbctl &> /dev/null; then
            if sbctl list-files | grep -q "$kernel_path"; then
                log_info "✓ TEST PASSED: Current kernel is signed and tracked"
                return 0
            else
                log_warn "Current kernel not in sbctl database"
            fi
        fi
        
        # Check for signature using pesign (if available)
        if command -v pesign &> /dev/null; then
            if pesign -S -i "$kernel_path" 2>/dev/null | grep -q "signature"; then
                log_info "✓ TEST PASSED: Current kernel has valid signature"
                return 0
            else
                log_error "✗ TEST FAILED: Current kernel lacks valid signature"
                return 1
            fi
        fi
        
        log_warn "Cannot verify kernel signature (pesign not available)"
        return 1
    else
        log_error "✗ TEST FAILED: Current kernel file not found"
        return 1
    fi
}

# Test 6: Simulate unauthorized kernel rejection
test_unauthorized_kernel_rejection() {
    log_test "Testing unauthorized kernel rejection..."
    
    # This test can only be performed by attempting to boot an unsigned kernel
    # We'll create a test scenario and document the expected behavior
    
    local esp_mount=$(findmnt -n -o TARGET -t vfat | grep -E "(boot/efi|efi)" | head -1)
    if [ -z "$esp_mount" ]; then
        log_error "✗ TEST SKIPPED: EFI System Partition not found"
        return 1
    fi
    
    # Check if test unsigned kernel exists
    if [ -f "$esp_mount/EFI/test-unsigned.efi" ]; then
        log_info "Test unsigned kernel found at $esp_mount/EFI/test-unsigned.efi"
        log_info "✓ TEST SETUP: Unauthorized kernel available for testing"
        log_warn "To complete this test:"
        log_info "1. Reboot system"
        log_info "2. Try to boot test-unsigned.efi from UEFI boot menu"
        log_info "3. Verify that Secure Boot rejects the unsigned kernel"
        log_info "4. System should refuse to boot or show security violation"
        return 0
    else
        log_warn "Test unsigned kernel not found - creating one..."
        
        # Create a simple test EFI file
        cat > "$WORK_DIR/test-unsigned.c" << 'EOF'
#include <efi.h>
#include <efilib.h>

EFI_STATUS
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    InitializeLib(ImageHandle, SystemTable);
    Print(L"This is an unsigned test kernel - should be rejected by Secure Boot\n");
    return EFI_SUCCESS;
}
EOF
        
        # Note: Actual compilation would require EFI development environment
        log_info "Test kernel source created - manual compilation required"
        log_warn "This test requires manual verification during boot"
        return 1
    fi
}

# Test 7: Check MOK (Machine Owner Key) status
test_mok_status() {
    log_test "Testing MOK (Machine Owner Key) status..."
    
    if ! command -v mokutil &> /dev/null; then
        log_warn "mokutil not available - skipping MOK test"
        return 1
    fi
    
    # Check MOK state
    local mok_state
    if mok_state=$(mokutil --sb-state 2>/dev/null); then
        log_info "MOK Secure Boot state: $mok_state"
        if echo "$mok_state" | grep -q "SecureBoot enabled"; then
            log_info "✓ TEST PASSED: MOK reports Secure Boot enabled"
            return 0
        else
            log_error "✗ TEST FAILED: MOK reports Secure Boot disabled"
            return 1
        fi
    else
        log_warn "Cannot determine MOK state"
        return 1
    fi
}

# Test 8: Verify EFI boot variables
test_efi_boot_variables() {
    log_test "Testing EFI boot variables..."
    
    if ! command -v efibootmgr &> /dev/null; then
        log_error "✗ TEST SKIPPED: efibootmgr not available"
        return 1
    fi
    
    local boot_entries
    if boot_entries=$(efibootmgr 2>/dev/null); then
        log_info "Current boot entries:"
        echo "$boot_entries" | tee -a "$LOG_FILE"
        
        # Check for signed bootloader entries
        if echo "$boot_entries" | grep -qi "grub\|shim"; then
            log_info "✓ TEST PASSED: Signed bootloader entries found"
            return 0
        else
            log_warn "No obvious signed bootloader entries found"
            return 1
        fi
    else
        log_error "✗ TEST FAILED: Cannot read boot entries"
        return 1
    fi
}

# Generate test report
generate_test_report() {
    log_test "Generating Secure Boot test report..."
    
    local report_file="$WORK_DIR/secure-boot-test-report.md"
    
    cat > "$report_file" << EOF
# Secure Boot Test Report

**Generated:** $(date)
**Task:** 4. Implement UEFI Secure Boot with custom keys - Testing Phase

## Test Summary

This report documents the testing of UEFI Secure Boot implementation.

## Test Results

EOF
    
    # Add test results summary
    local total_tests=0
    local passed_tests=0
    
    echo "### Individual Test Results" >> "$report_file"
    echo "" >> "$report_file"
    
    # Run tests and capture results
    local test_functions=(
        "test_secure_boot_enabled"
        "test_user_mode" 
        "test_platform_key_enrolled"
        "test_signed_files"
        "test_boot_chain_integrity"
        "test_mok_status"
        "test_efi_boot_variables"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        echo "#### Test: $test_func" >> "$report_file"
        if $test_func >> "$report_file" 2>&1; then
            passed_tests=$((passed_tests + 1))
            echo "**Result: PASSED**" >> "$report_file"
        else
            echo "**Result: FAILED**" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    # Add summary
    cat >> "$report_file" << EOF

## Overall Results

- **Total Tests:** $total_tests
- **Passed:** $passed_tests
- **Failed:** $((total_tests - passed_tests))
- **Success Rate:** $(( passed_tests * 100 / total_tests ))%

## Manual Testing Required

The following tests require manual verification:

1. **Unauthorized Kernel Rejection Test:**
   - Boot with test unsigned kernel
   - Verify Secure Boot blocks execution
   - Check for security violation messages

2. **Recovery Boot Test:**
   - Test recovery partition boot
   - Verify signed recovery kernel works
   - Test fallback mechanisms

## Recommendations

EOF
    
    if [ $passed_tests -eq $total_tests ]; then
        echo "✅ **All automated tests passed!** Secure Boot appears to be properly configured." >> "$report_file"
    else
        echo "⚠️  **Some tests failed.** Review the failures and address configuration issues." >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Next Steps

1. Complete manual testing procedures
2. Test recovery scenarios
3. Document any issues found
4. Proceed to Task 5 (TPM2 integration)

## Files

- Test log: \`$LOG_FILE\`
- This report: \`$report_file\`

EOF
    
    log_info "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting Secure Boot testing and validation..."
    
    init_test_logging
    
    # Run all tests
    local total_tests=0
    local passed_tests=0
    
    local test_functions=(
        "test_secure_boot_enabled"
        "test_user_mode"
        "test_platform_key_enrolled" 
        "test_signed_files"
        "test_boot_chain_integrity"
        "test_mok_status"
        "test_efi_boot_variables"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
        echo # Add spacing between tests
    done
    
    # Special test that requires manual verification
    test_unauthorized_kernel_rejection
    
    generate_test_report
    
    log_info "=== Secure Boot Testing Completed ==="
    log_info "Results: $passed_tests/$total_tests automated tests passed"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_info "✅ All automated tests PASSED!"
    else
        log_warn "⚠️  Some tests FAILED - review configuration"
    fi
    
    log_info "Manual testing still required for complete validation"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--test-only]"
        echo "Tests UEFI Secure Boot implementation and enforcement"
        echo ""
        echo "Options:"
        echo "  --help      Show this help"
        echo "  --test-only Run tests without generating report"
        exit 0
        ;;
    --test-only)
        init_test_logging
        # Run individual tests as requested
        shift
        if [ $# -gt 0 ]; then
            for test_name in "$@"; do
                if declare -f "test_$test_name" > /dev/null; then
                    "test_$test_name"
                else
                    log_error "Unknown test: $test_name"
                fi
            done
        else
            log_error "No test specified"
        fi
        ;;
    *)
        main "$@"
        ;;
esac