function Get-MockSecureString {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    param([string]$String)
    ConvertTo-SecureString -String $String -AsPlainText -Force
}
