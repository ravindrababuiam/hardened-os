#!/bin/bash
#
# Hardened Kernel Build Script
# Downloads, configures, and builds a hardened Linux kernel with KSPP recommendations
#
# Task 6: Build hardened kernel with KSPP configuration and exploit testing
# - Download Linux kernel source and apply Debian patches
# - Create hardened kernel configuration with all KSPP-recommended flags
# - Enable KASLR, KPTI, Spectre/Meltdown mitigations, and memory protection features
# - Disable debugging features and reduce attack surface (CONFIG_DEVMEM=n, etc.)
# - Test kernel against known CVE exploits to validate mitigations
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
SRC_DIR="$HOME/harden/src"
KERNEL_VERSION="6.1.55"  # Debian stable kernel version
DEBIAN_KERNEL_VERSION="6.1.55-1"
LOG_FILE="$WORK_DIR/kernel-build.log"

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}# 
Initialize logging
init_logging() {
    mkdir -p "$WORK_DIR" "$SRC_DIR"
    echo "=== Hardened Kernel Build Log - $(date) ===" > "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking build prerequisites..."
    
    # Check required tools
    local deps=("gcc" "make" "bc" "bison" "flex" "libssl-dev" "libelf-dev" "libncurses-dev")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$dep" 2>/dev/null && ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install build-essential bc bison flex libssl-dev libelf-dev libncurses-dev"
        exit 1
    fi
    
    # Check disk space (need ~20GB for kernel build)
    local available_space=$(df "$WORK_DIR" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 20971520 ]; then  # 20GB in KB
        log_warn "Low disk space: $(( available_space / 1024 / 1024 ))GB available"
        log_warn "Kernel build requires ~20GB of free space"
    fi
    
    # Check CPU cores for parallel build
    local cpu_cores=$(nproc)
    log_info "Available CPU cores: $cpu_cores"
    export MAKEFLAGS="-j$cpu_cores"
    
    log_info "Prerequisites check passed"
}

# Download kernel source
download_kernel_source() {
    log_step "Downloading Linux kernel source..."
    
    local kernel_dir="$SRC_DIR/linux-$KERNEL_VERSION"
    
    if [ -d "$kernel_dir" ]; then
        log_info "Kernel source already exists at $kernel_dir"
        return 0
    fi
    
    cd "$SRC_DIR"
    
    # Download from kernel.org
    local kernel_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz"
    log_info "Downloading from: $kernel_url"
    
    if ! wget -O "linux-$KERNEL_VERSION.tar.xz" "$kernel_url"; then
        log_error "Failed to download kernel source"
        exit 1
    fi
    
    # Verify signature (if available)
    local sig_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.sign"
    if wget -q "$sig_url" 2>/dev/null; then
        log_info "Verifying kernel signature..."
        # Note: This requires GPG keys to be imported
        gpg --verify "linux-$KERNEL_VERSION.tar.sign" "linux-$KERNEL_VERSION.tar.xz" || {
            log_warn "Signature verification failed - continuing anyway"
        }
    fi
    
    # Extract kernel
    log_info "Extracting kernel source..."
    tar -xf "linux-$KERNEL_VERSION.tar.xz"
    
    log_info "Kernel source downloaded and extracted"
}

# Apply Debian patches
apply_debian_patches() {
    log_step "Applying Debian kernel patches..."
    
    local kernel_dir="$SRC_DIR/linux-$KERNEL_VERSION"
    cd "$kernel_dir"
    
    # Download Debian kernel source for patches
    local debian_src_dir="$SRC_DIR/debian-kernel"
    mkdir -p "$debian_src_dir"
    cd "$debian_src_dir"
    
    # Get Debian kernel source
    if ! apt source "linux-source-$KERNEL_VERSION" 2>/dev/null; then
        log_warn "Could not download Debian kernel source - skipping Debian patches"
        return 0
    fi
    
    # Find Debian patches directory
    local debian_patches_dir=$(find . -name "debian" -type d | head -1)
    if [ -n "$debian_patches_dir" ] && [ -d "$debian_patches_dir/patches" ]; then
        log_info "Applying Debian patches from $debian_patches_dir/patches"
        
        cd "$kernel_dir"
        
        # Apply patches that are safe for hardening
        local patch_series="$debian_patches_dir/patches/series"
        if [ -f "$patch_series" ]; then
            while IFS= read -r patch; do
                # Skip comment lines and empty lines
                [[ "$patch" =~ ^#.*$ ]] && continue
                [[ -z "$patch" ]] && continue
                
                local patch_file="$debian_patches_dir/patches/$patch"
                if [ -f "$patch_file" ]; then
                    log_info "Applying patch: $patch"
                    if ! patch -p1 < "$patch_file"; then
                        log_warn "Failed to apply patch: $patch - continuing"
                    fi
                fi
            done < "$patch_series"
        fi
    else
        log_warn "No Debian patches found - continuing with vanilla kernel"
    fi
    
    log_info "Debian patches applied"
}

# Create hardened kernel configuration
create_hardened_config() {
    log_step "Creating hardened kernel configuration..."
    
    local kernel_dir="$SRC_DIR/linux-$KERNEL_VERSION"
    cd "$kernel_dir"
    
    # Start with default config
    make defconfig
    
    # Create hardened configuration based on KSPP recommendations
    local config_file=".config"
    local hardened_config="$WORK_DIR/hardened-kernel.config"
    
    log_info "Applying KSPP hardening recommendations..."
    
    # Create hardened config additions
    cat > "$hardened_config" << 'EOF'
# Hardened Kernel Configuration - KSPP Recommendations
# Based on Kernel Self Protection Project guidelines

# Memory protection
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_STRICT_MODULE_RWX=y
CONFIG_DEBUG_WX=y
CONFIG_RANDOMIZE_BASE=y
CONFIG_RANDOMIZE_MEMORY=y

# Stack protection
CONFIG_STACKPROTECTOR=y
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_GCC_PLUGIN_STACKLEAK=y
CONFIG_GCC_PLUGIN_STRUCTLEAK=y
CONFIG_GCC_PLUGIN_STRUCTLEAK_BYREF_ALL=y

# Integer overflow protection
CONFIG_UBSAN=y
CONFIG_UBSAN_BOUNDS=y
CONFIG_UBSAN_SANITIZE_ALL=y

# Control Flow Integrity (if supported)
CONFIG_CFI_CLANG=y
CONFIG_CFI_PERMISSIVE=n

# Kernel Address Space Layout Randomization
CONFIG_RANDOMIZE_BASE=y
CONFIG_RANDOMIZE_MEMORY=y

# Kernel Page Table Isolation (Meltdown mitigation)
CONFIG_PAGE_TABLE_ISOLATION=y

# Spectre mitigations
CONFIG_RETPOLINE=y
CONFIG_CPU_SRSO=y

# Memory initialization
CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y
CONFIG_INIT_ON_FREE_DEFAULT_ON=y

# Heap hardening
CONFIG_SLAB_FREELIST_RANDOM=y
CONFIG_SLAB_FREELIST_HARDENED=y
CONFIG_SHUFFLE_PAGE_ALLOCATOR=y

# Attack surface reduction
CONFIG_DEVMEM=n
CONFIG_DEVKMEM=n
CONFIG_DEVPORT=n
CONFIG_PROC_KCORE=n
CONFIG_LEGACY_PTYS=n
CONFIG_MODIFY_LDT_SYSCALL=n
CONFIG_X86_PTDUMP=n

# Disable debugging features in production
CONFIG_DEBUG_KERNEL=n
CONFIG_DEBUG_INFO=n
CONFIG_KPROBES=n
CONFIG_FTRACE=n
CONFIG_PROFILING=n
CONFIG_KEXEC=n
CONFIG_HIBERNATION=n

# Harden BPF
CONFIG_BPF_UNPRIV_DEFAULT_OFF=y
CONFIG_BPF_JIT_HARDEN=2

# Lockdown kernel
CONFIG_SECURITY_LOCKDOWN_LSM=y
CONFIG_SECURITY_LOCKDOWN_LSM_EARLY=y
CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY=y

# Enable additional security modules
CONFIG_SECURITY=y
CONFIG_SECURITY_SELINUX=y
CONFIG_SECURITY_APPARMOR=y
CONFIG_SECURITY_YAMA=y

# Hardened usercopy
CONFIG_HARDENED_USERCOPY=y
CONFIG_HARDENED_USERCOPY_FALLBACK=n
CONFIG_HARDENED_USERCOPY_PAGESPAN=y

# Fortify source
CONFIG_FORTIFY_SOURCE=y

# Control Groups
CONFIG_CGROUPS=y
CONFIG_CGROUP_PIDS=y

# Namespaces for sandboxing
CONFIG_NAMESPACES=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y

# Seccomp for syscall filtering
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y

# KASLR for modules
CONFIG_RANDOMIZE_KSTACK_OFFSET_DEFAULT=y

# Disable unused filesystems to reduce attack surface
CONFIG_CRAMFS=n
CONFIG_FREEVXFS_FS=n
CONFIG_JFFS2_FS=n
CONFIG_HFS_FS=n
CONFIG_HFSPLUS_FS=n
CONFIG_SQUASHFS=n
CONFIG_UDF_FS=n

# Disable unused network protocols
CONFIG_TIPC=n
CONFIG_SCTP=n
CONFIG_DCCP=n
CONFIG_RDS=n

# Enable IOMMU support
CONFIG_INTEL_IOMMU=y
CONFIG_INTEL_IOMMU_DEFAULT_ON=y
CONFIG_AMD_IOMMU=y

# TPM support for measured boot
CONFIG_TCG_TPM=y
CONFIG_TCG_TIS=y
CONFIG_TCG_CRB=y

# Crypto hardening
CONFIG_CRYPTO_MANAGER_DISABLE_TESTS=y
CONFIG_CRYPTO_FIPS=y
EOF
    
    # Merge hardened config with base config
    log_info "Merging hardened configuration..."
    
    # Apply each config option
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        if [[ "$line" =~ ^CONFIG_.*=.*$ ]]; then
            local config_name=$(echo "$line" | cut -d'=' -f1)
            local config_value=$(echo "$line" | cut -d'=' -f2)
            
            # Remove existing config if present
            sed -i "/^$config_name=/d" "$config_file"
            sed -i "/^# $config_name is not set/d" "$config_file"
            
            # Add new config
            echo "$line" >> "$config_file"
        fi
    done < "$hardened_config"
    
    # Run olddefconfig to resolve dependencies
    make olddefconfig
    
    log_info "Hardened kernel configuration created"
}

# Build the kernel
build_kernel() {
    log_step "Building hardened kernel..."
    
    local kernel_dir="$SRC_DIR/linux-$KERNEL_VERSION"
    cd "$kernel_dir"
    
    # Build kernel and modules
    log_info "Starting kernel compilation (this may take 30-60 minutes)..."
    
    if ! make $MAKEFLAGS 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Kernel compilation failed"
        exit 1
    fi
    
    # Build modules
    log_info "Building kernel modules..."
    if ! make modules $MAKEFLAGS 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Module compilation failed"
        exit 1
    fi
    
    log_info "Kernel build completed successfully"
}

# Install kernel and modules
install_kernel() {
    log_step "Installing hardened kernel..."
    
    local kernel_dir="$SRC_DIR/linux-$KERNEL_VERSION"
    cd "$kernel_dir"
    
    # Install modules
    log_info "Installing kernel modules..."
    sudo make modules_install
    
    # Install kernel
    log_info "Installing kernel..."
    sudo make install
    
    # Update initramfs
    log_info "Updating initramfs..."
    sudo update-initramfs -c -k "$KERNEL_VERSION"
    
    # Update GRUB
    log_info "Updating GRUB configuration..."
    sudo update-grub
    
    log_info "Kernel installation completed"
}

# Verify hardened configuration
verify_hardened_config() {
    log_step "Verifying hardened kernel configuration..."
    
    local kernel_dir="$SRC_DIR/linux-$KERNEL_VERSION"
    local config_file="$kernel_dir/.config"
    local verification_report="$WORK_DIR/kernel-hardening-verification.txt"
    
    log_info "Checking KSPP recommendations..."
    
    # Key hardening features to verify
    local required_configs=(
        "CONFIG_STRICT_KERNEL_RWX=y"
        "CONFIG_STRICT_MODULE_RWX=y"
        "CONFIG_STACKPROTECTOR_STRONG=y"
        "CONFIG_RANDOMIZE_BASE=y"
        "CONFIG_PAGE_TABLE_ISOLATION=y"
        "CONFIG_RETPOLINE=y"
        "CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y"
        "CONFIG_SLAB_FREELIST_HARDENED=y"
        "CONFIG_HARDENED_USERCOPY=y"
        "CONFIG_FORTIFY_SOURCE=y"
    )
    
    local disabled_configs=(
        "CONFIG_DEVMEM=n"
        "CONFIG_DEVKMEM=n"
        "CONFIG_PROC_KCORE=n"
        "CONFIG_DEBUG_KERNEL=n"
        "CONFIG_KPROBES=n"
    )
    
    echo "# Kernel Hardening Verification Report" > "$verification_report"
    echo "# Generated: $(date)" >> "$verification_report"
    echo "" >> "$verification_report"
    
    local passed=0
    local total=0
    
    echo "## Required Hardening Features" >> "$verification_report"
    for config in "${required_configs[@]}"; do
        total=$((total + 1))
        if grep -q "^$config$" "$config_file"; then
            echo "✓ $config" >> "$verification_report"
            passed=$((passed + 1))
        else
            echo "✗ $config" >> "$verification_report"
        fi
    done
    
    echo "" >> "$verification_report"
    echo "## Disabled Attack Surface" >> "$verification_report"
    for config in "${disabled_configs[@]}"; do
        total=$((total + 1))
        local config_name=$(echo "$config" | cut -d'=' -f1)
        if grep -q "^$config$" "$config_file" || grep -q "^# $config_name is not set$" "$config_file"; then
            echo "✓ $config" >> "$verification_report"
            passed=$((passed + 1))
        else
            echo "✗ $config" >> "$verification_report"
        fi
    done
    
    echo "" >> "$verification_report"
    echo "## Summary" >> "$verification_report"
    echo "Passed: $passed/$total" >> "$verification_report"
    echo "Success Rate: $(( passed * 100 / total ))%" >> "$verification_report"
    
    log_info "Verification report: $verification_report"
    log_info "Hardening verification: $passed/$total checks passed"
}

# Main execution function
main() {
    log_info "Starting hardened kernel build..."
    log_warn "This implements Task 6: Build hardened kernel with KSPP configuration"
    
    init_logging
    check_prerequisites
    download_kernel_source
    apply_debian_patches
    create_hardened_config
    verify_hardened_config
    build_kernel
    install_kernel
    
    log_info "=== Hardened Kernel Build Completed ==="
    log_info "Next steps:"
    log_info "1. Reboot to test new kernel"
    log_info "2. Verify hardening features are active"
    log_info "3. Run exploit tests to validate mitigations"
    log_warn "Keep old kernel as fallback in GRUB menu"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--config-only|--build-only]"
        echo "Builds hardened Linux kernel with KSPP recommendations"
        echo ""
        echo "Options:"
        echo "  --help        Show this help"
        echo "  --config-only Only create hardened configuration"
        echo "  --build-only  Only build (skip download and config)"
        exit 0
        ;;
    --config-only)
        init_logging
        check_prerequisites
        download_kernel_source
        apply_debian_patches
        create_hardened_config
        verify_hardened_config
        exit 0
        ;;
    --build-only)
        init_logging
        check_prerequisites
        build_kernel
        install_kernel
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac