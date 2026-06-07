#!/usr/bin/env bash
# Tracker adapter: abstracts issue / work-item and PR operations across trackers.
#
# Workflow skills call this script instead of using a specific tracker's CLI
# directly. Two backends are fully wired: `github` (dispatches to `gh`) and
# `azure-devops` (dispatches to `az` with the azure-devops extension). The
# `none` backend is a tracker-less mode for projects without an issue tracker.
#
# Usage:  bash .claude/scripts/tracker.sh <subcommand> <args...>
#
# Subcommands (issue / work-item):
#   view <id> [--json field1,field2,...]      Fetch a work item as JSON.
#   set-state <id> <new> [<old>]              Apply a state transition.
#   comment <id> <text>                       Post a comment on a work item.
#
# Subcommands (PR / merge request):
#   pr-current [--json fields]                Fetch the PR for the current branch.
#   pr-view <id> [--json fields]              Fetch a PR by id.
#   pr-diff <id>                              Print the PR diff.
#   pr-edit-body <id> <body-file>             Replace the PR description.
#   pr-comment <id> <text>                    Post a comment on the PR.
#   pr-list-open                              List recent open PRs.
#   pr-reviews <id>                           Fetch reviews on a PR.
#   pr-review-comments <id>                   Fetch inline review comments.
#   pr-decision <id>                          Fetch the PR review decision.
#   pr-closing-issues <id>                    List issues this PR will close.
#
# Subcommands (utility):
#   repo-info                                 Owner + repo name as JSON.
#   backend                                   Print the active backend name.
#
# Backend selection: reads `.claude/tracker.json` (gitignored) if present,
# else `.claude/tracker.example.json`, else defaults to `github`. Override
# at runtime with `TRACKER_BACKEND=<name>`.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="${REPO_ROOT}/.claude/tracker.json"
[ ! -f "$CONFIG" ] && CONFIG="${REPO_ROOT}/.claude/tracker.example.json"

command -v jq >/dev/null 2>&1 || { echo "ERROR: 'jq' not installed" >&2; exit 3; }

if [ -n "${TRACKER_BACKEND:-}" ]; then
  BACKEND="$TRACKER_BACKEND"
elif [ -f "$CONFIG" ]; then
  BACKEND="$(jq -r '.tracker // "github"' "$CONFIG")"
else
  BACKEND="github"
fi

abort() { echo "ERROR: $1" >&2; exit "${2:-2}"; }

# Extract a `--json fields` pair from a remaining-args list, leaving other args alone.
# Sets globals: _JSON_FIELDS (string) and _REST (array).
parse_json_arg() {
  _JSON_FIELDS=""
  _REST=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --json)
        shift
        _JSON_FIELDS="${1:-}"
        shift || true
        ;;
      *)
        _REST+=("$1")
        shift
        ;;
    esac
  done
}

# ----------------------------------------------------------------------------
# GitHub backend
# ----------------------------------------------------------------------------
gh_require() { command -v gh >/dev/null 2>&1 || abort "'gh' CLI not installed; run 'gh auth login'" 3; }

gh_view() {
  gh_require
  local id="$1"; shift
  parse_json_arg "$@"
  local fields="${_JSON_FIELDS:-title,body,state,labels,comments}"
  gh issue view "$id" --json "$fields"
}

gh_set_state() {
  gh_require
  local id="$1" new="$2" old="${3:-}"
  if [ -n "$old" ]; then
    gh issue edit "$id" --add-label "$new" --remove-label "$old"
  else
    gh issue edit "$id" --add-label "$new"
  fi
}

gh_comment() {
  gh_require
  gh issue comment "$1" --body "$2"
}

gh_pr_current() {
  gh_require
  parse_json_arg "$@"
  local fields="${_JSON_FIELDS:-number,title,headRefName,state,url}"
  gh pr view --json "$fields"
}

gh_pr_view() {
  gh_require
  local id="$1"; shift
  parse_json_arg "$@"
  local fields="${_JSON_FIELDS:-title,body,state,reviews,comments,baseRefName,headRefName,url}"
  gh pr view "$id" --json "$fields"
}

gh_pr_diff()         { gh_require; gh pr diff "$1"; }
gh_pr_edit_body()    { gh_require; gh pr edit "$1" --body-file "$2"; }
gh_pr_comment()      { gh_require; gh pr comment "$1" --body "$2"; }
gh_pr_list_open()    { gh_require; gh pr list --limit 10 --json number,title,headRefName,author; }
gh_pr_reviews()      { gh_require; gh pr view "$1" --json reviews; }
gh_pr_review_comments() { gh_require; gh api "repos/:owner/:repo/pulls/$1/comments"; }
gh_pr_decision()     { gh_require; gh pr view "$1" --json reviewDecision; }
gh_pr_closing_issues() { gh_require; gh pr view "$1" --json closingIssuesReferences --jq '.closingIssuesReferences[].number'; }
gh_repo_info()       { gh_require; gh repo view --json owner,name; }

# ----------------------------------------------------------------------------
# Azure DevOps backend
# ----------------------------------------------------------------------------
# Auth: `az login` (Entra ID OAuth) plus, optionally,
#   `az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>`
# to pin org / project. The `--detect` flag on PR / repo commands lets the CLI
# infer org / project from the current git remote. The `azure-devops` extension
# must be installed: `az extension add --name azure-devops`.
azdo_require() {
  command -v az >/dev/null 2>&1 \
    || abort "'az' CLI not installed. Install Azure CLI and 'az extension add --name azure-devops'" 3
}

# Helper: remove a tag from a System.Tags string (semicolon-space separated).
azdo_tags_remove() {
  local tags="$1" rm_tag="$2" result="" t
  [ -z "$tags" ] && { printf ''; return; }
  local -a _arr=()
  IFS=';' read -ra _arr <<< "$tags" || true
  for t in "${_arr[@]:-}"; do
    [ -z "$t" ] && continue
    t="$(printf '%s' "$t" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -n "$t" ] && [ "$t" != "$rm_tag" ]; then
      [ -z "$result" ] && result="$t" || result="$result; $t"
    fi
  done
  printf '%s' "$result"
}

# Helper: add a tag to a System.Tags string (no duplicate).
azdo_tags_add() {
  local tags="$1" add_tag="$2" t
  [ -z "$tags" ] && { printf '%s' "$add_tag"; return; }
  local -a _arr=()
  IFS=';' read -ra _arr <<< "$tags" || true
  for t in "${_arr[@]:-}"; do
    [ -z "$t" ] && continue
    t="$(printf '%s' "$t" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ "$t" = "$add_tag" ] && { printf '%s' "$tags"; return; }
  done
  printf '%s; %s' "$tags" "$add_tag"
}

azdo_view() {
  azdo_require
  # No --json fields equivalent in az; --expand all returns the full item.
  az boards work-item show --id "$1" --expand all --output json
}

azdo_set_state() {
  azdo_require
  local id="$1" new="$2" old="${3:-}"
  local current new_tags mapped_state
  current=$(az boards work-item show --id "$id" --query 'fields."System.Tags"' -o tsv 2>/dev/null || true)
  new_tags="$current"
  [ -n "$old" ] && new_tags=$(azdo_tags_remove "$new_tags" "$old")
  new_tags=$(azdo_tags_add "$new_tags" "$new")
  # Optional typed System.State transition from the config's state_transitions block.
  mapped_state=""
  if [ -f "$CONFIG" ]; then
    mapped_state=$(jq -r --arg n "$new" '.["azure-devops"].state_transitions[$n].state // empty' "$CONFIG" 2>/dev/null || true)
  fi
  if [ -n "$mapped_state" ]; then
    az boards work-item update --id "$id" --state "$mapped_state" --fields "System.Tags=$new_tags" --output json
  else
    az boards work-item update --id "$id" --fields "System.Tags=$new_tags" --output json
  fi
}

azdo_comment() {
  azdo_require
  az boards work-item update --id "$1" --discussion "$2" --output json
}

azdo_pr_current() {
  azdo_require
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch=""
  [ -z "$branch" ] && abort "cannot detect current branch (not in a git repo?)" 2
  az repos pr list --source-branch "refs/heads/$branch" --status active --output json --query '[0]'
}

azdo_pr_view() { azdo_require; az repos pr show --id "$1" --output json; }

azdo_pr_diff() {
  azdo_require
  local id="$1" source target
  source=$(az repos pr show --id "$id" --query sourceRefName -o tsv 2>/dev/null | sed 's|refs/heads/||')
  target=$(az repos pr show --id "$id" --query targetRefName -o tsv 2>/dev/null | sed 's|refs/heads/||')
  [ -z "$source" ] && abort "could not resolve PR $id source branch" 4
  [ -z "$target" ] && abort "could not resolve PR $id target branch" 4
  git fetch origin "$source" "$target" >/dev/null 2>&1 || true
  git diff "origin/${target}...origin/${source}"
}

azdo_pr_edit_body() {
  azdo_require
  [ ! -f "$2" ] && abort "body file not found: $2" 2
  az repos pr update --id "$1" --description "$(cat "$2")" --output json
}

# Resolve project + repository.id for a PR (needed by az devops invoke for thread ops).
azdo_pr_resolve_repo() {
  local id="$1" info
  info=$(az repos pr show --id "$id" --output json 2>/dev/null) \
    || abort "could not resolve PR $id" 4
  _AZDO_PROJECT=$(printf '%s' "$info" | jq -r '.repository.project.name // empty')
  _AZDO_REPO_ID=$(printf '%s' "$info" | jq -r '.repository.id // empty')
  [ -z "$_AZDO_PROJECT" ] && abort "could not resolve repository.project.name for PR $id" 4
  [ -z "$_AZDO_REPO_ID" ] && abort "could not resolve repository.id for PR $id" 4
}

azdo_pr_comment() {
  azdo_require
  local id="$1" text="$2" body_file
  azdo_pr_resolve_repo "$id"
  body_file="$(mktemp)"
  trap 'rm -f "$body_file"' RETURN
  jq -n --arg text "$text" '{comments: [{parentCommentId: 0, content: $text, commentType: 1}], status: 1}' > "$body_file"
  az devops invoke \
    --area git --resource pullRequestThreads \
    --route-parameters "project=$_AZDO_PROJECT" "repositoryId=$_AZDO_REPO_ID" "pullRequestId=$id" \
    --http-method POST --in-file "$body_file" --api-version 7.1 --output json
}

azdo_pr_list_open() { azdo_require; az repos pr list --status active --top 10 --output json; }

azdo_pr_reviews() { azdo_require; az repos pr reviewer list --id "$1" --output json; }

azdo_pr_review_comments() {
  azdo_require
  local id="$1"
  azdo_pr_resolve_repo "$id"
  az devops invoke \
    --area git --resource pullRequestThreads \
    --route-parameters "project=$_AZDO_PROJECT" "repositoryId=$_AZDO_REPO_ID" "pullRequestId=$id" \
    --http-method GET --api-version 7.1 --output json
}

azdo_pr_decision() {
  azdo_require
  # ADO has no native reviewDecision; derive from reviewer-vote integers
  # (REST 7.1): 10=approved, 5=approved-with-suggestions, 0=no-vote, -5=waiting, -10=rejected.
  local votes rejections approvals
  votes=$(az repos pr reviewer list --id "$1" --output json 2>/dev/null) || votes='[]'
  rejections=$(printf '%s' "$votes" | jq '[.[] | select(.vote == -10)] | length')
  approvals=$(printf '%s' "$votes" | jq '[.[] | select(.vote >= 5)] | length')
  if [ "$rejections" -gt 0 ]; then
    printf '{"reviewDecision":"CHANGES_REQUESTED"}\n'
  elif [ "$approvals" -gt 0 ]; then
    printf '{"reviewDecision":"APPROVED"}\n'
  else
    printf '{"reviewDecision":"REVIEW_REQUIRED"}\n'
  fi
}

azdo_pr_closing_issues() {
  azdo_require
  # Returns work-item ids, one per line, to match the GitHub backend's behaviour.
  az repos pr work-item list --id "$1" --output tsv --query '[].id'
}

azdo_repo_info() {
  azdo_require
  # {owner, project, name} - owner is the org name parsed from remoteUrl.
  az repos show --detect --output json 2>/dev/null \
    | jq '{owner: (.remoteUrl | split("/")[3]), project: .project.name, name: .name}'
}

# ----------------------------------------------------------------------------
# None backend (tracker-less projects)
# ----------------------------------------------------------------------------
# Query subcommands return empty JSON so callers proceed gracefully.
# Mutating subcommands log and exit 0 so the workflow flows on.
none_query()    { echo "{}"; }
none_mutating() { echo "INFO: tracker=none; skipping $1" >&2; }

# ----------------------------------------------------------------------------
# Dispatch
# ----------------------------------------------------------------------------
SUBCMD="${1:-}"
[ -z "$SUBCMD" ] && abort "missing subcommand (try: backend, view, set-state, pr-view, ...)" 2
shift

case "$BACKEND" in
  github)
    case "$SUBCMD" in
      backend) echo github ;;
      view) gh_view "$@" ;;
      set-state) gh_set_state "$@" ;;
      comment) gh_comment "$@" ;;
      pr-current) gh_pr_current "$@" ;;
      pr-view) gh_pr_view "$@" ;;
      pr-diff) gh_pr_diff "$@" ;;
      pr-edit-body) gh_pr_edit_body "$@" ;;
      pr-comment) gh_pr_comment "$@" ;;
      pr-list-open) gh_pr_list_open ;;
      pr-reviews) gh_pr_reviews "$@" ;;
      pr-review-comments) gh_pr_review_comments "$@" ;;
      pr-decision) gh_pr_decision "$@" ;;
      pr-closing-issues) gh_pr_closing_issues "$@" ;;
      repo-info) gh_repo_info ;;
      *) abort "unknown subcommand for github backend: $SUBCMD" 2 ;;
    esac
    ;;

  azure-devops)
    case "$SUBCMD" in
      backend) echo azure-devops ;;
      view) azdo_view "$@" ;;
      set-state) azdo_set_state "$@" ;;
      comment) azdo_comment "$@" ;;
      pr-current) azdo_pr_current "$@" ;;
      pr-view) azdo_pr_view "$@" ;;
      pr-diff) azdo_pr_diff "$@" ;;
      pr-edit-body) azdo_pr_edit_body "$@" ;;
      pr-comment) azdo_pr_comment "$@" ;;
      pr-list-open) azdo_pr_list_open ;;
      pr-reviews) azdo_pr_reviews "$@" ;;
      pr-review-comments) azdo_pr_review_comments "$@" ;;
      pr-decision) azdo_pr_decision "$@" ;;
      pr-closing-issues) azdo_pr_closing_issues "$@" ;;
      repo-info) azdo_repo_info ;;
      *) abort "unknown subcommand for azure-devops backend: $SUBCMD" 2 ;;
    esac
    ;;

  none)
    case "$SUBCMD" in
      backend) echo none ;;
      view|pr-current|pr-view|pr-diff|pr-list-open|pr-reviews|pr-review-comments|pr-decision|pr-closing-issues|repo-info)
        none_query ;;
      set-state|comment|pr-edit-body|pr-comment)
        none_mutating "$SUBCMD" ;;
      *) abort "unknown subcommand for none backend: $SUBCMD" 2 ;;
    esac
    ;;

  *)
    abort "unknown tracker backend: $BACKEND (supported: github, azure-devops, none)" 2
    ;;
esac
