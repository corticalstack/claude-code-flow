# Flow

A cross-tool agentic-coding workflow toolkit: 11 workflow skills (research → plan → implement → validate → review → ship), an optional cross-vendor code-review skill, and a tracker abstraction (GitHub Issues, Azure DevOps work items, GitLab issues, …) - all behind the [Agent Skills open standard](https://agentskills.io/specification) so the same files work in Claude Code and GitHub Copilot CLI.

## Install

### Claude Code (plugin, recommended)

```
/plugin marketplace add corticalstack/flow
/plugin install flow@flow
/flow:init
```

`/flow:init` is an interactive bootstrap that creates `AGENTS.md` at your project root from Flow's template, creates `.claude/tracker.json` from the example, and optionally sets up cross-vendor review profiles.

### GitHub Copilot CLI

```
gh skill install corticalstack/flow                                  # interactive picker (recommended)
gh skill install corticalstack/flow .claude/skills/create-plan       # one specific skill
```

Then drop in an `AGENTS.md` (see [docs/AGENTS.md.template](docs/AGENTS.md.template)) and configure `.claude/tracker.json` (see [.claude/tracker.example.json](.claude/tracker.example.json)).

## What you get

**Workflow skills (11):**

- `/flow:research-requirements`, `/flow:research-codebase` - structured research phase
- `/flow:create-plan`, `/flow:iterate-plan` - implementation planning
- `/flow:implement-plan`, `/flow:validate-plan` - execution + quality gate
- `/flow:commit` - commit hygiene
- `/flow:describe-pr`, `/flow:handle-pr-feedback` - PR description + review-feedback loop
- `/flow:create-handoff`, `/flow:resume-handoff` - cross-session continuity

**Optional cross-vendor review:**

- `/flow:cross-review` - a configurable OAuth-only review against Azure AI Foundry, GitHub Models, or GitHub Copilot CLI. A model from a different vendor reads the diff vs `main` and surfaces high/critical findings - advisory only, never edits code. See [docs/cross-vendor-review.md](docs/cross-vendor-review.md).

**Tracker abstraction:**

- `bin/tracker` (PATH-wrapper) + `.claude/scripts/tracker.sh` (the adapter)
- `github` backend wired (uses `gh`); `azure-devops` backend stub; `none` for tracker-less projects
- Configurable per-project via `.claude/tracker.json`. See [docs/tracker-portability.md](docs/tracker-portability.md).

**Bootstrap helper:**

- `/flow:init` - creates `AGENTS.md`, `.claude/tracker.json`, and optional `cross-review/profiles.json` from templates.

## Workflow overview

```
/flow:research-requirements
       ↓
/flow:create-plan
       ↓
/flow:implement-plan        ←─── iterate per phase
       ↓
/flow:validate-plan          (quality gate)
       ↓
/flow:cross-review           (optional, advisory)
       ↓
/flow:commit
       ↓
Push  &  PR
       ↓
/flow:describe-pr
       ↓
Review (human or @claude)
       ↓
/flow:handle-pr-feedback     (if changes requested)
       ↓
Merge
```

Each stage drops a durable markdown artifact under `flow/research/`, `flow/plans/`, `flow/prs/`, or `flow/reviews/`, so the next agent (or future you) can pick up cleanly.

## Docs

- [docs/tracker-portability.md](docs/tracker-portability.md) - the tracker adapter contract, neutral state vocabulary, supported backends.
- [docs/cross-vendor-review.md](docs/cross-vendor-review.md) - `/flow:cross-review` setup, backends, caveats.
- [docs/AGENTS.md.template](docs/AGENTS.md.template) - the `AGENTS.md` `/flow:init` ships.

## License

MIT - see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
