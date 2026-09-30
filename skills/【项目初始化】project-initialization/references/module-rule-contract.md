# Module rule contract

Every enabled core module must have a local rule entrypoint, normally `AGENTS.md`. Keep it concise and module-specific. Include these fields:

1. Module name and owner.
2. Module goal and user-visible outcome.
3. In-scope responsibilities.
4. Explicit boundaries and non-goals.
5. Directory and repository locations.
6. Inputs and upstream dependencies.
7. Outputs and downstream consumers.
8. Required Skills, tools, runtime, and permissions.
9. Build or change workflow.
10. Validation commands and evidence locations.
11. Delivery and acceptance standard.
12. Common problems, recovery, and escalation path.

The module rule must point to the project Router and records instead of copying their full content. If Claude Code also needs a module mirror, create `CLAUDE.md` only when that runtime is actually enabled and verify the agreed synchronization policy.
