# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),  
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.47] - 2025-05-29

## [1.0.46] - 2025-05-29

### Προστέθηκαν

- Προσθήκη εισαγωγής των helper functions Send-BridgeNotification και Write-BridgeStage στο BridgeWatcher.psm1
- Προσθήκη workflow_call trigger με required secrets, έξοδος module_published μέσω set_output και αφαίρεση βημάτων Pester/tests.
- Προστέθηκαν τα secrets στα PowerShell Module workflows
- Προστέθηκε HEALTHCHECK, αλλάζει ENTRYPOINT σε sh και βελτιώνει ρύθμιση timezone
- Προστέθηκε default φάκελο εξόδου, try/catch και έξοδο με κωδικό 1 σε σφάλμα
- Προστέθηκε προέλεγχος νέων commits πριν από version bump

### Αλλαγές

- Αλλαγή του shell wrapper, αφαιρεί τη συνάρτηση get_secret και ελέγχει μόνο ύπαρξη των secrets πριν από το exec pwsh

### Αφαιρέθηκαν

- Αφαίρεση της συνάρτησης Send-BridgeNotification από το Invoke-BridgeStatusComparison και μεταφορά της σε ξεχωριστό αρχείο Send-BridgeNotification.ps1
- Αφαίρεση της συνάρτησης Write-BridgeStage από το Invoke-BridgeStatusComparison και μεταφορά της σε ξεχωριστό αρχείο Write-BridgeStage.ps1
- Αφαίρεση των helper functions από το Invoke-BridgeStatusComparison και μεταφορά τους σε ξεχωριστά .ps1 αρχεία

## [1.0.45] - 2025-05-29

### Προστέθηκαν

- Προσθήκη εισαγωγής των helper functions Send-BridgeNotification και Write-BridgeStage στο BridgeWatcher.psm1
- Προσθήκη workflow_call trigger με required secrets, έξοδος module_published μέσω set_output και αφαίρεση βημάτων Pester/tests.
- Προστέθηκαν τα secrets στα PowerShell Module workflows
- Προστέθηκε HEALTHCHECK, αλλάζει ENTRYPOINT σε sh και βελτιώνει ρύθμιση timezone
- Προστέθηκε default φάκελο εξόδου, try/catch και έξοδο με κωδικό 1 σε σφάλμα
- Προστέθηκε προέλεγχος νέων commits πριν από version bump

### Αλλαγές

- Αλλαγή του shell wrapper, αφαιρεί τη συνάρτηση get_secret και ελέγχει μόνο ύπαρξη των secrets πριν από το exec pwsh

### Αφαιρέθηκαν

- Αφαίρεση της συνάρτησης Send-BridgeNotification από το Invoke-BridgeStatusComparison και μεταφορά της σε ξεχωριστό αρχείο Send-BridgeNotification.ps1
- Αφαίρεση της συνάρτησης Write-BridgeStage από το Invoke-BridgeStatusComparison και μεταφορά της σε ξεχωριστό αρχείο Write-BridgeStage.ps1
- Αφαίρεση των helper functions από το Invoke-BridgeStatusComparison και μεταφορά τους σε ξεχωριστά .ps1 αρχεία

## [1.0.39] - 2025-05-28

### Προστέθηκαν

- Προσθήκη ελέγχου για μη κενές optional παραμέτρους στο New-BridgePushoverPayload

## [1.0.38] - 2025-05-20

### Προστέθηκαν

- Προσθήκη ελέγχου για μη κενές optional παραμέτρους στο New-BridgePushoverPayload


### Τεκμηρίωση

- Ενημέρωση CHANGELOG.md

## [1.0.37] - 2025-05-19

### Αφαιρέθηκαν

- Αφαίρεση break από το catch για συνεχή παρακολούθηση

### Τεκμηρίωση

- Ενημέρωση CHANGELOG.md

## [1.0.36] - 2025-05-17

### Αλλαγές

- Αλλαγές: Δημιουργήθηκε το αρχείο BridgeStatus.format.ps1xml με custom πίνακα για τα πεδία GefyraName, GefyraStatus και Timestamp (μορφοποιημένο)

- Ορίστηκε PSTypeName = 'Bridge.Status' στο output της New-BridgeStatusObject για ενεργοποίηση format view

- Ενημερώθηκε το BridgeWatcher.psd1 με FormatsToProcess = @('Formats/BridgeStatus.format.ps1xml') για σωστό import του format

- 🧹 Cleanup: Ευθυγράμμιση πεδίων στο module manifest για αναγνωσιμότητα

- Ενοποιήθηκε το indentation για όλα τα πεδία του BridgeWatcher.psd1

- Δεν αλλάζει καμία λειτουργικότητα – purely cosmetic αλλαγή

### Τεκμηρίωση

- Ενημέρωση CHANGELOG.md

## [1.0.35] - 2025-05-17

### Προστέθηκαν

- Προστέθηκαν Pester tests για αλλαγές status "Κλειστή για συντήρηση" στην Invoke-BridgeStatusComparison

### Αλλαγές

- Αλλαγές: ➤ Το GitHub Actions pipeline (PowerShell Module CI) τροποποιήθηκε ώστε να ενεργοποιείται και στον κλάδο develop, εκτός από τον main.

## [1.0.34] - 2025-05-16

### Προστέθηκαν

- Προστέθηκαν Pester tests για αλλαγές status "Κλειστή για συντήρηση" στην Invoke-BridgeStatusComparison
- Προστέθηκε Pester test για status "Κλειστή για συντήρηση" στην Invoke-BridgeClosedNotification

## [1.0.33] - 2025-05-16

### Προστέθηκαν

- Προστέθηκε Pester test για status "Κλειστή για συντήρηση" στην Invoke-BridgeClosedNotification
- Προσθήκη χειρισμού "Κλειστή για συντήρηση" στο Invoke-BridgeStatusComparison
- Προσθήκη υποστήριξης ειδοποίησης για "Κλειστή για συντήρηση" στο Invoke-BridgeClosedNotification
- Προσθήκη υποστήριξης status "Κλειστή για συντήρηση" στη Get-BridgeStatusFromHtml

## [1.0.32] - 2025-05-16

### Προστέθηκαν

- Προσθήκη χειρισμού "Κλειστή για συντήρηση" στο Invoke-BridgeStatusComparison
- Προσθήκη υποστήριξης ειδοποίησης για "Κλειστή για συντήρηση" στο Invoke-BridgeClosedNotification
- Προσθήκη υποστήριξης status "Κλειστή για συντήρηση" στη Get-BridgeStatusFromHtml
- Προστέθηκε: Πλήρης εναρμόνιση headers → emojis στο Get-FormattedReleaseNotes.ps1

## [1.0.31] - 2025-05-07

### Προστέθηκαν

- Προστέθηκε: Πλήρης εναρμόνιση headers → emojis στο Get-FormattedReleaseNotes.ps1

### Διορθώθηκαν

- Διόρθωση: Λάθος σύνταξη στο git tag --sort για Get-GitCommitsSinceLastRelease.ps1

### Τεκμηρίωση

- Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs

## [1.0.30] - 2025-05-07

### Προστέθηκαν

- Προσθήκη emojis στα release notes και βελτιωμένο help στο Get-FormattedReleaseNotes

### Διορθώθηκαν

- Διόρθωση: Λάθος σύνταξη στο git tag --sort για Get-GitCommitsSinceLastRelease.ps1

### Τεκμηρίωση

- Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs

## [1.0.29] - 2025-05-06

### Προστέθηκαν

- Προσθήκη emojis στα release notes και βελτιωμένο help στο Get-FormattedReleaseNotes

### Τεκμηρίωση

- Bump version to 1.0.28 and update CHANGELOG.md

## [1.0.28] - 2025-05-01

### Προστέθηκαν

- Προσθήκη script για αυτόματη αύξηση patch version σε PowerShell module manifest

### Τεκμηρίωση

- Bump version to 1.0.27 and update CHANGELOG.md

## [1.0.27] - 2025-05-01

### Προστέθηκαν

- Προσθήκη script για αυτόματη αύξηση patch version σε PowerShell module manifest
- Υποστήριξη εκδόσεων με χωρίς "v" στο Get-ReleaseNotes.ps1

### Τεκμηρίωση

- Bump version to 1.0.26 and update CHANGELOG.md

## [1.0.26] - 2025-05-01

### Προστέθηκαν

- Υποστήριξη εκδόσεων με χωρίς "v" στο Get-ReleaseNotes.ps1

### Τεκμηρίωση

- Bump version to 1.0.25 and update CHANGELOG.md
- Ενημερώθηκε το regex ώστε να ταιριάζει σωστά τα sections τύπου ## [1.0.24] στο CHANGELOG.md

## [1.0.25] - 2025-05-01

### Προστέθηκαν

- Προσθήκη script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow

### Τεκμηρίωση

- Ενημερώθηκε το regex ώστε να ταιριάζει σωστά τα sections τύπου ## [1.0.24] στο CHANGELOG.md
- Bump version to 1.0.24 and update CHANGELOG.md

## [1.0.24] - 2025-05-01

### Προστέθηκαν

- Προσθήκη script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow

### Τεκμηρίωση

- Bump version to 1.0.23 and update CHANGELOG.md

## [1.0.23] - 2025-05-01

### Τεκμηρίωση

- Bump version to 1.0.22 and update CHANGELOG.md

## [1.0.22] - 2025-05-01

### Τεκμηρίωση

- Bump version to 1.0.21 and update CHANGELOG.md

## [1.0.21] - 2025-05-01

### Προστέθηκαν

- Προσθήκη συστήματος αυτόματης ενημέρωσης CHANGELOG στο /scripts/

### Τεκμηρίωση

- Bump version to 1.0.20 and update CHANGELOG.md
- Ενημέρωση αρχείου CHANGELOG.md
-  Αντικατάσταση inline changelog generation με script-based σύστημα στο publish.yml
- Ενημέρωση αρχείου CHANGELOG.md

## [1.0.20] - 2025-05-01

### Προστέθηκαν

- Προσθήκη συστήματος αυτόματης ενημέρωσης CHANGELOG στο /scripts/
- Προστέθηκε try/catch στο test αποτυχίας API για Send-BridgePushoverRequest
- Προστέθηκε mock της Send-BridgeNotification για έλεγχο ειδοποίησης τύπου Closed
- Προστέθηκε υποστήριξη για structured exception handling στο Send-BridgePushoverRequest

### Τεκμηρίωση

- Ενημέρωση αρχείου CHANGELOG.md
-  Αντικατάσταση inline changelog generation με script-based σύστημα στο publish.yml
- Ενημέρωση αρχείου CHANGELOG.md
- Bump version to 1.0.19 and update CHANGELOG.md
- Ενημερώθηκε το αρχείο CHANGELOG.md
- Ενημέρωση αρχείου CHANGELOG.md

## [v1.0.19] - 2025-05-01

### Προστέθηκαν

- Προστέθηκε try/catch στο test αποτυχίας API για Send-BridgePushoverRequest

## [v1.0.18] - 2025-05-01

### Αλλαγές

- Aλλαξε το encoding όλων των αρχείων σε UTF8-BOM

---

## [v1.0.17] - 2025-04-30

### Αλλαγές

- Ενημερώθηκε το workflow `docker-build.yml`.

---

## [v1.0.16] - 2025-04-29

### Αλλαγές

- Ενημερώθηκε το workflow `docker-build.yml`.
  
---

## [1.0.15] - 2025-04-29

### Αλλαγές

- Ενημερώθηκε το workflow `docker-build.yml`.

---

## [1.0.14] - 2025-04-29

### Αλλαγές

- Ενημερώθηκε το workflow `docker-build.yml`.

---

## [1.0.13] - 2025-04-29

### Αλλαγές

- Ενημερώθηκε το workflow `docker-build.yml`.

---

## [1.0.12] - 2025-04-29

### Αλλαγές

- Ενημερώθηκε το `Dockerfile`.

---

## [1.0.11] - 2025-04-29

### Αλλαγές

- Ενημερώθηκε το `Dockerfile`.

---

## [1.0.10] - 2025-04-29

### Αλλαγές

- Ενημερώθηκε το workflow `docker-build.yml`.

---

## [1.0.9] - 2025-04-29

### Τεκμηρίωση

- Ενημερώθηκε το CHANGELOG.md με προσθήκες Docker, entrypoint, .env, workflow και αλλαγή run.ps1.

---

## [1.0.8] - 2025-04-28

### Αλλαγές

- Ενημερώθηκε το αρχείο `powershell-docs.yml`.

---

## [1.0.7] - 2025-04-28

### Αλλαγές

- Ενημέρωση αρχείου `powershell-docs.yml`.

---

## [1.0.6] - 2025-04-28

### Προστέθηκαν

- Δημιουργήθηκε το αρχείο `powershell-docs.yml`.

---

## [1.0.5] - 2025-04-27

### Αλλαγές

- Ενημέρωση αρχείου `publish.yml`.

---

## [1.0.4] - 2025-04-27

### Προστέθηκαν

- Ενσωμάτωση [Codecov](https://about.codecov.io/) για παρακολούθηση κάλυψης κώδικα.

---

## [1.0.3] - 2025-04-27

### Αλλαγές

- Ενημέρωση του αρχείου `README.md` με λεπτομέρειες για τη χρήση του module.

---

## [1.0.2] - 2025-04-27

### Προστέθηκαν

- Δημιουργία workflow για `Publish` στο [PowerShell Gallery](https://www.powershellgallery.com/).

---

## [1.0.1] - 2025-04-23

### Προστέθηκαν

- Επανασχεδιασμός λογικής `Get-DiorigaStatus` με προτεραιότητα στην εικόνα.
- Αποφυγή OCR όταν δεν απαιτείται.
- Κατάργηση χρονικών συγκρίσεων (`Now > To`).
- Προσθήκη αυτοτεκμηρίωσης (README generator).
- 100% test coverage σε OCR + εικόνα logic.

---

## [1.0.0] - 2025-04-11

### Προστέθηκαν

- Αρχική έκδοση του PowerShell module BridgeWatcher.
- 100% [Pester](https://pester.dev/) test coverage.
- Λειτουργίες για ανίχνευση κατάστασης γεφυρών, OCR μέσω Google Vision API και ειδοποιήσεις Pushover.
- Συνεχής ενσωμάτωση [GitHub Actions](https://docs.github.com/en/actions) με έλεγχο δοκιμών και κάλυψης.

---


























