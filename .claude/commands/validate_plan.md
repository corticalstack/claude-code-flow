---
description: Validate implementation against plan, verify success criteria, identify issues
---

# Validate Plan

You are tasked with validating that an implementation plan was correctly executed, verifying all success criteria and identifying any deviations or issues.

## Initial Setup

When invoked:
1. **Determine context** - Are you in an existing conversation or starting fresh?
   - If existing: Review what was implemented in this session
   - If fresh: Need to discover what was done through git and codebase analysis

2. **Locate the plan**:
   - If plan path provided, use it
   - Otherwise, search recent commits for plan references or ask user

3. **Gather implementation evidence**:
   ```bash
   # Check recent commits
   git log --oneline -n 20
   git diff HEAD~N..HEAD  # Where N covers implementation commits

   # Run project-specific verification commands
   # The plan's "Automated Verification" section specifies what to run
   # Common examples:
   # - Python: uv run pytest tests/ -v
   # - Node: npm test
   # - Make: make check test
   # - Rust: cargo test
   # - Go: go test ./...
   ```

## Validation Process

### Step 1: Context Discovery

If starting fresh or need more context:

1. **Read the implementation plan** completely
2. **Identify what should have changed**:
   - List all files that should be modified
   - Note all success criteria (automated and manual)
   - Identify key functionality to verify

3. **Spawn parallel research tasks** to discover implementation:
   ```
   Task 1 - Verify code changes:
   Find all modified files related to [feature].
   Compare actual changes to plan specifications.
   Return: File-by-file comparison of planned vs actual

   Task 2 - Verify test coverage:
   Check if tests were added/modified as specified.
   Run test commands and capture results.
   Return: Test status and any missing coverage
   ```

### Step 2: Systematic Validation

For each phase in the plan:

1. **Check completion status**:
   - Look for checkmarks in the plan (- [x])
   - Verify the actual code matches claimed completion

2. **Run automated verification**:
   - Execute each command from the plan's "Automated Verification" section
   - Document pass/fail status with the actual command that was run
   - If failures, investigate root cause

3. **Assess manual criteria**:
   - List what needs manual testing
   - Provide clear steps for user verification

4. **Think deeply about edge cases**:
   - Were error conditions handled?
   - Are there missing validations?
   - Could the implementation break existing functionality?

### Step 3: Generate Validation Report

Create comprehensive validation summary:

```markdown
## Validation Report: [Plan Name]

### Implementation Status
✓ Phase 1: [Name] - Fully implemented
✓ Phase 2: [Name] - Fully implemented
⚠️ Phase 3: [Name] - Partially implemented (see issues)

### Automated Verification Results
✓ Build passes: `[command from plan's automated verification]`
✓ Tests pass: `[command from plan's automated verification]`
✗ Linting issues: `[command from plan's automated verification]` (3 warnings)

### Code Review Findings

#### Matches Plan:
- Database migration correctly adds [table]
- API endpoints implement specified methods
- Error handling follows plan

#### Deviations from Plan:
- Used different variable names in [file:line]
- Added extra validation in [file:line] (improvement)

#### Potential Issues:
- Missing index on foreign key could impact performance
- No rollback handling in migration

### Manual Testing Required:
1. UI functionality:
   - [ ] Verify [feature] appears correctly
   - [ ] Test error states with invalid input

2. Integration:
   - [ ] Confirm works with existing [component]
   - [ ] Check performance with large datasets

### Recommendations:
- Address linting warnings before merge
- Consider adding integration test for [scenario]
- Document new API endpoints
```

### Step 4: Update GitHub Issue Label

Based on validation results:

**If validation fails** (automated checks fail, critical issues found):
```bash
gh issue edit <number> --add-label "validation-failed" --remove-label "in-progress"
```

**If validation passes** (all automated checks pass, ready for PR):
- Keep `in-progress` label (will be updated to `pr-submitted` after PR creation)
- Validation passing doesn't mean implementation is done - it means it's ready for code review via PR

## Working with Existing Context

If you were part of the implementation:
- Review the conversation history
- Check your todo list for what was completed
- Focus validation on work done in this session
- Be honest about any shortcuts or incomplete items

## Important Guidelines

1. **Be thorough but practical** - Focus on what matters
2. **Run all automated checks** - Don't skip verification commands
3. **Document everything** - Both successes and issues
4. **Think critically** - Question if the implementation truly solves the problem
5. **Consider maintenance** - Will this be maintainable long-term?

## Validation Checklist

Always verify:
- [ ] All phases marked complete are actually done
- [ ] Automated tests pass
- [ ] Code follows existing patterns
- [ ] No regressions introduced
- [ ] Error handling is robust
- [ ] Documentation updated if needed
- [ ] Manual test steps are clear

## Relationship to Other Commands

Recommended workflow:
1. `/implement_plan` - Execute the implementation
2. `/validate_plan` - Verify implementation correctness (quality gate)
3. Fix any issues found during validation
4. `/commit` - Create atomic commits for changes (only after validation passes)
5. `/describe_pr` - Generate PR description

Validation works best on uncommitted changes, acting as a quality gate before creating commits. This ensures a cleaner git history without "fix validation issues" commits. Use `git diff` to analyze what was implemented.

Remember: Good validation catches issues before they reach production. Be constructive but thorough in identifying gaps or improvements.