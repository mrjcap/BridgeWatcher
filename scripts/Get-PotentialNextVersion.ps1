<#
.SYNOPSIS
    Calculates the next potential version based on bump type and latest stable tag.
.DESCRIPTION
    Finds the latest stable Git tag (vX.Y.Z or X.Y.Z), increments according to bump type,
    and outputs the next version. Does NOT modify any files.
.PARAMETER BumpType
    The type of version bump: 'major', 'minor', or 'patch'.
.EXAMPLE
    ./Get-PotentialNextVersion.ps1 -BumpType patch
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('major','minor','patch')]
    [string]$BumpType
)

function Get-LatestStableTag {
    $tags = git tag --sort=-v:refname | Where-Object { $_ -match '^v?\d+\.\d+\.\d+$' }
    return $tags | Select-Object -First 1
}

$latestTag = Get-LatestStableTag

if (-not $latestTag) {
    switch ($BumpType) {
        'major' { Write-Output '1.0.0'; exit 0 }
        'minor' { Write-Output '0.1.0'; exit 0 }
        'patch' { Write-Output '0.0.1'; exit 0 }
        default { throw "Invalid bump type" }
    }
}

$versionString = $latestTag -replace '^v', ''
$versionParts = $versionString -split '\.'
if ($versionParts.Count -ne 3) {
    throw "Latest tag '$latestTag' is not in expected format X.Y.Z"
}

[int]$major = $versionParts[0]
[int]$minor = $versionParts[1]
[int]$patch = $versionParts[2]

switch ($BumpType) {
    'major' {
        $major++; $minor=0; $patch=0
    }
    'minor' {
        $minor++; $patch=0
    }
    'patch' {
        $patch++
    }
}

Write-Output "$major.$minor.$patch"