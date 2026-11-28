Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
    Describe -Name 'Send-BridgePushoverRequest' -Fixture {
        BeforeAll -Scriptblock {
            $script:Config = New-BridgeConfiguration
        }

    It -Name 'Επιστρέφει το αποτέλεσμα όταν το API απαντάει επιτυχώς' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ status = 1; request = 'abcd' }
        }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $payload = @{ message = 'test' }
        $result = Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config

        $result.status | Should -Be -ExpectedValue 1
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
    }

    It -Name 'Returns the accepted response and warns when logging fails' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ status = 1; request = 'abcd' }
        }
        Mock -CommandName Write-BridgeLog -MockWith {
            throw 'Read-only file system'
        }

        Mock -CommandName Write-Warning -MockWith { }
        $payload = @{ message = 'crash alert' }
        $result = Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config

        $result.status | Should -Be -ExpectedValue 1
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
        Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -Scope It -ParameterFilter { $Message -like '*Read-only file system*' }
    }

    It -Name 'Ρίχνει απευθείας terminating error σε HTTP 400 (Bad Request)' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            $response = [System.Net.HttpWebResponse]::new()
            $response.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('StatusCode', 400))
            $ex = [System.Net.WebException]::new('Bad Request', [System.Exception]::new('dummy'), [System.Net.WebExceptionStatus]::ProtocolError, $response)
            throw $ex
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw -ExpectedMessage '*Bad Request*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
        Should -Not -Invoke -CommandName Start-Sleep -Scope It
    }

    It -Name 'Επαναλαμβάνει σε HTTP 500 και ρίχνει terminating error όταν εξαντληθούν οι προσπάθειες' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            $response = [System.Net.HttpWebResponse]::new()
            $response.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('StatusCode', 500))
            $ex = [System.Net.WebException]::new('Internal Server Error', [System.Exception]::new('dummy'), [System.Net.WebExceptionStatus]::ProtocolError, $response)
            throw $ex
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw -ExpectedMessage '*Internal Server Error*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly -Scope It
    }

    It -Name 'Επαναλαμβάνει σε γενικό σφάλμα και ρίχνει terminating error όταν εξαντληθούν οι προσπάθειες' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            throw 'Some generic error'
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw -ExpectedMessage '*Some generic error*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly -Scope It
    }

    It -Name 'Καλεί Dispose() στο Response αν υποστηρίζει IDisposable' -Test {
        $script:disposeCount = 0
        Mock -CommandName Invoke-RestMethod -MockWith {
            $ex = [System.Net.WebException]::new('Service Unavailable')
            throw $ex
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'test' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config } | Should -Throw -ExpectedMessage '*Service Unavailable*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
    }

    It -Name 'Επαναλαμβάνει σε HttpRequestException χωρίς ιδιότητα Response υπό strict mode και δεν αποτυγχάνει όταν λείπει το title' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            throw [System.Net.Http.HttpRequestException]::new('Connection reset by peer')
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }

        $payload = @{ message = 'transport error alert' }
        { Send-BridgePushoverRequest -Payload $payload -Configuration $script:Config -Verbose } | Should -Throw -ExpectedMessage '*Connection reset by peer*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly -Scope It
    }
}
}
