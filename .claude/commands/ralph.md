---
description: Autonomous issue processing loop - Research → Plan → Implement → Validate → PR until all issues complete
---

# Ralph Wiggum - Autonomous Development Loop

This command implements the [Ralph Wiggum technique](https://ghuntley.com/ralph/) - running AI coding agents in a continuous loop until all tasks are complete.

## How It Works

Ralph loops through open GitHub issues, processing each one end-to-end:
1. **Research** → 2. **Plan** → 3. **Implement** → 4. **Validate** → 5. **PR** → 6. **Review** → 7. **Merge** → 8. **Next issue**

It reuses existing commands to maintain consistency with the workflow. Validation acts as a quality gate before committing, ensuring only working code enters version control.

## Configuration

```bash
MAX_ITERATIONS=10                # Safety limit - adjust based on your budget
CLAUDE_TIMEOUT_SECONDS=1800      # 30 minutes per phase
ENABLE_PR_REVIEW=true            # Request @claude PR reviews
ENABLE_PR_AUTO_MERGE=false       # Legacy auto-merge without review
MAX_REVIEW_ITERATIONS=3          # Max times to implement review feedback
REVIEW_POLL_INTERVAL=30          # Seconds between review status checks
REVIEW_TIMEOUT_SECONDS=600       # 10 minutes timeout for review
```

## The Loop

```
ITERATION = 0
MAX_ITERATIONS = 10

while ITERATION < MAX_ITERATIONS:
    ITERATION += 1

    # Step 1: Find next issue to work on
    # Priority: issues with plans first, then issues needing research
```

### Step 1: Find Next Issue

Fetch open issues and prioritize:

```bash
# First, check for issues ready to implement (have plans)
gh issue list --label "ready-for-dev" --limit 5 --json number,title,labels

# If none, check for issues needing research/planning
gh issue list --state open --limit 10 --json number,title,labels
```

Select the highest priority issue. If no open issues remain, **EXIT with success message**.

### Step 2: Check for Existing Research

Look for research document matching this issue:

```bash
ls thoughts/research/*-gh-<number>-*.md 2>/dev/null
```

**If research exists:** Read it and proceed to Step 3.

**If no research exists:**
1. Update issue label:
   ```bash
   gh issue edit <number> --add-label "research-in-progress"
   ```
2. Run research (reusing existing command logic):
   - Fetch issue details: `gh issue view <number> --json number,title,body,labels,comments`
   - Research the codebase and web as needed
   - Create research document: `thoughts/research/YYYY-MM-DD-gh-<number>-<description>.md`
   - Follow the research process from `/research_requirements`
3. Update label:
   ```bash
   gh issue edit <number> --add-label "research-complete" --remove-label "research-in-progress"
   ```

### Step 3: Check for Existing Plan

Look for implementation plan matching this issue:

```bash
ls thoughts/plans/*-gh-<number>-*.md 2>/dev/null
```

**If plan exists:** Read it and proceed to Step 4.

**If no plan exists:**
1. Update issue label:
   ```bash
   gh issue edit <number> --add-label "planning-in-progress"
   ```
2. Create plan (reusing existing command logic):
   - Read the research document from Step 2
   - Follow the planning process from `/create_plan`
   - Create plan document: `thoughts/plans/YYYY-MM-DD-gh-<number>-<description>.md`
   - Plan should include phased implementation with TDD
3. Update label:
   ```bash
   gh issue edit <number> --add-label "ready-for-dev" --remove-label "planning-in-progress"
   ```

### Step 4: Implement the Plan

1. Update issue label:
   ```bash
   gh issue edit <number> --add-label "in-progress" --remove-label "ready-for-dev"
   ```

2. Create feature branch:
   ```bash
   git checkout -b feature/<number>-<description>
   ```

3. Implement (reusing existing command logic):
   - Read the plan document from Step 3
   - Follow the implementation process from `/implement_plan`
   - Write tests first (TDD)
   - Implement each phase
   - Run verification after each phase

4. If implementation fails or tests don't pass:
   - Add comment to issue explaining the blocker
   - Add label: `implementation-failed`
   - Move to next issue (don't get stuck)

### Step 5: Validate Implementation

Before committing, validate that the implementation matches the plan and meets quality standards. This is a critical quality gate for autonomous operation.

1. Run validation (reusing existing command logic):
   - Follow the validation process from `/validate_plan`
   - Read the plan document: `thoughts/plans/YYYY-MM-DD-gh-<number>-<description>.md`
   - Analyze uncommitted changes via `git diff`
   - Run all automated verification commands (tests, linting, etc.)
   - Generate validation report

2. **If validation passes:**
   - All automated tests pass
   - No critical issues found
   - Implementation matches plan specifications
   - **Proceed to Step 6 (Commit and Create PR)**

3. **If validation fails:**
   - Add label:
     ```bash
     gh issue edit <number> --add-label "validation-failed" --remove-label "in-progress"
     ```
   - Add comment with validation report:
     ```bash
     gh issue comment <number> --body "## ⚠️ Validation Failed

     Implementation completed but validation identified issues:

     <paste validation report>

     This issue requires human review before proceeding.

     ---
     Generated by Ralph Wiggum autonomous loop"
     ```
   - **DO NOT commit broken code**
   - Reset working directory: `git reset --hard`
   - Return to main branch: `git checkout main`
   - **Move to next issue (Step 1)**

**Important:** Ralph does not attempt to fix validation failures autonomously. Issues that fail validation are flagged for human review. This prevents Ralph from making things worse or entering infinite fix loops.

### Step 6: Commit and Create PR

1. Stage and commit changes:
   - Follow the commit process from `/commit`
   - Create atomic, well-described commits

2. Push branch:
   ```bash
   git push -u origin feature/<number>-<description>
   ```

3. Create PR:
   ```bash
   gh pr create --title "Closes #<number>: <description>" --body "## Summary

   Implements #<number>

   ## Changes
   - <list changes>

   ## Test Plan
   - <verification steps>

   ---
   Generated by Ralph Wiggum autonomous loop"
   ```

4. Link PR to issue:
   ```bash
   gh issue comment <number> --body "PR created: <pr-url>"
   ```

### Step 7: PR Review Phase (if ENABLE_PR_REVIEW=true)

1. Request @claude review:
   ```bash
   gh pr comment <pr-number> --body "@claude please review this PR"
   ```

2. Poll for review completion (10 minute timeout):
   - Check review status every 30 seconds
   - Handle outcomes:
     - **APPROVED** → Proceed to Step 8
     - **CHANGES_REQUESTED** → Implement feedback (up to 3 iterations) or label `needs-human-review`
     - **TIMEOUT** → Label `needs-human-review` and continue to next issue

3. Handle review feedback:
   - Get review comments from @claude
   - Implement changes in same PR branch
   - Push updates and request re-review
   - Max 3 review iteration cycles

### Step 8: Merge PR (if review approved)

1. Merge PR with squash:
   ```bash
   gh pr merge <pr-number> --squash --delete-branch
   ```

2. Close issue with success comment:
   ```bash
   gh issue close <number> --comment "✅ Completed and merged via PR #<pr-number>

   Autonomous cycle: Research → Plan → Implement → Validate → Review → Merge"
   ```

3. Return to main branch:
   ```bash
   git checkout main
   git pull
   ```

4. **Continue to next iteration**

## Exit Conditions

The loop exits when:
- **Success:** No more open issues to process
- **Safety:** MAX_ITERATIONS reached (default: 10)
- **Error:** Unrecoverable error (report and exit)

## Completion Message

When done, print:

```
🤖 Ralph Wiggum Complete

Iterations: <N>
Issues processed: <list>
PRs created: <list>

Remaining open issues: <count>
- <issue list if any>

Total time: <duration>
```

## Important Notes

- **Cost awareness:** Each iteration uses API tokens. Monitor usage.
- **Autonomous reviews:** With `ENABLE_PR_REVIEW=true`, Ralph requests @claude reviews and auto-merges approved PRs.
- **Review fallback:** If review times out, has unclear feedback, or exceeds max iterations, issue is labeled `needs-human-review` and Ralph continues to next issue.
- **Feedback implementation:** Automated implementation of review feedback is coming soon. Currently marks as `needs-human-review` when changes are requested.
- **Stuck issues:** If an issue fails, Ralph moves on rather than looping forever.
- **Branch hygiene:** Each issue gets its own feature branch.

## Usage

```
/ralph              # Process up to 10 issues (default)
/ralph 5            # Process up to 5 issues
/ralph --dry-run    # Show what would be processed without doing it
```

Think deeply at each step. Use TodoWrite to track progress across iterations.
