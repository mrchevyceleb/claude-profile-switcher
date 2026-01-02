# Claude Profile Switcher

**Easily switch between multiple Claude Code accounts (personal, Teams, work) on a single machine.**

Claude Code only supports one logged-in account at a time. This tool lets you:
- Save multiple accounts as profiles
- Switch between them with a single command
- Run multiple accounts **simultaneously** in separate terminals

## Quick Start

### Installation

Run this in PowerShell:

```powershell
irm https://raw.githubusercontent.com/mtjohns/claude-profile-switcher/main/install.ps1 | iex
```

Or manually:
1. Download `claude-profile.ps1`
2. Save to `~/.claude-profiles/claude-profile.ps1`
3. Add this to your PowerShell profile (`notepad $PROFILE`):
   ```powershell
   function claude-profile { & "$env:USERPROFILE\.claude-profiles\claude-profile.ps1" @args }
   Set-Alias ccp claude-profile
   ```

### Setup Your Profiles

```powershell
# Log into your personal account in Claude Code (/login), then:
ccp create personal

# Log into your Teams/work account in Claude Code (/login), then:
ccp create teams
```

### Usage

```powershell
# Switch accounts (restart Claude Code after)
ccp switch personal
ccp switch teams

# Or run both simultaneously
ccp launch personal    # Opens new terminal with personal account
ccp launch teams       # Opens new terminal with Teams account
```

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

## Important Notes

- Run `ccp` commands in **PowerShell**, not inside Claude Code
- After `switch`, restart Claude Code for changes to take effect
- First time using `launch` for each profile requires a one-time login

## Troubleshooting

See the [detailed beginner's guide](docs/beginners-guide.md) for step-by-step instructions and troubleshooting.

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

Issues and PRs welcome!

---

*Built because Anthropic doesn't support multi-account yet. When they do, this tool becomes obsolete (and that's fine).*
