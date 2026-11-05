$script:ModulePath = Resolve-Path (Join-Path $PSScriptRoot "..\..\BridgeWatcher")
$script:Files = Get-ChildItem -Path $script:ModulePath -Recurse -Include *.ps1 | Where-Object {
    $_.FullName -like "*\Public\*" -or $_.FullName -like "*\Private\*"
}
$Psm1Path = Resolve-Path (Join-Path $script:ModulePath "BridgeWatcher.psm1")

# Helper function to find the variable name assigned to an expression
function global:Find-AssignmentVariable($node) {
    <#
    .SYNOPSIS
        Finds assignment variable for node.
    #>
    $parent = $node.Parent
    while ($parent) {
        if ($parent -is [System.Management.Automation.Language.AssignmentStatementAst]) {
            return $parent.Left.ToString().TrimStart('$')
        }
        $parent = $parent.Parent
    }
    return $null
}

# Helper function to assert disposal of a resource variable
function global:Assert-VariableIsDisposed($varName, $node, $file) {
    <#
    .SYNOPSIS
        Asserts a variable is disposed.
    #>
    if (-not $varName) {
        throw "Resource at line $($node.Extent.StartLineNumber) is not assigned to a variable (leak risk)."
    }

    # Check if variable is module-scoped
    if ($varName -like 'script:*' -or $varName -like 'global:*') {
        $psm1Path = Join-Path (Split-Path (Split-Path $file.FullName)) "BridgeWatcher.psm1"
        $psm1Ast = [System.Management.Automation.Language.Parser]::ParseFile($psm1Path, [ref]$null, [ref]$null)
        $onRemove = $psm1Ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $n.Left.ToString() -match '\.OnRemove$'
        }, $true)

        if (-not $onRemove) {
            throw "Module-scoped variable '$varName' used but no OnRemove cleanup handler found in module script."
        }

        $bareName = $varName -replace '^(script|global):'
        $cleanFound = $false
        foreach ($or in $onRemove) {
            $disposes = $or.Right.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.MemberExpressionAst] -and
                $n.Member.Value -in @('Dispose', 'Close') -and
                ($n.Expression.ToString() -match "\b(script:|global:)?$bareName\b")
            }, $true)
            if ($disposes) {
                $cleanFound = $true
                break
            }
        }

        if (-not $cleanFound) {
            throw "Module-scoped variable '$varName' is not cleaned up in OnRemove block in module script."
        }
    } else {
        # Local variable: find TryStatementAst parent
        $parent = $node.Parent
        $tryAst = $null
        while ($parent) {
            if ($parent -is [System.Management.Automation.Language.TryStatementAst]) {
                $tryAst = $parent
                break
            }
            $parent = $parent.Parent
        }

        if (-not $tryAst) {
            throw "Variable '$varName' at line $($node.Extent.StartLineNumber) is not enclosed in a try block."
        }

        if (-not $tryAst.FinallyBlock) {
            throw "Variable '$varName' at line $($node.Extent.StartLineNumber) has a try block but lacks a finally block."
        }

        $bareName = $varName
        $cleanFound = $tryAst.FinallyBlock.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $n.Member.Value -in @('Dispose', 'Close') -and
            ($n.Expression.ToString() -match "\b$bareName\b")
        }, $true)

        if (-not $cleanFound) {
            throw "Variable '$varName' is not cleaned up (Dispose/Close) inside the finally block of the try statement at line $($tryAst.Extent.StartLineNumber)."
        }
    }
}

Describe "Disposable Resource Cleanup Review" {
    Context "Audit Source Files" {
        It "Should properly dispose of audited IDisposable resources in <Name>" -ForEach $script:Files {
            $file = $_
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

            # Find New-Object calls of target types
            $newObjectNodes = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'New-Object'
            }, $true)

            $targetNodes = @()
            foreach ($node in $newObjectNodes) {
                $typeName = $null
                for ($i = 1; $i -lt $node.CommandElements.Count; $i++) {
                    $el = $node.CommandElements[$i]
                    if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                        if ($el.ParameterName -eq 'TypeName' -and ($i + 1) -lt $node.CommandElements.Count) {
                            $typeName = $node.CommandElements[$i+1].Value
                            break
                        }
                    }
                }
                if ($null -eq $typeName -and $node.CommandElements.Count -gt 1) {
                    $firstArg = $node.CommandElements[1]
                    if ($firstArg -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                        if ($null -ne $firstArg.Value) {
                            $typeName = $firstArg.Value
                        } else {
                            $typeName = $firstArg.ToString()
                        }
                    }
                }
                if ($typeName -and $typeName -match '\b(HttpWebRequest|HttpWebResponse|WebClient|StreamReader|StreamWriter)\b') {
                    $targetNodes += $node
                }
            }

            # Find type constructor calls
            $constructorNodes = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $node.Member.Name -eq 'new' -and
                $node.Expression -is [System.Management.Automation.Language.TypeExpressionAst] -and
                $node.Expression.TypeName.FullName -match '\b(HttpWebRequest|HttpWebResponse|WebClient|StreamReader|StreamWriter)\b'
            }, $true)
            $targetNodes += $constructorNodes

            # Find type constraint/cast calls
            $typeNodes = $ast.FindAll({
                param($node)
                ($node -is [System.Management.Automation.Language.TypeExpressionAst] -or
                 $node -is [System.Management.Automation.Language.TypeConstraintAst] -or
                 $node -is [System.Management.Automation.Language.ConvertExpressionAst]) -and
                $node.TypeName.FullName -match '\b(HttpWebRequest|HttpWebResponse|WebClient|StreamReader|StreamWriter)\b'
            }, $true)
            $targetNodes += $typeNodes

            # Find GetResponse / GetResponseStream calls
            $methodNodes = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.MemberExpressionAst] -and
                $node.Member.Name -in @('GetResponse', 'GetResponseStream')
            }, $true)
            $targetNodes += $methodNodes

            # Run assertions on each found node
            foreach ($node in $targetNodes) {
                $varName = Find-AssignmentVariable $node
                Assert-VariableIsDisposed -varName $varName -node $node -file $file
            }
        }
    }
}
