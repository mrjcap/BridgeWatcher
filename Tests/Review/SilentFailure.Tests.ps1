$script:ModulePath = Resolve-Path (Join-Path $PSScriptRoot "../../BridgeWatcher")
$script:Files = Get-ChildItem -Path $script:ModulePath -Recurse -Include *.ps1 | Where-Object {
    $_.FullName -match '[\\/](Public|Private)[\\/]'
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

    function Find-ParentAstOfType($node, [type[]]$types) {
        <#
        .SYNOPSIS
        Finds the nearest ancestor AST node matching any of the given types.
        #>
        $parent = $node.Parent
        while ($parent) {
            foreach ($t in $types) {
                if ($parent -is $t) { return $parent }
            }
            $parent = $parent.Parent
        }
        return $null
    }

    function Test-VariableReadAfterTry($varName, $tryAst, $enclosingScope) {
        <#
        .SYNOPSIS
        Checks if a variable is read lexically after the try-catch block.
        #>
        $allRefs = $enclosingScope.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $n.VariablePath.UserPath -eq $varName
        }, $true)

        foreach ($ref in $allRefs) {
            $isAfter = $ref.Extent.StartOffset -gt $tryAst.Extent.EndOffset
            if ($isAfter -and -not (Test-IsAssignmentLeft $ref)) {
                return $true
            }
        }
        return $false
    }

    function Test-CatchSetsFailureVariable($catchBlock, $ast) {
        <#
        .SYNOPSIS
        Checks if a catch block sets a failure state variable read after the try block.
        #>
        $tryAst = Find-ParentAstOfType $catchBlock @([System.Management.Automation.Language.TryStatementAst])
        if (-not $tryAst) { return $false }

        $scopeTypes = @(
            [System.Management.Automation.Language.FunctionDefinitionAst],
            [System.Management.Automation.Language.ScriptBlockAst]
        )
        $enclosingScope = Find-ParentAstOfType $catchBlock $scopeTypes
        if (-not $enclosingScope) { $enclosingScope = $ast }

        $ignorePattern = '(?i)(splat|log|errorRecord|errorMessage|title|message|^null$|^true$|^false$|^_$|^args$|^this$|^input$)'
        $assignments = $catchBlock.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)
        foreach ($assign in $assignments) {
            $varsInLeft = $assign.Left.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)
            foreach ($var in $varsInLeft) {
                $varName = $var.VariablePath.UserPath
                if ($varName -notmatch $ignorePattern -and (Test-VariableReadAfterTry -VarName $varName -TryAst $tryAst -EnclosingScope $enclosingScope)) {
                    return $true
                }
            }
        }
        return $false
    }

    function Test-CatchBlockCompliance($catchBlock, $ast) {
        <#
        .SYNOPSIS
        Checks if a catch block complies with Section 6 of AGENTS.md.
        #>
        $controlFlowTypes = @(
            [System.Management.Automation.Language.ThrowStatementAst],
            [System.Management.Automation.Language.ReturnStatementAst],
            [System.Management.Automation.Language.ExitStatementAst],
            [System.Management.Automation.Language.BreakStatementAst],
            [System.Management.Automation.Language.ContinueStatementAst]
        )
        $hasControlFlow = $catchBlock.FindAll({
            param($n)
            foreach ($t in $controlFlowTypes) {
                if ($n -is $t) { return $true }
            }
            return $false
        }, $true)
        if ($hasControlFlow) { return $true }

        $hasThrowTerminating = $catchBlock.FindAll({
            param($n)
            ($n -is [System.Management.Automation.Language.MemberExpressionAst] -and $n.Member.ToString() -match '^''?ThrowTerminatingError''?$') -or
            ($n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'ThrowTerminatingError')
        }, $true)
        if ($hasThrowTerminating) { return $true }

        return (Test-CatchSetsFailureVariable $catchBlock $ast)
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
