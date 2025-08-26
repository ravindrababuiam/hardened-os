#!/bin/bash
# Validation script for Task 18: HSM-based signing infrastructure
# Tests all components of the production HSM infrastructure

set -euo pipefail

# Test configuration
TEST_TOKEN="HardenedOS-Dev"
TEST_PIN="1234"
PROD_TOKEN="HardenedOS-Prod"
HSM_CONFIG_DIR="/etc/hardened-os/hsm"
SIGNING_DIR="/opt/signing-infrastructure"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

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
    FAILED_TESTS+=("$1")
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

test_hsm_infrastructure_setup() {
    log_test "Testing HSM infrastructure setup..."
    
    # Test 1: Check if HSM directories exist
    if [[ -d "$HSM_CONFIG_DIR" && -d "$SIGNING_DIR" ]]; then
        log_pass "HSM directories created"
    else
        log_fail "HSM directories missing"
        return 1
    fi
    
    # Test 2: Check configuration files
    local config_files=(
        "$HSM_CONFIG_DIR/pkcs11.conf"
        "$HSM_CONFIG_DIR/signing-policy.yaml"
        "$HSM_CONFIG_DIR/softhsm2.conf"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_pass "Configuration file exists: $(basename "$config_file")"
        else
            log_fail "Configuration file missing: $config_file"
        fi
    done
    
    # Test 3: Check script permissions
    local scripts=(
        "$SIGNING_DIR/scripts/hsm-sign.sh"
        "$SIGNING_DIR/scripts/hsm-key-manager.sh"
        "$SIGNING_DIR/scripts/test-hsm-infrastructure.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            log_pass "Script executable: $(basename "$script")"
        else
            log_fail "Script not executable: $script"
        fi
    done
}

test_softhsm_setup() {
    log_test "Testing SoftHSM development setup..."
    
    # Set SoftHSM configuration
    export SOFTHSM2_CONF="$HSM_CONFIG_DIR/softhsm2.conf"
    
    # Test 1: Check if SoftHSM is installed
    if command -v softhsm2-util &> /dev/null; then
        log_pass "SoftHSM2 installed"
    else
        log_fail "SoftHSM2 not installed"
        return 1
    fi
    
    # Test 2: Check if development token exists
    if softhsm2-util --show-slots | grep -q "$TEST_TOKEN"; then
        log_pass "Development token exists"
    else
        log_fail "Development token not found"
        return 1
    fi
    
    # Test 3: Test token access
    if pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --token-label "$TEST_TOKEN" --pin "$TEST_PIN" --list-objects &> /dev/null; then
        log_pass "Token access successful"
    else
        log_fail "Cannot access development token"
    fi
}

test_key_management() {
    log_test "Testing HSM key management..."
    
    local test_key_id="98"
    local key_manager="$SIGNING_DIR/scripts/hsm-key-manager.sh"
    
    # Test 1: Generate test key
    if "$key_manager" generate-key "$TEST_TOKEN" "$TEST_PIN" "$test_key_id" 2048 &> /dev/null; then
        log_pass "Key generation successful"
    else
        log_fail "Key generation failed"
        return 1
    fi
    
    # Test 2: List keys
    if "$key_manager" list-keys "$TEST_TOKEN" "$TEST_PIN" | grep -q "$test_key_id"; then
        log_pass "Key listing successful"
    else
        log_fail "Generated key not found in listing"
    fi
    
    # Test 3: Backup key
    local backup_file="/tmp/test-key-backup-$$"
    if "$key_manager" backup-key "$TEST_TOKEN" "$TEST_PIN" "$test_key_id" "$backup_file" &> /dev/null; then
        log_pass "Key backup successful"
        rm -f "${backup_file}.pub" 2>/dev/null || true
    else
        log_fail "Key backup failed"
    fi
    
    # Cleanup test key
    pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
        --token-label "$TEST_TOKEN" \
        --pin "$TEST_PIN" \
        --id "$test_key_id" \
        --delete-object \
        --type privkey &> /dev/null || true
}

test_signing_operations() {
    log_test "Testing HSM signing operations..."
    
    local test_key_id="97"
    local test_file="/tmp/test-signing-$$"
    local sig_file="${test_file}.sig"
    local key_manager="$SIGNING_DIR/scripts/hsm-key-manager.sh"
    local signer="$SIGNING_DIR/scripts/hsm-sign.sh"
    
    # Generate test key
    "$key_manager" generate-key "$TEST_TOKEN" "$TEST_PIN" "$test_key_id" 2048 &> /dev/null
    
    # Create test file
    echo "Test data for HSM signing validation" > "$test_file"
    
    # Test 1: Sign file
    if "$signer" -t "$TEST_TOKEN" -p "$TEST_PIN" -k "$test_key_id" -o "$sig_file" "$test_file" &> /dev/null; then
        log_pass "File signing successful"
    else
        log_fail "File signing failed"
        cleanup_signing_test "$test_key_id" "$test_file" "$sig_file"
        return 1
    fi
    
    # Test 2: Verify signature exists
    if [[ -f "$sig_file" ]]; then
        log_pass "Signature file created"
    else
        log_fail "Signature file not created"
    fi
    
    # Test 3: Extract public key and verify signature
    local pubkey_file="/tmp/test-pubkey-$$.pem"
    pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
        --token-label "$TEST_TOKEN" \
        --pin "$TEST_PIN" \
        --id "$test_key_id" \
        --read-object \
        --type pubkey \
        --output-file "${pubkey_file}.der" &> /dev/null
    
    openssl rsa -pubin -inform DER -in "${pubkey_file}.der" -outform PEM -out "$pubkey_file" &> /dev/null
    
    if openssl dgst -sha256 -verify "$pubkey_file" -signature "$sig_file" "$test_file" &> /dev/null; then
        log_pass "Signature verification successful"
    else
        log_fail "Signature verification failed"
    fi
    
    cleanup_signing_test "$test_key_id" "$test_file" "$sig_file" "$pubkey_file"
}

cleanup_signing_test() {
    local key_id="$1"
    local test_file="$2"
    local sig_file="$3"
    local pubkey_file="${4:-}"
    
    # Remove test key
    pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
        --token-label "$TEST_TOKEN" \
        --pin "$TEST_PIN" \
        --id "$key_id" \
        --delete-object \
        --type privkey &> /dev/null || true
    
    # Remove test files
    rm -f "$test_file" "$sig_file" "${pubkey_file}"* 2>/dev/null || true
}

test_audit_logging() {
    log_test "Testing HSM audit logging..."
    
    # Test 1: Check if audit log directory exists
    if [[ -d "/var/log/hsm" ]]; then
        log_pass "HSM audit log directory exists"
    else
        log_fail "HSM audit log directory missing"
    fi
    
    # Test 2: Check rsyslog configuration
    if [[ -f "/etc/rsyslog.d/50-hsm-audit.conf" ]]; then
        log_pass "HSM audit logging configuration exists"
    else
        log_fail "HSM audit logging configuration missing"
    fi
    
    # Test 3: Check logrotate configuration
    if [[ -f "/etc/logrotate.d/hsm-audit" ]]; then
        log_pass "HSM log rotation configuration exists"
    else
        log_fail "HSM log rotation configuration missing"
    fi
    
    # Test 4: Check if audit logs are being written
    local audit_log="/var/log/hsm-signing.log"
    if [[ -f "$audit_log" ]]; then
        log_pass "HSM signing audit log exists"
        
        # Check if recent entries exist
        if [[ -s "$audit_log" ]]; then
            log_pass "HSM audit log contains entries"
        else
            log_warn "HSM audit log is empty (may be normal for new installation)"
        fi
    else
        log_warn "HSM signing audit log not yet created (normal for new installation)"
    fi
}

test_key_rotation_infrastructure() {
    log_test "Testing key rotation infrastructure..."
    
    # Test 1: Check if key rotation script exists
    local rotation_script="scripts/production-key-rotation.sh"
    if [[ -x "$rotation_script" ]]; then
        log_pass "Key rotation script exists and is executable"
    else
        log_fail "Key rotation script missing or not executable"
    fi
    
    # Test 2: Check backup directory structure
    local backup_dir="/secure-backup/keys"
    if mkdir -p "$backup_dir" 2>/dev/null; then
        log_pass "Key backup directory can be created"
        rmdir "$backup_dir" 2>/dev/null || true
    else
        log_warn "Cannot create key backup directory (may require manual setup)"
    fi
    
    # Test 3: Test rotation check (dry run)
    if bash -n "$rotation_script" 2>/dev/null; then
        log_pass "Key rotation script syntax is valid"
    else
        log_fail "Key rotation script has syntax errors"
    fi
}

test_air_gap_procedures() {
    log_test "Testing air-gap signing procedures..."
    
    # Test 1: Check if air-gap documentation exists
    local air_gap_doc="$SIGNING_DIR/air-gap-signing-procedure.md"
    if [[ -f "$air_gap_doc" ]]; then
        log_pass "Air-gap signing procedure documentation exists"
    else
        log_fail "Air-gap signing procedure documentation missing"
    fi
    
    # Test 2: Check incident response documentation
    local incident_doc="$SIGNING_DIR/incident-response.md"
    if [[ -f "$incident_doc" ]]; then
        log_pass "Incident response documentation exists"
    else
        log_fail "Incident response documentation missing"
    fi
    
    # Test 3: Check if signing scripts support air-gap mode
    local signer="$SIGNING_DIR/scripts/hsm-sign.sh"
    if grep -q "audit_log" "$signer"; then
        log_pass "Signing script includes audit logging"
    else
        log_fail "Signing script missing audit logging"
    fi
}

test_production_readiness() {
    log_test "Testing production readiness..."
    
    # Test 1: Check for development vs production separation
    if grep -q "softhsm" "$HSM_CONFIG_DIR/pkcs11.conf"; then
        log_warn "Configuration includes SoftHSM (development mode)"
    else
        log_pass "Configuration ready for production HSM"
    fi
    
    # Test 2: Check security of configuration files
    local config_perms=$(stat -c "%a" "$HSM_CONFIG_DIR/pkcs11.conf" 2>/dev/null || echo "000")
    if [[ "$config_perms" == "600" ]]; then
        log_pass "HSM configuration has secure permissions"
    else
        log_fail "HSM configuration permissions too permissive: $config_perms"
    fi
    
    # Test 3: Check for required documentation
    local required_docs=(
        "$SIGNING_DIR/air-gap-signing-procedure.md"
        "$SIGNING_DIR/incident-response.md"
    )
    
    for doc in "${required_docs[@]}"; do
        if [[ -f "$doc" && -s "$doc" ]]; then
            log_pass "Required documentation exists: $(basename "$doc")"
        else
            log_fail "Required documentation missing or empty: $(basename "$doc")"
        fi
    done
}

run_comprehensive_test() {
    log_test "Running comprehensive HSM infrastructure test..."
    
    # Use the built-in test script if available
    local test_script="$SIGNING_DIR/scripts/test-hsm-infrastructure.sh"
    if [[ -x "$test_script" ]]; then
        if "$test_script" &> /dev/null; then
            log_pass "Comprehensive HSM test passed"
        else
            log_fail "Comprehensive HSM test failed"
        fi
    else
        log_warn "Comprehensive test script not available"
    fi
}

print_summary() {
    echo
    echo "=================================="
    echo "HSM Infrastructure Validation Summary"
    echo "=================================="
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo
        echo -e "${RED}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo
        echo -e "${YELLOW}Recommendations:${NC}"
        echo "1. Run 'sudo scripts/setup-hsm-infrastructure.sh' to fix setup issues"
        echo "2. Check HSM device connectivity and configuration"
        echo "3. Verify all required packages are installed"
        echo "4. Review audit logs for detailed error information"
        return 1
    else
        echo
        echo -e "${GREEN}All tests passed! HSM infrastructure is ready.${NC}"
        echo
        echo "Next steps for production deployment:"
        echo "1. Configure production HSM device"
        echo "2. Generate production key hierarchy"
        echo "3. Set up air-gapped signing workstation"
        echo "4. Test key rotation procedures"
        echo "5. Train personnel on signing procedures"
        return 0
    fi
}

main() {
    echo "HSM Infrastructure Validation - Task 18"
    echo "======================================="
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_warn "Running as non-root user. Some tests may fail."
        echo
    fi
    
    # Run all test suites
    test_hsm_infrastructure_setup
    test_softhsm_setup
    test_key_management
    test_signing_operations
    test_audit_logging
    test_key_rotation_infrastructure
    test_air_gap_procedures
    test_production_readiness
    run_comprehensive_test
    
    # Print summary and exit with appropriate code
    print_summary
}

main "$@"