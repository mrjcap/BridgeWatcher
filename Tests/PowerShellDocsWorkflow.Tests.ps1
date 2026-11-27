Describe 'PowerShell documentation workflow' {
    BeforeAll {
        $script:root = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
        $script:workflow = Get-Content -Path (Join-Path -Path $script:root -ChildPath '.github/workflows/powershell-docs.yml') -Raw
    }

    It 'Keeps generated cmdlet documentation in its own directory' {
        $script:workflow | Should -Match "\`$docsPath = 'docs/cmdlets'"
        $script:workflow | Should -Not -Match "\`$docsPath = 'docs'"
    }

    It 'Does not move hand-written documents out of the way during generation' {
        $script:workflow | Should -Not -Match 'docs_backup'
        $script:workflow | Should -Not -Match 'Move-Item'
    }

    It 'Delegates Markdown formatting to the tested script' {
        $script:workflow | Should -Match '& \./scripts/Format-PlatyPSMarkdown\.ps1 -Path \$docsPath'
        $script:workflow | Should -Not -Match 'StartsWith\(.```'
    }

    It 'Lints and commits only the generated cmdlet documents' {
        $script:workflow | Should -Match 'markdownlint-cli2 "docs/\*\.md" "docs/cmdlets/\*\.md"'
        $script:workflow | Should -Match 'git add docs/cmdlets/\*\.md'
    }

    It 'Keeps only generated documents in docs/cmdlets' {
        $generated = Get-ChildItem -Path (Join-Path -Path $script:root -ChildPath 'docs/cmdlets') -Filter '*.md'
        $generated | Should -Not -BeNullOrEmpty
        foreach ($file in $generated) {
            $file.BaseName | Should -Match '^(about_BridgeWatcher|[A-Z][a-z]+-Bridge[A-Za-z]+)$'
        }
    }
}
