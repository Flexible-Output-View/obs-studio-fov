# Description

<!-- Provide a clear, concise summary of the changes and why they are needed. -->

## Type of Change

What kind of change does this PR introduce? *(Check all that apply)*

- [ ] **Bugfix (`FIX`):** Fixes a broken behavior or issue
- [ ] **Feature (`ADD`):** Introduces new functionality
- [ ] **Refactoring (`REFACT`):** Code restructuring with no functional or API changes
- [ ] **Code Style:** Formatting, naming, or local variable updates
- [ ] **Build / CI (`BUILD` / `CI`):** Changes to build scripts, dependencies, or GitHub Actions workflows
- [ ] **Documentation (`DOC`):** Updates to docs, comments, or READMEs
- [ ] **Tests (`TEST`):** Adds or updates unit/integration tests
- [ ] **Other:** *(Please describe in the Description above)*

## Checklist Before Merge

### Git & Workflow

- [ ] I have read the [Contribution Documentation](https://flexible-output-view.github.io/documentation-fov/contributing.html).
- [ ] The target branch is set to **`dev`** *(direct merges into `main` or `master` are prohibited)*.
- [ ] This PR was created from a dedicated feature or bugfix branch.
- [ ] Commit messages follow the standardized format (`PREFIX: Short description`, e.g., `ADD:`, `FIX:`, `DOC:`, `REFACT:` etc).
- [ ] Linked any relevant issues (e.g., `Fixes #123` or `Closes #456`).

### Code Quality & Testing

- [ ] Code follows project style guidelines (standard JS for `web-fov`, clean C practices for `obs-studio-fov`).
- [ ] Automatic formatting has been applied (**`clang-format`** for C; **`eslint`** / **`prettier`** for frontend/backend).
- [ ] Documentation and comments are updated (including Doxygen comments for C code where applicable).
- [ ] Changes have been tested locally and verified for stability.
