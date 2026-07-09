$script:ModulePath = Resolve-Path (Join-Path $PSScriptRoot "..\..\BridgeWatcher")
$script:Files = Get-ChildItem -Path $script:ModulePath -Recurse -Include *.ps1, *.psm1 | ForEach-Object {
    [PSCustomObject]@{
        Name     = $_.Name
        FullName = $_.FullName
    }
}

BeforeAll {
    # Pester 5/6 scope setup
}

Describe "Hot Path Configuration Review" {
    Context "New-BridgeConfiguration Calls in Hot Paths" {
        It "Should not call New-BridgeConfiguration in <Name>" -ForEach $script:Files {
            $file = $_
            # Skip New-BridgeConfiguration.ps1 itself, as that defines the configuration creator
            if ($file.Name -eq 'New-BridgeConfiguration.ps1') {
                return
            }

            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            # Find all calls to New-BridgeConfiguration
            $calls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'New-BridgeConfiguration'
            }, $true)

            if ($calls.Count -gt 0) {
                throw "File $($file.Name) contains call to New-BridgeConfiguration. Configuration must be passed explicitly."
            }

            $calls.Count | Should -Be 0
        }

        It "Should not call New-BridgeConfiguration inside loop bodies in <Name>" -ForEach $script:Files {
            $file = $_
            if ($file.Name -eq 'New-BridgeConfiguration.ps1') {
                return
            }

            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            # Find all loop statements
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

    Context "PSCustomObject Configuration Construction in Frequently-Called Helpers and Loops" {
        It "Should not build configuration objects via PSCustomObject inside <Name>" -ForEach $script:Files {
            $file = $_
            if ($file.Name -eq 'New-BridgeConfiguration.ps1') {
                return
            }

            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            # Find PSCustomObject creations:
            # - ConvertExpressionAst casting to [pscustomobject]
            # - CommandAst calling New-Object PSCustomObject
            $customObjects = $ast.FindAll({
                param($node)
                ($node -is [System.Management.Automation.Language.ConvertExpressionAst] -and
                 $node.Type.TypeName.FullName -eq 'pscustomobject') -or
                ($node -is [System.Management.Automation.Language.CommandAst] -and
                 $node.GetCommandName() -eq 'New-Object' -and
                 ($node.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $_.Value -eq 'PSCustomObject' }))
            }, $true)

            $configKeys = @('Urls', 'Defaults', 'Statuses', 'BridgeNames', 'StatusMappings', 'ErrorMessages', 'StatusMessages', 'LoggingConfig', 'ExportMessages', 'OCRMessages', 'PushoverMessages', 'AdviceMessages', 'LogDirectory')

            foreach ($obj in $customObjects) {
                # Look for child hashtables
                $hashtables = $obj.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)
                foreach ($ht in $hashtables) {
                    $keys = @()
                    foreach ($pair in $ht.KeyValuePairs) {
                        if ($pair.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                            $keys += $pair.Item1.Value
                        }
                    }

                    # Heuristic: If the PSCustomObject contains keys that explicitly represent configuration,
                    # like 'Urls', 'Defaults', 'LoggingConfig', or contains 2 or more keys from our config list,
                    # it represents an implicitly built configuration object.
                    $matchingKeys = $keys | Where-Object { $configKeys -contains $_ }

                    $matchingCount = 0
                    if ($null -ne $matchingKeys) {
                        $matchingCount = @($matchingKeys).Count
                    }

                    if (($keys -contains 'LoggingConfig') -or ($keys -contains 'Defaults') -or ($keys -contains 'Urls') -or ($matchingCount -ge 2)) {

                        # Check if this PSCustomObject is inside a loop body
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

                        # All helper functions in Public/ and Private/ are frequently called or part of hot paths.
                        if ($inLoop -or $file.FullName -like '*\\Private\\*' -or $file.FullName -like '*\\Public\\*') {
                            $matchedString = if ($null -ne $matchingKeys) { @($matchingKeys) -join ', ' } else { '' }
                            throw "File $($file.Name) builds configuration object implicitly via PSCustomObject (matching keys: $matchedString)."
                        }
                    }
                }
            }
        }
    }
}