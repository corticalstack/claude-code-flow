# Claude Code Flow

A template repository for advanced Claude Code development workflows. Build code **manually step-by-step** with `.claude` commands, or run **fully autonomous** multi-issue development loops with `.ralph` (Ralph Wiggum approach). Both follow the Research → Plan → Implement → Validate pattern.

## Using This Template

This is a **GitHub template repository** - click the green "Use this template" button at the top of this page to create a new repository with this workflow structure.

> **Important**: `claude-code-flow` is the **template** repository. When you click "Use this template", you'll create a **new repository** with your own project name (e.g., `my-awesome-app`). All instructions below apply to your new project repository, not this template.

### Quick Start

1. **Create from template**: Click "Use this template" → "Create a new repository"
   - Name it after your project (e.g., `my-awesome-app`, not `claude-code-flow`)
2. **Clone locally**: `git clone git@github.com:YOUR_USERNAME/YOUR_REPO_NAME.git`
3. **Follow setup guide below**: Complete the [Prerequisites](#prerequisites) and [Step-by-Step Setup Guide](#step-by-step-setup-guide)
4. **Start using workflow commands**: Begin with `/research_requirements` or `/create_plan`

### What This Template Includes

This template provides **workflow infrastructure** only - no example project code:

| Directory/File | Purpose |
|----------------|---------|
| `.claude/` | Claude Code commands, skills, and configuration |
| `.ralph/` | Ralph autonomous workflow state and logs |
| `thoughts/` | Empty directory structure for research and plans |
| `docs/` | Workflow methodology documentation |
| `.github/` | PR templates, CODEOWNERS, GitHub Actions |
| `ralph-autonomous.sh` | Shell script for autonomous issue processing |
| `.tmux.ralph.conf` | Monitoring dashboard configuration |

### What You Need to Add

After creating from this template, add your own:

- **Source code** in `src/` or your preferred structure
- **Tests** in `tests/` or your preferred location
- **Dependencies** via `pyproject.toml`, `package.json`, `go.mod`, etc.
- **Build/run commands** in README and CLAUDE.md

The workflow adapts to any language or project structure.

---

## Overview

This template provides a structured workflow for using Claude Code effectively on software projects. It works for:

- **New projects** - Brand new repositories starting from scratch
- **Brownfield projects** - Existing codebases requiring new features, bug fixes, or refactoring

The workflow follows a **Research → Plan → Implement → Validate** pattern with dedicated commands for each phase.

## Workflow at a Glance

**Greenfield (new features):**
```
/research_requirements → /create_plan → /implement_plan → /validate_plan → /commit
```

**Brownfield (existing codebase):**
```
/research_codebase → /create_plan → /implement_plan → /validate_plan → /commit
```

See [Commands](#commands) for detailed documentation of each command.

## Prerequisites

Before setting up the workflow, ensure you have:

1. **Git repository** - New or existing, with a GitHub remote configured
2. **GitHub CLI** - See [GitHub CLI Setup](#github-cli-setup) below
3. **Claude Code** - Installed and configured
4. **Python environment** - See [Python Environment Setup (UV)](#python-environment-setup-uv) below (required for auto-formatting hooks)

### GitHub CLI Setup

The workflow uses the GitHub CLI (`gh`) for issue and PR management. This is required for commands like `/create_plan`, `/describe_pr`, and others that interact with GitHub.

#### Install GitHub CLI

Download and install from https://cli.github.com or use your package manager, e.g.:

```bash
# Ubuntu/Debian
sudo apt install gh
```

Verify installation:
```bash
gh --version
```

#### Authenticate GitHub CLI

```bash
# Start interactive authentication
gh auth login
```

Follow the prompts to:
1. Select `GitHub.com`
2. Choose your preferred protocol (SSH recommended)
3. Authenticate via browser or token

Verify authentication:
```bash
gh auth status
```

You should see output showing your account and token scopes including `repo`.

### Python Environment Setup (UV)

The workflow hooks use Python tools like `black` for auto-formatting. We recommend [UV](https://docs.astral.sh/uv/) - a fast, modern Python package manager written in Rust that's 10-100x faster than pip.

#### 1. Check if UV is Installed

```bash
which uv && uv --version || echo "UV not installed"
```

#### 2. Install or Update UV

**If UV is not installed:**
```bash
# Install uv (Linux/macOS)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**If UV is already installed, update to latest:**
```bash
uv self update
```

#### 3. Initialize Python Environment

In your project directory:

```bash
# Initialize a new Python project (creates pyproject.toml and .venv)
uv init

# Or if pyproject.toml already exists, just sync
uv sync
```

#### 4. Add Black for Auto-Formatting

Install the Python formatter used by the auto-format hooks:

```bash
# Add black as a dev dependency
uv add black --dev
```

#### 5. Verify Black is Installed

```bash
uv run black --version
```

#### Using UV

UV automatically manages virtual environments. You don't need to activate them manually:

```bash
# Run any command in the virtual environment
uv run black myfile.py
uv run python script.py

# Add more packages
uv add requests
uv add pytest --dev
```

If you prefer activating the environment manually (traditional workflow):
```bash
source .venv/bin/activate
black --version
```

#### Why UV over pip/poetry?

- **Speed**: 10-100x faster than pip, with aggressive caching
- **Simplicity**: Drop-in replacement for pip (`uv pip install` works)
- **All-in-one**: Manages Python versions, virtual environments, and dependencies
- **Standards-based**: Uses `pyproject.toml`, compatible with existing tooling

---

## Branch Protection Setup

**Configure branch protection before starting development work.** This enforces the feature branch + PR workflow and prevents accidental commits directly to main.

### Why Protect Main?

Branch protection ensures:
- All changes go through pull requests with code review
- CI/CD checks (tests, linting) pass before merging
- Clear audit trail of what changed, why, and who approved it
- Safety net preventing accidental force pushes or breaking changes

### Check if Main Branch Exists

**Important:** In a new repository, the main branch doesn't exist until you make your first commit.

```bash
# Check if main branch exists
git branch -a | grep main
```

If you see `main` or `origin/main`, the branch exists. If not, create it:

```bash
# Option 1: If you have commits but no main branch yet
# (e.g., you started on a feature branch)
git branch main HEAD
git push -u origin main

# Option 2: If this is a brand new empty repo
# Create an initial commit first
git add README.md
git commit -m "Initial commit"
git branch -M main
git push -u origin main
```

Set main as the default branch (if not already):
```bash
gh repo edit --default-branch main
```

### Configure Branch Protection Rules

Once main exists, configure protection rules via GitHub CLI:

```bash
# Create branch protection with PR requirements
# Replace YOUR_USERNAME/YOUR_REPO_NAME with your actual repo:
gh api repos/YOUR_USERNAME/YOUR_REPO_NAME/branches/main/protection \
  --method PUT \
  --input - <<EOFINNER
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null
}
EOFINNER
```

**Note:** For solo projects, you can set `"required_approving_review_count": 0` to allow self-merge (still requires PR, but no approval needed).

**Or configure via GitHub UI:**

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Branches**
3. Under "Branch protection rules", click **Add rule** (or edit existing rule)
4. For "Branch name pattern", enter: `main`
5. Enable these settings:
   - ✅ **Require a pull request before merging**
     - Require approvals: 1 (or 0 for solo projects to allow self-merge)
     - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ **Do not allow bypassing the above settings**
6. Click **Create** or **Save changes**

### Verify Branch Protection

```bash
# Check protection status
gh api repos/YOUR_USERNAME/YOUR_REPO_NAME/branches/main/protection

# Or use placeholders (auto-filled from current repo)
gh api repos/:owner/:repo/branches/main/protection

# Or use GitHub UI: Settings → Branches → View rule details
```

You should see the main branch listed with a "Protected" badge.

### Working with Protected Main

Once protected, you **cannot** push directly to main:

```bash
git push origin main
# remote: error: GH006: Protected branch update failed
```

Instead, all work must go through feature branches and pull requests (see [Feature Branch Workflow](#feature-branch-workflow)).

### Automatic Reviewer Assignment

**Ensure all PRs have reviewers assigned automatically** using a CODEOWNERS file. This works for PRs created manually, by Claude Code, or through automation.

#### Why Auto-assign Reviewers?

- Ensures no PR is forgotten or left unreviewed
- Works consistently across all PR creation methods (CLI, Claude Code, GitHub Actions)
- Single source of truth for who reviews what
- Integrates seamlessly with GitHub's review workflow

#### Setup CODEOWNERS

Create `.github/CODEOWNERS` to automatically request reviews:

```bash
# Create .github directory if it doesn't exist
mkdir -p .github

# Create CODEOWNERS file
cat > .github/CODEOWNERS << 'EOFINNER'
# CODEOWNERS
#
# Automatically request code review from repository owner for all changes.
# This ensures all PRs have a reviewer assigned, whether created manually
# via gh CLI, by Claude Code, or through GitHub Actions.

# Default owner for everything in the repo
* @corticalstack
EOFINNER
```

**Replace `@corticalstack` with your GitHub username.**

**How it works:**
- When any PR is created, GitHub automatically requests review from the specified user
- Applies to all files (`*` pattern) in the repository
- Works immediately—no additional configuration needed

#### Alternative Approaches

If CODEOWNERS doesn't fit your workflow, consider:

1. **Update `/describe_pr` command** - Add `--reviewer @me` flag when creating PRs in `.claude/commands/describe_pr.md`

2. **GitHub Actions automation** - Create `.github/workflows/auto-assign-reviewer.yml`:
   ```yaml
   name: Auto-assign Reviewer
   on:
     pull_request:
       types: [opened, ready_for_review]
   jobs:
     assign:
       runs-on: ubuntu-latest
       steps:
         - run: gh pr edit ${{ github.event.pull_request.number }} --add-reviewer ${{ github.repository_owner }}
           env:
             GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
   ```

**Recommendation:** Use CODEOWNERS for simplicity and consistency across all PR creation methods.

---

## Step-by-Step Setup Guide

### Step 1: Verify Directory Structure

After creating from the template, your project will have this structure:

```
your-project/
├── .claude/
│   ├── commands/           # Claude Code slash commands
│   ├── skills/             # Reusable skill definitions
│   └── settings.json       # Hooks configuration
├── .ralph/
│   ├── state/              # Ralph autonomous state tracking
│   └── active/             # Per-issue logs and feedback
├── thoughts/
│   ├── research/           # Research output documents (empty)
│   ├── plans/              # Implementation plans (empty)
│   └── prs/                # PR descriptions (empty)
├── docs/                   # Workflow documentation
├── .github/
│   ├── workflows/          # GitHub Actions (claude.yml)
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
├── ralph-autonomous.sh     # Autonomous loop script
├── .tmux.ralph.conf        # Monitoring dashboard config
├── README.md               # This file
└── CLAUDE.md               # Claude Code instructions
```

**What's missing?** Your source code! Add:
- `src/` or your preferred code directory
- `tests/` or your preferred test location
- `pyproject.toml`, `package.json`, or your dependency file
- Build/run scripts specific to your project

---

## Step 2:  Git Configuration (Optional)

You can choose whether to track `thoughts/` in version control:

**Option A: Track thoughts for team collaboration**
```bash
# Add and commit the thoughts directory
git add thoughts/
git commit -m "Add thoughts directory for workflow artifacts"
```

**Option B: Exclude thoughts from version control**
```bash
# Add to .gitignore
echo "thoughts/" >> .gitignore
```

---

## Step 3: Configure Hooks

Claude Code hooks automate common tasks and protect sensitive files. The hooks configuration lives in [`.claude/settings.json`](.claude/settings.json).

### What the Hooks Do

| Hook Type | Trigger | Purpose |
|-----------|---------|---------|
| **PreToolUse** | Before Edit/Write | Blocks modifications to sensitive files (.env, credentials, secrets, .git/) |
| **PostToolUse** | After Edit/Write | Auto-formats JS/TS files with Prettier, Python files with Black |
| **Notification** | When Claude needs input | Desktop notification (Linux `notify-send`) |

### Why These Hooks Matter

1. **Security**: The PreToolUse hook prevents accidental exposure of secrets by blocking edits to sensitive files. Claude will be stopped before it can write to `.env`, `credentials.json`, or similar files.

2. **Code Quality**: Auto-formatting ensures consistent code style without manual intervention. Every file edit is automatically formatted according to project standards.

3. **Workflow**: Desktop notifications alert you when Claude needs your attention, useful during long-running operations.

### Prerequisites for Hooks

The auto-format hooks require formatters to be installed. If you followed [Python Environment Setup (UV)](#python-environment-setup-uv), black is already installed.

```bash
# Python formatting (already done if you followed UV setup)
uv add black --dev

# JavaScript/TypeScript formatting (if needed)
npm install --save-dev prettier
```

If these tools aren't installed, the hooks will silently skip formatting (they won't cause errors).

### Testing the Hooks

After configuring hooks, **restart your Claude Code session** for changes to take effect.

#### Test PreToolUse (File Protection)

Ask Claude to create a `.env` file:

```
Create a .env file with TEST_VAR=hello
```

**Expected result**: Claude should be blocked with an error:
```
PreToolUse:Write hook error: [python3 -c "..."]: No stderr output
```

#### Test PostToolUse (Auto-Formatting)

Ask Claude to create a badly formatted Python file:

```
Create a file called test_format.py with this exact content:
def ugly(x,y,z):return x+y+z
```

**Expected result**: The file is created and automatically formatted by black:
```python
def ugly(x, y, z):
    return x + y + z
```

You can verify by reading the file - it should be properly formatted despite the ugly input.

#### Test Notification Hook

The notification hook alerts you when Claude needs attention. The default configuration tries Linux first, then falls back to WSL/Windows.

Test notifications manually:
```bash
# Linux
notify-send 'Claude Code' 'Test notification'

# WSL/Windows
powershell.exe -Command "[System.Windows.Forms.MessageBox]::Show('Test','Claude Code')"

# macOS
osascript -e 'display notification "Test" with title "Claude Code"'
```

**Expected result**: A desktop notification or message box appears.

### Customizing Hooks

Edit [`.claude/settings.json`](.claude/settings.json) to customize:

- **Add file types**: Extend the PostToolUse patterns for other languages
- **Change formatters**: Replace Prettier/Black with your preferred tools
- **Adjust blocked files**: Modify the PreToolUse blocked list for your project
- **Change notifications**: Replace with platform-specific command (see test examples above)

---

## Important: Command Caching Behavior

Claude Code loads command files (`.claude/commands/*.md`) into memory when a session starts. This means:

**If you edit a command file during a session, the changes won't take effect until you restart Claude Code.**

This applies to:
- Creating new commands
- Modifying existing commands
- Renaming or deleting commands

### Symptoms of Stale Cache

If you edit a command and it still behaves the old way:
- The Skill tool loaded the in-memory (stale) version
- Your file edits are correct on disk but not loaded

### Solution

Restart your Claude Code session after modifying any files in `.claude/commands/`.

```bash
# Exit Claude Code (Ctrl+C or /exit)
# Then restart it
claude
```

This ensures all command files are freshly loaded from disk.

---

## Feature Branch Workflow

All development work should be done on feature branches, not directly on `main`. This keeps your main branch stable and makes it easy to create pull requests.

### When to Create a Feature Branch

**Create your feature branch BEFORE starting research or planning.** This ensures all artifacts (research documents, plans, and code) are created on the feature branch, making your PR self-contained.

### Branch Naming Convention

```bash
feature/<issue-number>-<brief-description>
```

Examples:
- `feature/42-add-authentication`
- `feature/7-configurable-system-prompt`
- `feature/123-fix-memory-leak`

### Typical Workflow

#### For New Features (Greenfield)

```bash
# 1. Create GitHub issue first
gh issue create --title "Add feature X" --body "Description..."

# 2. Create feature branch immediately
git checkout -b feature/42-add-feature-x

# 3. Research requirements
/research_requirements #42

# 4. Create implementation plan
/create_plan thoughts/research/2026-01-13-gh-42-add-feature-x.md

# 5. Implement the plan
/implement_plan thoughts/plans/2026-01-13-gh-42-add-feature-x.md

# 6. Validate implementation
/validate_plan thoughts/plans/2026-01-13-gh-42-add-feature-x.md

# 7. Commit changes
/commit

# 8. Push and create PR
git push -u origin feature/42-add-feature-x
gh pr create --base main --draft
/describe_pr
```

#### For Existing Codebases (Brownfield)

```bash
# 1. Create GitHub issue first
gh issue create --title "Add new endpoint" --body "Description..."

# 2. Create feature branch immediately
git checkout -b feature/7-new-endpoint

# 3. Research the codebase
/research_codebase #7

# 4. Create implementation plan
/create_plan thoughts/research/2026-01-13-gh-7-new-endpoint.md

# 5. Implement the plan
/implement_plan thoughts/plans/2026-01-13-gh-7-new-endpoint.md

# 6. Validate implementation
/validate_plan thoughts/plans/2026-01-13-gh-7-new-endpoint.md

# 7. Commit changes
/commit

# 8. Push and create PR
git push -u origin feature/7-new-endpoint
gh pr create --base main --draft
/describe_pr
```

### Why Create the Branch Early?

Creating the branch before research/planning has several benefits:
- **Self-contained PRs**: All work artifacts, including thoughts, live on the feature branch
- **Clean history**: Research and planning commits don't pollute main
- **Easy cleanup**: Abandoned branches can be deleted without affecting main
- **Parallel work**: Multiple features can be researched simultaneously on different branches

### Note on `/ralph` (Autonomous Loop)

The `/ralph` command automatically creates feature branches for each issue it processes. You only need to manually create branches when using the commands individually.

---

## Commands

The workflow provides slash commands for each phase of the Research → Plan → Implement pattern.

### `/research_requirements`

> Implementation: [`.claude/commands/research_requirements.md`](.claude/commands/research_requirements.md)

Researches requirements, technology choices, and constraints for new projects or features.

```
/research_requirements <project description or GitHub issue URL>
```

**Examples:**
```
/research_requirements
/research_requirements Build a CLI tool for managing dotfiles
/research_requirements https://github.com/owner/repo/issues/123
```

**What it does:**
- Fetches requirements from GitHub issues (if URL provided)
- Spawns parallel agents to research technology options, existing solutions, and best practices
- Checks `thoughts/` for relevant historical context
- Produces a structured requirements document in `thoughts/research/`

**What it does NOT do:**
- Write implementation code
- Create plans (that's [`/create_plan`](#create_plan))
- Make final technology decisions (presents options with trade-offs)

#### Example Output

Research documents are saved to `thoughts/research/` with the naming convention:
- With issue: `YYYY-MM-DD-gh-[issue]-[description].md`
- Without issue: `YYYY-MM-DD-[description].md`

### `/create_plan`

> Implementation: [`.claude/commands/create_plan.md`](.claude/commands/create_plan.md)

Creates detailed implementation plans through an interactive, iterative process. The command is collaborative - it will ask clarifying questions and iterate on the plan structure before writing the final document.

```
/create_plan <argument>
```

#### Accepted Arguments

| Argument Type | Example | Description |
|--------------|---------|-------------|
| No argument | `/create_plan` | Interactive mode - prompts for issue or description |
| GitHub issue number | `/create_plan #123` | Fetches issue via `gh issue view` |
| GitHub issue URL | `/create_plan https://github.com/owner/repo/issues/123` | Fetches issue content |
| Research document path | `/create_plan thoughts/research/2026-01-12-gh-3-feature-name.md` | Uses existing research as input |
| Task description | `/create_plan Build a REST API for user management` | Free-form description |

#### Examples

**From a GitHub issue:**
```
/create_plan #3
```

**From a research document (recommended workflow):**
```
# First, research the requirements
/research_requirements #3

# Then create a plan from the research output
/create_plan thoughts/research/2026-01-12-gh-3-fastapi-streaming-chat-backend.md
```

**Interactive mode:**
```
/create_plan
# Claude will ask: "Please provide a GitHub issue URL or task description..."
```

#### Typical Workflow

1. **Research first**: Run `/research_requirements #123` → produces `thoughts/research/YYYY-MM-DD-gh-123-description.md`
2. **Create plan**: Run `/create_plan thoughts/research/YYYY-MM-DD-gh-123-description.md` → uses research to create plan
3. **Interactive refinement**: Claude presents plan structure, asks clarifying questions, iterates based on feedback
4. **Final output**: Plan written to `thoughts/plans/YYYY-MM-DD-gh-123-description.md`

#### Output

Plans are written to `thoughts/plans/` with the naming convention:
- With issue: `YYYY-MM-DD-gh-[issue]-[description].md`
- Without issue: `YYYY-MM-DD-[description].md`

Each plan includes:
- Overview and current state analysis
- Phased implementation with TDD structure (tests before implementation)
- Success criteria (automated and manual verification)
- What's explicitly out of scope

**What it does:**
- Reads research documents or fetches GitHub issue content
- Spawns research agents to understand relevant codebase patterns
- Guides you through requirements clarification interactively
- Produces a phased implementation plan in `thoughts/plans/`

**What it does NOT do:**
- Write implementation code (that's [`/implement_plan`](#implement_plan))
- Make decisions without user input
- Skip verification steps

#### Example Workflow

The typical flow from research to plan:

1. Run `/research_requirements #123` → produces `thoughts/research/YYYY-MM-DD-gh-123-feature-name.md`
2. Run `/create_plan thoughts/research/YYYY-MM-DD-gh-123-feature-name.md` → produces `thoughts/plans/YYYY-MM-DD-gh-123-feature-name.md`
3. Plan is ready for `/implement_plan`

### `/implement_plan`

> Implementation: [`.claude/commands/implement_plan.md`](.claude/commands/implement_plan.md)

Executes implementation plans phase by phase with verification checkpoints.

```
/implement_plan <path to plan file>
```

**Example:**
```
/implement_plan thoughts/plans/2026-01-12-gh-1-feature-name.md
```

**What it does:**
- Reads the implementation plan
- Executes each phase sequentially
- Runs automated verification after each phase
- Pauses for manual verification before proceeding

**What it does NOT do:**
- Skip phases or verification steps
- Continue past failed verifications without approval
- Modify the plan without user consent

#### How Implementation Works

The `/implement_plan` command:
1. Reads your plan file from `thoughts/plans/`
2. Executes each phase sequentially
3. Follows TDD approach (tests first, then implementation)
4. Runs automated verification after each phase
5. Pauses for your approval before proceeding to the next phase

**Example**: A plan with 4 phases would execute as:
- Phase 1: Write tests → Implement → Verify → Wait for approval
- Phase 2: Write tests → Implement → Verify → Wait for approval
- Phase 3: Write tests → Implement → Verify → Wait for approval
- Phase 4: Write tests → Implement → Verify → Complete

### `/validate_plan`

> Implementation: [`.claude/commands/validate_plan.md`](.claude/commands/validate_plan.md)

Validates that implementation matches the plan and catches issues before committing. Acts as a quality gate between implementation and version control.

```
/validate_plan <path to plan file>
```

**Example:**
```
/validate_plan thoughts/plans/2026-01-12-gh-3-feature-name.md
```

**What it does:**
- Reads the implementation plan and identifies success criteria
- Analyzes uncommitted changes via `git diff`
- Runs all automated verification commands (build, tests, lint)
- Compares actual implementation against plan specifications
- Generates a validation report showing passes, failures, and deviations
- Lists manual testing steps still needed

**Why it comes before `/commit`:**

Validation acts as a **quality gate before committing** to ensure:
- All planned features are actually implemented
- Automated tests and checks pass
- No critical issues are introduced
- Cleaner git history without "fix validation issues" commits

By catching problems on uncommitted changes, you can fix issues immediately without polluting version control history with correction commits.

**What it does NOT do:**
- Make fixes automatically (presents findings for you to address)
- Modify the plan
- Create commits (that's [`/commit`](#commit))

### `/commit`

> Implementation: [`.claude/commands/commit.md`](.claude/commands/commit.md)

After implementation is complete and tests pass, use `/commit` to create git commits.

```
/commit
```

**What it does:**
- Reviews changes via `git status` and `git diff`
- Plans logical, atomic commits grouping related changes
- Presents the plan and asks for confirmation before committing
- Creates commits without Claude attribution (authored by you)

> **Tip:** For fully automated workflows (e.g., CI pipelines or `/ralph`), consider creating a variant `ci_commit.md` that never asks for feedback before committing. This enables uninterrupted autonomous operation.

#### Example Usage

After implementing your feature:

```
/commit
```

Claude will:
1. Analyze `git status` and `git diff` output
2. Group related changes into logical, atomic commits
3. Generate commit messages following your project conventions
4. Show you the plan and ask for confirmation
5. Create the commits (authored by you, not Claude)

### Pushing Changes

After committing, push your branch to the remote repository.

**Option 1: Via CLI**

```bash
# Push and set upstream (first push of a new branch)
git push -u origin feature/your-branch-name

# Subsequent pushes
git push
```

**Option 2: Ask Claude Code**

Simply ask Claude to push:

```
Push my commits to the remote
```

or

```
Push this branch to origin
```

Claude will run `git push` (or `git push -u origin <branch>` if no upstream is set) and report the result.

> **Note:** Claude Code respects git safety - it won't force push or push to protected branches without explicit confirmation.

### Creating a Pull Request

After pushing, create a pull request to merge your changes.

> **First-time setup:** If your repository doesn't have a `main` branch yet (e.g., you started work directly on a feature branch), you'll need to create one first:
> ```bash
> # Create main from an earlier commit (e.g., first commit)
> git branch main <commit-hash>
> git push -u origin main
>
> # Set main as default branch
> gh repo edit --default-branch main
> ```

**Option 1: Via CLI**

```bash
# Create a draft PR
gh pr create --base main --title "Your PR title" --body "Description" --draft

# Create a PR ready for review
gh pr create --base main --title "Your PR title" --body "Description"
```

**Option 2: Ask Claude Code**

```
Create a PR for this branch
```

Claude will use `gh pr create` and prompt you for title and description if needed.

### `/describe_pr`

> Implementation: [`.claude/commands/describe_pr.md`](.claude/commands/describe_pr.md)

Generates comprehensive PR descriptions following your repository's template.

```
/describe_pr
```

**What it does:**
- Reads your PR template from [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md)
- Analyzes the full diff and commit history
- Runs verification commands (tests, linting) and marks checklist items
- Generates a thorough description filling all template sections
- Saves the description to `thoughts/prs/{number}_description.md`
- Updates the PR directly via `gh pr edit`

**Example workflow:**

```bash
# 1. Create PR with minimal description (draft mode)
gh pr create --base main --title "Add feature X" --body "WIP" --draft

# 2. Generate comprehensive description
/describe_pr

# 3. PR is now updated with full description (still in draft)

# 4. Mark PR as ready for review (two options):
```

**Option 1: Via CLI**
```bash
gh pr ready <pr-number>
```

**Option 2: Via GitHub UI**
- Go to your PR page on GitHub
- Scroll to the bottom of the PR
- Click the green "Ready for review" button

**What it does NOT do:**
- Create the PR (use `gh pr create` or ask Claude first)
- Change draft status (PR remains draft until you mark it ready)
- Merge the PR
- Complete manual verification steps (leaves those unchecked for you)

### Using @claude in PR Reviews

After creating your PR, you can @mention Claude in PR comments to get code reviews, architectural feedback, and suggestions. Claude will respond directly in the PR using your Claude Code Max subscription.

**Example comments to try:**

```
@claude Review this PR for code quality and potential issues
```

```
@claude What do you think about the architecture decisions in this PR?
```

```
@claude Suggest improvements to CLAUDE.md based on patterns you see
```

```
@claude Are there any edge cases we might have missed in the validation logic?
```

```
@claude Review this PR with a focus on security concerns
```

**What happens:**
1. You add a comment mentioning @claude
2. The GitHub Action triggers automatically
3. Claude reviews your code and responds with feedback
4. Claude may suggest updates to `CLAUDE.md` for future improvements

**Workflow integration:**

```bash
# Complete development workflow
/implement_plan thoughts/plans/...    # Implement your feature
/commit                               # Create commits

# Push and create PR
git push -u origin feature/my-feature
gh pr create --base main --title "Add feature X" --body "WIP" --draft

# Generate comprehensive PR description
/describe_pr

# Get Claude's review
# In GitHub PR: @claude Review this PR for code quality and potential issues

# Claude responds with feedback - see below for handling action items
```

### Handling @claude Feedback

When @claude reviews your PR and suggests changes, follow this workflow:

#### 1. Review Claude's Feedback
- Read through all comments and suggestions
- Decide which feedback to address (you're the human - final call is yours)
- Prioritize critical issues (security, bugs) over suggestions (style, optimizations)

#### 2. Make Changes on the Feature Branch
Stay on your feature branch and make the recommended changes:

```bash
# Ensure you're on the correct branch
git checkout feature/your-branch-name

# Make changes to address feedback
# Edit files as needed
```

#### 3. Commit and Push Updates
```bash
# Commit your changes
git add <changed-files>
git commit -m "Address @claude feedback: <describe what you fixed>"

# Push to update the PR
git push
```

The PR automatically updates with your new commits.

#### 4. (Optional) Ask Claude to Verify
After making changes, you can ask Claude to verify:

```
@claude I've addressed your feedback in the latest commit. Can you verify the changes?
```

#### 5. Iterate Until Ready
Repeat steps 2-4 until all critical feedback is addressed. Then merge the PR.

**Example interaction:**
```
You: @claude Review this PR for security concerns

Claude: Found potential SQL injection in auth.py:42.
        Recommend using parameterized queries instead of string concatenation.

You: [Makes changes, commits, pushes]

You: @claude I've fixed the SQL injection issue. Please verify.

Claude: ✅ Looks good! The parameterized query properly prevents SQL injection.

You: [Merges PR]
```

**Important notes:**
- **Don't create new PRs for feedback** - update the existing branch
- **Don't squash commits prematurely** - keep feedback commits separate for clarity
- **Use descriptive commit messages** - reference what feedback you're addressing
- **Claude sees the full PR history** - it can track what changed between reviews

> **Tip:** Ask Claude to review with CLAUDE.md improvements in mind. This creates a feedback loop where each PR review can make your workflow better over time. When all good, ask Claude to merge the PR.

---

## Ralph Wiggum - Autonomous Development Loop

The [Ralph Wiggum technique](https://ghuntley.com/ralph/) is an AI development methodology created by Geoffrey Huntley that runs coding agents in a continuous loop until all tasks are complete. Named after the Simpsons character known for being simple but persistent.

### `/ralph`

> Implementation: [`.claude/commands/ralph.md`](.claude/commands/ralph.md)

Processes GitHub issues autonomously in a loop: **Research → Plan → Implement → Validate → PR → Next issue**

**Autonomous operation requires guardrails.** Unlike manual workflows where you review work before committing, Ralph runs unsupervised. The validation step acts as a quality gate, ensuring only working code enters version control and preventing wasted PR review time on broken implementations.

```
/ralph              # Process up to 10 issues (default)
/ralph 5            # Process up to 5 issues
```

**The loop for each issue:**

```
┌─────────────────────────────────────────────────────────────────────────┐
│  1. Pick highest priority open issue                                    │
│  2. Check for research → if missing, create it (like /research_requirements) │
│  3. Check for plan → if missing, create it (like /create_plan)          │
│  4. Implement the plan (like /implement_plan)                           │
│  5. Validate implementation (like /validate_plan)                       │
│  6. IF validation passes: Commit (like /commit) and create PR           │
│     IF validation fails: Label issue, skip to next (don't commit)       │
│  7. Move to next issue                                                  │
│  8. Repeat until no issues remain or max iterations reached             │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key features:**
- Reuses existing commands (`/research_requirements`, `/create_plan`, `/implement_plan`, `/validate_plan`, `/commit`)
- Maintains the Research → Plan → Implement → Validate pattern
- Quality gate: Only commits and creates PRs for implementations that pass validation
- Safety limit prevents runaway costs (default: 10 iterations)
- Creates feature branch and PR for each issue
- Moves on if stuck (doesn't loop forever on one issue or try to fix validation failures)

### How Ralph Prioritizes Issues

Ralph doesn't process issues in creation order. Instead, it uses a sophisticated prioritization system that considers dependencies, task types, and readiness.

#### Priority Levels

Ralph analyzes issue titles and descriptions to assign priority levels:

| Priority | Type | Description | Keywords |
|----------|------|-------------|----------|
| 1 | **Foundational** | Creates structure/setup that other work depends on | structure, setup, scaffold, foundation, infrastructure, base, initial, directory, layout |
| 2 | **Feature** | Core implementation work | implement, add, create, build, feature, api, client |
| 3 | **Integration** | Connects components together | integrate, integration, connect, wire up, link, combine, streaming, real-time |
| 4 | **Enhancement** | Improves existing functionality | improve, enhance, optimize, refactor, update, markdown, render |
| 5 | **Testing** | Requires other work to be complete | test, testing, e2e, qa, playwright, jest, coverage |

#### Dependency Blocking

Issues can be blocked by other issues using the `blocked-by-#` label:

```bash
# Mark issue #58 as blocked by issue #54
gh issue edit 58 --add-label "blocked-by-#54"
```

Ralph automatically:
- Detects `blocked-by-#` labels
- Checks if blocker issues are still open
- Skips blocked issues until blockers are resolved
- Removes the label when blocker is closed

#### Sorting Algorithm

Ralph selects issues using this multi-level sort:

1. **Priority** (ascending) - Lower number = higher priority
2. **Has plan** (`ready-for-dev` label) - Issues with approved plans first
3. **Has research** (`research-complete` label) - Researched issues before unresearched
4. **Issue number** (ascending) - Older issues first as tiebreaker

**Example queue order:**

```
Priority 1: #54 Frontend: Chat UI structure (Foundational)
Priority 2: #55 Frontend: API client integration (Feature, has plan)
Priority 2: #56 Frontend: Real-time streaming (Feature, has research)
Priority 2: #57 Frontend: Multi-turn conversation (Feature)
Priority 4: #58 Frontend: Markdown rendering (Enhancement)
```

Even though #58 was created first, it's processed last because enhancements have lower priority than foundational work and features.

#### Why Not Creation Date?

Processing issues by creation date (oldest first) ignores:
- **Dependencies** - Can't build features without foundation
- **Logical order** - Integration requires components to exist first
- **Efficiency** - Writing tests before the code exists wastes effort
- **Readiness** - Issues with plans are ready to implement now

Ralph's prioritization ensures work happens in a logical order that minimizes rework and blocked time.

> **Implementation**: Priority logic in [`lib/ralph_priority.sh`](lib/ralph_priority.sh), dependency checking in [`lib/ralph_github.sh`](lib/ralph_github.sh)

### `ralph-autonomous.sh` - Shell Script Interface

> Alternative to `/ralph` command: [`ralph-autonomous.sh`](ralph-autonomous.sh)

While `/ralph` runs within a Claude Code session, `ralph-autonomous.sh` is a standalone shell script that can run independently (e.g., in tmux, screen, or CI/CD pipelines). Both implement the same autonomous loop logic.

#### Usage Examples

| Command | Description | Use Case |
|---------|-------------|----------|
| `./ralph-autonomous.sh` | Run autonomous loop with default settings | Production autonomous execution |
| `./ralph-autonomous.sh --monitor` | Launch with real-time monitoring dashboard in tmux | Visual monitoring of long-running loops |
| `./ralph-autonomous.sh --monitor --dry-run` | Preview loop behavior with monitoring, no changes made | Test monitoring dashboard, verify loop logic |
| `./ralph-autonomous.sh --dry-run` | Show what would happen without making changes | Preview before running, debug loop logic |
| `./ralph-autonomous.sh --status` | Show current loop status and exit | Check progress of running instance |
| `./ralph-autonomous.sh --priorities` | Show prioritized issue list and exit | Review what Ralph will work on |
| `./ralph-autonomous.sh --reset-circuit` | Reset circuit breaker to CLOSED | Recover from repeated validation failures |
| `./ralph-autonomous.sh --reset-state` | Clear all state and start fresh | Start over from scratch |

#### What is Dry-Run Mode?

**Dry-run mode** (`--dry-run`) is a preview mode that shows what Ralph would do without making any actual changes.

**What dry-run DOES:**
- ✅ Select issues from GitHub in priority order
- ✅ Go through all phases (Research → Plan → Implement → Validate → PR)
- ✅ Show "[DRY RUN] Would invoke..." log messages for each action
- ✅ Update monitor status files (if using `--monitor`)
- ✅ Complete the full loop iteration

**What dry-run DOES NOT do:**
- ❌ Invoke Claude Code skills (`/research_codebase`, `/create_plan`, `/implement_plan`, `/validate_plan`)
- ❌ Make API calls to Claude (no cost incurred)
- ❌ Update GitHub issue labels
- ❌ Create git commits
- ❌ Create or modify branches
- ❌ Create pull requests
- ❌ Make any changes to your repository

**Use dry-run to:**
- Preview which issues Ralph will process and in what order
- Test the monitoring dashboard without making changes
- Verify loop logic after configuration changes
- Debug issues without side effects

#### Reset Commands

Ralph maintains state across runs to track progress, remember failures, and prevent infinite loops. Sometimes you need to reset this state.

##### `--reset-circuit` - Reset Circuit Breaker

**What it does:**
- Resets `.ralph/state/circuit_breaker.json` to initial state
- Sets circuit breaker state to `CLOSED` (normal operation)
- Clears all failure counters:
  - `consecutive_no_progress`: 0
  - `consecutive_same_error`: 0
  - `consecutive_validation_fails`: 0
- Updates `last_transition` timestamp

**When to use:**
- Circuit breaker is `OPEN` (halting execution)
- After 3+ consecutive validation failures
- After 5+ consecutive identical errors
- After 3+ attempts with no file changes (no progress)
- You've fixed underlying issues and want Ralph to retry

**What triggers the circuit breaker:**
- **No Progress**: 3 consecutive attempts with no files changed
- **Same Error**: 5 consecutive attempts with identical error messages
- **Validation Failures**: 3 consecutive failed validation attempts

**Example:**
```bash
# Check if circuit breaker is open
./ralph-autonomous.sh --status

# Output shows:
# Circuit Breaker: OPEN
#   - 3 consecutive validation failures
#   - Last error: Tests failed in validation phase

# After investigating and fixing test issues, reset
./ralph-autonomous.sh --reset-circuit
```

##### `--reset-state` - Complete State Reset

**What it does:**
- Deletes entire `.ralph/` directory
- Recreates fresh state with default values
- Clears all tracking and history

**Files deleted:**
```
.ralph/
├── state/
│   ├── session.json          (current session info)
│   ├── counters.json          (successful/failed/blocked issue counts)
│   ├── history.json           (attempt history for all issues)
│   ├── rate_limit.json        (API call tracking)
│   ├── circuit_breaker.json   (failure tracking)
│   ├── status.json            (monitor status - if using --monitor)
│   ├── progress.json          (live progress - if using --monitor)
│   └── task_queue.json        (queue state - if using --monitor)
├── active/                    (per-issue logs and feedback)
│   └── {issue}/
│       ├── research_attempt_*.log
│       ├── plan_attempt_*.log
│       ├── implement_attempt_*.log
│       ├── validate_attempt_*.log
│       └── feedback_*.json
└── archived/                  (completed issue data, organized by month)
    └── {YYYY-MM}/
        └── {issue}/
```

**When to use:**
- Starting completely fresh (forgetting all previous runs)
- Clearing stuck state that's causing issues
- Testing from a clean slate
- Resetting API call counters
- Clearing all issue history and logs

**⚠️ Warning:** This is destructive and cannot be undone. All attempt history, feedback, and logs will be permanently deleted.

**Example:**
```bash
# You'll be prompted to confirm
./ralph-autonomous.sh --reset-state

# Prompt:
# Reset all Ralph state? This will clear session history and counters. [y/N]
```

**Comparison:**

| Aspect | `--reset-circuit` | `--reset-state` |
|--------|-------------------|-----------------|
| **Scope** | Circuit breaker only | Everything |
| **Files affected** | 1 file (circuit_breaker.json) | All files in .ralph/ |
| **Destructive** | No (just resets counters) | Yes (deletes all history) |
| **Use when** | Circuit is OPEN, want to retry | Want completely fresh start |
| **Preserves** | All history and logs | Nothing |
| **Typical use** | After fixing validation issues | Testing, debugging, major changes |

#### Monitoring Dashboard

The `--monitor` flag launches Ralph in a split tmux session with a live dashboard:

```
┌─────────────────────────────┬─────────────────────────────┐
│ Left Pane                   │ Right Pane                  │
│ Ralph execution logs        │ Live monitoring dashboard   │
│ - Issue selection           │ - Current status            │
│ - Research/Plan/Implement   │ - Task queue progress       │
│ - Validation results        │ - API rate limits           │
│ - PR creation               │ - Recent activity log       │
└─────────────────────────────┴─────────────────────────────┘
```

**Dashboard features:**
- Real-time updates every 2 seconds
- Current GitHub issue being processed
- Phase tracking (Research → Plan → Implement → Validate)
- API call counter and rate limits
- Live progress indicators with animated spinner
- Recent activity log (last 8 entries)

**Controls:**
- `Ctrl+B` then `→` - Switch to monitor pane
- `Ctrl+B` then `←` - Switch to execution pane
- `Ctrl+B` then `D` - Detach from session (Ralph keeps running)
- `tmux attach -t ralph-monitor-*` - Reattach to detached session
- `Ctrl+C` - Stop Ralph and exit

**Example workflow:**
```bash
# Launch with monitoring in dry-run mode to preview
./ralph-autonomous.sh --monitor --dry-run

# After verifying behavior, run for real with monitoring
./ralph-autonomous.sh --monitor

# Detach to let it run in background
# Press: Ctrl+B then D

# Later, check on progress
./ralph-autonomous.sh --status

# Or reattach to see live dashboard
tmux attach -t ralph-monitor-20260120-143022-12345
```

#### Dashboard Theme & Appearance

The monitoring dashboard uses a custom tmux theme ([`.tmux.ralph.conf`](.tmux.ralph.conf)) designed for optimal readability and professional appearance.

**Theme Features:**
- **Catppuccin Mocha** color scheme - Professional, easy on the eyes for extended monitoring
- **Pane titles** - Clear labels ("Ralph Execution" and "Monitor Dashboard")
- **Enhanced status bar** - Shows session name, time, and keyboard shortcuts
- **Powerline-style separators** - Clean visual hierarchy (requires Nerd Fonts)

**Installing Nerd Fonts (Optional but Recommended):**

For best appearance with Powerline symbols and icons, install a [Nerd Font](https://www.nerdfonts.com/):

```bash
# Ubuntu/Debian - Install JetBrainsMono Nerd Font
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip JetBrainsMono.zip
rm JetBrainsMono.zip
fc-cache -fv
```

**Alternative fonts:**
- **FiraCode Nerd Font** - Popular among developers
- **Hack Nerd Font** - Excellent readability
- **Meslo Nerd Font** - Widely compatible

After installing, configure your terminal emulator to use the Nerd Font.

**Graceful Degradation:**

The dashboard works perfectly fine **without** Nerd Fonts - you'll see replacement characters instead of fancy icons, but all functionality remains intact. The configuration is designed to degrade gracefully:

- With Nerd Fonts: ` RALPH │  /home/project │  14:23:45`
- Without Nerd Fonts: `RALPH │ /home/project │ 14:23:45` (functional, just less fancy)

**Customizing the Theme:**

To modify colors, layout, or status bar content:

1. Edit [`.tmux.ralph.conf`](.tmux.ralph.conf)
2. Adjust color variables in the "CATPPUCCIN MOCHA COLORS" section
3. Modify status bar in the "STATUS BAR CONTENT" section
4. Changes take effect on next `--monitor` launch

**Alternative Themes:**

If you prefer a different theme (Nord, Tokyo Night, Dracula), you can replace the color palette in `.tmux.ralph.conf`. See comments in the config file for guidance.

### Why Validation Matters for Autonomous Loops

When Claude Code runs supervised, you naturally review work before committing. But autonomous loops like Ralph run overnight or in the background without human oversight. This creates unique risks:

**Without validation:**
- Broken implementations get committed
- Failed tests enter version control
- PRs waste reviewer time on non-functional code
- Git history polluted with "fix validation issues" commits
- Costly LLM calls spent on fixing preventable issues

**With validation as a quality gate:**
- ✅ Only working code enters version control
- ✅ All tests pass before creating PR
- ✅ Failed implementations flagged for human review
- ✅ Clean git history (no fix-up commits)
- ✅ Efficient use of autonomous cycles

**How Ralph handles validation failures:**

Ralph does **NOT** attempt to fix validation failures autonomously. This prevents:
- Infinite fix loops that burn through API budget
- Making implementations worse through blind fixes
- Compounding errors without understanding root cause

Instead, Ralph:
1. Labels the issue as `validation-failed`
2. Adds a comment with the full validation report
3. Resets the working directory (no commit)
4. Moves to the next issue

This design prioritizes **quality over quantity** - better to successfully complete 7 out of 10 issues than to create 10 PRs where 3 are broken.

### Why Custom Command Over Official Plugin?

Anthropic provides an official plugin: `/plugin install ralph-wiggum@claude-plugins-official`

This template uses a **custom command** instead. Here's why:

| Aspect | Official Plugin | Custom `/ralph` |
|--------|----------------|-----------------|
| **Transparency** | Black box - can't see what it does | Full visibility into loop logic |
| **Integration** | Generic | Uses YOUR GitHub labels, paths, existing commands |
| **Workflow** | Standalone | Orchestrates `/research_requirements` → `/create_plan` → `/implement_plan` → `/validate_plan` |
| **Quality Gates** | Unknown | Validation before commits, fails gracefully |
| **Artifacts** | Unknown | Creates `thoughts/research/` and `thoughts/plans/` documents |
| **Customization** | Use as-is | Modify to match your workflow |
| **Maintenance** | Anthropic controls updates | You control changes, version controlled in your repo |

### Testing Ralph Autonomous

Want to test Ralph's ability to autonomously build features from scratch? Use the reset script to create a clean testing environment.

#### `reset_ralph_test_environment.sh`

> Script: [`scripts/reset_ralph_test_environment.sh`](scripts/reset_ralph_test_environment.sh)

This helper script prepares a clean slate for testing Ralph by:
1. **Deleting** `src/frontend/` source code
2. **Resetting** Ralph state and circuit breaker
3. **Recreating** 5 frontend GitHub issues

**Usage:**
```bash
./scripts/reset_ralph_test_environment.sh
```

The script will ask for confirmation once, then proceed with all steps automatically.

**What issues does it recreate?**

The script recreates five frontend implementation issues:
1. Chat UI structure and layout with Tailwind CSS
2. Backend API client integration with CORS
3. Real-time streaming response handler
4. Multi-turn conversation state management
5. Markdown rendering for assistant messages

All issues are created with the `ready-for-dev` label so Ralph can immediately start working on them.

**Typical testing workflow:**
```bash
# 1. Reset environment and recreate issues
./scripts/reset_ralph_test_environment.sh

# 2. Verify issues were created
gh issue list --label "ready-for-dev"

# 3. Run Ralph in dry-run mode to preview
./ralph-autonomous.sh --monitor --dry-run

# 4. Run Ralph for real with monitoring
./ralph-autonomous.sh --monitor

# 5. Detach and let it run (Ctrl+B then D)

# 6. Check on progress later
./ralph-autonomous.sh --status

# 7. Review completed PRs
gh pr list
```

**Safety features:**
- Confirmation prompts before destructive actions
- Shows clear summary of what will be done
- Can skip individual steps with flags

### Prerequisite: GitHub Labels

> **Required before using `/ralph`:** These labels must exist in your repository.

Labels track issue state through the workflow. `/ralph` reads labels to know where each issue is, and updates them as it progresses.

| Label | Purpose | Color | Set by |
|-------|---------|-------|--------|
| `research-in-progress` | Research actively underway | Blue | `/ralph` |
| `research-complete` | Research done, ready for planning | Green | `/ralph` |
| `planning-in-progress` | Plan being created | Yellow | `/ralph` |
| `ready-for-dev` | Has implementation plan, ready to build | Purple | `/ralph` or manually |
| `in-progress` | Development actively underway | Red | `/ralph` |
| `validation-failed` | Implementation complete but failed validation | Orange | `/ralph` |
| `implementation-failed` | Implementation could not be completed | Dark red | `/ralph` |
| `pr-submitted` | PR created, awaiting review | Light green | `/ralph` |

#### Creating the Labels

**Option 1: Ask Claude to create them**
```
Create the GitHub labels needed for /ralph workflow:
research-in-progress, research-complete, planning-in-progress,
ready-for-dev, in-progress, validation-failed, implementation-failed,
pr-submitted
```

**Option 2: Create manually via CLI**
```bash
gh label create "research-in-progress" --description "Research actively underway" --color "1d76db"
gh label create "research-complete" --description "Research done, ready for planning" --color "0e8a16"
gh label create "planning-in-progress" --description "Plan being created" --color "fbca04"
gh label create "ready-for-dev" --description "Has implementation plan, ready to build" --color "5319e7"
gh label create "in-progress" --description "Development actively underway" --color "d93f0b"
gh label create "validation-failed" --description "Implementation complete but failed validation" --color "d4c5f9"
gh label create "implementation-failed" --description "Implementation could not be completed" --color "b60205"
gh label create "pr-submitted" --description "PR created, awaiting review" --color "c2e0c6"
```

**Option 3: Create via GitHub UI** - Settings → Labels → New label

#### How `/ralph` Uses Labels

```bash
# Read: Find issues ready for implementation
gh issue list --label "ready-for-dev" --json number,title

# Update: Move issue to next state
gh issue edit 42 --add-label "in-progress" --remove-label "ready-for-dev"
```

**Manual workflow:** You can also move issues through states manually by adding/removing labels in GitHub UI. `/ralph` will pick up from wherever the issue is.

---

## Setting Up Claude PR Reviews

Enable Claude to review pull requests and improve `CLAUDE.md` over time by setting up the GitHub Action.

### Step 1: Workflow File (Already Included)

The workflow file [`.github/workflows/claude.yml`](.github/workflows/claude.yml) is already included in this template. It triggers when @claude is mentioned in issues or PR comments.

![Claude workflow file](docs/screenshots/claude-yml.png)

#### Workflow Permissions

The workflow is configured with **write permissions**:

| Permission | Level | Purpose |
|------------|-------|---------|
| `contents` | write | Commit updates to `CLAUDE.md` and other files |
| `pull-requests` | write | Comment on PRs, suggest changes |
| `issues` | write | Respond to issue comments |
| `id-token` | write | Authentication with GitHub |

**Why write access?** The feedback loop requires Claude to commit improvements to `CLAUDE.md` directly. Without write access, Claude could only suggest changes in comments, losing the automated improvement cycle.

#### CLAUDE.md Update Instructions

The workflow includes a [prompt](.github/workflows/claude.yml#L38-L46) that instructs Claude to consider updating `CLAUDE.md` when it notices:
- Recurring mistakes or anti-patterns
- Project conventions worth documenting
- Corrections to existing instructions

Claude will propose changes and commit them upon user approval.

### Step 2: Set Up OAuth Token

The workflow uses your Claude Code Max subscription via an OAuth token. Set it up using the built-in Claude Code command:

```bash
/install-github-app
```

**What this does:**
- Authenticates your GitHub account with Claude Code
- Creates a `CLAUDE_CODE_OAUTH_TOKEN` secret in your repository
- Enables Claude to respond to @mentions in PRs and issues

**After running the command:**
1. Follow the prompts to authorize Claude Code with GitHub
2. Select your repository when prompted
3. The token is automatically configured as a repository secret

> **Note:** This uses your Claude Code Max subscription, not a separate Anthropic API key. The workflow is already configured to use `claude_code_oauth_token` in [`.github/workflows/claude.yml`](.github/workflows/claude.yml).

### Step 3: Test the Workflow

Once the OAuth token is configured, test that @claude mentions work:

1. Create a test PR (or use an existing one)
2. Add a comment mentioning @claude:
   ```
   @claude Hello! Please confirm the workflow is working.
   ```
3. Watch for:
   - 👀 emoji appears (Claude sees the mention)
   - GitHub Action runs (check Actions tab)
   - Claude responds with a comment

See [Using @claude in PR Reviews](#using-claude-in-pr-reviews) for comprehensive examples of how to use Claude for code reviews and feedback.

### The Feedback Loop

The workflow has **write permissions**, enabling Claude to commit updates to `CLAUDE.md` when it notices:
- Recurring mistakes or anti-patterns
- Project conventions that should be documented
- Lessons learned from code reviews

This creates a feedback loop where Claude Code improves over time - each PR review can result in better instructions for future sessions. See [Workflow Concepts](docs/claude-code-workflow-concepts.md#use-code-review-to-improve-claude-code-over-time) for more details.

---

## Reference Documents

- **Design Decisions**: [`handoff.md`](handoff.md)
- **Workflow Concepts**: [`docs/claude-code-workflow-concepts.md`](docs/claude-code-workflow-concepts.md)
- **Implementation Progress**: [`template_implementation_checklist.md`](template_implementation_checklist.md)
