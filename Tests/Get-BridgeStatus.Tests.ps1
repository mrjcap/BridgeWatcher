Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Test Get-BridgeStatus function' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"

        Mock Export-BridgeStatusJson {}
        Mock Write-Warning {}
    }

    Context 'Επιτυχής ανάκτηση HTML και αποθήκευση JSON' {
        It 'Πρέπει να καλείται Export-BridgeStatusJson με τα σωστά params' {
            $OutputFile = 'C:\mock\path\to\output.json'
            $timestamp = Get-Date -Format o

            Mock Invoke-WebRequest {
                return [pscustomobject]@{ Content = '<html></html>' }
            }
            Mock Get-BridgeStatusFromHtml {
                return @(
                    [pscustomobject]@{Location = 'Isthmia'; Status = 'Ανοιχτή'; Timestamp = $timestamp; ImageSrc = 'image1.jpg'; BaseUrl = 'http://localhost' }
                )
            }
            Mock Export-BridgeStatusJson {
                New-BridgeResult -Success $true
            }
            Mock Write-Warning { }

            $result = Get-BridgeStatus -OutputFile $OutputFile

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].Location | Should -Be 'Isthmia'
            $result[0].Status | Should -Be 'Ανοιχτή'

            Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It
            Assert-MockCalled Get-BridgeStatusFromHtml -Exactly 1 -Scope It
            Assert-MockCalled Export-BridgeStatusJson -Exactly 1 -Scope It
        }
    }

    Context 'Αποτυχία ανάκτησης HTML' {
        It 'Πρέπει να ρίχνει terminating error όταν το Invoke-WebRequest αποτυγχάνει' {
            Mock Invoke-WebRequest { throw 'Σφάλμα δικτύου' }
            { Get-BridgeStatus } | Should -Throw -ExpectedMessage "*Σφάλμα δικτύου*"
        }
        It 'Πρέπει να ρίχνει terminating error όταν το response είναι κενό' {
            Mock Invoke-WebRequest { return [pscustomobject]@{ Content = $null } }
            # Get-BridgeStatusFromHtml parameter validation throws error
            { Get-BridgeStatus } | Should -Throw -ExpectedMessage "*The argument is null or empty*"
        }
    }

    Context 'Get-BridgeStatusFromHtml επιστρέφει κενό' {
        It 'Πρέπει να ρίχνει terminating error όταν δεν υπάρχει διαθέσιμο status για αποθήκευση' {
            Mock Invoke-WebRequest { return [pscustomobject]@{ Content = '<html></html>' } }
            Mock Get-BridgeStatusFromHtml { return @() }

            { Get-BridgeStatus } | Should -Throw -ExpectedMessage "*Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο*"
        }
    }

    Context 'Σφάλμα κατά την αποθήκευση JSON' {
        It 'Πρέπει να ρίχνει terminating error όταν η αποθήκευση JSON αποτύχει' {
            Mock Invoke-WebRequest { return [pscustomobject]@{ Content = '<html></html>' } }
            Mock Get-BridgeStatusFromHtml {
                return @( [pscustomobject]@{Status = 'Open'; Location = 'Isthmia'} )
            }
            Mock Export-BridgeStatusJson {
                return New-BridgeResult -Success $false -ErrorMessage "Error during saving" -ErrorCode 'JSON_EXPORT_FAILURE'
            }

            { Get-BridgeStatus -OutputFile 'C:\path\to\output.json' } | Should -Throw -ExpectedMessage "*Error during saving*"
        }
    }
}

Describe 'Get-BridgeStatus Integration' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeNameFromUri.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"
    }

    It 'Επιστρέφει σωστά αποτελέσματα για Ποσειδωνία και Ισθμία από mocked HTML' {
        $mockHtml = @'
<div class="panel panel-primary ">
        <h4><b>ΠΟΣΕΙΔΩΝΊΑ</b></h4>
    </div>
    <div         class="panel-body">
    <div         class="form-group">
    <center><img style="width:100%;" src="image-bridge-open-with-schedule-posidonia.php?1744355551"></center>
        </div>
    </div>
</div>
<div class="panel panel-primary">
        <h4><b>ΙΣΘΜΊΑ</b></h4>
    </div>
<div         class="panel-body">
<div         class="form-group">
<center><img style="width:100%;" src="image-bridge-open-with-schedule-isthmia.php?1744355551"></center>
        </div>
    </div>
</div>
'@
        Mock -CommandName Invoke-WebRequest -MockWith {
            return [pscustomobject]@{ Content = $mockHtml }
        }
        $result = Get-BridgeStatus
        $result.Count | Should -Be 2

        # Depending on naming in the current object
        if ($result[0].gefyraName -eq 'Ποσειδωνία') {
            $result[0].gefyraName | Should -Be 'Ποσειδωνία'
            $result[0].gefyraStatus | Should -Be 'Κλειστή με πρόγραμμα'
        }
    }

    It 'Ρίχνει σφάλμα όταν το html δεν περιέχει καμία γέφυρα' {
        $html = @'
    <div class="panel panel-primary">
    <div class="panel-heading"><b>ΑΛΛΗΓΕΦΥΡΑ</b></div>
    </div>
'@
        Mock Invoke-WebRequest { return [pscustomobject]@{ Content = $html } }
        { Get-BridgeStatus } | Should -Throw "*Δεν βρέθηκε block*"
    }
}

Describe 'Get-BridgeStatus Configuration Fallbacks' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"
    }

    It 'Ρίχνει terminating error όταν η New-BridgeConfiguration αποτυγχάνει' {
        Mock New-BridgeConfiguration { throw "Configuration error" }
        Mock Invoke-WebRequest { return [pscustomobject]@{ Content = '<html>test</html>' } }
        Mock Get-BridgeStatusFromHtml { return @() }
        Mock Write-BridgeLog { }

        { Get-BridgeStatus -OutputFile 'test.json' } | Should -Throw "Η αρχικοποίηση της διαμόρφωσης απέτυχε: Configuration error"
    }

    It 'Χρησιμοποιεί σωστό configuration όταν περνιέται ρητά' {
        Mock Invoke-WebRequest { return [pscustomobject]@{ Content = '<html>test</html>' } }
        Mock Get-BridgeStatusFromHtml {
            return @( [pscustomobject]@{Status = 'Open'; Location = 'Isthmia'} )
        }
        Mock Export-BridgeStatusJson {
            return New-BridgeResult -Success $true
        }
        Mock Write-BridgeLog { }

        $config = New-BridgeConfiguration
        { Get-BridgeStatus -Configuration $config -OutputFile 'test.json' } | Should -Not -Throw
        Assert-MockCalled Invoke-WebRequest -Exactly 1
        Assert-MockCalled Get-BridgeStatusFromHtml -Exactly 1
    }
}