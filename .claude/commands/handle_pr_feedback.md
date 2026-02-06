---
description: Handle PR feedback from @claude reviews - update plan and implement changes
---

# Handle PR Feedback

You are tasked with handling feedback from @claude's PR review. This command fetches review comments, updates the implementation plan to document the feedback, implements the requested changes, and pushes updates.

## Command Usage

```bash
/handle_pr_feedback <pr-number>
# Or auto-detect from current branch:
/handle_pr_feedback
```

## Steps to Follow

### 1. Identify the PR

**If PR number provided:**
- Use the provided PR number

**If no PR number provided:**
- Auto-detect from current branch: `gh pr view --json number,title,headRefName 2>/dev/null`
- If multiple PRs or unclear, ask user which PR to handle

### 2. Fetch PR Review Feedback

```bash
# Get PR review comments
gh pr view <pr-number> --json reviews,comments --jq '.reviews[] | select(.author.login == "claude-code[bot]" or .body | contains("@claude"))'

# Also get inline review comments
gh api repos/:owner/:repo/pulls/<pr-number>/comments
```

**Parse the feedback:**
- Look for @claude's review comments (both overall review and inline comments)
- Identify what changes were requested
- Categorize by type: security, bugs, style, architecture, edge cases
- Extract specific file locations and suggested fixes

**If no feedback found:**
- Check if review is still pending: `gh pr view <pr-number> --json reviewDecision`
- If APPROVED: notify user "PR already approved, no changes needed"
- If CHANGES_REQUESTED but no comments: ask user to specify what to fix
- If pending: notify user to wait for review to complete

### 3. Find the Implementation Plan

```bash
# Look for plan file related to this PR
# Strategy 1: Check PR description for plan reference
gh pr view <pr-number> --json body | grep -o "thoughts/plans/[^)]*"

# Strategy 2: Get issue number from PR title/body
gh pr view <pr-number> --json title,body | grep -o "#[0-9]*" | head -1

# Then find plan:
ls thoughts/plans/*-gh-<issue-number>-*.md 2>/dev/null

# Strategy 3: Check commits for plan references
gh pr view <pr-number> --json commits | grep -o "thoughts/plans/[^)]*"
```

**If plan not found:**
- List all recent plans: `ls -t thoughts/plans/*.md | head -5`
- Ask user which plan to update
- If user says "none" or "skip", proceed without plan update (just implement changes)

### 4. Update the Implementation Plan

Read the plan file and add a "PR Review Updates" section (or append to existing one):

```markdown
## PR Review Updates

### Review: <date> by @claude

**Review Decision:** CHANGES_REQUESTED

#### Changes Requested:

1. **[Category]** [Issue description]
   - **Location:** `path/to/file.py:42`
   - **Problem:** [What's wrong]
   - **Solution:** [How to fix it]
   - **Reason:** [Why this matters]

2. **[Category]** [Issue description]
   ...

#### Implementation Status:
- [ ] Change 1: [description]
- [ ] Change 2: [description]
```

**Write the updated plan back to the file.**

### 5. Implement the Changes

For each change requested:

**Read relevant files:**
- Use the Read tool to examine files mentioned in feedback
- Understand current implementation
- Identify what needs to change

**Make the changes:**
- Follow @claude's suggestions
- Ensure changes align with the codebase patterns
- Consider edge cases and related code that might need updates
- Maintain code style and consistency

**Important:**
- If feedback is unclear, make best judgment and note assumptions in commit message
- If multiple valid approaches exist, choose the simplest one
- Don't over-engineer - fix exactly what was requested

### 6. Verify the Changes

**Run relevant tests/checks:**
```bash
# If project has tests, run them
# Python example:
uv run pytest tests/

# If project has linting:
uv run ruff check .

# Or whatever test/check commands exist in the project
```

**If tests fail:**
- Fix the issues
- Re-run tests
- Repeat until passing

### 7. Update Plan Status

Update the implementation plan's "Implementation Status" section to mark completed items:

```markdown
#### Implementation Status:
- [x] Change 1: Fixed SQL injection - COMPLETED
- [x] Change 2: Added null check - COMPLETED
```

### 8. Commit Changes

Create a clear commit message:

```bash
git add <changed-files>

git commit -m "$(cat <<'EOF'
Address @claude PR feedback: <brief summary>

Changes made:
- <change 1>
- <change 2>
- <change 3>

Review: <pr-url>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

**Also commit the updated plan:**
```bash
git add thoughts/plans/<plan-file>.md
git commit --amend --no-edit
```

### 9. Push Updates

```bash
# Push to the PR branch (updates the existing PR)
git push
```

### 10. Request Re-review

```bash
# Comment on the PR to request re-review
gh pr comment <pr-number> --body "@claude I've addressed your feedback in the latest commit. Please re-review:

Changes made:
- <change 1>
- <change 2>

All tests passing ✅"
```

### 11. Update Plan Labels (if GitHub issue exists)

```bash
# Get linked issue number
gh pr view <pr-number> --json closingIssuesReferences --jq '.closingIssuesReferences[].number'

# Keep issue in 'in-progress' (already there, no change needed)
```

### 12. Report Summary

Show the user:

```
✅ PR Feedback Handled: PR #<number>

📋 Plan Updated: thoughts/plans/<plan-file>.md
   - Added PR Review Updates section
   - Documented <N> changes requested

🔧 Changes Implemented:
   - <change 1>
   - <change 2>
   - <change 3>

✅ Tests: PASSING (or show failures if any)

📤 Pushed to: <branch-name>
💬 Re-review requested from @claude

Next: Wait for @claude's re-review, or run `/handle_pr_feedback` again if more feedback arrives.
```

## Important Notes

- **Human oversight:** While this command automates the process, you should review @claude's feedback before running it to ensure you agree with the changes
- **Iteration limit:** If this is the 3rd+ iteration of feedback on the same PR, consider adding `needs-human-review` label and asking user to review
- **Plan updates are documentation:** The primary goal is to keep the plan accurate as a historical record
- **No new PRs:** This updates the existing PR by pushing to the same branch
- **Atomic changes:** Each feedback item should be a logical, testable change
- **Failed tests:** If tests fail after changes, fix them before pushing

## Edge Cases

**Multiple reviewers:**
- Focus on @claude's feedback specifically
- If human reviewers also left feedback, mention it but focus on @claude's automation-friendly review

**Conflicting feedback:**
- If @claude's suggestions conflict with each other, implement the most critical ones first (security > bugs > style)
- Note conflicts in commit message

**Large architectural changes:**
- If feedback requests major refactoring, update plan extensively
- Consider asking user if they want to proceed with large changes
- Might be better suited for a new issue/plan cycle

**No plan file:**
- Still implement the changes
- Note that plan wasn't found in commit message
- Suggest creating a plan retrospectively if changes are significant

## Example Session

```bash
# User runs command
/handle_pr_feedback 42

# Output:
📥 Fetching PR #42 feedback...
Found @claude review: CHANGES_REQUESTED

Changes requested:
1. Security: SQL injection in auth.py:42
2. Bug: Missing null check in user_validator.py:15
3. Style: Use list comprehension in data_processor.py:88

📋 Updating plan: thoughts/plans/2026-02-06-gh-42-add-auth.md
✅ Plan updated with PR Review Updates section

🔧 Implementing changes...
✅ Fixed SQL injection - using parameterized queries
✅ Added null validation before processing
✅ Refactored to list comprehension

✅ Running tests... PASSED

📤 Pushing changes to feature/42-add-auth
💬 Re-review requested from @claude

Done! ✅
```
