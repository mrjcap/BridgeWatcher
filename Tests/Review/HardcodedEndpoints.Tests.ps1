$script:ModulePath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\..\BridgeWatcher")
$script:PublicPath = Join-Path -Path $script:ModulePath -ChildPath "Public"
$script:PrivatePath = Join-Path -Path $script:ModulePath -ChildPath "Private"
$script:Files = Get-ChildItem -Path $script:PublicPath, $script:PrivatePath -Recurse -Filter *.ps1 | ForEach-Object -Process {
    [PSCustomObject]@{
        Name     = $_.Name
        FullName = $_.FullName
    }
}

Describe -Name "Hardcoded Service Endpoints in Defaults Review" -Fixture {
    foreach ($file in $script:Files) {
        Context -Name "$($file.Name)" -Fixture {
            It -Name "Should not contain hardcoded URLs, file paths, or API endpoints as default values" -Test {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
                $params = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true)
                $violations = @()

                foreach ($p in $params) {
                    if ($p.DefaultValue) {
                        $stringNodes = $p.DefaultValue.FindAll({
                            $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                            $args[0] -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
                        }, $true)

                        foreach ($node in $stringNodes) {
                            $val = $node.Value
                            if ($val) {
                                $isUrl = $val -match 'https?://'
                                $isPath = ($val -match '^[a-zA-Z]:[\\/]') -or ($val -match '^\\\\[a-zA-Z0-9]') -or ($val -match '^/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+')
                                if ($isUrl -or $isPath) {
                                    $violations += [PSCustomObject]@{
                                        Parameter    = $p.Name.VariablePath.UserPath
                                        DefaultValue = $p.DefaultValue.Extent.Text
                                        MatchedValue = $val
                                        Type         = if ($isUrl) { "URL" } else { "Path" }
                                    }
                                }
                            }
                        }
                    }
                }

                if ($violations.Count -gt 0) {
                    $details = $violations | ForEach-Object -Process {
                        "Parameter '$($_.Parameter)' has default value '$($_.DefaultValue)' containing hardcoded $($_.Type) '$($_.MatchedValue)'"
                    }
                    throw "Found violations in $($file.Name):`n$($details -join "`n")"
                }

                $violations.Count | Should -Be -ExpectedValue 0
            }
        }
    }
}
