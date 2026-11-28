$script:ModulePath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\..\BridgeWatcher")
$script:Files = Get-ChildItem -Path $script:ModulePath -Recurse -Include *.ps1, *.psm1 | ForEach-Object -Process {
    [PSCustomObject]@{
        Name     = $_.Name
        FullName = $_.FullName
    }
}

BeforeAll -Scriptblock {
}

Describe -Name "Hot Path Configuration Review" -Fixture {
    Context -Name "New-BridgeConfiguration Calls in Hot Paths" -Fixture {
        It -Name "Should not call New-BridgeConfiguration in <Name>" -ForEach $script:Files -Test {
            $file = $_
            if ($file.Name -eq 'New-BridgeConfiguration.ps1') {
                return
            }

            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            $calls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'New-BridgeConfiguration'
            }, $true)

            if ($calls.Count -gt 0) {
                throw "File $($file.Name) contains call to New-BridgeConfiguration. Configuration must be passed explicitly."
            }

            $calls.Count | Should -Be -ExpectedValue 0
        }

        It -Name "Should not call New-BridgeConfiguration inside loop bodies in <Name>" -ForEach $script:Files -Test {
            $file = $_
            if ($file.Name -eq 'New-BridgeConfiguration.ps1') {
                return
            }

            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            $loops = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.ForStatementAst] -or
                $node -is [System.Management.Automation.Language.ForEachStatementAst] -or
                $node -is [System.Management.Automation.Language.WhileStatementAst] -or
                $node -is [System.Management.Automation.Language.DoWhileStatementAst] -or
                $node -is [System.Management.Automation.Language.DoUntilStatementAst]
            }, $true)

            foreach ($loop in $loops) {
                $nestedCalls = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'New-BridgeConfiguration'
                }, $true)

                if ($nestedCalls.Count -gt 0) {
                    throw "File $($file.Name) contains call to New-BridgeConfiguration inside a loop body."
                }
            }
        }
    }

    Context -Name "PSCustomObject Configuration Construction in Frequently-Called Helpers and Loops" -Fixture {
        It -Name "Should not build configuration objects via PSCustomObject inside <Name>" -ForEach $script:Files -Test {
            $file = $_
            if ($file.Name -eq 'New-BridgeConfiguration.ps1') {
                return
            }

            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            $customObjects = $ast.FindAll({
                param($node)
                ($node -is [System.Management.Automation.Language.ConvertExpressionAst] -and
                 $node.Type.TypeName.FullName -eq 'pscustomobject') -or
                ($node -is [System.Management.Automation.Language.CommandAst] -and
                 $node.GetCommandName() -eq 'New-Object' -and
                 ($node.CommandElements | Where-Object -FilterScript { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $_.Value -eq 'PSCustomObject' }))
            }, $true)

            $configKeys = @('Urls', 'Defaults', 'Statuses', 'BridgeNames', 'ErrorMessages', 'StatusMessages', 'LoggingConfig', 'ExportMessages', 'OCRMessages', 'PushoverMessages', 'AdviceMessages', 'LogDirectory')

            foreach ($obj in $customObjects) {
                $hashtables = $obj.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)
                foreach ($ht in $hashtables) {
                    $keys = @()
                    foreach ($pair in $ht.KeyValuePairs) {
                        if ($pair.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                            $keys += $pair.Item1.Value
                        }
                    }

                    $matchingKeys = $keys | Where-Object -FilterScript { $configKeys -contains $_ }

                    $matchingCount = 0
                    if ($null -ne $matchingKeys) {
                        $matchingCount = @($matchingKeys).Count
                    }

                    if (($keys -contains 'LoggingConfig') -or ($keys -contains 'Defaults') -or ($keys -contains 'Urls') -or ($matchingCount -ge 2)) {

                        $node = $obj
                        $inLoop = $false
                        while ($null -ne $node) {
                            if ($node -is [System.Management.Automation.Language.ForStatementAst] -or
                                $node -is [System.Management.Automation.Language.ForEachStatementAst] -or
                                $node -is [System.Management.Automation.Language.WhileStatementAst] -or
                                $node -is [System.Management.Automation.Language.DoWhileStatementAst] -or
                                $node -is [System.Management.Automation.Language.DoUntilStatementAst]) {
                                $inLoop = $true
                                break
                            }
                            $node = $node.Parent
                        }

                        if ($inLoop -or $file.FullName -match '[\\/](Private|Public)[\\/]') {
                            $matchedString = if ($null -ne $matchingKeys) { @($matchingKeys) -join ', ' } else { '' }
                            throw "File $($file.Name) builds configuration object implicitly via PSCustomObject (matching keys: $matchedString)."
                        }
                    }
                }
            }
        }
    }
}