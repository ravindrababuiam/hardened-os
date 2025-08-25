Write-Host "=== HARDENED OS COMPATIBILITY CHECK ===" -ForegroundColor Cyan
Write-Host ""

# Get basic system info
$computerInfo = Get-ComputerInfo
$totalRAM = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
$firmwareType = $computerInfo.BiosFirmwareType

Write-Host "SYSTEM INFORMATION:" -ForegroundColor Yellow
Write-Host "  Computer: $($computerInfo.CsName)"
Write-Host "  Model: $($computerInfo.CsModel)"
Write-Host "  RAM: $totalRAM GB"
Write-Host "  Firmware: $firmwareType"
Write-Host ""

Write-Host "COMPATIBILITY CHECK:" -ForegroundColor Yellow

# Check UEFI
if ($firmwareType -eq "Uefi") {
    Write-Host "  ✓ UEFI firmware - Compatible" -ForegroundColor Green
    $uefiOK = $true
} else {
    Write-Host "  ✗ Legacy BIOS - NOT Compatible" -ForegroundColor Red
    $uefiOK = $false
}

# Check RAM
if ($totalRAM -ge 8) {
    Write-Host "  ✓ RAM ($totalRAM GB) - Sufficient" -ForegroundColor Green
    $ramOK = $true
} else {
    Write-Host "  ⚠ RAM ($totalRAM GB) - May be slow" -ForegroundColor Yellow
    $ramOK = $false
}

# Check disks
$disks = Get-Disk | Where-Object { $_.BusType -ne "USB" }
$largestDisk = ($disks | Measure-Object -Property Size -Maximum).Maximum / 1GB
Write-Host "  ✓ Storage: $([math]::Round($largestDisk, 0)) GB available" -ForegroundColor Green

Write-Host ""
Write-Host "🚨 CRITICAL WARNINGS:" -ForegroundColor Red
Write-Host "  • Installation will COMPLETELY WIPE this laptop" -ForegroundColor Red
Write-Host "  • ALL Windows data will be PERMANENTLY LOST" -ForegroundColor Red
Write-Host "  • ALL programs will be DELETED" -ForegroundColor Red
Write-Host "  • Process is IRREVERSIBLE without recovery media" -ForegroundColor Red

Write-Host ""
if ($uefiOK -and $ramOK) {
    Write-Host "RESULT: System appears compatible" -ForegroundColor Green
} elseif ($uefiOK) {
    Write-Host "RESULT: System may work with limitations" -ForegroundColor Yellow
} else {
    Write-Host "RESULT: System NOT compatible" -ForegroundColor Red
}

Write-Host ""
Write-Host "REQUIRED BEFORE INSTALLATION:" -ForegroundColor Yellow
Write-Host "  1. Backup ALL important data" -ForegroundColor White
Write-Host "  2. Create Windows recovery media" -ForegroundColor White
Write-Host "  3. Document licenses and settings" -ForegroundColor White
Write-Host "  4. Test in virtual machine first" -ForegroundColor White