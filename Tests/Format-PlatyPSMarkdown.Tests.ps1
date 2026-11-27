BeforeAll {
    $script:ScriptPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Format-PlatyPSMarkdown.ps1'))
    . $script:ScriptPath
    $script:BareDocument = "## SYNTAX`n" + '```' + "`n" + '```'
    $script:LongLine = 'This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, ' +
    '-InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. ' +
    'For more information, see about_CommonParameters.'
}

Describe 'Format-PlatyPSMarkdown' {
    Context 'Format-PlatyPSMarkdownContent' {
        It 'Tags bare fences in the SYNTAX and EXAMPLES sections as PowerShell' {
            $content = @('## SYNTAX', '', '```', 'Get-Thing', '```', '', '## EXAMPLES', '', '```', 'Get-Thing -Id 1', '```') -join "`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            ($result -split "`n" | Where-Object { $_ -eq '```powershell' }).Count | Should -Be 2
            ($result -split "`n" | Where-Object { $_ -eq '```' }).Count | Should -Be 2
        }

        It 'Leaves bare fences in other sections and already tagged fences alone' {
            $content = @('## DESCRIPTION', '```', 'text', '```', '## EXAMPLES', '```powershell', 'Get-Thing', '```') -join "`n"
            Format-PlatyPSMarkdownContent -Content $content | Should -BeExactly $content
        }

        It 'Does not touch the content of a code block' {
            $content = @('## EXAMPLES', '```', '## SYNTAX', $script:LongLine, '```') -join "`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            $result | Should -Match ([regex]::Escape($script:LongLine))
            ($result -split "`n")[3] | Should -BeExactly $script:LongLine
        }

        It 'Wraps the long CommonParameters paragraph outside fences' {
            $result = Format-PlatyPSMarkdownContent -Content "## PARAMETERS`n$($script:LongLine)"
            $lines = $result -split "`n"
            $lines | Should -Contain '-InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction,'
            $lines | Should -Contain 'and -WarningVariable. For more information, see about_CommonParameters.'
        }

        It 'Leaves a short CommonParameters paragraph unchanged' {
            $short = 'This cmdlet supports the common parameters: -Verbose.'
            Format-PlatyPSMarkdownContent -Content $short | Should -BeExactly $short
        }

        It 'Preserves CRLF line endings' {
            $content = @('## SYNTAX', '```', 'Get-Thing', '```') -join "`r`n"
            $result = Format-PlatyPSMarkdownContent -Content $content
            $result | Should -Match '```powershell\r\n'
            $result | Should -Not -Match '(?<!\r)\n'
        }

        It 'Is idempotent' {
            $content = @('## SYNTAX', '```', 'Get-Thing', '```', $script:LongLine) -join "`n"
            $once = Format-PlatyPSMarkdownContent -Content $content
            Format-PlatyPSMarkdownContent -Content $once | Should -BeExactly $once
        }

        It 'Accepts an empty document' {
            Format-PlatyPSMarkdownContent -Content '' | Should -BeExactly ''
        }
    }

    Context 'Invoke-PlatyPSMarkdownFormat' {
        BeforeEach {
            $script:Dir = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $script:Dir | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'Get-Thing.md') -Value $script:BareDocument -NoNewline
            Set-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'Clean.md') -Value '# Clean' -NoNewline
            Set-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'ignored.txt') -Value $script:BareDocument -NoNewline
        }

        It 'Rewrites only the Markdown files that need changes and reports them' {
            $changed = Invoke-PlatyPSMarkdownFormat -Path $script:Dir
            $changed | Should -Be @('Get-Thing.md')
            Get-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'Get-Thing.md') -Raw | Should -Match '```powershell'
            Get-Content -LiteralPath (Join-Path -Path $script:Dir -ChildPath 'ignored.txt') -Raw | Should -Not -Match 'powershell'
            @(Invoke-PlatyPSMarkdownFormat -Path $script:Dir) | Should -BeNullOrEmpty
        }

        It 'Formats a single file path' {
            $file = Join-Path -Path $script:Dir -ChildPath 'Get-Thing.md'
            Invoke-PlatyPSMarkdownFormat -Path $file | Should -Be @('Get-Thing.md')
        }

        It 'Throws when the path does not exist' {
            { Invoke-PlatyPSMarkdownFormat -Path (Join-Path -Path $script:Dir -ChildPath 'missing') } | Should -Throw "*does not exist*"
        }
    }

    Context 'Script invocation' {
        It 'Requires a path' {
            { & $script:ScriptPath } | Should -Throw '*-Path parameter is required*'
        }

        It 'Reports formatted files' {
            $dir = Join-Path -Path $TestDrive -ChildPath 'run'
            New-Item -ItemType Directory -Path $dir | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $dir -ChildPath 'Get-Thing.md') -Value $script:BareDocument -NoNewline
            @(& $script:ScriptPath -Path $dir) | Should -Be @('Formatted Get-Thing.md')
        }
    }
}
