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

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
codex_home=${CODEX_HOME:-"${HOME:?HOME must be set}/.codex"}
state_dir=$codex_home/.codex-fusion
state_marker=$state_dir/managed-by-codex-fusion
profile_target=$codex_home/fusion.config.toml
luna_target=$codex_home/fusion/luna.toml

if [[ ! -f $repo_dir/templates/fusion.config.toml || ! -f $repo_dir/templates/fusion/luna.toml ]]; then
  printf 'Fusion templates are missing from %s\n' "$repo_dir/templates" >&2
  exit 1
fi

if (( dry_run )); then
  printf 'Would install Fusion into: %s\n' "$codex_home"
  printf '  %s\n  %s\n' "$profile_target" "$luna_target"
  if [[ -d $state_dir ]]; then
    printf 'Existing install state found: %s\n' "$state_dir"
  else
    printf 'First install will preserve pre-existing target files under: %s/original\n' "$state_dir"
  fi
  exit 0
fi

if [[ -e $state_dir && ! -f $state_marker ]]; then
  printf 'Refusing to use unrecognized install state directory: %s\n' "$state_dir" >&2
  exit 1
fi

mkdir -p "$codex_home" "$codex_home/fusion" "$state_dir/original" "$state_dir/installed"
chmod 700 "$state_dir" "$state_dir/original" "$state_dir/installed"
if [[ ! -f $state_marker ]]; then
  printf 'codex-fusion v0.1.0\n' > "$state_marker"
  chmod 600 "$state_marker"
fi

preserve_original() {
  local target=$1 rel=$2 original absent
  original=$state_dir/original/$rel
  absent=$state_dir/original/$rel.absent
  if [[ -e $original || -e $absent ]]; then
    return
  fi
  mkdir -p "$(dirname -- "$original")"
  if [[ -e $target ]]; then
    cp -p "$target" "$original"
    printf 'Backed up existing file: %s\n' "$target"
  else
    : > "$absent"
  fi
}

install_one() {
  local source=$1 target=$2 rel=$3 installed tmp
  installed=$state_dir/installed/$rel
  mkdir -p "$(dirname -- "$installed")"
  preserve_original "$target" "$rel"
  if [[ -f $target ]] && cmp -s "$source" "$target"; then
    cp "$source" "$installed"
    printf 'Already current: %s\n' "$target"
    return
  fi
  if [[ -e $target && -f $installed ]] && ! cmp -s "$target" "$installed"; then
    local backup_dir=$codex_home/backups/codex-fusion/upgrade-$(date -u +%Y%m%dT%H%M%SZ)-$$
    mkdir -p "$backup_dir/$(dirname -- "$rel")"
    cp -p "$target" "$backup_dir/$rel"
    printf 'Backed up edited Fusion file: %s\n' "$backup_dir/$rel"
  fi
  tmp=$(mktemp "$(dirname -- "$target")/.codex-fusion.XXXXXX")
  cp "$source" "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$target"
  cp "$source" "$installed"
  chmod 600 "$installed"
  printf 'Installed: %s\n' "$target"
}

install_one "$repo_dir/templates/fusion.config.toml" "$profile_target" fusion.config.toml
install_one "$repo_dir/templates/fusion/luna.toml" "$luna_target" fusion/luna.toml

printf 'Fusion is ready. Start it with: codex -p fusion\n'
