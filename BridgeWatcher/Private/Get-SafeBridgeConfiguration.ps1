function Get-SafeBridgeConfiguration {
    <#
    .SYNOPSIS
    Returns a safe bridge configuration, creating a new one if necessary.

    .DESCRIPTION
    Get-SafeBridgeConfiguration reduces boilerplate in the main functions by handling
    configuration fallback logic.

    .PARAMETER Configuration
    The existing configuration object, if any.

    .PARAMETER Quiet
    If set, suppresses exceptions and returns $null on failure.

    .OUTPUTS
    [PSCustomObject]
    #>
    [CmdletBinding()]
    param(
        [PSCustomObject]$Configuration,
        [switch]$Quiet
    )

    if ($Configuration) {
        return $Configuration
    }

    try {
        return New-BridgeConfiguration
    } catch {
        if ($Quiet) {
            return $null
        }
        throw $_
    }
}
