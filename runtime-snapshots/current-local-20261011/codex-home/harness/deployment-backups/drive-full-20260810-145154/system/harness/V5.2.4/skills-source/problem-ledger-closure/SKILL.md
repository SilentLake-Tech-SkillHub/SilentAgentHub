---
name: problem-ledger-closure
description: Track and close a project problem from discovery through analysis, repair, verification, and rule-candidate review. Use for bugs, failures, regressions, repeated rework, operational incidents, documentation defects, or any issue that must be auditable in 流程管理/问题流水.md.
---

# Problem Ledger Closure

## Workflow

1. Add the problem as `新增` before repair. Capture time, trigger, impact, severity, priority, owner, and evidence.
2. Classify it as one of: 需求、研究、分析规划、决策、设计、前端、后端、数据、AI Agent、测试、运维、文档、版本、规则、安全、权限、性能、兼容性、集成、环境、部署、知识同步.
3. Reproduce or establish evidence, set `分析中`, and record competing causes plus the current best explanation.
4. Set `修复中` only when work begins. Link the task, Plan, changed files, and target version.
5. After changes, set `待验证`; record commands, screenshots, logs, or substitute checks.
6. Set `已关闭` only after verification passes. Otherwise use `待修复`, `需用户决策`, `阻塞`, or `暂缓处理` with the next action.
7. Also update `debug记录.md` for bugs and failures, and `运维记录.md` for environment or production operations.

## Rule candidate trigger

Add an item to `流程管理/规则补充待审.md` when any of these occurs: recurrence, missing rule, unclear directory boundary, missing validation, repeated Agent misjudgment, cross-project impact, or a reusable long-term practice. Do not edit the system-level rule until the user approves it.

## Closeout gate

A closed item must contain root cause, actual treatment, affected version, validation evidence, regression scope, duplicate relation, and whether it became a rule or Skill candidate.
