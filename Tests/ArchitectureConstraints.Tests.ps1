BeforeAll {
    $script:Files = Get-ChildItem -Path "$PSScriptRoot\..\BridgeWatcher\*" -Recurse -Include *.ps1, *.psm1, *.psd1
}

Describe "Architectural Constraints (OOP)" {
    It "Should not contain OOP keywords (class, enum, interface) in <Name>" -ForEach $script:Files {
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

        $oopNodes.Count | Should -Be 0
    }
}
