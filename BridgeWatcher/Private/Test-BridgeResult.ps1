function Test-BridgeResult {
    <#
    .SYNOPSIS
    Ελέγχει το αποτέλεσμα μιας λειτουργίας και καταγράφει σφάλματα.

    .DESCRIPTION
    Η Test-BridgeResult ελέγχει αν ένα αποτέλεσμα που επιστράφηκε από το New-BridgeResult
    είναι επιτυχές ή όχι. Αν υπάρχει σφάλμα, το καταγράφει στο log.

    .PARAMETER Result
    Το αντικείμενο αποτελέσματος που δημιουργήθηκε με το New-BridgeResult.

    .OUTPUTS
    [bool] - $true if the operation was successful, $false if there was an error.

    .EXAMPLE
    $result = New-BridgeResult -Success $false -ErrorMessage "HTTP failed" -ErrorCode "HTTP_ERROR"
    $isSuccess = Test-BridgeResult -Result $result
    # Returns $false and logs the error

    .EXAMPLE
    $result = New-BridgeResult -Success $true -Data $bridgeStatus
    $isSuccess = Test-BridgeResult -Result $result
    # Returns $true

    .NOTES
    Uses Write-BridgeLog for error logging with Stage 'Σφάλμα' and Level 'Warning'.
    Χρησιμοποιεί το Write-BridgeLog για καταγραφή σφαλμάτων με Stage 'Σφάλμα' και Level 'Warning'.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )    if (-not $Result.Success) {
        $errorMessage = if ([string]::IsNullOrWhiteSpace($Result.ErrorMessage)) {
            'Άγνωστο σφάλμα'
        } else {
            $Result.ErrorMessage
        }

        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = $errorMessage
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        return $false
    }
    return $true
}

