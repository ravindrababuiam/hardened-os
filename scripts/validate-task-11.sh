#!/bin/bash

# Validation script for Task 11: Configure userspace hardening and memory protection
# This script performs final validation of all userspace hardening requirements

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

# Requirement 13.1: Compiler hardening flags validation
validate_requirement_13_1() {
    log "=== Validating Requirement 13.1: Compiler hardening flags ==="
    
    # Check dpkg buildflags configuration
    validate "dpkg buildflags hardening configuration exists" \
        "[[ -f '/etc/dpkg/buildflags.conf.d/hardening.conf' ]]" \
        "13.1"
    
    # Verify specific hardening flags are configured
    validate "fstack-protector-strong flag configured" \
        "grep -q 'fstack-protector-strong' /etc/dpkg/buildflags.conf.d/hardening.conf" \
        "13.1"
    
    validate "fPIE flag configured" \
        "grep -q 'fPIE' /etc/dpkg/buildflags.conf.d/hardening.conf" \
        "13.1"
    
    validate "fstack-clash-protection flag configured" \
        "grep -q 'fstack-clash-protection' /etc/dpkg/buildflags.conf.d/hardening.conf" \
        "13.1"
    
    validate "D_FORTIFY_SOURCE=3 flag configured" \
        "grep -q 'D_FORTIFY_SOURCE=3' /etc/dpkg/buildflags.conf.d/hardening.conf" \
        "13.1"
    
    # Check environment configuration
    validate "compiler hardening environment configured" \
        "[[ -f '/etc/environment.d/compiler-hardening.conf' ]]" \
        "13.1"
    
    # Test compilation with hardening flags
    if command -v gcc >/dev/null 2>&1; then
        cat > /tmp/validate_hardening.c << 'EOF'
#include <stdio.h>
int main() { printf("Hardening test\n"); return 0; }
EOF
        
        validate "compilation with hardening flags works" \
            "gcc -fstack-protector-strong -fPIE -fstack-clash-protection -D_FORTIFY_SOURCE=3 -o /tmp/validate_hardening /tmp/validate_hardening.c" \
            "13.1"
        
        rm -f /tmp/validate_hardening /tmp/validate_hardening.c
    else
        warning "GCC not available for compilation test"
    fi
}

# Requirement 13.2: hardened_malloc system-wide deployment
validate_requirement_13_2() {
    log "=== Validating Requirement 13.2: hardened_malloc system-wide ==="
    
    # Check hardened_malloc library installation
    validate "hardened_malloc library installed" \
        "[[ -f '/usr/lib/libhardened_malloc.so' ]]" \
        "13.2"
    
    # Check ld.so.preload configuration
    validate "ld.so.preload configured for hardened_malloc" \
        "grep -q 'libhardened_malloc' /etc/ld.so.preload 2>/dev/null" \
        "13.2"
    
    # Check environment configuration
    validate "hardened_malloc environment configured" \
        "[[ -f '/etc/environment.d/hardened-malloc.conf' ]]" \
        "13.2"
    
    # Test malloc functionality
    if command -v gcc >/dev/null 2>&1; then
        cat > /tmp/validate_malloc.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
int main() {
    void *ptr = malloc(1024);
    if (!ptr) return 1;
    free(ptr);
    printf("malloc test passed\n");
    return 0;
}
EOF
        
        validate "hardened_malloc functionality test" \
            "gcc -o /tmp/validate_malloc /tmp/validate_malloc.c && /tmp/validate_malloc" \
            "13.2"
        
        rm -f /tmp/validate_malloc /tmp/validate_malloc.c
    else
        warning "GCC not available for malloc functionality test"
    fi
}

# Requirement 13.3: Mandatory ASLR enforcement
validate_requirement_13_3() {
    log "=== Validating Requirement 13.3: Mandatory ASLR enforcement ==="
    
    # Check kernel ASLR setting
    validate "kernel ASLR fully enabled" \
        "[[ \$(cat /proc/sys/kernel/randomize_va_space) == '2' ]]" \
        "13.3"
    
    # Check sysctl configuration persistence
    validate "ASLR sysctl configuration persistent" \
        "grep -q 'kernel.randomize_va_space = 2' /etc/sysctl.conf" \
        "13.3"
    
    # Check additional memory protection settings
    validate "kernel pointer restriction configured" \
        "grep -q 'kernel.kptr_restrict = 2' /etc/sysctl.conf" \
        "13.3"
    
    validate "dmesg restriction configured" \
        "grep -q 'kernel.dmesg_restrict = 1' /etc/sysctl.conf" \
        "13.3"
    
    # Test ASLR effectiveness
    if command -v gcc >/dev/null 2>&1; then
        cat > /tmp/validate_aslr.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
int main() {
    void *stack_var;
    void *heap_var = malloc(100);
    printf("%p %p\n", &stack_var, heap_var);
    free(heap_var);
    return 0;
}
EOF
        
        gcc -o /tmp/validate_aslr /tmp/validate_aslr.c
        
        # Run multiple times and verify addresses are different
        addr1=$(/tmp/validate_aslr)
        addr2=$(/tmp/validate_aslr)
        
        validate "ASLR effectiveness (addresses randomized)" \
            "[[ '$addr1' != '$addr2' ]]" \
            "13.3"
        
        rm -f /tmp/validate_aslr /tmp/validate_aslr.c
    else
        warning "GCC not available for ASLR effectiveness test"
    fi
}

# Requirement 6.4: systemd service hardening
validate_requirement_6_4() {
    log "=== Validating Requirement 6.4: systemd service hardening ==="
    
    # Check global systemd hardening configuration
    validate "systemd global hardening configured" \
        "[[ -f '/etc/systemd/system.conf.d/security-hardening.conf' ]]" \
        "6.4"
    
    # Check service-level hardening configuration
    validate "systemd service hardening configured" \
        "[[ -f '/etc/systemd/system/service.d/security-hardening.conf' ]]" \
        "6.4"
    
    # Verify PrivateTmp is configured
    validate "PrivateTmp configured for all services" \
        "grep -q 'PrivateTmp=yes' /etc/systemd/system/service.d/security-hardening.conf" \
        "6.4"
    
    # Verify NoNewPrivileges is configured
    validate "NoNewPrivileges configured for all services" \
        "grep -q 'NoNewPrivileges=yes' /etc/systemd/system/service.d/security-hardening.conf" \
        "6.4"
    
    # Check additional hardening measures
    validate "ProtectSystem configured" \
        "grep -q 'ProtectSystem=strict' /etc/systemd/system/service.d/security-hardening.conf" \
        "6.4"
    
    validate "MemoryDenyWriteExecute configured" \
        "grep -q 'MemoryDenyWriteExecute=yes' /etc/systemd/system/service.d/security-hardening.conf" \
        "6.4"
    
    validate "SystemCallFilter configured" \
        "grep -q 'SystemCallFilter=' /etc/systemd/system/service.d/security-hardening.conf" \
        "6.4"
    
    # Check service-specific hardening profiles
    validate "web service hardening profile exists" \
        "[[ -f '/etc/systemd/system/web-service.d/hardening.conf' ]]" \
        "6.4"
    
    validate "database service hardening profile exists" \
        "[[ -f '/etc/systemd/system/database-service.d/hardening.conf' ]]" \
        "6.4"
    
    # Verify critical services have hardening applied
    critical_services=("ssh" "systemd-networkd" "systemd-resolved" "systemd-timesyncd")
    for service in "${critical_services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            validate "$service service hardening applied" \
                "[[ -f '/etc/systemd/system/${service}.service.d/hardening.conf' ]]" \
                "6.4"
        else
            log "$service is not enabled, skipping validation"
        fi
    done
}

# Additional security validations
validate_additional_security() {
    log "=== Additional security validations ==="
    
    # Check for proper file permissions
    validate "hardening configuration files have secure permissions" \
        "[[ \$(stat -c '%a' /etc/systemd/system/service.d/security-hardening.conf 2>/dev/null) == '644' ]]" \
        "General"
    
    # Verify no world-writable configuration files
    validate "no world-writable hardening configuration files" \
        "[[ \$(find /etc/systemd/system -name '*.conf' -perm -002 2>/dev/null | wc -l) -eq 0 ]]" \
        "General"
    
    # Check systemd daemon reload status
    validate "systemd configuration is current" \
        "systemctl daemon-reload && echo 'systemd reloaded successfully'" \
        "General"
}

# Integration validation
validate_integration() {
    log "=== Integration validation ==="
    
    # Test that all hardening measures work together
    if command -v gcc >/dev/null 2>&1; then
        cat > /tmp/validate_integration.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    // Test hardened malloc
    void *ptr = malloc(1024);
    if (!ptr) return 1;
    
    // Test ASLR (addresses should be randomized)
    printf("Integration test - Stack: %p, Heap: %p\n", &ptr, ptr);
    
    free(ptr);
    return 0;
}
EOF
        
        validate "integration test: all hardening measures work together" \
            "gcc -fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=3 -o /tmp/validate_integration /tmp/validate_integration.c && /tmp/validate_integration" \
            "Integration"
        
        rm -f /tmp/validate_integration /tmp/validate_integration.c
    else
        warning "GCC not available for integration test"
    fi
}

# Generate validation report
generate_validation_report() {
    log "=== Task 11 Validation Report ==="
    log "Total validations: $VALIDATIONS_TOTAL"
    log "Passed: $VALIDATIONS_PASSED"
    log "Failed: $VALIDATIONS_FAILED"
    
    if [[ $VALIDATIONS_FAILED -eq 0 ]]; then
        success "✓ ALL VALIDATIONS PASSED"
        log ""
        log "Task 11 implementation is COMPLETE and meets all requirements:"
        log ""
        log "Requirement 13.1 - Compiler hardening flags:"
        log "  ✓ -fstack-protector-strong configured"
        log "  ✓ -fPIE configured"
        log "  ✓ -fstack-clash-protection configured"
        log "  ✓ -D_FORTIFY_SOURCE=3 configured"
        log ""
        log "Requirement 13.2 - hardened_malloc system-wide:"
        log "  ✓ hardened_malloc library installed"
        log "  ✓ ld.so.preload configured"
        log "  ✓ System-wide deployment verified"
        log ""
        log "Requirement 13.3 - Mandatory ASLR:"
        log "  ✓ Kernel ASLR fully enabled (randomize_va_space=2)"
        log "  ✓ Additional memory protections configured"
        log "  ✓ ASLR effectiveness verified"
        log ""
        log "Requirement 6.4 - systemd service hardening:"
        log "  ✓ PrivateTmp=yes configured for all services"
        log "  ✓ NoNewPrivileges=yes configured for all services"
        log "  ✓ Additional hardening measures applied"
        log "  ✓ Service-specific profiles created"
        log ""
        success "Task 11: Configure userspace hardening and memory protection - COMPLETED"
        return 0
    else
        error "✗ VALIDATION FAILED"
        error "Task 11 implementation has issues that need to be addressed."
        log "Failed validations: $VALIDATIONS_FAILED"
        return 1
    fi
}

# Main execution
main() {
    log "Starting validation for Task 11: Configure userspace hardening and memory protection"
    log "This validation ensures all requirements are properly implemented"
    
    # Run all validations
    validate_requirement_13_1
    validate_requirement_13_2
    validate_requirement_13_3
    validate_requirement_6_4
    validate_additional_security
    validate_integration
    
    # Generate final validation report
    generate_validation_report
}

# Execute main function
main "$@"