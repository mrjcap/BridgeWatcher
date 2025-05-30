# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο καταγράφονται εδώ.

Η μορφή ακολουθεί το [Keep a Changelog](https://keepachangelog.com/el/1.1.0/) και το έργο εφαρμόζει [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.52] - 2025-05-30

### Προστέθηκαν

- Προσθήκη συγχρονισμού branch πριν το push
- Προσθήκη ξεχωριστού βήματος tagging εικόνας ως latest

### Τεκμηρίωση

- Ενημέρωση CHANGELOG.md
- Ενημέρωση CHANGELOG.md
- ci: update CHANGELOG.md for v1.0.52
- Ενημέρωση commit CHANGELOG.md σε ξεχωριστό βήμα
- chore: Bump version to 1.0.51 and update changelog
- chore: Bump version to 1.0.50 and update changelog

## [1.0.51] - 2025-05-29

### Προστέθηκαν

* Προσθήκη ξεχωριστού βήματος tagging εικόνας ως latest

### Τεκμηρίωση

* Ενημέρωση commit CHANGELOG.md σε ξεχωριστό βήμα

---

## [1.0.46] - 2025-05-29

### Προστέθηκαν

* Εισαγωγή helper functions `Send-BridgeNotification` και `Write-BridgeStage` στο `BridgeWatcher.psm1`.

* Προσθήκη workflow_call trigger με required secrets και έξοδο `module_published` μέσω set_output.

* Προστέθηκαν secrets στα PowerShell Module workflows.

* HEALTHCHECK, αλλαγή ENTRYPOINT σε `sh` και βελτίωση ρύθμισης timezone.

* Default φάκελος εξόδου, χρήση try/catch και έξοδος με κωδικό 1 σε σφάλμα.

* Προέλεγχος νέων commits πριν από την αύξηση έκδοσης.

### Αλλαγές

* Τροποποίηση shell wrapper: αφαίρεση της get_secret, έλεγχος μόνο ύπαρξης secrets πριν το `exec pwsh`.

### Αφαιρέθηκαν

* Μεταφορά των `Send-BridgeNotification`, `Write-BridgeStage` και άλλων helper functions από το `Invoke-BridgeStatusComparison` σε ξεχωριστά `.ps1` αρχεία.

---

## [1.0.39] - 2025-05-28

### Προστέθηκαν

* Έλεγχος για μη κενές optional παραμέτρους στο `New-BridgePushoverPayload`.

---

## [1.0.38] - 2025-05-20

### Αλλαγές

* Έλεγχος για μη κενές optional παραμέτρους στο `New-BridgePushoverPayload`.

---

## [1.0.37] - 2025-05-19

### Αφαιρέθηκαν

* Αφαίρεση break από το catch για συνεχή παρακολούθηση.

---

## [1.0.36] - 2025-05-17

### Αλλαγές

* Δημιουργία `BridgeStatus.format.ps1xml` με custom πίνακα για τα πεδία GefyraName, GefyraStatus και Timestamp.

* Ορισμός PSTypeName = 'Bridge.Status' στο output της `New-BridgeStatusObject` για ενεργοποίηση format view.

* Ενημέρωση `BridgeWatcher.psd1` με `FormatsToProcess` για σωστό import του format.

* 🧹 Καθαρισμός: ευθυγράμμιση πεδίων και ενοποίηση indentation στο module manifest.

* Αλλαγές καθαρά αισθητικές.

---

## [1.0.35] - 2025-05-17

### Προστέθηκαν

* Pester tests για αλλαγές status "Κλειστή για συντήρηση" στην `Invoke-BridgeStatusComparison`.

### Αλλαγές

* Τροποποίηση GitHub Actions pipeline (PowerShell Module CI) ώστε να ενεργοποιείται και στον κλάδο `develop`.

---

## [1.0.34] - 2025-05-16

### Προστέθηκαν

* Pester tests για status "Κλειστή για συντήρηση" στις `Invoke-BridgeStatusComparison` και `Invoke-BridgeClosedNotification`.

---

## [1.0.33] - 2025-05-16

### Προστέθηκαν

* Υποστήριξη και χειρισμός status "Κλειστή για συντήρηση" στα `Invoke-BridgeStatusComparison`, `Invoke-BridgeClosedNotification` και `Get-BridgeStatusFrom...`.

---

## [1.0.32] - 2025-05-16

### Προστέθηκαν

* Πλήρης εναρμόνιση headers → emojis στο `Get-FormattedReleaseNotes.ps1`.

---

## [1.0.31] - 2025-05-07

### Διορθώθηκαν

* Διόρθωση συντακτικού στο git tag --sort για `Get-GitCommitsSinceLastRelease.ps1`.

### Τεκμηρίωση

* Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs.

---

## [1.0.30] - 2025-05-07

### Προστέθηκαν

* Emojis στα release notes και βελτιωμένο help στο `Get-FormattedReleaseNotes`.

---

## [1.0.28] - 2025-05-01

### Προστέθηκαν

* Script για αυτόματη αύξηση patch version σε PowerShell module manifest.

---

## [1.0.27] - 2025-05-01

### Προστέθηκαν

* Υποστήριξη εκδόσεων με και χωρίς "v" στο `Get-ReleaseNotes.ps1`.

---

## [1.0.26] - 2025-05-01

### Τεκμηρίωση

* Ενημέρωση regex ώστε να ταιριάζει σωστά τα sections τύπου `## [1.0.24]` στο CHANGELOG.md.

---

## [1.0.25] - 2025-05-01

### Προστέθηκαν

* Script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow.

---

## [1.0.21] - 2025-05-01

### Προστέθηκαν

* Σύστημα αυτόματης ενημέρωσης CHANGELOG στο `/scripts/`.

---

## [1.0.20] - 2025-05-01

### Προστέθηκαν

* Προσθήκη try/catch στο test αποτυχίας API για `Send-BridgePushoverRequest`.

* Mock της `Send-BridgeNotification` για έλεγχο ειδοποίησης τύπου Closed.

* Υποστήριξη structured exception handling στο `Send-BridgePushoverRequest`.

---

## [v1.0.18] - 2025-05-01

### Αλλαγές

* Αλλαγή encoding όλων των αρχείων σε UTF8-BOM.

---

## [v1.0.17] - 2025-04-30

### Αλλαγές

* Ενημέρωση workflow `docker-build.yml`.

---

## [1.0.12] - 2025-04-29

### Αλλαγές

* Ενημέρωση `Dockerfile`.

---

## [1.0.9] - 2025-04-29

### Τεκμηρίωση

* Προσθήκες Docker, entrypoint, .env, workflow και αλλαγή run.ps1.

---

## [1.0.8] - 2025-04-28

### Προστέθηκαν

* Δημιουργία αρχείου `powershell-docs.yml`.

---

## [1.0.7] - 2025-04-28

### Αλλαγές

* Ενημέρωση αρχείου `powershell-docs.yml`.

---

## [1.0.5] - 2025-04-27

### Αλλαγές

* Ενημέρωση αρχείου `publish.yml`.

---

## [1.0.4] - 2025-04-27

### Προστέθηκαν

* Ενσωμάτωση [Codecov](https://about.codecov.io/) για παρακολούθηση κάλυψης κώδικα.

---

## [1.0.3] - 2025-04-27

### Αλλαγές

* Ενημέρωση `README.md` με λεπτομέρειες για τη χρήση του module.

---

## [1.0.2] - 2025-04-27

### Προστέθηκαν

* Δημιουργία workflow για `Publish` στο [PowerShell Gallery](https://www.powershellgallery.com/).

---

## [1.0.1] - 2025-04-23

### Προστέθηκαν

* Επανασχεδιασμός λογικής `Get-DiorigaStatus` με προτεραιότητα στην εικόνα.

* Αποφυγή OCR όταν δεν απαιτείται.

* Κατάργηση χρονικών συγκρίσεων (`Now > To`).

* Προσθήκη αυτοτεκμηρίωσης (README generator).

* 100% test coverage σε OCR + εικόνα logic.

---

## [1.0.0] - 2025-04-11

### Προστέθηκαν

* Αρχική έκδοση PowerShell module BridgeWatcher.

* 100% [Pester](https://pester.dev/) test coverage.

* Λειτουργίες για ανίχνευση κατάστασης γεφυρών, OCR μέσω Google Vision API και ειδοποιήσεις Pushover.

* Συνεχής ενσωμάτωση [GitHub Actions](https://docs.github.com/en/actions) με έλεγχο δοκιμών και κάλυψης.

---

