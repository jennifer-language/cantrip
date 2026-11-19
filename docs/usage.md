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
| `handout` | three slides to an A4 portrait page, with room for notes | `<input>-handout.pdf` |
| `highlight` | source files as highlighted HTML, for code shown outside a deck | standard output, or `<dir>/<file>.html` |
| `info` | report the deck's shape | nothing |
| `themes` | list the themes, ratios, and transitions | nothing |

```sh
cantrip build talk.md              # talk.html and talk.pdf
cantrip html talk.md               # talk.html
cantrip pdf talk.md --notes        # talk.pdf, presenter's copy
cantrip handout talk.md            # talk-handout.pdf, to print
cantrip highlight app.j            # app.j as highlighted HTML
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

### The handout

`handout` prints the same slides as `pdf`, three to an A4 portrait page, for
the audience to take home or write on. Each slide keeps its own text and
pictures, scaled down, with a thin frame and its number under it; where the
slide leaves room on the right, light ruled lines give space for notes. The
deck's title heads every page, above its first slide. The footer carries the
`--footer` text, if you give one (a URL to the slides, say), and the page
numbers, whatever `--no-numbers` says. The PDF flags apply as for `pdf`: `--notes` puts the speaker notes on
the slides, `--theme` and `--ratio` change the slides themselves. A slide that
overflows its page in `pdf` overflows in the handout too, and gets the same
warning.

## Options

| Option | Does | Default |
| ------ | ---- | ------- |
| `-o`, `--out PATH` | where to write | beside the input |
| `-t`, `--theme NAME` | override the deck's theme | the deck's, else `plain` |
| `--mode light\|dark` | HTML: the mode the page opens in | the deck's `mode:`, else `light` |
| `-r`, `--ratio NAME` | override the deck's ratio | the deck's, else `16:9` |
| `--transition NAME` | override the deck's HTML slide transition | the deck's, else `fade` |
| `-f`, `--footer TEXT` | text at the foot of every slide | none |
| `--bookmarks N` | PDF outline depth, 0 for none | `2` |
| `-n`, `--notes` | put speaker notes **into** the PDF | off |
| `--no-notes` | leave speaker notes **out of** the HTML | off |
| `--notes-panel open\|closed` | HTML: the speaker-notes panel open or closed when the page opens | the deck's `notes:`, else `closed` |
| `--start-slide N` | HTML: the slide the page opens on, from 1 | the deck's `slide:`, else `1` |
| `--overview open\|closed` | HTML: open in the slide overview | the deck's `overview:`, else `closed` |
| `--no-numbers` | omit slide numbers | off |
| `--raw-html` | pass raw HTML through unescaped | off |
| `-v`, `--verbose` | report byte counts, and each image skipped and why | off |

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

`--notes-panel` is a third, separate thing: whether the HTML's notes panel is
open when the page loads (`--notes` already means "notes in the PDF"). It needs
the notes in the page, so `--no-notes --notes-panel open` is refused with exit
code `1` rather than producing a page whose panel cannot open. See
[How the slideshow opens](format.md#how-the-slideshow-opens).

### Highlighting source files

`highlight` colours source files with the highlighter the slides use, for a
page that shows code beside a deck: a site's listing of a talk's programs, say.
It writes HTML fragments, the file's text escaped and wrapped in highlight.js
class names (`hljs-keyword`, `hljs-string`, ...), ready to go inside
`<pre><code>`; the page brings its own colours for those classes. The language
comes from the file's extension, or for a file without one (a `bin/` launcher)
from its `#!` line; a file in a language the highlighter does not know comes
out as escaped plain text.

```sh
cantrip highlight app.j > app.html          # one file to standard output
cantrip highlight -o out src/app.j bin/run  # out/src/app.j.html and out/bin/run.html
```

With `--out`, each file keeps its path below the directory, so the paths must
be relative and stay below it (`../x.j` is refused). The directory itself must
exist; the ones below it are made.

### What `--out` means

For `html`, `pdf` and `handout` it is the **exact file** to write:

```sh
cantrip html talk.md -o public/index.html
```

For `build` it is the **path without an extension**, since one run writes two
files:

```sh
cantrip build talk.md -o dist/talk    # dist/talk.html and dist/talk.pdf
```

With no `--out`, an output replaces the input's extension and sits beside it:
`slides/talk.md` gives `slides/talk.html`, and the handout
`slides/talk-handout.pdf`.

> [!NOTE]
> `cantrip` writes files but never creates directories. `-o dist/talk` needs
> `dist` to exist.

An output is never written over one of the input files: `-o talk.md` on
`cantrip html talk.md` is refused with exit code `1`, and the deck is left alone.

## Exit codes

| Code | Means |
| ---- | ----- |
| `0` | it worked |
| `1` | it was asked correctly but could not be done - a missing file, an unknown theme, a deck with no slides, a deck over a [size limit](format.md#size-limits) (2 MiB a file, 2,000 slides), an output that would overwrite an input |
| `2` | it was asked incorrectly - no arguments, an unknown verb or flag, a malformed flag value such as `--bookmarks x`, `--notes-panel maybe` or `--start-slide 0`, a verb with no input file |

The split matters in a shell script: a `2` is a bug in your command line, a `1`
is a problem with the deck or its surroundings. `--help` and `--version` exit
`0`. Errors, warnings, and the usage text printed for a misuse go to stderr;
stdout carries only what you asked for - the `wrote ...` lines, `info`,
`themes`, `--help`, and `--version`. Text taken from the deck, such as the
titles `info` lists, the image paths `--verbose` names, or a theme name in an
error, is printed with its control characters escaped (`\x1B`), so a deck
cannot send escape sequences to your terminal.

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
| <kbd>m</kbd> | light / dark mode |
| <kbd>f</kbd> | fullscreen |
| <kbd>?</kbd> | the shortcut list |
| <kbd>Esc</kbd> | close an overlay; with none open, end the presentation: leave fullscreen and go back to the page that opened the slideshow (nothing when it was opened directly). In fullscreen it works the same: Chrome and Edge let the slideshow claim the key (hold it to only leave fullscreen), Firefox and Safari leave fullscreen first and the slideshow then goes back |

On a phone or tablet, swipe left or right to turn the slide, or tap the right
or left third of the screen to go forward or back. A tap on a link follows the
link, a swipe in a code block that is wider than the slide scrolls the code,
and pinching zooms without turning the slide.

A bar of four buttons in the top-right corner stands in for the other keys:
the overview, the speaker notes (left out when the page has none), light /
dark mode, and fullscreen (left out where the browser has none, as on an
iPhone). On any device with a touch screen, a laptop with one included, it
shows when the page opens and fades out after three seconds, so it does not
cover the slide; tap the middle third of the screen to bring it back or hide
it. With only a mouse it never appears.
While the overview is open, the bar stays.

The current slide is in the URL fragment (`talk.html#4`), so a reload keeps your
place and you can link to a slide. `?notes=1` / `?notes=0` and `?overview=1` /
`?overview=0` in the URL open or close the notes panel and the overview when
the page loads (`talk.html?notes=0#4`), and `?mode=light` / `?mode=dark` pick
the mode, whatever the deck was built with. While
the notes panel is open, the slide is scaled into the space above it. The slide scales to the window, so the deck
looks the same on a laptop and a projector.

### Printing from the browser

The print stylesheet lays one slide per page at the deck's own page size, and
hides the progress bar, notes, and overlays. The browser's own print dialog is
therefore a second route to a PDF. The `pdf` verb is the better one - it carries
metadata, bookmarks, and a running footer, and it needs no browser - but the
print route is there when you want the browser's exact rendering.
