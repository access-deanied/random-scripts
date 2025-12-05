# Define the target version you want to reach
$expectedVersion = [version]"2.25"

# 1. Define Standard System Paths
$searchPaths = @(
    "$env:ProgramFiles\Vonage Business\Vonage Business.exe",
    "${env:ProgramFiles(x86)}\Vonage Business\Vonage Business.exe"
)

# 2. Add User Profile Paths (Since Intune runs as SYSTEM, we must scan C:\Users manually)
# Vonage typically installs to AppData\Local for user-context installs
$userProfiles = Get-ChildItem "C:\Users" -Directory
foreach ($user in $userProfiles) {
    $searchPaths += "$($user.FullName)\AppData\Local\Programs\vonage\Vonage Business.exe"
}

# Initialize variables
$highestVersionFound = $null
$isInstalled = $false

# 3. Loop through ALL paths to find the highest installed version
foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $isInstalled = $true
        
        # Get version
        $rawVersion = (Get-Item $path).VersionInfo.ProductVersion
        try {
            $foundVersion = [version]$rawVersion
        }
        catch {
            Write-Output "Warning: Could not parse version for $path"
            continue
        }

        # Keep track of the highest version found on the machine
        if ($null -eq $highestVersionFound -or $foundVersion -gt $highestVersionFound) {
            $highestVersionFound = $foundVersion
        }
    }
}

# 4. Final Compliance Logic
if ($isInstalled) {
    if ($highestVersionFound -ge $expectedVersion) {
        Write-Output "Compliant: Found version $highestVersionFound (Target: $expectedVersion)"
        exit 0
    } else {
        Write-Output "Outdated: Highest version found is $highestVersionFound. Upgrade required."
        exit 1
    }
} else {
    Write-Output "Not Detected: Vonage Business not found in Program Files or User Profiles."
    exit 1
}