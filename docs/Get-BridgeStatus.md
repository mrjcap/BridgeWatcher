---
external help file: BridgeWatcher-help.xml
Module Name: BridgeWatcher
online version:
schema: 2.0.0
---

# Get-BridgeStatus

## SYNOPSIS

Ανακτά την τρέχουσα κατάσταση γεφυρών από διαδικτυακή σελίδα.

## SYNTAX

```
Get-BridgeStatus [[-OutputFile] <String>] [[-Configuration] <PSObject>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION

Η Get-BridgeStatus ανακτά HTML, αναλύει την κατάσταση
και επιστρέφει λίστα καταστάσεων γεφυρών χρησιμοποιώντας
τα utility functions New-BridgeResult και Test-BridgeResult
για καλύτερο error handling και DRY compliance.

## EXAMPLES

### EXAMPLE 1

```
Get-BridgeStatus -OutputFile 'C:\Logs\current-status.json'
```

### EXAMPLE 2

```
$result = Get-BridgeStatus
if (Test-BridgeResult $result) {
    Write-Host "Success: $($result.Data.Count) bridges found"
} else {
    Write-Warning "Error: $($result.ErrorMessage)"
}
```

## PARAMETERS

### -OutputFile

(Προαιρετικό) Το αρχείο όπου θα αποθηκευτεί η τρέχουσα κατάσταση.

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

### -Configuration

(Προαιρετικό) Αντικείμενο διαμόρφωσης.
Αν δεν παρέχεται, δημιουργείται αυτόματα.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

### [PSCustomObject] - Αντικείμενο αποτελέσματος με Success, Data, ErrorMessage, ErrorCode και Timestamp

## NOTES

Χρησιμοποιεί pipeline approach με New-BridgeResult/Test-BridgeResult για καλύτερο error handling.

## RELATED LINKS
