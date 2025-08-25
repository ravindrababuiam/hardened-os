#!/bin/bash
#
# Task 5 Validation Script
# Validates the implementation of TPM2 measured boot and key sealing with recovery
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

# Validation counters
total_checks=0
passed_checks=0

# Helper function to run checks
run_check() {
    local description="$1"
    local command="$2"
    
    total_checks=$((total_checks + 1))
    log_check "$description"
    
    if eval "$command" &>/dev/null; then
        log_info "✓ PASS: $description"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        log_error "✗ FAIL: $description"
        return 1
    fi
}

echo "=== Task 5 Implementation Validation ==="
echo "Validating: Configure TPM2 measured boot and key sealing with recovery"
echo

# Check 1: Verify main setup script exists and is executable
log_check "Main setup script exists and is executable"
if [ -f "scripts/setup-tpm2-measured-boot.sh" ] && [ -x "scripts/setup-tpm2-measured-boot.sh" ]; then
    log_info "✓ PASS: Main setup script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Main setup script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 2: Verify test script exists and is executable
log_check "Test script exists and is executable"
if [ -f "scripts/test-tpm2-measured-boot.sh" ] && [ -x "scripts/test-tpm2-measured-boot.sh" ]; then
    log_info "✓ PASS: Test script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 3: Verify recovery script exists and is executable
log_check "Recovery script exists and is executable"
if [ -f "scripts/tpm2-recovery.sh" ] && [ -x "scripts/tpm2-recovery.sh" ]; then
    log_info "✓ PASS: Recovery script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Recovery script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 4: Verify validation script exists
run_check "Validation script exists" "[ -f 'scripts/validate-task-5.sh' ]"

# Check 5: Verify TPM2 tools are available
run_check "tpm2_getcap is available" "command -v tpm2_getcap"
run_check "tpm2_pcrread is available" "command -v tpm2_pcrread"
run_check "tpm2_createpolicy is available" "command -v tpm2_createpolicy"

# Check 6: Verify systemd tools
run_check "systemd-cryptenroll is available" "command -v systemd-cryptenroll"
run_check "cryptsetup is available" "command -v cryptsetup"

# Check 7: Verify UEFI environment (if available)
if [ -d /sys/firmware/efi ]; then
    run_check "System booted with UEFI" "[ -d /sys/firmware/efi ]"
else
    log_warn "System not booted with UEFI (may be normal in test environment)"
    total_checks=$((total_checks + 1))
fi

# Check 8: Verify TPM device (if available)
if [ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]; then
    run_check "TPM device available" "[ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]"
else
    log_warn "No TPM device found (may be normal in test environment)"
    total_checks=$((total_checks + 1))
fi

# Check 9: Script syntax validation
log_check "Main setup script syntax validation"
if bash -n scripts/setup-tpm2-measured-boot.sh 2>/dev/null; then
    log_info "✓ PASS: Main setup script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Main setup script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Test script syntax validation"
if bash -n scripts/test-tpm2-measured-boot.sh 2>/dev/null; then
    log_info "✓ PASS: Test script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Recovery script syntax validation"
if bash -n scripts/tpm2-recovery.sh 2>/dev/null; then
    log_info "✓ PASS: Recovery script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Recovery script has syntax errors"
fi
total_checks=$((total_checks + 1))

# Check 10: Help functionality
log_check "Main setup script help functionality"
if scripts/setup-tpm2-measured-boot.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Main setup script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Main setup script help not working"
fi
total_checks=$((total_checks + 1))

log_check "Test script help functionality"
if scripts/test-tpm2-measured-boot.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Test script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script help not working"
fi
total_checks=$((total_checks + 1))

# Check 11: TPM2 communication (if TPM available)
if command -v tpm2_getcap &>/dev/null && ([ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ]); then
    log_check "TPM2 communication test"
    if tpm2_getcap properties-fixed &>/dev/null; then
        log_info "✓ PASS: TPM2 communication successful"
        passed_checks=$((passed_checks + 1))
    else
        log_error "✗ FAIL: TPM2 communication failed"
    fi
    total_checks=$((total_checks + 1))
else
    log_warn "Skipping TPM2 communication test (TPM not available)"
fi

echo
echo "=== Validation Summary ==="
echo "Total Checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed: $((total_checks - passed_checks))"
echo "Success Rate: $(( passed_checks * 100 / total_checks ))%"

if [ $passed_checks -eq $total_checks ]; then
    echo
    log_info "🎉 ALL CHECKS PASSED! Task 5 implementation is complete."
    echo
    echo "Next Steps:"
    echo "1. Run: ./scripts/setup-tpm2-measured-boot.sh"
    echo "2. Enroll TPM2 keyslots for LUKS devices"
    echo "3. Test: ./scripts/test-tpm2-measured-boot.sh"
    echo "4. Proceed to Task 6 (hardened kernel)"
    exit 0
else
    echo
    log_error "❌ Some checks failed. Please address the issues above."
    echo
    echo "Common fixes:"
    echo "- Make scripts executable: chmod +x scripts/*.sh"
    echo "- Install TPM2 tools: sudo apt install tpm2-tools"
    echo "- Install systemd tools: sudo apt install systemd-container"
    echo "- Enable TPM in BIOS/UEFI settings"
    exit 1
fi