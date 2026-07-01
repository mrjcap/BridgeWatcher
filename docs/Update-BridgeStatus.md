---
external help file: BridgeWatcher-help.xml
Module Name: BridgeWatcher
online version:
schema: 2.0.0
---

# Update-BridgeStatus

## SYNOPSIS

Συγκρίνει προηγούμενη και τρέχουσα κατάσταση γεφυρών.

## SYNTAX

```
Update-BridgeStatus [-OutputFile] <String> [-ApiKey] <String> [-PoUserKey] <String> [-PoApiKey] <String>
 [[-Configuration] <PSObject>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Η Get-BridgeStatusComparison συγκρίνει δύο snapshots γεφυρών
και ανιχνεύει αλλαγές κατάστασης.

## EXAMPLES

### EXAMPLE 1

```
Get-BridgeStatusComparison -OutputFile 'C:\Logs\bridge-status.json' -ApiKey 'abc123' -PoUserKey 'user123' -PoApiKey 'token123'
```

## PARAMETERS

### -OutputFile

Το path του αρχείου JSON για αποθήκευση νέου snapshot.

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

### -ApiKey

Το API Key για OCR ανάλυση αν απαιτηθεί.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PoUserKey

Το User Key του παραλήπτη για ειδοποίηση.

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

### -PoApiKey

Το API Token της εφαρμογής Pushover.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
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
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf

Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
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

Χρησιμοποιεί OCR αν χρειάζεται, συγκρίνει states και αποστέλλει ειδοποιήσεις.

## RELATED LINKS
