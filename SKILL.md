---
name: branch-and-file-naming-guide
description: Team Git branching and file naming standards - primary branches production / qa_deliveries / development, work branches feature/ bugfix/ hotfix/ with optional ticket ID, PascalCase Swift/Kotlin/Java files, snake_case Dart and Android resource files. Use when creating a git branch, starting work on a task, ticket or bug, suggesting or checking a branch name, auditing or renaming old branches, migrating master/main/develop/qa to the standard branches, or creating, naming, auditing or renaming files and folders in Android, iOS or Flutter projects.
---

# Branch & File Naming Guide

Core principle: **names describe purpose, not ownership or history.**
No developer names, no `new/old/final/latest/copy`, no spaces, no unnecessary special characters.

## Scripts (read-only)

Resolve `scripts/` relative to the directory containing this SKILL.md (written `<skill>` below).
Run with `sh` (Windows: Git Bash). Audit modes never fetch or modify the repository.
`--self-test` creates temporary repositories and removes them afterwards.

| Command | Purpose |
|---|---|
| `sh <skill>/scripts/audit-branches.sh --name <branch>` | validate one proposed branch name |
| `sh <skill>/scripts/audit-branches.sh` | audit all local + remote-tracking branches of the repo in cwd |
| `sh <skill>/scripts/audit-files.sh --path <relative/path>` | validate one proposed file path |
| `sh <skill>/scripts/audit-files.sh [dir]` | audit tracked files/dirs of the repo in cwd |

Output is TSV. Status: `OK`, `WARN` (judgment needed), `FIX` (breaks a rule), `MIGRATE` (legacy primary branch).
Suggestions are mechanical candidates: always refine them from context before proposing.
Exit codes: `0` no FIX/MIGRATE, `1` FIX or MIGRATE found, `2` usage/runtime error.
If the scripts cannot be run, apply the rules below by hand and say so.

## Safety rules (every workflow)

1. Every repository change follows **detect, propose, explicit user confirmation, execute, verify**. Never rename,
   delete, push, commit or change provider settings silently.
2. Need no confirmation: audit scripts, read-only git (`status`, `log`, `branch`, `for-each-ref`, `ls-remote`, `grep`),
   `git fetch --prune` (updates remote-tracking refs only), read-only `gh`/`glab` queries when already authenticated.
3. Need confirmation:

   | Action | Confirmation |
   |---|---|
   | Create local branch | one line, unless the user gave the exact name and base |
   | Push a branch | only when the user asks |
   | Stash or carry uncommitted changes | ask |
   | Rename branches (local) | approved rename table |
   | Push / rename / delete on the remote | rename table must explicitly include remote scope; every deletion needs its own yes |
   | Primary-branch migration | per branch; separate yes for provider settings and for deleting the old branch |
   | Rename files, edit references | approved rename table |
   | Commit | separate yes |
   | `git reset --hard` (rollback) | explicit yes |

4. Never develop, commit or push directly on `production`, `qa_deliveries` or `development`. Promotion between
   them happens through Pull Requests by the team; this skill does not merge them.
5. **Remote**: use `origin` if it exists, else the only remote, else ask. With no remote, say the branch is based on
   the local base branch.
6. **Provider checks** (default branch, protection rules, open PRs, deploy integrations) are invisible to Git. Use
   `gh`/`glab` only if already installed and authenticated; never install or log in. Otherwise report each such
   check as `NOT VERIFIED` and let the user confirm it.
7. Stop at the first failing command and report. Verify after every mutation.

## Branch rules

Primary branches (exact names): `production` (released code, tag releases `vX.Y.Z`), `qa_deliveries` (current QA
candidate), `development` (integration). Flow: `feature/* -> development -> qa_deliveries -> production`.

Work branches: `<type>/[TICKET-ID-]<slug>`

- Structure (FIX if broken): `^(feature|bugfix|hotfix)/([A-Z][A-Z0-9]+-[0-9]+-)?[a-z0-9]+(-[a-z0-9]+)*$`
  e.g. `feature/user-login`, `feature/APP-123-user-login`, `bugfix/APP-245-api-timeout`, `hotfix/payment-failure`.
- Ticket ID is optional; when present it is uppercase (`APP-123`).
- WARN (judgment): slug outside 2-5 words (ticket not counted), version words, lowercase ticket ID.
- Judgment only (scripts cannot see it): developer names (`developer-dev`, `developer-changes`), vague slugs
  (`changes`, `my-branch`, `test-branch`, `updates`), slug not matching the actual work.

| Type | Use for | Base |
|---|---|---|
| `feature/` | new functionality or improvement | `development` |
| `bugfix/` | normal defect found in development or QA | `development` |
| `hotfix/` | urgent issue in the released production version needing an expedited release | `production` |

If it is unclear whether a bug is a `bugfix` or a `hotfix`, **ask**. A hotfix must afterwards be merged back into
`development` (and other active branches) so the fix is not lost.

## Workflow A: create a branch

1. Read the task. If no ticket ID was given, ask once ("none" is fine).
2. Choose the type from the table; ask if bugfix vs hotfix is unclear.
3. Build the slug: lowercase kebab-case, 2-5 words describing the work, no names, no version or filler words.
4. Validate: `audit-branches.sh --name <candidate>` must be `OK` (or a `WARN` the user accepts).
5. Preflight:
   - resolve the remote (safety rule 5) and run `git fetch <remote> --prune`;
   - the base must exist as `<remote>/<base>` (else local `<base>`, and say so). If it is missing and legacy
     branches exist (`master`, `main`, `develop`, `dev`, `qa`, `staging`), stop and offer workflow E; otherwise
     offer to create the missing primary branch (confirm first);
   - the name must not exist locally or on the remote (`git for-each-ref`, `git ls-remote --heads`);
   - `git status --porcelain` must be empty; if not, ask: carry changes over, stash, or abort.
6. Confirm: "Create `bugfix/APP-245-login-timeout` from `origin/development`?"
7. `git switch --no-track -c <name> <remote>/<base>` (`--no-track` so pull/push never target the primary branch).
   Push only if asked: `git push -u <remote> <name>`.
8. Verify: `git branch --show-current` equals the name and `git rev-parse HEAD` equals the base commit.
   For a hotfix, remind the user to merge it back into `development` after release.

If the user asks to commit while on a primary branch, propose workflow A instead.

## Workflow B: suggest a name (no changes)

Return the best name and two alternatives, each with a one-line reason, validated with `--name`. If inside a repo,
say whether the name already exists. Do not run any mutating command.

## Workflow C: audit and rename existing work branches

Read `references/branch-migration.md` (section C) and follow it exactly. `MIGRATE` rows never go through C.

## Workflow E: migrate legacy primary branches (master/main, develop/dev, qa/staging)

High risk (default branch, protection, CI/CD, open PRs, deployments). Read `references/branch-migration.md`
(section E) and follow it exactly, one primary branch at a time.

## Files and directories

Quick rules when creating or naming files:

| Platform | Source files | Example |
|---|---|---|
| Kotlin / Java | PascalCase, matches the main type | `LoginViewModel.kt`, `PaymentService.java` |
| Android resources | snake_case | `activity_login.xml`, `ic_bluetooth.xml` |
| Swift | PascalCase, matches the main type; extensions `Type+Feature.swift` | `LoginView.swift`, `String+Validation.swift` |
| Dart / Flutter | snake_case; tests end `_test` | `login_screen.dart`, `login_view_model_test.dart` |

Directories: no spaces or special characters, no generic names (`temp`, `misc`, `new`, `old`, `final`,
`developer-work`), shallow and purpose-named. Never keep versions as duplicate files (`LoginFinal2.kt`); use Git
history. Validate a new path with `audit-files.sh --path <path>`.

For auditing or renaming files and folders (workflow D) read `references/file-naming.md`.
