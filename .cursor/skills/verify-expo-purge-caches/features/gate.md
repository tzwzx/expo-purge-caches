# Project gate

The CLI refuses to run unless the current directory looks like an Expo or React Native project. That keeps a stray invocation from deleting some other folder's `ios/`.

## Sub-features

- `gate-no-package` exits 1 when `package.json` is missing.
- `gate-not-expo` exits 1 when `package.json` has no `expo` or `react-native` key.

## How to get to it (user POV)

- Run `expo-purge-caches` from `/tmp` or any non-app directory.
- Run it from a Node project that is not Expo / React Native.

## Driving it with verify-cli

Preconditions:

- `bin/doctor` has passed.
- `$ROOT` is this run's scratch root (`$(dirname "$PROJ")` after `bin/project`, or the path `bin/project` created under).
- `$EMPTY` is a new directory under that scratch with **no** `package.json`.
- `$OTHER` is a new directory under that scratch whose `package.json` is `{"name":"demo"}`.
- `$FAKE_TMP` is the isolated tmp from `bin/project`.

- **No package.json.** Run `"$PATH_VERIFY/cli" --cwd "$EMPTY" --tmp "$FAKE_TMP" --name gate-no-package -- -y --dry-run`. `exit.txt` is `1`. `stderr.txt` contains `package.json not found`. `$EMPTY` still has no extra files.
- **Not Expo.** Run `"$PATH_VERIFY/cli" --cwd "$OTHER" --tmp "$FAKE_TMP" --name gate-not-expo -- -y --dry-run`. `exit.txt` is `1`. `stderr.txt` contains `does not look like an Expo / React Native project`.
- **Proof.** Keep both transcripts. The fake Expo project from `bin/project` is unchanged.

## Gotchas

- The product checks for the JSON keys `"expo"` or `"react-native"` with a colon. A README mention is not enough; a `devDependencies.expo` key **does** match.
- `bin/cli` refuses this package repo as `--cwd`. Use `$EMPTY` / `$OTHER` under scratch, not `/Users/tazawa/Code`.
- Always pass `--dry-run` on these bullets so a harness bug cannot delete anything if the gate regresses.
