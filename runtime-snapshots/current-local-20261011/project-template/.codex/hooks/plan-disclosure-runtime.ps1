param(
    [Parameter(Mandatory = $true)][ValidateSet('Register','Read','Acknowledge','Validate')][string]$Event,
    [string]$Root = '',
    [string]$ConversationId = '',
    [string]$TurnId = '',
    [string]$PlanPath = '',
    [ValidateSet('plan_create_or_update','plan_redisclose')][string]$QueryRoute = 'plan_create_or_update'
)

. "$PSScriptRoot/common.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
$indexPath = Join-Path $Root '.codex/harness/index.json'
$stateRelative = '.codex/harness/plan-disclosure-state.json'
if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
    $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $configured = [string](Get-PropertyValue $index 'planDisclosureState' '')
    if (-not [string]::IsNullOrWhiteSpace($configured)) { $stateRelative = $configured }
}
$statePath = Join-Path $Root $stateRelative
$lockPath = Join-Path $Root '.codex/harness/plan-disclosure-state.lock'

function New-DisclosureState {
    [pscustomobject]@{ '$schema' = './plan-disclosure-state.schema.json'; version = '1.0.0'; updatedAt = $null; records = @() }
}

function Read-DisclosureState {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return New-DisclosureState }
    Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-DisclosureState([object]$State) {
    $State.updatedAt = [DateTime]::UtcNow.ToString('o')
    $parent = Split-Path -Parent $statePath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = "$statePath.$PID.tmp"
    try {
        $encoding = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($temp, (($State | ConvertTo-Json -Depth 10) + "`r`n"), $encoding)
        Move-Item -LiteralPath $temp -Destination $statePath -Force
    } finally { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
}

function Assert-StableId([string]$Value, [string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Za-z0-9._-]+$') { throw "invalid-$Name" }
}

function Resolve-BoundedPlan([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) { throw 'invalid-plan-path' }
    $full = [System.IO.Path]::GetFullPath((Join-Path $Root ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
    $prefix = $Root + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'plan-path-outside-root' }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw 'plan-file-missing' }
    $full
}

function Get-TurnPromptHash([string]$Conversation, [string]$Turn) {
    $shortPath = Join-Path $Root 'SHORT_MEMORY.md'
    if (-not (Test-Path -LiteralPath $shortPath -PathType Leaf)) { throw 'short-memory-missing' }
    $content = Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8
    $pattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->'
    $turnRecords = @()
    foreach ($record in [regex]::Matches($content, $pattern)) {
        $meta = $record.Groups['meta'].Value | ConvertFrom-Json
        if ([string](Get-PropertyValue $meta 'conversation_id' '') -eq $Conversation -and [string]$meta.turn_id -eq $Turn) { $turnRecords += $meta }
    }
    if ($turnRecords.Count -ne 1) { throw "query-turn-record-count:$($turnRecords.Count)" }
    $hash = [string]$turnRecords[0].prompt_hash
    if ($hash -notmatch '^[a-fA-F0-9]{64}$') { throw 'invalid-query-prompt-hash' }
    $hash.ToUpperInvariant()
}

function Test-State([object]$State) {
    $errors = [System.Collections.Generic.List[string]]::new()
    if ([string]$State.version -ne '1.0.0') { $errors.Add('invalid-version') }
    $seen = @{}
    foreach ($record in @($State.records)) {
        foreach ($field in @('conversationId','turnId','promptHash','planPath','planHash','queryRoute','state','registeredAt')) {
            if ([string]::IsNullOrWhiteSpace([string](Get-PropertyValue $record $field ''))) { $errors.Add("missing-$field") }
        }
        if ([string]$record.promptHash -notmatch '^[A-Fa-f0-9]{64}$') { $errors.Add('invalid-prompt-hash') }
        if ([string]$record.planHash -notmatch '^[A-Fa-f0-9]{64}$') { $errors.Add('invalid-plan-hash') }
        if ([string]$record.conversationId -notmatch '^[A-Za-z0-9._-]+$') { $errors.Add('invalid-conversation-id') }
        if ([string]$record.turnId -notmatch '^[A-Za-z0-9._-]+$') { $errors.Add('invalid-turn-id') }
        if ([System.IO.Path]::IsPathRooted([string]$record.planPath) -or [string]$record.planPath -match '(^|/|\\)\.\.(/|\\|$)') { $errors.Add('invalid-plan-path') }
        if ([string]$record.queryRoute -notin @('plan_create_or_update','plan_redisclose')) { $errors.Add('invalid-query-route') }
        if ([string]$record.state -notin @('pending','disclosed')) { $errors.Add('invalid-disclosure-state') }
        if ([string]$record.state -eq 'disclosed' -and [string]::IsNullOrWhiteSpace([string]$record.disclosedAt)) { $errors.Add('missing-disclosed-at') }
        if ([string]$record.state -eq 'pending' -and -not [string]::IsNullOrWhiteSpace([string]$record.disclosedAt)) { $errors.Add('pending-has-disclosed-at') }
        $key = "$($record.conversationId)|$($record.turnId)"
        if ($seen.ContainsKey($key)) { $errors.Add("duplicate-turn-binding:$key") } else { $seen[$key] = $true }
        if ($record.PSObject.Properties.Name -contains 'prompt' -or $record.PSObject.Properties.Name -contains 'planBody') { $errors.Add('forbidden-content-field') }
    }
    if (@($State.records).Count -gt 200) { $errors.Add('record-retention-limit-exceeded') }
    @($errors)
}

try {
    if ($Event -in @('Register','Read','Acknowledge')) { Assert-StableId $ConversationId 'conversation-id'; Assert-StableId $TurnId 'turn-id' }
    if ($Event -eq 'Validate') {
        $state = Read-DisclosureState; $errors = @(Test-State $state)
        [ordered]@{ passed = ($errors.Count -eq 0); records = @($state.records).Count; errors = $errors } | ConvertTo-Json -Depth 8 -Compress
        exit 0
    }
    if ($Event -eq 'Read') {
        $state = Read-DisclosureState; $errors = @(Test-State $state)
        if ($errors.Count -gt 0) { [ordered]@{ passed = $false; found = $false; errors = $errors } | ConvertTo-Json -Depth 8 -Compress; exit 0 }
        $turnBindings = @($state.records | Where-Object { [string]$_.conversationId -eq $ConversationId -and [string]$_.turnId -eq $TurnId })
        if ($turnBindings.Count -gt 1) { [ordered]@{ passed = $false; found = $false; errors = @('multiple-current-turn-bindings') } | ConvertTo-Json -Depth 8 -Compress; exit 0 }
        if ($turnBindings.Count -eq 0) { [ordered]@{ passed = $true; found = $false; errors = @() } | ConvertTo-Json -Depth 8 -Compress; exit 0 }
        $record = $turnBindings[0]; $currentPromptHash = Get-TurnPromptHash $ConversationId $TurnId
        if ([string]$record.promptHash -ne $currentPromptHash) { [ordered]@{ passed = $false; found = $true; errors = @('query-prompt-hash-mismatch') } | ConvertTo-Json -Depth 8 -Compress; exit 0 }
        [ordered]@{ passed = $true; found = $true; record = $record; errors = @() } | ConvertTo-Json -Depth 8 -Compress
        exit 0
    }

    $lockParent = Split-Path -Parent $lockPath
    if (-not (Test-Path -LiteralPath $lockParent)) { New-Item -ItemType Directory -Path $lockParent -Force | Out-Null }
    $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $state = Read-DisclosureState; $errors = @(Test-State $state)
        if ($errors.Count -gt 0) { throw ('invalid-disclosure-state:' + ($errors -join ',')) }
        $turnBindings = @($state.records | Where-Object { [string]$_.conversationId -eq $ConversationId -and [string]$_.turnId -eq $TurnId })
        if ($Event -eq 'Register') {
            $fullPlan = Resolve-BoundedPlan $PlanPath
            $relativePlan = $fullPlan.Substring($Root.Length).TrimStart('\','/') -replace '\\','/'
            $planBody = [System.IO.File]::ReadAllText($fullPlan, [System.Text.Encoding]::UTF8)
            if ($planBody -notmatch '(?im)^State\s*:\s*awaiting_review\s*$') { throw 'plan-not-awaiting-review' }
            $planHash = (Get-FileHash -LiteralPath $fullPlan -Algorithm SHA256).Hash.ToUpperInvariant(); $promptHash = Get-TurnPromptHash $ConversationId $TurnId
            if ($turnBindings.Count -gt 0) {
                $existing = $turnBindings[0]
                if ([string]$existing.planPath -ne $relativePlan) { throw 'multiple-plan-bindings-for-current-query' }
                if ([string]$existing.planHash -eq $planHash -and [string]$existing.queryRoute -eq $QueryRoute) { [ordered]@{ passed = $true; changed = $false; record = $existing } | ConvertTo-Json -Depth 8 -Compress; exit 0 }
            }
            $now = [DateTime]::UtcNow.ToString('o'); $kept = @($state.records | Where-Object { -not ([string]$_.conversationId -eq $ConversationId -and [string]$_.turnId -eq $TurnId) })
            $record = [pscustomobject]@{ conversationId = $ConversationId; turnId = $TurnId; promptHash = $promptHash; planPath = $relativePlan; planHash = $planHash; queryRoute = $QueryRoute; state = 'pending'; registeredAt = $now; disclosedAt = $null }
            $state.records = @($kept | Select-Object -Last 199) + @($record); Write-DisclosureState $state
            [ordered]@{ passed = $true; changed = $true; record = $record } | ConvertTo-Json -Depth 8 -Compress
            exit 0
        }
        if ($turnBindings.Count -ne 1) { throw "current-turn-binding-count:$($turnBindings.Count)" }
        $record = $turnBindings[0]; $fullPlan = Resolve-BoundedPlan ([string]$record.planPath); $currentHash = (Get-FileHash -LiteralPath $fullPlan -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($currentHash -ne [string]$record.planHash) { throw 'plan-hash-changed-before-acknowledge' }
        if ([string]$record.state -eq 'disclosed') { [ordered]@{ passed = $true; changed = $false; record = $record } | ConvertTo-Json -Depth 8 -Compress; exit 0 }
        $record.state = 'disclosed'; $record.disclosedAt = [DateTime]::UtcNow.ToString('o'); Write-DisclosureState $state
        [ordered]@{ passed = $true; changed = $true; record = $record } | ConvertTo-Json -Depth 8 -Compress
    } finally { if ($null -ne $lock) { $lock.Dispose() }; Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
} catch {
    [ordered]@{ passed = $false; changed = $false; found = $false; errors = @("$($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]") } | ConvertTo-Json -Depth 8 -Compress
    exit 0
}
