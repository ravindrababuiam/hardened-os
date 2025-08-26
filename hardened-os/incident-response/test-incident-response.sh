#!/bin/bash
# Test script for the Incident Response and Recovery System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
        "incident-response-framework.sh"
        "recovery-procedures.sh"
        "key-rotation-procedures.sh"
        "install-incident-response.sh"
        "README.md"
        "test-incident-response.sh"
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
        "incident-response-framework.sh"
        "recovery-procedures.sh"
        "key-rotation-procedures.sh"
        "install-incident-response.sh"
        "test-incident-response.sh"
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

test_script_executability() {
    log_test "Testing script executability..."
    
    local scripts=(
        "incident-response-framework.sh"
        "recovery-procedures.sh"
        "key-rotation-procedures.sh"
        "install-incident-response.sh"
    )
    
    local non_executable=()
    
    for script in "${scripts[@]}"; do
        if [[ ! -x "$SCRIPT_DIR/$script" ]]; then
            non_executable+=("$script")
        fi
    done
    
    if [[ ${#non_executable[@]} -eq 0 ]]; then
        log_pass "All scripts are executable"
    else
        log_fail "Non-executable scripts: ${non_executable[*]}"
    fi
}

test_help_functionality() {
    log_test "Testing help functionality..."
    
    local scripts=(
        "incident-response-framework.sh"
        "recovery-procedures.sh"
        "key-rotation-procedures.sh"
    )
    
    local help_failures=()
    
    for script in "${scripts[@]}"; do
        if ! "$SCRIPT_DIR/$script" help >/dev/null 2>&1; then
            help_failures+=("$script")
        fi
    done
    
    if [[ ${#help_failures[@]} -eq 0 ]]; then
        log_pass "All scripts provide help functionality"
    else
        log_fail "Help functionality missing in: ${help_failures[*]}"
    fi
}

test_configuration_templates() {
    log_test "Testing configuration templates..."
    
    # Check if installation script contains configuration templates
    local config_sections=(
        "incident-response.conf"
        "recovery.conf"
        "key-rotation.conf"
    )
    
    local missing_configs=()
    
    for config in "${config_sections[@]}"; do
        if ! grep -q "$config" "$SCRIPT_DIR/install-incident-response.sh"; then
            missing_configs+=("$config")
        fi
    done
    
    if [[ ${#missing_configs[@]} -eq 0 ]]; then
        log_pass "All configuration templates present"
    else
        log_fail "Missing configuration templates: ${missing_configs[*]}"
    fi
}

test_systemd_service_templates() {
    log_test "Testing systemd service templates..."
    
    local services=(
        "hardened-os-monitor.service"
        "hardened-os-monitor.timer"
        "recovery-point-create.service"
        "recovery-point-create.timer"
        "key-expiration-check.service"
        "key-expiration-check.timer"
    )
    
    local missing_services=()
    
    for service in "${services[@]}"; do
        if ! grep -q "$service" "$SCRIPT_DIR/install-incident-response.sh"; then
            missing_services+=("$service")
        fi
    done
    
    if [[ ${#missing_services[@]} -eq 0 ]]; then
        log_pass "All systemd service templates present"
    else
        log_fail "Missing systemd service templates: ${missing_services[*]}"
    fi
}

test_threat_detection_functions() {
    log_test "Testing threat detection functions..."
    
    local detection_functions=(
        "detect_rootkit"
        "detect_intrusion"
        "detect_malware"
    )
    
    local missing_functions=()
    
    for function in "${detection_functions[@]}"; do
        if ! grep -q "$function" "$SCRIPT_DIR/incident-response-framework.sh"; then
            missing_functions+=("$function")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_pass "All threat detection functions present"
    else
        log_fail "Missing threat detection functions: ${missing_functions[*]}"
    fi
}

test_recovery_modes() {
    log_test "Testing recovery modes..."
    
    local recovery_modes=(
        "restore_safe_mode"
        "restore_full_mode"
        "restore_forensic_mode"
    )
    
    local missing_modes=()
    
    for mode in "${recovery_modes[@]}"; do
        if ! grep -q "$mode" "$SCRIPT_DIR/recovery-procedures.sh"; then
            missing_modes+=("$mode")
        fi
    done
    
    if [[ ${#missing_modes[@]} -eq 0 ]]; then
        log_pass "All recovery modes implemented"
    else
        log_fail "Missing recovery modes: ${missing_modes[*]}"
    fi
}

test_key_rotation_types() {
    log_test "Testing key rotation types..."
    
    local key_types=(
        "rotate_secure_boot_keys"
        "rotate_luks_keys"
        "rotate_ssh_host_keys"
        "rotate_tls_certificates"
    )
    
    local missing_types=()
    
    for key_type in "${key_types[@]}"; do
        if ! grep -q "$key_type" "$SCRIPT_DIR/key-rotation-procedures.sh"; then
            missing_types+=("$key_type")
        fi
    done
    
    if [[ ${#missing_types[@]} -eq 0 ]]; then
        log_pass "All key rotation types implemented"
    else
        log_fail "Missing key rotation types: ${missing_types[*]}"
    fi
}

test_emergency_procedures() {
    log_test "Testing emergency procedures..."
    
    local emergency_functions=(
        "emergency_recovery"
        "emergency_key_revocation"
        "contain_threat"
        "create_forensic_snapshot"
    )
    
    local missing_emergency=()
    
    for function in "${emergency_functions[@]}"; do
        local found=false
        for script in incident-response-framework.sh recovery-procedures.sh key-rotation-procedures.sh; do
            if grep -q "$function" "$SCRIPT_DIR/$script"; then
                found=true
                break
            fi
        done
        
        if [[ "$found" != "true" ]]; then
            missing_emergency+=("$function")
        fi
    done
    
    if [[ ${#missing_emergency[@]} -eq 0 ]]; then
        log_pass "All emergency procedures implemented"
    else
        log_fail "Missing emergency procedures: ${missing_emergency[*]}"
    fi
}

test_logging_functionality() {
    log_test "Testing logging functionality..."
    
    local logging_functions=(
        "log_incident"
        "log_recovery"
        "log_key_operation"
    )
    
    local missing_logging=()
    
    for function in "${logging_functions[@]}"; do
        local found=false
        for script in incident-response-framework.sh recovery-procedures.sh key-rotation-procedures.sh; do
            if grep -q "$function" "$SCRIPT_DIR/$script"; then
                found=true
                break
            fi
        done
        
        if [[ "$found" != "true" ]]; then
            missing_logging+=("$function")
        fi
    done
    
    if [[ ${#missing_logging[@]} -eq 0 ]]; then
        log_pass "All logging functions implemented"
    else
        log_fail "Missing logging functions: ${missing_logging[*]}"
    fi
}

test_requirements_coverage() {
    log_test "Testing requirements coverage..."
    
    local requirements=(
        "11.1"  # Incident response procedures
        "11.2"  # Recovery scripts
        "11.3"  # Key rotation procedures
        "11.4"  # Secure logging and audit trails
        "12.3"  # Key rotation without reinstallation
        "12.4"  # Key revocation procedures
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

test_security_features() {
    log_test "Testing security features..."
    
    local security_features=(
        "automated threat detection"
        "threat containment"
        "forensic analysis"
        "system recovery"
        "key management"
        "emergency response"
    )
    
    local missing_features=()
    
    for feature in "${security_features[@]}"; do
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

test_installation_completeness() {
    log_test "Testing installation script completeness..."
    
    local installation_steps=(
        "check_requirements"
        "install_incident_response_framework"
        "create_configuration_files"
        "setup_systemd_services"
        "create_incident_response_tools"
        "setup_log_rotation"
        "start_services"
        "verify_installation"
    )
    
    local missing_steps=()
    
    for step in "${installation_steps[@]}"; do
        if ! grep -q "$step" "$SCRIPT_DIR/install-incident-response.sh"; then
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
        echo -e "${GREEN}All tests passed! Incident Response system implementation is ready.${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed. Please review and fix the issues.${NC}"
        return 1
    fi
}

main() {
    echo "Testing Incident Response and Recovery System Implementation"
    echo "==========================================================="
    echo ""
    
    test_file_structure
    test_script_syntax
    test_script_executability
    test_help_functionality
    test_configuration_templates
    test_systemd_service_templates
    test_threat_detection_functions
    test_recovery_modes
    test_key_rotation_types
    test_emergency_procedures
    test_logging_functionality
    test_requirements_coverage
    test_security_features
    test_installation_completeness
    
    print_test_summary
}

main "$@"