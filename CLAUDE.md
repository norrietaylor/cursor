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
| client layer | `open`/`new`/`attach` (session, stanza, settings, `cursor --remote` unless `--no-window`; `new --empty`), `destroy` (`--if-idle`), `gc`, `status` (`--json`), `doctor`, `completions`, `config`, `setup`, hidden `_sessions`; hooks `client_on_connect` and `client_on_destroy` (settings sync) |
| `bin/min-cursor-config` | python3: marked-block merge of per-host `remote.SSH.remotePlatform` (the only key; Cursor has no `useLocalServer`) into Cursor's user settings.json; `--install`, `--sync NAME...`, `--remove`, `--doctor`, `--dry-run` |
| `loadouts/cursor.toml`, `loadouts/cursor/` | `openssh curl rsync xxhash git`; sshd env prep; `min:workbench` rc line; a patch copying `cursor/skills/minimal-sandbox` to `~/.cursor/skills` in the box. `setup` copies `cursor/` beside the linked toml: `$LOADOUT_ROOT` must be a real directory |
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
  `open`/`attach`/`ssh`/`_proxy`, so a recreated session self-heals.
  `_proxy` always runs `prepare` and writes nothing to stdout before `exec`
  (stdout is the SSH byte stream). `_proxy` and `prepare` never call client
  hooks, never touch settings.json.
- `ssh-config` is an opt-in gate: nothing under `~/.ssh` is touched until it
  has run. `ssh-config --remove` leaves `~/.ssh/config` byte-identical to
  before install; `--print` writes nothing. Other tools' Include lines are
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
  ProxyCommand `ssh` builds.
- `gc` and `destroy` never destroy without an explicit y; `-y` is the only
  way past `destroy`'s question.
- `gc` offers only own sessions (`own_ls`: a key dir `STATE/sessions/NAME`),
  and `gc`/`status` date only those in `orphan/` (`track_orphans`, each run);
  boxes made by `min` alone are never listed. The same holds wherever a
  session is chosen for the user: `open`'s reuse of a live session for PATH,
  `destroy`'s cwd lookup, the `attach` picker and `_sessions` (completions).
  Only an explicit NAME (`attach NAME`, `destroy NAME`, `open -n NAME`) may
  reach another tool's box.
- In use = some host process runs `min session exec NAME ... sshd` (any ssh
  client's connection). Never contact a box without such a live process: a
  connect starts a stopped box.
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
  `PROMPT_COMMAND`/`MINIMAL_MOTD`) and sshd runs with `PermitUserEnvironment=yes`.
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
