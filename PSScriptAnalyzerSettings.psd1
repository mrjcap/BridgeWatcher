@{
    Rules = @{
        PSUseApprovedVerbs = @{
            Enable = $true
        }
        PSAvoidUsingWriteHost = @{
            Enable = $true
        }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }
        PSProvideCommentHelp = @{
            Enable                  = $true
            ExportedOnly            = $false
            BlockComment            = $true
            VSCodeSnippetCorrection = $true
            Placement               = 'begin'
        }
    }
}
