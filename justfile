# min-cursor: Minimal sessions as Cursor Remote-SSH hosts. Every recipe runs on the HOST.
# `just --list` for the menu.


_default:
    @just --list

# shellcheck, py_compile, and the test suite (normal and long host prefix).
check:
    #!/bin/sh
    set -eu
    shellcheck -s sh bin/min-cursor tests/run.sh tests/stubs/*
    python3 -m py_compile bin/min-cursor-config
    sh tests/run.sh
    LONG_PREFIX=1 sh tests/run.sh
    if [ -d extension/node_modules ]; then (cd extension && npm run --silent check)
    else echo "extension/node_modules missing: run just ext-deps to type-check the extension" >&2; exit 1; fi

# Install the extension's build tools (TypeScript, vsce) into extension/node_modules.
ext-deps:
    cd extension && npm ci

# Build min-cursor.vsix: the extension plus the bundled CLI, merger and loadout (same layout as the repo).
vsix: ext-deps
    #!/bin/sh
    set -eu
    rm -rf extension/cli extension/out
    mkdir -p extension/cli/bin extension/cli/loadouts
    cp bin/min-cursor bin/min-cursor-config extension/cli/bin/
    chmod 755 extension/cli/bin/*
    cp -R loadouts/cursor.toml loadouts/cursor extension/cli/loadouts/
    cp -R skills extension/cli/skills
    cp LICENSE extension/LICENSE
    cd extension && npm run --silent compile && npm run --silent package

# Link min-cursor into ~/.local/bin, install the `cursor` loadout, write the ssh stanzas, wire Cursor's settings.
install:
    "$PWD/bin/min-cursor" setup

# Minimal's skills for Cursor's agent, vendored from gominimal/minimal-skills (MIT) at a pinned commit
# (version 0.7.0): the host ones in skills/ (setup installs them into ~/.cursor/skills on the Mac),
# minimal-sandbox in loadouts/cursor/skills/ (the loadout copies it into every box).
skills_commit := "d3ccc13ed4286978e2581a30eb3859dcbed59076"
skills_sha256 := "bea8b245fc5e32de55ca4175dfc46c271c3a9ee8befa5d4c276336fc7a8aa993"

# Re-fetch the vendored skills (after changing skills_commit and skills_sha256).
skills:
    #!/bin/sh
    set -eu
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    curl -fsSL "https://codeload.github.com/gominimal/minimal-skills/tar.gz/{{ skills_commit }}" -o "$t/a.tgz"
    got=$(shasum -a 256 "$t/a.tgz" 2>/dev/null || sha256sum "$t/a.tgz"); got=${got%% *}
    [ "$got" = "{{ skills_sha256 }}" ] || { echo "sha256 mismatch: $got" >&2; exit 1; }
    tar -xzf "$t/a.tgz" -C "$t" --strip-components 1
    rm -rf skills loadouts/cursor/skills
    mkdir -p skills loadouts/cursor/skills
    for d in "$t"/skills/*/; do
        d=${d%/}; n=$(basename "$d")   # no trailing slash: BSD cp would copy the contents only
        if [ "$n" = minimal-sandbox ]; then cp -R "$d" loadouts/cursor/skills/; else cp -R "$d" skills/; fi
    done
    cp "$t/LICENSE" skills/LICENSE
    cp "$t/LICENSE" loadouts/cursor/skills/LICENSE
    echo "skills at {{ skills_commit }}: $(ls skills | grep -v LICENSE | tr '\n' ' ')+ minimal-sandbox (box)"

# Write Host min-cursor.NAME stanzas to ~/.ssh/min-cursor.conf and Include them from the top of ~/.ssh/config.
ssh-config:
    "$PWD/bin/min-cursor" ssh-config

# Opt in to the Cursor settings (remote.SSH.remotePlatform per session; Cursor has no useLocalServer) in the user settings.json.
cursor-config:
    "$PWD/bin/min-cursor" config

# Undo `install`, touching only what is ours: settings entries, ssh Include, loadout link and copy, CLI link.
uninstall:
    "$PWD/bin/min-cursor" setup --remove
