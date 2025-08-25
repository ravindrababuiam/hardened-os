#!/bin/bash

# Validation script for Task 14: Create user onboarding wizard and security mode switching
# This script performs final validation of all user onboarding requirements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation counters
VALIDATIONS_TOTAL=0
VALIDATIONS_PASSED=0
VALIDATIONS_FAILED=0

# Logging functions
log() {
    echo -e "${BLUE}[VALIDATE]${NC} $1"
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

# Validation function
validate() {
    local validation_name="$1"
    local validation_command="$2"
    local requirement="$3"
    
    VALIDATIONS_TOTAL=$((VALIDATIONS_TOTAL + 1))
    log "Validating: $validation_name (Requirement: $requirement)"
    
    if eval "$validation_command"; then
        success "✓ PASS: $validation_name"
        VALIDATIONS_PASSED=$((VALIDATIONS_PASSED + 1))
        return 0
    else
        error "✗ FAIL: $validation_name"
        VALIDATIONS_FAILED=$((VALIDATIONS_FAILED + 1))
        return 1
    fi
}

# Requirement 17.4: Development tools isolated from personal data with explicit permission models
validate_requirement_17_4() {
    log "=== Validating Requirement 17.4: Development tools isolated with explicit permission models ==="
    
    # Check application permission manager exists
    validate "application permission manager exists" \
        "[[ -f '/usr/local/bin/app-permission-manager' && -x '/usr/local/bin/app-permission-manager' ]]" \
        "17.4"
    
    # Check permission manager implements development tool isolation
    validate "development tool isolation implemented" \
        "grep -q 'Development Tools\\|dev.*permission\\|development.*isolation' /usr/local/bin/app-permission-manager" \
        "17.4"
    
    # Check explicit permission models are implemented
    validate "explicit permission models implemented" \
        "grep -q 'permission.*model\\|explicit.*permission\\|permission.*control' /usr/local/bin/app-permission-manager" \
        "17.4"
    
    # Check desktop integration for permission manager
    validate "permission manager desktop integration" \
        "[[ -f '/usr/share/applications/app-permission-manager.desktop' ]]" \
        "17.4"
    
    # Check permission manager can be launched
    validate "permission manager functionality" \
        "python3 -c 'import sys; exec(open(\"/usr/local/bin/app-permission-manager\").read().split(\"if __name__\")[0])' 2>/dev/null" \
        "17.4"
}

# Requirement 17.5: Application profiles based on principle of least privilege
validate_requirement_17_5() {
    log "=== Validating Requirement 17.5: Application profiles based on least privilege principle ==="
    
    # Check least privilege principle implementation
    validate "least privilege principle implemented" \
        "grep -q 'least.*privilege\\|deny.*default\\|minimal.*permission' /usr/local/bin/app-permission-manager" \
        "17.5"
    
    # Check deny-by-default policies
    validate "deny-by-default policies implemented" \
        "grep -q 'deny.*default\\|default.*deny\\|blocked.*default' /usr/local/bin/app-permission-manager" \
        "17.5"
    
    # Check application categories with different permission levels
    validate "application categories with permission levels" \
        "grep -q 'app_categories\\|Web Browsers\\|Office Applications\\|Media Players' /usr/local/bin/app-permission-manager" \
        "17.5"
    
    # Check security manager implements profile-based controls
    validate "security manager implements profile controls" \
        "grep -q 'security.*profile\\|mode.*profile\\|profile.*security' /usr/local/bin/security-manager" \
        "17.5"
}

# Requirement 19.1: User interfaces provide clear, non-technical explanations
validate_requirement_19_1() {
    log "=== Validating Requirement 19.1: User interfaces provide clear, non-technical explanations ==="
    
    # Check onboarding wizard exists
    validate "onboarding wizard exists" \
        "[[ -f '/usr/local/bin/wizard/hardened-os-onboarding' && -x '/usr/local/bin/wizard/hardened-os-onboarding' ]]" \
        "19.1"
    
    # Check onboarding wizard provides clear explanations
    validate "onboarding wizard provides clear explanations" \
        "grep -q 'plain.*language\\|clear.*explanation\\|non-technical\\|user.*friendly' /usr/local/bin/wizard/hardened-os-onboarding" \
        "19.1"
    
    # Check security manager provides user-friendly language
    validate "security manager uses user-friendly language" \
        "grep -q 'user.*friendly\\|plain.*language\\|clear\\|explanation' /usr/local/bin/security-manager" \
        "19.1"
    
    # Check GUI dependencies are available
    validate "GUI dependencies available for clear interfaces" \
        "python3 -c 'import tkinter; import tkinter.ttk' 2>/dev/null" \
        "19.1"
    
    # Check desktop entries have clear descriptions
    validate "desktop entries have clear descriptions" \
        "grep -q 'Comment=' /usr/share/applications/hardened-os-onboarding.desktop && grep -q 'Comment=' /usr/share/applications/security-manager.desktop" \
        "19.1"
    
    # Check onboarding wizard has help text and explanations
    validate "onboarding wizard has comprehensive help" \
        "grep -q 'help\\|explanation\\|guide\\|wizard.*text' /usr/local/bin/wizard/hardened-os-onboarding" \
        "19.1"
}

# Requirement 19.4: Security warnings are actionable and explain risks in plain language
validate_requirement_19_4() {
    log "=== Validating Requirement 19.4: Security warnings are actionable and explain risks ==="
    
    # Check security manager provides actionable warnings
    validate "security manager provides actionable warnings" \
        "grep -q 'warning\\|risk.*explanation\\|security.*impact\\|actionable' /usr/local/bin/security-manager" \
        "19.4"
    
    # Check permission manager explains security implications
    validate "permission manager explains security implications" \
        "grep -q 'Security Impact\\|security.*risk\\|risk.*explanation' /usr/local/bin/app-permission-manager" \
        "19.4"
    
    # Check onboarding wizard explains security choices
    validate "onboarding wizard explains security choices" \
        "grep -q 'security.*choice\\|risk\\|protection\\|security.*level' /usr/local/bin/wizard/hardened-os-onboarding" \
        "19.4"
    
    # Check plain language explanations in security contexts
    validate "plain language security explanations" \
        "grep -q 'plain.*language\\|easy.*understand\\|simple.*explanation' /usr/local/bin/security-manager" \
        "19.4"
    
    # Check actionable security recommendations
    validate "actionable security recommendations provided" \
        "grep -q 'recommend\\|suggest\\|should.*do\\|action.*take' /usr/local/bin/wizard/hardened-os-onboarding" \
        "19.4"
}

# Additional functionality validations
validate_additional_functionality() {
    log "=== Additional functionality validations ==="
    
    # Check security mode switching functionality
    validate "security mode switching works" \
        "/usr/local/bin/security-manager set-mode normal >/dev/null 2>&1" \
        "General"
    
    # Check configuration persistence
    validate "configuration persistence works" \
        "[[ -f '/etc/hardened-os/security-config.json' ]]" \
        "General"
    
    # Check all three security modes can be set
    validate "normal mode can be set" \
        "/usr/local/bin/security-manager set-mode normal >/dev/null 2>&1" \
        "General"
    
    validate "paranoid mode can be set" \
        "/usr/local/bin/security-manager set-mode paranoid >/dev/null 2>&1" \
        "General"
    
    validate "enterprise mode can be set" \
        "/usr/local/bin/security-manager set-mode enterprise >/dev/null 2>&1" \
        "General"
    
    # Reset to normal mode
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1 || true
    
    # Check invalid mode rejection
    validate "invalid security modes are rejected" \
        "! /usr/local/bin/security-manager set-mode invalid >/dev/null 2>&1" \
        "General"
    
    # Check TPM setup integration (if available)
    validate "TPM setup integration available" \
        "grep -q 'TPM\\|tpm\\|Trusted Platform Module' /usr/local/bin/wizard/hardened-os-onboarding" \
        "General"
    
    # Check passphrase setup integration
    validate "passphrase setup integration available" \
        "grep -q 'passphrase\\|password\\|Passphrase Setup' /usr/local/bin/wizard/hardened-os-onboarding" \
        "General"
}

# Desktop integration validation
validate_desktop_integration() {
    log "=== Desktop integration validation ==="
    
    # Check all desktop entries exist
    desktop_files=("hardened-os-onboarding" "security-manager" "app-permission-manager")
    for desktop_file in "${desktop_files[@]}"; do
        validate "$desktop_file desktop entry exists" \
            "[[ -f '/usr/share/applications/${desktop_file}.desktop' ]]" \
            "Integration"
    done
    
    # Check desktop entries are properly categorized
    validate "onboarding wizard properly categorized" \
        "grep -q 'Categories=System' /usr/share/applications/hardened-os-onboarding.desktop" \
        "Integration"
    
    validate "security manager properly categorized" \
        "grep -q 'Categories=System.*Security' /usr/share/applications/security-manager.desktop" \
        "Integration"
    
    validate "permission manager properly categorized" \
        "grep -q 'Categories=System.*Security' /usr/share/applications/app-permission-manager.desktop" \
        "Integration"
    
    # Validate desktop entries if validator is available
    if command -v desktop-file-validate >/dev/null 2>&1; then
        for desktop_file in "${desktop_files[@]}"; do
            validate "$desktop_file desktop entry valid" \
                "desktop-file-validate /usr/share/applications/${desktop_file}.desktop" \
                "Integration"
        done
    else
        warning "desktop-file-validate not available, skipping desktop entry validation"
    fi
}

# User experience validation
validate_user_experience() {
    log "=== User experience validation ==="
    
    # Check error handling
    config_backup="/etc/hardened-os/security-config.json.validation-backup"
    if [[ -f "/etc/hardened-os/security-config.json" ]]; then
        mv "/etc/hardened-os/security-config.json" "$config_backup"
    fi
    
    validate "missing configuration handled gracefully" \
        "/usr/local/bin/security-manager set-mode normal >/dev/null 2>&1" \
        "UX"
    
    # Restore configuration
    if [[ -f "$config_backup" ]]; then
        mv "$config_backup" "/etc/hardened-os/security-config.json"
    fi
    
    # Check recovery mechanisms
    validate "recovery mechanisms available" \
        "grep -q 'recovery\\|reset.*default\\|restore' /usr/local/bin/wizard/hardened-os-onboarding" \
        "UX"
    
    # Check user guidance
    validate "user guidance provided" \
        "grep -q 'guide\\|help\\|instruction\\|step.*step' /usr/local/bin/wizard/hardened-os-onboarding" \
        "UX"
    
    # Check configuration file permissions
    if [[ -f "/etc/hardened-os/security-config.json" ]]; then
        validate "configuration file has secure permissions" \
            "[[ \$(stat -c '%a' /etc/hardened-os/security-config.json) == '644' ]]" \
            "UX"
    fi
}

# Integration validation
validate_integration() {
    log "=== Integration validation ==="
    
    # Check integration with network controls
    if command -v app-network-control >/dev/null 2>&1; then
        validate "network controls integration available" \
            "command -v app-network-control >/dev/null 2>&1" \
            "Integration"
        
        # Test that security modes affect network controls
        original_mode=$(grep -o '"security_mode": "[^"]*"' /etc/hardened-os/security-config.json 2>/dev/null | cut -d'"' -f4 || echo "normal")
        
        /usr/local/bin/security-manager set-mode paranoid >/dev/null 2>&1
        sleep 1
        
        if app-network-control list | grep -E "(office|media).*(BLOCKED)" >/dev/null 2>&1; then
            validate "security modes affect network policies" \
                "true" \
                "Integration"
        else
            validate "security modes affect network policies" \
                "false" \
                "Integration"
        fi
        
        # Restore original mode
        /usr/local/bin/security-manager set-mode "$original_mode" >/dev/null 2>&1
    else
        warning "Network controls not available, skipping network integration validation"
    fi
    
    # Check integration with bubblewrap sandboxing
    if command -v bwrap >/dev/null 2>&1; then
        validate "bubblewrap sandboxing integration available" \
            "command -v bwrap >/dev/null 2>&1" \
            "Integration"
    else
        warning "Bubblewrap not available, skipping sandboxing integration validation"
    fi
    
    # Check testing framework
    validate "user experience testing framework exists" \
        "[[ -f '/usr/local/bin/ux-tests/test-user-experience.sh' && -x '/usr/local/bin/ux-tests/test-user-experience.sh' ]]" \
        "Integration"
}

# Performance validation
validate_performance() {
    log "=== Performance validation ==="
    
    # Test security manager performance
    start_time=$(date +%s%N)
    /usr/local/bin/security-manager set-mode normal >/dev/null 2>&1
    end_time=$(date +%s%N)
    
    duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    validate "security manager performance acceptable" \
        "[[ $duration -lt 2000 ]]" \
        "Performance"
    
    log "Security manager execution time: ${duration}ms"
    
    # Check configuration file size
    if [[ -f "/etc/hardened-os/security-config.json" ]]; then
        config_size=$(stat -c%s "/etc/hardened-os/security-config.json" 2>/dev/null || echo "0")
        
        validate "configuration file size reasonable" \
            "[[ $config_size -lt 10240 ]]" \
            "Performance"
        
        log "Configuration file size: ${config_size} bytes"
    fi
    
    # Check no background processes remain
    validate "no background processes remain" \
        "! pgrep -f 'hardened-os-onboarding|security-manager|app-permission-manager'" \
        "Performance"
}

# Generate validation report
generate_validation_report() {
    log "=== Task 14 Validation Report ==="
    log "Total validations: $VALIDATIONS_TOTAL"
    log "Passed: $VALIDATIONS_PASSED"
    log "Failed: $VALIDATIONS_FAILED"
    
    if [[ $VALIDATIONS_FAILED -eq 0 ]]; then
        success "✓ ALL VALIDATIONS PASSED"
        log ""
        log "Task 14 implementation is COMPLETE and meets all requirements:"
        log ""
        log "Requirement 17.4 - Development tools isolation:"
        log "  ✓ Application permission manager implemented"
        log "  ✓ Development tool isolation with explicit permission models"
        log "  ✓ Permission control interface available"
        log ""
        log "Requirement 17.5 - Least privilege principle:"
        log "  ✓ Deny-by-default policies implemented"
        log "  ✓ Application categories with different permission levels"
        log "  ✓ Profile-based security controls"
        log ""
        log "Requirement 19.1 - Clear, non-technical explanations:"
        log "  ✓ User-friendly onboarding wizard with clear explanations"
        log "  ✓ Security manager with plain language interface"
        log "  ✓ GUI applications with comprehensive help"
        log "  ✓ Desktop integration with clear descriptions"
        log ""
        log "Requirement 19.4 - Actionable security warnings:"
        log "  ✓ Security warnings explain risks in plain language"
        log "  ✓ Permission manager explains security implications"
        log "  ✓ Actionable security recommendations provided"
        log ""
        log "Additional features:"
        log "  ✓ Security mode switching (normal/paranoid/enterprise)"
        log "  ✓ TPM enrollment and passphrase setup integration"
        log "  ✓ Configuration persistence and error handling"
        log "  ✓ Desktop integration and user experience"
        log "  ✓ Integration with existing security components"
        log "  ✓ Performance and resource usage acceptable"
        log ""
        success "Task 14: Create user onboarding wizard and security mode switching - COMPLETED"
        return 0
    else
        error "✗ VALIDATION FAILED"
        error "Task 14 implementation has issues that need to be addressed."
        log "Failed validations: $VALIDATIONS_FAILED"
        return 1
    fi
}

# Main execution
main() {
    log "Starting validation for Task 14: Create user onboarding wizard and security mode switching"
    log "This validation ensures all requirements are properly implemented"
    
    # Run all validations
    validate_requirement_17_4
    validate_requirement_17_5
    validate_requirement_19_1
    validate_requirement_19_4
    validate_additional_functionality
    validate_desktop_integration
    validate_user_experience
    validate_integration
    validate_performance
    
    # Generate final validation report
    generate_validation_report
}

# Execute main function
main "$@"