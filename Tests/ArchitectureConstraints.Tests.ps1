$script:ModulePath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\BridgeWatcher")
$script:Files = Get-ChildItem -Path $script:ModulePath -Recurse -Filter *.ps* | Where-Object -Property Extension -in -Value '.ps1', '.psm1', '.psd1'

Describe -Name "Architectural Constraints (OOP)" -Fixture {
    It -Name "Should not contain OOP keywords (class, enum, interface) in <Name>" -ForEach $script:Files -Test {
        $file = $_
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        $oopNodes = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.TypeDefinitionAst]
        }, $true)

        if ($oopNodes) {
            $types = $oopNodes.Name -join ", "
            throw "File $($file.Name) contains forbidden OOP keywords: $types"
        }

        $oopNodes.Count | Should -Be -ExpectedValue 0
    }
}