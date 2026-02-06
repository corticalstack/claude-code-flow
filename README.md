# [Your Project Name Here]

> **⚠️ POST-TEMPLATE SETUP REQUIRED**
>
> You've created a project from the `claude-code-flow` template. **Replace this README** with your project documentation after setup.
>
> **Complete Instructions**: [docs/TEMPLATE_INSTRUCTIONS.md](docs/TEMPLATE_INSTRUCTIONS.md)

---

## About This Template

This project uses the **Claude Code Flow** template - a structured workflow for AI-assisted development with manual step-by-step commands or fully autonomous multi-issue processing.

---

## Workflow Overview

**Manual (step-by-step):**

[/research_requirements](.claude/commands/research_requirements.md) → [/create_plan](.claude/commands/create_plan.md) → [/implement_plan](.claude/commands/implement_plan.md) → [/validate_plan](.claude/commands/validate_plan.md) → [/commit](.claude/commands/commit.md) → Push & PR → [/describe_pr](.claude/commands/describe_pr.md) → Review → [/handle_pr_feedback](.claude/commands/handle_pr_feedback.md) (if needed) → Merge

**Autonomous (unattended):**
```bash
./scripts/ralph-autonomous.sh --monitor  # Launch with live dashboard
```

Processes up to 10 issues automatically with live monitoring, state management, and retry logic.

See [docs/TEMPLATE_INSTRUCTIONS.md](docs/TEMPLATE_INSTRUCTIONS.md) for complete documentation.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

**Remember**: This README is a template placeholder. Replace it with documentation specific to your project after completing setup!
