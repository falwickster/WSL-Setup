<#
.SYNOPSIS
    Idempotently installs a global commit-msg git hook that rejects any
    commit crediting Copilot (or another AI assistant) as a co-author.

.DESCRIPTION
    Points git's global core.hooksPath at the commit-msg hook deployed by
    the dotfiles repo (%USERPROFILE%\.git-hooks\commit-msg) - the same
    way, and for the same reason, as git-config'd user.name/user.email:
    once per machine/user, applying to every repo (including ones cloned
    fresh in the future), not just the ones this setup touches directly.

    Requires the dotfiles repo to already be checked out into %USERPROFILE%
    (see https://github.com/falwickster/dotfiles) and git for Windows to be
    installed and on PATH.

.EXAMPLE
    .\Install-GitHooks.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

if (-not (Test-CommandExists -Name 'git')) {
    Write-Host 'git not found on PATH, skipping git hook install.' -ForegroundColor Yellow
    exit 0
}

$hooksDir = Join-Path $env:USERPROFILE '.git-hooks'
$hookFile = Join-Path $hooksDir 'commit-msg'

if (-not (Test-Path $hookFile)) {
    Write-Host "$hookFile not found (expected to be deployed by the dotfiles checkout)." -ForegroundColor Yellow
    Write-Host 'Deploy https://github.com/falwickster/dotfiles into your home directory first, then re-run this script.' -ForegroundColor Yellow
    exit 0
}

# Git for Windows runs hooks through its own bundled sh.exe, which honors
# Unix-style LF line endings and the shebang regardless of Windows file
# permission bits, so no chmod equivalent is needed here.
$hooksPathForGit = $hooksDir -replace '\\', '/'
$currentHooksPath = (git config --global --get core.hooksPath 2>$null)

if ($currentHooksPath -eq $hooksPathForGit) {
    Write-Host "git core.hooksPath already set to $hooksPathForGit, skipping." -ForegroundColor DarkGray
}
else {
    git config --global core.hooksPath $hooksPathForGit
    Write-Host "git core.hooksPath set to $hooksPathForGit." -ForegroundColor Green
}

Write-Host 'Copilot co-author commit-msg hook active globally.' -ForegroundColor Green
