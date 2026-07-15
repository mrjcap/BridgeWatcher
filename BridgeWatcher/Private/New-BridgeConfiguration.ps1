function New-BridgeConfiguration {
    <#
    .SYNOPSIS
    Δημιουργεί ένα configuration object για το BridgeWatcher module.

    .DESCRIPTION
    Κεντρικοποιεί όλα τα configuration settings, URLs, patterns και mappings
    που χρησιμοποιούνται στο BridgeWatcher module. Επιστρέφει ένα αντικείμενο
    με Urls, Defaults, Statuses και υπο-αντικείμενα μηνυμάτων.

    .PARAMETER BaseUrl
    Το base URL για τα δεδομένα και εικόνες γεφυρών.

    .PARAMETER OCRApiUrl
    Το URL για τη Google Cloud Vision API.

    .PARAMETER PushoverApiUrl
    Το URL για την αποστολή Pushover notifications.

    .PARAMETER DefaultIntervalSeconds
    Το προεπιλεγμένο διάστημα σε δευτερόλεπτα για τη παρακολούθηση.

    .PARAMETER DefaultMaxIterations
    Ο προεπιλεγμένος μέγιστος αριθμός επαναλήψεων.

    .OUTPUTS
    [PSCustomObject] - Αντικείμενο διαμόρφωσης με Urls, Defaults, Statuses και υπο-αντικείμενα μηνυμάτων.

    .NOTES
    Αυτή η συνάρτηση δημιουργεί μόνο ένα configuration object στη μνήμη και δεν αλλάζει την κατάσταση του συστήματος.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Η συνάρτηση δημιουργεί μόνο το αντικείμενο διαμόρφωσης στη μνήμη, δεν αλλάζει την κατάσταση του συστήματος.')]

    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OCRApiUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PushoverApiUrl,

        [Parameter()]
        [ValidateRange(1, 3600)]
        [int]$DefaultIntervalSeconds = 300,

        [Parameter()]
        [ValidateRange(0, 1000)]
        [int]$DefaultMaxIterations = 100,

        [Parameter()]
        [ValidateRange(1, 1440)]
        [int]$MaxConsecutiveFailures = 60,

        [Parameter()]
        [string]$LogDirectory = ''
    )
    $configPath = Join-Path $PSScriptRoot '..\config.json'
    if (-not (Test-Path $configPath)) {
        throw "Δεν βρέθηκε το αρχείο configuration στο $configPath"
    }

    $jsonConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
        if (Test-Path 'TestDrive:\') {
            $LogDirectory = 'TestDrive:\logs'
        } else {
            $LogDirectory = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'logs'
        }
    }

    if (-not $BaseUrl) { $BaseUrl = $jsonConfig.Urls.Source }
    if (-not $OCRApiUrl) { $OCRApiUrl = $jsonConfig.Urls.OCRApi }
    if (-not $PushoverApiUrl) { $PushoverApiUrl = $jsonConfig.Urls.PushoverApi }

    $jsonConfig.Urls.Source = $BaseUrl.TrimEnd('/') + '/'
    $jsonConfig.Urls.BaseImage = $BaseUrl.TrimEnd('/')
    $jsonConfig.Urls.OCRApi = $OCRApiUrl
    $jsonConfig.Urls.PushoverApi = $PushoverApiUrl

    # Override defaults if passed explicitly
    if ($PSBoundParameters.ContainsKey('DefaultIntervalSeconds')) {
        $jsonConfig.Defaults.IntervalSeconds = $DefaultIntervalSeconds
    }
    if ($PSBoundParameters.ContainsKey('DefaultMaxIterations')) {
        $jsonConfig.Defaults.MaxIterations = $DefaultMaxIterations
    }
    if ($PSBoundParameters.ContainsKey('MaxConsecutiveFailures')) {
        $jsonConfig.Defaults.MaxConsecutiveFailures = $MaxConsecutiveFailures
    }

    $jsonConfig.Defaults | Add-Member -MemberType NoteProperty -Name 'LogDirectory' -Value $LogDirectory -Force

    $jsonConfig.psobject.TypeNames.Insert(0, 'BridgeWatcher.Configuration')

    return $jsonConfig
}

