$script:PublicPath = Resolve-Path (Join-Path $PSScriptRoot "..\..\BridgeWatcher\Public")
$script:Files = Get-ChildItem -Path $script:PublicPath -Filter *.ps1 | ForEach-Object { $_.Name }

BeforeAll {
    # Pester setup
}

Describe "PowerShell Comment-Based Help Completeness Review" {
    Context "Public Functions Comment-Based Help Location" {
        It "Should have contiguous comment-based help located immediately before the function Name { keyword in <_>" -ForEach $script:Files {
            $fileName = $_
            $publicPath = Resolve-Path (Join-Path $PSScriptRoot "..\..\BridgeWatcher\Public")
            $fullName = Join-Path $publicPath $fileName
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
                # Find function keyword token index
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

                # Look backward to see if there is a comment-based help block immediately preceding the function
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
                    # Track non-whitespace/newline tokens between help and function keyword
                    $separatedByTokens += $token.Text
                    $idx--
                }

                # Check inside body just to give a better error message if it's placed inside
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

                # Checks
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

        It "Should have a matching .PARAMETER entry in the help block for every declared parameter in <_>" -ForEach $script:Files {
            $fileName = $_
            $publicPath = Resolve-Path (Join-Path $PSScriptRoot "..\..\BridgeWatcher\Public")
            $fullName = Join-Path $publicPath $fileName
            $errors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($fullName, [ref]$tokens, [ref]$errors)

            $functions = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

            foreach ($func in $functions) {
                # Find the help comment (check outside first, then inside)
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
                    # Try looking inside the body
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
}
