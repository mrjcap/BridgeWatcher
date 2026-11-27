<#
.SYNOPSIS
Normalises platyPS-generated Markdown so it satisfies markdownlint.

.DESCRIPTION
platyPS emits bare code fences in the SYNTAX and EXAMPLES sections and one very long CommonParameters paragraph.
This script tags those fences as PowerShell and wraps that paragraph. Existing formatting is left untouched, so
running it twice produces no further changes, and the line ending style of each file is preserved.

.PARAMETER Path
Directory containing the generated Markdown files, or a single Markdown file.

.OUTPUTS
[string[]] The names of the files that were rewritten.
#>
[CmdletBinding()]
[OutputType([string[]])]
param(
    [Parameter()]
    [string]$Path
)

function Format-PlatyPSCommonParameterLine {
    <#
    .SYNOPSIS
    Wraps the long CommonParameters paragraph emitted by platyPS.

    .PARAMETER Line
    One Markdown line outside a code fence.

    .PARAMETER Newline
    The line ending used by the file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
        [Parameter(Mandatory)][string]$Newline
    )

    if ($Line.Length -le 120 -or -not $Line.StartsWith('This cmdlet supports the common parameters: ')) {
        return $Line
    }

    $wrapped = $Line.Replace(', -InformationVariable', ",${Newline}-InformationVariable")
    return $wrapped.Replace(', and -WarningVariable', ",${Newline}and -WarningVariable")
}

function Test-PlatyPSBareCodeFence {
    <#
    .SYNOPSIS
    Reports whether a fence line opens an untagged code block in a section that holds PowerShell.

    .PARAMETER Line
    One Markdown line that starts with a code fence marker.

    .PARAMETER InFence
    Whether the scanner is already inside a code block.

    .PARAMETER Section
    The most recent level-two heading.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Line,
        [Parameter(Mandatory)][bool]$InFence,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Section
    )

    return (-not $InFence) -and $Line -eq '```' -and $Section -in @('## SYNTAX', '## EXAMPLES')
}

function Format-PlatyPSMarkdownContent {
    <#
    .SYNOPSIS
    Applies the platyPS formatting fixes to one document.

    .PARAMETER Content
    The full Markdown text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    $newline = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = $Content -split '\r?\n'
    $section = ''
    $inFence = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.StartsWith('```')) {
            if (Test-PlatyPSBareCodeFence -Line $line -InFence $inFence -Section $section) {
                $lines[$i] = '```powershell'
            }
            $inFence = -not $inFence
        } elseif (-not $inFence) {
            if ($line.StartsWith('## ')) { $section = $line }
            $lines[$i] = Format-PlatyPSCommonParameterLine -Line $line -Newline $newline
        }
    }

    return $lines -join $newline
}

function Invoke-PlatyPSMarkdownFormat {
    <#
    .SYNOPSIS
    Formats every Markdown file under a path and returns the files that changed.

    .PARAMETER Path
    Directory containing Markdown files, or a single Markdown file.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path '$Path' does not exist."
    }

    $files = if (Test-Path -LiteralPath $Path -PathType Container) {
        Get-ChildItem -LiteralPath $Path -Filter '*.md' -File
    } else {
        Get-Item -LiteralPath $Path
    }

    $changed = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $files) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
        $formatted = Format-PlatyPSMarkdownContent -Content $content
        if ($formatted -cne $content) {
            Set-Content -LiteralPath $file.FullName -Value $formatted -Encoding utf8 -NoNewline
            $changed.Add($file.Name)
        }
    }

    return $changed.ToArray()
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

if ([string]::IsNullOrWhiteSpace($Path)) {
    throw 'The -Path parameter is required.'
}

$rewritten = Invoke-PlatyPSMarkdownFormat -Path $Path
foreach ($name in $rewritten) {
    Write-Output "Formatted $name"
}
