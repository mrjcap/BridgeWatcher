# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.98] - 2026-07-03

### 🐛 Διορθώσεις

- fix: backfill ImageHash on legacy state files to prevent StrictMode errors

## [1.0.97] - 2026-07-03

### 🐛 Διορθώσεις

- fix: use image content hashing to deduplicate schedule updates

## [1.0.96] - 2026-07-03

### 🐛 Διορθώσεις

- fix: compare ImageUrl in status comparison to detect scheduled closure updates

## [1.0.93] - 2026-07-02

### 🐛 Διορθώσεις

- fix: allow empty PreviousState in Resolve-BridgeStateForChange parameter

## [1.0.91] - 2026-07-02

### 🐛 Διορθώσεις

- fix: send notification on first run when no previous state exists
- fix(docker): create /app/logs directory and fix healthcheck path

## [1.0.90] - 2026-07-02

### 🐛 Διορθώσεις

- fix(ci): fix container test and Trivy SARIF upload in docker workflow

## [1.0.89] - 2026-07-02

### 🐛 Διορθώσεις

- fix: resolve PSScriptAnalyzer violations for UTF8-BOM and trailing whitespaces

## [1.0.88] - 2026-07-02

### 🐛 Διορθώσεις

- fix: replace orphaned  with  in OCR request headers

## [1.0.87] - 2026-07-01

### ♻️ Αναδιαρθρώσεις

- refactor(Update-BridgeStatus): translate comments, documentation, and logs to Greek
- refactor(Send-BridgePushover): translate comments, documentation, and logs to Greek
- refactor(Invoke-BridgeStatusComparison): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeStatusMonitor): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeStatus): translate comments, documentation, and logs to Greek
- refactor(Get-BridgePreviousStatus): translate comments, documentation, and logs to Greek
- refactor(Write-BridgeLog): translate comments, documentation, and logs to Greek
- refactor(Test-BridgeResult): translate comments, documentation, and logs to Greek
- refactor(Send-BridgePushoverRequest): translate comments, documentation, and logs to Greek
- refactor(Send-BridgeNotification): translate comments, documentation, and logs to Greek
- refactor(Resolve-BridgeStatus): translate comments, documentation, and logs to Greek
- refactor(Resolve-BridgeStateForChange): translate comments, documentation, and logs to Greek
- refactor(New-BridgeResult): translate comments, documentation, and logs to Greek
- refactor(New-BridgeConfiguration): translate comments, documentation, and logs to Greek
- refactor(Invoke-BridgeOpenedNotification): translate comments, documentation, and logs to Greek
- refactor(Invoke-BridgeOCRRequest): translate comments, documentation, and logs to Greek
- refactor(Invoke-BridgeOCRGoogleCloud): translate comments, documentation, and logs to Greek
- refactor(Invoke-BridgeClosedNotification): translate comments, documentation, and logs to Greek
- refactor(Get-SafeBridgeConfiguration): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeStatusObject): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeStatusFromHtml): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeStatusAdvice): translate comments, documentation, and logs to Greek
- refactor(Get-BridgePushoverPayload): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeOCRRequestBody): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeNameFromUri): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeImage): translate comments, documentation, and logs to Greek
- refactor(Get-BridgeHtml): translate comments, documentation, and logs to Greek
- refactor(Export-BridgeStatusJson): translate comments, documentation, and logs to Greek
- refactor(ConvertTo-BridgeTimeRange): translate comments, documentation, and logs to Greek
- refactor(ConvertTo-BridgeClosedDuration): translate comments, documentation, and logs to Greek
- refactor(ConvertFrom-BridgeOCRResult): translate comments, documentation, and logs to Greek
- refactor(ConvertFrom-BridgeHtml): translate comments, documentation, and logs to Greek
- refactor(module): clean up region markers and set strict mode module-wide

### 🧪 Δοκιμές

- test(Invoke-BridgeOCRRequest): fix file BOM encoding for compliance
- test(ConvertFrom-BridgeHtml): fix file BOM encoding for compliance
- test(Write-BridgeLog): translate test blocks, descriptions, and comments to Greek
- test(Update-BridgeStatus): translate test blocks, descriptions, and comments to Greek
- test(Test-BridgeResult): translate test blocks, descriptions, and comments to Greek
- test(Test-BridgeResult): translate test blocks, descriptions, and comments to Greek
- test(Send-BridgePushoverRequest): translate test blocks, descriptions, and comments to Greek
- test(Send-BridgePushover): translate test blocks, descriptions, and comments to Greek
- test(Send-BridgeNotification): translate test blocks, descriptions, and comments to Greek
- test(RunScript): translate test blocks, descriptions, and comments to Greek
- test(Resolve-BridgeStatus): translate test blocks, descriptions, and comments to Greek
- test(Resolve-BridgeStateForChange): translate test blocks, descriptions, and comments to Greek
- test(PesterConfiguration): translate test blocks, descriptions, and comments to Greek
- test(PSScriptAnalyzerSettings): translate test blocks, descriptions, and comments to Greek
- test(New-BridgeResult): translate test blocks, descriptions, and comments to Greek
- test(New-BridgeConfiguration): translate test blocks, descriptions, and comments to Greek
- test(ModuleExports): translate test blocks, descriptions, and comments to Greek
- test(MockHelper): translate test blocks, descriptions, and comments to Greek
- test(Invoke-BridgeStatusComparison): translate test blocks, descriptions, and comments to Greek
- test(Invoke-BridgeOpenedNotification): translate test blocks, descriptions, and comments to Greek
- test(Invoke-BridgeOCRRequest): translate test blocks, descriptions, and comments to Greek
- test(Invoke-BridgeOCRGoogleCloud): translate test blocks, descriptions, and comments to Greek
- test(Invoke-BridgeClosedNotification): translate test blocks, descriptions, and comments to Greek
- test(Integration): translate test blocks, descriptions, and comments to Greek
- test(Get-SafeBridgeConfiguration): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeStatusObject): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeStatusMonitor): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeStatusFromHtml): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeStatusAdvice): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeStatus): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeStatus-Refactored): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgePushoverPayload): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgePreviousStatus): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeOCRRequestBody): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeNameFromUri): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeImage): translate test blocks, descriptions, and comments to Greek
- test(Get-BridgeHtml): translate test blocks, descriptions, and comments to Greek
- test(Export-BridgeStatusJson): translate test blocks, descriptions, and comments to Greek
- test(DockerBuildWorkflow): translate test blocks, descriptions, and comments to Greek
- test(ConvertTo-BridgeTimeRange): translate test blocks, descriptions, and comments to Greek
- test(ConvertTo-BridgeClosedDuration): translate test blocks, descriptions, and comments to Greek
- test(ConvertFrom-BridgeOCRResult): translate test blocks, descriptions, and comments to Greek
- test(ConvertFrom-BridgeHtml): translate test blocks, descriptions, and comments to Greek

### 🎨 Στυλ & Μορφοποίηση

- style(docs): fix table formatting in README.md for better readability

## [1.0.86] - 2026-07-01

### 🐛 Διορθώσεις

- fix(docker): αντικατάσταση περιττού cat με ανακατεύθυνση εισόδου (SC2002)

### 🎨 Στυλ & Μορφοποίηση

- style(tests): διόρθωση indentation και alignment για συμμόρφωση με Codacy

## [1.0.85] - 2026-07-01

### 🐛 Διορθώσεις

- fix(ci): ενεργοποίηση upload αποτελεσμάτων ανάλυσης Codacy

## [1.0.84] - 2026-07-01

### 🐛 Διορθώσεις

- fix(docker): αφαίρεση su-exec από το entrypoint καθώς το container τρέχει ως appuser

## [1.0.82] - 2026-07-01

### ✨ Χαρακτηριστικά

- feat: ρυθμιζόμενος κατάλογος log μέσω New-BridgeConfiguration

### 🐛 Διορθώσεις

- fix: επίλυση τελικών παραβιάσεων PSScriptAnalyzer για εξασφάλιση CI pipeline
- fix: διασφάλιση διατήρησης BOM κατά την ενημέρωση έκδοσης module
- fix: διόρθωση ελληνικών τόνων και συνένωσης URL

## [1.0.81] - 2026-07-01

### 🐛 Διορθώσεις

- fix: απενεργοποίηση DOCKER_CONTENT_TRUST καθολικά για διόρθωση Trivy action

## [1.0.80] - 2026-07-01

### 🐛 Διορθώσεις

- fix: διόρθωση GitHub Actions pipelines

## [1.0.79] - 2026-06-30

### ✨ Χαρακτηριστικά

- feat(ci): σταθεροποίηση (pin) Codecov actions στο commit SHA fb8b3582
- feat(ci): μετάβαση βημάτων Codecov σε χρήση codecov-action@v7
- feat(ci): ενημέρωση έκδοσης Codecov test results action σε v5
- feat(ci): προσθήκη βήματος upload αποτελεσμάτων δοκιμών Codecov
- feat(Send-BridgePushover): ενημέρωση Send-BridgePushover βάσει ευρημάτων αναθεώρησης
- feat(Invoke-BridgeStatusComparison): ενημέρωση Invoke-BridgeStatusComparison βάσει ευρημάτων αναθεώρησης
- feat(Get-BridgeStatusMonitor): ενημέρωση Get-BridgeStatusMonitor βάσει ευρημάτων αναθεώρησης
- feat(Get-BridgeStatusComparison): ενημέρωση Get-BridgeStatusComparison βάσει ευρημάτων αναθεώρησης
- feat(Get-BridgeStatus): ενημέρωση Get-BridgeStatus βάσει ευρημάτων αναθεώρησης
- feat(config): προσθήκη βοηθητικού Get-SafeBridgeConfiguration για ασφαλείς ελέγχους null στη ρύθμιση
- feat: προσθήκη script για αυτοματοποίηση κατηγοριοποίησης changelog και ενημέρωση υπαρχόντων εγγραφών
- feat: υλοποίηση Manage-Changelog.ps1 και βοηθητικού script για αυτόματες ενημερώσεις changelog και δημιουργία PR
- feat: εισαγωγή Manage-Changelog.ps1 για ενοποίηση ροών ενημέρωσης, μορφοποίησης changelog και δημιουργίας PR
- feat: προσθήκη scripts για αυτοματοποίηση ενημερώσεων changelog και μετατροπή ιστορικού commits

### 🐛 Διορθώσεις

- fix(scripts): αφαίρεση κλήσης στο ανύπαρκτο Translate-CommitMessage.ps1
- fix(scripts): χρήση Join-Path για cross-platform κλήσεις scripts
- fix(lint): επίλυση όλων των σφαλμάτων και προειδοποιήσεων PSScriptAnalyzer
- fix(ci): διόρθωση διαδρομής PSScriptAnalyzer και παραμέτρου report_type του Codecov
- fix(ci): διόρθωση έκδοσης Gitleaks action στο ci.yml
- fix(PesterConfiguration): αλλαγή μορφής εξόδου TestResult σε JUnitXml
- fix: ενημέρωση regex αντικατάστασης έκδοσης module για υποστήριξη πολυγραμμικής αντιστοίχισης
- fix: βελτίωση επεξεργασίας μηνυμάτων commit με αφαίρεση εμπρόσθιων emojis και κενών
- fix(changelog): καθαρισμός εμπρόσθιων emojis κατά την αντιστοίχιση

### ♻️ Αναδιαρθρώσεις

- refactor(run): ενημέρωση run βάσει ευρημάτων αναθεώρησης
- refactor(Write-BridgeLog): ενημέρωση Write-BridgeLog βάσει ευρημάτων αναθεώρησης
- refactor(Send-BridgePushoverRequest): ενημέρωση Send-BridgePushoverRequest βάσει ευρημάτων αναθεώρησης
- refactor(Send-BridgeNotification): ενημέρωση Send-BridgeNotification βάσει ευρημάτων αναθεώρησης
- refactor(Invoke-BridgeOpenedNotification): ενημέρωση Invoke-BridgeOpenedNotification βάσει ευρημάτων αναθεώρησης
- refactor(Invoke-BridgeOCRRequest): ενημέρωση Invoke-BridgeOCRRequest βάσει ευρημάτων αναθεώρησης
- refactor(Invoke-BridgeOCRGoogleCloud): ενημέρωση Invoke-BridgeOCRGoogleCloud βάσει ευρημάτων αναθεώρησης
- refactor(Invoke-BridgeClosedNotification): ενημέρωση Invoke-BridgeClosedNotification βάσει ευρημάτων αναθεώρησης
- refactor(Get-BridgeStatusFromHtml): ενημέρωση Get-BridgeStatusFromHtml βάσει ευρημάτων αναθεώρησης
- refactor(Get-BridgePushoverPayload): ενημέρωση Get-BridgePushoverPayload βάσει ευρημάτων αναθεώρησης
- refactor(Get-BridgeImage): ενημέρωση Get-BridgeImage βάσει ευρημάτων αναθεώρησης
- refactor(Get-BridgeHtml): ενημέρωση Get-BridgeHtml βάσει ευρημάτων αναθεώρησης
- refactor(Export-BridgeStatusJson): ενημέρωση Export-BridgeStatusJson βάσει ευρημάτων αναθεώρησης
- refactor(ConvertFrom-BridgeHtml): ενημέρωση ConvertFrom-BridgeHtml βάσει ευρημάτων αναθεώρησης
- refactor(BridgeWatcher): ενημέρωση BridgeWatcher βάσει ευρημάτων αναθεώρησης

### 🧪 Δοκιμές

- test(Write-BridgeLog.Tests): ενημέρωση Write-BridgeLog.Tests βάσει ευρημάτων αναθεώρησης
- test(Test-BridgeResult.Tests): ενημέρωση Test-BridgeResult.Tests βάσει ευρημάτων αναθεώρησης
- test(Test-BridgeResult-Simple.Tests): ενημέρωση Test-BridgeResult-Simple.Tests βάσει ευρημάτων αναθεώρησης
- test(Send-BridgePushoverRequest.Tests): ενημέρωση Send-BridgePushoverRequest.Tests βάσει ευρημάτων αναθεώρησης
- test(Send-BridgePushover.Tests): ενημέρωση Send-BridgePushover.Tests βάσει ευρημάτων αναθεώρησης
- test(Resolve-BridgeStatus.Tests): ενημέρωση Resolve-BridgeStatus.Tests βάσει ευρημάτων αναθεώρησης
- test(Resolve-BridgeStateForChange.Tests): ενημέρωση Resolve-BridgeStateForChange.Tests βάσει ευρημάτων αναθεώρησης
- test(New-BridgeResult.Tests): ενημέρωση New-BridgeResult.Tests βάσει ευρημάτων αναθεώρησης
- test(Invoke-BridgeStatusComparison.Tests): ενημέρωση Invoke-BridgeStatusComparison.Tests βάσει ευρημάτων αναθεώρησης
- test(Invoke-BridgeOpenedNotification.Tests): ενημέρωση Invoke-BridgeOpenedNotification.Tests βάσει ευρημάτων αναθεώρησης
- test(Invoke-BridgeOCRRequest.Tests): ενημέρωση Invoke-BridgeOCRRequest.Tests βάσει ευρημάτων αναθεώρησης
- test(Invoke-BridgeOCRGoogleCloud.Tests): ενημέρωση Invoke-BridgeOCRGoogleCloud.Tests βάσει ευρημάτων αναθεώρησης
- test(Invoke-BridgeClosedNotification.Tests): ενημέρωση Invoke-BridgeClosedNotification.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeStatusObject.Tests): ενημέρωση Get-BridgeStatusObject.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeStatusMonitor.Tests): ενημέρωση Get-BridgeStatusMonitor.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeStatusFromHtml.Tests): ενημέρωση Get-BridgeStatusFromHtml.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeStatusComparison.Tests): ενημέρωση Get-BridgeStatusComparison.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeStatusAdvice.Tests): ενημέρωση Get-BridgeStatusAdvice.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeStatus.Tests): ενημέρωση Get-BridgeStatus.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeStatus-Refactored.Tests): ενημέρωση Get-BridgeStatus-Refactored.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgePushoverPayload.Tests): ενημέρωση Get-BridgePushoverPayload.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgePreviousStatus.Tests): ενημέρωση Get-BridgePreviousStatus.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeOCRRequestBody.Tests): ενημέρωση Get-BridgeOCRRequestBody.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeNameFromUri.Tests): ενημέρωση Get-BridgeNameFromUri.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeImages.Tests): ενημέρωση Get-BridgeImages.Tests βάσει ευρημάτων αναθεώρησης
- test(Get-BridgeHtml.Tests): ενημέρωση Get-BridgeHtml.Tests βάσει ευρημάτων αναθεώρησης
- test(Export-BridgeStatusJson.Tests): ενημέρωση Export-BridgeStatusJson.Tests βάσει ευρημάτων αναθεώρησης
- test(ConvertTo-BridgeTimeRange.Tests): ενημέρωση ConvertTo-BridgeTimeRange.Tests βάσει ευρημάτων αναθεώρησης
- test(ConvertTo-BridgeClosedDuration.Tests): ενημέρωση ConvertTo-BridgeClosedDuration.Tests βάσει ευρημάτων αναθεώρησης
- test(ConvertFrom-BridgeOCRResult.Tests): ενημέρωση ConvertFrom-BridgeOCRResult.Tests βάσει ευρημάτων αναθεώρησης
- test(ConvertFrom-BridgeHtml.Tests): ενημέρωση ConvertFrom-BridgeHtml.Tests βάσει ευρημάτων αναθεώρησης
- test(integration): δημιουργία integration tests ζωντανής ανάλυσης HTML

### 🎨 Στυλ & Μορφοποίηση

- style(changelog): διόρθωση μήκους γραμμής markdown και κενών γραμμών στο τέλος

## [1.0.78] - 2026-06-25

### ✨ Χαρακτηριστικά

- feat: ενημέρωση του regex αντικατάστασης έκδοσης module

### 🐛 Διορθώσεις

- fix(docs): αφαίρεση κατεστραμμένου μπλοκ begin από το docstring
- fix(logging): προσθήκη των σταδίων που λείπουν στο ValidateSet του Write-BridgeStage
- fix(resilience): επιβολή ατομικών εγγραφών κατάστασης μέσω μετονομασίας προσωρινού αρχείου
- fix(logging): ευθυγράμμιση του ValidateSet με τον υποκείμενο logger
- fix(security): καθαρισμός διαπιστευτηρίων από το ErrorRecord payload
- fix(docker): υποστήριξη δυναμικού PGID στο COPY
- fix(module-version): διατήρηση της μορφοποίησης έκδοσης psd1
  - διατήρηση της δομής της γραμμής ModuleVersion
  - αντικατάσταση μόνο της τιμής έκδοσης μέσα στο εισαγωγικό
  - αποφυγή επανασυγγραφής ολόκληρης της γραμμής ανάθεσης

## [1.0.77] - 2026-06-24

### ✨ Χαρακτηριστικά

- feat: προσθήκη UTF-8 BOM στο module manifest για συμμόρφωση με το PSScriptAnalyzer

## [1.0.76] - 2026-06-24

### ✨ Χαρακτηριστικά

- feat(ci): ενημέρωση του περιβάλλοντος εκτέλεσης powershell ci
  - μετονομασία του workflow σε PowerShell Module CI
  - αναβάθμιση του setup-pwsh tag από v7.5.1 σε v7.6.3
  - ενημέρωση των cache keys και των ονομάτων artifacts σε v7.6.3
  - διατήρηση των βημάτων analyzer, manifest και coverage αμετάβλητων
- feat(container): αναβάθμιση περιβάλλοντος εκτέλεσης και powershell
  - ενημέρωση της βασικής εικόνας σε mcr.microsoft.com/dotnet/runtime:10.0.9-alpine3.23
  - αναβάθμιση του PowerShell σε 7.6.3 linux-musl-x64
  - ανανέωση των πακέτων Alpine για τη νέα βάση
- feat: κεντρικοποίηση configuration και επίτευξη 100% test coverage
- feat: εξαγωγή Resolve-BridgeStateForChange ως ξεχωριστό Private function με comprehensive tests
- feat: προσθήκη [OutputType()] attributes για καλύτερη τεκμηρίωση
- feat(error-handling): βελτίωση error handling, validation και test coverage
- feat(docs): εναρμόνιση comment-based help σε Private functions

### 🐛 Διορθώσεις

- fix(ci): σταθεροποίηση (pin) του sha της ενέργειας codecov
  - αντικατάσταση του codecov/codecov-action@18283e04ce6e62d37312384ff67231eb8fd56d24 με το
    fb8b3582c8e4def4969c97caa2f19720cb33a72f
  - διατήρηση των coverage upload inputs αμετάβλητων
  - διατήρηση της συμπεριφοράς artifact και cache
- fix: επίλυση συμβατότητας εξαγωγής JSON με αφαίρεση του μη υποστηριζόμενου ορίσματος Set-Content Encoding
- fix: διόρθωση μορφοποίησης και indentation στο Resolve-BridgeStateForChange
- fix: βελτίωση formatting και splatting consistency στα Resolve-BridgeStateForChange tests
- fix: διόρθωση code style στο Write-BridgeLog.Tests.ps1
- fix: διόρθωση syntax errors και ενίσχυση parameter validation
- fix: συμμόρφωση με PSScriptAnalyzer και βελτιώσεις επικύρωσης παραμέτρων

## [1.0.75] - 2025-06-13

### ✨ Χαρακτηριστικά

- feat(ci): προσθήκη ελέγχου για υπάρχουσα έκδοση μονάδας στο PSGallery

### 🐛 Διορθώσεις

- fix(bridgestatuscomparison): ενημέρωση λογικής για μη εύρεση bridge state

## [1.0.74] - 2025-06-12

### 🐛 Διορθώσεις

- fix(release.yml): διορθώσεις ασφαλείας και CI στο release workflow
- fix(security): αντιμετώπιση shell injection vulnerabilities στο release.yml
- fix(dockerfile): αλλαγή έκδοσης curl σε 8.14.1-r0

## [1.0.73] - 2025-06-12

### ✨ Χαρακτηριστικά

- feat: προσθήκη Semgrep ignore comments για PowerShell workflows
- feat: προσθήκη version pinning για Docker packages

### 🐛 Διορθώσεις

- fix(security): αντιμετώπιση shell injection vulnerabilities
- fix: διόρθωση security issues σε workflow αρχεία
- fix(notifications): διόρθωση λογικής εύρεσης bridge state για αποστολή ειδοποιήσεων
- fix(encoding): μαζική διόρθωση encoding σε UTF8BOM για όλα τα αρχεία

## [1.0.72] - 2025-06-12

### ✨ Χαρακτηριστικά

- feat: ενημέρωση Update-ReleaseChangeLog.ps1 για χρήση Manage-Changelog.ps1
- feat: δημιουργία Manage-Changelog.ps1 για consolidated changelog operations
- feat: βελτίωση Get-PotentialNextVersion.ps1 με καλύτερο error handling
- feat: βελτίωση Update-ModuleVersion.ps1 για υποστήριξη specific versions

### 🐛 Διορθώσεις

- fix(scripts): βελτίωση κατηγοριοποίησης commits με conventional commit support
- fix(scripts): διόρθωση syntax error στο Update-ReleaseChangeLog.ps1
- fix(scripts): διόρθωση syntax errors και αφαίρεση duplicate κώδικα στο Manage-Changelog.ps1
- fix(scripts): διόρθωση σφάλματος 'Cannot index into a null array' στο Update-ReleaseChangeLog.ps1
- fix: αντικατάσταση null-coalescing operator για PowerShell compatibility
- fix(scripts): διόρθωση empty changelog generation στο Update-ReleaseChangeLog.ps1

## [1.0.71] - 2025-06-11

### ✨ Χαρακτηριστικά

- feat(docker): προσθήκη Docker container για BridgeWatcher

## [1.0.70] - 2025-06-11

### ✨ Χαρακτηριστικά

- feat: revert "ci(workflows): προσθήκη manual trigger στο CI workflow"
- feat: revert "ci(workflows): προσθήκη manual trigger στο code quality workflow"
- feat: revert "ci(workflows): προσθήκη manual trigger στο Docker build workflow"
- feat: revert "ci(workflows): προσθήκη manual trigger στο documentation workflow"
- feat: revert "ci(workflows): προσθήκη manual trigger στο publish workflow"
- feat(scripts): προσθήκη demo script για changelog format validation
- feat(scripts): προσθήκη perfect validation demo script
- feat(scripts): νέο content validation script για commits
- feat(scripts): comprehensive format validation για markdown αρχεία
- feat(scripts): νέο comprehensive validation script
- feat(scripts): τελικό validation script για quality assurance
- feat(scripts): ultimate validation με perfect score achievement
- feat(scripts): προσθήκη emoji support στα section headers

### 🐛 Διορθώσεις

- fix(scripts): διόρθωση syntax error στο changelog workflow test
- fix(scripts): διόρθωση duplicate function name και function call

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

## [1.0.60] - 2025-06-03

### ✨ Χαρακτηριστικά

- feat(ci): ενσωμάτωση job CI στο Release Orchestrator και ενημέρωση εξαρτήσεων
- feat(ci): προσθήκη Release Orchestrator GitHub Actions workflow

### 🐛 Διορθώσεις

- fix(ci): διόρθωση συνθήκης εκκίνησης job ci από gatekeeper σε pre-release

## [1.0.59] - 2025-06-03

### ✨ Χαρακτηριστικά

- feat(changelog): προσθήκη Update-ChangelogAndCreatePR.ps1 για αυτόματη ενημέρωση CHANGELOG και PR (#9)
- feat(bridgewatcher): προσθήκη ApiKey/PoUserKey/PoApiKey σε Send-BridgeNotification και ενημέρωση handlerMap
- feat(changelog): προσθήκη Test-ChangelogWorkflow και Compare-ChangelogApproach για τοπικό testing changelog workflow
- feat(changelog): προσθήκη Test-ChangelogWorkflow και Compare-ChangelogApproaches scripts
- feat(script): προσθήκη script για ενημέρωση και έλεγχο μορφοποίησης CHANGELOG.md

### 🐛 Διορθώσεις

- fix(ci): απόκρυψη επιπλέον ροών εξόδου στο Invoke-Pester (#7)
- fix(script): διόρθωση Join-Path να χρησιμοποιεί named parameters αντί για positional
- fix(test): αφαίρεση unused variable
- fix(script): αφαίρεση Write-Host
- fix(script): αφαίρεση CRLF
- fix(script): αλλαγή encoding του Test-ChangelogWorkflow.ps1 σε UTF8BOM
- fix(ci): ασφαλής ανάθεση VERSION_BUMP_TYPE μέσω περιβάλλοντος
- fix(update-releasechangelog): χρήση ονομαστικών παραμέτρων για Join-Path

## [1.0.53] - 2025-05-31

### ✨ Χαρακτηριστικά

- feat(scripts): έξυπνη επιλογή From ref με Get-LatestTagOnCurrentBranch και απλοποίηση logic git log

## [1.0.52] - 2025-05-30

### ✨ Χαρακτηριστικά

- feat(scripts): προσθήκη ExcludeHousekeeping switch στο Update-ReleaseChangeLog.ps1 και έξυπνο commit filtering
- feat(scripts): έξυπνη επιλογή From/To refs, προσθήκη ExcludeHousekeeping & IncludeMergeCommits flags με advanced
  filtering
- feat: προσθήκη συγχρονισμού branch πριν το push

### 🐛 Διορθώσεις

- fix(run.ps1): προσθήκη BOM και διασφάλιση συμβατότητας Unicode

## [1.0.51] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: προσθήκη ξεχωριστού βήματος tagging εικόνας ως latest

## [1.0.49] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: προσθήκη Set-FinalModuleVersion.ps1 για ενημέρωση module manifest
- feat: προσθήκη Get-PotentialNextVersion.ps1 για υπολογισμό επόμενης έκδοσης
- feat: προσθήκη gatekeeper job και επιλογής bump τύπου έκδοσης

## [1.0.46] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: αποφυγή δημιουργίας tag αν το "v${{ env.new_version }}" υπάρχει ήδη στο βήμα Create Tag
- feat: βελτίωση του workflow Publish με έλεγχο νέων commits, αποθήκευση flag, debug βήμα και ορθή εξαγωγή του
  new_version.

## [1.0.45] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: προσθήκη εισαγωγής των helper functions Send-BridgeNotification και Write-BridgeStage στο BridgeWatcher.psm1
- feat: προσθήκη workflow_call trigger με required secrets, έξοδος module_published μέσω set_output και αφαίρεση
  βημάτων Pester/tests.

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

## [1.0.29] - 2025-05-06

### ✨ Χαρακτηριστικά

- feat: προσθήκη emojis στα release notes και βελτιωμένο help στο Get-FormattedReleaseNotes

## [1.0.27] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: προσθήκη script για αυτόματη αύξηση patch version σε PowerShell module manifest

## [1.0.24] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: προσθήκη script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow

## [1.0.20] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: προσθήκη συστήματος αυτόματης ενημέρωσης CHANGELOG στο /scripts/

## [1.0.18] - 2025-05-01

### 🐛 Διορθώσεις

- fix: μετάφραση description και διόρθωση αναμενόμενων κλήσεων Write-BridgeLog σε Start-BridgeStatusMonitor.Tests

## [1.0.9] - 2025-04-29

### ✨ Χαρακτηριστικά

- feat(docker): προσθήκη entrypoint.sh για εκκίνηση Docker container
- feat(config): προσθήκη αρχείου .env για παραμετροποίηση μεταβλητών περιβάλλοντος
- feat(docker): προσθήκη Dockerfile για containerization του BridgeWatcher

## [1.0.3] - 2025-04-27

### ✨ Χαρακτηριστικά

- feat: προσθήκη publish.yml για το PowerShell Gallery









