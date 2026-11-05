# MD5 schedule image hashing during status retrieval to gate OCR calls

The upstream bridge website serves scheduled closure notices from static PHP endpoints whose URLs do not change when a
new schedule graphic is posted. To detect schedule updates without invoking Google Vision OCR on every polling cycle,
`Get-BridgeStatusObject` downloads the schedule image bytes during status retrieval and computes an MD5 `ImageHash`.
`Invoke-BridgeStatusComparison` compares `ImageHash` values between snapshots so OCR runs only when a bridge enters a
scheduled closure or its schedule image content changes.
