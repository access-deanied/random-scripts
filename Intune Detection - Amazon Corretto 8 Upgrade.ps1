# Define expected version
$expectedVersion = "1.8.0_472"  # Update to match your latest pushed version

# Define possible install paths
$paths = @(
    "C:\Program Files\Amazon Corretto",
    "C:\Program Files (x86)\Amazon Corretto"
)

$installedVersion = $null

foreach ($basePath in $paths) {
    if (Test-Path $basePath) {
        # Look for JDK folders matching the pattern
        $jdkFolders = Get-ChildItem $basePath -Directory | Where-Object { $_.Name -like "jdk1.8.0_*" }
        foreach ($folder in $jdkFolders) {
            if ($folder.Name -eq "jdk$expectedVersion") {
                Write-Output "Amazon Corretto is up to date"
                exit 0
            } else {
                $installedVersion = $folder.Name
            }
        }
    }
}

if ($installedVersion) {
    Write-Output "Amazon Corretto is installed but outdated: $installedVersion"
    exit 1  # Trigger update via Intune
} else {
    Write-Output "Amazon Corretto is not installed"
    exit 0  # Do NOT trigger install via Intune
}