Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeStatus BridgeResult Behavior Tests' {
        BeforeEach {
            Mock Write-BridgeLog {}
        }

        Context 'CRIT-001: Configuration Fallback' {
            It 'Returns BridgeResult when New-BridgeConfiguration fails' {
                Mock New-BridgeConfiguration { throw "Configuration error" }
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $false -ErrorMessage 'Network error' -ErrorCode 'HTTP_ERROR'
                }

                $result = Get-BridgeStatus

                $result | Should -Not -BeNullOrEmpty
                $result.GetType().Name | Should -Be 'PSCustomObject'
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'HTTP_ERROR'
            }

            It 'Uses fallback configuration when New-BridgeConfiguration throws' {
                Mock New-BridgeConfiguration { throw "Configuration error" }
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>test</html>'
                }
                Mock ConvertFrom-BridgeHtml {
                    return New-BridgeResult -Success $true -Data @()
                }

                $result = Get-BridgeStatus

                # Should not throw and should call Get-BridgeHtml with fallback config
                $result | Should -Not -BeNullOrEmpty
                Assert-MockCalled Get-BridgeHtml -Exactly 1
            }
        }

        Context 'CRIT-002: No ThrowTerminatingError' {
            It 'Returns BridgeResult instead of throwing when HTML retrieval returns null' {
                Mock Get-BridgeHtml { $null }

                $result = Get-BridgeStatus

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'HTML retrieval returned null'
                $result.ErrorCode | Should -Be 'HTML_NULL'
            }

            It 'Returns BridgeResult instead of throwing when HTML retrieval fails' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $false -ErrorMessage 'Network error' -ErrorCode 'HTTP_ERROR'
                }

                $result = Get-BridgeStatus

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Network error'
                $result.ErrorCode | Should -Be 'HTTP_ERROR'
            }

            It 'Returns BridgeResult instead of throwing when HTML parsing fails' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>test</html>'
                }
                Mock ConvertFrom-BridgeHtml {
                    return New-BridgeResult -Success $false -ErrorMessage 'Parse error' -ErrorCode 'PARSE_ERROR'
                }

                $result = Get-BridgeStatus

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Parse error'
                $result.ErrorCode | Should -Be 'PARSE_ERROR'
            }

            It 'Returns BridgeResult instead of throwing when JSON export fails' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>test</html>'
                }
                Mock ConvertFrom-BridgeHtml {
                    return New-BridgeResult -Success $true -Data @()
                }
                Mock Export-BridgeStatusJson {
                    return New-BridgeResult -Success $false -ErrorMessage 'Export error' -ErrorCode 'EXPORT_ERROR'
                }

                $result = Get-BridgeStatus -OutputFile 'test.json'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Export error'
                $result.ErrorCode | Should -Be 'EXPORT_ERROR'
            }
        }

        Context 'CRIT-003: Always Return BridgeResult' {
            It 'Returns BridgeResult object on success' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>test</html>'
                }
                Mock ConvertFrom-BridgeHtml {
                    $mockData = @(
                        [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }
                    )
                    return New-BridgeResult -Success $true -Data $mockData
                }

                $result = Get-BridgeStatus

                $result | Should -Not -BeNullOrEmpty
                $result.GetType().Name | Should -Be 'PSCustomObject'
                $result.Success | Should -Be $true
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.Count | Should -Be 1
                $result.Data[0].GefyraName | Should -Be 'Ισθμία'
            }

            It 'Returns complete BridgeResult with all required properties' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>test</html>'
                }
                Mock ConvertFrom-BridgeHtml {
                    return New-BridgeResult -Success $true -Data @()
                }

                $result = Get-BridgeStatus

                $result | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties.Name | Should -Contain 'Success'
                $result.PSObject.Properties.Name | Should -Contain 'Data'
                $result.PSObject.Properties.Name | Should -Contain 'ErrorMessage'
                $result.PSObject.Properties.Name | Should -Contain 'ErrorCode'
                $result.PSObject.Properties.Name | Should -Contain 'Timestamp'
            }
        }

        Context 'Backward Compatibility Verification' {
            It 'Data property contains the bridge status array when successful' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>test</html>'
                }
                Mock ConvertFrom-BridgeHtml {
                    $mockData = @(
                        [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' },
                        [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή' }
                    )
                    return New-BridgeResult -Success $true -Data $mockData
                }

                $result = Get-BridgeStatus

                $result.Success | Should -Be $true
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.Count | Should -Be 2
                $result.Data[0].GefyraName | Should -Be 'Ισθμία'
                $result.Data[1].GefyraName | Should -Be 'Ποσειδωνία'
            }
        }
    }
}