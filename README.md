# WSL-Setup

Windows-side bootstrap for a WSL2 development environment. This repository
is deliberately scoped to **Windows-side setup only**, and is
distro-agnostic so you can distro-hop later without rewriting it:

- Registering an officially Microsoft-supported WSL2 distro (via
  `wsl --install -d <Name>` — no custom/unofficial rootfs building).
  Defaults to `Ubuntu`.
- Installing [WezTerm](https://wezterm.org/) as the terminal (via
  Chocolatey), idempotently.

None of the scripts require running elevated up front. If a step actually
needs administrator rights (enabling the WSL optional component, some
Chocolatey installs), it fails with a clear message telling you to re-run
that step from an elevated PowerShell session — elevation isn't assumed by
default.

All Linux-side provisioning (package installs, `git`, GitHub CLI + Copilot
CLI, Helix, Zellij, Podman, base package updates, etc.) lives in a
separate, distro-specific repository, run from *inside* the distro. For the
default distro (Ubuntu), that's
[Ubuntu-Setup](https://github.com/falwickster/Ubuntu-Setup), pulled in here
as a **git submodule** at `Ubuntu-Setup/`. If you distro-hop to something
else later, use that distro's own equivalent setup repo the same way (a
submodule is optional — it's just how the default is wired here); the
Windows-side scripts in this repo don't need to change either way.

Even with the submodule present, this stays a simple two-step process:

1. Set up WSL + the distro + WezTerm on Windows (this repo).
2. Open the distro and run the submodule's provisioning script from inside
   it.

Every install step here — and in Ubuntu-Setup — checks first whether its
target is already present and skips reinstalling it if so.

Clone this repo with submodules:

```powershell
git clone --recurse-submodules https://github.com/falwickster/WSL-Setup.git
# or, if already cloned without --recurse-submodules:
git submodule update --init --recursive
```

## Prerequisites

- Windows 10/11 with the WSL2 feature available. If `wsl --status` fails,
  run (from an elevated session) `wsl --install --no-distribution` and
  reboot if prompted, then continue below as a normal user.
- [Chocolatey](https://chocolatey.org/) — installed automatically by
  `Install-WezTerm.ps1` if missing (may require elevation; see above).

## Usage

Run everything in one go:

```powershell
.\scripts\Bootstrap.ps1
```

Or run steps individually:

```powershell
# Install/register the WSL distro only (default: Ubuntu)
.\scripts\Install-WslDistro.ps1

# Use a different distro name (must be a current `wsl --list --online` NAME)
.\scripts\Install-WslDistro.ps1 -DistroName Ubuntu-24.04 -SetDefault

# Install/upgrade WezTerm only
.\scripts\Install-WezTerm.ps1
```

See the comment-based help in each script (`Get-Help .\scripts\Install-WslDistro.ps1 -Full`)
for all parameters.

## What happens next

The first launch of a newly installed distro opens its own console window
and asks you to create a UNIX username/password interactively — this can't
be automated safely, so complete that yourself. After that, open the distro
and run the Ubuntu-Setup submodule's install script (paths below assume you
cloned this repo to `C:\...\WSL-Setup`, adjust the Windows drive mapping if
different):

```bash
wsl -d Ubuntu
cd /mnt/c/.../WSL-Setup/Ubuntu-Setup
./install.sh
```

That companion repository handles everything inside the distro: base
package updates, `git`, GitHub CLI (`gh`, with GitHub Copilot CLI support),
the Helix editor, Zellij, and Podman — each checked for existing
installation before being installed. See
[Ubuntu-Setup's README](https://github.com/falwickster/Ubuntu-Setup) for
details.

## Repository layout

```
scripts/
  Bootstrap.ps1          # Runs WSL distro install + WezTerm install
  Install-WslDistro.ps1  # Idempotently registers an officially supported WSL2 distro
  Install-WezTerm.ps1    # Installs Chocolatey (if needed) + WezTerm, idempotently
  Common.ps1             # Shared helpers (elevation checks/hints, command detection)
Ubuntu-Setup/            # Submodule: in-distro provisioning for the default (Ubuntu) distro
```