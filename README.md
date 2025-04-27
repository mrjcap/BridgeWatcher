# 🌉 BridgeWatcher: Έξυπνη Παρακολούθηση Γεφυρών Ισθμού

[![CI Status](https://github.com/mrjcap/BridgeWatcher/actions/workflows/ci.yml/badge.svg)](https://github.com/mrjcap/BridgeWatcher/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Codecov](https://codecov.io/gh/mrjcap/BridgeWatcher/branch/main/graph/badge.svg)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/BridgeWatcher?color=blue)](https://www.powershellgallery.com/packages/BridgeWatcher)

---

## 📖 Περιγραφή

Το **BridgeWatcher** αποτελεί μια εξελιγμένη και πλήρως αυτοματοποιημένη λύση PowerShell module, ειδικά σχεδιασμένη για την αξιόπιστη παρακολούθηση της επιχειρησιακής κατάστασης των γεφυρών Ποσειδωνίας και Ισθμίας στην Κόρινθο. Μέσω τεχνικών HTML scraping και οπτικής αναγνώρισης χαρακτήρων (OCR) με χρήση του Google Vision API, το σύστημα αναλύει πληροφορίες σε πραγματικό χρόνο, αποστέλλει κρίσιμες ειδοποιήσεις μέσω Pushover και αρχειοθετεί τα δεδομένα σε μορφή JSON για ιστορική αναφορά και αναλυτική αξιολόγηση.

---

## 💡 Χαρακτηριστικά

- Αυτόματη και περιοδική ανάκτηση πληροφοριών από επίσημες πηγές.
- Εφαρμογή προηγμένων τεχνικών OCR για εξαγωγή χρονικών δεδομένων.
- Άμεση αποστολή προσαρμόσιμων ειδοποιήσεων μέσω Pushover API.
- Δημιουργία και διαχείριση JSON snapshots για χρονική ανάλυση.
- Ρύθμιση διαστημάτων παρακολούθησης μέσω παραμέτρων.
- Ενσωμάτωση δοκιμαστικών ελέγχων με χρήση Pester v5.
- Συμβατότητα με περιβάλλοντα CI/CD.

---
## 🛠️ Προαπαιτήσεις
📄 Προαπαιτούμενα για το PowerShell Module BridgeWatcher
Πριν ξεκινήσεις τη χρήση του BridgeWatcher module, θα χρειαστείς τα παρακάτω:

### Google Vision API Key:

  Για να χρησιμοποιήσεις τις δυνατότητες OCR (Οπτική Αναγνώριση Χαρακτήρων) του BridgeWatcher, απαιτείται Google Vision API Key.

  Μπορείς να αποκτήσεις το API Key από το Google Cloud Console, αφού ενεργοποιήσεις το Vision API για το πρότζεκτ σου.

### Pushover API Key:

  Για την αποστολή ειδοποιήσεων, χρειάζεσαι το Pushover API Key.

  Μπορείς να αποκτήσεις το API Key από το Pushover website, αφού δημιουργήσεις έναν λογαριασμό.

###  Pushover User Key:

  Το Pushover User Key είναι απαραίτητο για να στέλνεις ειδοποιήσεις στον προσωπικό σου λογαριασμό.

  Θα το βρεις στο Pushover Dashboard αφού συνδεθείς με τον λογαριασμό σου.

### Εφαρμογή Pushover στο κινητό (Android/iOS):

  Για να λαμβάνεις ειδοποιήσεις στο κινητό σου, θα χρειαστεί να κατεβάσεις και να εγκαταστήσεις την εφαρμογή Pushover.

  Η εφαρμογή είναι διαθέσιμη για Android και iOS. Μπορείς να τη βρεις στο Google Play Store ή στο Apple App Store.

## 🛠️ Απαιτήσεις

- Windows PowerShell 5.1 ή PowerShell 7+
- Συμβατότητα με PowerShell Core
- Καμία ανάγκη πρόσθετων modules ή βιβλιοθηκών

---

## 📦 Εγκατάσταση

```powershell
# Εγκατάσταση από PowerShell Gallery (όταν διατεθεί):
Install-Module -Name BridgeWatcher -Scope CurrentUser

# Χειροκίνητη φόρτωση από τοπικό αποθετήριο:
Import-Module ./src/BridgeWatcher.psd1 -Force
```

---

## 🚀 Παραδείγματα Χρήσης

**Έναρξη Συνεχούς Παρακολούθησης:**
```powershell
Start-BridgeStatusMonitor -IntervalSeconds 600 -PoApiKey 'your-api-key' -PoUserKey 'your-user-key' -ApiKey 'your-google-vision-api-key' -OutputFile './BridgeStatusSnapshot.json'
```


**Ανάκτηση Τρέχουσας Κατάστασης:**
```powershell
Get-BridgeStatus -Verbose
```

---

## 🧩 Εξαρτήσεις Module

Το **BridgeWatcher** έχει αναπτυχθεί ως πλήρως αυτοδύναμο module:

- Χρησιμοποιεί Pester 5 αποκλειστικά για testing.

---

## 📝 Άδειες και Συνεισφορές

- Άδεια Χρήσης: [MIT License](https://opensource.org/licenses/MIT)
- Δημιουργός: Γιάννης Καπλατζής
- Επίσημο Repository: [https://github.com/mrjcap/BridgeWatcher](https://github.com/mrjcap/BridgeWatcher)

Η κοινότητα καλωσορίζεται να συμβάλλει μέσω Pull Requests και αναφορών σφαλμάτων.

---

## 🗺️ Οδικός Χάρτης Εξέλιξης

- [x] Πλήρης κάλυψη δοκιμών μέσω Pester
- [x] Ενσωμάτωση CI με GitHub Actions
- [x] Έκδοση στο PowerShell Gallery
- [ ] Ενσωμάτωση Codecov

---
