<#
.SYNOPSIS
    Idempotently installs the JetBrainsMono Nerd Font via Chocolatey.

.DESCRIPTION
    Does NOT require running elevated up front. Ensures Chocolatey is
    present (installing it only if missing) and then ensures the
    nerd-fonts-jetbrainsmono package is installed (installing it only if
    not already present, or upgrading if -Upgrade is passed). Chocolatey
    installs typically do need administrator rights; if a step fails in a
    way that looks permissions-related, this script prints a clear hint to
    re-run elevated rather than demanding elevation before you've even
    started.

    A real Nerd Font is required for Alacritty (see Install-Alacritty.ps1):
    unlike WezTerm, which ships a built-in Nerd Font glyph fallback,
    Alacritty renders unsupported glyphs (tmux status icons, prompt icons,
    etc.) as tofu/boxes unless a real Nerd Font is installed and configured.

.PARAMETER Version
    Optional specific nerd-fonts-jetbrainsmono package version to install.

.PARAMETER Upgrade
    If the font is already installed, upgrade it to the latest (or
    -Version) release instead of leaving it untouched.

.EXAMPLE
    .\Install-NerdFont.ps1

.EXAMPLE
    .\Install-NerdFont.ps1 -Upgrade
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$Upgrade
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

$packageName = 'nerd-fonts-jetbrainsmono'

function Test-ChocoPackageInstalled {
    param([Parameter(Mandatory)][string]$PackageName)
    $result = & choco list --local-only --exact $PackageName --limit-output 2>$null
    return [bool]($result | Where-Object { $_ -match "^$([regex]::Escape($PackageName))\|" })
}

if (-not (Test-IsElevated)) {
    Write-Host 'Not running elevated. Chocolatey installs usually need admin rights; if a step below fails, re-run this script from an elevated PowerShell session.' -ForegroundColor Yellow
}

# --- Chocolatey ---------------------------------------------------------------
if (Test-CommandExists -Name 'choco') {
    Write-Host 'Chocolatey already installed, skipping.' -ForegroundColor DarkGray
}
else {
    Write-Host 'Chocolatey not found. Installing Chocolatey...' -ForegroundColor Cyan
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    catch {
        Write-ElevationHint -Context 'Chocolatey install'
        throw
    }

    # Refresh PATH for the current process so 'choco' is immediately usable.
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

    if (-not (Test-CommandExists -Name 'choco')) {
        Write-ElevationHint -Context 'Chocolatey install'
        throw 'Chocolatey installation did not complete successfully.'
    }
}

# --- JetBrainsMono Nerd Font ----------------------------------------------------
$alreadyInstalled = Test-ChocoPackageInstalled -PackageName $packageName

if ($alreadyInstalled -and -not $Upgrade) {
    Write-Host 'JetBrainsMono Nerd Font already installed, skipping (use -Upgrade to force an upgrade).' -ForegroundColor DarkGray
}
else {
    $action = if ($alreadyInstalled) { 'upgrade' } else { 'install' }
    Write-Host "Running choco $action $packageName..." -ForegroundColor Cyan

    $chocoArgs = @($action, $packageName, '-y', '--no-progress')
    if ($Version) {
        $chocoArgs += @('--version', $Version)
    }

    & choco @chocoArgs
    if ($LASTEXITCODE -ne 0) {
        Write-ElevationHint -Context "choco $action $packageName"
        throw "choco $action $packageName exited with code $LASTEXITCODE"
    }

    Write-Host 'JetBrainsMono Nerd Font install complete.' -ForegroundColor Green
}
