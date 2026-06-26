# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ Προστέθηκαν

- docs(security): Προσθήκη πολιτικής ασφάλειας ([SECURITY.md](SECURITY.md)) και απαιτήσεων ασφάλειας εφαρμογών ([docs/SECURITY-REQUIREMENTS.md](docs/SECURITY-REQUIREMENTS.md))
- docs(incident-response): Προσθήκη οδηγού αντιμετώπισης περιστατικών ([docs/INCIDENT-RESPONSE.md](docs/INCIDENT-RESPONSE.md))
- docs(operations): Προσθήκη οδηγού λειτουργιών και ανάκαμψης ([docs/OPERATIONS.md](docs/OPERATIONS.md))
- docs(supply-chain): Προσθήκη πολιτικής ασφάλειας εφοδιαστικής αλυσίδας ([docs/SUPPLY-CHAIN.md](docs/SUPPLY-CHAIN.md))
- docs(communication): Προσθήκη προτύπων επικοινωνίας συμβάντων ([docs/COMMUNICATION-TEMPLATES.md](docs/COMMUNICATION-TEMPLATES.md))
- docs(risk-assessment): Προσθήκη καταλόγου κινδύνων κατά NIST SP 800-30 ([docs/RISK-ASSESSMENT.md](docs/RISK-ASSESSMENT.md))
- docs(compliance): Προσθήκη διαδραστικού πίνακα ελέγχου συμμόρφωσης σε HTML ([docs/compliance_dashboard.html](docs/compliance_dashboard.html))
- ci(gitleaks): Προσθήκη ενοποίησης Gitleaks για αυτόματο έλεγχο μυστικών στο GitHub Actions CI workflow
- build(docker): Προσθήκη αυτόματης παραγωγής SBOM μέσω Trivy στο Docker build pipeline
- docs(github): Προσθήκη προτύπου GitHub Issue για ετήσιο έλεγχο ασφάλειας και κινδύνων
- build(docker): Προσθήκη [docker-compose.yml](docker-compose.yml) και [Docker/filebeat.yml](Docker/filebeat.yml)
  για έλεγχο πόρων, ασφάλεια και ενεργή προώθηση αρχείων καταγραφής

### 🛡️ Ασφάλεια

- fix(security): Διόρθωση F-1: Μεταφορά του Google Cloud Vision API key από τις παραμέτρους URL στην κεφαλίδα `X-Goog-Api-Key`
- fix(docker): Διόρθωση F-3: Κατάργηση της έκθεσης της θύρας 8090 στο Dockerfile
- fix(docker): Διόρθωση F-5: Αφαίρεση SUID/SGID δικαιωμάτων από εκτελέσιμα στο Docker base image
- fix(docker): Διόρθωση F-6: Ενεργοποίηση Docker Content Trust (DCT) στο workflow κατασκευής εικόνας
- fix(notifications): Διόρθωση F-10: Προσθήκη ειδοποιήσεων σφάλματος Pushover σε περίπτωση αποτυχίας του κύκλου ελέγχου (run.ps1)

## [1.0.77] - 2026-06-24

### ✨ Προστέθηκαν

- build(manifest): Προσθήκη UTF-8 BOM στο module manifest για την ικανοποίηση του PSScriptAnalyzer

## [1.0.76] - 2026-06-24

### ✨ Προστέθηκαν

- feat: Προσθήκη χαρακτηριστικών [OutputType()] για καλύτερη τεκμηρίωση
- feat(error-handling): Βελτίωση χειρισμού σφαλμάτων, επικύρωσης και κάλυψης δοκιμών
- feat(docs): Εναρμόνιση βοήθειας σχολίων σε ιδιωτικές συναρτήσεις

### 🐛 Διορθώθηκαν

- fix: διόρθωση μορφοποίησης και εσοχών στο Resolve-BridgeStateForChange
- fix: Συμμόρφωση με PSScriptAnalyzer και βελτιώσεις επικύρωσης παραμέτρων

## [1.0.75] - 2025-06-13

### 🐛 Διορθώθηκαν

- fix(bridge-status-comparison): Ενημέρωση λογικής για μη εύρεση bridge state

## [1.0.74] - 2025-06-12

### 🐛 Διορθώθηκαν

- fix(dockerfile): αλλαγή έκδοσης curl σε 8.14.1-r0

## [1.0.73] - 2025-06-12

### 🐛 Διορθώθηκαν

- fix(notifications): διόρθωση λογικής εύρεσης bridge state για αποστολή ειδοποιήσεων
- fix(encoding): μαζική διόρθωση encoding σε UTF8BOM για όλα τα αρχεία

## [1.0.72] - 2025-06-12

### ✨ Προστέθηκαν

- feat: ενημέρωση Update-ReleaseChangeLog.ps1 για χρήση Manage-Changelog.ps1
- feat: δημιουργία Manage-Changelog.ps1 για consolidated changelog operations

### 🐛 Διορθώθηκαν

- fix: αντικατάσταση null-coalescing operator για PowerShell compatibility
- fix(scripts): διόρθωση syntax errors και αφαίρεση duplicate κώδικα στο Manage-Changelog.ps1
- fix(scripts): διόρθωση σφάλματος 'Cannot index into a null array' στο Update-ReleaseChangeLog.ps1
- fix(scripts): διόρθωση empty changelog generation στο Update-ReleaseChangeLog.ps1

## [1.0.71] - 2025-06-11

### ✨ Προστέθηκαν

- feat(docker): προσθήκη κοντέινερ Docker για το BridgeWatcher
  - Εικόνα βάσης: .NET Runtime 9.0.6 Alpine 3.22
  - PowerShell 7.5.1 με πλήρεις εξαρτήσεις
  - Ρύθμιση ζώνης ώρας για Europe/Athens
  - Ρυθμιζόμενα δικαιώματα χρήστη (PUID/PGID)
  - Έκθεση θύρας 8090 για διεπαφή ιστού
  - Healthcheck για την παρακολούθηση της κατάστασης της γέφυρας
  - Σενάριο εισόδου (entrypoint script) για αρχικοποίηση

## [1.0.70] - 2025-06-11

### ✨ Προστέθηκαν

- feat(scripts): προσθήκη σεναρίου επίδειξης για επικύρωση μορφής changelog
- feat(scripts): προσθήκη σεναρίου επίδειξης για τέλεια επικύρωση
- feat(scripts): νέο σενάριο επικύρωσης περιεχομένου για υποβολές (commits)
- feat(scripts): ολοκληρωμένη επικύρωση μορφής για αρχεία markdown
- feat(scripts): νέο ολοκληρωμένο σενάριο επικύρωσης
- feat(scripts): τελικό σενάριο επικύρωσης για διασφάλιση ποιότητας
- feat(scripts): τελική επικύρωση με επίτευξη τέλειου σκορ
- feat(scripts): προσθήκη υποστήριξης emoji στις κεφαλίδες ενοτήτων

### 🔄 Αλλαγές

- refactor(scripts): βελτίωση των μοτίβων εξαίρεσης για git commits
- build(dockerfile): μετάβαση σε εικόνα βάσης .NET runtime:9.0.6-alpine3.22

### 🐛 Διορθώθηκαν

- fix(scripts): διόρθωση συντακτικού σφάλματος στη δοκιμή της ροής εργασιών του changelog
- fix(scripts): διόρθωση διπλότυπου ονόματος συνάρτησης και κλήσης συνάρτησης

### 🧪 Testing

- test(scripts): προσθήκη σεναρίου δοκιμής για την επικύρωση διορθώσεων του changelog

### 🔧 CI/CD

- ci(workflows): προσθήκη και αφαίρεση χειροκίνητου εναύσματος από τις ροές εργασιών (καθαρή μηδενική αλλαγή)
- ci(release): βελτίωση διαχείρισης σφαλμάτων και μορφοποίησης στην ενημέρωση του changelog

### 📝 Τεκμηρίωση

- docs(changelog): ενημέρωση CHANGELOG.md με ενότητες που δεν έχουν κυκλοφορήσει

## [1.0.69] - 2025-06-11

### 🔄 Αλλαγές

- build(dockerfile): ενημέρωση ρύθμισης ζώνης ώρας

## [1.0.68] - 2025-06-10

### 🐛 Διορθώθηκαν

#### Διενέξεις Ομάδων στο Alpine Linux

- fix(docker): Επίλυση διένεξης με την προεγκατεστημένη ομάδα 'users' (GID 100) του Alpine
  - Έξυπνη λογική υπό όρους για ανίχνευση σύγκρουσης GID
  - PGID=100: χρήση της υπάρχουσας ομάδας 'users'
  - PGID≠100: δημιουργία προσαρμοσμένης ομάδας 'appgroup'
- fix(docker): Διόρθωση σφάλματος "chown: unknown user/group appuser:appgroup"
  - Μετάβαση σε αριθμητική ιδιοκτησία ${PUID}:${PGID}
  - Προσέγγιση ανεξάρτητη από πλατφόρμα που λειτουργεί παντού

#### Τυπογραφικό Σφάλμα σε Κρίσιμη Διαδρομή

- fix(docker): Διόρθωση: `/tm` → `/tmp` στο chmod 1777
  - Χωρίς αυτό, η εφεδρική λειτουργία του healthcheck θα αποτύγχανε σιωπηλά
  - Επηρεάζει: Λειτουργίες προσωρινών αρχείων του PowerShell

### 🔄 Αλλαγές

- refactor(docker): Αναδιάρθρωση της ροής δημιουργίας χρήστη με λογική if/else
- refactor(docker): Υιοθέτηση αριθμητικών αναγνωριστικών σε όλες τις λειτουργίες chown
- refactor(docker): Βελτιωμένη ανθεκτικότητα σε σφάλματα για ειδικές περιπτώσεις

### ✨ Προστέθηκαν

- feat(docker): Πλήρης πίνακας συμβατότητας
  - ✅ Unraid NAS (99:100 - nobody:users)
  - ✅ Standard Linux (1000:1000)
  - ✅ Synology DSM (1024:100)
  - ✅ Προσαρμοσμένα περιβάλλοντα (αυθαίρετο UID/GID)
- docs(docker): Σχόλια για την τεκμηρίωση της συμπεριφοράς του Alpine

## [1.0.67] - 2025-06-10

### 🐛 Διορθώθηκαν

#### Συντακτικό Δημιουργίας Χρήστη στο Alpine Linux

- fix(docker): Αφαίρεση της σημαίας `-S` από το `addgroup` (μη υποστηριζόμενη στο Alpine/BusyBox)
- fix(docker): Αντικατάσταση του `-S` με `-D` στο `adduser` για συμβατότητα με Alpine
  - `-D`: Μην ορίζετε κωδικό πρόσβασης (στυλ Alpine)
  - `-S`: Χρήστης συστήματος (στυλ Debian/Ubuntu - μη διαθέσιμο)
- fix(docker): Προσθήκη ρητού καθορισμού κελύφους: `-s /bin/sh`
- fix(docker): Διόρθωση σειράς ορισμάτων για τα BusyBox utilities

### 🔄 Αλλαγές

- refactor(docker): Μετάβαση από τη σύνταξη GNU coreutils στη σύνταξη BusyBox
- refactor(docker): Χρήση σημαιών ειδικά για Alpine για τη διαχείριση χρηστών/ομάδων
- refactor(docker): Βελτίωση συμβατότητας με Alpine Linux containers

### 📝 Τεκμηρίωση

- docs(changelog): Ενημέρωση CHANGELOG.md με αναλυτικές εγγραφές για v1.0.66
- docs(docker): Προσθήκη τεχνικών λεπτομερειών για τη δυνατότητα δυναμικού UID/GID
- docs(changelog): Χρήση κατηγοριών emoji για βελτιωμένη αναγνωσιμότητα

## [1.0.66] - 2025-06-10

### ✨ Προστέθηκαν

- feat(docker): Υποστήριξη δυναμικού UID/GID στο Dockerfile για πλήρη συμβατότητα με Unraid
  - Οδηγίες ARG για PUID/PGID με προεπιλεγμένες τιμές 99:100 (nobody:users)
  - Ρυθμιζόμενη δημιουργία χρήστη κατά τον χρόνο κατασκευής
  - Υποστήριξη προσαρμοσμένων κατασκευών: `docker build --build-arg PUID=1000`

### 🔄 Αλλαγές

- refactor: Προσθήκη καταλόγων .cache και .local για προσωρινή αποθήκευση του PowerShell module
- refactor: Βελτίωση δομής καταλόγου για καλύτερη απομόνωση του module
- refactor(docker): Καθαρισμός των λεπτομερών σχολίων για ένα πιο καθαρό Dockerfile

### 🐛 Διορθώθηκαν

- fix(docker): Διόρθωση τυπογραφικού: `/tm` → `/tmp` στην εντολή chmod (κρίσιμο για το healthcheck fallback)

### 📝 Τεκμηρίωση

- docs(changelog): Ενημέρωση CHANGELOG.md με λεπτομερείς καταχωρίσεις για τις εκδόσεις 1.0.64 και 1.0.65
- docs(changelog): Προσθήκη κατηγοριών emoji για καλύτερη αναγνωσιμότητα
- docs: Αναλυτική τεκμηρίωση των breaking αλλαγών και διορθώσεων

## [1.0.65] - 2025-06-10

### 🐛 Διορθώθηκαν

- fix(docker): Διόρθωση απόλυτης διαδρομής για το entrypoint.sh στο Dockerfile
  - Από: `./entrypoint.sh` (σχετική διαδρομή που μπορεί να προκαλέσει προβλήματα)
  - Σε: `/home/appuser/scripts/entrypoint.sh` (ρητή απόλυτη διαδρομή)
- fix(run): Διόρθωση μονοπατιών ειδικά για Windows στο run.ps1
  - Import-Module από προκαθορισμένη διαδρομή Windows σε σχετική διαδρομή
  - Συμβατότητα με περιβάλλον κοντέινερ Linux

### 🔄 Αλλαγές

- refactor(secrets): Μετάβαση από τη διαχείριση μυστικών PowerShell (PowerShell SecretManagement) στα μυστικά Docker (Docker secrets)
  - Αντικατάσταση του `Get-Secret` cmdlet με το `Get-Content` από προσαρτημένα μυστικά
  - Χρήση του τυπικού προτύπου Docker `/run/secrets/*`
  - Διαχείριση μυστικών ανεξάρτητα από την πλατφόρμα

## [1.0.64] - 2025-06-10

### 📝 Τεκμηρίωση

- docs(readme): Ενημέρωση README.md με βελτιωμένες οδηγίες

### 🐛 Διορθώθηκαν

- fix(notifications): Διόρθωση λογικής αποστολής ειδοποιήσεων ώστε να στέλνονται μόνο για τις επηρεαζόμενες γέφυρες
  - Αντικατάσταση του `$CurrentState` με το συγκεκριμένο αντικείμενο γέφυρας στο `Send-BridgeNotification`
  - Προσθήκη επικύρωσης για την ύπαρξη της κατάστασης της γέφυρας πριν την αποστολή
  - Βελτίωση διαχείρισης σφαλμάτων με περιγραφικά μηνύματα

### 🔄 Αλλαγές

- refactor(manifest): Διόρθωση μορφοποίησης module manifest (καθαρισμός κενών γραμμών)
- refactor(status-comparison): Αναδιάρθρωση του Invoke-BridgeStatusComparison για καλύτερη αναγνωσιμότητα
  - Αντικατάσταση ενσωματωμένων χειριστών με πίνακα αναζήτησης
  - Απλοποίηση της λογικής με έλεγχο `ContainsKey`
  - Βελτίωση της ροής ελέγχου με πρόωρες συνεχίσεις

## [1.0.63] - 2025-06-05

### 📝 Τεκμηρίωση

- docs(readme): Ενημέρωση README.md με εκτενές παράδειγμα για την αυτοματοποίηση του SecretStore
- docs(changelog): Ενημέρωση CHANGELOG.md με την τρέχουσα έκδοση

### ✨ Προστέθηκαν

- docs(secrets): Λεπτομερής οδηγός για ασφαλή αυτοματοποίηση με Microsoft.PowerShell.SecretStore
  - Οδηγίες βήμα-προς-βήμα για εκτέλεση χωρίς επίβλεψη
  - Προσέγγιση συμβατή με το πρότυπο NIST SP 800-53 (IA-5)
  - Βέλτιστες πρακτικές για τη διαχείριση μυστικών
- docs(secrets): Παραδείγματα για
  - Αποθήκευση κωδικού πρόσβασης στο Vault με Export-Clixml
  - Διαμόρφωση του SecretStore για αυτοματοποίηση
  - Ασφαλής ανάκτηση μυστικών σε σενάρια

### 🔧 CI & Συντήρηση

- ci(release): Βελτίωση της ροής εργασίας κυκλοφορίας με αυτόματες υποβολές changelog
  - Διαμόρφωση χρήστη Git για το github-actions[bot]
  - Αυτόματη υποβολή ενημερώσεων του changelog με τη σημαία [skip ci]
  - Ώθηση αλλαγών πριν τη δημιουργία της κυκλοφορίας
- build(version): Version bump από 1.0.62 σε 1.0.63

---

## [1.0.58] - 2025-05-31

### ❌ Αφαιρέθηκαν

- refactor: Μόνο ενημέρωση έκδοσης στο psd1
  (το changelog πλέον γίνεται στην ανώτερρη ροή / upstream)

---

## [1.0.53] - 2025-05-31

### ✨ Προστέθηκαν

- ci(changelog): Ενσωμάτωση mikepenz/release-changelog-builder-action για αυτόματο changelog
- feat(git): Προσθήκη έξυπνης επιλογής From ref με Get-LatestTagOnCurrentBranch
- ci(testing): Νέα εργασία πίνακα δοκιμών (test-matrix job) & καθαρισμός τεχνουργημάτων για multi-OS/multi-version PowerShell

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(release): Απλοποίηση και βελτίωση της λογικής του git log και του Gatekeeper

---

## [1.0.52] - 2025-05-30

### ✨ Προστέθηκαν

- feat(changelog): Προσθήκη διακόπτη ExcludeHousekeeping στο Update-ReleaseChangeLog.ps1
- feat(changelog): Δυνατότητα έξυπνου φιλτραρίσματος commits (From/To refs, σημαίες ExcludeHousekeeping & IncludeMergeCommits)

---

## [1.0.51] - 2025-05-29

### ✨ Προστέθηκαν

- feat(docker): Ξεχωριστό βήμα προσθήκης ετικέτας (tagging) της εικόνας Docker ως latest
- feat(notifications): Εισαγωγή βοηθητικών συναρτήσεων Send-BridgeNotification & Write-BridgeStage στο BridgeWatcher.psm1
- refactor: Μεταφορά βοηθητικών συναρτήσεων σε ξεχωριστά αρχεία

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(publish): Αναδιάρθρωση της ροής εργασίας δημοσίευσης του PowerShell Module (είσοδοι / inputs, ρύθμιση / setup, βάθος checkout / checkout depth)

---

## [1.0.50] - 2025-05-29

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(changelog): Πλήρης αναβάθμιση του Update-ReleaseChangeLog.ps1
  με διαχείριση σφαλμάτων & λεπτομερή καταγραφή
- refactor(version): Επανασχεδιασμός του Get-PotentialNextVersion.ps1
  με καλύτερη διαχείριση σφαλμάτων και ταξινόμηση semver
- refactor(release): Ενοποίηση του Release Orchestrator στη διαδικασία κυκλοφορίας (ενσωμάτωση Gatekeeper)
- refactor(version): Δομημένα στάδια στο Set-FinalModuleVersion.ps1

---

## [1.0.48] - 2025-05-29

### ✨ Προστέθηκαν

- feat(docker): HEALTHCHECK & αλλαγή του ENTRYPOINT σε κέλυφος Alpine στο Dockerfile
- feat(monitor): Προστέθηκε φάκελος εξόδου `/tmp`, try/catch & exit 1 σε περίπτωση σφάλματος στο Start-BridgeStatusMonitor

---

## [1.0.44] - 2025-05-28

### ✨ Προστέθηκαν

- feat(changelog): Αρχείο σημαίας changelog_updated.flag για νέα commits
- feat(status): Υποστήριξη καταστάσεων “Κλειστή για συντήρηση” σε όλα τα επίπεδα (cmdlets & tests)
- feat(format): Υποστήριξη προσαρμοσμένης προβολής μορφοποίησης για το Bridge.Status (BridgeStatus.format.ps1xml)
- feat(testing): Νέες δοκιμές Pester για μεταβάσεις της κατάστασης “Κλειστή για συντήρηση”

---

## [1.0.42] - 2025-05-28

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(publish): Βελτιστοποίηση της ροής εργασίας δημοσίευσης του PowerShell module (actions/checkout@v4, ανάκτηση όλων των ετικετών, αύξηση έκδοσης/ενημέρωση/υποβολή/ετικέτα/κυκλοφορία/δημοσίευση, διαχείριση σφαλμάτων)

---

## [1.0.39] - 2025-05-28

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(ci): Ενεργοποίηση τερματισμού της διοχέτευσης σε αποτυχίες δοκιμών
- refactor(ci): Αναβάθμιση ενεργειών, προσωρινής αποθήκευσης ενοτήτων, δοκιμών υπό όρους & μεταφόρτωσης κάλυψης

---

## [1.0.38] - 2025-05-20

### 🐛 Διορθώθηκαν

- fix(pushover): Έλεγχος για μη κενές προαιρετικές παραμέτρους στο New-BridgePushoverPayload
- fix(git): Συντακτικό λάθος στο git tag --sort στο Get-GitCommitsSinceLastRelease.ps1

### ✨ Προστέθηκαν

- feat(release): Φιλτράρισμα, υποστήριξη συγχώνευσης & προστασία διπλότυπων changelogs στη διοχέτευση κυκλοφορίας

---

## [1.0.37] - 2025-05-19

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(monitor): Αφαίρεση του break από το catch στο Start-BridgeStatusMonitor για συνεχή παρακολούθηση

### ✨ Προστέθηκαν

- feat(format): Υποστήριξη προσαρμοσμένης προβολής μορφής για το Bridge.Status
- test(status): Δοκιμές Pester για αλλαγές κατάστασης “Κλειστή για συντήρηση”

---

## [1.0.34] - 2025-05-16

### ✨ Προστέθηκαν

- test(status): Πρόσθετες δοκιμές Pester για την κατάσταση “Κλειστή για συντήρηση” στο Invoke-BridgeStatusComparison

---

## [1.0.31] - 2025-05-07

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(release): Πλήρης εναρμόνιση κεφαλίδων → emojis στο Get-FormattedReleaseNotes.ps1
- refactor(release): Νέα μορφοποίηση των σημειώσεων κυκλοφορίας

---

## [1.0.30] - 2025-05-07

### 🐛 Διορθώθηκαν

- fix(git): Λάθος σύνταξη στο git tag --sort για το Get-GitCommitsSinceLastRelease.ps1

### ✨ Προστέθηκαν

- feat(release): Επέκταση της διοχέτευσης κυκλοφορίας με φιλτράρισμα, υποστήριξη συγχώνευσης & προστασία διπλότυπων changelogs

---

## [1.0.29] - 2025-05-06

### ✨ Προστέθηκαν

- feat(release): Emojis στις σημειώσεις κυκλοφορίας & βελτιωμένη βοήθεια στο Get-FormattedReleaseNotes

---

## [1.0.27] - 2025-05-01

### ✨ Προστέθηκαν

- feat(manifest): Σενάριο για αυτόματη αύξηση της έκδοσης patch στο PowerShell module manifest

---

## [1.0.25] - 2025-05-01

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(changelog): Ενημέρωση regex για ενότητες τύπου ## [1.0.24] στο CHANGELOG.md
- refactor(release): Σενάριο για αυτόματη εξαγωγή σημειώσεων κυκλοφορίας & βελτιώσεις της ροής εργασίας

---

## [1.0.20] - 2025-05-01

### ✨ Προστέθηκαν

- feat(changelog): Σύστημα βασισμένο σε σενάρια για αυτόματη δημιουργία και ενημέρωση του CHANGELOG στο /scripts/

---

## [1.0.19] - 2025-05-01

### 🐛 Διορθώθηκαν

- fix(pushover): Προσθήκη try/catch στη δοκιμή αποτυχίας API για το Send-BridgePushoverRequest
- fix(pushover): Δομημένος χειρισμός εξαιρέσεων στο Send-BridgePushoverRequest

---

## [1.0.18] - 2025-05-01

### ♻️ Αλλαγές/Βελτιώσεις

- refactor(testing): Μετάφραση περιγραφής & διόρθωση αναμενόμενων κλήσεων Write-BridgeLog στο Start-BridgeStatusMonitor.Tests
- refactor(monitor): Μετάφραση μηνυμάτων καταγραφής στο Start-BridgeStatusMonitor στα ελληνικά
- refactor(status-comparison): Διόρθωση άρθρου στο λεπτομερές μήνυμα της Invoke-BridgeStatusComparison

---

## [1.0.0] - 2025-04-27

### ✨ Προστέθηκαν

- feat: Αρχική κυκλοφορία του module BridgeWatcher

---
