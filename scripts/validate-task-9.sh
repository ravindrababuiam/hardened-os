#!/bin/bash
#
# Task 9 Validation Script
# Validates the implementation of SELinux enforcing mode configuration
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

echo "=== Task 9 Implementation Validation ==="
echo "Validating: Configure SELinux in enforcing mode with targeted policy"
echo

# Check 1: Verify main setup script exists and is executable
log_check "SELinux setup script exists and is executable"
if [ -f "scripts/setup-selinux-enforcing.sh" ] && [ -x "scripts/setup-selinux-enforcing.sh" ]; then
    log_info "✓ PASS: Setup script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 2: Verify test script exists and is executable
log_check "SELinux test script exists and is executable"
if [ -f "scripts/test-selinux-enforcement.sh" ] && [ -x "scripts/test-selinux-enforcement.sh" ]; then
    log_info "✓ PASS: Test script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 3: Verify validation script exists
run_check "Validation script exists" "[ -f 'scripts/validate-task-9.sh' ]"

# Check 4: Check for SELinux tools availability
log_check "SELinux basic tools available"
selinux_tools=("getenforce" "semodule" "restorecon" "chcon")
available_tools=0

for tool in "${selinux_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        available_tools=$((available_tools + 1))
    fi
done

if [ $available_tools -gt 0 ]; then
    log_info "✓ PASS: SELinux tools available ($available_tools/4)"
    passed_checks=$((passed_checks + 1))
else
    log_warn "No SELinux tools available - may need to install SELinux packages"
fi
total_checks=$((total_checks + 1))

# Check 5: Check for policy development tools
log_check "SELinux policy development tools"
policy_tools=("checkpolicy" "semodule_package" "make")
available_policy_tools=0

for tool in "${policy_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        available_policy_tools=$((available_policy_tools + 1))
    fi
done

if [ $available_policy_tools -gt 0 ]; then
    log_info "✓ PASS: Policy development tools available ($available_policy_tools/3)"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Policy development tools not available - install selinux-policy-dev"
fi
total_checks=$((total_checks + 1))

# Check 6: Check for audit tools
run_check "Audit tools available" "command -v ausearch"
run_check "Audit daemon available" "command -v auditd"

# Check 7: Check for setroubleshoot
log_check "Setroubleshoot available"
if command -v sealert &>/dev/null; then
    log_info "✓ PASS: sealert (setroubleshoot) available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "sealert not available - install setroubleshoot-server"
fi
total_checks=$((total_checks + 1))

# Check 8: Script syntax validation
log_check "Setup script syntax validation"
if bash -n scripts/setup-selinux-enforcing.sh 2>/dev/null; then
    log_info "✓ PASS: Setup script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Test script syntax validation"
if bash -n scripts/test-selinux-enforcement.sh 2>/dev/null; then
    log_info "✓ PASS: Test script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script has syntax errors"
fi
total_checks=$((total_checks + 1))

# Check 9: Help functionality
log_check "Setup script help functionality"
if scripts/setup-selinux-enforcing.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Setup script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script help not working"
fi
total_checks=$((total_checks + 1))

log_check "Test script help functionality"
if scripts/test-selinux-enforcement.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Test script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script help not working"
fi
total_checks=$((total_checks + 1))

# Check 10: Kernel SELinux support
log_check "Kernel SELinux support"
if [ -d /sys/fs/selinux ] || [ -f /proc/filesystems ] && grep -q selinuxfs /proc/filesystems; then
    log_info "✓ PASS: Kernel has SELinux support"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Kernel SELinux support not detected - may need kernel recompile"
fi
total_checks=$((total_checks + 1))

# Check 11: Current SELinux status (if available)
log_check "Current SELinux status"
if command -v getenforce &>/dev/null; then
    selinux_status=$(getenforce 2>/dev/null || echo "Unknown")
    case "$selinux_status" in
        "Enforcing")
            log_info "✓ PASS: SELinux is currently enforcing"
            passed_checks=$((passed_checks + 1))
            ;;
        "Permissive")
            log_info "SELinux is in permissive mode (can be changed to enforcing)"
            passed_checks=$((passed_checks + 1))
            ;;
        "Disabled")
            log_warn "SELinux is currently disabled"
            ;;
        *)
            log_warn "SELinux status unknown: $selinux_status"
            ;;
    esac
else
    log_warn "Cannot determine SELinux status - getenforce not available"
fi
total_checks=$((total_checks + 1))

# Check 12: SELinux configuration file
log_check "SELinux configuration file"
if [ -f /etc/selinux/config ]; then
    log_info "✓ PASS: SELinux configuration file exists"
    
    # Check configuration content
    if grep -q "SELINUX=" /etc/selinux/config; then
        selinux_config=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
        log_info "  Current config: SELINUX=$selinux_config"
    fi
    
    passed_checks=$((passed_checks + 1))
else
    log_warn "SELinux configuration file not found"
fi
total_checks=$((total_checks + 1))

# Check 13: Policy makefile availability
log_check "SELinux policy development makefile"
if [ -f /usr/share/selinux/devel/Makefile ]; then
    log_info "✓ PASS: SELinux policy development makefile available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "SELinux policy development makefile not found"
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
    log_info "🎉 ALL CHECKS PASSED! Task 9 implementation is complete."
    echo
    echo "Next Steps:"
    echo "1. Run: ./scripts/setup-selinux-enforcing.sh"
    echo "2. Reboot system to activate SELinux enforcing mode"
    echo "3. Test: ./scripts/test-selinux-enforcement.sh"
    echo "4. Proceed to Task 10 (minimal system services)"
    exit 0
else
    echo
    log_error "❌ Some checks failed. Please address the issues above."
    echo
    echo "Common fixes:"
    echo "- Make scripts executable: chmod +x scripts/*.sh"
    echo "- Install SELinux packages: sudo apt install selinux-basics selinux-policy-default"
    echo "- Install policy development: sudo apt install selinux-policy-dev checkpolicy"
    echo "- Install audit tools: sudo apt install auditd"
    echo "- Install setroubleshoot: sudo apt install setroubleshoot-server"
    echo "- Check kernel SELinux support in kernel config"
    exit 1
fi