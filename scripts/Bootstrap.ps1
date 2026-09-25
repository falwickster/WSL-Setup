<#
.SYNOPSIS
    Runs the full Windows-side bootstrap: WSL distro + WezTerm.

.DESCRIPTION
    Convenience wrapper around Install-WslDistro.ps1 and Install-WezTerm.ps1.
    Does not require running elevated; individual steps will warn and point
    you to an elevated re-run only if they actually hit a permissions error.

    Everything specific to the distro's own package manager (git, gh, the
    GitHub Copilot CLI extension, Helix, Zellij, base package updates, ...)
    is provisioned separately, from inside the distro, by a companion
    in-distro setup repository (see README.md).

.PARAMETER DistroName
    Passed through to Install-WslDistro.ps1. Default: Ubuntu

.PARAMETER SetDefault
    Passed through to Install-WslDistro.ps1.

.PARAMETER SkipWezTerm
    Skip installing WezTerm.

.EXAMPLE
    .\Bootstrap.ps1

.EXAMPLE
    .\Bootstrap.ps1 -DistroName Ubuntu-24.04 -SkipWezTerm
#>
[CmdletBinding()]
param(
    [string]$DistroName = 'Ubuntu',
    [switch]$SetDefault,
    [switch]$SkipWezTerm
)

$ErrorActionPreference = 'Stop'

$distroArgs = @{ DistroName = $DistroName }
if ($SetDefault) { $distroArgs['SetDefault'] = $true }
& (Join-Path $PSScriptRoot 'Install-WslDistro.ps1') @distroArgs

if (-not $SkipWezTerm) {
    & (Join-Path $PSScriptRoot 'Install-WezTerm.ps1')
}
else {
    Write-Host 'Skipping WezTerm install (-SkipWezTerm).' -ForegroundColor DarkGray
}
