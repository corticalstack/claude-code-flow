# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

This is a template repository for setting up an advanced Claude Code workflow. See [`README.md`](README.md) for setup instructions.

## Workflow

Follow the **Research → Plan → Implement → Validate** pattern:

1. **Research first**: Understand before changing
   - `/research_requirements` for new projects or features

2. **Plan before coding**: Create implementation plans
   - `/create_plan <GitHub issue URL>`
   - Plans live in [`thoughts/plans/`](thoughts/plans/)

3. **Implement with verification**: Execute plans phase by phase
   - `/implement_plan <plan path>`
   - Pause for manual verification between phases

4. **Validate before committing**: Quality gate to catch issues
   - `/validate_plan <plan path>`
   - Ensures tests pass and implementation matches plan
   - Prevents broken code from entering version control

## Development Conventions

<!-- Add your project-specific conventions here -->
<!-- Examples:
- Package manager: npm, uv, cargo, go mod, etc.
- Code style: formatters, linters
- Testing approach: TDD, integration tests, etc.
- Branch naming: feature/, bugfix/, etc.
-->

## Documentation Conventions

When writing or editing documentation:

- **Always use navigable links** for file references: `[filename](path/to/file)` not just backticks
- **Link to sections** when referencing commands: `[/command](#command)` not just backticks
- **Include line numbers** when referencing code: `path/to/file.ts:42`
- **Keep CLAUDE.md lean**: ~150-200 instructions max for consistent following

## GitHub Issue Conventions

When creating or editing GitHub issues:

- **Use navigable links** for file references, not just code-highlighted text:
  - ✅ Good: `[prompts.yaml](src/prompts.yaml)` - clickable link
  - ❌ Bad: `` `prompts.yaml` `` - just highlighted, not navigable
- **Link formats**:
  - Relative path: `[config.py](src/backend/config.py)`
  - With line numbers: `[config.py:50](src/backend/config.py#L50)`
  - With line range: `[config.py:50-75](src/backend/config.py#L50-L75)`
- **Benefits**: Makes issues more actionable by allowing direct navigation to referenced code

## GitHub Issue Label Lifecycle

Workflow commands automatically update issue labels to track progress:

**Label progression:**
```
New Issue
  ↓ /research_requirements or /research_codebase
[research-in-progress] → [research-complete]
  ↓ /create_plan
[planning-in-progress] → [ready-for-dev]
  ↓ /implement_plan
[in-progress]
  ↓ /validate_plan (on failure) OR /describe_pr (on success)
[validation-failed] OR [pr-submitted]
```

**Label meanings:**
- `research-in-progress` - Research actively underway
- `research-complete` - Research done, ready for planning
- `planning-in-progress` - Implementation plan being created
- `ready-for-dev` - Has approved plan, ready to implement
- `in-progress` - Development actively underway
- `validation-failed` - Implementation failed validation checks
- `implementation-failed` - Implementation could not be completed
- `pr-submitted` - PR created, awaiting review

**Important:** Labels update automatically when using workflow commands with GitHub issue URLs/numbers

## Reference Documents

- [`docs/claude-code-workflow-concepts.md`](docs/claude-code-workflow-concepts.md) - Workflow methodology and principles

## Lessons Learned

<!-- Add lessons here as the project develops -->
<!-- Example: "Don't use X approach because Y" -->

## Build & Test Commands

```bash
# No build/test commands yet - this is a template repository
```
