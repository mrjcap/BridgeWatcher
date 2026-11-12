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

    .PARAMETER MaxConsecutiveFailures
    Ο μέγιστος αριθμός διαδοχικών αποτυχιών.

    .PARAMETER LogDirectory
    Ο κατάλογος αποθήκευσης αρχείων καταγραφής.

    .PARAMETER ConfigurationPath
    Προαιρετική διαδρομή σε εξωτερικό αρχείο JSON για παράκαμψη των προεπιλογών.

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
        [string]$LogDirectory = '',

        [Parameter()]
        [string]$ConfigurationPath = ''
    )

    $testDriveLog = if (Test-Path 'TestDrive:\') { 'TestDrive:\logs' } else { '' }
    $defaultLogDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'logs'
    $LogDirectory = @($LogDirectory, $Env:BRIDGEWATCHER_OUT, $testDriveLog, $defaultLogDir) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() } |
        Select-Object -First 1

    $sourceUrl = @($BaseUrl, 'https://www.topvision.gr/dioriga') | Where-Object { $_ } | Select-Object -First 1
    $ocrUrl = @($OCRApiUrl, 'https://vision.googleapis.com/v1/images:annotate') | Where-Object { $_ } | Select-Object -First 1
    $poUrl = @($PushoverApiUrl, 'https://api.pushover.net/1/messages.json') | Where-Object { $_ } | Select-Object -First 1

    $config = [PSCustomObject]@{
        Urls                      = [PSCustomObject]@{
            Source      = $sourceUrl.TrimEnd('/') + '/'
            BaseImage   = $sourceUrl.TrimEnd('/')
            OCRApi      = $ocrUrl
            PushoverApi = $poUrl
        }
        Defaults                  = [PSCustomObject]@{
            IntervalSeconds        = $DefaultIntervalSeconds
            MaxIterations          = $DefaultMaxIterations
            MaxConsecutiveFailures = $MaxConsecutiveFailures
            JsonDepth              = 5
            MaxWaitTimeMinutes     = 12
            HttpRequestTimeout     = 60
            LogDirectory           = $LogDirectory
            TimezoneIds            = @('GTB Standard Time', 'Europe/Athens')
        }
        Statuses                  = [PSCustomObject]@{
            Open                 = 'Ανοιχτή'
            Closed               = 'Κλειστή'
            ClosedForMaintenance = 'Κλειστή για συντήρηση'
            ClosedWithSchedule   = 'Κλειστή με πρόγραμμα'
            PermanentlyClosed    = 'Μόνιμα κλειστή'
            Unknown              = 'Άγνωστη'
        }
        BridgeNames               = @{
            'isthmia'    = 'Ισθμία'
            'poseidonia' = 'Ποσειδωνία'
        }
        ErrorMessages             = @{
            MonitoringError      = '❌ Σφάλμα κατά την ανάκτηση της κατάστασης της γέφυρας'
        }
        StatusMessages            = @{
            MonitoringStart    = 'Ξεκίνησε ο κύκλος παρακολούθησης'
            MonitoringComplete = '✅ Ο κύκλος παρακολούθησης ολοκληρώθηκε'
        }
        LoggingConfig             = @{
            ErrorStage   = 'Σφάλμα'
            InfoStage    = 'Ανάλυση'
            WarningLevel = 'Warning'
            DebugLevel   = 'Debug'
            VerboseLevel = 'Verbose'
        }
        ExportMessages            = @{
            Success            = '✅ Επιτυχής εξαγωγή JSON'
            Failed             = '❌ Αποτυχία εξαγωγής JSON'
            DirectoryNotExists = '❌ Ο φάκελος προορισμού δεν υπάρχει'
        }
        OCRMessages               = @{
            StartOCR  = '🔍 Εκκίνηση OCR'
            OCRFailed = '❌ Αποτυχία OCR'
        }
        PushoverMessages          = @{
            SendFailed = '❌ Αποτυχία αποστολής Pushover'
        }
        AdviceMessages            = @{
            DoNotWait = 'Είναι προτιμότερο να μην περιμένεις'
            Wait      = 'Είναι προτιμότερο να περιμένεις'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ConfigurationPath)) {
        if (-not (Test-Path -Path $ConfigurationPath)) {
            throw [System.IO.FileNotFoundException]::new("Configuration file not found: $ConfigurationPath", $ConfigurationPath)
        }
        $rawJson = Get-Content -Path $ConfigurationPath -Raw -Encoding utf8
        $fileConfig = ConvertFrom-Json -InputObject $rawJson
        foreach ($section in @('Urls', 'Defaults')) {
            $sectionProp = $fileConfig.PSObject.Properties[$section]
            if ($null -ne $sectionProp -and $null -ne $sectionProp.Value) {
                foreach ($prop in $sectionProp.Value.PSObject.Properties) {
                    $config.$section | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
                }
            }
        }
    }

    $config.psobject.TypeNames.Insert(0, 'BridgeWatcher.Configuration')
    return $config
}
