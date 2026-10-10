param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ConversationId,
    [Parameter(Mandatory = $true)][string]$TurnId,
    [ValidateSet('completed','needs_user','blocked','cancelled','superseded','closed_unresolved')][string]$Status,
    [string]$Result = '',
    [string[]]$Evidence = @(),
    [string]$NextAction = '',
    [switch]$UserApprovedClosure,
    [switch]$SimulateLongWriteFailure
)
. "$PSScriptRoot/common.ps1"
$Root = [System.IO.Path]::GetFullPath($Root)
$policy = Get-Content -LiteralPath (Join-Path $Root '.codex/harness/memory-policy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Status -eq 'closed_unresolved' -and -not $UserApprovedClosure) { throw 'closed_unresolved requires explicit user approval.' }
if ($Status -eq 'completed' -and $Evidence.Count -eq 0) { throw 'completed requires formal validation or acceptance evidence.' }

$shortPath = Join-Path $Root ([string]$policy.files.short)
if (-not (Test-Path -LiteralPath $shortPath)) { throw "SHORT_MEMORY is missing: $shortPath" }
$content = Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8
$pattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->\r?\n?'
$targetFound = $false
foreach ($candidate in [regex]::Matches($content, $pattern)) {
    $candidateMeta = $candidate.Groups['meta'].Value | ConvertFrom-Json
    if ([string]$candidateMeta.conversation_id -eq $ConversationId -and [string]$candidateMeta.turn_id -eq $TurnId) { $targetFound = $true; break }
}
if (-not $targetFound) { throw "Memory turn not found: $ConversationId/$TurnId" }
$output = [regex]::Replace($content, $pattern, {
    param($match)
    $meta = $match.Groups['meta'].Value | ConvertFrom-Json
    if ([string]$meta.conversation_id -ne $ConversationId -or [string]$meta.turn_id -ne $TurnId) { return $match.Value }
    $meta.status = $Status
    $meta.verification_cycle = 1
    $meta.evidence = @($Evidence | ForEach-Object { Protect-MemoryText ([string]$_) })
    if ($meta.PSObject.Properties.Name -notcontains 'closed_at') { $meta | Add-Member -NotePropertyName closed_at -NotePropertyValue $null }
    if (@($policy.terminalStates) -contains $Status) { $meta.closed_at = [DateTime]::UtcNow.ToString('o') }
    $body = $match.Groups['body'].Value
    $body = [regex]::Replace($body, '(?ms)### 本轮结果\s*.*?(?=\r?\n### 下一步)', "### 本轮结果`r`n`r`n$(Protect-MemoryText $Result)`r`n")
    $body = [regex]::Replace($body, '(?ms)### 下一步\s*.*?$', "### 下一步`r`n`r`n$(Protect-MemoryText $NextAction)`r`n")
    return "<!-- memory-record-begin -->`r`n$($meta | ConvertTo-Json -Depth 8 -Compress)`r`n$($body.Trim())`r`n<!-- memory-record-end -->`r`n"
})
Write-Utf8BomFile $shortPath $output

if (@($policy.terminalStates) -contains $Status) {
    $migration = & (Join-Path $PSScriptRoot 'memory-short-to-long.ps1') -Root $Root -ConversationId $ConversationId -Status $Status -UserApprovedClosure:$UserApprovedClosure -SimulateLongWriteFailure:$SimulateLongWriteFailure
    $migration
} else {
    $null = & (Join-Path $PSScriptRoot 'memory-compact.ps1') -Root $Root -ConversationId $ConversationId
    $finalShort = Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8
    $indexPath = Join-Path $Root ([string]$policy.files.index)
    if (-not (Test-Path -LiteralPath $indexPath)) { throw "Memory index is missing during closeout: $indexPath" }
    $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $entry = @($index.conversations | Where-Object { [string]$_.conversationId -eq $ConversationId })
    if ($entry.Count -ne 1) { throw "Memory index entry count is not one during closeout: $ConversationId" }
    if ([string]$entry[0].state -ne $Status -or [string]$entry[0].location -ne 'short') { throw "Memory index state did not follow closeout: $ConversationId/$Status" }
    $expectedHash = Get-ShortConversationHash $finalShort $ConversationId
    if ([string]$entry[0].contentHash -ne $expectedHash) { throw "Memory index hash did not follow closeout: $ConversationId" }
    @{ passed = $true; changed = $true; migrated = $false; conversationId = $ConversationId; turnId = $TurnId; status = $Status } | ConvertTo-Json -Compress
}
