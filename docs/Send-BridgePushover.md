---
external help file: BridgeWatcher-help.xml
Module Name: BridgeWatcher
online version:
schema: 2.0.0
---

# Send-BridgePushover

## SYNOPSIS

Αποστέλλει ειδοποίηση μέσω Pushover για κατάσταση γέφυρας.

## SYNTAX

```
Send-BridgePushover [-PoUserKey] <String> [-PoApiKey] <String> [-Message] <String> [[-Device] <String>]
 [[-Title] <String>] [[-Url] <String>] [[-UrlTitle] <String>] [[-Priority] <Int32>] [[-Sound] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Η Send-BridgePushover δημιουργεί payload και αποστέλλει ειδοποίηση
στο σύστημα Pushover, χρησιμοποιώντας παρεχόμενα διαπιστευτήρια.

## EXAMPLES

### EXAMPLE 1

```
Send-BridgePushover -PoUserKey 'user123' -PoApiKey 'token123' -Message 'Η γέφυρα είναι ανοιχτή.'
```

## PARAMETERS

### -PoUserKey

Το User Key του παραλήπτη στο Pushover.

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

### -PoApiKey

Το API Token της εφαρμογής.

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

### -Message

Το μήνυμα της ειδοποίησης.

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

### -Device

Η συσκευή στόχος (προαιρετικό).

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

### -Title

Ο τίτλος της ειδοποίησης (προαιρετικό).

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

### -Url

URL που θα επισυνάπτεται στην ειδοποίηση (προαιρετικό).

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

### -UrlTitle

Ο τίτλος για το επισυναπτόμενο URL (προαιρετικό).

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

### -Priority

Η προτεραιότητα ειδοποίησης (προαιρετικό).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Sound

Ο ήχος ειδοποίησης (προαιρετικό).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
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

Χρησιμοποιεί εσωτερικές helper συναρτήσεις για payload και αποστολή.

## RELATED LINKS
