<#
.SYNOPSIS
    Sets the exact module version in a PowerShell module manifest.
.DESCRIPTION
    Updates the ModuleVersion property in the specified .psd1 file, and sets GitHub Actions env var if available.
.PARAMETER Version
    The exact version string to set (e.g., 1.2.4).
.PARAMETER Path
    Path to the module manifest. Default: ./BridgeWatcher.psd1
.EXAMPLE
    ./Set-FinalModuleVersion.ps1 -Version 1.2.4
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [string]$Path = './BridgeWatcher.psd1'
)

if (-not (Test-Path $Path)) {
    throw "Module manifest file '$Path' not found."
}

$content = Get-Content $Path -Raw
if ($content -notmatch "ModuleVersion\s*=\s*'[^']+'") {
    throw "No ModuleVersion property found in $Path."
}
$newContent = $content -replace "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion = '$Version'"
Set-Content $Path -Value $newContent -Encoding UTF8

if ($env:GITHUB_ENV) {
    "new_version=$Version" | Out-File -FilePath $env:GITHUB_ENV -Append
}