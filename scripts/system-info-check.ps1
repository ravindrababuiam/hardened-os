# System Information Check for Hardened OS Installation

Write-Host "=== SYSTEM COMPATIBILITY CHECK ===" -ForegroundColor Cyan
Write-Host ""

# Basic System Information
Write-Host "SYSTEM INFORMATION:" -ForegroundColor Yellow
$computerInfo = Get-ComputerInfo -Property CsName,CsModel,CsManufacturer,TotalPhysicalMemory,BiosFirmwareType

Write-Host "  Computer: $($computerInfo.CsName)"
Write-Host "  Model: $($computerInfo.CsModel)"
Write-Host "  Manufacturer: $($computerInfo.CsManufacturer)"
Write-Host "  Total RAM: $([math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)) GB"
Write-Host ""

# Firmware Type Check
Write-Host "FIRMWARE CHECK:" -ForegroundColor Yellow
$firmwareType = $computerInfo.BiosFirmwareType
if ($firmwareType -eq "Uefi") {
    Write-Host "  ✓ UEFI firmware detected" -ForegroundColor Green
} else {
    Write-Host "  ✗ Legacy BIOS detected - UEFI required for Hardened OS" -ForegroundColor Red
}
Write-Host ""

# Memory Check
Write-Host "MEMORY CHECK:" -ForegroundColor Yellow
$totalRAM = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
if ($totalRAM -ge 16) {
    Write-Host "  ✓ $totalRAM GB RAM - Excellent for Hardened OS" -ForegroundColor Green
} elseif ($totalRAM -ge 8) {
    Write-Host "  ✓ $totalRAM GB RAM - Good for Hardened OS" -ForegroundColor Green
} elseif ($totalRAM -ge 4) {
    Write-Host "  ⚠ $totalRAM GB RAM - Minimum (installation may be slow)" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ $totalRAM GB RAM - Insufficient for Hardened OS" -ForegroundColor Red
}
Write-Host ""

# Disk Information
Write-Host "STORAGE INFORMATION:" -ForegroundColor Yellow
$disks = Get-Disk | Where-Object { $_.BusType -ne "USB" }
foreach ($disk in $disks) {
    $sizeGB = [math]::Round($disk.Size / 1GB, 2)
    Write-Host "  Disk $($disk.Number): $sizeGB GB ($($disk.BusType))"
    if ($sizeGB -ge 250) {
        Write-Host "    ✓ Sufficient storage for Hardened OS" -ForegroundColor Green
    } else {
        Write-Host "    ⚠ May be too small for Hardened OS (250GB+ recommended)" -ForegroundColor Yellow
    }
}
Write-Host ""

# TPM Check
Write-Host "TPM CHECK:" -ForegroundColor Yellow
$tpmPresent = $false
if (Get-Command "Get-Tpm" -ErrorAction SilentlyContinue) {
    $tpm = Get-Tpm -ErrorAction SilentlyContinue
    if ($tpm -and $tpm.TpmPresent) {
        Write-Host "  ✓ TPM detected" -ForegroundColor Green
        Write-Host "    Enabled: $($tpm.TpmEnabled)"
        Write-Host "    Ready: $($tpm.TpmReady)"
        $tpmPresent = $true
    } else {
        Write-Host "  ⚠ No TPM detected (some security features will be limited)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠ Cannot check TPM status" -ForegroundColor Yellow
}
Write-Host ""

# Network Adapters
Write-Host "NETWORK ADAPTERS:" -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    Write-Host "  ✓ $($adapter.Name): $($adapter.InterfaceDescription)" -ForegroundColor Green
}
Write-Host ""

# Overall Compatibility
Write-Host "COMPATIBILITY ASSESSMENT:" -ForegroundColor Cyan
$compatible = $true
$warnings = @()

if ($firmwareType -ne "Uefi") {
    $compatible = $false
    Write-Host "  ✗ CRITICAL: UEFI firmware required" -ForegroundColor Red
}

if ($totalRAM -lt 8) {
    $warnings += "Low memory may cause slow installation"
    Write-Host "  ⚠ WARNING: Low memory ($totalRAM GB)" -ForegroundColor Yellow
}

if (-not $tpmPresent) {
    $warnings += "No TPM detected - some security features limited"
    Write-Host "  ⚠ WARNING: No TPM detected" -ForegroundColor Yellow
}

if ($compatible) {
    Write-Host "  ✓ System appears compatible with Hardened OS" -ForegroundColor Green
} else {
    Write-Host "  ✗ System NOT compatible with Hardened OS" -ForegroundColor Red
}

Write-Host ""
Write-Host "CRITICAL WARNINGS:" -ForegroundColor Red
Write-Host "  🚨 COMPLETE DATA LOSS: Installation will WIPE ALL DATA" -ForegroundColor Red
Write-Host "  🚨 IRREVERSIBLE: Cannot easily undo installation" -ForegroundColor Red
Write-Host "  🚨 WINDOWS REMOVAL: Current Windows system will be deleted" -ForegroundColor Red
Write-Host "  🚨 HARDWARE RISK: Some components may not work with Linux" -ForegroundColor Red

Write-Host ""
Write-Host "REQUIRED PREPARATIONS:" -ForegroundColor Yellow
Write-Host "  1. ✓ Create COMPLETE backup of all important data" -ForegroundColor White
Write-Host "  2. ✓ Create Windows recovery media (USB/DVD)" -ForegroundColor White
Write-Host "  3. ✓ Document software licenses and settings" -ForegroundColor White
Write-Host "  4. ✓ Test Hardened OS in virtual machine first" -ForegroundColor White
Write-Host "  5. ✓ Have alternative computer available" -ForegroundColor White
Write-Host "  6. ✓ Ensure stable power supply during installation" -ForegroundColor White

Write-Host ""
if ($compatible) {
    Write-Host "NEXT STEPS (if you choose to proceed):" -ForegroundColor Green
    Write-Host "  1. Complete all preparations above" -ForegroundColor White
    Write-Host "  2. Boot from Linux live USB" -ForegroundColor White
    Write-Host "  3. Run Hardened OS installation script" -ForegroundColor White
} else {
    Write-Host "RECOMMENDATION: System not suitable for Hardened OS installation" -ForegroundColor Red
}