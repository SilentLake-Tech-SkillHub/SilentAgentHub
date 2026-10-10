# Technical review writing

## Inputs and scope

Identify the exact design version, requirement versions/amendments, candidate code or deployment identity and evidence inspected. Read the linked contract details needed for the review. State whether this is an author self-review or an independent review; do not imply another reviewer or model was used.

## Review the user outcome

Reconcile every requirement with the coverage table and implementation route. Inspect the mechanisms and component handoffs, not just the presence of sections. Evaluate feasibility, technology choices, data semantics, interfaces, resource/cost implications and acceptance/rollback paths within the actual scope.

Trace at least the core user journey through input, processing, output and later reopening when relevant. Include one meaningful boundary or failure case for fragile contracts. A mixed text/chart answer should, for example, remain complete in streaming and history states; a deletion design must not restore deleted content from backup. Choose cases appropriate to the project.

## Findings and conclusion

For each finding record the affected requirement and design location, evidence, user/business consequence, correction or choice, owner, and the check that will resolve it. Separate:

- a design defect that prevents implementation;
- an engineering task already adequately specified but not built;
- a missing product decision;
- a verification gap in a claim of current functionality.

An unbuilt feature is not automatically a failed design review. A proposed mechanism is not proof that it works. Quantify scope when possible and avoid vague statements that everything is ready or everything needs discussion.

Use a clear conclusion: ready for the stated implementation scope, conditional on named decisions/corrections, or blocked by identified design defects. Explain which scopes may proceed and which may not. Record the product owner's approval separately according to the existing project workflow. Do not approve an engineering Plan or production release in the review document.

After changes, review the revised version and retain the disposition of prior findings. Link the review ledger and validation evidence through the registered document controllers.
