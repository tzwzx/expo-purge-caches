#!/usr/bin/env bash
# expo-purge-caches の TMPDIR 削除対象を検証する
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/bin/purge-build-caches.sh"
# Watchman を動かさない（実マシンの watch を消さない）
SAFE_PATH="/usr/bin:/bin"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "ok - $*"
}

run_purge() {
  local fake_tmp="$1"
  PATH="$SAFE_PATH" TMPDIR="$fake_tmp" bash "$SCRIPT" -y >/dev/null
}

setup_project() {
  local workdir="$1"
  printf '{"dependencies":{"expo":"1.0.0"}}\n' >"$workdir/package.json"
}

# bun.lock が残った空の bunx 展開は、次回 bunx が再インストールせず壊れたままになる
test_removes_zombie_bunx_cache() {
  local workdir fake_tmp
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/expo-purge-test-proj.XXXXXX")"
  fake_tmp="$(mktemp -d "${TMPDIR:-/tmp}/expo-purge-test-tmp.XXXXXX")"
  trap 'rm -rf "$workdir" "$fake_tmp"' RETURN

  setup_project "$workdir"
  mkdir -p "$fake_tmp/bunx-501-eas-cli@latest/node_modules/debug/src"
  printf '{"dependencies":{"eas-cli":"^22.0.0"}}\n' >"$fake_tmp/bunx-501-eas-cli@latest/package.json"
  : >"$fake_tmp/bunx-501-eas-cli@latest/bun.lock"

  (cd "$workdir" && run_purge "$fake_tmp")

  if [ -e "$fake_tmp/bunx-501-eas-cli@latest" ]; then
    fail "zombie bunx cache should be removed ($fake_tmp/bunx-501-eas-cli@latest still exists)"
  fi
  pass "removes zombie bunx cache from TMPDIR"
}

test_removes_metro_cache() {
  local workdir fake_tmp
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/expo-purge-test-proj.XXXXXX")"
  fake_tmp="$(mktemp -d "${TMPDIR:-/tmp}/expo-purge-test-tmp.XXXXXX")"
  trap 'rm -rf "$workdir" "$fake_tmp"' RETURN

  setup_project "$workdir"
  mkdir -p "$fake_tmp/metro-cache" "$fake_tmp/haste-map-old"

  (cd "$workdir" && run_purge "$fake_tmp")

  if [ -e "$fake_tmp/metro-cache" ] || [ -e "$fake_tmp/haste-map-old" ]; then
    fail "metro/haste-map caches should be removed"
  fi
  pass "removes metro and haste-map caches from TMPDIR"
}

test_leaves_unrelated_tmpdir_entries() {
  local workdir fake_tmp
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/expo-purge-test-proj.XXXXXX")"
  fake_tmp="$(mktemp -d "${TMPDIR:-/tmp}/expo-purge-test-tmp.XXXXXX")"
  trap 'rm -rf "$workdir" "$fake_tmp"' RETURN

  setup_project "$workdir"
  mkdir -p "$fake_tmp/unrelated-keep-me" "$fake_tmp/bunx-backup"

  (cd "$workdir" && run_purge "$fake_tmp")

  [ -d "$fake_tmp/unrelated-keep-me" ] || fail "unrelated TMPDIR entry should remain"
  [ -d "$fake_tmp/bunx-backup" ] || fail "non-uid bunx-* name should remain"
  pass "leaves unrelated TMPDIR entries"
}

test_removes_zombie_bunx_cache
test_removes_metro_cache
test_leaves_unrelated_tmpdir_entries

echo "All tests passed."
