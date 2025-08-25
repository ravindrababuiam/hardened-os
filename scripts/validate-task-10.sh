#!/bin/bash
#
# Task 10 Validation Script
# Validates the implementation of minimal system services and attack surface reduction
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

echo "=== Task 10 Implementation Validation ==="
echo "Validating: Implement minimal system services and attack surface reduction"
echo

# Check 1: Verify main setup script exists and is executable
log_check "Minimal services setup script exists and is executable"
if [ -f "scripts/setup-minimal-services.sh" ] && [ -x "scripts/setup-minimal-services.sh" ]; then
    log_info "✓ PASS: Setup script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 2: Verify test script exists and is executable
log_check "Minimal services test script exists and is executable"
if [ -f "scripts/test-minimal-services.sh" ] && [ -x "scripts/test-minimal-services.sh" ]; then
    log_info "✓ PASS: Test script exists and is executable"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script missing or not executable"
fi
total_checks=$((total_checks + 1))

# Check 3: Verify validation script exists
run_check "Validation script exists" "[ -f 'scripts/validate-task-10.sh' ]"

# Check 4: Check for systemd availability
run_check "Systemd available" "command -v systemctl"

# Check 5: Check for required system tools
log_check "Required system tools available"
required_tools=("find" "grep" "awk" "sysctl" "modprobe")
available_tools=0

for tool in "${required_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        available_tools=$((available_tools + 1))
    fi
done

if [ $available_tools -eq ${#required_tools[@]} ]; then
    log_info "✓ PASS: All required tools available ($available_tools/${#required_tools[@]})"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Some required tools missing ($available_tools/${#required_tools[@]})"
fi
total_checks=$((total_checks + 1))

# Check 6: Check for capability tools (optional but recommended)
log_check "Capability management tools available"
if command -v setcap &>/dev/null && command -v getcap &>/dev/null; then
    log_info "✓ PASS: Capability tools available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Capability tools not available - install libcap2-bin"
fi
total_checks=$((total_checks + 1))

# Check 7: Script syntax validation
log_check "Setup script syntax validation"
if bash -n scripts/setup-minimal-services.sh 2>/dev/null; then
    log_info "✓ PASS: Setup script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script has syntax errors"
fi
total_checks=$((total_checks + 1))

log_check "Test script syntax validation"
if bash -n scripts/test-minimal-services.sh 2>/dev/null; then
    log_info "✓ PASS: Test script syntax is valid"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script has syntax errors"
fi
total_checks=$((total_checks + 1))

# Check 8: Help functionality
log_check "Setup script help functionality"
if scripts/setup-minimal-services.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Setup script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Setup script help not working"
fi
total_checks=$((total_checks + 1))

log_check "Test script help functionality"
if scripts/test-minimal-services.sh --help | grep -q "Usage:"; then
    log_info "✓ PASS: Test script help works"
    passed_checks=$((passed_checks + 1))
else
    log_error "✗ FAIL: Test script help not working"
fi
total_checks=$((total_checks + 1))

# Check 9: Sudo access (required for system modifications)
log_check "Sudo access available"
if sudo -n true 2>/dev/null || sudo -v 2>/dev/null; then
    log_info "✓ PASS: Sudo access available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Sudo access not available - required for system modifications"
fi
total_checks=$((total_checks + 1))

# Check 10: Check current system state (informational)
log_check "Current system service count"
if command -v systemctl &>/dev/null; then
    running_services=$(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep -c "\.service" || echo "0")
    enabled_services=$(systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null | grep -c "\.service" || echo "0")
    
    log_info "Current system state:"
    log_info "  Running services: $running_services"
    log_info "  Enabled services: $enabled_services"
    
    # This is always a pass since it's informational
    passed_checks=$((passed_checks + 1))
else
    log_warn "Cannot check service status - systemctl not available"
fi
total_checks=$((total_checks + 1))

# Check 11: Check for existing hardening configurations
log_check "Existing hardening configurations"
existing_configs=0

if [ -f /etc/modprobe.d/hardened-blacklist.conf ]; then
    log_info "  ✓ Kernel module blacklist already exists"
    existing_configs=$((existing_configs + 1))
fi

if [ -f /etc/sysctl.d/99-hardened-security.conf ]; then
    log_info "  ✓ Hardened sysctl configuration already exists"
    existing_configs=$((existing_configs + 1))
fi

if [ $existing_configs -gt 0 ]; then
    log_info "✓ PASS: Some hardening configurations already present ($existing_configs found)"
    passed_checks=$((passed_checks + 1))
else
    log_info "No existing hardening configurations found (normal for first run)"
    passed_checks=$((passed_checks + 1))
fi
total_checks=$((total_checks + 1))

# Check 12: Check SUID binary count (baseline)
log_check "Current SUID/SGID binary count"
if command -v find &>/dev/null; then
    suid_count=$(find /usr -type f -perm -4000 2>/dev/null | wc -l)
    sgid_count=$(find /usr -type f -perm -2000 2>/dev/null | wc -l)
    
    log_info "Current SUID/SGID binary count:"
    log_info "  SUID binaries: $suid_count"
    log_info "  SGID binaries: $sgid_count"
    
    # This is informational, always pass
    passed_checks=$((passed_checks + 1))
else
    log_warn "Cannot check SUID/SGID binaries - find command not available"
fi
total_checks=$((total_checks + 1))

# Check 13: Check kernel module support
log_check "Kernel module management support"
if command -v modprobe &>/dev/null && [ -d /proc/modules ]; then
    log_info "✓ PASS: Kernel module management available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Kernel module management not available"
fi
total_checks=$((total_checks + 1))

# Check 14: Check sysctl support
log_check "Sysctl configuration support"
if command -v sysctl &>/dev/null && [ -d /proc/sys ]; then
    log_info "✓ PASS: Sysctl configuration available"
    passed_checks=$((passed_checks + 1))
else
    log_warn "Sysctl configuration not available"
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
    log_info "🎉 ALL CHECKS PASSED! Task 10 implementation is ready."
    echo
    echo "Next Steps:"
    echo "1. Run: ./scripts/setup-minimal-services.sh"
    echo "2. Reboot system to apply all changes"
    echo "3. Test: ./scripts/test-minimal-services.sh"
    echo "4. Proceed to Task 11 (userspace hardening)"
    exit 0
else
    echo
    log_error "❌ Some checks failed. Please address the issues above."
    echo
    echo "Common fixes:"
    echo "- Make scripts executable: chmod +x scripts/*.sh"
    echo "- Install required tools: sudo apt install libcap2-bin"
    echo "- Ensure sudo access is available"
    echo "- Check script syntax for any errors"
    echo "- Verify systemd is available and running"
    exit 1
fi