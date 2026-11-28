BeforeAll -Scriptblock {
    $script:ScriptPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Format-PlatyPSMarkdown.ps1'))
    . $script:ScriptPath
    $script:BareDocument = "## SYNTAX`n" + '```' + "`n" + '```'
    $script:LongLine = 'This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, ' +
    '-InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. ' +
    'For more information, see about_CommonParameters.'
}

Describe -Name 'Format-PlatyPSMarkdown' -Fixture {
    Context -Name 'Format-PlatyPSMarkdownContent' -Fixture {
        It -Name 'Tags bare fences in the SYNTAX and EXAMPLES sections as PowerShell' -Test {
            $content = @('## SYNTAX', '', '```', 'Get-Thing', '```', '', '## EXAMPLES', '', '```', 'Get-Thing -Id 1', '```') -join "`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            ($result -split "`n" | Where-Object -FilterScript { $_ -eq '```powershell' }).Count | Should -Be -ExpectedValue 2
            ($result -split "`n" | Where-Object -FilterScript { $_ -eq '```' }).Count | Should -Be -ExpectedValue 2
        }

        It -Name 'Leaves bare fences in other sections and already tagged fences alone' -Test {
            $content = @('## DESCRIPTION', '```', 'text', '```', '## EXAMPLES', '```powershell', 'Get-Thing', '```') -join "`n"
            Format-PlatyPSMarkdownContent -Content $content | Should -BeExactly -ExpectedValue $content
        }

        It -Name 'Does not touch the content of a code block' -Test {
            $content = @('## EXAMPLES', '```', '## SYNTAX', $script:LongLine, '```') -join "`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            $result | Should -Match -RegularExpression ([regex]::Escape($script:LongLine))
            ($result -split "`n")[3] | Should -BeExactly -ExpectedValue $script:LongLine
        }

        It -Name 'Does not rewrite the content of a tilde fence' -Test {
            $content = @('## DESCRIPTION', '~~~markdown', '## EXAMPLES', '```', 'Get-Thing', '```', $script:LongLine, '~~~', '## SYNTAX', '```', 'Get-Thing', '```') -join "`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            $lines = $result -split "`n"
            $lines[3] | Should -BeExactly -ExpectedValue '```'
            $lines[6] | Should -BeExactly -ExpectedValue $script:LongLine
            $lines[9] | Should -BeExactly -ExpectedValue '```powershell'
        }

        It -Name 'Closes a fence only with the same character and at least the same length' -Test {
            $content = @('## EXAMPLES', '````', '```', '## SYNTAX', '````', '```', 'Get-Thing', '```') -join "`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            ($result -split "`n")[2] | Should -BeExactly -ExpectedValue '```'
            ($result -split "`n")[5] | Should -BeExactly -ExpectedValue '```powershell'
        }

        It -Name 'Wraps the long CommonParameters paragraph outside fences' -Test {
            $result = Format-PlatyPSMarkdownContent -Content "## PARAMETERS`n$($script:LongLine)"
            $lines = $result -split "`n"
            $lines | Should -Contain -ExpectedValue '-InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction,'
            $lines | Should -Contain -ExpectedValue 'and -WarningVariable. For more information, see about_CommonParameters.'
        }

        It -Name 'Leaves a short CommonParameters paragraph unchanged' -Test {
            $short = 'This cmdlet supports the common parameters: -Verbose.'
            Format-PlatyPSMarkdownContent -Content $short | Should -BeExactly -ExpectedValue $short
        }

        It -Name 'Preserves CRLF line endings' -Test {
            $content = @('## SYNTAX', '```', 'Get-Thing', '```') -join "`r`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            $result | Should -Match -RegularExpression '```powershell\r\n'
            $result | Should -Not -Match -RegularExpression '(?<!\r)\n'
        }

        It -Name 'Is idempotent' -Test {
            $content = @('## SYNTAX', '```', 'Get-Thing', '```', $script:LongLine) -join "`n"
            $once = Format-PlatyPSMarkdownContent -Content $content
            Format-PlatyPSMarkdownContent -Content $once | Should -BeExactly -ExpectedValue $once
        }

        It -Name 'Accepts an empty document' -Test {
            Format-PlatyPSMarkdownContent -Content '' | Should -BeExactly -ExpectedValue ''
        }
    }

    Context -Name 'Invoke-PlatyPSMarkdownFormat' -Fixture {
        BeforeEach -Scriptblock {
            $script:Dir = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $script:Dir | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'Get-Thing.md') -Value $script:BareDocument -NoNewline
            Set-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'Clean.md') -Value '# Clean' -NoNewline
            Set-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'ignored.txt') -Value $script:BareDocument -NoNewline
        }

        It -Name 'Rewrites only the Markdown files that need changes and reports them' -Test {
            $changed = Invoke-PlatyPSMarkdownFormat -Path $script:Dir
            $changed | Should -Be -ExpectedValue @('Get-Thing.md')
            Get-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'Get-Thing.md') -Raw | Should -Match -RegularExpression '```powershell'
            Get-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'ignored.txt') -Raw | Should -Not -Match -RegularExpression 'powershell'
            @(Invoke-PlatyPSMarkdownFormat -Path $script:Dir) | Should -BeNullOrEmpty
        }

        It -Name 'Formats a single file path' -Test {
            $file = Join-Path -Path $script:Dir -ChildPath 'Get-Thing.md'
            Invoke-PlatyPSMarkdownFormat -Path $file | Should -Be -ExpectedValue @('Get-Thing.md')
        }

        It -Name 'Throws when the path does not exist' -Test {
            { Invoke-PlatyPSMarkdownFormat -Path (Join-Path -Path $script:Dir -ChildPath 'missing') } | Should -Throw -ExpectedMessage "*does not exist*"
        }
    }

    Context -Name 'Script invocation' -Fixture {
        It -Name 'Requires a path' -Test {
            { & $script:ScriptPath } | Should -Throw -ExpectedMessage '*-Path parameter is required*'
        }

        It -Name 'Reports formatted files' -Test {
            $dir = Join-Path -Path $TestDrive -ChildPath 'run'
            New-Item -ItemType Directory -Path $dir | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $dir -ChildPath 'Get-Thing.md') -Value $script:BareDocument -NoNewline
            @(& $script:ScriptPath -Path $dir) | Should -Be -ExpectedValue @('Formatted Get-Thing.md')
        }
    }
}
