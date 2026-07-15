# BridgeWatcher.psm1
Set-StrictMode -Version Latest

#region Module Loading
$publicFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File
foreach ($file in $publicFiles) {
    . $file.FullName
}

$privateFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File
foreach ($file in $privateFiles) {
    . $file.FullName
}
#endregion Module Loading
