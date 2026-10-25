# Branch audit, rename and primary-branch migration

Loaded by `SKILL.md` for workflows C and E. All safety rules from `SKILL.md` apply. `<remote>` is resolved as in
safety rule 5, `<skill>` is the directory containing `SKILL.md`.

## Provider detection (C and E)

`git remote get-url <remote>`:
- contains `github` and `gh auth status` succeeds -> GitHub checks available;
- contains `gitlab` and `glab auth status` succeeds -> GitLab checks available;
- anything else (Bitbucket, Azure DevOps, self-hosted, no CLI, not logged in) -> every provider check is
  `NOT VERIFIED`. Never install a CLI or log in on the user's behalf.

Read-only provider queries:

| Check | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| Open PRs from branch | `gh pr list --head <b> --state open` | `glab mr list --source-branch <b>` |
| Open PRs into branch | `gh pr list --base <b> --state open` | `glab mr list --target-branch <b>` |
| Default branch | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` | `glab repo view` |
| Protection / rulesets | `gh api repos/{owner}/{repo}/branches/<b-encoded>/protection`, `gh api repos/{owner}/{repo}/rules/branches/<b-encoded>` | project settings (or `NOT VERIFIED`) |

`<b-encoded>` = branch name with `/` written as `%2F`. A 403/404 on protection means "not visible", report it as
`NOT VERIFIED`, not as "unprotected".

---

## C. Audit and rename existing work branches

1. **Detect**: `git fetch --all --prune`, then `sh <skill>/scripts/audit-branches.sh`.
   Rows with `MIGRATE` go to section E, never to this loop. `OK` rows need nothing.
2. **Understand each FIX/WARN branch** (the mechanical suggestion is only a starting point):
   - `git log --oneline -n 20 <remote>/development..<branch>` (or `<branch>` alone if that range is empty) to see
     what the work actually is; name it after the work, not after the person or phase.
   - Merged? `git merge-base --is-ancestor <branch> <remote>/development` (exit 0 = merged). Squash-merged branches
     look unmerged; check PR history if a provider is available. A merged, finished branch should be **deleted**
     rather than renamed (standard: delete temporary branches after integration) - propose it, don't do it.
   - Ask the user when the purpose cannot be inferred. Never invent a ticket ID.
3. **Provider pre-check** for every branch that exists on the remote: open PRs from it (table above).
   Defer a rename or deletion while the branch is the source/head of an open PR; list the affected PRs.
   No provider access -> `NOT VERIFIED`; the user must verify that no open source PRs remain before proceeding.
   Do not automatically close, recreate or edit PRs. GitHub updates PR **base** branches on rename, but closes
   PRs whose **head** branch is renamed ([GitHub documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-branches-in-your-repository/renaming-a-branch)).
4. **Propose** one table and record local and remote SHAs separately (needed for verification and rollback):

   | old | new | scope | action | open PRs | local SHA | remote SHA |
   |---|---|---|---|---|---|---|
   | `developer_dev` | `feature/device-pairing` | local + origin | rename | none (verified) | `a1b2c3d` | `c4d5e6f` |
   | `Phase_2` | - | origin | delete (merged) | none (verified) | - | `9f8e7d6` |

   Capture full SHAs (shortened above): local with `git rev-parse "refs/heads/$old"`, remote with
   `git ls-remote --heads "$remote" "refs/heads/$old"`. Different local and remote tips are allowed; preserve
   each independently, without merging or overwriting either. Ensure the fetched remote object is available
   locally with `git cat-file -e "$remote_sha^{commit}"`; if not, fetch and recheck before approval.
   Commands below use `remote`, `old`, `new`, `local_sha` and `remote_sha` from the approved row.
   The user approves the table (or edits rows, then show it again). The approval must explicitly cover remote
   changes for rows with remote scope. Each deletion needs its own explicit yes.
5. **Execute row by row**, stop at the first error:
   - target name already exists (local or remote) -> skip the row and report;
   - Recheck the local tip and live remote tip against their respective recorded SHAs. If either changed,
     stop and report; refresh the proposal rather than proceeding under stale approval.
   - local copy, only when it exists: `git branch -m "$old" "$new"`;
   - remote copy, GitHub with `gh`: `gh api -X POST "repos/{owner}/{repo}/branches/<old-encoded>/rename" -f "new_name=$new"`.
     This moves protection and updates PR bases; the source-PR pre-check above still applies. Verify the new
     remote ref and its SHA, then `git fetch "$remote" --prune`. If the new ref is not yet visible, stop and
     report the pending rename; do not repeat the mutation.
   - remote copy, otherwise: create the destination from the recorded **remote** SHA, requiring it to be absent:
     ```bash
     git push --force-with-lease="refs/heads/$new:" "$remote" "$remote_sha:refs/heads/$new"
     ```
     Verify the destination with `git ls-remote --heads "$remote" "refs/heads/$new"` before deleting the source:
     ```bash
     git push --force-with-lease="refs/heads/$old:$remote_sha" "$remote" ":refs/heads/$old"
     ```
     The explicit leases prevent overwriting a destination or deleting a source advanced since approval.
     If deletion fails after creation, keep both branches and report a partial rename. Never retry with
     unrestricted force. After success, `git fetch "$remote" --prune`.
   - Set upstream with `git branch -u "$remote/$new" "$new"` only if a local renamed branch exists, after the
     remote destination has been verified and fetched. A remote-only rename creates no local branch.
   - delete rows: use the same recorded-SHA leased remote deletion above and/or `git branch -d "$old"`
     (`-d`, not `-D`; if Git refuses because it is unmerged, stop and ask).
6. **Verify**: re-run `audit-branches.sh`; the local renamed branch, if present, retains `local_sha`, and
   `git ls-remote --heads "$remote" "refs/heads/$new"` retains `remote_sha`. Deleted remote names are absent.
   Report any mismatch or partial operation; do not reset or force either tip to make the check pass.
7. **Report** the final table plus the snippet for teammates who have the old branch checked out:

   ```bash
   git fetch --prune && git branch -m <old> <new> && git branch -u <remote>/<new> <new>
   ```

Rollback: local `git branch -m "$new" "$old"`; restore a deleted remote branch only if its name is still absent:
`git push --force-with-lease="refs/heads/$old:" "$remote" "$remote_sha:refs/heads/$old"`.
GitHub rename -> recheck affected PRs and current refs, then rename back with the same API call. A changed or
occupied ref requires a refreshed plan; rollback must not overwrite newer work.

---

## E. Migrate legacy primary branches

Mapping: `master` / `main` -> `production`, `develop` / `dev` -> `development`, `qa` / `staging` -> `qa_deliveries`.
These branches drive the default branch, protection rules, CI/CD triggers, open PRs and deployments. Handle **one
primary branch at a time**, never inside a workflow C table.

1. **Inventory (read-only)**:
   - legacy branches locally and on the remote with separate full `local_sha` / `remote_sha` values
     (`git for-each-ref`, `git ls-remote --heads <remote>`), as in section C;
   - conflicts: both `main` and `master` exist -> ask which one is production; a target name already exists ->
     compare SHAs and ask (may already be migrated, or diverged);
   - default branch as Git sees it: `git symbolic-ref refs/remotes/<remote>/HEAD` (run `git remote set-head <remote> -a`
     first if it is missing);
   - CI/config references (expect noise from words like `main`/`dev`, review each hit):
     `git grep -nwE 'master|main|develop|dev|qa|staging' -- .github .gitlab-ci.yml bitbucket-pipelines.yml Jenkinsfile fastlane codemagic.yaml bitrise.yml azure-pipelines.yml .circleci`
   - provider: default branch, protection/rulesets, open PRs into and from the branch (table at the top).
     Defer source/head-branch renames or deletion while source PRs are open. `NOT VERIFIED` requires the user's
     verification before proceeding; changing PR bases does not preserve PRs whose head branch is renamed.
2. **Report** a checklist, each item `OK`, `NEEDS CHANGE` or `NOT VERIFIED`:
   default branch, protection/rulesets, open PRs targeting it, CI/CD config in repo, deploy systems configured
   outside the repo (Codemagic/Bitrise/Xcode Cloud/Firebase/Play Console/App Store Connect automation, webhooks),
   teammates' local clones. Deploy systems outside the repo are **always** `NOT VERIFIED`; the user must confirm them.
   Recommend telling the team and pausing merges into the branch during the migration.
3. **Confirm** this one primary branch's migration explicitly.
4. **Execute, additive first**:
   Recheck recorded local and remote tips before mutation. Stop if either changed; ensure `remote_sha` is
   available locally. Preserve different local/remote tips independently, as in section C.
   - GitHub with `gh` and admin rights (separate yes, it changes provider settings):
     `gh api -X POST "repos/{owner}/{repo}/branches/<old-encoded>/rename" -f "new_name=$new"`. GitHub updates PR
     **bases**, moves protection rules and updates the default branch; renaming a PR **head** closes that PR.
     Verify the new ref and recorded remote SHA before continuing. If it is not yet visible, report the pending
     rename without repeating it. The old name then redirects; there is nothing left to delete.
   - Otherwise:
     1. Create the new branch at the same commit without touching local branches:
        `git push --force-with-lease="refs/heads/$new:" "$remote" "$remote_sha:refs/heads/$new"`
        Verify that the destination matches `remote_sha` before changing provider settings.
     2. Default branch (if the old branch was default), protection rules and open PR/MR retargeting: via
        `gh repo edit --default-branch <new>`, `gh pr edit <n> --base <new>`, `glab` equivalents (each a separate yes),
        or by the user in the provider UI. Ask the user to confirm each manual step is done.
     3. CI/config references: change them on a work branch (workflow A, e.g. `feature/standard-branch-names`) with
        an approved edit list; merging it is the team's normal PR process.
5. **Old branch** - only after default branch, PRs and CI are switched, and with its own explicit yes:
   recommend keeping it for a grace period (protected/read-only) instead of deleting. If the user wants it gone:
   `git push --force-with-lease="refs/heads/$old:$remote_sha" "$remote" ":refs/heads/$old"`.
   If the lease fails, keep both branches and report the changed source; do not retry with force.
6. **Missing primaries** with no legacy source (for example no QA branch at all): offer to create it from
   `production` (nothing delivered to QA yet) or a base the user chooses:
   `git push <remote> <remote>/production:refs/heads/qa_deliveries` - confirm first.
7. **Update the local clone** (rename and set upstream only when the old local branch exists):
   ```bash
   git fetch <remote> --prune
   git branch -m <old> <new>
   git branch -u <remote>/<new> <new>
   git remote set-head <remote> -a
   ```
8. **Verify**: the renamed local branch retains `local_sha`, if present; `git ls-remote --heads <remote> <new>`
   equals `remote_sha`; `git remote show <remote>` shows the expected HEAD branch. Provider checks re-run, or
   listed as `NOT VERIFIED`. Re-run `audit-branches.sh`; report mismatches without resetting either tip.
9. **Report** the checklist with final statuses and give teammates the step 7 commands.

Rollback: GitHub rename -> recheck PRs and refs before renaming back. Manual path -> before step 5 the old branch
still exists: switch provider settings back, then delete the new branch only with approval and a matching-SHA
lease (`git push --force-with-lease="refs/heads/$new:$remote_sha" "$remote" ":refs/heads/$new"`). After step 5,
first restore the old branch with the absent-target lease from section C, then switch settings back.
Keep both refs if either changed; do not overwrite newer work during rollback.
