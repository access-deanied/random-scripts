
<# 
Clean-TeamsStaleKeys.ps1
Removes stale Teams registry entries across all user hives and optionally deprovisions legacy MicrosoftTeams MSIX.
Run as SYSTEM/Administrator, ideally at startup before users sign in.
#>

[CmdletBinding()]
param(
    [switch]$RemoveProvisionedMicrosoftTeams,
    [string]$LogPath = "C:\Temp\CleanTeamsStaleKeys_$($env:COMPUTERNAME).log"
)

# Prep logging
$logDir = Split-Path $LogPath
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
Start-Transcript -Path $LogPath -ErrorAction SilentlyContinue

Write-Host "Starting Teams stale key cleanup..." -ForegroundColor Cyan

# Enumerate local profiles
$profiles = Get-ChildItem -Path 'C:\Users' -Directory |
            Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }

foreach ($p in $profiles) {
    $nt = Join-Path $p.FullName 'NTUSER.DAT'
    if (-not (Test-Path $nt)) { 
        Write-Host "Skipping (no NTUSER.DAT): $($p.FullName)" -ForegroundColor DarkGray
        continue 
    }

    $hive = "TEMP_$($p.Name.Replace(' ','_'))"
    try {
        # Load hive
        $null = reg load "HKU\$hive" $nt 2>$null

        # Targets to remove
        $targets = @(
            "Registry::HKU\$hive\Software\Microsoft\Windows\CurrentVersion\Uninstall\Teams",
            "Registry::HKU\$hive\Software\Microsoft\Teams",
            "Registry::HKU\$hive\Software\Microsoft\Office\Teams"
        )

        foreach ($key in $targets) {
            if (Test-Path $key) {
                try {
                    Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                    Write-Host "Removed: $($key)" -ForegroundColor Green
                } catch {
                    # IMPORTANT: wrap $key so ':' doesn't break parsing
                    Write-Warning ("Failed to remove {0}: {1}" -f $key, $_.Exception.Message)
                }
            } else {
                Write-Host "Not present: $($key)" -ForegroundColor DarkGray
            }
        }
    } finally {
        # Always unload
        $null = reg unload "HKU\$hive" 2>$null
    }
}

# Optional: remove legacy MicrosoftTeams provisioning so it doesn’t get re-applied to new profiles
if ($RemoveProvisionedMicrosoftTeams) {
    try {
        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'MicrosoftTeams' }
        foreach ($pp in $prov) {
            Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null
            Write-Host "Deprovisioned MicrosoftTeams: $($pp.PackageName)" -ForegroundColor Green
        }
        if (-not $prov) { Write-Host "No MicrosoftTeams provisioning found." -ForegroundColor DarkGray }
    } catch {
        Write-Warning ("Deprovision step failed: {0}" -f $_.Exception.Message)
    }
}

Write-Host "Teams stale key cleanup complete." -ForegroundColor Cyan
Stop-Transcript | Out-Null