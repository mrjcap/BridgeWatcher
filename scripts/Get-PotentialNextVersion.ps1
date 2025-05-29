[CmdletBinding()]
<#
.SYNOPSIS
Υπολογίζει την επόμενη πιθανή έκδοση χωρίς να τροποποιεί αρχεία.

.DESCRIPTION
Η Get-PotentialNextVersion αναλύει τα Git tags για να βρει την τελευταία σταθερή
έκδοση και υπολογίζει την επόμενη βάσει του τύπου αύξησης (major/minor/patch).

.PARAMETER BumpType
Ο τύπος αύξησης έκδοσης: 'major', 'minor', ή 'patch'.

.OUTPUTS
[string] - Η υπολογισμένη έκδοση (π.χ. 1.2.4).

.EXAMPLE
Get-PotentialNextVersion -BumpType 'patch'
# Επιστρέφει: 1.0.39 (αν η τελευταία έκδοση είναι 1.0.38)

.EXAMPLE
Get-PotentialNextVersion -BumpType 'minor'
# Επιστρέφει: 1.1.0 (αν η τελευταία έκδοση είναι 1.0.38)

.NOTES
Αγνοεί pre-release tags και υποστηρίζει μορφές vX.Y.Z και X.Y.Z.
#>
param (
    [Parameter(Mandatory)]
    [ValidateSet('major', 'minor', 'patch')]
    [string]$BumpType
)

# Βήμα 1: Ανάκτηση όλων των tags
$writeBridgeLogSplat = @{
    Message = "🔍 Αναζήτηση Git tags..."
}
Write-Verbose @writeBridgeLogSplat

$gitTagSplat = @{
    ArgumentList = @('tag', '--sort=-v:refname')
    NoNewWindow  = $true
    Wait         = $true
    PassThru     = $true
}
$tagProcess = Start-Process -FilePath 'git' @gitTagSplat
$allTags = $tagProcess.StandardOutput.ReadToEnd() -split "`n" | Where-Object { $_ }

# Βήμα 2: Φιλτράρισμα για σταθερές εκδόσεις
$stableTags = $allTags | Where-Object { $_ -match '^v?\d+\.\d+\.\d+$' }
$latestTag = $stableTags | Select-Object -First 1

$writeBridgeLogSplat = @{
    Message = "📌 Τελευταίο σταθερό tag: $($latestTag ?? 'Κανένα')"
}
Write-Verbose @writeBridgeLogSplat

# Βήμα 3: Προσδιορισμός αρχικής έκδοσης
if (-not $latestTag) {
    $version = switch ($BumpType) {
        'major' { '1.0.0' }
        'minor' { '0.1.0' }
        'patch' { '0.0.1' }
    }
    $writeBridgeLogSplat = @{
        Message = "🆕 Δεν βρέθηκαν tags. Χρήση προεπιλογής: $version"
    }
    Write-Verbose @writeBridgeLogSplat
    Write-Output $version
    return
}

# Βήμα 4: Ανάλυση της τρέχουσας έκδοσης
$cleanVersion = $latestTag -replace '^v', ''
$versionParts = $cleanVersion -split '\.'

$major = [int]$versionParts[0]
$minor = [int]$versionParts[1]
$patch = [int]$versionParts[2]

# Βήμα 5: Υπολογισμός νέας έκδοσης
$newVersion = switch ($BumpType) {
    'major' {
        "$($major + 1).0.0"
    }
    'minor' {
        "$major.$($minor + 1).0"
    }
    'patch' {
        "$major.$minor.$($patch + 1)"
    }
}

$writeBridgeLogSplat = @{
    Message = "✅ Υπολογισμένη έκδοση: $newVersion"
}
Write-Verbose @writeBridgeLogSplat

Write-Output $newVersion