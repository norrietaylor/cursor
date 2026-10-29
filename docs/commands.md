# Commands

Run `min-cursor` on the host (any terminal). Shells inside a box run in the
box, where `min-cursor` is not installed.

| Command | Does |
|---|---|
| `min-cursor open [PATH] [-n NAME] [--no-window]` | the session for `PATH` (default `.`): a live one is reused, else one is activated with `--loadout cursor`; then Cursor opens `/workbench` in it. Prints `min-cursor.NAME` |
| `min-cursor new [PATH \| --empty] [-n NAME] [--no-window]` | always a new session for `PATH`, then Cursor; `--empty`: an empty `/workbench` (`--sync none`), named by min (`box-<hex>`) |
| `min-cursor attach [NAME] [--no-window]` | an existing session in Cursor (no NAME: pick one) |
| `min-cursor destroy [-y] [--if-idle] [--force] [NAME]` | ask `[y/N]`, then destroy (no NAME: the one session for the current directory); `--if-idle` refuses with exit 3 while something is connected. Without a terminal, min refuses a session with unsaved changes: exit 4; `-y --force` discards them |
| `min-cursor gc [--older-than SECONDS] [--dry-run]` | list active sessions no ssh client is using (oldest first), then ask `[y/N/q]` for each |
| `min-cursor status [--json]` | table: session, status, project, in use, idle age; `--json`: `[{name, status, project, own, empty, in_use, idle}]` (idle in seconds or null) |
| `min-cursor doctor` | health report; exits 1 on any FAIL |
| `min-cursor setup [--remove]` | the whole install from this copy: links `~/.local/bin/min-cursor` and the `cursor` loadout here, then `ssh-config` and `config`; `--remove` undoes only ours |
| `min-cursor config [--remove\|--print]` | opt in to (or out of) the settings block; `--print` only prints |
| `min-cursor ssh NAME [-- ARGS]` | plain `ssh` over the same transport (debugging: `-- -v`) |
| `min-cursor ssh-config [--remove\|--print]` | opt in: one `Host min-cursor.NAME` stanza per session in `~/.ssh/min-cursor.conf`, included from the top of `~/.ssh/config` |
| `min-cursor completions <zsh\|bash>` | print a completion script (`eval "$(min-cursor completions zsh)"`) |

`--no-window` does everything but open the window; the extension opens it
itself (`vscode-remote://ssh-remote+min-cursor.NAME/workbench`).

Names: without `-n`, min names a new session (`<dir>-<hex>`, e.g.
`myproject-3f9c`), and min-cursor takes the one new session for the path.
Every name, min's or a `-n NAME`, must match `^[a-z0-9][a-z0-9-]*$`: names
become hostnames and ssh `Host` patterns; one that does not is refused.

"In use" means some process on the host is connected to the box: any
`min session exec NAME ... sshd`, which covers Cursor, a terminal `ssh`,
`scp` and any other ssh client. `gc` leaves sessions in use out; their idle age
(`status`, `gc`) restarts while they are in use, and counts from the first
`gc` or `status` that saw the session unused (each run dates them).
`gc` offers only sessions min-cursor has connected to (it has keys for them
under `STATE/sessions/NAME`); boxes other tools or `min` alone made are not its
to tidy.

just recipes: `check`, `install`, `ssh-config`, `cursor-config`, `skills`,
`uninstall`, `ext-deps`, `vsix`.
