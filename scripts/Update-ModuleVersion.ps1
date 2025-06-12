<#
.SYNOPSIS
  Updates the version in a PowerShell module manifest (.psd1).
.DESCRIPTION
  Reads a .psd1 file and either increments the patch version or sets a specific version.
  Optionally, writes the new version to the GITHUB_ENV file for use in GitHub Actions.
.PARAMETER Path
  The path to the .psd1 file.
.PARAMETER Version
  The specific version to set (e.g., '1.2.4'). If not provided, increments the patch version.
.PARAMETER GitHubEnv
  Optionally, the path to the GITHUB_ENV file for CI environments.
.EXAMPLE
  Update-ModuleVersion -Path './MyModule.psd1' -Version '1.2.4'
.EXAMPLE
  Update-ModuleVersion -Path './MyModule.psd1' -GitHubEnv $env:GITHUB_ENV
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter()]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

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

function Update-ModuleVersionContent {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Content,
        [string]$OldVersion,
        [string]$NewVersion
    )

    if ($PSCmdlet.ShouldProcess("Module version", "Update from '$OldVersion' to '$NewVersion'")) {
        return $Content -replace "ModuleVersion\s*=\s*'$OldVersion'", "ModuleVersion = '$NewVersion'"
    }
    return $Content
}

try {
    $content = Get-Content $Path -Raw
    $currentVersion = Get-ModuleVersion -Content $content
    Write-Output "Current version: $currentVersion"

    if ($Version) {
        # Set specific version
        $newVersion = $Version
        Write-Output "Setting version to: $newVersion"
    } else {
        # Increment patch version
        $versionParts = $currentVersion -split '\.'
        $versionParts[2] = [int]$versionParts[2] + 1
        $newVersion = "$($versionParts[0]).$($versionParts[1]).$($versionParts[2])"
        Write-Output "Incrementing patch version to: $newVersion"
    }

    $newContent = Update-ModuleVersionContent -Content $content -OldVersion $currentVersion -NewVersion $newVersion
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