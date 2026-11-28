Describe -Name 'Docker Build Workflow Configuration' -Fixture {
    BeforeAll -Scriptblock {
        $script:workflowPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/docker-build.yml'))
        $script:content = Get-Content -Path $script:workflowPath -Raw
        $script:releasePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/release.yml'))
        $script:releaseContent = Get-Content -Path $script:releasePath -Raw
        $script:publishPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/publish.yml'))
        $script:publishContent = Get-Content -Path $script:publishPath -Raw
        $script:docsPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/powershell-docs.yml'))
        $script:docsContent = Get-Content -Path $script:docsPath -Raw
        $script:dockerfilePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../Docker/Dockerfile'))
        $script:dockerfileContent = Get-Content -Path $script:dockerfilePath -Raw
        $script:composePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../docker-compose.yml'))
        $script:composeContent = Get-Content -Path $script:composePath -Raw
    }

    It -Name 'Requires CI and security-analysis success before gatekeeper commits changelog and resumes untagged releases' -Test {
        $script:releaseContent | Should -Match -RegularExpression "needs:\s*\[ci,\s*security-analysis\]"
        $script:releaseContent | Should -Match -RegularExpression "if:\s*needs\.ci\.result\s*==\s*'success'\s*&&\s*needs\.security-analysis\.result\s*==\s*'success'"
        $script:releaseContent | Should -Match -RegularExpression 'refs/tags/v\$NEXT_VERSION'
    }

    It -Name 'Ελέγχει την ακριβή έκδοση release tag στο build-and-test job' -Test {
        $script:content | Should -Match -RegularExpression 'ref:\s+v\$\{\{\s*inputs\.version\s*\}\}'
    }

    It -Name 'Sets test-logs permissions before changing ownership to container UID:GID' -Test {
        $script:content | Should -Match -RegularExpression 'chmod 750 test-logs\s+sudo chown 99:100 test-logs'
    }

    It -Name 'Sets owner-only test-secrets permissions for container UID 99' -Test {
        $script:content | Should -Match -RegularExpression 'mkdir -m 0700 test-secrets test-logs'
        $script:content | Should -Match -RegularExpression 'sudo chmod 0600 test-secrets/\{api_key,pushover_token,pushover_user\}'
        $script:content | Should -Match -RegularExpression 'sudo chown 99 test-secrets test-secrets/\{api_key,pushover_token,pushover_user\}'
    }

    It -Name 'Cleans up container-owned test-logs directory using sudo' -Test {
        $script:content | Should -Match -RegularExpression 'sudo rm -rf test-secrets test-logs'
    }

    It -Name 'Runs the hermetic first-poll E2E test and its negative control against the built image' -Test {
        $script:content | Should -Match -RegularExpression "(?s)-\s*name:\s*Test Docker image\s+id:\s*e2e\s.*?bash Tests/E2E/run-image-e2e\.sh happy\s+bash Tests/E2E/run-image-e2e\.sh pushover-reject"
        $script:content | Should -Match -RegularExpression 'E2E_FIXTURE_IMAGE:\s*public\.ecr\.aws/docker/library/python:[^@\s]+@sha256:[0-9a-f]{64}'
        $script:content | Should -Match -RegularExpression "(?s)-\s*name:\s*Upload E2E evidence\s+if:\s*always\(\)\s*&&\s*steps\.e2e\.outcome\s*==\s*'failure'"
        $e2ePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath 'E2E/run-image-e2e.sh'))
        $e2eContent = [System.IO.File]::ReadAllText($e2ePath)
        $e2eContent | Should -Not -Match -RegularExpression "`r"
        $e2eContent | Should -Match -RegularExpression 'docker network create --internal'
        $e2eContent | Should -Match -RegularExpression '-e SSL_CERT_FILE=/e2e/ca/ca\.pem -e SSL_CERT_DIR=/e2e/ca-empty'
        $e2eContent | Should -Match -RegularExpression '-e BRIDGEWATCHER_CONFIG_PATH=/e2e/bridgewatcher\.e2e\.json'
        $e2eContent | Should -Not -Match -RegularExpression '--insecure|curl -k\b|SkipCertificateCheck'
        $e2eContent | Should -Not -Match -RegularExpression '>\s*"\$SECRETS/'
    }

    It -Name 'Gates non-PR steps using pull_request event checks instead of workflow_call' -Test {
        $script:content | Should -Not -Match -RegularExpression "github\.event_name\s*[!=]=\s*'workflow_call'"
        $script:content | Should -Match -RegularExpression "github\.event_name\s*!=\s*'pull_request'\s*&&\s*!inputs\.dry_run"
    }

    It -Name 'Supports RELEASE_TOKEN with GITHUB_TOKEN fallback across release workflows' -Test {
        $script:releaseContent | Should -Match -RegularExpression 'secrets\.RELEASE_TOKEN\s*\|\|\s*secrets\.GITHUB_TOKEN'
        $script:publishContent | Should -Match -RegularExpression 'secrets\.RELEASE_TOKEN\s*\|\|\s*secrets\.GITHUB_TOKEN'
        $script:docsContent | Should -Match -RegularExpression 'secrets\.RELEASE_TOKEN\s*\|\|\s*secrets\.GITHUB_TOKEN'
    }

    It -Name 'Invokes run.ps1 directly via pwsh ENTRYPOINT without entrypoint.sh exporting secrets to env' -Test {
        $entrypointFile = Join-Path -Path $PSScriptRoot -ChildPath '../Docker/entrypoint.sh'
        Test-Path -Path $entrypointFile | Should -BeFalse
        $script:dockerfileContent | Should -Not -Match -RegularExpression 'entrypoint\.sh'
        $script:dockerfileContent | Should -Match -RegularExpression 'ENTRYPOINT \["pwsh", "-NoLogo", "-NoProfile", "-File", "\./run\.ps1"\]'
    }

    It -Name 'Disables persist-credentials on checkout and pins exact module versions in powershell-docs.yml' -Test {
        $script:docsContent | Should -Match -RegularExpression 'persist-credentials:\s*false'
        $script:docsContent | Should -Not -Match -RegularExpression '-MinimumVersion'
        $script:docsContent | Should -Match -RegularExpression 'Install-Module -Name \$module\.Name -RequiredVersion \$module\.RequiredVersion'
    }

    It -Name 'Uses JSON exec array notation for HEALTHCHECK CMD in Dockerfile (Hadolint DL3025)' -Test {
        $script:dockerfileContent | Should -Match -RegularExpression '# hadolint ignore=DL3025'
        $script:dockerfileContent | Should -Match -RegularExpression 'CMD \["sh", "-c",'
        $script:dockerfileContent | Should -Match -RegularExpression '\$\{BRIDGEWATCHER_OUT:-/app/logs\}'
        $script:dockerfileContent | Should -Not -Match -RegularExpression 'CMD \["pwsh"'
    }

    It -Name 'Sets ash pipefail SHELL before RUN instructions with pipes in Dockerfile (Hadolint DL4006)' -Test {
        $script:dockerfileContent | Should -Match -RegularExpression '(?m)^SHELL \["/bin/ash", "-eo", "pipefail", "-c"\]\s*$'
        $shellPos = $script:dockerfileContent.IndexOf('SHELL ["/bin/ash", "-eo", "pipefail", "-c"]')
        $runPos = $script:dockerfileContent.IndexOf('RUN apk update')
        $shellPos | Should -BeGreaterThan -ExpectedValue -1
        $runPos | Should -BeGreaterThan -ExpectedValue $shellPos
    }

    It -Name 'Integrates upstream branch changes without --force-with-lease in powershell-docs.yml' -Test {
        $script:docsContent | Should -Not -Match -RegularExpression '--force-with-lease'
        $script:docsContent | Should -Match -RegularExpression "ref:\s*\$\{\{\s*github\.event_name\s*==\s*'pull_request'\s*&&\s*github\.ref\s*\|\|\s*\(github\.head_ref\s*\|\|\s*github\.ref_name\)\s*\}\}"
        $script:docsContent | Should -Match -RegularExpression 'git pull --rebase origin "\$BRANCH_NAME"'
        $script:docsContent | Should -Match -RegularExpression 'git push origin "HEAD:\$BRANCH_NAME"'
    }

    It -Name 'Enforces blocking HIGH and CRITICAL severity exit-code on Trivy vulnerability scan in docker-build.yml' -Test {
        $script:content | Should -Match -RegularExpression "(?s)-\s*name:\s*Scan Docker image for vulnerabilities.*?exit-code:\s*'1'.*?severity:\s*'HIGH,CRITICAL'"
    }

    It -Name 'Gates git push and GitHub Release creation steps on !inputs.dry_run across release workflows' -Test {
        $script:releaseContent | Should -Match -RegularExpression "(?s)-\s*name:\s*Commit and Push Changelog\s+if:\s*steps\.changelog_check\.outputs\.updated\s*==\s*'true'\s*&&\s*!inputs\.dry_run"
        $script:releaseContent | Should -Match -RegularExpression "(?s)uses:\s*\./\.github/workflows/powershell-docs\.yml\s+with:\s+dry_run:\s*\$\{\{\s*inputs\.dry_run(?:\s*==\s*true)?\s*\}\}"
        $script:docsContent | Should -Match -RegularExpression "(?s)workflow_call:\s+inputs:\s+dry_run:.*?type:\s*boolean\s+default:\s*false"
        $script:docsContent | Should -Match -RegularExpression "(?s)-\s*name:\s*Configure git credentials for documentation push\s+if:\s*steps\.docs_changes\.outputs\.changes_detected\s*==\s*'true'\s*&&\s*github\.event_name\s*!=\s*'pull_request'\s*&&\s*!inputs\.dry_run"
        $script:docsContent | Should -Match -RegularExpression "(?s)-\s*name:\s*Commit and push documentation changes\s+if:\s*steps\.docs_changes\.outputs\.changes_detected\s*==\s*'true'\s*&&\s*github\.event_name\s*!=\s*'pull_request'\s*&&\s*!inputs\.dry_run"
        $script:publishContent | Should -Match -RegularExpression "(?s)-\s*name:\s*Commit version update\s+if:\s*\$\{\{\s*!inputs\.dry_run\s*\}\}"
        $script:publishContent | Should -Match -RegularExpression "(?s)-\s*name:\s*Push changes\s+if:\s*\$\{\{\s*!inputs\.dry_run\s*\}\}"
        $script:publishContent | Should -Match -RegularExpression "(?s)-\s*name:\s*Create GitHub Release\s+id:\s*create_release\s+if:\s*\$\{\{\s*!inputs\.dry_run\s*\}\}"
        $script:publishContent | Should -Match -RegularExpression "RELEASE_URL:\s*\$\{\{\s*steps\.create_release\.outputs\.url\s*\|\|\s*'N/A'\s*\}\}"
    }

    It -Name 'Gates filebeat behind the siem profile and hardens privileges in docker-compose.yml' -Test {
        $filebeatSection = (($script:composeContent -split '(?m)^\s{2}filebeat:\r?\n')[1] -split '(?m)^volumes:\r?\n')[0]
        $filebeatSection | Should -Not -BeNullOrEmpty
        $filebeatSection | Should -Match -RegularExpression 'image:\s*docker\.elastic\.co/beats/filebeat:'
        $filebeatSection | Should -Match -RegularExpression 'profiles:\s*(?:\[\s*"?siem"?\s*\]|\r?\n\s*-\s*siem\b)'
        $filebeatSection | Should -Match -RegularExpression 'security_opt:\s*(?:\[\s*"?no-new-privileges:true"?\s*\]|\r?\n\s*-\s*no-new-privileges:true\b)'
        $filebeatSection | Should -Match -RegularExpression 'cap_drop:\s*(?:\[\s*"?ALL"?\s*\]|\r?\n\s*-\s*ALL\b)'
    }
}