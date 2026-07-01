Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgePreviousStatus' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgePreviousStatus.ps1"
    }

    It 'Επιστρέφει αντικείμενα από έγκυρο JSON αρχείο' {
        $mockData = @(
            @{
                Bridge = 'Ποσειδωνία'
                Status = 'Κλειστή με πρόγραμμα'
                Source = 'https://example.com/image.png'
            },
            @{
                Bridge = 'Ισθμία'
                Status = 'Ανοιχτή'
                Source = 'https://example.com/image2.png'
            }
        )
        $jsonPath = "TestDrive:\mock_previous_status.json"
        $mockData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
        $result = Get-BridgePreviousStatus -InputFile $jsonPath
        $result.Count | Should -Be 2
        $result[0].Bridge | Should -Be 'Ποσειδωνία'
        $result[1].Status | Should -Be 'Ανοιχτή'
    }
    It 'Επιστρέφει κενό array αν το αρχείο δεν υπάρχει' {
        $path = "TestDrive:\nonexistent.json"
        $result = Get-BridgePreviousStatus -InputFile $path
        $result | Should -Be @()
    }
    It 'Ρίχνει σφάλμα αν το JSON είναι άκυρο' {
        $badFile = "TestDrive:\invalid.json"
        '💩 not valid json' | Set-Content -Path $badFile -Encoding UTF8
        { Get-BridgePreviousStatus -InputFile $badFile } | Should -Throw
    }
}
