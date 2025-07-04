Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeStatus Refactored Pipeline Tests' {
        BeforeEach {
            Mock Write-BridgeLog
        }
        Context 'New Pipeline Data Flow - Backward Compatibility' {
            It 'Returns raw data array for successful operation' {
                # Mock successful HTML retrieval
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>mock data</html>'
                }

                # Mock successful bridge status parsing
                Mock ConvertFrom-BridgeHtml {
                    $bridgeData = @(
                        @{
                            gefyraName   = 'Ισθμία'
                            gefyraStatus = 'Ανοιχτή'
                            timestamp    = '2023-01-01T12:00:00'
                        }
                    )
                    return New-BridgeResult -Success $true -Data $bridgeData
                }

                $result = Get-BridgeStatus

                $result | Should -Not -BeNullOrEmpty

                # Handle both single item and array cases
                if ($result -is [Array]) {
                    $result.Count | Should -BeGreaterThan 0
                    $result[0].gefyraName | Should -Be 'Ισθμία'
                    $result[0].gefyraStatus | Should -Be 'Ανοιχτή'
                } else {
                    $result.gefyraName | Should -Be 'Ισθμία'
                    $result.gefyraStatus | Should -Be 'Ανοιχτή'
                }
            }
            It 'Throws terminating error when HTML retrieval fails' {
                # Mock failed HTML retrieval
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $false -ErrorMessage 'Network error' -ErrorCode 'HTTP_ERROR'
                }
                { Get-BridgeStatus } | Should -Throw 'Network error'
            }
            It 'Throws terminating error when HTML parsing fails' {
                # Mock successful HTML retrieval
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>mock data</html>'
                }

                # Mock failed bridge status parsing
                Mock ConvertFrom-BridgeHtml {
                    return New-BridgeResult -Success $false -ErrorMessage 'Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο' -ErrorCode 'NO_BRIDGES_FOUND'
                }

                { Get-BridgeStatus } | Should -Throw 'Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο'
            }
            It 'Throws terminating error for null HTML return' {
                Mock Get-BridgeHtml { $null }
                { Get-BridgeStatus } | Should -Throw 'HTML retrieval returned null'
            }
            It 'Can use Test-BridgeResult to check success internally' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>mock data</html>'
                }

                Mock ConvertFrom-BridgeHtml {
                    $bridgeData = @(
                        @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                    )
                    return New-BridgeResult -Success $true -Data $bridgeData
                }

                $result = Get-BridgeStatus

                # Get-BridgeStatus returns raw data, but we can test that it worked
                $result | Should -Not -BeNullOrEmpty

                # Handle both single item and array cases
                if ($result -is [Array]) {
                    $result.Count | Should -BeGreaterThan 0
                    $result[0].gefyraName | Should -Be 'Ισθμία'
                } else { $result.gefyraName | Should -Be 'Ισθμία'
                }
            }
        }

        Context 'Export Functionality' {
            It 'Exports successfully when OutputFile is provided' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>mock data</html>'
                }

                Mock ConvertFrom-BridgeHtml {
                    $bridgeData = @(
                        @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                    )
                    return New-BridgeResult -Success $true -Data $bridgeData
                }

                Mock Export-BridgeStatusJson {
                    return New-BridgeResult -Success $true -Data @{ ExportedPath = $Path; RecordCount = 1 }
                }

                $result = Get-BridgeStatus -OutputFile 'test.json'

                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -BeGreaterThan 0
                Assert-MockCalled Export-BridgeStatusJson -Exactly 1
            }

            It 'Throws error when export fails' {
                Mock Get-BridgeHtml {
                    return New-BridgeResult -Success $true -Data '<html>mock data</html>'
                }

                Mock ConvertFrom-BridgeHtml {
                    $bridgeData = @(
                        @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                    )
                    return New-BridgeResult -Success $true -Data $bridgeData
                }

                Mock Export-BridgeStatusJson {
                    return New-BridgeResult -Success $false -ErrorMessage 'Directory not found' -ErrorCode 'DIRECTORY_NOT_EXISTS'
                }

                { Get-BridgeStatus -OutputFile 'invalid/path/test.json' } | Should -Throw 'Directory not found'
            }
        }
    }
    Describe 'ConvertFrom-BridgeHtml' {
        Context 'Configuration Error Handling' {
            It 'Returns BridgeResult with error when configuration initialization fails' {
                # Mock New-BridgeConfiguration to throw an error
                Mock New-BridgeConfiguration { throw "Configuration error" }

                $result = ConvertFrom-BridgeHtml -Html '<html>test</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Match 'Configuration initialization failed'
                $result.ErrorCode | Should -Be 'CFG-001'
            }
        }

        Context 'No Bridges Found Scenario' {
            It 'Returns error when no bridges are found in HTML' {
                Mock Get-BridgeStatusFromHtml {
                    return @()  # Empty array - no bridges found
                }
                Mock Write-BridgeLog { }

                $result = ConvertFrom-BridgeHtml -Html '<html>no bridges</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο'
                $result.ErrorCode | Should -Be 'NO_BRIDGES_FOUND'                # Verify that warning was logged
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and
                    $Message -eq '⛔ Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο' -and
                    $Level -eq 'Warning'
                } -Exactly 1
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

        Context 'General Exception Handling' {
            It 'Returns BridgeResult with error when Get-BridgeStatusFromHtml throws exception' {
                # Mock Get-BridgeStatusFromHtml to throw an exception
                Mock Get-BridgeStatusFromHtml { throw "Unexpected parsing error" }
                Mock Write-BridgeLog { }

                $result = ConvertFrom-BridgeHtml -Html '<html>test</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Unexpected parsing error'
                $result.ErrorCode | Should -Be 'PAR-002'

                # Verify that error was logged
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and
                    $Message -match '❌ Σφάλμα κατά την ανάλυση HTML' -and
                    $Level -eq 'Warning'
                } -Exactly 1
            }
            It 'Returns BridgeResult with error when New-BridgeResult throws exception during success path' {
                # Mock Get-BridgeStatusFromHtml to return valid data
                Mock Get-BridgeStatusFromHtml {
                    return @(
                        @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                    )
                }
                Mock Write-BridgeLog { }
                # Mock New-BridgeResult to throw on success path (second call)
                Mock New-BridgeResult {
                    if ($Success -eq $true) {
                        throw "BridgeResult creation error"
                    }
                    return [PSCustomObject]@{
                        Success      = $false
                        ErrorMessage = $ErrorMessage
                        ErrorCode    = $ErrorCode
                        Timestamp    = Get-Date -Format o
                    }
                }

                $result = ConvertFrom-BridgeHtml -Html '<html>test</html>'

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'BridgeResult creation error'
                $result.ErrorCode | Should -Be 'PAR-002'

                # Verify that error was logged
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and
                    $Message -match '❌ Σφάλμα κατά την ανάλυση HTML' -and
                    $Level -eq 'Warning'
                } -Exactly 1
            }
        }
    }
} # End InModuleScope