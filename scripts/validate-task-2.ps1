# Task 2 Validation Script (PowerShell)
# Validates the implementation of development signing keys and recovery infrastructure

# Colors for output
function Write-Pass { param($Message) Write-Host "[PASS] $Message" -ForegroundColor Green }
function Write-Fail { param($Message) Write-Host "[FAIL] $Message" -ForegroundColor Red }
function Write-Test { param($Message) Write-Host "[TEST] $Message" -ForegroundColor Blue }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Yellow }

$TestsPassed = 0
$TestsFailed = 0

function Test-Pass { $script:TestsPassed++ }
function Test-Fail { $script:TestsFailed++ }

Write-Host "========================================" -ForegroundColor Blue
Write-Host "    Task 2 Implementation Validation   " -ForegroundColor Blue  
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Test 1: Directory structure from Task 1
Write-Test "Testing harden directory structure..."
$HardenDir = "$env:USERPROFILE\harden"
$RequiredDirs = @("keys", "src", "build", "ci", "artifacts")

if (Test-Path $HardenDir) {
    Write-Pass "Base harden directory exists: $HardenDir"
    Test-Pass
    
    foreach ($Dir in $RequiredDirs) {
        $FullPath = Join-Path $HardenDir $Dir
        if (Test-Path $FullPath) {
            Write-Pass "Directory exists: $Dir"
            Test-Pass
        } else {
            Write-Fail "Directory missing: $Dir"
            Test-Fail
        }
    }
} else {
    Write-Fail "Base harden directory missing: $HardenDir"
    Write-Info "Run Task 1 first to create directory structure"
    Test-Fail
}

Write-Host ""

# Test 2: Script files
Write-Test "Testing script files..."
$ScriptFiles = @(
    "scripts\generate-dev-keys.sh",
    "scripts\create-recovery-infrastructure.sh", 
    "scripts\key-manager.sh",
    "scripts\key-manager.ps1"
)

foreach ($Script in $ScriptFiles) {
    if (Test-Path $Script) {
        Write-Pass "Script exists: $Script"
        Test-Pass
        
        # Check file size
        $FileInfo = Get-Item $Script
        if ($FileInfo.Length -gt 0) {
            Write-Pass "Script has content: $Script ($($FileInfo.Length) bytes)"
            Test-Pass
        } else {
            Write-Fail "Script is empty: $Script"
            Test-Fail
        }
    } else {
        Write-Fail "Script missing: $Script"
        Test-Fail
    }
}

Write-Host ""

# Test 3: Documentation files
Write-Test "Testing documentation files..."
$DocFiles = @(
    "docs\key-management.md",
    "docs\task-2-implementation.md"
)

foreach ($Doc in $DocFiles) {
    if (Test-Path $Doc) {
        Write-Pass "Documentation exists: $Doc"
        Test-Pass
        
        # Check file size
        $FileInfo = Get-Item $Doc
        if ($FileInfo.Length -gt 1000) {  # Should be substantial documentation
            Write-Pass "Documentation has substantial content: $Doc ($($FileInfo.Length) bytes)"
            Test-Pass
        } else {
            Write-Fail "Documentation seems too short: $Doc ($($FileInfo.Length) bytes)"
            Test-Fail
        }
    } else {
        Write-Fail "Documentation missing: $Doc"
        Test-Fail
    }
}

Write-Host ""

# Test 4: PowerShell key manager functionality
Write-Test "Testing PowerShell key manager..."
if (Test-Path "scripts\key-manager.ps1") {
    try {
        # Test help command
        $HelpOutput = & ".\scripts\key-manager.ps1" "help" 2>&1
        if ($HelpOutput -match "Key Management Utility") {
            Write-Pass "PowerShell key manager help works"
            Test-Pass
        } else {
            Write-Fail "PowerShell key manager help failed"
            Test-Fail
        }
    } catch {
        Write-Fail "PowerShell key manager execution failed: $($_.Exception.Message)"
        Test-Fail
    }
    
    # Check for required functions in the script
    $ScriptContent = Get-Content "scripts\key-manager.ps1" -Raw
    $RequiredFunctions = @("Invoke-Generate", "Show-Status", "Invoke-Backup", "Invoke-Restore")
    
    foreach ($Function in $RequiredFunctions) {
        if ($ScriptContent -match "function $Function") {
            Write-Pass "PowerShell function exists: $Function"
            Test-Pass
        } else {
            Write-Fail "PowerShell function missing: $Function"
            Test-Fail
        }
    }
} else {
    Write-Fail "PowerShell key manager not found"
    Test-Fail
}

Write-Host ""

# Test 5: Security configurations in scripts
Write-Test "Testing security configurations..."

# Check bash scripts for security settings
$BashScripts = @("scripts\generate-dev-keys.sh", "scripts\key-manager.sh")
foreach ($Script in $BashScripts) {
    if (Test-Path $Script) {
        $Content = Get-Content $Script -Raw
        
        if ($Content -match "chmod 600") {
            Write-Pass "Script sets secure file permissions (600): $(Split-Path $Script -Leaf)"
            Test-Pass
        } else {
            Write-Fail "Script missing secure file permissions: $(Split-Path $Script -Leaf)"
            Test-Fail
        }
        
        if ($Content -match "DEVELOPMENT.*NOT.*PRODUCTION") {
            Write-Pass "Script includes development warnings: $(Split-Path $Script -Leaf)"
            Test-Pass
        } else {
            Write-Fail "Script missing development warnings: $(Split-Path $Script -Leaf)"
            Test-Fail
        }
    }
}

Write-Host ""

# Test 6: Key management documentation content
Write-Test "Testing key management documentation content..."
if (Test-Path "docs\key-management.md") {
    $DocContent = Get-Content "docs\key-management.md" -Raw
    
    $RequiredSections = @(
        "Key Hierarchy",
        "Key Generation Procedures", 
        "Signing Procedures",
        "Key Backup and Recovery",
        "Security Considerations"
    )
    
    foreach ($Section in $RequiredSections) {
        if ($DocContent -match $Section) {
            Write-Pass "Documentation section exists: $Section"
            Test-Pass
        } else {
            Write-Fail "Documentation section missing: $Section"
            Test-Fail
        }
    }
} else {
    Write-Fail "Key management documentation not found"
    Test-Fail
}

Write-Host ""

# Test 7: Recovery infrastructure components
Write-Test "Testing recovery infrastructure script content..."
if (Test-Path "scripts\create-recovery-infrastructure.sh") {
    $RecoveryContent = Get-Content "scripts\create-recovery-infrastructure.sh" -Raw
    
    $RequiredComponents = @(
        "create_recovery_kernel_config",
        "create_recovery_boot_script",
        "create_grub_recovery_config",
        "sign_recovery_components"
    )
    
    foreach ($Component in $RequiredComponents) {
        if ($RecoveryContent -match $Component) {
            Write-Pass "Recovery component exists: $Component"
            Test-Pass
        } else {
            Write-Fail "Recovery component missing: $Component"
            Test-Fail
        }
    }
} else {
    Write-Fail "Recovery infrastructure script not found"
    Test-Fail
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Blue
Write-Host "           Validation Summary           " -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Tests Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $TestsFailed" -ForegroundColor Red

if ($TestsFailed -eq 0) {
    Write-Host "All validations passed! Task 2 implementation is complete." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Review the implementation documentation in docs\task-2-implementation.md"
    Write-Host "2. Test key generation: .\scripts\key-manager.ps1 generate"
    Write-Host "3. Proceed to Task 3: Set up Debian stable base system"
    exit 0
} else {
    Write-Host "Some validations failed. Please review the implementation." -ForegroundColor Red
    exit 1
}