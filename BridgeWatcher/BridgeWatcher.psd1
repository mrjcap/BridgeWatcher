@{
    RootModule = 'BridgeWatcher.psm1'
    ModuleVersion = '1.0.16'
    GUID = 'e7c0fd85-a740-47f4-8179-d952e33edb9f'
    Author = 'Γιάννης Καπλατζής'
    CompanyName = 'Open Source Community'
    Copyright = '(c) 2025 Γιάννης Καπλατζής. MIT License.'
    Description = 'Παρακολούθηση κατάστασης γεφυρών Ισθμίας & Ποσειδωνίας, με υποστήριξη OCR και ειδοποιήσεις Pushover.'
    PowerShellVersion = '5.1'
    RequiredModules      = @()
    RequiredAssemblies   = @()
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    FunctionsToExport = @(
        'Get-BridgeStatus',
        'Get-BridgePreviousStatus',
        'Get-BridgeStatusComparison',
        'Invoke-BridgeStatusComparison',
        'Send-BridgePushover',
        'Start-BridgeStatusMonitor'
    )
    PrivateData = @{
        PSData = @{
            Tags       = @('Bridge', 'Monitoring', 'Pushover', 'OCR')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/mrjcap/BridgeWatcher'
            ReleaseNotes = 'Πρώτη επίσημη έκδοση.'
        }
    }
}














