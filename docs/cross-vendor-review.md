# Cross-vendor review (optional, advisory)

Run a code review on the current branch's diff vs `main` using a model from a **different vendor lineage** than the author. Optional, opt-in, advisory only: it never blocks merge and never edits code.

## Why

Same-vendor reviewers share blind spots ([correlated errors](https://arxiv.org/html/2506.07962v1)). A model in a different lineage catches different classes of issue. Use this on changes where a missed bug would be expensive.

## When (and when not)

- **Use it** on security-critical or architectural changes, before opening or updating a PR.
- **Don't use it** on every save; it doubles to triples the per-PR model cost.
- The severity filter is **HIGH and CRITICAL only** by design - cross-vendor LLM review surfaces real bugs better than nitpicks, and same-lineage models already cover style/quality well.

## One-time setup

1. **Tools.** All backends need `jq` and `curl`. Then per backend, install the CLI you intend to use:
   - Azure Foundry: [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
   - GitHub Models: [GitHub CLI](https://cli.github.com/)
   - Copilot CLI: [GitHub Copilot CLI](https://docs.github.com/copilot/concepts/agents/about-copilot-cli)

2. **Authenticate (OAuth, no static keys go in the repo).**
   - `az login` - Entra ID for Foundry.
   - `gh auth login` - GitHub token for GitHub Models.
   - `copilot auth login` - Copilot subscription for Copilot CLI.

3. **Create your profiles file.**
   ```bash
   cp .claude/skills/cross-review/profiles.example.json \
      .claude/skills/cross-review/profiles.json
   ```
   Then edit `profiles.json` and fill in your Foundry endpoint(s) and deployment / model names. The file is gitignored.

## Usage

```text
/cross-review                    # uses the default profile from profiles.json
/cross-review github-o3-mini     # picks a specific profile by name
```

Or, to narrow the review to less than the full branch:
```bash
CROSS_REVIEW_BASE=HEAD~3 /cross-review foundry-gpt4o
```

The skill prints findings inline and saves a markdown copy at `flow/reviews/<branch>-cross-review-<timestamp>.md`.

## Backends

| Backend | OAuth token | Endpoint / call | Model selection |
|---|---|---|---|
| `azure-foundry-openai` | `az account get-access-token --scope https://ai.azure.com/.default` | `POST {endpoint}/openai/v1/chat/completions` (no `api-version` - the v1 path is the version) | by Foundry deployment name. **Recommended.** |
| `azure-foundry-inference` | `az account get-access-token --scope https://cognitiveservices.azure.com/.default` | `POST {endpoint}/models/chat/completions?api-version=2024-05-01-preview` | by model id. **Deprecated, retires 2026-08-26** - migrate to `azure-foundry-openai`. |
| `github-models` | `gh auth token` | `POST https://models.github.ai/inference/chat/completions` with `X-GitHub-Api-Version: 2026-03-10` and `Accept: application/vnd.github+json` | from the [GitHub Models catalog](https://github.com/marketplace?type=models), e.g. `openai/gpt-4o`, `openai/o3-mini`, `meta/Meta-Llama-3.1-70B-Instruct`. Works for Copilot Enterprise users with a standard `gh` token. |
| `copilot-cli` | OAuth via `copilot auth login` (uses your Copilot subscription) | shells out: `copilot -p "<prompt>" -s --model=<m> --allow-all-tools --deny-tool=write` | `auto` or any Copilot-supported model. No key management. |

`profiles.example.json` ships with sample entries for each.

## Intentional limits

- **Advisory only.** The skill never edits code; it surfaces findings for human triage.
- **Explicit invocation only.** The skill sets `disable-model-invocation: true` so Claude Code does not fire it autonomously, and the script is never to be wired to a Stop hook ([codex-plugin-cc #306](https://github.com/openai/codex-plugin-cc/issues/306) is the precedent of why).
- **No static keys in the repo.** All four backends authenticate via OAuth tokens from CLIs you already have logged in (`az`, `gh`, `copilot`).
- **Diff scope.** Reviews the merge-base diff `main...HEAD` by default. For very large branches, set `CROSS_REVIEW_BASE=<closer-ref>` to narrow.

## Alternatives considered (and not adopted)

- **PAL MCP** (formerly `zen-mcp-server`): a good MCP-server review tool, but its config holds a static API key and cannot refresh Entra ID tokens, so it does not fit our keyless / OAuth-only constraint.
- **`openai/codex-plugin-cc`**: usable via an explicit `/codex:adversarial-review`, but heavier (npm + plugin + `codex login`) and carries two open issues - [#306](https://github.com/openai/codex-plugin-cc/issues/306) (Stop-hook infinite loop on rate limit) and [#320](https://github.com/openai/codex-plugin-cc/issues/320) (subscription auth broken). If you specifically want Codex models reviewing, the `copilot-cli` backend reaches them via your Copilot Enterprise subscription instead.
