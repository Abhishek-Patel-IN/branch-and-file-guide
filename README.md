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

### Antigravity App/IDE — Windows global installation

Use Windows PowerShell 5.1 or PowerShell 7. The explicit `--agent antigravity` option bypasses the missing
Antigravity entry in the installer's grouped chooser; it does not change that chooser. `npx.cmd` uses the
Windows command shim without changing PowerShell's execution policy.

**1. Install and check the files.** Run this block, then continue only if the installer reports a completed
installation. If you cancel, stop here: files from an older installation can still pass the file checks.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    npx.cmd skills add Abhishek-Patel-IN/branch-and-file-naming-guide --skill branch-and-file-naming-guide --agent antigravity --global
    if ($LASTEXITCODE -ne 0) { throw 'Installation failed. Stop here.' }

    $source = Join-Path $HOME '.agents\skills\branch-and-file-naming-guide'
    $required = @(
        'SKILL.md',
        'scripts\audit-branches.sh',
        'scripts\audit-files.sh',
        'references\branch-migration.md',
        'references\file-naming.md'
    )
    foreach ($file in $required) {
        $path = Join-Path $source $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing installed file: $path" }
    }
    Write-Host "Installed files checked at: $source"
}
```

Behavior checked with [skills 1.7.4](https://www.npmjs.com/package/skills/v/1.7.4): global Antigravity installs
still go to `~/.agents/skills/`. The [official Antigravity locations](https://antigravity.google/docs/skills)
are `~/.gemini/config/skills/` globally and `<workspace>/.agents/skills/` for a project. The IDE also supports
the legacy global location `~/.gemini/antigravity/skills/`; that compatibility is not documented for the App.

**2. Check discovery before copying anything.** Start a fresh conversation in a project without another
project-level copy of this skill. In the IDE, inspect active skills through **Customizations** in the agent
side panel. In the App, enter `/branch-and-file-naming-guide`. In either product, ask the agent to use
`branch-and-file-naming-guide` and report the location of the `SKILL.md` it loaded.

If it is discovered, skip the repair below, including when the IDE already uses a working legacy installation.
A successful installer summary alone does not prove discovery. If a newer installer reports a different
installation location, check that location and discovery before attempting this repair.

**3. Check that it works.** Enter this read-only prompt in Antigravity:

> Use branch-and-file-naming-guide. Report its loaded location, read its bundled references/file-naming.md,
> and run its bundled scripts/audit-files.sh --path lib/login_screen.dart through Git Bash. Report the result
> without modifying files.

Expect `OK` for `lib/login_screen.dart` and exit code `0`. If Git Bash is unavailable, report script execution
as **unverified**; missing Git Bash does not mean the skill was not discovered.

**Windows validation is pending.** PowerShell 5.1/7 execution and Antigravity App/IDE discovery have not been
tested on Windows. Local file checks and the sample audit do not establish Windows compatibility.
Antigravity CLI uses a different global location and is not covered by this workaround.

Before marking this workflow verified, record Windows, PowerShell, installer, and Antigravity versions and test:

- Installation success, command launch failure, nonzero exit, and cancellation with older files still present.
- Modern and legacy destination preservation: files, directories, links (including dangling links), and junctions.
- Home paths containing spaces or brackets; missing source files; complete copying of scripts and references.
- Copy/publication failures, permissions, locked files, and redirected or cross-volume paths. Existing data must
  survive; no incomplete destination may appear. Cleanup failure must retain the original error, including with
  `$WarningPreference = 'Stop'`, and report any leftover staging path.
- Fresh App and IDE conversations: global discovery, loaded location, reference access, and Git Bash execution.
  Confirm an already discovered skill skips repair and missing Git Bash is reported separately.
- Updating without stale files, restoring the backup after a failed repair, and scoped uninstall plus manual-copy
  removal without affecting other skills.

<details>
<summary>Skill still missing?</summary>

Only if discovery failed, run this block to copy the **entire installed skill folder**, including its scripts
and references, into the global location shared by App and IDE. It stops if the skill already exists at either
the modern or legacy global location, including as a file, link, or junction. Inspect the reported path and
back up any existing installation outside the skills directories before retrying; do not overwrite it blindly.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $name = 'branch-and-file-naming-guide'
    $source = Join-Path $HOME ".agents\skills\$name"
    $config = Join-Path $HOME '.gemini\config'
    $skills = Join-Path $config 'skills'
    $destination = Join-Path $skills $name
    $legacy = Join-Path $HOME '.gemini\antigravity\skills'
    $required = @(
        'SKILL.md',
        'scripts\audit-branches.sh',
        'scripts\audit-files.sh',
        'references\branch-migration.md',
        'references\file-naming.md'
    )
    $stage = $null
    try {
        foreach ($file in $required) {
            $path = Join-Path $source $file
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing source file: $path" }
        }
        foreach ($parent in @($skills, $legacy)) {
            if (Test-Path -LiteralPath $parent -PathType Container) {
                $existing = Get-ChildItem -LiteralPath $parent -Force | Where-Object { $_.Name -eq $name }
                if ($existing) { throw "Existing installation preserved: $(Join-Path $parent $name)" }
            }
        }

        [void][System.IO.Directory]::CreateDirectory($skills)
        $stageName = '.skill-install-' + [guid]::NewGuid().ToString('N')
        $existing = Get-ChildItem -LiteralPath $config -Force | Where-Object { $_.Name -eq $stageName }
        if ($existing) { throw 'Staging path already exists. Run the repair again.' }
        $stage = Join-Path $config $stageName
        Copy-Item -LiteralPath $source -Destination $stage -Recurse -Force -ErrorAction Stop
        foreach ($file in $required) {
            $path = Join-Path $stage $file
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing copied file: $path" }
        }

        [System.IO.Directory]::Move($stage, $destination)
        $stage = $null
        Write-Host "Complete skill copied to: $destination"
    } catch {
        $failure = $_
        if ($stage) {
            try {
                if (Test-Path -LiteralPath $stage) {
                    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop
                }
            } catch {
                Write-Warning "Could not clean staging directory: $stage. $($_.Exception.Message)" -WarningAction Continue
            }
        }
        throw $failure
    }
}
```

This stages the copy beside `skills`, outside its discovery root, and checks all five required files before
publishing it. [Directory.Move](https://learn.microsoft.com/en-us/dotnet/api/system.io.directory.move)
rejects an existing destination instead of overwriting it or nesting the copy inside it. Permissions, locked
files, redirected directories, or different volumes can still make the move fail; it is not a guarantee of
atomic installation. Only this run's staging directory is cleaned up on failure.

After a successful copy, repeat steps 2 and 3. If discovery still fails, record the Antigravity product/version,
installer version, reported installation path, and error; do not create more copies or delete existing skills.

</details>

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

### Antigravity Windows workaround: update or uninstall

Back up any customizations in the installed or manually copied skill before reinstalling. To update, rerun the
explicit Antigravity installation block [above](#antigravity-appide--windows-global-installation); generic
`skills update` does not offer an agent filter. If you used the copy workaround, move the old copied folder to
a backup **outside all skills directories**, then rerun the guarded repair and discovery/functionality checks.
Replace the whole folder rather than merging files, so removed files do not linger. Restore the backup if the
repair fails. Inspect a reported legacy installation separately before moving it.

To remove the installer-managed Antigravity installation, run:

```powershell
npx.cmd skills remove branch-and-file-naming-guide --global --agent antigravity
```

Installer update/removal does **not** maintain the manual copy. After preserving customizations, separately
remove only the physical folder created by this workaround:
`$HOME\.gemini\config\skills\branch-and-file-naming-guide`. Do not delete a skills root or recursively delete
an unidentified link or junction. The canonical `~/.agents/skills/` folder may remain if other assistants share
it. Start a fresh conversation after removal to check that this installation is no longer discovered.

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
