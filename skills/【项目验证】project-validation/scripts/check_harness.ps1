param(
    [Parameter(Mandatory = $false)]
    [string]$Root = (Get-Location).Path
)

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$required = @('ROUTER.md', 'ARCHITECTURE.md', 'MEMORY.md', 'SHORT_MEMORY.md', 'LONG_MEMORY.md', '流程管理', '知识管理', '流程管理/历史记录库/INDEX.md', '知识管理/KnowledgeRouter.md')
$results = foreach ($item in $required) {
    $path = Join-Path $resolvedRoot $item
    [pscustomobject]@{
        Item = $item
        Exists = Test-Path -LiteralPath $path
        Path = $path
    }
}

$missing = @($results | Where-Object { -not $_.Exists })
[pscustomobject]@{
    Root = $resolvedRoot
    Passed = $missing.Count -eq 0
    Missing = @($missing | ForEach-Object { $_.Item })
    Results = @($results)
} | ConvertTo-Json -Depth 5

if ($missing.Count -gt 0) { exit 1 }
