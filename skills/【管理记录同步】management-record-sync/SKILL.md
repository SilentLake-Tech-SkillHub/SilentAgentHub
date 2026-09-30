---
name: management-record-sync
description: Reconcile project management records after scope, implementation, validation, acceptance, version, deployment, or handoff changes. Use at stage boundaries and before reporting progress or completion.
---

# Management Record Sync

## Reconcile

Use the approved `plans.md` as the execution source of truth, then reconcile:

- `流程管理/任务管理.md`: current work and owner;
- `产品管理/需求变更记录.md`: 做 / Waitlist / 不做 demand-pool decision;
- `流程管理/需求与范围变更记录.md`: in-development status and scope history;
- decision, issue, debug, risk, acceptance, operations, version, rule-review, and handoff records;
- Router paths and module records.

Compare IDs, stage, scope, status, timestamps, version, validation, and approval. Apply the newest valid event only within the same artifact lineage and version window. If two records conflict, do not silently pick one: record the conflict, affected claims, candidate resolution, and recommended source.

Completion may be reported only when Plan, task, acceptance, issue, and version state agree. Keep Waitlist or rejected product ideas out of the engineering completion count.

At Stop, finish this reconciliation before invoking `ledger-history-archiver`. Only configured terminal rows may leave active ledgers; archive verification and index update must complete before source removal. History remains cold after migration.
