#!/bin/bash
# check-resources.sh - Verify system meets hardware requirements

set -e

echo "=== System Resources Verification ==="
echo

# Check RAM
echo "1. Checking system memory..."
ram_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
ram_gb=$((ram_total_kb / 1024 / 1024))
ram_available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
ram_available_gb=$((ram_available_kb / 1024 / 1024))

if [ "$ram_gb" -ge 16 ]; then
    echo "   ✓ Total RAM: ${ram_gb}GB (meets 16GB minimum requirement)"
else
    echo "   ✗ Total RAM: ${ram_gb}GB (below 16GB minimum requirement)"
    echo "   Kernel compilation may fail or be very slow"
fi

echo "   Available RAM: ${ram_available_gb}GB"

# Check disk space for build directory
echo
echo "2. Checking disk space..."
build_dir="$HOME/harden"
if [ -d "$build_dir" ]; then
    disk_available_kb=$(df "$build_dir" | awk 'NR==2{print $4}')
else
    disk_available_kb=$(df "$HOME" | awk 'NR==2{print $4}')
fi
disk_gb=$((disk_available_kb / 1024 / 1024))

if [ "$disk_gb" -ge 250 ]; then
    echo "   ✓ Available disk space: ${disk_gb}GB (meets 250GB requirement)"
else
    echo "   ! Available disk space: ${disk_gb}GB (below 250GB recommended)"
    echo "   May need to free up space for build artifacts"
fi

# Check CPU architecture
echo
echo "3. Checking CPU architecture..."
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    echo "   ✓ Architecture: $arch (compatible)"
else
    echo "   ✗ Architecture: $arch (x86_64 required)"
    exit 1
fi

# Check CPU cores
cpu_cores=$(nproc)
echo "   CPU cores: $cpu_cores"
if [ "$cpu_cores" -ge 4 ]; then
    echo "   ✓ Sufficient CPU cores for parallel compilation"
else
    echo "   ! Limited CPU cores - compilation will be slower"
fi

# Check virtualization support
echo
echo "4. Checking virtualization support..."
if grep -q -E "(vmx|svm)" /proc/cpuinfo; then
    echo "   ✓ CPU virtualization support detected"
    
    # Check if KVM is available
    if [ -c /dev/kvm ]; then
        echo "   ✓ KVM device available"
    else
        echo "   ! KVM device not available"
        echo "   May need to load KVM modules or enable in BIOS"
    fi
else
    echo "   ✗ No CPU virtualization support detected"
    echo "   QEMU testing will be slower without hardware acceleration"
fi

# Check for required CPU features
echo
echo "5. Checking CPU security features..."

# Check for ASLR support
if grep -q "randomize_va_space" /proc/sys/kernel/randomize_va_space 2>/dev/null; then
    aslr_status=$(cat /proc/sys/kernel/randomize_va_space)
    if [ "$aslr_status" = "2" ]; then
        echo "   ✓ ASLR fully enabled"
    else
        echo "   ! ASLR not fully enabled (current: $aslr_status)"
    fi
fi

# Check for NX bit support
if grep -q " nx " /proc/cpuinfo; then
    echo "   ✓ NX bit (No-Execute) support available"
else
    echo "   ! NX bit support not detected"
fi

# Check for SMEP/SMAP support (Intel)
if grep -q " smep " /proc/cpuinfo; then
    echo "   ✓ SMEP (Supervisor Mode Execution Prevention) available"
fi

if grep -q " smap " /proc/cpuinfo; then
    echo "   ✓ SMAP (Supervisor Mode Access Prevention) available"
fi

# Check storage type
echo
echo "6. Checking storage configuration..."
root_device=$(df / | awk 'NR==2{print $1}' | sed 's/[0-9]*$//')
if [ -b "$root_device" ]; then
    # Check if it's an SSD
    if [ -f "/sys/block/$(basename $root_device)/queue/rotational" ]; then
        rotational=$(cat "/sys/block/$(basename $root_device)/queue/rotational")
        if [ "$rotational" = "0" ]; then
            echo "   ✓ Root filesystem on SSD (recommended for performance)"
        else
            echo "   ! Root filesystem on HDD (SSD recommended for better performance)"
        fi
    fi
fi

# Check swap configuration
echo
echo "7. Checking swap configuration..."
swap_total=$(free | awk '/^Swap:/{print $2}')
if [ "$swap_total" -gt 0 ]; then
    swap_gb=$((swap_total / 1024 / 1024))
    echo "   ✓ Swap available: ${swap_gb}GB"
else
    echo "   ! No swap configured"
    echo "   Swap may be needed for large kernel compilations"
fi

echo
echo "=== Resource Verification Complete ==="

# Overall assessment
issues=0
if [ "$ram_gb" -lt 16 ]; then
    issues=$((issues + 1))
fi
if [ "$disk_gb" -lt 250 ]; then
    issues=$((issues + 1))
fi
if [ "$arch" != "x86_64" ]; then
    issues=$((issues + 1))
fi

if [ "$issues" -eq 0 ]; then
    echo "✓ System meets all hardware requirements for hardened OS development"
else
    echo "! System has $issues requirement issues that should be addressed"
fi