Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
. "$PSScriptRoot/TestHelper.ps1"

InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
    Describe -Name 'Update-BridgeStatus' -Fixture {
        BeforeAll -Scriptblock {
            $script:Config = New-BridgeConfiguration

            <#
            .SYNOPSIS
            Initializes mocks for two-bridge partial alert tests.

            .DESCRIPTION
            Sets up previous and current bridge entries for tests that exercise partial notification delivery.

            .PARAMETER PreviousEntries
            The bridge entries in the previous snapshot.

            .PARAMETER ExtraCurrentEntries
            Additional entries to include in the current snapshot.
            #>
            function script:Initialize-TwoBridgeDiffMock {
                param(
                    [object[]]$PreviousEntries = @(),
                    [object[]]$ExtraCurrentEntries = @()
                )
                $b1 = [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-04-25T10:00:00' }
                $b2 = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T10:00:00' }
                $hasPrevious = $PreviousEntries.Count -gt 0
                Mock -CommandName Test-Path -MockWith { return $hasPrevious }.GetNewClosure()
                if ($hasPrevious) {
                    Mock -CommandName Get-BridgePreviousStatus -MockWith { return $PreviousEntries }.GetNewClosure()
                }
                $allCurrent = @($ExtraCurrentEntries) + @($b1, $b2)
                Mock -CommandName Get-BridgeStatus -MockWith { return $allCurrent }.GetNewClosure()
                Mock -CommandName Invoke-BridgeStatusComparison -MockWith {
                    return @(
                        [PSCustomObject]@{ BridgeName = 'Ποσειδωνία'; Type = 'Closed'; StateInfo = @($b1) },
                        [PSCustomObject]@{ BridgeName = 'Ισθμία'; Type = 'Opened'; StateInfo = @($b2) }
                    )
                }.GetNewClosure()
                $script:capturedExports = @()
                Mock -CommandName Export-BridgeStatusJson -MockWith {
                    $script:capturedExports += , @($Data)
                    return New-BridgeResult -Success $true
                }
                Mock -CommandName Write-BridgeLog -MockWith { }
            }
        }

        It -Name 'Εκτελεί όλες τις βασικές λειτουργίες χωρίς σφάλμα' -Test {
            $jsonFile = 'TestDrive:\bridge_status_test.json'
            Mock -CommandName Get-BridgePreviousStatus -MockWith {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' },
                    [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }
                )
            } -ParameterFilter { $InputFile -eq $jsonFile }
            Mock -CommandName Get-BridgeStatus -MockWith {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' },
                    [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }
                )
            }
            Mock -CommandName Invoke-BridgeStatusComparison -MockWith {}
            Mock -CommandName Export-BridgeStatusJson -MockWith {
                New-BridgeResult -Success $true
            }
            Mock -CommandName Write-Verbose -MockWith {}

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Not -Throw
        }

        It -Name 'Πρέπει να καλούνται Get-BridgePreviousStatus και Get-BridgeStatus με τα σωστά parameters όταν το αρχείο υπάρχει' -Test {
            $jsonFile = 'TestDrive:\bridge_status_test_exists.json'

            Set-Content -Path $jsonFile -Value '[]'

            Mock -CommandName Get-BridgePreviousStatus -MockWith {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; From = '00:00'; ImageHash = 'abc' }
                )
            }
            Mock -CommandName Get-BridgeStatus -MockWith {
                return @(
                    [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }
                )
            }
            Mock -CommandName Invoke-BridgeStatusComparison -MockWith {
                return @(
                    [PSCustomObject]@{ Type = 'Closed'; StateInfo = @{ GefyraName = 'Ποσειδωνία' } },
                    [PSCustomObject]@{ Type = 'Opened'; StateInfo = @{ GefyraName = 'Ισθμία' } }
                )
            }
            Mock -CommandName Export-BridgeStatusJson -MockWith {
                New-BridgeResult -Success $true
            }
            Mock -CommandName Write-Verbose -MockWith {}
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith {}
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith {}

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

        It -Name 'Εκτελείται σωστά με -WhatIf και δεν καλεί Invoke/Export' -Test {
            $jsonFile = 'TestDrive:\bridge_status_whatif.json'

            Set-Content -Path $jsonFile -Value '[]'
            Mock -CommandName Get-BridgePreviousStatus -MockWith { return @() }
            Mock -CommandName Get-BridgeStatus -MockWith { return @() }
            Mock -CommandName Invoke-BridgeStatusComparison -MockWith {}
            Mock -CommandName Export-BridgeStatusJson -MockWith {}
            Mock -CommandName Write-BridgeLog -MockWith {}

            Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k' -WhatIf

            Should -Not -Invoke -CommandName Invoke-BridgeStatusComparison -Scope It
            Should -Not -Invoke -CommandName Export-BridgeStatusJson -Scope It
            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -eq 'Finished comparison and saved snapshot.' } -Times 1 -Scope It
        }

        It -Name 'Ρίχνει terminating error όταν η Export-BridgeStatusJson επιστρέφει Success = $false' -Test {
            $jsonFile = 'TestDrive:\bridge_status_export_fail.json'

            if (Test-Path -Path $jsonFile) { Remove-Item -Path $jsonFile -Force }
            Mock -CommandName Get-BridgeStatus -MockWith { return @([PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }) }
            Mock -CommandName Invoke-BridgeStatusComparison -MockWith { return @() }
            Mock -CommandName Export-BridgeStatusJson -MockWith {
                return New-BridgeResult -Success $false -ErrorMessage 'Disk full' -ErrorCode 'JSON_EXPORT_FAILURE'
            }
            Mock -CommandName Write-BridgeLog -MockWith {}

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*Disk full*'
        }

        It -Name 'Αποθηκεύει μόνο την επιτυχημένη γέφυρα σε cold start όταν αποτυγχάνει η δεύτερη ειδοποίηση και επαναρίχνει το σφάλμα' -Test {
            Initialize-TwoBridgeDiffMock
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { throw 'Bridge 2 Pushover timeout' }

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_cold_partial.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*Bridge 2 Pushover timeout*'

            Should -Invoke -CommandName Export-BridgeStatusJson -Times 1 -Exactly -Scope It
            $saved = @($script:capturedExports[0])
            $saved.Count | Should -Be -ExpectedValue 1
            $saved[0].GefyraName | Should -Be -ExpectedValue 'Ποσειδωνία'
            $saved[0].GefyraStatus | Should -Be -ExpectedValue 'Κλειστή για συντήρηση'
        }

        It -Name 'Αποθηκεύει τη νέα κατάσταση της πρώτης γέφυρας, τις αμετάβλητες και την προηγούμενη της αποτυχημένης όταν υπάρχει ιστορικό' -Test {
            $prevEntries = @(
                [PSCustomObject]@{ GefyraName = 'Κόρινθος'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T09:55:00' },
                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T09:55:00' },
                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-04-25T09:55:00'; From = '10:00' }
            )
            $unchangedCurrent = @([PSCustomObject]@{ GefyraName = 'Κόρινθος'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T10:00:00' })
            Initialize-TwoBridgeDiffMock -PreviousEntries $prevEntries -ExtraCurrentEntries $unchangedCurrent
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { throw 'Bridge 2 Pushover HTTP 503' }

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_warm_partial.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*Bridge 2 Pushover HTTP 503*'

            Should -Invoke -CommandName Export-BridgeStatusJson -Times 1 -Exactly -Scope It
            $saved = @($script:capturedExports[0])
            $saved.Count | Should -Be -ExpectedValue 3
            ($saved | Where-Object -FilterScript { $_.GefyraName -eq 'Κόρινθος' }).Timestamp | Should -Be -ExpectedValue '2025-04-25T10:00:00'
            ($saved | Where-Object -FilterScript { $_.GefyraName -eq 'Ποσειδωνία' }).GefyraStatus | Should -Be -ExpectedValue 'Κλειστή για συντήρηση'
            $isthmiaSaved = $saved | Where-Object -FilterScript { $_.GefyraName -eq 'Ισθμία' }
            $isthmiaSaved.GefyraStatus | Should -Be -ExpectedValue 'Κλειστή με πρόγραμμα'
            $isthmiaSaved.From | Should -Be -ExpectedValue '10:00'
        }

        It -Name 'Δεν καλεί Export-BridgeStatusJson όταν αποτύχουν όλες οι ειδοποιήσεις αλλαγών' -Test {
            Initialize-TwoBridgeDiffMock
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { throw 'First bridge notification failed' }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { throw 'Second bridge notification failed' }

            {
                Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_first_fail.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Throw -ExpectedMessage '*First bridge notification failed*'

            Should -Not -Invoke -CommandName Export-BridgeStatusJson -Scope It
        }

        It -Name 'Retries OCR but delivers the fallback only once per unchanged closure image' -Test {
            $params = @{
                OutputFile = (Join-Path -Path $TestDrive -ChildPath 'retry.json'); Configuration = $script:Config
                ApiKey = 'ocr'; PoUserKey = 'user'; PoApiKey = 'app'
            }
            $poll = @{ Hash = 'first'; FailPush = $true; Recovered = $false }
            Mock -CommandName Get-BridgeStatus -MockWith {
                [pscustomobject]@{ GefyraName = 'Ισθμία'; GefyraStatus = $script:Config.Statuses.ClosedWithSchedule
                    ImageUrl = 'https://example.com/schedule'; ImageHash = $poll.Hash }
            }
            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
                if (-not $poll.Recovered) { throw 'OCR unavailable' }
                [pscustomobject]@{ ScheduleState = 'Future'; From = '10:00'; To = '11:00' }
            }
            Mock -CommandName Send-BridgePushover -MockWith { if ($poll.FailPush) { throw 'Push unavailable' } }

            { Update-BridgeStatus @params } | Should -Throw -ExpectedMessage '*Push unavailable*'
            $poll.FailPush = $false
            $null = Update-BridgeStatus @params
            $null = Update-BridgeStatus @params
            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 3 -Exactly
            Should -Invoke -CommandName Send-BridgePushover -Times 2 -Exactly

            $poll.Hash = 'replacement'
            $null = Update-BridgeStatus @params
            Should -Invoke -CommandName Send-BridgePushover -Times 3 -Exactly
            $poll.Recovered = $true
            $null = Update-BridgeStatus @params
            $null = Update-BridgeStatus @params
            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 5 -Exactly
            Should -Invoke -CommandName Send-BridgePushover -Times 4 -Exactly
            $saved = Get-BridgePreviousStatus -InputFile $params.OutputFile -Configuration $script:Config
            $saved.ScheduleState | Should -Be -ExpectedValue 'Future'
            $saved.ImageHash | Should -Be -ExpectedValue 'replacement'
        }

        It -Name 'Checkpoints an accepted push when only the delivery success log fails' -Test {
            $params = @{
                OutputFile = (Join-Path -Path $TestDrive -ChildPath 'push-checkpoint.json'); Configuration = $script:Config
                ApiKey = 'ocr'; PoUserKey = 'user'; PoApiKey = 'app'
            }
            Mock -CommandName Get-BridgeStatus -MockWith {
                [pscustomobject]@{ GefyraName = 'Ισθμία'; GefyraStatus = $script:Config.Statuses.Open
                    ImageUrl = 'https://example.com/open'; ImageHash = $null; Timestamp = '2030-01-15T11:30:00' }
            }
            Mock -CommandName Invoke-RestMethod -MockWith { @{ status = 1 } }
            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Write-BridgeLog -ParameterFilter { $Message -like '*Pushover*' -and $Level -eq 'Verbose' } -MockWith { throw 'Log append failed' }
            Mock -CommandName Write-Warning -MockWith {}

            $null = Update-BridgeStatus @params
            $null = Update-BridgeStatus @params

            Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
            Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -Scope It -ParameterFilter { $Message -like '*Log append failed*' }
            (Get-BridgePreviousStatus -InputFile $params.OutputFile -Configuration $script:Config).GefyraStatus | Should -BeExactly -ExpectedValue $script:Config.Statuses.Open
        }

        It -Name 'Retries an image-level Vision error and sends the recovered schedule' -Test {
            $params = @{
                OutputFile = (Join-Path -Path $TestDrive -ChildPath 'vision-recovery.json'); Configuration = $script:Config
                ApiKey = 'ocr'; PoUserKey = 'user'; PoApiKey = 'app'
            }
            $poll = @{ Recovered = $false }
            Mock -CommandName Get-BridgeStatus -MockWith {
                [pscustomobject]@{ GefyraName = 'Ισθμία'; GefyraStatus = $script:Config.Statuses.ClosedWithSchedule
                    ImageUrl = 'https://example.com/schedule'; ImageHash = 'same-image' }
            }
            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Get-BridgeCachedImageBytes -MockWith { [byte[]]@(1, 2, 3) }
            Mock -CommandName Invoke-RestMethod -MockWith {
                if ($poll.Recovered) {
                    return ConvertFrom-Json -InputObject '{"responses":[{"textAnnotations":[{"description":"15/01/2030 11:30 to 15/01/2030 12:00"}]}]}'
                }
                return ConvertFrom-Json -InputObject '{"responses":[{"error":{"code":14,"message":"Unavailable"}}]}'
            }
            Mock -CommandName Send-BridgePushover -MockWith {}

            $null = Update-BridgeStatus @params
            $null = Update-BridgeStatus @params
            $poll.Recovered = $true
            $null = Update-BridgeStatus @params
            $null = Update-BridgeStatus @params

            Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly
            Should -Invoke -CommandName Send-BridgePushover -Times 2 -Exactly
            $saved = Get-BridgePreviousStatus -InputFile $params.OutputFile -Configuration $script:Config
            $saved.To | Should -BeExactly -ExpectedValue '15/01/2030 12:00'
        }

        Context -Name 'End-to-End Orchestration Pipeline (External HTTP Mocked Only)' -Fixture {
            It -Name 'Εκτελεί πλήρη ροή δύο διαδοχικών κύκλων χωρίς εσωτερικά mocks και αποφεύγει διπλές ειδοποιήσεις' -Test {
                $e2eLogDir = Join-Path -Path $TestDrive -ChildPath 'e2e_logs'
                $e2eConfig = New-BridgeConfiguration -LogDirectory $e2eLogDir
                $e2eStatusFile = 'TestDrive:\e2e_status.json'
                if (Test-Path -Path $e2eStatusFile) {
                    Remove-Item -Path $e2eStatusFile -Force
                }

                $ocrCalls = [System.Collections.Generic.List[string]]::new()
                $pushoverCalls = [System.Collections.Generic.List[hashtable]]::new()

                Mock -CommandName Invoke-WebRequest -MockWith {
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

                Mock -CommandName Invoke-RestMethod -MockWith {
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

                $poll1State = @(Update-BridgeStatus @pollParams)
                $poll1State.Count | Should -Be -ExpectedValue 2
                Test-Path -Path $e2eStatusFile | Should -BeTrue

                $savedRecords = @(Get-Content -Path $e2eStatusFile -Raw -Encoding utf8BOM | ConvertFrom-Json)
                $savedRecords.Count | Should -Be -ExpectedValue 2

                $poseidoniaRecord = $savedRecords | Where-Object -FilterScript { $_.GefyraName -eq 'Ποσειδωνία' }
                $isthmiaRecord = $savedRecords | Where-Object -FilterScript { $_.GefyraName -eq 'Ισθμία' }

                $poseidoniaRecord | Should -Not -BeNullOrEmpty
                $poseidoniaRecord.GefyraStatus | Should -Be -ExpectedValue $e2eConfig.Statuses.ClosedWithSchedule
                $poseidoniaRecord.ImageHash | Should -Not -BeNullOrEmpty

                $isthmiaRecord | Should -Not -BeNullOrEmpty
                $isthmiaRecord.GefyraStatus | Should -Be -ExpectedValue $e2eConfig.Statuses.Open

                $ocrCalls.Count | Should -Be -ExpectedValue 1
                $pushoverCalls.Count | Should -Be -ExpectedValue 2

                $closedPushover = $pushoverCalls | Where-Object -FilterScript { $_.title -match 'Ποσειδωνία' }
                $openedPushover = $pushoverCalls | Where-Object -FilterScript { $_.message -match 'Ισθμία' -and $_.title -eq 'Γέφυρα Ανοιχτή!' }

                $closedPushover | Should -Not -BeNullOrEmpty
                $closedPushover.message | Should -Match -RegularExpression '25/12/2099 10:00'
                $closedPushover.message | Should -Match -RegularExpression '25/12/2099 11:00'
                $openedPushover | Should -Not -BeNullOrEmpty

                $poll2State = @(Update-BridgeStatus @pollParams)
                $poll2State.Count | Should -Be -ExpectedValue 2

                $ocrCalls.Count | Should -Be -ExpectedValue 1
                $pushoverCalls.Count | Should -Be -ExpectedValue 2
                Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
            }
        }
    }
}
