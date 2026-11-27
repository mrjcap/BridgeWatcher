Set-StrictMode -Version Latest

$publicFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File
foreach ($file in $publicFiles) {
    . $file.FullName
}

$privateFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File
foreach ($file in $privateFiles) {
    . $file.FullName
}
