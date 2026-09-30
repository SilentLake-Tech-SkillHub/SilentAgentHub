---
name: git-environment-promotion
description: Govern Git push and environment promotion at Verify and Final gates. Use after validation when changes must reach test or production, including Vercel deployments.
---

# Git Environment Promotion

## Verify gate

1. Confirm review, change ownership, validation evidence, remote, branch, environment, permission, and rollback policy.
2. Commit only the owned and verified scope, then push the configured test branch/remote.
3. Deploy or promote to the registered test environment and run smoke plus the applicable module/E2E checks.
4. Record commit, remote, branch, deployment identity, evidence, failures, and rollback in `流程管理/GitPromotion.md` through `doc-git-promotion`.

## Final gate

1. Require user acceptance and explicit production authorization.
2. Merge/tag/push according to the registered release policy.
3. Promote the approved artifact to production; run production smoke/E2E/monitoring checks.
4. Update GitPromotion, Release, Environment, Validation, Acceptance, task, risk, and version records.

## Vercel routing

For Vercel projects, use the available Vercel Skills as applicable: `vercel:vercel-cli`, `vercel:deployments-cicd`, `vercel:verification`, and `vercel:observability` or `vercel:vercel-api` when live inspection is required.

## Safety

- A Hook may block closeout for missing evidence but must never auto-commit, auto-push, auto-deploy, or infer production authorization.
- If destination, credentials, permission, rollback, or environment identity is missing, record the blocker and stop before mutation.

