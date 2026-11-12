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
        $script:dockerfilePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../Docker/Dockerfile'))
        $script:dockerfileContent = Get-Content -Path $script:dockerfilePath -Raw
        $script:composePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../docker-compose.yml'))
        $script:composeContent = Get-Content -Path $script:composePath -Raw
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

    It 'Disables persist-credentials on checkout and pins exact module versions in powershell-docs.yml' {
        $script:docsContent | Should -Match 'persist-credentials:\s*false'
        $script:docsContent | Should -Not -Match '-MinimumVersion'
        $script:docsContent | Should -Match 'Install-Module -Name \$module\.Name -RequiredVersion \$module\.RequiredVersion'
    }

    It 'Uses JSON exec array notation for HEALTHCHECK CMD in Dockerfile (Hadolint DL3025)' {
        $script:dockerfileContent | Should -Match '# hadolint ignore=DL3025'
        $script:dockerfileContent | Should -Match 'CMD \["pwsh", "-NoLogo", "-NoProfile", "-Command",'
    }

    It 'Integrates upstream branch changes without --force-with-lease in powershell-docs.yml' {
        $script:docsContent | Should -Not -Match '--force-with-lease'
        $script:docsContent | Should -Match "ref:\s*\$\{\{\s*github\.event_name\s*==\s*'pull_request'\s*&&\s*github\.ref\s*\|\|\s*\(github\.head_ref\s*\|\|\s*github\.ref_name\)\s*\}\}"
        $script:docsContent | Should -Match 'git pull --rebase origin "\$BRANCH_NAME"'
        $script:docsContent | Should -Match 'git push origin "HEAD:\$BRANCH_NAME"'
    }

    It 'Enforces blocking HIGH and CRITICAL severity exit-code on Trivy vulnerability scan in docker-build.yml' {
        $script:content | Should -Match "(?s)-\s*name:\s*Scan Docker image for vulnerabilities.*?exit-code:\s*'1'.*?severity:\s*'HIGH,CRITICAL'"
    }

    It 'Gates git push and GitHub Release creation steps on !inputs.dry_run across release workflows' {
        $script:releaseContent | Should -Match "(?s)-\s*name:\s*Commit and Push Changelog\s+if:\s*steps\.changelog_check\.outputs\.updated\s*==\s*'true'\s*&&\s*!inputs\.dry_run"
        $script:releaseContent | Should -Match "(?s)uses:\s*\./\.github/workflows/powershell-docs\.yml\s+with:\s+dry_run:\s*\$\{\{\s*inputs\.dry_run\s*\}\}"
        $script:docsContent | Should -Match "(?s)workflow_call:\s+inputs:\s+dry_run:.*?type:\s*boolean\s+default:\s*false"
        $script:docsContent | Should -Match "(?s)-\s*name:\s*Configure git credentials for documentation push\s+if:\s*steps\.docs_changes\.outputs\.changes_detected\s*==\s*'true'\s*&&\s*github\.event_name\s*!=\s*'pull_request'\s*&&\s*!inputs\.dry_run"
        $script:docsContent | Should -Match "(?s)-\s*name:\s*Commit and push documentation changes\s+if:\s*steps\.docs_changes\.outputs\.changes_detected\s*==\s*'true'\s*&&\s*github\.event_name\s*!=\s*'pull_request'\s*&&\s*!inputs\.dry_run"
        $script:publishContent | Should -Match "(?s)-\s*name:\s*Commit version update\s+if:\s*\$\{\{\s*!inputs\.dry_run\s*\}\}"
        $script:publishContent | Should -Match "(?s)-\s*name:\s*Push changes\s+if:\s*\$\{\{\s*!inputs\.dry_run\s*\}\}"
        $script:publishContent | Should -Match "(?s)-\s*name:\s*Create GitHub Release\s+id:\s*create_release\s+if:\s*\$\{\{\s*!inputs\.dry_run\s*\}\}"
        $script:publishContent | Should -Match "RELEASE_URL:\s*\$\{\{\s*steps\.create_release\.outputs\.url\s*\|\|\s*'N/A'\s*\}\}"
    }

    It 'Gates filebeat behind the siem profile and hardens privileges in docker-compose.yml' {
        $filebeatSection = (($script:composeContent -split '(?m)^\s{2}filebeat:\r?\n')[1] -split '(?m)^volumes:\r?\n')[0]
        $filebeatSection | Should -Not -BeNullOrEmpty
        $filebeatSection | Should -Match 'image:\s*docker\.elastic\.co/beats/filebeat:'
        $filebeatSection | Should -Match 'profiles:\s*(?:\[\s*"?siem"?\s*\]|\r?\n\s*-\s*siem\b)'
        $filebeatSection | Should -Match 'security_opt:\s*(?:\[\s*"?no-new-privileges:true"?\s*\]|\r?\n\s*-\s*no-new-privileges:true\b)'
        $filebeatSection | Should -Match 'cap_drop:\s*(?:\[\s*"?ALL"?\s*\]|\r?\n\s*-\s*ALL\b)'
    }
}