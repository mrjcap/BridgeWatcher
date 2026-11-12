function Get-BridgeExportJsonDepth {
    <#
    .SYNOPSIS
    Υπολογίζει το ενεργό βάθος σειριοποίησης JSON από τις παραμέτρους και τις ρυθμίσεις.
    #>
    param (
        [Parameter()][int]$JsonDepth,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    $configJsonDepthProp = $Configuration.Defaults.PSObject.Properties['JsonDepth']
    $configJsonDepth = if ($null -ne $configJsonDepthProp) { $configJsonDepthProp.Value } else { 0 }
    return (@($JsonDepth, $configJsonDepth, 10) | Where-Object { $_ -gt 0 } | Select-Object -First 1)
}

function Write-BridgeAtomicJson {
    <#
    .SYNOPSIS
    Εγγράφει περιεχόμενο JSON ατομικά μέσω προσωρινού αρχείου.
    #>
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter()][AllowNull()][object]$JsonContent
    )
    $tmpPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        Set-Content -Path $tmpPath -Value $JsonContent -Encoding UTF8 -Force -ErrorAction Stop
        Move-Item -Path $tmpPath -Destination $Path -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -Path $tmpPath) {
            Remove-Item -Path $tmpPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Export-BridgeStatusJson {
    <#
    .SYNOPSIS
    Εξάγει την κατάσταση γέφυρας σε αρχείο JSON.

    .DESCRIPTION
    Η Export-BridgeStatusJson αποθηκεύει δεδομένα κατάστασης γέφυρας σε μορφή JSON
    σε καθορισμένη διαδρομή.

    .PARAMETER Data
    Το αντικείμενο ή η λίστα αντικειμένων που θα εξαχθεί.

    .PARAMETER Path
    Η πλήρης διαδρομή του αρχείου εξόδου.

    .PARAMETER JsonDepth
    Το βάθος σειριοποίησης (serialization) του JSON.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    [PSCustomObject] - Αντικείμενο αποτελέσματος.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Data,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [int]$JsonDepth,

        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )

    begin {
        $items = [System.Collections.Generic.List[object]]::new()
        $resolvedDepth = Get-BridgeExportJsonDepth -JsonDepth $JsonDepth -Configuration $Configuration

        $successMessage = $Configuration.ExportMessages.Success
        $failedMessage = $Configuration.ExportMessages.Failed
        $directoryNotExistsMessage = $Configuration.ExportMessages.DirectoryNotExists
        $analysisStage = $Configuration.LoggingConfig.InfoStage
        $errorStage = $Configuration.LoggingConfig.ErrorStage
    }

    process {
        $isEmptyCollection = ($Data -is [System.Collections.IEnumerable]) -and ($Data -isnot [string]) -and ($Data.Count -eq 0)
        if ($null -ne $Data -and -not $isEmptyCollection) {
            $items.Add($Data)
        }
    }

    end {
        try {
            $dataToExport = if ($items.Count -eq 1) { $items[0] } else { $items.ToArray() }

            if ($PSCmdlet.ShouldProcess($Path, "Create JSON export")) {
                $parentDir = Split-Path -Parent $Path
                if (-not [string]::IsNullOrWhiteSpace($parentDir)) {
                try {
                    $null = New-Item -ItemType Directory -Force -Path $parentDir -ErrorAction Stop
                } catch {
                    $errorMessage = "$directoryNotExistsMessage ($parentDir): $($_.Exception.Message)"
                    $writeBridgeLogSplat = @{
                        Stage   = $errorStage
                        Message = $errorMessage
                        Level   = 'Warning'
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

                    return [PSCustomObject]@{
                        Success      = $false
                        Data         = $null
                        ErrorMessage = $errorMessage
                        ErrorCode    = 'DIRECTORY_NOT_EXISTS'
                        Timestamp    = (Get-Date -Format o)
                    }
                }
                }

                $json = ConvertTo-Json -InputObject $dataToExport -Depth $resolvedDepth -Compress
                Write-BridgeAtomicJson -Path $Path -JsonContent $json

                $writeBridgeLogSplat = @{
                    Stage   = $analysisStage
                    Message = "$successMessage`: $Path"
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            }

            return [PSCustomObject]@{
                Success      = $true
                Data         = @{ ExportedPath = $Path; RecordCount = $items.Count }
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
                Level   = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

            return [PSCustomObject]@{
                Success      = $false
                Data         = $null
                ErrorMessage = $errorMessage
                ErrorCode    = 'JSON_EXPORT_FAILURE'
                Timestamp    = (Get-Date -Format o)
            }
        }
    }
}
