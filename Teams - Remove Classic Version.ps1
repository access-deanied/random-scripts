<#
    Delete Teams folder under all user profiles if found.
    Target: C:\Users\<Profile>\AppData\Local\Microsoft\Teams

    Output: Table showing Profile, TeamsPath, Exists (True/False), Action (Deleted/NotFound/Failed), and Notes.
    Optional: Use -WhatIf to simulate without deleting.
    Optional: Export to CSV by uncommenting the Export-CSV section at the bottom.

    Run as admin for best results (to access all profiles).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Set the root users directory (change if your profiles live elsewhere)
$UsersRoot = 'C:\Users'

# Exclude built-in/system profiles that won't have typical AppData
$ExcludedProfiles = @('Public', 'Default', 'Default User', 'All Users', 'Administrator') # adjust if needed

# Collect results
$results = @()

# Enumerate profile directories
Get-ChildItem -Path $UsersRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {

    $profileName = $_.Name

    # Skip excluded or junction-like entries
    if ($ExcludedProfiles -contains $profileName) {
        return
    }

    # Construct full Teams path
    $teamsPath = Join-Path -Path $_.FullName -ChildPath 'AppData\Local\Microsoft\Teams'

    # Some profiles may not have loaded AppData yet; handle gracefully
    $exists = $false
    $action = 'NotFound'
    $note = $null

    try {
        $exists = Test-Path -LiteralPath $teamsPath
    }
    catch {
        $exists = $false
        $action = 'Failed'
        $note = "Access error during test: $($_.Exception.Message)"
    }

    if ($exists) {
        # Attempt deletion
        try {
            if ($PSCmdlet.ShouldProcess($teamsPath, "Remove-Item -Recurse -Force")) {
                Remove-Item -LiteralPath $teamsPath -Recurse -Force -ErrorAction Stop
                $action = 'Deleted'
                $note = $null
            }
            else {
                # When using -WhatIf or ShouldProcess declines
                $action = 'WouldDelete'
                $note = 'Simulated via -WhatIf'
            }
        }
        catch {
            $action = 'Failed'
            $note = "Delete error: $($_.Exception.Message)"
        }
    }

    $results += [PSCustomObject]@{
        Profile    = $profileName
        TeamsPath  = $teamsPath
        Exists     = $exists
        Action     = $action
        Notes      = $note
    }
}

# Display results
$results | Sort-Object Profile | Format-Table -AutoSize

# Uncomment to export results to CSV
# $csvPath = 'C:\Temp\TeamsFolderDeleteResults.csv'
# New-Item -ItemType Directory -Path (Split-Path $csvPath) -Force | Out-Null
# $results | Export-Csv -Path $csvPath -NoTypeInformation