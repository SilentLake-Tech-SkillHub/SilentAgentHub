# Document Controller Registry

## Model

Every governed Markdown artifact has exactly one atomic `doc-*` controller registered in `.codex/harness/document-controllers.json`.

- A semantic Skill performs the business work.
- The atomic controller creates, appends, links, and validates one Markdown artifact.
- The Markdown file preserves human-readable governance evidence.
- Hooks, JSON Schema, and deterministic scripts validate the registry, required fields, and lifecycle gates.

## Human ledger contract

Every governed document records, at minimum:

- timestamp;
- triggering user request or event;
- called Skills/plugins and why;
- current state;
- related requirement, task, Decision, Plan, issue, version, or release IDs;
- result;
- next action.

Raw Hook/Skill events remain append-only in `.codex/harness/runtime-events.jsonl`. Human Markdown summarizes only the calls needed to explain that artifact's lifecycle.

## Initialization selection

1. Load the registry and validate one controller per path.
2. Always initialize root Memory files, Router, core flow ledgers, and the cold history index.
3. Add product, research, engineering, deployment, data, API, or knowledge artifacts only when the project goal or enabled module requires them.
4. Invoke each selected `doc-*` Skill using its own `assets/template.md`.
5. Register the resulting path in `ROUTER.md` through `doc-router`.
6. Run `.codex/hooks/document-controller-integrity.ps1`.

Every controller declares `documentType`, `readPolicy`, and `archivePolicy`. Activity ledgers use `active`; history and LONG_MEMORY use `cold`. A configured status field and terminal states are required before automatic archival may be enabled.

`clarification.md` is required as the requirement-intake lifecycle ledger. `requirement-clarification` performs the reasoning; `doc-clarification` preserves the time, user request, Skill calls, state, routes, result, and next step.

Do not create a Markdown state-machine definition. Lifecycle rules live in `.codex/harness/lifecycle-state-machine.json` and are checked by the corresponding script.
