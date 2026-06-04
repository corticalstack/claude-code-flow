# [Your Project Name Here]

> **⚠️ POST-TEMPLATE SETUP REQUIRED**
>
> You've created a project from the `flow` template. **Replace this README** with your project documentation after setup.
>
> **Complete Instructions**: [docs/TEMPLATE_INSTRUCTIONS.md](docs/TEMPLATE_INSTRUCTIONS.md)

---

## About This Template

This project uses the **Flow** template - a structured workflow for AI-assisted development with manual step-by-step commands or fully autonomous multi-issue processing.

---

## Workflow Overview

**Manual (step-by-step):**

[/research-requirements](.claude/skills/research-requirements/SKILL.md) → [/create-plan](.claude/skills/create-plan/SKILL.md) → [/implement-plan](.claude/skills/implement-plan/SKILL.md) → [/validate-plan](.claude/skills/validate-plan/SKILL.md) → [/cross-review](.claude/skills/cross-review/SKILL.md) (optional, advisory) → [/commit](.claude/skills/commit/SKILL.md) → Push & PR → [/describe-pr](.claude/skills/describe-pr/SKILL.md) → Review → [/handle-pr-feedback](.claude/skills/handle-pr-feedback/SKILL.md) (if needed) → Merge

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
