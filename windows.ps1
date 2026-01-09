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
