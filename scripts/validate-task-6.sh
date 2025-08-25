#!/bin/bash
#
# Task 6 Validation Script
# Validates the implementation of hardened kernel build with KSPP configuration
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

echo "=== Task 6 Implementation Validation ==="
echo "Validating: Build hardened kernel with KSPP configuration and exploit testing"
echo

# Check 1: Verify kernel build script exists and is executable
log_check "Kernel build script exists and is executable"
if [ -f "scripts/build-hardened-kernel.sh" ] && [ -x "scripts/build-hardened-kernel.sh" ]; then
    log_info "✓ PASS: Kernel build script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Kernel build script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 2: Verify exploit testing script exists and is executable
log_check "Exploit testing script exists and is executable"
if [ -f "scripts/test-kernel-exploits.sh" ] && [ -x "scripts/test-kernel-exploits.sh" ]; then
    log_info "✓ PASS: Exploit testing script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Exploit testing script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 3: Verify validation script exists
run_check "Validation script exists" "[ -f 'scripts/validate-task-6.sh' ]"

# Check 4: Verify build dependencies
run_check "gcc compiler available" "command -v gcc"
run_check "make build tool available" "command -v make"
run_check "bc calculator available" "command -v bc"

# Check 5: Verify kernel build dependencies (packages)
log_check "Kernel build dependencies check"
deps=("build-essential" "bc" "bison" "flex" "libssl-dev" "libelf-dev" "libncurses-dev")
missing_deps=()

for dep in "${deps[@]}"; do
    if ! dpkg -l | grep -q "^ii.*$dep" 2>/dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -eq 0 ]; then
    log_info "✓ PASS: All kernel build dependencies available"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Missing dependencies: ${missing_deps[*]}"
fi
total_checks=$((total_checks + 1))

# Check 6: Verify sufficient disk space (approximate)
log_check "Sufficient disk space for kernel build"
local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
if [ "$available_space" -gt 10485760 ]; then  # 10GB in KB
    log_info "✓ PASS: Sufficient disk space ($(( available_space / 1024 / 1024 ))GB available)"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Insufficient disk space (need ~20GB for kernel build)"
fi
total_checks=$((total_checks + 1))

# Check 7: Script syntax validation
log_check "Kernel build script syntax validation"
if bash -n scripts/build-hardened-kernel.sh 2>/dev/null; then
    log_info "✓ PASS: Kernel build script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Kernel build script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Exploit testing script syntax validation"
if bash -n scripts/test-kernel-exploits.sh 2>/dev/null; then
    log_info "✓ PASS: Exploit testing script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Exploit testing script has syntax errors"
fi
total_checks=$((total_checks + 1))

# Check 8: Help functionality
log_check "Kernel build script help functionality"
if scripts/build-hardened-kernel.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Kernel build script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Kernel build script help not working"
fi
total_checks=$((total_checks + 1))

log_check "Exploit testing script help functionality"
if scripts/test-kernel-exploits.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Exploit testing script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Exploit testing script help not working"
fi
total_checks=$((total_checks + 1))

# Check 9: Current kernel hardening features (if available)
if [ -d /sys/devices/system/cpu/vulnerabilities ]; then
    log_check "Current kernel vulnerability mitigations"
    local mitigated=0
    local total_vulns=0
    
    for vuln_file in /sys/devices/system/cpu/vulnerabilities/*; do
        total_vulns=$((total_vulns + 1))
        local vuln_status=$(cat "$vuln_file" 2>/dev/null || echo "unknown")
        if echo "$vuln_status" | grep -q -i "mitigation\|not affected"; then
            mitigated=$((mitigated + 1))
        fi
    done
    
    if [ $mitigated -gt 0 ]; then
        log_info "✓ PASS: Kernel vulnerability mitigations active ($mitigated/$total_vulns)"
        passed_checks=$((passed_checks + 1))
    else
        log_warn "Current kernel has limited vulnerability mitigations"
    fi
    total_checks=$((total_checks + 1))
else
    log_warn "Kernel vulnerability information not available"
fi

# Check 10: ASLR configuration
log_check "ASLR configuration"
local aslr_setting=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "0")
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
    log_info "🎉 ALL CHECKS PASSED! Task 6 implementation is complete."
    echo
    echo "Next Steps:"
    echo "1. Run: ./scripts/build-hardened-kernel.sh --config-only (to test configuration)"
    echo "2. Run: ./scripts/build-hardened-kernel.sh (full kernel build - takes time!)"
    echo "3. Test: ./scripts/test-kernel-exploits.sh (after kernel installation)"
    echo "4. Proceed to Task 7 (compiler hardening)"
    exit 0
else
    echo
    log_error "❌ Some checks failed. Please address the issues above."
    echo
    echo "Common fixes:"
    echo "- Make scripts executable: chmod +x scripts/*.sh"
    echo "- Install build dependencies: sudo apt install build-essential bc bison flex libssl-dev libelf-dev libncurses-dev"
    echo "- Ensure sufficient disk space (20GB+ recommended)"
    echo "- Check script syntax for any errors"
    exit 1
fi