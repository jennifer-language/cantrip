# The command line

```text
cantrip <command> [options] [file...]
```

One command with five verbs. `cantrip --help` prints the same list, and
`cantrip --version` prints the version.

## Verbs

| Verb | Does | Writes |
| ---- | ---- | ------ |
| `build` | both outputs, from one parse | `<input>.html` and `<input>.pdf` |
| `html` | the slideshow only | `<input>.html` |
| `pdf` | the printable deck only | `<input>.pdf` |
| `info` | report the deck's shape | nothing |
| `themes` | list the themes and ratios | nothing |

```sh
cantrip build talk.md              # talk.html and talk.pdf
cantrip html talk.md               # talk.html
cantrip pdf talk.md --notes        # talk.pdf, presenter's copy
cantrip info talk.md               # what is in there
cantrip themes                     # what is available
```

`info` is the one to reach for when a deck does not come out the way you
expected - it shows the slide numbering, each slide's heading, and which slides
carry notes, without writing anything:

```text
$ cantrip info examples/sample.md
Cantrip: 12 slide(s), 6 with notes
   1 * Cantrip
   2 * The format is just Markdown
   3   Front matter sets the deck up
   ...
```

A `*` marks a slide with speaker notes. `(no heading)` means the slide has no
heading at all, which is usually a separator in the wrong place.

## Options

| Option | Does | Default |
| ------ | ---- | ------- |
| `-o`, `--out PATH` | where to write | beside the input |
| `-t`, `--theme NAME` | override the deck's theme | the deck's, else `plain` |
| `-r`, `--ratio NAME` | override the deck's ratio | the deck's, else `16:9` |
| `--transition NAME` | override the deck's HTML slide transition | the deck's, else `fade` |
| `-f`, `--footer TEXT` | text at the foot of every slide | none |
| `--bookmarks N` | PDF outline depth, 0 for none | `2` |
| `-n`, `--notes` | put speaker notes **into** the PDF | off |
| `--no-notes` | leave speaker notes **out of** the HTML | off |
| `--no-numbers` | omit slide numbers | off |
| `--raw-html` | pass raw HTML through unescaped | off |
| `-v`, `--verbose` | report byte counts and skipped images | off |

`--flag=value` and `--flag value` both work, short flags bundle (`-nv`), and
`--` ends the options.

### Why notes have two flags

The two outputs start from opposite defaults, because they go to different
people. The HTML is what you present from, so notes are **in** by default and
`--no-notes` takes them out for the copy you publish. The PDF is what the
audience gets, so notes are **out** by default and `--notes` puts them in for
your own copy.

```sh
cantrip html talk.md --no-notes -o public/talk.html   # for the attendees
cantrip pdf  talk.md --notes    -o talk-presenter.pdf # for you
```

### What `--out` means

For `html` and `pdf` it is the **exact file** to write:

```sh
cantrip html talk.md -o public/index.html
```

For `build` it is the **path without an extension**, since one run writes two
files:

```sh
cantrip build talk.md -o dist/talk    # dist/talk.html and dist/talk.pdf
```

With no `--out`, an output replaces the input's extension and sits beside it:
`slides/talk.md` gives `slides/talk.html`.

> [!NOTE]
> `cantrip` writes files but never creates directories. `-o dist/talk` needs
> `dist` to exist.

An output is never written over one of the input files: `-o talk.md` on
`cantrip html talk.md` is refused with exit code `1`, and the deck is left alone.

## Exit codes

| Code | Means |
| ---- | ----- |
| `0` | it worked |
| `1` | it was asked correctly but could not be done - a missing file, an unknown theme, a deck with no slides, an output that would overwrite an input |
| `2` | it was asked incorrectly - no arguments, an unknown verb or flag, a verb with no input file |

The split matters in a shell script: a `2` is a bug in your command line, a `1`
is a problem with the deck or its surroundings. `--help` and `--version` exit
`0`. Errors, warnings, and the usage text printed for a misuse go to stderr;
stdout carries only what you asked for - the `wrote ...` lines, `info`,
`themes`, `--help`, and `--version`.

```sh
cantrip build talk.md || echo "deck did not build" >&2
```

## Presenting the HTML

Open the file. No server is needed, and nothing is fetched.

| Key | Does |
| --- | ---- |
| <kbd>&rarr;</kbd> <kbd>space</kbd> <kbd>PageDown</kbd> <kbd>n</kbd> | next slide |
| <kbd>&larr;</kbd> <kbd>PageUp</kbd> <kbd>p</kbd> | previous slide |
| <kbd>Home</kbd> <kbd>End</kbd> | first / last slide |
| digits then <kbd>Enter</kbd> | jump to a slide |
| <kbd>o</kbd> | slide overview; click, <kbd>Enter</kbd>, or <kbd>space</kbd> to jump |
| <kbd>s</kbd> | speaker-notes panel |
| <kbd>f</kbd> | fullscreen |
| <kbd>?</kbd> | the shortcut list |
| <kbd>Esc</kbd> | close an overlay |

The current slide is in the URL fragment (`talk.html#4`), so a reload keeps your
place and you can link to a slide. The slide scales to the window, so the deck
looks the same on a laptop and a projector.

### Printing from the browser

The print stylesheet lays one slide per page at the deck's own page size, and
hides the progress bar, notes, and overlays. The browser's own print dialog is
therefore a second route to a PDF. The `pdf` verb is the better one - it carries
metadata, bookmarks, and a running footer, and it needs no browser - but the
print route is there when you want the browser's exact rendering.
