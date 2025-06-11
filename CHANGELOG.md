# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.69] - 2025-06-11

### Τεκμηρίωση

- docs(changelog): ενημέρωση CHANGELOG.md

## [1.0.68] - 2025-06-10

### 🐛 Διορθώθηκαν

#### Alpine Linux Group Conflicts
- Επίλυση conflict με το προεγκατεστημένο Alpine 'users' group (GID 100)
  - Smart conditional logic για ανίχνευση GID collision
  - PGID=100: χρήση existing 'users' group
  - PGID≠100: δημιουργία custom 'appgroup'
- Διόρθωση "chown: unknown user/group appuser:appgroup" error
  - Μετάβαση σε numeric ${PUID}:${PGID} ownership
  - Platform-agnostic approach που παίζει παντού

#### Critical Path Typo
- Διόρθωση: `/tm` → `/tmp` στο chmod 1777
  - Χωρίς αυτό, το healthcheck fallback θα απέτυχνε silently
  - Affects: PowerShell temp file operations

### 🔄 Αλλαγές
- Refactoring του user creation flow με if/else logic
- Adoption των numeric IDs σε όλα τα chown operations
- Improved error resilience για edge cases

### ✨ Προστέθηκαν
- Full compatibility matrix:
  - ✅ Unraid NAS (99:100 - nobody:users)
  - ✅ Standard Linux (1000:1000)
  - ✅ Synology DSM (1024:100)
  - ✅ Custom environments (arbitrary UID/GID)
- Comments για documentation του Alpine behavior

## [1.0.67] - 2025-06-10

### 🐛 Διορθώθηκαν

#### Alpine Linux User Creation Syntax
- Αφαίρεση του `-S` flag από το `addgroup` (unsupported στο Alpine/BusyBox)
- Αντικατάσταση `-S` με `-D` στο `adduser` για Alpine compatibility
  - `-D`: Don't assign password (Alpine style)
  - `-S`: System user (Debian/Ubuntu style - not available)
- Προσθήκη explicit shell specification: `-s /bin/sh`
- Διόρθωση argument ordering για BusyBox utilities

### 🔄 Αλλαγές
- Μετάβαση από GNU coreutils syntax σε BusyBox syntax
- Χρήση Alpine-specific flags για user/group management
- Βελτίωση compatibility με το mcr.microsoft.com/powershell Alpine image

### 📝 Τεκμηρίωση
- Ενημέρωση CHANGELOG.md με αναλυτικές εγγραφές για v1.0.66
- Προσθήκη τεχνικών details για το dynamic UID/GID feature
- Χρήση emoji categories για improved readability

## [1.0.66] - 2025-06-10

### ✨ Προστέθηκαν
- Dynamic UID/GID support στο Dockerfile για πλήρη Unraid compatibility
  - ARG directives για PUID/PGID με default values 99:100 (nobody:users)
  - Configurable user creation κατά το build time
  - Υποστήριξη custom builds: `docker build --build-arg PUID=1000`

### 🔄 Αλλαγές
- Προσθήκη .cache και .local directories για PowerShell module caching
- Βελτίωση directory structure για better module isolation
- Cleanup των verbose comments για cleaner Dockerfile

### 🐛 Διορθώθηκαν
- Typo fix: `/tm` → `/tmp` στο chmod command (critical για healthcheck fallback)

### 📝 Τεκμηρίωση
- Ενημέρωση CHANGELOG.md με detailed entries για versions 1.0.64 και 1.0.65
- Προσθήκη emoji categories για καλύτερη αναγνωσιμότητα
- Αναλυτική τεκμηρίωση των breaking changes και fixes

## [1.0.65] - 2025-06-10

### 🐛 Διορθώθηκαν
- Διόρθωση absolute path για το entrypoint.sh στο Dockerfile
  - Από: `./entrypoint.sh` (relative path που μπορεί να προκαλέσει issues)
  - Σε: `/home/appuser/scripts/entrypoint.sh` (explicit absolute path)
- Διόρθωση Windows-specific paths στο run.ps1
  - Import-Module από hardcoded Windows path σε relative path
  - Συμβατότητα με Linux container environment

### 🔄 Αλλαγές
- Μετάβαση από PowerShell SecretManagement σε Docker secrets
  - Αντικατάσταση `Get-Secret` cmdlet με `Get-Content` από mounted secrets
  - Χρήση standard Docker pattern `/run/secrets/*`
  - Platform-agnostic secret management

## [1.0.64] - 2025-06-10

### 📝 Τεκμηρίωση
- Ενημέρωση README.md με βελτιωμένες οδηγίες

### 🐛 Διορθώθηκαν
- Διόρθωση λογικής αποστολής ειδοποιήσεων ώστε να στέλνονται μόνο για τις επηρεαζόμενες γέφυρες
  - Αντικατάσταση του `$CurrentState` με το specific bridge object στο `Send-BridgeNotification`
  - Προσθήκη validation για την ύπαρξη του bridge state πριν την αποστολή
  - Βελτίωση error handling με descriptive messages

### 🔄 Αλλαγές
- Διόρθωση μορφοποίησης module manifest (καθαρισμός κενών γραμμών)
- Refactoring του `Invoke-BridgeStatusComparison` για καλύτερη readability
  - Αντικατάσταση inline handlers με lookup table
  - Απλοποίηση της λογικής με `ContainsKey` check
  - Βελτίωση του control flow με early continues

## [1.0.63] - 2025-06-05

### 📝 Τεκμηρίωση
- Ενημέρωση README.md με εκτενές παράδειγμα για SecretStore automation
- Ενημέρωση CHANGELOG.md με την τρέχουσα έκδοση

### ✨ Προστέθηκαν
- Detailed guide για ασφαλή αυτοματοποίηση με Microsoft.PowerShell.SecretStore
  - Step-by-step οδηγίες για unattended execution
  - NIST SP 800-53 (IA-5) compliant approach
  - Best practices για secret management
- Παραδείγματα για:
  - Vault password storage με Export-Clixml
  - SecretStore configuration για automation
  - Secure secret retrieval σε scripts

### 🔧 CI & Συντήρηση
- Βελτίωση release workflow με automated changelog commits
  - Git user configuration για github-actions[bot]
  - Auto-commit changelog updates με [skip ci] flag
  - Push changes πριν το release creation
- Version bump από 1.0.62 σε 1.0.63

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






