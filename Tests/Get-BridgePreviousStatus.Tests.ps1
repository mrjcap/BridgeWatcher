Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgePreviousStatus' {
    BeforeAll {
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

    It 'Χρησιμοποιεί συμβατές παραμέτρους ανάγνωσης JSON όταν IsLegacyPowerShell είναι true' {
        $savedLegacyEnv = $env:IsLegacyPowerShell
        try {
            $env:IsLegacyPowerShell = 'true'
            $mockData = @(
                @{
                    GefyraName   = 'Ισθμία'
                    GefyraStatus = 'Ανοιχτή'
                    ImageUrl     = 'https://example.com/isthmia.png'
                }
            )
            $jsonPath = 'TestDrive:\legacy_ps51_branch.json'
            $mockData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding utf8BOM
            $result = Get-BridgePreviousStatus -Configuration $script:Config -InputFile $jsonPath
            $result.Count | Should -Be 1
            $result[0].GefyraName | Should -Be 'Ισθμία'
        } finally {
            $env:IsLegacyPowerShell = $savedLegacyEnv
        }
    }

    It 'Διαβάζει αποθηκευμένο snapshot επιτυχώς σε Windows PowerShell 5.1 (powershell.exe)' -Skip:(-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
        $realFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "bw-ps51-$([guid]::NewGuid().ToString('N')).json"
        $moduleManifest = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../BridgeWatcher/BridgeWatcher.psd1'))
        try {
            $utf8Bom = [System.Text.UTF8Encoding]::new($true)
            [System.IO.File]::WriteAllText($realFile, '[{"GefyraName":"Ισθμία","GefyraStatus":"Ανοιχτή","ImageUrl":"https://example.com/1.png"}]', $utf8Bom)

            $ps51Script = @"
`$ErrorActionPreference = 'Stop'
Import-Module '$moduleManifest' -Force
`$cfg = New-BridgeConfiguration -LogDirectory ([System.IO.Path]::GetTempPath())
`$res = @(Get-BridgePreviousStatus -InputFile '$realFile' -Configuration `$cfg)
if (`$res.Count -ne 1 -or [string]::IsNullOrEmpty(`$res[0].GefyraStatus)) { exit 2 }
Write-Output 'PS51_OK'
"@
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($ps51Script))
            $output = & powershell.exe -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($output | Out-String)
            ($output | Out-String) | Should -Match 'PS51_OK'
        } finally {
            if (Test-Path -Path $realFile) {
                Remove-Item -Path $realFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
