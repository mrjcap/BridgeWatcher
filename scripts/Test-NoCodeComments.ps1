<#
.SYNOPSIS
Enforces the repository-wide code comment ban using a ratchet baseline.

.DESCRIPTION
Scans PowerShell files via the PowerShell AST tokenizer and non-PowerShell
code/config files (git hooks, Dockerfile, YAML workflows/configs) via a
directive-aware scanner, then validates per-file comment counts against
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

function ConvertTo-NormalizedRelativePath {
    <#
    .SYNOPSIS
    Converts an absolute file path to a forward-slash path relative to the repository root.

    .PARAMETER FullPath
    The absolute file path.

    .PARAMETER Root
    The absolute repository root path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$FullPath,
        [Parameter(Mandatory)][string]$Root
    )

    return ([System.IO.Path]::GetRelativePath($Root, $FullPath) -replace '\\', '/')
}

function Test-IsExemptPowerShellComment {
    <#
    .SYNOPSIS
    Returns true when a PowerShell comment token is comment-based help or an approved directive.

    .PARAMETER CommentText
    The raw PowerShell comment token text.
    #>
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

function Test-IsExemptHashDirectiveLine {
    <#
    .SYNOPSIS
    Returns true when a hash-comment line in shell, Dockerfile, or YAML is a required tool directive.

    .PARAMETER Line
    The full source line text.
    #>
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

function Get-PowerShellCommentFindingsFromContent {
    <#
    .SYNOPSIS
    Finds disallowed PowerShell comment tokens in an in-memory script string.

    .PARAMETER Content
    PowerShell source text.

    .PARAMETER RelativePath
    Relative path label to include on returned findings.
    #>
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

function Get-HashLineCommentFindingsFromContent {
    <#
    .SYNOPSIS
    Finds disallowed hash comments in shell, Dockerfile, or YAML text.

    .PARAMETER Content
    File content text.

    .PARAMETER RelativePath
    Relative path label to include on returned findings.
    #>
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

function Get-RepoCommentAuditFile {
    <#
    .SYNOPSIS
    Enumerates all repository code and config files subject to the comment ban.

    .PARAMETER Root
    The absolute repository root directory.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Root
    )

    $excludedPattern = '(^|/)(?:\.git|node_modules|shard-output|shard-artifacts)(/|$)'
    $results = [System.Collections.Generic.List[object]]::new()

    $psFiles = Get-ChildItem -Path $Root -Recurse -File -Force -Include '*.ps1', '*.psm1', '*.psd1' -ErrorAction SilentlyContinue
    foreach ($f in @($psFiles)) {
        $rel = ConvertTo-NormalizedRelativePath -FullPath $f.FullName -Root $Root
        if ($rel -match $excludedPattern) { continue }
        $results.Add([PSCustomObject]@{
            RelativePath = $rel
            FullName     = $f.FullName
            Kind         = 'PowerShell'
        })
    }

    $hashCandidates = [System.Collections.Generic.List[string]]::new()
    foreach ($single in @('.githooks/pre-commit', '.githooks/pre-push', 'Docker/Dockerfile', 'Docker/filebeat.yml', 'docker-compose.yml', '.semgrep.yml')) {
        $full = Join-Path -Path $Root -ChildPath $single
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $hashCandidates.Add($full)
        }
    }

    $workflowsDir = Join-Path -Path $Root -ChildPath '.github/workflows'
    if (Test-Path -LiteralPath $workflowsDir -PathType Container) {
        $wfFiles = Get-ChildItem -Path $workflowsDir -File -Filter '*.yml' -ErrorAction SilentlyContinue
        foreach ($wf in @($wfFiles)) {
            $hashCandidates.Add($wf.FullName)
        }
    }

    foreach ($fullPath in ($hashCandidates | Sort-Object -Unique)) {
        $rel = ConvertTo-NormalizedRelativePath -FullPath $fullPath -Root $Root
        $results.Add([PSCustomObject]@{
            RelativePath = $rel
            FullName     = $fullPath
            Kind         = 'HashLine'
        })
    }

    return @($results | Sort-Object -Property RelativePath)
}

function Get-RepoCommentInventory {
    <#
    .SYNOPSIS
    Scans all audited repository files and returns findings and per-file counts.

    .PARAMETER Root
    The absolute repository root directory.
    #>
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
        $fileFindings = @(if ($entry.Kind -eq 'PowerShell') {
            Get-PowerShellCommentFindingsFromContent -Content $content -RelativePath $entry.RelativePath
        } else {
            Get-HashLineCommentFindingsFromContent -Content $content -RelativePath $entry.RelativePath
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

function ConvertTo-RatchetAllowanceMap {
    <#
    .SYNOPSIS
    Converts a ratchet configuration object into a hashtable of per-file caps and their total sum.

    .PARAMETER Ratchet
    The parsed ratchet JSON object containing a files property.
    #>
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

function Find-RatchetCeilingViolation {
    <#
    .SYNOPSIS
    Finds files whose current comment counts exceed their ratchet allowances.

    .PARAMETER Inventory
    The output object from Get-RepoCommentInventory.

    .PARAMETER AllowedByFile
    Hashtable mapping normalized relative file paths to maximum allowed comment counts.
    #>
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

        $fileLines = @($Inventory.Findings | Where-Object { $_.File -eq $fileKey } | ForEach-Object { "L$($_.Line): $($_.Text)" })
        $preview = ($fileLines | Select-Object -First 5) -join '; '
        $violations.Add("${fileKey}: found $actual comment(s), exceeds ratchet cap of $allowed ($preview)")
    }

    return $violations.ToArray()
}

function Find-RatchetSlackNotice {
    <#
    .SYNOPSIS
    Finds ratcheted files whose comment counts have dropped below their configured caps.

    .PARAMETER Inventory
    The output object from Get-RepoCommentInventory.

    .PARAMETER AllowedByFile
    Hashtable mapping normalized relative file paths to maximum allowed comment counts.
    #>
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

function Invoke-CommentRatchetEvaluation {
    <#
    .SYNOPSIS
    Evaluates a repository comment inventory against a ratchet baseline configuration.

    .PARAMETER Inventory
    The output object from Get-RepoCommentInventory.

    .PARAMETER Ratchet
    The parsed ratchet JSON object containing total and files properties.

    .PARAMETER AllowSlack
    When set, does not treat reduced comment counts as ratchet-tightening violations.
    #>
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

function Update-CommentRatchetFile {
    <#
    .SYNOPSIS
    Tightens a ratchet baseline file downward based on the current inventory.

    .PARAMETER RatchetFilePath
    Absolute path to the .comment-ratchet.json file.

    .PARAMETER Inventory
    The output object from Get-RepoCommentInventory.
    #>
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
    Write-Output "Updated comment ratchet '$RatchetPath': total=$($updated.total) across $($updated.files.Count) file(s)."
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

Write-Output "Comment-ban ratchet passed: $($evaluation.TotalComments)/$($evaluation.RatchetTotal) ratcheted comment(s) across $($evaluation.ScannedFileCount) audited file(s)."
