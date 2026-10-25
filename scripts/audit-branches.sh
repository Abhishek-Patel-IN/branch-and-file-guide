#!/bin/sh
# audit-branches.sh - read-only linter for branch names (Git Branching & File Naming Standards).
#
# Usage:
#   audit-branches.sh               audit local + remote-tracking branches of the repo in cwd
#   audit-branches.sh --name NAME   check one proposed branch name (no repo needed)
#   audit-branches.sh --self-test   run built-in tests
#
# Output (TSV): STATUS  branch  where  suggestion  reason
#   STATUS: OK | WARN (judgment needed) | FIX (breaks a rule) | MIGRATE (legacy primary branch)
#   Suggestions are mechanical candidates only; the agent refines them from commit history.
# Summary line goes to stderr. Audit modes never fetch or modify the repository; self-tests use temporary repos.
# Exit: 0 = no FIX/MIGRATE, 1 = FIX or MIGRATE found, 2 = usage or runtime error.

set -u

usage() {
  sed -n '4,7p' "$0" >&2
  exit 2
}

# stdin: "name<TAB>where[<TAB>symbolic-target]" lines; symbolic references are skipped.
classify() {
  LC_ALL=C awk -F '\t' '
  function vword(w) { return w ~ /^(new|old|final|latest|copy|backup|v[0-9]+)$/ }

  # Mechanical candidate: map prefix, keep/uppercase ticket, lowercase kebab slug, drop version words.
  function norm(n,   i, p, s, t, a, k, cnt, out) {
    i = index(n, "/"); p = tolower(substr(n, 1, i - 1)); s = substr(n, i + 1)
    if (p ~ /^(feature|features|feat)$/) p = "feature"
    else if (p ~ /^(bugfix|bugfixes|bug|bugs|fix|fixes)$/) p = "bugfix"
    else if (p ~ /^(hotfix|hotfixes)$/) p = "hotfix"
    else { p = "feature"; s = n }
    t = ""
    if (match(s, /^[A-Za-z][A-Za-z0-9]+-[0-9]+-/)) { t = toupper(substr(s, 1, RLENGTH)); s = substr(s, RLENGTH + 1) }
    while (match(s, /[a-z0-9][A-Z]/)) s = substr(s, 1, RSTART) "-" substr(s, RSTART + 1)      # ApplePay -> Apple-Pay
    while (match(s, /[A-Z][A-Z][a-z]/)) s = substr(s, 1, RSTART) "-" substr(s, RSTART + 1)     # HTMLParser -> HTML-Parser
    s = tolower(s); gsub(/[^a-z0-9]+/, "-", s)
    cnt = split(s, a, "-"); out = ""
    for (k = 1; k <= cnt; k++) if (a[k] != "" && !vword(a[k])) out = out (out == "" ? "" : "-") a[k]
    return out == "" ? "" : p "/" t out
  }

  # Sets globals st (status), sg (suggestion), rs (reason).
  function check(b,   l, s, a, k, cnt, why) {
    sg = ""; rs = ""; l = tolower(b)
    if (b ~ /^(production|qa_deliveries|development)$/) { st = "OK"; rs = "primary branch"; return }
    if (l ~ /^(production|qa_deliveries|development)$/) { st = "FIX"; sg = l; rs = "primary branch must be lowercase"; return }
    if (l ~ /^(master|main)$/)   { st = "MIGRATE"; sg = "production";    rs = "legacy primary branch"; return }
    if (l ~ /^(develop|dev)$/)   { st = "MIGRATE"; sg = "development";   rs = "legacy primary branch"; return }
    if (l ~ /^(qa|staging)$/)    { st = "MIGRATE"; sg = "qa_deliveries"; rs = "legacy primary branch"; return }
    if (b !~ /^(feature|bugfix|hotfix)\//) {
      st = "FIX"; sg = norm(b); rs = "missing or invalid prefix (feature/, bugfix/, hotfix/)"; return
    }
    if (b !~ /^(feature|bugfix|hotfix)\/([A-Z][A-Z0-9]+-[0-9]+-)?[a-z0-9]+(-[a-z0-9]+)*$/) {
      st = "FIX"; sg = norm(b); rs = "slug must be lowercase kebab-case with optional TICKET-123- prefix"; return
    }
    # Structurally valid: semantic checks are WARN only.
    s = substr(b, index(b, "/") + 1); sub(/^[A-Z][A-Z0-9]+-[0-9]+-/, "", s); why = ""
    if (s ~ /^[a-z][a-z0-9]+-[0-9]+-/) { why = "ticket ID should be uppercase"; sub(/^[a-z][a-z0-9]+-[0-9]+-/, "", s) }
    cnt = split(s, a, "-")
    # ponytail: 2-5 words is our heuristic for "short but descriptive"; the standard gives no number.
    if (cnt < 2 || cnt > 5) why = why (why == "" ? "" : "; ") "slug has " cnt " words (aim for 2-5)"
    for (k = 1; k <= cnt; k++) if (vword(a[k])) why = why (why == "" ? "" : "; ") "version word: " a[k]
    if (why == "") { st = "OK"; return }
    st = "WARN"; rs = why; sg = norm(b); if (sg == b) sg = ""
  }

  NF == 0 || $3 != "" { next }
  {
    w = $2
    if (index(w, "/")) w = substr(w, 1, length(w) - length($1) - 1)   # origin/feature/x -> origin
    if (!($1 in where)) { order[++n] = $1; where[$1] = w }
    else if (w != "") where[$1] = where[$1] "," w
  }
  END {
    for (r = 1; r <= n; r++) {
      b = order[r]; check(b); cnt[st]++
      printf "%s\t%s\t%s\t%s\t%s\n", st, b, (where[b] == "" ? "-" : where[b]), (sg == "" ? "-" : sg), (rs == "" ? "-" : rs)
    }
    printf "# %d FIX, %d WARN, %d MIGRATE, %d OK\n", cnt["FIX"], cnt["WARN"], cnt["MIGRATE"], cnt["OK"] > "/dev/stderr"
    exit (cnt["FIX"] + cnt["MIGRATE"] > 0)
  }'
}

self_test() {
  self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  test_dir=$(mktemp -d "${TMPDIR:-/tmp}/branch-audit.XXXXXX") || exit 2
  trap 'rm -rf "$test_dir"' 0
  trap 'exit 2' 1 2 3 15
  # STATUS<TAB>name[<TAB>expected suggestion]
  cases='OK	feature/user-login
OK	feature/APP-123-user-login
OK	bugfix/APP-245-api-timeout
OK	hotfix/payment-failure
OK	production
OK	qa_deliveries
OK	development
OK	feature/APP-1-user-login-screen-otp-flow
MIGRATE	master	production
MIGRATE	main	production
MIGRATE	develop	development
MIGRATE	dev	development
MIGRATE	qa	qa_deliveries
MIGRATE	staging	qa_deliveries
FIX	Production	production
FIX	developer_dev
FIX	developer_changes
FIX	HEAD
FIX	my-branch
FIX	test-branch
FIX	New-changes
FIX	final-feature
FIX	release/1.2.0
FIX	feature/
FIX	feature/user--login
FIX	feature/-login
FIX	feature/APP123-user-login
FIX	feature/Login_New	feature/login
FIX	feat/user-login	feature/user-login
FIX	Feature/user-login	feature/user-login
FIX	fix/API_Timeout	bugfix/api-timeout
FIX	feature/ApplePay	feature/apple-pay
FIX	bugfix/HTMLLanguageLocalization	bugfix/html-language-localization
FIX	agoraChannel_XcodeWarnings	feature/agora-channel-xcode-warnings
WARN	feature/login
WARN	feature/user-login-screen-with-otp-and-biometric
WARN	feature/app-123-user-login	feature/APP-123-user-login
WARN	feature/final-feature
WARN	feature/new-user-onboarding	feature/user-onboarding'

  fails=$(printf '%s\n' "$cases" | cut -f2 | classify 2>/dev/null | CASES="$cases" awk -F '\t' '
    BEGIN {
      n = split(ENVIRON["CASES"], L, "\n")
      for (i = 1; i <= n; i++) { split(L[i], f, "\t"); want[f[2]] = f[1]; if (f[3] != "") sug[f[2]] = f[3] }
    }
    { seen[$2] = 1
      if (!($2 in want)) print "FAIL unexpected row: " $2
      else if ($1 != want[$2]) print "FAIL " $2 ": status " $1 ", want " want[$2]
      if (($2 in sug) && $4 != sug[$2]) print "FAIL " $2 ": suggestion " $4 ", want " sug[$2] }
    END { for (k in want) if (!(k in seen)) print "FAIL missing row: " k }')

  exit_checks=0
  expect_exit() {
    want=$1; shift
    exit_checks=$((exit_checks + 1))
    output=$("$@" 2>"$test_dir/stderr"); got=$?
    [ "$got" -eq "$want" ] || fails="${fails}
FAIL exit code of '$*': $got, want $want"
    if [ "$want" -eq 2 ] && { [ -n "$output" ] || LC_ALL=C awk '/^# [0-9]+ FIX/ { found = 1 } END { exit !found }' "$test_dir/stderr"; }; then fails="${fails}
FAIL runtime/usage error printed audit results: $*"; fi
  }
  expect_exit 0 sh "$self" --name feature/user-login
  expect_exit 0 sh "$self" --name feature/login
  expect_exit 1 sh "$self" --name developer_dev
  expect_exit 1 sh "$self" --name master
  expect_exit 2 sh "$self" --name
  expect_exit 2 sh "$self" --bogus
  expect_exit 2 env GIT_DIR=/nonexistent-git-dir sh "$self"

  expect_exit 1 sh "$self" --name HEAD
  expect_exit 2 sh "$self" --name ''
  expect_exit 2 sh "$self" --name "$(printf 'feature/bad\tname')"
  expect_exit 2 sh "$self" --name "$(printf 'feature/bad\nname')"
  expect_exit 2 sh "$self" --name "$(printf 'feature/bad\rname')"
  expect_exit 1 sh "$self" --name feature/日本語

  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  export GIT_AUTHOR_NAME=Anonymous GIT_AUTHOR_EMAIL=anonymous@example.invalid
  export GIT_COMMITTER_NAME=Anonymous GIT_COMMITTER_EMAIL=anonymous@example.invalid
  git init -q -b production "$test_dir/work" || exit 2
  cd "$test_dir/work" || exit 2
  expect_exit 0 sh "$self"
  tree=$(git mktree </dev/null) || exit 2
  original=$(printf 'Initial\n' | git commit-tree "$tree") || exit 2
  git update-ref refs/heads/production "$original" || exit 2
  git update-ref refs/heads/feature/user-login "$original" || exit 2
  git update-ref refs/remotes/origin/feature/user-login "$original" || exit 2
  git update-ref refs/remotes/origin/feature/remote-only "$original" || exit 2
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/feature/user-login || exit 2
  expect_exit 0 sh "$self"
  actual=$(sh "$self" 2>/dev/null)
  expected=$(printf 'OK\tfeature/user-login\tlocal,origin\t-\t-\nOK\tproduction\tlocal\t-\tprimary branch\nOK\tfeature/remote-only\torigin\t-\t-')
  [ "$actual" = "$expected" ] || fails="${fails}
FAIL repository audit lost a branch, its scope, or included symbolic HEAD"

  mkdir "$test_dir/bin" || exit 2
  cat >"$test_dir/bin/git" <<'SHIM'
#!/bin/sh
case "$*" in
  'rev-parse --git-dir') exit 0 ;;
  *refs/heads) [ "$AUDIT_FAIL" = local ] || exit 0 ;;
  *refs/remotes) [ "$AUDIT_FAIL" = remote ] || exit 0 ;;
esac
echo 'fatal: injected Git read failure' >&2
exit 128
SHIM
  chmod +x "$test_dir/bin/git" || exit 2
  expect_exit 2 env PATH="$test_dir/bin:$PATH" AUDIT_FAIL=local sh "$self"
  expect_exit 2 env PATH="$test_dir/bin:$PATH" AUDIT_FAIL=remote sh "$self"

  # Exercise the documented rename commands against a local remote, including stale approvals.
  git init --bare -q -b production "$test_dir/remote.git" || exit 2
  git remote add origin "$test_dir/remote.git" || exit 2
  git push -q origin production "$original:refs/heads/legacy" || exit 2
  local_tip=$(printf 'Local work\n' | git commit-tree "$tree" -p "$original") || exit 2
  remote_tip=$(printf 'Remote work\n' | git commit-tree "$tree" -p "$original") || exit 2
  git update-ref refs/heads/legacy "$local_tip" || exit 2
  expect_exit 0 git branch -m legacy feature/renamed-work
  expect_exit 0 git push --force-with-lease=refs/heads/feature/renamed-work: origin "$original:refs/heads/feature/renamed-work"
  git push -q origin "$remote_tip:refs/heads/legacy" || exit 2
  expect_exit 1 git push "--force-with-lease=refs/heads/legacy:$original" origin :refs/heads/legacy
  expect_exit 1 git push --force-with-lease=refs/heads/feature/renamed-work: origin "$local_tip:refs/heads/feature/renamed-work"
  [ "$(git rev-parse refs/heads/feature/renamed-work)" = "$local_tip" ] &&
    [ "$(git --git-dir="$test_dir/remote.git" rev-parse refs/heads/legacy)" = "$remote_tip" ] &&
    [ "$(git --git-dir="$test_dir/remote.git" rev-parse refs/heads/feature/renamed-work)" = "$original" ] || fails="${fails}
FAIL rename overwrote local work, newer remote work, or an existing destination"

  git push -q origin "$original:refs/heads/remote-only" || exit 2
  expect_exit 0 git push --force-with-lease=refs/heads/feature/remote-work: origin "$original:refs/heads/feature/remote-work"
  [ "$(git --git-dir="$test_dir/remote.git" rev-parse refs/heads/feature/remote-work)" = "$original" ] || fails="${fails}
FAIL remote-only destination did not preserve its recorded commit"
  expect_exit 0 git push "--force-with-lease=refs/heads/remote-only:$original" origin :refs/heads/remote-only
  expect_exit 1 git show-ref --verify --quiet refs/heads/remote-only
  expect_exit 1 git show-ref --verify --quiet refs/heads/feature/remote-work
  expect_exit 1 git --git-dir="$test_dir/remote.git" show-ref --verify --quiet refs/heads/remote-only

  if [ -n "$fails" ]; then printf '%s\n' "$fails" >&2; exit 1; fi
  echo "audit-branches self-test: all $(printf '%s\n' "$cases" | wc -l | tr -d ' ') cases + $exit_checks exit codes + repository/rename assertions passed"
}

case "${1:-}" in
  --name)
    [ $# -eq 2 ] || usage
    case "$2" in ''|*[[:cntrl:]]*) echo 'audit-branches: name must be nonempty and contain no control characters' >&2; exit 2 ;; esac
    printf '%s\t\n' "$2" | classify ;;
  --self-test) self_test ;;
  "")
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "audit-branches: not a git repository" >&2; exit 2; }
    # ponytail: remote names containing "/" are not supported (lstrip=3 assumes one path segment).
    local_refs=$(git for-each-ref --format='%(refname:lstrip=2)%09local' refs/heads) || exit 2
    remote_refs=$(git for-each-ref --format='%(refname:lstrip=3)%09%(refname:lstrip=2)%09%(symref)' refs/remotes) || exit 2
    printf '%s\n%s\n' "$local_refs" "$remote_refs" | classify ;;
  *) usage ;;
esac
