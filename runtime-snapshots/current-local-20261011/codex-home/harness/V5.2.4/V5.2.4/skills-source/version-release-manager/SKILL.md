---
name: version-release-manager
description: Assign version changes, maintain candidate and production identities, archive major versions, and record release or rollback evidence. Use for staged delivery, rule updates, bug fixes, feature releases, architecture changes, production promotion, or rollback.
---

# Version Release Manager

1. Determine the current candidate, current production, prior candidate, rollback baseline, and user-acceptance state from the version index and Git evidence.
2. Apply semantic intent: patch for fixes and non-structural detail; minor for compatible capability or rule growth; major for architecture, directory, state-machine, or initialization-system changes.
3. Update version record with date, type, changes, impact, validation, linked issues, Plan, and approval.
4. A `【新版】Vx.y.z` is only a candidate until the user explicitly accepts or promotes it. Preserve the prior production and label superseded candidates clearly.
5. For every major version, create an additional complete visible archive named `xxx_X.0.0`. Verify it represents the full code state and remains independently reviewable.
6. Major archives supplement rather than replace Git commits, tags, hashes, or version records.
7. Before promotion, verify acceptance, migration, backup, deployment authorization, monitoring, and rollback. After rollback, record cause, target identity, data effect, and validation.
