# Initialization acceptance

Initialization passes only when all applicable checks have evidence:

- The actual root is identified and Router paths resolve or are explicit placeholders.
- The user goal, current stage, enabled modules, deferred scope, and acceptance criteria are recorded.
- A durable Windows project is located on a user-approved non-system drive, or the system-drive exception and migration decision are explicitly recorded.
- `产品管理/需求变更记录.md` and `流程管理/需求与范围变更记录.md` have distinct ownership.
- Every complex initialization has an approved `流程管理/执行计划/<任务ID>_<任务名>/plans.md` before execution.
- Git exists at the intended boundary, existing history and user changes are preserved, and no accidental nested repository was created.
- `.gitignore` excludes secrets, local environments, caches, and build outputs; `.env.example` contains names and descriptions only.
- Root `ARCHITECTURE.md` is the only project architecture source of truth; code-management records do not duplicate it.
- Project-root `MEMORY.md`, `SHORT_MEMORY.md`, and `LONG_MEMORY.md` exist, are registered in Router, are not ignored by Git, and pass Memory integrity; only locks and incomplete temporary files are ignored.
- The cold history index and retention policy exist. Automatic retention remains disabled until fixture and project acceptance have passed.
- When knowledge management is enabled, KnowledgeRouter identifies project knowledge and has explicit R&D hub Router/index/log plus LLM Wiki placeholders or verified identities.
- Each enabled module has a local rule satisfying the module-rule contract; deferred modules were not scaffolded.
- When a code module is enabled, `.codex/harness/source-layout.json` exists, every enabled directory has a non-empty responsibility and exists on disk, every actual immediate directory under configured coverage roots is declared or explicitly excluded, and `source-layout-integrity.ps1` returns `passed: true`.
- When no code module is enabled, `.codex/harness/index.json` explicitly keeps `sourceLayoutRequired: false`; absence of a source-layout manifest is then intentional rather than an omitted check.
- Reusable assets were searched and selection or rejection reasons were recorded.
- Task, issue, risk, acceptance, version, and context-handoff records exist where applicable and do not contradict the Plan.
- A validation command or a documented substitute check was run for every created artifact.
- The final report distinguishes verified, unverified, deferred, and awaiting-user-approval items.
