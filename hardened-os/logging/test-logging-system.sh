#!/bin/bash
# Test script for the tamper-evident logging system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS=()

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TEST_RESULTS+=("PASS: $1")
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TEST_RESULTS+=("FAIL: $1")
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

test_file_structure() {
    log_test "Testing file structure..."
    
    local required_files=(
        "install-logging-system.sh"
        "setup-journal-signing.sh"
        "systemd-journal-sign.service"
        "journal-upload.conf"
        "audit-rules.conf"
        "log-server-config.py"
        "README.md"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_pass "All required files present"
    else
        log_fail "Missing files: ${missing_files[*]}"
    fi
}

test_script_syntax() {
    log_test "Testing script syntax..."
    
    local scripts=(
        "install-logging-system.sh"
        "setup-journal-signing.sh"
        "test-logging-system.sh"
    )
    
    local syntax_errors=()
    
    for script in "${scripts[@]}"; do
        if ! bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
            syntax_errors+=("$script")
        fi
    done
    
    if [[ ${#syntax_errors[@]} -eq 0 ]]; then
        log_pass "All scripts have valid syntax"
    else
        log_fail "Syntax errors in: ${syntax_errors[*]}"
    fi
}

test_python_syntax() {
    log_test "Testing Python script syntax..."
    
    if command -v python3 >/dev/null 2>&1; then
        if python3 -m py_compile "$SCRIPT_DIR/log-server-config.py" 2>/dev/null; then
            log_pass "Python script syntax is valid"
        else
            log_fail "Python script has syntax errors"
        fi
    else
        log_info "Python3 not available, skipping syntax check"
    fi
}

test_systemd_service_syntax() {
    log_test "Testing systemd service file syntax..."
    
    # Basic validation of systemd service file structure
    local service_file="$SCRIPT_DIR/systemd-journal-sign.service"
    
    if grep -q "^\[Unit\]" "$service_file" && \
       grep -q "^\[Service\]" "$service_file" && \
       grep -q "^\[Install\]" "$service_file" && \
       grep -q "^ExecStart=" "$service_file"; then
        log_pass "Systemd service file structure is valid"
    else
        log_fail "Systemd service file structure is invalid"
    fi
}

test_audit_rules_syntax() {
    log_test "Testing audit rules syntax..."
    
    # Check if audit rules file contains expected rule types
    local rule_types=(
        "-D"     # Delete rules
        "-b"     # Buffer size
        "-f"     # Failure mode
        "-w"     # Watch rules
        "-a"     # Append rules
        "-e"     # Enable rules
    )
    
    local found_rules=0
    
    for rule_type in "${rule_types[@]}"; do
        if grep -q "^$rule_type " "$SCRIPT_DIR/audit-rules.conf"; then
            ((found_rules++))
        fi
    done
    
    if [[ $found_rules -ge 4 ]]; then
        log_pass "Audit rules contain expected rule types"
    else
        log_fail "Audit rules missing expected rule types (found: $found_rules/6)"
    fi
}

test_configuration_files() {
    log_test "Testing configuration file formats..."
    
    # Test journal upload configuration
    if grep -q "^\[Upload\]" "$SCRIPT_DIR/journal-upload.conf"; then
        log_pass "Journal upload configuration format is valid"
    else
        log_fail "Journal upload configuration format is invalid"
    fi
}

test_security_features() {
    log_test "Testing security feature coverage..."
    
    local security_checks=(
        "cryptographic signing"
        "integrity verification"
        "tamper detection"
        "secure remote forwarding"
        "audit rules"
        "monitoring"
    )
    
    local missing_features=()
    
    # Check if README mentions all security features
    for feature in "${security_checks[@]}"; do
        if ! grep -qi "$feature" "$SCRIPT_DIR/README.md"; then
            missing_features+=("$feature")
        fi
    done
    
    if [[ ${#missing_features[@]} -eq 0 ]]; then
        log_pass "All security features documented"
    else
        log_fail "Missing security features in documentation: ${missing_features[*]}"
    fi
}

test_requirements_coverage() {
    log_test "Testing requirements coverage..."
    
    local requirements=(
        "14.1"  # Cryptographically signed logs
        "14.2"  # Security event logging
        "14.3"  # Secure remote storage
        "14.5"  # Tamper detection
    )
    
    local missing_requirements=()
    
    for req in "${requirements[@]}"; do
        if ! grep -q "$req" "$SCRIPT_DIR/README.md"; then
            missing_requirements+=("$req")
        fi
    done
    
    if [[ ${#missing_requirements[@]} -eq 0 ]]; then
        log_pass "All requirements covered in documentation"
    else
        log_fail "Missing requirements coverage: ${missing_requirements[*]}"
    fi
}

test_installation_completeness() {
    log_test "Testing installation script completeness..."
    
    local installation_steps=(
        "check_requirements"
        "install_logging_components"
        "configure_log_server"
        "setup_log_rotation"
        "create_monitoring_scripts"
        "start_services"
        "verify_installation"
    )
    
    local missing_steps=()
    
    for step in "${installation_steps[@]}"; do
        if ! grep -q "$step" "$SCRIPT_DIR/install-logging-system.sh"; then
            missing_steps+=("$step")
        fi
    done
    
    if [[ ${#missing_steps[@]} -eq 0 ]]; then
        log_pass "Installation script is complete"
    else
        log_fail "Missing installation steps: ${missing_steps[*]}"
    fi
}

print_test_summary() {
    echo ""
    echo "=================================="
    echo "Test Summary"
    echo "=================================="
    
    local pass_count=0
    local fail_count=0
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
        if [[ "$result" =~ ^PASS ]]; then
            ((pass_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    echo "Total Tests: $((pass_count + fail_count))"
    echo -e "${GREEN}Passed: $pass_count${NC}"
    echo -e "${RED}Failed: $fail_count${NC}"
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! Logging system implementation is ready.${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed. Please review and fix the issues.${NC}"
        return 1
    fi
}

main() {
    echo "Testing Tamper-Evident Logging System Implementation"
    echo "===================================================="
    echo ""
    
    test_file_structure
    test_script_syntax
    test_python_syntax
    test_systemd_service_syntax
    test_audit_rules_syntax
    test_configuration_files
    test_security_features
    test_requirements_coverage
    test_installation_completeness
    
    print_test_summary
}

main "$@"