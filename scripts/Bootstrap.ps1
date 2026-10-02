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

.PARAMETER Reinstall
    Passed through to Install-WslDistro.ps1. If the distro is already
    installed, remove it and install a fresh copy instead of skipping.
    THIS PERMANENTLY DELETES ALL DATA in the existing instance. You'll be
    prompted to confirm unless -Force is also passed.

.PARAMETER Force
    Passed through to Install-WslDistro.ps1. Skips the reinstall
    confirmation prompt, for non-interactive/scripted runs.

.PARAMETER SkipWezTerm
    Skip installing WezTerm.

.PARAMETER SkipNerdFont
    Skip installing the JetBrainsMono Nerd Font. Installed by default for
    consistent glyph rendering (icons in tmux's status bar, eza, shell
    prompts, etc.), even though WezTerm has its own built-in fallback.

.PARAMETER SkipGitHooks
    Skip installing the global commit-msg hook that rejects commits
    crediting Copilot as a co-author.

.EXAMPLE
    .\Bootstrap.ps1

.EXAMPLE
    .\Bootstrap.ps1 -DistroName Ubuntu-26.04 -SkipWezTerm

.EXAMPLE
    # Wipe and reinstall the existing distro from scratch
    .\Bootstrap.ps1 -Reinstall

.EXAMPLE
    # Same, but non-interactive (e.g. CI or automation)
    .\Bootstrap.ps1 -Reinstall -Force
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$DistroName = 'Ubuntu',
    [switch]$SetDefault,
    [switch]$Reinstall,
    [switch]$Force,
    [switch]$SkipWezTerm,
    [switch]$SkipNerdFont,
    [switch]$SkipGitHooks
)

$ErrorActionPreference = 'Stop'

$distroArgs = @{ DistroName = $DistroName }
if ($SetDefault) { $distroArgs['SetDefault'] = $true }
if ($Reinstall) { $distroArgs['Reinstall'] = $true }
if ($Force) { $distroArgs['Force'] = $true }
if ($WhatIfPreference) { $distroArgs['WhatIf'] = $true }
& (Join-Path $PSScriptRoot 'Install-WslDistro.ps1') @distroArgs

if (-not $SkipWezTerm) {
    & (Join-Path $PSScriptRoot 'Install-WezTerm.ps1')
}
else {
    Write-Host 'Skipping WezTerm install (-SkipWezTerm).' -ForegroundColor DarkGray
}

if (-not $SkipNerdFont) {
    & (Join-Path $PSScriptRoot 'Install-NerdFont.ps1')
}
else {
    Write-Host 'Skipping Nerd Font install (-SkipNerdFont).' -ForegroundColor DarkGray
}

if (-not $SkipGitHooks) {
    & (Join-Path $PSScriptRoot 'Install-GitHooks.ps1')
}
else {
    Write-Host 'Skipping git hooks install (-SkipGitHooks).' -ForegroundColor DarkGray
}
