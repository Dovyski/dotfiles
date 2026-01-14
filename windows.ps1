<# 
windows.ps1 (NO ADMIN)

1) Download + install FiraCode Nerd Font (current user only)
2) Install oh-my-posh using winget
3) Configure oh-my-posh agnoster theme (session + persistent profile)
4) Add terminal aliases (session + persistent profile)
#>

$ErrorActionPreference = "Stop"

function Ensure-Directory([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Download-File([string]$Url, [string]$OutFile) {
    Write-Host "Downloading: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile
}

function Get-FileContentSafe([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    try {
        # Avoid relying on -Raw across environments: read as lines then join.
        return ((Get-Content -LiteralPath $Path -ErrorAction Stop) -join "`n")
    } catch {
        return ""
    }
}

function Add-LineIfMissing([string]$Path, [string]$Line) {
    $dir = Split-Path -Parent $Path
    Ensure-Directory $dir

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }

    $content = Get-FileContentSafe $Path
    if ($content -notmatch [regex]::Escape($Line)) {
        Add-Content -LiteralPath $Path -Value "`r`n# oh-my-posh`r`n$Line`r`n"
        return $true
    }
    return $false
}

function Add-BlockIfMissing([string]$Path, [string]$BeginMarker, [string]$EndMarker, [string]$BlockContent) {
    $dir = Split-Path -Parent $Path
    Ensure-Directory $dir

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }

    $content = Get-FileContentSafe $Path

    $beginEsc = [regex]::Escape($BeginMarker)
    $endEsc   = [regex]::Escape($EndMarker)

    # If the block is already present (even if edited), do nothing.
    if ($content -match "$beginEsc[\s\S]*?$endEsc") {
        return $false
    }

    $toAppend = @"
`r`n$BeginMarker
$BlockContent
$EndMarker
"@

    Add-Content -LiteralPath $Path -Value $toAppend
    return $true
}

function Get-ProfileTargets {
    $targets = New-Object System.Collections.Generic.List[string]

    # 1) The active host profile path for THIS session
    $targets.Add($PROFILE)

    # 2) CurrentUserAllHosts (covers other pwsh hosts too)
    try { $targets.Add($PROFILE.CurrentUserAllHosts) } catch {}

    # 3) My Documents as Windows resolves it (handles OneDrive redirection + localized "Documentos")
    $myDocs = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    if ($myDocs) {
        $targets.Add((Join-Path $myDocs "PowerShell\Microsoft.PowerShell_profile.ps1"))
        $targets.Add((Join-Path $myDocs "PowerShell\profile.ps1"))
    }

    # 4) Common fallbacks (in case env is weird)
    $targets.Add((Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"))
    $targets.Add((Join-Path $HOME "OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"))
    $targets.Add((Join-Path $HOME "OneDrive\Documentos\PowerShell\Microsoft.PowerShell_profile.ps1"))

    # De-duplicate + keep only non-empty
    return ($targets | Where-Object { $_ -and $_.Trim() } | Select-Object -Unique)
}

function Install-NerdFont-FiraCode-User {
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip"
    $tempRoot = Join-Path $env:TEMP "work-env-setup"
    $zipPath  = Join-Path $tempRoot "FiraCode.zip"
    $extract  = Join-Path $tempRoot "FiraCode"

    Ensure-Directory $tempRoot

    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    Download-File -Url $url -OutFile $zipPath

    Write-Host "Extracting fonts..."
    Expand-Archive -Path $zipPath -DestinationPath $extract -Force

    $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    Ensure-Directory $userFontsDir
    $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

    Write-Host "Installing FiraCode Nerd Font for current user..."
    $fonts = Get-ChildItem -LiteralPath $extract -Recurse -Include *.ttf -File
    if (-not $fonts) { throw "No .ttf font files found after extracting." }

    foreach ($font in $fonts) {
        $dest = Join-Path $userFontsDir $font.Name
        if (-not (Test-Path -LiteralPath $dest)) {
            Copy-Item -LiteralPath $font.FullName -Destination $dest -Force
        }

        $displayName = ($font.BaseName -replace "-", " ") + " (TrueType)"
        $existing = $null
        try {
            $existing = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).$displayName
        } catch {}

        if (-not $existing) {
            New-ItemProperty -Path $regPath -Name $displayName -PropertyType String -Value $font.Name -Force | Out-Null
        }
    }

    Write-Host "FiraCode Nerd Font installed for current user."
}

function Install-OhMyPosh {
    Write-Host "Installing oh-my-posh via winget..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget not found. Install 'App Installer' from Microsoft Store first."
    }

    winget install JanDeDobbeleer.OhMyPosh `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements | Out-Null
}

function Configure-OhMyPoshTheme {
    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/agnoster.omp.json"
    $initLine = "oh-my-posh init pwsh --config $themeUrl | Invoke-Expression"

    Write-Host "Applying oh-my-posh theme for this session..."
    Invoke-Expression $initLine

    Write-Host "Persisting oh-my-posh config in PowerShell profile(s)..."

    $targets = Get-ProfileTargets

    $changed = @()
    foreach ($p in $targets) {
        try {
            if (Add-LineIfMissing -Path $p -Line $initLine) {
                $changed += $p
            }
        } catch {
            Write-Warning "Could not write profile: $p (`$($_.Exception.Message))"
        }
    }

    if ($changed.Count -gt 0) {
        Write-Host "Updated profile(s):"
        $changed | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "No profile updates were needed (init line already present)."
    }

    # Quick sanity check: show what THIS session will load next time
    Write-Host "`nCurrent session `$PROFILE is:"
    Write-Host "  $PROFILE"
}

function Configure-TerminalAliases {
    # Session alias (available immediately in the current PowerShell session)
    if (-not (Get-Command a -ErrorAction SilentlyContinue)) {
        function global:a {
            param(
                [Parameter(ValueFromRemainingArguments = $true)]
                [string[]]$Args
            )
            & php artisan @Args
        }
    }

    # Persistent alias (added to profile(s))
    $begin = "# >>> work-env aliases >>>"
    $end   = "# <<< work-env aliases <<<"

    $block = @'
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
'@

    Write-Host "Persisting aliases in PowerShell profile(s)..."
    $targets = Get-ProfileTargets

    $changed = @()
    foreach ($p in $targets) {
        try {
            if (Add-BlockIfMissing -Path $p -BeginMarker $begin -EndMarker $end -BlockContent $block) {
                $changed += $p
            }
        } catch {
            Write-Warning "Could not write profile: $p (`$($_.Exception.Message))"
        }
    }

    if ($changed.Count -gt 0) {
        Write-Host "Updated profile(s) with aliases:"
        $changed | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "No profile updates were needed (aliases block already present)."
    }
}

try {
    Install-NerdFont-FiraCode-User
    Install-OhMyPosh
    Configure-OhMyPoshTheme

    # Call inside the existing try..catch block, as requested
    Configure-TerminalAliases

    Write-Host "`nSetup complete!"
    Write-Host "Close ALL Windows Terminal windows and open again to ensure the profile is reloaded."
} catch {
    Write-Error $_
    exit 1
}
