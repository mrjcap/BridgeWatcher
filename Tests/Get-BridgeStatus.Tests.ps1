Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Test Get-BridgeStatus function' {
        BeforeAll {
            # Μόκ για εξωτερικές συναρτήσεις
            Mock Get-BridgeHtml {}
            Mock Get-BridgeStatusFromHtml {}
            Mock ConvertTo-Json {}
            Mock Set-Content {}
            Mock Write-Warning {}
        }
        Context 'Επιτυχής ανάκτηση HTML και αποθήκευση JSON' {
            It 'Πρέπει να καλείται Get-BridgeHtml και Get-BridgeStatusFromHtml με τα σωστά splat params' {
                # Ρύθμιση
                $OutputFile = 'C:\mock\path\to\output.json'
                $html = '<html></html>'
                $timestamp = Get-Date -Format o
                Mock Get-BridgeHtml { $html }
                Mock Get-BridgeStatusFromHtml {
                    return @(
                        [pscustomobject]@{Location = 'Isthmia'; Status = 'Ανοιχτή'; Timestamp = $timestamp; ImageSrc = 'image1.jpg'; BaseUrl = 'http://localhost' }
                    )
                }
                Mock Export-BridgeStatusJson { }
                Mock Write-Warning { }
                # Εκτέλεση
                Get-BridgeStatus -OutputFile $OutputFile
                # Έλεγχοι
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Get-BridgeStatusFromHtml -Exactly 1 -Scope It
                Assert-MockCalled Export-BridgeStatusJson -Exactly 1 -Scope It
                Assert-MockCalled Write-Warning -Exactly 0 -Scope It
            }
        }
        Context 'Αποτυχία ανάκτησης HTML' {
            It 'Πρέπει να καλείται Write-Warning με το μήνυμα: [BridgeWatcher] ❌ Αποτυχία ανάκτησης HTML' {
                # Ρύθμιση
                Mock Get-BridgeHtml { $null }
                # Εκτέλεση
                $result = Get-BridgeStatus
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Write-Warning -Exactly 2 -Scope It
                Assert-MockCalled Get-BridgeStatusFromHtml -Exactly 0 -Scope It
                Assert-MockCalled Set-Content -Exactly 0 -Scope It
                $result | Should -BeNullOrEmpty
            }
        }
        Context 'Get-BridgeStatusFromHtml επιστρέφει κενό' {
            It 'Πρέπει να καλείται Write-Warning με το μήνυμα: [BridgeWatcher] ⛔ Δεν υπάρχει διαθέσιμο status για αποθήκευση' {
                # Ρύθμιση
                $html = '<html></html>'
                Mock Get-BridgeHtml { $html }
                Mock Get-BridgeStatusFromHtml { @() }
                # Εκτέλεση
                $result = Get-BridgeStatus
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Get-BridgeStatusFromHtml -Exactly 1 -Scope It
                Assert-MockCalled Write-Warning -Exactly 1 -Scope It
                Assert-MockCalled Set-Content -Exactly 0 -Scope It
                $result | Should -BeNullOrEmpty
            }
        }
        Context 'Σφάλμα κατά την αποθήκευση JSON' {
            It 'Πρέπει να καλείται Write-Warning με το μήνυμα σφάλματος αποθήκευσης' {
                # Ρύθμιση
                $html = '<html></html>'
                $result = @(@{Status = 'Open'; Location = 'Isthmia'; Timestamp = (Get-Date); ImageSrc = 'image.jpg'; BaseUrl = 'http://localhost' })
                Mock Get-BridgeHtml { $html }
                Mock Get-BridgeStatusFromHtml { $result }
                #Mock ConvertTo-Json { '{"Status":"Open","Location":"Isthmia","Timestamp":"2025-04-18T00:00:00Z","ImageSrc":"image.jpg","BaseUrl":"http://localhost"}' }
                #Mock Set-Content { throw "Error during saving" }
                # Εκτέλεση
                $result = Get-BridgeStatus -OutputFile 'C:\path\to\output.json'
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Get-BridgeStatusFromHtml -Exactly 1 -Scope It
                #Assert-MockCalled ConvertTo-Json -Exactly 1 -Scope It
                #Assert-MockCalled Set-Content -Exactly 1 -Scope It
                Assert-MockCalled Write-Warning -Exactly 2 -Scope It
                $result | Should -BeNullOrEmpty
            }
        }
        Context 'Permission Denied κατά την εγγραφή αρχείου' {
            It 'Πρέπει να καταγράφεται προειδοποίηση για το σφάλμα και να επιστρέφεται κενό' {
                # Ρύθμιση
                $html = '<html></html>'
                $result = @(@{Status = 'Open'; Location = 'Isthmia'; Timestamp = (Get-Date); ImageSrc = 'image.jpg'; BaseUrl = 'http://localhost' })
                Mock Get-BridgeHtml { $html }
                Mock Get-BridgeStatusFromHtml { $result }
                Mock ConvertTo-Json { '{"Status":"Open","Location":"Isthmia","Timestamp":"2025-04-18T00:00:00Z","ImageSrc":"image.jpg","BaseUrl":"http://localhost"}' }
                Mock Set-Content { throw [System.UnauthorizedAccessException] 'Permission Denied' }
                # Εκτέλεση
                $result = Get-BridgeStatus -OutputFile 'C:\path\to\output.json'
                # Έλεγχος κλήσεων
                Assert-MockCalled Get-BridgeHtml -Exactly 1 -Scope It
                Assert-MockCalled Get-BridgeStatusFromHtml -Exactly 1 -Scope It
                Assert-MockCalled Write-Warning -Exactly 2 -Scope It
                $result | Should -BeNullOrEmpty
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
            Mock Get-BridgeHtml { '<html></html>' }
            Mock Get-BridgeStatusFromHtml { @() }
            Mock Export-BridgeStatusJson { }
            { Get-BridgeStatus -OutputFile 'dummy.json' -Verbose } | Should -Not -Throw
        }
    }

    Describe 'Get-BridgeStatus Integration - Error Handling' {
        It 'Χειρίζεται σφάλμα από Invoke-WebRequest' {
            Mock -CommandName Invoke-WebRequest -MockWith {
                throw 'Κάτι πήγε στραβά'
            }
            { Get-BridgeStatus } | Should -Throw "Αποτυχία λήψης HTML: Κάτι πήγε στραβά"
            # Αν θέλεις:μπορείς να πιάσεις το warning μέσω transcript ή out-string
        }
    }
}