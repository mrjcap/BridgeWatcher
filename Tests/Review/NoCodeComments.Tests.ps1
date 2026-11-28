BeforeAll -Scriptblock {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '../..')).Path
    $script:LinterScript = Join-Path -Path $script:RepoRoot -ChildPath 'scripts/Test-NoCodeComments.ps1'
    $script:CustomRulePath = Join-Path -Path $script:RepoRoot -ChildPath 'scripts/NoCodeCommentsRule.psm1'
    $script:RatchetPath = Join-Path -Path $script:RepoRoot -ChildPath '.comment-ratchet.json'
    . $script:LinterScript
}

Describe -Name 'Code Comment Ban and Ratchet Review' -Fixture {
    Context -Name 'Repository compliance' -Fixture {
        It -Name 'Satisfies the .comment-ratchet.json baseline across all audited files' -Test {
            $result = & $script:LinterScript -RepositoryRoot $script:RepoRoot -RatchetPath $script:RatchetPath -PassThru
            $result.Violations | Should -BeNullOrEmpty
            $result.Passed | Should -BeTrue
        }

        It -Name 'Has zero Measure-NoCodeComment PSScriptAnalyzer findings across all PowerShell files' -Test {
            if (-not (Get-Module -Name PSScriptAnalyzer)) {
                Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
            }

            $targets = @(
                (Join-Path -Path $script:RepoRoot -ChildPath 'BridgeWatcher'),
                (Join-Path -Path $script:RepoRoot -ChildPath 'Tests'),
                (Join-Path -Path $script:RepoRoot -ChildPath 'scripts'),
                (Join-Path -Path $script:RepoRoot -ChildPath 'run.ps1'),
                (Join-Path -Path $script:RepoRoot -ChildPath 'gate.ps1')
            )

            $findings = @(foreach ($target in $targets) {
                Invoke-ScriptAnalyzer -Path $target -Recurse -CustomRulePath $script:CustomRulePath -IncludeRule Measure-NoCodeComment -ErrorAction Stop
            })

            $findings | Should -BeNullOrEmpty
        }
    }

    Context -Name 'Verification of the comment-ban rule and ratchet mechanics' -Fixture {
        It -Name 'Flags ordinary single-line, inline, and block code comments in PowerShell' -Test {
            $sample = @(
                '# leading comment',
                '$value = 1 # inline comment',
                '<# block comment #>',
                'Write-Output $value'
            ) -join "`n"

            $findings = @(Get-PowerShellCommentFindingsFromContent -Content $sample -RelativePath 'sample.ps1')
            $findings.Count | Should -Be -ExpectedValue 3

            $pssaFindings = @(Invoke-ScriptAnalyzer -ScriptDefinition $sample -CustomRulePath $script:CustomRulePath -IncludeRule Measure-NoCodeComment)
            $pssaFindings.Count | Should -Be -ExpectedValue 3
        }

        It -Name 'Exempts comment-based help, gitleaks pragmas, #Requires, and hash characters inside strings' -Test {
            $sample = @(
                '#Requires -Version 7.0',
                '<#',
                '.SYNOPSIS',
                'Example helper function.',
                '#>',
                'function Get-Sample {',
                '    $token = "not-a-secret" # gitleaks:allow',
                '    $url = "https://example.com/#fragment"',
                '    $text = "# not a comment inside string"',
                '    return "$token $url $text"',
                '}'
            ) -join "`n"

            $findings = @(Get-PowerShellCommentFindingsFromContent -Content $sample -RelativePath 'exempt.ps1')
            $findings | Should -BeNullOrEmpty

            $pssaFindings = @(Invoke-ScriptAnalyzer -ScriptDefinition $sample -CustomRulePath $script:CustomRulePath -IncludeRule Measure-NoCodeComment)
            $pssaFindings | Should -BeNullOrEmpty
        }

        It -Name 'Exempts shebangs, renovate/hadolint/semgrep directives, and SHA-pinned action version comments in non-PowerShell files' -Test {
            $sample = @(
                '#!/usr/bin/env bash',
                '# renovate: datasource=github-releases depName=PowerShell/PowerShell',
                '# hadolint ignore=DL3018',
                '# nosemgrep: yaml.github-actions.security.curl-eval.curl-eval',
                '# semgrep:ignore yaml.github-actions.security.curl-eval.curl-eval',
                '      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1',
                '      # actual comment to flag'
            ) -join "`n"

            $findings = @(Get-HashLineCommentFindingsFromContent -Content $sample -RelativePath '.github/workflows/sample.yml')
            $findings.Count | Should -Be -ExpectedValue 1
            $findings[0].Line | Should -Be -ExpectedValue 7
        }

        It -Name 'Fails when a file exceeds its ratchet cap or introduces a comment in an unlisted file' -Test {
            $inventory = [PSCustomObject]@{
                ScannedFileCount = 2
                TotalComments    = 3
                CountsByFile     = [ordered]@{
                    'a.ps1' = 2
                    'b.ps1' = 1
                }
                Findings         = @(
                    [PSCustomObject]@{ File = 'a.ps1'; Line = 1; Text = '# one' },
                    [PSCustomObject]@{ File = 'a.ps1'; Line = 2; Text = '# two' },
                    [PSCustomObject]@{ File = 'b.ps1'; Line = 5; Text = '# new' }
                )
            }
            $ratchet = [PSCustomObject]@{
                version = 1
                total   = 1
                files   = [PSCustomObject]@{ 'a.ps1' = 1 }
            }

            $eval = Invoke-CommentRatchetEvaluation -Inventory $inventory -Ratchet $ratchet
            $eval.Passed | Should -BeFalse
            ($eval.Violations -join "`n") | Should -Match -RegularExpression 'a\.ps1: found 2 comment\(s\), exceeds ratchet cap of 1'
            ($eval.Violations -join "`n") | Should -Match -RegularExpression 'b\.ps1: found 1 comment\(s\), exceeds ratchet cap of 0'
        }

        It -Name 'Fails when comments are removed without tightening the ratchet, and allows lowering via Update-CommentRatchetFile' -Test {
            $tmpRatchet = Join-Path -Path $TestDrive -ChildPath '.comment-ratchet.json'
            @{
                version = 1
                total   = 2
                files   = @{ 'legacy.ps1' = 2 }
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $tmpRatchet -Encoding utf8

            $reducedInventory = [PSCustomObject]@{
                ScannedFileCount = 1
                TotalComments    = 1
                CountsByFile     = [ordered]@{ 'legacy.ps1' = 1 }
                Findings         = @([PSCustomObject]@{ File = 'legacy.ps1'; Line = 3; Text = '# remaining' })
            }

            $ratchetObj = Get-Content -LiteralPath $tmpRatchet -Raw | ConvertFrom-Json
            $eval = Invoke-CommentRatchetEvaluation -Inventory $reducedInventory -Ratchet $ratchetObj
            $eval.Passed | Should -BeFalse
            ($eval.Violations -join "`n") | Should -Match -RegularExpression 'dropped from 2 to 1'

            $updated = Update-CommentRatchetFile -RatchetFilePath $tmpRatchet -Inventory $reducedInventory
            $updated.total | Should -Be -ExpectedValue 1
            $updated.files['legacy.ps1'] | Should -Be -ExpectedValue 1

            $reloaded = Get-Content -LiteralPath $tmpRatchet -Raw | ConvertFrom-Json
            $reEval = Invoke-CommentRatchetEvaluation -Inventory $reducedInventory -Ratchet $reloaded
            $reEval.Passed | Should -BeTrue
        }

        It -Name 'Refuses to raise the ratchet when comment counts increase' -Test {
            $tmpRatchet = Join-Path -Path $TestDrive -ChildPath '.comment-ratchet-up.json'
            @{
                version = 1
                total   = 1
                files   = @{ 'legacy.ps1' = 1 }
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $tmpRatchet -Encoding utf8

            $increasedInventory = [PSCustomObject]@{
                ScannedFileCount = 1
                TotalComments    = 2
                CountsByFile     = [ordered]@{ 'legacy.ps1' = 2 }
                Findings         = @(
                    [PSCustomObject]@{ File = 'legacy.ps1'; Line = 1; Text = '# old' },
                    [PSCustomObject]@{ File = 'legacy.ps1'; Line = 2; Text = '# added' }
                )
            }

            { Update-CommentRatchetFile -RatchetFilePath $tmpRatchet -Inventory $increasedInventory } | Should -Throw -ExpectedMessage '*Refusing to raise comment ratchet*'
        }
    }

    Context -Name 'Markup, ignore-file, and discovery coverage' -Fixture {
        It -Name 'Flags HTML, CSS, and JavaScript comments but not URLs or exempt syntax' -Test {
            $sample = @(
                '<!-- section label -->',
                '<a href="https://example.com/x">link</a>',
                '<style>',
                '  /* block */',
                '  .a { color: red; /* trailing */ }',
                '  /* multi',
                '     line */',
                '</style>',
                '<script>',
                '  // line comment',
                '  const url = "https://example.com";',
                '</script>'
            ) -join "`n"

            $findings = @(Get-MarkupCommentFindingsFromContent -Content $sample -RelativePath 'page.html')
            ($findings.Line -join ',') | Should -Be -ExpectedValue '1,4,5,6,7,10'
        }

        It -Name 'Does not treat comment openers inside JavaScript string literals as comments' -Test {
            $sample = @(
                'const marker = "/*";',
                "const other = '//';",
                'const tpl = `a // b /* c`;',
                'const escaped = "quote \" // still string";',
                'const url = "https://example.com";'
            ) -join "`n"

            @(Get-MarkupCommentFindingsFromContent -Content $sample -RelativePath 'app.js') | Should -BeNullOrEmpty
        }

        It -Name 'Detects compact trailing JavaScript comments and real block comments after string literals' -Test {
            $sample = @(
                'const n = 1;//note',
                'const marker = "/*"; /* real */',
                'const keep = 2;'
            ) -join "`n"

            $findings = @(Get-MarkupCommentFindingsFromContent -Content $sample -RelativePath 'app.js')
            ($findings.Line -join ',') | Should -Be -ExpectedValue '1,2'
        }

        It -Name 'Keeps standalone JavaScript and CSS in their own mode when a closing tag appears in text' -Test {
            $js = @('const marker = `</script>`;', 'const n = 1; // banned') -join "`n"
            $jsFindings = @(Get-MarkupCommentFindingsFromContent -Content $js -RelativePath 'app.js')
            ($jsFindings.Line -join ',') | Should -Be -ExpectedValue '2'

            $css = @('a::before { content: "</style>"; }', '/* banned */') -join "`n"
            $cssFindings = @(Get-MarkupCommentFindingsFromContent -Content $css -RelativePath 'site.css')
            ($cssFindings.Line -join ',') | Should -Be -ExpectedValue '2'
        }

        It -Name 'Still leaves an embedded script element when a template ends inside it' -Test {
            $html = @('<script>const a = `x`;</script>', '<p>// text</p>', '<!-- real -->') -join "`n"
            $findings = @(Get-MarkupCommentFindingsFromContent -Content $html -RelativePath 'page.html')
            ($findings.Line -join ',') | Should -Be -ExpectedValue '3'
        }

        It -Name 'Scans template substitutions for comments but ignores comment markers in template text' -Test {
            $sample = @(
                'const a = `${1 /* note */}`;',
                'const b = `x /* y */ // z`;',
                'const c = `${1}//still text`;',
                'const d = `${2}`; //real'
            ) -join "`n"

            $findings = @(Get-MarkupCommentFindingsFromContent -Content $sample -RelativePath 'app.js')
            ($findings.Line -join ',') | Should -Be -ExpectedValue '1,4'
        }

        It -Name 'Handles nested templates and object literals inside substitutions' -Test {
            $sample = @(
                'const a = `${ {k: 1}.k }//text`;',
                'const b = `${ `inner ${ 2 /* c */ } //x` }//text`;',
                'const c = `plain`;',
                '}',
                'const d = 3; // real'
            ) -join "`n"

            $findings = @(Get-MarkupCommentFindingsFromContent -Content $sample -RelativePath 'app.js')
            ($findings.Line -join ',') | Should -Be -ExpectedValue '2,5'
        }

        It -Name 'Does not treat comment openers inside CSS strings or HTML text as comments' -Test {
            $css = @('a::before { content: "/*"; }', 'b::after { content: ''//''; }') -join "`n"
            @(Get-MarkupCommentFindingsFromContent -Content $css -RelativePath 'site.css') | Should -BeNullOrEmpty

            $html = @('<p>glob /* and // are plain text here</p>', '<script>const a = 1;</script>') -join "`n"
            @(Get-MarkupCommentFindingsFromContent -Content $html -RelativePath 'page.html') | Should -BeNullOrEmpty
        }

        It -Name 'Returns to markup mode after a script or style element ends' -Test {
            $sample = @(
                '<script src="a.js"></script>',
                '<p>// not a comment</p>',
                '<style>a { }</style>',
                '<p>/* not a comment */</p>',
                '<!-- real -->'
            ) -join "`n"

            $findings = @(Get-MarkupCommentFindingsFromContent -Content $sample -RelativePath 'page.html')
            ($findings.Line -join ',') | Should -Be -ExpectedValue '5'
        }

        It -Name 'Reports an unterminated block comment through the end of the file' -Test {
            $sample = @('a { }', '/* never closed', 'b { }') -join "`n"
            $findings = @(Get-MarkupCommentFindingsFromContent -Content $sample -RelativePath 'site.css')
            ($findings.Line -join ',') | Should -Be -ExpectedValue '2,3'
        }

        It -Name 'Does not treat double slashes in CSS or XML files as comments' -Test {
            $css = 'a { background: url(//cdn.example.com/x.png); }'
            @(Get-MarkupCommentFindingsFromContent -Content $css -RelativePath 'site.css') | Should -BeNullOrEmpty

            $xml = '<Configuration><!-- note --></Configuration>'
            @(Get-MarkupCommentFindingsFromContent -Content $xml -RelativePath 'view.ps1xml').Count | Should -Be -ExpectedValue 1
        }

        It -Name 'Maps file names to comment syntax families and skips unsupported types' -Test {
            Get-RepoCommentFileKind -RelativePath 'a/b.ps1' | Should -Be -ExpectedValue 'PowerShell'
            Get-RepoCommentFileKind -RelativePath '.github/workflows/ci.yml' | Should -Be -ExpectedValue 'HashLine'
            Get-RepoCommentFileKind -RelativePath '.gitignore' | Should -Be -ExpectedValue 'HashLine'
            Get-RepoCommentFileKind -RelativePath '.semgrepignore' | Should -Be -ExpectedValue 'HashLine'
            Get-RepoCommentFileKind -RelativePath '.gitleaksignore' | Should -Be -ExpectedValue 'HashLine'
            Get-RepoCommentFileKind -RelativePath 'Docker/Dockerfile' | Should -Be -ExpectedValue 'HashLine'
            Get-RepoCommentFileKind -RelativePath '.githooks/pre-commit' | Should -Be -ExpectedValue 'HashLine'
            Get-RepoCommentFileKind -RelativePath '.githooks/Invoke-StagedScriptAnalyzer.ps1' | Should -Be -ExpectedValue 'PowerShell'
            Get-RepoCommentFileKind -RelativePath 'docs/compliance_dashboard.html' | Should -Be -ExpectedValue 'Markup'
            Get-RepoCommentFileKind -RelativePath 'BridgeWatcher/Formats/BridgeStatus.format.ps1xml' | Should -Be -ExpectedValue 'Markup'
            Get-RepoCommentFileKind -RelativePath 'README.md' | Should -BeNullOrEmpty
            Get-RepoCommentFileKind -RelativePath 'renovate.json' | Should -BeNullOrEmpty
        }

        It -Name 'Discovers files without git and reports ignore-file and HTML comments in the inventory' -Test {
            $root = Join-Path -Path $TestDrive -ChildPath 'discovery'
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $root -ChildPath 'docs') -Force
            Set-Content -LiteralPath (Join-Path -Path $root -ChildPath '.gitignore') -Value @('# header', 'bin/')
            Set-Content -LiteralPath (Join-Path -Path $root -ChildPath 'docs/page.html') -Value '<!-- label --><p>x</p>'
            Set-Content -LiteralPath (Join-Path -Path $root -ChildPath 'notes.md') -Value '# heading'

            $inventory = Get-RepoCommentInventory -Root $root
            $inventory.TotalComments | Should -Be -ExpectedValue 2
            $inventory.ScannedFileCount | Should -Be -ExpectedValue 2
            $inventory.CountsByFile['.gitignore'] | Should -Be -ExpectedValue 1
            $inventory.CountsByFile['docs/page.html'] | Should -Be -ExpectedValue 1
        }
    }
}
