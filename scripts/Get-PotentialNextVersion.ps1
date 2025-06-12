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
    # Get all version tags
    $tags = @(git tag --sort=version:refname | Where-Object { $_ -match '^v?\d+\.\d+\.\d+$' })

    if ($tags.Count -eq 0) {
        # No tags exist, return default based on bump type
        switch ($BumpType) {
            'major' { Write-Output '1.0.0'; return }
            'minor' { Write-Output '0.1.0'; return }
            'patch' { Write-Output '0.0.1'; return }
        }
    }

    # Get the latest tag
    $latestTag = $tags[-1]
    $cleanVersion = $latestTag -replace '^v', ''
    $parts = $cleanVersion -split '\.'

    [int]$major = $parts[0]
    [int]$minor = $parts[1]
    [int]$patch = $parts[2]

    # Calculate new version
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

    Write-Verbose "Current version: $cleanVersion"
    Write-Verbose "Bump type: $BumpType"
    Write-Verbose "Next version: $newVersion"

    Write-Output $newVersion

} catch {
    Write-Error "Failed to calculate next version: $_"
    exit 1
}