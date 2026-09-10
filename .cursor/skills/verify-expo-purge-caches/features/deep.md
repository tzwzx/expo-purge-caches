# Deep dry-run

`--deep` would also purge machine-wide Xcode, Simulator, CocoaPods, SwiftPM, and Gradle caches. This map only allows `--deep` together with `--dry-run`. A live `--deep` is out of scope for verification on a developer machine.

## Sub-features

- `deep-dry` prints would-remove lines for the machine-wide paths and does not delete them.
- `deep-refused` is the harness refusal when `--deep` is passed without `--dry-run` (not a product test).

## How to get to it (user POV)

- Run `expo-purge-caches --deep --dry-run` to preview.
- App scripts use `expo-purge-caches -y --deep`. Do **not** drive that spelling here.

## Driving it with verify-cli

Preconditions:

- `bin/doctor` has passed.
- `read -r PROJ FAKE_TMP < <("$PATH_VERIFY/project")`.
- Note whether `~/Library/Developer/Xcode/DerivedData` exists **before** the drive (`ls` only).

- **Deep dry-run.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name deep-dry -- --deep --dry-run -y`. `exit.txt` is `0`. `stdout.txt` contains `would remove:` and `DerivedData` (or the Gradle/CocoaPods section headers if those paths are absent — section headers still print). If DerivedData existed before, it still exists after. `stdout.txt` contains `dry-run: nothing was deleted`.
- **Harness refuse.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name deep-refused -- --deep -y`. The helper exits 2 and writes no transcript named `deep-refused` unless you created the evidence dir by hand. Treat helper exit 2 as the expected isolation save. Do not then run the raw script to "see what happens".
- **Proof.** Keep `deep-dry` transcripts. Confirm the real DerivedData path was not removed.

## Gotchas

- `--deep` without `--dry-run` is how apps call this tool. Proving that path would slow every other project's next native build. The map forbids it.
- Section headers print even when a path is missing (`remove` skips absent paths). Do not require DerivedData to exist on the machine.
- `pod cache clean --all` is only printed in dry-run if `pod` is on PATH. This harness uses `PATH=/usr/bin:/bin`, so expect `skipped (pod not installed)` rather than a pod dry-run line.
