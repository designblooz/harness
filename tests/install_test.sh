#!/usr/bin/env bash

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
  printf 'FAIL [%s]: %s\n' "$current_case" "$*" >&2
  exit 1
}

assert_link() {
  local destination=$1 expected=$2 actual

  [ -L "$destination" ] || fail "$destination is not a symlink"
  actual="$(readlink "$destination")"
  [ "$actual" = "$expected" ] ||
    fail "$destination points to $actual, expected $expected"
  [ -e "$destination" ] || fail "$destination is a broken symlink"
}

assert_no_path() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1 unexpectedly exists"
}

run_install() {
  local case_root=$1 log
  shift

  mkdir -p "$case_root"
  log="$case_root/install.log"
  if ! HOME="$case_root/home" \
    CODEX_HOME="$case_root/codex" \
    CLAUDE_CONFIG_DIR="$case_root/claude" \
    bash "$repo/install.sh" "$@" >"$log" 2>&1; then
    sed 's/^/  /' "$log" >&2
    fail "install.sh failed for $(basename "$case_root")"
  fi
}

assert_managed_links() {
  local case_root=$1 agent

  assert_link "$case_root/codex/AGENTS.md" "$repo/.codex/AGENTS.md"
  assert_link "$case_root/claude/CLAUDE.md" "$repo/.claude/CLAUDE.md"

  for agent in researcher planner implementer reviewer; do
    assert_link \
      "$case_root/codex/agents/$agent.toml" \
      "$repo/.codex/agents/$agent.toml"
    assert_link \
      "$case_root/claude/agents/$agent.md" \
      "$repo/.claude/agents/$agent.md"
  done
}

assert_single_backup() {
  local destination=$1 expected_file=$2 candidate backup='' count=0
  local prefix suffix

  prefix="${destination}.backup-"
  for candidate in "${prefix}"*; do
    [ -e "$candidate" ] || [ -L "$candidate" ] || continue
    backup=$candidate
    count=$((count + 1))
  done

  [ "$count" -eq 1 ] ||
    fail "$destination has $count backups, expected exactly one"
  [ -f "$backup" ] && [ ! -L "$backup" ] ||
    fail "$backup is not a regular, non-symlink file"

  suffix=${backup#"$prefix"}
  [[ "$suffix" =~ ^[0-9]{8}([T_-]?[0-9]{6})(Z)?([._-][0-9]+)?$ ]] ||
    fail "$backup does not have a timestamp suffix"

  cmp -s "$backup" "$expected_file" ||
    fail "$backup does not preserve the original content"
}

assert_no_backups() {
  local root=$1 backups

  backups="$(find "$root" -name '*.backup-*' -print)"
  [ -z "$backups" ] || fail "unexpected backup paths: $backups"
}

test_dry_run_makes_no_changes() {
  local case_root="$test_root/dry-run"

  run_install "$case_root" --dry-run

  assert_no_path "$case_root/home/.codex"
  assert_no_path "$case_root/home/.claude"
  assert_no_path "$case_root/codex"
  assert_no_path "$case_root/claude"
}

test_clean_install_links_managed_files() {
  local case_root="$test_root/clean-install"

  run_install "$case_root"
  assert_managed_links "$case_root"
}

test_second_install_is_idempotent() {
  local case_root="$test_root/idempotent"

  run_install "$case_root"
  run_install "$case_root"
  assert_managed_links "$case_root"

  assert_no_backups "$case_root"
}

test_instruction_conflicts_are_backed_up() {
  local case_root="$test_root/conflicts"
  local codex_expected="$case_root/codex-original"
  local claude_expected="$case_root/claude-original"

  mkdir -p "$case_root/codex" "$case_root/claude"
  printf 'existing Codex instructions\nsecond line\n' >"$codex_expected"
  printf 'existing Claude instructions\nsecond line\n' >"$claude_expected"
  cp "$codex_expected" "$case_root/codex/AGENTS.md"
  cp "$claude_expected" "$case_root/claude/CLAUDE.md"

  run_install "$case_root"

  assert_link "$case_root/codex/AGENTS.md" "$repo/.codex/AGENTS.md"
  assert_link "$case_root/claude/CLAUDE.md" "$repo/.claude/CLAUDE.md"
  assert_single_backup "$case_root/codex/AGENTS.md" "$codex_expected"
  assert_single_backup "$case_root/claude/CLAUDE.md" "$claude_expected"
}

test_custom_configuration_directories_are_honored() {
  local case_root="$test_root/custom-homes"

  run_install "$case_root"

  assert_managed_links "$case_root"
  assert_no_path "$case_root/home/.codex"
  assert_no_path "$case_root/home/.claude"
}

run_test() {
  local description=$1 test_function=$2

  current_case=$description
  "$test_function"
  printf 'PASS: %s\n' "$description"
}

current_case='test setup'
test_root="$(mktemp -d "${TMPDIR:-/tmp}/pkfire-install-test.XXXXXX")"
cleanup() {
  [ -n "${test_root:-}" ] && rm -rf "$test_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

run_test 'dry-run makes no changes' test_dry_run_makes_no_changes
run_test 'clean install links instructions and agents' test_clean_install_links_managed_files
run_test 'second install is idempotent' test_second_install_is_idempotent
run_test 'instruction conflicts are backed up' test_instruction_conflicts_are_backed_up
run_test 'custom configuration directories are honored' test_custom_configuration_directories_are_honored

printf 'PASS: installer regression harness\n'
