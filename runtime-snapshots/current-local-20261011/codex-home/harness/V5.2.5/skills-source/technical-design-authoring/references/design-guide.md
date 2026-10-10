# Technical design writing

## Establish the input and baseline

Read the current requirements and the amendments that actually changed them. Record their IDs, versions and acceptance status, then identify the relevant code, data and deployed environment with evidence dates. Do not turn an old limitation, candidate label or missing test into a new product requirement.

Explain the product service, the user problem, the proposed outcome and current capability before detailed engineering. Definitions should explain what unfamiliar components do in this project. A reader without the original conversation must understand why the design is needed.

## Trace requirements into implementation

Maintain a coverage table with requirement ID and source, user-visible outcome, implementation location/mechanism, dependency, deliverable, acceptance evidence and current state. Group related requirements when their individual scope remains traceable. Include error, interrupted and historical/reopened states when the requirement applies to them. Distinguish implemented, proposed, verified, accepted and deferred.

For each material capability explain:

- Which component receives the input, how it processes it, what it produces, and who consumes that output.
- The concrete technology choice, its reason in the current architecture, viable alternatives and material tradeoffs. Verify changing external capabilities from primary sources; separate documented support from an actual project test.
- Relevant contracts: fields, types, identifiers, provenance, versioning, state changes and error behavior. State how two components agree, rather than describing two disconnected solutions.
- Data ownership, persistence and lifecycle where relevant, including how updates/deletions affect derived copies and restored backups.
- Implementation route in dependency order, files/modules to change, migration and compatibility behavior, deliverables and tests that demonstrate the requirement. This route belongs to the design and can later inform the execution Plan.

Use diagrams, example payloads, formulas and state transitions when they clarify a mechanism. They supplement the prose; they do not stand in for an explanation. Do not include generic infrastructure, security or AI checklists unrelated to the actual scope.

## Delivery and operational evidence

State how the integrated feature will be delivered and observed, including local/integration tests, real UI evidence where applicable and environment/version identity. Component success alone cannot establish a complete user journey.

For affected deployments or persistent data, explain configuration ownership, reversible migration, rollback conditions and what rollback preserves. For metered services, show the units, assumptions, measured versus estimated costs and the currently authorized test budget. Credentials remain references.

Identify unresolved choices that change product outcome, cost, feasibility or risk, with a recommendation and the exact affected scope. Technical parameter choices that are well supported may be made autonomously within authorization. Do not reopen already accepted product choices.

## Read-through

Read the result against every requirement and the actual system. Check cross-component contracts, development order, delivery artifact and measurable acceptance. Fix gaps in the document itself before sending it for review. Provide a short summary of coverage, important choices, current evidence and remaining decisions; writing the document does not mean the feature is built.
