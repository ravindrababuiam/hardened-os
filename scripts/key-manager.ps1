# Key Management Utility for Hardened OS (PowerShell Version)
# Provides unified interface for key operations on Windows

param(
    [Parameter(Position=0)]
    [ValidateSet("generate", "status", "backup", "restore", "enroll", "sign", "verify", "rotate", "clean", "help")]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$Target,
    
    [switch]$Force,
    [switch]$VerboseOutput
)

# Configuration
$KeysDir = "$env:USERPROFILE\harden\keys"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Colors for output (Windows PowerShell compatible)
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Header { param($Message) Write-Host $Message -ForegroundColor Blue }

# Show usage information
function Show-Usage {
    @"
Key Management Utility for Hardened OS (Windows)

Usage: .\key-manager.ps1 <command> [options]

Commands:
  generate        Generate new development keys
  status          Show key status and information
  backup          Create encrypted key backup
  restore         Restore keys from backup
  enroll          Enroll keys in UEFI firmware
  sign            Sign boot components
  verify          Verify signatures
  rotate          Rotate keys (emergency procedure)
  clean           Clean up old keys and backups
  help            Show this help message

Options:
  -Force          Force operation without confirmation
  -Verbose        Enable verbose output

Examples:
  .\key-manager.ps1 generate                    # Generate new development keys
  .\key-manager.ps1 status                      # Show current key status
  .\key-manager.ps1 backup                      # Create encrypted backup
  .\key-manager.ps1 sign C:\boot\vmlinuz       # Sign kernel
  .\key-manager.ps1 verify C:\boot\vmlinuz     # Verify kernel signature

Note: This is the Windows PowerShell version. For Linux systems, use key-manager.sh
"@
}

# Check if keys exist
function Test-KeysExist {
    if (-not (Test-Path "$KeysDir\dev")) {
        Write-Error "Development keys not found. Run '.\key-manager.ps1 generate' first."
        return $false
    }
    
    $RequiredFiles = @(
        "$KeysDir\dev\PK\PK.key",
        "$KeysDir\dev\KEK\KEK.key",
        "$KeysDir\dev\DB\DB.key"
    )
    
    foreach ($File in $RequiredFiles) {
        if (-not (Test-Path $File)) {
            Write-Error "Required key file missing: $File"
            return $false
        }
    }
    
    return $true
}

# Generate keys
function Invoke-Generate {
    Write-Header "Generating Development Keys"
    
    if ((Test-Path "$KeysDir\dev") -and -not $Force) {
        Write-Warn "Development keys already exist!"
        $Confirm = Read-Host "Overwrite existing keys? (y/N)"
        if ($Confirm -notmatch "^[Yy]$") {
            Write-Info "Key generation cancelled"
            return
        }
        
        # Backup existing keys
        $BackupDir = "$KeysDir\backup\replaced_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Move-Item "$KeysDir\dev" $BackupDir
        Write-Info "Existing keys backed up to: $BackupDir"
    }
    
    Write-Info "Calling Linux key generation script..."
    Write-Warn "Note: This requires WSL or Linux environment for OpenSSL and efitools"
    Write-Info "Run: wsl bash $ScriptDir/generate-dev-keys.sh"
}

# Show key status
function Show-Status {
    Write-Header "Key Status Information"
    
    if (-not (Test-KeysExist)) {
        return
    }
    
    Write-Host ""
    Write-Info "Key Directory: $KeysDir\dev"
    Write-Host ""
    
    # Show key metadata if available
    $MetadataFile = "$KeysDir\dev\key_metadata.json"
    if (Test-Path $MetadataFile) {
        Write-Info "Key Metadata:"
        Get-Content $MetadataFile | ConvertFrom-Json | ConvertTo-Json -Depth 10
        Write-Host ""
    }
    
    # Show key file information
    Write-Info "Key Files:"
    foreach ($KeyType in @("PK", "KEK", "DB")) {
        $KeyDir = "$KeysDir\dev\$KeyType"
        if (Test-Path $KeyDir) {
            Write-Host "  ${KeyType}:"
            Get-ChildItem $KeyDir -Filter "*.key" | ForEach-Object { Write-Host "    $($_.Name) - $($_.Length) bytes - $($_.LastWriteTime)" }
            Get-ChildItem $KeyDir -Filter "*.crt" | ForEach-Object { Write-Host "    $($_.Name) - $($_.Length) bytes - $($_.LastWriteTime)" }
            Write-Host ""
        }
    }
    
    # Check Windows Secure Boot status
    Write-Info "Secure Boot Status:"
    try {
        $SecureBoot = Confirm-SecureBootUEFI
        if ($SecureBoot) {
            Write-Host "  Secure Boot: Enabled" -ForegroundColor Green
        } else {
            Write-Host "  Secure Boot: Disabled" -ForegroundColor Red
        }
    } catch {
        Write-Host "  Unable to determine Secure Boot state (requires UEFI system)"
    }
}

# Create backup
function Invoke-Backup {
    Write-Header "Creating Key Backup"
    
    if (-not (Test-KeysExist)) {
        return
    }
    
    $BackupDir = "$KeysDir\backup"
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupFile = "$BackupDir\dev_keys_backup_$Timestamp.zip"
    
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    
    Write-Info "Creating backup archive..."
    
    try {
        # Create ZIP backup
        Compress-Archive -Path "$KeysDir\dev" -DestinationPath $BackupFile -Force
        
        # Create checksum
        $Hash = Get-FileHash $BackupFile -Algorithm SHA256
        $Hash.Hash | Out-File "$BackupFile.sha256" -Encoding ASCII
        
        Write-Info "Backup created: $BackupFile"
        Write-Info "Checksum created: $BackupFile.sha256"
        Write-Warn "Consider encrypting the backup file for additional security"
    } catch {
        Write-Error "Backup creation failed: $($_.Exception.Message)"
    }
}

# Restore from backup
function Invoke-Restore {
    Write-Header "Restoring Keys from Backup"
    
    $BackupDir = "$KeysDir\backup"
    
    if (-not (Test-Path $BackupDir)) {
        Write-Error "Backup directory not found: $BackupDir"
        return
    }
    
    # List available backups
    Write-Info "Available backups:"
    $Backups = Get-ChildItem "$BackupDir\*.zip" | Sort-Object LastWriteTime -Descending
    for ($i = 0; $i -lt $Backups.Count; $i++) {
        Write-Host "  $($i + 1). $($Backups[$i].Name) - $($Backups[$i].LastWriteTime)"
    }
    
    if ($Backups.Count -eq 0) {
        Write-Error "No backups found"
        return
    }
    
    $Selection = Read-Host "Enter backup number (1-$($Backups.Count))"
    try {
        $SelectedBackup = $Backups[$Selection - 1]
    } catch {
        Write-Error "Invalid selection"
        return
    }
    
    $BackupFile = $SelectedBackup.FullName
    
    # Verify checksum if available
    if (Test-Path "$BackupFile.sha256") {
        Write-Info "Verifying backup integrity..."
        $StoredHash = Get-Content "$BackupFile.sha256"
        $CurrentHash = (Get-FileHash $BackupFile -Algorithm SHA256).Hash
        
        if ($StoredHash -eq $CurrentHash) {
            Write-Info "Backup integrity verified"
        } else {
            Write-Error "Backup integrity check failed!"
            return
        }
    }
    
    # Backup existing keys if they exist
    if (Test-Path "$KeysDir\dev") {
        $OldBackup = "$KeysDir\backup\replaced_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $OldBackup -Force | Out-Null
        Move-Item "$KeysDir\dev" $OldBackup
        Write-Info "Existing keys backed up to: $OldBackup"
    }
    
    # Restore from backup
    Write-Info "Restoring keys..."
    try {
        Expand-Archive -Path $BackupFile -DestinationPath $KeysDir -Force
        Write-Info "Keys restored successfully"
    } catch {
        Write-Error "Key restoration failed: $($_.Exception.Message)"
    }
}

# Main command dispatcher
switch ($Command) {
    "generate" { Invoke-Generate }
    "status" { Show-Status }
    "backup" { Invoke-Backup }
    "restore" { Invoke-Restore }
    "enroll" { 
        Write-Warn "Key enrollment requires Linux tools (efi-updatevar)"
        Write-Info "Use WSL: wsl sudo efi-updatevar -f ~/harden/keys/dev/PK/PK.auth PK"
    }
    "sign" { 
        if (-not $Target) {
            Write-Error "No file specified for signing"
            Write-Host "Usage: .\key-manager.ps1 sign <file>"
            return
        }
        Write-Warn "Signing requires Linux tools (sbsign)"
        Write-Info "Use WSL: wsl sbsign --key ~/harden/keys/dev/DB/DB.key --cert ~/harden/keys/dev/DB/DB.crt --output $Target.signed $Target"
    }
    "verify" { 
        if (-not $Target) {
            Write-Error "No file specified for verification"
            Write-Host "Usage: .\key-manager.ps1 verify <file>"
            return
        }
        Write-Warn "Verification requires Linux tools (sbverify)"
        Write-Info "Use WSL: wsl sbverify --cert ~/harden/keys/dev/DB/DB.crt $Target"
    }
    "rotate" { 
        Write-Header "Emergency Key Rotation"
        Write-Warn "This requires regenerating all keys and re-enrolling in UEFI"
        Write-Info "Use: .\key-manager.ps1 generate -Force"
    }
    "clean" { 
        Write-Header "Cleaning Up Old Keys and Backups"
        $BackupDir = "$KeysDir\backup"
        if (Test-Path $BackupDir) {
            $OldFiles = Get-ChildItem $BackupDir | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
            if ($OldFiles) {
                Write-Info "Removing $($OldFiles.Count) old backup files"
                $OldFiles | Remove-Item -Recurse -Force
            } else {
                Write-Info "No old backup files to remove"
            }
        }
    }
    "help" { Show-Usage }
    default { 
        if (-not $Command) {
            Write-Error "No command specified"
        } else {
            Write-Error "Unknown command: $Command"
        }
        Show-Usage
    }
}