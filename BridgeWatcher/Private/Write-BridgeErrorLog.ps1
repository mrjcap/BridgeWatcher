function Write-BridgeErrorLog {
    <#
    .SYNOPSIS
    Common helper for writing error logs with standardized error handling.

    .DESCRIPTION
    Provides a consistent way to log errors across the BridgeWatcher module,
    reducing code duplication and ensuring uniform error handling patterns.

    .PARAMETER Configuration
    The configuration object containing logging settings.

    .PARAMETER ErrorMessage
    The error message to log.

    .PARAMETER Exception
    The original exception object (optional).

    .PARAMETER Stage
    The stage where the error occurred (optional, will use Configuration default).

    .PARAMETER Level
    The log level (optional, will use Configuration default).

    .PARAMETER ErrorCode
    A specific error code for categorization (optional).

    .OUTPUTS
    [PSCustomObject] - BridgeResult object with error details.

    .EXAMPLE
    Write-BridgeErrorLog -Configuration $config -ErrorMessage "API call failed" -Exception $_.Exception

    .NOTES
    This function standardizes error logging patterns and creates BridgeResult objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [PSCustomObject]$Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ErrorMessage,

        [Parameter()]
        [System.Exception]$Exception,

        [Parameter()]
        [string]$Stage,

        [Parameter()]
        [string]$Level,

        [Parameter()]
        [string]$ErrorCode = 'GENERIC_ERROR'
    )

    # Get stage from parameter, configuration, or use fallback
    if (-not $Stage) {
        $Stage = Get-ConfigurationValue -Configuration $Configuration -PropertyPath 'LoggingConfig.ErrorStage' -FallbackValue 'Σφάλμα'
    }

    # Get level from parameter, configuration, or use fallback
    if (-not $Level) {
        $Level = Get-ConfigurationValue -Configuration $Configuration -PropertyPath 'LoggingConfig.WarningLevel' -FallbackValue 'Warning'
    }

    # Create full error message
    $fullErrorMessage = if ($Exception) {
        "$ErrorMessage`: $($Exception.Message)"
    } else {
        $ErrorMessage
    }

    # Log the error
    $writeBridgeLogSplat = @{
        Stage   = $Stage
        Message = $fullErrorMessage
        Level   = $Level
    }
    Write-BridgeLog @writeBridgeLogSplat

    # Return BridgeResult object
    return New-BridgeResult -Success $false -ErrorMessage $fullErrorMessage -ErrorCode $ErrorCode
}