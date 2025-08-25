# Windows Compatibility Check for Hardened OS Installation
# Checks current system compatibility before installation

Write-Host "=== HARDENED OS COMPATIBILITY CHECK ===" -ForegroundColor Cyan
Write-Host ""

# System Information
Write-Host "SYSTEM INFORMATION:" -ForegroundColor Yellow
$computerInfo = Get-ComputerInfo
Write-Host "  Computer: $($computerInfo.CsName)"
Write-Host "  Model: $($computerInfo.CsModel)"
Write-Host "  Manufacturer: $($computerInfo.CsManufacturer)"
Write-Host "  Architecture: $($computerInfo.CsProcessors[0].Architecture)"
Write-Host "  Total RAM: $([math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)) GB"
Write-Host ""

# UEFI Check
Write-Host "FIRMWARE CHECK:" -ForegroundColor Yellow
$firmwareType = $computerInfo.BiosFirmwareType
if ($firmwareType -eq "Uefi") {
    Write-Host "  ✓ UEFI firmware detected" -ForegroundColor Green
    $uefiSupported = $true
} else {
    Write-Host "  ✗ Legacy BIOS detected - UEFI required" -ForegroundColor Red
    $uefiSupported = $false
}

# Secure Boot Check
try {
    $secureBootState = Confirm-SecureBootUEFI
    if ($secureBootState) {
        Write-Host "  ✓ Secure Boot is enabled" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Secure Boot is disabled (can be enabled)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠ Cannot determine Secure Boot status" -ForegroundColor Yellow
}

# TPM Check
Write-Host ""
Write-Host "TPM CHECK:" -ForegroundColor Yellow
try {
    $tpm = Get-Tpm
    if ($tpm.TpmPresent) {
        Write-Host "  ✓ TPM detected" -ForegroundColor Green
        Write-Host "    Version: $($tpm.TpmVersion)"
        Write-Host "    Enabled: $($tpm.TpmEnabled)"
        Write-Host "    Activated: $($tpm.TpmActivated)"
        Write-Host "    Ready: $($tpm.TpmReady)"
    } else {
        Write-Host "  ✗ No TPM detected" -ForegroundColor Red
    }
} catch {
    Write-Host "  ⚠ Cannot access TPM information" -ForegroundColor Yellow
}

# Disk Information
Write-Host ""
Write-Host "STORAGE INFORMATION:" -ForegroundColor Yellow
$disks = Get-Disk | Where-Object { $_.BusType -ne "USB" }
foreach ($disk in $disks) {
    $sizeGB = [math]::Round($disk.Size / 1GB, 2)
    Write-Host "  Disk $($disk.Number): $($disk.Model) - $sizeGB GB ($($disk.BusType))"
    
    # Check partitions
    $partitions = Get-Partition -DiskNumber $disk.Number
    foreach ($partition in $partitions) {
        $sizeGB = [math]::Round($partition.Size / 1GB, 2)
        Write-Host "    Partition $($partition.PartitionNumber): $($partition.Type) - $sizeGB GB"
    }
}

# Memory Check
Write-Host ""
Write-Host "MEMORY CHECK:" -ForegroundColor Yellow
$totalRAM = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
if ($totalRAM -ge 16) {
    Write-Host "  ✓ $totalRAM GB RAM - Excellent" -ForegroundColor Green
} elseif ($totalRAM -ge 8) {
    Write-Host "  ✓ $totalRAM GB RAM - Good" -ForegroundColor Green
} elseif ($totalRAM -ge 4) {
    Write-Host "  ⚠ $totalRAM GB RAM - Minimum (may be slow)" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ $totalRAM GB RAM - Insufficient" -ForegroundColor Red
}

# Network Adapters
Write-Host ""
Write-Host "NETWORK ADAPTERS:" -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    Write-Host "  $($adapter.Name): $($adapter.InterfaceDescription)"
}

# BitLocker Check
Write-Host ""
Write-Host "ENCRYPTION STATUS:" -ForegroundColor Yellow
try {
    $bitlockerVolumes = Get-BitLockerVolume
    foreach ($volume in $bitlockerVolumes) {
        Write-Host "  Drive $($volume.MountPoint): $($volume.ProtectionStatus)"
    }
} catch {
    Write-Host "  Cannot determine BitLocker status"
}

# Compatibility Summary
Write-Host ""
Write-Host "COMPATIBILITY SUMMARY:" -ForegroundColor Cyan
if ($uefiSupported -and $totalRAM -ge 8) {
    Write-Host "  ✓ System appears compatible with Hardened OS" -ForegroundColor Green
} elseif ($uefiSupported) {
    Write-Host "  ⚠ System may work but with limitations" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ System not compatible - UEFI required" -ForegroundColor Red
}

Write-Host ""
Write-Host "IMPORTANT WARNINGS:" -ForegroundColor Red
Write-Host "  • Installation will COMPLETELY WIPE this system" -ForegroundColor Red
Write-Host "  • ALL data and programs will be permanently lost" -ForegroundColor Red
Write-Host "  • Windows recovery will require installation media" -ForegroundColor Red
Write-Host "  • Some hardware may not work with Linux" -ForegroundColor Red

Write-Host ""
Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
Write-Host "  1. Create complete system backup" -ForegroundColor White
Write-Host "  2. Create Windows recovery media" -ForegroundColor White
Write-Host "  3. Document important settings and licenses" -ForegroundColor White
Write-Host "  4. Test with virtual machine first" -ForegroundColor White
Write-Host "  5. Have alternative computer available during installation" -ForegroundColor White