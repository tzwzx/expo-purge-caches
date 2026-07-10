# expo-purge-caches

**A CLI tool that wipes Expo / React Native build caches so you can rebuild from a clean slate.** 🧹

"Dependencies were updated but the change isn't picked up", "`Unable to resolve module` won't go away even after clearing caches", "Xcode fails to build because of stale artifacts" — when you hit one of these cache-related dead ends, this tool blows away the relevant caches in one shot so you can rebuild everything from scratch.

Under the hood it's a single shell script, [bin/purge-build-caches.sh](bin/purge-build-caches.sh), exposed as the `expo-purge-caches` command.

---

## ✨ What does it do?

By default, `expo-purge-caches` only touches things that are **safe to delete and scoped to your project** (plus the per-user Metro / Watchman state that belongs to it):

1. Local build artifacts in your project (`ios` / `android` / `.expo` / `.gradle` / `node_modules/.cache`) — with [safety checks](#-safety-checks) for `ios` / `android`
2. Metro bundler caches (`$TMPDIR/metro-*`, `$TMPDIR/haste-map-*`, `$TMPDIR/metro-file-map-*`)
3. Watchman watches (`watchman watch-del-all`)

With the **`--deep`** flag it additionally purges **machine-wide caches shared across all your projects** (after a confirmation prompt):

4. Xcode caches (`~/Library/Developer/Xcode/DerivedData`, `~/Library/Caches/com.apple.dt.Xcode`)
5. iOS Simulator caches (`~/Library/Developer/CoreSimulator/Caches`)
6. CocoaPods cache (`pod cache clean --all`, `~/Library/Caches/CocoaPods`)
7. Swift Package Manager cache (`~/Library/Caches/org.swift.swiftpm`)
8. Gradle cache (`~/.gradle/caches`)

Deleting the machine-wide caches breaks nothing, but the next build of **other** projects will be slower while the caches regenerate — that's why they are opt-in.

---

## 📦 Requirements

| Item | Details |
| --- | --- |
| OS | **macOS or Linux** (the Xcode / Simulator / CocoaPods steps only apply on macOS and are skipped elsewhere) |
| Required | Node.js (used to run via `npx`), Bash |
| Optional | Watchman, CocoaPods (related steps are skipped when not installed) |

> 📝 Windows is not supported (the package declares `"os": ["darwin", "linux"]`).

---

## 🚀 Usage

### Run directly with npx (no install required)

```bash
# safe, project-scoped purge
npx expo-purge-caches

# also purge machine-wide caches (Xcode, Simulator, CocoaPods, Gradle, SwiftPM)
npx expo-purge-caches --deep

# preview what would be deleted, without deleting anything
npx expo-purge-caches --deep --dry-run
```

> ⚠️ Run it from the **root of your Expo / React Native project**. The command refuses to run if the current directory doesn't contain a `package.json` with an `expo` or `react-native` dependency, so accidentally running it elsewhere is harmless.

### Options

| Option | Description |
| --- | --- |
| `--deep` | Also purge machine-wide caches shared across all projects (asks for confirmation) |
| `--dry-run` | Print everything that would be deleted, delete nothing |
| `-y`, `--yes` | Skip confirmation prompts (for CI / npm scripts) |
| `--version` | Print the version |
| `-h`, `--help` | Show help |

### Install globally

```bash
npm install -g expo-purge-caches

# afterwards you can run it from anywhere by name
expo-purge-caches
```

### Wire it into a project npm script

Registering it in `package.json` makes it easy to share across a team.

```jsonc
{
  "scripts": {
    "clean": "expo-purge-caches",
    "clean:deep": "expo-purge-caches --deep --yes"
  }
}
```

```bash
npm run clean
```

---

## 🛟 Safety checks

The script is deliberately paranoid before deleting anything:

- **Project validation** — it refuses to run unless the current directory contains a `package.json` that declares an `expo` or `react-native` dependency. Running it in the wrong directory does nothing.
- **`ios` / `android` protection** — these directories are only deleted when they are **not tracked by git** (i.e. they are generated artifacts, as in [Continuous Native Generation](https://docs.expo.dev/workflow/continuous-native-generation/)). If they are tracked — which usually means hand-written native code — they are **skipped with a warning** instead of deleted. If the project isn't a git repo at all, you are asked to confirm.
- **Machine-wide caches are opt-in** — nothing outside your project (except Metro temp files and Watchman watches) is touched unless you pass `--deep`, and `--deep` asks for confirmation first.
- **`--dry-run`** — preview every path that would be removed.
- **Missing tools never break it** — Watchman / CocoaPods steps are skipped when the tools aren't installed.

---

## 🧹 What gets deleted (in detail)

### 1. Local build artifacts (inside the project)

| Target | What it is | Why it's removed |
| --- | --- | --- |
| `ios` / `android` | Native project directories | Reset stale native build config / output. Only deleted when untracked by git (regenerable with `npx expo prebuild`) |
| `.expo` | Expo's local cache / temp config | Remove stale dev-server-related caches |
| `.gradle` | Project-level Gradle cache | Remove stale Gradle configuration state |
| `node_modules/.cache` | Cache directory for various tools | Remove caches left by Babel / Metro, etc. (the full `node_modules` is **not** deleted) |

### 2. Metro bundler caches

```bash
rm -rf "$TMPDIR"/metro-* "$TMPDIR"/haste-map-* "$TMPDIR"/metro-file-map-*
```

Metro writes its caches to the OS temp directory reported by Node.js (`os.tmpdir()`), which on macOS is `$TMPDIR` (somewhere under `/var/folders/...`), **not** `/tmp`. This matches the [official Expo cache-clearing guide](https://docs.expo.dev/troubleshooting/clear-cache-macos-linux/).

| Target | What it is |
| --- | --- |
| `$TMPDIR/metro-*` | Metro transformer cache (`metro-cache`) and friends |
| `$TMPDIR/haste-map-*` | File map caches (older Metro versions) |
| `$TMPDIR/metro-file-map-*` | File map caches (newer Metro versions) |

### 3. Watchman

```bash
watchman watch-del-all
```

Cancels all watches and resets Watchman's file-watching state. Skipped when Watchman isn't installed.

### 4. Machine-wide caches (`--deep` only)

| Target | What it is |
| --- | --- |
| `~/Library/Developer/Xcode/DerivedData` | Xcode's intermediate build output / indexes |
| `~/Library/Caches/com.apple.dt.Xcode` | Cache for the Xcode app itself |
| `~/Library/Developer/CoreSimulator/Caches` | iOS Simulator caches |
| `pod cache clean --all` + `~/Library/Caches/CocoaPods` | Downloaded Pod caches |
| `~/Library/Caches/org.swift.swiftpm` | Swift Package Manager downloads |
| `~/.gradle/caches` | Gradle's global dependency / build cache |

---

## 🖥 Example output

```text
$ npx expo-purge-caches
Purging build caches...
Removing local build artifacts...
  removing: ios
  removing: android
  removing: .expo
  removing: node_modules/.cache
Removing Metro cache...
  removing: /var/folders/xx/.../T/metro-cache
Resetting Watchman watches...
  running: watchman watch-del-all
Done.
```

---

## ⚠️ Caveats (read before running)

- **The `ios` / `android` directories are deleted when untracked by git.**
  This assumes they can be regenerated with `npx expo prebuild` (Continuous Native Generation). Directories tracked by git are skipped automatically, but if you keep hand-written native code untracked for some reason, commit or back it up first.

- **`--deep` affects other projects.**
  Xcode's DerivedData, the Simulator caches, and the CocoaPods / Gradle / SwiftPM caches are global. Other projects' next builds will be slower or re-download dependencies (nothing breaks — it just takes time to regenerate).

- **It operates on the current directory.**
  Always run it from the root of the target project. The built-in project validation refuses to run anywhere that doesn't look like an Expo / React Native project.

---

## 🔄 Clean rebuild steps afterwards (reference)

After clearing caches, recreate your dependencies and native projects before building. Below is a typical example (the script itself does **not** do these).

```bash
# 1. Reinstall dependencies
npm install            # or yarn / bun install

# 2. Regenerate native projects (for Continuous Native Generation)
npx expo prebuild --clean

# 3. Start the dev server with cache clearing
npx expo start --clear

# 4. Build natively and run
npx expo run:ios
npx expo run:android
```

---

## 💡 When to use it

- You updated dependencies or native modules, but the changes aren't reflected
- A resolution error like `Unable to resolve module ...` won't go away with ordinary cache clearing
- Xcode fails to build because of stale intermediate artifacts
- As a way to isolate a problem, you simply want to do one clean rebuild from a pristine state

---

## 📄 License

[MIT](LICENSE)
