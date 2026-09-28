param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ConversationId,
    [Parameter(Mandatory = $true)][string]$Status,
    [switch]$UserApprovedClosure,
    [switch]$SimulateLongWriteFailure
)
. "$PSScriptRoot/common.ps1"
$Root = [System.IO.Path]::GetFullPath($Root)
$policy = Get-Content -LiteralPath (Join-Path $Root '.codex/harness/memory-policy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($policy.terminalStates) -notcontains $Status) { throw "Not a terminal state: $Status" }
if ($Status -eq 'closed_unresolved' -and -not $UserApprovedClosure) { throw 'closed_unresolved requires explicit user approval.' }
$shortPath = Join-Path $Root ([string]$policy.files.short)
$longPath = Join-Path $Root ([string]$policy.files.long)
$indexPath = Join-Path $Root ([string]$policy.files.index)
$txDir = Join-Path $Root ([string]$policy.files.transactions)
$lockDir = Join-Path $Root ([string]$policy.files.locks)
New-Item -ItemType Directory -Path $txDir, $lockDir -Force | Out-Null
$lockPath = Join-Path $lockDir ($ConversationId + '.lock')
$lockStream = $null
$txId = "memory-$ConversationId-$(Get-Date -Format 'yyyyMMddHHmmssfff')"
$txPath = Join-Path $txDir ($txId + '.json')
try {
    $lockStream = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    $shortContent = Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8
    $recordPattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->\r?\n?'
    $records = @([regex]::Matches($shortContent, $recordPattern) | Where-Object { (($_.Groups['meta'].Value | ConvertFrom-Json).conversation_id) -eq $ConversationId })
    if ($records.Count -eq 0) {
        $longExisting = if (Test-Path -LiteralPath $longPath) { Get-Content -LiteralPath $longPath -Raw -Encoding UTF8 } else { '' }
        if ($longExisting -match ('"conversation_id":"' + [regex]::Escape($ConversationId) + '"')) {
            @{ passed = $true; changed = $false; migrated = $true; reason = 'already-in-long'; conversationId = $ConversationId } | ConvertTo-Json -Compress
            exit 0
        }
        throw "Conversation not found in SHORT_MEMORY: $ConversationId"
    }
    $latestRecord = $records | Sort-Object { [DateTime](($_.Groups['meta'].Value | ConvertFrom-Json).timestamp) } | Select-Object -Last 1
    $latestMeta = $latestRecord.Groups['meta'].Value | ConvertFrom-Json
    if (@($policy.terminalStates) -notcontains [string]$latestMeta.status) { throw "Latest conversation turn is not terminal: $($latestMeta.status)" }
    $rollupPattern = '(?ms)<!-- memory-rollup-begin:' + [regex]::Escape($ConversationId) + ' -->.*?<!-- memory-rollup-end:' + [regex]::Escape($ConversationId) + ' -->\r?\n?'
    $activeSummaryPattern = '(?ms)<!-- memory-active-summary-begin:' + [regex]::Escape($ConversationId) + ' -->.*?<!-- memory-active-summary-end:' + [regex]::Escape($ConversationId) + ' -->\r?\n?'
    $rollup = [regex]::Match($shortContent, $rollupPattern).Value
    $payload = (($records | ForEach-Object { $_.Value }) -join "`r`n") + $rollup
    $payloadHash = Get-Sha256 $payload
    $tx = [ordered]@{ transactionId = $txId; type = 'short-to-long'; conversationId = $ConversationId; status = 'prepared'; payloadHash = $payloadHash; createdAt = [DateTime]::UtcNow.ToString('o'); source = $shortPath; destination = $longPath }
    Write-Utf8BomFile $txPath (($tx | ConvertTo-Json -Depth 6) + "`r`n")
    if ($SimulateLongWriteFailure) { throw 'Simulated LONG_MEMORY write failure.' }
    $longContent = if (Test-Path -LiteralPath $longPath) { Get-Content -LiteralPath $longPath -Raw -Encoding UTF8 } else { "# LONG_MEMORY`r`n`r`n> Closed conversations only. Cold by default.`r`n" }
    $archiveMarker = "<!-- memory-archive-begin:${ConversationId}:${payloadHash} -->`r`n$payload`r`n<!-- memory-archive-end:${ConversationId}:${payloadHash} -->`r`n"
    if ($longContent -notmatch [regex]::Escape("memory-archive-begin:${ConversationId}:${payloadHash}")) { $longContent += "`r`n$archiveMarker" }
    $longTemp = "$longPath.$txId.tmp"
    Write-Utf8BomFile $longTemp $longContent
    $verifyLong = Get-Content -LiteralPath $longTemp -Raw -Encoding UTF8
    if ($verifyLong -notmatch [regex]::Escape("memory-archive-begin:${ConversationId}:${payloadHash}")) { throw 'LONG_MEMORY verification failed.' }
    Move-Item -LiteralPath $longTemp -Destination $longPath -Force
    $tx.status = 'destination_verified'
    Write-Utf8BomFile $txPath (($tx | ConvertTo-Json -Depth 6) + "`r`n")

    $newShort = $shortContent
    foreach ($record in $records) { $newShort = $newShort.Replace($record.Value, '') }
    $newShort = [regex]::Replace($newShort, $rollupPattern, '')
    $newShort = [regex]::Replace($newShort, $activeSummaryPattern, '')
    $shortTemp = "$shortPath.$txId.tmp"
    Write-Utf8BomFile $shortTemp $newShort
    if ((Get-Content -LiteralPath $shortTemp -Raw -Encoding UTF8) -match ('"conversation_id":"' + [regex]::Escape($ConversationId) + '"')) { throw 'SHORT_MEMORY cleanup verification failed.' }
    Move-Item -LiteralPath $shortTemp -Destination $shortPath -Force

    if (Test-Path -LiteralPath $indexPath) {
        $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $now = [DateTime]::UtcNow.ToString('o')
        $updated = @($index.conversations | ForEach-Object {
            if ($_.conversationId -eq $ConversationId) { $_.state = $Status; $_.location = 'long'; $_.updatedAt = $now; $_.contentHash = $payloadHash }
            $_
        })
        $out = [ordered]@{ '$schema' = './memory-index.schema.json'; version = '1.0.0'; updatedAt = $now; conversations = $updated }
        Write-Utf8BomFile $indexPath (($out | ConvertTo-Json -Depth 8) + "`r`n")
    }
    $tx.status = 'committed'; $tx.completedAt = [DateTime]::UtcNow.ToString('o')
    Write-Utf8BomFile $txPath (($tx | ConvertTo-Json -Depth 6) + "`r`n")
    @{ passed = $true; changed = $true; migrated = $true; conversationId = $ConversationId; status = $Status; payloadHash = $payloadHash; transaction = $txPath } | ConvertTo-Json -Compress
} catch {
    if (Test-Path -LiteralPath $txPath) {
        try {
            $failed = Get-Content -LiteralPath $txPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $failed.status = 'failed'; $failed | Add-Member -NotePropertyName error -NotePropertyValue $_.Exception.Message -Force
            Write-Utf8BomFile $txPath (($failed | ConvertTo-Json -Depth 8) + "`r`n")
        } catch { }
    }
    throw
} finally {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
}
