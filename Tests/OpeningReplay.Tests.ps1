BeforeAll -Scriptblock {
    Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

    <#
    .SYNOPSIS
    Returns the HTML for a simulated two-bridge poll.
    .DESCRIPTION
    Varies the first panel's images and keeps the second bridge on a scheduled closure.
    .PARAMETER PoseidoniaImages
    Image tags to place in the first bridge panel.
    #>
    function Get-OpeningReplayHtml {
        param([string]$PoseidoniaImages)
        @"
<div class="panel panel-primary">
    <h4><b>ΠΟΣΕΙΔΩΝΊΑ</b></h4>
    <div class="panel-body"><div class="form-group">$PoseidoniaImages</div></div>
</div>
<div class="panel panel-primary">
    <h4><b>ΙΣΘΜΊΑ</b></h4>
    <div class="panel-body"><div class="form-group"><img src="image-bridge-open-with-schedule-isthmia.php?1"></div></div>
</div>
"@
    }
}

Describe -Name 'Scheduled opening replay through Update-BridgeStatus' -Fixture {
    BeforeEach -Scriptblock {
        $cfg = New-BridgeConfiguration -LogDirectory $TestDrive
        $cfg.Defaults.TimezoneIds = @('Europe/Athens')
        $path = Join-Path -Path $TestDrive -ChildPath 'status.json'
        $script:params = @{ OutputFile = $path; ApiKey = 'ocr'; PoUserKey = 'user'; PoApiKey = 'token'; Configuration = $cfg }
        $script:saved = [pscustomobject]@{
            GefyraName = $cfg.BridgeNames.poseidonia; GefyraStatus = $cfg.Statuses.ClosedWithSchedule
            ImageUrl = "$($cfg.Urls.BaseImage.TrimEnd('/'))/image-bridge-open-with-schedule-posidonia.php?1"
            ImageHash = 'original'; From = '15/01/2030 10:00'; To = '15/01/2030 12:00'
            ScheduleState = 'Expired'; OpensIn = 'Τώρα'
        }
        $plainImage = '<img src="image-bridge-open-no-schedule.php?2">'
        $endUtc = [datetime]::new(2030, 1, 15, 10, 0, 0, [DateTimeKind]::Utc)
        $poll = @{ Now = $endUtc.AddMinutes(-1); Html = (Get-OpeningReplayHtml -PoseidoniaImages $plainImage); Writes = [System.Collections.Generic.List[object]]::new() }
        Mock -ModuleName BridgeWatcher -CommandName Get-Date -MockWith { if ($Format) { $poll.Now.ToString($Format) } else { $poll.Now } }
        Mock -ModuleName BridgeWatcher -CommandName Invoke-WebRequest -MockWith {
            if ($Uri -eq $cfg.Urls.Source) { return @{ Content = $poll.Html } }
            if ($Uri -like '*with-schedule-*.php*') { return @{ Content = [byte[]]@(1, 2, 3, 4) } }
            throw "Unexpected network request: $Uri"
        }
        Mock -ModuleName BridgeWatcher -CommandName Invoke-RestMethod -MockWith { throw 'Unexpected REST request' }
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -MockWith {}
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeClosedNotification -MockWith {}
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith {
            if ($Message -eq "$($cfg.ExportMessages.Success): $path") {
                $poll.Writes.Add(@(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json))
            }
        }
    }

    It -Name 'Preserves the schedule through the other bridge checkpoint and final write, then opens exactly once' -Test {
        ConvertTo-Json -InputObject @($saved, @{ GefyraName = $cfg.BridgeNames.isthmia; GefyraStatus = $cfg.Statuses.Open }) |
            Set-Content -LiteralPath $path -Encoding utf8BOM
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 0 -Exactly
        Should -Invoke -CommandName Invoke-BridgeClosedNotification -ModuleName BridgeWatcher -Times 1 -Exactly
        $poll.Writes.Count | Should -Be -ExpectedValue 2
        $poll.Now = $endUtc
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 0 -Exactly
        $poll.Writes.Count | Should -Be -ExpectedValue 3
        foreach ($snapshot in $poll.Writes) {
            $bridge = $snapshot | Where-Object -Property GefyraName -EQ -Value $saved.GefyraName
            foreach ($property in $saved.PSObject.Properties.Name) {
                $bridge.$property | Should -BeExactly -ExpectedValue $saved.$property
            }
            ($snapshot | Where-Object -Property GefyraName -EQ -Value $cfg.BridgeNames.isthmia).GefyraStatus | Should -Be -ExpectedValue $cfg.Statuses.ClosedWithSchedule
        }
        $poll.Now = $endUtc.AddSeconds(1)
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 1 -Exactly -ParameterFilter { $CurrentState[0].GefyraName -eq $saved.GefyraName }
        $confirmed = Get-BridgePreviousStatus -InputFile $path -Configuration $cfg | Where-Object -Property GefyraName -EQ -Value $saved.GefyraName
        $confirmed.GefyraStatus | Should -Be -ExpectedValue $cfg.Statuses.Open
        $confirmed.PSObject.Properties.Name | Should -Not -Contain -ExpectedValue 'Observation'
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 1 -Exactly
        Should -Invoke -CommandName Invoke-BridgeClosedNotification -ModuleName BridgeWatcher -Times 1 -Exactly
    }

    It -Name 'Waits until the later occurrence of a repeated Athens reopening time has passed' -Test {
        $saved.To = '25/10/2026 03:30'
        $wallTime = [datetime]::new(2026, 10, 25, 3, 30, 0)
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById($cfg.Defaults.TimezoneIds[0])
        $instants = @($zone.GetAmbiguousTimeOffsets($wallTime) | ForEach-Object -Process {
            [datetimeoffset]::new($wallTime, $_).UtcDateTime
        } | Sort-Object)
        ConvertTo-Json -InputObject @($saved, @{ GefyraName = $cfg.BridgeNames.isthmia; GefyraStatus = $cfg.Statuses.ClosedWithSchedule }) |
            Set-Content -LiteralPath $path -Encoding utf8BOM

        foreach ($now in @($instants[0].AddMinutes(15), $instants[1])) {
            $poll.Now = $now
            $null = Update-BridgeStatus @params
            Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 0 -Exactly
            $bridge = Get-BridgePreviousStatus -InputFile $path -Configuration $cfg | Where-Object -Property GefyraName -EQ -Value $saved.GefyraName
            $bridge.GefyraStatus | Should -Be -ExpectedValue $saved.GefyraStatus
            $bridge.To | Should -BeExactly -ExpectedValue $saved.To
            $bridge.ImageUrl | Should -BeExactly -ExpectedValue $saved.ImageUrl
        }
        $poll.Now = $instants[1].AddSeconds(1)
        $null = Update-BridgeStatus @params
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 1 -Exactly
    }

    It -Name 'Uses <Case> to determine when to reopen' -ForEach @(
        @{ Case = 'the default Athens time when no zones are configured'; Zones = @(); UtcHour = 10 }
        @{ Case = 'the next usable zone when the first is unknown'; Zones = @('Test/UnknownZone', 'UTC'); UtcHour = 12 }
    ) -Test {
        $cfg.Defaults.TimezoneIds = $Zones
        ConvertTo-Json -InputObject @($saved) | Set-Content -LiteralPath $path -Encoding utf8BOM
        $poll.Now = [datetime]::new(2030, 1, 15, $UtcHour, 0, 0, [DateTimeKind]::Utc)
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 0 -Exactly

        $poll.Now = $poll.Now.AddSeconds(1)
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 1 -Exactly -ParameterFilter { $CurrentState[0].GefyraName -eq $saved.GefyraName }
    }

    It -Name 'Keeps the saved closure when <Case>' -ForEach @(
        @{ Case = 'no configured zone can be resolved'; Zones = @('Test/UnknownZone'); End = '15/01/2030 12:00' }
        @{ Case = 'the saved time falls in the Athens spring-forward gap'; Zones = @('Europe/Athens'); End = '31/03/2030 03:30' }
    ) -Test {
        $cfg.Defaults.TimezoneIds = $Zones
        $saved.To = $End
        ConvertTo-Json -InputObject @($saved) | Set-Content -LiteralPath $path -Encoding utf8BOM
        $poll.Now = [datetime]::new(2030, 4, 1, 12, 0, 0, [DateTimeKind]::Utc)
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 0 -Exactly
        $bridge = Get-BridgePreviousStatus -InputFile $path -Configuration $cfg | Where-Object -Property GefyraName -EQ -Value $saved.GefyraName
        $bridge.GefyraStatus | Should -BeExactly -ExpectedValue $saved.GefyraStatus
        $bridge.To | Should -BeExactly -ExpectedValue $End
    }

    It -Name 'Records repeated open observations without confirming an unreadable closure has ended' -Test {
        $saved.PSObject.Properties.Remove('To')
        ConvertTo-Json -InputObject @($saved) | Set-Content -LiteralPath $path -Encoding utf8BOM
        foreach ($offset in 1..2) {
            $poll.Now = $endUtc.AddDays($offset)
            $null = Update-BridgeStatus @params
            $bridge = Get-BridgePreviousStatus -InputFile $path -Configuration $cfg | Where-Object -Property GefyraName -EQ -Value $saved.GefyraName
            $bridge.GefyraStatus | Should -BeExactly -ExpectedValue $saved.GefyraStatus
            $bridge.Observation.Status | Should -BeExactly -ExpectedValue $cfg.Statuses.Open
            Get-Content -LiteralPath $path -Raw | Should -Match -RegularExpression ([regex]::Escape($poll.Now.ToString('o')))
            $bridge.Observation.ReopeningConfirmed | Should -BeFalse
        }
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 0 -Exactly
        foreach ($snapshot in $poll.Writes) {
            ($snapshot | Where-Object -Property GefyraName -EQ -Value $saved.GefyraName).Observation.ReopeningConfirmed | Should -BeFalse
        }
    }

    It -Name 'Does not open after the scheduled time when <Case>' -ForEach @(
        @{ Case = 'To is missing'; End = $null; Extra = ''; QueryOnly = $false }
        @{ Case = 'To is invalid'; End = '31/02/2030 12:00'; Extra = ''; QueryOnly = $false }
        @{ Case = 'the same panel still shows a schedule'; End = '15/01/2030 12:00'; Extra = '<img src="image-bridge-open-with-schedule-posidonia.php?2">'; QueryOnly = $false }
        @{ Case = 'the same panel contains a schedule image with an unexpected suffix'; End = '15/01/2030 12:00'; Extra = '<img src="image-bridge-open-with-schedule-isthmia.php?2">'; QueryOnly = $false }
        @{ Case = 'only the URL query changes'; End = '15/01/2030 12:00'; Extra = ''; QueryOnly = $true }
    ) -Test {
        $saved.To = $End
        if ($null -eq $End) { $saved.PSObject.Properties.Remove('To') }
        if ($QueryOnly) { $saved.ImageUrl = "$($cfg.Urls.BaseImage.TrimEnd('/'))/image-bridge-open-no-schedule.php?1" }
        ConvertTo-Json -InputObject @($saved) | Set-Content -LiteralPath $path -Encoding utf8BOM
        $poll.Now = $endUtc.AddSeconds(1)
        $poll.Html = Get-OpeningReplayHtml -PoseidoniaImages ($plainImage + $Extra)
        $null = Update-BridgeStatus @params
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -ModuleName BridgeWatcher -Times 0 -Exactly
    }
}
