# Claude Profile Switcher - Beginner's Guide

**What is this?** A simple tool that lets you switch between multiple Claude Code accounts (like personal and work/Teams) on the same computer.

**Created:** 2026-01-02
**Difficulty:** Beginner-friendly (no coding knowledge required)

---

## Cheat Sheet (Quick Reference)

Run these in a **PowerShell window** (NOT inside Claude Code):

| Command | What it does |
|---------|--------------|
| `ccp list` | See all profiles (* = active) |
| `ccp switch personal` | Switch to personal account |
| `ccp switch teams` | Switch to Teams account |
| `ccp launch personal` | Open personal in NEW window (simultaneous use) |
| `ccp launch teams` | Open Teams in NEW window (simultaneous use) |
| `ccp create NAME` | Save current login as a profile |
| `ccp current` | Show which profile is active |
| `ccp delete NAME` | Delete a profile |

> **Note:** `ccp` is a shortcut for `claude-profile` - both work the same.

**After switching:** Restart Claude Code for changes to take effect.

**After launching:** First time only, you'll need to log in once. It remembers after that.

---

## Table of Contents

1. [What Problem Does This Solve?](#what-problem-does-this-solve)
2. [Before You Start](#before-you-start)
3. [One-Time Setup](#one-time-setup)
4. [How to Use It](#how-to-use-it)
5. [Running Two Accounts at the Same Time](#running-two-accounts-at-the-same-time)
6. [Quick Reference Card](#quick-reference-card)
7. [Troubleshooting](#troubleshooting)
8. [Glossary](#glossary)

---

## What Problem Does This Solve?

### The Situation
You have two Claude Code accounts:
- **Personal account** - for your own projects
- **Teams/Work account** - for your job

### The Problem
Claude Code only lets you be logged into ONE account at a time. If you want to switch:
- You have to log out
- Then log back in with the other account
- This is slow and annoying

### The Solution
The **Claude Profile Switcher** lets you:
- Save each account as a "profile"
- Switch between profiles with a simple command
- Even run BOTH accounts at the same time in different windows

---

## Before You Start

### What You Need
- Windows computer
- Claude Code already installed and working
- PowerShell (comes with Windows - you probably already have it)
- Already logged into at least one Claude Code account

### How to Open PowerShell
1. Press the **Windows key** on your keyboard
2. Type **PowerShell**
3. Click on **Windows PowerShell** (the blue icon)

A blue/black window will open. This is where you'll type commands.

---

## One-Time Setup

You only need to do this setup once. After that, switching is easy.

### Step 1: Open PowerShell

1. Press **Windows key**
2. Type **PowerShell**
3. Click **Windows PowerShell**

### Step 2: Reload Your Profile

Copy and paste this command into PowerShell, then press **Enter**:

```powershell
. $PROFILE
```

**What this does:** This loads the profile switcher tool so you can use it.

> **Note:** If you see a red error message, that's okay for now. Continue to the next step.

### Step 3: Test That It Works

Type this command and press **Enter**:

```powershell
claude-profile help
```

You should see a help menu that looks like this:

```
Claude Code Profile Switcher
============================

Commands:
  create <name>   Save current credentials as a named profile
  switch <name>   Switch to a different profile
  list            Show all profiles (* = active)
  ...
```

**If you see this, you're ready to go!**

---

## How to Use It

### Save Your First Account (Personal)

Let's save your current Claude Code account as "personal":

**Step 1:** Make sure you're logged into your personal Claude Code account
- If you're not sure, open Claude Code and it should show which account you're using

**Step 2:** In PowerShell, type:

```powershell
claude-profile create personal
```

**Step 3:** Press **Enter**

You should see:
```
Profile 'personal' created and set as active
```

**Congratulations!** Your personal account is now saved.

---

### Save Your Second Account (Teams/Work)

Now let's save your work account:

**Step 1:** Open Claude Code

**Step 2:** Inside Claude Code, type:
```
/login
```

**Step 3:** Follow the prompts to log into your Teams/work account

**Step 4:** Once you're logged in, go back to PowerShell and type:

```powershell
claude-profile create teams
```

**Step 5:** Press **Enter**

You should see:
```
Profile 'teams' created and set as active
```

**Now you have BOTH accounts saved!**

---

### Switching Between Accounts

Now the fun part - switching is super easy:

**To switch to your personal account:**
```powershell
claude-profile switch personal
```

**To switch to your Teams account:**
```powershell
claude-profile switch teams
```

> **Important:** After switching, you need to restart Claude Code for the change to take effect. Just close Claude Code and open it again.

---

### See Which Account is Active

To see all your saved profiles and which one is currently active:

```powershell
claude-profile list
```

You'll see something like:
```
Claude Code Profiles:
---------------------
  * personal (active)
    teams
```

The one with the `*` star is your currently active profile.

---

## Running Two Accounts at the Same Time

This is the really cool part! You can have your personal AND Teams account open in separate windows at the same time.

### How to Do It

**Step 1:** Open PowerShell

**Step 2:** Type this command:

```powershell
claude-profile launch personal
```

**Step 3:** A NEW PowerShell window will pop up

**Step 4:** In that new window, you can run `claude` and it will use your personal account

**Step 5:** Go back to your original PowerShell window and type:

```powershell
claude-profile launch teams
```

**Step 6:** ANOTHER new window pops up

**Step 7:** In that window, run `claude` and it uses your Teams account

**Now you have TWO Claude Code sessions running - one personal, one Teams!**

---

## Quick Reference Card

Print this out or save it somewhere handy:

| What You Want to Do | Command to Type |
|---------------------|-----------------|
| See all your profiles | `claude-profile list` |
| See which profile is active | `claude-profile current` |
| Switch to personal | `claude-profile switch personal` |
| Switch to teams | `claude-profile switch teams` |
| Open personal in new window | `claude-profile launch personal` |
| Open teams in new window | `claude-profile launch teams` |
| Save current account as new profile | `claude-profile create NAME` |
| Delete a profile | `claude-profile delete NAME` |
| Get help | `claude-profile help` |

---

## Troubleshooting

### "claude-profile is not recognized"

**What happened:** PowerShell doesn't know about the profile switcher yet.

**How to fix it:**

1. Close PowerShell completely
2. Open a NEW PowerShell window
3. Try the command again

If it still doesn't work, type this first:
```powershell
. $PROFILE
```
Then try your command again.

---

### Running commands inside Claude Code doesn't work

**What happened:** You're typing `ccp` or `claude-profile` commands inside Claude Code's terminal.

**How to fix it:**

The profile commands must be run in a **separate PowerShell window**, NOT inside Claude Code.

- Open a new PowerShell window (Windows key → type "PowerShell" → click it)
- Run your commands there

---

### I created a profile but it has the wrong account

**What happened:** When you run `ccp create NAME`, it saves whatever account is currently logged into Claude Code. If you were logged into the wrong account, the profile will have the wrong credentials.

**How to fix it:**

1. Log into the correct account in Claude Code using `/login`
2. Exit Claude Code
3. Run `ccp create NAME` again (it will overwrite the old one)

---

### "Profile not found"

**What happened:** You're trying to switch to a profile that doesn't exist.

**How to fix it:**

1. Check what profiles you have:
   ```powershell
   claude-profile list
   ```

2. Make sure you're spelling the profile name correctly

3. Profile names are case-sensitive! "Personal" is different from "personal"

---

### "No Claude credentials found"

**What happened:** You tried to create a profile, but you're not logged into Claude Code.

**How to fix it:**

1. Open Claude Code
2. Type `/login`
3. Log into your account
4. Close Claude Code
5. Now try `claude-profile create NAME` again

---

### Switch didn't seem to work

**What happened:** You switched profiles but Claude Code is still using the old account.

**How to fix it:**

You need to restart Claude Code after switching:

1. Close Claude Code completely
2. Open Claude Code again
3. It should now be using the new profile

---

### The "launch" command asks me to log in

**What happened:** This is normal! The `launch` command creates a completely isolated environment. The first time you use it for each profile, you need to log in once.

**How to fix it:**

1. In the new window that opened, type `claude`
2. Select option 1 (Claude account with subscription)
3. Log in with that profile's account (personal or Teams)
4. **This is a one-time thing** - next time you `launch` that profile, it will remember

---

### The "launch" command opens a window but Claude doesn't work

**What happened:** The isolated environment might not be set up correctly.

**How to fix it:**

1. In the new window that opened, type:
   ```powershell
   claude
   ```

2. If it asks you to log in, that's normal for first use. Log in with that profile's account.

3. The login will be saved for next time.

---

## Glossary

**Profile**
A saved set of login credentials for one Claude Code account. You can have multiple profiles (like "personal" and "teams").

**Active Profile**
The profile that's currently being used when you run Claude Code normally. Only one profile can be active at a time (unless you use the `launch` command).

**PowerShell**
A program on Windows where you type commands. It looks like a blue or black window with text.

**Command**
Text that you type into PowerShell to make things happen. You type the command and press Enter.

**Credentials**
Your login information - the stuff that proves you're you. Claude Code stores these securely on your computer.

**Switch**
Changing from one profile to another. After switching, restart Claude Code to use the new profile.

**Launch**
Opening a completely separate, isolated Claude Code session. This lets you run multiple accounts at the same time.

---

## Where Are Files Stored?

If you're curious, here's where everything lives on your computer:

| What | Location |
|------|----------|
| The profile switcher script | `C:\Users\YOUR_USERNAME\.claude-profiles\claude-profile.ps1` |
| Your saved profiles | `C:\Users\YOUR_USERNAME\.claude-profiles\` (one folder per profile) |
| Which profile is active | `C:\Users\YOUR_USERNAME\.claude-profiles\.active-profile` |

(Replace YOUR_USERNAME with your actual Windows username)

---

## Need More Help?

If something isn't working:

1. Try the [Troubleshooting](#troubleshooting) section above
2. Make sure you followed all the steps in [One-Time Setup](#one-time-setup)
3. Close everything and start fresh - sometimes that's all you need!

---

## Summary

1. **Save your accounts as profiles** using `claude-profile create NAME`
2. **Switch between them** using `claude-profile switch NAME`
3. **Run both at once** using `claude-profile launch NAME`
4. **Always restart Claude Code** after switching (not needed for launch)

That's it! You now have full control over your multiple Claude Code accounts.

---

**Last Updated:** 2026-01-02
**Works With:** Windows 10, Windows 11
**Requires:** PowerShell, Claude Code installed
