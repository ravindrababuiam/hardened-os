#!/bin/bash
#
# Test Script for Task 2 Implementation
# Validates key generation and recovery infrastructure
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test directory structure
test_directory_structure() {
    log_test "Testing directory structure..."
    
    local base_dir="$HOME/harden"
    local required_dirs=(
        "$base_dir/keys"
        "$base_dir/src"
        "$base_dir/build"
        "$base_dir/ci"
        "$base_dir/artifacts"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_pass "Directory exists: $dir"
        else
            log_fail "Directory missing: $dir"
        fi
    done
}

# Test script files exist
test_script_files() {
    log_test "Testing script files..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local required_scripts=(
        "$script_dir/generate-dev-keys.sh"
        "$script_dir/create-recovery-infrastructure.sh"
        "$script_dir/key-manager.sh"
        "$script_dir/key-manager.ps1"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ -f "$script" ]; then
            log_pass "Script exists: $(basename "$script")"
            
            # Check if executable (for .sh files)
            if [[ "$script" == *.sh ]] && [ -x "$script" ]; then
                log_pass "Script is executable: $(basename "$script")"
            elif [[ "$script" == *.sh ]]; then
                log_fail "Script not executable: $(basename "$script")"
            fi
        else
            log_fail "Script missing: $(basename "$script")"
        fi
    done
}

# Test documentation files
test_documentation() {
    log_test "Testing documentation files..."
    
    local doc_files=(
        "docs/key-management.md"
        "docs/task-2-implementation.md"
    )
    
    for doc in "${doc_files[@]}"; do
        if [ -f "$doc" ]; then
            log_pass "Documentation exists: $doc"
            
            # Check file size (should not be empty)
            if [ -s "$doc" ]; then
                log_pass "Documentation has content: $doc"
            else
                log_fail "Documentation is empty: $doc"
            fi
        else
            log_fail "Documentation missing: $doc"
        fi
    done
}

# Test key generation (dry run)
test_key_generation_dryrun() {
    log_test "Testing key generation script (syntax check)..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local key_script="$script_dir/generate-dev-keys.sh"
    
    if [ -f "$key_script" ]; then
        # Test script syntax
        if bash -n "$key_script"; then
            log_pass "Key generation script syntax is valid"
        else
            log_fail "Key generation script has syntax errors"
        fi
        
        # Check for required functions
        local required_functions=(
            "check_dependencies"
            "setup_key_directories"
            "generate_platform_key"
            "generate_kek"
            "generate_db_key"
        )
        
        for func in "${required_functions[@]}"; do
            if grep -q "^$func()" "$key_script"; then
                log_pass "Function exists: $func"
            else
                log_fail "Function missing: $func"
            fi
        done
    else
        log_fail "Key generation script not found"
    fi
}

# Test recovery infrastructure script
test_recovery_script() {
    log_test "Testing recovery infrastructure script (syntax check)..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local recovery_script="$script_dir/create-recovery-infrastructure.sh"
    
    if [ -f "$recovery_script" ]; then
        # Test script syntax
        if bash -n "$recovery_script"; then
            log_pass "Recovery infrastructure script syntax is valid"
        else
            log_fail "Recovery infrastructure script has syntax errors"
        fi
        
        # Check for required functions
        local required_functions=(
            "setup_recovery_directories"
            "create_recovery_kernel_config"
            "create_recovery_boot_script"
            "create_grub_recovery_config"
        )
        
        for func in "${required_functions[@]}"; do
            if grep -q "^$func()" "$recovery_script"; then
                log_pass "Function exists: $func"
            else
                log_fail "Function missing: $func"
            fi
        done
    else
        log_fail "Recovery infrastructure script not found"
    fi
}

# Test key manager utility
test_key_manager() {
    log_test "Testing key manager utility..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local key_manager="$script_dir/key-manager.sh"
    
    if [ -f "$key_manager" ]; then
        # Test script syntax
        if bash -n "$key_manager"; then
            log_pass "Key manager script syntax is valid"
        else
            log_fail "Key manager script has syntax errors"
        fi
        
        # Test help command
        if "$key_manager" --help &> /dev/null; then
            log_pass "Key manager help command works"
        else
            log_fail "Key manager help command failed"
        fi
        
        # Check for required commands
        local required_commands=(
            "cmd_generate"
            "cmd_status"
            "cmd_backup"
            "cmd_restore"
            "cmd_enroll"
        )
        
        for cmd in "${required_commands[@]}"; do
            if grep -q "^$cmd()" "$key_manager"; then
                log_pass "Command function exists: $cmd"
            else
                log_fail "Command function missing: $cmd"
            fi
        done
    else
        log_fail "Key manager script not found"
    fi
}

# Test PowerShell key manager
test_powershell_key_manager() {
    log_test "Testing PowerShell key manager..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local ps_manager="$script_dir/key-manager.ps1"
    
    if [ -f "$ps_manager" ]; then
        log_pass "PowerShell key manager exists"
        
        # Check for required functions
        local required_functions=(
            "Invoke-Generate"
            "Show-Status"
            "Invoke-Backup"
            "Invoke-Restore"
        )
        
        for func in "${required_functions[@]}"; do
            if grep -q "function $func" "$ps_manager"; then
                log_pass "PowerShell function exists: $func"
            else
                log_fail "PowerShell function missing: $func"
            fi
        done
    else
        log_fail "PowerShell key manager not found"
    fi
}

# Test security configurations
test_security_configs() {
    log_test "Testing security configurations in scripts..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check for secure permissions in key generation script
    if grep -q "chmod 600" "$script_dir/generate-dev-keys.sh"; then
        log_pass "Key generation script sets secure file permissions (600)"
    else
        log_fail "Key generation script missing secure file permissions"
    fi
    
    if grep -q "chmod 700" "$script_dir/generate-dev-keys.sh"; then
        log_pass "Key generation script sets secure directory permissions (700)"
    else
        log_fail "Key generation script missing secure directory permissions"
    fi
    
    # Check for development warnings
    if grep -q "DEVELOPMENT.*NOT.*PRODUCTION" "$script_dir/generate-dev-keys.sh"; then
        log_pass "Key generation script includes development warnings"
    else
        log_fail "Key generation script missing development warnings"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Task 2 Implementation Tests        ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    test_directory_structure
    echo ""
    
    test_script_files
    echo ""
    
    test_documentation
    echo ""
    
    test_key_generation_dryrun
    echo ""
    
    test_recovery_script
    echo ""
    
    test_key_manager
    echo ""
    
    test_powershell_key_manager
    echo ""
    
    test_security_configs
    echo ""
    
    # Summary
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}           Test Summary                 ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed! Task 2 implementation is ready.${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed. Please review the implementation.${NC}"
        exit 1
    fi
}

# Run tests
main "$@"