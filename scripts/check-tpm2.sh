#!/bin/bash
# check-tpm2.sh - Verify TPM2 chip availability and functionality

set -e

echo "=== TPM2 Hardware Verification ==="
echo

# Check if TPM device exists
echo "1. Checking TPM device availability..."
if [ -c /dev/tpm0 ]; then
    echo "   ✓ TPM device found at /dev/tpm0"
elif [ -c /dev/tpmrm0 ]; then
    echo "   ✓ TPM resource manager found at /dev/tpmrm0"
else
    echo "   ✗ No TPM device found"
    echo "   Please enable TPM in BIOS/UEFI settings"
    exit 1
fi

# Check TPM2 tools installation
echo
echo "2. Checking TPM2 tools..."
if command -v tpm2_getcap >/dev/null 2>&1; then
    echo "   ✓ TPM2 tools installed"
else
    echo "   ✗ TPM2 tools not installed"
    echo "   Install with: sudo apt install tpm2-tools"
    exit 1
fi

# Test TPM2 functionality
echo
echo "3. Testing TPM2 functionality..."
if tpm2_getcap properties-fixed >/dev/null 2>&1; then
    echo "   ✓ TPM2 communication successful"
    
    # Get TPM version info
    echo
    echo "4. TPM2 Information:"
    echo "   Manufacturer: $(tpm2_getcap properties-fixed | grep TPM2_PT_MANUFACTURER | awk '{print $2}')"
    echo "   Firmware Version: $(tpm2_getcap properties-fixed | grep TPM2_PT_FIRMWARE_VERSION | awk '{print $2}')"
    
    # Check PCR banks
    echo
    echo "5. Available PCR Banks:"
    tpm2_getcap pcrs | grep -A 20 "supported:" || echo "   Unable to read PCR banks"
    
else
    echo "   ✗ Unable to communicate with TPM2"
    echo "   Check TPM is enabled and accessible"
    exit 1
fi

echo
echo "=== TPM2 Verification Complete ==="
echo "✓ TPM2 is available and functional for the hardened OS project"