# CLAUDE.md

@AGENTS.md

Claude-Code-specific guidance. The shared, tool-agnostic project rules live in [AGENTS.md](AGENTS.md), imported above and expanded into context automatically at session start.

## Workflow skills

Each workflow stage in [AGENTS.md](AGENTS.md) is an explicit-invocation skill in [.claude/skills/](.claude/skills/) (the Agent Skills open standard, so the same files are also picked up by Copilot CLI and other compatible tools). Invoking one creates the `flow/` artifacts and, when given a GitHub issue URL or number, updates the issue labels automatically. Each sets `disable-model-invocation: true`, so it runs only when you invoke it explicitly, never autonomously.

| Stage | Command | Artifact |
|---|---|---|
| Research (requirements) | [`/research-requirements`](.claude/skills/research-requirements/SKILL.md) | `flow/research/` |
| Research (codebase) | [`/research-codebase`](.claude/skills/research-codebase/SKILL.md) | `flow/research/` |
| Plan | [`/create-plan <issue URL>`](.claude/skills/create-plan/SKILL.md) | `flow/plans/` |
| Implement | [`/implement-plan <plan path>`](.claude/skills/implement-plan/SKILL.md) | code, tests |
| Validate | [`/validate-plan <plan path>`](.claude/skills/validate-plan/SKILL.md) | quality gate |
| PR description | [`/describe-pr`](.claude/skills/describe-pr/SKILL.md) | `flow/prs/` |
| PR feedback | [`/handle-pr-feedback`](.claude/skills/handle-pr-feedback/SKILL.md) | code, plan updates |

See [.claude/skills/](.claude/skills/) for the full set (including `/commit`, `/iterate-plan`, `/create-handoff`, and `/resume-handoff`). Run these on a feature branch and pause for manual verification between implementation phases.

## Lessons learned

<!-- Add Claude-Code-specific lessons here as the project develops. -->
