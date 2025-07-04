function Send-BridgePushoverRequest {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Αποστέλλει αίτημα ειδοποίησης στο API του Pushover.

    .DESCRIPTION
    Η Send-BridgePushoverRequest στέλνει ένα formatted payload
    στο Pushover API endpoint και επιστρέφει την απόκριση.

    .PARAMETER Payload
    Το hashtable με όλα τα απαιτούμενα δεδομένα.

    .PARAMETER Configuration
    Το configuration object που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    [object] - Το αποτέλεσμα του API ή $null σε σφάλμα.

    .EXAMPLE
    Send-BridgePushoverRequest -Payload $pushoverPayload

    .NOTES
    Χρησιμοποιεί Invoke-RestMethod με ErrorAction Stop για ασφαλή αποστολή.
    #>

    [OutputType([object])]
    param (
        [Parameter(Mandatory)][hashtable]$Payload,
        [Parameter()][PSCustomObject]$Configuration
    )

    # Get Pushover API URL from configuration or use fallback
    $pushoverApiUrl = Get-ConfigurationValue -Configuration $Configuration -PropertyPath 'PushoverApiUrl' -FallbackValue 'https://api.pushover.net/1/messages.json'

    # Get error message from configuration or use fallback
    $errorMessagePrefix = Get-ConfigurationValue -Configuration $Configuration -PropertyPath 'PushoverMessages.SendFailed' -FallbackValue '❌ Αποτυχία αποστολής'

    # Get logging stage from configuration or use fallback
    $errorStage = Get-ConfigurationValue -Configuration $Configuration -PropertyPath 'LoggingConfig.ErrorStage' -FallbackValue 'Σφάλμα'
    
    $warningLevel = Get-ConfigurationValue -Configuration $Configuration -PropertyPath 'LoggingConfig.WarningLevel' -FallbackValue 'Warning'

    try {
        $invokeRestMethodSplat = @{
            Method      = 'Post'
            Uri         = $pushoverApiUrl
            Body        = $Payload
            ErrorAction = 'Stop'
        }
        return Invoke-RestMethod @invokeRestMethodSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = "$errorMessagePrefix`: $($_.Exception.Message)"
            Level   = $warningLevel
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($_.Exception, 'PushoverSendFailure', [System.Management.Automation.ErrorCategory]::ConnectionError, $Payload)
        throw $errorRecord
    }
}