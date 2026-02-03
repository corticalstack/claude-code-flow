# Template Setup Guide

This guide walks you through setting up a project created from the `claude-code-flow` template.

> **You are here because**: You clicked *Use this template* and created a new project. Now you need to configure it for development.

## Table of Contents

- [Prerequisites](#prerequisites)
  - [GitHub CLI Setup](#github-cli-setup)
  - [Python Environment Setup (UV)](#python-environment-setup-uv)
- [Branch Protection Setup](#branch-protection-setup)
  - [Why Protect Main?](#why-protect-main)
  - [Check if Main Branch Exists](#check-if-main-branch-exists)
  - [Configure Branch Protection Rules](#configure-branch-protection-rules)
  - [Verify Branch Protection](#verify-branch-protection)
  - [Working with Protected Main](#working-with-protected-main)
  - [Automatic Reviewer Assignment](#automatic-reviewer-assignment)
- [Workflow Setup Guide](#workflow-setup-guide)
  - [Step 1: Verify Directory Structure](#step-1-verify-directory-structure)
  - [Step 2: Git Configuration (Optional)](#step-2-git-configuration-optional)
  - [Step 3: Configure Hooks](#step-3-configure-hooks)
- [Important: Command Caching Behavior](#important-command-caching-behavior)
- [Setting Up Claude PR Reviews](#setting-up-claude-pr-reviews)
- [Command Reference](#command-reference)
- [Feature Branch Workflow](#feature-branch-workflow)
- [Directory Structure](#directory-structure)
- [Using @claude in Pull Requests](#using-claude-in-pull-requests)
- [Ralph Autonomous Development](#ralph-autonomous-development)
- [Next Steps](#next-steps)

---

## Prerequisites

Before setting up the workflow, ensure you have:

1. **Git repository** - New or existing, with a GitHub remote configured
2. **GitHub CLI** - See [GitHub CLI Setup](#github-cli-setup) below
3. **Claude Code** - Installed and configured

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

> **Note:** This section is specific to Python projects and serves as an example of setting up a language environment and package manager. If you're building with a different language, you'd follow similar steps with your language's tooling (e.g., `npm`/`pnpm` for JavaScript/TypeScript, `cargo` for Rust, `go mod` for Go). **Skip this section if you're not using Python.**

The workflow hooks use Python tools like `ruff` for auto-formatting and linting. We recommend [UV](https://docs.astral.sh/uv/) - a fast, modern Python package manager written in Rust that's 10-100x faster than pip.

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

#### 4. Add Ruff for Auto-Formatting and Linting

Install the Python formatter and linter used by the auto-format hooks:

```bash
# Add ruff as a dev dependency
uv add ruff --dev
```

#### 5. Verify Ruff is Installed

```bash
uv run ruff --version
```

#### Using UV

UV automatically manages virtual environments. You don't need to activate them manually:

```bash
# Run any command in the virtual environment
uv run ruff format myfile.py
uv run python script.py

# Add more packages
uv add requests
uv add pytest --dev
```

If you prefer activating the environment manually (traditional workflow):
```bash
source .venv/bin/activate
ruff --version
```

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

Instead, all work must go through feature branches and pull requests (see [Feature Branch Workflow](#feature-branch-workflow) below).

### Automatic Reviewer Assignment

**Ensure all PRs have reviewers assigned automatically** using a CODEOWNERS file. This works for PRs created manually, by Claude Code, or through automation.

> **Note:** For solo developers, CODEOWNERS is optional. If you're the only contributor and have `required_approving_review_count: 0` set in branch protection, you can skip this section. CODEOWNERS is primarily useful for teams or repositories that accept external contributions.

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
* @YOUR_GITHUB_USERNAME
EOFINNER
```

**Replace `@YOUR_GITHUB_USERNAME` with your GitHub username.**

**How it works:**
- When any PR is created, GitHub automatically requests review from the specified user
- Applies to all files (`*` pattern) in the repository
- Works immediately—no additional configuration needed

---

## Workflow Setup Guide

This section guides you through configuring the Claude Code workflow for your project.

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
│   └── TEMPLATE_INSTRUCTIONS.md
├── .github/
│   ├── workflows/          # GitHub Actions
│   │   └── claude.yml      # Claude Code PR review automation
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

### Step 2: Git Configuration (Optional)

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

### Step 3: Configure Hooks

Claude Code hooks automate common tasks and protect sensitive files. The hooks configuration lives in `.claude/settings.json`.

### What the Hooks Do

| Hook Type | Trigger | Purpose |
|-----------|---------|---------|
| **PreToolUse** | Before Edit/Write | Blocks modifications to sensitive files (.env, credentials, secrets, .git/) |
| **PostToolUse** | After Edit/Write | Auto-formats JS/TS files with Prettier, Python files with Ruff |
| **Notification** | When Claude needs input | Desktop notification (Linux `notify-send`) |

### Why These Hooks Matter

1. **Security**: The PreToolUse hook prevents accidental exposure of secrets by blocking edits to sensitive files. Claude will be stopped before it can write to `.env`, `credentials.json`, or similar files.

2. **Code Quality**: Auto-formatting ensures consistent code style without manual intervention. Every file edit is automatically formatted according to project standards.

3. **Workflow**: Desktop notifications alert you when Claude needs your attention, useful during long-running operations.

### Prerequisites for Hooks

The auto-format hooks require formatters to be installed. If you followed [Python Environment Setup (UV)](#python-environment-setup-uv), ruff is already installed.

```bash
# Python formatting and linting (already done if you followed UV setup)
uv add ruff --dev

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

**Expected result**: The file is created and automatically formatted by ruff:
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

Edit `.claude/settings.json` to customize:

- **Add file types**: Extend the PostToolUse patterns for other languages
- **Change formatters**: Replace Prettier/Ruff with your preferred tools
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

## Setting Up Claude PR Reviews

Enable Claude to review pull requests and improve `CLAUDE.md` over time by setting up the GitHub Action.

### Step 1: Workflow File (Already Included)

The workflow file `.github/workflows/claude.yml` is already included in this template. It triggers when @claude is mentioned in issues or PR comments.

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

The workflow includes a prompt that instructs Claude to consider updating `CLAUDE.md` when it notices:
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

> **Note:** This uses your Claude Code Max subscription, not a separate Anthropic API key. The workflow is already configured to use `claude_code_oauth_token` in `.github/workflows/claude.yml`.

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

See [Using @claude in PR Reviews](../README.md#using-claude-in-pr-reviews) in the main README for comprehensive examples.

### The Feedback Loop

The workflow has **write permissions**, enabling Claude to commit updates to `CLAUDE.md` when it notices:
- Recurring mistakes or anti-patterns
- Project conventions that should be documented
- Lessons learned from code reviews

This creates a feedback loop where Claude Code improves over time - each PR review can result in better instructions for future sessions.

---

## Command Reference

The workflow provides these commands organized by phase:

### Research Phase

| Command | Purpose |
|---------|---------|
| `/research_requirements` | Research requirements and tech choices for new features |
| `/research_codebase` | Document existing codebase patterns and architecture |

### Planning Phase

| Command | Purpose |
|---------|---------|
| `/create_plan` | Create detailed implementation plans with phased approach |
| `/iterate_plan` | Update existing plans based on new requirements |

### Implementation Phase

| Command | Purpose |
|---------|---------|
| `/implement_plan` | Execute plans phase by phase with verification checkpoints |
| `/validate_plan` | Validate implementation matches plan (quality gate before commit) |

### Commit & PR Phase

| Command | Purpose |
|---------|---------|
| `/commit` | Create git commits with user approval |
| `/autonomous_commit` | Create commits without approval (for autonomous workflows) |
| `/describe_pr` | Generate comprehensive PR descriptions from templates |

### Autonomous Workflow

| Command | Purpose |
|---------|---------|
| `/ralph` | Autonomous issue processing loop (Research → Plan → Implement → Validate → PR) |

### Session Management

| Command | Purpose |
|---------|---------|
| `/create_handoff` | Create handoff document for transferring work to another session |
| `/resume_handoff` | Resume work from handoff document with context |

**Typical workflow:**

**Greenfield (new features):**
```
/research_requirements → /create_plan → /implement_plan → /validate_plan → /commit
```

**Brownfield (existing codebase):**
```
/research_codebase → /create_plan → /implement_plan → /validate_plan → /commit
```

See [CLAUDE.md](../CLAUDE.md) for workflow guidance and the main [README.md](../README.md) for quick reference.

---

## Feature Branch Workflow

All development work should be done on feature branches. Here's the typical workflow:

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

**Branch naming convention:**
```
feature/<issue-number>-<brief-description>
```

Examples:
- `feature/42-add-authentication`
- `feature/7-configurable-system-prompt`

---

## Directory Structure

After creating a project from this template, you'll have this structure:

```
your-project/
├── .claude/              # Commands, skills, hooks configuration
├── .ralph/               # Autonomous workflow state
├── thoughts/             # Research documents and implementation plans
│   ├── research/         # Requirements and codebase research
│   ├── plans/            # Implementation plans
│   └── prs/              # PR descriptions
├── docs/                 # Documentation
│   └── TEMPLATE_INSTRUCTIONS.md
├── src/                  # YOUR SOURCE CODE (add this)
├── tests/                # YOUR TESTS (add this)
└── [your project files]  # YOUR PROJECT STRUCTURE (add this)
```

**What's included:**
- `.claude/` - Workflow commands and configuration
- `.ralph/` - Autonomous workflow state tracking
- `thoughts/` - Research and planning artifacts
- `docs/` - Template documentation

**What you add:**
- Your source code (`src/` or your preferred structure)
- Your tests (`tests/` or your preferred location)
- Your dependencies (`pyproject.toml`, `package.json`, etc.)
- Your build/run scripts

---

## Using @claude in Pull Requests

After creating PRs, you can @mention Claude in PR comments for code reviews. Claude will respond using your Claude Code Max subscription.

**Example interactions:**

```
@claude Review this PR for code quality and potential issues
```

```
@claude What do you think about the architecture decisions?
```

```
@claude Are there any edge cases we might have missed in the validation logic?
```

```
@claude Suggest improvements to CLAUDE.md based on patterns you see
```

**What happens:**
1. You add a comment mentioning @claude
2. The GitHub Action triggers automatically (see [Setting Up Claude PR Reviews](#setting-up-claude-pr-reviews))
3. Claude reviews your code and responds with feedback
4. Claude may suggest updates to `CLAUDE.md` for future improvements

This creates a feedback loop where Claude Code improves over time - each PR review can result in better instructions for future sessions.

---

## Ralph Autonomous Development

For fully autonomous multi-issue processing, use the `/ralph` command or `ralph-autonomous.sh` shell script.

### Using Ralph with Live Monitor

Launch Ralph with a live monitoring dashboard:

```bash
# Launch with live monitoring dashboard
./ralph-autonomous.sh --monitor

# The dashboard shows:
# - Left pane: Ralph execution logs (research, planning, implementation)
# - Right pane: Live status, task queue, API limits, recent activity
#
# Controls:
# - Ctrl+B then D: Detach (Ralph keeps running in background)
# - Ctrl+B then arrow keys: Switch between panes

# Later, check on progress
./ralph-autonomous.sh --status

# Or reattach to see live dashboard
tmux attach -t ralph-monitor-<session-id>

# Preview before running
./ralph-autonomous.sh --dry-run        # See what would happen without making changes
```

### How Ralph Works

Ralph automatically processes issues end-to-end:

1. Selects highest priority open issue
2. Creates research if missing (`/research_requirements`)
3. Creates plan if missing (`/create_plan`)
4. Implements the plan (`/implement_plan`)
5. Validates implementation (`/validate_plan`)
6. Creates PR if validation passes
7. Moves to next issue

**Prerequisites:**
- GitHub labels must exist (see label setup in Branch Protection section)
- Branch protection configured (prevents direct commits to main)

**Quality Gate:**
Ralph only creates commits and PRs for implementations that pass validation. Failed validations are flagged for human review rather than attempting automated fixes.

### Resetting Ralph State

If you need to start fresh or clear old test data, use the reset script:

```bash
./reset-ralph-state.sh
```

**What it resets:**
- Clears `.ralph/active/` (active issue logs)
- Clears `.ralph/archived/` (archived issue logs)
- Resets circuit breaker to CLOSED state
- Resets all counters (iterations, successes, failures) to 0
- Clears execution history
- Resets rate limiting
- Removes session file

**When to use:**
- Starting fresh with the template
- After testing/development work
- Recovering from corrupted state
- Before sharing the template

The script includes a confirmation prompt and shows exactly what will be reset.

---

## Next Steps

After completing this setup:

1. **Update README.md** - Replace it with your project documentation
2. **Update CLAUDE.md** - Add project-specific conventions and build commands
3. **Create your first issue** - Use GitHub issues to track work
4. **Start the workflow** - Use `/research_requirements` or `/create_plan` to begin

See the main [README.md](../README.md) for workflow overview.
