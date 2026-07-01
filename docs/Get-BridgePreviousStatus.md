---
external help file: BridgeWatcher-help.xml
Module Name: BridgeWatcher
online version:
schema: 2.0.0
---

# Get-BridgePreviousStatus

## SYNOPSIS

Ανακτά προηγούμενη αποθηκευμένη κατάσταση γέφυρας από JSON.

## SYNTAX

```
Get-BridgePreviousStatus [-InputFile] <String> [[-JsonDepth] <Int32>] [[-Configuration] <PSObject>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Η Get-BridgePreviousStatus διαβάζει αρχείο JSON που περιέχει
καταγεγραμμένη κατάσταση γεφυρών.

## EXAMPLES

### EXAMPLE 1

```
Get-BridgePreviousStatus -InputFile 'C:\Logs\previous-status.json'
```

### EXAMPLE 2

```
Get-BridgePreviousStatus -InputFile 'C:\Logs\previous-status.json' -JsonDepth 5
```

## PARAMETERS

### -InputFile

Η διαδρομή του αρχείου JSON.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -JsonDepth

Το βάθος deserialization του JSON (προεπιλογή: 10).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -Configuration

{{ Fill Configuration Description }}

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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

### Λίστα καταστάσεων ή κενό array αν δεν υπάρχει

## NOTES

Ασφαλής ανάγνωση με structured error handling και fallback.

## RELATED LINKS
