$script:ModulePath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\..\BridgeWatcher")
$script:Files = Get-ChildItem -Path $script:ModulePath -Recurse -Include *.ps1, *.psm1 | ForEach-Object -Process {
    [PSCustomObject]@{
        Name     = $_.Name
        FullName = $_.FullName
    }
}

BeforeAll -Scriptblock {
}

Describe -Name "Object-Oriented Over-Engineering Prohibition Review" -Fixture {
    Context -Name "PowerShell Types and Embedded C# Definitions" -Fixture {
        It -Name "Should not define PowerShell classes or enums in <Name>" -ForEach $script:Files -Test {
            $file = $_
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            $oopNodes = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.TypeDefinitionAst]
            }, $true)

            if ($oopNodes) {
                $types = $oopNodes.Name -join ", "
                throw "File $($file.Name) contains forbidden TypeDefinitionAst (class/enum): $types"
            }

            $oopNodes.Count | Should -Be -ExpectedValue 0
        }

        It -Name "Should not contain C# class/struct/enum definitions via Add-Type -TypeDefinition in <Name>" -ForEach $script:Files -Test {
            $file = $_
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            $addTypes = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'Add-Type'
            }, $true)

            $violatingCmds = @()
            foreach ($cmd in $addTypes) {
                $hasTypeDefinition = $false
                for ($i = 1; $i -lt $cmd.CommandElements.Count; $i++) {
                    $element = $cmd.CommandElements[$i]
                    if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
                        if ($element.ParameterName -like 'Type*' -or $element.ParameterName -eq 'TypeDefinition') {
                            $hasTypeDefinition = $true
                            break
                        }
                    } elseif ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                              $element -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                        $val = $element.Value
                        if ($val -match '\b(class|struct|enum|interface)\b') {
                            $hasTypeDefinition = $true
                            break
                        }
                    }
                }
                if ($hasTypeDefinition) {
                    $violatingCmds += $cmd
                }
            }

            if ($violatingCmds.Count -gt 0) {
                throw "File $($file.Name) contains forbidden Add-Type -TypeDefinition block"
            }

            $violatingCmds.Count | Should -Be -ExpectedValue 0
        }
    }
}