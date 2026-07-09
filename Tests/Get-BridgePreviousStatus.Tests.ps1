Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgePreviousStatus' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgePreviousStatus.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It 'Επιστρέφει αντικείμενα από έγκυρο JSON αρχείο' {
        $mockData = @(
            @{
                GefyraName   = 'Ποσειδωνία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                ImageUrl     = 'https://example.com/image.png'
            },
            @{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Ανοιχτή'
                ImageUrl     = 'https://example.com/image2.png'
            }
        )
        $jsonPath = "TestDrive:\mock_previous_status.json"
        $mockData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
        $result = Get-BridgePreviousStatus -Configuration $script:Config -InputFile $jsonPath
        $result.Count | Should -Be 2
        $result[0].GefyraName | Should -Be 'Ποσειδωνία'
        $result[1].GefyraStatus | Should -Be 'Ανοιχτή'
    }
    It 'Επιστρέφει κενό array αν το αρχείο δεν υπάρχει' {
        $path = "TestDrive:\nonexistent.json"
        $result = Get-BridgePreviousStatus -Configuration $script:Config -InputFile $path
        $result | Should -Be @()
    }
    It 'Ρίχνει σφάλμα αν το JSON είναι άκυρο' {
        $badFile = "TestDrive:\invalid.json"
        '💩 not valid json' | Set-Content -Path $badFile -Encoding UTF8
        { Get-BridgePreviousStatus -Configuration $script:Config -InputFile $badFile } | Should -Throw
    }
    It 'Backfills ImageHash as $null when property is missing from old state files' {
        $legacyData = @(
            @{
                GefyraName   = 'Ποσειδωνία'
                GefyraStatus = 'Ανοιχτή'
                ImageUrl     = 'https://example.com/img.png'
            }
        )
        $jsonPath = "TestDrive:\legacy_no_hash.json"
        $legacyData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
        $result = Get-BridgePreviousStatus -Configuration $script:Config -InputFile $jsonPath
        $result.ImageHash | Should -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain 'ImageHash'
    }
    It 'Επιστρέφει κενό array αν το JSON είναι έγκυρο αλλά δεν περιέχει εγγραφές με GefyraName' {
        $mockData = @(
            @{ foo = 'bar' },
            @{ something = 'else' }
        )
        $jsonPath = "TestDrive:\valid_but_no_gefyraname.json"
        $mockData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
        $result = Get-BridgePreviousStatus -Configuration $script:Config -InputFile $jsonPath
        $result | Should -Be @()
    }
}
