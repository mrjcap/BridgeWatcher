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

function global:Test-BridgeResult {
    param($Result)
    if (-not $Result.Success) {
        $errorMessage = if ([string]::IsNullOrWhiteSpace($Result.ErrorMessage)) {
            'Άγνωστο σφάλμα'
        } else {
            $Result.ErrorMessage
        }
        Write-BridgeLog -Stage 'Σφάλμα' -Message $errorMessage -Level 'Warning'
        return $false
    }
    return $true
}
