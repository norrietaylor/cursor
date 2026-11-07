# Commands

Run `min-cursor` on the host (any terminal). Shells inside a box run in the
box, where `min-cursor` is not installed.

| Command | Does |
|---|---|
| `min-cursor open [PATH] [-n NAME] [--no-window]` | the session for `PATH` (default `.`): a live one min-cursor made is reused, else one is activated with `--loadout cursor`; then Cursor opens `/workbench` in it. Prints `min-cursor.NAME` |
| `min-cursor new [PATH \| --empty] [-n NAME] [--no-window]` | always a new session for `PATH`, then Cursor; `--empty`: an empty `/workbench` (`--sync none`), named by min (`box-<hex>`) |
| `min-cursor attach [NAME] [--no-window]` | an existing session in Cursor (no NAME: pick one of its own) |
| `min-cursor destroy [-y] [--if-idle] [--force] [NAME]` | ask `[y/N]`, then destroy (no NAME: its one session for the current directory); `--if-idle` refuses with exit 3 while something is connected. Without a terminal, min refuses a session with unsaved changes: exit 4; `-y --force` discards them. When the `min ls` that follows fails, the session's keys and stanza stay, with a warning, and after a y the exit is non-zero (min's own status, or 1 when min destroyed it); once `min ls` lists its id no more (a key dir with no id: once no box is named NAME), `destroy NAME` removes what was kept |
| `min-cursor gc [--older-than SECONDS] [--dry-run]` | list active sessions no ssh client is using (oldest first), then ask `[y/N/q]` for each |
| `min-cursor status [--json]` | table: session, status, project, in use, idle age; `--json`: `[{name, id, status, project, own, recorded, empty, in_use, idle}]` (`id`: min's session id; `own`: min-cursor's box, by that id; `recorded`: that id is in `STATE/sessions/NAME/id`, not only adoptable; idle in seconds or null, own boxes only) |
| `min-cursor doctor` | health report; exits 1 on any FAIL |
| `min-cursor setup [--remove]` | the whole install from this copy: links `~/.local/bin/min-cursor` and the `cursor` loadout here, then `ssh-config` and `config`; `--remove` undoes only ours |
| `min-cursor config [--remove\|--print]` | opt in to (or out of) the settings block; `--print` only prints |
| `min-cursor ssh NAME [-- ARGS]` | plain `ssh` over the same transport (debugging: `-- -v`) |
| `min-cursor ssh-config [--remove\|--print]` | opt in: one `Host min-cursor.NAME` stanza per session in `~/.ssh/min-cursor.conf`, included from the top of `~/.ssh/config` |
| `min-cursor completions <zsh\|bash>` | print a completion script (`eval "$(min-cursor completions zsh)"`) |

`--no-window` does everything but open the window; the extension opens it
itself (`vscode-remote://ssh-remote+min-cursor.NAME/workbench`).

`--own` (`attach`, `destroy`; internal, the extension's): NAME must still
be one of min-cursor's own boxes, as one picked from its list; otherwise the
command refuses ("NAME is not a box of min-cursor's"). `destroy --own` also
refuses a key dir with no recorded id ("NAME has no recorded box id yet"), so
the view's Destroy and Clean up only reach a box by the id min-cursor
recorded. `gc` likewise lists such a key dir as "no id recorded (attach NAME
once)" and never asks about it, and `destroy` with no NAME (the current
folder's box) refuses it the way `--own` does.

Names: without `-n`, min names a new session (`<dir>-<hex>`, e.g.
`myproject-3f9c`), and min-cursor takes the one new session for the path.
Every name, min's or a `-n NAME`, must match `^[a-z0-9][a-z0-9-]*$`: names
become hostnames and ssh `Host` patterns; one that does not is refused.

"In use" means some process on the host is connected to the box: any
`min session exec ID ... sshd` (or, from older connections and other tools,
`... exec NAME ...`), which covers Cursor, a terminal `ssh`,
`scp` and any other ssh client. `gc` leaves sessions in use out; their idle age
(`status`, `gc`) restarts while they are in use, and counts from the first
`gc` or `status` that saw the session unused (each run dates them).
`gc` offers only sessions min-cursor has connected to (it has keys for them
under `STATE/sessions/NAME`, and the box's id in `STATE/sessions/NAME/id`);
boxes other tools or `min` alone made are not its to tidy. `open`, `destroy`
without NAME, the `attach` picker and completions pass them over too; only
an explicit NAME (`attach NAME`, `ssh NAME`, `destroy NAME`, `open -n NAME`)
reaches one.

Box ids: since min 0.8 several boxes may share a name (a stopped box keeps
its name and is still listed, but a new box may take the name; only a
running box holds it), and min picks the running one, else the
latest, for a name. So min-cursor reaches its own boxes by the id it recorded
when it made or first connected to them; the name stays the handle (`ssh
min-cursor.NAME`, the settings entry, the extension, the commands). A box is
own only while `min ls` lists that id under that name. A key dir from before
ids takes the id of the one box with its name; when several share it,
min-cursor cannot tell which is its own and leaves them all alone (`doctor`
says so; naming it says so too). An explicit NAME that is not own goes to
the one box with that name, and is refused when several have it, or when
min-cursor's own box of that name is gone (it never takes another box in its
place; `destroy NAME` then drops only min-cursor's record).

just recipes: `check`, `install`, `ssh-config`, `cursor-config`, `skills`,
`uninstall`, `ext-deps`, `vsix`.
