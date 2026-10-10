---
name: technical-design-authoring
description: Write or review technical designs from approved requirements and verified system facts, tracing each requirement through implementation, delivery and acceptance. Use for technical方案、选型、开发路线 and technical评审; use execution Plans only after the applicable reviews.
metadata:
  version: "1.0.1"
---

# Technical Design Authoring

Produce an implementable design whose coverage can be reviewed against the actual requirements. Preserve the user's product decisions and distinguish the current system, proposed design, verified behavior and unresolved choices.

## Choose the work

- **Write or revise a technical design:** read [design-guide.md](references/design-guide.md). Inputs are the approved requirements, their later amendments and the current system facts. An engineering Plan can supply historical context; it cannot replace these inputs or determine the design backwards.
- **Write a technical review:** read [review-guide.md](references/review-guide.md). Review the design against the requirements and evidence. A written review conclusion does not authorize implementation or release on the user's behalf.
- A status question or ordinary document clarification does not create a construction Plan. After the applicable requirement and technical reviews pass, use the available engineering planning workflow for the approved build scope.

## Harness integration

When locating this Skill, its callers or document ownership, read [harness-integration.md](references/harness-integration.md). Resolve actual project paths with `harness-router`; use the installed English Skill directory, not a personal source-store path. Automatic discovery remains enabled.

## Shared responsibilities

Locate the project's current requirement entry, later decisions, applicable module rules and the actual candidate code/version. Resolve stale references against those facts. Give each requirement a stable trace to its mechanism, dependencies, delivery artifact and observable acceptance; partial implementations retain their missing parts.

This Skill owns design and review semantics. Use the registered document controllers for architecture, API, data, validation and review ledgers; link the detailed design instead of duplicating it into every file. If a controller or registered path is absent, record the missing ownership and follow the project's registration workflow.

Write enough for another engineer to implement the feature and for the product owner to judge the outcome. Select the depth appropriate to the task: cross-component features need contracts and handoffs; a small change may need only a short implementation explanation. Do not use page counts, headings or completed checkboxes as evidence of adequate design.

Before delivery, compare the complete user outcome with the whole implementation path. For a response containing text, charts and citations, for example, specifying each component separately is insufficient without specifying their ordering, shared data, transport and persistence. Use project-specific examples to expose gaps; do not impose that particular response layout on other products.

Report missing decisions, technical uncertainties and unverified behavior precisely. Complete independent design work while a genuine missing input is pending. Preserve existing authorization, secrets and user changes.
