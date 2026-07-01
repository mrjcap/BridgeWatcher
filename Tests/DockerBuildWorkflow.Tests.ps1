Describe 'Docker Build Workflow Configuration' {
    It 'Ελέγχει την ακριβή έκδοση release tag στο build-and-test job' {
        $workflowPath = Join-Path $PSScriptRoot '../.github/workflows/docker-build.yml'
        $content = Get-Content $workflowPath -Raw

        # Check if the file contains ref config under checkout
        $content | Should -Match 'ref:\s+v\$\{\{\s*inputs\.version\s*\}\}'
    }
}