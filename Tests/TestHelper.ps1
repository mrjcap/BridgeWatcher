<#
.SYNOPSIS
Δημιουργεί ένα αντικείμενο αποτελέσματος.

.DESCRIPTION
Δημιουργεί αντικείμενο αποτελέσματος για δοκιμές με δεδομένα ή πληροφορίες αποτυχίας.

.PARAMETER Success
Δηλώνει αν η λειτουργία ολοκληρώθηκε επιτυχώς.

.PARAMETER Data
Τα δεδομένα που επιστρέφει μια επιτυχής λειτουργία.

.PARAMETER ErrorMessage
Το μήνυμα που περιγράφει την αποτυχία.

.PARAMETER ErrorCode
Ο κωδικός της αποτυχίας.
#>
function global:New-BridgeResult {
    param(
        [bool]$Success,
        $Data,
        $ErrorMessage = '',
        $ErrorCode = ''
    )
    return [PSCustomObject]@{
        Success      = $Success
        Data         = $Data
        ErrorMessage = $ErrorMessage
        ErrorCode    = $ErrorCode
        Timestamp    = (Get-Date -Format o)
    }
}

<#
.SYNOPSIS
Ελέγχει αν το αποτέλεσμα είναι επιτυχές.

.DESCRIPTION
Ελέγχει ότι το αποτέλεσμα δοκιμής έχει την αναμενόμενη δομή.

.PARAMETER Result
Το αντικείμενο αποτελέσματος που ελέγχεται.
#>
function global:Test-BridgeResult {
    param($Result)
    if (-not $Result.Success) {
        $errorMessage = if ([string]::IsNullOrWhiteSpace($Result.ErrorMessage)) {
            'Άγνωστο σφάλμα'
        } else {
            $Result.ErrorMessage
        }
        Write-BridgeLog -Configuration $script:Config -Stage 'Σφάλμα' -Message $errorMessage -Level 'Warning'
        return $false
    }
    return $true
}
