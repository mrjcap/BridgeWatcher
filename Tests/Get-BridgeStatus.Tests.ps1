Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Test Get-BridgeStatus function' -Fixture {
    BeforeAll -Scriptblock {

        . "$PSScriptRoot/TestHelper.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"
        $script:Config = New-BridgeConfiguration

        Mock -CommandName Export-BridgeStatusJson -MockWith {
    }
        Mock -CommandName Write-Warning -MockWith {}
    }

    Context -Name 'Επιτυχής ανάκτηση HTML και αποθήκευση JSON' -Fixture {
        It -Name 'Πρέπει να καλείται Export-BridgeStatusJson με τα σωστά params' -Test {
            $OutputFile = 'C:\mock\path\to\output.json'
            $timestamp = Get-Date -Format o

            Mock -CommandName Invoke-WebRequest -MockWith {
                return [pscustomobject]@{ Content = '<html></html>' }
            }
            Mock -CommandName Get-BridgeStatusFromHtml -MockWith {
                return @(
                    [pscustomobject]@{Location = 'Isthmia'; Status = 'Ανοιχτή'; Timestamp = $timestamp; ImageSrc = 'image1.jpg'; BaseUrl = 'http://localhost' }
                )
            }
            Mock -CommandName Export-BridgeStatusJson -MockWith {
                New-BridgeResult -Success $true
            }
            Mock -CommandName Write-Warning -MockWith { }

            $result = Get-BridgeStatus -OutputFile $OutputFile -Configuration $script:Config

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be -ExpectedValue 1
            $result[0].Location | Should -Be -ExpectedValue 'Isthmia'
            $result[0].Status | Should -Be -ExpectedValue 'Ανοιχτή'

            Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly -Scope It -ParameterFilter {
                $TimeoutSec -eq $script:Config.Defaults.HttpRequestTimeout
            }
            Should -Invoke -CommandName Get-BridgeStatusFromHtml -Times 1 -Exactly -Scope It
            Should -Invoke -CommandName Export-BridgeStatusJson -Times 1 -Exactly -Scope It
        }
    }

    Context -Name 'Αποτυχία ανάκτησης HTML' -Fixture {
        It -Name 'Πρέπει να ρίχνει terminating error όταν το Invoke-WebRequest αποτυγχάνει' -Test {
            Mock -CommandName Invoke-WebRequest -MockWith { throw 'Σφάλμα δικτύου' }
            Mock -CommandName Start-Sleep -MockWith {}
            { Get-BridgeStatus -Configuration $script:Config } | Should -Throw -ExpectedMessage "*Σφάλμα δικτύου*"
            Should -Invoke -CommandName Invoke-WebRequest -Times 3 -Exactly -Scope It
            Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly -Scope It
        }
        It -Name 'Πρέπει να ρίχνει terminating error όταν το response είναι κενό' -Test {
            Mock -CommandName Invoke-WebRequest -MockWith { return [pscustomobject]@{ Content = $null } }
            { Get-BridgeStatus -Configuration $script:Config } | Should -Throw -ExpectedMessage "*The argument is null or empty*"
        }
    }

    Context -Name 'Get-BridgeStatusFromHtml επιστρέφει κενό' -Fixture {
        It -Name 'Πρέπει να ρίχνει terminating error όταν δεν υπάρχει διαθέσιμο status για αποθήκευση' -Test {
            Mock -CommandName Invoke-WebRequest -MockWith { return [pscustomobject]@{ Content = '<html></html>' } }
            Mock -CommandName Get-BridgeStatusFromHtml -MockWith { return @() }

            { Get-BridgeStatus -Configuration $script:Config } | Should -Throw -ExpectedMessage "*Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο*"
        }
    }

    Context -Name 'Σφάλμα κατά την αποθήκευση JSON' -Fixture {
        It -Name 'Πρέπει να ρίχνει terminating error όταν η αποθήκευση JSON αποτύχει' -Test {
            Mock -CommandName Invoke-WebRequest -MockWith { return [pscustomobject]@{ Content = '<html></html>' } }
            Mock -CommandName Get-BridgeStatusFromHtml -MockWith {
                return @( [pscustomobject]@{ Status = 'Open'; Location = 'Isthmia' } )
            }
            Mock -CommandName Export-BridgeStatusJson -MockWith {
                return New-BridgeResult -Success $false -ErrorMessage "Error during saving" -ErrorCode 'JSON_EXPORT_FAILURE'
            }

            { Get-BridgeStatus -Configuration $script:Config -OutputFile 'C:\path\to\output.json' } | Should -Throw -ExpectedMessage "*Error during saving*"
        }
    }
}

Describe -Name 'Get-BridgeStatus Integration' -Fixture {
    BeforeAll -Scriptblock {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It -Name 'Επιστρέφει σωστά αποτελέσματα για Ποσειδωνία και Ισθμία από mocked HTML' -Test {
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
        $result = Get-BridgeStatus -Configuration $script:Config
        $result.Count | Should -Be -ExpectedValue 2

        if ($result[0].GefyraName -eq 'Ποσειδωνία') {
            $result[0].GefyraName | Should -Be -ExpectedValue 'Ποσειδωνία'
            $result[0].GefyraStatus | Should -Be -ExpectedValue 'Κλειστή με πρόγραμμα'
        }
    }

    It -Name 'Ρίχνει σφάλμα όταν το html δεν περιέχει καμία γέφυρα' -Test {
        $html = @'
    <div class="panel panel-primary">
    <div class="panel-heading"><b>ΑΛΛΗΓΕΦΥΡΑ</b></div>
    </div>
'@
        Mock -CommandName Invoke-WebRequest -MockWith { return [pscustomobject]@{ Content = $html } }
        { Get-BridgeStatus -Configuration $script:Config } | Should -Throw -ExpectedMessage "*Δεν βρέθηκε block*"
    }

    It -Name 'Ρίχνει σφάλμα PARSING_ERROR όταν η μία γέφυρα δεν έχει έγκυρη εικόνα κατάστασης (partial scrape)' -Test {
        $partialHtml = @'
<div class="panel panel-primary ">
        <h4><b>ΠΟΣΕΙΔΩΝΊΑ</b></h4>
    </div>
    <div class="panel-body">
    <div class="form-group">
    <center><img style="width:100%;" src="image-bridge-open-no-schedule.php?1744355551"></center>
    <img src="info.php?1744355551">
        </div>
    </div>
</div>
<div class="panel panel-primary">
        <h4><b>ΙΣΘΜΊΑ</b></h4>
    </div>
<div class="panel-body">
<div class="form-group">
<center><img style="width:100%;" src="unrecognized-placeholder.png"></center>
        </div>
    </div>
</div>
'@
        Mock -CommandName Invoke-WebRequest -MockWith { return [pscustomobject]@{ Content = $partialHtml } }
        { Get-BridgeStatus -Configuration $script:Config } | Should -Throw -ErrorId '*PARSING_ERROR*'
    }
}

Describe -Name 'Get-BridgeStatus Configuration Fallbacks' -Fixture {
    BeforeAll -Scriptblock {
        . "$PSScriptRoot/TestHelper.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"
    }



    It -Name 'Χρησιμοποιεί σωστό configuration όταν περνιέται ρητά' -Test {
        Mock -CommandName Invoke-WebRequest -MockWith { return [pscustomobject]@{ Content = '<html>test</html>' } }
        Mock -CommandName Get-BridgeStatusFromHtml -MockWith {
            return @( [pscustomobject]@{ Status = 'Open'; Location = 'Isthmia' } )
        }
        Mock -CommandName Export-BridgeStatusJson -MockWith {
            return New-BridgeResult -Success $true
        }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $config = New-BridgeConfiguration
        { Get-BridgeStatus -Configuration $config -OutputFile 'test.json' } | Should -Not -Throw
        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly
        Should -Invoke -CommandName Get-BridgeStatusFromHtml -Times 1 -Exactly
    }
}
