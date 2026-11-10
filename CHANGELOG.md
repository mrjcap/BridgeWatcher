# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.100] - 2026-11-10

### 🐛 Διορθώσεις

- fix(docker): αναβάθμιση πακέτων Alpine κατά το build για επίλυση του CVE-2026-4738
- fix(Export-BridgeStatusJson): αποκατάσταση ατομικής εγγραφής αρχείου μέσω προσωρινού αρχείου και μετονομασίας

### ♻️ Αναδιαρθρώσεις

- refactor(Invoke-BridgeStatusComparison): αφαίρεση παρωχημένων παραμέτρων και επιστροφή ρητών συμβάντων αλλαγής
- refactor(Update-BridgeStatus): διόρθωση λογικής αξιολόγησης κατάστασης για σωστή αντιστοίχιση δεικτών
- refactor(Resolve-BridgeStateForChange): διόρθωση λογικής αντιστοίχισης κατάστασης

## [1.0.99] - 2026-07-03

### 🐛 Διορθώσεις

- fix: αποστολή εφεδρικών ειδοποιήσεων Pushover όταν αποτυγχάνει το Google Cloud Vision OCR

## [1.0.98] - 2026-07-03

### 🐛 Διορθώσεις

- fix: συμπλήρωση ImageHash σε παλαιότερα αρχεία κατάστασης για αποφυγή σφαλμάτων StrictMode

## [1.0.97] - 2026-07-03

### 🐛 Διορθώσεις

- fix: χρήση κατακερματισμού περιεχομένου εικόνας (hash) για αποφυγή διπλότυπων ενημερώσεων προγράμματος

## [1.0.96] - 2026-07-03

### 🐛 Διορθώσεις

- fix: σύγκριση του ImageUrl στη σύγκριση κατάστασης για εντοπισμό ενημερώσεων προγραμματισμένου κλεισίματος

## [1.0.93] - 2026-07-02

### 🐛 Διορθώσεις

- fix: αποδοχή κενής τιμής στην παράμετρο PreviousState της Resolve-BridgeStateForChange

## [1.0.91] - 2026-07-02

### 🐛 Διορθώσεις

- fix: αποστολή ειδοποίησης κατά την πρώτη εκτέλεση όταν δεν υπάρχει προηγούμενη κατάσταση
- fix(docker): δημιουργία καταλόγου /app/logs και διόρθωση διαδρομής healthcheck

## [1.0.88] - 2026-07-02

### 🐛 Διορθώσεις

- fix: αντικατάσταση ορφανής μεταβλητής στις κεφαλίδες αιτήματος OCR

## [1.0.87] - 2026-07-01

### ♻️ Αναδιαρθρώσεις

- refactor(module): καθαρισμός δεικτών region και ενεργοποίηση StrictMode σε όλο το module

## [1.0.84] - 2026-07-01

### 🐛 Διορθώσεις

- fix(docker): αφαίρεση su-exec από το entrypoint καθώς το container τρέχει ως appuser

## [1.0.82] - 2026-07-01

### ✨ Χαρακτηριστικά

- feat: ρυθμιζόμενος κατάλογος log μέσω New-BridgeConfiguration

### 🐛 Διορθώσεις

- fix: διόρθωση ελληνικών τόνων και συνένωσης URL

## [1.0.79] - 2026-06-30

### ✨ Χαρακτηριστικά

- feat(config): προσθήκη βοηθητικού Get-SafeBridgeConfiguration για ασφαλείς ελέγχους null στη ρύθμιση
- feat(Send-BridgePushover): ενημέρωση Send-BridgePushover βάσει ευρημάτων αναθεώρησης
- feat(Invoke-BridgeStatusComparison): ενημέρωση Invoke-BridgeStatusComparison βάσει ευρημάτων αναθεώρησης
- feat(Get-BridgeStatusMonitor): ενημέρωση Get-BridgeStatusMonitor βάσει ευρημάτων αναθεώρησης
- feat(Get-BridgeStatusComparison): ενημέρωση Get-BridgeStatusComparison βάσει ευρημάτων αναθεώρησης
- feat(Get-BridgeStatus): ενημέρωση Get-BridgeStatus βάσει ευρημάτων αναθεώρησης

## [1.0.78] - 2026-06-25

### 🐛 Διορθώσεις

- fix(logging): προσθήκη των σταδίων που λείπουν στο ValidateSet του Write-BridgeStage
- fix(resilience): επιβολή ατομικών εγγραφών κατάστασης μέσω μετονομασίας προσωρινού αρχείου
- fix(logging): ευθυγράμμιση του ValidateSet με τον υποκείμενο logger
- fix(security): καθαρισμός διαπιστευτηρίων από το ErrorRecord payload
- fix(docker): υποστήριξη δυναμικού PGID στο COPY

## [1.0.76] - 2026-06-24

### ✨ Χαρακτηριστικά

- feat(container): αναβάθμιση περιβάλλοντος εκτέλεσης και powershell
  - ενημέρωση της βασικής εικόνας σε mcr.microsoft.com/dotnet/runtime:10.0.9-alpine3.23
  - αναβάθμιση του PowerShell σε 7.6.3 linux-musl-x64
  - ανανέωση των πακέτων Alpine για τη νέα βάση
- feat: κεντρικοποίηση configuration και επίτευξη 100% test coverage
- feat: εξαγωγή Resolve-BridgeStateForChange ως ξεχωριστό Private function με comprehensive tests
- feat(error-handling): βελτίωση error handling, validation και test coverage

### 🐛 Διορθώσεις

- fix: επίλυση συμβατότητας εξαγωγής JSON με αφαίρεση του μη υποστηριζόμενου ορίσματος Set-Content Encoding

## [1.0.75] - 2025-06-13

### 🐛 Διορθώσεις

- fix(bridgestatuscomparison): ενημέρωση λογικής για μη εύρεση bridge state

## [1.0.74] - 2025-06-12

### 🐛 Διορθώσεις

- fix(dockerfile): αλλαγή έκδοσης curl σε 8.14.1-r0

## [1.0.73] - 2025-06-12

### ✨ Χαρακτηριστικά

- feat: προσθήκη version pinning για Docker packages

### 🐛 Διορθώσεις

- fix(notifications): διόρθωση λογικής εύρεσης bridge state για αποστολή ειδοποιήσεων

## [1.0.71] - 2025-06-11

### ✨ Χαρακτηριστικά

- feat(docker): προσθήκη Docker container για BridgeWatcher

## [1.0.68] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση Alpine user/group conflicts και typo στο Dockerfile

## [1.0.67] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση Alpine Linux user creation syntax στο Dockerfile

## [1.0.66] - 2025-06-10

### ✨ Χαρακτηριστικά

- feat: προσθήκη dynamic UID/GID support για Unraid compatibility

## [1.0.65] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση paths και secrets management για Docker environment

## [1.0.64] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση αποστολής ειδοποιήσεων μόνο για την επηρεαζόμενη γέφυρα

## [1.0.62] - 2025-06-05

### ✨ Χαρακτηριστικά

- feat(bridgewatcher): ενημέρωση Get-BridgeStatusAdvice για χρήση MinutesUntilOpen

### 🐛 Διορθώσεις

- fix(convertfrom-bridgeocrresult): απλοποίηση return για επιστροφή null αντί κενής λίστας
- fix(bridgeocr): διόρθωση OutputType σε PSCustomObject
- fix(ocr): διόρθωση ορθογραφίας σε "Ανοίγει σε"

## [1.0.59] - 2025-06-03

### ✨ Χαρακτηριστικά

- feat(bridgewatcher): προσθήκη ApiKey/PoUserKey/PoApiKey σε Send-BridgeNotification και ενημέρωση handlerMap

## [1.0.45] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: προσθήκη εισαγωγής των helper functions Send-BridgeNotification και Write-BridgeStage στο BridgeWatcher.psm1

## [1.0.38] - 2025-05-20

### ✨ Χαρακτηριστικά

- feat: προσθήκη ελέγχου για μη κενές optional παραμέτρους στο New-BridgePushoverPayload

## [1.0.36] - 2025-05-17

### ✨ Χαρακτηριστικά

- feat: προσθήκη υποστήριξης custom format view για Bridge.Status αντικείμενα

## [1.0.32] - 2025-05-16

### ✨ Χαρακτηριστικά

- feat: προσθήκη χειρισμού "Κλειστή για συντήρηση" στο Invoke-BridgeStatusComparison
- feat: προσθήκη υποστήριξης ειδοποίησης για "Κλειστή για συντήρηση" στο Invoke-BridgeClosedNotification
- feat: προσθήκη υποστήριξης status "Κλειστή για συντήρηση" στη Get-BridgeStatusFromHtml

## [1.0.9] - 2025-04-29

### ✨ Χαρακτηριστικά

- feat(docker): προσθήκη entrypoint.sh για εκκίνηση Docker container
- feat(config): προσθήκη αρχείου .env για παραμετροποίηση μεταβλητών περιβάλλοντος
- feat(docker): προσθήκη Dockerfile για containerization του BridgeWatcher
