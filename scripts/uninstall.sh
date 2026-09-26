#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--dry-run]\n' "$0"
}

dry_run=0
if [[ ${1:-} == --dry-run ]]; then
  dry_run=1
elif [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi

codex_home=${CODEX_HOME:-"${HOME:?HOME must be set}/.codex"}
state_dir=$codex_home/.codex-fusion
state_marker=$state_dir/managed-by-codex-fusion

if [[ ! -d $state_dir ]]; then
  printf 'No Codex Fusion install state found in %s\n' "$codex_home"
  exit 0
fi

if [[ ! -f $state_marker ]]; then
  printf 'Refusing to use unrecognized install state directory: %s\n' "$state_dir" >&2
  exit 1
fi

restore_one() {
  local rel=$1 target original absent installed
  target=$codex_home/$rel
  original=$state_dir/original/$rel
  absent=$state_dir/original/$rel.absent
  installed=$state_dir/installed/$rel
  if (( dry_run )); then
    printf 'Would remove installed file and restore backup if present: %s\n' "$target"
    return
  fi
  if [[ -e $target ]]; then
    if [[ -f $installed ]] && cmp -s "$target" "$installed"; then
      rm -f "$target"
    else
      local backup_dir=$codex_home/backups/codex-fusion/uninstall-$(date -u +%Y%m%dT%H%M%SZ)-$$
      mkdir -p "$backup_dir/$(dirname -- "$rel")"
      cp -p "$target" "$backup_dir/$rel"
      printf 'Saved your edited file to: %s\n' "$backup_dir/$rel"
      rm -f "$target"
    fi
  fi
  if [[ -f $original ]]; then
    mkdir -p "$(dirname -- "$target")"
    cp -p "$original" "$target"
    printf 'Restored backup: %s\n' "$target"
  elif [[ ! -f $absent ]]; then
    printf 'No original-file record for %s; left it removed.\n' "$target" >&2
  fi
}

restore_one fusion.config.toml
restore_one fusion/luna.toml
if (( ! dry_run )); then
  rm -rf "$state_dir"
  rmdir "$codex_home/fusion" 2>/dev/null || true
  printf 'Codex Fusion has been uninstalled.\n'
fi
