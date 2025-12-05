<#
.SYNOPSIS
    Cleans up Microsoft Intune enrollment artifacts to facilitate re-enrollment.
.DESCRIPTION
    This script performs the following actions:
    1. Unjoins the device from Azure AD / Entra ID.
    2. Uninstalls the Microsoft Intune Management Extension.
    3. Removes Intune-related scheduled tasks.
    4. Cleans up leftover ProgramData files.
    5. Removes specific enrollment registry keys (Use with caution).
.NOTES
    Run as Administrator.
#>

Write-Host "Starting Intune Cleanup Process..." -ForegroundColor Cyan

# 1. Unjoin from Azure AD / Entra ID
Write-Host "Step 1: Leaving Azure AD..." -ForegroundColor Yellow
try {
    # /leave removes the device from Azure AD and unenrolls it from MDM
    & dsregcmd.exe /leave
    Write-Host "Device leave command executed." -ForegroundColor Green
}
catch {
    Write-Error "Failed to execute dsregcmd. Ensure you are running as Admin."
}

# 2. Uninstall Microsoft Intune Management Extension
Write-Host "Step 2: Uninstalling Intune Management Extension..." -ForegroundColor Yellow
$ime = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Microsoft Intune Management Extension" }

if ($ime) {
    try {
        $ime.Uninstall() | Out-Null
        Write-Host "Intune Management Extension uninstalled successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to uninstall Intune Management Extension."
    }
}
else {
    Write-Host "Intune Management Extension not found." -ForegroundColor Gray
}

# 3. Cleanup Files and Folders
Write-Host "Step 3: Removing Intune ProgramData folders..." -ForegroundColor Yellow
$pathsToRemove = @(
    "C:\ProgramData\Microsoft\IntuneManagementExtension",
    "C:\ProgramData\Microsoft\IntuneManagementExtension.log"
)

foreach ($path in $pathsToRemove) {
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed: $path" -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not remove $path. It may be in use or require a reboot."
        }
    }
}

# 4. Cleanup Scheduled Tasks
# Note: Uninstalling the extension usually removes these, but this ensures they are gone.
Write-Host "Step 4: Checking for leftover Scheduled Tasks..." -ForegroundColor Yellow
$tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Intune*" -or $_.TaskPath -like "*Intune*" }

foreach ($task in $tasks) {
    try {
        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Removed Task: $($task.TaskName)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to remove task: $($task.TaskName)"
    }
}

# 5. Cleanup Enrollment Registry Keys (Advanced)
# WARNING: This removes the enrollment info from the registry. 
# Only necessary if the device is stuck in a loop.
Write-Host "Step 5: Cleaning Enrollment Registry Keys..." -ForegroundColor Yellow
$enrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"

if (Test-Path $enrollmentPath) {
    $keys = Get-ChildItem $enrollmentPath
    foreach ($key in $keys) {
        # We avoid deleting the 'Context', 'Status', and 'ValidNode' generic keys usually found here.
        # We look for GUID-based keys which represent specific enrollments.
        if ($key.PSChildName -match "^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$") {
            try {
                Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "Removed Enrollment Key: $($key.PSChildName)" -ForegroundColor Green
            }
            catch {
                Write-Warning "Could not remove registry key: $($key.PSChildName)"
            }
        }
    }
}

Write-Host "---"
Write-Host "Cleanup Complete." -ForegroundColor Cyan
Write-Host "Please REBOOT your machine before attempting to re-enroll." -ForegroundColor Cyan
Write-Host "Ensure the device object is deleted from Intune/Azure AD portals by an admin." -ForegroundColor Cyan