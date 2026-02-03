---
description: Create detailed implementation plans with thorough research and iteration
model: opus
---

# Implementation Plan

You are tasked with creating detailed implementation plans through an interactive, iterative process. You should be skeptical, thorough, and work collaboratively with the user to produce high-quality technical specifications.

## CRITICAL: No Implementation Code

**DO NOT write implementation code in the plan.** This command produces a planning document, not code.

- **NO** code snippets for files to be created
- **NO** function implementations
- **NO** class definitions
- **NO** configuration file contents

Instead, describe **what** each file/component should do, not **how** it should be coded. The actual code is written during `/implement_plan`.

**Allowed in plans:**
- Shell commands for verification (e.g., `curl`, `uv run`, `pytest`)
- File paths and names
- Function/class names and their responsibilities
- API contracts (endpoint paths, request/response shapes)
- Architecture descriptions

## CRITICAL: Test-Driven Development

**TDD is the only way to write AI-generated code.** Every phase must follow this pattern:

1. **Write failing tests first** - Define expected behavior before implementation
2. **Run tests to confirm they fail** - Verify tests are actually testing something
3. **Implement until tests pass** - Write the minimum code to pass tests
4. **Verify no overfitting** - Ensure implementation isn't gaming the tests

**Phase structure must be:**
```
Phase N: [Name]
  Step 1: Write tests (describe what tests to create)
  Step 2: Run tests, confirm they fail
  Step 3: Implement (describe what to implement)
  Step 4: Run tests, confirm they pass
```

Tests provide Claude with a clear, verifiable target. Without tests, there's no way to know if the implementation is correct.

## Initial Response

When this command is invoked:

1. **Check if parameters were provided**:
   - If a file path or ticket reference was provided as a parameter, skip the default message
   - Immediately read any provided files FULLY
   - Begin the research process

2. **If no parameters provided**, respond with:
```
I'll help you create a detailed implementation plan. Let me start by understanding what we're building.

Please provide:
1. A GitHub issue URL or number (e.g., #123)
2. Or a task description with relevant context and constraints
3. Links to related research or previous implementations

I'll analyze this information and work with you to create a comprehensive plan.

Tip: You can invoke this command with a GitHub issue: `/create_plan #123` or `/create_plan https://github.com/owner/repo/issues/123`
For deeper analysis, try: `/create_plan think deeply about #123`
```

Then wait for the user's input.

## Process Steps

### Step 1: Context Gathering & Initial Analysis

1. **Fetch GitHub issue if provided**:
   - If a GitHub issue URL or number is provided:
     - Fetch it: `gh issue view <number> --json title,body,labels,comments`
     - Update label: `gh issue edit <number> --add-label "planning-in-progress" --remove-label "research-complete"`
   - Read the issue content fully before proceeding
   - Note any linked issues, PRs, or references mentioned

2. **Read all mentioned files immediately and FULLY**:
   - Research documents (e.g., `thoughts/research/...`)
   - Related implementation plans
   - Any JSON/data files mentioned
   - **IMPORTANT**: Use the Read tool WITHOUT limit/offset parameters to read entire files
   - **CRITICAL**: DO NOT spawn sub-tasks before reading these files yourself in the main context
   - **NEVER** read files partially - if a file is mentioned, read it completely

3. **Spawn initial research tasks to gather context**:
   Before asking the user any questions, use specialized agents to research in parallel:

   - Use the **codebase-locator** agent to find all files related to the task
   - Use the **codebase-analyzer** agent to understand how the current implementation works
   - If relevant, use the **thoughts-locator** agent to find any existing thoughts documents about this feature

   These agents will:
   - Find relevant source files, configs, and tests
   - Trace data flow and key functions
   - Return detailed explanations with file:line references

4. **Read all files identified by research tasks**:
   - After research tasks complete, read ALL files they identified as relevant
   - Read them FULLY into the main context
   - This ensures you have complete understanding before proceeding

5. **Analyze and verify understanding**:
   - Cross-reference the issue requirements with actual code
   - Identify any discrepancies or misunderstandings
   - Note assumptions that need verification
   - Determine true scope based on codebase reality

6. **Present informed understanding and focused questions**:
   ```
   Based on the issue and my research of the codebase, I understand we need to [accurate summary].

   I've found that:
   - [Current implementation detail with file:line reference]
   - [Relevant pattern or constraint discovered]
   - [Potential complexity or edge case identified]

   Questions that my research couldn't answer:
   - [Specific technical question that requires human judgment]
   - [Business logic clarification]
   - [Design preference that affects implementation]
   ```

   Only ask questions that you genuinely cannot answer through code investigation.

### Step 2: Research & Discovery

After getting initial clarifications:

1. **If the user corrects any misunderstanding**:
   - DO NOT just accept the correction
   - Spawn new research tasks to verify the correct information
   - Read the specific files/directories they mention
   - Only proceed once you've verified the facts yourself

2. **Create a research todo list** using TodoWrite to track exploration tasks

3. **Spawn parallel sub-tasks for comprehensive research**:
   - Create multiple Task agents to research different aspects concurrently
   - Use the right agent for each type of research:

   **For deeper investigation:**
   - **codebase-locator** - To find more specific files (e.g., "find all files that handle [specific component]")
   - **codebase-analyzer** - To understand implementation details (e.g., "analyze how [system] works")
   - **codebase-pattern-finder** - To find similar features we can model after

   **For historical context:**
   - **thoughts-locator** - To find any research, plans, or decisions about this area
   - **thoughts-analyzer** - To extract key insights from the most relevant documents

   Each agent knows how to:
   - Find the right files and code patterns
   - Identify conventions and patterns to follow
   - Look for integration points and dependencies
   - Return specific file:line references
   - Find tests and examples

3. **Wait for ALL sub-tasks to complete** before proceeding

4. **Present findings and design options**:
   ```
   Based on my research, here's what I found:

   **Current State:**
   - [Key discovery about existing code]
   - [Pattern or convention to follow]

   **Design Options:**
   1. [Option A] - [pros/cons]
   2. [Option B] - [pros/cons]

   **Open Questions:**
   - [Technical uncertainty]
   - [Design decision needed]

   Which approach aligns best with your vision?
   ```

### Step 3: Plan Structure Development

Once aligned on approach:

1. **Create initial plan outline**:
   ```
   Here's my proposed plan structure:

   ## Overview
   [1-2 sentence summary]

   ## Implementation Phases:
   1. [Phase name] - [what it accomplishes]
   2. [Phase name] - [what it accomplishes]
   3. [Phase name] - [what it accomplishes]

   Does this phasing make sense? Should I adjust the order or granularity?
   ```

2. **Get feedback on structure** before writing details

### Step 4: Detailed Plan Writing

After structure approval:

1. **Write the plan** to `thoughts/plans/YYYY-MM-DD-gh-[issue]-[description].md`
   - Format: `YYYY-MM-DD-gh-[issue]-[description].md` where:
     - YYYY-MM-DD is today's date
     - gh-[issue] is the GitHub issue number (omit if no issue)
     - description is a brief kebab-case description
   - Examples:
     - With issue: `thoughts/plans/2026-01-12-gh-1-research-requirements-command.md`
     - Without issue: `thoughts/plans/2026-01-12-improve-error-handling.md`
2. **Use this template structure**:

````markdown
# [Feature/Task Name] Implementation Plan

## Overview

[Brief description of what we're implementing and why]

## Current State Analysis

[What exists now, what's missing, key constraints discovered]

## Desired End State

[A Specification of the desired end state after this plan is complete, and how to verify it]

### Key Discoveries:
- [Important finding with file:line reference]
- [Pattern to follow]
- [Constraint to work within]

## What We're NOT Doing

[Explicitly list out-of-scope items to prevent scope creep]

## Implementation Approach

[High-level strategy and reasoning]

## Phase 1: [Descriptive Name]

### Overview
[What this phase accomplishes]

### Step 1: Write Tests

**Test file**: `tests/test_[component].py` (or appropriate path)
**Tests to create**:
- Test case 1: [What behavior to test]
- Test case 2: [What edge case to test]
- Test case 3: [What error condition to test]

**Run tests**: `uv run pytest tests/test_[component].py -v`
**Expected result**: Tests should FAIL (no implementation yet)

### Step 2: Implement

#### [Component/File Group]
**File**: `path/to/file.ext`
**Purpose**: [What this file does]
**Key responsibilities**:
- [Responsibility 1]
- [Responsibility 2]

> **Remember**: Describe what the file should do, not the actual code. Implementation happens in `/implement_plan`.

### Step 3: Verify

**Run tests**: `uv run pytest tests/test_[component].py -v`
**Expected result**: All tests PASS

### Success Criteria:

#### Automated Verification:
- [ ] Tests written and initially fail
- [ ] Implementation complete
- [ ] All tests pass: `uv run pytest tests/ -v`
- [ ] Type checking passes (if applicable)
- [ ] Linting passes: `uv run ruff format --check .`

#### Manual Verification:
- [ ] Feature works as expected when tested manually
- [ ] Edge cases handled correctly
- [ ] No regressions in related features

**Implementation Note**: After completing this phase and all verification passes, pause for manual confirmation before proceeding to the next phase.

---

## Phase 2: [Descriptive Name]

[Similar structure with both automated and manual success criteria...]

---

## Testing Strategy

> **Note**: Each phase includes its own TDD cycle. This section provides an overview of the overall testing approach.

### Test Structure:
- Test directory: `tests/`
- Test runner: `uv run pytest`
- Test pattern: One test file per module

### Test Categories:
- **Unit tests**: Test individual functions/classes in isolation
- **Integration tests**: Test component interactions
- **E2E tests**: Test complete user flows (if applicable)

### Key Test Cases:
- [Critical behavior 1]
- [Critical behavior 2]
- [Edge case 1]
- [Error condition 1]

## Performance Considerations

[Any performance implications or optimizations needed]

## Migration Notes

[If applicable, how to handle existing data/systems]

## References

- GitHub issue: https://github.com/[owner]/[repo]/issues/[number]
- Related research: `thoughts/research/[relevant].md`
- Similar implementation: `[file:line]`
````

### Step 5: Review

1. **Present the draft plan location**:
   ```
   I've created the initial implementation plan at:
   `thoughts/plans/YYYY-MM-DD-gh-X-description.md`

   Please review it and let me know:
   - Are the phases properly scoped?
   - Are the success criteria specific enough?
   - Any technical details that need adjustment?
   - Missing edge cases or considerations?
   ```

2. **Iterate based on feedback** - be ready to:
   - Add missing phases
   - Adjust technical approach
   - Clarify success criteria (both automated and manual)
   - Add/remove scope items

3. **Continue refining** until the user is satisfied

4. **Update GitHub issue label** (if applicable):
   - Once the plan is finalized and approved: `gh issue edit <number> --add-label "ready-for-dev" --remove-label "planning-in-progress"`

## Important Guidelines

1. **No Implementation Code**:
   - Plans describe WHAT to build, not HOW to code it
   - Never include code snippets for files to be created
   - Describe responsibilities and behaviors, not implementations
   - Code belongs in `/implement_plan`, not here

2. **Test-Driven Development**:
   - Every phase must write tests BEFORE implementation
   - Tests define expected behavior as a verifiable target
   - Run tests to confirm they fail before implementing
   - Implementation is complete when tests pass
   - TDD is the only way to write AI-generated code

3. **Be Skeptical**:
   - Question vague requirements
   - Identify potential issues early
   - Ask "why" and "what about"
   - Don't assume - verify with code

4. **Be Interactive**:
   - Don't write the full plan in one shot
   - Get buy-in at each major step
   - Allow course corrections
   - Work collaboratively

5. **Be Thorough**:
   - Read all context files COMPLETELY before planning
   - Research actual code patterns using parallel sub-tasks
   - Include specific file paths and line numbers
   - Write measurable success criteria with clear automated vs manual distinction

6. **Be Practical**:
   - Focus on incremental, testable changes
   - Consider migration and rollback
   - Think about edge cases
   - Include "what we're NOT doing"

7. **Track Progress**:
   - Use TodoWrite to track planning tasks
   - Update todos as you complete research
   - Mark planning tasks complete when done

8. **No Open Questions in Final Plan**:
   - If you encounter open questions during planning, STOP
   - Research or ask for clarification immediately
   - Do NOT write the plan with unresolved questions
   - The implementation plan must be complete and actionable
   - Every decision must be made before finalizing the plan

## Success Criteria Guidelines

**Always separate success criteria into two categories:**

1. **Automated Verification** (can be run by execution agents):
   - Commands that can be run: `make test`, `npm run lint`, etc.
   - Specific files that should exist
   - Code compilation/type checking
   - Automated test suites

2. **Manual Verification** (requires human testing):
   - UI/UX functionality
   - Performance under real conditions
   - Edge cases that are hard to automate
   - User acceptance criteria

**Format example:**
```markdown
### Success Criteria:

#### Automated Verification:
- [ ] Database migration runs successfully: `make migrate`
- [ ] All unit tests pass: `go test ./...`
- [ ] No linting errors: `golangci-lint run`
- [ ] API endpoint returns 200: `curl localhost:8080/api/new-endpoint`

#### Manual Verification:
- [ ] New feature appears correctly in the UI
- [ ] Performance is acceptable with 1000+ items
- [ ] Error messages are user-friendly
- [ ] Feature works correctly on mobile devices
```

## Common Patterns

### For Database Changes:
- Start with schema/migration
- Add store methods
- Update business logic
- Expose via API
- Update clients

### For New Features:
- Research existing patterns first
- Start with data model
- Build backend logic
- Add API endpoints
- Implement UI last

### For Refactoring:
- Document current behavior
- Plan incremental changes
- Maintain backwards compatibility
- Include migration strategy

## Sub-task Spawning Best Practices

When spawning research sub-tasks:

1. **Spawn multiple tasks in parallel** for efficiency
2. **Each task should be focused** on a specific area
3. **Provide detailed instructions** including:
   - Exactly what to search for
   - Which directories to focus on
   - What information to extract
   - Expected output format
4. **Be EXTREMELY specific about directories**:
   - Include the full path context in your prompts
5. **Specify read-only tools** to use
6. **Request specific file:line references** in responses
7. **Wait for all tasks to complete** before synthesizing
8. **Verify sub-task results**:
   - If a sub-task returns unexpected results, spawn follow-up tasks
   - Cross-check findings against the actual codebase
   - Don't accept results that seem incorrect

Example of spawning multiple tasks:
```python
# Spawn these tasks concurrently:
tasks = [
    Task("Research database schema", db_research_prompt),
    Task("Find API patterns", api_research_prompt),
    Task("Investigate UI components", ui_research_prompt),
    Task("Check test patterns", test_research_prompt)
]
```

## Example Interaction Flow

```
User: /create_plan #1
Assistant: Let me fetch that GitHub issue and understand what we're building...

[Fetches issue with gh issue view 1]

Based on the issue, I understand we need to create a /research_requirements command for greenfield projects. Let me research the codebase to understand the existing patterns...

[Spawns research agents]

I've found the existing research_codebase.md command which follows a specific pattern. Before I start planning, I have some questions...

[Interactive process continues...]
```