# Configuration

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `MIN_CURSOR_STATE_DIR` | `${XDG_STATE_HOME:-~/.local/state}/min-cursor` | state directory (keys, facts, backups, logs) |
| `MIN_CURSOR_SETTINGS` | `~/Library/Application Support/Cursor/User/settings.json` | the settings file `config` edits |
| `MIN_CURSOR_EDITOR_BIN` | `cursor` | the Cursor CLI (stable Cursor only; Nightly is untested) |
| `MIN_LOCK_WAIT` | 10 | seconds `ssh-config` waits for the `~/.ssh/config` lock |
| `MIN_CURSOR_DEBUG` | unset | log the editor command and other detail |
| `MIN_BIN` | `min` on PATH | `min` binary; resolved to an absolute path for the ProxyCommand |
| `SSH_KEYGEN_BIN` | `ssh-keygen` | key generator |

`MIN_BIN` and `MIN_CURSOR_STATE_DIR` are baked into each
`~/.ssh/min-cursor.conf` stanza as it is written, because Cursor starts
`ssh` with the launchd PATH and no shell rc; after changing either, re-run
`min-cursor ssh-config` (or any `open`/`attach`).

Needs min 0.7.0 or newer; `doctor` fails on an older one.

**Loadout.** `loadouts/cursor.toml` adds `openssh`, `curl`, `rsync`,
`xxhash` and `git`, copies Minimal's `minimal-sandbox` skill into
`~/.cursor/skills` for Cursor's agent (vendored in `loadouts/cursor/` from
gominimal/minimal-skills; `just skills` refreshes it), prepares the in-box sshd environment, and adds the
`min:workbench` rc line. `min-cursor setup` symlinks it to
`~/.config/minimal/loadouts/cursor.toml` and copies `loadouts/cursor/` beside
it. It is never added to
`default_loadouts`: min-cursor activates with your `default_loadouts` plus
`--loadout cursor` (min would drop the defaults once any `--loadout` is
named, so min-cursor passes them on), and boxes made by other tools carry only
their own loadouts (min-cursor can still attach to them).

**Settings.** See [cursor.md](cursor.md#settings-min-cursor-config).

## Rolling back

    just uninstall

takes the settings block out (`min-cursor config
--remove`, with a backup), removes the Include from `~/.ssh/config`
(byte-identical to before; `~/.ssh/min-cursor.conf` is deleted), and removes
the loadout and CLI symlinks if they point into this checkout. It leaves the
state directory, which holds the session keys and every backup.
