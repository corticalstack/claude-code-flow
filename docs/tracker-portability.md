# Tracker portability

The workflow skills (`/research-requirements`, `/create-plan`, `/implement-plan`, `/validate-plan`, `/describe-pr`, `/handle-pr-feedback`, etc.) are designed to drive a project from "issue / work item" through "merged PR / merge request", updating tracker state at each stage. Different teams use different trackers (GitHub Issues, Azure DevOps work items, GitLab issues, Jira, or nothing at all), so the skills do not call any tracker's CLI directly. They call `tracker` - a thin wrapper the plugin puts on the Bash tool's PATH - which dispatches through the adapter at [.claude/scripts/tracker.sh](../.claude/scripts/tracker.sh) to whichever backend you've configured.

This file explains the contract, the supported backends, the neutral workflow-state vocabulary, and how to configure a project.

## The contract

The adapter exposes a small set of subcommands - the contract every backend must satisfy. Skills call them as `tracker <subcommand> <args>` - the plugin adds `bin/tracker` (a thin wrapper around the adapter) to the Bash tool's PATH.

### Issue / work-item subcommands

| Subcommand | Purpose |
|---|---|
| `view <id> [--json fields]` | Fetch a work item as JSON. Default fields cover title, body, state, comments. |
| `set-state <id> <new> [<old>]` | Transition the work item to a new neutral state (see vocabulary below); optionally remove a previous state. |
| `comment <id> <text>` | Post a comment on the work item. |

### PR / merge-request subcommands

| Subcommand | Purpose |
|---|---|
| `pr-current [--json fields]` | Fetch the PR for the current branch. |
| `pr-view <id> [--json fields]` | Fetch a PR by id. |
| `pr-diff <id>` | Print the PR diff. |
| `pr-edit-body <id> <body-file>` | Replace the PR description from a file. |
| `pr-comment <id> <text>` | Post a comment on the PR. |
| `pr-list-open` | List recent open PRs (JSON). |
| `pr-reviews <id>` | Fetch reviews on a PR. |
| `pr-review-comments <id>` | Fetch inline review comments. |
| `pr-decision <id>` | Fetch the PR review decision (APPROVED / CHANGES_REQUESTED / etc.). |
| `pr-closing-issues <id>` | List the work-item ids this PR will close. |

### Utility

| Subcommand | Purpose |
|---|---|
| `repo-info` | Owner + repo name (or backend equivalent) as JSON. |
| `backend` | Print the active backend name. |

## Neutral workflow-state vocabulary

States are the same strings every tracker sees. Backends translate them to native concepts.

| Neutral state | Meaning |
|---|---|
| `research-in-progress` | Research is underway. |
| `research-complete` | Research is done; ready for planning. |
| `planning-in-progress` | A plan is being authored. |
| `ready-for-dev` | Plan approved; ready to implement. |
| `in-progress` | Development is underway. |
| `validation-failed` | Implementation failed the validation gate. |
| `implementation-failed` | Implementation could not be completed. |
| `pr-submitted` | PR is open and awaiting review. |
| `pr-merged` | PR is merged; work is done. |

## Supported backends

### `github` (default; fully wired)

Uses the `gh` CLI's default repo context. States become GitHub **labels** with the same names. Run `gh auth login` and (if needed) `gh repo set-default`.

Example mapping (1:1):

```
neutral set-state <id> research-in-progress  ->  gh issue edit <id> --add-label "research-in-progress"
neutral set-state <id> research-complete research-in-progress  ->  gh issue edit <id> --add-label "research-complete" --remove-label "research-in-progress"
```

### `azure-devops` (wired)

States become Azure DevOps **Tags** (free-form, kept as-is - one tag per neutral-state name). Optionally, the config maps specific neutral states to typed **System.State** transitions (`New` -> `Active` -> `Resolved` -> `Closed`); see the `state_transitions` block in [.claude/tracker.example.json](../.claude/tracker.example.json). When a mapping exists, `set-state` updates both the Tag set and System.State in a single `az boards work-item update` call.

Setup:

```bash
az login                                                                  # Entra ID OAuth
az extension add --name azure-devops                                      # required extension
az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>
```

Implementation notes:

- `set-state` reads the current `System.Tags` string (semicolon-space separated, per the REST API 7.1 contract), removes the optional `<old-state>` tag if present, appends `<new-state>` (deduped), and writes the full replacement string back. The API replaces, not appends, so the helper round-trips the string.
- `pr-comment` and `pr-review-comments` route through `az devops invoke` against the REST API 7.1 `pullRequestThreads` resource - the CLI has no dedicated subcommand for either.
- `pr-decision` derives the equivalent of GitHub's `reviewDecision` from reviewer-vote integers (10 = approved, -10 = rejected, ...); returns `APPROVED` / `CHANGES_REQUESTED` / `REVIEW_REQUIRED` in a JSON envelope shaped like the GitHub one.
- `pr-diff` is git-side (`git diff origin/<target>...origin/<source>`) because `az repos pr diff` does not exist.
- `repo-info` returns `{owner, project, name}` (with `owner` parsed from the repo's `remoteUrl`) - note the extra `project` field vs the GitHub shape.

### `none` (tracker-less projects)

Skills work without a tracker. Mutating calls are no-ops (logged); query calls return empty JSON. Suitable for greenfield work or local-only projects.

## Configuration

1. Copy the template:

   ```bash
   cp .claude/tracker.example.json .claude/tracker.json
   ```

   `.claude/tracker.json` is gitignored so each contributor can pick their own backend.

2. Edit `.claude/tracker.json`: set `"tracker"` to one of `"github"`, `"azure-devops"`, or `"none"`, and fill in the backend-specific block. Authenticate the corresponding CLI (`gh` / `az`) if needed.

3. Override per-invocation via env var if you want a one-off:

   ```bash
   TRACKER_BACKEND=none tracker view 1
   ```

## What is NOT in scope here

A few GitHub-specific behaviors deliberately remain in the skills as GitHub examples (with a note), because they have no neat tracker-neutral analog yet:

- The `@claude` PR-review handshake in `/handle-pr-feedback` (driven by the Claude Code GitHub Action) - GitHub Actions only.
- GitHub permalink generation in `/research-codebase` for inline file links - the URL shape is GitHub-specific.

A future PR can lift these into the adapter (or document non-GitHub equivalents) once the backends settle.
