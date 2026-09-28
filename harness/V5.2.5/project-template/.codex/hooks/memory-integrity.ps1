param(
    [string]$Root = '',
    [ValidateSet('Validate','Read','Stop','Search')][string]$Mode = 'Validate',
    [string]$ConversationId = '',
    [string]$SessionId = '',
    [string]$Query = ''
)
. "$PSScriptRoot/common.ps1"
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$policyPath = Join-Path $Root '.codex/harness/memory-policy.json'
if (-not (Test-Path -LiteralPath $policyPath)) { @{ passed = $false; errors = @('memory-policy-missing') } | ConvertTo-Json -Compress; exit 0 }
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$shortPath = Join-Path $Root ([string]$policy.files.short)
$longPath = Join-Path $Root ([string]$policy.files.long)
$errors = [System.Collections.Generic.List[string]]::new()
$recordPattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->\r?\n?'
$shortContent = if (Test-Path -LiteralPath $shortPath) { Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8 } else { $errors.Add('short-memory-missing'); '' }
$records = @([regex]::Matches($shortContent, $recordPattern))
$parsed = @()
foreach ($record in $records) {
    try { $parsed += [pscustomobject]@{ Meta = ($record.Groups['meta'].Value | ConvertFrom-Json); Body = $record.Groups['body'].Value; Raw = $record.Value } }
    catch { $errors.Add('invalid-memory-metadata') }
}
foreach ($group in @($parsed | Group-Object { $_.Meta.conversation_id })) {
    if ($group.Count -gt [int]$policy.maxDetailedTurnsPerOpenConversation) { $errors.Add("too-many-detailed-turns:$($group.Name)") }
}
$indexPath = Join-Path $Root ([string]$policy.files.index)
if (-not (Test-Path -LiteralPath $indexPath)) { $errors.Add('memory-index-missing') }
else {
    try {
        $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($group in @($parsed | Group-Object { $_.Meta.conversation_id })) {
            $conversation = [string]$group.Name
            $latest = @($group.Group | Sort-Object { [DateTime]$_.Meta.timestamp } | Select-Object -Last 1)[0]
            $entries = @($index.conversations | Where-Object { [string]$_.conversationId -eq $conversation })
            if ($entries.Count -ne 1) { $errors.Add("index-entry-count:$conversation"); continue }
            $entry = $entries[0]
            if ([string]$entry.location -ne 'short') { $errors.Add("index-location-mismatch:$conversation") }
            if ([string]$entry.state -ne [string]$latest.Meta.status) { $errors.Add("index-state-mismatch:$conversation") }
            if ([string]$entry.contentHash -ne (Get-ShortConversationHash $shortContent $conversation)) { $errors.Add("index-hash-mismatch:$conversation") }
        }
        foreach ($entry in @($index.conversations | Where-Object { [string]$_.location -eq 'short' })) {
            if (@($parsed | Where-Object { [string]$_.Meta.conversation_id -eq [string]$entry.conversationId }).Count -eq 0) { $errors.Add("index-orphan-short:$($entry.conversationId)") }
        }
    } catch { $errors.Add('memory-index-invalid') }
}
$txDir = Join-Path $Root ([string]$policy.files.transactions)
if (Test-Path -LiteralPath $txDir) {
    foreach ($tx in Get-ChildItem -LiteralPath $txDir -Filter '*.json' -File) {
        try { $state = (Get-Content -LiteralPath $tx.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).status; if ($state -notin @('committed','failed')) { $errors.Add("unfinished-transaction:$($tx.Name)") } }
        catch { $errors.Add("invalid-transaction:$($tx.Name)") }
    }
}

$selected = @($parsed)
if ($ConversationId) { $selected = @($selected | Where-Object { $_.Meta.conversation_id -eq $ConversationId }) }
elseif ($SessionId) { $selected = @($selected | Where-Object { $_.Meta.session_id -eq $SessionId }) }
if ($Mode -eq 'Read') {
    $context = ($selected | Select-Object -Last ([int]$policy.maxDetailedTurnsPerOpenConversation) | ForEach-Object { $_.Raw }) -join "`r`n"
    @{ passed = ($errors.Count -eq 0); source = 'short'; longRead = $false; found = ($selected.Count -gt 0); context = $context; errors = @($errors) } | ConvertTo-Json -Depth 6
    exit 0
}
if ($Mode -eq 'Stop') {
    $latest = $selected | Sort-Object { [DateTime]$_.Meta.timestamp } | Select-Object -Last 1
    $prompt = ''
    if ($null -ne $latest) { $prompt = [regex]::Match($latest.Body, '(?ms)### 用户 Prompt\s*(?<prompt>.*?)(?:\r?\n### 本轮结果)').Groups['prompt'].Value.Trim() }
    @{ passed = ($errors.Count -eq 0); found = ($null -ne $latest); conversationId = $(if ($latest) { $latest.Meta.conversation_id } else { '' }); turnId = $(if ($latest) { $latest.Meta.turn_id } else { '' }); status = $(if ($latest) { $latest.Meta.status } else { '' }); verificationCycle = $(if ($latest) { [int]$latest.Meta.verification_cycle } else { 0 }); prompt = $prompt; errors = @($errors) } | ConvertTo-Json -Depth 6
    exit 0
}
if ($Mode -eq 'Search') {
    if ($selected.Count -gt 0) { @{ passed = $true; source = 'short'; longRead = $false; found = $true; matches = @($selected | Select-Object -Last 5 | ForEach-Object { $_.Raw }) } | ConvertTo-Json -Depth 6; exit 0 }
    $longContent = if (Test-Path -LiteralPath $longPath) { Get-Content -LiteralPath $longPath -Raw -Encoding UTF8 } else { '' }
    $terms = @($Query -split '\s+' | Where-Object { $_.Length -ge 2 } | Select-Object -First 5)
    $hits = @()
    foreach ($archive in [regex]::Matches($longContent, '(?ms)<!-- memory-archive-begin:(?<id>[^:]+):(?<hash>[a-f0-9]{64}) -->.*?<!-- memory-archive-end:\k<id>:\k<hash> -->')) {
        if ($terms.Count -eq 0 -or @($terms | Where-Object { $archive.Value -match [regex]::Escape($_) }).Count -gt 0) { $hits += $archive.Value }
        if ($hits.Count -ge 3) { break }
    }
    @{ passed = $true; source = 'long'; longRead = $true; found = ($hits.Count -gt 0); matches = $hits } | ConvertTo-Json -Depth 6
    exit 0
}
@{ passed = ($errors.Count -eq 0); records = $records.Count; conversations = @($parsed | ForEach-Object { $_.Meta.conversation_id } | Select-Object -Unique).Count; errors = @($errors) } | ConvertTo-Json -Depth 6
