#!/bin/sh
# audit-files.sh - read-only linter for file and directory names (Git Branching & File Naming Standards).
#
# Usage:
#   audit-files.sh [DIR]            audit tracked files under DIR (default: cwd) of the repo in cwd
#   audit-files.sh --path PATH      check one proposed relative path (no repo needed; prints OK too)
#   audit-files.sh --self-test      run built-in tests
#
# Output (TSV): STATUS  path  reason       (directories end with "/")
#   STATUS: FIX (breaks an explicit rule) | WARN (judgment needed, e.g. version words) | OK (--path only)
# Directories are derived from tracked file paths; empty directories are not tracked by Git and not audited.
# Summary line goes to stderr. Audit modes never modify the repository; self-tests use temporary repos.
# Exit: 0 = no FIX, 1 = FIX found, 2 = usage or runtime error.

set -u

usage() {
  sed -n '4,7p' "$0" >&2
  exit 2
}

# stdin: one relative path per line. $1 = 1 to print OK rows for files.
audit() {
  # ponytail: case folding is ASCII-only; Unicode case collisions need a Unicode-aware parser.
  LC_ALL=C awk -v showok="$1" '
  function vword(w) { return w ~ /^(new|old|final|latest|copy|backup|v[0-9]+)$/ }

  # Version words found in a name, split on separators, camelCase and letter/digit boundaries ("V2" stays one token).
  function vwords(s,   i, c, prev, tok, out, sp, len) {
    out = ""; tok = ""; prev = ""; len = length(s)
    for (i = 1; i <= len + 1; i++) {
      c = (i <= len) ? substr(s, i, 1) : "_"
      sp = 0
      if (c !~ /[A-Za-z0-9]/) sp = 1
      else if (prev ~ /[a-z]/ && c ~ /[A-Z]/) sp = 1
      else if (prev ~ /[A-Za-z]/ && c ~ /[0-9]/ && tolower(tok) != "v") sp = 1
      else if (prev ~ /[0-9]/ && c ~ /[A-Za-z]/) sp = 1
      if (sp) { if (vword(tolower(tok))) out = out (out == "" ? "" : ", ") tolower(tok); tok = "" }
      if (c ~ /[A-Za-z0-9]/) tok = tok c
      prev = c
    }
    return out
  }

  function add(p, sev, why) {
    if (!(p in fix)) { order[++n] = p; fix[p] = ""; warn[p] = "" }
    if (sev == "FIX") fix[p] = fix[p] (fix[p] == "" ? "" : "; ") why
    else warn[p] = warn[p] (warn[p] == "" ? "" : "; ") why
  }

  # Checks shared by file and directory names.
  function common(p, name,   t, v) {
    if (name ~ / /) add(p, "FIX", "space in name")
    t = name; gsub(/@[1-3]x/, "", t)          # iOS scale suffix Icon@2x.png is fine
    if (t ~ /[@#$%&!]/) add(p, "FIX", "special character in name")
    if ((v = vwords(name)) != "") add(p, "WARN", "version word: " v)
  }

  # Case-only duplicates (UserService.kt vs userService.kt) break on case-insensitive file systems.
  function collide(p,   l) {
    l = tolower(p)
    if ((l in lower) && lower[l] != p) {
      add(p, "FIX", "case-only duplicate of " lower[l]); add(lower[l], "FIX", "case-only duplicate of " p)
    } else lower[l] = p
  }

  # Excluded: dependency/build output and generated code.
  /(^|\/)(Pods|build|\.dart_tool|node_modules|Carthage|\.gradle|\.idea|DerivedData)\// { next }
  /\.(xcodeproj|xcworkspace)\// { next }
  /\.(g|freezed|mocks)\.dart$/ || /\.generated\.swift$/ { next }
  $0 == "" { next }

  {
    p = $0; k = split(p, part, "/"); d = ""
    for (j = 1; j < k; j++) {
      d = d part[j] "/"
      if (d in seendir) continue
      seendir[d] = 1; collide(d)
      if (tolower(part[j]) ~ /^(temp|misc|new|old|final|developer-work)$/) add(d, "FIX", "generic directory name")
      else common(d, part[j])
    }
    # Files inside asset-catalog sets (SampleIcon.imageset/check-box 1@2x.png) are Xcode-managed and never
    # referenced from code; the set names above are still audited.
    if (p ~ /\.(imageset|appiconset|colorset|symbolset|dataset)\/[^\/]+$/) next

    f = part[k]; files[p] = 1; nfiles++
    if (!(p in fix)) { order[++n] = p; fix[p] = ""; warn[p] = "" }
    collide(p)
    common(p, f)

    base = f; ext = ""
    if (match(f, /\.[^.]+$/)) { base = substr(f, 1, RSTART - 1); ext = substr(f, RSTART + 1) }

    if (ext ~ /^(kt|java|swift)$/ && f !~ /^(main\.swift|package-info\.java|module-info\.java)$/ \
        && base !~ /^[A-Z][A-Za-z0-9]*(\+[A-Z][A-Za-z0-9]*)?$/)
      add(p, "FIX", "Kotlin/Java/Swift files use PascalCase")
    if (ext == "dart" && base !~ /^[a-z][a-z0-9_]*$/)
      add(p, "FIX", "Dart files use snake_case")
    if (p ~ /(^|\/)res\/(anim|animator|color|drawable|font|layout|menu|mipmap|navigation|raw|transition|values|xml)[^\/]*\/[^\/]+$/) {
      r = base; sub(/\.9$/, "", r)             # nine-patch: name.9.png
      if (r !~ /^[a-z][a-z0-9_]*$/) add(p, "FIX", "Android resource files use snake_case")
    }
  }

  END {
    for (i = 1; i <= n; i++) {
      p = order[i]
      if (fix[p] != "") { st = "FIX"; why = fix[p] (warn[p] == "" ? "" : "; " warn[p]) }
      else if (warn[p] != "") { st = "WARN"; why = warn[p] }
      else if (showok && (p in files)) { st = "OK"; why = "-" }
      else continue
      cnt[st]++
      printf "%s\t%s\t%s\n", st, p, why
    }
    printf "# %d FIX, %d WARN (%d files scanned)\n", cnt["FIX"], cnt["WARN"], nfiles > "/dev/stderr"
    exit (cnt["FIX"] > 0)
  }'
}

self_test() {
  self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  test_dir=$(mktemp -d "${TMPDIR:-/tmp}/file-audit.XXXXXX") || exit 2
  trap 'rm -rf "$test_dir"' 0
  trap 'exit 2' 1 2 3 15
  # STATUS<TAB>path   (SKIP = excluded, must produce no row; directory rows only appear when they have findings)
  cases='OK	app/src/main/java/com/acme/LoginActivity.kt
OK	app/src/main/java/com/acme/PaymentService.java
OK	ios/Sources/String+Extensions.swift
OK	ios/Sources/main.swift
OK	ios/Tests/LoginViewModelTests.swift
OK	test/login_view_model_test.dart
OK	app/src/main/res/drawable/ic_bluetooth.xml
OK	app/src/main/res/drawable/bg_button.9.png
OK	ios/Assets.xcassets/Icon@2x.png
SKIP	ios/Assets.xcassets/icon.imageset/check-box 1@2x.png
FIX	ios/Assets.xcassets/App Colors/
SKIP	ios/Assets.xcassets/App Colors/brand.colorset/Contents.json
OK	ios/Sources/WhatsNewsFeed.swift
OK	app/src/main/java/com/acme/DeveloperLogin.kt
OK	docs/日本語.txt
FIX	app/src/main/java/com/acme/auth/loginActivity.kt
FIX	app/src/main/java/com/acme/login_activity.kt
FIX	lib/LoginScreen.dart
FIX	app/src/main/res/layout/ActivityLogin.xml
OK	User Profile/Foo.swift
FIX	User Profile/
FIX	ios/Sources/Login Screen.swift
OK	payment#module/a.dart
FIX	payment#module/
OK	temp/a.dart
FIX	temp/
FIX	app/src/main/java/com/acme/UserService.kt
FIX	app/src/main/java/com/acme/userService.kt
WARN	app/src/main/java/com/acme/LoginFinal.kt
WARN	app/src/main/java/com/acme/LoginFinal2.kt
WARN	ios/Sources/LoginNew.swift
WARN	ios/Sources/PaymentServiceOld.swift
WARN	lib/login_new.dart
WARN	lib/login_v2.dart
WARN	lib/copy_login.dart
OK	old_screens/home_screen.dart
WARN	old_screens/
SKIP	ios/Pods/Alamofire/AFError.swift
SKIP	lib/models/user_model.g.dart
SKIP	ios/App.xcodeproj/project.pbxproj
SKIP	ios/Sources/Strings.generated.swift'

  fails=$(printf '%s\n' "$cases" | cut -f2 | audit 1 2>/dev/null | CASES="$cases" LC_ALL=C awk -F '\t' '
    BEGIN { n = split(ENVIRON["CASES"], L, "\n"); for (i = 1; i <= n; i++) { split(L[i], f, "\t"); want[f[2]] = f[1] } }
    { seen[$2] = 1
      if (!($2 in want)) print "FAIL unexpected row: " $1 " " $2 " (" $3 ")"
      else if ($1 != want[$2]) print "FAIL " $2 ": status " $1 " (" $3 "), want " want[$2] }
    END { for (k in want) if (want[k] != "SKIP" && !(k in seen)) print "FAIL missing row: " k }')

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
  expect_exit 0 sh "$self" --path LoginActivity.kt
  expect_exit 0 sh "$self" --path LoginFinal.kt
  expect_exit 1 sh "$self" --path loginActivity.kt
  expect_exit 2 sh "$self" --path
  expect_exit 2 sh "$self" --bogus
  expect_exit 2 env GIT_DIR=/nonexistent-git-dir sh "$self"

  expect_exit 2 sh "$self" --path ''
  expect_exit 2 sh "$self" --path "$(printf 'bad\tname.txt')"
  expect_exit 2 sh "$self" --path "$(printf 'bad\nname.txt')"
  expect_exit 2 sh "$self" --path "$(printf 'bad\rname.txt')"

  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  git init -q -b production "$test_dir/work" || exit 2
  cd "$test_dir/work" || exit 2
  expect_exit 0 sh "$self"
  mkdir docs || exit 2
  : >docs/日本語.txt
  git add docs/日本語.txt || exit 2
  expect_exit 0 sh "$self"
  mkdir 'User Profile' || exit 2
  : >'User Profile/Login.swift'
  git add 'User Profile/Login.swift' || exit 2
  expect_exit 1 sh "$self"
  git rm -q -f 'User Profile/Login.swift' || exit 2

  for path in 'quoted"name.txt' 'back\slash.txt' "$(printf 'bad\tname.txt')" "$(printf 'bad\nname.txt')"; do
    : >"$path"
    git add -- "$path" || exit 2
    expect_exit 2 sh "$self"
    git rm -q -f -- "$path" || exit 2
  done
  : >"$test_dir/empty-index"
  expect_exit 2 env GIT_INDEX_FILE="$test_dir/empty-index" sh "$self"

  mkdir "$test_dir/bin" || exit 2
  cat >"$test_dir/bin/git" <<'SHIM'
#!/bin/sh
if [ "$1" = rev-parse ]; then exit 0; fi
echo 'fatal: injected Git read failure' >&2
exit 128
SHIM
  chmod +x "$test_dir/bin/git" || exit 2
  expect_exit 2 env PATH="$test_dir/bin:$PATH" sh "$self"

  # Exercise the documented move sequence when the destination directory does not exist.
  printf '// Example\n' >Example.swift
  git add Example.swift || exit 2
  expect_exit 0 mkdir -p Sources
  expect_exit 0 git mv -- Example.swift Sources/Example.swift
  [ -f Sources/Example.swift ] && [ ! -e Example.swift ] &&
    [ "$(cat Sources/Example.swift)" = '// Example' ] || fails="${fails}
FAIL move into newly created parent did not preserve the file"

  if [ -n "$fails" ]; then printf '%s\n' "$fails" >&2; exit 1; fi
  echo "audit-files self-test: all $(printf '%s\n' "$cases" | wc -l | tr -d ' ') cases + $exit_checks exit codes + move assertions passed"
}

case "${1:-}" in
  --path)
    [ $# -eq 2 ] || usage
    case "$2" in ''|*[[:cntrl:]]*) echo 'audit-files: path must be nonempty and contain no control characters' >&2; exit 2 ;; esac
    printf '%s\n' "$2" | audit 1 ;;
  --self-test) self_test ;;
  -*)          usage ;;
  *)
    [ $# -le 1 ] || usage
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "audit-files: not a git repository" >&2; exit 2; }
    paths=$(git -c core.quotePath=false ls-files -- "${1:-.}") || exit 2
    # ponytail: quoted Git paths are unsupported; a filename-boundary-preserving parser would replace this guard.
    printf '%s\n' "$paths" | LC_ALL=C awk '/^"/ { bad = 1 } END { exit bad }' || {
      echo 'audit-files: Git-quoted filenames cannot be safely audited; quotes, backslashes and control characters are unsupported' >&2
      exit 2
    }
    printf '%s\n' "$paths" | audit 0 ;;
esac
