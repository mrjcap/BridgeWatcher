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
        [string]$BaseUrl,

        [Parameter()]
        [string]$OCRApiUrl,

        [Parameter()]
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
        [ValidateNotNullOrEmpty()]
        [string]$LogDirectory = $(
            if (Test-Path 'TestDrive:\') {
                'TestDrive:\logs'
            } else {
                (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'logs')
            }
        )
    )

    if (-not $BaseUrl) { $BaseUrl = 'https://www.topvision.gr/dioriga' }
    if (-not $OCRApiUrl) { $OCRApiUrl = 'https://vision.googleapis.com/v1/images:annotate' }

    # Bridge name mappings (add new bridge slugs here)
    $bridgeNames = @{
        'isthmia'    = 'Ισθμία'
        'poseidonia' = 'Ποσειδωνία'
    }

    # Unified status strings
    $statuses = [PSCustomObject]@{
        Open                 = 'Ανοιχτή'
        Closed               = 'Κλειστή'
        ClosedForMaintenance = 'Κλειστή για συντήρηση'
        ClosedWithSchedule   = 'Κλειστή με πρόγραμμα'
        PermanentlyClosed    = 'Μόνιμα κλειστή'
        Unknown              = 'Άγνωστη'
    }

    # Status mappings
    $statusMappings = @{
        'ΚΛΕΙΣΤΗ' = 'Κλειστή'
        'ΑΝΟΙΧΤΗ' = 'Ανοιχτή'
        'CLOSED'  = 'Κλειστή'
        'OPEN'    = 'Ανοιχτή'
    }

    # Error messages
    $errorMessages = @{
        NoStatus             = '⛔ Δεν υπάρχει διαθέσιμο status για αποθήκευση.'
        HtmlRetrievalFailure = 'Αποτυχία ανάκτησης HTML από τον server'
        ExportFailure        = '⛔ Αποτυχία εξαγωγής δεδομένων'
        OCRFailure           = '❌ Απέτυχε η OCR'
        NetworkError         = '❌ Σφάλμα δικτύου'
        MonitoringError      = '❌ Σφάλμα κατά την ανάκτηση της κατάστασης της γέφυρας'
    }

    # Status messages
    $statusMessages = @{
        MonitoringStart    = 'Ξεκίνησε ο κύκλος παρακολούθησης'
        MonitoringComplete = '✅ Ο κύκλος παρακολούθησης ολοκληρώθηκε'
    }

    # Logging configuration
    $loggingConfig = @{
        ErrorStage   = 'Σφάλμα'
        DebugStage   = 'Debug'
        InfoStage    = 'Ανάλυση'
        WarningLevel = 'Warning'
        ErrorLevel   = 'Error'
        InfoLevel    = 'Info'
        DebugLevel   = 'Debug'
        VerboseLevel = 'Verbose'
    }

    # Export messages
    $exportMessages = @{
        Success            = '✅ Επιτυχής εξαγωγή JSON'
        Failed             = '❌ Αποτυχία εξαγωγής JSON'
        DirectoryNotExists = '❌ Ο φάκελος προορισμού δεν υπάρχει'
    }

    # OCR messages
    $ocrMessages = @{
        StartOCR  = '🔍 Εκκίνηση OCR'
        OCRFailed = '❌ Αποτυχία OCR'
    }

    # Pushover messages
    $pushoverMessages = @{
        SendFailed = '❌ Αποτυχία αποστολής Pushover'
    }

    # Advice messages
    $adviceMessages = @{
        DoNotWait = 'Είναι προτιμότερο να μην περιμένεις'
        Wait      = 'Είναι προτιμότερο να περιμένεις'
    }

    return [PSCustomObject]@{
        # URLs
        Urls                      = [PSCustomObject]@{
            Source      = $BaseUrl.TrimEnd('/') + '/'
            BaseImage   = $BaseUrl.TrimEnd('/')
            OCRApi      = $OCRApiUrl
            PushoverApi = if ($PushoverApiUrl) { $PushoverApiUrl } else { 'https://api.pushover.net/1/messages.json' }
        }

        # Defaults
        Defaults                  = [PSCustomObject]@{
            IntervalSeconds        = $DefaultIntervalSeconds
            MaxIterations          = $DefaultMaxIterations
            MaxConsecutiveFailures = $MaxConsecutiveFailures
            JsonDepth              = 5
            MaxWaitTimeMinutes     = 12
            LogDirectory           = $LogDirectory
            TimezoneIds            = @('GTB Standard Time', 'Europe/Athens')
        }

        # Mappings
        Statuses                  = $statuses
        BridgeNames               = $bridgeNames
        StatusMappings            = $statusMappings
        ErrorMessages             = $errorMessages
        StatusMessages            = $statusMessages
        LoggingConfig             = $loggingConfig
        ExportMessages            = $exportMessages
        OCRMessages               = $ocrMessages
        PushoverMessages          = $pushoverMessages
        AdviceMessages            = $adviceMessages

        # Patterns (can be extended)
        TimePatterns              = @(
            '\d{1,2}:\d{2}'
            '\d{1,2}\.\d{2}'
        )

        # File extensions
        SupportedImageExtensions  = @('.jpg', '.jpeg', '.png', '.gif')

        PSTypeName                = 'BridgeWatcher.Configuration'
    }
}

