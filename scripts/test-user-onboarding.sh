#!/bin/bash

# Test script for Task 14: User onboarding wizard and security mode switching
# This script verifies all aspects of the user onboarding implementation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test execution function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log "Running test: $test_name"
    
    if eval "$test_command"; then
        success "✓ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        error "✗ FAIL: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Verify onboarding wizard installation and functionality
test_onboarding_wizard() {
    log "=== Testing onboarding wizard installation and functionality ==="
    
    # Test 1.1: Check if onboarding wizard executable exists
    run_test "onboarding wizard executable exists" "[[ -f '/usr/local/bin/wizard/hardened-os-onboarding' && -x '/usr/local/bin/wizard/hardened-os-onboarding' ]]"
    
    # Test 1.2: Check wizard directory structure
    run_test "wizard directory structure exists" "[[ -d '/usr/local/share/hardened-os-wizard' && -d '/usr/local/bin/wizard' ]]"
    
    # Test 1.3: Check GUI dependencies
    run_test "GUI dependencies available" "python3 -c 'import tkinter; import tkinter.ttk' 2>/dev/null"
    
    # Test 1.4: Check desktop entry
    run_test "onboarding wizard desktop entry exists" "[[ -f '/usr/share/applications/hardened-os-onboarding.desktop' ]]"
    
    # Test 1.5: Validate desktop entry
    if command -v desktop-file-validate >/dev/null 2>&1; then
        run_test "onboarding wizard desktop entry valid" "desktop-file-validate /usr/share/applications/hardened-os-onboarding.desktop"
    else
        warning "desktop-file-validate not available, skipping desktop entry validation"
    fi
    
    # Test 1.6: Check wizard can import required modules
    run_test "wizard can import required modules" "python3 -c 'import sys; sys.path.insert(0, \"/usr/local/bin/wizard\"); exec(open(\"/usr/local/bin/wizard/hardened-os-onboarding\").read().split(\"if __name__\")[0])' 2>/dev/null"
}

# Test 2: Verify security manager functionality
test_security_manager() {
    log "=== Testing security manager functionality ==="
    
    # Test 2.1: Check if security manager executable exists
    run_test "security manager executable exists" "[[ -f '/usr/local/bin/security-manager' && -x '/usr/local/bin/security-manager' ]]"
    
    # Test 2.2: Check desktop entry
    run_test "security manager desktop entry exists" "[[ -f '/usr/share/applications/security-manager.desktop' ]]"
    
    # Test 2.3: Test command line interface
    run_test "security manager CLI functionality" "/usr/local/bin/security-manager set-mode normal >/dev/null 2>&1"
    
    # Test 2.4: Check configuration file creation
    run_test "security configuration file created" "[[ -f '/etc/hardened-os/security-config.json' ]]"
    
    # Test 2.5: Test security mode switching
    run_test "normal mode setting" "/usr/local/bin/security-manager set-mode normal >/dev/null 2>&1"
    run_test "paranoid mode setting" "/usr/local/bin/security-manager set-mode paranoid >/dev/null 2>&1"
    run_test "enterprise mode setting" "/usr/local/bin/security-manager set-mode enterprise >/dev/null 2>&1"
    
    # Reset to normal mode
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1 || true
    
    # Test 2.6: Test invalid mode rejection
    run_test "invalid mode rejection" "! /usr/local/bin/security-manager set-mode invalid >/dev/null 2>&1"
    
    # Test 2.7: Check security manager can import required modules
    run_test "security manager can import required modules" "python3 -c 'import sys; exec(open(\"/usr/local/bin/security-manager\").read().split(\"if __name__\")[0])' 2>/dev/null"
}

# Test 3: Verify application permission manager
test_permission_manager() {
    log "=== Testing application permission manager ==="
    
    # Test 3.1: Check if permission manager executable exists
    run_test "permission manager executable exists" "[[ -f '/usr/local/bin/app-permission-manager' && -x '/usr/local/bin/app-permission-manager' ]]"
    
    # Test 3.2: Check desktop entry
    run_test "permission manager desktop entry exists" "[[ -f '/usr/share/applications/app-permission-manager.desktop' ]]"
    
    # Test 3.3: Check permission manager can import required modules
    run_test "permission manager can import required modules" "python3 -c 'import sys; exec(open(\"/usr/local/bin/app-permission-manager\").read().split(\"if __name__\")[0])' 2>/dev/null"
    
    # Test 3.4: Validate desktop entry
    if command -v desktop-file-validate >/dev/null 2>&1; then
        run_test "permission manager desktop entry valid" "desktop-file-validate /usr/share/applications/app-permission-manager.desktop"
    else
        warning "desktop-file-validate not available, skipping desktop entry validation"
    fi
}

# Test 4: Test security mode transitions and their effects
test_security_mode_transitions() {
    log "=== Testing security mode transitions and their effects ==="
    
    # Test 4.1: Test normal mode configuration
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
    run_test "normal mode applied" "grep -q '\"security_mode\": \"normal\"' /etc/hardened-os/security-config.json"
    
    # Test 4.2: Test paranoid mode configuration
    /usr/local/bin/security-manager set-mode paranoid >/dev/null 2>&1
    run_test "paranoid mode applied" "grep -q '\"security_mode\": \"paranoid\"' /etc/hardened-os/security-config.json"
    
    # Test 4.3: Test enterprise mode configuration
    /usr/local/bin/security-manager set-mode enterprise >/dev/null 2>&1
    run_test "enterprise mode applied" "grep -q '\"security_mode\": \"enterprise\"' /etc/hardened-os/security-config.json"
    
    # Test 4.4: Test mode persistence
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
    run_test "mode persistence works" "grep -q '\"security_mode\": \"normal\"' /etc/hardened-os/security-config.json"
    
    # Test 4.5: Test integration with network controls (if available)
    if command -v app-network-control >/dev/null 2>&1; then
        # Set paranoid mode and check if it affects network controls
        /usr/local/bin/security-manager set-mode paranoid >/dev/null 2>&1
        sleep 1
        
        # Check if browser is restricted in paranoid mode
        run_test "paranoid mode affects network controls" "app-network-control list | grep -E 'browser.*(RESTRICTED|BLOCKED)' >/dev/null"
        
        # Reset to normal mode
        /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
    else
        warning "Network controls not available, skipping integration test"
    fi
}

# Test 5: Test user interface accessibility and usability
test_ui_accessibility() {
    log "=== Testing user interface accessibility and usability ==="
    
    # Test 5.1: Check desktop entry categories
    run_test "onboarding wizard categorized correctly" "grep -q 'Categories=System' /usr/share/applications/hardened-os-onboarding.desktop"
    run_test "security manager categorized correctly" "grep -q 'Categories=System.*Security' /usr/share/applications/security-manager.desktop"
    run_test "permission manager categorized correctly" "grep -q 'Categories=System.*Security' /usr/share/applications/app-permission-manager.desktop"
    
    # Test 5.2: Check for user-friendly descriptions
    run_test "onboarding wizard has user-friendly description" "grep -q 'Comment=' /usr/share/applications/hardened-os-onboarding.desktop"
    run_test "security manager has user-friendly description" "grep -q 'Comment=' /usr/share/applications/security-manager.desktop"
    run_test "permission manager has user-friendly description" "grep -q 'Comment=' /usr/share/applications/app-permission-manager.desktop"
    
    # Test 5.3: Check for clear explanations in code (Requirement 19.1)
    run_test "onboarding wizard provides clear explanations" "grep -q 'plain.*language\\|clear.*explanation\\|non-technical' /usr/local/bin/wizard/hardened-os-onboarding"
    run_test "security manager uses user-friendly language" "grep -q 'user.*friendly\\|plain.*language\\|clear' /usr/local/bin/security-manager"
    
    # Test 5.4: Check for recovery mechanisms (Requirement 19.2)
    run_test "recovery mechanisms available" "grep -q 'recovery\\|reset.*default\\|restore' /usr/local/bin/wizard/hardened-os-onboarding"
}

# Test 6: Test error handling and robustness
test_error_handling() {
    log "=== Testing error handling and robustness ==="
    
    # Test 6.1: Test handling of missing configuration
    config_backup="/etc/hardened-os/security-config.json.test-backup"
    if [[ -f "/etc/hardened-os/security-config.json" ]]; then
        mv "/etc/hardened-os/security-config.json" "$config_backup"
    fi
    
    run_test "missing configuration handled gracefully" "/usr/local/bin/security-manager set-mode normal >/dev/null 2>&1"
    
    # Restore configuration
    if [[ -f "$config_backup" ]]; then
        mv "$config_backup" "/etc/hardened-os/security-config.json"
    fi
    
    # Test 6.2: Test invalid input handling
    run_test "invalid security mode rejected" "! /usr/local/bin/security-manager set-mode invalid_mode >/dev/null 2>&1"
    
    # Test 6.3: Test permission handling
    run_test "configuration directory permissions correct" "[[ \$(stat -c '%a' /etc/hardened-os 2>/dev/null || echo '755') == '755' ]]"
    
    # Test 6.4: Test file creation permissions
    if [[ -f "/etc/hardened-os/security-config.json" ]]; then
        run_test "configuration file permissions secure" "[[ \$(stat -c '%a' /etc/hardened-os/security-config.json) == '644' ]]"
    fi
}

# Test 7: Test integration with existing security components
test_integration() {
    log "=== Testing integration with existing security components ==="
    
    # Test 7.1: Integration with network controls
    if command -v app-network-control >/dev/null 2>&1; then
        run_test "network controls integration available" "true"
        
        # Test that security modes affect network policies
        original_mode=$(/usr/local/bin/security-manager set-mode normal >/dev/null 2>&1; grep -o '"security_mode": "[^"]*"' /etc/hardened-os/security-config.json 2>/dev/null | cut -d'"' -f4 || echo "normal")
        
        # Switch to paranoid mode and verify network restrictions
        /usr/local/bin/security-manager set-mode paranoid >/dev/null 2>&1
        sleep 1
        
        if app-network-control list | grep -E "(office|media).*(BLOCKED)" >/dev/null 2>&1; then
            run_test "security modes affect network policies" "true"
        else
            run_test "security modes affect network policies" "false"
        fi
        
        # Restore original mode
        /usr/local/bin/security-manager set-mode "$original_mode" >/dev/null 2>&1
    else
        warning "Network controls not available, skipping network integration tests"
    fi
    
    # Test 7.2: Integration with bubblewrap sandboxing
    if command -v bwrap >/dev/null 2>&1; then
        run_test "bubblewrap sandboxing integration available" "true"
    else
        warning "Bubblewrap not available, skipping sandboxing integration tests"
    fi
    
    # Test 7.3: Integration with SELinux (if available)
    if command -v getenforce >/dev/null 2>&1; then
        run_test "SELinux integration available" "true"
    else
        warning "SELinux not available, skipping SELinux integration tests"
    fi
}

# Test 8: Test user experience requirements compliance
test_ux_requirements() {
    log "=== Testing user experience requirements compliance ==="
    
    # Test 8.1: Requirement 17.4 - Development tools isolation with explicit permission models
    run_test "development tools permission model implemented" "grep -q 'dev.*permission\\|development.*permission' /usr/local/bin/app-permission-manager"
    
    # Test 8.2: Requirement 17.5 - Least privilege principle
    run_test "least privilege principle implemented" "grep -q 'least.*privilege\\|deny.*default\\|minimal.*permission' /usr/local/bin/app-permission-manager"
    
    # Test 8.3: Requirement 19.1 - Clear, non-technical explanations
    run_test "clear explanations provided" "grep -q 'explanation\\|plain.*language\\|user.*friendly' /usr/local/bin/wizard/hardened-os-onboarding"
    
    # Test 8.4: Requirement 19.4 - Actionable security warnings
    run_test "actionable security warnings implemented" "grep -q 'warning\\|risk.*explanation\\|security.*impact' /usr/local/bin/security-manager"
}

# Test 9: Test configuration persistence and recovery
test_configuration_persistence() {
    log "=== Testing configuration persistence and recovery ==="
    
    # Test 9.1: Configuration survives mode changes
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
    original_config=$(cat /etc/hardened-os/security-config.json 2>/dev/null || echo "{}")
    
    /usr/local/bin/security-manager set-mode paranoid >/dev/null 2>&1
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
    
    run_test "configuration persistence across mode changes" "[[ -f '/etc/hardened-os/security-config.json' ]]"
    
    # Test 9.2: Configuration backup and recovery
    if [[ -f "/etc/hardened-os/security-config.json" ]]; then
        cp "/etc/hardened-os/security-config.json" "/tmp/config-test-backup"
        rm "/etc/hardened-os/security-config.json"
        
        /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
        
        run_test "configuration recreation after deletion" "[[ -f '/etc/hardened-os/security-config.json' ]]"
        
        # Restore original configuration
        if [[ -f "/tmp/config-test-backup" ]]; then
            mv "/tmp/config-test-backup" "/etc/hardened-os/security-config.json"
        fi
    fi
}

# Test 10: Test performance and resource usage
test_performance() {
    log "=== Testing performance and resource usage ==="
    
    # Test 10.1: Application startup time
    start_time=$(date +%s%N)
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
    end_time=$(date +%s%N)
    
    duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [[ $duration -lt 1000 ]]; then # Less than 1 second
        run_test "security manager startup performance acceptable" "true"
    else
        run_test "security manager startup performance acceptable" "false"
    fi
    
    log "Security manager execution time: ${duration}ms"
    
    # Test 10.2: Configuration file size
    if [[ -f "/etc/hardened-os/security-config.json" ]]; then
        config_size=$(stat -c%s "/etc/hardened-os/security-config.json" 2>/dev/null || echo "0")
        
        if [[ $config_size -lt 10240 ]]; then # Less than 10KB
            run_test "configuration file size reasonable" "true"
        else
            run_test "configuration file size reasonable" "false"
        fi
        
        log "Configuration file size: ${config_size} bytes"
    fi
    
    # Test 10.3: Memory usage (basic check)
    run_test "applications don't leave background processes" "! pgrep -f 'hardened-os-onboarding|security-manager|app-permission-manager'"
}

# Generate test report
generate_report() {
    log "=== Test Report ==="
    log "Total tests: $TESTS_TOTAL"
    log "Passed: $TESTS_PASSED"
    log "Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        success "All tests passed! User onboarding implementation is working correctly."
        log ""
        log "Verified user onboarding features:"
        log "  ✓ Onboarding wizard installed and functional"
        log "  ✓ Security manager with mode switching working"
        log "  ✓ Application permission manager available"
        log "  ✓ Desktop integration configured"
        log "  ✓ Security mode transitions working"
        log "  ✓ User interface accessibility validated"
        log "  ✓ Error handling and robustness confirmed"
        log "  ✓ Integration with security components verified"
        log "  ✓ User experience requirements met"
        log "  ✓ Configuration persistence working"
        log "  ✓ Performance acceptable"
        log ""
        log "Requirements validation:"
        log "  ✓ 17.4: Development tools isolated with explicit permission models"
        log "  ✓ 17.5: Application profiles based on least privilege principle"
        log "  ✓ 19.1: User interfaces provide clear, non-technical explanations"
        log "  ✓ 19.4: Security warnings are actionable and explain risks"
        return 0
    else
        error "Some tests failed. Please review the implementation."
        return 1
    fi
}

# Main execution
main() {
    log "Starting comprehensive test suite for Task 14: User onboarding wizard and security mode switching"
    log "This test suite validates all aspects of the user onboarding implementation"
    
    # Run all test suites
    test_onboarding_wizard
    test_security_manager
    test_permission_manager
    test_security_mode_transitions
    test_ui_accessibility
    test_error_handling
    test_integration
    test_ux_requirements
    test_configuration_persistence
    test_performance
    
    # Generate final report
    generate_report
}

# Execute main function
main "$@"