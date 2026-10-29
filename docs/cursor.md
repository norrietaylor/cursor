# Cursor guide

min-cursor turns a Minimal session into a Remote-SSH host named
`min-cursor.NAME` and opens Cursor on `/workbench` in it. Everything Cursor
does after that (installing its server in the box, terminals, extensions,
port forwarding, its agent) is the behaviour of Cursor's own Remote-SSH
extension.

## Requirements

- Cursor with the `cursor` shell command (Command Palette, "Shell Command:
  Install 'cursor' command in PATH").
- Cursor's own Remote-SSH extension, `anysphere.remote-ssh` (bundled with
  current Cursor; `cursor --install-extension anysphere.remote-ssh`).
  Microsoft's `ms-vscode-remote.remote-ssh` does not run in Cursor and is not
  what min-cursor checks for.
- `min-cursor ssh-config` installed (`just install` does it): Cursor's ssh
  reads `~/.ssh/config`, which then includes `~/.ssh/min-cursor.conf`.
- The box: glibc ≥ 2.28 (older needs Cursor's `linux-legacy` server), bash,
  tar, curl (all present; checked 2026-10-02).

`min-cursor doctor` checks each of these.

## Opening a session

| Command | Session | Window |
|---|---|---|
| `min-cursor open [PATH]` | the live session for PATH if there is one, else a new one | yes |
| `min-cursor open PATH -n NAME` | NAME if it exists (for PATH), else a new one named NAME | yes |
| `min-cursor new [PATH]` | always a new one | yes |
| `min-cursor attach [NAME]` | an existing one (no NAME: a numbered picker) | yes |

New sessions are activated with `--loadout cursor`. Each command prepares
the box (pins its host key, pushes the public key, refreshes the stanza),
refreshes the settings block, then runs:

    cursor --remote ssh-remote+min-cursor.NAME /workbench

The command prints `min-cursor.NAME`, so `ssh "$(min-cursor open)"` works too.

Recent folders and the Remote Explorer reconnect the same way: every
connection goes through `min-cursor _proxy NAME`, which prepares the box
again first, so a session recreated under the same name heals itself.

## How Cursor's Remote-SSH differs from VS Code's

Read from `anysphere.remote-ssh` 1.1.16 (Cursor 3.23.12) on 2026-10-16:

- **Same setting names, fewer of them.** It reads `remote.SSH.remotePlatform`
  and `remote.SSH.serverInstallPath` under the same keys as Microsoft's
  extension, both looked up by the exact host name (no wildcard keys). It has
  **no `remote.SSH.useLocalServer`**; min-cursor does not write one.
- **Platform detection.** With no `remotePlatform` entry Cursor runs its
  installer and detects the platform with `uname`; it asks only when that
  install fails. The per-session entry skips the guess and the fallback
  prompt.
- **No exec server, no separate CLI.** One server per commit, at
  `~/.cursor-server/bin/linux-<arch>/<commit>/` (arch `x64` or `arm64`),
  started from `bin/cursor-server`; data and extensions in
  `~/.cursor-server/`. 2026-10-02 (Cursor 3.21) put 442 MB there.
- **One ssh per window,** `ssh -T -D <port> min-cursor.NAME` (or `-L` to a
  socket with `remote.SSH.remoteServerListenOnSocket`), with
  `-o RemoteCommand=none` unless `remote.SSH.enableRemoteCommand` is on.
- **Agent forwarding.** `remote.SSH.enableAgentForwarding` (default on) only
  fixes up the box environment when ssh actually forwards the agent; the
  stanza says `ForwardAgent no`, and the box's sshd refuses it anyway.
- **GPG forwarding** (`remote.SSH.enableGPGAgentForwarding`, default off)
  runs a cleanup ssh with `-o StrictHostKeyChecking=accept-new`. The key is
  already pinned in the stanza's `UserKnownHostsFile`, so a changed key is
  still refused; leave it off unless you need it.
- **Installer lock** `cursor-remote-lock.<md5 of the server dir>` in
  `$XDG_RUNTIME_DIR` or `/tmp`, with a heartbeat; the commit directory is
  created before the lock is taken.

## Settings (`min-cursor config`)

min-cursor keeps one `remote.SSH.remotePlatform` entry per session in
Cursor's user settings:

```jsonc
{
  // min-cursor:begin (managed by `min-cursor config`; `min-cursor config --remove` removes it)
  "remote.SSH.remotePlatform": {
    "min-cursor.myproject-3f9c": "linux"
  }
  // min-cursor:end
  ...your settings...
}
```

- Entries are added by `open`, `attach` and `ssh`, and dropped by
  `destroy`, `gc` and any later refresh once min no longer lists the session.
- If you already have `remote.SSH.remotePlatform` (Cursor writes it when you
  pick a platform for any host), only that object's value is rewritten,
  keeping every host that does not start with `min-cursor.`; there is then no
  marked block. That object comes back re-indented as plain JSON (comments
  inside it are lost); everything else in the file keeps its bytes.
- `--remove` restores the file byte for byte when the block was ours: the
  original framing after `{` (the end marker says `(joined)` when it had to
  add a line break), CRLF line endings and a UTF-8 BOM are all kept.
- When `min ls` fails, `config` leaves the existing `min-cursor.*` entries
  as they are (a partial list would prune live ones), and doctor says it
  could not check them.
- `remote.SSH.serverInstallPath` is left alone: the server goes to
  `/home/.cursor-server`, which persists with the session.
- Before each write the old file is copied to
  `~/.local/state/min-cursor/backups/settings.json.<time>`. A symlinked
  settings.json is written through.
- `min-cursor config --print` shows the result without writing;
  `min-cursor config --remove` takes everything out (and deletes the file if
  min-cursor created it and it is empty again).

The file is `~/Library/Application Support/Cursor/User/settings.json`, or
`MIN_CURSOR_SETTINGS`.

## Troubleshooting

- **Cursor asks for the platform.** Its install failed first; see the
  Remote-SSH output panel. `min-cursor config` (once) adds the entry so the
  retry does not ask. `min-cursor doctor` shows missing or stale entries.
- **"Could not establish connection".** `min-cursor doctor`, then
  `ssh -v min-cursor.NAME true`, then `~/.local/state/min-cursor/proxy.log`
  (one line per connection attempt). The Remote-SSH output panel shows the
  ProxyCommand's stderr.
- **"no min-cursor ssh stanza for this min-cursor.\* host".** The session is
  gone, or was never prepared by min-cursor: `min-cursor status`, then
  `min-cursor attach NAME`.
- **Host key changed after recreating a session.** Reconnect: `_proxy`
  re-pins before sshd starts.
- **Window opens but the terminal is in `/home`.** The `min:workbench` rc
  line moves interactive shells that start in `$HOME`; sessions without the
  loadout get it on the next connect.
