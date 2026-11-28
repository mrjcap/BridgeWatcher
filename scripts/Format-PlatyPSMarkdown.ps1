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

<#
.SYNOPSIS
Wraps the long CommonParameters paragraph emitted by platyPS.

.DESCRIPTION
Splits the generated common-parameter text at the expected documentation boundary.

.PARAMETER Line
One Markdown line outside a code fence.

.PARAMETER Newline
The line ending used by the file.
#>
function Format-PlatyPSCommonParameterLine {
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

<#
.SYNOPSIS
Parses a Markdown code fence line.

.DESCRIPTION
Returns the delimiter of a fence marker so the formatter can track where code blocks begin and end.

.PARAMETER Line
One Markdown line.

.OUTPUTS
An object with the fence character, its length and any info string, or $null when the line is not a fence.
#>
function Get-PlatyPSFenceMarker {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line
    )

    if ($Line -notmatch '^ {0,3}(?<fence>`{3,}|~{3,})(?<info>.*)$') {
        return $null
    }

    return [pscustomobject]@{
        Char   = $Matches['fence'][0]
        Length = $Matches['fence'].Length
        Info   = $Matches['info'].Trim()
    }
}

<#
.SYNOPSIS
Reports whether a line is an untagged backtick fence in a section that holds PowerShell.

.DESCRIPTION
Distinguishes a plain backtick fence from an already tagged fence before adding a language label.

.PARAMETER Line
One Markdown line.

.PARAMETER Section
The most recent level-two heading.
#>
function Test-PlatyPSBareCodeFence {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Section
    )

    return $Line -eq '```' -and $Section -in @('## SYNTAX', '## EXAMPLES')
}

<#
.SYNOPSIS
Returns the fence that is open after a line has been read.

.DESCRIPTION
Updates the open-fence state while preserving fences with a different delimiter.

.PARAMETER Marker
The marker parsed from the line, or $null when the line is not a fence.

.PARAMETER Open
The marker that opened the current fence, or $null outside a fence.

.OUTPUTS
The open fence marker, or $null when no fence is open.
#>
function Step-PlatyPSFence {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()][AllowNull()][pscustomobject]$Marker,
        [Parameter()][AllowNull()][pscustomobject]$Open
    )

    if (-not $Open) {
        return $Marker
    }

    $closes = $Marker -and $Marker.Char -eq $Open.Char -and $Marker.Length -ge $Open.Length -and -not $Marker.Info
    if ($closes) {
        return $null
    }

    return $Open
}

<#
.SYNOPSIS
Applies the platyPS formatting fixes to one document.

.DESCRIPTION
Tracks section headings and open fences while formatting generated help text.

.PARAMETER Content
The full Markdown text.
#>
function Format-PlatyPSMarkdownContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    $newline = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = $Content -split '\r?\n'
    $section = ''
    $open = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $marker = Get-PlatyPSFenceMarker -Line $line
        if (-not $open -and (Test-PlatyPSBareCodeFence -Line $line -Section $section)) {
            $lines[$i] = '```powershell'
        }

        $wasOpen = [bool]$open
        $open = Step-PlatyPSFence -Marker $marker -Open $open
        if ($wasOpen -or $marker) { continue }

        if ($line.StartsWith('## ')) { $section = $line }
        $lines[$i] = Format-PlatyPSCommonParameterLine -Line $line -Newline $newline
    }

    return $lines -join $newline
}

<#
.SYNOPSIS
Formats every Markdown file under a path and returns the files that changed.

.DESCRIPTION
Reads each generated Markdown document and writes back only the ones affected by formatting.

.PARAMETER Path
Directory containing Markdown files, or a single Markdown file.
#>
function Invoke-PlatyPSMarkdownFormat {
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
    Write-Output -InputObject "Formatted $name"
}
