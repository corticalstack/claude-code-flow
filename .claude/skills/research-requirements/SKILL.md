---
name: research-requirements
description: Research requirements, technology choices, and constraints for a feature or project and write findings under flow/research/. Explicit workflow command; run only when invoked via /research-requirements or explicitly asked.
argument-hint: [issue-url-or-description]
model: opus
disable-model-invocation: true
---

# Research Requirements

You are tasked with researching requirements for new projects or features. This is the first step in the Research → Plan → Implement workflow, used when starting work that doesn't require understanding an existing codebase.

This command researches and documents:
- Project requirements and constraints
- Technology choices and trade-offs
- Architecture considerations
- External dependencies and existing solutions

## Initial Setup

When this command is invoked:

1. **Check if parameters were provided**:
   - If a tracker URL or project description was provided, proceed immediately
   - Read/fetch input FULLY before spawning sub-tasks

2. **If no parameters provided**, respond with:
```
I'm ready to research requirements for a new project or feature. Please provide:
- A project description, OR
- An issue / work-item URL with requirements (any supported tracker)

I'll research technology options, constraints, and existing solutions to inform planning.
```

Then wait for user input.

## Steps to follow after receiving input:

### Step 1: Parse Input Source

- If a tracker URL or work-item id was provided:
  - Fetch the work-item content: `tracker view <id> --json title,body,state,comments`
  - Transition state: `tracker set-state <id> research-in-progress`
- If plain text: use as-is
- **CRITICAL**: Read/fetch input FULLY before spawning sub-tasks

Extract:
- Core requirements
- Constraints mentioned
- Technology preferences (if any)
- Success criteria

### Step 2: Decompose Research Areas

Break requirements into researchable components:
- Identify functional requirements
- Identify non-functional requirements (performance, security, etc.)
- Identify technology domains needing research

Create a research plan using TodoWrite to track exploration tasks.

### Step 3: Spawn Parallel Sub-Agents

Use these agent types concurrently to research different aspects:

| Agent | Purpose |
|-------|---------|
| `web-search-researcher` | Technology options, best practices, similar projects |
| `flow-locator` | Find existing research in flow/ directory |
| `flow-analyzer` | Extract insights from relevant historical docs (if locator finds any) |

Run multiple agents in parallel for different research areas. Example:

```
# Spawn concurrently:
- web-search-researcher: "Research [technology domain 1] options for [use case]"
- web-search-researcher: "Research [technology domain 2] best practices"
- web-search-researcher: "Find similar open source projects for [description]"
- flow-locator: "Find any existing research or decisions about [relevant topics]"
```

**Note on flow agents**: Always include these agents. The `flow/` directory accumulates historical context over time. For early research cycles, agents may report "no prior research found" - this is expected and still useful information.

### Step 4: Wait and Synthesize

- **CRITICAL**: Wait for ALL sub-agents to complete before proceeding
- Compile findings across all sources
- Identify technology trade-offs and recommendations
- Note open questions requiring user input
- Identify any conflicting recommendations

### Step 5: Gather Metadata

Collect metadata for the output document:
- Get current date: `date -Iseconds`
- Get git commit hash: `git rev-parse HEAD`
- Get current branch: `git branch --show-current`
- Get repository name: `basename $(git rev-parse --show-toplevel)`
- Extract tracker work-item id (if applicable)

Generate filename using this convention:
```
flow/research/YYYY-MM-DD-gh-[issue-number]-[description].md
```

- `YYYY-MM-DD` - today's date
- `gh-[issue-number]` - tracker work-item id (omit if no work item; the literal "gh-" prefix is a stable filename convention)
- `[description]` - brief kebab-case description

Examples:
- With issue: `flow/research/2026-01-12-gh-1-research-requirements-command.md`
- Without issue: `flow/research/2026-01-12-dotfile-manager-requirements.md`

### Step 6: Generate Research Document

Write the research document with this structure:

```markdown
---
date: [ISO timestamp with timezone]
researcher: claude
git_commit: [current hash]
branch: [current branch]
repository: [repo name]
github_issue: [issue number or null]
topic: "[Project/Feature Name] Requirements Research"
tags: [research, requirements, relevant-tech-tags]
status: complete
---

# Requirements Research: [Project/Feature Name]

## Original Request
[User's input or tracker work-item content]

## Summary
[High-level findings and recommendations - 2-3 paragraphs]

## Functional Requirements
- Requirement 1
- Requirement 2
- ...

## Non-Functional Requirements
- Constraint 1 (e.g., performance, security, scalability)
- Constraint 2
- ...

## Technology Options

### [Domain 1, e.g., "Database"]
| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Option A | ... | ... | ... |
| Option B | ... | ... | ... |

### [Domain 2, e.g., "Framework"]
| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Option A | ... | ... | ... |

## Existing Solutions
[Similar projects and approaches from web research]
- [Project/Library Name](url) - Description and relevance
- [Another Resource](url) - Description

## Historical Context (from flow/)
[Relevant past research or decisions, or "No prior research found" for early cycles]

## Open Questions
[Items requiring user clarification before planning]
- Question 1
- Question 2

## Recommended Next Steps
1. Resolve open questions above
2. Run `/create-plan` with this research document
```

### Step 7: Present and Confirm

After writing the document:

1. **Transition the work-item state** (if applicable):
   - `tracker set-state <id> research-complete research-in-progress`

2. **Present summary to user**:
```
I've completed the requirements research and written the findings to:
`flow/research/[filename].md`

Key findings:
- [Most important finding 1]
- [Most important finding 2]
- [Most important finding 3]

Technology recommendations:
- [Domain]: [Recommended option] because [reason]

Open questions requiring your input:
- [Question 1]
- [Question 2]

Please review the research document. Once you've resolved any open questions, you can proceed with `/create-plan` to design the implementation.
```

3. **Wait for user confirmation** before any next steps
4. **Do NOT automatically proceed to planning**

## Important Notes

### Critical Ordering
1. Always read/fetch input FULLY before spawning sub-agents
2. Always wait for ALL sub-agents to complete before synthesizing
3. Always gather real metadata (don't use placeholders)
4. Always present findings and wait for user confirmation

### What NOT To Do

- **DO NOT write any implementation code** - this is research only
- **DO NOT create a plan** - that's `/create-plan`'s job
- **DO NOT make final technology decisions** - present options with trade-offs
- **DO NOT skip user confirmation** - always present findings for review
- **DO NOT pollute main context** - use sub-agents for heavy research
- **DO NOT proceed to planning automatically** - wait for user approval
- **DO NOT use placeholder values** - gather real metadata before writing
- **DO NOT skip flow agents** - always include them, they handle empty results gracefully

## References

- Pattern reference: [`.claude/skills/research-codebase/SKILL.md`](.claude/skills/research-codebase/SKILL.md)
- Workflow concepts: [`docs/claude-code-workflow-concepts.md`](docs/claude-code-workflow-concepts.md)
- Output directory: `flow/research/`
