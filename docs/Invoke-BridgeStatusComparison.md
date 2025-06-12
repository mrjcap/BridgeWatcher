---
external help file: BridgeWatcher-help.xml
Module Name: BridgeWatcher
online version:
schema: 2.0.0
---

# Invoke-BridgeStatusComparison

## SYNOPSIS

Συγκρίνει δύο λίστες καταστάσεων γεφυρών και ενεργοποιεί ειδοποιήσεις.

## SYNTAX

```
Invoke-BridgeStatusComparison [-PreviousState] <Object[]> [-CurrentState] <Object[]> [-ApiKey] <String>
 [-PoUserKey] <String> [-PoApiKey] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Η Invoke-BridgeStatusComparison συγκρίνει την προηγούμενη και την τρέχουσα
κατάσταση γεφυρών και καλεί ειδικούς handlers για αλλαγές (άνοιγμα/κλείσιμο).

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -ApiKey 'abc' -PoUserKey 'user' -PoApiKey 'token'
```

## PARAMETERS

### -PreviousState

Η προηγούμενη λίστα καταστάσεων.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CurrentState

Η τρέχουσα λίστα καταστάσεων.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey

Το API Key για OCR αν απαιτηθεί.

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

### -PoUserKey

Το User Key για Pushover ειδοποίηση.

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

### -PoApiKey

Το API Token για Pushover ειδοποίηση.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
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

Καταγράφει αλλαγές και ενεργοποιεί κατάλληλες ειδοποιήσεις.

## RELATED LINKS
