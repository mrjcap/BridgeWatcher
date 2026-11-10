Describe 'Docker Build Workflow Configuration' {
    BeforeAll {
        $script:workflowPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/docker-build.yml'))
        $script:content = Get-Content -Path $script:workflowPath -Raw
        $script:releasePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/release.yml'))
        $script:releaseContent = Get-Content -Path $script:releasePath -Raw
        $script:publishPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/publish.yml'))
        $script:publishContent = Get-Content -Path $script:publishPath -Raw
        $script:docsPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/powershell-docs.yml'))
        $script:docsContent = Get-Content -Path $script:docsPath -Raw
        $script:entrypointPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../Docker/entrypoint.sh'))
        $script:entrypointContent = Get-Content -Path $script:entrypointPath -Raw
    }

    It 'Requires CI and security-analysis success before gatekeeper commits changelog and resumes untagged releases' {
        $script:releaseContent | Should -Match "needs:\s*\[ci,\s*security-analysis\]"
        $script:releaseContent | Should -Match "if:\s*needs\.ci\.result\s*==\s*'success'\s*&&\s*needs\.security-analysis\.result\s*==\s*'success'"
        $script:releaseContent | Should -Match 'refs/tags/v\$NEXT_VERSION'
    }

    It 'Ελέγχει την ακριβή έκδοση release tag στο build-and-test job' {
        # Check if the file contains ref config under checkout
        $script:content | Should -Match 'ref:\s+v\$\{\{\s*inputs\.version\s*\}\}'
    }

    It 'Sets test-logs permissions before changing ownership to container UID:GID' {
        $script:content | Should -Match 'chmod 750 test-logs\s+sudo chown 99:100 test-logs'
    }

    It 'Cleans up container-owned test-logs directory using sudo' {
        $script:content | Should -Match 'sudo rm -rf test-secrets test-logs'
    }

    It 'Gates non-PR steps using pull_request event checks instead of workflow_call' {
        $script:content | Should -Not -Match "github\.event_name\s*[!=]=\s*'workflow_call'"
        $script:content | Should -Match "github\.event_name\s*!=\s*'pull_request'\s*&&\s*!inputs\.dry_run"
    }

    It 'Supports RELEASE_TOKEN with GITHUB_TOKEN fallback across release workflows' {
        $script:releaseContent | Should -Match 'secrets\.RELEASE_TOKEN\s*\|\|\s*secrets\.GITHUB_TOKEN'
        $script:publishContent | Should -Match 'secrets\.RELEASE_TOKEN\s*\|\|\s*secrets\.GITHUB_TOKEN'
        $script:docsContent | Should -Match 'secrets\.RELEASE_TOKEN\s*\|\|\s*secrets\.GITHUB_TOKEN'
    }

    It 'Reads secrets in entrypoint.sh without piping through xargs' {
        $script:entrypointContent | Should -Match 'tr -d ''\\r\\n'' < "\$secret_path"'
        $script:entrypointContent | Should -Not -Match '\|\s*xargs'
    }
}