function Get-BridgeTimestamp {
    <#
    .SYNOPSIS
    Provides standardized timestamp generation with explicit timezone handling.

    .DESCRIPTION
    Generates timestamps in ISO 8601 format with timezone information, ensuring
    consistent date/time handling across the BridgeWatcher module (MED-003).

    .PARAMETER Format
    The timestamp format to use. Defaults to ISO 8601 with timezone.

    .OUTPUTS
    [string] - Formatted timestamp with timezone information

    .EXAMPLE
    Get-BridgeTimestamp
    # Returns: '2025-07-04T07:46:12.2271866+00:00'

    .EXAMPLE
    Get-BridgeTimestamp -Format 'DateOnly'
    # Returns: '2025-07-04'

    .NOTES
    Addresses MED-003: Explicit Timezone Handling requirement.
    All timestamps include timezone information for proper chronological ordering.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateSet('ISO8601', 'DateOnly', 'TimeOnly', 'LogFormat')]
        [string]$Format = 'ISO8601'
    )

    $now = Get-Date

    switch ($Format) {
        'ISO8601' {
            return $now.ToString('o')  # ISO 8601 with timezone
        }
        'DateOnly' {
            return $now.ToString('yyyy-MM-dd')
        }
        'TimeOnly' {
            return $now.ToString('HH:mm:ss')
        }
        'LogFormat' {
            return $now.ToString('yyyy-MM-dd HH:mm:ss K')  # Includes timezone offset
        }
        default {
            return $now.ToString('o')
        }
    }
}