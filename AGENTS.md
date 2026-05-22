# AGENTS.md

Project instructions for any AI coding agent (Claude Code, OpenAI Codex, GitHub Copilot CLI, Cursor, Gemini CLI, and other AGENTS.md-compatible tools). This file holds the tool-agnostic rules. Tool-specific notes live in that tool's own file; for Claude Code that is [CLAUDE.md](CLAUDE.md), which imports this file.

## Project overview

A template repository for an advanced, staged agentic-coding workflow: research, then plan, then implement, then validate, resetting context between stages. See [README.md](README.md) and [docs/claude-code-workflow-concepts.md](docs/claude-code-workflow-concepts.md).

## Critical: feature-branch requirement

**Never make changes directly on the `main` branch. No exceptions.**

- Create a feature branch before generating or modifying ANY file: code, tests, docs, or workflow artifacts under `flow/`.
- Every change reaches `main` through a pull request, never a direct commit.
- Before starting any step that writes files (research, planning, implementation, validation):
  1. Check the current branch: `git branch --show-current`
  2. If on `main`, create a feature branch immediately: `git checkout -b feature/<name>`
  3. Only proceed once on a feature branch.
- If you find yourself on `main` with changes, stop, create a feature branch, and move the changes there before continuing.

Why: `main` must stay stable and deployable, every change needs review, and accidental `main` commits disrupt the workflow.

## Branch naming

- Features: `feature/<issue-number>-<brief-description>`
- Bug fixes: `bugfix/<issue-number>-<brief-description>`
- Always branch from `main`; never commit to `main` directly.

## Workflow: research, plan, implement, validate

Stage the work and reset context between stages. Each stage leaves a durable artifact under `flow/`:

1. **Research**: understand before changing. Output a markdown file in [flow/research/](flow/research/).
2. **Plan**: write an implementation plan before coding. Output a markdown file in [flow/plans/](flow/plans/).
3. **Implement**: execute the plan in phases, pausing for verification between phases.
4. **Validate**: a quality gate before committing. Run the existing test suite, confirm the implementation matches the plan, and catch issues before they reach version control.

Pause for human review at the research and plan boundaries; those are the highest-leverage review points.

## Project conventions

Fill in as the project gains them (package manager, formatters and linters, testing approach). Keep entries specific and load-bearing.

## Documentation conventions

- Use navigable links for file references: `[filename](path/to/file)`, not bare backticks.
- Reference code with line numbers: `path/to/file.ts:42`; use `#L50-L75` for ranges in links.
- Keep instruction files (this file and CLAUDE.md) lean and hand-written, roughly 150 to 200 lines maximum. Generic or auto-generated guidance measurably reduces task success, so write only specific, load-bearing rules.

## GitHub issue conventions

- Use navigable links for file references in issues, not just code-highlighted text.
  - Good: `[config.py](src/backend/config.py)` (clickable)
  - Avoid: `` `config.py` `` (highlighted but not navigable)
- Link formats: relative `[config.py](src/backend/config.py)`; with line `[config.py:50](src/backend/config.py#L50)`; with range `[config.py:50-75](src/backend/config.py#L50-L75)`.

## GitHub issue label lifecycle

Each workflow step updates issue labels to track progress:

```
New issue
  ↓ research step
research-in-progress → research-complete
  ↓ planning step
planning-in-progress → ready-for-dev
  ↓ implementation step
in-progress
  ↓ validation (on failure) OR PR creation (on success)
validation-failed OR pr-submitted
```

Label meanings:
- `research-in-progress`: research underway
- `research-complete`: research done, ready for planning
- `planning-in-progress`: plan being created
- `ready-for-dev`: has an approved plan, ready to implement
- `in-progress`: development underway
- `validation-failed`: implementation failed validation
- `implementation-failed`: implementation could not be completed
- `pr-submitted`: PR created, awaiting review

## Build and test commands

```bash
# No build/test commands yet - this is a template repository.
```
