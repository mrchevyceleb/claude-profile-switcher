<#
.SYNOPSIS
    Claude Code Profile Switcher v1.1 - Manage multiple Claude Code accounts

.DESCRIPTION
    Switch between personal and Teams (or other) Claude Code accounts seamlessly.
    Supports both credential switching and simultaneous isolated sessions.
    Includes debug logging and verification features.

.EXAMPLE
    claude-profile create personal
    claude-profile create teams
    claude-profile switch teams
    claude-profile verify           # Check current state
    claude-profile launch personal  # Opens new terminal with isolated profile
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("create", "switch", "list", "current", "delete", "launch", "verify", "help")]
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

function Write-Debug-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "Gray" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "DEBUG"   { "Cyan" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-AccountInfo {
    param([string]$CredFilePath)

    $info = @{
        Exists = $false
        SubscriptionType = "unknown"
        AccountType = "Unknown"
        TokenId = "N/A"
        ExpiresAt = $null
        IsExpired = $false
        HoursLeft = 0
        RateLimitTier = "unknown"
        FileHash = "N/A"
    }

    if (-not (Test-Path $CredFilePath)) {
        return $info
    }

    $info.Exists = $true

    try {
        # Get file hash for verification
        $info.FileHash = (Get-FileHash -Path $CredFilePath -Algorithm MD5).Hash.Substring(0, 8)

        $creds = Get-Content $CredFilePath -Raw | ConvertFrom-Json

        if ($creds.claudeAiOauth) {
            $oauth = $creds.claudeAiOauth

            # Subscription type
            if ($oauth.subscriptionType) {
                $info.SubscriptionType = $oauth.subscriptionType
                $info.AccountType = switch ($oauth.subscriptionType) {
                    "max"  { "Claude Max (Personal)" }
                    "team" { "Claude Team" }
                    "pro"  { "Claude Pro" }
                    "free" { "Claude Free" }
                    default { "Unknown ($($oauth.subscriptionType))" }
                }
            }

            # Rate limit tier
            if ($oauth.rateLimitTier) {
                $info.RateLimitTier = $oauth.rateLimitTier
            }

            # Token ID (last 8 chars of refresh token for identification)
            if ($oauth.refreshToken) {
                $info.TokenId = $oauth.refreshToken.Substring($oauth.refreshToken.Length - 8)
            }

            # Expiration
            if ($oauth.expiresAt) {
                $info.ExpiresAt = $oauth.expiresAt
                $now = [long]((Get-Date).ToUniversalTime() - [datetime]'1970-01-01T00:00:00Z').TotalMilliseconds
                $info.IsExpired = $now -gt $oauth.expiresAt
                $diffMs = $oauth.expiresAt - $now
                $info.HoursLeft = [math]::Round($diffMs / 3600000, 1)
            }
        }
    } catch {
        Write-Debug-Log "Failed to parse credentials: $($_.Exception.Message)" "ERROR"
    }

    return $info
}

function Show-AccountInfo {
    param(
        [string]$Label,
        [hashtable]$Info,
        [string]$FilePath = ""
    )

    Write-Host ""
    Write-Color "  $Label" "Cyan"
    Write-Host "  ----------------------------------------"

    if (-not $Info.Exists) {
        Write-Color "    No credentials found" "Yellow"
        if ($FilePath) {
            Write-Host "    Path: $FilePath" -ForegroundColor Gray
        }
        return
    }

    Write-Host "    Account Type:  " -NoNewline
    $typeColor = switch ($Info.SubscriptionType) {
        "max"  { "Magenta" }
        "team" { "Blue" }
        "pro"  { "Green" }
        default { "White" }
    }
    Write-Color $Info.AccountType $typeColor

    Write-Host "    Token ID:      " -NoNewline
    Write-Color "...$($Info.TokenId)" "Gray"

    Write-Host "    Rate Limit:    $($Info.RateLimitTier)"

    Write-Host "    File Hash:     " -NoNewline
    Write-Color $Info.FileHash "Gray"

    if ($Info.ExpiresAt) {
        Write-Host "    Token Status:  " -NoNewline
        if ($Info.IsExpired) {
            Write-Color "EXPIRED" "Red"
        } elseif ($Info.HoursLeft -lt 2) {
            Write-Color "Expires in $($Info.HoursLeft)h" "Yellow"
        } else {
            Write-Color "$($Info.HoursLeft)h remaining" "Green"
        }
    }

    if ($FilePath) {
        Write-Host "    Path:          " -NoNewline
        Write-Host $FilePath -ForegroundColor Gray
    }
}

function Get-ActiveProfile {
    if (Test-Path $ActiveProfileFile) {
        $content = Get-Content $ActiveProfileFile -Raw
        # Remove BOM and whitespace
        return $content -replace '^\xEF\xBB\xBF', '' -replace '^\s+', '' -replace '\s+$', ''
    }
    return $null
}

function Set-ActiveProfile {
    param([string]$Name)
    # Write without BOM
    [System.IO.File]::WriteAllText($ActiveProfileFile, $Name)
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
    Write-Color "`nClaude Code Profile Switcher v1.1" "Cyan"
    Write-Color "=================================`n" "Cyan"

    Write-Host "Commands:"
    Write-Host "  create <name>   Save current credentials as a named profile"
    Write-Host "  switch <name>   Switch to a different profile"
    Write-Host "  list            Show all profiles (* = active)"
    Write-Host "  current         Show the active profile name"
    Write-Host "  verify          Verify current state and show account details"
    Write-Host "  delete <name>   Remove a profile"
    Write-Host "  launch <name>   Open new terminal with isolated profile (simultaneous use)"
    Write-Host "  help            Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Color "  claude-profile create personal" "Yellow"
    Write-Host "  # After logging into Teams account via /login:"
    Write-Color "  claude-profile create teams" "Yellow"
    Write-Color "  claude-profile switch personal" "Yellow"
    Write-Color "  claude-profile verify" "Yellow"
    Write-Color "  claude-profile launch teams" "Yellow"
    Write-Host ""
    Write-Color "IMPORTANT: " "Red" -NoNewline
    Write-Host "You must restart Claude Code after switching profiles!"
    Write-Host "Claude Code caches credentials in memory at startup."
    Write-Host ""
}

function New-Profile {
    param([string]$Name)

    if (-not $Name) {
        Write-Color "Error: Profile name required" "Red"
        Write-Host "Usage: claude-profile create <name>"
        return
    }

    Write-Debug-Log "Creating profile '$Name'..." "INFO"

    if (-not (Test-Path $CredentialsFile)) {
        Write-Color "Error: No Claude credentials found at $CredentialsFile" "Red"
        Write-Host "Please log into Claude Code first using /login"
        return
    }

    # Show what we're saving
    $sourceInfo = Get-AccountInfo -CredFilePath $CredentialsFile
    Show-AccountInfo -Label "Credentials to save:" -Info $sourceInfo -FilePath $CredentialsFile

    $profileDir = Join-Path $ProfilesDir $Name

    # Create profile directory
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        Write-Debug-Log "Created profile directory: $profileDir" "DEBUG"
    }

    # Copy credentials
    $destCredFile = Join-Path $profileDir ".credentials.json"
    Copy-Item -Path $CredentialsFile -Destination $destCredFile -Force
    Write-Debug-Log "Copied credentials to profile" "DEBUG"

    # Create .claude directory for isolated launch mode
    $isolatedClaudeDir = Join-Path $profileDir ".claude"
    if (-not (Test-Path $isolatedClaudeDir)) {
        New-Item -ItemType Directory -Path $isolatedClaudeDir -Force | Out-Null
        # Copy credentials there too for isolated mode
        Copy-Item -Path $CredentialsFile -Destination (Join-Path $isolatedClaudeDir ".credentials.json") -Force
    }

    # Set as active profile
    Set-ActiveProfile $Name

    Write-Host ""
    Write-Color "Profile '$Name' created and set as active" "Green"
    Write-Debug-Log "Profile creation complete" "SUCCESS"
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

    Write-Host ""
    Write-Color "========================================" "Cyan"
    Write-Color "  PROFILE SWITCH: $Name" "Cyan"
    Write-Color "========================================" "Cyan"
    Write-Debug-Log "Starting profile switch to '$Name'" "INFO"

    $profileDir = Join-Path $ProfilesDir $Name
    $profileCredFile = Join-Path $profileDir ".credentials.json"

    if (-not (Test-Path $profileCredFile)) {
        Write-Color "Error: Profile '$Name' not found" "Red"
        Write-Host "Available profiles:"
        Get-AllProfiles | ForEach-Object { Write-Host "  $_" }
        return
    }

    # ===== BEFORE STATE =====
    Write-Host ""
    Write-Color "--- BEFORE SWITCH ---" "Yellow"

    $currentProfile = Get-ActiveProfile
    Write-Host "  Active Profile Marker: " -NoNewline
    if ($currentProfile) {
        Write-Color $currentProfile "White"
    } else {
        Write-Color "(none)" "Gray"
    }

    $beforeInfo = Get-AccountInfo -CredFilePath $CredentialsFile
    Show-AccountInfo -Label "Current Active Credentials:" -Info $beforeInfo -FilePath $CredentialsFile

    $targetInfo = Get-AccountInfo -CredFilePath $profileCredFile
    Show-AccountInfo -Label "Target Profile Credentials:" -Info $targetInfo -FilePath $profileCredFile

    # Check token expiration
    if ($targetInfo.Exists -and $targetInfo.IsExpired) {
        Write-Host ""
        Write-Color "WARNING: Token for profile '$Name' has EXPIRED!" "Red"
        Write-Color "The switch will likely fail. Please update this profile:" "Yellow"
        Write-Host "  1. Log into the $Name account in Claude Code (/login)"
        Write-Host "  2. Run: claude-profile create $Name"
        Write-Host ""
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Color "Switch cancelled." "Yellow"
            return
        }
    } elseif ($targetInfo.Exists -and $targetInfo.HoursLeft -lt 2) {
        Write-Color "`nNote: Token expires in $($targetInfo.HoursLeft) hours" "Yellow"
    }

    # Save current credentials to active profile ONLY if they match (same refresh token)
    if ($currentProfile -and (Test-Path $CredentialsFile)) {
        $currentProfileDir = Join-Path $ProfilesDir $currentProfile
        $currentCredFile = Join-Path $currentProfileDir ".credentials.json"
        if (Test-Path $currentCredFile) {
            try {
                $activeCreds = Get-Content $CredentialsFile -Raw | ConvertFrom-Json
                $profileCreds = Get-Content $currentCredFile -Raw | ConvertFrom-Json

                $activeRefresh = $activeCreds.claudeAiOauth.refreshToken
                $profileRefresh = $profileCreds.claudeAiOauth.refreshToken

                if ($activeRefresh -and $profileRefresh -and $activeRefresh -eq $profileRefresh) {
                    Copy-Item -Path $CredentialsFile -Destination $currentCredFile -Force
                    Write-Debug-Log "Saved updated tokens back to '$currentProfile' profile" "DEBUG"
                } else {
                    Write-Debug-Log "Active credentials don't match '$currentProfile' profile - not saving back" "WARN"
                }
            } catch {
                Write-Debug-Log "Could not verify credentials for save-back: $($_.Exception.Message)" "WARN"
            }
        }
    }

    # ===== PERFORM SWITCH =====
    Write-Host ""
    Write-Debug-Log "Copying credentials from profile to active location..." "INFO"
    Copy-Item -Path $profileCredFile -Destination $CredentialsFile -Force

    # Update active profile marker
    Set-ActiveProfile $Name
    Write-Debug-Log "Updated active profile marker to '$Name'" "DEBUG"

    # ===== AFTER STATE =====
    Write-Host ""
    Write-Color "--- AFTER SWITCH ---" "Yellow"

    $afterInfo = Get-AccountInfo -CredFilePath $CredentialsFile
    Show-AccountInfo -Label "New Active Credentials:" -Info $afterInfo -FilePath $CredentialsFile

    # ===== VERIFICATION =====
    Write-Host ""
    Write-Color "--- VERIFICATION ---" "Yellow"

    $hashMatch = $afterInfo.FileHash -eq $targetInfo.FileHash
    Write-Host "  File Hash Match: " -NoNewline
    if ($hashMatch) {
        Write-Color "YES" "Green"
    } else {
        Write-Color "NO - MISMATCH!" "Red"
    }

    $tokenMatch = $afterInfo.TokenId -eq $targetInfo.TokenId
    Write-Host "  Token ID Match:  " -NoNewline
    if ($tokenMatch) {
        Write-Color "YES (...$($afterInfo.TokenId))" "Green"
    } else {
        Write-Color "NO - Expected ...$($targetInfo.TokenId), got ...$($afterInfo.TokenId)" "Red"
    }

    Write-Host ""
    if ($hashMatch -and $tokenMatch) {
        Write-Color "SUCCESS: Switched to profile '$Name'" "Green"
        Write-Debug-Log "Profile switch completed successfully" "SUCCESS"
    } else {
        Write-Color "ERROR: Switch verification failed!" "Red"
        Write-Debug-Log "Profile switch verification failed" "ERROR"
    }

    Write-Host ""
    Write-Color "========================================" "Yellow"
    Write-Color "  IMPORTANT: RESTART CLAUDE CODE NOW!" "Yellow"
    Write-Color "========================================" "Yellow"
    Write-Host ""
    Write-Host "Claude Code caches credentials at startup."
    Write-Host "Run /exit in Claude, then start a new session."
    Write-Host ""
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
        $info = Get-AccountInfo -CredFilePath $profileCredFile

        $status = ""
        $color = "White"

        if ($info.Exists) {
            if ($info.IsExpired) {
                $status = " [EXPIRED]"
                $color = "Red"
            } elseif ($info.HoursLeft -lt 2) {
                $status = " [expires in $($info.HoursLeft)h]"
                $color = "Yellow"
            } elseif ($info.HoursLeft -lt 12) {
                $status = " [$($info.HoursLeft)h left]"
                $color = "White"
            }

            # Add account type
            $typeLabel = switch ($info.SubscriptionType) {
                "max"  { " (Max)" }
                "team" { " (Team)" }
                "pro"  { " (Pro)" }
                default { "" }
            }
            $status = $typeLabel + $status
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

function Show-Verify {
    Write-Host ""
    Write-Color "========================================" "Cyan"
    Write-Color "  PROFILE VERIFICATION" "Cyan"
    Write-Color "========================================" "Cyan"
    Write-Debug-Log "Running verification check..." "INFO"

    # Active profile marker
    $activeProfile = Get-ActiveProfile
    Write-Host ""
    Write-Host "  Active Profile Marker: " -NoNewline
    if ($activeProfile) {
        Write-Color $activeProfile "Green"
    } else {
        Write-Color "(none set)" "Yellow"
    }
    Write-Host "  Marker File: $ActiveProfileFile"

    # Active credentials
    $activeInfo = Get-AccountInfo -CredFilePath $CredentialsFile
    Show-AccountInfo -Label "Active Credentials (what Claude Code uses):" -Info $activeInfo -FilePath $CredentialsFile

    # Compare with active profile if set
    if ($activeProfile) {
        $profileDir = Join-Path $ProfilesDir $activeProfile
        $profileCredFile = Join-Path $profileDir ".credentials.json"

        if (Test-Path $profileCredFile) {
            $profileInfo = Get-AccountInfo -CredFilePath $profileCredFile
            Show-AccountInfo -Label "Profile '$activeProfile' Credentials:" -Info $profileInfo -FilePath $profileCredFile

            Write-Host ""
            Write-Color "  --- MATCH CHECK ---" "Yellow"

            $hashMatch = $activeInfo.FileHash -eq $profileInfo.FileHash
            Write-Host "    File Hash:    " -NoNewline
            if ($hashMatch) {
                Write-Color "MATCH" "Green"
            } else {
                Write-Color "MISMATCH" "Red"
            }

            $tokenMatch = $activeInfo.TokenId -eq $profileInfo.TokenId
            Write-Host "    Token ID:     " -NoNewline
            if ($tokenMatch) {
                Write-Color "MATCH" "Green"
            } else {
                Write-Color "MISMATCH (Active: ...$($activeInfo.TokenId), Profile: ...$($profileInfo.TokenId))" "Red"
            }

            $typeMatch = $activeInfo.SubscriptionType -eq $profileInfo.SubscriptionType
            Write-Host "    Account Type: " -NoNewline
            if ($typeMatch) {
                Write-Color "MATCH ($($activeInfo.AccountType))" "Green"
            } else {
                Write-Color "MISMATCH (Active: $($activeInfo.AccountType), Profile: $($profileInfo.AccountType))" "Red"
            }

            Write-Host ""
            if ($hashMatch -and $tokenMatch -and $typeMatch) {
                Write-Color "  STATUS: Active credentials match '$activeProfile' profile" "Green"
            } else {
                Write-Color "  STATUS: CREDENTIALS MISMATCH!" "Red"
                Write-Host "  The active credentials don't match the '$activeProfile' profile."
                Write-Host "  This could mean:"
                Write-Host "    - You logged in with a different account (/login)"
                Write-Host "    - The switch didn't complete properly"
                Write-Host "    - Claude Code is still using cached credentials from a previous session"
                Write-Host ""
                Write-Host "  To fix: Run 'claude-profile switch $activeProfile' and restart Claude Code"
            }
        } else {
            Write-Color "  WARNING: Profile '$activeProfile' credentials file not found!" "Red"
        }
    }

    # Show all profiles summary
    Write-Host ""
    Write-Color "  --- ALL PROFILES ---" "Yellow"
    $profiles = Get-AllProfiles
    foreach ($profile in $profiles) {
        $profileDir = Join-Path $ProfilesDir $profile
        $profileCredFile = Join-Path $profileDir ".credentials.json"
        $info = Get-AccountInfo -CredFilePath $profileCredFile

        $marker = if ($profile -eq $activeProfile) { "*" } else { " " }
        $type = $info.AccountType.PadRight(25)
        $token = "...$($info.TokenId)"

        Write-Host "    $marker $($profile.PadRight(15)) $type $token"
    }

    Write-Host ""
    Write-Color "========================================" "Yellow"
    Write-Color "  REMEMBER: Restart Claude Code after switching!" "Yellow"
    Write-Color "========================================" "Yellow"
    Write-Host ""
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

    # Show what we're launching
    $info = Get-AccountInfo -CredFilePath $profileCredFile
    Show-AccountInfo -Label "Launching isolated session for:" -Info $info

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
    $accountType = $info.AccountType
    $script = @"
`$env:USERPROFILE = '$tempHome'
`$env:HOME = '$tempHome'
`$env:CLAUDE_PROFILE = '$Name'
Write-Host ''
Write-Host '=======================================' -ForegroundColor Cyan
Write-Host '  Claude Code - Profile: $Name' -ForegroundColor Cyan
Write-Host '  Account: $accountType' -ForegroundColor Cyan
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
    "verify" { Show-Verify }
    "delete" { Remove-Profile -Name $ProfileName }
    "launch" { Start-IsolatedSession -Name $ProfileName }
    "help"   { Show-Help }
    default  { Show-Help }
}
