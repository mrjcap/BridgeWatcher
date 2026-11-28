Describe -Name 'Release Automation and Unreleased Changelog Rollup' -Fixture {
    BeforeAll -Scriptblock {
        $script:repoRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
        $script:promoteScript = Join-Path -Path $script:repoRoot -ChildPath 'scripts/Promote-UnreleasedChangelog.ps1'
        $script:releaseNotesScript = Join-Path -Path $script:repoRoot -ChildPath 'scripts/Get-ReleaseNotes.ps1'
        $script:prepareWorkflow = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/prepare-release.yml') -Raw
        $script:releaseWorkflow = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/release.yml') -Raw
        $script:publishWorkflow = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath '.github/workflows/publish.yml') -Raw
        $script:repoChangelog = Get-Content -LiteralPath (Join-Path -Path $script:repoRoot -ChildPath 'CHANGELOG.md') -Raw
    }

    Context -Name 'Promote-UnreleasedChangelog.ps1' -Fixture {
        It -Name 'Promotes populated subsections, drops empty headings, and resets the Greek Unreleased template' -Test {
            $changelogPath = Join-Path -Path $TestDrive -ChildPath 'CHANGELOG.md'
            $initial = @(
                '# Αρχείο Αλλαγών (Changelog)'
                ''
                '## [Unreleased]'
                ''
                '### ✨ Χαρακτηριστικά'
                ''
                '- Προσθήκη νέας επιλογής με περιγραφή'
                '  σε δεύτερη γραμμή.'
                ''
                '### 🐛 Διορθώσεις'
                ''
                '### 🔒 Ασφάλεια'
                ''
                '- Ενίσχυση ελέγχου διαδρομής.'
                ''
                '### 🔄 Αλλαγές'
                ''
                '## [1.0.102] - 2026-11-28'
                ''
                '### 🐛 Διορθώσεις'
                ''
                '- Προηγούμενη διόρθωση.'
                ''
            ) -join "`n"
            [System.IO.File]::WriteAllText($changelogPath, $initial, [System.Text.UTF8Encoding]::new($true))

            $result = & $script:promoteScript -Version '1.0.103' -ChangelogPath $changelogPath -Date '2026-12-01'

            $result.Updated | Should -BeTrue
            $result.AlreadyPresent | Should -BeFalse
            $result.Version | Should -Be -ExpectedValue '1.0.103'
            $result.BulletCount | Should -Be -ExpectedValue 2

            $bytes = [System.IO.File]::ReadAllBytes($changelogPath)
            $bytes[0] | Should -Be -ExpectedValue 0xEF
            $bytes[1] | Should -Be -ExpectedValue 0xBB
            $bytes[2] | Should -Be -ExpectedValue 0xBF

            $updated = [System.IO.File]::ReadAllText($changelogPath)
            $updated | Should -Not -Match -RegularExpression "`r"
            $updated | Should -Match -RegularExpression '(?s)## \[Unreleased\]\n\n### ✨ Χαρακτηριστικά\n\n### 🐛 Διορθώσεις\n\n### 🔒 Ασφάλεια\n\n### 🔄 Αλλαγές\n\n## \[1\.0\.103\] - 2026-12-01'

            $notes = & $script:releaseNotesScript -Version 'v1.0.103' -Path $changelogPath -IncludeCompareLink -WarningAction Stop
            $notes | Should -Match -RegularExpression '### ✨ Χαρακτηριστικά'
            $notes | Should -Match -RegularExpression 'σε δεύτερη γραμμή\.'
            $notes | Should -Match -RegularExpression '### 🔒 Ασφάλεια'
            $notes | Should -Not -Match -RegularExpression '### 🐛 Διορθώσεις'
            $notes | Should -Not -Match -RegularExpression '### 🔄 Αλλαγές'
            $notes | Should -Match -RegularExpression '\*\*Πλήρες Αρχείο Αλλαγών\*\*: https://github\.com/mrjcap/BridgeWatcher/compare/v1\.0\.102\.\.\.v1\.0\.103'
        }

        It -Name 'Throws when Unreleased has no bullet items and AllowEmpty is not set' -Test {
            $changelogPath = Join-Path -Path $TestDrive -ChildPath 'CHANGELOG-empty.md'
            $initial = @(
                '# Αρχείο Αλλαγών (Changelog)'
                ''
                '## [Unreleased]'
                ''
                '### ✨ Χαρακτηριστικά'
                ''
                '### 🐛 Διορθώσεις'
                ''
                '## [1.0.102] - 2026-11-28'
                ''
                '### 🐛 Διορθώσεις'
                ''
                '- Προηγούμενη διόρθωση.'
                ''
            ) -join "`n"
            [System.IO.File]::WriteAllText($changelogPath, $initial, [System.Text.UTF8Encoding]::new($true))

            { & $script:promoteScript -Version '1.0.103' -ChangelogPath $changelogPath -Date '2026-12-01' } | Should -Throw -ExpectedMessage '*No unreleased changelog entries found*'
        }

        It -Name 'Skips without modifying CHANGELOG.md when the target version already exists' -Test {
            $changelogPath = Join-Path -Path $TestDrive -ChildPath 'CHANGELOG-existing.md'
            $initial = @(
                '# Αρχείο Αλλαγών (Changelog)'
                ''
                '## [Unreleased]'
                ''
                '## [1.0.103] - 2026-12-01'
                ''
                '### 🐛 Διορθώσεις'
                ''
                '- Υπάρχουσα εγγραφή.'
                ''
            ) -join "`n"
            [System.IO.File]::WriteAllText($changelogPath, $initial, [System.Text.UTF8Encoding]::new($true))

            $result = & $script:promoteScript -Version 'v1.0.103' -ChangelogPath $changelogPath -Date '2026-12-02'

            $result.Updated | Should -BeFalse
            $result.AlreadyPresent | Should -BeTrue
            [System.IO.File]::ReadAllText($changelogPath) | Should -Be -ExpectedValue $initial
        }

        It -Name 'Throws FileNotFoundException when CHANGELOG.md does not exist' -Test {
            $missingPath = Join-Path -Path $TestDrive -ChildPath 'missing-changelog.md'
            { & $script:promoteScript -Version '1.0.103' -ChangelogPath $missingPath } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
        }
    }

    Context -Name 'Get-ReleaseNotes.ps1' -Fixture {
        It -Name 'Extracts release notes without a compare link by default and appends the Greek compare link when requested' -Test {
            $changelogPath = Join-Path -Path $TestDrive -ChildPath 'CHANGELOG-notes.md'
            $content = @(
                '# Αρχείο Αλλαγών (Changelog)'
                ''
                '## [1.0.103] - 2026-12-01'
                ''
                '### Διορθώθηκαν'
                ''
                '- Διόρθωση απόκρισης OCR.'
                ''
                '## [1.0.102] - 2026-11-28'
                ''
                '### 🐛 Διορθώσεις'
                ''
                '- Προηγούμενη έκδοση.'
                ''
            ) -join "`n"
            [System.IO.File]::WriteAllText($changelogPath, $content, [System.Text.UTF8Encoding]::new($true))

            $plain = & $script:releaseNotesScript -Version 'v1.0.103' -Path $changelogPath -WarningAction Stop
            $plain | Should -Match -RegularExpression '### 🐛 Διορθώθηκαν'
            $plain | Should -Not -Match -RegularExpression 'Πλήρες Αρχείο Αλλαγών'

            $withLink = & $script:releaseNotesScript -Version 'v1.0.103' -Path $changelogPath -IncludeCompareLink -WarningAction Stop
            $withLink | Should -Match -RegularExpression '\*\*Πλήρες Αρχείο Αλλαγών\*\*: https://github\.com/mrjcap/BridgeWatcher/compare/v1\.0\.102\.\.\.v1\.0\.103'

            $customLink = & $script:releaseNotesScript -Version '1.0.103' -Path $changelogPath -IncludeCompareLink -PreviousVersion 'v1.0.100' -RepositoryUrl 'https://github.com/example/repo/' -WarningAction Stop
            $customLink | Should -Match -RegularExpression '\*\*Πλήρες Αρχείο Αλλαγών\*\*: https://github\.com/example/repo/compare/v1\.0\.100\.\.\.v1\.0\.103'
        }
        It -Name 'Does not append a compare link to a version section that has no release note body' -Test {
            $changelogPath = Join-Path -Path $TestDrive -ChildPath 'CHANGELOG-empty-version.md'
            $content = @(
                '# Αρχείο Αλλαγών (Changelog)'
                ''
                '## [1.0.103] - 2026-12-01'
                ''
                '## [1.0.102] - 2026-11-28'
                ''
                '### 🐛 Διορθώσεις'
                ''
                '- Προηγούμενη έκδοση.'
                ''
            ) -join "`n"
            [System.IO.File]::WriteAllText($changelogPath, $content, [System.Text.UTF8Encoding]::new($true))

            $notes = & $script:releaseNotesScript -Version 'v1.0.103' -Path $changelogPath -IncludeCompareLink -WarningAction Stop
            $notes | Should -Be -ExpectedValue '## [1.0.103] - 2026-12-01'
        }
    }

    Context -Name 'Repository CHANGELOG.md and two-stage release workflows' -Fixture {
        It -Name 'Keeps an Unreleased section at the top of CHANGELOG.md' -Test {
            $script:repoChangelog | Should -Match -RegularExpression '(?m)^## \[Unreleased\]$'
            $unreleasedIdx = $script:repoChangelog.IndexOf('## [Unreleased]')
            $firstReleaseIdx = $script:repoChangelog.IndexOf('## [1.0.102]')
            $unreleasedIdx | Should -BeGreaterThan -ExpectedValue -1
            $firstReleaseIdx | Should -BeGreaterThan -ExpectedValue $unreleasedIdx
        }

        It -Name 'Configures prepare-release.yml to promote Unreleased, bump manifest, regenerate docs, and open a PR with RELEASE_TOKEN' -Test {
            $script:prepareWorkflow | Should -Match -RegularExpression 'git tag --list "v\$next"'
            $script:prepareWorkflow | Should -Match -RegularExpression 'Promote-UnreleasedChangelog\.ps1'
            $script:prepareWorkflow | Should -Match -RegularExpression 'Update-ModuleVersion\.ps1'
            $script:prepareWorkflow | Should -Match -RegularExpression 'Format-PlatyPSMarkdown\.ps1'
            $script:prepareWorkflow | Should -Match -RegularExpression 'Get-ReleaseNotes\.ps1[^\r\n]*-IncludeCompareLink'
            $script:prepareWorkflow | Should -Match -RegularExpression 'secrets\.RELEASE_TOKEN\s*\|\|\s*secrets\.GITHUB_TOKEN'
            $script:prepareWorkflow | Should -Match -RegularExpression 'gh pr create --base main --head "\$RELEASE_BRANCH"'
            $script:prepareWorkflow | Should -Not -Match -RegularExpression 'git push[^\r\n]*\bmain\b'
        }

        It -Name 'Triggers release.yml automatically on main pushes to BridgeWatcher.psd1 without breaking workflow_dispatch' -Test {
            $script:releaseWorkflow | Should -Match -RegularExpression "(?s)push:\s+branches:\s*\[main\]\s+paths:\s+-\s*'BridgeWatcher/BridgeWatcher\.psd1'"
            $script:releaseWorkflow | Should -Match -RegularExpression 'workflow_dispatch:'
            $script:releaseWorkflow | Should -Match -RegularExpression 'dry_run:\s*\$\{\{\s*inputs\.dry_run == true\s*\}\}'
        }

        It -Name 'Publishes Greek-only GitHub Release notes without auto-appended English PR lists and pins release target_commitish' -Test {
            $script:publishWorkflow | Should -Match -RegularExpression '(?s)Get-ReleaseNotes\.ps1.{0,200}-IncludeCompareLink'
            $script:publishWorkflow | Should -Match -RegularExpression 'generate_release_notes:\s*false'
            $script:publishWorkflow | Should -Match -RegularExpression 'git fetch origin "\$REF_NAME"'
            $script:publishWorkflow | Should -Match -RegularExpression 'target_commitish:\s*\$\{\{\s*steps\.push_changes\.outputs\.commit_sha\s*\}\}'
        }
    }
}
