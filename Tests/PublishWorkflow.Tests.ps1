Describe -Name 'Publish Workflow Verification Step' -Fixture {
    BeforeAll -Scriptblock {
        $script:workflowPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../.github/workflows/publish.yml'))
        $script:content = Get-Content -Path $script:workflowPath -Raw
        $script:start = $script:content.IndexOf('- name: Verify module publication')
        $script:end = $script:content.IndexOf('- name: Set job outputs')
        $script:verifyStep = $script:content.Substring($script:start, $script:end - $script:start)
    }

    It -Name 'Locates the verification step' -Test {
        $script:verifyStep | Should -Match -RegularExpression 'Find-Module'
    }

    It -Name 'Does not run aggressive Git cleanup before setting job outputs' -Test {
        $script:verifyStep | Should -Not -Match -RegularExpression 'git gc'
    }

    It -Name 'Does not sleep unconditionally before the first poll' -Test {
        $firstSleep = $script:verifyStep.IndexOf('Start-Sleep')
        $firstPoll = $script:verifyStep.IndexOf('Find-Module')
        $firstPoll | Should -BeLessThan -ExpectedValue $firstSleep
        $script:verifyStep | Should -Not -Match -RegularExpression 'Start-Sleep -Seconds 30'
    }

    It -Name 'Backs off between attempts and keeps a bounded delay' -Test {
        $script:verifyStep | Should -Match -RegularExpression '\$delaySeconds = \[Math\]::Min\(\$delaySeconds \* 2, \$maxDelaySeconds\)'
    }

    It -Name 'Waits at least as long overall as the previous fixed delay plus six 30 second retries' -Test {
        $maxAttempts = [int]([regex]::Match($script:verifyStep, '\$maxAttempts = (\d+)').Groups[1].Value)
        $delay = [int]([regex]::Match($script:verifyStep, '\$delaySeconds = (\d+)\r?\n').Groups[1].Value)
        $cap = [int]([regex]::Match($script:verifyStep, '\$maxDelaySeconds = (\d+)').Groups[1].Value)

        $total = 0
        for ($i = 1; $i -lt $maxAttempts; $i++) {
            $total += $delay
            $delay = [Math]::Min($delay * 2, $cap)
        }
        $total | Should -BeGreaterOrEqual -ExpectedValue 210
    }

    It -Name 'Reports the last observed state when verification fails' -Test {
        $script:verifyStep | Should -Match -RegularExpression 'Last observed state: \$lastState'
    }
}
