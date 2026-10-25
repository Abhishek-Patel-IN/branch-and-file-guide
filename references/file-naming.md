# File and directory naming

Loaded by `SKILL.md` for creating, auditing or renaming files and folders. All safety rules from `SKILL.md` apply.

## Rules

General (all platforms): names describe purpose; follow the language convention; no spaces; no special characters
(`@ # $ % & !`); no developer names; no version indicators (`new`, `old`, `latest`, `final`, `copy`, `backup`, `v2`)
- Git is the version history; consistent with the rest of the project.

| Platform | Convention | Examples | Common suffixes |
|---|---|---|---|
| Kotlin / Java | PascalCase, named after the main class/interface/object | `LoginActivity.kt`, `UserRepository.kt`, `PaymentService.java` | Activity, Fragment, ViewModel, Repository, Service, Manager, Adapter, Mapper, UseCase |
| Android resources | lowercase snake_case | `activity_login.xml`, `fragment_home.xml`, `dialog_device_pairing.xml`, `ic_bluetooth.xml`, `bg_primary_button.xml`, `img_device_placeholder.webp` | prefixes `activity_`, `fragment_`, `dialog_`, `ic_`, `bg_`, `img_` |
| Android tests | PascalCase + `Test` | `LoginViewModelTest.kt`, `PaymentServiceTest.java` | |
| Swift (UIKit / SwiftUI) | PascalCase, named after the main type | `LoginViewController.swift`, `LoginView.swift`, `BluetoothManager.swift` | ViewController, View, ViewModel, Service, Manager, Coordinator, Repository |
| Swift extensions | `Type+Purpose.swift` | `String+Validation.swift` | |
| iOS tests | PascalCase + `Tests` | `LoginViewModelTests.swift` | |
| Dart / Flutter | lowercase snake_case | `login_screen.dart`, `profile_page.dart`, `device_provider.dart`, `user_model.dart` | screen, page, view_model, provider, repository, service, model |
| Flutter tests | source name + `_test` | `login_view_model_test.dart` | |

Directories:
- no spaces (`User Profile/` -> `user_profile/` or `UserProfile/`, matching the platform's existing convention);
- no special characters (`payment#module/`);
- no generic names: `temp/`, `misc/`, `new/`, `old/`, `final/`, `developer-work/`; prefer `authentication/`,
  `network/`, `database/`, `services/`, `repositories/`, `features/`, `models/`, `utils/`;
- keep nesting shallow (`features/authentication/login/`, not `features/authentication/user/login/screens/components/forms/inputs/`).

Consistency and portability:
- do not mix conventions within one language (`LoginScreen.dart` next to `user_profile.dart`);
- never rely on case-only differences (`UserService.kt` and `userService.kt`): macOS and Windows file systems are
  case-insensitive;
- avoid very long names and paths.

Pre-create checklist: describes purpose? platform convention? no spaces / special characters / developer name /
version words? not too long? consistent with existing names? Then `sh <skill>/scripts/audit-files.sh --path <path>`.

## What the script checks vs. what you check

`scripts/audit-files.sh` (read-only) reports:
- `FIX`: spaces, special characters (iOS `@2x/@3x` allowed), Kotlin/Java/Swift not PascalCase
  (`main.swift`, `package-info.java`, `module-info.java` allowed), Dart not snake_case, Android `res/` files not
  snake_case (`.9.png` allowed), generic directory names, case-only duplicates.
- `WARN`: version words anywhere in a name. Many are legitimate (`WhatsNewView.swift`, `OldPasswordField.swift`,
  `NewGroupCreationView.swift`, `copyLink.imageset`) - decide per file, never rename a WARN automatically.
- Skipped: `Pods/`, `build/`, `.dart_tool/`, `node_modules/`, `Carthage/`, `.gradle/`, `.idea/`, `DerivedData/`,
  inside `*.xcodeproj/` and `*.xcworkspace/`, generated `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`,
  `*.generated.swift`, and image files inside asset-catalog sets (`*.imageset/` etc.; the set names are still checked).
- Directories come from tracked file paths; empty directories are not tracked by Git, so they are not audited.
- Empty proposed paths and control characters are rejected with exit `2`. Repository scans also stop with `2`
  on Git-quoted filenames (quotes, backslashes or control characters), without printing a successful summary.
  Ordinary Unicode paths are preserved, but case-only collision detection folds ASCII letters only.

You add (judgment): developer names (`DeveloperLogin.kt`, `developer_test.dart`), vague names, file name not matching
the main type it contains, mixed directory conventions, deep nesting, overly long names.

## D. Audit and rename files and directories

1. **Detect**: `sh <skill>/scripts/audit-files.sh [dir]` and add your judgment findings. Large repos: work one
   module or feature folder at a time.
2. **Propose** a table; for each row list what else must change:

   | old path | new path | status | references to update |
   |---|---|---|---|
   | `Example App/Helper/Notification Center.swift` | `Example App/Helper/NotificationCenterHelper.swift` | FIX | `project.pbxproj` file ref |
   | `lib/LoginScreen.dart` | `lib/login_screen.dart` | FIX | 4 `import` lines |

   Reference rules:
   - **Swift / Xcode**: renaming a file does not rename its type; rename the type only if the user agrees.
     Update `project.pbxproj` file references unless the folder is a synchronized group (Xcode 16
     `PBXFileSystemSynchronizedRootGroup`) or the project is generated (XcodeGen `project.yml`, Tuist) - then update
     that source instead. Folder renames also touch build settings that hold paths (`INFOPLIST_FILE`,
     `CODE_SIGN_ENTITLEMENTS`, `DEVELOPMENT_ASSET_PATHS`, bridging header). If an old name appears ambiguously in
     `project.pbxproj` (same name in several groups), stop and ask, or suggest renaming in Xcode.
   - **Kotlin / Java**: class name should match the file; update imports and usages; Java requires the public class
     to match the file name. Directory renames under `src/main/java|kotlin` change the package - only with explicit
     approval.
   - **Dart**: update every `import`/`export`/`part` that references the file (package and relative imports).
   - **Android resources**: update `R.<type>.<name>` usages and `@<type>/<name>` XML references.
   - **Asset sets** (`*.imageset`, `*.colorset`): the set name is what code uses (`UIImage(named:)`, `Image("...")`,
     `R.swift`/SwiftGen output).
3. **Preconditions**: `git status --porcelain` is empty (so rollback is clean); current branch is a work branch,
   never a primary branch - otherwise offer workflow A (for example `feature/file-naming-cleanup`).
4. **Confirm** the table, then execute in small batches:
   - Assign the approved paths to `old` and `new`, create the destination parent, then move:
     ```bash
     mkdir -p -- "$(dirname -- "$new")" && git mv -- "$old" "$new"
     ```
     `git mv` does not create parent directories. Quote paths, update references, then verify the move and build.
   - **case-only renames** (macOS/Windows): go through a temporary name in the same directory, and first make sure
     the temporary name does not exist:
     ```bash
     test ! -e "Dir/Foo.swift.rename-tmp" && git mv "Dir/Foo.swift" "Dir/Foo.swift.rename-tmp" && git mv "Dir/Foo.swift.rename-tmp" "Dir/foo.swift"
     ```
     The same two steps work for directories;
   - update references from the table.
5. **Verify**: re-run `audit-files.sh`; `git grep -n -F '<old basename>'` has no leftover references; build or
   analyze when the toolchain is available (`flutter analyze`, `./gradlew compileDebugKotlin`, `xcodebuild build`
   with the project's scheme); if not available, report the build as `NOT VERIFIED`.
6. **Commit** only after a separate yes, e.g. `Rename files to naming standards`.

Rollback: before commit, `git reset --hard HEAD` restores everything (safe only because the tree was clean at step
3; ask first). After commit, `git revert <commit>`.
