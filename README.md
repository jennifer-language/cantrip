# Cantrip

Turn a Markdown file into a self-contained HTML slideshow **and** a PDF.
Written in [Jennifer](https://jennifer-lang.dev/).

> **A cantrip is a small spell** - a charm, a conjuring trick, a piece of
> mischief worked in a moment. The word is Scots, written down from the early
> eighteenth century, and its origin is unknown. Burns was fond of it: in *Tam
> o' Shanter* the corpses in Alloway kirk hold candles "by some devilish cantrip
> slight", and in *Address to the Deil* the best tool in the house is "instant
> made no worth a louse" by cantrip wit.
>
> Tabletop games later took the word for the smallest spells, the ones you cast
> at will and never have to ration. That is the sense meant here. This one only
> makes slides.

```sh
cantrip build talk.md
# wrote talk.html (10 slide(s))
# wrote talk.pdf (10 slide(s))
```

The input is ordinary Markdown: slides separated by a line of three dashes,
optional front matter at the top, speaker notes in HTML comments. Nothing else
is invented, so the file still reads as a document, renders on any forge, and
diffs like prose.

```markdown
---
title: Cantrip
author: mplx
theme: midnight
ratio: 16:9
---

# One Markdown file in

Two artifacts out.

<!-- notes: what to say here, and what to skip -->

---

## The slideshow

- one file, nothing fetched at view time
- keyboard navigation, overview, presenter notes
- opens over `file://` as readily as from a web root
```

## What you get

**The HTML** is one file. The stylesheet and the navigation script are inlined
and nothing is loaded from a network, so a deck works on a conference laptop
with no connection. Keyboard navigation, a slide overview, a presenter-notes
panel, a progress bar, slide transitions, the current slide in the URL fragment, and a print
stylesheet so the browser's own print dialog produces slides.

**The PDF** is one page per slide at the deck's own aspect ratio, so a viewer
shows it full-bleed rather than re-fitting a portrait document. It carries the
deck's metadata, a bookmark outline from the headings, and a running footer.
The page stays white whatever the screen theme is, because this is the artifact
that gets printed - so a dark deck still gives a legible handout.

## Install

```sh
jvc app install https://github.com/jennifer-language/cantrip
```

Needs the Jennifer interpreter, 0.25.0 or newer (until 0.25.0 is released,
a development build from its `main` branch). There are no third-party
dependencies: everything it imports ships with the interpreter, and it needs no
`net`, `exec`, or `sql` capability, so it runs on `jennifer-tiny` too.

From a checkout, no build step is needed:

```sh
git clone https://github.com/jennifer-language/cantrip
cd cantrip
./bin/cantrip build examples/sample.md
```

## Commands

| Verb | Does |
| ---- | ---- |
| `build` | both outputs, from one parse |
| `html` | the slideshow only |
| `pdf` | the printable deck only |
| `info` | report the deck's shape, writing nothing |
| `themes` | list the themes and ratios |

```sh
cantrip html talk.md --no-notes -o public/talk.html   # for the attendees
cantrip pdf  talk.md --notes -o talk-presenter.pdf    # for you
cantrip build talk.md --theme contrast --ratio 4:3    # for a bad projector
cantrip info talk.md                                  # what is in there
```

`cantrip --help` lists every flag, and `cantrip themes` every theme. There are
24 of them: Cantrip's own `plain`, `midnight`, `solar`, and `contrast`, plus all
ten [Grimoire](https://grimoire.jennifer-lang.dev/) themes under their own names,
each light and `-dark` - so a talk can match the manual beside it. Three ratios
(`16:9`, `16:10`, `4:3`), and four slide transitions (`fade`, `slide`, `zoom`,
`none`).

## Documentation

Published at **<https://jennifer-language.github.io/cantrip/>**. The pages in `docs/` are
a [Grimoire](https://grimoire.jennifer-lang.dev/) book, built with
`grimoire build --config grimoire.toml`.

| | |
| - | - |
| [Introduction](docs/index.md) | what it does, in one page |
| [Installation](docs/installation.md) | `jvc`, scopes, versions, or a plain checkout |
| [The slide format](docs/format.md) | front matter, separators, notes, supported Markdown |
| [The command line](docs/usage.md) | every verb and flag, and the exit codes |
| [Themes, ratios, and transitions](docs/themes.md) | the themes, Grimoire's included, and how the PDF differs |
| [Working on Cantrip](docs/development.md) | the layout, the gate, the release process |

`examples/sample.md` is a worked deck that documents the format by being it.

## Tests

```sh
./scripts/check.sh
```

That is the whole gate: formatting, lint, doc coverage and drift, the rule that
every module has a test overlay, every overlay, and a real build of the example
deck whose outputs are checked for their magic bytes. CI runs the same script.

```sh
for t in src/*_test.j; do jennifer test "$t"; done
jennifer lint src/*.j scripts/*.j bin/cantrip
```

Every module in `src/` has a co-located `*_test.j` white-box overlay. The
launcher is a thin adapter; all the logic, and all the tests, live in `src/`.

## License

LGPL-3.0-only. Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.
