# How min-cursor works

## The shape of it

```
Cursor ──ssh min-cursor.NAME──▶ /usr/bin/ssh ──ProxyCommand──▶ min-cursor _proxy NAME
                                                                   │ prepare (re-pin, push key)
                                                                   ▼
                                                   exec min session exec ID sshd -i ...
                                                                   │ (min's exec channel)
                                                                   ▼
                                                       sshd in the box ◀── Cursor server
```

`bin/min-cursor` has three parts: tool constants (`TOOL`, `HOST_PREFIX`,
...), the **plumbing** (transport, ssh, sessions), and the **client layer**
(everything Cursor). The plumbing never mentions an editor:
it calls `client_on_connect`, `client_on_destroy` and `client_linked` when
the client layer defines them.

## Transport

`min session exec ID argv...` is a byte-transparent, non-PTY exec channel
into the box. The ProxyCommand runs `sshd -i` over it, so ssh speaks to a
real OpenSSH server on stdin/stdout. No port listens anywhere.

sshd runs with a fixed flag set: `-f /dev/null` (no config file), the
box's host key `~/.ssh/min-cursor/host_ed25519`, `AuthorizedKeysFile
~/.ssh/min-cursor/authorized_keys`, public-key auth only,
`PermitUserEnvironment=yes` (sshd scrubs the environment; `~/.ssh/environment`
restores the session's variables), TCP forwarding on, agent and X11
forwarding off, `internal-sftp`.

### prepare and PREP

Before every connection (`open`, `attach`, `ssh`, and `_proxy` behind every
stanza) `prepare` runs one `min session exec ID sh -c PREP min-cursor
PUBKEY`, ID being the box's id (below). PREP, in the box:

- generates the box's host key once, under a lock (`.keygen` dir; stale
  locks broken by one waiter at a time; the pair renamed into place whole),
  so concurrent connects agree on one key;
- writes `authorized_keys`;
- rewrites `~/.ssh/environment` from `env`;
- appends the `min:workbench` and `min:motd` rc lines (each unless there; an older `min:motd` line is replaced) and a `~/.bash_profile` that sources
  `~/.bashrc`;
- prints `user=`, `home=`, `sshd=`, `hostkey=`.

The host validates every fact (they come from an untrusted box), then writes
`known_hosts` (`min-cursor.NAME <key>`), `user`, `home`, `sshd` and `id` under
`~/.local/state/min-cursor/sessions/NAME/`, each by rename, and refreshes the
stanza file; if a write fails, `prepare` stops there. `_proxy` and the
ProxyCommand `min-cursor ssh` builds re-check the stored `home`, `sshd` and
`id` before using them. A box min-cursor recreates (`open -n NAME` once the
old one is gone) gets a new id and heals on its first connect; `prepare`
never replaces a recorded id with another one.

### Box ids

min 0.8 ([gominimal/minimal#2756](https://github.com/gominimal/minimal/pull/2756))
made a session name an alias: a stopped box keeps its name, and `min ls`
still lists it, but it doesn't stop a new box from taking the name; only a
running box (or a resume in flight) does. min resolves a name to the
running box, else the latest. Every min command min-cursor runs
takes a full session id first, so min-cursor addresses its own boxes by id:
`session exec` (prepare, `_proxy`, `ssh`'s ProxyCommand) and `session
destroy`. The id is `sessions/NAME/id`, one line, checked against
`[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` whenever it is
read; a file that fails the check is never used (the box is not own, and
naming it is refused). Activation records it: the one id `min ls` lists
afterwards and not before (named NAME with `-n`, else for the folder). The
name stays the handle: `ssh min-cursor.NAME`, the settings entry, the
extension and the commands.

Own means: a key dir whose recorded id `min ls` lists under the dir's name
(a box renamed outside min-cursor, or another tool's box that took the name,
is not own). A key dir from before ids is adopted, its id written by a
command that connects to the box (`open`, `attach`, `ssh`, `_proxy`), when
exactly one box has its name; only that box adopts, never the other key dirs
a list or a refresh of the stanzas or settings looks at. Every other command
(`destroy`, which reaches the box by that id but writes none; `ssh-config`,
`config`, `setup`, each with any option; `gc`, `status`, completions and
`doctor`) counts it own without writing; `doctor` says it will be adopted.
`gc` lists such a key dir as "no id recorded (attach NAME once)" and never
asks about it, and `destroy --own` (the extension's Destroy and Clean up)
and `destroy` with no NAME (the cwd lookup) refuse it: none ever destroys a
box found only by its name. `status --json` marks each row `recorded` (its
id is in `sessions/NAME/id`), and Clean up offers only those. `open` never
adopts while it looks: the id is recorded by `prepare`, after the project
check. A box min lists with no id, or one that is no session id, is never
reached and never counts as gone. With several, none is own, no stanza or
settings entry is written for it, and `doctor` warns. The adoption has a
risk: a legacy key dir whose own box is long gone adopts the one box that
now holds the name, whoever made it. "Gone" is a successful `min ls` that no
longer lists the recorded id. A recorded id is never traded for a box found
by name: when ours is gone and another box has the name, `destroy NAME`
drops only our keys and records, and `attach`, `ssh`, `open -n` and `_proxy`
refuse ("your box NAME is gone; another box now has the name"); when min
lists our id under another name (renamed outside min-cursor), everything
refuses. `_proxy NAME` reaches only an own box (or, with no key dir at all,
the one box of that name). When `min ls` fails, the stanzas on disk stay
(all but those with a bad `id`); `_proxy` decides at connect.

### Stanzas and `_proxy`

`min-cursor ssh-config` adds two marked lines at the top of `~/.ssh/config`:

    # min-cursor ssh-config (remove with: min-cursor ssh-config --remove)
    Include ~/.ssh/min-cursor.conf

`~/.ssh/min-cursor.conf` (mode 600) has one stanza per prepared session that
min still lists as own (by its id, above):

    # myproject-3f9c
    Host min-cursor.myproject-3f9c
        User <box user>
        IdentitiesOnly yes
        AddKeysToAgent no
        UserKnownHostsFile "~/.local/state/min-cursor/sessions/myproject-3f9c/known_hosts"
        StrictHostKeyChecking yes
        ForwardAgent no
        ForwardX11 no
        ForwardX11Trusted no
        IdentityFile "~/.local/state/min-cursor/sessions/myproject-3f9c/id_ed25519"
        ProxyCommand env MIN_BIN=/path/to/min MIN_CURSOR_STATE_DIR=... ~/.local/bin/min-cursor _proxy myproject-3f9c

then a catch-all `Host min-cursor.* !min-cursor.*.*` whose ProxyCommand
explains that no stanza exists (it passes no hostname to the shell). The
file is rewritten only when its content changes. `_proxy` writes nothing to
stdout before it `exec`s `min session exec ID sshd ...`, and logs one line
per attempt to `proxy.log` (mode 600, capped): `ok`, or `fail:` and why.

Any other `Include ~/.ssh/min-*.conf` line in `~/.ssh/config` is left
alone. What the install created (`~/.ssh`, `~/.ssh/config`) is recorded in
`~/.local/state/min-clients/ssh-config-created`, and removing the last such
Include deletes those, so `~/.ssh/config` ends byte for byte as it was.

### In use

`in_use_names` reads the host process table (`ps -xo pid=,ppid=,args=`)
for processes whose argv has `session exec X <path ending /sshd>`:
`_proxy` after its exec, ControlPersist masters, any ssh client. X is an id
or, for connections opened before ids or by other tools, a name; an own box
is in use when either its name or its id is there. Nothing
contacts a box to find out.

## Client layer

### open / new / attach

1. Pick or activate the session (`min session activate --no-prompt
   [--loadout D]... --loadout cursor [-n NAME] PATH`, D being your
   `[loadouts] default_loadouts`, which min skips once any `--loadout` is
   named; min-cursor takes the one id new in `min ls`, named NAME with
   `-n`, else for PATH, and records it in `sessions/NAME/id`).
2. `prepare` (above).
3. `client_on_connect`: settings refresh (below).
4. `cursor --remote ssh-remote+min-cursor.NAME /workbench`.

### Settings merger (`bin/min-cursor-config`)

settings.json is JSONC and Cursor edits it too, so it is never rewritten
from a parsed object. The merger blanks comments (keeping byte offsets) to
parse it, then makes one of two textual edits: a marked block after the
opening brace holding `remote.SSH.remotePlatform` when you do not have it,
or, when you do, a replacement of just that object's value. It writes no
other key: Cursor's Remote-SSH has no `remote.SSH.useLocalServer`. A `--sync
NAME...` list is the full set of live prepared own sessions; entries with
the `min-cursor.` prefix not in it are dropped, every other entry stays,
including ones Cursor added inside our block. The opt-in record is
`STATE/settings-installed`; a refresh is skipped when `min ls` fails, so a
transient error never empties the list.

## State directory

`~/.local/state/min-cursor/`:

| Path | What |
|---|---|
| `sessions/NAME/` | `id_ed25519` keypair, `known_hosts`, `user`, `home`, `sshd`, `id` (the box's min session id: min-cursor reaches it by that) |
| `created/NAME` | the session was activated by min-cursor (has the loadout) |
| `orphan/NAME`, `kept/NAME` | first seen unused by `gc` or `status` (epoch); kept at a destroy prompt |
| `backups/` | `ssh_config.<time>`, `settings.json.<time>` |
| `settings-installed`, `settings-created` | opt-in records (the ssh-config one is `~/.local/state/min-clients/ssh-config-created`) |
| `proxy.log` | one line per connection attempt |

In the box: `~/.ssh/min-cursor/host_ed25519`, `~/.ssh/min-cursor/authorized_keys`,
`~/.ssh/environment`, `~/.cursor-server/`.
