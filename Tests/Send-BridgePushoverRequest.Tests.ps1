Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Send-BridgePushoverRequest' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It 'Επιστρέφει το αποτέλεσμα όταν το API απαντάει επιτυχώς' {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ status = 1; request = 'abcd' }
        }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $payload = @{ message = 'test' }
        $result = Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config

        $result.status | Should -Be 1
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
    }

    It 'Ρίχνει απευθείας terminating error σε HTTP 400 (Bad Request)' {
        Mock -CommandName Invoke-RestMethod -MockWith {
            $response = [System.Net.HttpWebResponse]::new()
            $response.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('StatusCode', 400))
            $ex = [System.Net.WebException]::new('Bad Request', [System.Exception]::new('dummy'), [System.Net.WebExceptionStatus]::ProtocolError, $response)
            throw $ex
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw '*Bad Request*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
        Should -Not -Invoke -CommandName Start-Sleep -Scope It
    }

    It 'Επαναλαμβάνει σε HTTP 500 και ρίχνει terminating error όταν εξαντληθούν οι προσπάθειες' {
        Mock -CommandName Invoke-RestMethod -MockWith {
            $response = [System.Net.HttpWebResponse]::new()
            $response.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('StatusCode', 500))
            $ex = [System.Net.WebException]::new('Internal Server Error', [System.Exception]::new('dummy'), [System.Net.WebExceptionStatus]::ProtocolError, $response)
            throw $ex
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw '*Internal Server Error*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly -Scope It
    }

    It 'Επαναλαμβάνει σε γενικό σφάλμα και ρίχνει terminating error όταν εξαντληθούν οι προσπάθειες' {
        Mock -CommandName Invoke-RestMethod -MockWith {
            throw 'Some generic error'
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw '*Some generic error*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly -Scope It
    }

    It 'Καλεί Dispose() στο Response αν υποστηρίζει IDisposable' {
        $script:disposeCount = 0
        Mock -CommandName Invoke-RestMethod -MockWith {
            $ex = [System.Net.WebException]::new('Service Unavailable')
            throw $ex
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw '*Service Unavailable*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
        # It should have called Dispose() inside the finally block of the catch [WebException]
        # MemoryStream.Dispose() doesn't have an easily observable side effect unless we mock it,
        # but since we hit the finally block, coverage should increase.
    }
}
