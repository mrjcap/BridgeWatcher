function Test-BridgeInputSanitization {
    <#
    .SYNOPSIS
    Validates and sanitizes URLs and paths for security (MED-007).

    .DESCRIPTION
    Provides input sanitization for URLs and file paths to prevent injection attacks,
    path traversal, and other security vulnerabilities.

    .PARAMETER InputString
    The string to validate and sanitize (URL or file path).

    .PARAMETER Type
    The type of input being validated (URL, FilePath, or Generic).

    .PARAMETER AllowEmpty
    Whether to allow empty/null values.

    .OUTPUTS
    [PSCustomObject] - Result object with IsValid, SanitizedValue, and ErrorCode properties

    .EXAMPLE
    Test-BridgeInputSanitization -InputString 'https://example.com/image.jpg' -Type 'URL'

    .EXAMPLE
    Test-BridgeInputSanitization -InputString 'C:\logs\bridge.json' -Type 'FilePath'

    .NOTES
    Addresses MED-007: Input Sanitization για URLs/Paths requirement.
    Filters special characters and prevents common injection attacks.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputString,

        [Parameter(Mandatory)]
        [ValidateSet('URL', 'FilePath', 'Generic')]
        [string]$Type,

        [Parameter()]
        [bool]$AllowEmpty = $false
    )

    $result = [PSCustomObject]@{
        IsValid = $false
        SanitizedValue = ''
        ErrorCode = ''
        ErrorMessage = ''
    }

    # Check for null/empty
    if ([string]::IsNullOrWhiteSpace($InputString)) {
        if ($AllowEmpty) {
            $result.IsValid = $true
            $result.SanitizedValue = ''
            return $result
        } else {
            $result.ErrorCode = Get-BridgeErrorCode -Category 'Validation' -Type 'ParameterEmpty'
            $result.ErrorMessage = 'Input cannot be null or empty'
            return $result
        }
    }

    # Common dangerous patterns (check for URL and FilePath types)
    if ($Type -in @('URL', 'FilePath')) {
        $dangerousPatterns = @(
            '\.\.',           # Path traversal
            'javascript:',    # JavaScript injection
            'data:',          # Data URLs
            'vbscript:',      # VBScript injection
            '<script',        # Script tags
            'eval\(',         # Code execution
            'exec\(',         # Command execution
            '\$\(',           # PowerShell subexpression
            '`',              # PowerShell backticks
            ';',              # Command separator
            '&',              # Command separator
            '\|',             # Pipe operator
            '\x00'            # Null bytes
        )

        # Check for dangerous patterns
        foreach ($pattern in $dangerousPatterns) {
            if ($InputString -match $pattern) {
                $result.ErrorCode = Get-BridgeErrorCode -Category 'Sanitization' -Type 'InvalidCharacters'
                $result.ErrorMessage = "Input contains potentially dangerous pattern: $pattern"
                return $result
            }
        }
    }

    switch ($Type) {
        'URL' {
            try {
                # Validate URL format
                $uri = [Uri]$InputString
                if (-not $uri.IsAbsoluteUri) {
                    $result.ErrorCode = Get-BridgeErrorCode -Category 'Network' -Type 'InvalidUrl'
                    $result.ErrorMessage = 'URL must be absolute'
                    return $result
                }

                # Check allowed schemes
                $allowedSchemes = @('http', 'https')
                if ($uri.Scheme -notin $allowedSchemes) {
                    $result.ErrorCode = Get-BridgeErrorCode -Category 'Network' -Type 'InvalidUrl'
                    $result.ErrorMessage = "URL scheme '$($uri.Scheme)' not allowed. Allowed: $($allowedSchemes -join ', ')"
                    return $result
                }

                $result.IsValid = $true
                $result.SanitizedValue = $uri.ToString()
            }
            catch {
                $result.ErrorCode = Get-BridgeErrorCode -Category 'Network' -Type 'InvalidUrl'
                $result.ErrorMessage = "Invalid URL format: $($_.Exception.Message)"
                return $result
            }
        }
        'FilePath' {
            try {
                # Basic path validation
                $invalidChars = [System.IO.Path]::GetInvalidPathChars()
                foreach ($char in $invalidChars) {
                    if ($InputString.Contains($char)) {
                        $result.ErrorCode = Get-BridgeErrorCode -Category 'Sanitization' -Type 'InvalidCharacters'
                        $result.ErrorMessage = "Path contains invalid character: $char"
                        return $result
                    }
                }

                # Normalize path separators and resolve relative paths
                $normalizedPath = [System.IO.Path]::GetFullPath($InputString)
                
                $result.IsValid = $true
                $result.SanitizedValue = $normalizedPath
            }
            catch {
                $result.ErrorCode = Get-BridgeErrorCode -Category 'Sanitization' -Type 'PathTraversal'
                $result.ErrorMessage = "Invalid file path: $($_.Exception.Message)"
                return $result
            }
        }
        'Generic' {
            # Remove or escape potentially dangerous characters
            $sanitized = $InputString -replace '[<>&"'']', ''
            $sanitized = $sanitized -replace 'script', ''  # Remove script tags completely
            $sanitized = $sanitized.Trim()
            
            $result.IsValid = $true
            $result.SanitizedValue = $sanitized
        }
    }

    return $result
}