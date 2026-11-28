BeforeAll -ScriptBlock {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'PowerShellStyle.psm1') -Force
}

Describe -Name 'PowerShell style rules' -Fixture {
    It -Name 'rejects <Name>' -ForEach @(
        @{ Name = 'inside-body help'; Code = "function Get-Example {`n<#`n.SYNOPSIS`nExample.`n.DESCRIPTION`nDetails.`n#>`n}"; Rule = 'HelpPlacement' }
        @{ Name = 'a line comment'; Code = "# .SYNOPSIS`nfunction Get-Example {}"; Rule = 'HelpPlacement' }
        @{ Name = 'a blank line between help and function'; Code = "<#`n.SYNOPSIS`nExample.`n.DESCRIPTION`nDetails.`n#>`n`nfunction Get-Example {}"; Rule = 'HelpPlacement' }
        @{ Name = 'omitted headings'; Code = "<#`n.PARAMETER Value`nInput.`n#>`nfunction Get-Example { param(`$Value) `$Value }"; Rule = 'HelpSection' }
        @{ Name = 'an empty synopsis'; Code = "<#`n.SYNOPSIS`n.DESCRIPTION`nDetails.`n#>`nfunction Get-Example {}"; Rule = 'HelpSection' }
        @{ Name = 'a whitespace-only description'; Code = "<#`n.SYNOPSIS`nExample.`n.DESCRIPTION`n  `t`n.EXAMPLE`nGet-Example`n#>`nfunction Get-Example {}"; Rule = 'HelpSection' }
        @{ Name = 'an empty parameter description'; Code = "<#`n.SYNOPSIS`nExample.`n.DESCRIPTION`nDetails.`n.PARAMETER Value`n.EXAMPLE`nGet-Example -Value sample`n#>`nfunction Get-Example(`$Value) { `$Value }"; Rule = 'HelpParameter' }
        @{ Name = 'an undocumented signature parameter'; Code = "<#`n.SYNOPSIS`nExample.`n.DESCRIPTION`nDetails.`n#>`nfunction Get-Example(`$Value) { `$Value }"; Rule = 'HelpParameter' }
        @{ Name = 'duplicate entries'; Code = "<#`n.SYNOPSIS`nExample.`n.DESCRIPTION`nDetails.`n.PARAMETER Value`nInput.`n.PARAMETER Value`nAgain.`n#>`nfunction Get-Example { param(`$Value) `$Value }"; Rule = 'HelpParameter' }
        @{ Name = 'no block for a nested helper'; Code = "<#`n.SYNOPSIS`nExample.`n.DESCRIPTION`nDetails.`n#>`nfunction Get-Outer {`nfunction Get-Inner {}`n}"; Rule = 'HelpPlacement' }
        @{ Name = 'one positional argument'; Code = 'Get-Item .'; Rule = 'PositionalArgument' }
        @{ Name = 'two positional arguments'; Code = 'Join-Path . child'; Rule = 'PositionalArgument' }
        @{ Name = 'a positional argument after a switch'; Code = 'Get-Item -Force .'; Rule = 'PositionalArgument' }
        @{ Name = 'a positional argument alongside a splat'; Code = 'Get-Item @options .'; Rule = 'PositionalArgument' }
        @{ Name = 'a positional argument to a local function'; Code = 'function Get-Example { param([switch]$Force, $Path) }; Get-Example -Force .'; Rule = 'PositionalArgument' }
        @{ Name = 'a positional argument to a cmdlet alias'; Code = 'gi .'; Rule = 'PositionalArgument' }
        @{ Name = 'ambiguous definitions in one scope'; Code = 'function Get-Example([switch]$Force) {}; function Get-Example([string]$Force) {}; Get-Example -Force sample'; Rule = 'CommandAmbiguity' }
    ) -Test {
        $issues = @(Get-PowerShellStyleFinding -Source $Code -Path 'scripts/Fixture.ps1')
        $issues.Rule | Should -Contain -ExpectedValue $Rule
        ($issues | Where-Object -FilterScript { $_.Rule -eq $Rule }).Line | Should -Not -BeNullOrEmpty
    }

    It -Name 'accepts <Name>' -ForEach @(
        @{ Name = 'adjacent blocks including a nested helper'; Code = "<#`n.SYNOPSIS`nOuter.`n.DESCRIPTION`nDetails.`n#>`nfunction Get-Outer {`n<#`n.SYNOPSIS`nInner.`n.DESCRIPTION`nDetails.`n.PARAMETER Value`nInput.`n#>`nfunction Get-Inner(`$Value) { `$Value }`nGet-Inner -Value 'value'`n}" }
        @{ Name = 'named parameters and a splat'; Code = 'Get-Item -LiteralPath:. -Force; Get-Item @options -Force; Get-Item -Path (Join-Path -Path . -ChildPath child)' }
        @{ Name = 'native command arguments'; Code = 'git status --short' }
    ) -Test {
        @(Get-PowerShellStyleFinding -Source $Code -Path 'Fixture.ps1') | Should -BeNullOrEmpty
    }

    It -Name 'uses the nearest function scope to classify arguments' -Test {
        $source = @'
function Get-Example([switch]$Force, $Name) { $Name }
Get-Example -Force sample
function Invoke-Wrapper {
    function Get-Example([string]$Force) { $Force }
    Get-Example -Force sample
}
'@
        $issues = @(Get-PowerShellStyleFinding -Source $source -Path 'Fixture.ps1' |
            Where-Object -FilterScript { $_.Rule -in 'PositionalArgument', 'CommandAmbiguity' })
        $issues.Count | Should -Be -ExpectedValue 1
        $issues[0].Rule | Should -Be -ExpectedValue 'PositionalArgument'
        $issues[0].Line | Should -Be -ExpectedValue 2
    }

    It -Name 'staged analyzer reports <Rule> in scripts independently of general lint' -ForEach @(
        @{ Code = 'function Get-LintFixture {}'; Rule = 'HelpPlacement' }
        @{ Code = "Get-StagedFixture -Enabled 'bare'"; Rule = 'PositionalArgument' }
        @{ Code = "Get-StagedFixture -Enabled -Value 'named'"; Rule = '' }
    ) -Test {
        $repoRoot = Join-Path -Path $PSScriptRoot -ChildPath '../..'
        $analyzer = Join-Path -Path $repoRoot -ChildPath '.githooks/Invoke-StagedScriptAnalyzer.ps1'
        $snapshot = Join-Path -Path $TestDrive -ChildPath 'snapshot'
        $null = New-Item -Path "$snapshot/staged/scripts", "$snapshot/staged/Tests/Review" -ItemType Directory -Force
        Copy-Item -LiteralPath "$PSScriptRoot/PowerShellStyle.psm1" -Destination "$snapshot/staged/Tests/Review"
        Copy-Item -LiteralPath "$repoRoot/PSScriptAnalyzerSettings.psd1" -Destination "$snapshot/staged"
        $helper = @'
<#
.SYNOPSIS
Echoes a value.
.DESCRIPTION
Returns the provided value when enabled.
.PARAMETER Enabled
Enables output.
.PARAMETER Value
Text to return.
#>
function Get-StagedFixture {
    param([switch]$Enabled, [string]$Value)
    if ($Enabled) { $Value }
}
'@
        Set-Content -LiteralPath "$snapshot/staged/scripts/Definition.ps1" -Value $helper
        Set-Content -LiteralPath "$snapshot/staged/scripts/Fixture.ps1" -Value $Code
        [IO.File]::WriteAllText("$snapshot/paths", "scripts/Fixture.ps1`0")

        Push-Location -LiteralPath $snapshot
        try {
            if ($Rule) {
                { & $analyzer } | Should -Throw -ExpectedMessage "*$Rule*"
            } else {
                (& $analyzer) | Should -Match -RegularExpression 'PRE-COMMIT PASSED: checked 1 staged PowerShell file'
            }
        } finally {
            Pop-Location
        }
    }

    It -Name 'finds no style violations in tracked PowerShell files' -Test {
        $repoRoot = Join-Path -Path $PSScriptRoot -ChildPath '../..'
        $paths = @(Get-TrackedPowerShellPath -RepositoryRoot $repoRoot)
        $findings = @(Get-PowerShellStyleFinding -RepositoryRoot $repoRoot -Paths $paths)
        if ($findings.Count -gt 0) {
            $messages = $findings | ForEach-Object -Process { "$($_.Path):$($_.Line) [$($_.Rule)] $($_.Message)" }
            throw ($messages -join [Environment]::NewLine)
        }
    }
}
