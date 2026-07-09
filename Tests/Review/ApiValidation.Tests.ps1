$rootPath = "C:\Users\jcap\github\BridgeWatcher\BridgeWatcher"
$files = Get-ChildItem -Path (Join-Path $rootPath "Public\*.ps1"), (Join-Path $rootPath "Private\*.ps1")

Describe "API Contract Validation Strictness" {
    foreach ($file in $files) {
        Context "$($file.Name)" {
            BeforeAll {
                $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
                $script:paramBlocks = $script:ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParamBlockAst] }, $true)
            }

            It "Should not have mandatory string parameters without ValidateNotNullOrEmpty" {
                $violations = @()
                foreach ($block in $script:paramBlocks) {
                    foreach ($param in $block.Parameters) {
                        if ($param.StaticType.FullName -eq 'System.String') {
                            $isMandatory = $false
                            foreach ($attr in $param.Attributes) {
                                if ($attr.TypeName.FullName -eq 'Parameter' -or $attr.TypeName.FullName -eq 'System.Management.Automation.ParameterAttribute') {
                                    $mandatoryArg = $attr.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
                                    if ($mandatoryArg) {
                                        if ($mandatoryArg.Argument -is [System.Management.Automation.Language.ConstantExpressionAst]) {
                                            $isMandatory = [bool]$mandatoryArg.Argument.Value
                                        } else {
                                            $isMandatory = $true
                                        }
                                    }
                                }
                            }

                            if ($isMandatory) {
                                $hasValidateNotNullOrEmpty = $false
                                foreach ($attr in $param.Attributes) {
                                    if ($attr.TypeName.FullName -eq 'ValidateNotNullOrEmpty' -or $attr.TypeName.FullName -eq 'System.Management.Automation.ValidateNotNullOrEmptyAttribute') {
                                        $hasValidateNotNullOrEmpty = $true
                                    }
                                }
                                if (-not $hasValidateNotNullOrEmpty) {
                                    $violations += $param.Name.VariablePath.UserPath
                                }
                            }
                        }
                    }
                }
                $violations.Count | Should -Be 0
            }

            It "Should have consistent validation attributes for sibling string parameters" {
                $violations = @()
                foreach ($block in $script:paramBlocks) {
                    $stringParams = @()
                    foreach ($param in $block.Parameters) {
                        if ($param.StaticType.FullName -eq 'System.String') {
                            $stringParams += $param
                        }
                    }

                    if ($stringParams.Count -gt 1) {
                        $validated = @()
                        $unvalidated = @()
                        foreach ($param in $stringParams) {
                            $hasValidation = $false
                            foreach ($attr in $param.Attributes) {
                                if ($attr.TypeName.FullName -like 'Validate*') {
                                    $hasValidation = $true
                                }
                            }
                            if ($hasValidation) {
                                $validated += $param.Name.VariablePath.UserPath
                            } else {
                                $unvalidated += $param.Name.VariablePath.UserPath
                            }
                        }

                        if ($validated.Count -gt 0 -and $unvalidated.Count -gt 0) {
                            $violations += "Inconsistent sibling validation: Validated ($($validated -join ', ')), Unvalidated ($($unvalidated -join ', '))"
                        }
                    }
                }
                $violations.Count | Should -Be 0
            }
        }
    }
}
