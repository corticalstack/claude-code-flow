#!/usr/bin/env bash
# Tracker adapter: abstracts issue / work-item and PR operations across trackers.
#
# Workflow skills call this script instead of using a specific tracker's CLI
# directly. Today the only fully wired backend is `github` (which dispatches
# to `gh`). The `azure-devops` backend is a stub returning a clear error;
# the `none` backend is a tracker-less mode for projects without an issue tracker.
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
# Azure DevOps backend (stub - implemented in PR 2)
# ----------------------------------------------------------------------------
azdo_stub() {
  abort "azure-devops backend is not implemented yet (PR 2). See docs/tracker-portability.md." 3
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
      *) azdo_stub ;;
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
