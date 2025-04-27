Import-Module ".\src\BridgeWatcher.psm1" -Force -Verbose
#$Credxmlpath    = ".\securePassword.credential"
#$password       = Import-CliXml -Path $Credxmlpath
#Unlock-SecretStore -Password $password
$startBridgeStatusMonitorSplat = @{
    IntervalSeconds    = 300
    MaxIterations      = 0
    OutputFile         = ".\bridge_status.json"
    ApiKey             = (Get-Secret -Name GoogleVisionAPI -AsPlainText)
    PoApiKey           = (Get-Secret -Name PoApiKey -AsPlainText)
    PoUserKey          = (Get-Secret -Name PoUserKey -AsPlainText)
    Verbose            = $true
}
Start-BridgeStatusMonitor @startBridgeStatusMonitorSplat