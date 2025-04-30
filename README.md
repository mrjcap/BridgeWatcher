# 🌉 BridgeWatcher: Προηγμένη Παρακολούθηση Γεφυρών Ισθμού

[![Κατάσταση CI](https://github.com/mrjcap/BridgeWatcher/actions/workflows/ci.yml/badge.svg)](https://github.com/mrjcap/BridgeWatcher/actions/workflows/ci.yml)
[![Κατασκευή Docker](https://github.com/mrjcap/BridgeWatcher/actions/workflows/docker-build.yml/badge.svg)](https://github.com/mrjcap/BridgeWatcher/actions/workflows/docker-build.yml)
[![Τεκμηρίωση PowerShell](https://github.com/mrjcap/BridgeWatcher/actions/workflows/powershell-docs.yml/badge.svg)](https://github.com/mrjcap/BridgeWatcher/actions/workflows/powershell-docs.yml)
[![Δημοσίευση](https://github.com/mrjcap/BridgeWatcher/actions/workflows/publish.yml/badge.svg)](https://github.com/mrjcap/BridgeWatcher/actions/workflows/publish.yml)
![Κάλυψη Κώδικα](https://codecov.io/gh/mrjcap/BridgeWatcher/branch/main/graph/badge.svg)
[![Έκδοση PowerShell Gallery](https://img.shields.io/powershellgallery/v/BridgeWatcher?color=blue)](https://www.powershellgallery.com/packages/BridgeWatcher)
[![Λήψεις από Gallery](https://img.shields.io/powershellgallery/dt/BridgeWatcher?color=blue)](https://www.powershellgallery.com/packages/BridgeWatcher)
[![Docker Pulls](https://img.shields.io/docker/pulls/mrjcap/bridgewatcher.svg)](https://hub.docker.com/r/mrjcap/bridgewatcher/)
[![Άδεια: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)



---

## 📖 Περιγραφή

Το **BridgeWatcher** αποτελεί ένα υψηλής εξειδίκευσης και πλήρως αυτοματοποιημένο PowerShell module, σχεδιασμένο με σκοπό την αξιόπιστη εποπτεία της λειτουργικής κατάστασης των γεφυρών Ποσειδωνίας και Ισθμίας στον Ισθμό της Κορίνθου. Με την αξιοποίηση τεχνικών HTML scraping και Οπτικής Αναγνώρισης Χαρακτήρων (OCR) μέσω του Google Vision API, το σύστημα διενεργεί σε βάθος ανάλυση δεδομένων σε πραγματικό χρόνο, αποστέλλει κρίσιμες ειδοποιήσεις μέσω της πλατφόρμας Pushover και διατηρεί ιστορικό καταγραφών σε μορφή JSON για εκ των υστέρων επεξεργασία και αξιολόγηση.

---

## 💡 Δυνατότητες

- Αυτοματοποιημένη και επαναλαμβανόμενη ανάκτηση δεδομένων από επίσημες διαδικτυακές πηγές
- Χρήση εξελιγμένων αλγορίθμων OCR για ακριβή εξαγωγή χρονικών παραμέτρων
- Στιγμιαία αποστολή προσαρμοσμένων ειδοποιήσεων μέσω Pushover API
- Δημιουργία και διαχείριση χρονικών στιγμιοτύπων (JSON snapshots)
- Ευέλικτος καθορισμός διαστημάτων παρακολούθησης μέσω παραμέτρων
- Ενσωματωμένες δοκιμές μονάδων με χρήση Pester έκδοσης 5
- Απόλυτη συμβατότητα με περιβάλλοντα συνεχούς ενσωμάτωσης (CI/CD)

---

## 🛠️ Προϋποθέσεις

### 📄 **Απαραίτητες Παράμετροι για την εκτέλεση του BridgeWatcher**

Προτού ξεκινήσεις την αξιοποίηση του **BridgeWatcher**, βεβαιώσου ότι έχεις εξασφαλίσει τα ακόλουθα:

1. **Κλειδί API για Google Vision**
   - Απαραίτητο για την ενεργοποίηση των OCR λειτουργιών.
   - Απόκτησέ το μέσω του [Google Cloud Console](https://console.cloud.google.com/) ενεργοποιώντας το αντίστοιχο API.

2. **Κλειδί Pushover API**
   - Απαιτείται για την αποστολή ειδοποιήσεων προς την πλατφόρμα Pushover.
   - Παρέχεται μέσω του [επίσημου ιστότοπου Pushover](https://pushover.net/).

3. **Κλειδί Χρήστη Pushover (User Key)**
   - Απαραίτητο για την προσωποποιημένη αποστολή ειδοποιήσεων.
   - Εντοπίζεται μέσω του [Pushover Dashboard](https://pushover.net/).

4. **Εγκατάσταση Pushover στο κινητό**
   - Για την απρόσκοπτη λήψη ειδοποιήσεων, απαιτείται η εφαρμογή Pushover σε Android ή iOS.
   - Διαθέσιμη στο [Google Play Store](https://play.google.com/store/apps/details?id=com.pushover.client) και στο [Apple App Store](https://apps.apple.com/us/app/pushover/id506088175).

---

## 📦 Εγκατάσταση

```powershell
# Εγκατάσταση μέσω PowerShell Gallery:
Install-Module -Name BridgeWatcher -Scope CurrentUser

# Χειροκίνητη φόρτωση από τοπικό αποθετήριο:
Import-Module ./BridgeWatcher.psd1 -Force
```

---

## 🚀 Παραδείγματα Χρήσης

**Εκκίνηση συνεχούς παρακολούθησης:**

```powershell
$startBridgeStatusMonitorSplat = @{
    MaxIterations      = 0
    IntervalSeconds    = 600
    PoApiKey           = 'your-api-key'
    PoUserKey          = 'your-user-key'
    ApiKey             = 'your-google-vision-api-key'
    OutputFile         = './BridgeStatusSnapshot.json'
}

Start-BridgeStatusMonitor @startBridgeStatusMonitorSplat
```

**Άμεση ανάκτηση τρέχουσας κατάστασης:**

```powershell
Get-BridgeStatus -Verbose
```

---

## 🧩 Εξαρτήσεις Module

Το **BridgeWatcher** έχει αναπτυχθεί ως αυτάρκες module χωρίς εξωτερικές εξαρτήσεις, με αποκλειστική χρήση του Pester v5 για τις δοκιμές.

---

## 📝 Άδεια Χρήσης & Συμμετοχή

- **Άδεια**: [MIT License](https://opensource.org/licenses/MIT)
- **Συγγραφέας**: Γιάννης Καπλατζής
- **Repository**: [GitHub: mrjcap/BridgeWatcher](https://github.com/mrjcap/BridgeWatcher)
- Κάθε μορφή συνεισφοράς είναι ευπρόσδεκτη — είτε μέσω Pull Requests είτε μέσω αναφοράς ζητημάτων.

---

## 🗺️ Οδικός Χάρτης Ανάπτυξης

- [x] Ολοκληρωμένη κάλυψη μέσω Pester tests
- [x] Ενσωμάτωση GitHub Actions για CI
- [x] Δημοσίευση στο PowerShell Gallery
- [x] Υποστήριξη Codecov
- [x] Δημιουργία Docker Image

---
