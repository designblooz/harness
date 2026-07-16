#!/usr/bin/env bash

# Install repository-managed instructions, custom agents, and skills globally.
set -euo pipefail

usage() {
  printf 'Usage: %s [--dry-run]\n' "$(basename "$0")" >&2
}

case $# in
  0)
    dry_run=false
    ;;
  1)
    if [ "$1" != '--dry-run' ]; then
      usage
      exit 2
    fi
    dry_run=true
    ;;
  *)
    usage
    exit 2
    ;;
esac

: "${HOME:?HOME is required}"

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
codex_home="${CODEX_HOME:-$HOME/.codex}"
claude_home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
roles=(researcher planner implementer reviewer)

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

require_source() {
  if [ ! -e "$1" ]; then
    printf 'error: required source does not exist: %s\n' "$1" >&2
    exit 1
  fi
}

next_backup_path() {
  local destination=$1 base candidate suffix=0

  base="${destination}.backup-${timestamp}"
  candidate=$base
  while path_exists "$candidate"; do
    suffix=$((suffix + 1))
    candidate="${base}.${suffix}"
  done
  printf '%s\n' "$candidate"
}

ensure_parent() {
  local parent

  parent="$(dirname "$1")"
  if [ -d "$parent" ]; then
    return
  fi

  if [ "$dry_run" = true ]; then
    printf 'would create directory %s\n' "$parent"
  else
    mkdir -p "$parent"
  fi
}

link_path() {
  local source=$1 destination=$2 backup='' status

  if [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source" ]; then
    printf 'unchanged %s -> %s\n' "$destination" "$source"
    return
  fi

  ensure_parent "$destination"

  if path_exists "$destination"; then
    backup="$(next_backup_path "$destination")"
    if [ "$dry_run" = true ]; then
      printf 'would back up %s -> %s\n' "$destination" "$backup"
    else
      mv "$destination" "$backup"
      printf 'backed up %s -> %s\n' "$destination" "$backup"
    fi
  fi

  if [ "$dry_run" = true ]; then
    printf 'would link %s -> %s\n' "$destination" "$source"
    return
  fi

  if ln -s "$source" "$destination"; then
    printf 'linked %s -> %s\n' "$destination" "$source"
    return
  else
    status=$?
  fi

  printf 'error: failed to link %s -> %s\n' "$destination" "$source" >&2
  if [ -n "$backup" ] && ! path_exists "$destination"; then
    if mv "$backup" "$destination"; then
      printf 'restored %s from %s\n' "$destination" "$backup" >&2
    else
      printf 'error: restore failed; original remains at %s\n' "$backup" >&2
    fi
  elif [ -n "$backup" ]; then
    printf 'error: destination changed; original remains at %s\n' "$backup" >&2
  fi
  return "$status"
}

# Validate every fixed source before changing a destination.
require_source "$repo/.codex/AGENTS.md"
require_source "$repo/.claude/CLAUDE.md"
for role in "${roles[@]}"; do
  require_source "$repo/.codex/agents/$role.toml"
  require_source "$repo/.claude/agents/$role.md"
done
for skill in "$repo"/skills/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  require_source "${skill%/}"
done

link_path "$repo/.codex/AGENTS.md" "$codex_home/AGENTS.md"
link_path "$repo/.claude/CLAUDE.md" "$claude_home/CLAUDE.md"

for role in "${roles[@]}"; do
  link_path \
    "$repo/.codex/agents/$role.toml" \
    "$codex_home/agents/$role.toml"
  link_path \
    "$repo/.claude/agents/$role.md" \
    "$claude_home/agents/$role.md"
done

for skill in "$repo"/skills/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  skill="${skill%/}"
  link_path "$skill" "$codex_home/skills/$(basename "$skill")"
  link_path "$skill" "$claude_home/skills/$(basename "$skill")"
done
