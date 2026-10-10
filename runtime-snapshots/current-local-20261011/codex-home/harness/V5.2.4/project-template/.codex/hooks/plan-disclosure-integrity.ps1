param(
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$ConversationId = '',
    [string]$TurnId = '',
    [switch]$StopHookActive
)

. "$PSScriptRoot/common.ps1"

$result = [ordered]@{
    passed = $true
    requiresDisclosure = $false
    allowStop = $true
    planPath = $null
    planHash = $null
    state = $null
    fullPlan = $null
    systemMessage = $null
}

if ([string]::IsNullOrWhiteSpace($ConversationId) -or [string]::IsNullOrWhiteSpace($TurnId)) {
    $result.systemMessage = 'No current Query/turn binding was supplied; global awaiting_review Plans are intentionally ignored.'
    Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}

$runtime = Join-Path $PSScriptRoot 'plan-disclosure-runtime.ps1'
if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) {
    $result.passed = $false
    $result.allowStop = $false
    $result.systemMessage = 'Repair the current Query Plan route: plan-disclosure-runtime.ps1 is missing.'
    Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}

$read = (((& $runtime -Event Read -Root $Root -ConversationId $ConversationId -TurnId $TurnId) | Out-String).Trim()) | ConvertFrom-Json
if (-not [bool]$read.passed) {
    $result.passed = $false
    $result.allowStop = $false
    $result.systemMessage = 'Repair the current Query Plan route before ending: ' + (@($read.errors) -join ', ')
    Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}
if (-not [bool]$read.found) {
    $result.systemMessage = 'The current user Query is not registered as a Plan creation, update, or explicit redisclosure turn.'
    Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}

$record = $read.record
$relativePath = [string]$record.planPath
$candidatePath = [System.IO.Path]::GetFullPath((Join-Path $Root ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
$rootPrefix = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $candidatePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
    $result.passed = $false
    $result.allowStop = $false
    $result.systemMessage = 'Repair the current Query Plan binding before ending: registered Plan path is missing or outside the project root.'
    Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}
$planBody = [System.IO.File]::ReadAllText($candidatePath, [System.Text.Encoding]::UTF8)
$planHash = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($planHash -ne [string]$record.planHash) {
    $result.passed = $false
    $result.allowStop = $false
    $result.systemMessage = "Re-register the current Query Plan before ending: '$relativePath' changed after disclosure routing."
    Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}
if ($planBody -notmatch '(?im)^State\s*:\s*awaiting_review\s*$') {
    $result.passed = $false
    $result.allowStop = $false
    $result.systemMessage = "Repair the current Query Plan route before ending: '$relativePath' is no longer awaiting_review."
    Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}

$result.requiresDisclosure = ([string]$record.state -eq 'pending')
$result.planPath = $relativePath
$result.planHash = $planHash
$result.state = [string]$record.state
$result.fullPlan = $planBody

if ([string]$record.state -eq 'disclosed') {
    $result.systemMessage = "The current Query-bound Plan '$relativePath' already has a disclosure receipt."
} elseif (-not $StopHookActive) {
    $result.passed = $false
    $result.allowStop = $false
    $result.systemMessage = @"
The current user Query created, materially changed, or explicitly requested redisclosure of the Plan below. Before ending, output the COMPLETE Plan verbatim or as fully faithful Markdown, then explicitly ask the user to approve it. Do not replace it with a link, summary, excerpt, or file path. This is the one allowed Stop reinjection for the current Query binding and Plan hash $planHash.

--- COMPLETE PLAN START ---
$planBody
--- COMPLETE PLAN END ---
"@
} else {
    $ack = (((& $runtime -Event Acknowledge -Root $Root -ConversationId $ConversationId -TurnId $TurnId) | Out-String).Trim()) | ConvertFrom-Json
    if (-not [bool]$ack.passed) {
        $result.passed = $false
        $result.allowStop = $false
        $result.systemMessage = 'Persist the current Query Plan disclosure receipt before ending: ' + (@($ack.errors) -join ', ')
    } else {
        $result.state = 'disclosed'
        $result.systemMessage = "The one-time Plan disclosure continuation for '$relativePath' has been acknowledged for this Query/turn."
    }
}

Write-Output ($result | ConvertTo-Json -Depth 8 -Compress)
