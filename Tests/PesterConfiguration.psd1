@{
    Run = @{
        Path    = '.\Tests\'
        Parameters    = @{
            ModuleName = 'BridgeWatcher'
        }
        TestExtension = '.Tests.ps1'
        Exit        = $false
        Throw       = $false
        PassThru    = $true
    }
    Filter = @{
        Tag         = @()
        ExcludeTag  = @()
    }
    CodeCoverage = @{
        Enabled                 = $true
        Path                    = @(
            '.\\Public\\*.ps1',
            '.\\Private\\*.ps1'
        )
        OutputFormat            = 'JaCoCo'
        OutputPath              = 'coverage.xml'
        OutputEncoding          = 'UTF8'
        CoveragePercentTarget   = 100
        ExcludeTests            = $true
        RecursePaths            = $true
    }
    TestResult = @{
        Enabled         = $true
        OutputFormat    = 'NUnitXml'
        OutputPath      = 'testResults.xml'
        OutputEncoding  = 'UTF8'
        TestSuiteName   = 'BridgeWatcher'
    }
    Should = @{
        ErrorAction = 'Stop'
    }
    Debug = @{
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = @('Mock', 'CodeCoverage')
        ShowFullErrors         = $false
        ShowNavigationMarkers  = $false
    }
    Output = @{
        Verbosity             = 'Detailed'
        StackTraceVerbosity   = 'Filtered'
        CIFormat              = 'GithubActions'
        CILogLevel            = 'Error'
        RenderMode            = 'Ansi'
    }
    TestDrive = @{
        Enabled = $true
    }
    TestRegistry = @{
        Enabled = $false
    }
}
