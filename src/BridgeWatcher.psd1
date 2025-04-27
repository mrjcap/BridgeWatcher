@{
    RootModule = 'BridgeWatcher.psm1'
    ModuleVersion = '1.0.0'
    GUID = '1e66a1b4-5f7e-42e2-a9ff-c32e3fc3fa33'
    Author = 'Γιάννης Καπλατζής'
    CompanyName = 'Open Source Community'
    Copyright = '(c) 2025 Γιάννης Καπλατζής. MIT License.'
    Description = 'Παρακολούθηση κατάστασης γεφυρών Ισθμίας & Ποσειδωνίας, με υποστήριξη OCR και ειδοποιήσεις Pushover.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-BridgeStatus',
        'Get-BridgePreviousStatus',
        'Get-BridgeStatusComparison',
        'Invoke-BridgeStatusComparison',
        'Invoke-BridgeClosedNotification',
        'Invoke-BridgeOpenedNotification',
        'Send-BridgePushover',
        'Start-BridgeStatusMonitor'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('HomeAssistant', 'Bridge', 'Pushover', 'OCR', 'Monitoring')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/mrjcap/BridgeWatcher'
            ReleaseNotes = 'Πρώτη επίσημη έκδοση.'
        }
    }
}