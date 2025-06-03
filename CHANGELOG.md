# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα τεκμηριώνονται σε αυτό το αρχείο,
ακολουθώντας το πρότυπο [Keep a Changelog](https://keepachangelog.com/).

---

## [1.0.58] - 2025-05-31

### ❌ Αφαιρέθηκαν

- refactor: Μόνο ενημέρωση έκδοσης στο psd1
(το changelog πλέον γίνεται upstream)

---

## [1.0.53] - 2025-05-31

### ✨ Προστέθηκαν

- Ενσωμάτωση mikepenz/release-changelog-builder-action για αυτόματο changelog
- Προσθήκη έξυπνης επιλογής From ref με Get-LatestTagOnCurrentBranch
- Νέο test-matrix job & cleanup artifacts για multi-OS/multi-version PowerShell

### ♻️ Αλλαγές/Βελτιώσεις

- Απλοποίηση και βελτίωση λογικής git log και Gatekeeper

---

## [1.0.52] - 2025-05-30

### ✨ Προστέθηκαν

- Προσθήκη ExcludeHousekeeping switch στο Update-ReleaseChangeLog.ps1
- Δυνατότητα έξυπνου commit filtering (From/To refs,
ExcludeHousekeeping & IncludeMergeCommits flags)

---

## [1.0.51] - 2025-05-29

### ✨ Προστέθηκαν

- Ξεχωριστό βήμα tagging Docker image ως latest
- Εισαγωγή helper functions Send-BridgeNotification &
Write-BridgeStage στο BridgeWatcher.psm1
- Μεταφορά helper functions σε ξεχωριστά αρχεία

### ♻️ Αλλαγές/Βελτιώσεις

- Αναδιάρθρωση PowerShell Module Publish workflow
(inputs, setup, checkout depth)

---

## [1.0.50] - 2025-05-29

### ♻️ Αλλαγές/Βελτιώσεις

- Πλήρης αναβάθμιση Update-ReleaseChangeLog.ps1
με error handling & verbose logging
- Επανασχεδιασμός Get-PotentialNextVersion.ps1
με καλύτερο error handling και semver ταξινόμηση
- Ενοποίηση Release Orchestrator σε Release Process (ενσωμάτωση Gatekeeper)
- Structured stages σε Set-FinalModuleVersion.ps1

---

## [1.0.48] - 2025-05-29

### ✨ Προστέθηκαν

- HEALTHCHECK & αλλαγή ENTRYPOINT σε Alpine shell στο Dockerfile
- Προστέθηκε φάκελος εξόδου `/tmp`,
try/catch & exit 1 σε σφάλμα στο Start-BridgeStatusMonitor

---

## [1.0.44] - 2025-05-28

### ✨ Προστέθηκαν

- Flag αρχείο changelog_updated.flag για νέα commits
- Υποστήριξη καταστάσεων “Κλειστή για συντήρηση” σε όλα τα layers (cmdlets & tests)
- Υποστήριξη custom format view για Bridge.Status (BridgeStatus.format.ps1xml)
- Νέα Pester tests για “Κλειστή για συντήρηση” transitions

---

## [1.0.42] - 2025-05-28

### ♻️ Αλλαγές/Βελτιώσεις

- Βελτιστοποίηση workflow δημοσίευσης PowerShell module (actions/checkout@v4,
fetch all tags, bump/update/commit/tag/release/publish, error handling)

---

## [1.0.39] - 2025-05-28

### ♻️ Αλλαγές/Βελτιώσεις

- Ενεργοποίηση τερματισμού pipeline σε αποτυχίες tests
- Αναβάθμιση actions, caching modules, conditional test & coverage upload

---

## [1.0.38] - 2025-05-20

### 🐛 Διορθώθηκαν

- Έλεγχος για μη κενές optional παραμέτρους στο New-BridgePushoverPayload
- Συντακτικό λάθος στο git tag --sort στο Get-GitCommitsSinceLastRelease.ps1

### ✨ Προστέθηκαν

- Filtering, merge support & προστασία διπλότυπων changelogs στο release pipeline

---

## [1.0.37] - 2025-05-19

### ♻️ Αλλαγές/Βελτιώσεις

- Αφαίρεση break από το catch στη Start-BridgeStatusMonitor για συνεχή παρακολούθηση

### ✨ Προστέθηκαν

- Υποστήριξη custom format view για Bridge.Status
- Pester tests για αλλαγές status “Κλειστή για συντήρηση”

---

## [1.0.34] - 2025-05-16

### ✨ Προστέθηκαν

- Πρόσθετα Pester tests για “Κλειστή για συντήρηση” στο Invoke-BridgeStatusComparison

---

## [1.0.31] - 2025-05-07

### ♻️ Αλλαγές/Βελτιώσεις

- Πλήρης εναρμόνιση headers → emojis στο Get-FormattedReleaseNotes.ps1
- Νέα μορφοποίηση release notes

---

## [1.0.30] - 2025-05-07

### 🐛 Διορθώθηκαν

- Λάθος σύνταξη στο git tag --sort για Get-GitCommitsSinceLastRelease.ps1

### ✨ Προστέθηκαν

- Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs

---

## [1.0.29] - 2025-05-06

### ✨ Προστέθηκαν

- Emojis στα release notes & βελτιωμένο help στο Get-FormattedReleaseNotes

---

## [1.0.27] - 2025-05-01

### ✨ Προστέθηκαν

- Script για αυτόματη αύξηση patch version σε PowerShell module manifest

---

## [1.0.25] - 2025-05-01

### ♻️ Αλλαγές/Βελτιώσεις

- Ενημέρωση regex για sections τύπου `## [1.0.24]` στο CHANGELOG.md
- Script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow

---

## [1.0.20] - 2025-05-01

### ✨ Προστέθηκαν

- Script-based σύστημα αυτόματης δημιουργίας και ενημέρωσης
CHANGELOG στο `/scripts/`

---

## [1.0.19] - 2025-05-01

### 🐛 Διορθώθηκαν

- Προσθήκη try/catch στο test αποτυχίας API για Send-BridgePushoverRequest
- Structured exception handling στο Send-BridgePushoverRequest

---

## [1.0.18] - 2025-05-01

### ♻️ Αλλαγές/Βελτιώσεις

- Μετάφραση description & διόρθωση αναμενόμενων κλήσεων Write-BridgeLog σε Start-BridgeStatusMonitor.Tests
- Μετάφραση μηνυμάτων καταγραφής σε Start-BridgeStatusMonitor σε ελληνικά
- Διόρθωση άρθρου στο Verbose μήνυμα της Invoke-BridgeStatusComparison

---

## [1.0.0] - 2025-04-27

### ✨ Προστέθηκαν

- Αρχικό release του BridgeWatcher module

---
