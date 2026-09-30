<#
.SYNOPSIS
    Idempotently installs/registers an officially Microsoft-supported WSL2
    distro (e.g. Ubuntu, or a Fedora distro name if you distro-hop later).

.DESCRIPTION
    Does NOT require running elevated. `wsl --install -d <Name>` generally
    works from a normal user session on current Windows builds; if the WSL
    optional component itself still needs enabling, this script detects the
    failure and tells you to re-run elevated for that specific step, rather
    than demanding elevation up front.

    Only ever installs distros that Microsoft officially ships through
    `wsl --install` (checked live against `wsl --list --online`) — no
    custom/unofficial rootfs building.

.PARAMETER DistroName
    The WSL distro identifier to install, e.g. 'Ubuntu' (default),
    'Ubuntu-26.04', or a Fedora name such as 'FedoraLinux-44'. Must match a
    NAME currently returned by `wsl --list --online`.

.PARAMETER SetDefault
    Set this distro as the default WSL distro after install.

.PARAMETER Reinstall
    If the distro is already installed, remove it (wsl --terminate +
    wsl --unregister) and install a fresh copy instead of skipping.
    THIS PERMANENTLY DELETES ALL DATA in the existing instance (files,
    packages, everything set up inside it). You'll be prompted to confirm
    unless -Force is also passed.

.PARAMETER Force
    Skip the confirmation prompt when used with -Reinstall (or when the
    interactive re-install prompt would otherwise be shown). Use for
    non-interactive/scripted runs. Has no effect if the distro isn't
    already installed.

.EXAMPLE
    .\Install-WslDistro.ps1

.EXAMPLE
    .\Install-WslDistro.ps1 -DistroName Ubuntu-26.04 -SetDefault

.EXAMPLE
    # Wipe and reinstall the existing 'Ubuntu' distro from scratch
    .\Install-WslDistro.ps1 -Reinstall

.EXAMPLE
    # Same, but non-interactive (e.g. CI or automation)
    .\Install-WslDistro.ps1 -Reinstall -Force
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$DistroName = 'Ubuntu',
    [switch]$SetDefault,
    [switch]$Reinstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

if (-not (Test-CommandExists -Name 'wsl')) {
    throw "wsl.exe was not found. Install the 'Windows Subsystem for Linux' feature first: https://aka.ms/wslinstall"
}

# --- 1. Confirm the WSL2 subsystem itself is functional --------------------------
Write-Host 'Checking WSL status...' -ForegroundColor Cyan
$statusOutput = & wsl --status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning ($statusOutput -join "`n")
    Write-ElevationHint -Context 'wsl --status'
    throw "WSL does not appear to be fully set up. From an elevated PowerShell session run: wsl --install --no-distribution, reboot if prompted, then re-run this script."
}

# --- 2. Confirm the requested distro name is currently valid ----------------------
Write-Host "Checking that '$DistroName' is a currently valid distro name (wsl --list --online)..." -ForegroundColor Cyan
$onlineList = (& wsl --list --online 2>&1) -replace "`0", ''
if ($LASTEXITCODE -ne 0) {
    throw "wsl --list --online failed:`n$($onlineList -join "`n")"
}

$matchLine = $onlineList | Where-Object { $_ -match "^\s*$([regex]::Escape($DistroName))\s" }
if (-not $matchLine) {
    Write-Warning ($onlineList -join "`n")
    throw "'$DistroName' was not found in 'wsl --list --online' (see NAME column above). Pick a currently listed name and re-run with -DistroName."
}

# --- 3. Idempotency check: is it already installed? --------------------------------
$installedList = (& wsl --list --quiet 2>&1) -replace "`0", ''
$alreadyInstalled = $installedList | Where-Object { $_.Trim() -eq $DistroName }

if ($alreadyInstalled) {
    $doReinstall = $Reinstall

    # Not explicitly asked to reinstall, but running interactively: offer it
    # instead of just silently skipping.
    if (-not $doReinstall -and -not $Force -and [Environment]::UserInteractive -and -not $WhatIfPreference) {
        Write-Host "'$DistroName' is already installed." -ForegroundColor DarkGray
        $response = Read-Host "Remove it and install a fresh copy? This deletes all its data. [y/N]"
        $doReinstall = $response -match '^[Yy]'
    }

    if ($doReinstall) {
        Write-Warning "This will PERMANENTLY DELETE all data in the existing '$DistroName' instance (files, packages, everything set up inside it)."

        # -Force skips the "are you sure?" confirmation ShouldProcess would
        # otherwise raise (ConfirmImpact='High'); -WhatIf still reports the
        # planned action either way.
        $savedConfirmPreference = $ConfirmPreference
        if ($Force) { $ConfirmPreference = 'None' }
        try {
            $proceed = $PSCmdlet.ShouldProcess($DistroName, 'Remove existing installation and reinstall fresh (wsl --terminate && wsl --unregister)')
        }
        finally {
            $ConfirmPreference = $savedConfirmPreference
        }

        if (-not $proceed) {
            Write-Host "Reinstall cancelled, leaving '$DistroName' untouched." -ForegroundColor DarkGray
            return
        }

        Write-Host "Terminating '$DistroName'..." -ForegroundColor Cyan
        & wsl --terminate $DistroName 2>&1 | Out-Null

        Write-Host "Unregistering '$DistroName'..." -ForegroundColor Cyan
        & wsl --unregister $DistroName
        if ($LASTEXITCODE -ne 0) {
            throw "wsl --unregister $DistroName exited with code $LASTEXITCODE"
        }
        $alreadyInstalled = $false
    }
    else {
        Write-Host "'$DistroName' is already installed, skipping install." -ForegroundColor DarkGray
    }
}

if (-not $alreadyInstalled) {
    Write-Host "Installing '$DistroName' (wsl --install -d $DistroName)..." -ForegroundColor Cyan
    Write-Host "A separate console window will open to finish setup and ask you to create a UNIX username/password. Complete that, then return here." -ForegroundColor Yellow

    & wsl --install -d $DistroName
    if ($LASTEXITCODE -ne 0) {
        Write-ElevationHint -Context "wsl --install -d $DistroName"
        throw "wsl --install -d $DistroName exited with code $LASTEXITCODE"
    }

    Write-Host "'$DistroName' installed." -ForegroundColor Green
}

# --- 4. Optionally set as default ---------------------------------------------------
if ($SetDefault) {
    Write-Host "Setting '$DistroName' as the default WSL distro..." -ForegroundColor Cyan
    & wsl --set-default $DistroName
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --set-default $DistroName exited with code $LASTEXITCODE"
    }
}

Write-Host ''
Write-Host "Distro '$DistroName' is ready." -ForegroundColor Green
Write-Host 'Next: open it and run your in-distro provisioning repo (e.g. Fedora-Setup) to install packages:' -ForegroundColor Green
Write-Host "  wsl -d $DistroName"
