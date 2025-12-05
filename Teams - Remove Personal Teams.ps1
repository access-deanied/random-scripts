
<# 
Remove Teams (personal) for all users + deprovision + block re-install + hide Chat icon
Safe for environments using Teams (work or school) including the new MSTeams client.
#>

$ErrorActionPreference = 'SilentlyContinue'
$consumerPkgName = 'MicrosoftTeams'  # Consumer/MSA appx name

Write-Host "Removing Teams (personal) AppX for all users..."
Get-AppxPackage -AllUsers -Name $consumerPkgName | ForEach-Object {
    Try {
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
        Write-Host "Removed AppX: $($_.PackageFullName)"
    } Catch {
        Write-Warning "Failed to remove $($_.PackageFullName): $($_.Exception.Message)"
    }
}

Write-Host "De-provisioning Teams (personal) from the image..."
$provPkg = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $consumerPkgName }
if ($provPkg) {
    Try {
        Remove-AppxProvisionedPackage -Online -PackageName $provPkg.PackageName -ErrorAction Stop
        Write-Host "Removed provisioned package: $($provPkg.PackageName)"
    } Catch {
        Write-Warning "Failed to remove provisioned package: $($_.Exception.Message)"
    }
} else {
    Write-Host "No provisioned MicrosoftTeams package found."
}

# Prevent Windows from auto-installing consumer Teams again and hide the Chat icon
$commKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications'
if (-not (Test-Path $commKey)) { New-Item -Path $commKey -Force | Out-Null }

# ConfigureChatAutoInstall: 0 = Do not auto-install the Chat (consumer Teams) experience
New-ItemProperty -Path $commKey -Name 'ConfigureChatAutoInstall' -PropertyType DWord -Value 0 -Force | Out-Null

# ConfigureChatIcon: 3 = Hide the Chat icon for all users
New-ItemProperty -Path $commKey -Name 'ConfigureChatIcon' -PropertyType DWord -Value 3 -Force | Out-Null

Write-Host "Completed removal and policy hardening for Teams (personal)."
