# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο καταγράφονται εδώ.

Η μορφή ακολουθεί το [Keep a Changelog](https://keepachangelog.com/el/1.1.0/) και το έργο εφαρμόζει [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.48] - 2025-05-29

### Changed
- Bump version (αυτόματη ενημέρωση από pipeline).

---

## [1.0.47] - 2025-05-29

### Changed
- Bump version (αυτόματη ενημέρωση από pipeline).

---

## [1.0.46] - 2025-05-29

### Added
- Εισαγωγή helper functions `Send-BridgeNotification` και `Write-BridgeStage` στο `BridgeWatcher.psm1`.
- Προσθήκη workflow_call trigger με required secrets και έξοδο `module_published` μέσω set_output.
- Προστέθηκαν secrets στα PowerShell Module workflows.
- HEALTHCHECK, αλλαγή ENTRYPOINT σε `sh` και βελτίωση ρύθμισης timezone.
- Default φάκελος εξόδου, χρήση try/catch και έξοδος με κωδικό 1 σε σφάλμα.
- Προέλεγχος νέων commits πριν από version bump.

### Changed
- Τροποποίηση shell wrapper: αφαίρεση της get_secret, έλεγχος μόνο ύπαρξης secrets πριν το `exec pwsh`.

### Removed
- Μεταφορά των `Send-BridgeNotification`, `Write-BridgeStage` και άλλων helper functions από το `Invoke-BridgeStatusComparison` σε ξεχωριστά `.ps1` αρχεία.

---

## [1.0.45] - 2025-05-29

### Changed
- Bump version (αυτόματη ενημέρωση από pipeline).

---

## [1.0.39] - 2025-05-28

### Added
- Έλεγχος για μη κενές optional παραμέτρους στο `New-BridgePushoverPayload`.

---

## [1.0.38] - 2025-05-20

### Changed
- Έλεγχος για μη κενές optional παραμέτρους στο `New-BridgePushoverPayload`.

### Documentation
- Ενημέρωση CHANGELOG.md.

---

## [1.0.37] - 2025-05-19

### Removed
- Αφαίρεση break από το catch για συνεχή παρακολούθηση.

### Documentation
- Ενημέρωση CHANGELOG.md.

---

## [1.0.36] - 2025-05-17

### Changed
- Δημιουργία `BridgeStatus.format.ps1xml` με custom πίνακα για τα πεδία GefyraName, GefyraStatus και Timestamp.
- Ορισμός PSTypeName = 'Bridge.Status' στο output της `New-BridgeStatusObject` για ενεργοποίηση format view.
- Ενημέρωση `BridgeWatcher.psd1` με `FormatsToProcess` για σωστό import του format.
- 🧹 Cleanup: ευθυγράμμιση πεδίων και ενοποίηση indentation στο module manifest.
- Αλλαγές purely cosmetic.

### Documentation
- Ενημέρωση CHANGELOG.md.

---

## [1.0.35] - 2025-05-17

### Added
- Pester tests για αλλαγές status "Κλειστή για συντήρηση" στην `Invoke-BridgeStatusComparison`.

### Changed
- Τροποποίηση GitHub Actions pipeline (PowerShell Module CI) ώστε να ενεργοποιείται και στον κλάδο `develop`.

---

## [1.0.34] - 2025-05-16

### Added
- Pester tests για status "Κλειστή για συντήρηση" στις `Invoke-BridgeStatusComparison` και `Invoke-BridgeClosedNotification`.

---

## [1.0.33] - 2025-05-16

### Added
- Υποστήριξη και χειρισμός status "Κλειστή για συντήρηση" στα `Invoke-BridgeStatusComparison`, `Invoke-BridgeClosedNotification` και `Get-BridgeStatusFromHtml`.

---

## [1.0.32] - 2025-05-16

### Added
- Πλήρης εναρμόνιση headers → emojis στο `Get-FormattedReleaseNotes.ps1`.

---

## [1.0.31] - 2025-05-07

### Added
- Πλήρης εναρμόνιση headers → emojis στο `Get-FormattedReleaseNotes.ps1`.

### Fixed
- Διόρθωση συντακτικού στο git tag --sort για `Get-GitCommitsSinceLastRelease.ps1`.

### Documentation
- Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs.

---

## [1.0.30] - 2025-05-07

### Added
- Emojis στα release notes και βελτιωμένο help στο `Get-FormattedReleaseNotes`.

### Fixed
- Διόρθωση συντακτικού στο git tag --sort για `Get-GitCommitsSinceLastRelease.ps1`.

---

## [1.0.29] - 2025-05-06

### Documentation
- Bump version σε 1.0.28 και ενημέρωση CHANGELOG.md.

---

## [1.0.28] - 2025-05-01

### Added
- Script για αυτόματη αύξηση patch version σε PowerShell module manifest.

---

## [1.0.27] - 2025-05-01

### Added
- Υποστήριξη εκδόσεων με και χωρίς "v" στο `Get-ReleaseNotes.ps1`.

---

## [1.0.26] - 2025-05-01

### Documentation
- Ενημέρωση regex ώστε να ταιριάζει σωστά τα sections τύπου `## [1.0.24]` στο CHANGELOG.md.

---

## [1.0.25] - 2025-05-01

### Added
- Script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow.

---

## [1.0.24] - 2025-05-01

### Documentation
- Bump version σε 1.0.23 και ενημέρωση CHANGELOG.md.

---

## [1.0.23] - 2025-05-01

### Documentation
- Bump version σε 1.0.22 και ενημέρωση CHANGELOG.md.

---

## [1.0.22] - 2025-05-01

### Documentation
- Bump version σε 1.0.21 και ενημέρωση CHANGELOG.md.

---

## [1.0.21] - 2025-05-01

### Added
- Σύστημα αυτόματης ενημέρωσης CHANGELOG στο `/scripts/`.

---

## [1.0.20] - 2025-05-01

### Added
- Προσθήκη try/catch στο test αποτυχίας API για `Send-BridgePushoverRequest`.
- Mock της `Send-BridgeNotification` για έλεγχο ειδοποίησης τύπου Closed.
- Υποστήριξη structured exception handling στο `Send-BridgePushoverRequest`.

---

## [v1.0.19] - 2025-05-01

### Added
- Προσθήκη try/catch στο test αποτυχίας API για `Send-BridgePushoverRequest`.

---

## [v1.0.18] - 2025-05-01

### Changed
- Αλλαγή encoding όλων των αρχείων σε UTF8-BOM.

---

## [v1.0.17] - 2025-04-30

### Changed
- Ενημέρωση workflow `docker-build.yml`.

---

## [v1.0.16] - 2025-04-29

### Changed
- Ενημέρωση workflow `docker-build.yml`.

---

## [1.0.15] - 2025-04-29

### Changed
- Ενημέρωση workflow `docker-build.yml`.

---

## [1.0.14] - 2025-04-29

### Changed
- Ενημέρωση workflow `docker-build.yml`.

---

## [1.0.13] - 2025-04-29

### Changed
- Ενημέρωση workflow `docker-build.yml`.

---

## [1.0.12] - 2025-04-29

### Changed
- Ενημέρωση `Dockerfile`.

---

## [1.0.11] - 2025-04-29

### Changed
- Ενημέρωση `Dockerfile`.

---

## [1.0.10] - 2025-04-29

### Changed
- Ενημέρωση workflow `docker-build.yml`.

---

## [1.0.9] - 2025-04-29

### Documentation
- Ενημέρωση CHANGELOG.md με προσθήκες Docker, entrypoint, .env, workflow και αλλαγή run.ps1.

---

## [1.0.8] - 2025-04-28

### Added
- Δημιουργία αρχείου `powershell-docs.yml`.

---

## [1.0.7] - 2025-04-28

### Changed
- Ενημέρωση αρχείου `powershell-docs.yml`.

---

## [1.0.6] - 2025-04-28

### Changed
- Δημιουργία αρχείου `powershell-docs.yml`.

---

## [1.0.5] - 2025-04-27

### Changed
- Ενημέρωση αρχείου `publish.yml`.

---

## [1.0.4] - 2025-04-27

### Added
- Ενσωμάτωση [Codecov](https://about.codecov.io/) για παρακολούθηση κάλυψης κώδικα.

---

## [1.0.3] - 2025-04-27

### Changed
- Ενημέρωση `README.md` με λεπτομέρειες για τη χρήση του module.

---

## [1.0.2] - 2025-04-27

### Added
- Δημιουργία workflow για `Publish` στο [PowerShell Gallery](https://www.powershellgallery.com/).

---

## [1.0.1] - 2025-04-23

### Added
- Επανασχεδιασμός λογικής `Get-DiorigaStatus` με προτεραιότητα στην εικόνα.
- Αποφυγή OCR όταν δεν απαιτείται.
- Κατάργηση χρονικών συγκρίσεων (`Now > To`).
- Προσθήκη αυτοτεκμηρίωσης (README generator).
- 100% test coverage σε OCR + εικόνα logic.

---

## [1.0.0] - 2025-04-11

### Added
- Αρχική έκδοση PowerShell module BridgeWatcher.
- 100% [Pester](https://pester.dev/) test coverage.
- Λειτουργίες για ανίχνευση κατάστασης γεφυρών, OCR μέσω Google Vision API και ειδοποιήσεις Pushover.
- Συνεχής ενσωμάτωση [GitHub Actions](https://docs.github.com/en/actions) με έλεγχο δοκιμών και κάλυψης.

---