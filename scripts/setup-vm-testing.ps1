# Hardened OS VM Testing Setup Script
# Helps prepare for virtual machine testing

Write-Host "=== HARDENED OS VM TESTING SETUP ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "STEP 1: DOWNLOAD VIRTUALBOX" -ForegroundColor Yellow
Write-Host "  1. Go to: https://www.virtualbox.org/wiki/Downloads"
Write-Host "  2. Download 'VirtualBox for Windows hosts'"
Write-Host "  3. Install with default settings"
Write-Host ""

Write-Host "STEP 2: DOWNLOAD DEBIAN ISO" -ForegroundColor Yellow
Write-Host "  1. Go to: https://www.debian.org/CD/netinst/"
Write-Host "  2. Download 'debian-12.x.x-amd64-netinst.iso'"
Write-Host "  3. Save to Downloads folder"
Write-Host ""

Write-Host "STEP 3: CHECK SYSTEM REQUIREMENTS" -ForegroundColor Yellow

# Check available RAM
$totalRAM = [math]::Round((Get-ComputerInfo).TotalPhysicalMemory / 1GB, 2)
if ($totalRAM -ge 16) {
    Write-Host "  ✓ RAM: $totalRAM GB - Excellent for VM" -ForegroundColor Green
} elseif ($totalRAM -ge 12) {
    Write-Host "  ✓ RAM: $totalRAM GB - Good for VM" -ForegroundColor Green
} elseif ($totalRAM -ge 8) {
    Write-Host "  ⚠ RAM: $totalRAM GB - Minimum for VM" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ RAM: $totalRAM GB - May be insufficient" -ForegroundColor Red
}

# Check free disk space
$freeSpace = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB, 2)
if ($freeSpace -ge 100) {
    Write-Host "  ✓ Free Space: $freeSpace GB - Sufficient" -ForegroundColor Green
} elseif ($freeSpace -ge 50) {
    Write-Host "  ⚠ Free Space: $freeSpace GB - Tight but workable" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ Free Space: $freeSpace GB - Insufficient" -ForegroundColor Red
}

# Check virtualization support
$cpu = Get-WmiObject -Class Win32_Processor
$virtSupport = $cpu.VirtualizationFirmwareEnabled
if ($virtSupport) {
    Write-Host "  ✓ Virtualization: Enabled" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Virtualization: May need BIOS enable" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "STEP 4: VM CONFIGURATION RECOMMENDATIONS" -ForegroundColor Yellow
Write-Host "  VM Name: Hardened-OS-Test"
Write-Host "  Type: Linux / Debian (64-bit)"
Write-Host "  RAM: 8192 MB (or 16384 MB if available)"
Write-Host "  Disk: 80 GB (dynamically allocated)"
Write-Host "  Enable EFI: ✓ Yes"
Write-Host "  Enable TPM: ✓ Yes (if available)"
Write-Host ""

Write-Host "STEP 5: AFTER VM CREATION" -ForegroundColor Yellow
Write-Host "  1. Mount Debian ISO to VM CD/DVD"
Write-Host "  2. Start VM and install Debian"
Write-Host "  3. Install git and clone Hardened OS repository"
Write-Host "  4. Run: bash scripts/install-hardened-os.sh --vm-mode"
Write-Host ""

Write-Host "BENEFITS OF VM TESTING:" -ForegroundColor Green
Write-Host "  ✓ Zero risk to current system" -ForegroundColor Green
Write-Host "  ✓ Test all security features safely" -ForegroundColor Green
Write-Host "  ✓ Learn interface before committing" -ForegroundColor Green
Write-Host "  ✓ Identify issues early" -ForegroundColor Green
Write-Host "  ✓ Take snapshots for easy rollback" -ForegroundColor Green

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Install VirtualBox"
Write-Host "  2. Download Debian ISO"
Write-Host "  3. Create VM with recommended settings"
Write-Host "  4. Follow VM_INSTALLATION_GUIDE.md"

Write-Host ""
Write-Host "📖 Complete guide: VM_INSTALLATION_GUIDE.md" -ForegroundColor White