---
description: Autonomously create git commits without user approval (for Ralph workflow)
---

# Autonomous Commit

You are tasked with creating git commits autonomously without user approval. This skill is used by the Ralph autonomous workflow.

## Process:

1. **Analyze what changed:**
   - Run `git status` to see current changes
   - Run `git diff` to understand the modifications
   - Consider whether changes should be one commit or multiple logical commits

2. **Create commit(s) automatically:**
   - Identify which files belong together
   - Draft clear, descriptive commit messages
   - Use imperative mood in commit messages
   - Focus on why the changes were made, not just what

3. **Execute immediately without asking:**
   - Use `git add` with specific files (never use `-A` or `.`)
   - Create commits with your planned messages
   - Show the result with `git log --oneline -n [number]`
   - Output "COMMIT_COMPLETE" when finished

## Important:
- **NEVER add co-author information or Claude attribution**
- Commits should be authored solely by the user
- Do not include any "Generated with Claude" messages
- Do not add "Co-Authored-By" lines
- Write commit messages as if the user wrote them
- **Do NOT ask "Shall I proceed?" - execute immediately**
- This is for autonomous operation - no user approval needed

## Remember:
- Rely on `git status` and `git diff` to understand changes
- If unsure about change intent, read the modified files
- Group related changes together
- Keep commits focused and atomic when possible
- Execute immediately after planning - this is autonomous mode
- Output "COMMIT_COMPLETE" at the end for Ralph to detect success
