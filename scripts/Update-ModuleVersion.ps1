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

<#
.SYNOPSIS
Reads the version from module manifest text.

.DESCRIPTION
Extracts the ModuleVersion field from the supplied manifest text and fails if it is absent.

.PARAMETER Content
The source text to inspect.
#>
function Get-ModuleVersion {
    param([string]$Content)
    if ($Content -match "ModuleVersion\s*=\s*'(\d+\.\d+\.\d+)'") {
        return $matches[1]
    }
    else {
        throw "Could not find version in .psd1 file."
    }
}

<#
.SYNOPSIS
Replaces the module version in manifest text.

.DESCRIPTION
Substitutes the expected module version in the manifest text only when ShouldProcess approves.

.PARAMETER Content
The source text to inspect.

.PARAMETER OldVersion
The current version expected in the manifest.

.PARAMETER NewVersion
The replacement version to write to the manifest.
#>
function Update-ModuleVersionContent {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Content,
        [string]$OldVersion,
        [string]$NewVersion
    )

    if ($PSCmdlet.ShouldProcess("Module version", "Update from '$OldVersion' to '$NewVersion'")) {
        return $Content -replace "(?m)^(?<left>\s*ModuleVersion)(?<between>\s*=\s*)(?<quote>')(?<ver>\d+\.\d+\.\d+)(')", ('${left}${between}${quote}' + $NewVersion + "'")
    }
    return $Content
}

try {
    $content = Get-Content -Path $Path -Raw
    $currentVersion = Get-ModuleVersion -Content $content
    Write-Output -InputObject "Current version: $currentVersion"

    if ($Version) {
        $newVersion = $Version
        Write-Output -InputObject "Setting version to: $newVersion"
    } else {
        $versionParts = $currentVersion -split '\.'
        $versionParts[2] = [int]$versionParts[2] + 1
        $newVersion = "$($versionParts[0]).$($versionParts[1]).$($versionParts[2])"
        Write-Output -InputObject "Incrementing patch version to: $newVersion"
    }

    $newContent = Update-ModuleVersionContent -Content $content -OldVersion $currentVersion -NewVersion $newVersion
    $utf8Bom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true
    [System.IO.File]::WriteAllText($Path, $newContent, $utf8Bom)
    Write-Output -InputObject "Updated version to: $newVersion"

    if ($GitHubEnv) {
        "new_version=$newVersion" | Out-File -FilePath $GitHubEnv -Append
    }

    return $newVersion
}
catch {
    Write-Output -InputObject $_.Exception.Message
    exit 1
}
