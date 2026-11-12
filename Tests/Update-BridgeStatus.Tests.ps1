Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
. "$PSScriptRoot/TestHelper.ps1"

InModuleScope BridgeWatcher {
    Describe 'Update-BridgeStatus' {
        BeforeAll {
            $script:Config = New-BridgeConfiguration

            function script:Initialize-TwoBridgeDiffMock {
                <#
                .SYNOPSIS
                Initializes mocks for two-bridge partial alert tests.
                #>
                param(
                    [object[]]$PreviousEntries = @(),
                    [object[]]$ExtraCurrentEntries = @()
                )
                $b1 = [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-04-25T10:00:00' }
                $b2 = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T10:00:00' }
                $hasPrevious = $PreviousEntries.Count -gt 0
                Mock Test-Path { return $hasPrevious }.GetNewClosure()
                if ($hasPrevious) {
                    Mock Get-BridgePreviousStatus { return $PreviousEntries }.GetNewClosure()
                }
                $allCurrent = @($ExtraCurrentEntries) + @($b1, $b2)
                Mock Get-BridgeStatus { return $allCurrent }.GetNewClosure()
                Mock Invoke-BridgeStatusComparison {
                    return @(
                        [PSCustomObject]@{ BridgeName = 'Ποσειδωνία'; Type = 'Closed'; StateInfo = @($b1) },
                        [PSCustomObject]@{ BridgeName = 'Ισθμία'; Type = 'Opened'; StateInfo = @($b2) }
                    )
                }.GetNewClosure()
                $script:capturedExports = @()
                Mock Export-BridgeStatusJson {
                    $script:capturedExports += , @($Data)
                    return New-BridgeResult -Success $true
                }
                Mock Write-BridgeLog { }
            }
        }

        It 'Εκτελεί όλες τις βασικές λειτουργίες χωρίς σφάλμα' {
            $jsonFile = 'TestDrive:\bridge_status_test.json'
            Mock Get-BridgePreviousStatus {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' },
                    [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }
                )
            } -ParameterFilter { $InputFile -eq $jsonFile }
            Mock Get-BridgeStatus -MockWith {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' },
                    [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }
                )
            }
            Mock Invoke-BridgeStatusComparison {}
            Mock Export-BridgeStatusJson {
                New-BridgeResult -Success $true
            }
            Mock Write-Verbose {}

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Not -Throw
        }

        It 'Πρέπει να καλούνται Get-BridgePreviousStatus και Get-BridgeStatus με τα σωστά parameters όταν το αρχείο υπάρχει' {
            $jsonFile = 'TestDrive:\bridge_status_test_exists.json'

            Mock Test-Path { return $true }

            Mock Get-BridgePreviousStatus {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; From = '00:00'; ImageHash = 'abc' }
                )
            }
            Mock Get-BridgeStatus -MockWith {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }
                )
            }
            Mock Invoke-BridgeStatusComparison {
                return @(
                    [PSCustomObject]@{ Type = 'Closed'; StateInfo = @{ GefyraName = 'Ποσειδωνία' } },
                    [PSCustomObject]@{ Type = 'Opened'; StateInfo = @{ GefyraName = 'Ισθμία' } }
                )
            }
            Mock Export-BridgeStatusJson {
                New-BridgeResult -Success $true
            }
            Mock Write-Verbose {}
            Mock Invoke-BridgeClosedNotification {}
            Mock Invoke-BridgeOpenedNotification {}

            $updateBridgeStatusSplat = @{
                OutputFile    = $jsonFile
                ApiKey        = 'dummyApiKey'
                PoUserKey     = 'dummyPoUserKey'
                PoApiKey      = 'dummyPoApiKey'
                Configuration = $script:Config
            }
            { Update-BridgeStatus @updateBridgeStatusSplat } | Should -Not -Throw

            Should -Invoke -CommandName Get-BridgeStatus -Times 1 -Exactly -Scope It
            Should -Invoke -CommandName Invoke-BridgeStatusComparison -Times 1 -Exactly -Scope It
            Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1 -Exactly -Scope It
            Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly -Scope It
        }

        It 'Εκτελείται σωστά με -WhatIf και δεν καλεί Invoke/Export' {
            $jsonFile = 'TestDrive:\bridge_status_whatif.json'

            Mock Test-Path { return $true }
            Mock Get-BridgePreviousStatus { return @() }
            Mock Get-BridgeStatus { return @() }
            Mock Invoke-BridgeStatusComparison {}
            Mock Export-BridgeStatusJson {}
            Mock Write-BridgeLog {}

            Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k' -WhatIf

            Should -Not -Invoke -CommandName Invoke-BridgeStatusComparison -Scope It
            Should -Not -Invoke -CommandName Export-BridgeStatusJson -Scope It
            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -eq 'Finished comparison and saved snapshot.' } -Times 1 -Scope It
        }

        It 'Ρίχνει terminating error όταν η Export-BridgeStatusJson επιστρέφει Success = $false' {
            $jsonFile = 'TestDrive:\bridge_status_export_fail.json'

            Mock Test-Path { return $false }
            Mock Get-BridgeStatus { return @([PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }) }
            Mock Invoke-BridgeStatusComparison { return @() }
            Mock Export-BridgeStatusJson {
                return New-BridgeResult -Success $false -ErrorMessage 'Disk full' -ErrorCode 'JSON_EXPORT_FAILURE'
            }
            Mock Write-BridgeLog {}

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*Disk full*'
        }

        It 'Αποθηκεύει μόνο την επιτυχημένη γέφυρα σε cold start όταν αποτυγχάνει η δεύτερη ειδοποίηση και επαναρίχνει το σφάλμα' {
            Initialize-TwoBridgeDiffMock
            Mock Invoke-BridgeClosedNotification { }
            Mock Invoke-BridgeOpenedNotification { throw 'Bridge 2 Pushover timeout' }

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_cold_partial.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*Bridge 2 Pushover timeout*'

            Should -Invoke -CommandName Export-BridgeStatusJson -Times 1 -Exactly -Scope It
            $saved = @($script:capturedExports[0])
            $saved.Count | Should -Be 1
            $saved[0].GefyraName | Should -Be 'Ποσειδωνία'
            $saved[0].GefyraStatus | Should -Be 'Κλειστή για συντήρηση'
        }

        It 'Αποθηκεύει τη νέα κατάσταση της πρώτης γέφυρας, τις αμετάβλητες και την προηγούμενη της αποτυχημένης όταν υπάρχει ιστορικό' {
            $prevEntries = @(
                [PSCustomObject]@{ GefyraName = 'Κόρινθος'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T09:55:00' },
                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T09:55:00' },
                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-04-25T09:55:00'; From = '10:00' }
            )
            $unchangedCurrent = @([PSCustomObject]@{ GefyraName = 'Κόρινθος'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T10:00:00' })
            Initialize-TwoBridgeDiffMock -PreviousEntries $prevEntries -ExtraCurrentEntries $unchangedCurrent
            Mock Invoke-BridgeClosedNotification { }
            Mock Invoke-BridgeOpenedNotification { throw 'Bridge 2 Pushover HTTP 503' }

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_warm_partial.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*Bridge 2 Pushover HTTP 503*'

            Should -Invoke -CommandName Export-BridgeStatusJson -Times 1 -Exactly -Scope It
            $saved = @($script:capturedExports[0])
            $saved.Count | Should -Be 3
            ($saved | Where-Object { $_.GefyraName -eq 'Κόρινθος' }).Timestamp | Should -Be '2025-04-25T10:00:00'
            ($saved | Where-Object { $_.GefyraName -eq 'Ποσειδωνία' }).GefyraStatus | Should -Be 'Κλειστή για συντήρηση'
            $isthmiaSaved = $saved | Where-Object { $_.GefyraName -eq 'Ισθμία' }
            $isthmiaSaved.GefyraStatus | Should -Be 'Κλειστή με πρόγραμμα'
            $isthmiaSaved.From | Should -Be '10:00'
        }

        It 'Δεν καλεί Export-BridgeStatusJson όταν αποτύχουν όλες οι ειδοποιήσεις αλλαγών' {
            Initialize-TwoBridgeDiffMock
            Mock Invoke-BridgeClosedNotification { throw 'First bridge notification failed' }
            Mock Invoke-BridgeOpenedNotification { throw 'Second bridge notification failed' }

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_first_fail.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*First bridge notification failed*'

            Should -Not -Invoke -CommandName Export-BridgeStatusJson -Scope It
        }

        Context 'End-to-End Orchestration Pipeline (External HTTP Mocked Only)' {
            It 'Εκτελεί πλήρη ροή δύο διαδοχικών κύκλων χωρίς εσωτερικά mocks και αποφεύγει διπλές ειδοποιήσεις' {
                $e2eLogDir = Join-Path $TestDrive 'e2e_logs'
                $e2eConfig = New-BridgeConfiguration -LogDirectory $e2eLogDir
                $e2eStatusFile = 'TestDrive:\e2e_status.json'
                if (Test-Path $e2eStatusFile) {
                    Remove-Item -Path $e2eStatusFile -Force
                }

                $ocrCalls = [System.Collections.Generic.List[string]]::new()
                $pushoverCalls = [System.Collections.Generic.List[hashtable]]::new()

                Mock Invoke-WebRequest {
                    if ($Uri -like '*image-bridge-open-with-schedule-posidonia.php*') {
                        return [PSCustomObject]@{
                            Content = [byte[]]@(1, 2, 3, 4)
                        }
                    }

                    $htmlPage = @'
<div class="panel panel-primary">
    <h4><b>ΠΟΣΕΙΔΩΝΊΑ</b></h4>
    <div class="panel-body">
        <div class="form-group">
            <img src="image-bridge-open-with-schedule-posidonia.php?111">
        </div>
    </div>
</div>
<div class="panel panel-primary">
    <h4><b>ΙΣΘΜΊΑ</b></h4>
    <div class="panel-body">
        <div class="form-group">
            <img src="image-bridge-open-no-schedule.php?111">
            <img src="image-bridge-open-no-schedule-info.php?111">
        </div>
    </div>
</div>
'@
                    return [PSCustomObject]@{
                        Content = $htmlPage
                    }
                }

                Mock Invoke-RestMethod {
                    if ($Uri -like "$($e2eConfig.Urls.OCRApi)*") {
                        $ocrCalls.Add($Uri)
                        return [PSCustomObject]@{
                            responses = @(
                                [PSCustomObject]@{
                                    textAnnotations = @(
                                        [PSCustomObject]@{
                                            description = '25/12/2099 10:00 - 25/12/2099 11:00'
                                        }
                                    )
                                }
                            )
                        }
                    }

                    if ($Uri -eq $e2eConfig.Urls.PushoverApi) {
                        $pushoverCalls.Add($Body)
                        return @{ status = 1 }
                    }

                    throw "Unexpected Invoke-RestMethod URI: $Uri"
                }

                $pollParams = @{
                    OutputFile    = $e2eStatusFile
                    ApiKey        = 'e2e-ocr-key'
                    PoUserKey     = 'e2e-po-user'
                    PoApiKey      = 'e2e-po-token'
                    Configuration = $e2eConfig
                }

                # Poll 1: Cold start (no prior state file on disk)
                $poll1State = @(Update-BridgeStatus @pollParams)
                $poll1State.Count | Should -Be 2
                Test-Path $e2eStatusFile | Should -BeTrue

                $savedRecords = @(Get-Content -Path $e2eStatusFile -Raw -Encoding utf8BOM | ConvertFrom-Json)
                $savedRecords.Count | Should -Be 2

                $poseidoniaRecord = $savedRecords | Where-Object { $_.GefyraName -eq 'Ποσειδωνία' }
                $isthmiaRecord = $savedRecords | Where-Object { $_.GefyraName -eq 'Ισθμία' }

                $poseidoniaRecord | Should -Not -BeNullOrEmpty
                $poseidoniaRecord.GefyraStatus | Should -Be $e2eConfig.Statuses.ClosedWithSchedule
                $poseidoniaRecord.ImageHash | Should -Not -BeNullOrEmpty

                $isthmiaRecord | Should -Not -BeNullOrEmpty
                $isthmiaRecord.GefyraStatus | Should -Be $e2eConfig.Statuses.Open

                $ocrCalls.Count | Should -Be 1
                $pushoverCalls.Count | Should -Be 2

                $closedPushover = $pushoverCalls | Where-Object { $_.title -match 'Ποσειδωνία' }
                $openedPushover = $pushoverCalls | Where-Object { $_.message -match 'Ισθμία' -and $_.title -eq 'Γέφυρα Ανοιχτή!' }

                $closedPushover | Should -Not -BeNullOrEmpty
                $closedPushover.message | Should -Match '25/12/2099 10:00'
                $closedPushover.message | Should -Match '25/12/2099 11:00'
                $openedPushover | Should -Not -BeNullOrEmpty

                # Poll 2: Unchanged state & identical schedule image bytes
                $poll2State = @(Update-BridgeStatus @pollParams)
                $poll2State.Count | Should -Be 2

                # Assert 0 new OCR or Pushover Invoke-RestMethod calls occurred in Poll 2
                $ocrCalls.Count | Should -Be 1
                $pushoverCalls.Count | Should -Be 2
                Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
            }
        }
    }
}
