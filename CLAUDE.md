# CLAUDE.md

`min-cursor` opens Minimal boxes (`min` sessions, libkrun microVMs) in Cursor
over Cursor's Remote-SSH, with sshd running inside the box behind a
`min session exec` ProxyCommand. A Cursor extension (the Minimal view) is the
everyday UI; it drives one POSIX shell script plus a python3 settings merger,
which also work alone from a terminal.

## Layout

| File | Role |
|---|---|
| `bin/min-cursor` | tool constants, then the transport/ssh/session plumbing, then the client layer, whose first block holds every editor-specific constant |
| plumbing | transport, PREP/prepare, `stored_path`, ssh options and stanzas, `ssh-config`, `_proxy`, `ssh`, naming, `activate_session`, `destroy_one`, `in_use_names`/`box_in_use`, `track_orphans`, `default_loadouts`, the ssh-config record, report helpers; editor-neutral, reaching the client layer only through its hooks |
| client layer | `open`/`new`/`attach` (session, stanza, settings, `cursor --remote` unless `--no-window`; `new --empty`; `attach`'s hidden `--own`), `destroy` (`--if-idle`; hidden `--own`), `gc`, `status` (`--json`), `doctor`, `completions`, `config`, `setup`, hidden `_sessions`; hooks `client_on_connect` and `client_on_destroy` (settings sync) |
| `bin/min-cursor-config` | python3: marked-block merge of per-host `remote.SSH.remotePlatform` (the only key; Cursor has no `useLocalServer`) into Cursor's user settings.json; `--install`, `--sync NAME...`, `--remove`, `--doctor`, `--dry-run` |
| `loadouts/cursor.toml`, `loadouts/cursor/` | `openssh curl rsync xxhash git`; sshd env prep; `min:workbench` and `min:motd` rc lines; a patch copying `cursor/skills/minimal-sandbox` to `~/.cursor/skills` in the box. `setup` copies `cursor/` beside the linked toml: `$LOADOUT_ROOT` must be a real directory |
| `skills/`, `loadouts/cursor/skills/` | Minimal's skills, vendored from gominimal/minimal-skills (MIT) at a pinned commit by `just skills`: the host ones (`setup` copies them into the Mac's `~/.cursor/skills`, marked `.min-cursor-copy`, never over a dir with no `.min-*-copy` mark; one another min tool marked is shared, keeping its mark, and `--remove` deletes it only once no other mark is left) and `minimal-sandbox` (box only: the host ones teach commands a box lacks) |
| `extension/` | the Cursor extension (TypeScript, `extensionKind: ui`): Minimal view, commands, status bar; every action is a `min-cursor` call. The VSIX bundles `bin/`, `loadouts/` and `skills/` under `cli/` |
| `minimal.toml` | developing this repo in a box: session packages for `just check`/`just vsix`; tasks `check`, `vsix` (`min task run check`) |
| `justfile` | `check` (also type-checks `extension/`), `install`/`uninstall` (= `setup`), `ssh-config`, `cursor-config`, `skills`, `ext-deps`, `vsix` |
| `tests/run.sh`, `tests/stubs/` | plain-sh tests over stub `min`, `cursor`, `ssh`, `ssh-keygen`, `ps` and a `tripwire` for bare GUI commands; `LONG_PREFIX=1` reruns them with a long host prefix |
| `docs/` | `cursor.md` (guide, and how Cursor's Remote-SSH differs from VS Code's), `commands.md`, `configuration.md`, `security.md`, `troubleshooting.md`, `how-it-works.md`, `public/` marks and badge |

## Invariants

- Session names match `^[a-z0-9][a-z0-9-]*$`, `-n` included: they are
  hostnames and ssh `Host` patterns. Without `-n`, min names the session;
  `activate_session` takes the one new session for the path and refuses a
  name that is no hostname.
- Host alias is `min-cursor.NAME` (`HOST_PREFIX`); nothing hard-codes the
  prefix length (the long-prefix test run guards it).
- `prepare` re-pins the host key and re-pushes the public key on every
  `open`/`attach`/`ssh`/`_proxy`, so a box min-cursor recreated self-heals;
  it never replaces a recorded id with another.
  `_proxy` always runs `prepare` and writes nothing to stdout before `exec`
  (stdout is the SSH byte stream). `_proxy` and `prepare` never call client
  hooks, never touch settings.json.
- `ssh-config` is an opt-in gate: nothing under `~/.ssh` is touched until it
  has run. `ssh-config --remove` leaves `~/.ssh/config` byte-identical to
  before install; `--print` writes nothing (`PICK_NOADOPT`: not even a
  legacy key dir's adopted id). Other tools' Include lines are
  never touched.
- `config` is the same kind of gate for settings.json: `--sync` is a no-op
  until `config` has run (`STATE/settings-installed`). The merger keeps the
  user's bytes outside its marked block, edits only the value of an existing
  `remote.SSH.remotePlatform`, never removes a host entry without our prefix,
  writes no key but `remote.SSH.remotePlatform`, backs up to
  `STATE/backups/` before a write, and never writes when the effective
  settings are unchanged. Settings sync is skipped when `min ls` fails.
- The host key is pinned (`StrictHostKeyChecking=yes`); never `accept-new`.
- Agent and X11 forwarding stay off on every client path: one option list
  (`ssh_common`) feeds both the stanza and `ssh_opts`.
- Facts the box reports (user, hostkey, home, sshd) are untrusted: `prepare`
  validates them before writing anything, and dies if a write fails; stored
  `home`/`sshd` are re-checked on read (`stored_path`) by `_proxy` and by the
  ProxyCommand `ssh` builds; the stored `id` likewise (`stored_id`).
- `gc` and `destroy` never destroy without an explicit y; `-y` is the only
  way past `destroy`'s question.
- A box is gone (keys, records and stanza dropped, `client_on_destroy` run
  by `destroy_one`) only when a successful `min ls` no longer lists its id; a
  failed `min ls` keeps everything (ssh-config not rewritten), warns, and
  after a y exits non-zero; `destroy NAME` drops what was kept once a
  successful `min ls` no longer lists the recorded id (a key dir with no
  id: once no box is named NAME). `min_ls` fails, as min failing does, when
  min exits 0 with no session list (`.sessions` not an array), and
  `own_filter` fails on such input: never an empty list in its place.
- Every min call aimed at one box passes its id, never its name (min 0.8
  resolves a name to whichever box holds it): `session exec` (prepare,
  `_proxy`'s exec, `proxy_command`) and `session destroy` (`destroy_one`). The
  id is `STATE/sessions/NAME/id` (`activate_session`: the one id new in `min
  ls`, named NAME with `-n`, else for PATH; `prepare` writes it with the
  facts), checked against `ID_ERE` on every read (`stored_id`) before it
  reaches a command line or a stanza. `pick_id`/`box_id` resolve NAME: own
  (the recorded id, listed under NAME); a key dir with no `id` adopts the one
  box named NAME, only when a command connects to that box (`box_id`;
  `own_filter`, which every list and the stanza and settings refreshes go
  through, never writes; nor does anything under `PICK_NOADOPT=1`, which every
  command but `open`, `attach`, `ssh` and `_proxy` sets: `destroy` (it
  destroys by the id `pick_id` prints, and writes none), `ssh-config`,
  `config`, `setup` (the extension runs it on startup), `gc`, `status`,
  `_sessions` and `doctor`; they count it own without writing); several boxes
  named NAME, none recorded, or a bad `id` file: no id (`box_id` status 2,
  `BWHY`; also a listed box with a null or non-UUID id, `pick_id` 7, which is
  never "none", so `destroy` keeps our keys), so an explicit NAME dies saying
  why, `doctor` warns, it is not own and gets no stanza or settings entry;
  never a by-name call. A recorded id is never traded for a box found by name:
  ours gone (id unlisted; `pick_id` 5) with another box named NAME is `box_id`
  status 5, "your box NAME is gone": `destroy NAME` drops only our keys and
  records, everything else refuses; ours listed under another name (`pick_id`
  6) is refused everywhere. A NAME chosen from the own list (the cwd, the
  picker) resolves with `own`, and so does one the extension sends: its
  `destroy` and `attach` calls pass the hidden `--own`: NAME must still be own
  ("NAME is not a box of min-cursor's"), and `destroy --own` also refuses a
  key dir with no `id` ("NAME has no recorded box id yet"), and so does
  `destroy` with no NAME (the cwd lookup), so the view's Destroy and Clean up
  and the cwd lookup never reach a box found only by its name (`status --json`
  gives `recorded`; Clean up offers only recorded rows). `open` never adopts
  in its lookup: prepare records the id once the project matches. `gc` never
  adopts: a key dir with no `id` is listed ("no id recorded (attach NAME
  once)"), never asked about; `gc` destroys only a box whose recorded id `min
  ls` lists. A failed `min ls` keeps every stanza but a bad-id one. An
  explicit NAME that is not own and has no recorded id reaches the one box of
  that name (`attach`, `ssh`, `open -n`, `destroy`), refused when several
  share it; `_proxy NAME` only an own box, or the one box of that name when
  there is no key dir at all (a stanza of a box of ours that is gone never
  reaches the box that took its name). Helpers reading one session
  (`id_field`, `ls_lists`) select by id. Names stay the user-facing key: host
  aliases, settings entries, the extension.
- `gc` offers only own sessions (`own_ls`: a key dir `STATE/sessions/NAME`
  whose recorded id `min ls` lists under NAME; `status --json` gives `id`),
  and `gc`/`status` date only those in `orphan/` (`track_orphans`, each run);
  boxes made by `min` alone are never listed. The same holds wherever a
  session is chosen for the user: `open`'s reuse of a live session for PATH,
  `destroy`'s cwd lookup, the `attach` picker and `_sessions` (completions).
  Only an explicit NAME (`attach NAME`, `ssh NAME`, `destroy NAME`, `open -n
  NAME`) may reach another tool's box.
- In use = some host process runs `min session exec X ... sshd` (any ssh
  client's connection), for an own box by its name or its id (gc rows,
  `gc_still_idle`, `st_used`, `track_orphans`; `in_use_names` maps nothing); X
  is an id or a bare name (connections from before ids, other tools). Never
  contact a box without such a live process: a connect starts a stopped box.
- `gc` re-checks `gc_still_idle` before each question.
- `config`/doctor never prune on a failed `min ls`. `--remove` restores the
  bytes it found (brace framing, CRLF, BOM); a user's own remotePlatform
  object that we rewrote is re-indented.
- Activation passes the user's `default_loadouts` on before `--loadout cursor`.
- What `ssh-config` created under `~/.ssh` is recorded in
  `~/.local/state/min-clients/ssh-config-created`; removing the last
  `Include ~/.ssh/min-*.conf` deletes only that, so `~/.ssh/config` ends
  byte-identical.
- Install never edits `default_loadouts`; `setup --remove` (`just uninstall`)
  removes only our own links, settings entries and Include. `setup` replaces
  a link only when missing, dangling, or pointing to another copy of the same
  file (a checkout or an older extension dir); stanzas bake the
  `~/.local/bin` link, so it follows the extension across updates.
- The extension never decides a destroy itself: a modal's destructive button
  is the explicit y (`destroy -y`); unsaved changes (exit 4, min refused
  without a terminal) need a second modal before `destroy -y --force`;
  clean-up calls `destroy -y --if-idle`, which re-checks `gc_still_idle`
  (exit 3 when in use). It lists only own sessions, runs `setup` on startup
  only once `~/.ssh/min-cursor.conf` exists, and prunes Cursor's recent list
  only from a successful `status --json`.

## External facts that bite

- min 0.8.0-dev.381
  ([gominimal/minimal#2756](https://github.com/gominimal/minimal/pull/2756),
  BOX-004/005): a session name is an alias many boxes may share. A stopped box
  keeps its name, and `min ls` still lists it, but it doesn't stop a new box
  from taking the name; only a running box (or a resume in flight) does
  (minimald's `claim_name`/`running_name_holder`). A name resolves to the
  running box, else the latest. `session exec`, `attach`, `destroy`, `rename`
  and `policy` take a full session id first (`SessionLookup::parse`), and `min
  ls --json` gives each session's `id` (lowercase hex UUID) and `name` (which
  may be null).

- `min` is a zsh function on the host; `MIN_BIN` is resolved to an absolute
  path and baked into each stanza (Cursor spawns ssh with the launchd PATH).
- `bin/min-cursor` appends `/opt/homebrew/bin` to PATH (unless
  `MIN_NO_PATH_EXTEND=1`, which tests set, with `ZDOTDIR VISUAL EDITOR`
  unset), where the real `cursor` lives on this host: tests must point `MIN_CURSOR_EDITOR_BIN` (and every
  other `*_BIN`) at an absolute stub path, never a bare name. Bare `open`,
  `osascript`, `zed`, `code`, `cursor` and `windsurf` on the test
  PATH are `tests/stubs/tripwire` (stubs live in `$T/stub-bin`), and any
  tripwire line fails the case. A mutation check never removes or bypasses a
  stub or the tripwire; skip any that could launch a real app.
- ssh runs the ProxyCommand via `$SHELL -c "exec ..."` and expands `%`
  tokens: every word goes through `shq` and the whole string through `pct`.
- Cursor ships its own Remote-SSH, `anysphere.remote-ssh` (1.1.16 with
  Cursor 3.23.12), not Microsoft's. It reads `remote.SSH.remotePlatform` and
  `remote.SSH.serverInstallPath` by exact host (no wildcards), has no
  `remote.SSH.useLocalServer`, detects the platform itself and prompts only
  after a failed install.
- Cursor's server: `~/.cursor-server/bin/linux-<x64|arm64>/<commit>/`
  (`bin/cursor-server`), no separate CLI; installer lock
  `cursor-remote-lock.<md5>` in `$XDG_RUNTIME_DIR` or `/tmp`. Download:
  `downloads.cursor.com/production/<realCommit>/…/cursor-reh-linux-<arch>.tar.gz`
  (realCommit from `product.json`, may differ from `cursor --version`'s last
  character), fallback `cursor.blob.core.windows.net/remote-releases/<commit>/vscode-reh-linux-<arch>.tar.gz`.
  Read from the extension, not yet from a box.
- The box is uid 1000 with `$HOME=/home`, aarch64, glibc 2.44, has bash, tar,
  curl, python3, zsh; `sshd` at `/usr/sbin/sshd`.
- sshd scrubs the environment: PREP writes `~/.ssh/environment` (filtering
  `PROMPT_COMMAND`, the attach shell's banner trigger) and sshd runs with
  `PermitUserEnvironment=yes`. `MINIMAL_MOTD` is kept: the `min:motd` rc line
  prints it in the first interactive shell that has `SSH_CONNECTION` and
  whose stdout is a TTY, then unsets it (a non-TTY probe leaves it set). A
  `min session attach` shell sources `~/.bashrc`/`~/.zshrc` too, without
  `SSH_CONNECTION`; there minimald's own `PROMPT_COMMAND` prints the banner
  with the real detach chord. Both writers replace a `min:motd` line that
  differs.
- In the box, the host key and `authorized_keys` live in `~/.ssh/min-cursor/`.
- Without a terminal, `min session destroy` refuses a box with unsaved
  changes ("refusing to destroy the session without confirmation; pass
  --force").

## Working here

- Verify: `just check`.
- Tests never touch the real min, Cursor, `~/.ssh` or settings: stubs first
  on a private PATH, `HOME`, `MIN_CURSOR_STATE_DIR` and
  `MIN_CURSOR_SETTINGS` in a tempdir.
- Don't create, attach or destroy min sessions, or `min session exec` into
  one, without asking. Don't run `ssh-config`, `config`, `_proxy`,
  `just install`/`uninstall` against the real HOME; use `HOME=<scratch>`
  `XDG_CONFIG_HOME=<scratch>` and a stub `MIN_BIN`.

## Unverified (needs a live session)

- **New Empty Box** (`min session activate --sync none` on an empty dir).
- The unsaved-changes modal's detail and the `--force` destroy after it.
- The folder picker from a remote window starts on the Mac.
- Destroying the box a window is on closes that remote connection.
- GPG forwarding's `accept-new` cleanup ssh; the `remotePlatform` entry is
  used.
- The `min:motd` banner shows once in a Cursor terminal over real sshd, and
  Cursor's shell-env probe leaves `MINIMAL_MOTD` for it.
- The **Run on** rows `docs/cursor.md` describes for a box's remote workspace:
  read from the Cursor 3.27.22 bundle, never seen on screen. Its My Machines
  worker row was seen and run on 2026-11-06.
