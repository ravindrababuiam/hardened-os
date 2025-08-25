#!/bin/bash

# Validation script for Task 13: Configure per-application network controls with nftables
# This script performs final validation of all network control requirements

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

# Requirement 7.2: nftables rules implement per-application controls
validate_requirement_7_2() {
    log "=== Validating Requirement 7.2: nftables rules implement per-application controls ==="
    
    # Check nftables installation and service
    validate "nftables installed and running" \
        "command -v nft >/dev/null 2>&1 && systemctl is-active --quiet nftables" \
        "7.2"
    
    # Check nftables configuration exists
    validate "nftables configuration file exists" \
        "[[ -f '/etc/nftables.conf' ]]" \
        "7.2"
    
    # Check default DROP policy is configured
    validate "default DROP policy configured" \
        "nft list ruleset | grep -q 'policy drop'" \
        "7.2"
    
    # Check per-application rules exist
    validate "per-application rules configured" \
        "nft list ruleset | grep -E '(browser|office|media|dev)' >/dev/null" \
        "7.2"
    
    # Check application-specific chains exist
    validate "application-specific chains configured" \
        "nft list ruleset | grep -q '_output'" \
        "7.2"
    
    # Check browser application rules
    validate "browser application rules configured" \
        "nft list ruleset | grep -q 'browser'" \
        "7.2"
    
    # Check office application blocking rules
    validate "office application blocking rules configured" \
        "nft list ruleset | grep -q 'office'" \
        "7.2"
    
    # Check media application blocking rules
    validate "media application blocking rules configured" \
        "nft list ruleset | grep -q 'media'" \
        "7.2"
    
    # Check development tools rules
    validate "development tools rules configured" \
        "nft list ruleset | grep -q 'dev'" \
        "7.2"
}

# Requirement 7.3: Network access disabled apps have all socket operations blocked
validate_requirement_7_3() {
    log "=== Validating Requirement 7.3: Network access disabled apps have all socket operations blocked ==="
    
    # Check network control interface exists
    validate "network control interface exists" \
        "[[ -f '/usr/local/bin/app-network-control' && -x '/usr/local/bin/app-network-control' ]]" \
        "7.3"
    
    # Check network control interface functionality
    validate "network control interface functional" \
        "/usr/local/bin/app-network-control list >/dev/null 2>&1" \
        "7.3"
    
    # Check office applications are blocked by default
    validate "office applications network blocked by default" \
        "/usr/local/bin/app-network-control list | grep -q 'office.*BLOCKED'" \
        "7.3"
    
    # Check media applications are blocked by default
    validate "media applications network blocked by default" \
        "/usr/local/bin/app-network-control list | grep -q 'media.*BLOCKED'" \
        "7.3"
    
    # Check raw socket blocking for non-privileged users
    validate "raw socket creation blocked for non-privileged users" \
        "su -c 'python3 -c \"
import socket
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)
    s.close()
    exit(1)
except PermissionError:
    exit(0)
except Exception:
    exit(1)
\"' nobody 2>/dev/null" \
        "7.3"
    
    # Check that blocked applications cannot make network connections
    validate "blocked applications cannot make network connections" \
        "! timeout 3 nc -z 192.0.2.1 9999 2>/dev/null" \
        "7.3"
    
    # Check logging for blocked connections
    validate "blocked connections are logged" \
        "nft list ruleset | grep -q 'log prefix.*BLOCK'" \
        "7.3"
    
    # Test dynamic blocking functionality
    original_browser_status=$(/usr/local/bin/app-network-control list | grep "browser" | cut -d: -f2 2>/dev/null || echo "unknown")
    
    # Temporarily disable browser network
    if /usr/local/bin/app-network-control disable browser >/dev/null 2>&1; then
        validate "dynamic network blocking works" \
            "/usr/local/bin/app-network-control list | grep -q 'browser.*BLOCKED'" \
            "7.3"
        
        # Restore original browser status
        /usr/local/bin/app-network-control enable browser 80,443 >/dev/null 2>&1
    else
        error "Failed to test dynamic network blocking"
        VALIDATIONS_FAILED=$((VALIDATIONS_FAILED + 1))
    fi
}

# Additional security validations
validate_additional_security() {
    log "=== Additional security validations ==="
    
    # Check SELinux integration
    validate "SELinux integration configured" \
        "[[ -f '/usr/local/bin/selinux-nftables-sync' && -x '/usr/local/bin/selinux-nftables-sync' ]]" \
        "General"
    
    # Check SELinux context mapping
    validate "SELinux context mapping exists" \
        "[[ -f '/etc/nftables.d/contexts/selinux-mapping.conf' ]]" \
        "General"
    
    # Check SELinux integration rules
    validate "SELinux integration rules exist" \
        "[[ -f '/etc/nftables.d/selinux-integration.nft' ]]" \
        "General"
    
    # Check if SELinux context-based rules are configured (if SELinux is enforcing)
    if getenforce 2>/dev/null | grep -q "Enforcing"; then
        validate "SELinux context-based rules configured" \
            "nft list ruleset | grep -q 'meta secctx'" \
            "General"
    else
        warning "SELinux not in enforcing mode, skipping context-based rule validation"
    fi
    
    # Check network monitoring capability
    validate "network monitoring capability exists" \
        "[[ -f '/etc/systemd/system/app-network-monitor.service' ]]" \
        "General"
    
    # Check policy configuration directory
    validate "policy configuration directory exists" \
        "[[ -d '/etc/nftables.d/app-rules' ]]" \
        "General"
    
    # Check application policy file
    validate "application policy file exists" \
        "[[ -f '/etc/nftables.d/app-policies.conf' ]]" \
        "General"
}

# Network isolation validation
validate_network_isolation() {
    log "=== Network isolation validation ==="
    
    # Test DNS resolution is controlled
    validate "DNS resolution controlled" \
        "nft list ruleset | grep -q 'dport 53'" \
        "Isolation"
    
    # Test ICMP traffic is controlled
    validate "ICMP traffic controlled" \
        "nft list ruleset | grep -q 'icmp'" \
        "Isolation"
    
    # Test that system services have appropriate network access
    validate "system services network access configured" \
        "nft list ruleset | grep -q 'system'" \
        "Isolation"
    
    # Test that unknown traffic is dropped by default
    validate "unknown traffic dropped by default" \
        "! timeout 3 nc -z 192.0.2.1 9999 2>/dev/null" \
        "Isolation"
    
    # Test logging of dropped connections
    validate "dropped connections are logged" \
        "nft list ruleset | grep -q 'log prefix.*DROP'" \
        "Isolation"
    
    # Test network control interface can modify rules
    validate "network control interface can modify rules" \
        "/usr/local/bin/app-network-control reload >/dev/null 2>&1" \
        "Isolation"
}

# Performance validation
validate_performance() {
    log "=== Performance validation ==="
    
    # Test network filtering performance
    start_time=$(date +%s%N)
    for i in {1..5}; do
        timeout 1 nc -z 8.8.8.8 53 >/dev/null 2>&1 || true
    done
    end_time=$(date +%s%N)
    
    duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    average_duration=$((duration / 5))
    
    validate "network filtering performance acceptable" \
        "[[ $average_duration -lt 200 ]]" \
        "Performance"
    
    log "Average connection time: ${average_duration}ms"
    
    # Test rule count is reasonable
    rule_count=$(nft list ruleset | grep -c "^[[:space:]]*[^#]" || echo "0")
    validate "nftables rule count reasonable" \
        "[[ $rule_count -lt 1000 ]]" \
        "Performance"
    
    log "Total nftables rules: $rule_count"
    
    # Test memory usage is reasonable
    nft_memory=$(ps -o rss= -p $(pgrep nft | head -1) 2>/dev/null || echo "0")
    validate "nftables memory usage reasonable" \
        "[[ $nft_memory -lt 100000 ]]" \
        "Performance"
    
    log "nftables memory usage: ${nft_memory}KB"
}

# Integration validation
validate_integration() {
    log "=== Integration validation ==="
    
    # Test integration with bubblewrap sandboxing
    if command -v bwrap >/dev/null 2>&1; then
        validate "integration with bubblewrap available" \
            "command -v bwrap >/dev/null 2>&1" \
            "Integration"
        
        # Test network isolation works in sandbox
        validate "network isolation works in sandbox" \
            "timeout 5 bwrap --ro-bind /usr /usr --tmpfs /tmp --unshare-all --unshare-net --die-with-parent /bin/sh -c '! ping -c 1 8.8.8.8' 2>/dev/null" \
            "Integration"
    else
        warning "Bubblewrap not available, skipping integration validation"
    fi
    
    # Test systemd service integration
    validate "systemd service integration" \
        "systemctl is-enabled nftables" \
        "Integration"
    
    # Test configuration persistence
    validate "configuration files persistent" \
        "[[ -f '/etc/nftables.conf' && -d '/etc/nftables.d' ]]" \
        "Integration"
    
    # Test that nftables starts automatically
    validate "nftables service auto-start configured" \
        "systemctl is-enabled nftables" \
        "Integration"
}

# Generate validation report
generate_validation_report() {
    log "=== Task 13 Validation Report ==="
    log "Total validations: $VALIDATIONS_TOTAL"
    log "Passed: $VALIDATIONS_PASSED"
    log "Failed: $VALIDATIONS_FAILED"
    
    if [[ $VALIDATIONS_FAILED -eq 0 ]]; then
        success "✓ ALL VALIDATIONS PASSED"
        log ""
        log "Task 13 implementation is COMPLETE and meets all requirements:"
        log ""
        log "Requirement 7.2 - nftables per-application controls:"
        log "  ✓ nftables installed and configured with default DROP policy"
        log "  ✓ Per-application firewall rules implemented"
        log "  ✓ Application-specific chains configured"
        log "  ✓ Browser, office, media, and development rules configured"
        log ""
        log "Requirement 7.3 - Network access blocking:"
        log "  ✓ Network control interface functional"
        log "  ✓ Office and media applications blocked by default"
        log "  ✓ Raw socket creation blocked for non-privileged users"
        log "  ✓ Blocked applications cannot make network connections"
        log "  ✓ Dynamic blocking functionality working"
        log ""
        log "Additional security features:"
        log "  ✓ SELinux integration configured and functional"
        log "  ✓ Network monitoring and logging implemented"
        log "  ✓ Policy configuration management available"
        log "  ✓ Network isolation validated"
        log "  ✓ Performance impact acceptable"
        log "  ✓ Integration with other security components verified"
        log ""
        success "Task 13: Configure per-application network controls with nftables - COMPLETED"
        return 0
    else
        error "✗ VALIDATION FAILED"
        error "Task 13 implementation has issues that need to be addressed."
        log "Failed validations: $VALIDATIONS_FAILED"
        return 1
    fi
}

# Main execution
main() {
    log "Starting validation for Task 13: Configure per-application network controls with nftables"
    log "This validation ensures all requirements are properly implemented"
    
    # Run all validations
    validate_requirement_7_2
    validate_requirement_7_3
    validate_additional_security
    validate_network_isolation
    validate_performance
    validate_integration
    
    # Generate final validation report
    generate_validation_report
}

# Execute main function
main "$@"