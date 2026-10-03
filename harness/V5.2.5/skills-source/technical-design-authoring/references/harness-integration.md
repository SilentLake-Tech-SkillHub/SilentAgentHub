# Harness integration contract

## Storage and discovery

| Copy | Location | Role |
|---|---|---|
| Maintained source | `skills/【技术方案与评审】technical-design-authoring/` in SilentAgentHub | Edit and review here |
| Versioned package | `harness/V5.2.5/skills-source/technical-design-authoring/` | Installation/recovery source; keep changed manifest entries current |
| Active Codex Skill | `$CODEX_HOME/skills/technical-design-authoring/` (default `~/.codex/skills/`) | Host discovery and runtime use |
| Installed package | packageRoot resolved from `$CODEX_HOME/harness/current.json` | Packaged copy; does not itself replace the active Skill |

The independent website/SKILLS store is outside this update's destination set. Source and package names do not decide project document locations: resolve them through the project's ROUTER and document-controller registry. Do not add personal absolute paths to this distributable Skill.

## Entry and conditions

Root AGENTS/CLAUDE routes technical design/review here. `harness-router` resolves the active requirement, module and review paths. `workflow-orchestrator` selects this capability at the technical-design/review stage; `skill-library-router` selects it when writing implementation choices or a development route. Explicit `$technical-design-authoring` also invokes it; implicit discovery is allowed. These are semantic agent instructions, not a new automatic background Hook or a paid model API.

- Write/revise: read `design-guide.md`; use requirements, amendments and verified system facts. If product approval is pending, label the design candidate and carry unresolved choices to review.
- Review: read `review-guide.md`; check requirement coverage, contracts, costs, delivery and evidence. Label author self-review accurately; record the user's review decision separately.
- Status/path clarification alone: answer from current evidence, without creating a design, review or construction Plan.
- Approved build: `plan-orchestrator` consumes the approved design/review as inputs and controls engineering execution only. A user-selected bounded pre-review Demo follows its existing exception; it does not approve the full product.

## Document ownership and handoff

This Skill owns technical reasoning, not document-controller schemas or lifecycle approvals. Resolve the registered controller for each detailed design/review artifact. `doc-architecture` maintains ARCHITECTURE's summary/link; `doc-api`, `doc-data-model`, `doc-validation` maintain their respective contracts/evidence; `doc-code-review` maintains CodeReview's review record. These controllers do not automatically own every standalone technical-design or technical-review file. Register custom artifacts through the project's existing document registration mechanism before treating them as managed.

Link requirement IDs → design sections/contracts → review findings and user decision → engineering Plan → implementation/acceptance evidence. Return missing coverage to the design; report new product decisions to requirement clarification. Never infer approval from document existence, schema validation, a passed author self-review, or this Skill's invocation.

## Update safety

Before updating the active copies, preserve the exact affected files and read back their hashes. Apply owned deltas, preserve unrelated local rule additions, and update only affected manifest/current-pointer fields. Keep authentication, sessions, Memory and runtime logs out of the public package. Hash equality verifies copy identity; it does not prove future host invocation or product correctness. Roll back affected files from the recorded baseline without resetting repositories or replacing unrelated Skills.
