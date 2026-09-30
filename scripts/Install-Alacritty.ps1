<#
.SYNOPSIS
    Idempotently installs Alacritty via Chocolatey.

.DESCRIPTION
    Does NOT require running elevated up front. Ensures Chocolatey is
    present (installing it only if missing) and then ensures the alacritty
    package is installed (installing it only if not already present, or
    upgrading if -Upgrade is passed). Chocolatey installs typically do need
    administrator rights; if a step fails in a way that looks
    permissions-related, this script prints a clear hint to re-run elevated
    rather than demanding elevation before you've even started.

    Alacritty is installed alongside WezTerm (not as a replacement) so it
    can be tested before WezTerm is removed. Unlike WezTerm, Alacritty has
    no built-in Nerd Font glyph fallback, so run Install-NerdFont.ps1 too
    (or via Bootstrap.ps1, which runs it by default) or icons will render
    as tofu/boxes.

.PARAMETER Version
    Optional specific Alacritty package version to install.

.PARAMETER Upgrade
    If Alacritty is already installed, upgrade it to the latest (or
    -Version) release instead of leaving it untouched.

.EXAMPLE
    .\Install-Alacritty.ps1

.EXAMPLE
    .\Install-Alacritty.ps1 -Upgrade
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$Upgrade
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

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

# --- Alacritty ---------------------------------------------------------------
$alreadyInstalled = Test-ChocoPackageInstalled -PackageName 'alacritty'

if ($alreadyInstalled -and -not $Upgrade) {
    Write-Host 'Alacritty already installed, skipping (use -Upgrade to force an upgrade).' -ForegroundColor DarkGray
}
else {
    $action = if ($alreadyInstalled) { 'upgrade' } else { 'install' }
    Write-Host "Running choco $action alacritty..." -ForegroundColor Cyan

    $chocoArgs = @($action, 'alacritty', '-y', '--no-progress')
    if ($Version) {
        $chocoArgs += @('--version', $Version)
    }

    & choco @chocoArgs
    if ($LASTEXITCODE -ne 0) {
        Write-ElevationHint -Context "choco $action alacritty"
        throw "choco $action alacritty exited with code $LASTEXITCODE"
    }

    Write-Host 'Alacritty install complete.' -ForegroundColor Green
}
