Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'run.ps1 Script Execution' -Fixture {
    BeforeEach -Scriptblock {
        $script:OriginalEnvApiKey = $Env:API_KEY
        $script:OriginalEnvPoApiKey = $Env:POAPI_KEY
        $script:OriginalEnvPoUserKey = $Env:POUSER_KEY
        $script:OriginalEnvOutDir = $Env:BRIDGEWATCHER_OUT
        $script:OriginalEnvSecretsDir = $Env:BRIDGEWATCHER_SECRETS_DIR
        $script:OriginalEnvConfigPath = $Env:BRIDGEWATCHER_CONFIG_PATH

        $Env:API_KEY = $null
        $Env:POAPI_KEY = $null
        $Env:POUSER_KEY = $null
        $Env:BRIDGEWATCHER_OUT = "$TestDrive"
        $Env:BRIDGEWATCHER_SECRETS_DIR = $null
        $Env:BRIDGEWATCHER_CONFIG_PATH = $null
        $script:calledParams = $null
    }

    AfterEach -Scriptblock {
        $Env:API_KEY = $script:OriginalEnvApiKey
        $Env:POAPI_KEY = $script:OriginalEnvPoApiKey
        $Env:POUSER_KEY = $script:OriginalEnvPoUserKey
        $Env:BRIDGEWATCHER_OUT = $script:OriginalEnvOutDir
        $Env:BRIDGEWATCHER_SECRETS_DIR = $script:OriginalEnvSecretsDir
        $Env:BRIDGEWATCHER_CONFIG_PATH = $script:OriginalEnvConfigPath
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

    It -Name 'Should apply BRIDGEWATCHER_CONFIG_PATH overrides to the monitor configuration for <Case>' -TestCases @(
        @{ Case = 'an ordinary filename'; FileName = 'bridgewatcher.e2e.json' }
        @{ Case = 'a bracketed filename'; FileName = 'bridgewatcher[1].e2e.json' }
    ) -Test {
        param($Case, $FileName)
        $null = $Case
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'
        $configFile = Join-Path -Path $TestDrive -ChildPath $FileName
        @{
            Urls     = @{
                Source      = 'https://fixture.bridgewatcher.test:8443/dioriga/'
                BaseImage   = 'https://fixture.bridgewatcher.test:8443/dioriga'
                OCRApi      = 'https://fixture.bridgewatcher.test:8443/v1/images:annotate'
                PushoverApi = 'https://fixture.bridgewatcher.test:8443/1/messages.json'
            }
            Defaults = @{ HttpRequestTimeout = 10 }
        } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $configFile -Encoding utf8
        $Env:BRIDGEWATCHER_CONFIG_PATH = "  $configFile  "

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {
            param($Configuration, $IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $ApiKey; $null = $PoApiKey; $null = $PoUserKey; $null = $Verbose
            $script:calledParams = @{ Configuration = $Configuration }
        }

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.Configuration.Urls.Source | Should -Be -ExpectedValue 'https://fixture.bridgewatcher.test:8443/dioriga/'
        $script:calledParams.Configuration.Urls.BaseImage | Should -Be -ExpectedValue 'https://fixture.bridgewatcher.test:8443/dioriga'
        $script:calledParams.Configuration.Urls.OCRApi | Should -Be -ExpectedValue 'https://fixture.bridgewatcher.test:8443/v1/images:annotate'
        $script:calledParams.Configuration.Urls.PushoverApi | Should -Be -ExpectedValue 'https://fixture.bridgewatcher.test:8443/1/messages.json'
        $script:calledParams.Configuration.Defaults.HttpRequestTimeout | Should -Be -ExpectedValue 10
        $script:calledParams.Configuration.Defaults.LogDirectory | Should -Be -ExpectedValue "$TestDrive"
    }

    It -Name 'Should keep production endpoints when BRIDGEWATCHER_CONFIG_PATH is <Case>' -TestCases @(
        @{ Case = 'unset'; Value = $null }
        @{ Case = 'blank'; Value = '   ' }
    ) -Test {
        param($Case, $Value)
        $null = $Case
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'
        $Env:BRIDGEWATCHER_CONFIG_PATH = $Value

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {
            param($Configuration, $IntervalSeconds, $MaxIterations, $OutputFile, $ApiKey, $PoApiKey, $PoUserKey, $Verbose)
            $null = $IntervalSeconds; $null = $MaxIterations; $null = $OutputFile; $null = $ApiKey; $null = $PoApiKey; $null = $PoUserKey; $null = $Verbose
            $script:calledParams = @{ Configuration = $Configuration }
        }

        . "$PSScriptRoot/../run.ps1"

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 1 -Exactly
        $script:calledParams.Configuration.Urls.Source | Should -Be -ExpectedValue 'https://www.topvision.gr/dioriga/'
        $script:calledParams.Configuration.Urls.OCRApi | Should -Be -ExpectedValue 'https://vision.googleapis.com/v1/images:annotate'
        $script:calledParams.Configuration.Urls.PushoverApi | Should -Be -ExpectedValue 'https://api.pushover.net/1/messages.json'
        $script:calledParams.Configuration.Defaults.HttpRequestTimeout | Should -Be -ExpectedValue 60
    }

    It -Name 'Should throw FileNotFoundException before monitoring when BRIDGEWATCHER_CONFIG_PATH is <Case>' -TestCases @(
        @{ Case = 'missing'; Kind = 'missing' }
        @{ Case = 'a directory'; Kind = 'directory' }
    ) -Test {
        param($Case, $Kind)
        $null = $Case
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'
        $target = Join-Path -Path $TestDrive -ChildPath "config-$Kind"
        if ($Kind -eq 'directory') {
            $null = New-Item -ItemType Directory -Path $target -Force
        }
        $Env:BRIDGEWATCHER_CONFIG_PATH = $target

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {}
        Mock -CommandName Send-BridgePushover -MockWith {}

        { . "$PSScriptRoot/../run.ps1" } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 0 -Exactly
        Should -Invoke -CommandName Send-BridgePushover -Times 0 -Exactly
    }

    It -Name 'Should throw before monitoring when BRIDGEWATCHER_CONFIG_PATH is not valid JSON' -Test {
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'
        $configFile = Join-Path -Path $TestDrive -ChildPath 'broken.json'
        Set-Content -Path $configFile -Value '{ "Urls": ' -Encoding utf8
        $Env:BRIDGEWATCHER_CONFIG_PATH = $configFile

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {}
        Mock -CommandName Send-BridgePushover -MockWith {}

        { . "$PSScriptRoot/../run.ps1" } | Should -Throw

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 0 -Exactly
        Should -Invoke -CommandName Send-BridgePushover -Times 0 -Exactly
    }

    It -Name 'Should throw before monitoring when BRIDGEWATCHER_CONFIG_PATH is unreadable' -Skip:$IsWindows -Test {
        $Env:API_KEY = 'env-api-key'
        $Env:POAPI_KEY = 'env-po-api-key'
        $Env:POUSER_KEY = 'env-po-user-key'
        $configFile = Join-Path -Path $TestDrive -ChildPath 'unreadable.json'
        Set-Content -Path $configFile -Value '{}' -Encoding utf8
        [System.IO.File]::SetUnixFileMode($configFile, [System.IO.UnixFileMode]::None)
        $readable = $true
        try {
            $null = [System.IO.File]::ReadAllText($configFile)
        } catch [System.UnauthorizedAccessException] {
            $readable = $false
        }
        if ($readable) {
            Set-ItResult -Skipped -Because 'the current user can read files with mode 000'
            return
        }
        $Env:BRIDGEWATCHER_CONFIG_PATH = $configFile

        Mock -CommandName Get-BridgeStatusMonitor -MockWith {}
        Mock -CommandName Send-BridgePushover -MockWith {}

        try {
            { . "$PSScriptRoot/../run.ps1" } | Should -Throw
        } finally {
            [System.IO.File]::SetUnixFileMode($configFile, [System.IO.UnixFileMode]'UserRead, UserWrite')
        }

        Should -Invoke -CommandName Get-BridgeStatusMonitor -Times 0 -Exactly
        Should -Invoke -CommandName Send-BridgePushover -Times 0 -Exactly
    }
}