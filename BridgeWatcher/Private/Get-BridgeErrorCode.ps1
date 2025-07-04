function Get-BridgeErrorCode {
    <#
    .SYNOPSIS
    Provides standardized error codes for BridgeWatcher operations.

    .DESCRIPTION
    Centralizes error code definitions following the MED-XXX naming convention
    with clear categorization and consistent naming.

    .PARAMETER Category
    The category of error (Validation, Network, Configuration, etc.)

    .PARAMETER Type
    The specific type of error within the category

    .OUTPUTS
    [string] - Standardized error code

    .EXAMPLE
    Get-BridgeErrorCode -Category 'Validation' -Type 'BridgeNameEmpty'
    # Returns: 'VAL-001'

    .NOTES
    Error code format: [CATEGORY]-[NUMBER]
    Categories:
    - VAL: Validation errors (MED-001)
    - NET: Network/HTTP errors 
    - CFG: Configuration errors
    - PAR: Parsing errors
    - CON: Concurrency errors (MED-008)
    - SAN: Sanitization errors (MED-007)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Validation', 'Network', 'Configuration', 'Parsing', 'Concurrency', 'Sanitization')]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Type
    )

    $errorCodes = @{
        'Validation' = @{
            'BridgeNameEmpty'    = 'VAL-001'
            'BridgeNameNull'     = 'VAL-002'
            'ParameterEmpty'     = 'VAL-003'
            'ParameterNull'      = 'VAL-004'
            'InvalidFormat'      = 'VAL-005'
        }
        'Network' = @{
            'HttpError'          = 'NET-001'
            'ConnectionTimeout'  = 'NET-002'
            'InvalidUrl'         = 'NET-003'
            'NetworkUnavailable' = 'NET-004'
        }
        'Configuration' = @{
            'ConfigError'        = 'CFG-001'
            'MissingConfig'      = 'CFG-002'
            'InvalidConfig'      = 'CFG-003'
        }
        'Parsing' = @{
            'ParsingError'       = 'PAR-001'
            'HtmlParseError'     = 'PAR-002'
            'JsonParseError'     = 'PAR-003'
            'TimeParseError'     = 'PAR-004'
        }
        'Concurrency' = @{
            'InstanceExists'     = 'CON-001'
            'LockTimeout'        = 'CON-002'
            'MutexError'         = 'CON-003'
        }
        'Sanitization' = @{
            'InvalidCharacters'  = 'SAN-001'
            'PathTraversal'      = 'SAN-002'
            'UrlInjection'       = 'SAN-003'
        }
    }

    if ($errorCodes.ContainsKey($Category) -and $errorCodes[$Category].ContainsKey($Type)) {
        return $errorCodes[$Category][$Type]
    }

    # Fallback to generic error code if specific type not found
    switch ($Category) {
        'Validation'     { return 'VAL-999' }
        'Network'        { return 'NET-999' }
        'Configuration'  { return 'CFG-999' }
        'Parsing'        { return 'PAR-999' }
        'Concurrency'    { return 'CON-999' }
        'Sanitization'   { return 'SAN-999' }
        default          { return 'GEN-999' }
    }
}