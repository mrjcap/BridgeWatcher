<#
.SYNOPSIS
  Bumps the patch version in a PowerShell module manifest (.psd1).
.DESCRIPTION
  Reads a .psd1 file, increments the patch version, updates the manifest, and outputs the new version.
  Optionally, writes the new version to the GITHUB_ENV file for use in GitHub Actions.
.PARAMETER Path
  The path to the .psd1 file.
.PARAMETER GitHubEnv
  Optionally, the path to the GITHUB_ENV file for CI environments.
.EXAMPLE
  Update-Psd1ModuleVersion -Path './MyModule.psd1' -GitHubEnv $env:GITHUB_ENV
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter()]
    [string]$GitHubEnv
)

function Get-ModuleVersion {
    param([string]$Content)
    if ($Content -match "ModuleVersion\s*=\s*'(\d+\.\d+\.\d+)'") {
        return $matches[1]
    }
    else {
        throw "Could not find version in .psd1 file."
    }
}

function Set-ModuleVersion {
    param(
        [string]$Content,
        [string]$OldVersion,
        [string]$NewVersion
    )
    return $Content -replace "ModuleVersion\s*=\s*'$OldVersion'", "ModuleVersion = '$NewVersion'"
}
try {
    $content = Get-Content $Path -Raw
    $currentVersion = Get-ModuleVersion -Content $content
    Write-Output "Current version: $currentVersion"
    $versionParts = $currentVersion -split '\.'
    $versionParts[2] = [int]$versionParts[2] + 1
    $newVersion = "$($versionParts[0]).$($versionParts[1]).$($versionParts[2])"
    $newContent = Set-ModuleVersion -Content $content -OldVersion $currentVersion -NewVersion $newVersion
    Set-Content $Path -Value $newContent
    Write-Output "Updated version to: $newVersion"
    if ($GitHubEnv) {
        "new_version=$newVersion" | Out-File -FilePath $GitHubEnv -Append
    }
    return $newVersion
}
catch {
    Write-Output $_.Exception.Message
    exit 1
}