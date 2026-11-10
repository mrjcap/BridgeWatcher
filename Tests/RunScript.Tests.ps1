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

        # Mock του Get-BridgeStatusMonitor in both scopes to intercept all calls
        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        } -ModuleName 'BridgeWatcher'

        # Execute run.ps1
        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
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
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        } -ModuleName 'BridgeWatcher'

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.ApiKey | Should -Be 'env-api-key'
        $script:calledParams.PoApiKey | Should -Be 'env-po-api-key'
        $script:calledParams.PoUserKey | Should -Be 'env-po-user-key'
    }

    It 'Should trim newlines and spaces from secrets loaded from files' {
        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null

        # Create secret files with newlines and spaces in TestDrive
        $null = New-Item -ItemType Directory -Path "$TestDrive/run/secrets" -Force
        "  file-api-key`n`r  " | Out-File -FilePath "$TestDrive/run/secrets/API_KEY" -NoNewline
        "  file-po-api-key`n  " | Out-File -FilePath "$TestDrive/run/secrets/PUSHOVER_TOKEN" -NoNewline
        "file-po-user-key`r" | Out-File -FilePath "$TestDrive/run/secrets/PUSHOVER_USER" -NoNewline

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        Mock Get-BridgeStatusMonitor {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
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

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.ApiKey | Should -Be 'file-api-key'
        $script:calledParams.PoApiKey | Should -Be 'file-po-api-key'
        $script:calledParams.PoUserKey | Should -Be 'file-po-user-key'
    }

    It 'Should load lowercase compose secret files (/run/secrets/api_key, pushover_token, pushover_user)' {
        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null

        $null = New-Item -ItemType Directory -Path "$TestDrive/run/secrets_lower" -Force
        "lower-api-key`n" | Out-File -FilePath "$TestDrive/run/secrets_lower/api_key" -NoNewline
        "lower-po-api-key`n" | Out-File -FilePath "$TestDrive/run/secrets_lower/pushover_token" -NoNewline
        "lower-po-user-key`n" | Out-File -FilePath "$TestDrive/run/secrets_lower/pushover_user" -NoNewline

        Mock Get-BridgeStatusMonitor {
            param($Configuration, $IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                Configuration = $Configuration
                ApiKey        = $ApiKey
                PoApiKey      = $PoApiKey
                PoUserKey     = $PoUserKey
            }
        }

        Mock Get-BridgeStatusMonitor {
            param($Configuration, $IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                Configuration = $Configuration
                ApiKey        = $ApiKey
                PoApiKey      = $PoApiKey
                PoUserKey     = $PoUserKey
            }
        } -ModuleName 'BridgeWatcher'

        Mock Test-Path {
            param($Path)
            if ($Path -like '*/run/secrets/*') {
                $fileName = Split-Path $Path -Leaf
                return ( & (Get-Command Test-Path -CommandType Cmdlet) -Path "$TestDrive/run/secrets_lower/$fileName" )
            }
            return ( & (Get-Command Test-Path -CommandType Cmdlet) @PSBoundParameters )
        }

        Mock Get-Content {
            param($Path, $Raw)
            $null = $Raw
            if ($Path -like '*/run/secrets/*') {
                $fileName = Split-Path $Path -Leaf
                return ( & (Get-Command Get-Content -CommandType Cmdlet) -Path "$TestDrive/run/secrets_lower/$fileName" -Raw )
            }
            return ( & (Get-Command Get-Content -CommandType Cmdlet) @PSBoundParameters )
        }

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.ApiKey | Should -Be 'lower-api-key'
        $script:calledParams.PoApiKey | Should -Be 'lower-po-api-key'
        $script:calledParams.PoUserKey | Should -Be 'lower-po-user-key'
        $script:calledParams.Configuration.Defaults.LogDirectory | Should -Be "$TestDrive"
    }

    It 'Should send a Pushover crash alert with -Configuration when Get-BridgeStatusMonitor throws' {
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'

        Mock Get-BridgeStatusMonitor { throw 'Simulated monitor crash' }
        Mock Write-Error {}
        Mock Send-BridgePushover {}

        & "$PSScriptRoot/../run.ps1"

        $LASTEXITCODE | Should -Be 1
        Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly -ParameterFilter {
            $null -ne $Configuration -and $Configuration.Defaults.LogDirectory -eq "$TestDrive" -and $Priority -eq 1
        }
    }
}