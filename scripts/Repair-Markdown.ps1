<#
.SYNOPSIS
    Διορθώνει αυτόματα αρχεία Markdown για Codacy/markdownlint (MD022, MD025).
.DESCRIPTION
    - Προσθέτει κενές γραμμές πριν/μετά από headings (MD022).
    - Εξασφαλίζει μόνο ένα top-level heading ανά αρχείο (MD025).
.PARAMETER Path
    Το path προς τα αρχεία .md (π.χ. 'docs/*.md').
.EXAMPLE
    ./Repair-Markdown.ps1 -Path 'docs/*.md'
.NOTES
    Ενσωμάτωσε το script ως βήμα στο CI workflow σου πριν το markdown linting.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

$mdFiles = Get-ChildItem -Path $Path -File

foreach ($file in $mdFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding utf8BOM

    # MD022: Ensure blank lines before/after headings
    $content = $content -replace "(?m)([^\r\n])(\r?\n#)", "`$1`r`n`r`n#"
    $content = $content -replace "(?m)(#.*?)(\r?\n[^\r\n])", "`$1`r`n`r`n`2"

    # MD025: Remove extra top-level headings (keep only the first)
    $lines = $content -split "`r?`n"
    $foundTopLevel = $false
    $fixedLines = foreach ($line in $lines) {
        if ($line -match '^# ') {
            if (-not $foundTopLevel) {
                $foundTopLevel = $true
                $line
            }
            # skip extra top-level headings
        } else {
            $line
        }
    }
    $fixedContent = ($fixedLines -join "`r`n").Trim()
    Set-Content $file.FullName -Value $fixedContent -Encoding UTF8
}

Write-Verbose "✅ Markdown formatting fixed for Codacy (MD022/MD025)."