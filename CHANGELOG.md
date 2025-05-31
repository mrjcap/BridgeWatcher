## 📦 Uncategorized

- ci: auto-update CHANGELOG.md for v1.0.53
- chore: Bump version to 1.0.53 and update changelog
- Ενημέρωση changelog-configuration.json
- ci(powershell-module-publish): χρήση softprops/action-gh-release@v2 και προσθήκη permissions για write στο contents
- ci(release-process): προσθήκη εξάρτησης pre-release στο test job
- chore: προσθήκη BOM σε αρχεία PowerShell που περιέχουν μη-ASCII χαρακτήρες (BridgeWatcher.psd1, Update-Changelog.ps1, Get-ReleaseNotes.ps1, Convert-GreekChangelogCommitsToSections.ps1)
- test: ενημέρωση των Unit Tests για Get-BridgeStatusComparison – απλοποίηση mocks (αφαίρεση παραμέτρων από Get-BridgePreviousStatus και προσαρμογή του Get-Content)
- ci(script):  Ενημέρωση Update-Changelog.ps1 για βελτιστοποίηση εντοπισμού header, χρήση Write-Verbose και διόρθωση regex
- ci(script): Αντικαταστάθηκαν Write-Host με Write-Output στο Update-Psd1ModuleVersion για καλύτερη συμβατότητα με CI pipeline
- ci(script): αντικαταστάθηκαν Write-Host με Write-Verbose και απλοποιήθηκε δημιουργία και έλεγχος αρχείου changelog_updated.flag
- ci: προσθήκη SonarCloud Analysis και ενημέρωση workflow release
- ci: χρήση codequality.yml αντί sonarcloud.yml στο workflow έκδοσης
- ci: αντικατάσταση SonarCloud με Codacy για ανάλυση κώδικα
- ci: προσθήκη ανάλυσης Codacy και αφαίρεση SonarCloud στο workflow release
- ci: Ενημέρωση release.yml
- ci: ενημέρωση build_changelog με HYBRID mode και προσθήκη configuration αρχείου
- ci: auto-update CHANGELOG.md for v1.0.54
- chore: Bump version to 1.0.54 and update changelog

