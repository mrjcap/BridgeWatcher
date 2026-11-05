# Empty OCR result returns null instead of throwing terminating error

ConvertFrom-BridgeOCRResult returns $null when vision analysis extracts zero text tokens. Callers such as
Invoke-BridgeClosedNotification evaluate this $null return value to dispatch alerts directing users to inspect the
schedule graphic directly. Reserving terminating errors strictly for HTTP and network failures prevents conflating
unreadable notices with upstream infrastructure outages.
