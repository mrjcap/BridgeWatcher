# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.78] - 2026-06-25

### ✨ Χαρακτηριστικά

- feat: update module version replacement regex

### 🐛 Διορθώσεις

- fix(docs): remove corrupted begin block from docstring
- fix(logging): add missing stages to Write-BridgeStage ValidateSet
- fix(resilience): enforce atomic state writes via tmp file rename
- fix(logging): align ValidateSet with underlying logger
- fix(security): scrub credentials from ErrorRecord payload
- fix(docker): support dynamic PGID in COPY
- fix(module-version): preserve psd1 version formatting - keep the ModuleVersion line structure intact - replace only the version value inside the quoted string - avoid rewriting the whole assignment line

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.78 [skip ci]

### 🧪 Δοκιμές

- test: mock Move-Item to suppress red output in Export tests

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.78 [skip ci]

### 🎨 Στυλ & Μορφοποίηση

- style: restore UTF-8 BOM encoding across scripts

---

## [1.0.77] - 2026-06-24

### ✨ Χαρακτηριστικά

- feat: Add UTF-8 BOM to module manifest to satisfy PSScriptAnalyzer

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.77 [skip ci]

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.77 [skip ci]

---

## [1.0.76] - 2026-06-24

### ✨ Χαρακτηριστικά

- feat(ci): update powershell ci runtime - rename workflow to PowerShell Module CI - bump setup-pwsh tag from v7.5.1 to v7.6.3 - update cache keys and artifact names to v7.6.3 - keep analyzer, manifest, and coverage steps unchanged
- feat(container): bump runtime and powershell - update base image to mcr.microsoft.com/dotnet/runtime:10.0.9-alpine3.23 - upgrade PowerShell to 7.6.3 linux-musl-x64 - refresh Alpine packages for the new base
- feat: κεντρικοποίηση configuration και επίτευξη 100% test coverage
- feat: Εξαγωγή Resolve-BridgeStateForChange ως ξεχωριστό Private function με comprehensive tests
- feat: Προσθήκη [OutputType()] attributes για καλύτερη τεκμηρίωση
- feat(error-handling): Βελτίωση error handling, validation και test coverage
- feat(docs): Εναρμόνιση comment-based help σε Private functions

### 🐛 Διορθώσεις

- fix(ci): pin codecov action sha - replace codecov/codecov-action@18283e04ce6e62d37312384ff67231eb8fd56d24 with fb8b3582c8e4def4969c97caa2f19720cb33a72f - keep coverage upload inputs unchanged - preserve artifact and cache behavior
- fix: Fix JSON export compatibility by removing unsupported Set-Content Encoding argument
- fix: διόρθωση μορφοποίησης και indentation στο Resolve-BridgeStateForChange
- fix: Βελτίωση formatting και splatting consistency στα Resolve-BridgeStateForChange tests
- fix: Διόρθωση code style στο Write-BridgeLog.Tests.ps1
- fix: Διόρθωση syntax errors και ενίσχυση parameter validation
- fix: Συμμόρφωση με PSScriptAnalyzer και βελτιώσεις επικύρωσης παραμέτρων

### ♻️ Αναδιαρθρώσεις

- refactor(pester): normalize test paths - change Run.Path from c:\\code\\BridgeWatcher\\Tests\\ to ./Tests - change CodeCoverage paths to relative ./BridgeWatcher/Public/*.ps1 and ./BridgeWatcher/Private/*.ps1 - keep result outputs, filters, and reporting unchanged
- refactor: ανακατασκευή pipeline Get-BridgeStatus με BridgeResult objects
- refactor: παραμετροποίηση magic numbers σε όλες τις functions
- refactor: Μείωση log spam στο notification flow

### 📝 Τεκμηρίωση

- docs: auto-generate PowerShell documentation [skip docs]
- docs: Αφαίρεση περιττού documentation αρχείου
- docs(readme): ενημέρωση README.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.76 [skip ci]

### 🧪 Δοκιμές

- test: αναδιάρθρωση tests για εξάλειψη PSScriptAnalyzer warnings
- test: Ολοκλήρωση αυστηρού refactor με 100% test coverage

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.76 [skip ci]
- chore: Καθαρισμός formatting και code style στα test αρχεία
- chore(changelog): τακτοποίηση μορφοποίησης στο CHANGELOG.md με αφαίρεση περιττών κενών γραμμών

### 🎨 Στυλ & Μορφοποίηση

- style: διόρθωση formatting και documentation

---

## [1.0.75] - 2025-06-13

### ✨ Χαρακτηριστικά

- feat(ci): προσθέτει έλεγχο για υπάρχουσα έκδοση μονάδας στο PSGallery

### 🐛 Διορθώσεις

- fix(bridgestatuscomparison): Ενημέρωση λογικής για μη εύρεση bridge state

### 📝 Τεκμηρίωση

- docs: auto-generate PowerShell documentation [skip docs]

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.75 [skip ci]
- ci(docs): Προσθήκη βήματος εμφάνισης npm debug log σε failure

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.75 [skip ci]
- chore(psd1): μετατροπή της κωδικοποίησης του manifest σε UTF-8 με BOM

---

## [1.0.74] - 2025-06-12

### 🐛 Διορθώσεις

- fix(release.yml): Διορθώσεις ασφαλείας και CI στο release workflow
- fix: Security fix: Αντιμετώπιση shell injection vulnerabilities στο release.yml
- fix(dockerfile): αλλαγή έκδοσης curl σε 8.14.1-r0

### 📝 Τεκμηρίωση

- docs: Βελτίωση auto-commit τεκμηρίωσης: ασφαλέστερο push και fallback σε conflict

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Ενημέρωση release workflow: βελτιώσεις και διορθώσεις ασφαλείας
- ci: Update changelog for 1.0.74 [skip ci]

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.74 [skip ci]
- chore(μεταδεδομένα): Ενημέρωση BridgeWatcher.psd1 σύμφωνα με τις τελευταίες αλλαγές

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

### 📝 Τεκμηρίωση

- docs(readme): ενημερωση README.md
- docs: Καθαρισμός μορφοποίησης αρχείων τεκμηρίωσης
- docs(changelog): ενημέρωση CHANGELOG.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.73 [skip ci]
- ci(docker-build): ενημέρωση docker-build.yml
- ci: Επιπρόσθετη διαμόρφωση Semgrep για PowerShell workflows
- ci: Workflow maintenance: Line ending normalization
- ci: Καθαρισμός invisible Unicode characters από workflows

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.73 [skip ci]

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

### ♻️ Αναδιαρθρώσεις

- refactor: βελτίωση formatting hashtable και απλοποίηση logic στο Update-ReleaseChangeLog.ps1
- refactor: απλοποίηση Get-ReleaseNotes.ps1 για workflow integration

### 📝 Τεκμηρίωση

- docs(changelog): ενημέρωση CHANGELOG.md
- docs: docs(changelog)ενημέρωση CHANGELOG.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.72 [skip ci]
- ci: ενημέρωση publish.yml workflow για χρήση Update-ModuleVersion.ps1

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.72 [skip ci]
- chore: αφαίρεση scripts που δεν χρειάζονται για workflows

### 🎨 Στυλ & Μορφοποίηση

- style(scripts): μικρές βελτιώσεις formatting στο Update-ReleaseChangeLog.ps1
- style: καθαρισμός formatting και αφαίρεση περιττών κενών γραμμών στο Manage-Changelog.ps1
- style: βελτίωση alignment στο emoji map του Manage-Changelog.ps1
- style: διόρθωση indentation στο Get-GitCommitsSinceLastRelease.ps1
- style: διόρθωση formatting στο BridgeWatcher.psd1

---

## [1.0.71] - 2025-06-11

### ✨ Χαρακτηριστικά

- feat(docker): προσθήκη Docker container για BridgeWatcher

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.71 [skip ci]

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.71 [skip ci]

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

### ♻️ Αναδιαρθρώσεις

- refactor(scripts): βελτίωση git commit exclusion patterns

### 📝 Τεκμηρίωση

- docs(changelog): ενημέρωση CHANGELOG.md
- docs(changelog): προσθήκη unreleased section για Docker base image update

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci(workflows): αφαίρεση manual trigger από release workflow
- ci: Update changelog for 1.0.70 [skip ci]
- ci(workflows): προσθήκη manual trigger στο publish workflow
- ci(workflows): προσθήκη manual trigger στο documentation workflow
- ci(workflows): προσθήκη manual trigger στο Docker build workflow
- ci(workflows): προσθήκη manual trigger στο code quality workflow
- ci(workflows): προσθήκη manual trigger στο CI workflow
- ci(release): βελτίωση error handling και formatting στο changelog update

### 🛠️ Κατασκευή

- build(dockerfile): μετάβαση σε .NET runtime:9.0.6-alpine3.22 base image

### 🧪 Δοκιμές

- test(scripts): προσθήκη test script για changelog fixes validation

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.70 [skip ci]

---

## [1.0.69] - 2025-06-11

### 📝 Τεκμηρίωση

- docs(changelog): ενημέρωση CHANGELOG.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.69 [skip ci]

### 🛠️ Κατασκευή

- build(dockerfile): ενημέρωση ρύθμισης ζώνης ώρας

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.69 [skip ci]

---

## [1.0.68] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση Alpine user/group conflicts και typo στο Dockerfile

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.68 [skip ci]

---

## [1.0.67] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση Alpine Linux user creation syntax στο Dockerfile

### 📝 Τεκμηρίωση

- docs(changelog): ενημέρωση CHANGELOG.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.67 [skip ci]

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.67 [skip ci]

---

## [1.0.66] - 2025-06-10

### ✨ Χαρακτηριστικά

- feat: προσθήκη dynamic UID/GID support για Unraid compatibility

### 📝 Τεκμηρίωση

- docs(changelog): ενημέρωση CHANGELOG.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.66 [skip ci]

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.66 [skip ci]

---

## [1.0.65] - 2025-06-10

### 🐛 Διορθώσεις

- fix: Διόρθωση paths και secrets management για Docker environment

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.65 [skip ci]

---

## [1.0.64] - 2025-06-10

### 🐛 Διορθώσεις

- fix: διόρθωση αποστολής ειδοποιήσεων μόνο για την επηρεαζόμενη γέφυρα

### 📝 Τεκμηρίωση

- docs(readme): ενημέρωση README.md
- docs: doc(readme) Ενημέρωση README.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.64 [skip ci]

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.64 [skip ci]

### 🎨 Στυλ & Μορφοποίηση

- style: διόρθωση μορφοποίησης module manifest

---

## [1.0.63] - 2025-06-05

### 📝 Τεκμηρίωση

- docs: doc(readme) Ενημέρωση README.md
- docs(readme): ενημέρωση README.md
- docs(changelog): ενημέρωση CHANGELOG.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update changelog for 1.0.63 [skip ci]

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.63 [skip ci]

---

## [1.0.62] - 2025-06-05

### ✨ Χαρακτηριστικά

- feat(bridgewatcher): ενημέρωση Get-BridgeStatusAdvice για χρήση MinutesUntilOpen

### 🐛 Διορθώσεις

- fix(convertfrom-bridgeocrresult): απλοποίηση return για επιστροφή null αντί κενής λίστας
- fix(bridgeocr): διορθώθηκε OutputType σε PSCustomObject
- fix(ocr): διόρθωση ορθογραφίας σε "Ανοίγει σε"

### ♻️ Αναδιαρθρώσεις

- refactor(bridgewatcher): ευθυγράμμιση κώδικα Write-BridgeLog και απλοποίηση return σε Get-BridgeStatus
- refactor(bridgewatcher): αλλαγή OutputType σε PSCustomObject

### 📝 Τεκμηρίωση

- docs: auto-generate PowerShell documentation [skip docs]
- docs(changelog): προσθήκη αναφορών σε Keep a Changelog και Semantic Versioning
- docs: βελτίωση markdownlint config και μορφοποίησης documentation
- docs: ενημέρωση ρυθμίσεων markdownlint, αναδιαμόρφωση CHANGELOG, README και about_BridgeWatcher

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.62 [skip ci]
- chore(tests): προσθέτει αρχείο PSScriptAnalyzerSettings
- chore(manifest): ενημέρωση FunctionsToExport με Start-BridgeStatusMonitor

### 🎨 Στυλ & Μορφοποίηση

- style(bridgewatcher): ευθυγράμμιση και βελτίωση μορφοποίησης κώδικα, απενεργοποίηση PSProvideCommentHelp

---

## [1.0.61] - 2025-06-03

### 📝 Τεκμηρίωση

- docs: auto-generate PowerShell documentation [skip docs]
- docs(chore): ενημέρωση README.md

### 🧹 Εργασίες Συντήρησης

- chore: bump version to 1.0.61 [skip ci]
- chore(docs): ενημέρωση lint markdown σε warn-only
- chore(docs): καθάρισμα npm artifacts μετά το lint

---

## [1.0.60] - 2025-06-03

### ✨ Χαρακτηριστικά

- feat(ci): ενσωμάτωση job CI στο Release Orchestrator και ενημέρωση εξαρτήσεων
- feat(ci): προσθήκη Release Orchestrator GitHub Actions workflow

### 🐛 Διορθώσεις

- fix(ci): διόρθωση συνθήκης εκκίνησης job ci από gatekeeper σε pre-release

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: ci(release) αφαίρεση του needs.gatekeeper.outputs.proceed_with_release == 'true' απο το release.yml

### 🧹 Εργασίες Συντήρησης

- chore(ci): διόρθωση αναφοράς actions/setup-node σε σωστό commit SHA
- chore: bump version to 1.0.60 [skip ci]
- chore: chore(script) αλλαγη encoding σε utf8BOM
- chore(ci): απλοποίηση workflow σε μονό OS και PowerShell έκδοση
- chore(ci): απλοποίηση Codacy workflow, κατάργηση PowerShell και security jobs
- chore(docs): προσθήκη αρχείου ρύθμισης .markdownlint-cli2.yaml
- chore(ci): αναβάθμιση workflow τεκμηρίωσης PowerShell με linting
- chore(docs): αντικατάσταση Write-Host με Write-Verbose στο Repair-Markdown.ps1
- chore(docs): προσθήκη step για διόρθωση markdown πριν από τον έλεγχο

---

## [1.0.59] - 2025-06-03

### ✨ Χαρακτηριστικά

- feat(changelog): προσθήκη Update-ChangelogAndCreatePR.ps1 για αυτόματη ενημέρωση CHANGELOG και PR (#9)
- feat(bridgewatcher): προσθήκη ApiKey/PoUserKey/PoApiKey σε Send-BridgeNotification και ενημέρωση handlerMap
- feat(changelog): προσθήκη Test-ChangelogWorkflow και Compare-ChangelogApproach για τοπικό testing changelog workflow
- feat(changelog): προσθήκη Test-ChangelogWorkflow και Compare-ChangelogApproaches scripts
- feat(script): προσθήκη script για ενημέρωση και έλεγχο μορφοποίησης CHANGELOG.md

### 🐛 Διορθώσεις

- fix: ci(release) debugging changelog rules
- fix: ci(release) test debug
- fix(ci): απόκρυψη επιπλέον ροών εξόδου στο Invoke-Pester (#7)
- fix(script): Διόρθωση Join-Path να χρησιμοποιεί named parameters αντί για positional
- fix(test): Αφαίρεση unused variable
- fix(script): Αφαίρεση Write-Host
- fix(script): Αφαίρεση CRLF
- fix: fix(script) Test-ChangelogWorkflow.ps1 αλλαγή encoding σε UTF8BOM
- fix(ci): ασφαλής ανάθεση VERSION_BUMP_TYPE μέσω περιβάλλοντος
- fix(update-releasechangelog): χρήση ονομαστικών παραμέτρων για Join-Path

### ♻️ Αναδιαρθρώσεις

- refactor(bridgewatcher): μετονομασία New-* σε Get-* και ενημέρωση exports/tests - Μετονομασία συναρτήσεων: - `New-BridgeStatusMonitor` → `Get-BridgeStatusMonitor` - `New-BridgeStatusObject` → `Get-BridgeStatusObject` - `New-BridgeOCRRequestBody` → `Get-BridgeOCRRequestBody` - `New-BridgePushoverPayload` → `Get-BridgePushoverPayload` - Ενημέρωση `BridgeWatcher.psm1`: - Αντικατάσταση των φορτώσεων αρχείων Private/Public για τις μετονοματισμένες συναρτήσεις. - Προσαρμογή της εντολής `Export-ModuleMember` ώστε να εξάγει `Get-BridgeStatusMonitor` αντί του `Start-BridgeStatusMonitor`. - Αφαίρεση παλαιών αρχείων `New-*.ps1` από τον φάκελο `Private` (διαγραφή των `New-Bridge*`). - Ενημέρωση των Unit Tests: - Αντικατάσταση όλων των mocks/Assert-MockCalled από `New-Bridge*` σε `Get-Bridge*`. - Αφαίρεση tests για τις διαγραμμένες συναρτήσεις `New-Bridge*`. - Ενημέρωση `run.ps1`: - Άλλαξε το call σε `Get-BridgeStatusMonitor` αντί για `Start-BridgeStatusMonitor`. - Ενημέρωση `scripts/Update-ChangelogFormat.ps1` σε `Get-ChangelogFormat.ps1` και αντίστοιχες αναφορές. - Διόρθωση `scripts/Update-ModuleVersion.ps1` ώστε η συνάρτηση `Get-ModuleVersion` να αντικαθιστά σωστά το version string.

### 📝 Τεκμηρίωση

- docs: μετονομασία αρχείου module overview σε about_<ModuleName> και αφαίρεση Remove-Item
- docs: auto-generate PowerShell documentation [skip docs]
- docs(changelog): ενημέρωση τίτλου και εισαγωγής CHANGELOG
- docs: doc(readme) Ενημέρωση README.md
- docs(changelog): διόρθωση MD022 - προσθήκη κενών γραμμών γύρω από τα headings
- docs: διόρθωση MD022 - προσθήκη κενών γραμμών γύρω από τα headings

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci(release): add step to install powershell
- ci: Αλλαγή runners σε ubuntu-latest στο Release Process
- ci: ci(release) ενημέρωση release.yml
- ci: ενημέρωση διαδικασίας release workflow
- ci(release): προσθήκη write permission για issues και βελτίωση job changelog-pr
- ci(release): αναβάθμιση job changelog-pr για αυτόματη δημιουργία PR μέσω create-pull-request
- ci(release): βελτιώσεις στο workflow για αυτοματοποίηση changelog και εξαρτήσεις (#12)
- ci(release): διόρθωση inputs και απλοποίηση changelog-pr (#11)
- ci(release): αλλαγή εξάρτησης test-matrix σε changelog-pr αντί για gatekeeper (#10)
- ci: c(release)i: ενημέρωση Release Process workflow – προσαρμογή configurationJson για changelog και ελληνικό μήνυμα commit

### 🧪 Δοκιμές

- test: αφαίρεση Write-Error και throw σε Send-BridgePushoverRequest.Tests.ps1 (#8)
- test(send-bridgepushoverrequest): προσθήκη Write-Error στο catch για logging
- test(invoke-bridgestatuscomparison): χρήση Mock για Compare-Object σε περίπτωση σφάλματος

### 🧹 Εργασίες Συντήρησης

- chore(docker): αφαίρεση SBOM generation και upload
- chore: bump version to 1.0.59 [skip ci]
- chore(docker): περιορισμός πλατφορμών σε linux/amd64
- chore(encoding): αλλαγή κωδικοποίησης σε utf8BOM σε scripts και Pester config
- chore(scripts): αλλαγή κωδικοποίησης σε utf8BOM στο Set-FinalModuleVersion.ps1
- chore(docker): αναβάθμιση docker/metadata-action και docker/build-push-action
- chore(release): αφαίρεση βήματος Setup PowerShell από το workflow
- chore(publish): αφαίρεση βήματος Setup PowerShell
- chore(publish): αφαίρεση tag στο setup-pwsh
- chore(release): αφαίρεση job test-matrix από release.yml
- chore(workflows): αναβάθμιση PowerShell στην έκδοση v7.4.10
- chore(workflows): αναβάθμιση PowerShell σε v7.4.10
- chore(ci): διόρθωση pwsh-version σε 'v7.4.2' στο matrix
- chore(ci): ενημέρωση matrix PowerShell εκδόσεων σε v7.5.1 και 7.4.2
- chore(workflows): ορισμός συγκεκριμένης έκδοσης PowerShell (v7.4.2)
- chore(workflows): αλλαγή pwsh-version σε tag στο setup-pwsh και ευθυγράμμιση παραμέτρων Publish-Module
- chore(publish): προσθήκη step για ορισμό έκδοσης module πριν τη validation
- chore(docs): τροποποίηση παραμέτρου -AboutName στο New-MarkdownAboutHelp
- chore(docs): καθαρισμός module overview και βελτίωση μηνύματος επιτυχίας
- chore(ci): αφαίρεση -PassThru από κλήση Invoke-Pester
- chore(ci): inline Import-PowerShellDataFile στην κλήση Invoke-Pester
- chore(tests): αντικαταστήστε τα σχόλια με Write-Verbose στο catch του Send-BridgePushoverRequest.Tests
- chore(release): αφαίρεση ελέγχου changelog_updated από συνθήκες jobs
- chore(release): αφαίρεση αυτόματου PR για CHANGELOG και ενημέρωση σύνοψης release
- chore(release): διόρθωση αναφοράς και normalization στο flag changelog_updated
- chore(release): αφαίρεση διπλού βήματος ελέγχου αλλαγών CHANGELOG
- chore(release): αντικατάσταση action δημιουργίας CHANGELOG με custom script
- chore(release): αντικατάσταση action για ενημέρωση CHANGELOG με custom PowerShell script
- chore(ci): αντικατάσταση actions/setup-powershell με milliewalky/setup-pwsh
- chore(ci): αναβάθμιση και ενοποίηση GitHub Actions workflows - CI Matrix Testing (.github/workflows/ci.yml) - Code Quality Analysis (.github/workflows/codequality.yml) - Docker Build & Push (.github/workflows/docker-build.yml) - PowerShell Documentation (.github/workflows/powershell-docs.yml) - Publish to PowerShell Gallery (.github/workflows/publish.yml) - Release Orchestrator (.github/workflows/release.yml) - Scripts Update (scripts/Update-ChangelogAndCreatePR.ps1) - Προστέθηκε BOM (UTF-8 header) στην αρχή του αρχείου.
- chore: Αλλαγή runners σε self-hosted στο Release Process
- chore(ci): βελτιώσεις μορφοποίησης στα GitHub workflows (#6)
- chore(changelog): κανονικοποίηση κατηγοριών και μορφοποίησης (#5)
- chore(logs): διαγραφ;h αρχείου .log
- chore(module): ενημέρωση encoding
- chore(ci): κλείδωμα GitHub Actions σε συγκεκριμένα SHA
- chore(ci): κλείδωμα actions σε συγκεκριμένα SHA
- chore(ci): κλείδωμα των GitHub Actions σε συγκεκριμένα SHA
- chore(dockerfile): Αναβάθμιση πακέτου tzdata σε 2025b-r0
- chore: doc(changelog) Ενημέρωση CHANGELOG.md

### DOC (doc)

- doc(readme): ενημέρωση README.md
- doc(changelog): ενημέρωση CHANGELOG.md

---

## [1.0.58] - 2025-05-31

### ♻️ Αναδιαρθρώσεις

- refactor: μόνο ενημέρωση έκδοσης στο psd1, το changelog γίνεται upstream

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: auto-update CHANGELOG.md for v1.0.58

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.58

---

## [1.0.57] - 2025-05-31

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: auto-update CHANGELOG.md for v1.0.57
- ci(release): ενσωμάτωση inline configuration για mikepenz/release-changelog-builder

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.57 and update changelog

---

## [1.0.56] - 2025-05-31

### 📝 Τεκμηρίωση

- docs(readme): ενημέρωση README.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: auto-update CHANGELOG.md for v1.0.56
- ci(release): Προσαρμόστηκε το path του configuration για το mikepenz/release-changelog-builder-action σε ./.github/changelog-configuration.json

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.56 and update changelog

---

## [1.0.55] - 2025-05-31

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: auto-update CHANGELOG.md for v1.0.55
- ci: προσαρμογή εξαρτήσεων Gatekeeper για να περιλαμβάνει ανάλυση Codacy

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.55 and update changelog
- chore(doc): Update CHANGELOG.md
- chore(release-changelog): ενημέρωση διαμόρφωσης για προσαρμοσμένο template και categories

---

## [1.0.54] - 2025-05-31

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: auto-update CHANGELOG.md for v1.0.54
- ci: ενημέρωση build_changelog με HYBRID mode και προσθήκη configuration αρχείου
- ci: Ενημέρωση release.yml
- ci: προσθήκη ανάλυσης Codacy και αφαίρεση SonarCloud στο workflow release
- ci: αντικατάσταση SonarCloud με Codacy για ανάλυση κώδικα
- ci: χρήση codequality.yml αντί sonarcloud.yml στο workflow έκδοσης
- ci: προσθήκη SonarCloud Analysis και ενημέρωση workflow release
- ci(script): αντικαταστάθηκαν Write-Host με Write-Verbose και απλοποιήθηκε δημιουργία και έλεγχος αρχείου changelog_updated.flag
- ci(script): Αντικαταστάθηκαν Write-Host με Write-Output στο Update-Psd1ModuleVersion για καλύτερη συμβατότητα με CI pipeline
- ci(script): Ενημέρωση Update-Changelog.ps1 για βελτιστοποίηση εντοπισμού header, χρήση Write-Verbose και διόρθωση regex
- ci(release-process): προσθήκη εξάρτησης pre-release στο test job
- ci(powershell-module-publish): χρήση softprops/action-gh-release@v2 και προσθήκη permissions για write στο contents
- ci: auto-update CHANGELOG.md for v1.0.53

### 🧪 Δοκιμές

- test: ενημέρωση των Unit Tests για Get-BridgeStatusComparison – απλοποίηση mocks (αφαίρεση παραμέτρων από Get-BridgePreviousStatus και προσαρμογή του Get-Content)

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.54 and update changelog
- chore: προσθήκη BOM σε αρχεία PowerShell που περιέχουν μη-ASCII χαρακτήρες (BridgeWatcher.psd1, Update-Changelog.ps1, Get-ReleaseNotes.ps1, Convert-GreekChangelogCommitsToSections.ps1)
- chore: Ενημέρωση changelog-configuration.json
- chore: Bump version to 1.0.53 and update changelog

---

## [1.0.53] - 2025-05-31

### ✨ Χαρακτηριστικά

- feat(scripts): έξυπνη επιλογή From ref με Get-LatestTagOnCurrentBranch και απλοποίηση logic git log

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci(release-process): αντικατάσταση custom Update-ReleaseChangeLog με mikepenz/release-changelog-builder-action και βελτιώσεις gatekeeper
- ci(release-process): προσθήκη test-matrix job και cleanup παλαιών release artifacts
- ci: update CHANGELOG.md for v1.0.52

### 🧹 Εργασίες Συντήρησης

- chore: Ενημέρωση release.yml
- chore: Bump version to 1.0.52 and update changelog

---

## [1.0.52] - 2025-05-30

### ✨ Χαρακτηριστικά

- feat(scripts): προσθήκη ExcludeHousekeeping switch στο Update-ReleaseChangeLog.ps1 και έξυπνο commit filtering
- feat(scripts): έξυπνη επιλογή From/To refs, προσθήκη ExcludeHousekeeping & IncludeMergeCommits flags με advanced filtering
- feat: Προσθήκη συγχρονισμού branch πριν το push

### 🐛 Διορθώσεις

- fix(run.ps1): προσθήκη BOM και διασφάλιση συμβατότητας Unicode

### 📝 Τεκμηρίωση

- docs: Ενημέρωση powershell-docs.yml

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: update CHANGELOG.md for v1.0.52
- ci(release-process): cleanup artifacts & matrix tests για multi-OS/multi-version PowerShell
- ci(publish): προσθήκη git cleanup μετά το publish στο PowerShell Gallery
- ci(lint-docs): caching modules, warnings στο lint και artifact upload documentation
- ci(docker-build): βελτιώσεις traceability, logging & artifact upload στο docker build
- ci(powershell-module-ci): προσθήκη caching PowerShell modules για ταχύτερα builds
- ci(release-process): ομαδοποίηση jobs και προσθήκη pre-release βήματος για έναρξη διαδικασίας
- ci(publish): προσθήκη βήματος Verify module publish με Find-Module για έλεγχο στο PSGallery
- ci(lint-docs): προσθήκη caching των PowerShell modules με actions/cache@v4
- ci(docker-build): προσθήκη OCI labels στο docker build και cleanup με docker system prune
- ci(powershell-module-ci): διαχωρισμός βημάτων Install Pester και Run Tests & conditional upload coverage.xml

### 🧹 Εργασίες Συντήρησης

- chore: Ενημέρωση release.yml
- chore: Ενημέρωση CHANGELOG.md
- chore(bridgewatcher.psd1): αποθήκευση manifest ως UTF-8 με BOM για υποστήριξη Unicode
- chore: Ενημέρωση commit CHANGELOG.md σε ξεχωριστό βήμα
- chore: Bump version to 1.0.51 and update changelog

---

## [1.0.51] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Προσθήκη ξεχωριστού βήματος tagging εικόνας ως latest

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.50 and update changelog

---

## [1.0.50] - 2025-05-29

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Ενημέρωση PowerShell Module Publish workflow

### 🧹 Εργασίες Συντήρησης

- chore: Ενημέρωση Update-ReleaseChangeLog.ps1 με πλήρη error handling και verbose logging
- chore: Ενημέρωση του Get-PotentialNextVersion.ps1
- chore: Ενημέρωση Release Orchestrator σε Release Process
- chore: Ενημέρωση Update-ReleaseChangeLog.ps1 με initialization και καθαρά βήματα
- chore: Ενημέρωση Set-FinalModuleVersion.ps1 με validation και verbose logging
- chore: Ενημέρωση Get-PotentialNextVersion.ps1 με verbose logging και δομημένα βήματα

---

## [1.0.49] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Προσθήκη Set-FinalModuleVersion.ps1 για ενημέρωση module manifest
- feat: Προσθήκη Get-PotentialNextVersion.ps1 για υπολογισμό επόμενης έκδοσης
- feat: Προσθήκη gatekeeper job και επιλογής bump τύπου έκδοσης

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Αναδιαμόρφωση PowerShell Module Publish workflow
- ci: Ενημέρωση εκδόσεων actions στο workflow CI

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.49 and update changelog
- chore: Ενημέρωση publish.yml
- chore: Ενημέρωση release.yml
- chore: Αντικατάσταση του input “published” με “version” και απλούστευση ροής
- chore: Ενημέρωση CHANGELOG.md
- chore: Ενημέωση publish.yml

---

## [1.0.48] - 2025-05-29

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Ενημέρωση workflows

### 🛠️ Κατασκευή

- build: Ενημέρωση docker-build.yml

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.48 and update CHANGELOG.md
- chore: Ενημέρωση publish.yml

---

## [1.0.47] - 2025-05-29

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.47 and update CHANGELOG.md
- chore: Ενημέρωση release.yml
- chore: Ενημέρωση secrets

---

## [1.0.46] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Αποφυγή δημιουργίας tag αν το “v${{ env.new_version }}” υπάρχει ήδη στο βήμα Create Tag
- feat: Βελτιώθηκε το workflow Publish με έλεγχο νέων commits, αποθήκευση flag, debug βήμα και ορθή εξαγωγή του new_version.

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.46 and update CHANGELOG.md
- chore: Bump version to 1.0.45 and update CHANGELOG.md

---

## [1.0.45] - 2025-05-29

### ✨ Χαρακτηριστικά

- feat: Προσθήκη εισαγωγής των helper functions Send-BridgeNotification και Write-BridgeStage στο BridgeWatcher.psm1
- feat: Προσθήκη workflow_call trigger με required secrets, έξοδος module_published μέσω set_output και αφαίρεση βημάτων Pester/tests.

### 📝 Τεκμηρίωση

- docs: Ενημέρωση README.md
- docs: - Νέο workflow **Release Orchestrator**   - Εκτελεί επαναχρησιμοποιούμενα workflows με `workflow_call` σε σειρά:     1. `ci.yml` (test)     2. `powershell-docs.yml` (docs)     3. `publish.yml` (publish)     4. `docker-build.yml` (docker)

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Προστέθηκαν τα secrets στα PowerShell Module workflows
- ci: Ενημέρωση docker-build.yml workflow
- ci: - Αλλαγή του CI workflow σε reusable workflow με χρήση `workflow_call` trigger αντί για `push`/`pull_request`.

### 🧪 Δοκιμές

- test: Αφαιρέθηκαν τα βήματα εγκατάστασης Pester και εκτέλεσης tests από το `publish.yml` workflow.

### 🧹 Εργασίες Συντήρησης

- chore: Αφαίρεση της συνάρτησης Send-BridgeNotification από το Invoke-BridgeStatusComparison και μεταφορά της σε ξεχωριστό αρχείο Send-BridgeNotification.ps1
- chore: Αφαίρεση της συνάρτησης Write-BridgeStage από το Invoke-BridgeStatusComparison και μεταφορά της σε ξεχωριστό αρχείο Write-BridgeStage.ps1
- chore: Αφαίρεση των helper functions από το Invoke-BridgeStatusComparison και μεταφορά τους σε ξεχωριστά .ps1 αρχεία
- chore: - Προστέθηκε στο `release.yml` η συνθήκη `if: needs.publish.outputs.module_published == 'true'` για conditional εκτέλεση.
- chore: Ενημέρωση release.yml
- chore: Προστέθηκε HEALTHCHECK, αλλάζει ENTRYPOINT σε sh και βελτιώνει ρύθμιση timezone
- chore: Αλλαγή του shell wrapper, αφαιρεί τη συνάρτηση get_secret και ελέγχει μόνο ύπαρξη των secrets πριν από το exec pwsh
- chore: Προστέθηκε default φάκελο εξόδου, try/catch και έξοδο με κωδικό 1 σε σφάλμα
- chore: Ενημέρωση publish.yml
- chore: Προστέθηκε προέλεγχος νέων commits πριν από version bump

---

## [1.0.44] - 2025-05-28

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.44 and update CHANGELOG.md
- chore: Ενημέρωση publish.yml
- chore: Προστέθηκε changelog_updated.flag στο Update-ReleaseChangeLog.ps1
- chore: Ενημέρωση CHANGELOG.md

---

## [1.0.43] - 2025-05-28

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.43 and update CHANGELOG.md
- chore: Εξαιρούνται commits που περιέχουν τη λέξη `changelog` (χωρίς διάκριση πεζών/κεφαλαίων) από την αυτόματη δημιουργία του CHANGELOG.md, για αποφυγή περιττών καταγραφών.

---

## [1.0.42] - 2025-05-28

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Βελτιστοποίηση workflow δημοσίευσης PowerShell module

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.42 and update CHANGELOG.md
- chore: Ενημέρωση CHANGELOG.md

---

## [1.0.41] - 2025-05-28

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.41 and update CHANGELOG.md
- chore: Ενημέρωση BridgeWatcher.psd1
- chore: Eνημέρωση CHANGELOG.md
- chore: Ενημέρωση publish.yml

---

## [1.0.39] - 2025-05-28

### 📝 Τεκμηρίωση

- docs: Ενημέρωση README.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Βελτιστοποίηση CI pipeline: αναβάθμιση actions & συνένωση βημάτων

### 🧪 Δοκιμές

- test: Ενημέρωση CI config: ενεργοποίηση τερματισμού σε αποτυχίες tests

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.39 and update CHANGELOG.md
- chore: Ενημέρωση CHANGELOG.md

---

## [1.0.38] - 2025-05-20

### ✨ Χαρακτηριστικά

- feat: Προσθήκη ελέγχου για μη κενές optional παραμέτρους στο New-BridgePushoverPayload

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.38 and update CHANGELOG.md
- chore: Ενημέρωση CHANGELOG.md

---

## [1.0.37] - 2025-05-19

### 🧪 Δοκιμές

- test: Ενημέρωση Start-BridgeStatusMonitor.Tests.ps1

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.37 and update CHANGELOG.md
- chore: Αφαίρεση break από το catch για συνεχή παρακολούθηση
- chore: Ενημέρωση CHANGELOG.md

---

## [1.0.36] - 2025-05-17

### ✨ Χαρακτηριστικά

- feat: Προσθήκη υποστήριξης custom format view για Bridge.Status αντικείμενα

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.36 and update CHANGELOG.md
- chore: Ενημέρωση CHANGELOG.md

### CLEANUP (cleanup)

- cleanup: Ευθυγράμμιση πεδίων στο module manifest για αναγνωσιμότητα

---

## [1.0.35] - 2025-05-17

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.35 and update CHANGELOG.md

### ΑΛΛΑΓΈΣ (αλλαγές)

- αλλαγές: 

---

## [1.0.34] - 2025-05-16

### 🧪 Δοκιμές

- test: Προστέθηκαν Pester tests για αλλαγές status "Κλειστή για συντήρηση" στην Invoke-BridgeStatusComparison

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.34 and update CHANGELOG.md

---

## [1.0.33] - 2025-05-16

### 🧪 Δοκιμές

- test: Προστέθηκε Pester test για status "Κλειστή για συντήρηση" στην Invoke-BridgeClosedNotification

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.33 and update CHANGELOG.md

---

## [1.0.32] - 2025-05-16

### ✨ Χαρακτηριστικά

- feat: Προσθήκη χειρισμού "Κλειστή για συντήρηση" στο Invoke-BridgeStatusComparison
- feat: Προσθήκη υποστήριξης ειδοποίησης για "Κλειστή για συντήρηση" στο Invoke-BridgeClosedNotification
- feat: Προσθήκη υποστήριξης status "Κλειστή για συντήρηση" στη Get-BridgeStatusFromHtml

### 📝 Τεκμηρίωση

- docs: Ενημέρωση README.md

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.32 and update CHANGELOG.md
- chore: Ενημέρωση τεστ: Προσαρμογή Assert-MockCalled σε νέα συνολικά status (8 αντί για 6)

---

## [1.0.31] - 2025-05-07

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.31 and update CHANGELOG.md

### ΠΡΟΣΤΈΘΗΚΕ (προστέθηκε)

- προστέθηκε: Πλήρης εναρμόνιση headers → emojis στο Get-FormattedReleaseNotes.ps1

---

## [1.0.30] - 2025-05-07

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.30 and update CHANGELOG.md
- chore: Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs

### ΔΙΌΡΘΩΣΗ (διόρθωση)

- διόρθωση: Λάθος σύνταξη στο git tag --sort για Get-GitCommitsSinceLastRelease.ps1

---

## [1.0.29] - 2025-05-06

### ✨ Χαρακτηριστικά

- feat: Προσθήκη emojis στα release notes και βελτιωμένο help στο Get-FormattedReleaseNotes

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.29 and update CHANGELOG.md
- chore: Ενημέρωση του συνδέσμου του badge κάλυψης κώδικα στο νέο URL του Codecov.

---

## [1.0.28] - 2025-05-01

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.28 and update CHANGELOG.md
- chore: Ενσωμάτωση αυτοματοποιημένου βήματος αύξησης έκδοσης PowerShell module

---

## [1.0.27] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: Προσθήκη script για αυτόματη αύξηση patch version σε PowerShell module manifest

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.27 and update CHANGELOG.md

---

## [1.0.26] - 2025-05-01

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.26 and update CHANGELOG.md
- chore: Υποστήριξη εκδόσεων με χωρίς "v" στο Get-ReleaseNotes.ps1

---

## [1.0.25] - 2025-05-01

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.25 and update CHANGELOG.md
- chore: Ενημερώθηκε το regex ώστε να ταιριάζει σωστά τα sections τύπου ## [1.0.24] στο CHANGELOG.md

---

## [1.0.24] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: Προσθήκη script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.24 and update CHANGELOG.md
- chore: Ενημέρωση αρχείου publish.yml

---

## [1.0.23] - 2025-05-01

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.23 and update CHANGELOG.md
- chore: Ενημέρωση αρχείου publish.yml

---

## [1.0.22] - 2025-05-01

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.22 and update CHANGELOG.md
- chore: Ενημέρωση του αρχείου publish.yml

---

## [1.0.21] - 2025-05-01

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.21 and update CHANGELOG.md
- chore: Ενημέρωση του publish.yml

---

## [1.0.20] - 2025-05-01

### ✨ Χαρακτηριστικά

- feat: Προσθήκη συστήματος αυτόματης ενημέρωσης CHANGELOG στο /scripts/

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.20 and update CHANGELOG.md
- chore: Ενημέρωση αρχείου CHANGELOG.md
- chore: Ενημέρωση του αρχείου publish.yml
- chore: Ενημέρωση του publish.yml
- chore: Αντικατάσταση inline changelog generation με script-based σύστημα στο publish.yml

---

## [1.0.19] - 2025-05-01

### 🧪 Δοκιμές

- test: Προστέθηκε try/catch στο test αποτυχίας API για Send-BridgePushoverRequest

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.19 and update CHANGELOG.md
- chore: Προστέθηκε mock της Send-BridgeNotification για έλεγχο ειδοποίησης τύπου Closed
- chore: Προστέθηκε υποστήριξη για structured exception handling στο Send-BridgePushoverRequest
- chore: Ενημερώθηκε το αρχείο CHANGELOG.md
- chore: Ενημέρωση αρχείου CHANGELOG.md

---

## [1.0.18] - 2025-05-01

### 🐛 Διορθώσεις

- fix: Mετέφραση description και διόρθωση αναμενόμενων κλήσεων Write-BridgeLog σε Start-BridgeStatusMonitor.Tests

### 📝 Τεκμηρίωση

- docs: Ενημέρωση του αρχείου README.md
- docs: Update CHANGELOG.md

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.18 and update CHANGELOG.md
- chore: Aλλαξε το encoding όλων των αρχείων σε UTF8-BOM
- chore: Μεταφράστηκαν τα μηνύματα καταγραφής σε Start-BridgeStatusMonitor σε ελληνικά
- chore: Διορθώθηκε άρθρο στο Verbose μήνυμα της Invoke-BridgeStatusComparison

---

## [1.0.17] - 2025-04-30

### 📝 Τεκμηρίωση

- docs: Update LICENSE
- docs: Update README.md
- docs: Update CHANGELOG.md

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.17 and update CHANGELOG.md
- chore: Update docker-build.yml
- chore: Update publish.yml
- chore: Update CHANGELOG.md

---

## [1.0.16] - 2025-04-29

### 📝 Τεκμηρίωση

- docs: Update README.md

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.16 and update CHANGELOG.md
- chore: Update docker-build.yml

### DOC (doc)

- doc: Update CHANGELOG.md

---

## [1.0.15] - 2025-04-29

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.15 and update CHANGELOG.md
- chore: Update docker-build.yml

---

## [1.0.14] - 2025-04-29

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.14 and update CHANGELOG.md
- chore: Update docker-build.yml

---

## [1.0.13] - 2025-04-29

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.13 and update CHANGELOG.md
- chore: Update docker-build.yml

---

## [1.0.12] - 2025-04-29

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.12 and update CHANGELOG.md
- chore: Update Dockerfile

---

## [1.0.11] - 2025-04-29

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.11 and update CHANGELOG.md
- chore: Update Dockerfile

---

## [1.0.10] - 2025-04-29

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.10 and update CHANGELOG.md
- chore: Update docker-build.yml

---

## [1.0.9] - 2025-04-29

### ✨ Χαρακτηριστικά

- feat(docker): Προσθήκη entrypoint.sh για εκκίνηση Docker container
- feat(config): Προσθήκη αρχείου .env για παραμετροποίηση μεταβλητών περιβάλλοντος
- feat(docker): Προσθήκη Dockerfile για containerization του BridgeWatcher

### ♻️ Αναδιαρθρώσεις

- refactor(docker): Ενημέρωση run.ps1 για εκτέλεση σε container

### 📝 Τεκμηρίωση

- docs(changelog): Ενημέρωση CHANGELOG.md με προσθήκες Docker, entrypoint, .env, workflow και αλλαγή run.ps1
- docs: Update README.md
- docs: auto-generate PowerShell documentation

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci(docker): Δημιουργία workflow docker-build.yml για αυτόματο build images

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.9 and update CHANGELOG.md
- chore: Update publish.yml
- chore: Update CHANGELOG.md
- chore: Update powershell-docs.yml

---

## [1.0.8] - 2025-04-28

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.8 and update CHANGELOG.md
- chore: Update powershell-docs.yml

---

## [1.0.7] - 2025-04-28

### 📝 Τεκμηρίωση

- docs: Update powershell-docs.yml

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.7 and update CHANGELOG.md

---

## [1.0.6] - 2025-04-28

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.6 and update CHANGELOG.md
- chore: Create powershell-docs.yml
- chore: Update CHANGELOG.md
- chore: updated publish.yml

---

## [1.0.5] - 2025-04-27

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.5 and update CHANGELOG.md
- chore: Updated publish.yml

---

## [1.0.4] - 2025-04-27

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.4
- chore: Update BridgeWatcher.psd1

---

## [1.0.3] - 2025-04-27

### ✨ Χαρακτηριστικά

- feat: Add codecov Updated README.md with badge
- feat: added publish.yml for powershellgallery

### 📝 Τεκμηρίωση

- docs: Update README.md
- docs: Updated README.md

### ⚙️ CI/CD (Συνεχής Ενοποίηση)

- ci: Update ci.yml

### 🧪 Δοκιμές

- test: Replace test path
- test: Updated PesterConfiguration.psd and test path
- test: Updated PesterConfiguration.psd1
- test: updated test paths
- test: updated test paths and publish.yml

### 🧹 Εργασίες Συντήρησης

- chore: Bump version to 1.0.3
- chore: Update publish.yml
- chore: Updated publish.yml
- chore: Update BridgeWatcher.psd1
- chore: Updated BridgeWatcher.psd1
- chore: Renamed src folder
- chore: removed utf8BOM
- chore: Initial commit for BridgeWatcher module
- chore: Initial commit

