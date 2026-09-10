# Local purge

The default command (no `--deep`) removes project-local caches and Metro/bunx entries under `TMPDIR`. `--dry-run` only prints. Git-tracked `ios/` / `android/` are skipped.

## Sub-features

- `local-dry` lists `.expo` and fake Metro/bunx paths and leaves them on disk.
- `local-yes` deletes those fixtures under the scratch project and scratch TMPDIR, and leaves `unrelated-keep-me`.
- `local-ios-tracked` warns and keeps a git-tracked `ios/` directory.

## How to get to it (user POV)

- From an Expo app root: `expo-purge-caches --dry-run`.
- From an app npm script: `expo-purge-caches -y` (or `-y --deep`, which is out of scope here).
- Run it in an app whose `ios/` is committed (prebuild output checked in).

## Driving it with verify-cli

Preconditions:

- `bin/doctor` has passed.
- First two bullets share one `bin/project` (`$PROJ`, `$FAKE_TMP`).
- `local-ios-tracked` uses a **new** `bin/project`, then `git init` / commit a dummy `ios/Podfile` inside `$PROJ`.

- **Dry-run.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name local-dry -- --dry-run -y`. `exit.txt` is `0`. `stdout.txt` contains `[dry-run] would remove:` and the paths `$PROJ/.expo` and `$FAKE_TMP/metro-cache`. After the command, `$PROJ/.expo`, `$FAKE_TMP/metro-cache`, `$FAKE_TMP/bunx-501-eas-cli@latest`, and `$FAKE_TMP/unrelated-keep-me` still exist. `stdout.txt` contains `dry-run: nothing was deleted`.
- **Live local.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name local-yes -- -y`. `exit.txt` is `0`. `$PROJ/.expo` is gone. `$FAKE_TMP/metro-cache`, `$FAKE_TMP/haste-map-old`, and `$FAKE_TMP/bunx-501-eas-cli@latest` are gone. `$FAKE_TMP/unrelated-keep-me` still exists. `stdout.txt` contains `✔ Done.` and does not contain `dry-run: nothing was deleted`.
- **Tracked ios.** In a new project, `mkdir -p "$PROJ/ios" && printf '#\n' >"$PROJ/ios/Podfile" && git -C "$PROJ" init -q && git -C "$PROJ" add -A && git -C "$PROJ" -c commit.gpgsign=false commit -qm ios`. Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name local-ios-tracked -- -y`. `exit.txt` is `0`. `stdout.txt` contains `skipped ios/ (tracked by git`. `$PROJ/ios/Podfile` still exists.
- **Proof.** Re-stat the paths after each drive. Cleanup must not delete evidence.

## Gotchas

- `-y` without `--dry-run` **does** delete. Only do that against `bin/project` fixtures.
- `bunx-backup` (no uid digit after `bunx-`) is not removed. `bin/project` seeds `bunx-501-*` which is removed, and `unrelated-keep-me` which is not.
- Watchman is not on PATH in this harness. A `skipped (watchman not installed)` line is expected and is not a product bug.
- Do not export the real user `TMPDIR`. `metro-*` there is live Metro state.
