#!/bin/bash
#
# Task 7 Validation Script
# Validates the implementation of compiler hardening for kernel and userspace
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

echo "=== Task 7 Implementation Validation ==="
echo "Validating: Implement compiler hardening for kernel and userspace"
echo

# Check 1: Verify main setup script exists and is executable
log_check "Compiler hardening setup script exists and is executable"
if [ -f "scripts/setup-compiler-hardening.sh" ] && [ -x "scripts/setup-compiler-hardening.sh" ]; then
    log_info "✓ PASS: Setup script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 2: Verify test script exists and is executable
log_check "Compiler hardening test script exists and is executable"
if [ -f "scripts/test-compiler-hardening.sh" ] && [ -x "scripts/test-compiler-hardening.sh" ]; then
    log_info "✓ PASS: Test script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 3: Verify validation script exists
run_check "Validation script exists" "[ -f 'scripts/validate-task-7.sh' ]"

# Check 4: Verify compilers are available
run_check "GCC compiler available" "command -v gcc"

log_check "Clang compiler available"
if command -v clang &>/dev/null; then
    log_info "✓ PASS: Clang compiler available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Clang compiler not available (optional but recommended)"
fi
total_checks=$((total_checks + 1))

# Check 5: Verify build tools
run_check "make build tool available" "command -v make"
run_check "ld linker available" "command -v ld"

# Check 6: Check GCC hardening support
log_check "GCC stack protection support"
if gcc -fstack-protector-strong -x c -c /dev/null -o /dev/null 2>/dev/null; then
    log_info "✓ PASS: GCC supports stack protection"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: GCC does not support stack protection"
fi
total_checks=$((total_checks + 1))

log_check "GCC PIE support"
if gcc -fPIE -pie -x c -c /dev/null -o /dev/null 2>/dev/null; then
    log_info "✓ PASS: GCC supports PIE"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: GCC does not support PIE"
fi
total_checks=$((total_checks + 1))

log_check "GCC FORTIFY_SOURCE support"
if gcc -D_FORTIFY_SOURCE=3 -O2 -x c -c /dev/null -o /dev/null 2>/dev/null; then
    log_info "✓ PASS: GCC supports FORTIFY_SOURCE"
    passed_checks=$((passed_checks + 1))
else
    log_warn "GCC FORTIFY_SOURCE support limited"
fi
total_checks=$((total_checks + 1))

# Check 7: Check Clang hardening support (if available)
if command -v clang &>/dev/null; then
    log_check "Clang CFI support"
    if clang -fsanitize=cfi -x c -c /dev/null -o /dev/null 2>/dev/null; then
        log_info "✓ PASS: Clang supports CFI"
        passed_checks=$((passed_checks + 1))
    else
        log_warn "Clang CFI support not available"
    fi
    total_checks=$((total_checks + 1))
    
    log_check "Clang stack protection support"
    if clang -fstack-protector-strong -x c -c /dev/null -o /dev/null 2>/dev/null; then
        log_info "✓ PASS: Clang supports stack protection"
        passed_checks=$((passed_checks + 1))
    else
        log_error "✗ FAIL: Clang does not support stack protection"
    fi
    total_checks=$((total_checks + 1))
fi

# Check 8: Script syntax validation
log_check "Setup script syntax validation"
if bash -n scripts/setup-compiler-hardening.sh 2>/dev/null; then
    log_info "✓ PASS: Setup script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Test script syntax validation"
if bash -n scripts/test-compiler-hardening.sh 2>/dev/null; then
    log_info "✓ PASS: Test script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script has syntax errors"
fi
total_checks=$((total_checks + 1))

# Check 9: Help functionality
log_check "Setup script help functionality"
if scripts/setup-compiler-hardening.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Setup script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script help not working"
fi
total_checks=$((total_checks + 1))

log_check "Test script help functionality"
if scripts/test-compiler-hardening.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Test script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script help not working"
fi
total_checks=$((total_checks + 1))

# Check 10: Architecture support
log_check "Architecture hardening support"
arch=$(uname -m)
case "$arch" in
    x86_64)
        log_info "✓ PASS: x86_64 architecture - full hardening support available"
        passed_checks=$((passed_checks + 1))
        ;;
    aarch64)
        log_info "✓ PASS: ARM64 architecture - enhanced hardening features available"
        passed_checks=$((passed_checks + 1))
        ;;
    *)
        log_warn "Architecture $arch - limited hardening support"
        ;;
esac
total_checks=$((total_checks + 1))

# Check 11: Kernel lockdown interface (if available)
log_check "Kernel lockdown interface availability"
if [ -f /sys/kernel/security/lockdown ]; then
    log_info "✓ PASS: Kernel lockdown interface available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Kernel lockdown interface not available (may need kernel upgrade)"
fi
total_checks=$((total_checks + 1))

# Check 12: Current system hardening status
log_check "Current ASLR configuration"
aslr_setting=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "0")
if [ "$aslr_setting" = "2" ]; then
    log_info "✓ PASS: Full ASLR enabled"
    passed_checks=$((passed_checks + 1))
else
    log_warn "ASLR not fully enabled (current: $aslr_setting, should be 2)"
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
    log_info "🎉 ALL CHECKS PASSED! Task 7 implementation is complete."
    echo
    echo "Next Steps:"
    echo "1. Run: ./scripts/setup-compiler-hardening.sh"
    echo "2. Test: ./scripts/test-compiler-hardening.sh"
    echo "3. Install system-wide: ./scripts/setup-compiler-hardening.sh --install-only"
    echo "4. Proceed to Task 8 (signed kernel packages)"
    exit 0
else
    echo
    log_error "❌ Some checks failed. Please address the issues above."
    echo
    echo "Common fixes:"
    echo "- Make scripts executable: chmod +x scripts/*.sh"
    echo "- Install compilers: sudo apt install gcc clang"
    echo "- Update GCC/Clang to newer versions for better hardening support"
    echo "- Check script syntax for any errors"
    exit 1
fi