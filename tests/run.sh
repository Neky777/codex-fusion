#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-fusion-tests.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT
export HOME=$tmp_root/home
export CODEX_HOME="$HOME/.codex"
mkdir -p "$HOME" "$CODEX_HOME/fusion"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [[ -f $1 ]] || fail "expected file: $1"; }
assert_not_file() { [[ ! -e $1 ]] || fail "unexpected file: $1"; }
assert_contains() { grep -F "$2" "$1" >/dev/null || fail "missing '$2' in $1"; }

# Preserve pre-existing target content and the user's base config.
printf 'user profile data\n' > "$CODEX_HOME/fusion.config.toml"
printf 'user Luna data\n' > "$CODEX_HOME/fusion/luna.toml"
printf 'default config stays untouched\n' > "$CODEX_HOME/config.toml"

"$repo_dir/scripts/install.sh" >/dev/null
assert_file "$CODEX_HOME/.codex-fusion/original/fusion.config.toml"
assert_file "$CODEX_HOME/.codex-fusion/original/fusion/luna.toml"
assert_contains "$CODEX_HOME/fusion.config.toml" 'config_file = "fusion/luna.toml"'
assert_contains "$CODEX_HOME/fusion/luna.toml" 'sandbox_mode = "workspace-write"'
assert_contains "$CODEX_HOME/config.toml" 'default config stays untouched'

# A repeat install stays the same and does not replace the original backup.
cp "$CODEX_HOME/.codex-fusion/original/fusion.config.toml" "$tmp_root/original-before.toml"
"$repo_dir/scripts/install.sh" >/dev/null
cmp -s "$tmp_root/original-before.toml" "$CODEX_HOME/.codex-fusion/original/fusion.config.toml" || fail 'repeat install changed the original backup'

# Uninstall restores existing files and leaves the base config untouched.
"$repo_dir/scripts/uninstall.sh" >/dev/null
[[ $(cat "$CODEX_HOME/fusion.config.toml") == 'user profile data' ]] || fail 'profile backup was not restored'
[[ $(cat "$CODEX_HOME/fusion/luna.toml") == 'user Luna data' ]] || fail 'Luna backup was not restored'
assert_contains "$CODEX_HOME/config.toml" 'default config stays untouched'
assert_not_file "$CODEX_HOME/.codex-fusion"

# An install into an empty Codex home is removed cleanly.
rm -rf "$CODEX_HOME/fusion.config.toml" "$CODEX_HOME/fusion/luna.toml"
"$repo_dir/scripts/install.sh" >/dev/null
"$repo_dir/scripts/uninstall.sh" >/dev/null
assert_not_file "$CODEX_HOME/fusion.config.toml"
assert_not_file "$CODEX_HOME/fusion/luna.toml"

# Edits made after installation are preserved as an uninstall backup.
"$repo_dir/scripts/install.sh" >/dev/null
printf '\n# user edit\n' >> "$CODEX_HOME/fusion.config.toml"
"$repo_dir/scripts/install.sh" >/dev/null
grep -R -l -F '# user edit' "$CODEX_HOME/backups/codex-fusion" >/dev/null || fail 'edited file was not backed up during upgrade'
"$repo_dir/scripts/uninstall.sh" >/dev/null
grep -R -l -F '# user edit' "$CODEX_HOME/backups/codex-fusion" >/dev/null || fail 'edited file was not backed up during uninstall'

printf 'All Codex Fusion tests passed.\n'
