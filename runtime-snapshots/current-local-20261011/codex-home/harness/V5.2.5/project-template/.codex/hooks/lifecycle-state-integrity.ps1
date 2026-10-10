param([string]$Root, [string]$From, [string]$To, [string[]]$Evidence = @())

$Evidence = @($Evidence | ForEach-Object { @([string]$_ -split ',') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
$machinePath = Join-Path $Root '.codex/harness/lifecycle-state-machine.json'
$errors = [System.Collections.Generic.List[string]]::new()
$machine = $null
if (-not (Test-Path -LiteralPath $machinePath -PathType Leaf)) {
    $errors.Add('missing lifecycle state machine')
} else {
    try { $machine = Get-Content -LiteralPath $machinePath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { $errors.Add('invalid lifecycle state machine JSON') }
}
if ($null -ne $machine) {
    $stateSet = @($machine.states)
    if (@($stateSet | Select-Object -Unique).Count -ne $stateSet.Count) { $errors.Add('duplicate lifecycle states') }
    foreach ($transition in @($machine.transitions)) {
        if ($stateSet -notcontains [string]$transition.from -or $stateSet -notcontains [string]$transition.to) { $errors.Add("transition references unknown state: $($transition.from)->$($transition.to)") }
    }
    if (-not [string]::IsNullOrWhiteSpace($From) -and -not [string]::IsNullOrWhiteSpace($To)) {
        $allowed = @($machine.transitions | Where-Object { $_.from -eq $From -and $_.to -eq $To }).Count -gt 0
        if (-not $allowed) { $errors.Add("invalid transition: $From->$To") }
        $gateName = "$From->$To"
        $gateProperty = $machine.gates.PSObject.Properties[$gateName]
        if ($null -ne $gateProperty) {
            foreach ($requiredEvidence in @($gateProperty.Value)) {
                if ($Evidence -notcontains [string]$requiredEvidence) { $errors.Add("missing gate evidence: $requiredEvidence") }
            }
        }
    }
}
@{ passed = ($errors.Count -eq 0); errors = @($errors); transition = if ($From -and $To) { "$From->$To" } else { $null } } | ConvertTo-Json -Depth 5 -Compress
