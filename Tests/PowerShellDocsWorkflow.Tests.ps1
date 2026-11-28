Describe -Name 'PowerShell documentation workflow' -Fixture {
    BeforeAll -Scriptblock {
        $script:root = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
        $script:workflow = Get-Content -Path (Join-Path -Path $script:root -ChildPath '.github/workflows/powershell-docs.yml') -Raw
    }

    It -Name 'Keeps generated cmdlet documentation in its own directory' -Test {
        $script:workflow | Should -Match -RegularExpression "\`$docsPath = 'docs/cmdlets'"
        $script:workflow | Should -Not -Match -RegularExpression "\`$docsPath = 'docs'"
    }

    It -Name 'Does not move hand-written documents out of the way during generation' -Test {
        $script:workflow | Should -Not -Match -RegularExpression 'docs_backup'
        $script:workflow | Should -Not -Match -RegularExpression 'Move-Item'
    }

    It -Name 'Delegates Markdown formatting to the tested script' -Test {
        $script:workflow | Should -Match -RegularExpression '& \./scripts/Format-PlatyPSMarkdown\.ps1 -Path \$docsPath'
        $script:workflow | Should -Not -Match -RegularExpression 'StartsWith\(.```'
    }

    It -Name 'Lints and commits only the generated cmdlet documents' -Test {
        $script:workflow | Should -Match -RegularExpression 'markdownlint-cli2 "docs/\*\.md" "docs/cmdlets/\*\.md"'
        $script:workflow | Should -Match -RegularExpression 'git add docs/\*\.md docs/cmdlets/\*\.md'
    }

    It -Name 'Keeps only generated documents in docs/cmdlets' -Test {
        $generated = Get-ChildItem -Path (Join-Path -Path $script:root -ChildPath 'docs/cmdlets') -Filter '*.md'
        $generated | Should -Not -BeNullOrEmpty
        foreach ($file in $generated) {
            $file.BaseName | Should -Match -RegularExpression '^(about_BridgeWatcher|[A-Z][a-z]+-Bridge[A-Za-z]+)$'
        }
    }
}
