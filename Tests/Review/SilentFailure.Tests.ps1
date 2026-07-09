$script:ModulePath = Resolve-Path (Join-Path $PSScriptRoot "..\..\BridgeWatcher")
$script:Files = Get-ChildItem -Path $script:ModulePath -Recurse -Include *.ps1 | Where-Object {
    $_.FullName -like "*\Public\*" -or $_.FullName -like "*\Private\*"
}

BeforeAll {
    function Test-IsAssignmentLeft($ref) {
        <#
        .SYNOPSIS
        Checks if a variable reference is on the left-hand side of an assignment.
        #>
        $p = $ref.Parent
        while ($p) {
            if ($p -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                $found = $p.Left.FindAll({ param($n) $n -eq $ref }, $true)
                if ($found) { return $true }
            }
            if ($p -is [System.Management.Automation.Language.StatementBlockAst]) { break }
            $p = $p.Parent
        }
        return $false
    }

    function Test-CatchBlockCompliance($catchBlock, $ast) {
        <#
        .SYNOPSIS
        Checks if a catch block complies with Section 6 of AGENTS.md.
        #>
        # 1. Check for throw statement
        $hasThrow = $catchBlock.FindAll({ param($n) $n -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)
        if ($hasThrow) { return $true }

        # 2. Check for ThrowTerminatingError call
        $hasThrowTerminating = $catchBlock.FindAll({
            param($n)
            ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and ($n.Member.ToString() -eq 'ThrowTerminatingError' -or ($n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Member.Value -eq 'ThrowTerminatingError'))) -or
            ($n -is [System.Management.Automation.Language.MemberExpressionAst] -and ($n.Member.ToString() -eq 'ThrowTerminatingError' -or ($n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Member.Value -eq 'ThrowTerminatingError'))) -or
            ($n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'ThrowTerminatingError')
        }, $true)
        if ($hasThrowTerminating) { return $true }

        # 3. Check for return or exit statement
        $hasReturnOrExit = $catchBlock.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.ReturnStatementAst] -or
            $n -is [System.Management.Automation.Language.ExitStatementAst]
        }, $true)
        if ($hasReturnOrExit) { return $true }

        # 4. Check for break or continue statement
        $hasBreakOrContinue = $catchBlock.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.BreakStatementAst] -or
            $n -is [System.Management.Automation.Language.ContinueStatementAst]
        }, $true)
        if ($hasBreakOrContinue) { return $true }

        # 5. Check for failure-state variables checked outside the try-catch block
        $parent = $catchBlock.Parent
        $tryAst = $null
        while ($parent) {
            if ($parent -is [System.Management.Automation.Language.TryStatementAst]) {
                $tryAst = $parent
                break
            }
            $parent = $parent.Parent
        }

        # Find the enclosing scope
        $parent = $catchBlock.Parent
        $enclosingScope = $null
        while ($parent) {
            if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst] -or $parent -is [System.Management.Automation.Language.ScriptBlockAst]) {
                $enclosingScope = $parent
                break
            }
            $parent = $parent.Parent
        }
        if (-not $enclosingScope) { $enclosingScope = $ast }

        $assignments = $catchBlock.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)
        foreach ($assign in $assignments) {
            $varExpr = $assign.Left
            $varsInLeft = $varExpr.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)
            foreach ($var in $varsInLeft) {
                $varName = $var.VariablePath.UserPath
                # Ignore temporary formatting, logging, and automatic variables
                if ($varName -match '(?i)(splat|log|errorRecord|errorMessage|title|message|^null$|^true$|^false$|^_$|^args$|^this$|^input$)') { continue }

                if ($tryAst) {
                    $allRefs = $enclosingScope.FindAll({
                        param($n)
                        $n -is [System.Management.Automation.Language.VariableExpressionAst] -and
                        $n.VariablePath.UserPath -eq $varName
                    }, $true)

                    $outsideReadCount = 0
                    foreach ($ref in $allRefs) {
                        # Reference must be outside the try-catch block
                        $refParent = $ref.Parent
                        $isInsideTry = $false
                        while ($refParent) {
                            if ($refParent -eq $tryAst) {
                                $isInsideTry = $true
                                break
                            }
                            $refParent = $refParent.Parent
                        }

                        if (-not $isInsideTry) {
                            # Must be lexically after the try-catch block
                            $isAfter = $ref.Extent.StartOffset -gt $tryAst.Extent.EndOffset
                            # Must be a read (not on the left side of an assignment)
                            $isRead = -not (Test-IsAssignmentLeft $ref)

                            if ($isAfter -and $isRead) {
                                $outsideReadCount++
                            }
                        }
                    }
                    if ($outsideReadCount -gt 0) {
                        return $true
                    }
                }
            }
        }

        return $false
    }
}

Describe "Silent Failure / Catch-and-Log-Only Review" {
    Context "PowerShell Try/Catch Error Handling Rules" {
        It "Should not have catch blocks that only log and continue in <Name>" -ForEach $script:Files {
            $file = $_
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $catchBlocks = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CatchClauseAst] }, $true)

            $violations = @()
            foreach ($cb in $catchBlocks) {
                if (-not (Test-CatchBlockCompliance $cb $ast)) {
                    $violations += "Line $($cb.Extent.StartLineNumber): $(($cb.Extent.Text -replace '`r?`n', ' '))"
                }
            }

            if ($violations.Count -gt 0) {
                $msg = $violations -join "`n"
                throw "File $($file.Name) contains silent failure catch blocks:`n$msg"
            }

            $violations.Count | Should -Be 0
        }
    }
}
