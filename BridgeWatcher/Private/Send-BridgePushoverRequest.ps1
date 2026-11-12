function Get-BridgePushoverExceptionInfo {
    <#
    .SYNOPSIS
    Εξάγει την απόκριση HTTP και αν το σφάλμα Pushover είναι μη ανακτήσιμο.
    #>
    param (
        [Parameter(Mandatory)][ValidateNotNull()][System.Exception]$Exception
    )
    $responseProp = $Exception.PSObject.Properties['Response']
    $response = if ($null -ne $responseProp) { $responseProp.Value } else { $null }
    $isFatal = ($null -ne $response) -and (([int]$response.StatusCode) -in @(400, 401, 403))
    return [PSCustomObject]@{
        Response = $response
        IsFatal  = $isFatal
    }
}

function Send-BridgePushoverRequest {
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
    Το αποτέλεσμα του API ή $null σε σφάλμα.

    .EXAMPLE
    Send-BridgePushoverRequest -Payload $pushoverPayload

    .NOTES
    Χρησιμοποιεί Invoke-RestMethod με ErrorAction Stop για ασφαλή αποστολή.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory)][hashtable]$Payload,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )


    # Get Pushover API URL from configuration
    $pushoverApiUrl = $Configuration.Urls.PushoverApi

    # Get error message from configuration
    $errorMessagePrefix = $Configuration.PushoverMessages.SendFailed

    # Get logging stage from configuration
    $errorStage = $Configuration.LoggingConfig.ErrorStage

    $warningLevel = $Configuration.LoggingConfig.WarningLevel

    try {
        Write-Verbose "📲 Αποστολή ειδοποίησης Pushover (Τίτλος: $($Payload['title']))..."

        $invokeRestMethodSplat = @{
            Method      = 'Post'
            Uri         = $pushoverApiUrl
            Body        = $Payload
            TimeoutSec  = $Configuration.Defaults.HttpRequestTimeout
            ErrorAction = 'Stop'
        }
        $maxRetries = 3
        $result = $null
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                $result = Invoke-RestMethod @invokeRestMethodSplat
                break
            } catch {
                $errInfo = Get-BridgePushoverExceptionInfo -Exception $_.Exception
                $response = $errInfo.Response
                try {
                    if ($errInfo.IsFatal -or $i -eq $maxRetries) { throw }
                    $baseSleep = [Math]::Pow(2, $i)
                    $jitter = Get-Random -Minimum 0 -Maximum 3
                    Start-Sleep -Seconds ($baseSleep + $jitter)
                } finally {
                    if ($response -is [System.IDisposable]) { $response.Dispose() }
                }
            }
        }

        $writeBridgeLogSuccess = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = "✅ Η ειδοποίηση Pushover στάλθηκε με επιτυχία!"
            Level   = $Configuration.LoggingConfig.VerboseLevel
        }
        Write-BridgeLog @writeBridgeLogSuccess -Configuration $Configuration

        return $result
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = "$errorMessagePrefix`: $($_.Exception.Message)"
            Level   = $warningLevel
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($_.Exception, 'PushoverSendFailure', [System.Management.Automation.ErrorCategory]::ConnectionError, $null)
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}