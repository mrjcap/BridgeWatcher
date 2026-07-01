Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'run.ps1 Script Execution' {
    BeforeEach {
        $script:OriginalEnvApiKey = $Env:API_KEY
        $script:OriginalEnvPoApiKey = $Env:POAPI_KEY
        $script:OriginalEnvPoUserKey = $Env:POUSER_KEY
        $script:OriginalEnvOutDir = $Env:BRIDGEWATCHER_OUT

        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null
        $Env:BRIDGEWATCHER_OUT = "$TestDrive"
        $script:calledParams = $null
    }

    AfterEach {
        $Env:API_KEY = $script:OriginalEnvApiKey
        $Env:POAPI_KEY = $script:OriginalEnvPoApiKey
        $Env:POUSER_KEY = $script:OriginalEnvPoUserKey
        $Env:BRIDGEWATCHER_OUT = $script:OriginalEnvOutDir
    }

    It 'Should read secrets from environment variables if present, bypassing file reads' {
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'

        # Mock Get-BridgeStatusMonitor in both scopes to intercept all calls
        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        } -ModuleName 'BridgeWatcher'

        # Execute run.ps1
        . "$PSScriptRoot/../run.ps1"

        Assert-MockCalled Get-BridgeStatusMonitor -Exactly 1
        $script:calledParams.ApiKey | Should -Be 'env-api-key'
        $script:calledParams.PoApiKey | Should -Be 'env-po-api-key'
        $script:calledParams.PoUserKey | Should -Be 'env-po-user-key'
    }

    It 'Should trim newlines and spaces from secrets set in environment variables' {
        $Env:API_KEY = "  env-api-key`n`r  "
        $Env:POAPI_KEY = "  env-po-api-key`n  "
        $Env:POUSER_KEY = "env-po-user-key`r"

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        } -ModuleName 'BridgeWatcher'

        . "$PSScriptRoot/../run.ps1"

        Assert-MockCalled Get-BridgeStatusMonitor -Exactly 1
        $script:calledParams.ApiKey | Should -Be 'env-api-key'
        $script:calledParams.PoApiKey | Should -Be 'env-po-api-key'
        $script:calledParams.PoUserKey | Should -Be 'env-po-user-key'
    }

    It 'Should trim newlines and spaces from secrets loaded from files' {
        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null

        # Create secret files with newlines and spaces in TestDrive
        $secretDir = New-Item -ItemType Directory -Path "$TestDrive/run/secrets" -Force
        "  file-api-key`n`r  " | Out-File -FilePath "$TestDrive/run/secrets/API_KEY" -NoNewline
        "  file-po-api-key`n  " | Out-File -FilePath "$TestDrive/run/secrets/POAPI_KEY" -NoNewline
        "file-po-user-key`r" | Out-File -FilePath "$TestDrive/run/secrets/POUSER_KEY" -NoNewline

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        } -ModuleName 'BridgeWatcher'

        # Route /run/secrets to $TestDrive/run/secrets for the execution of run.ps1
        Mock Test-Path {
            param($Path)
            if ($Path -like '*/run/secrets/*') {
                $fileName = Split-Path $Path -Leaf
                return ( & (Get-Command Test-Path -CommandType Cmdlet) -Path "$TestDrive/run/secrets/$fileName" )
            }
            return ( & (Get-Command Test-Path -CommandType Cmdlet) @PSBoundParameters )
        }

        Mock Get-Content {
            param($Path, $Raw)
            if ($Path -like '*/run/secrets/*') {
                $fileName = Split-Path $Path -Leaf
                return ( & (Get-Command Get-Content -CommandType Cmdlet) -Path "$TestDrive/run/secrets/$fileName" -Raw )
            }
            return ( & (Get-Command Get-Content -CommandType Cmdlet) @PSBoundParameters )
        }

        . "$PSScriptRoot/../run.ps1"

        Assert-MockCalled Get-BridgeStatusMonitor -Exactly 1
        $script:calledParams.ApiKey | Should -Be 'file-api-key'
        $script:calledParams.PoApiKey | Should -Be 'file-po-api-key'
        $script:calledParams.PoUserKey | Should -Be 'file-po-user-key'
    }
}
