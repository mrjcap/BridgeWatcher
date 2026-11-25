$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath '../../BridgeWatcher'
$publicPath = Join-Path -Path $moduleRoot -ChildPath 'Public'
$privatePath = Join-Path -Path $moduleRoot -ChildPath 'Private'
$publicFiles = Get-ChildItem -Path $publicPath -Recurse -Filter '*.ps1' -File | ForEach-Object {
    @{ FileName = $_.Name; FullName = $_.FullName }
}
$privateFiles = Get-ChildItem -Path $privatePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
    @{ FileName = $_.Name; FullName = $_.FullName }
}

Describe "PowerShell Comment-Based Help Completeness Review" {
    Context "Public function help" {
        It "Should have contiguous comment-based help located immediately before the function Name { keyword in <FileName>" -ForEach $publicFiles {
            $errors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($fullName, [ref]$tokens, [ref]$errors)

            $functions = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

            if ($functions.Count -eq 0) {
                return
            }

            foreach ($func in $functions) {
                $funcTokenIdx = -1
                for ($i = 0; $i -lt $tokens.Count; $i++) {
                    if ($tokens[$i].Extent.StartOffset -eq $func.Extent.StartOffset) {
                        $funcTokenIdx = $i
                        break
                    }
                }

                if ($funcTokenIdx -eq -1) {
                    throw "Could not locate AST start token for function $($func.Name)"
                }

                $idx = $funcTokenIdx - 1
                $foundCommentOutside = $null
                $separatedByTokens = @()

                while ($idx -ge 0) {
                    $token = $tokens[$idx]
                    if ($token.Kind -eq 'NewLine' -or $token.Kind -eq 'Whitespace') {
                        $idx--
                        continue
                    }
                    if ($token.Kind -eq 'Comment') {
                        if ($token.Text -match '\.(SYNOPSIS|DESCRIPTION|PARAMETER)') {
                            $foundCommentOutside = $token
                        }
                        break
                    }
                    $separatedByTokens += $token.Text
                    $idx--
                }

                $foundCommentInside = $null
                $bodyStartOffset = $func.Body.Extent.StartOffset
                $bodyTokenIdx = -1
                for ($i = 0; $i -lt $tokens.Count; $i++) {
                    if ($tokens[$i].Extent.StartOffset -eq $bodyStartOffset) {
                        $bodyTokenIdx = $i
                        break
                    }
                }

                if ($bodyTokenIdx -ne -1) {
                    $idx = $bodyTokenIdx + 1
                    while ($idx -lt $tokens.Count) {
                        $token = $tokens[$idx]
                        if ($token.Kind -eq 'NewLine' -or $token.Kind -eq 'Whitespace') {
                            $idx++
                            continue
                        }
                        if ($token.Kind -eq 'Comment' -and $token.Text -match '\.(SYNOPSIS|DESCRIPTION|PARAMETER)') {
                            $foundCommentInside = $token
                        }
                        break
                    }
                }

                if (-not $foundCommentOutside -and -not $foundCommentInside) {
                    throw "Function '$($func.Name)' in file '$fileName' is missing comment-based help entirely."
                }

                if ($foundCommentInside) {
                    throw "Function '$($func.Name)' in file '$fileName' has comment-based help located inside the function body. It must be located immediately before the function definition."
                }

                if ($foundCommentOutside -and $separatedByTokens.Count -gt 0) {
                    $sepList = $separatedByTokens -join ' '
                    throw "Function '$($func.Name)' in file '$fileName' comment-based help is separated from the function keyword by non-comment tokens: $sepList"
                }
            }
        }

        It "Should have a matching .PARAMETER entry in the help block for every declared parameter in <FileName>" -ForEach $publicFiles {
            $errors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($fullName, [ref]$tokens, [ref]$errors)

            $functions = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

            foreach ($func in $functions) {
                $funcTokenIdx = -1
                for ($i = 0; $i -lt $tokens.Count; $i++) {
                    if ($tokens[$i].Extent.StartOffset -eq $func.Extent.StartOffset) {
                        $funcTokenIdx = $i
                        break
                    }
                }

                $helpComment = $null
                if ($funcTokenIdx -ne -1) {
                    $idx = $funcTokenIdx - 1
                    while ($idx -ge 0) {
                        $token = $tokens[$idx]
                        if ($token.Kind -eq 'NewLine' -or $token.Kind -eq 'Whitespace') {
                            $idx--
                            continue
                        }
                        if ($token.Kind -eq 'Comment' -and $token.Text -match '\.(SYNOPSIS|DESCRIPTION|PARAMETER)') {
                            $helpComment = $token
                        }
                        break
                    }
                }

                if (-not $helpComment) {
                    $bodyStartOffset = $func.Body.Extent.StartOffset
                    $bodyTokenIdx = -1
                    for ($i = 0; $i -lt $tokens.Count; $i++) {
                        if ($tokens[$i].Extent.StartOffset -eq $bodyStartOffset) {
                            $bodyTokenIdx = $i
                            break
                        }
                    }
                    if ($bodyTokenIdx -ne -1) {
                        $idx = $bodyTokenIdx + 1
                        while ($idx -lt $tokens.Count) {
                            $token = $tokens[$idx]
                            if ($token.Kind -eq 'NewLine' -or $token.Kind -eq 'Whitespace') {
                                $idx++
                                continue
                            }
                            if ($token.Kind -eq 'Comment' -and $token.Text -match '\.(SYNOPSIS|DESCRIPTION|PARAMETER)') {
                                $helpComment = $token
                            }
                            break
                        }
                    }
                }

                if (-not $helpComment) {
                    continue
                }

                $commentText = $helpComment.Text
                $pattern = '(?mi)^\s*\.PARAMETER\s+(\w+)'
                $helpParams = [regex]::Matches($commentText, $pattern) | ForEach-Object { $_.Groups[1].Value }

                $declaredParams = @()
                if ($func.Body.ParamBlock -and $func.Body.ParamBlock.Parameters) {
                    $declaredParams = $func.Body.ParamBlock.Parameters.Name.VariablePath.UserPath
                }

                $missingInHelp = @()
                foreach ($dp in $declaredParams) {
                    if ($helpParams -notcontains $dp) {
                        $missingInHelp += $dp
                    }
                }

                if ($missingInHelp.Count -gt 0) {
                    $missingStr = $missingInHelp -join ', '
                    throw "Function '$($func.Name)' in file '$fileName' has declared parameters missing in the comment-based help block: $missingStr"
                }
            }
        }
    }

    Context 'Private function help' {
        It 'Should have parseable comment-based help for every function in <FileName>' -ForEach $privateFiles {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($fullName, [ref]$tokens, [ref]$errors)
            $functions = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

            foreach ($function in $functions) {
                $help = $function.GetHelpContent()
                $help.Synopsis | Should -Not -BeNullOrEmpty -Because "$($function.Name) in $fileName needs a .SYNOPSIS"
            }
        }
    }
}
