# Define expected version
$expectedVersion = "17.4.1"

# Define Keeper x86 install path
$keeperPath = "C:\Program Files (x86)\Keeper Password Manager"
$exePath = Join-Path $keeperPath "KeeperPasswordManager.exe"

# Check if Keeper is installed
if (Test-Path $exePath) {
    $fileVersion = (Get-Item $exePath).VersionInfo.ProductVersion
    if ($fileVersion -eq $expectedVersion) {
        Write-Output "Keeper is up to date"
        exit 0
    } else {
        Write-Output "Keeper is installed but outdated: $fileVersion"
        exit 1  # Trigger update via Intune
    }
} else {
    Write-Output "Keeper is not installed"
    exit 1  # Trigger install via Intune
}