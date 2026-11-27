Describe 'Release download integrity checks' {
    BeforeAll {
        $script:root = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
        $script:dockerfile = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'Docker/Dockerfile') -Raw
        $script:ci = Get-Content -Path (Join-Path -Path $script:root -ChildPath '.github/workflows/ci.yml') -Raw
        $script:renovate = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'renovate.json') -Raw | ConvertFrom-Json
    }

    Context 'PowerShell in the Docker image' {
        It 'Has no hand-maintained digest next to the version' {
            $script:dockerfile | Should -Not -Match 'ARG\s+POWERSHELL_SHA256'
        }

        It 'Verifies the tarball against the release hashes.sha256 and aborts when no digest is found' {
            $script:dockerfile | Should -Match 'releases/download/v\$\{POWERSHELL_VERSION\}'
            $script:dockerfile | Should -Match 'hashes\.sha256'
            $script:dockerfile | Should -Match 'test -n "\$\{POWERSHELL_SHA256\}"'
            $script:dockerfile | Should -Match 'sha256sum\s+-c\s+-'
        }

        It 'Decodes the UTF-16 checksum file published with PowerShell releases' {
            $script:dockerfile | Should -Match 'iconv -f UTF-16 -t UTF-8'
        }

        It 'Keeps the Renovate directive that tracks POWERSHELL_VERSION' {
            $script:dockerfile | Should -Match '# renovate: datasource=github-releases depName=PowerShell/PowerShell\r?\nARG POWERSHELL_VERSION='
        }
    }

    Context 'Codacy coverage reporter in CI' {
        It 'Has no hand-maintained digest next to the version' {
            $script:ci | Should -Not -Match 'CODACY_REPORTER_SHA256'
        }

        It 'Verifies the binary against the SHA512SUM published with the release' {
            $script:ci | Should -Match 'codacy-coverage-reporter-linux\.SHA512SUM'
            $script:ci | Should -Match 'sha512sum -c -'
            $script:ci | Should -Match 'verify_reporter\s*\r?\n\s+fi'
        }

        It 'Lets Renovate bump CODACY_REPORTER_VERSION' {
            $manager = $script:renovate.customManagers | Where-Object { $_.matchStrings -match 'CODACY_REPORTER_VERSION' }
            $manager | Should -Not -BeNullOrEmpty
            $sample = "  # renovate: datasource=github-releases depName=codacy/codacy-coverage-reporter`n  CODACY_REPORTER_VERSION: '14.1.3'"
            $sample | Should -Match $manager.matchStrings[0]
        }
    }
}
