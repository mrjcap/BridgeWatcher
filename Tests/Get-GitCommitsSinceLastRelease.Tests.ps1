$ErrorActionPreference = 'Stop'

Describe "Get-LatestTagOnCurrentBranch" {
    BeforeAll {
        Mock -CommandName 'git' -MockWith {
            $global:LastExitCode = 1
            return $null
        }
        . "$PSScriptRoot/../scripts/Get-GitCommitsSinceLastRelease.ps1" -From 'dummy' -To 'dummy'
    }

    It "throws an error if git describe and git rev-list fail with a non-zero exit code" {
        Mock -CommandName 'git' -MockWith {
            $global:LastExitCode = 1
            return $null
        }

        { Get-LatestTagOnCurrentBranch } | Should -Throw
    }
}
