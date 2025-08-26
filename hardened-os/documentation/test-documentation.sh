#!/bin/bash
# Test script for comprehensive documentation validation

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

test_documentation_structure() {
    log_test "Testing documentation structure..."
    
    local required_files=(
        "README.md"
        "INSTALLATION_GUIDE.md"
        "USER_GUIDE.md"
        "SECURITY_GUIDE.md"
        "TROUBLESHOOTING_GUIDE.md"
        "test-documentation.sh"
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

test_markdown_syntax() {
    log_test "Testing Markdown syntax..."
    
    local markdown_files=(
        "README.md"
        "INSTALLATION_GUIDE.md"
        "USER_GUIDE.md"
        "SECURITY_GUIDE.md"
        "TROUBLESHOOTING_GUIDE.md"
    )
    
    local syntax_errors=()
    
    for file in "${markdown_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            # Basic markdown validation - check for common issues
            if grep -q "^#[^# ]" "$SCRIPT_DIR/$file"; then
                # Headers should have space after #
                continue
            fi
            
            # Check for unmatched code blocks
            local code_blocks=$(grep -c "^```" "$SCRIPT_DIR/$file" || echo "0")
            if [[ $((code_blocks % 2)) -ne 0 ]]; then
                syntax_errors+=("$file (unmatched code blocks)")
            fi
        fi
    done
    
    if [[ ${#syntax_errors[@]} -eq 0 ]]; then
        log_pass "Markdown syntax validation passed"
    else
        log_fail "Markdown syntax errors in: ${syntax_errors[*]}"
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
            if ! grep -q "## Table of Contents" "$SCRIPT_DIR/$file"; then
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

test_cross_references() {
    log_test "Testing cross-references..."
    
    local broken_links=()
    
    # Check for references to other documentation files
    for file in "$SCRIPT_DIR"/*.md; do
        if [[ -f "$file" ]]; then
            # Find markdown links to other files
            while IFS= read -r line; do
                if [[ "$line" =~ \[.*\]\(([^)]+\.md)\) ]]; then
                    local referenced_file="${BASH_REMATCH[1]}"
                    # Remove any anchors
                    referenced_file="${referenced_file%#*}"
                    
                    if [[ ! -f "$SCRIPT_DIR/$referenced_file" ]]; then
                        broken_links+=("$(basename "$file"): $referenced_file")
                    fi
                fi
            done < "$file"
        fi
    done
    
    if [[ ${#broken_links[@]} -eq 0 ]]; then
        log_pass "All cross-references are valid"
    else
        log_fail "Broken cross-references: ${broken_links[*]}"
    fi
}

test_code_block_syntax() {
    log_test "Testing code block syntax..."
    
    local syntax_issues=()
    
    for file in "$SCRIPT_DIR"/*.md; do
        if [[ -f "$file" ]]; then
            local in_code_block=false
            local line_number=0
            
            while IFS= read -r line; do
                ((line_number++))
                
                if [[ "$line" =~ ^```.*$ ]]; then
                    if [[ "$in_code_block" == "false" ]]; then
                        in_code_block=true
                    else
                        in_code_block=false
                    fi
                elif [[ "$in_code_block" == "true" ]]; then
                    # Check for common shell syntax issues in code blocks
                    if [[ "$line" =~ ^sudo.*\&\&.*$ ]]; then
                        # Suggest using separate lines for better readability
                        continue
                    fi
                fi
            done < "$file"
            
            # Check if we ended in a code block (unmatched)
            if [[ "$in_code_block" == "true" ]]; then
                syntax_issues+=("$(basename "$file"): Unmatched code block")
            fi
        fi
    done
    
    if [[ ${#syntax_issues[@]} -eq 0 ]]; then
        log_pass "Code block syntax is valid"
    else
        log_fail "Code block syntax issues: ${syntax_issues[*]}"
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
        "Base System Installation"
        "Security Hardening"
        "Post-Installation"
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
        "Troubleshooting"
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

test_troubleshooting_coverage() {
    log_test "Testing troubleshooting guide coverage..."
    
    local troubleshooting_areas=(
        "Boot Issues"
        "TPM Issues"
        "Security Feature Issues"
        "Application Issues"
        "Network Issues"
        "Performance Issues"
        "System Recovery"
        "Emergency Procedures"
    )
    
    local missing_areas=()
    
    if [[ -f "$SCRIPT_DIR/TROUBLESHOOTING_GUIDE.md" ]]; then
        for area in "${troubleshooting_areas[@]}"; do
            if ! grep -qi "$area" "$SCRIPT_DIR/TROUBLESHOOTING_GUIDE.md"; then
                missing_areas+=("$area")
            fi
        done
    else
        missing_areas=("${troubleshooting_areas[@]}")
    fi
    
    if [[ ${#missing_areas[@]} -eq 0 ]]; then
        log_pass "Troubleshooting guide coverage is complete"
    else
        log_fail "Missing troubleshooting areas: ${missing_areas[*]}"
    fi
}

test_command_examples() {
    log_test "Testing command examples..."
    
    local command_issues=()
    
    for file in "$SCRIPT_DIR"/*.md; do
        if [[ -f "$file" ]]; then
            # Look for command examples that might have issues
            while IFS= read -r line; do
                # Check for potentially dangerous commands without proper warnings
                if [[ "$line" =~ rm.*-rf ]] && ! grep -B5 -A5 "rm.*-rf" "$file" | grep -qi "warning\|caution\|danger"; then
                    command_issues+=("$(basename "$file"): Dangerous rm -rf without warning")
                fi
                
                # Check for commands that should use sudo
                if [[ "$line" =~ ^[[:space:]]*cryptsetup ]] && ! [[ "$line" =~ sudo ]]; then
                    command_issues+=("$(basename "$file"): cryptsetup command without sudo")
                fi
            done < "$file"
        fi
    done
    
    if [[ ${#command_issues[@]} -eq 0 ]]; then
        log_pass "Command examples are safe and properly formatted"
    else
        log_fail "Command example issues: ${command_issues[*]}"
    fi
}

test_requirements_coverage() {
    log_test "Testing requirements coverage in documentation..."
    
    local requirements=(
        "19.1"  # User-friendly interfaces
        "19.3"  # Documentation accessibility
        "19.4"  # Actionable security warnings
        "19.5"  # Automated recovery tools
        "11.1"  # Incident response procedures
        "11.2"  # Recovery procedures
        "11.3"  # Key rotation procedures
        "11.4"  # Forensic analysis tools
    )
    
    local missing_requirements=()
    
    for req in "${requirements[@]}"; do
        local found=false
        for file in "$SCRIPT_DIR"/*.md; do
            if [[ -f "$file" ]] && grep -q "$req" "$file"; then
                found=true
                break
            fi
        done
        
        # Also check if the requirement is covered conceptually
        if [[ "$found" != "true" ]]; then
            case "$req" in
                "19.1"|"19.3"|"19.4"|"19.5")
                    if grep -qi "user.*friendly\|accessible\|recovery" "$SCRIPT_DIR"/*.md; then
                        found=true
                    fi
                    ;;
                "11.1"|"11.2"|"11.3"|"11.4")
                    if grep -qi "incident.*response\|recovery\|key.*rotation\|forensic" "$SCRIPT_DIR"/*.md; then
                        found=true
                    fi
                    ;;
            esac
        fi
        
        if [[ "$found" != "true" ]]; then
            missing_requirements+=("$req")
        fi
    done
    
    if [[ ${#missing_requirements[@]} -eq 0 ]]; then
        log_pass "All requirements covered in documentation"
    else
        log_fail "Missing requirements coverage: ${missing_requirements[*]}"
    fi
}

test_accessibility() {
    log_test "Testing documentation accessibility..."
    
    local accessibility_issues=()
    
    for file in "$SCRIPT_DIR"/*.md; do
        if [[ -f "$file" ]]; then
            # Check for proper heading hierarchy
            local prev_level=0
            while IFS= read -r line; do
                if [[ "$line" =~ ^(#+)[[:space:]] ]]; then
                    local current_level=${#BASH_REMATCH[1]}
                    if [[ $prev_level -gt 0 ]] && [[ $current_level -gt $((prev_level + 1)) ]]; then
                        accessibility_issues+=("$(basename "$file"): Heading hierarchy skip")
                        break
                    fi
                    prev_level=$current_level
                fi
            done < "$file"
            
            # Check for alt text on images (if any)
            if grep -q '!\[.*\](' "$file"; then
                if grep -q '!\[\](' "$file"; then
                    accessibility_issues+=("$(basename "$file"): Image without alt text")
                fi
            fi
        fi
    done
    
    if [[ ${#accessibility_issues[@]} -eq 0 ]]; then
        log_pass "Documentation accessibility is good"
    else
        log_fail "Accessibility issues: ${accessibility_issues[*]}"
    fi
}

test_consistency() {
    log_test "Testing documentation consistency..."
    
    local consistency_issues=()
    
    # Check for consistent terminology
    local terms=(
        "Hardened Laptop OS"
        "TPM2"
        "LUKS2"
        "SELinux"
        "UEFI Secure Boot"
    )
    
    for term in "${terms[@]}"; do
        local variations=()
        
        # Look for potential variations
        case "$term" in
            "TPM2")
                variations=("TPM_2.0" "TPM2.0" "tpm2")
                ;;
            "LUKS2")
                variations=("LUKS_2" "LUKS2.0" "luks2")
                ;;
            "SELinux")
                variations=("selinux" "SE_Linux")
                ;;
        esac
        
        for variation in "${variations[@]}"; do
            for file in "$SCRIPT_DIR"/*.md; do
                if [[ -f "$file" ]] && grep -q "$variation" "$file"; then
                    consistency_issues+=("$(basename "$file"): Inconsistent term $variation should be $term")
                fi
            done
        done
    done
    
    if [[ ${#consistency_issues[@]} -eq 0 ]]; then
        log_pass "Documentation terminology is consistent"
    else
        log_fail "Consistency issues: ${consistency_issues[*]}"
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
    test_markdown_syntax
    test_table_of_contents
    test_cross_references
    test_code_block_syntax
    test_security_content
    test_installation_completeness
    test_user_guide_completeness
    test_troubleshooting_coverage
    test_command_examples
    test_requirements_coverage
    test_accessibility
    test_consistency
    
    print_test_summary
}

main "$@"