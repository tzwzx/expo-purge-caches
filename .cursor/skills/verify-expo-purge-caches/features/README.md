# expo-purge-caches verification map

This directory is the maintained source for verifying the expo-purge-caches CLI. Read the index before driving.

## Baseline preconditions

- `bin/doctor` exits 0.
- Set `VERIFY_RUN_ID`. Create fixtures with `bin/project`.
- Drive only through `bin/cli` so `TMPDIR` is isolated and `--deep` without `--dry-run` is refused.
- PATH inside `bin/cli` is `/usr/bin:/bin` (Watchman is not called).

## Driving conventions

- Start from a fresh `bin/project` unless a bullet says to reuse one.
- Treat flags as literal. `-y` and `--yes` are both mapped; drive the spelling the bullet names.
- After a dry-run, re-stat the path. After a live delete, re-stat the path and the unrelated keeper.

## Proof and skip reporting

- Capture command, streams, exit code, and a second look at the files.
- Record feature id and flags in `--name`.
- A harness refusal (exit 2) is not a product failure.

## Feature entry contract

H1 + one paragraph, then `Sub-features`, `How to get to it (user POV)`, `Driving it with verify-cli`, `Gotchas`.

## Features

- [Help and version](./help.md) covers `--help`, `-h`, `--version`, and an unknown option.
- [Project gate](./gate.md) covers missing package.json and a non-Expo package.json.
- [Local purge](./local.md) covers dry-run, live isolated delete, and git-tracked `ios/` skip.
- [Deep dry-run](./deep.md) covers `--deep --dry-run` listing machine paths without deleting them.
