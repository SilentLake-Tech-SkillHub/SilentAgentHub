---
name: google-drive-sync-snapshot
description: Push or pull project snapshots between local disk and Google Drive or another handoff target for backups, restores, handoff packages, and continuation on another machine. Use when the user asks for Google Drive snapshot push, pull, sync, backup, restore, copy, or handoff work; perform version checks, file-diff checks, sensitive-file confirmation, and incremental updates before copying.
---

# Google Drive Sync Snapshot

## Core rules

- Determine direction first: push local to Google Drive, or pull Google Drive to local.
- Confirm both real paths on disk. If either path looks stale, verify the mounted-volume or CloudStorage path before comparing.
- Do not overwrite a newer version or newer files without explicit user confirmation.
- Do not perform the final copy until sensitive-file handling is explicit.
- Use incremental sync with a dry-run first; do not blindly recopy the whole project.
- Treat deletion as a separate destructive action. Use final `--delete` only after explicit confirmation.
- Record direction, versions, diff result, sensitive-file decision, included/excluded scope, and verification in `快照说明.md` or the project ledger.

# Inputs / context to gather

1. Determine sync direction:
   - Push: local project -> Google Drive snapshot
   - Pull: Google Drive snapshot -> local project
2. Determine snapshot intent:
   - Safe archive / review copy
   - Full continuation / restorable environment
3. Identify source path, target path, and naming convention.
4. Check for sensitive and runtime materials:
   - `.env`, `.env.*` except `.env.example`, `.secrets/`
   - API keys, tokens, cookies, credentials, private keys, certs
   - `.git/` and other VCS metadata that may contain history or remotes
   - DB dumps or required DB export paths
   - `node_modules`, virtualenvs, local caches, generated runtime state
   - external assets used by the project but stored outside the repo
5. Check required governance files or ledgers in the repo.

# Preflight comparison

Run these checks before push or pull:

1. Version check:
   - Prefer the latest version in `版本控制.md` or `CHANGELOG.md` if present.
   - Otherwise check `package.json`, `pyproject.toml`, `VERSION`, `快照说明.md`, Git tag, or another project-specific version source.
   - Compare semantic versions when possible. If the version is missing or ambiguous, mark it as `unknown` and rely on file evidence.
2. File update check:
   - Run an incremental dry-run from source to target with itemized output.
   - Compare file counts and total size for the intended include/exclude scope.
   - Spot-check critical files by mtime and checksum when they drive recovery, config, or source correctness.
3. Conflict classification:
   - Push risk: local version is lower than Google Drive, or local files are older than Google Drive files that would be overwritten.
   - Pull risk: Google Drive version is lower than local, or Google Drive files are older than local files that would be overwritten.
   - Divergence risk: both sides contain changed files and neither side is clearly authoritative.
   - Delete risk: the dry-run would remove files from the target.

If any risk exists, pause before final sync and ask the user to confirm whether to proceed, choose the other direction, or create a separate conflict snapshot.

# Procedure

1. Read the project rules and current version/task records before copying anything.
2. Infer or confirm the snapshot mode:
   - If the user says "在另一个机器上继续工作", treat the target mode as full continuation.
   - If the user asks for a safer archive or review package, treat it as safe archive mode.
3. Inventory the source before syncing:
   - project-root contents
   - runtime deps
   - sensitive files and credentials
   - DB/env materials
   - external but actually used assets
4. Run version and file update checks in the requested direction.
5. Ask the user to confirm sensitive-file handling before the final copy unless the current request already gives explicit consent:
   - Include source path, target path, direction, and snapshot mode in the question.
   - List the sensitive categories found or expected.
   - Offer two clear choices: include sensitive/runtime/VCS files, or exclude them.
   - If the user does not answer, stop before syncing and report `需用户确认`.
6. Ask for confirmation if the source is older, lower-version, divergent, or would delete target files.
7. Create the destination folder using the user’s naming pattern when given.
8. If helpful, split the output into:
   - project root copy
   - `_外部相关内容/`
9. Copy incrementally with a method that preserves structure and metadata.
   - If the user confirms inclusion, include sensitive/runtime/VCS files and add a sensitive-content warning to `快照说明.md`.
   - If the user confirms exclusion, explicitly exclude sensitive/runtime/VCS files and record the exact exclusions.
   - If delete behavior is confirmed, use authoritative mirror mode.
   - If delete behavior is not confirmed, use additive/update mode.
10. Write `快照说明.md` with:
   - source path
   - target path
   - direction: push or pull
   - snapshot time
   - source version and target version before sync
   - snapshot mode
   - sensitive-file decision and confirmation source
   - conflict or downgrade confirmations
   - included scope
   - excluded scope
   - recovery notes
11. Update the project ledgers that travel with the snapshot when the project has them:
   - `任务管理`
   - `验收清单`
   - `问题流水`
   - `版本控制`
12. Verify file presence, counts, and a few critical artifacts.

# Direction rules

## Push: local -> Google Drive

Use push when the local project is the intended source of truth.

Before pushing:

- Compare local version against Google Drive version.
- Compare local files against Google Drive files with a dry-run.
- If local version is lower than Google Drive, ask before pushing.
- If local files are older than Google Drive files that would be overwritten, ask before pushing.
- If Google Drive has files that would be deleted, ask separately before using `--delete`.

## Pull: Google Drive -> local

Use pull when the Google Drive snapshot is the intended source of truth.

Before pulling:

- Compare Google Drive version against local version.
- Compare Google Drive files against local files with a dry-run.
- If Google Drive version is lower than local, ask before pulling.
- If Google Drive files are older than local files that would be overwritten, ask before pulling.
- If local has files that would be deleted, ask separately before using `--delete`.
- Prefer pulling into a new recovery directory when local has active uncommitted work or unclear conflicts.

# Efficiency plan

1. Decide direction, snapshot mode, and sensitive-file policy before final copy.
2. Reuse one inventory pass for version comparison, dry-run analysis, and `快照说明.md`.
3. Use rsync dry-run output to choose between additive/update mode and authoritative mirror mode.
4. Search for external assets only after confirming the snapshot is for continuation, not safe archive.
5. Verify with file counts and critical-file presence before doing heavyweight spot checks.
6. Stop once:
   - destination exists
   - critical runtime materials match the intended mode
   - ledgers are updated
   - `快照说明.md` is present

# Sensitive-file confirmation

Use a concise confirmation question before final push or pull:

```text
这次 Google Drive 快照同步是否包含敏感/运行状态文件？方向：<push|pull>，源：<source>，目标：<target>。可能涉及：.env/.env.*、.secrets、密钥/证书、token/cookie、.git、数据库导出、node_modules/venv、本地运行状态。请确认：包含，或排除。
```

If the user says to include "所有内容", "包括 key", "完整恢复", or equivalent, treat that as explicit inclusion consent only when it is in the current task context. Otherwise ask.

If the user says to exclude, use explicit exclude patterns such as:

```bash
--include='.env.example' --exclude='.env' --exclude='.env.*' \
--exclude='.secrets/' --exclude='.git/' \
--exclude='*.pem' --exclude='*.p8' --exclude='id_*'
```

Adjust patterns to the project after inventory; avoid excluding required non-sensitive examples or templates.

# Incremental sync patterns

Always run a dry-run first:

```bash
rsync -aE --dry-run --itemize-changes SOURCE/ TARGET/
```

Use additive/update mode unless deletion is explicitly confirmed:

```bash
rsync -aE --itemize-changes SOURCE/ TARGET/
```

Use authoritative mirror mode only after delete confirmation:

```bash
rsync -aE --delete --itemize-changes SOURCE/ TARGET/
```

After syncing, rerun a dry-run in the same mode. It should be clean or show only intentional target-only files that were not part of the chosen mode.

# Pitfalls and fixes

- Symptom: first snapshot is rejected as incomplete.
  - Likely cause: safe defaults excluded secrets/deps, but the task was actually continuation.
  - Fix: ask for sensitive-file inclusion confirmation, then include runtime materials and out-of-repo assets if the user confirms.

- Symptom: DB export over SSH fails mid-copy.
  - Likely cause: unstable long-lived SSH session.
  - Fix: use locally generated current dumps or already-present server backup artifacts.

- Symptom: the snapshot has files but no context.
  - Likely cause: ledgers were not updated.
  - Fix: sync task, acceptance, issue, and version records before finishing.

- Symptom: cloud-safe snapshot accidentally uploads secrets.
  - Likely cause: sensitive-file confirmation was skipped.
  - Fix: require an explicit include/exclude answer before the final sync.

- Symptom: push overwrites a newer Google Drive snapshot.
  - Likely cause: version and file mtime comparison was skipped.
  - Fix: compare local vs Google Drive before pushing and ask when local is lower-version or older.

- Symptom: pull downgrades an active local workspace.
  - Likely cause: Google Drive was assumed authoritative without checking local changes.
  - Fix: compare Google Drive vs local before pulling and use a new recovery directory when conflicts are unclear.

- Symptom: incremental sync deletes files unexpectedly.
  - Likely cause: `--delete` was used without treating deletion as a separate decision.
  - Fix: run dry-run first and require explicit delete confirmation.

# Verification checklist

- Real source root was confirmed, not assumed from stale path context.
- Direction is explicit: push or pull.
- Snapshot mode is explicit: safe archive or full continuation.
- Source and target versions were compared or marked `unknown`.
- File update dry-run was reviewed before final sync.
- Older/lower-version source was confirmed by the user before overwriting a newer target.
- Sensitive-file decision was explicit before syncing.
- Delete behavior was explicitly confirmed before using `--delete`.
- Destination folder name matches the user’s requested pattern when provided.
- `快照说明.md` exists and describes included/excluded scope.
- Critical files/directories expected for the chosen mode are present.
- Excluded sensitive files are absent in safe archive mode.
- File counts or copy statistics were recorded.
- Project ledgers were updated alongside the snapshot.
