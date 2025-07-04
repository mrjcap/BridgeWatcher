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

    .PARAMETER DefaultTimeoutSeconds
    Ο προεπιλεγμένος χρόνος timeout σε δευτερόλεπτα για HTTP αιτήματα.

    .PARAMETER DefaultRetryAttempts
    Ο προεπιλεγμένος αριθμός επαναλήψεων σε περίπτωση αποτυχίας.

    .PARAMETER DefaultRetryDelaySeconds
    Η προεπιλεγμένη καθυστέρηση σε δευτερόλεπτα μεταξύ επαναλήψεων.

    .PARAMETER DefaultMaxResults
    Ο προεπιλεγμένος μέγιστος αριθμός αποτελεσμάτων για OCR αιτήματα.

    .PARAMETER EnableDetailedLogging
    Ενεργοποιεί λεπτομερή καταγραφή για debugging.

    .OUTPUTS
    [PSCustomObject] Configuration object

    .EXAMPLE
    # Δημιουργία configuration με προεπιλεγμένες ρυθμίσεις
    $config = New-BridgeConfiguration

    .EXAMPLE
    # Δημιουργία configuration με custom παραμέτρους
    $config = New-BridgeConfiguration -DefaultIntervalSeconds 600 -DefaultMaxIterations 50

    .EXAMPLE
    # Δημιουργία configuration για περιβάλλον testing με μικρότερα timeouts
    $config = New-BridgeConfiguration -DefaultTimeoutSeconds 10 -DefaultRetryAttempts 2

    .NOTES
    This function only creates a configuration object in memory and does not change system state.
    Το configuration object περιέχει όλες τις ρυθμίσεις που χρησιμοποιούνται στο module,
    συμπεριλαμβανομένων timeout values, retry settings, και message templates.
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

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$DefaultMaxIterations = 100,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$DefaultTimeoutSeconds = 30,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$DefaultRetryAttempts = 3,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$DefaultRetryDelaySeconds = 5,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$DefaultMaxResults = 50,

        [Parameter()]
        [switch]$EnableDetailedLogging
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
        DefaultStage          = 'Ανάλυση'
        ErrorStage            = 'Σφάλμα'
        DebugStage            = 'Debug'
        InfoStage             = 'Ανάλυση'
        WarningLevel          = 'Warning'
        ErrorLevel            = 'Error'
        InfoLevel             = 'Info'
        DebugLevel            = 'Debug'
        VerboseLevel          = 'Verbose'
        EnableConsoleOutput   = $true
        EnableFileLogging     = $true
        EnableDetailedLogging = $EnableDetailedLogging.IsPresent
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
        DefaultTimeoutSeconds     = $DefaultTimeoutSeconds
        DefaultRetryAttempts      = $DefaultRetryAttempts
        DefaultRetryDelaySeconds  = $DefaultRetryDelaySeconds
        DefaultMaxResults         = $DefaultMaxResults
        EnableDetailedLogging     = $EnableDetailedLogging.IsPresent

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
