# Codex Fusion

Codex Fusion is a reusable Codex CLI profile for a Sol lead agent with a Luna
implementation agent. It packages a working local setup as portable templates
and safe install scripts.

The profile is opt-in: use `codex -p fusion` (or `codex --profile fusion`). A
plain `codex` run continues to use the regular user configuration. The profile
does not edit `config.toml`, authentication files, or shell startup files.

## What it configures

- Sol uses `gpt-6-sol` with high reasoning effort.
- The Fusion profile describes when and how Sol should delegate bounded work
  to Luna and check the result.
- Luna uses `gpt-6-luna`, high reasoning effort, and `workspace-write`.
- Luna's role file is referenced relatively from the Fusion profile, so no
  machine-specific home path is embedded in the templates.

Codex may inherit live sandbox and approval overrides from the parent session
when it starts a subagent. A parent session switched to full access can therefore
override Luna's configured `workspace-write` setting. Keep the parent session
in the intended permission mode when workspace scoping matters.

Fusion gives Codex configuration and delegation guidance. Codex CLI does not
promise proactive delegation on every task, and this setup is not an exact
equivalent of Devin Fusion.

## Requirements

- Codex CLI with support for profiles and custom agents.
- Bash 3.2 or later (the macOS system Bash is supported).
- Standard macOS/Linux utilities: `cmp`, `cp`, `grep`, `mktemp`, and `rmdir`.

## Install

From the repository root:

```sh
./scripts/install.sh
```

Then start Fusion explicitly:

```sh
codex -p fusion
# equivalent:
codex --profile fusion
```

You can pass normal Codex arguments too, for example `codex -p fusion --help`.

The installer targets `$CODEX_HOME` when set, otherwise `~/.codex`. It writes
only `fusion.config.toml` and `fusion/luna.toml`. Existing versions are backed
up in `$CODEX_HOME/.codex-fusion/original/` before replacement. Re-running the
installer is safe and does not create duplicate backups when the installed
files already match.

To preview paths and changes without writing:

```sh
./scripts/install.sh --dry-run
```

To install into a temporary or custom Codex home:

```sh
CODEX_HOME="$HOME/.codex-test" ./scripts/install.sh
```

## Uninstall

```sh
./scripts/uninstall.sh
```

The uninstaller removes unchanged Fusion files and restores any files saved by
the installer. If you edited an installed file, it first saves that version to
`$CODEX_HOME/backups/codex-fusion/` before restoring the original. The regular
`config.toml`, auth state, shell files, and active Codex processes are untouched.

## Verification

Run the local script tests with:

```sh
./tests/run.sh
```

CI runs the same tests on macOS and Ubuntu. For a real session, verify the
profile and Luna's effective permissions in Codex's session details. Project
trust, managed policy, and live parent permission overrides can affect the
effective runtime.

The templates follow the official Codex CLI configuration format:

- [Config basics](https://developers.openai.com/codex/config-basic)
- [Configuration reference](https://developers.openai.com/codex/config-reference)
- [Subagents](https://developers.openai.com/codex/multi-agent)
