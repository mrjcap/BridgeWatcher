## v1.0.9 - 2025-04-29
* docs(changelog): Ενημέρωση CHANGELOG.md με προσθήκες Docker, entrypoint, .env, workflow και αλλαγή run.ps1

# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Ανέκδοτα]

### Προστέθηκαν

- Προστέθηκε `Dockerfile` για containerization του BridgeWatcher (`feat(docker): Προσθήκη Dockerfile για containerization`).
- Προστέθηκε αρχείο περιβάλλοντος `.env` για παραμετροποίηση μεταβλητών (`feat(config): Προσθήκη αρχείου .env για παραμετροποίηση`).
- Προστέθηκε το script `entrypoint.sh` ως entrypoint για τα Docker containers (`feat(docker): Προσθήκη entrypoint.sh για εκκίνηση container`).
- Δημιουργήθηκε workflow `docker-build.yml` για αυτόματο build Docker images μέσω GitHub Actions (`ci(docker): Δημιουργία docker-build.yml workflow`).

### Αλλαγές

- Ενημερώθηκε το `run.ps1` ώστε να τρέχει εντός Docker container (`refactor(docker): Ενημέρωση run.ps1 για εκτέλεση σε container`).

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
