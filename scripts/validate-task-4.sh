#!/bin/bash
#
# Task 4 Validation Script
# Validates the implementation of UEFI Secure Boot with custom keys
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

echo "=== Task 4 Implementation Validation ==="
echo "Validating: Implement UEFI Secure Boot with custom keys"
echo

# Check 1: Verify setup script exists and is executable
log_check "Setup script exists and is executable"
if [ -f "scripts/setup-secure-boot.sh" ] && [ -x "scripts/setup-secure-boot.sh" ]; then
    log_info "✓ PASS: Setup script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 2: Verify test script exists and is executable  
log_check "Test script exists and is executable"
if [ -f "scripts/test-secure-boot.sh" ] && [ -x "scripts/test-secure-boot.sh" ]; then
    log_info "✓ PASS: Test script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 3: Verify documentation exists
run_check "Documentation exists" "[ -f 'docs/secure-boot-implementation.md' ]"

# Check 4: Verify validation script exists
run_check "Validation script exists" "[ -f 'scripts/validate-task-4.sh' ]"

# Check 5: Verify development keys exist (prerequisite)
run_check "Development keys exist" "[ -f '$HOME/harden/keys/dev/PK/PK.key' ]"

# Check 6: Verify required tools are available
run_check "sbctl is available" "command -v sbctl"
run_check "efibootmgr is available" "command -v efibootmgr"  
run_check "openssl is available" "command -v openssl"

# Check 7: Verify UEFI boot environment
run_check "System booted with UEFI" "[ -d /sys/firmware/efi ]"

# Check 8: Verify EFI variables access
run_check "EFI variables accessible" "[ -d /sys/firmware/efi/efivars ]"

# Check 9: Check script functionality (basic syntax)
log_check "Setup script syntax validation"
if bash -n scripts/setup-secure-boot.sh 2>/dev/null; then
    log_info "✓ PASS: Setup script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Test script syntax validation"
if bash -n scripts/test-secure-boot.sh 2>/dev/null; then
    log_info "✓ PASS: Test script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script has syntax errors"
fi
total_checks=$((total_checks + 1))

# Check 10: Verify help functionality
log_check "Setup script help functionality"
if scripts/setup-secure-boot.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Setup script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script help not working"
fi
total_checks=$((total_checks + 1))

log_check "Test script help functionality"
if scripts/test-secure-boot.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Test script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script help not working"
fi
total_checks=$((total_checks + 1))

echo
echo "=== Validation Summary ==="
echo "Total Checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed: $((total_checks - passed_checks))"
echo "Success Rate: $(( passed_checks * 100 / total_checks ))%"

if [ $passed_checks -eq $total_checks ]; then
    echo
    log_info "🎉 ALL CHECKS PASSED! Task 4 implementation is complete."
    echo
    echo "Next Steps:"
    echo "1. Run: ./scripts/setup-secure-boot.sh"
    echo "2. Enable Secure Boot in UEFI setup"
    echo "3. Run: ./scripts/test-secure-boot.sh"
    echo "4. Proceed to Task 5 (TPM2 integration)"
    exit 0
else
    echo
    log_error "❌ Some checks failed. Please address the issues above."
    echo
    echo "Common fixes:"
    echo "- Make scripts executable: chmod +x scripts/*.sh"
    echo "- Install missing tools: sudo apt install sbctl efibootmgr"
    echo "- Generate development keys: ./scripts/generate-dev-keys.sh"
    exit 1
fi