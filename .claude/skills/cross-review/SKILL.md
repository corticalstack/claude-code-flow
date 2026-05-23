---
name: cross-review
description: Run an OPTIONAL, advisory cross-vendor code review of the current branch's diff vs main using a configurable second-opinion backend (Azure Foundry next-gen, GitHub Models, or Copilot CLI - all OAuth, all keyless). Explicit-only; run only when invoked via /cross-review or when the user explicitly asks for a cross-vendor review, never autonomously.
argument-hint: [profile-name]
disable-model-invocation: true
allowed-tools: Bash
---

# Cross-vendor review

You are running a cross-vendor code review on the current branch's diff vs `main`, using the reviewer profile the user named (or the default from `profiles.json`). This is a **second opinion** from a model in a different vendor lineage. It is **advisory only**: surface findings, do not apply changes.

## Run the review

!`bash ${CLAUDE_SKILL_DIR}/scripts/review.sh "$1" 2>&1`

## Present the result

The script printed the findings above and saved a markdown copy under `flow/reviews/`. In your reply:

1. **Surface the findings clearly** to the user, with the saved file path so they can re-read it.
2. **Do NOT modify any code** based on what the reviewer said. The reviewer is a second opinion, not an instruction.
3. If the user asks you to act on a specific finding, treat it as a separate task and apply your own judgement; the reviewer may be wrong.

## If the script errored

Common causes (the printed error points at one of these):
- `profiles.json` missing: copy `.claude/skills/cross-review/profiles.example.json` to `profiles.json` and edit endpoints/models.
- Authentication: `az login` (Foundry), `gh auth login` (GitHub Models), `copilot auth login` (Copilot CLI).
- Tool not installed: `az`, `gh`, `copilot`, `jq`, or `curl` missing.
- No diff vs `main`: the branch has no changes to review.

Tell the user the specific error from the script output and the fix; full setup is in [`docs/cross-vendor-review.md`](docs/cross-vendor-review.md).
