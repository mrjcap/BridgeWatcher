# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.86] - 2026-07-01

### 🐛 Διορθώσεις

- fix(docker): replace useless cat with input redirection (SC2002)

### 🎨 Στυλ & Μορφοποίηση

- style(tests): fix indentation and alignment for Codacy compliance

## [1.0.85] - 2026-07-01

### 🐛 Διορθώσεις

- fix(ci): enable upload of Codacy analysis results

## [1.0.84] - 2026-07-01

### 🐛 Διορθώσεις

- fix(docker): remove su-exec from entrypoint since container runs as appuser

## [1.0.82] - 2026-07-01

### ✨ Χαρακτηριστικά

- feat: make log directory configurable via New-BridgeConfiguration

### 🐛 Διορθώσεις

- fix: resolve final PSScriptAnalyzer violations to secure CI pipeline
- fix: ensure BOM is preserved when updating module version
- fix: correct Greek accents and URL concatenation

## [1.0.81] - 2026-07-01

### 🐛 Διορθώσεις

- fix: disable DOCKER_CONTENT_TRUST globally to fix Trivy action

## [1.0.80] - 2026-07-01

### 🐛 Διορθώσεις

- fix: github action pipelines

## [1.0.79] - 2026-06-30

### ✨ Χαρακτηριστικά

- feat(ci): pin Codecov actions to commit SHA fb8b3582
- feat(ci): migrate Codecov steps to use codecov-action@v7
- feat(ci): update Codecov test results action version to v5
- feat(ci): add Codecov test results upload step
- feat(Send-BridgePushover): update Send-BridgePushover to address review findings
- feat(Invoke-BridgeStatusComparison): update Invoke-BridgeStatusComparison to address review findings
- feat(Get-BridgeStatusMonitor): update Get-BridgeStatusMonitor to address review findings
- feat(Get-BridgeStatusComparison): update Get-BridgeStatusComparison to address review findings
- feat(Get-BridgeStatus): update Get-BridgeStatus to address review findings
- feat(config): add Get-SafeBridgeConfiguration helper for safe configuration null checks
- feat: add script to automate changelog sectioning and update existing entries
- feat: implement Manage-Changelog.ps1 and helper script to automate changelog updates and PR creation
- feat: introduce Manage-Changelog.ps1 to consolidate changelog update, formatting, and PR creation workflows
- feat: add scripts to automate changelog updates and commit history conversion

### 🐛 Διορθώσεις

- fix(scripts): remove call to missing Translate-CommitMessage.ps1
- fix(scripts): use Join-Path for cross-platform script invocations
- fix(lint): resolve all PSScriptAnalyzer errors and warnings
- fix(ci): fix PSScriptAnalyzer path and Codecov report_type parameter
- fix(ci): correct Gitleaks action version in ci.yml
- fix(PesterConfiguration): change TestResult output format to JUnitXml
- fix: update regex for module version replacement to support multiline matching
- fix: improve commit message processing by stripping leading emojis and whitespace
- 🐛 fix(changelog): clean leading emojis during matching

### ♻️ Αναδιαρθρώσεις

- refactor(run): update run to address review findings
- refactor(Write-BridgeLog): update Write-BridgeLog to address review findings
- refactor(Send-BridgePushoverRequest): update Send-BridgePushoverRequest to address review findings
- refactor(Send-BridgeNotification): update Send-BridgeNotification to address review findings
- refactor(Invoke-BridgeOpenedNotification): update Invoke-BridgeOpenedNotification to address review findings
- refactor(Invoke-BridgeOCRRequest): update Invoke-BridgeOCRRequest to address review findings
- refactor(Invoke-BridgeOCRGoogleCloud): update Invoke-BridgeOCRGoogleCloud to address review findings
- refactor(Invoke-BridgeClosedNotification): update Invoke-BridgeClosedNotification to address review findings
- refactor(Get-BridgeStatusFromHtml): update Get-BridgeStatusFromHtml to address review findings
- refactor(Get-BridgePushoverPayload): update Get-BridgePushoverPayload to address review findings
- refactor(Get-BridgeImage): update Get-BridgeImage to address review findings
- refactor(Get-BridgeHtml): update Get-BridgeHtml to address review findings
- refactor(Export-BridgeStatusJson): update Export-BridgeStatusJson to address review findings
- refactor(ConvertFrom-BridgeHtml): update ConvertFrom-BridgeHtml to address review findings
- refactor(BridgeWatcher): update BridgeWatcher to address review findings

### 🧪 Δοκιμές

- test(Write-BridgeLog.Tests): update Write-BridgeLog.Tests to address review findings
- test(Test-BridgeResult.Tests): update Test-BridgeResult.Tests to address review findings
- test(Test-BridgeResult-Simple.Tests): update Test-BridgeResult-Simple.Tests to address review findings
- test(Send-BridgePushoverRequest.Tests): update Send-BridgePushoverRequest.Tests to address review findings
- test(Send-BridgePushover.Tests): update Send-BridgePushover.Tests to address review findings
- test(Resolve-BridgeStatus.Tests): update Resolve-BridgeStatus.Tests to address review findings
- test(Resolve-BridgeStateForChange.Tests): update Resolve-BridgeStateForChange.Tests to address review findings
- test(New-BridgeResult.Tests): update New-BridgeResult.Tests to address review findings
- test(Invoke-BridgeStatusComparison.Tests): update Invoke-BridgeStatusComparison.Tests to address review findings
- test(Invoke-BridgeOpenedNotification.Tests): update Invoke-BridgeOpenedNotification.Tests to address review findings
- test(Invoke-BridgeOCRRequest.Tests): update Invoke-BridgeOCRRequest.Tests to address review findings
- test(Invoke-BridgeOCRGoogleCloud.Tests): update Invoke-BridgeOCRGoogleCloud.Tests to address review findings
- test(Invoke-BridgeClosedNotification.Tests): update Invoke-BridgeClosedNotification.Tests to address review findings
- test(Get-BridgeStatusObject.Tests): update Get-BridgeStatusObject.Tests to address review findings
- test(Get-BridgeStatusMonitor.Tests): update Get-BridgeStatusMonitor.Tests to address review findings
- test(Get-BridgeStatusFromHtml.Tests): update Get-BridgeStatusFromHtml.Tests to address review findings
- test(Get-BridgeStatusComparison.Tests): update Get-BridgeStatusComparison.Tests to address review findings
- test(Get-BridgeStatusAdvice.Tests): update Get-BridgeStatusAdvice.Tests to address review findings
- test(Get-BridgeStatus.Tests): update Get-BridgeStatus.Tests to address review findings
- test(Get-BridgeStatus-Refactored.Tests): update Get-BridgeStatus-Refactored.Tests to address review findings
- test(Get-BridgePushoverPayload.Tests): update Get-BridgePushoverPayload.Tests to address review findings
- test(Get-BridgePreviousStatus.Tests): update Get-BridgePreviousStatus.Tests to address review findings
- test(Get-BridgeOCRRequestBody.Tests): update Get-BridgeOCRRequestBody.Tests to address review findings
- test(Get-BridgeNameFromUri.Tests): update Get-BridgeNameFromUri.Tests to address review findings
- test(Get-BridgeImages.Tests): update Get-BridgeImages.Tests to address review findings
- test(Get-BridgeHtml.Tests): update Get-BridgeHtml.Tests to address review findings
- test(Export-BridgeStatusJson.Tests): update Export-BridgeStatusJson.Tests to address review findings
- test(ConvertTo-BridgeTimeRange.Tests): update ConvertTo-BridgeTimeRange.Tests to address review findings
- test(ConvertTo-BridgeClosedDuration.Tests): update ConvertTo-BridgeClosedDuration.Tests to address review findings
- test(ConvertFrom-BridgeOCRResult.Tests): update ConvertFrom-BridgeOCRResult.Tests to address review findings
- test(ConvertFrom-BridgeHtml.Tests): update ConvertFrom-BridgeHtml.Tests to address review findings
- test(integration): create live HTML parsing integration tests

### 🎨 Στυλ & Μορφοποίηση

- 🚨 style(changelog): fix markdown line length and trailing blank lines

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

---

## [1.0.77] - 2026-06-24

### ✨ Χαρακτηριστικά

- feat: Προσθήκη UTF-8 BOM στο module manifest για συμμόρφωση με το PSScriptAnalyzer

---

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
- feat: Εξαγωγή Resolve-BridgeStateForChange ως ξεχωριστό Private function με comprehensive tests
- feat: Προσθήκη [OutputType()] attributes για καλύτερη τεκμηρίωση
- feat(error-handling): Βελτίωση error handling, validation και test coverage
- feat(docs): Εναρμόνιση comment-based help σε Private functions

### 🐛 Διορθώσεις

- fix(ci): σταθεροποίηση (pin) του sha της ενέργειας codecov
  - αντικατάσταση του codecov/codecov-action@18283e04ce6e62d37312384ff67231eb8fd56d24 με το
    fb8b3582c8e4def4969c97caa2f19720cb33a72f
  - διατήρηση των coverage upload inputs αμετάβλητων
  - διατήρηση της συμπεριφοράς artifact και cache
- fix: Επίλυση συμβατότητας εξαγωγής JSON με αφαίρεση του μη υποστηριζόμενου ορίσματος Set-Content Encoding
- fix: διόρθωση μορφοποίησης και indentation στο Resolve-BridgeStateForChange
- fix: Βελτίωση formatting και splatting consistency στα Resolve-BridgeStateForChange tests
- fix: Διόρθωση code style στο Write-BridgeLog.Tests.ps1
- fix: Διόρθωση syntax errors και ενίσχυση parameter validation
- fix: Συμμόρφωση με PSScriptAnalyzer και βελτιώσεις επικύρωσης παραμέτρων

---

## [1.0.75] - 2025-06-13

### ✨ Χαρακτηριστικά

- feat(ci): προσθέτει έλεγχο για υπάρχουσα έκδοση μονάδας στο PSGallery

### 🐛 Διορθώσεις

- fix(bridgestatuscomparison): Ενημέρωση λογικής για μη εύρεση bridge state

---

## [1.0.74] - 2025-06-12

### 🐛 Διορθώσεις

- fix(release.yml): Διορθώσεις ασφαλείας και CI στο release workflow
- fix: Security fix: Αντιμετώπιση shell injection vulnerabilities στο release.yml
- fix(dockerfile): αλλαγή έκδοσης curl σε 8.14.1-r0

---

## [1.0.73] - 2025-06-12

### ✨ Χαρακτηριστικά

- feat: Προσθήκη Semgrep ignore comments για PowerShell workflows
- feat: Προσθήκη version pinning για Docker packages

### 🐛 Διορθώσεις

- fix: Security fix: Αντιμετώπιση shell injection vulnerabilities
- fix: Διόρθωση security issues σε workflow αρχεία
- fix(notifications): διόρθωση λογικής εύρεσης bridge state για αποστολή ειδοποιήσεων
- fix(encoding): μαζική διόρθωση encoding σε UTF8BOM για όλα τα αρχεία

---

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

---

## [1.0.71] - 2025-06-11

### ✨ Χαρακτηριστικά

- feat(docker): προσθήκη Docker container για BridgeWatcher

---

## [1.0.70] - 2025-06-11

### ✨ Χαρακτηριστικά

- feat: Revert "ci(workflows): προσθήκη manual trigger στο CI workflow"
- feat: Revert "ci(workflows): προσθήκη manual trigger στο code quality workflow"
- feat: Revert "ci(workflows): προσθήκη manual trigger στο Docker build workflow"
- feat: Revert "ci(workflows): προσθήκη manual trigger στο documentation workflow"
- feat: Revert "ci(workflows): προσθήκη manual trigger στο publish workflow"
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

---

## [1.0.68] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση Alpine user/group conflicts και typo στο Dockerfile

---

## [1.0.67] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση Alpine Linux user creation syntax στο Dockerfile

---

## [1.0.66] - 2025-06-10

### ✨ Χαρακτηριστικά

- feat: προσθήκη dynamic UID/GID support για Unraid compatibility

---

## [1.0.65] - 2025-06-10

### 🐛 Διορθώσεις

- fix: Διόρθωση paths και secrets management για Docker environment

---

## [1.0.64] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση αποστολής ειδοποιήσεων μόνο για την επηρεαζόμενη γέφυρα

---

## [1.0.62] - 2025-06-05

### ✨ Χαρακτηριστικά

- feat(bridgewatcher): ενημέρωση Get-BridgeStatusAdvice για χρήση MinutesUntilOpen

### 🐛 Διορθώσεις

- fix(convertfrom-bridgeocrresult): απλοποίηση return για επιστροφή null αντί κενής λίστας
- fix(bridgeocr): διορθώθηκε OutputType σε PSCustomObject
- fix(ocr): διόρθωση ορθογραφίας σε "Ανοίγει σε"

---

## [1.0.60] - 2025-06-03

### ✨ Χαρακτηριστικά

- feat(ci): ενσωμάτωση job CI στο Release Orchestrator και ενημέρωση εξαρτήσεων
- feat(ci): προσθήκη Release Orchestrator GitHub Actions workflow

### 🐛 Διορθώσεις

- fix(ci): διόρθωση συνθήκης εκκίνησης job ci από gatekeeper σε pre-release

---

## [1.0.59] - 2025-06-03

### ✨ Χαρακτηριστικά

- feat(changelog): προσθήκη Update-ChangelogAndCreatePR.ps1 για αυτόματη ενημέρωση CHANGELOG και PR (#9)
- feat(bridgewatcher): προσθήκη ApiKey/PoUserKey/PoApiKey σε Send-BridgeNotification και ενημέρωση handlerMap
- feat(changelog): προσθήκη Test-ChangelogWorkflow και Compare-ChangelogApproach για τοπικό testing changelog workflow
- feat(changelog): προσθήκη Test-ChangelogWorkflow και Compare-ChangelogApproaches scripts
- feat(script): προσθήκη script για ενημέρωση και έλεγχο μορφοποίησης CHANGELOG.md

### 🐛 Διορθώσεις

- fix(ci): απόκρυψη επιπλέον ροών εξόδου στο Invoke-Pester (#7)
- fix(script): Διόρθωση Join-Path να χρησιμοποιεί named parameters αντί για positional
- fix(test): Αφαίρεση unused variable
- fix(script): Αφαίρεση Write-Host
- fix(script): Αφαίρεση CRLF
- fix: fix(script) Test-ChangelogWorkflow.ps1 αλλαγή encoding σε UTF8BOM
- fix(ci): ασφαλής ανάθεση VERSION_BUMP_TYPE μέσω περιβάλλοντος
- fix(update-releasechangelog): χρήση ονομαστικών παραμέτρων για Join-Path

---

## [1.0.53] - 2025-05-31

### ✨ Χαρακτηριστικά

- feat(scripts): έξυπνη επιλογή From ref με Get-LatestTagOnCurrentBranch και απλοποίηση logic git log

---

## [1.0.52] - 2025-05-30

### ✨ Χαρακτηριστικά

- feat(scripts): προσθήκη ExcludeHousekeeping switch στο Update-ReleaseChangeLog.ps1 και έξυπνο commit filtering
- feat(scripts): έξυπνη επιλογή From/To refs, προσθήκη ExcludeHousekeeping & IncludeMergeCommits flags με advanced
  filtering
- feat: Προσθήκη συγχρονισμού branch πριν το push

### 🐛 Διορθώσεις

- fix(run.ps1): προσθήκη BOM και διασφάλιση συμβατότητας Unicode

---

## [1.0.51] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Προσθήκη ξεχωριστού βήματος tagging εικόνας ως latest

---

## [1.0.49] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Προσθήκη Set-FinalModuleVersion.ps1 για ενημέρωση module manifest
- feat: Προσθήκη Get-PotentialNextVersion.ps1 για υπολογισμό επόμενης έκδοσης
- feat: Προσθήκη gatekeeper job και επιλογής bump τύπου έκδοσης

---

## [1.0.46] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Αποφυγή δημιουργίας tag αν το “v${{ env.new_version }}” υπάρχει ήδη στο βήμα Create Tag
- feat: Βελτιώθηκε το workflow Publish με έλεγχο νέων commits, αποθήκευση flag, debug βήμα και ορθή εξαγωγή του
  new_version.

---

## [1.0.45] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Προσθήκη εισαγωγής των helper functions Send-BridgeNotification και Write-BridgeStage στο BridgeWatcher.psm1
- feat: Προσθήκη workflow_call trigger με required secrets, έξοδος module_published μέσω set_output και αφαίρεση
  βημάτων Pester/tests.

---

## [1.0.38] - 2025-05-20

### ✨ Χαρακτηριστικά

- feat: Προσθήκη ελέγχου για μη κενές optional παραμέτρους στο New-BridgePushoverPayload

---

## [1.0.36] - 2025-05-17

### ✨ Χαρακτηριστικά

- feat: Προσθήκη υποστήριξης custom format view για Bridge.Status αντικείμενα

---

## [1.0.32] - 2025-05-16

### ✨ Χαρακτηριστικά

- feat: Προσθήκη χειρισμού "Κλειστή για συντήρηση" στο Invoke-BridgeStatusComparison
- feat: Προσθήκη υποστήριξης ειδοποίησης για "Κλειστή για συντήρηση" στο Invoke-BridgeClosedNotification
- feat: Προσθήκη υποστήριξης status "Κλειστή για συντήρηση" στη Get-BridgeStatusFromHtml

---

## [1.0.29] - 2025-05-06

### ✨ Χαρακτηριστικά

- feat: Προσθήκη emojis στα release notes και βελτιωμένο help στο Get-FormattedReleaseNotes

---

## [1.0.27] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: Προσθήκη script για αυτόματη αύξηση patch version σε PowerShell module manifest

---

## [1.0.24] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: Προσθήκη script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow

---

## [1.0.20] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: Προσθήκη συστήματος αυτόματης ενημέρωσης CHANGELOG στο /scripts/

---

## [1.0.18] - 2025-05-01

### 🐛 Διορθώσεις

- fix: Mετέφραση description και διόρθωση αναμενόμενων κλήσεων Write-BridgeLog σε Start-BridgeStatusMonitor.Tests

---

## [1.0.9] - 2025-04-29

### ✨ Χαρακτηριστικά

- feat(docker): Προσθήκη entrypoint.sh για εκκίνηση Docker container
- feat(config): Προσθήκη αρχείου .env για παραμετροποίηση μεταβλητών περιβάλλοντος
- feat(docker): Προσθήκη Dockerfile για containerization του BridgeWatcher

---

## [1.0.3] - 2025-04-27

### ✨ Χαρακτηριστικά

- feat: προσθήκη publish.yml for powershellgallery








