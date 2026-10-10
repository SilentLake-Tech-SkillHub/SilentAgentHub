#!/usr/bin/env pwsh
<#
.SYNOPSIS
  回归测试：用 doc-plan 出厂模板生成 Plan，走真实 Register 链路。
.DESCRIPTION
  这是 V5.2.5 原包缺失的那个测试。

  原包的 plan-disclosure-e2e.ps1 在第 57-58 行自行手写
      "# PLAN A`r`n`r`n## State`r`n`r`nState: awaiting_review`r`n"
  绕开了 doc-plan/assets/template.md。于是模板产出的格式（Markdown 列表项）
  与 plan-disclosure-runtime.ps1 的校验正则（要求 State 独占一行）不兼容这一缺陷，
  被测试完全掩盖：fixture 恒过，真实 Plan 门禁恒失效。

  本测试从**真实模板**出发，模拟 doc-plan 填表，然后调用 Register，
  断言 passed=true。模板一旦退回到列表项格式，本测试立刻失败。

.EXAMPLE
  pwsh -NoProfile -File Test-PlanTemplateRegression.ps1
  pwsh -NoProfile -File Test-PlanTemplateRegression.ps1 -ProjectRoot ~/Documents/Codex/Agent-Harness-V5.2.5
#>
param(
    [string]$CodexHome   = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [string]$ProjectRoot = (Join-Path $HOME 'Documents/Codex/Agent-Harness-V5.2.5')
)

$ErrorActionPreference = 'Stop'
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$runId   = Get-Date -Format 'yyyyMMddHHmmssfff'
$root    = Join-Path ([System.IO.Path]::GetTempPath()) "Harness-PlanTemplate-$runId"
$hooks   = Join-Path $root '.codex/hooks'
$harness = Join-Path $root '.codex/harness'
$planDir = Join-Path $root '流程管理/执行计划/T-REG_TemplateRegression'

$results = [ordered]@{}
function Assert([string]$Name, [bool]$Condition, [string]$Detail = '') {
    $results[$Name] = $Condition
    if (-not $Condition) { throw "断言失败: $Name $Detail" }
}

try {
    New-Item -ItemType Directory -Path $hooks, $harness, $planDir -Force | Out-Null
    Copy-Item -Path (Join-Path $ProjectRoot '.codex/hooks/*') -Destination $hooks -Recurse -Force
    foreach ($n in @('memory-policy.json','memory-policy.schema.json',
                     'plan-disclosure-state.json','plan-disclosure-state.schema.json','index.json')) {
        Copy-Item -LiteralPath (Join-Path $ProjectRoot ".codex/harness/$n") -Destination $harness -Force
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'MEMORY.md'),       "# MEMORY Rules`r`n", $utf8Bom)
    [System.IO.File]::WriteAllText((Join-Path $root 'SHORT_MEMORY.md'), "# SHORT MEMORY`r`n`r`n## Active Conversations`r`n", $utf8Bom)
    [System.IO.File]::WriteAllText((Join-Path $root 'LONG_MEMORY.md'),  "# LONG MEMORY`r`n`r`n## Closed Conversations`r`n", $utf8Bom)

    # ---- 1. 取真实出厂模板 ----
    $templatePath = Join-Path $CodexHome 'skills/doc-plan/assets/template.md'
    Assert 'templateExists' (Test-Path -LiteralPath $templatePath -PathType Leaf) $templatePath
    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8

    # ---- 2. 模拟 doc-plan 填表，并同时覆盖 LF / CRLF ----
    #     先归一化为 LF，再只做占位符替换；不重写模板结构。
    $templateLf = $template -replace "`r`n?", "`n"
    $filledLf = $templateLf -replace '(?m)^State[ \t]*:[ \t]*<[^>]*>[ \t]*$', 'State: awaiting_review'
    Assert 'placeholderReplaced' ($filledLf -ne $templateLf) '模板中没有可替换的 `State: <...>` 占位行'

    # ---- 3. 写与 turn 对应的 Memory 记录（Register 需要 prompt_hash） ----
    $conversationId = 'template-regression-conversation'
    foreach ($variant in @(
        [pscustomobject]@{ Name = 'LF'; Eol = "`n" },
        [pscustomobject]@{ Name = 'CRLF'; Eol = "`r`n" }
    )) {
        $variantDir = Join-Path $root "流程管理/执行计划/T-REG_TemplateRegression-$($variant.Name)"
        New-Item -ItemType Directory -Path $variantDir -Force | Out-Null
        $body = $filledLf -replace "`n", $variant.Eol
        [System.IO.File]::WriteAllText((Join-Path $variantDir 'plans.md'), $body, $utf8Bom)

        $turnId = "turn-template-regression-$($variant.Name.ToLowerInvariant())"
        $capture = & (Join-Path $hooks 'memory-runtime.ps1') -Event Capture -Root $root `
            -Prompt "请创建 $($variant.Name) 执行计划并等待审批。" -ConversationId $conversationId `
            -SessionId 'template-regression-session' -TurnId $turnId
        $captureResult = (($capture | Out-String).Trim()) | ConvertFrom-Json
        Assert "memoryCaptured$($variant.Name)" ([bool]$captureResult.captured) ($capture | Out-String)

        $register = & (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root `
            -ConversationId $conversationId -TurnId $turnId `
            -PlanPath "流程管理/执行计划/T-REG_TemplateRegression-$($variant.Name)/plans.md" `
            -QueryRoute plan_create_or_update
        $reg = (($register | Out-String).Trim()) | ConvertFrom-Json
        Assert "registerPassed$($variant.Name)" ([bool]$reg.passed) (
            "Register $($variant.Name) 失败: $(@($reg.errors) -join ',')")
        Assert "recordPending$($variant.Name)" ([string]$reg.record.state -eq 'pending') "state=$($reg.record.state)"

        $read = ((& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Read -Root $root `
            -ConversationId $conversationId -TurnId $turnId | Out-String).Trim()) | ConvertFrom-Json
        Assert "readFound$($variant.Name)" ([bool]$read.found -and [bool]$read.passed) ($read | ConvertTo-Json -Compress)

        $ack = ((& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Acknowledge -Root $root `
            -ConversationId $conversationId -TurnId $turnId | Out-String).Trim()) | ConvertFrom-Json
        Assert "acknowledged$($variant.Name)" ([string]$ack.record.state -eq 'disclosed') ($ack | ConvertTo-Json -Compress)
    }

    # ---- 7. 状态文件整体合法 ----
    $val = ((& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Validate -Root $root | Out-String).Trim()) | ConvertFrom-Json
    Assert 'stateValid' ([bool]$val.passed) (@($val.errors) -join ',')

    # ---- 8. 兼容格式：列表、粗体、反引号、全角冒号 ----
    $formatCases = [ordered]@{
        list = '- State: awaiting_review'
        bold = '**State**: **awaiting_review**'
        code = 'State: `awaiting_review`'
        fullwidth = 'State：awaiting_review'
    }
    foreach ($caseName in $formatCases.Keys) {
        $caseDir = Join-Path $root "流程管理/执行计划/T-FMT-$caseName"
        New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $caseDir 'plans.md'), "# Format`r`n`r`n## State`r`n`r`n$($formatCases[$caseName])`r`n", $utf8Bom)
        $caseTurn = "turn-format-$caseName"
        & (Join-Path $hooks 'memory-runtime.ps1') -Event Capture -Root $root -Prompt "format $caseName" `
            -ConversationId $conversationId -SessionId 'template-regression-session' -TurnId $caseTurn | Out-Null
        $caseReg = ((& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root `
            -ConversationId $conversationId -TurnId $caseTurn -PlanPath "流程管理/执行计划/T-FMT-$caseName/plans.md" | Out-String).Trim()) | ConvertFrom-Json
        Assert "formatAccepted-$caseName" ([bool]$caseReg.passed) (@($caseReg.errors) -join ',')
    }

    # ---- 9. 负向：未填 State 与跨行状态必须被拒 ----
    $rawDir = Join-Path $root '流程管理/执行计划/T-RAW_Untouched'
    New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $rawDir 'plans.md'), $template, $utf8Bom)
    & (Join-Path $hooks 'memory-runtime.ps1') -Event Capture -Root $root -Prompt 'raw template' `
        -ConversationId $conversationId -SessionId 'template-regression-session' -TurnId 'turn-raw' | Out-Null
    $rawReg = ((& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root `
        -ConversationId $conversationId -TurnId 'turn-raw' `
        -PlanPath '流程管理/执行计划/T-RAW_Untouched/plans.md' | Out-String).Trim()) | ConvertFrom-Json
    Assert 'untouchedTemplateRejected' (-not [bool]$rawReg.passed -and @($rawReg.errors) -match 'plan-not-awaiting-review') '未填写 State 的模板应因状态而被拒'

    $splitDir = Join-Path $root '流程管理/执行计划/T-SPLIT_CrossLine'
    New-Item -ItemType Directory -Path $splitDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $splitDir 'plans.md'), "# Split`n`n## State`n`nState:`nawaiting_review`n", $utf8Bom)
    & (Join-Path $hooks 'memory-runtime.ps1') -Event Capture -Root $root -Prompt 'split state' `
        -ConversationId $conversationId -SessionId 'template-regression-session' -TurnId 'turn-split' | Out-Null
    $splitReg = ((& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root `
        -ConversationId $conversationId -TurnId 'turn-split' `
        -PlanPath '流程管理/执行计划/T-SPLIT_CrossLine/plans.md' | Out-String).Trim()) | ConvertFrom-Json
    Assert 'crossLineRejected' (-not [bool]$splitReg.passed -and @($splitReg.errors) -match 'plan-not-awaiting-review') '跨行 State 不应通过 Register'

    $out = [ordered]@{ passed = $true }
    foreach ($k in $results.Keys) { $out[$k] = $results[$k] }
    $out | ConvertTo-Json -Depth 6 -Compress
}
catch {
    [ordered]@{ passed = $false; error = $_.Exception.Message; checks = $results } | ConvertTo-Json -Depth 6 -Compress
    exit 1
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}
