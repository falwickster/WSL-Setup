<#
.SYNOPSIS
    Idempotently installs WezTerm via Chocolatey.

.DESCRIPTION
    Does NOT require running elevated up front. Ensures Chocolatey is
    present (installing it only if missing) and then ensures the WezTerm
    package is installed (installing it only if not already present, or
    upgrading if -Upgrade is passed). Chocolatey installs typically do need
    administrator rights; if a step fails in a way that looks
    permissions-related, this script prints a clear hint to re-run elevated
    rather than demanding elevation before you've even started.

.PARAMETER Version
    Optional specific WezTerm package version to install.

.PARAMETER Upgrade
    If WezTerm is already installed, upgrade it to the latest (or
    -Version) release instead of leaving it untouched.

.EXAMPLE
    .\Install-WezTerm.ps1

.EXAMPLE
    .\Install-WezTerm.ps1 -Upgrade
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

# --- WezTerm ---------------------------------------------------------------------
$alreadyInstalled = Test-ChocoPackageInstalled -PackageName 'wezterm'

if ($alreadyInstalled -and -not $Upgrade) {
    Write-Host 'WezTerm already installed, skipping (use -Upgrade to force an upgrade).' -ForegroundColor DarkGray
}
else {
    $action = if ($alreadyInstalled) { 'upgrade' } else { 'install' }
    Write-Host "Running choco $action wezterm..." -ForegroundColor Cyan

    $chocoArgs = @($action, 'wezterm', '-y', '--no-progress')
    if ($Version) {
        $chocoArgs += @('--version', $Version)
    }

    & choco @chocoArgs
    if ($LASTEXITCODE -ne 0) {
        Write-ElevationHint -Context "choco $action wezterm"
        throw "choco $action wezterm exited with code $LASTEXITCODE"
    }

    Write-Host 'WezTerm install complete.' -ForegroundColor Green
}
