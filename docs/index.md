# Cantrip

`cantrip` turns a Markdown file into two things: a self-contained HTML
slideshow you present from a browser, and a PDF you hand out or print.

```sh
cantrip build talk.md
# wrote talk.html (10 slide(s))
# wrote talk.pdf (10 slide(s))
```

The input is ordinary Markdown. Slides are separated by a line of three
dashes, optional front matter at the top names the deck, and speaker notes
live in HTML comments. Nothing else is invented, so the file still reads as a
document in any editor, renders on any forge, and diffs like prose in version
control.

## What you get

**The HTML** is one file. The stylesheet and the navigation script are inlined
and nothing is fetched at view time, so a deck opens over `file://`, from a web
root, or from a subdirectory, and works the same on a conference laptop with no
network. It has keyboard navigation, a slide overview, a presenter-notes panel,
a progress bar, and a print stylesheet so the browser's own print dialog
produces slides rather than a wall of text.

**The PDF** is one page per slide at the deck's own aspect ratio, so a viewer
shows it full-bleed instead of re-fitting a portrait document. It carries the
deck's metadata, a bookmark outline built from the headings, and a running
footer. The page itself stays white whatever the screen theme is, because this
is the artifact that gets printed; a slide that outgrows its page continues onto
the next, and the tool says so rather than letting you find out on a projector.

## What it is built on

`cantrip` is written in [Jennifer](https://jennifer-lang.dev/) and leans on
the interpreter's own modules rather than reimplementing them: `markdown` parses
the source and lays out the PDF, `pdf` writes it, `html` escapes the markup, and
`args` reads the command line. The parts that are this project's own are the
slide format, the themes, the slideshow, and the page geometry.

> [!NOTE]
> This is an **app**, not a deck. A Jennifer module's top level is
> declarations-only, so a deck can never be run; an app owns an entry script and
> installs onto your `PATH`. See [Installation](installation.md).

## See one

`examples/sample.md` is a worked deck that documents the format by being it.
The published copy is built from that file on every push:

- [the slideshow](https://jennifer-language.github.io/cantrip/sample.html) - press
  <kbd>?</kbd> for the shortcuts, <kbd>o</kbd> for the overview
- [the PDF](https://jennifer-language.github.io/cantrip/sample.pdf)

## Where to go next

| | |
| - | - |
| [Installation](installation.md) | installing with `jvc`, or running from a checkout |
| [The slide format](format.md) | front matter, separators, notes, and what Markdown is supported |
| [The command line](usage.md) | every verb and flag |
| [Themes, ratios, and transitions](themes.md) | the themes, Grimoire's included, the ratios, the slide transitions, and how the PDF differs |
| [Working on Cantrip](development.md) | the source layout, the gate, and the release process |

## License

LGPL-3.0-only. Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.
