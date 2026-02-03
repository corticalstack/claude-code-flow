# Template Setup Guide

This guide walks you through setting up a project created from the `claude-code-flow` template.

> **You are here because**: You clicked "Use this template" and created a new project. Now you need to configure it for development.

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

Instead, all work must go through feature branches and pull requests (see [Feature Branch Workflow](../README.md#feature-branch-workflow)).

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
* @YOUR_GITHUB_USERNAME
EOFINNER
```

**Replace `@YOUR_GITHUB_USERNAME` with your GitHub username.**

**How it works:**
- When any PR is created, GitHub automatically requests review from the specified user
- Applies to all files (`*` pattern) in the repository
- Works immediately—no additional configuration needed

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

Claude Code hooks automate common tasks and protect sensitive files. The hooks configuration lives in `.claude/settings.json`.

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

Edit `.claude/settings.json` to customize:

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

## Next Steps

After completing this setup:

1. **Update README.md** - Replace it with your project documentation
2. **Update CLAUDE.md** - Add project-specific conventions and build commands
3. **Create your first issue** - Use GitHub issues to track work
4. **Start the workflow** - Use `/research_requirements` or `/create_plan` to begin

See the main [README.md](../README.md) for workflow documentation and command reference.
