
# Get all user profile directories under C:\Users
$UserProfiles = Get-ChildItem 'C:\Users' -Directory | Where-Object {
    Test-Path "$($_.FullName)\AppData\Local\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy"
}

foreach ($profile in $UserProfiles) {
    $basePath = "$($profile.FullName)\AppData\Local\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy"
    $assetsPath = "$basePath\LocalState\Assets"
    $settingsPath = "$basePath\Settings"

    Write-Host "Resetting Windows Spotlight for user: $($profile.Name)"

    if (Test-Path $assetsPath) {
        Remove-Item "$assetsPath\*" -Force -Recurse -ErrorAction SilentlyContinue
    }

    if (Test-Path $settingsPath) {
        Remove-Item "$settingsPath\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Re-register Content Delivery Manager for all users
Get-AppxPackage -AllUsers Microsoft.Windows.ContentDeliveryManager | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}

Write-Host "Windows Spotlight cache reset completed for all users."
