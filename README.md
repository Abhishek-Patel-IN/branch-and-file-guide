<p align="center">
  <img src="assets/banner.svg" alt="Branch &amp; File Naming Guide — branch and file icons on a green-to-teal gradient" width="640">
</p>

<h1 align="center">Branch &amp; File Naming Guide</h1>

<p align="center">Clear branch names. Consistent file names.</p>

<p align="center">
  <a href="https://agentskills.io"><img src="https://img.shields.io/badge/Agent_Skills-Compatible-0f766e?style=flat-square" alt="Agent Skills compatible"></a>
  <a href="SKILL.md"><img src="https://img.shields.io/badge/Audits-Read--only-117a65?style=flat-square" alt="Read-only audits"></a>
  <a href="https://www.linkedin.com/in/abhishekpatel-in/"><img src="https://img.shields.io/badge/Contact-Abhishek_Patel-334155?style=flat-square" alt="Contact Abhishek Patel on LinkedIn"></a>
</p>

## Installing Branch & File Naming Guide

Run this command from the project where you want to use the skill:

```bash
npx skills add Abhishek-Patel-IN/branch-and-file-naming-guide --skill branch-and-file-naming-guide
```

During installation, choose the coding assistants you want to use and whether to install the skill for this
project or all your projects. You can also add `-g` to the command to install globally.

If `npx` is missing, install [Node.js](https://nodejs.org/en/download), then rerun the command.

Claude Code users can also add the marketplace and install the plugin directly through Claude:

```text
/plugin marketplace add Abhishek-Patel-IN/branch-and-file-naming-guide
/plugin install branch-and-file-naming-guide@branch-and-file-naming-guide
```

Choose either the `npx` or marketplace method for Claude Code to avoid installing the same skill twice.
Alternatively, clone this repository and install from a local checkout using the Local development commands below.

## Using Branch & File Naming Guide

Start a new session after installation. The skill is called **Branch & File Naming Guide** and can be triggered
in several ways. Enter these examples in your assistant's chat, not in a terminal.

In Claude Code, after installing with `npx`:

> /branch-and-file-naming-guide

In Codex:

> $branch-and-file-naming-guide

For a Claude marketplace installation, use the plugin-prefixed command:

> /branch-and-file-naming-guide:branch-and-file-naming-guide

Add specific instructions when you want a focused check or suggestion. For example, in Claude Code:

> /branch-and-file-naming-guide Check only the file and folder names in this Flutter project.

Or in Codex:

> $branch-and-file-naming-guide Suggest a branch name for fixing an API timeout, ticket APP-245.

You can also trigger the skill using natural language:

> Use the Branch & File Naming Guide skill to audit this project's branch names and show a rename plan.

Audits are read-only. Before renames or other repository changes, the skill proposes a plan and asks for
confirmation, as described in [SKILL.md](SKILL.md).

## What the guide covers

- Branch names with `feature/`, `bugfix/`, or `hotfix/` prefixes and optional ticket IDs.
- Primary branches named `production`, `qa_deliveries`, and `development`.
- PascalCase Kotlin, Java, and Swift files; snake_case Dart files and Android resources.
- Swift extension names such as `String+Validation.swift` and platform-specific test file names.
- Auditing existing names, updating references during file moves, and checking branch migrations.

### Naming examples

| Purpose | Example |
|---|---|
| Feature branch | `feature/APP-123-user-login` |
| Bug fix branch | `bugfix/api-timeout` |
| Hotfix branch | `hotfix/payment-failure` |
| Kotlin or Java source | `LoginViewModel.kt`, `PaymentService.java` |
| Swift source or extension | `LoginView.swift`, `String+Validation.swift` |
| Dart source or test | `login_screen.dart`, `login_screen_test.dart` |
| Android resource | `activity_login.xml` |

Names should describe purpose. Avoid developer names, vague labels, spaces, and duplicate versions such as
`LoginFinal2.kt`. The agent judges ambiguous cases; version words are warnings because some names legitimately
contain them.

## Updating or removing the skill

For installations made with `npx`:

```bash
npx skills update branch-and-file-naming-guide
npx skills remove branch-and-file-naming-guide
```

Add `-g` to target global installations. If you previously installed from a local directory with `skills add .`,
install again using the GitHub command above to switch the source. Local-directory installs need their source
updated and the local install command rerun.

Manage marketplace installations through Claude Code's `/plugin` manager, including updates and removal.

## Contributing

Improvements to checks, examples and documentation are welcome. Keep instructions concise and add a regression
case to the relevant script's `--self-test` when changing a rule it checks.

For Claude plugin changes, run `claude plugin validate .`. Bump the version in `.claude-plugin/plugin.json`
when releasing plugin updates so existing installations receive them.

<details>
<summary>Local development — cloning is only needed to edit or test the guide itself</summary>

```bash
git clone https://github.com/Abhishek-Patel-IN/branch-and-file-naming-guide.git
cd branch-and-file-naming-guide
sh scripts/audit-branches.sh --self-test
sh scripts/audit-files.sh --self-test
```

To try your local changes in a coding assistant:

```bash
npx skills add . --skill branch-and-file-naming-guide
```

Self-tests create temporary repositories and remove them afterwards. The audit commands do not modify the
repository being inspected. On Windows, run the scripts through Git Bash.

</details>

## Further reading

- [Skill instructions and workflows](SKILL.md)
- [Branch audit and migration guide](references/branch-migration.md)
- [File and folder naming guide](references/file-naming.md)

The file checker skips dependency/build output and generated code. Git-quoted filenames stop a repository scan
with an explicit error; ordinary Unicode paths are preserved, while case collision checks fold ASCII letters only.
Provider checks such as open PRs and branch protection need authenticated provider access; otherwise they are
reported as `NOT VERIFIED`.
