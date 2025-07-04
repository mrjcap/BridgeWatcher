function Get-ConfigurationValue {
    <#
    .SYNOPSIS
    Retrieves a configuration value using a property path with fallback support.

    .DESCRIPTION
    A helper function that simplifies retrieving configuration values from a Configuration object
    using dot notation property paths. If the value doesn't exist or Configuration is null,
    returns the provided fallback value.

    .PARAMETER Configuration
    The configuration object to retrieve values from.

    .PARAMETER PropertyPath
    The dot-separated property path (e.g., 'ExportMessages.Success', 'LoggingConfig.ErrorStage').

    .PARAMETER FallbackValue
    The default value to return if the configuration property doesn't exist.

    .OUTPUTS
    [object] - The configuration value or fallback value.

    .EXAMPLE
    Get-ConfigurationValue -Configuration $config -PropertyPath 'DefaultMaxWaitTimeMinutes' -FallbackValue 12

    .EXAMPLE
    Get-ConfigurationValue -Configuration $config -PropertyPath 'ExportMessages.Success' -FallbackValue '✅ Success'

    .NOTES
    This function helps reduce repetitive configuration retrieval patterns throughout the module.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter()]
        [PSCustomObject]$Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyPath,

        [Parameter()]
        [AllowNull()]
        [object]$FallbackValue
    )

    # If no configuration provided, return fallback
    if (-not $Configuration) {
        return $FallbackValue
    }

    # Split the property path and navigate through the object
    $properties = $PropertyPath -split '\.'
    $current = $Configuration

    foreach ($property in $properties) {
        if ($current) {
            # Handle both PSCustomObject and Hashtable
            if ($current -is [hashtable]) {
                if ($current.ContainsKey($property)) {
                    $current = $current[$property]
                } else {
                    return $FallbackValue
                }
            } elseif ([bool]($current.PSObject.Properties.Name -match "^$property$")) {
                $current = $current.$property
            } else {
                return $FallbackValue
            }
        } else {
            return $FallbackValue
        }
    }

    # Return the found value or fallback if null/empty
    if ($null -ne $current) {
        return $current
    } else {
        return $FallbackValue
    }
}