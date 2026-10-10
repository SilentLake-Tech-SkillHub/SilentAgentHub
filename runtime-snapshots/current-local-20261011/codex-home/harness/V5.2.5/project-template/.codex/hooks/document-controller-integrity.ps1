param([string]$Root)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
$registryPath = Join-Path $Root '.codex/harness/document-controllers.json'
$errors = [System.Collections.Generic.List[string]]::new()
$registry = $null
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    $errors.Add('missing document controller registry')
} else {
    try { $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { $errors.Add('invalid document controller registry JSON') }
}
if ($null -ne $registry) {
    $skills = @{}
    $paths = @{}
    foreach ($item in @($registry.controllers)) {
        if ($skills.ContainsKey([string]$item.skill)) { $errors.Add("duplicate controller skill: $($item.skill)") } else { $skills[[string]$item.skill] = $true }
        if ($paths.ContainsKey([string]$item.path)) { $errors.Add("duplicate governed path: $($item.path)") } else { $paths[[string]$item.path] = $true }
        if (-not (Test-Path -LiteralPath (Join-Path $Root "SKILLS/$($item.skill)/SKILL.md") -PathType Leaf)) { $errors.Add("missing controller: $($item.skill)") }
        $templatePath = Join-Path $Root ([string]$item.template)
        if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
            $errors.Add("missing controller template: $($item.template)")
        } else {
            $templateBody = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
            foreach ($field in @($registry.policy.humanLedgerContract.requiredFields)) {
                if ($templateBody -notmatch [regex]::Escape([string]$field)) { $errors.Add("template missing human-ledger field '$field': $($item.template)") }
            }
        }
    }
    foreach ($forbidden in @($registry.policy.forbiddenMarkdownArtifacts)) {
        $matches = @(Get-ChildItem -LiteralPath $Root -Filter ([string]$forbidden) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\.git\\' })
        if ($matches.Count -gt 0) { $errors.Add("forbidden governance Markdown exists: $forbidden") }
    }
}
@{ passed = ($errors.Count -eq 0); errors = @($errors); checked = if ($null -ne $registry) { @($registry.controllers).Count } else { 0 } } | ConvertTo-Json -Depth 5 -Compress

