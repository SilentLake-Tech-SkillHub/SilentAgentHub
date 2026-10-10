# 执行计划

> Path: `流程管理/执行计划/<任务ID>_<任务名>/plans.md`

## 治理信息

- 记录时间：
- 触发需求 / 事件：
- 调用 Skills / plugins：
- 当前状态：
- 关联需求 / 任务 / Decision / Plan：
- 本次结果：
- 下一步：
- 最近校验：

## State

State: <draft|awaiting_review|approved|executing|validating|awaiting_acceptance|closed>

> 上面这一行必须独占一行并以 `State:` 开头。`plan-disclosure-runtime.ps1 -Event Register`
> 以正则匹配该行来判定 Plan 是否处于 `awaiting_review`；写成 Markdown 列表项会导致注册
> 抛出 `plan-not-awaiting-review`，Plan 门禁将静默失效。

## Purpose

- 待填写

## Progress

- 待填写

## Context

- 待填写

## Plan of Work

- 待填写

## Validation

- 待填写

## Decision Log

- 待填写

## Surprises & Discoveries

- 待填写

## Outcomes & Retrospective

- 待填写
