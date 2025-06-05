param (
    [Parameter(Mandatory)]
    [ValidateSet('major', 'minor', 'patch')]
    [string]$BumpType
)

# Ultra-simple implementation for testing
try {
    # Get latest tag
    $tags = @(git tag | Where-Object { $_ -match '^v?\d+\.\d+\.\d+$' })
    if ($tags.Count -eq 0) {
        # No tags, return default
        switch ($BumpType) {
            'major' { Write-Output '1.0.0'; return }
            'minor' { Write-Output '0.1.0'; return }
            'patch' { Write-Output '0.0.1'; return }
        }
    }

    # Sort manually to avoid issues
    $sorted = $tags | ForEach-Object {
        $clean = $_ -replace '^v', ''
        $parts = $clean -split '\.'
        [PSCustomObject]@{
            Tag   = $_
            Major = [int]$parts[0]
            Minor = [int]$parts[1]
            Patch = [int]$parts[2]
            Clean = $clean
        }
    } | Sort-Object -Property Major, Minor, Patch -Descending

    $latest = $sorted | Select-Object -First 1

    # Calculate new version
    switch ($BumpType) {
        'major' {
            $new = "$($latest.Major + 1).0.0"
        }
        'minor' {
            $new = "$($latest.Major).$($latest.Minor + 1).0"
        }
        'patch' {
            $new = "$($latest.Major).$($latest.Minor).$($latest.Patch + 1)"
        }
    }

    Write-Output $new

} catch {
    Write-Error $_
    exit 1
}