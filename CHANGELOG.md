# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- `destroy` and `gc`: a failed `min ls` after the answer no longer counts as
  the box being gone. Before, it removed the session's keys, refreshed
  settings and dropped its ssh stanza even after an `n`; now everything is
  kept, with a warning, and after a `y` the command exits non-zero (min's
  own status, or 1 when min destroyed the box). Once `min ls` no longer
  lists the box, `destroy NAME` removes what was kept.

## [0.1.0] - 2026-10-28

First release.

- **Cursor extension** (Minimal view): set up once, create a box from a
  folder or empty, open it over Remote-SSH, destroy it, clean up idle boxes;
  the box name in a remote window's status bar. Destroyed boxes leave
  Cursor's recent list. The VSIX carries its own copy of the CLI and loadout.
- **`min-cursor` CLI**: `setup`, `open`/`new`/`attach` (`--no-window`,
  `new --empty`), `destroy` (`--if-idle`, `-y --force`), `gc`,
  `status [--json]`, `doctor`, `config`, `ssh`, `ssh-config`, `completions`.
- **Transport**: OpenSSH `sshd` inside the box behind a
  `min session exec` ProxyCommand; per-box keys, pinned host key, agent and
  X11 forwarding off, nothing listening on a port.
- **Settings**: one `remote.SSH.remotePlatform` entry per box in Cursor's
  `settings.json`, in a marked block that `--remove` takes out byte for byte.
- **`cursor` loadout**: `openssh`, `curl`, `rsync`, `xxhash`, `git`;
  Minimal's `minimal-sandbox` skill copied into `~/.cursor/skills` for
  Cursor's agent in the box; the in-box sshd environment;
  interactive shells start in `/workbench`.
- **Skills**: Minimal's skills from gominimal/minimal-skills 0.7.0 (MIT),
  vendored: `setup` gives Cursor's agent on the Mac the host ones
  (`minimal-setup`, `-config`, `-loadouts`, `-networking`, `-diag`); boxes
  get `minimal-sandbox`.
- Needs min 0.7.0 or newer (`doctor` fails on older).
