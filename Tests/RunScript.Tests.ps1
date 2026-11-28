Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'run.ps1 Script Execution' -Fixture {
    BeforeEach -Scriptblock {
        $script:OriginalEnvApiKey = $Env:API_KEY
        $script:OriginalEnvPoApiKey = $Env:POAPI_KEY
        $script:OriginalEnvPoUserKey = $Env:POUSER_KEY
        $script:OriginalEnvOutDir = $Env:BRIDGEWATCHER_OUT
        $script:OriginalEnvSecretsDir = $Env:BRIDGEWATCHER_SECRETS_DIR

        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null
        $Env:BRIDGEWATCHER_OUT = "$TestDrive"
        $Env:BRIDGEWATCHER_SECRETS_DIR = $null
        $script:calledParams = $null
    }

    AfterEach -Scriptblock {
        $Env:API_KEY = $script:OriginalEnvApiKey
        $Env:POAPI_KEY = $script:OriginalEnvPoApiKey
        $Env:POUSER_KEY = $script:OriginalEnvPoUserKey
        $Env:BRIDGEWATCHER_OUT = $script:OriginalEnvOutDir
        $Env:BRIDGEWATCHER_SECRETS_DIR = $script:OriginalEnvSecretsDir
    }

    It -Name 'Should read secrets from environment variables if present, bypassing file reads' -Test {
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.ApiKey | Should -Be -ExpectedValue 'env-api-key'
        $script:calledParams.PoApiKey | Should -Be -ExpectedValue 'env-po-api-key'
        $script:calledParams.PoUserKey | Should -Be -ExpectedValue 'env-po-user-key'
    }

    It -Name 'Should trim newlines and spaces from secrets set in environment variables' -Test {
        $Env:API_KEY = "  env-api-key`n`r  "
        $Env:POAPI_KEY = "  env-po-api-key`n  "
        $Env:POUSER_KEY = "env-po-user-key`r"

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.ApiKey | Should -Be -ExpectedValue 'env-api-key'
        $script:calledParams.PoApiKey | Should -Be -ExpectedValue 'env-po-api-key'
        $script:calledParams.PoUserKey | Should -Be -ExpectedValue 'env-po-user-key'
    }

    It -Name 'Should trim newlines and spaces from secrets loaded from files' -Test {
        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null
        $Env:BRIDGEWATCHER_SECRETS_DIR = "$TestDrive/run/secrets"

        $null = New-Item -ItemType Directory -Path "$TestDrive/run/secrets" -Force
        "  file-api-key`n`r  " | Out-File -FilePath "$TestDrive/run/secrets/API_KEY" -NoNewline
        "  file-po-api-key`n  " | Out-File -FilePath "$TestDrive/run/secrets/PUSHOVER_TOKEN" -NoNewline
        "file-po-user-key`r" | Out-File -FilePath "$TestDrive/run/secrets/PUSHOVER_USER" -NoNewline

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {
            param($IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                ApiKey    = $ApiKey
                PoApiKey  = $PoApiKey
                PoUserKey = $PoUserKey
            }
        }

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.ApiKey | Should -Be -ExpectedValue 'file-api-key'
        $script:calledParams.PoApiKey | Should -Be -ExpectedValue 'file-po-api-key'
        $script:calledParams.PoUserKey | Should -Be -ExpectedValue 'file-po-user-key'
    }

    It -Name 'Should load lowercase compose secret files (/run/secrets/api_key, pushover_token, pushover_user)' -Test {
        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null
        $Env:BRIDGEWATCHER_SECRETS_DIR = "$TestDrive/run/secrets_lower"

        $null = New-Item -ItemType Directory -Path "$TestDrive/run/secrets_lower" -Force
        "lower-api-key`n" | Out-File -FilePath "$TestDrive/run/secrets_lower/api_key" -NoNewline
        "lower-po-api-key`n" | Out-File -FilePath "$TestDrive/run/secrets_lower/pushover_token" -NoNewline
        "lower-po-user-key`n" | Out-File -FilePath "$TestDrive/run/secrets_lower/pushover_user" -NoNewline

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {
            param($Configuration, $IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $Verbose
            $script:calledParams = @{
                Configuration = $Configuration
                ApiKey        = $ApiKey
                PoApiKey      = $PoApiKey
                PoUserKey     = $PoUserKey
            }
        }

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.ApiKey | Should -Be -ExpectedValue 'lower-api-key'
        $script:calledParams.PoApiKey | Should -Be -ExpectedValue 'lower-po-api-key'
        $script:calledParams.PoUserKey | Should -Be -ExpectedValue 'lower-po-user-key'
        $script:calledParams.Configuration.Defaults.LogDirectory | Should -Be -ExpectedValue "$TestDrive"
    }

    It -Name 'Should send a Pushover crash alert with -Configuration when Get-BridgeStatusMonitor throws' -Test {
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'

        Mock -CommandName Get-BridgeStatusMonitor -MockWith { throw 'Simulated monitor crash' }
        Mock -CommandName Write-Error -MockWith {}
        Mock -CommandName Send-BridgePushover -MockWith {}

        & "$PSScriptRoot/../run.ps1"

        $LASTEXITCODE | Should -Be -ExpectedValue 1
        Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly -ParameterFilter {
            $null -ne $Configuration -and $Configuration.Defaults.LogDirectory -eq "$TestDrive" -and $Priority -eq 1
        }
    }
}