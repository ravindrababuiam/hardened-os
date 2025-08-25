#!/bin/bash
#
# TPM2 Measured Boot Testing Script
# Tests TPM2 functionality, PCR measurements, and Evil Maid attack simulation
#
# Part of Task 5: Configure TPM2 measured boot and key sealing with recovery
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
LOG_FILE="$WORK_DIR/tpm2-test.log"
PCR_POLICY="0,2,4,7"

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
    echo "=== TPM2 Measured Boot Testing Log - $(date) ===" > "$LOG_FILE"
}

# Test 1: Verify TPM2 hardware and communication
test_tpm2_hardware() {
    log_test "Testing TPM2 hardware and communication..."
    
    # Check TPM device
    if [ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]; then
        log_info "✓ TPM device found"
    else
        log_error "✗ No TPM device found"
        return 1
    fi
    
    # Test communication
    if tpm2_getcap properties-fixed &>/dev/null; then
        log_info "✓ TPM2 communication successful"
        
        # Get TPM info
        local manufacturer=$(tpm2_getcap properties-fixed | grep TPM2_PT_MANUFACTURER | awk '{print $2}' || echo "Unknown")
        local firmware=$(tpm2_getcap properties-fixed | grep TPM2_PT_FIRMWARE_VERSION | awk '{print $2}' || echo "Unknown")
        
        log_info "  Manufacturer: $manufacturer"
        log_info "  Firmware: $firmware"
        return 0
    else
        log_error "✗ TPM2 communication failed"
        return 1
    fi
}

# Test 2: Verify PCR measurements
test_pcr_measurements() {
    log_test "Testing PCR measurements..."
    
    local success=0
    
    for pcr in ${PCR_POLICY//,/ }; do
        local pcr_value=$(tpm2_pcrread sha256:$pcr 2>/dev/null | grep "sha256" | awk '{print $3}' || echo "")
        
        if [ -n "$pcr_value" ] && [ "$pcr_value" != "0000000000000000000000000000000000000000000000000000000000000000" ]; then
            log_info "✓ PCR $pcr has valid measurement: ${pcr_value:0:16}..."
            success=$((success + 1))
        else
            log_warn "✗ PCR $pcr appears empty or unreadable"
        fi
    done
    
    if [ $success -gt 0 ]; then
        log_info "✓ PCR measurements test passed ($success/4 PCRs have measurements)"
        return 0
    else
        log_error "✗ No valid PCR measurements found"
        return 1
    fi
}

# Test 3: Test PCR policy creation
test_pcr_policy() {
    log_test "Testing PCR policy creation..."
    
    local policy_file="/tmp/test_pcr_policy.dat"
    
    if tpm2_createpolicy --policy-pcr -l "sha256:$PCR_POLICY" -f "$policy_file" 2>/dev/null; then
        if [ -f "$policy_file" ]; then
            log_info "✓ PCR policy created successfully"
            rm -f "$policy_file"
            return 0
        fi
    fi
    
    log_error "✗ PCR policy creation failed"
    return 1
}

# Test 4: Test systemd-cryptenroll availability
test_systemd_cryptenroll() {
    log_test "Testing systemd-cryptenroll TPM2 support..."
    
    if ! command -v systemd-cryptenroll &>/dev/null; then
        log_error "✗ systemd-cryptenroll not available"
        return 1
    fi
    
    if systemd-cryptenroll --help | grep -q "tpm2"; then
        log_info "✓ systemd-cryptenroll supports TPM2"
        return 0
    else
        log_error "✗ systemd-cryptenroll lacks TPM2 support"
        return 1
    fi
}

# Test 5: Evil Maid attack simulation
test_evil_maid_simulation() {
    log_test "Running Evil Maid attack simulation..."
    
    log_warn "This test will modify PCR values - run on test system only!"
    
    # Record baseline PCR values
    local baseline_file="/tmp/pcr_baseline_$(date +%Y%m%d_%H%M%S).txt"
    log_info "Recording baseline PCR values..."
    
    for pcr in ${PCR_POLICY//,/ }; do
        echo "PCR $pcr: $(tpm2_pcrread sha256:$pcr | grep "sha256" | awk '{print $3}')" >> "$baseline_file"
    done
    
    log_info "Baseline saved to: $baseline_file"
    
    # Simulate bootloader tampering by extending PCR 4
    log_info "Simulating bootloader modification (extending PCR 4)..."
    
    local test_data="evil_maid_test_$(date +%s)"
    echo -n "$test_data" | tpm2_pcrextend 4:sha256=/dev/stdin
    
    # Show the change
    local new_pcr4=$(tpm2_pcrread sha256:4 | grep "sha256" | awk '{print $3}')
    log_warn "PCR 4 modified - new value: ${new_pcr4:0:16}..."
    
    # Test policy creation with modified PCRs (should create different policy)
    local modified_policy="/tmp/modified_pcr_policy.dat"
    if tpm2_createpolicy --policy-pcr -l "sha256:$PCR_POLICY" -f "$modified_policy" 2>/dev/null; then
        log_info "✓ Policy created with modified PCRs (would be different from original)"
        rm -f "$modified_policy"
    fi
    
    log_info "✓ Evil Maid simulation completed"
    log_warn "PCR 4 has been modified - reboot to restore normal values"
    
    return 0
}

# Test 6: LUKS device discovery
test_luks_discovery() {
    log_test "Testing LUKS device discovery..."
    
    local luks_found=0
    
    # Check /proc/mounts for LUKS devices
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        if [[ "$device" =~ ^/dev/mapper/ ]]; then
            if sudo cryptsetup status "$device" &>/dev/null; then
                local backing=$(sudo cryptsetup status "$device" | grep "device:" | awk '{print $2}' || echo "unknown")
                log_info "Found LUKS device: $device (backing: $backing)"
                luks_found=$((luks_found + 1))
            fi
        fi
    done < /proc/mounts
    
    if [ $luks_found -gt 0 ]; then
        log_info "✓ LUKS device discovery successful ($luks_found devices)"
        return 0
    else
        log_warn "No LUKS devices found (may be normal in test environment)"
        return 1
    fi
}

# Generate test report
generate_test_report() {
    log_test "Generating TPM2 test report..."
    
    local report_file="$WORK_DIR/tpm2-test-report.md"
    
    cat > "$report_file" << EOF
# TPM2 Measured Boot Test Report

**Generated:** $(date)
**Task:** 5. Configure TPM2 measured boot and key sealing with recovery - Testing

## Test Summary

This report documents the testing of TPM2 measured boot implementation.

## Test Results

EOF
    
    # Run tests and capture results
    local total_tests=0
    local passed_tests=0
    
    local test_functions=(
        "test_tpm2_hardware"
        "test_pcr_measurements"
        "test_pcr_policy"
        "test_systemd_cryptenroll"
        "test_luks_discovery"
    )
    
    echo "### Automated Test Results" >> "$report_file"
    echo "" >> "$report_file"
    
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
    
    # Add current system state
    cat >> "$report_file" << EOF

## Current System State

### TPM2 Information
EOF
    
    if command -v tpm2_getcap &>/dev/null; then
        echo '```' >> "$report_file"
        tpm2_getcap properties-fixed >> "$report_file" 2>/dev/null || echo "TPM2 not accessible" >> "$report_file"
        echo '```' >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### Current PCR Values
EOF
    
    echo '```' >> "$report_file"
    for pcr in ${PCR_POLICY//,/ }; do
        echo "PCR $pcr:" >> "$report_file"
        tpm2_pcrread sha256:$pcr >> "$report_file" 2>/dev/null || echo "  Error reading PCR $pcr" >> "$report_file"
    done
    echo '```' >> "$report_file"
    
    # Add summary
    cat >> "$report_file" << EOF

## Overall Results

- **Total Tests:** $total_tests
- **Passed:** $passed_tests  
- **Failed:** $((total_tests - passed_tests))
- **Success Rate:** $(( passed_tests * 100 / total_tests ))%

## Manual Testing Required

The following tests require manual verification:

1. **TPM2 LUKS Enrollment:**
   - Enroll TPM2 keyslot on actual LUKS device
   - Test automatic unlocking on boot
   - Verify fallback to passphrase

2. **Evil Maid Protection:**
   - Modify bootloader and test TPM2 sealing failure
   - Verify system falls back to passphrase entry
   - Test recovery procedures

3. **Hardware Changes:**
   - Test TPM2 behavior after hardware changes
   - Verify recovery procedures work
   - Test re-enrollment process

## Recommendations

EOF
    
    if [ $passed_tests -eq $total_tests ]; then
        echo "✅ **All automated tests passed!** TPM2 measured boot appears ready for deployment." >> "$report_file"
    else
        echo "⚠️  **Some tests failed.** Address the failures before proceeding." >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Next Steps

1. Complete manual testing procedures
2. Enroll TPM2 keyslots on production LUKS devices
3. Test recovery scenarios thoroughly
4. Proceed to Task 6 (hardened kernel)

## Files

- Test log: \`$LOG_FILE\`
- This report: \`$report_file\`

EOF
    
    log_info "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting TPM2 measured boot testing..."
    
    init_test_logging
    
    # Run all tests
    local total_tests=0
    local passed_tests=0
    
    local test_functions=(
        "test_tpm2_hardware"
        "test_pcr_measurements" 
        "test_pcr_policy"
        "test_systemd_cryptenroll"
        "test_luks_discovery"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
        echo # Add spacing between tests
    done
    
    # Ask about Evil Maid simulation
    echo
    log_warn "Evil Maid simulation will modify PCR values"
    read -p "Run Evil Maid simulation? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_evil_maid_simulation
    else
        log_info "Evil Maid simulation skipped"
    fi
    
    generate_test_report
    
    log_info "=== TPM2 Testing Completed ==="
    log_info "Results: $passed_tests/$total_tests automated tests passed"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_info "✅ All automated tests PASSED!"
    else
        log_warn "⚠️  Some tests FAILED - review configuration"
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--evil-maid-only]"
        echo "Tests TPM2 measured boot implementation"
        echo ""
        echo "Options:"
        echo "  --help           Show this help"
        echo "  --evil-maid-only Run only Evil Maid simulation"
        exit 0
        ;;
    --evil-maid-only)
        init_test_logging
        test_evil_maid_simulation
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac