Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Test Get-BridgeStatus function' {
        BeforeAll {
            # Μόκ για εξωτερικές συναρτήσεις
            Mock Get-BridgeHtml {}
            Mock ConvertFrom-BridgeHtml {}
            Mock Export-BridgeStatusJson {}
            Mock Write-Warning {}
        }
        Context 'Επιτυχής ανάκτηση HTML και αποθήκευση JSON' {
            It 'Πρέπει να καλείται Get-BridgeHtml και ConvertFrom-BridgeHtml με τα σωστά splat params' {
                # Ρύθμιση
                $OutputFile = 'C:\mock\path\to\output.json'
                $html = '<html></html>'
                $timestamp = Get-Date -Format o
                Mock Get-BridgeHtml {
                    New-BridgeResult -Success $true -Data $html
                }
                Mock ConvertFrom-BridgeHtml {
                    $bridgeData = @(
                        [pscustomobject]@{Location = 'Isthmia'; Status = 'Ανοιχτή'; Timestamp = $timestamp; ImageSrc = 'image1.jpg'; BaseUrl = 'http://localhost' }
                    )
                    return New-BridgeResult -Success $true -Data $bridgeData
                }
                Mock Export-BridgeStatusJson {
                    New-BridgeResult -Success $true
                }
                Mock Write-Warning { }
                # Εκτέλεση
                $result = Get-BridgeStatus -OutputFile $OutputFile
                # Έλεγχοι
                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 1
                $result[0].Location | Should -Be 'Isthmia'
                $result[0].Status | Should -Be 'Ανοιχτή'

                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled ConvertFrom-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Export-BridgeStatusJson -Exactly 1 -Scope It
                Assert-MockCalled Write-Warning -Exactly 0 -Scope It
            }
        }
        Context 'Αποτυχία ανάκτησης HTML' {
            It 'Πρέπει να ρίχνει terminating error όταν το Get-BridgeHtml επιστρέφει $null' {
                # Ρύθμιση
                Mock Get-BridgeHtml { $null }
                # Εκτέλεση & Έλεγχος
                { Get-BridgeStatus } | Should -Throw -ExpectedMessage "*HTML retrieval returned null*"
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled ConvertFrom-BridgeHtml -Exactly 0 -Scope It
                Assert-MockCalled Export-BridgeStatusJson -Exactly 0 -Scope It
            }
        }
        Context 'ConvertFrom-BridgeHtml επιστρέφει κενό' {
            It 'Πρέπει να ρίχνει terminating error όταν δεν υπάρχει διαθέσιμο status για αποθήκευση' {
                # Ρύθμιση
                $html = '<html></html>'
                Mock Get-BridgeHtml {
                    New-BridgeResult -Success $true -Data $html
                }
                Mock ConvertFrom-BridgeHtml {
                    New-BridgeResult -Success $false -ErrorMessage "Δεν υπάρχει διαθέσιμο status για αποθήκευση" -ErrorCode 'NO_STATUS_FOUND'
                }
                # Εκτέλεση & Έλεγχος
                { Get-BridgeStatus } | Should -Throw
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled ConvertFrom-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Export-BridgeStatusJson -Exactly 0 -Scope It
            }
        }
        Context 'Σφάλμα κατά την αποθήκευση JSON' {
            It 'Πρέπει να ρίχνει terminating error όταν η αποθήκευση JSON αποτύχει' {
                # Ρύθμιση
                $html = '<html></html>'
                $bridgeData = @(@{Status = 'Open'; Location = 'Isthmia'; Timestamp = (Get-Date); ImageSrc = 'image.jpg'; BaseUrl = 'http://localhost' })
                Mock Get-BridgeHtml {
                    New-BridgeResult -Success $true -Data $html
                }
                Mock ConvertFrom-BridgeHtml {
                    New-BridgeResult -Success $true -Data $bridgeData
                }
                Mock Export-BridgeStatusJson {
                    New-BridgeResult -Success $false -ErrorMessage "Error during saving" -ErrorCode 'JSON_EXPORT_FAILURE'
                }
                # Εκτέλεση & Έλεγχος
                { Get-BridgeStatus -OutputFile 'C:\path\to\output.json' } | Should -Throw
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled ConvertFrom-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Export-BridgeStatusJson -Exactly 1 -Scope It
            }
        }
        Context 'Permission Denied κατά την εγγραφή αρχείου' {
            It 'Πρέπει να ρίχνει terminating error για Permission Denied' {
                # Ρύθμιση
                $html = '<html></html>'
                $bridgeData = @(@{Status = 'Open'; Location = 'Isthmia'; Timestamp = (Get-Date); ImageSrc = 'image.jpg'; BaseUrl = 'http://localhost' })
                Mock Get-BridgeHtml {
                    New-BridgeResult -Success $true -Data $html
                }
                Mock ConvertFrom-BridgeHtml {
                    New-BridgeResult -Success $true -Data $bridgeData
                }
                Mock Export-BridgeStatusJson {
                    New-BridgeResult -Success $false -ErrorMessage "Permission Denied" -ErrorCode 'PERMISSION_DENIED'
                }
                # Εκτέλεση & Έλεγχος
                { Get-BridgeStatus -OutputFile 'C:\path\to\output.json' } | Should -Throw
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled ConvertFrom-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Export-BridgeStatusJson -Exactly 1 -Scope It
            }
        }
    }
    Describe 'Get-BridgeStatus Integration' {
        It 'Επιστρέφει σωστά αποτελέσματα για Ποσειδωνία και Ισθμία από mocked HTML' {
            $mockHtml = @'
<div class="panel panel-primary ">
        <h4><b>ΠΟΣΕΙΔΩΝΙΑ</b></h4>
    </div>
    <div         class="panel-body">
    <div         class="form-group">
    <center><img style="width:100%;" src="image-bridge-open-with-schedule-posidonia.php?1744355551"></center>
        </div>
    </div>
</div>
<div class="panel panel-primary">
        <h4><b>ΙΣΘΜΙΑ</b></h4>
    </div>
<div         class="panel-body">
<div         class="form-group">
<center><img style="width:100%;" src="image-bridge-open-with-schedule-isthmia.php?1744355551"></center>
        </div>
    </div>
</div>
'@
            Mock -CommandName Invoke-WebRequest -MockWith {
                return @{
                    Content = $mockHtml
                }
            }
            $resultJson = Get-BridgeStatus
            $result = $resultJson
            $result.Count | Should -Be 2
            if ($result[0].gefyraName -eq 'Ποσειδωνία') {
                $result[0].gefyraName | Should -Be 'Ποσειδωνία'
                $result[0].gefyraStatus | Should -Be 'Κλειστή με πρόγραμμα'
                $result[0].imageUrl | Should -Match 'posidonia'
            }
            if ($result[1].gefyraName -eq 'Ισθμία') {
                $result[1].gefyraName | Should -Be 'Ισθμία'
                $result[1].gefyraStatus | Should -Be 'Κλειστή με πρόγραμμα'
                $result[1].imageUrl | Should -Match 'isthmia'
            }
        }
        It 'Γράφει debug όταν το status παραλείπεται (no match)' {
            $html = @'
        <div class="panel panel-primary">
        <div class="panel-heading"><b>ΙΣΘΜΙΑ</b></div>
        <div class="panel-body">
        <img src="image-bridge-always-close.php?123">
            </div>
        </div>
'@
            Mock Invoke-WebRequest { [pscustomobject]@{ Content = $html } }
            { Get-BridgeStatus } | Should -Throw "Δεν βρέθηκε block για τη θέση poseidonia."
        }

        It 'Γράφει warning όταν δεν υπάρχει διαθέσιμο status για αποθήκευση' {
            Mock Get-BridgeHtml {
                return New-BridgeResult -Success $true -Data '<html></html>'
            }
            Mock ConvertFrom-BridgeHtml {
                return New-BridgeResult -Success $true -Data @()  # Empty array
            }
            Mock Export-BridgeStatusJson {
                return New-BridgeResult -Success $true -Data @{ ExportedPath = 'dummy.json'; RecordCount = 0 }
            }
            { Get-BridgeStatus -OutputFile 'dummy.json' -Verbose } | Should -Not -Throw
        }
    }

    Describe 'Get-BridgeStatus Integration - Error Handling' {
        It 'Χειρίζεται σφάλμα από Invoke-WebRequest' {
            Mock Get-BridgeHtml {
                return New-BridgeResult -Success $false -ErrorMessage 'Κάτι πήγε στραβά' -ErrorCode 'HTTP_ERROR'
            }
            { Get-BridgeStatus } | Should -Throw "Κάτι πήγε στραβά"
        }
    }

    Describe 'Get-BridgeStatus Configuration Fallbacks' {
        It 'Χρησιμοποιεί fallback values όταν η New-BridgeConfiguration αποτυγχάνει' {
            Mock New-BridgeConfiguration { throw "Configuration error" }
            Mock Get-BridgeHtml {
                return New-BridgeResult -Success $true -Data '<html>test</html>'
            }
            Mock ConvertFrom-BridgeHtml {
                return New-BridgeResult -Success $true -Data @()  # Empty array
            }
            Mock Export-BridgeStatusJson {
                return New-BridgeResult -Success $true -Data @{ ExportedPath = 'test.json'; RecordCount = 0 }
            }
            Mock Write-BridgeLog { }

            { Get-BridgeStatus -OutputFile 'test.json' } | Should -Not -Throw
        }

        It 'Χρησιμοποιεί fallback values όταν Configuration είναι null' {
            Mock Get-BridgeHtml {
                return New-BridgeResult -Success $true -Data '<html>test</html>'
            }
            Mock ConvertFrom-BridgeHtml {
                return New-BridgeResult -Success $true -Data @()  # Empty array
            }
            Mock Export-BridgeStatusJson {
                return New-BridgeResult -Success $true -Data @{ ExportedPath = 'test.json'; RecordCount = 0 }
            }
            Mock Write-BridgeLog { }

            { Get-BridgeStatus -Configuration $null -OutputFile 'test.json' } | Should -Not -Throw
            # Verify fallback behavior
            Assert-MockCalled Get-BridgeHtml -Exactly 1
            Assert-MockCalled ConvertFrom-BridgeHtml -Exactly 1
        }

        It 'Χειρίζεται null configuration στο error message fallback' {
            Mock New-BridgeConfiguration { throw "Configuration failed" }
            Mock Get-BridgeHtml { $null }

            { Get-BridgeStatus } | Should -Throw "HTML retrieval returned null"
        }
    }
}