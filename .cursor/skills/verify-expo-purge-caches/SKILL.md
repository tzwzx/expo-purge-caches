---
name: verify-expo-purge-caches
description: "Drive expo-purge-caches the way a user does — help, project-root refusal, dry-run, and isolated local deletes. Never touch this machine's Xcode/Gradle caches. Use when proving the purge CLI."
---

# Verify expo-purge-caches

expo-purge-caches is a short-lived bash CLI (`bin/purge-build-caches.sh`). There is no server. The published command is `expo-purge-caches`. It deletes caches. A wrong cwd or a real `TMPDIR` will delete user data.

This harness exists so an agent can prove behavior **without** wiping the machine. `bin/cli` sets `TMPDIR` to a scratch directory, `cd`s to a fake Expo project, puts only `/usr/bin:/bin` on `PATH` (so Watchman is never invoked), and **refuses `--deep` unless `--dry-run` is also present**.

Do not treat `bash tests/purge.test.sh` as the proof. Drive `bin/purge-build-caches.sh` through `bin/cli`.

Read `features/README.md` before driving.

## Launch

```bash
export VERIFY_RUN_ID=verify-$(date +%Y%m%dT%H%M%S)
export PATH_VERIFY=".cursor/skills/verify-expo-purge-caches/bin"
```

No install. Ready when `bin/doctor` exits 0. Each drive is a new process.

```bash
read -r PROJ FAKE_TMP < <("$PATH_VERIFY/project")
```

`bin/project` writes a fake Expo `package.json`, empty `.expo` / `.gradle` / `node_modules/.cache`, and a fake TMPDIR containing `metro-cache`, `haste-map-old`, `bunx-501-eas-cli@latest`, and `unrelated-keep-me`.

## Doctor

```bash
.cursor/skills/verify-expo-purge-caches/bin/doctor
```

Read-only. Checks the script is executable, package name `@tzwzx/expo-purge-caches`, `--help` names `--deep` / `--dry-run` / `--yes`, and `--version` matches `package.json`.

## Drive

```bash
"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name <stem> -- --dry-run -y
```

| User action | Args | Observable |
| --- | --- | --- |
| Help | `--help` or `-h` | usage; exit `0` |
| Version | `--version` | package version; exit `0` |
| Unknown flag | `--bogus` | `Unknown option:`; exit `1` |
| No package.json | (cwd without it) | `package.json not found`; exit `1` |
| Non-Expo package.json | (no expo/react-native key) | `does not look like an Expo`; exit `1` |
| Dry-run local | `--dry-run -y` | `[dry-run] would remove:` for `.expo` and fake metro/bunx; those paths still exist |
| Live local | `-y` | `.expo` and fake `metro-cache` / `bunx-501-*` gone; `unrelated-keep-me` remains |
| Tracked ios | git-tracked `ios/` then `-y` | warning `skipped ios/`; directory remains |
| Deep dry-run | `--deep --dry-run -y` | `would remove:` and `DerivedData` if that path exists (section headers still print if it does not); those real paths still exist |

`bin/cli` refuses (exit 2, no spawn):

- `--cwd` equal to this package repo
- `--tmp` outside `$TMPDIR/expo-purge-caches-verify-$VERIFY_RUN_ID`
- `--deep` without `--dry-run`

If `bin/cli` refuses, that is an isolation save, not a product failure.

## Evidence

Proof root: `test-results/verify-expo-purge-caches/` (survives cleanup). Each drive writes `argv.txt`, `cwd.txt`, `tmpdir.txt`, `stdout.txt`, `stderr.txt`, `exit.txt`.

Proof standards:

- Drive `bin/purge-build-caches.sh` through `bin/cli`.
- For dry-run, assert the path **still exists** after the command. A `[dry-run]` line alone is not enough.
- For a live local delete, assert the target is gone **and** `unrelated-keep-me` remains. Use the scratch TMPDIR only.
- For `--deep --dry-run`, assert `~/Library/Developer/Xcode/DerivedData` still exists if it existed before (do not create it). The would-remove line is not permission to run `--deep` for real.
- Never run `--deep` without `--dry-run`. Never export the real `TMPDIR` into a non-dry-run drive.

## Cleanup

```bash
.cursor/skills/verify-expo-purge-caches/bin/cleanup
```

Removes `$TMPDIR/expo-purge-caches-verify-$VERIFY_RUN_ID` only. Leaves evidence. Does not kill by process name. Does not delete Xcode/Gradle/Simulator caches.

## Helpers

```bash
.cursor/skills/verify-expo-purge-caches/bin/doctor
VERIFY_RUN_ID=<id> .cursor/skills/verify-expo-purge-caches/bin/project
VERIFY_RUN_ID=<id> .cursor/skills/verify-expo-purge-caches/bin/cli --cwd DIR --tmp DIR --name STEM -- <args>
VERIFY_RUN_ID=<id> .cursor/skills/verify-expo-purge-caches/bin/cleanup
```

`bin/_lib.sh` is sourced. Do not call it directly.

## Isolate

Different `VERIFY_RUN_ID` values may run in parallel. They must not share a project or fake TMPDIR.

Do not drive:

- the script from this package root
- `-y` / `--deep` against the real user `TMPDIR`
- `watchman` (the harness strips it from PATH)
- a second live delete in a project whose fixtures were already removed unless the feature says to recreate them

If you cannot get a scratch TMPDIR, refuse. Wiping this Mac's caches is not an acceptable fallback.
