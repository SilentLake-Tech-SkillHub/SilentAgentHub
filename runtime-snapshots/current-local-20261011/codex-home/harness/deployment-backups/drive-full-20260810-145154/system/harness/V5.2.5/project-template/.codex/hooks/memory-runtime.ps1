param(
    [Parameter(Mandatory = $true)][ValidateSet('Capture','Read','Compact','Repair','Closeout','Validate')][string]$Event,
    [string]$Root = '',
    [string]$Prompt = '',
    [string]$ConversationId = '',
    [string]$SessionId = '',
    [string]$TurnId = '',
    [string]$TaskId = '',
    [string]$PlanId = '',
    [ValidateSet('completed','needs_user','blocked','cancelled','superseded','closed_unresolved')][string]$Status,
    [string]$Result = '',
    [string[]]$Evidence = @(),
    [string]$NextAction = '',
    [switch]$UserApprovedClosure
)
. "$PSScriptRoot/common.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)

switch ($Event) {
    'Capture' {
        & (Join-Path $PSScriptRoot 'memory-prompt-capture.ps1') -Root $Root -Prompt $Prompt -ConversationId $ConversationId -SessionId $SessionId -TurnId $TurnId -TaskId $TaskId -PlanId $PlanId
    }
    'Read' {
        & (Join-Path $PSScriptRoot 'memory-integrity.ps1') -Root $Root -Mode Read -ConversationId $ConversationId -SessionId $SessionId
    }
    'Compact' {
        & (Join-Path $PSScriptRoot 'memory-compact.ps1') -Root $Root -ConversationId $ConversationId -SessionId $SessionId
    }
    'Repair' {
        & (Join-Path $PSScriptRoot 'memory-orphan-repair.ps1') -Root $Root
    }
    'Closeout' {
        & (Join-Path $PSScriptRoot 'memory-turn-closeout.ps1') -Root $Root -ConversationId $ConversationId -TurnId $TurnId -Status $Status -Result $Result -Evidence $Evidence -NextAction $NextAction -UserApprovedClosure:$UserApprovedClosure
    }
    'Validate' {
        & (Join-Path $PSScriptRoot 'memory-integrity.ps1') -Root $Root -Mode Validate
    }
}
