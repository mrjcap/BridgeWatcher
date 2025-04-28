## v1.0.8 - 2025-04-28
* chore: Update powershell-docs.yml

## v1.0.7 - 2025-04-28
* Update powershell-docs.yml

## v1.0.6 - 2025-04-28
* chore: Create powershell-docs.yml

# Changelog

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.5] - 2025-04-27

### Αλλαγές
- Ενημέρωση αρχείου `publish.yml`

## [1.0.4] - 2025-04-27

### Προστέθηκαν
- Ενσωμάτωση Codecov για παρακολούθηση κάλυψης κώδικα

## [1.0.3] - 2025-04-27

### Αλλαγές
- Ενημέρωση του αρχείου `README.md` με λεπτομέρειες για τη χρήση του module

## [1.0.2] - 2025-04-27

### Προστέθηκαν
- Δημιουργία workflow για Publish στο PowerShell Gallery

## [1.0.1] - 2025-04-23

### Προστέθηκαν
- Επανασχεδιασμός λογικής `Get-DiorigaStatus` με προτεραιότητα εικόνας
- Αποφυγή OCR όταν δεν απαιτείται
- Κατάργηση χρονικών συγκρίσεων (`Now > To`)
- Προσθήκη αυτοτεκμηρίωσης (README generator)
- 100% test coverage σε OCR + εικόνα logic

## [1.0.0] - 2025-04-11

### Προστέθηκαν
- Αρχική έκδοση του PowerShell module `BridgeWatcher`
- 100% Pester test coverage
- Λειτουργίες για ανίχνευση κατάστασης γεφυρών, OCR μέσω Google Vision API και ειδοποιήσεις Pushover
- Συνεχής ενσωμάτωση GitHub Actions με έλεγχο δοκιμών και κάλυψης
