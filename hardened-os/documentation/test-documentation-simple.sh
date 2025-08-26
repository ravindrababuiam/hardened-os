#!/bin/bash
# Simple test script for documentation validation

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

test_documentation_structure() {
    log_test "Testing documentation structure..."
    
    local required_files=(
        "README.md"
        "INSTALLATION_GUIDE.md"
        "USER_GUIDE.md"
        "SECURITY_GUIDE.md"
        "TROUBLESHOOTING_GUIDE.md"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_pass "All required documentation files present"
    else
        log_fail "Missing documentation files: ${missing_files[*]}"
    fi
}

test_table_of_contents() {
    log_test "Testing table of contents..."
    
    local files_with_toc=(
        "INSTALLATION_GUIDE.md"
        "USER_GUIDE.md"
        "SECURITY_GUIDE.md"
        "TROUBLESHOOTING_GUIDE.md"
    )
    
    local missing_toc=()
    
    for file in "${files_with_toc[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            if ! grep -q "Table of Contents" "$SCRIPT_DIR/$file"; then
                missing_toc+=("$file")
            fi
        fi
    done
    
    if [[ ${#missing_toc[@]} -eq 0 ]]; then
        log_pass "All required files have table of contents"
    else
        log_fail "Missing table of contents in: ${missing_toc[*]}"
    fi
}

test_security_content() {
    log_test "Testing security content coverage..."
    
    local security_topics=(
        "TPM"
        "Secure Boot"
        "LUKS"
        "SELinux"
        "sandboxing"
        "incident response"
        "key rotation"
        "threat model"
    )
    
    local missing_topics=()
    
    for topic in "${security_topics[@]}"; do
        local found=false
        for file in "$SCRIPT_DIR"/*.md; do
            if [[ -f "$file" ]] && grep -qi "$topic" "$file"; then
                found=true
                break
            fi
        done
        
        if [[ "$found" != "true" ]]; then
            missing_topics+=("$topic")
        fi
    done
    
    if [[ ${#missing_topics[@]} -eq 0 ]]; then
        log_pass "All security topics covered"
    else
        log_fail "Missing security topics: ${missing_topics[*]}"
    fi
}

test_installation_completeness() {
    log_test "Testing installation guide completeness..."
    
    local installation_sections=(
        "Prerequisites"
        "Hardware Requirements"
        "Installation"
        "Security"
        "Verification"
        "Troubleshooting"
    )
    
    local missing_sections=()
    
    if [[ -f "$SCRIPT_DIR/INSTALLATION_GUIDE.md" ]]; then
        for section in "${installation_sections[@]}"; do
            if ! grep -qi "$section" "$SCRIPT_DIR/INSTALLATION_GUIDE.md"; then
                missing_sections+=("$section")
            fi
        done
    else
        missing_sections=("${installation_sections[@]}")
    fi
    
    if [[ ${#missing_sections[@]} -eq 0 ]]; then
        log_pass "Installation guide is complete"
    else
        log_fail "Missing installation sections: ${missing_sections[*]}"
    fi
}

test_user_guide_completeness() {
    log_test "Testing user guide completeness..."
    
    local user_guide_sections=(
        "Getting Started"
        "Daily Operations"
        "Security Features"
        "Application Management"
        "System Maintenance"
        "Best Practices"
    )
    
    local missing_sections=()
    
    if [[ -f "$SCRIPT_DIR/USER_GUIDE.md" ]]; then
        for section in "${user_guide_sections[@]}"; do
            if ! grep -qi "$section" "$SCRIPT_DIR/USER_GUIDE.md"; then
                missing_sections+=("$section")
            fi
        done
    else
        missing_sections=("${user_guide_sections[@]}")
    fi
    
    if [[ ${#missing_sections[@]} -eq 0 ]]; then
        log_pass "User guide is complete"
    else
        log_fail "Missing user guide sections: ${missing_sections[*]}"
    fi
}

test_requirements_coverage() {
    log_test "Testing requirements coverage in documentation..."
    
    # Check for conceptual coverage of key requirements
    local requirement_concepts=(
        "user.*friendly"
        "documentation"
        "recovery"
        "incident.*response"
        "key.*rotation"
        "forensic"
    )
    
    local missing_concepts=()
    
    for concept in "${requirement_concepts[@]}"; do
        local found=false
        for file in "$SCRIPT_DIR"/*.md; do
            if [[ -f "$file" ]] && grep -qi "$concept" "$file"; then
                found=true
                break
            fi
        done
        
        if [[ "$found" != "true" ]]; then
            missing_concepts+=("$concept")
        fi
    done
    
    if [[ ${#missing_concepts[@]} -eq 0 ]]; then
        log_pass "All key requirements covered in documentation"
    else
        log_fail "Missing requirement concepts: ${missing_concepts[*]}"
    fi
}

print_test_summary() {
    echo ""
    echo "=================================="
    echo "Documentation Test Summary"
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
        echo -e "${GREEN}All documentation tests passed! Documentation is ready for use.${NC}"
        return 0
    else
        echo -e "${RED}Some documentation tests failed. Please review and fix the issues.${NC}"
        return 1
    fi
}

main() {
    echo "Testing Hardened Laptop OS Documentation"
    echo "========================================"
    echo ""
    
    test_documentation_structure
    test_table_of_contents
    test_security_content
    test_installation_completeness
    test_user_guide_completeness
    test_requirements_coverage
    
    print_test_summary
}

main "$@"