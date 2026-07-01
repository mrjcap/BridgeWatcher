Describe 'Docker Build Workflow Configuration' {
    It 'Checks out the exact release tag version in build-and-test job' {
        $workflowPath = Join-Path $PSScriptRoot '../.github/workflows/docker-build.yml'
        $content = Get-Content $workflowPath -Raw

        # Check if the file contains ref config under checkout
        $content | Should -Match 'ref:\s+v\$\{\{\s*inputs\.version\s*\}\}'
    }
}
