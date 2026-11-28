Describe 'Publish Workflow Verification Step' {
    BeforeAll {
        $script:workflowPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/publish.yml'))
        $script:content = Get-Content -Path $script:workflowPath -Raw
        $script:start = $script:content.IndexOf('- name: Verify module publication')
        $script:end = $script:content.IndexOf('- name: Set job outputs')
        $script:verifyStep = $script:content.Substring($script:start, $script:end - $script:start)
    }

    It 'Locates the verification step' {
        $script:verifyStep | Should -Match 'Find-Module'
    }

    It 'Does not run aggressive Git cleanup before setting job outputs' {
        $script:verifyStep | Should -Not -Match 'git gc'
    }

    It 'Does not sleep unconditionally before the first poll' {
        $firstSleep = $script:verifyStep.IndexOf('Start-Sleep')
        $firstPoll = $script:verifyStep.IndexOf('Find-Module')
        $firstPoll | Should -BeLessThan $firstSleep
        $script:verifyStep | Should -Not -Match 'Start-Sleep -Seconds 30'
    }

    It 'Backs off between attempts and keeps a bounded delay' {
        $script:verifyStep | Should -Match '\$delaySeconds = \[Math\]::Min\(\$delaySeconds \* 2, \$maxDelaySeconds\)'
    }

    It 'Waits at least as long overall as the previous fixed delay plus six 30 second retries' {
        $maxAttempts = [int]([regex]::Match($script:verifyStep, '\$maxAttempts = (\d+)').Groups[1].Value)
        $delay = [int]([regex]::Match($script:verifyStep, '\$delaySeconds = (\d+)\r?\n').Groups[1].Value)
        $cap = [int]([regex]::Match($script:verifyStep, '\$maxDelaySeconds = (\d+)').Groups[1].Value)

        $total = 0
        for ($i = 1; $i -lt $maxAttempts; $i++) {
            $total += $delay
            $delay = [Math]::Min($delay * 2, $cap)
        }
        $total | Should -BeGreaterOrEqual 210
    }

    It 'Reports the last observed state when verification fails' {
        $script:verifyStep | Should -Match 'Last observed state: \$lastState'
    }
}
