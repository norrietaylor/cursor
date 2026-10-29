# Troubleshooting

Start with `min-cursor doctor`. It checks `min`, the `cursor` CLI and its
commit, Cursor's Remote-SSH extension (`anysphere.remote-ssh`),
`jq`/`python3`/`ssh`, the `cursor` loadout, the state dir, the ssh Include and that `ssh -G min-cursor.NAME`
routes through `_proxy` and the settings block, and prints a one-line fix for each problem.
`min-cursor status` lists sessions, whether something is connected, and how
long each has been idle.

- **`openssh is not installed in this session`.** The session was activated
  without a loadout carrying openssh. `min-cursor open` activates with
  `--loadout cursor`; for a session made by `min` directly, re-activate it
  with `--loadout cursor`.
- **Connection problems.** `min-cursor ssh NAME -- -v` runs plain ssh over
  the same transport and prints the negotiation;
  `~/.local/state/min-cursor/proxy.log` has one line per connection attempt:
  `ok`, or `fail: no session named NAME`, `fail: prepare` (the box's facts
  could not be fetched, were invalid or could not be written) or
  `fail: invalid home|sshd in PATH` (a stored fact no longer valid; the next
  `min-cursor attach NAME` rewrites it).
  ssh runs the ProxyCommand under `$SHELL -c`: nushell and xonsh users
  should give Cursor a POSIX `SHELL`.
- **An earlier `Host`/`Match` block shadows the stanza.** doctor says so;
  keep the min-cursor Include at the top of `~/.ssh/config`.
- **`min-cursor-config: the // min-cursor:begin block holds keys of its
  own`.** Something added a setting inside the marked block. Move it below
  `// min-cursor:end`, then run `min-cursor config` again.

Cursor specifics (platform prompt):
[cursor.md](cursor.md#troubleshooting).
