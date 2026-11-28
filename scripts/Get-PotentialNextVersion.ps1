<#
.SYNOPSIS
    Calculates the next version based on git tags and bump type.

.DESCRIPTION
    Gets the latest version tag from git and calculates the next version
    based on the specified bump type (major, minor, patch).

.PARAMETER BumpType
    The type of version bump: major, minor, or patch.

.EXAMPLE
    Get-PotentialNextVersion -BumpType patch
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('major', 'minor', 'patch')]
    [string]$BumpType
)

try {
    $tags = @(git tag --sort=version:refname | Where-Object -FilterScript { $_ -match '^v?\d+\.\d+\.\d+$' })

    if ($tags.Count -eq 0) {
        switch ($BumpType) {
            'major' { Write-Output -InputObject '1.0.0'; return }
            'minor' { Write-Output -InputObject '0.1.0'; return }
            'patch' { Write-Output -InputObject '0.0.1'; return }
        }
    }

    $latestTag = $tags[-1]
    $cleanVersion = $latestTag -replace '^v', ''
    $parts = $cleanVersion -split '\.'

    [int]$major = $parts[0]
    [int]$minor = $parts[1]
    [int]$patch = $parts[2]

    switch ($BumpType) {
        'major' {
            $newVersion = "$($major + 1).0.0"
        }
        'minor' {
            $newVersion = "$major.$($minor + 1).0"
        }
        'patch' {
            $newVersion = "$major.$minor.$($patch + 1)"
        }
    }

    Write-Verbose -Message "Current version: $cleanVersion"
    Write-Verbose -Message "Bump type: $BumpType"
    Write-Verbose -Message "Next version: $newVersion"

    Write-Output -InputObject $newVersion

} catch {
    Write-Error -Message "Failed to calculate next version: $_"
    exit 1
}
