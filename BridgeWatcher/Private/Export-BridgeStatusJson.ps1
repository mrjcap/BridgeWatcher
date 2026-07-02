function Export-BridgeStatusJson {
    <#
    .SYNOPSIS
    Εξάγει την κατάσταση γέφυρας σε αρχείο JSON.

    .DESCRIPTION
    Η Export-BridgeStatusJson αποθηκεύει δεδομένα κατάστασης γέφυρας σε μορφή JSON
    σε καθορισμένη διαδρομή. Επιστρέφει αντικείμενο BridgeResult για καλύτερη
    διαχείριση σφαλμάτων και ενσωμάτωση στο pipeline.

    .PARAMETER Data
    Το αντικείμενο ή η λίστα αντικειμένων που θα εξαχθεί.

    .PARAMETER Path
    Η πλήρης διαδρομή του αρχείου εξόδου.

    .PARAMETER JsonDepth
    Το βάθος σειριοποίησης (serialization) του JSON (προεπιλογή: 10).

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    [PSCustomObject] - Αντικείμενο BridgeResult με Success, Data, ErrorMessage, ErrorCode, Timestamp.

    .EXAMPLE
        Write-Host "Εξαγωγή επιτυχής"
    }

    .NOTES
    Χρησιμοποιεί την New-BridgeResult για τυποποιημένη επιστροφή αποτελεσμάτων.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateRange(1, 20)]
        [int]$JsonDepth,

        [Parameter()]
        [PSCustomObject]$Configuration
    )

    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }

    # Λήψη βάθους JSON από τη διαμόρφωση ή την παράμετρο ή χρήση εναλλακτικής λύσης
    if (-not $JsonDepth) {
        $JsonDepth = $Configuration.Defaults.JsonDepth
    }

    # Λήψη μηνυμάτων από τη διαμόρφωση ή χρήση εναλλακτικής λύσης
    $successMessage = $Configuration.ExportMessages.Success

    $failedMessage = $Configuration.ExportMessages.Failed

    $directoryNotExistsMessage = $Configuration.ExportMessages.DirectoryNotExists

    # Λήψη σταδίου καταγραφής (logging stage) από τη διαμόρφωση ή χρήση εναλλακτικής λύσης
    $analysisStage = $Configuration.LoggingConfig.InfoStage

    $errorStage = $Configuration.LoggingConfig.ErrorStage

    $warningLevel = $Configuration.LoggingConfig.WarningLevel

    try {
        $convertToJsonSplat = @{
            Depth    = $JsonDepth
            Compress = $true
        }

        $parentDir = Split-Path -Parent $Path
        if (-not [string]::IsNullOrWhiteSpace($parentDir)) {
            try {
                $null = New-Item -ItemType Directory -Force -Path $parentDir -ErrorAction Stop
            } catch {
                $errorMessage = "$directoryNotExistsMessage`: $parentDir"
                $writeBridgeLogSplat = @{
                    Stage   = $errorStage
                    Message = $errorMessage
                    Level   = $warningLevel
                }
                Write-BridgeLog @writeBridgeLogSplat

                return [PSCustomObject]@{
                    Success      = $false
                    Data         = $null
                    ErrorMessage = $errorMessage
                    ErrorCode    = 'DIRECTORY_NOT_EXISTS'
                    Timestamp    = (Get-Date -Format o)
                }
            }
        }

        $json = ConvertTo-Json -InputObject $Data @convertToJsonSplat
        $fileStream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $fileStream.Write($bytes, 0, $bytes.Length)
        } finally {
            $fileStream.Close()
            $fileStream.Dispose()
        }

        $writeBridgeLogSplat = @{
            Stage   = $analysisStage
            Message = "$successMessage`: $Path"
        }
        Write-BridgeLog @writeBridgeLogSplat

        return [PSCustomObject]@{
            Success      = $true
            Data         = @{ ExportedPath = $Path; RecordCount = $Data.Count }
            ErrorMessage = ''
            ErrorCode    = ''
            Timestamp    = (Get-Date -Format o)
        }
    }
    catch {
        $errorMessage = "$failedMessage`: $($_.Exception.Message)"
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = $errorMessage
            Level   = $warningLevel
        }
        Write-BridgeLog @writeBridgeLogSplat

        return [PSCustomObject]@{
            Success      = $false
            Data         = $null
            ErrorMessage = $errorMessage
            ErrorCode    = 'JSON_EXPORT_FAILURE'
            Timestamp    = (Get-Date -Format o)
        }
    }
}
