#!/bin/bash
# check-uefi.sh - Verify UEFI and Secure Boot support

set -e

echo "=== UEFI and Secure Boot Verification ==="
echo

# Check if system booted with UEFI
echo "1. Checking UEFI boot mode..."
if [ -d /sys/firmware/efi ]; then
    echo "   ✓ System booted with UEFI"
else
    echo "   ✗ System did not boot with UEFI (Legacy BIOS detected)"
    echo "   UEFI boot is required for Secure Boot functionality"
    exit 1
fi

# Check EFI variables access
echo
echo "2. Checking EFI variables access..."
if [ -d /sys/firmware/efi/efivars ]; then
    echo "   ✓ EFI variables accessible"
    efi_vars_count=$(ls /sys/firmware/efi/efivars | wc -l)
    echo "   Found $efi_vars_count EFI variables"
else
    echo "   ✗ EFI variables not accessible"
    echo "   May need to mount efivarfs: sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars"
fi

# Check Secure Boot status
echo
echo "3. Checking Secure Boot status..."
sb_var=$(find /sys/firmware/efi/efivars -name "SecureBoot-*" 2>/dev/null | head -1)
if [ -n "$sb_var" ]; then
    # Read Secure Boot status (last byte of the variable)
    sb_status=$(od -An -t u1 "$sb_var" 2>/dev/null | awk '{print $NF}')
    if [ "$sb_status" = "1" ]; then
        echo "   ✓ Secure Boot is currently ENABLED"
    else
        echo "   ! Secure Boot is currently DISABLED"
        echo "   (This is normal for development - can be enabled later)"
    fi
else
    echo "   ? Secure Boot status variable not found"
    echo "   System may not support Secure Boot"
fi

# Check Setup Mode (for key enrollment)
echo
echo "4. Checking Setup Mode status..."
setup_var=$(find /sys/firmware/efi/efivars -name "SetupMode-*" 2>/dev/null | head -1)
if [ -n "$setup_var" ]; then
    setup_status=$(od -An -t u1 "$setup_var" 2>/dev/null | awk '{print $NF}')
    if [ "$setup_status" = "1" ]; then
        echo "   ! System is in Setup Mode (custom keys can be enrolled)"
    else
        echo "   ✓ System is in User Mode (Secure Boot keys are enrolled)"
    fi
else
    echo "   ? Setup Mode status not available"
fi

# Check for existing Platform Keys
echo
echo "5. Checking Platform Key (PK) status..."
pk_var=$(find /sys/firmware/efi/efivars -name "PK-*" 2>/dev/null | head -1)
if [ -n "$pk_var" ]; then
    pk_size=$(stat -c%s "$pk_var" 2>/dev/null)
    if [ "$pk_size" -gt 4 ]; then
        echo "   ✓ Platform Key (PK) is enrolled"
    else
        echo "   ! No Platform Key (PK) enrolled"
    fi
else
    echo "   ? Platform Key status not available"
fi

# Check EFI System Partition
echo
echo "6. Checking EFI System Partition..."
esp_mount=$(findmnt -n -o TARGET -t vfat | grep -E "(boot/efi|efi)" | head -1)
if [ -n "$esp_mount" ]; then
    echo "   ✓ EFI System Partition mounted at: $esp_mount"
    esp_size=$(df -h "$esp_mount" | awk 'NR==2{print $2}')
    echo "   ESP size: $esp_size"
else
    echo "   ! EFI System Partition not found or not mounted"
    echo "   Check with: sudo fdisk -l | grep EFI"
fi

# Check for efibootmgr
echo
echo "7. Checking boot manager tools..."
if command -v efibootmgr >/dev/null 2>&1; then
    echo "   ✓ efibootmgr available"
    echo "   Current boot entries:"
    efibootmgr 2>/dev/null | head -10 | sed 's/^/     /'
else
    echo "   ! efibootmgr not installed"
    echo "   Install with: sudo apt install efibootmgr"
fi

echo
echo "=== UEFI Verification Complete ==="

# Summary
if [ -d /sys/firmware/efi ]; then
    echo "✓ System is UEFI-compatible and ready for Secure Boot implementation"
else
    echo "✗ System requires UEFI boot mode for the hardened OS project"
    exit 1
fi