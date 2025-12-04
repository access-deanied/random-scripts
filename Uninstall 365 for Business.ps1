
<# Remove Microsoft 365 Apps for business - en-us (Click-to-Run) via UninstallString #>

$Log = "C:\Windows\Temp\Remove-M365Business-UninstallString.log"

function Write-Log { param([string]$m)
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "$ts  $m"
  Write-Host $line
  Add-Content -Path $Log -Value $line -ErrorAction SilentlyContinue
}

# 1) Locate uninstall entries (both 64-bit and 32-bit branches)
$uninstallRoots = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

Write-Log "Searching uninstall registry for 'Microsoft 365 Apps for business - en-us' ..."
$targets = foreach ($root in $uninstallRoots) {
  Get-ItemProperty -Path "$root\*" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.DisplayName -and
      ($_.DisplayName -like 'Microsoft 365 Apps for business*en-us*')
    }
}

if (-not $targets) {
  Write-Log "No matching uninstall entries found."
} else {
  $targets | ForEach-Object {
    $name = $_.DisplayName
    $uninstall = $_.UninstallString
    if (-not $uninstall) {
      Write-Log "WARN: No UninstallString for [$name]."
      return
    }

    # Some UninstallString values include quoted exe path + args; split safely
    $exe   = ($uninstall -split '"')[1]
    $args  = ($uninstall -split '"')[2]
    if (-not $exe) { Write-Log "ERROR: Could not parse EXE from UninstallString: $uninstall"; return }

    # Add DisplayLevel=False for silent C2R removal when supported
    if ($args) { $args = "$args DisplayLevel=False" } else { $args = "DisplayLevel=False" }

    Write-Log "Uninstalling [$name]"
    Write-Log "EXE: $exe"
    Write-Log "ARGS: $args"

    try {
      $p = Start-Process -FilePath $exe -ArgumentList $args -PassThru -Wait
      Write-Log "Process exit code: $($p.ExitCode)"
    } catch {
      Write-Log "ERROR starting uninstall for [$name]: $_"
    }
  }
}

# 2) Verification: check uninstall entries again
Start-Sleep -Seconds 5
$remaining = foreach ($root in $uninstallRoots) {
  Get-ItemProperty -Path "$root\*" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.DisplayName -and
      ($_.DisplayName -like 'Microsoft 365 Apps for business*en-us*')
    }
}
if ($remaining) {
  Write-Log "WARNING: Entry still present after uninstall attempt: $($remaining.DisplayName -join ', ')"
} else {
  Write-Log "SUCCESS: 'Microsoft 365 Apps for business - en-us' no longer present in uninstall list."
}

# 3) Secondary verification: check Click-to-Run ProductReleaseIds
function Get-C2RIds {
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration'
  )
  $ids = @()
  foreach ($p in $paths) {
    try {
      $cfg = Get-ItemProperty -Path $p -ErrorAction Stop
      if ($cfg.ProductReleaseIds) {
        $ids += ($cfg.ProductReleaseIds -split ',' | ForEach-Object { $_.Trim() })
      }
    } catch { }
  }
  $ids | Select-Object -Unique
}

$ids = Get-C2RIds
Write-Log ("Current ProductReleaseIds: " + ($ids -join ', '))

Write-Log "Script completed."
