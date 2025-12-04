
<#
.SYNOPSIS
  Escrows BitLocker RecoveryPassword protectors for all encrypted volumes to Microsoft Entra ID (Azure AD).

.DESCRIPTION
  - Enumerates all BitLocker volumes.
  - Ensures a RecoveryPassword protector exists; adds one if missing.
  - Calls BackupToAAD-BitLockerKeyProtector per volume.
  - Writes structured logs to %ProgramData%\BitLockerEscrow\.
  - Returns 0 on success, 1 on any failure (per-device).

.NOTES
  Run as SYSTEM. Recommended in Intune (Devices > Scripts) with 64-bit PowerShell.
#>

#region Utilities
$ErrorActionPreference = 'Stop'

$LogRoot = Join-Path $env:ProgramData 'BitLockerEscrow'
$null = New-Item -Path $LogRoot -ItemType Directory -Force
$LogFile = Join-Path $LogRoot ("Escrow_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0}`t{1}`t{2}' -f (Get-Date -Format 'o'), $Level, $Message
    $line | Tee-Object -FilePath $LogFile -Append | Out-Null
}

function Test-EntraJoin {
    # Parse dsregcmd /status to show AzureAdJoined and DomainJoined
    try {
        $status = dsregcmd /status | Out-String
        $aad = ($status -split "`n") | Where-Object { $_ -match '^\s*AzureAdJoined\s*:\s*(YES|NO)' } |
               ForEach-Object { ($_ -split ':')[1].Trim().ToUpper() }
        $dj = ($status -split "`n") | Where-Object { $_ -match '^\s*DomainJoined\s*:\s*(YES|NO)' } |
              ForEach-Object { ($_ -split ':')[1].Trim().ToUpper() }
        [PSCustomObject]@{ AzureAdJoined = $aad; DomainJoined = $dj }
    } catch {
        [PSCustomObject]@{ AzureAdJoined = 'UNKNOWN'; DomainJoined = 'UNKNOWN' }
    }
}
#endregion Utilities

#region Pre-checks
if (-not (Get-Command -Name BackupToAAD-BitLockerKeyProtector -ErrorAction SilentlyContinue)) {
    Write-Log "Required cmdlet 'BackupToAAD-BitLockerKeyProtector' not found. Ensure Windows BitLocker PowerShell module is present." 'ERROR'
    # This cmdlet ships with supported Windows builds. It is required to escrow to Entra ID. 
    # https://learn.microsoft.com/powershell/module/bitlocker/backuptoaad-bitlockerkeyprotector
    exit 1
}

$joinState = Test-EntraJoin
Write-Log ("Join state: AzureAdJoined={0}, DomainJoined={1}" -f $joinState.AzureAdJoined, $joinState.DomainJoined)
#endregion Pre-checks

#region Escrow workflow
$overallFailed = $false

try {
    $bitlockerVolumes = Get-BitLockerVolume

    foreach ($vol in $bitlockerVolumes) {
        $mp = $vol.MountPoint
        if ([string]::IsNullOrWhiteSpace($mp)) { continue } # skip volumes without mountpoint (e.g., hidden partitions)

        # Only attempt escrow on volumes that are protected/encrypted or encrypting
        $isCandidate = $vol.ProtectionStatus -eq 'On' -or $vol.VolumeStatus -in @('FullyEncrypted','EncryptionInProgress')
        if (-not $isCandidate) {
		Write-Log "Skipping ${mp}: BitLocker not protecting/encrypting."
            continue
        }

        # Ensure a RecoveryPassword protector exists (required for escrow)
        $rpProtectors = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
        if (-not $rpProtectors -or $rpProtectors.Count -eq 0) {
            Write-Log "No RecoveryPassword protector on $mp. Adding one..."
            $null = Add-BitLockerKeyProtector -MountPoint $mp -RecoveryPasswordProtector
            # Refresh
            $vol = Get-BitLockerVolume -MountPoint $mp
            $rpProtectors = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
        }

        # Escrow each RecoveryPassword protector found (covers multiple encrypted volumes)
        foreach ($kp in $rpProtectors) {
            try {
                Write-Log ("Escrowing RecoveryPassword protector for {0}, KeyProtectorId={1} ..." -f $mp, $kp.KeyProtectorId)
                BackupToAAD-BitLockerKeyProtector -MountPoint $mp -KeyProtectorId $kp.KeyProtectorId -ErrorAction Stop
                Write-Log ("SUCCESS: Escrowed {0} (KeyProtectorId={1}) to Entra." -f $mp, $kp.KeyProtectorId)
            } catch {
                Write-Log ("FAILED: {0} KeyProtectorId={1} — {2}" -f $mp, $kp.KeyProtectorId, $_.Exception.Message) 'ERROR'
                $overallFailed = $true
            }
        }
    }

} catch {
    Write-Log ("Unhandled error: {0}" -f $_.Exception.Message) 'ERROR'
    $overallFailed = $true
}
#endregion Escrow workflow

#region Optional: confirm escrow by checking Event 845 in the BitLocker Management log
# Many environments log Event ID 845 when backup to Azure AD succeeds; useful for detection/compliance.
# https://jonconwayuk.wordpress.com/2022/08/11/intune-proactive-remediation-bitlocker-key-escrow-to-azure-ad-after-mecm-osd-task-sequence/
try {
    $recent = Get-WinEvent -FilterHashTable @{LogName='Microsoft-Windows-BitLocker/BitLocker Management'; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
              Where-Object { $_.Id -eq 845 -and $_.Message -match 'was backed up successfully to your Azure AD' }
    if ($recent) {
        Write-Log ("Verification: Found {0} escrow success event(s) (ID 845) in last 7 days." -f ($recent | Measure-Object).Count)
    } else {
        Write-Log "Verification: No escrow success events (ID 845) found in last 7 days." 'WARN'
    }
} catch {
    Write-Log ("Verification check failed: {0}" -f $_.Exception.Message) 'WARN'
}
#endregion Optional verification

# Intune-friendly exit codes
if ($overallFailed) { exit 1 } else { exit 0 }
