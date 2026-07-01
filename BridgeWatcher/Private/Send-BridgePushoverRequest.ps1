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

    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }

    # Get Pushover API URL from configuration
    $pushoverApiUrl = $Configuration.PushoverApiUrl

    # Get error message from configuration
    $errorMessagePrefix = $Configuration.PushoverMessages.SendFailed

    # Get logging stage from configuration
    $errorStage = $Configuration.LoggingConfig.ErrorStage

    $warningLevel = $Configuration.LoggingConfig.WarningLevel

    try {
        $invokeRestMethodSplat = @{
            Method      = 'Post'
            Uri         = $pushoverApiUrl
            Body        = $Payload
            ErrorAction = 'Stop'
        }
        $maxRetries = 3
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                return Invoke-RestMethod @invokeRestMethodSplat
            } catch [System.Net.WebException] {
                $response = $_.Exception.Response
                if ($response -and $response.StatusCode -in @(400, 401, 403)) {
                    throw
                }
                if ($i -eq $maxRetries) { throw }
                Start-Sleep -Seconds ([Math]::Pow(2, $i))
            } catch {
                if ($i -eq $maxRetries) { throw }
                Start-Sleep -Seconds ([Math]::Pow(2, $i))
            }
        }
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = "$errorMessagePrefix`: $($_.Exception.Message)"
            Level   = $warningLevel
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($_.Exception, 'PushoverSendFailure', [System.Management.Automation.ErrorCategory]::ConnectionError, $null)
        throw $errorRecord
    }
}
