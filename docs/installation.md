# Installation

## What you need first

The [Jennifer interpreter](https://jennifer-lang.dev/), **0.25.0 or newer**.
Until 0.25.0 is released that means a development build from Jennifer's `main`
branch; the 0.24.0 release lacks library functions `cantrip` calls.
`deck.toml` declares that floor, so `jvc check` will tell you if the
interpreter you have is too old, and every source file carries the same floor
as a `pragma-jennifer-version` header, so an old interpreter stops with a clear
message instead of a missing-function error:

```sh
jennifer version
jvc check
```

`cantrip` runs on both interpreter builds. It needs no `net`, `exec`, or
`sql` capability - its `capabilities` list is empty - so it also runs on
`jennifer-tiny`.

## With jvc

`cantrip` is an **app**: an unscoped name with a runnable entry script, which
`jvc` installs once per user and puts on your `PATH`.

```sh
jvc app install https://github.com/jennifer-language/cantrip
```

```text
installed cantrip 0.1.0
  from:    https://github.com/jennifer-language/cantrip
  app:     ~/.local/share/jvc/apps/cantrip
  command: ~/.local/bin/cantrip
```

The command is a symlink into jvc's own store, so `readlink` shows you what you
are really running and no extra process sits between your shell and the
program. If `~/.local/bin` is not on your `PATH`, jvc says so at install time.

### Choosing a version

Versions are the repository's SemVer tags. Without `--version` you get the
newest:

```sh
jvc app install https://github.com/jennifer-language/cantrip --version "^0.1"
```

### Choosing where it goes

| Scope | Command lands in | For |
| ----- | ---------------- | --- |
| `user` (default) | `~/.local/bin` | just you |
| `system` | `/usr/local/bin` | every user on the machine |
| `project` | `./bin` | a deck pinned to one repository |

```sh
sudo jvc app install https://github.com/jennifer-language/cantrip --scope system
```

`--scope system` checks whether it can write the command directory before doing
any work, and prints the line to re-run rather than trying to elevate itself.

### Keeping it current, and removing it

```sh
jvc app list
jvc app update cantrip
jvc app uninstall cantrip
```

## From a checkout

The launcher runs from any working directory and through any symlink, so a
clone needs no build step:

```sh
git clone https://github.com/jennifer-language/cantrip
cd cantrip
./bin/cantrip build examples/sample.md
```

There are no third-party dependencies to fetch: everything `cantrip` imports
(`markdown`, `pdf`, `html`, `args`, `docblock`) ships with the interpreter, so
`deck.toml` has no `[decks]` table and `jvc install` has nothing to vendor.

## Checking the install

```sh
cantrip --version
cantrip themes
cantrip info examples/sample.md
```

`themes` needs no input file, so it is the quickest proof the command is wired
up correctly.
