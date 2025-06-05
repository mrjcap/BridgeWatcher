function Get-ChangelogFormat {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Ενημερώνει το υπάρχον CHANGELOG.md για εναρμόνιση με τη νέα μορφή.

    .DESCRIPTION
    Η Get-ChangelogFormat μετατρέπει τους υπάρχοντες τίτλους sections στο CHANGELOG.md
    ώστε να εναρμονιστούν με τη νέα μορφή που περιλαμβάνει emojis και συνεπή ονομασία.

    .PARAMETER ChangelogPath
    Η διαδρομή προς το αρχείο CHANGELOG.md που θα ενημερωθεί.

    .PARAMETER BackupOriginal
    Αν ενεργοποιηθεί, δημιουργεί αντίγραφο ασφαλείας του αρχικού αρχείου.

    .OUTPUTS
    None. Ενημερώνει το αρχείο CHANGELOG.md στη θέση του.

    .EXAMPLE
    Get-ChangelogFormat -ChangelogPath './CHANGELOG.md' -BackupOriginal

    .EXAMPLE
    Get-ChangelogFormat -ChangelogPath './CHANGELOG.md' -Verbose

    .NOTES
    Το script διατηρεί τη δομή και το περιεχόμενο, αλλάζει μόνο τους τίτλους των sections.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Leaf)) {
                    throw "Το αρχείο '$_' δεν βρέθηκε."
                }
                if ($_ -notmatch '\.md$') {
                    throw 'Το αρχείο πρέπει να έχει κατάληξη .md'
                }
                $true
            })]
        [string]$ChangelogPath,

        [switch]$BackupOriginal
    )

    begin {
        Write-Verbose 'Ξεκινάει η ενημέρωση του changelog format...'

        # Δημιουργία backup αν ζητήθηκε
        if ($BackupOriginal) {
            $backupPath = $ChangelogPath -replace '\.md$', "_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
            Copy-Item -Path $ChangelogPath -Destination $backupPath -Force
            Write-Verbose "✅ Δημιουργήθηκε backup: $backupPath"
        }

        # Mapping παλαιών → νέων τίτλων
        $sectionMapping = @{
            '### Προστέθηκαν'            = '### ✨ Προστέθηκαν'
            '### Αλλαγές'                = '### 🔄 Αλλαγές'
            '### Υποψήφια προς απόσυρση' = '### ⚠️ Υποψήφια προς απόσυρση'
            '### Αφαιρέθηκαν'            = '### ❌ Αφαιρέθηκαν'
            '### Διορθώθηκαν'            = '### 🐛 Διορθώθηκαν'
            '### Ασφάλεια'               = '### 🔒 Ασφάλεια'
            '### Τεκμηρίωση'             = '### 📝 Τεκμηρίωση'
            # Πρόσθετες παραλλαγές
            '### Νέα χαρακτηριστικά'     = '### ✨ Προστέθηκαν'
            '### Διορθώσεις'             = '### 🐛 Διορθώθηκαν'
            '### CI & Συντήρηση'         = '### 🔧 CI & Συντήρηση'
        }

        $changesCount = 0
    }

    process {
        try {
            # Ανάγνωση αρχείου
            $getContentSplat = @{
                Path     = $ChangelogPath
                Raw      = $true
                Encoding = 'utf8BOM'
            }
            $content = Get-Content @getContentSplat

            Write-Verbose "📖 Αναγνώστηκε αρχείο: $ChangelogPath"

            # Εφαρμογή mappings
            foreach ($mapping in $sectionMapping.GetEnumerator()) {
                $oldTitle = [regex]::Escape($mapping.Key)
                $newTitle = $mapping.Value

                if ($content -match $oldTitle) {
                    $content = $content -replace $oldTitle, $newTitle
                    $changesCount++
                    Write-Verbose "🔄 Αντικαταστάθηκε: '$($mapping.Key)' → '$newTitle'"
                }
            }

            # Εγγραφή ενημερωμένου περιεχομένου
            if ($changesCount -gt 0) {
                $setContentSplat = @{
                    Path      = $ChangelogPath
                    Value     = $content
                    Encoding  = 'utf8BOM'
                    NoNewline = $true
                }
                Set-Content @setContentSplat

                Write-Verbose '💾 Αποθηκεύτηκε ενημερωμένο αρχείο'
            } else {
                Write-Verbose 'ℹ️ Δεν απαιτούνται αλλαγές'
            }

        } catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                ([System.Exception]::new("Σφάλμα ενημέρωσης changelog: $($_.Exception.Message)")),
                'ChangelogUpdateError',
                [System.Management.Automation.ErrorCategory]::WriteError,
                $ChangelogPath
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    end {
        if ($changesCount -gt 0) {
            Write-Verbose '✅ Η ενημέρωση ολοκληρώθηκε επιτυχώς!'
            Write-Verbose "📊 Σύνολο αλλαγών: $changesCount"
        } else {
            Write-Verbose 'ℹ️ Το changelog είναι ήδη ενημερωμένο.'
        }

        if ($BackupOriginal) {
            Write-Verbose "💾 Backup δημιουργήθηκε: $backupPath"
        }
    }
}

function Test-ChangelogFormat {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Ελέγχει τη συμμόρφωση του CHANGELOG.md με το προσδοκώμενο format.

    .DESCRIPTION
    Η Test-ChangelogFormat επαληθεύει ότι το CHANGELOG.md ακολουθεί τη σωστή δομή
    και περιλαμβάνει τα αναμενόμενα elements.

    .PARAMETER ChangelogPath
    Η διαδρομή προς το αρχείο CHANGELOG.md που θα ελεγχθεί.

    .OUTPUTS
    [PSCustomObject] Αντικείμενο με τα αποτελέσματα του ελέγχου.

    .EXAMPLE
    Test-ChangelogFormat -ChangelogPath './CHANGELOG.md'

    .EXAMPLE
    $results = Test-ChangelogFormat -ChangelogPath './CHANGELOG.md'
    if (-not $results.IsValid) {
        $results.Issues | ForEach-Object { Write-Warning $_ }
    }

    .NOTES
    Ελέγχει για συνέπεια στη μορφοποίηση, παρουσία emojis και σωστή δομή.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Leaf)) {
                    throw "Το αρχείο '$_' δεν βρέθηκε."
                }
                $true
            })]
        [string]$ChangelogPath
    )

    begin {
        $expectedSections = @(
            '### ✨ Προστέθηκαν',
            '### 🔄 Αλλαγές',
            '### ⚠️ Υποψήφια προς απόσυρση',
            '### ❌ Αφαιρέθηκαν',
            '### 🐛 Διορθώθηκαν',
            '### 🔒 Ασφάλεια',
            '### 📝 Τεκμηρίωση',
            '### 🔧 CI & Συντήρηση'
        )

        $issues = @()
        $warnings = @()
    }

    process {
        try {
            $getContentSplat = @{
                Path     = $ChangelogPath
                Raw      = $true
                Encoding = 'utf8BOM'
            }
            $content = Get-Content @getContentSplat

            Write-Verbose "📖 Αναλύεται αρχείο: $ChangelogPath"

            # Έλεγχος header
            if ($content -notmatch '# Αρχείο Αλλαγών') {
                $issues += "❌ Λείπει το κύριο header '# Αρχείο Αλλαγών'"
            }

            # Έλεγχος αναφοράς σε Keep a Changelog
            if ($content -notmatch 'Keep a Changelog|keepachangelog\.com') {
                $warnings += "⚠️ Προτείνεται αναφορά στο 'Keep a Changelog'"
            }

            # Έλεγχος version entries
            $versionPattern = '## \[\d+\.\d+\.\d+\] - \d{4}-\d{2}-\d{2}'
            $versionMatches = [regex]::Matches($content, $versionPattern)

            if ($versionMatches.Count -eq 0) {
                $issues += '❌ Δεν βρέθηκαν έγκυρα version entries'
            } else {
                Write-Verbose "✅ Βρέθηκαν $($versionMatches.Count) version entries"
            }

            # Έλεγχος sections με emojis
            $foundSectionsWithEmojis = 0
            $foundSectionsWithoutEmojis = 0

            foreach ($section in $expectedSections) {
                if ($content -match [regex]::Escape($section)) {
                    $foundSectionsWithEmojis++
                }
            }

            # Έλεγχος για sections χωρίς emojis
            $sectionsWithoutEmojis = @(
                '### Προστέθηκαν',
                '### Αλλαγές',
                '### Διορθώθηκαν',
                '### Τεκμηρίωση'
            )

            foreach ($section in $sectionsWithoutEmojis) {
                if ($content -match "^$([regex]::Escape($section))$" -and
                    $content -notmatch "^$([regex]::Escape($section.Insert(4, ' ✨|🔄|🐛|📝')))") {
                    $foundSectionsWithoutEmojis++
                }
            }

            if ($foundSectionsWithoutEmojis -gt 0) {
                $warnings += "⚠️ Βρέθηκαν $foundSectionsWithoutEmojis sections χωρίς emojis - προτείνεται ενημέρωση"
            }

        } catch {
            $issues += "❌ Σφάλμα ανάλυσης αρχείου: $($_.Exception.Message)"
        }
    }

    end {
        $isValid = $issues.Count -eq 0

        return [PSCustomObject]@{
            IsValid  = $isValid
            Issues   = $issues
            Warnings = $warnings
            Summary  = if ($isValid) { '✅ Το changelog είναι έγκυρο' } else { "❌ Βρέθηκαν $($issues.Count) σφάλματα" }
        }
    }
}

# Εκτέλεση των functions αν το script καλείται απευθείας
if ($MyInvocation.InvocationName -ne '.') {
    $changelogPath = Join-Path (Get-Location) 'CHANGELOG.md'

    if (Test-Path $changelogPath) {
        Write-Verbose '🔍 Έλεγχος τρέχοντος format...'
        $testResults = Test-ChangelogFormat -ChangelogPath $changelogPath

        Write-Verbose $testResults.Summary

        if ($testResults.Issues) {
            $testResults.Issues | ForEach-Object { Write-Verbose $_ }
        }

        if ($testResults.Warnings) {
            $testResults.Warnings | ForEach-Object { Write-Verbose $_ }
        }

        if ($testResults.Warnings -contains '⚠️ Βρέθηκαν * sections χωρίς emojis - προτείνεται ενημέρωση') {
            $response = Read-Host "`nΘέλετε να ενημερώσετε το format αυτόματα; (Y/N)"
            if ($response -match '^[Yy]') {
                Get-ChangelogFormat -ChangelogPath $changelogPath -BackupOriginal -Verbose
            }
        }
    } else {
        Write-Warning 'Δεν βρέθηκε αρχείο CHANGELOG.md στον τρέχοντα φάκελο.'
    }
}