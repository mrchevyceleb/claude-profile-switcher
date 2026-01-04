# Claude Profile Switcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)

**Easily switch between multiple Claude Code accounts (personal, Teams, work) on a single machine.**

---

## The Problem

Claude Code only supports **one logged-in account at a time**. If you have both a personal account and a Teams/work account, you have to constantly log out and log back in. This is slow and frustrating.

## The Solution

This tool lets you:
- **Save** multiple accounts as named profiles
- **Switch** between them with a single command
- **Run both simultaneously** in separate terminal windows

---

## Quick Start

### 1. Install (One Command)

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/mrchevyceleb/claude-profile-switcher/main/install.ps1 | iex
```

Then **restart PowerShell**.


<details>
<summary>Manual Installation (click to expand)</summary>

1. Download `claude-profile.ps1`
2. Save to `~/.claude-profiles/claude-profile.ps1`
3. Add this to your PowerShell profile (`notepad $PROFILE`):
   ```powershell
   function claude-profile { & "$env:USERPROFILE\.claude-profiles\claude-profile.ps1" @args }
   Set-Alias ccp claude-profile
   ```
</details>

### 2. Save Your Accounts as Profiles

> **CRITICAL: Close ALL Claude Code sessions before setup!**
>
> If you have Claude Code open in multiple places (desktop app, VS Code, Obsidian, other terminals), **close them all first**. Multiple sessions share the same credentials file - if one session refreshes its token while you're setting up, it will overwrite your profiles with the wrong account.

**Save your personal account:**
1. **Close ALL Claude Code sessions everywhere**
2. Open ONE terminal and run `claude`
3. Make sure you're logged into your **personal** account (use `/login` if needed)
4. Exit Claude Code
5. In PowerShell, run:
   ```powershell
   ccp create personal
   ```

**Save your Teams/work account:**
1. Open Claude Code (same terminal)
2. Run `/logout`, then `/login` and log into your **Teams/work** account
3. Exit Claude Code
4. In PowerShell, run:
   ```powershell
   ccp create teams
   ```

5. Verify setup with `ccp list` - both profiles should show valid tokens (not `[EXPIRED]`)

### 3. Switch Between Accounts

```powershell
ccp switch personal    # Switch to personal account
ccp switch teams       # Switch to Teams account
```

> **Important:** Restart Claude Code after switching for changes to take effect.

### 4. Run Both Simultaneously (Optional)

```powershell
ccp launch personal    # Opens new terminal with personal account
ccp launch teams       # Opens new terminal with Teams account
```

Each runs in a completely isolated environment. First time requires a one-time login.

## Commands

| Command | Description |
|---------|-------------|
| `ccp list` | Show all profiles (* = active) |
| `ccp switch <name>` | Switch to a profile |
| `ccp launch <name>` | Open profile in new isolated terminal |
| `ccp create <name>` | Save current Claude login as profile |
| `ccp current` | Show active profile |
| `ccp delete <name>` | Remove a profile |
| `ccp help` | Show help |

## How It Works

Claude Code stores credentials in `~/.claude/.credentials.json`. This tool:

1. **Profiles**: Saves copies of credentials to `~/.claude-profiles/<name>/`
2. **Switch**: Copies the selected profile's credentials into place
3. **Launch**: Creates isolated environments with separate HOME directories for true simultaneous use

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Claude Code installed

## Tip: Quick Launch Shortcut

Add this to your PowerShell profile (`notepad $PROFILE`):

```powershell
function cc { claude --dangerously-skip-permissions }
```

Now just type `cc` instead of the full command. (Use with caution - this auto-approves all permission prompts.)

## Important Notes

- Run `ccp` commands in **PowerShell**, not inside Claude Code
- After `switch`, **close and restart** Claude Code for changes to take effect
- First time using `launch` for each profile requires a one-time login
- **Tokens expire after ~24 hours** - if `ccp list` shows `[EXPIRED]`, re-save the profile

## Troubleshooting

### "Switch doesn't work - stays on the same account"

**Cause 1: Multiple Claude Code sessions running**
- Close ALL Claude Code sessions before switching
- Switch with `ccp switch <name>`
- Then reopen Claude Code

**Cause 2: Expired tokens**
- Run `ccp list` - if you see `[EXPIRED]`, the stored tokens are dead
- Log into that account fresh and run `ccp create <name>` to update it

**Cause 3: Setup was done with multiple sessions open**
- If other Claude Code sessions were running during setup, they may have overwritten your profiles
- Close everything and redo the setup from scratch

### "Both profiles seem to use the same account"

This happens when profiles are created while other Claude Code sessions are running. The other session refreshes its token and overwrites the credentials file. Close everything and redo setup.

### Using multiple accounts simultaneously

Use `ccp launch <name>` instead of `ccp switch`. This opens an isolated terminal with a separate HOME directory, so credentials don't conflict.

See the [detailed beginner's guide](docs/beginners-guide.md) for more help.

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

Issues and PRs welcome!

---

*Built because Anthropic doesn't support multi-account yet. When they do, this tool becomes obsolete (and that's fine).*
