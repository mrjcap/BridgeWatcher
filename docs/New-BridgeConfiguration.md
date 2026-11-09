---
external help file: BridgeWatcher-help.xml
Module Name: BridgeWatcher
online version:
schema: 2.0.0
---

# New-BridgeConfiguration

## SYNOPSIS

Δημιουργεί ένα configuration object για το BridgeWatcher module.

## SYNTAX

```
New-BridgeConfiguration [[-BaseUrl] <String>] [[-OCRApiUrl] <String>] [[-PushoverApiUrl] <String>]
 [[-DefaultIntervalSeconds] <Int32>] [[-DefaultMaxIterations] <Int32>] [[-MaxConsecutiveFailures] <Int32>]
 [[-LogDirectory] <String>] [[-ConfigurationPath] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION

Κεντρικοποιεί όλα τα configuration settings, URLs, patterns και mappings
που χρησιμοποιούνται στο BridgeWatcher module.
Επιστρέφει ένα αντικείμενο
με Urls, Defaults, Statuses και υπο-αντικείμενα μηνυμάτων.

## EXAMPLES

### Example 1

```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -BaseUrl

Το base URL για τα δεδομένα και εικόνες γεφυρών.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OCRApiUrl

Το URL για τη Google Cloud Vision API.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PushoverApiUrl

Το URL για την αποστολή Pushover notifications.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DefaultIntervalSeconds

Το προεπιλεγμένο διάστημα σε δευτερόλεπτα για τη παρακολούθηση.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 300
Accept pipeline input: False
Accept wildcard characters: False
```

### -DefaultMaxIterations

Ο προεπιλεγμένος μέγιστος αριθμός επαναλήψεων.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 100
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxConsecutiveFailures

Ο μέγιστος αριθμός διαδοχικών αποτυχιών.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: 60
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogDirectory

Ο κατάλογος αποθήκευσης αρχείων καταγραφής.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConfigurationPath

Προαιρετική διαδρομή σε εξωτερικό αρχείο JSON για παράκαμψη των προεπιλογών.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction

{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### [PSCustomObject] - Αντικείμενο διαμόρφωσης με Urls, Defaults, Statuses και υπο-αντικείμενα μηνυμάτων

## NOTES

Αυτή η συνάρτηση δημιουργεί μόνο ένα configuration object στη μνήμη και δεν αλλάζει την κατάσταση του συστήματος.

## RELATED LINKS
