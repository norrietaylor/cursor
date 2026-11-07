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
  `ok`, or `fail: no session named NAME`, `fail: no id` (no box id to
  trust: see the box-id entries below), `fail: min ls`, `fail: prepare` (the box's facts
  could not be fetched, were invalid or could not be written) or
  `fail: invalid home|sshd in PATH` (a stored fact no longer valid; the next
  `min-cursor attach NAME` rewrites it).
  ssh runs the ProxyCommand under `$SHELL -c`: nushell and xonsh users
  should give Cursor a POSIX `SHELL`.
- **"several boxes are named NAME, and min-cursor cannot tell which is its
  own".** min 0.8 lets boxes share a name, and NAME's key dir is from
  before min-cursor recorded box ids. min-cursor leaves all of them alone (no
  list row, no stanza, no connect) rather than let min pick the running
  one. `min ls --json` shows their ids: give the others new names (`min
  session rename ID NEW`) and min-cursor takes the one left, or remove
  `~/.local/state/min-cursor/sessions/NAME` to let go of it.
- **"Several boxes are named NAME, and none is min-cursor's."** You named a
  box min-cursor never connected to, and several have that name. Give the
  others new names with `min session rename ID NEW` (`min ls --json` lists
  their ids), then try again.
- **"…/sessions/NAME/id is not a session id".** The file was edited or
  damaged; min-cursor never passes it to min. Write the box's id (from `min
  ls --json`) into it, or, if the box is gone, remove
  `~/.local/state/min-cursor/sessions/NAME`. Removing only the file makes
  min-cursor take whatever one box has the name now, which may not be yours.
- **"your box NAME is gone; another box now has the name".** min-cursor's
  box NAME was destroyed outside min-cursor and another tool (or `min`) made
  a box with the same name. min-cursor never reaches that box under your
  record: `min-cursor destroy NAME` drops what is left of yours; then
  `attach NAME` reaches the other box if you mean to.
- **"NAME was renamed outside min-cursor, to NEW. To use it here again: min
  session rename ID NAME."** (or "min lists box NAME with no name now").
  Run the command it gives (it names your box's id). Or remove
  `~/.local/state/min-cursor/sessions/NAME` to let go of it.
- **An earlier `Host`/`Match` block shadows the stanza.** doctor says so;
  keep the min-cursor Include at the top of `~/.ssh/config`.
- **`min-cursor-config: the // min-cursor:begin block holds keys of its
  own`.** Something added a setting inside the marked block. Move it below
  `// min-cursor:end`, then run `min-cursor config` again.
- **The VM will not start after going from `unstable` to `rc`.** Don't
  downgrade `min` that way: the older daemon cannot read the box index the
  newer one wrote ([minimal#3060](https://github.com/gominimal/minimal/issues/3060)).

Cursor specifics (platform prompt):
[cursor.md](cursor.md#troubleshooting).
