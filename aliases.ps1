# Laravel shortcuts
function a {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )
    & php artisan @Args
}

# Prefer GNU ls over PowerShell alias
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue

# Git worktree for issue, usage like:
#
# ```bash
#  w 1234 add user login
# ```
#
# creates a worktree in ../repo-name-1234-add-user-login
# and a branch named 1234-add-user-login. It can also just be
# called with the issue number only:
#
# ```bash
#  w 1234
# ```
#
# creates ../repo-name-1234 and branch 1234
# --- w: create git worktree from current repo and cd into it ---
function w {
    param(
        [Parameter(Position = 0)]
        [string]$Issue,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Description
    )

    # Help
    if (-not $Issue -or $Issue -in @('-h', '--help', 'help')) {
        Write-Host ""
        Write-Host "Usage:"
        Write-Host "  w <ISSUE> [description words...]"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  w 45"
        Write-Host "    -> branch: 45"
        Write-Host "    -> worktree: ../<repo>-45"
        Write-Host ""
        Write-Host "  w 45 tweak google columns"
        Write-Host "    -> branch: 45-tweak-google-columns"
        Write-Host "    -> worktree: ../<repo>-45-tweak-google-columns"
        Write-Host ""
        Write-Host "Notes:"
        Write-Host "  - Run inside a git repository"
        Write-Host "  - Description is converted to kebab-case"
        Write-Host ""
        return
    }

    # Validate issue number
    if ($Issue -notmatch '^\d+$') {
        Write-Error "Issue number must be numeric."
        return
    }

    # Ensure we're inside a git repo
    if (-not (git rev-parse --is-inside-work-tree 2>$null)) {
        Write-Error "Not inside a git repository."
        return
    }

    $IssueInt = [int]$Issue
    $repoName = Split-Path -Leaf (Get-Location)

    # Build kebab-case description if provided
    $kebab = $null
    if ($Description.Count -gt 0) {
        $kebab = ($Description -join ' ') `
            -replace '[^a-zA-Z0-9\s-]', '' `
            -replace '\s+', '-' `
            | ForEach-Object { $_.ToLower() }
    }

    $branch = if ($kebab) { "$IssueInt-$kebab" } else { "$IssueInt" }
    $worktreeDir = if ($kebab) { "../$repoName-$IssueInt-$kebab" } else { "../$repoName-$IssueInt" }

    Write-Host "Creating worktree:"
    Write-Host "  Branch : $branch"
    Write-Host "  Path   : $worktreeDir"

    git worktree add $worktreeDir -b $branch
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git worktree add failed."
        return
    }

    Set-Location $worktreeDir
}

# Git worktree remove for current folder, with confirmation
# Usage:
#
# ```bash
#  wr
# ```
# This command is the counterpart to `w`, removing the current
# worktree after user confirmation. It prevents removing the main
# worktree by mistake.
function wr {
    # Ensure we're inside a git repo
    if (-not (git rev-parse --is-inside-work-tree 2>$null)) {
        Write-Error "Not inside a git repository."
        return
    }

    $currentPath = (Resolve-Path (Get-Location)).Path

    # Main worktree is the first listed by git
    $mainWorktree = git worktree list --porcelain |
        Where-Object { $_ -like 'worktree *' } |
        Select-Object -First 1 |
        ForEach-Object { $_ -replace '^worktree\s+', '' }

    if (-not $mainWorktree) {
        Write-Error "Unable to determine main worktree."
        return
    }

    $mainWorktree = (Resolve-Path $mainWorktree).Path

    # Prevent removing the main worktree
    if ($currentPath -eq $mainWorktree) {
        Write-Error "You are in the main worktree. Aborting."
        return
    }

    Write-Host ""
    Write-Host "You are about to remove this worktree:"
    Write-Host "  $currentPath"
    Write-Host ""

    $confirm = Read-Host "Type YES to confirm"
    if ($confirm -ne "YES") {
        Write-Host "Aborted."
        return
    }

    # Move out before removing (avoids locks and self-removal issues)
    Set-Location $mainWorktree

    git worktree remove "$currentPath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to remove worktree."
        return
    }

    Write-Host ""
    Write-Host "Worktree removed successfully."
    Write-Host "Now in:"
    Write-Host "  $mainWorktree"
}

# Convert input to kebab-case
# Usage:
# ```bash
#  kb This is a Test!
# ```
# Outputs:
# ```
#  this-is-a-test
function kb {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    if (-not $Args -or $Args.Count -eq 0) { return }

    $text = (($Args -join ' ').ToLower() -replace '[^a-z0-9]+', '-' -replace '^-+|-+$', '')
    Write-Output $text
}
