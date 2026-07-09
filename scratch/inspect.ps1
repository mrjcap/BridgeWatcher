$code = @'
<#
.SYNOPSIS
Valid help
#>

function Test-Help1 {
}

<#
.SYNOPSIS
Invalid because of attribute in between
#>
[CmdletBinding()]
function Test-Help2 {
}
'@

$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$null)
$filteredTokens = $tokens | Where-Object { $_.Kind -ne 'NewLine' }

$functions = $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
foreach ($f in $functions) {
    # Find the function token index
    $funcTokenIdx = -1
    for ($i = 0; $i -lt $filteredTokens.Count; $i++) {
        if ($filteredTokens[$i].Extent.StartOffset -eq $f.Extent.StartOffset) {
            $funcTokenIdx = $i
            break
        }
    }
    
    Write-Host "Function: $($f.Name), TokenIndex: $funcTokenIdx"
    if ($funcTokenIdx -gt 0) {
        $prevToken = $filteredTokens[$funcTokenIdx - 1]
        Write-Host "  Prev token kind: $($prevToken.Kind)"
        Write-Host "  Prev token text: $($prevToken.Text)"
        
        # Check if it is comment help
        $isCommentHelp = $prevToken.Kind -eq 'Comment' -and (
            $prevToken.Text -like '*.[sS][yY][nN][oO][pP][sS][iI][sS]*' -or
            $prevToken.Text -like '*.[dD][eE][sS][cC][rR][iI][pP][tT][iI][oO][nN]*'
        )
        Write-Host "  Is preceding comment help: $isCommentHelp"
    } else {
        Write-Host "  No preceding token or index not found."
    }
    Write-Host "--------------------"
}
