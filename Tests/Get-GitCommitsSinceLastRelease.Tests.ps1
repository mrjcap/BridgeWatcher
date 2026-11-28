$ErrorActionPreference = 'Stop'

Describe -Name "Get-LatestTagOnCurrentBranch" -Fixture {
    BeforeAll -Scriptblock {
        Mock -CommandName 'git' -MockWith {
            $global:LastExitCode = 1
            return $null
        }
        . "$PSScriptRoot/../scripts/Get-GitCommitsSinceLastRelease.ps1" -From 'dummy' -To 'dummy'
    }

    It -Name "throws an error if git describe and git rev-list fail with a non-zero exit code" -Test {
        Mock -CommandName 'git' -MockWith {
            $global:LastExitCode = 1
            return $null
        }

        { Get-LatestTagOnCurrentBranch } | Should -Throw
    }
}
