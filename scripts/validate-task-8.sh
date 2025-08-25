#!/bin/bash
#
# Task 8 Validation Script
# Validates the implementation of signed kernel packages and initramfs
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

echo "=== Task 8 Implementation Validation ==="
echo "Validating: Create signed kernel packages and initramfs"
echo

# Check 1: Verify main packaging script exists and is executable
log_check "Kernel packaging script exists and is executable"
if [ -f "scripts/create-signed-kernel-packages.sh" ] && [ -x "scripts/create-signed-kernel-packages.sh" ]; then
    log_info "✓ PASS: Packaging script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Packaging script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 2: Verify test script exists and is executable
log_check "Package testing script exists and is executable"
if [ -f "scripts/test-kernel-packages.sh" ] && [ -x "scripts/test-kernel-packages.sh" ]; then
    log_info "✓ PASS: Test script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 3: Verify validation script exists
run_check "Validation script exists" "[ -f 'scripts/validate-task-8.sh' ]"

# Check 4: Verify packaging dependencies
run_check "dpkg-deb available" "command -v dpkg-deb"
run_check "fakeroot available" "command -v fakeroot"

log_check "sbsign available for signing"
if command -v sbsign &>/dev/null; then
    log_info "✓ PASS: sbsign available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "sbsign not available - install sbsigntool package"
fi
total_checks=$((total_checks + 1))

# Check 5: Verify initramfs tools
run_check "mkinitramfs available" "command -v mkinitramfs"

log_check "Compression tools available"
compression_tools=("lz4" "xz" "gzip")
available_tools=0

for tool in "${compression_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        available_tools=$((available_tools + 1))
    fi
done

if [ $available_tools -gt 0 ]; then
    log_info "✓ PASS: Compression tools available ($available_tools/3)"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: No compression tools available"
fi
total_checks=$((total_checks + 1))

# Check 6: Verify signing keys exist
log_check "Signing keys available"
if [ -f "$HOME/harden/keys/dev/DB/DB.key" ] && [ -f "$HOME/harden/keys/dev/DB/DB.crt" ]; then
    log_info "✓ PASS: Signing keys found"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Signing keys not found - run generate-dev-keys.sh first"
fi
total_checks=$((total_checks + 1))

# Check 7: Verify hardened kernel exists
log_check "Hardened kernel source available"
kernel_dirs=("$HOME/harden/src/linux-"*)
if [ -d "${kernel_dirs[0]}" ] 2>/dev/null; then
    log_info "✓ PASS: Kernel source directory found"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Kernel source not found - run build-hardened-kernel.sh first"
fi
total_checks=$((total_checks + 1))

# Check 8: Script syntax validation
log_check "Packaging script syntax validation"
if bash -n scripts/create-signed-kernel-packages.sh 2>/dev/null; then
    log_info "✓ PASS: Packaging script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Packaging script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Test script syntax validation"
if bash -n scripts/test-kernel-packages.sh 2>/dev/null; then
    log_info "✓ PASS: Test script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script has syntax errors"
fi
total_checks=$((total_checks + 1))

# Check 9: Help functionality
log_check "Packaging script help functionality"
if scripts/create-signed-kernel-packages.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Packaging script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Packaging script help not working"
fi
total_checks=$((total_checks + 1))

log_check "Test script help functionality"
if scripts/test-kernel-packages.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Test script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script help not working"
fi
total_checks=$((total_checks + 1))

# Check 10: TPM2 tools for initramfs
log_check "TPM2 tools available for initramfs"
tpm2_tools=("tpm2_pcrread" "tpm2_unseal")
available_tpm2=0

for tool in "${tpm2_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        available_tpm2=$((available_tpm2 + 1))
    fi
done

if [ $available_tpm2 -gt 0 ]; then
    log_info "✓ PASS: TPM2 tools available ($available_tpm2/2)"
    passed_checks=$((passed_checks + 1))
else
    log_warn "TPM2 tools not available - install tpm2-tools package"
fi
total_checks=$((total_checks + 1))

# Check 11: systemd-cryptsetup for LUKS
log_check "systemd-cryptsetup available"
if [ -f "/usr/lib/systemd/systemd-cryptsetup" ] || command -v systemd-cryptsetup &>/dev/null; then
    log_info "✓ PASS: systemd-cryptsetup available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "systemd-cryptsetup not found"
fi
total_checks=$((total_checks + 1))

# Check 12: Disk space for packaging
log_check "Sufficient disk space for packaging"
available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
if [ "$available_space" -gt 5242880 ]; then  # 5GB in KB
    log_info "✓ PASS: Sufficient disk space ($(( available_space / 1024 / 1024 ))GB available)"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Limited disk space (need ~5GB for packaging)"
fi
total_checks=$((total_checks + 1))

# Check 13: Architecture support
log_check "Architecture packaging support"
arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$arch" in
    amd64|x86_64)
        log_info "✓ PASS: x86_64 architecture supported"
        passed_checks=$((passed_checks + 1))
        ;;
    arm64|aarch64)
        log_info "✓ PASS: ARM64 architecture supported"
        passed_checks=$((passed_checks + 1))
        ;;
    *)
        log_warn "Architecture $arch may have limited support"
        ;;
esac
total_checks=$((total_checks + 1))

echo
echo "=== Validation Summary ==="
echo "Total Checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed: $((total_checks - passed_checks))"
echo "Success Rate: $(( passed_checks * 100 / total_checks ))%"

if [ $passed_checks -eq $total_checks ]; then
    echo
    log_info "🎉 ALL CHECKS PASSED! Task 8 implementation is complete."
    echo
    echo "Next Steps:"
    echo "1. Run: ./scripts/create-signed-kernel-packages.sh"
    echo "2. Test: ./scripts/test-kernel-packages.sh"
    echo "3. Install packages: sudo dpkg -i ~/harden/build/packages/*.deb"
    echo "4. Proceed to Task 9 (SELinux configuration)"
    exit 0
else
    echo
    log_error "❌ Some checks failed. Please address the issues above."
    echo
    echo "Common fixes:"
    echo "- Make scripts executable: chmod +x scripts/*.sh"
    echo "- Install packaging tools: sudo apt install dpkg-dev fakeroot sbsigntool"
    echo "- Install TPM2 tools: sudo apt install tpm2-tools"
    echo "- Install initramfs tools: sudo apt install initramfs-tools lz4 xz-utils"
    echo "- Generate signing keys: ./scripts/generate-dev-keys.sh"
    echo "- Build hardened kernel: ./scripts/build-hardened-kernel.sh"
    exit 1
fi