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
    'Ubuntu-24.04', or a Fedora name such as 'FedoraLinux-44'. Must match a
    NAME currently returned by `wsl --list --online`.

.PARAMETER SetDefault
    Set this distro as the default WSL distro after install.

.EXAMPLE
    .\Install-WslDistro.ps1

.EXAMPLE
    .\Install-WslDistro.ps1 -DistroName Ubuntu-24.04 -SetDefault
#>
[CmdletBinding()]
param(
    [string]$DistroName = 'Ubuntu',
    [switch]$SetDefault
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
    Write-Host "'$DistroName' is already installed, skipping install." -ForegroundColor DarkGray
}
else {
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
