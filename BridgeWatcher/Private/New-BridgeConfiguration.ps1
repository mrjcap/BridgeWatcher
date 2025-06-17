function New-BridgeConfiguration {
    <#
    .SYNOPSIS
    Δημιουργεί ένα configuration object για το BridgeWatcher module.

    .DESCRIPTION
    Κεντρικοποιεί όλα τα configuration settings, URLs, patterns και mappings
    που χρησιμοποιούνται στο BridgeWatcher module.

    .PARAMETER BaseUrl
    Το base URL για τα δεδομένα και εικόνες γεφυρών.

    .PARAMETER OCRApiUrl
    Το URL για τη Google Cloud Vision API.

    .PARAMETER DefaultIntervalSeconds
    Το προεπιλεγμένο διάστημα σε δευτερόλεπτα για τη παρακολούθηση.

    .PARAMETER DefaultMaxIterations
    Ο προεπιλεγμένος μέγιστος αριθμός επαναλήψεων.

    .OUTPUTS
    [PSCustomObject] Configuration object

    .NOTES
    This function only creates a configuration object in memory and does not change system state.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function only creates configuration object in memory, does not change system state')]

    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl = 'https://www.topvision.gr/dioriga',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OCRApiUrl = 'https://vision.googleapis.com/v1/images:annotate',

        [Parameter()]
        [ValidateRange(1, 3600)]
        [int]$DefaultIntervalSeconds = 300,

        [Parameter()]        [ValidateRange(1, 1000)]
        [int]$DefaultMaxIterations = 100
    )

    # Bridge name mappings
    $bridgeNames = @{
        'isthmia'    = 'Ισθμια'
        'poseidonia' = 'Ποσειδωνια'
    }    # Status mappings
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
    }    # Logging configuration
    $loggingConfig = @{
        DefaultStage = 'Ανάλυση'
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
    }    # Advice messages
    $adviceMessages = @{
        DoNotWait = 'Είναι προτιμότερο να μην περιμένεις'
        Wait      = 'Είναι προτιμότερο να περιμένεις'
    }

    return [PSCustomObject]@{
        # URLs
        SourceUrl                 = $BaseUrl.TrimEnd('/') + '/'
        BaseImageUrl              = $BaseUrl.TrimEnd('/')
        OCRApiUrl                 = $OCRApiUrl
        PushoverApiUrl            = 'https://api.pushover.net/1/messages.json'

        # Defaults
        DefaultIntervalSeconds    = $DefaultIntervalSeconds
        DefaultMaxIterations      = $DefaultMaxIterations
        DefaultJsonDepth          = 5
        DefaultMaxWaitTimeMinutes = 12

        # Mappings
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
