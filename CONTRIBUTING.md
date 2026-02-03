# Contributing

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone git@github.com:YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

### 2. Create a Feature Branch

```bash
# Create a branch for your changes
git checkout -b feature/your-feature-name
```

### 3. Make Your Changes

- Follow existing code style and conventions
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 4. Commit Your Changes

```bash
# Stage your changes
git add .

# Create a descriptive commit message
git commit -m "Add feature: brief description of changes"
```

### 5. Push and Create a Pull Request

```bash
# Push your branch to your fork
git push -u origin feature/your-feature-name

# Create a pull request on GitHub
gh pr create --base main --title "Your PR title" --body "Description of changes"
```

## Pull Request Guidelines

- **Title**: Use a clear, descriptive title
- **Description**: Explain what changes you made and why
- **Scope**: Keep PRs focused on a single feature or fix
- **Tests**: Include tests for new functionality
- **Documentation**: Update README or docs if needed

## Code Style

- Follow the existing code style in the project
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## Testing

- Run tests before submitting: `[add your test command]`
- Add tests for new features
- Ensure all existing tests pass

## Questions?

Feel free to open an issue if you have questions or need help with your contribution.
