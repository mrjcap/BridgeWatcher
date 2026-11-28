Describe -Name 'Release download integrity checks' -Fixture {
    BeforeAll -Scriptblock {
        $script:root = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
        $script:dockerfile = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'Docker/Dockerfile') -Raw
        $script:ci = Get-Content -Path (Join-Path -Path $script:root -ChildPath '.github/workflows/ci.yml') -Raw
        $script:renovate = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'renovate.json') -Raw | ConvertFrom-Json
    }

    Context -Name 'PowerShell in the Docker image' -Fixture {
        It -Name 'Has no hand-maintained digest next to the version' -Test {
            $script:dockerfile | Should -Not -Match -RegularExpression 'ARG\s+POWERSHELL_SHA256'
        }

        It -Name 'Verifies the tarball against the release hashes.sha256 and aborts when no digest is found' -Test {
            $script:dockerfile | Should -Match -RegularExpression 'releases/download/v\$\{POWERSHELL_VERSION\}'
            $script:dockerfile | Should -Match -RegularExpression 'hashes\.sha256'
            $script:dockerfile | Should -Match -RegularExpression 'test -n "\$\{POWERSHELL_SHA256\}"'
            $script:dockerfile | Should -Match -RegularExpression 'sha256sum\s+-c\s+-'
        }

        It -Name 'Decodes the UTF-16 checksum file published with PowerShell releases' -Test {
            $script:dockerfile | Should -Match -RegularExpression 'iconv -f UTF-16 -t UTF-8'
        }

        It -Name 'Keeps the Renovate directive that tracks POWERSHELL_VERSION' -Test {
            $script:dockerfile | Should -Match -RegularExpression '# renovate: datasource=github-releases depName=PowerShell/PowerShell\r?\nARG POWERSHELL_VERSION='
        }
    }

    Context -Name 'Codacy coverage reporter in CI' -Fixture {
        It -Name 'Has no hand-maintained digest next to the version' -Test {
            $script:ci | Should -Not -Match -RegularExpression 'CODACY_REPORTER_SHA256'
        }

        It -Name 'Verifies the binary against the SHA512SUM published with the release' -Test {
            $script:ci | Should -Match -RegularExpression 'codacy-coverage-reporter-linux\.SHA512SUM'
            $script:ci | Should -Match -RegularExpression 'sha512sum -c -'
            $script:ci | Should -Match -RegularExpression 'verify_reporter\s*\r?\n\s+fi'
        }

        It -Name 'Lets Renovate bump CODACY_REPORTER_VERSION' -Test {
            $manager = $script:renovate.customManagers | Where-Object -FilterScript { $_.matchStrings -match 'CODACY_REPORTER_VERSION' }
            $manager | Should -Not -BeNullOrEmpty
            $sample = "  # renovate: datasource=github-releases depName=codacy/codacy-coverage-reporter`n  CODACY_REPORTER_VERSION: '14.1.3'"
            $sample | Should -Match -RegularExpression $manager.matchStrings[0]
        }
    }
}
