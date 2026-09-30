---
name: memory-turn-closeout
description: Re-evaluate the current user prompt against task, Plan, issue, validation, and acceptance evidence before every final response, then update project Memory. Use proactively at turn closeout; the Stop Hook is fallback only.
---

# Memory Turn Closeout

1. Before drafting the final response, read the current turn's sanitized SHORT_MEMORY record. Do not wait for Stop to reinject an instruction.
2. Compare every requested outcome with task, Plan, Decision, issue, risk, Validation, and Acceptance evidence.
3. Choose exactly one status: `completed`, `needs_user`, `blocked`, `cancelled`, or `superseded`.
4. Run `.codex/hooks/memory-runtime.ps1 -Event Closeout` with conversation ID, turn ID, status, result, evidence, and next action. The runtime delegates to the transaction-safe closeout and migration scripts.
5. Only `completed`, `cancelled`, `superseded`, or user-approved `closed_unresolved` may move to LONG_MEMORY.
6. Keep `needs_user` and `blocked` in SHORT_MEMORY with a concrete blocker and next action. Refresh the active summary and require `memory-index.json` to match the new state, `short` location, and per-conversation Hash before returning success.
7. For terminal migration, remove the conversation's detailed records, rollup, and active summary from SHORT only after LONG verification succeeds.

## User-visible closeout contract

- Normal path: close out the current turn before submitting the final response; Stop should observe a settled status and pass without a card.
- Fallback path: if Stop finds `received`, `working`, or `verifying`, it may block once with a short internal-processing message. Complete the existing turn immediately; never re-capture the Prompt.
- A Plan approval, status question, or read-only follow-up uses `needs_user` only when the wider active task genuinely awaits user action. Do not manufacture a blocker merely to keep the conversation in SHORT.
- The final response must not claim the system was repaired merely because one turn was proactively closed.

Never infer completion from the prompt alone. Never mark unverified work completed.
