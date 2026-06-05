---
name: init
description: Bootstrap a new project with the Flow workflow - creates AGENTS.md from the template, creates .claude/tracker.json from the example, and optionally sets up cross-vendor review profiles. Run once per project after installing the Flow plugin. Explicit-only; do not auto-fire.
disable-model-invocation: true
allowed-tools: Bash, Read, Write
---

# Flow init

You are bootstrapping the **current user project** (the directory at `${CLAUDE_PROJECT_DIR}`) with Flow's workflow conventions and config templates. Read templates from the plugin install at `${CLAUDE_PLUGIN_ROOT}`. Treat this as an **interactive setup wizard**: ask before each write, never overwrite an existing file.

## Steps

### 1. AGENTS.md

Check if `${CLAUDE_PROJECT_DIR}/AGENTS.md` exists.

- **If it does NOT exist:**
  - Read `${CLAUDE_PLUGIN_ROOT}/docs/AGENTS.md.template`.
  - Ask the user: *"I'll create AGENTS.md at your project root from Flow's template. It has a `[Replace this section ...]` placeholder for the project overview - I can fill it in if you give me a one-paragraph description of this project, or leave the placeholder for you to edit later. What would you like?"*
  - Resolve the placeholder if the user gives a description, then write the content to `${CLAUDE_PROJECT_DIR}/AGENTS.md`.

- **If it DOES exist:**
  - Read it. Tell the user: *"AGENTS.md already exists. Flow expects (1) the feature-branch requirement, (2) the research / plan / implement / validate stages with `flow/` artifacts, (3) the workflow-state vocabulary, (4) a pointer to the tracker adapter. The template is at `${CLAUDE_PLUGIN_ROOT}/docs/AGENTS.md.template` - compare and merge anything missing."*
  - Do NOT overwrite.

### 2. Tracker config

Check if `${CLAUDE_PROJECT_DIR}/.claude/tracker.json` exists.

- **If it does NOT exist:**
  - Ask the user: *"Which issue tracker does this project use? `github`, `azure-devops`, or `none`? I'll create `.claude/tracker.json` from the Flow example with your choice as the active backend."*
  - Read `${CLAUDE_PLUGIN_ROOT}/.claude/tracker.example.json`.
  - Build the project's `.claude/tracker.json` with `"tracker": "<user-choice>"` and the corresponding backend block populated as much as you can from the example (keep the other backend blocks as inert reference - the adapter only reads the active one).
  - Create the `${CLAUDE_PROJECT_DIR}/.claude/` directory if it does not exist, then write the file.
  - Then per backend:
    - `github`: tell the user to confirm `gh auth login` is done.
    - `azure-devops`: warn that the backend is currently a stub (PR 2 pending) - tag / state-transition writes will not yet happen.
    - `none`: tell the user nothing more is needed; mutating tracker calls become no-ops, queries return empty JSON.

- **If it DOES exist:**
  - Tell the user: *".claude/tracker.json already exists; leaving it alone. If you want to change backend, edit it directly - see `${CLAUDE_PLUGIN_ROOT}/.claude/tracker.example.json` for the schema."*

### 3. Cross-vendor review (optional)

Ask: *"Want to set up cross-vendor review now? It's optional - you can do it later. (yes / no)"*

- If **yes**:
  - Check if `${CLAUDE_PROJECT_DIR}/.claude/skills/cross-review/profiles.json` exists.
  - If not, read `${CLAUDE_PLUGIN_ROOT}/.claude/skills/cross-review/profiles.example.json` and write a copy to `${CLAUDE_PROJECT_DIR}/.claude/skills/cross-review/profiles.json` (creating the directory if needed).
  - Tell the user to edit the file with their Foundry endpoint + deployment, GitHub Models model id, or Copilot CLI model, then run `az login`, `gh auth login`, or `copilot auth login` as needed.

### 4. Summary

Print a short summary of what was created and any pending user actions. End with:

> Try `/flow:research-requirements <issue-url-or-description>` to kick off the workflow.

## Out of scope

This skill does not:
- Commit anything (no `git add` / `git commit`).
- Run authentication flows (`gh auth login`, `az login`, `copilot auth login`) - the user does those.
- Install prerequisites (`jq`, `curl`, `gh`, `az`, `copilot`) - the user installs them.
- Overwrite existing `AGENTS.md` or `tracker.json` files.

## Errors

- If the project is not a git repo, the workflow skills assume git is in use. Suggest `git init` if applicable, but do not run it automatically.
- If a write fails (permissions, etc.), print the exact error and stop.
