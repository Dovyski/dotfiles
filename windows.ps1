<# 
init-work-env.ps1 (NO ADMIN)

1) Download + install FiraCode Nerd Font (current user only)
2) Install oh-my-posh using winget
3) Configure oh-my-posh agnoster theme (session + persistent profile)
#>

$ErrorActionPreference = "Stop"

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Download-File([string]$Url, [string]$OutFile) {
    Write-Host "Downloading: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Install-NerdFont-FiraCode-User {
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip"
    $tempRoot = Join-Path $env:TEMP "work-env-setup"
    $zipPath  = Join-Path $tempRoot "FiraCode.zip"
    $extract  = Join-Path $tempRoot "FiraCode"

    Ensure-Directory $tempRoot

    # Download
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    Download-File -Url $url -OutFile $zipPath

    # Extract
    Write-Host "Extracting fonts..."
    Expand-Archive -Path $zipPath -DestinationPath $extract -Force

    # Per-user fonts directory (Windows 10+)
    $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    Ensure-Directory $userFontsDir

    # Per-user font registry
    $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

    Write-Host "Installing FiraCode Nerd Font for current user..."
    $fonts = Get-ChildItem -LiteralPath $extract -Recurse -Include *.ttf -File
    if (-not $fonts) {
        throw "No .ttf font files found after extracting."
    }

    foreach ($font in $fonts) {
        $dest = Join-Path $userFontsDir $font.Name

        if (-not (Test-Path -LiteralPath $dest)) {
            Copy-Item -LiteralPath $font.FullName -Destination $dest -Force
        }

        # Register font for current user
        $displayName = ($font.BaseName -replace "-", " ") + " (TrueType)"
        $existing = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty $displayName -ErrorAction SilentlyContinue

        if (-not $existing) {
            New-ItemProperty `
                -Path $regPath `
                -Name $displayName `
                -PropertyType String `
                -Value $font.Name `
                -Force | Out-Null
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
        --accept-package-agreements
}

function Configure-OhMyPoshTheme {
    # Use RAW GitHub URL (important)
    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/agnoster.omp.json"
    $initLine = "oh-my-posh init pwsh --config $themeUrl | Invoke-Expression"

    Write-Host "Applying oh-my-posh theme for this session..."
    Invoke-Expression $initLine

    Write-Host "Persisting oh-my-posh config in PowerShell profile..."
    $profileDir = Split-Path -Parent $PROFILE
    Ensure-Directory $profileDir

    if (-not (Test-Path -LiteralPath $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    $profileContent = Get-Content -LiteralPath $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch [regex]::Escape($initLine)) {
        Add-Content -LiteralPath $PROFILE -Value "`r`n# oh-my-posh`r`n$initLine`r`n"
        Write-Host "Added oh-my-posh init to profile."
    } else {
        Write-Host "oh-my-posh already configured in profile."
    }
}

try {
    Install-NerdFont-FiraCode-User
    Install-OhMyPosh
    Configure-OhMyPoshTheme

    Write-Host "`nSetup complete!"
    Write-Host "Open a NEW PowerShell window to see the theme automatically."
} catch {
    Write-Error $_
    exit 1
}
