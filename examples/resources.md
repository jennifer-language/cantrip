---
title: Jennifer resources
author: mplx
date: 2026-11
theme: meridian
ratio: 16:9
transition: fade
description: Where to find everything around the Jennifer programming language: the interpreter, jvc, the deck registry, the curated Deckyard community decks, the apps and the demos. Based on Jennifer 0.26.0.
subject: The Jennifer ecosystem: interpreter, tools, decks, apps and demos
keywords: jennifer, programming language, interpreter, jvc, package manager, deck registry, deckyard, grimoire, cantrip, open source
lang: en
---

# Jennifer resources

![Jennifer](jennifer-logo.png)

The interpreter, the tools, the decks, and where each one lives.

Based on **Jennifer 0.26.0**, November 2026.

<!-- notes:
A short tour of everything around the language: what to install, where the
documentation is, how to get extra packages, and which programs already use
it. Every address on these slides is live.
-->

---

## The map

| What | Where |
| --- | --- |
| The language | [jennifer-lang.dev](https://jennifer-lang.dev/) |
| Documentation | [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/) |
| Source and releases | [github.com/jennifer-language](https://github.com/jennifer-language) |
| Decks | [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/) |
| The deck manager | [jvc.jennifer-lang.dev](https://jvc.jennifer-lang.dev/) |
| Community decks | [github.com/deckyard](https://github.com/deckyard) |

<!-- notes:
Six addresses cover it. The website explains the language, the documentation
site holds the guides and the reference for every library and module, and the
source lives on GitHub. Extra packages are called decks: the registry indexes
them, jvc installs them, and Deckyard is where the community ones are kept.
-->

---

## The interpreter

**One static binary:** no runtime, no system libraries, copy it and run it.

Runs on Linux (amd64, arm64), OpenWrt routers (`.ipk`) and Android in Termux;
macOS and Windows builds are best-effort.

Two builds from the same source:

- `jennifer`: the full build, multi-core `spawn`, network, processes, SQL
- `jennifer-tiny`: the TinyGo build, small and embeddable

43 built-in libraries and 80 shipped modules, over 2,300 functions.

```sh
sudo apt install ./jennifer_0.26.0_amd64.deb   # AUR: jennifer-bin
docker run --rm -it ghcr.io/jennifer-language/jennifer repl
```

<!-- notes:
Everything starts with the interpreter, and it is a single file. It needs no
language runtime and no shared system libraries, not even libc, so it runs on
any Linux of its architecture as it is, and in an empty "static" container
image. The same file runs on an OpenWrt router, installed from its .ipk, and on
an Android phone inside Termux, where network name lookups need 0.27.0, which
reads Termux's own resolver configuration. macOS and Windows get the standard
build on every release, unsigned and unsupported but working. The default build is the one to install; the tiny build is for small
systems and for embedding. Both come as
release archives and a .deb, Arch users get it from the AUR, and the container
image carries both builds plus jvc. The standard library is large on purpose:
databases, HTTP, crypto, formats, and the modules are plain Jennifer source
you can read and fork.
-->

---

## jvc: the package & app manager

```sh
jvc add "@deckyard/epub"          # require a deck
jvc install                       # vendor exactly what camcorder.lock pins
jvc app install https://github.com/jennifer-language/grimoire
jvc publish                       # tag, check, and announce your own deck
```

```jennifer
import "@deckyard/epub/" as epub;
```

<!-- notes:
jvc is the package manager. A deck is a library: jvc resolves its version,
writes a lock file and copies its source into the project's vendor directory,
so a build never fetches anything at run time. An app is a runnable program:
`jvc app install` puts its command on your PATH. Publishing is a tag in your
repository plus `jvc publish`; the registry reads the tagged commit itself.
-->

---

## The public package registry

[registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/browse): 65+
decks, searchable, each with its versions, documentation and repository.

| Scope | Who | Examples |
| --- | --- | --- |
| `@jennifer` | the project | `telegram`, `influxdb`, `oauthext`, `mikrotik` |
| `@deckyard` | the curated community | `epub`, `geo`, `sheets`, `proxmox`, `openai` |
| your own | anyone with a repository | claim a scope with `jvc claim` |

<!-- notes:
Every published deck has a page in the registry, and the registry offers a
feed of new and updated decks. Scopes tell you who stands behind a deck: the
project's own decks, the curated community collection, or anybody's personal
scope. Anyone can claim a scope and publish there.
-->

---

## Deckyard: community-based, but curated

A deck joins `@deckyard` only after review, and only while it keeps up:

- a named maintainer who uses what the deck wraps
- tests that run in CI without accounts or network
- documentation checked against the code
- strict input validation, typed errors, a cap and a deadline on every read
- the shared CI layer, so one fix reaches every deck

[github.com/deckyard](https://github.com/deckyard): API clients, file formats,
science, home infrastructure.

<!-- notes:
Deckyard is the community's shelf, but not an open one. The bar is the same
for every deck: someone who actually uses it maintains it, its tests run
offline, its documentation is verified by CI, and anything read from the
outside world is validated and bounded. Because all decks share one CI layer,
a fix to how decks are built and checked lands everywhere at once.
-->

---

## Apps written in Jennifer

| App | What it does |
| --- | --- |
| [grimoire](https://grimoire.jennifer-lang.dev/) | Markdown to a documentation site and a PDF; builds every deck's book |
| [cantrip](https://github.com/jennifer-language/cantrip) | Markdown to slides: an HTML slideshow and a PDF (this deck) |
| [jvc](https://jvc.jennifer-lang.dev/) | the deck manager |
| registry | the deck registry server and its operator tool |
| [ocsaml](https://github.com/mplx/openconnect-saml) | Cisco AnyConnect VPN with SAML / SSO login |

Grimoire plugins: [`grimoire-plugin`](https://github.com/topics/grimoire-plugin) on GitHub.

<!-- notes:
The best evidence that a language works is the tools built with it. Grimoire
builds the documentation of every deck, cantrip made the slides you are
looking at, jvc and the registry run the package ecosystem, and ocsaml gets
people through a corporate VPN. Grimoire takes plugins; user plugins such as
mermaid diagrams and KaTeX maths are tagged grimoire-plugin on GitHub.
-->

---

## Demos

| Demo | What it shows |
| --- | --- |
| [demo-jsnake](https://github.com/jennifer-language/demo-jsnake) | a multiplayer snake game for the Linux console, over UDP and TCP, with CPU opponents |
| [demo-micrograd](https://github.com/jennifer-language/demo-micrograd) | a scalar reverse-mode autodiff engine, built up in five steps |

<!-- notes:
Two demos to read rather than to use. jsnake is a real-time network game in
the terminal: discovery over UDP, play over TCP, opponents that steer
themselves. micrograd builds a small neural-network engine step by step, each
version with its own tests, so you can follow how it grows.
-->

---

## Start here

```sh
jennifer repl                                  # try the language
jvc app install https://github.com/jennifer-language/grimoire
jvc add "@deckyard/geo" && jvc install         # your first deck
```

- Learn: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- Find a deck: [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/)
- Share one: `jvc publish`

<!-- notes:
Three commands get you from nothing to a working setup: the REPL to try the
language, an app to see what it can do, and a deck in a project of your own.
When you have written a deck others could use, publish it under your scope,
and if it meets the Deckyard bar, propose it for the curated collection.
-->
