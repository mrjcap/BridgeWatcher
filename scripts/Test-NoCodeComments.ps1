<#
.SYNOPSIS
Enforces the repository-wide code comment ban using a ratchet baseline.

.DESCRIPTION
Scans PowerShell files via the PowerShell AST tokenizer, hash-comment files
(YAML, Dockerfile, git hooks, ignore files) and markup files (HTML, CSS, JS,
XML) via directive-aware scanners, discovering files through git so new files
are covered automatically, then validates per-file comment counts against
.comment-ratchet.json so comments can only decrease toward zero.

.PARAMETER RepositoryRoot
Path to the repository root directory. Defaults to the current working directory.

.PARAMETER RatchetPath
Path to the ratchet baseline JSON file. Defaults to <RepositoryRoot>/.comment-ratchet.json.

.PARAMETER UpdateRatchet
Tightens the ratchet baseline file downward when comments have been removed.
Refuses to increase any file's allowance or add new non-zero files.

.PARAMETER AllowRatchetSlack
When set, skips failing when a ratcheted file has fewer comments than its ceiling.

.PARAMETER PassThru
Returns a structured evaluation object instead of throwing on violations.

.OUTPUTS
[PSCustomObject] when -PassThru is specified.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Get-Location).Path,

    [Parameter()]
    [string]$RatchetPath,

    [Parameter()]
    [switch]$UpdateRatchet,

    [Parameter()]
    [switch]$AllowRatchetSlack,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Converts an absolute file path to a forward-slash path relative to the repository root.

.DESCRIPTION
Builds a relative path using forward slashes for the comment inventory.

.PARAMETER FullPath
The absolute file path.

.PARAMETER Root
The absolute repository root path.
#>
function ConvertTo-NormalizedRelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$FullPath,
        [Parameter(Mandatory)][string]$Root
    )

    return ([System.IO.Path]::GetRelativePath($Root, $FullPath) -replace '\\', '/')
}

<#
.SYNOPSIS
Returns true when a PowerShell comment token is comment-based help or an approved directive.

.DESCRIPTION
Recognizes help headings and approved tool directives so they do not count as ordinary comments.

.PARAMETER CommentText
The raw PowerShell comment token text.
#>
function Test-IsExemptPowerShellComment {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$CommentText
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

<#
.SYNOPSIS
Returns true when a hash-comment line in shell, Dockerfile, or YAML is a required tool directive.

.DESCRIPTION
Recognizes expected shebangs and tool directives without excluding unrelated hash comments.

.PARAMETER Line
The full source line text.
#>
function Test-IsExemptHashDirectiveLine {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Line
    )

    $trimmed = $Line.Trim()

    if ($trimmed.StartsWith('#!')) {
        return $true
    }

    if ($trimmed -match '^#\s*(renovate:|hadolint ignore|nosemgrep:|semgrep:ignore|gitleaks:allow)') {
        return $true
    }

    if ($Line -match 'uses:\s+\S+@[0-9a-fA-F]{40}\s+#\s*v?\d') {
        return $true
    }

    return $false
}

<#
.SYNOPSIS
Finds disallowed PowerShell comment tokens in an in-memory script string.

.DESCRIPTION
Uses PowerShell tokens to avoid counting comment markers inside strings.

.PARAMETER Content
PowerShell source text.

.PARAMETER RelativePath
Relative path label to include on returned findings.
#>
function Get-PowerShellCommentFindingsFromContent {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)

    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($token in @($tokens)) {
        if ($token.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment) {
            continue
        }
        if (Test-IsExemptPowerShellComment -CommentText $token.Text) {
            continue
        }
        $findings.Add([PSCustomObject]@{
            File = $RelativePath
            Line = $token.Extent.StartLineNumber
            Text = ($token.Text -replace '\r?\n', ' ')
        })
    }

    return $findings.ToArray()
}

<#
.SYNOPSIS
Finds disallowed hash comments in shell, Dockerfile, or YAML text.

.DESCRIPTION
Checks hash-comment lines and excludes directives needed by the relevant tool.

.PARAMETER Content
File content text.

.PARAMETER RelativePath
Relative path label to include on returned findings.
#>
function Get-HashLineCommentFindingsFromContent {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    if ([string]::IsNullOrEmpty($Content)) {
        return $findings.ToArray()
    }

    $lines = $Content -split '\r?\n'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.Trim()
        if ([string]::IsNullOrEmpty($trimmed)) {
            continue
        }
        if (Test-IsExemptHashDirectiveLine -Line $line) {
            continue
        }
        if ($trimmed.StartsWith('#')) {
            $findings.Add([PSCustomObject]@{
                File = $RelativePath
                Line = ($i + 1)
                Text = $trimmed
            })
        }
    }

    return $findings.ToArray()
}

<#
.SYNOPSIS
Returns the language mode a markup-family file starts in: Script for JavaScript, Style for CSS, otherwise Markup.

.DESCRIPTION
Chooses the initial tokenizer mode from the file type before scanning begins.

.PARAMETER RelativePath
Forward-slash path relative to the repository root.
#>
function Get-MarkupInitialMode {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$RelativePath
    )

    if ($RelativePath -match '(?i)\.js$') { return 'Script' }
    if ($RelativePath -match '(?i)\.css$') { return 'Style' }
    return 'Markup'
}

<#
.SYNOPSIS
Builds one tokenizer regex per language mode. Each matches the next string literal, comment opener, template delimiter, or mode switch.

.DESCRIPTION
Supplies patterns for switching between markup, code, and template regions without treating quoted text as comments.
#>
function Get-MarkupTokenRegexMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    $tag = '(?:[^>"'']|"[^"]*"|''[^'']*'')*>'
    $doubleQuoted = '"(?:[^"\\\r\n]|\\[\s\S])*"'
    $singleQuoted = '''(?:[^''\\\r\n]|\\[\s\S])*'''

    return @{
        Markup   = [regex]::new("<!--|<script\b$tag|<style\b$tag", $options)
        Script   = [regex]::new("$doubleQuoted|$singleQuoted|//[^\r\n]*|/\*|</script\b|``|\{|\}", $options)
        Template = [regex]::new('\\[\s\S]|\$\{|`|</script\b', $options)
        Style    = [regex]::new("$doubleQuoted|$singleQuoted|/\*|</style\b", $options)
    }
}

<#
.SYNOPSIS
Updates brace depth and template-literal nesting after a script-mode or template-mode token.

.DESCRIPTION
A backtick opens or closes a template literal, "${" opens a substitution whose contents are ordinary script, and
a closing brace at depth zero returns from a substitution to its template. Frames on the stack remember the mode
and brace depth to resume.

.PARAMETER State
The scanner state hashtable with Mode, Embedded, Depth, and Stack entries. It is modified in place.

.PARAMETER Text
The token text.
#>
function Step-MarkupScriptState {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][string]$Text
    )

    $closesTemplate = ($Text -eq '`' -and $State.Mode -eq 'Template')
    $closesSubstitution = ($Text -eq '}' -and $State.Depth -eq 0 -and $State.Stack.Count -gt 0 -and $State.Stack.Peek().Mode -eq 'Template')

    if ($closesTemplate -or $closesSubstitution) {
        $frame = $State.Stack.Pop()
        $State.Mode = $frame.Mode
        $State.Depth = $frame.Depth
    } elseif ($Text -eq '`') {
        $State.Stack.Push([PSCustomObject]@{ Mode = $State.Mode; Depth = $State.Depth })
        $State.Mode = 'Template'
    } elseif ($Text -eq '${') {
        $State.Stack.Push([PSCustomObject]@{ Mode = 'Template'; Depth = 0 })
        $State.Mode = 'Script'
        $State.Depth = 0
    } elseif ($Text -eq '{') {
        $State.Depth++
    } elseif ($Text -eq '}' -and $State.Depth -gt 0) {
        $State.Depth--
    }
}

<#
.SYNOPSIS
Interprets one tokenizer match, updates the scanner state, and reports where scanning resumes and the comment span if any.

.DESCRIPTION
Updates the tokenizer state and identifies the span to count when a comment is found.

.PARAMETER Token
The regex match produced by the tokenizer for the current mode.

.PARAMETER State
The scanner state hashtable with Mode, Embedded, Depth, and Stack entries. It is modified in place.

.PARAMETER Content
The full file text.
#>
function Resolve-MarkupToken {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][System.Text.RegularExpressions.Match]$Token,
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][string]$Content
    )

    $text = $Token.Value
    $tokenEnd = $Token.Index + $Token.Length
    $result = [PSCustomObject]@{ Resume = $tokenEnd; CommentEnd = -1 }

    $closer = $null
    if ($text.StartsWith('<!--')) { $closer = '-->' } elseif ($text.StartsWith('/*')) { $closer = '*/' }

    if ($closer) {
        $closeAt = $Content.IndexOf($closer, $tokenEnd, [System.StringComparison]::Ordinal)
        $result.CommentEnd = if ($closeAt -lt 0) { $Content.Length } else { $closeAt + $closer.Length }
        $result.Resume = $result.CommentEnd
    } elseif ($text.StartsWith('//')) {
        $result.CommentEnd = $tokenEnd
    } elseif ($text -match '^</') {
        if ($State.Embedded) {
            $State.Mode = 'Markup'
            $State.Depth = 0
            $State.Stack.Clear()
        }
    } elseif ($text -match '^<script') {
        $State.Mode = 'Script'
    } elseif ($text -match '^<style') {
        $State.Mode = 'Style'
    } else {
        Step-MarkupScriptState -State $State -Text $text
    }

    return $result
}

<#
.SYNOPSIS
Finds disallowed comments in HTML, CSS, JavaScript, and XML text.

.DESCRIPTION
Tracks the language mode (markup, script, or style) and skips string literals, so comment openers inside strings
such as "/*" or "https://example.com" are not reported. HTML and XML comments are recognised in markup mode,
block comments in script and style modes, and line comments in script mode only. Template literal text is skipped
while the code inside "${...}" substitutions is scanned. Regular expression literals in JavaScript are not parsed.

.PARAMETER Content
File content text.

.PARAMETER RelativePath
Relative path label to include on returned findings.
#>
function Get-MarkupCommentFindingsFromContent {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][string]$RelativePath
    )

    if ([string]::IsNullOrEmpty($Content)) {
        return @()
    }

    $regexByMode = Get-MarkupTokenRegexMap
    $initialMode = Get-MarkupInitialMode -RelativePath $RelativePath
    $state = @{
        Mode     = $initialMode
        Embedded = ($initialMode -eq 'Markup')
        Depth    = 0
        Stack    = [System.Collections.Generic.Stack[object]]::new()
    }
    $lineStarts = [System.Collections.Generic.List[int]]::new()
    $lineStarts.Add(0)
    for ($at = $Content.IndexOf("`n"); $at -ge 0; $at = $Content.IndexOf("`n", $at + 1)) {
        $lineStarts.Add($at + 1)
    }
    $startsArray = $lineStarts.ToArray()

    $commentLines = [System.Collections.Generic.SortedSet[int]]::new()
    $position = 0
    while ($position -lt $Content.Length) {
        $token = $regexByMode[$state.Mode].Match($Content, $position)
        if (-not $token.Success) { break }

        $resolved = Resolve-MarkupToken -Token $token -State $state -Content $Content
        if ($resolved.CommentEnd -ge 0) {
            $first = Get-MarkupLineIndex -LineStarts $startsArray -Offset $token.Index
            $last = Get-MarkupLineIndex -LineStarts $startsArray -Offset ([Math]::Max($token.Index, $resolved.CommentEnd - 1))
            for ($line = $first; $line -le $last; $line++) { $null = $commentLines.Add($line) }
        }
        $position = [Math]::Max($resolved.Resume, $position + 1)
    }

    $textLines = $Content -split '\r?\n'
    return @(foreach ($line in $commentLines) {
        [PSCustomObject]@{
            File = $RelativePath
            Line = ($line + 1)
            Text = $textLines[$line].Trim()
        }
    })
}

<#
.SYNOPSIS
Returns the zero-based line number that contains a character offset.

.DESCRIPTION
Looks up the nearest line start at or before the offset.

.PARAMETER LineStarts
Ascending character offsets at which each line begins.

.PARAMETER Offset
The character offset to locate.
#>
function Get-MarkupLineIndex {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][int[]]$LineStarts,
        [Parameter(Mandatory)][int]$Offset
    )

    $found = [System.Array]::BinarySearch($LineStarts, $Offset)
    if ($found -ge 0) { return $found }
    return (-bnot $found) - 1
}

<#
.SYNOPSIS
Maps a repository-relative path to the comment syntax family used to scan it, or $null when the file is out of scope.

.DESCRIPTION
Classifies the path by extension or known configuration name before selecting a scanner.

.PARAMETER RelativePath
Forward-slash path relative to the repository root.
#>
function Get-RepoCommentFileKind {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$RelativePath
    )

    $leaf = $RelativePath.Substring($RelativePath.LastIndexOf('/') + 1)

    if ($leaf -match '(?i)\.(ps1|psm1|psd1)$') { return 'PowerShell' }
    if ($leaf -match '(?i)\.(ya?ml)$') { return 'HashLine' }
    if ($leaf -match '(?i)\.(html?|css|js|ps1xml|xml|xsl|xslt)$') { return 'Markup' }
    if ($leaf -in @('Dockerfile', '.gitignore', '.gitattributes', '.dockerignore', '.semgrepignore', '.gitleaksignore', '.editorconfig')) { return 'HashLine' }
    if ($RelativePath -match '^\.githooks/[^/]+$' -and $leaf -notmatch '\.') { return 'HashLine' }

    return $null
}

<#
.SYNOPSIS
Lists candidate repository-relative paths, preferring git (tracked plus untracked-but-not-ignored) and falling back to a directory walk.

.DESCRIPTION
Uses Git's inventory when possible so ignored files do not enter the audit.

.PARAMETER Root
The absolute repository root directory.
#>
function Get-RepoCandidatePath {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][string]$Root
    )

    $git = Get-Command -Name git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git -and (Test-Path -LiteralPath (Join-Path -Path $Root -ChildPath '.git'))) {
        $listed = & $git.Source -C $Root ls-files -z --cached --others --exclude-standard 2>$null
        if ($LASTEXITCODE -eq 0 -and $listed) {
            return [string[]]@(($listed -split "`0") | Where-Object -FilterScript { $_ })
        }
    }

    $excludedPattern = '(^|/)(?:\.git|node_modules|shard-output|shard-artifacts)(/|$)'
    return [string[]]@(Get-ChildItem -Path $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object -Process { ConvertTo-NormalizedRelativePath -FullPath $_.FullName -Root $Root } |
        Where-Object -FilterScript { $_ -notmatch $excludedPattern })
}

<#
.SYNOPSIS
Enumerates all repository code and config files subject to the comment ban.

.DESCRIPTION
Filters candidate paths to the formats supported by the comment scanners.

.PARAMETER Root
The absolute repository root directory.
#>
function Get-RepoCommentAuditFile {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Root
    )

    $excludedPattern = '(^|/)(?:\.git|node_modules|shard-output|shard-artifacts)(/|$)'
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($rel in (Get-RepoCandidatePath -Root $Root | Sort-Object -Unique)) {
        if ($rel -match $excludedPattern) { continue }
        $kind = Get-RepoCommentFileKind -RelativePath $rel
        if (-not $kind) { continue }
        $full = Join-Path -Path $Root -ChildPath $rel
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $results.Add([PSCustomObject]@{
            RelativePath = $rel
            FullName     = $full
            Kind         = $kind
        })
    }

    return @($results | Sort-Object -Property RelativePath)
}

<#
.SYNOPSIS
Scans all audited repository files and returns findings and per-file counts.

.DESCRIPTION
Collects findings and per-file totals for comparison with the ratchet limits.

.PARAMETER Root
The absolute repository root directory.
#>
function Get-RepoCommentInventory {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$Root
    )

    $files = @(Get-RepoCommentAuditFile -Root $Root)
    $allFindings = [System.Collections.Generic.List[object]]::new()
    $countsByFile = [ordered]@{}

    foreach ($entry in $files) {
        $content = Get-Content -LiteralPath $entry.FullName -Raw -ErrorAction Stop
        if ($null -eq $content) { $content = '' }
        $fileFindings = @(switch ($entry.Kind) {
            'PowerShell' { Get-PowerShellCommentFindingsFromContent -Content $content -RelativePath $entry.RelativePath }
            'Markup' { Get-MarkupCommentFindingsFromContent -Content $content -RelativePath $entry.RelativePath }
            default { Get-HashLineCommentFindingsFromContent -Content $content -RelativePath $entry.RelativePath }
        })

        if ($fileFindings.Count -gt 0) {
            $countsByFile[$entry.RelativePath] = $fileFindings.Count
            foreach ($item in $fileFindings) {
                $allFindings.Add($item)
            }
        }
    }

    return [PSCustomObject]@{
        ScannedFileCount = $files.Count
        TotalComments    = $allFindings.Count
        CountsByFile     = $countsByFile
        Findings         = $allFindings.ToArray()
    }
}

<#
.SYNOPSIS
Converts a ratchet configuration object into a hashtable of per-file caps and their total sum.

.DESCRIPTION
Reads each stored allowance and tallies the total recorded comment budget.

.PARAMETER Ratchet
The parsed ratchet JSON object containing a files property.
#>
function ConvertTo-RatchetAllowanceMap {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Ratchet
    )

    $allowedByFile = @{}
    $sum = 0
    if ($null -ne $Ratchet.files) {
        foreach ($prop in $Ratchet.files.PSObject.Properties) {
            $cap = [int]$prop.Value
            $allowedByFile[$prop.Name] = $cap
            $sum += $cap
        }
    }

    return [PSCustomObject]@{
        AllowedByFile = $allowedByFile
        Sum           = $sum
    }
}

<#
.SYNOPSIS
Finds files whose current comment counts exceed their ratchet allowances.

.DESCRIPTION
Compares current counts with the per-file and total limits in the ratchet.

.PARAMETER Inventory
The output object from Get-RepoCommentInventory.

.PARAMETER AllowedByFile
Hashtable mapping normalized relative file paths to maximum allowed comment counts.
#>
function Find-RatchetCeilingViolation {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Inventory,
        [Parameter(Mandatory)][hashtable]$AllowedByFile
    )

    $violations = [System.Collections.Generic.List[string]]::new()
    foreach ($fileKey in $Inventory.CountsByFile.Keys) {
        $actual = [int]$Inventory.CountsByFile[$fileKey]
        $allowed = if ($AllowedByFile.ContainsKey($fileKey)) { [int]$AllowedByFile[$fileKey] } else { 0 }
        if ($actual -le $allowed) {
            continue
        }

        $fileLines = @($Inventory.Findings | Where-Object -FilterScript { $_.File -eq $fileKey } | ForEach-Object -Process { "L$($_.Line): $($_.Text)" })
        $preview = ($fileLines | Select-Object -First 5) -join '; '
        $violations.Add("${fileKey}: found $actual comment(s), exceeds ratchet cap of $allowed ($preview)")
    }

    return $violations.ToArray()
}

<#
.SYNOPSIS
Finds ratcheted files whose comment counts have dropped below their configured caps.

.DESCRIPTION
Reports allowances that can be lowered without rejecting the current source.

.PARAMETER Inventory
The output object from Get-RepoCommentInventory.

.PARAMETER AllowedByFile
Hashtable mapping normalized relative file paths to maximum allowed comment counts.
#>
function Find-RatchetSlackNotice {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Inventory,
        [Parameter(Mandatory)][hashtable]$AllowedByFile
    )

    $notices = [System.Collections.Generic.List[string]]::new()
    foreach ($fileKey in ($AllowedByFile.Keys | Sort-Object)) {
        $allowed = [int]$AllowedByFile[$fileKey]
        $actual = if ($Inventory.CountsByFile.Contains($fileKey)) { [int]$Inventory.CountsByFile[$fileKey] } else { 0 }
        if ($actual -lt $allowed) {
            $notices.Add("${fileKey}: comment count dropped from $allowed to $actual. Tighten the ratchet with: pwsh -File ./scripts/Test-NoCodeComments.ps1 -UpdateRatchet")
        }
    }

    return $notices.ToArray()
}

<#
.SYNOPSIS
Evaluates a repository comment inventory against a ratchet baseline configuration.

.DESCRIPTION
Compares the scan with the stored baseline and produces violations and notices.

.PARAMETER Inventory
The output object from Get-RepoCommentInventory.

.PARAMETER Ratchet
The parsed ratchet JSON object containing total and files properties.

.PARAMETER AllowSlack
When set, does not treat reduced comment counts as ratchet-tightening violations.
#>
function Invoke-CommentRatchetEvaluation {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Inventory,
        [Parameter(Mandatory)][PSCustomObject]$Ratchet,
        [Parameter()][switch]$AllowSlack
    )

    $violations = [System.Collections.Generic.List[string]]::new()
    $slackNotices = [System.Collections.Generic.List[string]]::new()
    $allowance = ConvertTo-RatchetAllowanceMap -Ratchet $Ratchet
    $declaredTotal = [int]$Ratchet.total

    if ($declaredTotal -ne $allowance.Sum) {
        $violations.Add("Ratchet total ($declaredTotal) does not match sum of per-file caps ($($allowance.Sum)).")
    }

    foreach ($ceilingViolation in @(Find-RatchetCeilingViolation -Inventory $Inventory -AllowedByFile $allowance.AllowedByFile)) {
        $violations.Add($ceilingViolation)
    }

    foreach ($slackMsg in @(Find-RatchetSlackNotice -Inventory $Inventory -AllowedByFile $allowance.AllowedByFile)) {
        if ($AllowSlack) {
            $slackNotices.Add($slackMsg)
        } else {
            $violations.Add($slackMsg)
        }
    }

    if ($Inventory.TotalComments -gt $declaredTotal) {
        $violations.Add("Total repository comments ($($Inventory.TotalComments)) exceed ratchet total ($declaredTotal).")
    }

    return [PSCustomObject]@{
        Passed           = ($violations.Count -eq 0)
        ScannedFileCount = $Inventory.ScannedFileCount
        TotalComments    = $Inventory.TotalComments
        RatchetTotal     = $declaredTotal
        Violations       = $violations.ToArray()
        SlackNotices     = $slackNotices.ToArray()
        Inventory        = $Inventory
    }
}

<#
.SYNOPSIS
Tightens a ratchet baseline file downward based on the current inventory.

.DESCRIPTION
Updates the baseline using current counts without increasing the allowed comment count.

.PARAMETER RatchetFilePath
Absolute path to the .comment-ratchet.json file.

.PARAMETER Inventory
The output object from Get-RepoCommentInventory.
#>
function Update-CommentRatchetFile {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$RatchetFilePath,
        [Parameter(Mandatory)][PSCustomObject]$Inventory
    )

    $existing = Get-Content -LiteralPath $RatchetFilePath -Raw -Encoding utf8 | ConvertFrom-Json
    $allowance = ConvertTo-RatchetAllowanceMap -Ratchet $existing
    $allowedByFile = $allowance.AllowedByFile

    $regressions = [System.Collections.Generic.List[string]]::new()
    foreach ($fileKey in $Inventory.CountsByFile.Keys) {
        $actual = [int]$Inventory.CountsByFile[$fileKey]
        $allowed = if ($allowedByFile.ContainsKey($fileKey)) { [int]$allowedByFile[$fileKey] } else { 0 }
        if ($actual -gt $allowed) {
            $regressions.Add("${fileKey}: cannot ratchet upward from $allowed to $actual.")
        }
    }

    if ($regressions.Count -gt 0) {
        throw ("Refusing to raise comment ratchet:`n" + ($regressions -join "`n"))
    }

    $nextFiles = [ordered]@{}
    $nextTotal = 0
    foreach ($fileKey in ($Inventory.CountsByFile.Keys | Sort-Object)) {
        $count = [int]$Inventory.CountsByFile[$fileKey]
        if ($count -gt 0) {
            $nextFiles[$fileKey] = $count
            $nextTotal += $count
        }
    }

    $updated = [ordered]@{
        version     = 1
        description = 'Per-file maximum allowed non-help, non-directive code comments. Ratchet-only: counts may decrease toward 0 and never increase.'
        total       = $nextTotal
        files       = $nextFiles
    }

    if ($PSCmdlet.ShouldProcess($RatchetFilePath, "Tighten comment ratchet to total=$nextTotal")) {
        $json = ($updated | ConvertTo-Json -Depth 5) + "`n"
        [System.IO.File]::WriteAllText($RatchetFilePath, $json, [System.Text.UTF8Encoding]::new($false))
    }

    return [PSCustomObject]$updated
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if ([string]::IsNullOrWhiteSpace($RatchetPath)) {
    $RatchetPath = Join-Path -Path $resolvedRoot -ChildPath '.comment-ratchet.json'
}

if (-not (Test-Path -LiteralPath $RatchetPath -PathType Leaf)) {
    throw "Comment ratchet baseline file not found at '$RatchetPath'."
}

$inventory = Get-RepoCommentInventory -Root $resolvedRoot

if ($UpdateRatchet) {
    $updated = Update-CommentRatchetFile -RatchetFilePath $RatchetPath -Inventory $inventory
    Write-Output -InputObject "Updated comment ratchet '$RatchetPath': total=$($updated.total) across $($updated.files.Count) file(s)."
    if ($PassThru) { return $updated }
    return
}

$ratchet = Get-Content -LiteralPath $RatchetPath -Raw -Encoding utf8 | ConvertFrom-Json
$evaluation = Invoke-CommentRatchetEvaluation -Inventory $inventory -Ratchet $ratchet -AllowSlack:$AllowRatchetSlack

if ($PassThru) {
    return $evaluation
}

if (-not $evaluation.Passed) {
    $detail = $evaluation.Violations -join "`n"
    throw "Comment-ban ratchet failed ($($evaluation.Violations.Count) issue(s)):`n$detail"
}

Write-Output -InputObject "Comment-ban ratchet passed: $($evaluation.TotalComments)/$($evaluation.RatchetTotal) ratcheted comment(s) across $($evaluation.ScannedFileCount) audited file(s)."
