Set-StrictMode -Version Latest

function Test-IsExemptPowerShellCommentToken {
    <#
    .SYNOPSIS
    Determines whether a PowerShell comment token is an exempted help block or tool directive.

    .DESCRIPTION
    Exempts PowerShell comment-based help blocks required by PSScriptAnalyzer and platyPS,
    #Requires directives, and security scanner pragmas such as gitleaks:allow.

    .PARAMETER CommentText
    The raw text of a PowerShell Comment token.

    .OUTPUTS
    [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$CommentText
    )

    if ($CommentText -match '^<#' -and $CommentText -match '\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|INPUTS|OUTPUTS|NOTES|LINK)\b') {
        return $true
    }

    if ($CommentText -match '^#\s*gitleaks:allow\b') {
        return $true
    }

    if ($CommentText -match '^#Requires\b') {
        return $true
    }

    return $false
}

function Measure-NoCodeComment {
    <#
    .SYNOPSIS
    PSScriptAnalyzer custom rule banning non-help, non-directive code comments.

    .DESCRIPTION
    Inspects PowerShell AST tokens and emits a Warning diagnostic record for every
    comment token that is neither a PowerShell comment-based help block nor an
    approved tooling directive.

    .PARAMETER Token
    The token array supplied by PSScriptAnalyzer for the analyzed file.

    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.Token[]]$Token
    )

    $results = [System.Collections.Generic.List[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]]::new()

    foreach ($item in $Token) {
        if ($item.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment) {
            continue
        }

        if (Test-IsExemptPowerShellCommentToken -CommentText $item.Text) {
            continue
        }

        $record = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]::new(
            'Code comments are banned. Delete tautological or stale comments, file an issue for workarounds, or document non-obvious decisions outside inline code comments.',
            $item.Extent,
            'Measure-NoCodeComment',
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticSeverity]::Warning,
            $item.Extent.File
        )
        $results.Add($record)
    }

    return $results.ToArray()
}

Export-ModuleMember -Function 'Measure-NoCodeComment'
