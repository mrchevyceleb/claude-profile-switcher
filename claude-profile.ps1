<#
.SYNOPSIS
    Claude Code Profile Switcher - Manage multiple Claude Code accounts

.DESCRIPTION
    Switch between personal and Teams (or other) Claude Code accounts seamlessly.
    Supports both credential switching and simultaneous isolated sessions.

.EXAMPLE
    claude-profile create personal
    claude-profile create teams
    claude-profile switch teams
    claude-profile launch personal  # Opens new terminal with isolated profile
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("create", "switch", "list", "current", "delete", "launch", "help")]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$ProfileName
)

# Configuration
$ProfilesDir = Join-Path $env:USERPROFILE ".claude-profiles"
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$CredentialsFile = Join-Path $ClaudeDir ".credentials.json"
$ActiveProfileFile = Join-Path $ProfilesDir ".active-profile"

# Ensure profiles directory exists
if (-not (Test-Path $ProfilesDir)) {
    New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null
}

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Get-ActiveProfile {
    if (Test-Path $ActiveProfileFile) {
        return (Get-Content $ActiveProfileFile -Raw).Trim()
    }
    return $null
}

function Set-ActiveProfile {
    param([string]$Name)
    $Name | Out-File -FilePath $ActiveProfileFile -NoNewline -Encoding UTF8
}

function Get-AllProfiles {
    $profiles = @()
    Get-ChildItem -Path $ProfilesDir -Directory | ForEach-Object {
        $credFile = Join-Path $_.FullName ".credentials.json"
        if (Test-Path $credFile) {
            $profiles += $_.Name
        }
    }
    return $profiles
}

function Get-TokenExpiry {
    param([string]$CredFilePath)

    if (-not (Test-Path $CredFilePath)) {
        return $null
    }

    try {
        $creds = Get-Content $CredFilePath -Raw | ConvertFrom-Json
        if ($creds.claudeAiOauth -and $creds.claudeAiOauth.expiresAt) {
            return $creds.claudeAiOauth.expiresAt
        }
    } catch {
        return $null
    }
    return $null
}

function Test-TokenExpired {
    param([long]$ExpiresAt)

    $now = [long]((Get-Date).ToUniversalTime() - [datetime]'1970-01-01T00:00:00Z').TotalMilliseconds
    return $now -gt $ExpiresAt
}

function Get-TimeUntilExpiry {
    param([long]$ExpiresAt)

    $now = [long]((Get-Date).ToUniversalTime() - [datetime]'1970-01-01T00:00:00Z').TotalMilliseconds
    $diffMs = $ExpiresAt - $now
    $diffHours = [math]::Round($diffMs / 3600000, 1)
    return $diffHours
}

function Invoke-TokenRefresh {
    param([string]$CredFilePath)

    if (-not (Test-Path $CredFilePath)) {
        return $false
    }

    try {
        $creds = Get-Content $CredFilePath -Raw | ConvertFrom-Json
        $refreshToken = $creds.claudeAiOauth.refreshToken

        if (-not $refreshToken) {
            Write-Color "No refresh token available" "Red"
            return $false
        }

        Write-Color "Refreshing token..." "Yellow"

        # Call Claude's OAuth refresh endpoint
        $body = @{
            grant_type = "refresh_token"
            refresh_token = $refreshToken
        }

        $response = Invoke-RestMethod -Uri "https://console.anthropic.com/v1/oauth/token" `
            -Method Post `
            -ContentType "application/x-www-form-urlencoded" `
            -Body $body `
            -ErrorAction Stop

        if ($response.access_token) {
            # Update credentials with new tokens
            $creds.claudeAiOauth.accessToken = $response.access_token
            if ($response.refresh_token) {
                $creds.claudeAiOauth.refreshToken = $response.refresh_token
            }
            # Calculate new expiry (response.expires_in is in seconds)
            $now = [long]((Get-Date).ToUniversalTime() - [datetime]'1970-01-01T00:00:00Z').TotalMilliseconds
            $creds.claudeAiOauth.expiresAt = $now + ($response.expires_in * 1000)

            # Save updated credentials
            $creds | ConvertTo-Json -Depth 10 | Set-Content $CredFilePath -Encoding UTF8

            Write-Color "Token refreshed successfully!" "Green"
            return $true
        }
    } catch {
        Write-Color "Token refresh failed: $($_.Exception.Message)" "Red"
        return $false
    }

    return $false
}

function Show-Help {
    Write-Color "`nClaude Code Profile Switcher" "Cyan"
    Write-Color "============================`n" "Cyan"

    Write-Host "Commands:"
    Write-Host "  create <name>   Save current credentials as a named profile"
    Write-Host "  switch <name>   Switch to a different profile"
    Write-Host "  list            Show all profiles (* = active)"
    Write-Host "  current         Show the active profile name"
    Write-Host "  delete <name>   Remove a profile"
    Write-Host "  launch <name>   Open new terminal with isolated profile (simultaneous use)"
    Write-Host "  help            Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Color "  claude-profile create personal" "Yellow"
    Write-Host "  # After logging into Teams account via /login:"
    Write-Color "  claude-profile create teams" "Yellow"
    Write-Color "  claude-profile switch personal" "Yellow"
    Write-Color "  claude-profile launch teams" "Yellow"
    Write-Host ""
}

function New-Profile {
    param([string]$Name)

    if (-not $Name) {
        Write-Color "Error: Profile name required" "Red"
        Write-Host "Usage: claude-profile create <name>"
        return
    }

    if (-not (Test-Path $CredentialsFile)) {
        Write-Color "Error: No Claude credentials found at $CredentialsFile" "Red"
        Write-Host "Please log into Claude Code first using /login"
        return
    }

    $profileDir = Join-Path $ProfilesDir $Name

    # Create profile directory
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Copy credentials
    $destCredFile = Join-Path $profileDir ".credentials.json"
    Copy-Item -Path $CredentialsFile -Destination $destCredFile -Force

    # Create .claude directory for isolated launch mode
    $isolatedClaudeDir = Join-Path $profileDir ".claude"
    if (-not (Test-Path $isolatedClaudeDir)) {
        New-Item -ItemType Directory -Path $isolatedClaudeDir -Force | Out-Null
        # Copy credentials there too for isolated mode
        Copy-Item -Path $CredentialsFile -Destination (Join-Path $isolatedClaudeDir ".credentials.json") -Force
    }

    # Set as active profile
    Set-ActiveProfile $Name

    Write-Color "Profile '$Name' created and set as active" "Green"
}

function Switch-Profile {
    param([string]$Name)

    if (-not $Name) {
        Write-Color "Error: Profile name required" "Red"
        Write-Host "Usage: claude-profile switch <name>"
        Write-Host "Available profiles:"
        Get-AllProfiles | ForEach-Object { Write-Host "  $_" }
        return
    }

    $profileDir = Join-Path $ProfilesDir $Name
    $profileCredFile = Join-Path $profileDir ".credentials.json"

    if (-not (Test-Path $profileCredFile)) {
        Write-Color "Error: Profile '$Name' not found" "Red"
        Write-Host "Available profiles:"
        Get-AllProfiles | ForEach-Object { Write-Host "  $_" }
        return
    }

    # Check token expiration
    $expiresAt = Get-TokenExpiry -CredFilePath $profileCredFile
    if ($expiresAt) {
        if (Test-TokenExpired -ExpiresAt $expiresAt) {
            Write-Color "`nWARNING: Token for profile '$Name' has EXPIRED!" "Red"
            Write-Color "The switch will likely fail. Please update this profile:" "Yellow"
            Write-Host "  1. Log into the $Name account in Claude Code (/login)"
            Write-Host "  2. Run: ccp create $Name"
            Write-Host ""
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                Write-Color "Switch cancelled." "Yellow"
                return
            }
        } else {
            $hoursLeft = Get-TimeUntilExpiry -ExpiresAt $expiresAt
            if ($hoursLeft -lt 2) {
                Write-Color "Note: Token expires in $hoursLeft hours" "Yellow"
            }
        }
    }

    # Save current credentials to active profile ONLY if they match (same refresh token)
    # This prevents corruption when user runs /login outside the profile switcher
    $currentProfile = Get-ActiveProfile
    if ($currentProfile -and (Test-Path $CredentialsFile)) {
        $currentProfileDir = Join-Path $ProfilesDir $currentProfile
        $currentCredFile = Join-Path $currentProfileDir ".credentials.json"
        if (Test-Path $currentCredFile) {
            try {
                $activeCreds = Get-Content $CredentialsFile -Raw | ConvertFrom-Json
                $profileCreds = Get-Content $currentCredFile -Raw | ConvertFrom-Json

                # Only save back if refresh tokens match (same account)
                $activeRefresh = $activeCreds.claudeAiOauth.refreshToken
                $profileRefresh = $profileCreds.claudeAiOauth.refreshToken

                if ($activeRefresh -and $profileRefresh -and $activeRefresh -eq $profileRefresh) {
                    # Same account - safe to save refreshed tokens back
                    Copy-Item -Path $CredentialsFile -Destination $currentCredFile -Force
                } else {
                    Write-Color "Note: Active credentials don't match '$currentProfile' profile (different account). Not saving back." "Yellow"
                }
            } catch {
                # If we can't parse credentials, skip the save-back
                Write-Color "Warning: Could not verify credentials, skipping save-back." "Yellow"
            }
        }
    }

    # Copy new profile credentials to Claude directory
    Copy-Item -Path $profileCredFile -Destination $CredentialsFile -Force

    # Update active profile
    Set-ActiveProfile $Name

    Write-Color "Switched to profile '$Name'" "Green"
    Write-Host "Restart Claude Code for changes to take effect"
}

function Show-Profiles {
    $profiles = Get-AllProfiles
    $active = Get-ActiveProfile

    if ($profiles.Count -eq 0) {
        Write-Color "No profiles found" "Yellow"
        Write-Host "Create one with: claude-profile create <name>"
        return
    }

    Write-Color "`nClaude Code Profiles:" "Cyan"
    Write-Host "---------------------"

    foreach ($profile in $profiles) {
        $profileDir = Join-Path $ProfilesDir $profile
        $profileCredFile = Join-Path $profileDir ".credentials.json"
        $expiresAt = Get-TokenExpiry -CredFilePath $profileCredFile

        $status = ""
        $color = "White"

        if ($expiresAt) {
            if (Test-TokenExpired -ExpiresAt $expiresAt) {
                $status = " [EXPIRED]"
                $color = "Red"
            } else {
                $hoursLeft = Get-TimeUntilExpiry -ExpiresAt $expiresAt
                if ($hoursLeft -lt 2) {
                    $status = " [expires in ${hoursLeft}h]"
                    $color = "Yellow"
                } elseif ($hoursLeft -lt 12) {
                    $status = " [${hoursLeft}h left]"
                    $color = "White"
                }
            }
        }

        if ($profile -eq $active) {
            Write-Color "  * $profile (active)$status" $(if ($color -eq "Red") { "Red" } else { "Green" })
        } else {
            Write-Color "    $profile$status" $color
        }
    }
    Write-Host ""
}

function Show-Current {
    $active = Get-ActiveProfile

    if ($active) {
        Write-Host $active
    } else {
        Write-Color "No active profile" "Yellow"
    }
}

function Remove-Profile {
    param([string]$Name)

    if (-not $Name) {
        Write-Color "Error: Profile name required" "Red"
        Write-Host "Usage: claude-profile delete <name>"
        return
    }

    $profileDir = Join-Path $ProfilesDir $Name

    if (-not (Test-Path $profileDir)) {
        Write-Color "Error: Profile '$Name' not found" "Red"
        return
    }

    $active = Get-ActiveProfile
    if ($Name -eq $active) {
        Write-Color "Warning: Deleting active profile" "Yellow"
        Remove-Item $ActiveProfileFile -ErrorAction SilentlyContinue
    }

    Remove-Item -Path $profileDir -Recurse -Force
    Write-Color "Profile '$Name' deleted" "Green"
}

function Start-IsolatedSession {
    param([string]$Name)

    if (-not $Name) {
        Write-Color "Error: Profile name required" "Red"
        Write-Host "Usage: claude-profile launch <name>"
        return
    }

    $profileDir = Join-Path $ProfilesDir $Name
    $isolatedClaudeDir = Join-Path $profileDir ".claude"
    $profileCredFile = Join-Path $profileDir ".credentials.json"

    if (-not (Test-Path $profileCredFile)) {
        Write-Color "Error: Profile '$Name' not found" "Red"
        return
    }

    # Ensure isolated .claude directory exists with credentials
    if (-not (Test-Path $isolatedClaudeDir)) {
        New-Item -ItemType Directory -Path $isolatedClaudeDir -Force | Out-Null
    }

    # Copy/update credentials in isolated directory
    $isolatedCredFile = Join-Path $isolatedClaudeDir ".credentials.json"
    Copy-Item -Path $profileCredFile -Destination $isolatedCredFile -Force

    # Create a temporary home directory structure
    $tempHome = Join-Path $ProfilesDir "$Name-home"
    if (-not (Test-Path $tempHome)) {
        New-Item -ItemType Directory -Path $tempHome -Force | Out-Null
    }

    # Create .claude directory in temp home
    $tempClaudeDir = Join-Path $tempHome ".claude"
    if (-not (Test-Path $tempClaudeDir)) {
        New-Item -ItemType Directory -Path $tempClaudeDir -Force | Out-Null
    }

    # Copy credentials to temp home's .claude directory
    Copy-Item -Path $profileCredFile -Destination (Join-Path $tempClaudeDir ".credentials.json") -Force

    # Copy essential settings if they exist
    $sourceSettings = Join-Path $ClaudeDir "settings.json"
    if (Test-Path $sourceSettings) {
        Copy-Item -Path $sourceSettings -Destination (Join-Path $tempClaudeDir "settings.json") -Force
    }

    Write-Color "Launching isolated Claude Code session for profile '$Name'..." "Cyan"

    # Launch new PowerShell with modified USERPROFILE
    $script = @"
`$env:USERPROFILE = '$tempHome'
`$env:HOME = '$tempHome'
`$env:CLAUDE_PROFILE = '$Name'
Write-Host ''
Write-Host '=======================================' -ForegroundColor Cyan
Write-Host '  Claude Code - Profile: $Name' -ForegroundColor Cyan
Write-Host '=======================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'This is an isolated session. Run claude to start.' -ForegroundColor Yellow
Write-Host ''
"@

    # Start new PowerShell window
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $script

    Write-Color "New terminal window opened with profile '$Name'" "Green"
}

# Main command dispatcher
switch ($Command) {
    "create" { New-Profile -Name $ProfileName }
    "switch" { Switch-Profile -Name $ProfileName }
    "list"   { Show-Profiles }
    "current" { Show-Current }
    "delete" { Remove-Profile -Name $ProfileName }
    "launch" { Start-IsolatedSession -Name $ProfileName }
    "help"   { Show-Help }
    default  { Show-Help }
}
