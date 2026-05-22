# CLAUDE.md

@AGENTS.md

Claude-Code-specific guidance. The shared, tool-agnostic project rules live in [AGENTS.md](AGENTS.md), imported above and expanded into context automatically at session start.

## Workflow commands

Each workflow stage in [AGENTS.md](AGENTS.md) is invoked through a slash command defined in [.claude/commands/](.claude/commands/). These commands create the `flow/` artifacts and, when given a GitHub issue URL or number, update the issue labels automatically.

| Stage | Command | Artifact |
|---|---|---|
| Research (requirements) | [`/research_requirements`](.claude/commands/research_requirements.md) | `flow/research/` |
| Research (codebase) | [`/research_codebase`](.claude/commands/research_codebase.md) | `flow/research/` |
| Plan | [`/create_plan <issue URL>`](.claude/commands/create_plan.md) | `flow/plans/` |
| Implement | [`/implement_plan <plan path>`](.claude/commands/implement_plan.md) | code, tests |
| Validate | [`/validate_plan <plan path>`](.claude/commands/validate_plan.md) | quality gate |
| PR description | [`/describe_pr`](.claude/commands/describe_pr.md) | `flow/prs/` |
| PR feedback | [`/handle_pr_feedback`](.claude/commands/handle_pr_feedback.md) | code, plan updates |

See [.claude/commands/](.claude/commands/) for the full set (including `/commit`, `/iterate_plan`, `/create_handoff`, and `/resume_handoff`). Run commands on a feature branch and pause for manual verification between implementation phases.

## Lessons learned

<!-- Add Claude-Code-specific lessons here as the project develops. -->
