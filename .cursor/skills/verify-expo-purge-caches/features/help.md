# Help and version

Help prints usage. `--help` / `-h` succeed. `--version` prints the package version. An unknown option exits 1.

## Sub-features

- `help-long` prints help for `--help`.
- `help-short` prints help for `-h`.
- `version` prints the `package.json` version.
- `help-unknown` reports `Unknown option:` and exits 1.

## How to get to it (user POV)

- Run `expo-purge-caches --help`.
- Run `expo-purge-caches -h`.
- Run `expo-purge-caches --version`.
- Run `expo-purge-caches --bogus`.

## Driving it with verify-cli

Preconditions:

- `bin/doctor` has passed.
- `read -r PROJ FAKE_TMP < <("$PATH_VERIFY/project")`.

- **Long help.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name help-long -- --help`. `exit.txt` is `0`. `stdout.txt` contains `Usage:`, `--deep`, `--dry-run`, `-y, --yes`, `--version`, and `-h, --help`.
- **Short help.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name help-short -- -h`. Same strings. `exit.txt` is `0`.
- **Version.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name version -- --version`. `exit.txt` is `0`. `stdout.txt` is this repo's `package.json` `version` plus a newline.
- **Unknown.** Run `"$PATH_VERIFY/cli" --cwd "$PROJ" --tmp "$FAKE_TMP" --name help-unknown -- --bogus`. `exit.txt` is `1`. `stderr.txt` contains `Unknown option: --bogus`.
- **Proof.** Keep the transcripts. Cleanup must not delete them.

## Gotchas

- `--help` still requires a valid `--tmp` under scratch because `bin/cli` isolates every drive. That is harness policy, not a product requirement.
- Do not treat `-h` as coverage for `--help`.
