<#
.SYNOPSIS
    Shared helper functions for the setup scripts in this repository.
#>

function Test-IsElevated {
    <#
    .SYNOPSIS
        Returns $true if the current PowerShell process is running elevated
        (as Administrator).
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-ElevationHint {
    <#
    .SYNOPSIS
        Prints a consistent hint pointing the user at re-running elevated,
        used when an operation fails in a way that looks permissions-related.
    #>
    param(
        [Parameter(Mandatory)][string]$Context
    )
    Write-Warning "$Context failed. If this looks like a permissions error, re-run this script from an elevated ('Run as Administrator') PowerShell session and try again."
}

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}
