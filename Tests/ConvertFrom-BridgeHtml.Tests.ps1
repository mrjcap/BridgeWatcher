Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psm1" -Force

Describe 'ConvertFrom-BridgeHtml Tests' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-SafeBridgeConfiguration.ps1"
    }
        Context 'Configuration Error Handling' {
            It 'Returns BridgeResult with error when configuration initialization fails' {
                # Mock New-BridgeConfiguration to throw an error to trigger lines 45-47
                Mock New-BridgeConfiguration { throw "Configuration error" }
                Mock Write-BridgeLog { }

                $result = ConvertFrom-BridgeHtml -Html '<html>test</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Match 'Configuration initialization failed'
                $result.ErrorCode | Should -Be 'CONFIG_ERROR'
            }
        }

        Context 'No Bridges Found Scenario' {
            It 'Returns error when no bridges are found in HTML' {
                # Mock Get-BridgeStatusFromHtml to return empty array to trigger lines 67-74
                Mock Get-BridgeStatusFromHtml {
                    return @()  # Empty array - no bridges found
                }
                Mock Write-BridgeLog { }

                $result = ConvertFrom-BridgeHtml -Html '<html>no bridges</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο'
                $result.ErrorCode | Should -Be 'NO_BRIDGES_FOUND'

                # Verify that warning was logged - this covers lines 67-72
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and
                    $Message -eq '⛔ Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο' -and
                    $Level -eq 'Warning'
                } -Exactly 1
            }

            It 'Returns error when bridges result is null' {
                # Mock Get-BridgeStatusFromHtml to return null to trigger lines 67-74
                Mock Get-BridgeStatusFromHtml {
                    return $null
                }
                Mock Write-BridgeLog { }

                $result = ConvertFrom-BridgeHtml -Html '<html>invalid</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο'
                $result.ErrorCode | Should -Be 'NO_BRIDGES_FOUND'

                # Verify that warning was logged
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and
                    $Message -eq '⛔ Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο' -and
                    $Level -eq 'Warning' } -Exactly 1
            }
        }

        Context 'Successful Conversion' {
            It 'Returns successful result when bridges are found' {
                # Mock successful scenario to ensure normal path works
                Mock Get-BridgeStatusFromHtml {
                    return @(
                        @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                    )
                }
                Mock Write-BridgeLog { }

                $result = ConvertFrom-BridgeHtml -Html '<html>valid bridges</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data | Should -Not -BeNullOrEmpty
            }
        }
    }

