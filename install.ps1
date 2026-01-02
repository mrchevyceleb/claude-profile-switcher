<#
.SYNOPSIS
    Installs Claude Profile Switcher

.DESCRIPTION
    Downloads and installs the Claude Profile Switcher tool for managing
    multiple Claude Code accounts on a single machine.

.EXAMPLE
    irm https://raw.githubusercontent.com/mtjohns/claude-profile-switcher/main/install.ps1 | iex
#>

Write-Host ""
Write-Host "Claude Profile Switcher - Installer" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ProfilesDir = Join-Path $env:USERPROFILE ".claude-profiles"
$ScriptUrl = "https://raw.githubusercontent.com/mrchevyceleb/claude-profile-switcher/main/claude-profile.ps1"
$ScriptPath = Join-Path $ProfilesDir "claude-profile.ps1"

# Step 1: Create profiles directory
Write-Host "[1/3] Creating profiles directory..." -ForegroundColor Yellow
if (-not (Test-Path $ProfilesDir)) {
    New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null
    Write-Host "      Created: $ProfilesDir" -ForegroundColor Green
} else {
    Write-Host "      Already exists: $ProfilesDir" -ForegroundColor Green
}

# Step 2: Download the script
Write-Host "[2/3] Downloading claude-profile.ps1..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath -UseBasicParsing
    Write-Host "      Downloaded to: $ScriptPath" -ForegroundColor Green
} catch {
    Write-Host "      ERROR: Failed to download script" -ForegroundColor Red
    Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Add to PowerShell profile
Write-Host "[3/3] Adding to PowerShell profile..." -ForegroundColor Yellow

$ProfileContent = @"

# Claude Code Profile Switcher
function claude-profile {
    & "`$env:USERPROFILE\.claude-profiles\claude-profile.ps1" @args
}
Set-Alias ccp claude-profile
"@

# Find the PowerShell profile
$ProfilePath = $PROFILE

# Create profile if it doesn't exist
if (-not (Test-Path $ProfilePath)) {
    $ProfileDir = Split-Path $ProfilePath -Parent
    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }
    New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    Write-Host "      Created new profile: $ProfilePath" -ForegroundColor Green
}

# Check if already installed
$ExistingContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
if ($ExistingContent -match "claude-profile") {
    Write-Host "      Already in profile (skipped)" -ForegroundColor Green
} else {
    Add-Content -Path $ProfilePath -Value $ProfileContent
    Write-Host "      Added to: $ProfilePath" -ForegroundColor Green
}

# Done
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell (or run: . `$PROFILE)"
Write-Host "  2. Log into Claude Code with your first account"
Write-Host "  3. Run: ccp create personal"
Write-Host "  4. Log into Claude Code with your second account"
Write-Host "  5. Run: ccp create teams"
Write-Host "  6. Switch anytime with: ccp switch personal"
Write-Host ""
Write-Host "Commands: ccp list | ccp switch <name> | ccp launch <name>" -ForegroundColor Yellow
Write-Host ""
