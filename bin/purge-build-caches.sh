#!/usr/bin/env bash
# CLI that safely purges Expo / React Native build caches
#
# Default: project-local caches + Metro + Watchman only (safe scope that never affects other projects)
# --deep : also purges machine-wide shared caches (Xcode / Simulator / CocoaPods / Gradle / SwiftPM)
#
# Note: must stay compatible with the bash 3.2 that ships with macOS
# (avoid bash 4+ features such as empty-array expansion under `set -u`)

set -euo pipefail
shopt -s nullglob

VERSION="1.0.0"

DEEP=false
DRY_RUN=false
ASSUME_YES=false

# ---- Colors ------------------------------------------------------------------

# Colorize only when stdout is a terminal; respect NO_COLOR (https://no-color.org)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

section() {
  echo "${BOLD}${CYAN}▸ $1${RESET}"
}

warn() {
  echo "  ${YELLOW}⚠ $1${RESET}"
}

die() {
  echo "${RED}Error: $1${RESET}" >&2
  [ $# -lt 2 ] || echo "${RED}$2${RESET}" >&2
  exit 1
}

usage() {
  cat <<EOF
${BOLD}expo-purge-caches${RESET} - purge Expo / React Native build caches for a clean rebuild

${BOLD}Usage:${RESET} expo-purge-caches [options]

Run from the root of your Expo / React Native project.

By default only project-local caches, Metro caches, and Watchman watches are
purged. Machine-wide caches are only touched with --deep.

${BOLD}Options:${RESET}
  --deep       Also purge machine-wide caches shared across all projects
               (Xcode DerivedData, iOS Simulator caches, CocoaPods, Gradle, SwiftPM)
  --dry-run    Show what would be deleted without deleting anything
  -y, --yes    Skip confirmation prompts
  --version    Show version
  -h, --help   Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --deep) DEEP=true ;;
    --dry-run) DRY_RUN=true ;;
    -y|--yes) ASSUME_YES=true ;;
    --version) echo "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "${RED}Unknown option: $arg${RESET}" >&2; usage >&2; exit 1 ;;
  esac
done

# Interactive confirmation. Always allowed with --yes; in non-interactive
# environments it fails closed (denies) to stay on the safe side
confirm() {
  if $ASSUME_YES; then
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "  ${DIM}(non-interactive shell: pass --yes to allow)${RESET}"
    return 1
  fi
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Remove paths (silently skips ones that don't exist; print-only in dry-run mode)
remove() {
  local path
  for path in "$@"; do
    [ -e "$path" ] || continue
    if $DRY_RUN; then
      echo "  ${CYAN}[dry-run]${RESET} would remove: ${DIM}$path${RESET}"
    else
      echo "  ${RED}✗${RESET} removing: ${DIM}$path${RESET}"
      rm -rf "$path"
    fi
  done
}

# Run an external command (silently skips if not installed; print-only in dry-run mode)
run_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "  ${DIM}skipped ($1 not installed)${RESET}"
    return 0
  fi
  if $DRY_RUN; then
    echo "  ${CYAN}[dry-run]${RESET} would run: ${DIM}$*${RESET}"
  else
    echo "  ${GREEN}▹${RESET} running: ${DIM}$*${RESET}"
    "$@" >/dev/null 2>&1 || true
  fi
}

# Safely delete a native directory (ios / android).
# Skips it when tracked by git, since hand-written native code could be lost;
# when not in a git repo (so it can't be verified automatically), asks for confirmation
purge_native_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ -n "$(git ls-files "$dir" | head -n 1)" ]; then
      warn "skipped $dir/ (tracked by git - it may contain hand-written native code)."
      echo "    ${DIM}If it is safe to regenerate with 'npx expo prebuild --clean', delete it manually.${RESET}"
      return 0
    fi
    remove "$dir"
  else
    if confirm "  Delete $dir/? (not a git repo, so it cannot be verified as regenerable)"; then
      remove "$dir"
    else
      warn "skipped $dir/"
    fi
  fi
}

# ---- Pre-flight checks -----------------------------------------------------

# Verify the current directory is the root of an Expo / React Native project,
# to prevent running in the wrong place (e.g. deleting an unrelated project's ios/)
if [ ! -f package.json ]; then
  die "package.json not found in the current directory." \
      "Run this command from the root of your Expo / React Native project."
fi
if ! grep -Eq '"(expo|react-native)"[[:space:]]*:' package.json; then
  die "this does not look like an Expo / React Native project" \
      "(no \"expo\" or \"react-native\" entry found in package.json)."
fi

if $DEEP && ! $DRY_RUN; then
  echo "${YELLOW}--deep will also purge machine-wide caches shared across ALL projects"
  echo "(Xcode DerivedData, iOS Simulator caches, CocoaPods, Gradle, SwiftPM)."
  echo "Nothing breaks, but other projects' next builds will be slower.${RESET}"
  if ! confirm "Continue?"; then
    echo "Aborted."
    exit 1
  fi
fi

echo "${BOLD}Purging build caches...${RESET}"

# ---- 1. Project-local build artifacts and caches ---------------------------

section "Removing local build artifacts..."
purge_native_dir ios
purge_native_dir android
remove .expo .gradle node_modules/.cache

# ---- 2. Metro bundler caches ------------------------------------------------

# Metro writes its caches to Node.js os.tmpdir() ($TMPDIR on macOS), NOT /tmp.
# metro-* covers metro-cache and the newer metro-file-map-* file map caches;
# haste-map-* is the file map cache of older Metro versions
section "Removing Metro cache..."
TMP_DIR="${TMPDIR:-/tmp}"
TMP_DIR="${TMP_DIR%/}"
remove "$TMP_DIR"/metro-* "$TMP_DIR"/haste-map-*

# ---- 3. Watchman -------------------------------------------------------------

section "Resetting Watchman watches..."
run_cmd watchman watch-del-all

# ---- 4. Machine-wide shared caches (--deep only) ----------------------------

if $DEEP; then
  section "Removing Xcode caches..."
  remove ~/Library/Developer/Xcode/DerivedData
  remove ~/Library/Caches/com.apple.dt.Xcode

  section "Removing iOS Simulator caches..."
  remove ~/Library/Developer/CoreSimulator/Caches

  section "Removing CocoaPods cache..."
  run_cmd pod cache clean --all
  remove ~/Library/Caches/CocoaPods

  section "Removing Swift Package Manager cache..."
  remove ~/Library/Caches/org.swift.swiftpm

  section "Removing Gradle cache..."
  remove ~/.gradle/caches
fi

if $DRY_RUN; then
  echo "${GREEN}${BOLD}✔ Done${RESET}${GREEN} (dry-run: nothing was deleted).${RESET}"
else
  echo "${GREEN}${BOLD}✔ Done.${RESET}"
fi
