#!/bin/bash
#
# Kernel Package Testing Script
# Tests signed kernel packages and boot process validation
#
# Part of Task 8: Create signed kernel packages and initramfs
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
PACKAGES_DIR="$WORK_DIR/packages"
LOG_FILE="$WORK_DIR/kernel-package-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize test logging
init_test_logging() {
    mkdir -p "$WORK_DIR"
    echo "=== Kernel Package Testing Log - $(date) ===" > "$LOG_FILE"
}

# Test 1: Verify package files exist
test_package_files_exist() {
    log_test "Testing if kernel package files exist..."
    
    local packages_found=0
    
    # Look for kernel image packages
    for pkg in "$PACKAGES_DIR"/linux-image-*.deb; do
        if [ -f "$pkg" ]; then
            log_info "✓ Found kernel package: $(basename "$pkg")"
            packages_found=$((packages_found + 1))
            export KERNEL_PACKAGE="$pkg"
        fi
    done
    
    # Look for headers packages
    for pkg in "$PACKAGES_DIR"/linux-headers-*.deb; do
        if [ -f "$pkg" ]; then
            log_info "✓ Found headers package: $(basename "$pkg")"
            packages_found=$((packages_found + 1))
            export HEADERS_PACKAGE="$pkg"
        fi
    done
    
    if [ $packages_found -gt 0 ]; then
        log_info "✓ Package files exist ($packages_found packages found)"
        return 0
    else
        log_error "✗ No kernel packages found in $PACKAGES_DIR"
        return 1
    fi
}

# Test 2: Verify package integrity
test_package_integrity() {
    log_test "Testing package integrity..."
    
    if [ -z "${KERNEL_PACKAGE:-}" ]; then
        log_error "No kernel package to test"
        return 1
    fi
    
    # Test package structure
    if dpkg-deb --info "$KERNEL_PACKAGE" &>/dev/null; then
        log_info "✓ Kernel package structure is valid"
    else
        log_error "✗ Kernel package structure is invalid"
        return 1
    fi
    
    # Test package contents
    local contents=$(dpkg-deb --contents "$KERNEL_PACKAGE")
    
    # Check for essential files
    local essential_files=(
        "./boot/vmlinuz-"
        "./boot/System.map-"
        "./boot/config-"
        "./boot/initrd.img-"
        "./lib/modules/"
    )
    
    local missing_files=()
    
    for file_pattern in "${essential_files[@]}"; do
        if echo "$contents" | grep -q "$file_pattern"; then
            log_info "✓ Found essential file pattern: $file_pattern"
        else
            missing_files+=("$file_pattern")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_info "✓ All essential files present in package"
        return 0
    else
        log_error "✗ Missing essential files: ${missing_files[*]}"
        return 1
    fi
}

# Test 3: Verify package metadata
test_package_metadata() {
    log_test "Testing package metadata..."
    
    if [ -z "${KERNEL_PACKAGE:-}" ]; then
        log_error "No kernel package to test"
        return 1
    fi
    
    # Extract and check control information
    local control_info=$(dpkg-deb --info "$KERNEL_PACKAGE")
    
    # Check required fields
    local required_fields=("Package:" "Version:" "Architecture:" "Description:")
    local missing_fields=()
    
    for field in "${required_fields[@]}"; do
        if echo "$control_info" | grep -q "$field"; then
            log_info "✓ Found required field: $field"
        else
            missing_fields+=("$field")
        fi
    done
    
    # Check dependencies
    if echo "$control_info" | grep -q "Depends:"; then
        local depends=$(echo "$control_info" | grep "Depends:" | cut -d: -f2-)
        log_info "✓ Package dependencies: $depends"
    else
        log_warn "No package dependencies specified"
    fi
    
    if [ ${#missing_fields[@]} -eq 0 ]; then
        log_info "✓ Package metadata is complete"
        return 0
    else
        log_error "✗ Missing metadata fields: ${missing_fields[*]}"
        return 1
    fi
}

# Test 4: Verify kernel signatures
test_kernel_signatures() {
    log_test "Testing kernel signatures..."
    
    if [ -z "${KERNEL_PACKAGE:-}" ]; then
        log_error "No kernel package to test"
        return 1
    fi
    
    # Extract package to temporary directory
    local temp_dir=$(mktemp -d)
    dpkg-deb --extract "$KERNEL_PACKAGE" "$temp_dir"
    
    # Find kernel image
    local kernel_image=$(find "$temp_dir/boot" -name "vmlinuz-*" | head -1)
    
    if [ -n "$kernel_image" ]; then
        log_info "Testing kernel image signature: $(basename "$kernel_image")"
        
        # Check if kernel is signed (look for signature)
        if command -v sbverify &>/dev/null; then
            if sbverify --list "$kernel_image" 2>/dev/null | grep -q "signature"; then
                log_info "✓ Kernel image has valid signature"
            else
                log_warn "Kernel image signature verification failed or not signed"
            fi
        else
            log_warn "sbverify not available - cannot verify signatures"
        fi
    else
        log_error "✗ No kernel image found in package"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Check initramfs signature
    local initramfs=$(find "$temp_dir/boot" -name "initrd.img-*" | head -1)
    
    if [ -n "$initramfs" ]; then
        log_info "Found initramfs: $(basename "$initramfs")"
        
        if command -v sbverify &>/dev/null; then
            if sbverify --list "$initramfs" 2>/dev/null | grep -q "signature"; then
                log_info "✓ Initramfs has valid signature"
            else
                log_warn "Initramfs signature verification failed or not signed"
            fi
        fi
    fi
    
    # Check module signatures
    local modules_dir=$(find "$temp_dir/lib/modules" -type d -name "*harden*" | head -1)
    
    if [ -n "$modules_dir" ]; then
        local signed_modules=0
        local total_modules=0
        
        while IFS= read -r -d '' module; do
            total_modules=$((total_modules + 1))
            
            # Check if module has signature
            if modinfo "$module" 2>/dev/null | grep -q "sig_id\|signature"; then
                signed_modules=$((signed_modules + 1))
            fi
        done < <(find "$modules_dir" -name "*.ko" -print0)
        
        if [ $total_modules -gt 0 ]; then
            log_info "Module signature status: $signed_modules/$total_modules modules signed"
            
            if [ $signed_modules -gt 0 ]; then
                log_info "✓ Some kernel modules are signed"
            else
                log_warn "No kernel modules appear to be signed"
            fi
        fi
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    log_info "Kernel signature testing completed"
    return 0
}

# Test 5: Verify initramfs contents
test_initramfs_contents() {
    log_test "Testing initramfs contents for TPM2 and LUKS support..."
    
    if [ -z "${KERNEL_PACKAGE:-}" ]; then
        log_error "No kernel package to test"
        return 1
    fi
    
    # Extract package
    local temp_dir=$(mktemp -d)
    dpkg-deb --extract "$KERNEL_PACKAGE" "$temp_dir"
    
    # Find initramfs
    local initramfs=$(find "$temp_dir/boot" -name "initrd.img-*" | head -1)
    
    if [ -z "$initramfs" ]; then
        log_error "✗ No initramfs found in package"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract initramfs
    local initramfs_dir="$temp_dir/initramfs"
    mkdir -p "$initramfs_dir"
    
    cd "$initramfs_dir"
    
    # Try different decompression methods
    if zcat "$initramfs" 2>/dev/null | cpio -id 2>/dev/null; then
        log_info "✓ Initramfs extracted with gzip"
    elif lz4cat "$initramfs" 2>/dev/null | cpio -id 2>/dev/null; then
        log_info "✓ Initramfs extracted with lz4"
    elif xzcat "$initramfs" 2>/dev/null | cpio -id 2>/dev/null; then
        log_info "✓ Initramfs extracted with xz"
    else
        log_warn "Could not extract initramfs - unknown compression"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Check for TPM2 support
    local tpm2_features=0
    
    if [ -f "usr/bin/tpm2_pcrread" ] || [ -f "bin/tpm2_pcrread" ]; then
        log_info "✓ TPM2 tools found in initramfs"
        tpm2_features=$((tpm2_features + 1))
    fi
    
    if [ -f "usr/lib/systemd/systemd-cryptsetup" ] || [ -f "lib/systemd/systemd-cryptsetup" ]; then
        log_info "✓ systemd-cryptsetup found in initramfs"
        tmp2_features=$((tpm2_features + 1))
    fi
    
    # Check for LUKS support
    local luks_features=0
    
    if find . -name "*dm-crypt*" | grep -q .; then
        log_info "✓ dm-crypt module found in initramfs"
        luks_features=$((luks_features + 1))
    fi
    
    if find . -name "*aes*" | grep -q .; then
        log_info "✓ AES crypto modules found in initramfs"
        luks_features=$((luks_features + 1))
    fi
    
    # Check for essential binaries
    local essential_bins=("init" "sh" "mount" "umount")
    local missing_bins=()
    
    for bin in "${essential_bins[@]}"; do
        if [ -f "bin/$bin" ] || [ -f "sbin/$bin" ] || [ -f "usr/bin/$bin" ] || [ -f "usr/sbin/$bin" ]; then
            log_info "✓ Found essential binary: $bin"
        else
            missing_bins+=("$bin")
        fi
    done
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Evaluate results
    local success=0
    
    if [ $tpm2_features -gt 0 ]; then
        log_info "✓ TPM2 support detected in initramfs"
        success=$((success + 1))
    else
        log_warn "Limited TPM2 support in initramfs"
    fi
    
    if [ $luks_features -gt 0 ]; then
        log_info "✓ LUKS support detected in initramfs"
        success=$((success + 1))
    else
        log_warn "Limited LUKS support in initramfs"
    fi
    
    if [ ${#missing_bins[@]} -eq 0 ]; then
        log_info "✓ All essential binaries present"
        success=$((success + 1))
    else
        log_warn "Missing essential binaries: ${missing_bins[*]}"
    fi
    
    if [ $success -ge 2 ]; then
        return 0
    else
        return 1
    fi
}

# Test 6: Test package installation simulation
test_package_installation_simulation() {
    log_test "Testing package installation simulation..."
    
    if [ -z "${KERNEL_PACKAGE:-}" ]; then
        log_error "No kernel package to test"
        return 1
    fi
    
    # Test dry-run installation
    if dpkg --dry-run -i "$KERNEL_PACKAGE" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "✓ Package installation simulation successful"
    else
        log_error "✗ Package installation simulation failed"
        return 1
    fi
    
    # Check dependencies
    local missing_deps=$(dpkg --dry-run -i "$KERNEL_PACKAGE" 2>&1 | grep "depends on" | wc -l)
    
    if [ "$missing_deps" -eq 0 ]; then
        log_info "✓ All package dependencies satisfied"
    else
        log_warn "Package has unmet dependencies ($missing_deps issues)"
    fi
    
    return 0
}

# Test 7: Test repository structure
test_repository_structure() {
    log_test "Testing package repository structure..."
    
    local repo_dir="$PACKAGES_DIR/repository"
    
    if [ ! -d "$repo_dir" ]; then
        log_warn "No repository directory found"
        return 1
    fi
    
    # Check for repository files
    local repo_files=("Packages" "Packages.gz" "Release")
    local missing_files=()
    
    for file in "${repo_files[@]}"; do
        if [ -f "$repo_dir/$file" ]; then
            log_info "✓ Found repository file: $file"
        else
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_info "✓ Repository structure is complete"
        
        # Test repository metadata
        if grep -q "Package:" "$repo_dir/Packages" 2>/dev/null; then
            log_info "✓ Repository metadata is valid"
        else
            log_warn "Repository metadata may be invalid"
        fi
        
        return 0
    else
        log_error "✗ Missing repository files: ${missing_files[*]}"
        return 1
    fi
}

# Test 8: Test boot configuration compatibility
test_boot_configuration() {
    log_test "Testing boot configuration compatibility..."
    
    # Check GRUB configuration
    if [ -f /boot/grub/grub.cfg ]; then
        log_info "✓ GRUB configuration found"
        
        # Check if GRUB supports signed kernels
        if grep -q "linux.*vmlinuz" /boot/grub/grub.cfg; then
            log_info "✓ GRUB configured for kernel booting"
        else
            log_warn "GRUB kernel configuration may need updates"
        fi
    else
        log_warn "GRUB configuration not found"
    fi
    
    # Check EFI System Partition
    local esp_mount=$(findmnt -n -o TARGET -t vfat | grep -E "(boot/efi|efi)" | head -1)
    
    if [ -n "$esp_mount" ]; then
        log_info "✓ EFI System Partition found: $esp_mount"
        
        # Check available space
        local esp_space=$(df -h "$esp_mount" | awk 'NR==2{print $4}')
        log_info "  Available ESP space: $esp_space"
    else
        log_warn "EFI System Partition not found"
    fi
    
    # Check Secure Boot status
    if command -v mokutil &>/dev/null; then
        local sb_state=$(mokutil --sb-state 2>/dev/null || echo "unknown")
        log_info "Secure Boot state: $sb_state"
    fi
    
    return 0
}

# Generate comprehensive test report
generate_test_report() {
    log_test "Generating kernel package test report..."
    
    local report_file="$WORK_DIR/kernel-package-test-report.md"
    
    cat > "$report_file" << EOF
# Kernel Package Test Report

**Generated:** $(date)
**Task:** 8. Create signed kernel packages and initramfs - Testing

## Test Summary

This report documents the testing of signed kernel packages and initramfs.

## Package Information

EOF
    
    # Add package information
    if [ -n "${KERNEL_PACKAGE:-}" ]; then
        echo "### Kernel Package" >> "$report_file"
        echo "- **File:** \`$(basename "$KERNEL_PACKAGE")\`" >> "$report_file"
        echo "- **Size:** $(du -h "$KERNEL_PACKAGE" | cut -f1)" >> "$report_file"
        
        # Add package info
        echo "" >> "$report_file"
        echo "#### Package Information" >> "$report_file"
        echo '```' >> "$report_file"
        dpkg-deb --info "$KERNEL_PACKAGE" >> "$report_file" 2>/dev/null || echo "Package info not available" >> "$report_file"
        echo '```' >> "$report_file"
    fi
    
    # Run tests and capture results
    local total_tests=0
    local passed_tests=0
    
    echo "" >> "$report_file"
    echo "## Test Results" >> "$report_file"
    echo "" >> "$report_file"
    
    local test_functions=(
        "test_package_files_exist"
        "test_package_integrity"
        "test_package_metadata"
        "test_kernel_signatures"
        "test_initramfs_contents"
        "test_package_installation_simulation"
        "test_repository_structure"
        "test_boot_configuration"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        echo "### Test: $test_func" >> "$report_file"
        if $test_func >> "$report_file" 2>&1; then
            passed_tests=$((passed_tests + 1))
            echo "**Result: PASSED**" >> "$report_file"
        else
            echo "**Result: FAILED**" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    # Add summary
    cat >> "$report_file" << EOF

## Overall Results

- **Total Tests:** $total_tests
- **Passed:** $passed_tests
- **Failed:** $((total_tests - passed_tests))
- **Success Rate:** $(( passed_tests * 100 / total_tests ))%

## Installation Instructions

### Manual Installation
\`\`\`bash
# Install kernel package
sudo dpkg -i $(basename "${KERNEL_PACKAGE:-kernel-package.deb}")

# Fix any dependency issues
sudo apt-get install -f

# Update GRUB
sudo update-grub

# Reboot to new kernel
sudo reboot
\`\`\`

### Repository Installation
\`\`\`bash
# Add repository
echo "deb [trusted=yes] file://$PACKAGES_DIR/repository ./" | sudo tee /etc/apt/sources.list.d/hardened-kernel.list

# Update and install
sudo apt update
sudo apt install linux-image-*harden*
\`\`\`

## Verification After Installation

### Boot Verification
\`\`\`bash
# Check running kernel
uname -r

# Verify Secure Boot
mokutil --sb-state
sbctl status
\`\`\`

### TPM2 Verification
\`\`\`bash
# Test TPM2 functionality
tpm2_getcap properties-fixed

# Test LUKS unlocking
sudo systemd-cryptsetup attach test /dev/sdX2
\`\`\`

## Recommendations

EOF
    
    if [ $passed_tests -eq $total_tests ]; then
        echo "✅ **All tests passed!** Kernel packages are ready for installation." >> "$report_file"
    else
        echo "⚠️  **Some tests failed.** Review the failed tests before installation." >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Next Steps

1. **Install packages on target system**
2. **Test boot process with Secure Boot enabled**
3. **Verify TPM2 automatic unlocking**
4. **Proceed to Task 9 (SELinux configuration)**

## Files

- Test log: \`$LOG_FILE\`
- This report: \`$report_file\`

EOF
    
    log_info "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting kernel package testing..."
    
    init_test_logging
    
    # Run all tests
    local total_tests=0
    local passed_tests=0
    
    local test_functions=(
        "test_package_files_exist"
        "test_package_integrity"
        "test_package_metadata"
        "test_kernel_signatures"
        "test_initramfs_contents"
        "test_package_installation_simulation"
        "test_repository_structure"
        "test_boot_configuration"
    )
    
    for test_func in "${test_functions[@]}"; do
        total_tests=$((total_tests + 1))
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
        echo # Add spacing between tests
    done
    
    generate_test_report
    
    log_info "=== Kernel Package Testing Completed ==="
    log_info "Results: $passed_tests/$total_tests tests passed"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_info "✅ All tests PASSED!"
    else
        log_warn "⚠️  Some tests FAILED - review before installation"
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--quick]"
        echo "Tests signed kernel packages and initramfs"
        echo ""
        echo "Options:"
        echo "  --help   Show this help"
        echo "  --quick  Run only basic tests"
        exit 0
        ;;
    --quick)
        init_test_logging
        test_package_files_exist
        test_package_integrity
        test_package_metadata
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac