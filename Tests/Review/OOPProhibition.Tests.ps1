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

Describe "Object-Oriented Over-Engineering Prohibition Review" {
    Context "PowerShell Types and Embedded C# Definitions" {
        It "Should not define PowerShell classes or enums in <Name>" -ForEach $script:Files {
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

            $oopNodes.Count | Should -Be 0
        }

        It "Should not contain C# class/struct/enum definitions via Add-Type -TypeDefinition in <Name>" -ForEach $script:Files {
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
                # Check elements
                for ($i = 1; $i -lt $cmd.CommandElements.Count; $i++) {
                    $element = $cmd.CommandElements[$i]
                    if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
                        if ($element.ParameterName -like 'Type*' -or $element.ParameterName -eq 'TypeDefinition') {
                            $hasTypeDefinition = $true
                            break
                        }
                    } elseif ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] -or 
                              $element -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                        # Positional parameter: check if it looks like C# class/struct/enum/interface
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

            $violatingCmds.Count | Should -Be 0
        }
    }
}
