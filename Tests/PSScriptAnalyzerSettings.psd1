@{
    # Version
    Severity            = @('Error', 'Warning', 'Information')

    # Include all default rules
    IncludeDefaultRules = $true

    # Specific rules configuration
    Rules               = @{
        # Performance Rules
        PSAvoidUsingCmdletAliases                      = @{
            Enable = $true
        }

        PSAvoidUsingWMICmdlet                          = @{
            Enable = $true
        }

        PSAvoidUsingEmptyCatchBlock                    = @{
            Enable = $true
        }

        # Security Rules
        PSAvoidUsingPlainTextForPassword               = @{
            Enable = $true
        }

        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }

        # Code Clarity Rules
        PSProvideCommentHelp                           = @{
            Enable                  = $false
            ExportedOnly            = $false
            BlockComment            = $true
            VSCodeSnippetCorrection = $true
            Placement               = 'begin'
        }

        PSUseApprovedVerbs                             = @{
            Enable = $true
        }

        PSReservedCmdletChar                           = @{
            Enable = $true
        }

        PSReservedParams                               = @{
            Enable = $true
        }

        PSUseConsistentIndentation                     = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }

        PSUseConsistentWhitespace                      = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            CheckParameter                          = $false
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSAlignAssignmentStatement                     = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSUseCorrectCasing                             = @{
            Enable = $true
        }

        # Compatibility Rules
        PSUseCompatibleSyntax                          = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
    }
    # Exclude specific rules if needed
    ExcludeRules        = @(
        # Greek text in strings is OK
        'PSAvoidUsingDoubleQuotesForConstantString'
    )
}