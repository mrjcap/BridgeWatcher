---
external help file: BridgeWatcher-help.xml
Module Name: BridgeWatcher
online version:
schema: 2.0.0
---

# Get-BridgeStatusMonitor

## SYNOPSIS

Ξεκινά συνεχή παρακολούθηση της κατάστασης γεφυρών.

## SYNTAX

```
Get-BridgeStatusMonitor [[-MaxIterations] <Int32>] [[-IntervalSeconds] <Int32>] [-OutputFile] <String>
 [[-ApiKey] <String>] [[-PoUserKey] <String>] [[-PoApiKey] <String>] [[-Configuration] <PSObject>]
 [[-Action] <ScriptBlock>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Get-BridgeStatusMonitor performs continuous monitoring of bridge statuses,
periodically fetching and analyzing the status and storing results.

Η Get-BridgeStatusMonitor εκτελεί ατέρμονο monitoring της κατάστασης γεφυρών,
κάνοντας περιοδικά λήψη και ανάλυση της κατάστασης και αποθηκεύοντας αποτελέσματα.

## EXAMPLES

### EXAMPLE 1

```
Get-BridgeStatusMonitor -MaxIterations 100 -IntervalSeconds 60 -OutputFile 'C:\Logs\bridge.json' -ApiKey 'api123' -PoUserKey 'user123' -PoApiKey 'token123'
```

### EXAMPLE 2

```
Get-BridgeStatusMonitor -OutputFile 'C:\Logs\bridge.json' -Action {
    param($splat)
    Write-Host "Custom monitoring action running for $($splat.OutputFile)"
    Update-BridgeStatus @splat
}
```

## PARAMETERS

### -MaxIterations

Ο μέγιστος αριθμός επαναλήψεων πριν τερματιστεί (0 για άπειρες).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -IntervalSeconds

Το διάστημα (σε δευτερόλεπτα) ανάμεσα σε κάθε έλεγχο (1-3600 δευτερόλεπτα, μέγιστο 1 ώρα).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputFile

Η διαδρομή αποθήκευσης των τρεχουσών καταστάσεων.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey

Το API Key που χρησιμοποιείται για OCR αναλύσεις.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PoUserKey

Το User Key για αποστολή Pushover ειδοποιήσεων.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PoApiKey

Το API Token της εφαρμογής Pushover.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Configuration

(Προαιρετικό) Αντικείμενο διαμόρφωσης.
Αν δεν παρέχεται, δημιουργείται αυτόματα.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Action

(Προαιρετικό) Scriptblock που εκτελείται κατά τη διάρκεια του monitoring αντί για την προεπιλεγμένη Update-BridgeStatus.

```yaml
Type: ScriptBlock
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

### None

## NOTES

Το monitoring συνεχίζει μέχρι να ολοκληρωθούν οι επαναλήψεις ή να τερματιστεί χειροκίνητα.

## RELATED LINKS
