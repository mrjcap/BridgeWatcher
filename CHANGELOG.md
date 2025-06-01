# Αρχείο Αλλαγών

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα τεκμηριώνονται σε αυτό το αρχείο, ακολουθώντας το πρότυπο [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), με τίτλους και κατηγορίες στα ελληνικά.

---

## [1.0.58] - 2025-05-31

### ❌ Αφαιρέθηκαν

- refactor: μόνο ενημέρωση έκδοσης στο psd1 (το changelog πλέον γίνεται upstream)

---

## [1.0.57] - 2025-05-31

### ✨ Προστέθηκαν

- ci(release): ενσωμάτωση inline configuration για mikepenz/release-changelog-builder (mode “HYBRID”, προσθήκη κανόνων κατηγοριοποίησης feat/fix/chore/docs)
- ci: προσαρμογή εξαρτήσεων Gatekeeper ώστε να περιλαμβάνει ανάλυση Codacy

---

## [1.0.56] - 2025-05-31

### ✨ Προστέθηκαν

- ci(release): Προσαρμογή του path του configuration για mikepenz/release-changelog-builder-action σε `./.github/changelog-configuration.json`
- docs(readme): ενημέρωση του README.md

---

## [1.0.55] - 2025-05-31

### ✨ Προστέθηκαν

- chore(doc): Update CHANGELOG.md (προσθήκη νέων αλλαγών, ομαδοποίηση)
- chore(release-changelog): Ενημέρωση διαμόρφωσης για custom template & κατηγορίες (“##” επίπεδο τίτλοι, αφαίρεση “Άλλα”, μείωση max_tags_to_fetch, αφαίρεση collapse section για μη κατηγοριοποιημένα PRs, προσθήκη σταθερού separator)
- ci: προσαρμογή εξαρτήσεων Gatekeeper ώστε να περιλαμβάνει ανάλυση Codacy

---

## [1.0.54] - 2025-05-31

### ✨ Προστέθηκαν

- ci: Ενημέρωση build_changelog με HYBRID mode και προσθήκη configuration αρχείου
- ci: Ενημέρωση release.yml
- ci: Προσθήκη ανάλυσης Codacy & αφαίρεση SonarCloud στο workflow release
- ci: Αντικατάσταση SonarCloud με Codacy για ανάλυση κώδικα
- ci: Χρήση codequality.yml αντί sonarcloud.yml στο workflow έκδοσης

---

## [1.0.53] - 2025-05-31

### ✨ Προστέθηκαν

- Ενημέρωση release.yml
- ci(release-process): αντικατάσταση custom Update-ReleaseChangeLog με mikepenz/release-changelog-builder-action και βελτιώσεις Gatekeeper
- feat(scripts): έξυπνη επιλογή From ref με Get-LatestTagOnCurrentBranch & απλοποίηση logic git log
- ci(release-process): προσθήκη test-matrix job & cleanup παλαιών release artifacts

---

## [1.0.52] - 2025-05-30

### ✨ Προστέθηκαν

- Ενημέρωση release.yml (commit e80bba26)
- Ενημέρωση CHANGELOG.md (commit 9ab877fd & 38ba07a)
- feat(scripts): προσθήκη ExcludeHousekeeping switch στο Update-ReleaseChangeLog.ps1 & έξυπνο commit filtering
- feat(scripts): έξυπνη επιλογή From/To refs, προσθήκη ExcludeHousekeeping & IncludeMergeCommits flags με advanced filtering

---

## [1.0.51] - 2025-05-29

### ✨ Προστέθηκαν

- Προσθήκη ξεχωριστού βήματος tagging εικόνας ως latest (Release workflow)
- ci(release-process): προσθήκη test-matrix job και cleanup artifacts για multi-OS/multi-version PowerShell
- ci(publish): προσθήκη git cleanup (git gc) μετά το publish στο PSGallery
- ci(lint-docs): caching modules, warnings στο lint & artifact upload documentation
- ci(docker-build): βελτιώσεις traceability, logging & artifact upload στο docker build
- ci(powershell-module-ci): προσθήκη caching PowerShell modules για ταχύτερα builds
- ci(release-process): ομαδοποίηση jobs & προσθήκη pre-release βήματος για έναρξη διαδικασίας
- ci(publish): προσθήκη βήματος Verify module publish με Find-Module για έλεγχο στο PSGallery

---

## [1.0.50] - 2025-05-29

### ✨ Προστέθηκαν

- Eνημέρωση Update-ReleaseChangeLog.ps1 με πλήρη error handling & verbose logging (CmdletBinding, ErrorActionPreference, initialization, validation, fetch, process, update, flag)
- Eνημέρωση Get-PotentialNextVersion.ps1 (αφαίρεση verbose logging & splatting, χειροκίνητη ταξινόμηση semver tags, fallback & error handling)
- Eνημέρωση Release Orchestrator σε Release Process (μετονομασία, απλοποίηση version_bump_type, ενσωμάτωση βημάτων gatekeeper, κοινή χρήση μυστικών, conditional execution)
- Ενημέρωση PowerShell Module Publish workflow (input next_version, checkout depth, PowerShell setup, Set-FinalModuleVersion.ps1, commit & push, tags, outputs module_published)
- Ενημέρωση Update-ReleaseChangeLog.ps1 με initialization, καθαρά βήματα, verbose μηνύματα, flag αρχείο
- Ενημέρωση Set-FinalModuleVersion.ps1 με validation, verbose logging, splatting, error handling, structured stages
- Ενημέρωση Get-PotentialNextVersion.ps1 με verbose logging & δομημένα βήματα (ανάκτηση git tags, φιλτράρισμα semver, default versions, next version υπολογισμός)

---

## [1.0.49] - 2025-05-29

### ✨ Προστέθηκαν

- Ενημέρωση publish.yml (τρεις ξεχωριστές ενημερώσεις)
- Ενημέρωση release.yml (δύο commits)
- Ενημέρωση secrets (δύο commits)
- Αποφυγή δημιουργίας dive tag αν το “v${{ env.new_version }}” υπάρχει ήδη
- Βελτίωση workflow Publish: έλεγχος νέων commits, αποθήκευση flag, debug βήμα, ορθή εξαγωγή new_version
- Προσθήκη εισαγωγής των helper functions Send-BridgeNotification & Write-BridgeStage στο BridgeWatcher.psm1
- Αφαίρεση των helper functions Send-BridgeNotification & Write-BridgeStage από Invoke-BridgeStatusComparison, μεταφορά σε ξεχωριστά αρχεία
- Προσθήκη Set-FinalModuleVersion.ps1 (ενημέρωση ModuleVersion σε .psd1, έλεγχος αρχείου, export new_version σε GITHUB_ENV)
- Προσθήκη Get-PotentialNextVersion.ps1 (εντοπισμός τελευταίου stable tag, bump type, αρχικές τιμές)
- Προσθήκη gatekeeper job & επιλογής bump τύπου έκδοσης (pipeline changes, conditional εκτέλεση downstream jobs)
- Αναδιαμόρφωση PowerShell Module Publish workflow (inputs.next_version, αφαίρεση commit detection, PowerShell setup, checkout depth)
- Αντικατάσταση input “published” με “version” & απλοποίηση ροής
- Ενημέρωση εκδόσεων actions στο workflow ci

---

## [1.0.48] - 2025-05-29

### ✨ Προστέθηκαν

- Ενημέρωση workflows (publish.yml, docker-build.yml)
- Προσθήκη HEALTHCHECK & αλλαγή ENTRYPOINT σε Alpine shell (Dockerfile):
- ENTRYPOINT → `["sh","/scripts/entrypoint.sh"]`
- HEALTHCHECK κάθε 60s: ελέγχει αν `/tmp/bridge_status.json` πρόσφατο (10 λεπτά)
- Διατήρηση tzdata, ρυθμίσεις Europe/Athens, σχόλιο για charles.crt, chmod +x στο entrypoint.sh
- Αλλαγή του shell wrapper: αφαιρέθηκε get_secret, loop ελέγχου των αρχείων μυστικών, εκτύπωση μηνύματος σε stderr & exit 1 αν λείπουν, exec pwsh
- Προσθήκη default φάκελου εξόδου `/tmp`, try/catch & exit 1 σε σφάλμα στο Start-BridgeStatusMonitor
- Ενημέρωση publish.yml
- Προσθήκη προελέγχου νέων commits πριν το version bump (flag για conditional βήματα)

---

## [1.0.47] - 2025-05-29

### ✨ Προστέθηκαν

- Ενημέρωση release.yml
- Ενημέρωση secrets
- Ενημέρωση docker-build.yml
- Ενημέρωση publish.yml (τρεις ξεχωριστές ενημερώσεις)
- Ομαλοποίηση workflows για conditional execution

---

## [1.0.46] - 2025-05-29

### ✨ Προστέθηκαν

- Αποφυγή δημιουργίας tag αν υπάρχει ήδη vX.Y.Z
- Βελτίωση workflow Publish (έλεγχος νέων commits, flag, debug, new_version export)
- Ενημέρωση publish.yml (πολλαπλές αλλαγές)
- Ενημέρωση BridgeWatcher.psd1
- Αναβάθμιση ci: actions & συνένωση βημάτων, caching modules, conditional test & coverage upload
- Προσθήκη gatekeeper job & bump type επιλογή, conditional downstream jobs
- Αναδιαμόρφωση PowerShell Module Publish workflow (inputs.next_version, removal commit detection, use actions/setup-powershell, checkout depth)
- Αντικατάσταση input “published” με “version” & απλοποίηση ροής
- Ενημέρωση εκδόσεων actions στο workflow ci
- Ενημέρωση CHANGELOG.md (πολλαπλές προσθήκες)

---

## [1.0.45] - 2025-05-29

### ✨ Προστέθηκαν

- Βελτίωση workflow Publish: έλεγχος νέων commits, flag, debug, new_version export
- Προσθήκη εισαγωγής των helper functions Send-BridgeNotification & Write-BridgeStage στο BridgeWatcher.psm1
- Αφαίρεση των helper functions από Invoke-BridgeStatusComparison & μεταφορά σε ξεχωριστά αρχεία
- Προσθήκη Set-FinalModuleVersion.ps1 (ενημέρωση ModuleVersion σε .psd1, validation, env var export)
- Προσθήκη Get-PotentialNextVersion.ps1 (εισαγωγή τελευταίου stable tag, bump computation, default values)
- Προσθήκη gatekeeper job & bump type επιλογή (conditional downstream execution)
- Αναδιαμόρφωση PowerShell Module Publish workflow (inputs.next_version, actions/setup-powershell, checkout depth, removal commit detection)

---

## [1.0.44] - 2025-05-28

### ✨ Προστέθηκαν

- Ενημέρωση publish.yml, docker-build.yml, release.yml, ci.yml (πολλαπλές commits)
- Προσθήκη changelog_updated.flag στο Update-ReleaseChangeLog.ps1 (flag για νέα commits, τερματισμός pipeline όταν δεν υπάρχουν αλλαγές)
- Ενημέρωση START-BridgeStatusMonitor.Tests.ps1 & αφαίρεση break από catch (συνεχής παρακολούθηση)
- Προσθήκη χειρισμού “Κλειστή για συντήρηση” σε Invoke-BridgeStatusComparison & Invoke-BridgeClosedNotification & Get-BridgeStatusFromHtml (updates σε Pester tests & regex patterns)
- cleanup: ευθυγράμμιση πεδίων στο BridgeWatcher.psd1 (cosmetic)
- Προσθήκη υποστήριξης custom format view για Bridge.Status (BridgeStatus.format.ps1xml, PSVTypeName, update BridgeWatcher.psd1)
- Προσθήκη Pester tests για “Κλειστή για συντήρηση” transitions στο Invoke-BridgeStatusComparison & Invoke-BridgeClosedNotification

---

## [1.0.43] - 2025-05-28

---

## [1.0.42] - 2025-05-28

### ✨ Προστέθηκαν

- Βελτιστοποίηση workflow δημοσίευσης PowerShell module (actions/checkout@v4, fetch all tags, επιλεκτικά βήματα bump/update/commit/tag/release/publish, get latest tag, commit με bot & [skip ci], softprops/action-gh-release → v2)

---

## [1.0.41] - 2025-05-28

---

## [1.0.39] - 2025-05-28

### ✨ Προστέθηκαν

- Ενημέρωση ci config: ενεργοποίηση τερματισμού σε αποτυχίες tests
- Βελτιστοποίηση ci pipeline: αναβάθμιση actions & συνένωση βημάτων, caching modules, conditional test & coverage upload

---

## [1.0.38] - 2025-05-20

### ✨ Προστέθηκαν

- Προσθήκη ελέγχου για μη κενές optional παραμέτρους στο New-BridgePushoverPayload
- Διόρθωση συντακτικού λάθους στο git tag --sort για Get-GitCommitsSinceLastRelease.ps1
- Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs

---

## [1.0.37] - 2025-05-19

### ✨ Προστέθηκαν

- Αφαίρεση break από το catch στη Start-BridgeStatusMonitor (συνεχής παρακολούθηση)
- cleanup: ευθυγράμμιση πεδίων στο BridgeWatcher.psd1 (cosmetic)
- Προσθήκη υποστήριξης custom format view για Bridge.Status
- Προσθήκη Pester tests για αλλαγές status “Κλειστή για συντήρηση” (Invoke-BridgeStatusComparison)

---

## [1.0.36] - 2025-05-17

### ✨ Προστέθηκαν

- merge pull request: Προσθήκη υποστήριξης custom format view για Bridge.Status (σημειώνεται στο v1.0.37)
- Πρόσθετες ενημερώσεις CHANGELOG.md (μετονομασίες, ομαδοποιήσεις)

---

## [1.0.35] - 2025-05-17

### ✨ Προστέθηκαν

- Τροποποίηση GitHub Actions pipeline (PowerShell Module ci) ώστε να ενεργοποιείται σε develop & main, caching modules, test coverage στο Codecov, stopping on test failures

---

## [1.0.34] - 2025-05-16

### ✨ Προστέθηκαν

- Προσθήκη Pester tests για αλλαγές status “Κλειστή για συντήρηση” στο Invoke-BridgeStatusComparison
- Προσθήκη Pester test για status “Κλειστή για συντήρηση” στο Invoke-BridgeClosedNotification

---

## [1.0.33] - 2025-05-16

### ✨ Προστέθηκαν

- Προσθήκη Pester test για status “Κλειστή για συντήρηση” στο Invoke-BridgeClosedNotification

---

## [1.0.32] - 2025-05-16

### ✨ Προστέθηκαν

- Ενημέρωση test: Προσαρμογή Assert-MockCalled σε νέα συνολικά status (8 αντί για 6)

---

## [1.0.31] - 2025-05-07

### ✨ Προστέθηκαν

- Προσθήκη: Πλήρης εναρμόνιση headers → emojis στο Get-FormattedReleaseNotes.ps1
- Ενημέρωση Get-FormattedReleaseNotes.ps1, release notes formatting

---

## [1.0.30] - 2025-05-07

### ✨ Προστέθηκαν

- Διόρθωση: Λάθος σύνταξη στο git tag --sort για Get-GitCommitsSinceLastRelease.ps1
- Επέκταση release pipeline με filtering, merge support & προστασία διπλότυπων changelogs

---

## [1.0.29] - 2025-05-06

### ✨ Προστέθηκαν

- Προσθήκη emojis στα release notes & βελτιωμένο help στο Get-FormattedReleaseNotes

---

## [1.0.28] - 2025-05-01

### ✨ Προστέθηκαν

- Ενημέρωση του συνδέσμου του badge κάλυψης κώδικα στο νέο URL του Codecov

---

## [1.0.27] - 2025-05-01

### ✨ Προστέθηκαν

- Προσθήκη script για αυτόματη αύξηση patch version σε PowerShell module manifest

---

## [1.0.26] - 2025-05-01

### ✨ Προστέθηκαν

- Υποστήριξη εκδόσεων χωρίς “v” στο Get-ReleaseNotes.ps1

---

## [1.0.25] - 2025-05-01

### ✨ Προστέθηκαν

- Ενημέρωση regex ώστε να ταιριάζει σωστά sections τύπου `## [1.0.24]` στο CHANGELOG.md
- Ενημέρωση αρχείου publish.yml (Διαφορετικά commits)
- Προσθήκη script για αυτόματη εξαγωγή release notes & βελτιώσεις workflow

---

## [1.0.24] - 2025-05-01

### ✨ Προστέθηκαν

- Ενημέρωση αρχείου publish.yml & release.yml (πολλαπλές αλλαγές)

---

## [1.0.23] - 2025-05-01

### ✨ Προστέθηκαν

- Ενημέρωση publish.yml (commit 86ce9b4e)

---

## [1.0.22] - 2025-05-01

### ✨ Προστέθηκαν

- Ενημέρωση publish.yml (commit d146092)

---

## [1.0.21] - 2025-05-01

### ✨ Προστέθηκαν

- Ενημέρωση publish.yml (commit 381d4a6)

---

## [1.0.20] - 2025-05-01

### ✨ Προστέθηκαν

- Ενημέρωση publish.yml (commit 2993d8e)
- Αντικατάσταση inline changelog generation με script-based σύστημα στο publish.yml
- Προσθήκη συστήματος αυτόματης ενημέρωσης CHANGELOG στο `/scripts/`

---

## [1.0.19] - 2025-05-01

### ✨ Προστέθηκαν

- Προσθήκη try/catch στο test αποτυχίας API για Send-BridgePushoverRequest
- Προσθήκη mock της Send-BridgeNotification για έλεγχο ειδοποίησης τύπου Closed
- Προσθήκη υποστήριξης για structured exception handling στο Send-BridgePushoverRequest

---

## [1.0.18] - 2025-05-01

### ✨ Προστέθηκαν

- Aλλαγή encoding όλων των αρχείων σε UTF8-BOM
- Μετάφραση description & διόρθωση αναμενόμενων κλήσεων Write-BridgeLog σε Start-BridgeStatusMonitor.Tests
- Μετάφραση μηνυμάτων καταγραφής σε Start-BridgeStatusMonitor σε ελληνικά
- Διόρθωση άρθρου στο Verbose μήνυμα της Invoke-BridgeStatusComparison

---

## [1.0.17] - 2025-04-30

### ✨ Προστέθηκαν

- chore: Ενημέρωση docker-build.yml
- docs: Ενημέρωση LICENSE & README.md
- chore: Ενημέρωση publish.yml
- docs: Ενημέρωση README.md (πολλαπλές ενημερώσεις)

---

## [1.0.16] - 2025-04-29

### ✨ Προστέθηκαν

- chore: Ενημέρωση docker-build.yml
- docs: Ενημέρωση README.md & CHANGELOG.md (πολλαπλά commits)
- doc: Ενημέρωση CHANGELOG.md (commit 78fbebeb & ea1558df)

---

## [1.0.15] - 2025-04-29

### ✨ Προστέθηκαν

- chore: Ενημέρωση docker-build.yml
- docs: Ενημέρωση README.md & CHANGELOG.md (πολλαπλά commits)

---

## [1.0.14] - 2025-04-29

### ✨ Προστέθηκαν

- chore: Ενημέρωση docker-build.yml
- docs: Ενημέρωση README.md

---

## [1.0.13] - 2025-04-29

### ✨ Προστέθηκαν

- chore: Ενημέρωση docker-build.yml

---

## [1.0.12] - 2025-04-29

### ✨ Προστέθηκαν

- chore: Ενημέρωση Dockerfile (commit 4ab55dd)

---

## [1.0.11] - 2025-04-29

### ✨ Προστέθηκαν

- chore: Ενημέρωση Dockerfile (commit ce6033b7)

---

## [1.0.10] - 2025-04-29

### ✨ Προστέθηκαν

- chore: Ενημέρωση docker-build.yml (commit df9bd5b)

---

## [1.0.9] - 2025-04-29

### ✨ Προστέθηκαν

- docs(changelog): Ενημέρωση CHANGELOG.md με προσθήκες Docker, entrypoint, .env, workflow & αλλαγή run.ps1
- refactor(docker): Ενημέρωση run.ps1 για εκτέλεση σε container
- ci(docker): Δημιουργία workflow docker-build.yml για αυτόματο build εικόνων
- feat(docker): Προσθήκη entrypoint.sh για εκκίνηση Docker container
- feat(config): Προσθήκη αρχείου .env για παραμετροποίηση μεταβλητών
- feat(docker): Προσθήκη Dockerfile για containerization του BridgeWatcher
- chore: Ενημέρωση publish.yml
- chore: Ενημέρωση CHANGELOG.md

---

## [1.0.8] - 2025-04-28

### ✨ Προστέθηκαν

- chore: Ενημέρωση powershell-docs.yml (πολλαπλά commits)
- docs: auto-generate PowerShell documentation

---

## [1.0.7] - 2025-04-28

### ✨ Προστέθηκαν

- chore: Ενημέρωση powershell-docs.yml
- merge: προσθήκη codecov badge στο README

---

## [1.0.6] - 2025-04-28

### ✨ Προστέθηκαν

- chore: Δημιουργία powershell-docs.yml

---

## [1.0.5] - 2025-04-27

### ✨ Προστέθηκαν

- chore: Ενημέρωση publish.yml (πολλαπλές commits)
- docs: Ενημέρωση README.md (πολλαπλές commits)

---

## [1.0.4] - 2025-04-27

### ✨ Προστέθηκαν

- Ενημέρωση BridgeWatcher.psd1

---

## [1.0.3] - 2025-04-27

### ✨ Προστέθηκαν

- Ενημέρωση publish.yml (πολλαπλές αλλαγές)

---

## [1.0.2] - *(χειροκίνητη συλλογή commits = προκαθορισμένη έκδοση — δεν υπήρχε tag)*

### (Δεν υπάρχουν αυτοματοποιημένα tags μεταξύ v1.0.3 και v1.0.1)

---

## [1.0.1] - *(χειροκίνητη συλλογή commits = προκαθορισμένη έκδοση — δεν υπήρχε tag)*

### (Δεν υπάρχουν αυτοματοποιημένα tags μεταξύ v1.0.1 και v1.0.0)

---

## [1.0.0] - 2025-04-27

### ✨ Προστέθηκαν

- Initial commit (BridgeWatcher module)

---