# [Your Project Name Here]

> **⚠️ POST-TEMPLATE SETUP REQUIRED**
>
> You've created a project from the `claude-code-flow` template. **Replace this README** with your project documentation after setup.
>
> **Setup Instructions**: Follow [docs/TEMPLATE_SETUP.md](docs/TEMPLATE_SETUP.md) to configure your development environment.

---

## About This Template

This project uses the **Claude Code Flow** template for structured AI-assisted development. It provides:

- **Manual workflow** - Step-by-step commands (`/research_requirements`, `/create_plan`, `/implement_plan`)
- **Autonomous workflow** - Ralph Wiggum autonomous loop (`/ralph`) for unattended multi-issue processing
- **Research → Plan → Implement → Validate** pattern for quality development

## Quick Start

1. **Follow setup guide**: [docs/TEMPLATE_SETUP.md](docs/TEMPLATE_SETUP.md)
2. **Update this README**: Replace with your project documentation
3. **Update CLAUDE.md**: Add project-specific conventions
4. **Create your first issue**: `gh issue create --title "Your first feature"`
5. **Start developing**: Use `/research_requirements #1` or `/create_plan #1`

---

## Workflow Overview

### Manual Step-by-Step

**Greenfield (new features):**
```
/research_requirements → /create_plan → /implement_plan → /validate_plan → /commit
```

**Brownfield (existing codebase):**
```
/research_codebase → /create_plan → /implement_plan → /validate_plan → /commit
```

### Autonomous Loop

```
/ralph              # Process up to 10 issues automatically
/ralph 5            # Process up to 5 issues
```

Ralph automatically handles: Research → Plan → Implement → Validate → PR for each issue.

---

## Available Commands

### Research Phase

- **`/research_requirements`** - Research requirements and tech choices for new features
- **`/research_codebase`** - Document existing codebase patterns and architecture

### Planning Phase

- **`/create_plan`** - Create detailed implementation plans with phased approach
- **`/iterate_plan`** - Update existing plans based on new requirements

### Implementation Phase

- **`/implement_plan`** - Execute plans phase by phase with verification checkpoints
- **`/validate_plan`** - Validate implementation matches plan (quality gate before commit)

### Commit & PR Phase

- **`/commit`** - Create git commits with user approval
- **`/autonomous_commit`** - Create commits without approval (for autonomous workflows)
- **`/describe_pr`** - Generate comprehensive PR descriptions from templates

### Autonomous Workflow

- **`/ralph`** - Autonomous issue processing loop (Research → Plan → Implement → Validate → PR)

### Session Management

- **`/create_handoff`** - Create handoff document for transferring work to another session
- **`/resume_handoff`** - Resume work from handoff document with context

---

## Feature Branch Workflow

All development uses feature branches:

```bash
# Create feature branch from issue
git checkout -b feature/42-your-feature-name

# Do your work using Claude Code commands
/create_plan #42
/implement_plan thoughts/plans/2026-02-03-gh-42-your-feature.md
/validate_plan thoughts/plans/2026-02-03-gh-42-your-feature.md

# Commit and create PR
/commit
git push -u origin feature/42-your-feature-name
gh pr create --base main --draft
/describe_pr
```

See [docs/TEMPLATE_SETUP.md](docs/TEMPLATE_SETUP.md) for branch protection setup.

---

## Documentation

- **[docs/TEMPLATE_SETUP.md](docs/TEMPLATE_SETUP.md)** - Complete setup guide (prerequisites, hooks, branch protection)
- **[docs/claude-code-workflow-concepts.md](docs/claude-code-workflow-concepts.md)** - Workflow methodology and principles
- **[CLAUDE.md](CLAUDE.md)** - Instructions for Claude Code (update with your project conventions)

---

## Directory Structure

```
your-project/
├── .claude/              # Commands, skills, hooks configuration
├── .ralph/               # Autonomous workflow state
├── thoughts/             # Research documents and implementation plans
│   ├── research/         # Requirements and codebase research
│   ├── plans/            # Implementation plans
│   └── prs/              # PR descriptions
├── docs/                 # Documentation
├── src/                  # YOUR SOURCE CODE (add this)
├── tests/                # YOUR TESTS (add this)
└── [your project files]  # YOUR PROJECT STRUCTURE (add this)
```

---

## Using @claude in Pull Requests

After creating PRs, @mention Claude in PR comments for code reviews:

```
@claude Review this PR for code quality and potential issues
@claude What do you think about the architecture decisions?
@claude Are there any edge cases we might have missed?
```

Claude will respond with feedback and may suggest improvements to `CLAUDE.md` based on patterns it observes.

---

## Ralph Autonomous Development

For fully autonomous multi-issue processing:

```bash
# Using the /ralph command
/ralph 10              # Process up to 10 issues

# Using the shell script
./ralph-autonomous.sh --monitor    # Launch with live dashboard
./ralph-autonomous.sh --dry-run    # Preview without making changes
```

Ralph automatically:
1. Selects highest priority open issue
2. Creates research if missing
3. Creates plan if missing
4. Implements the plan
5. Validates implementation
6. Creates PR if validation passes
7. Moves to next issue

See [docs/TEMPLATE_SETUP.md](docs/TEMPLATE_SETUP.md) for GitHub label prerequisites.

---

## License

[Add your license here]

---

## Contributing

[Add your contribution guidelines here]

---

**Remember**: This README is a template placeholder. Replace it with documentation specific to your project after completing setup!
