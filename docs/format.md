# The slide format

A deck is a Markdown file. The format adds three things to it and nothing else:
front matter, a slide separator, and speaker notes. Each is chosen so that
another Markdown renderer reading the same file produces something sensible
rather than something broken.

## Slides are separated by three dashes

A line holding nothing but three or more dashes ends one slide and begins the
next:

```markdown
# First slide

Some prose.

---

# Second slide

More prose.
```

Leading and trailing spaces on the separator are ignored. A run of separators,
or one at the end of the file, produces no blank slides - a chunk with no text
in it is dropped.

`***` and `___` are **not** separators, even though Markdown treats all three
as a thematic break. Only dashes split a deck, so you keep `***` for an actual
horizontal rule inside a slide.

> [!IMPORTANT]
> A separator inside a fenced code block is content. A slide that shows YAML,
> front matter, or any other `---` in a code fence stays in one piece. Fences
> are tracked properly, so a longer fence may contain a shorter one.

## Front matter describes the deck

If the **very first line** of the file is `---`, everything up to the next `---`
is front matter: one `name: value` pair per line.

```markdown
---
title: Cantrip
author: mplx
date: 2026-10-10
theme: midnight
ratio: 16:9
subject: A worked example deck
keywords: jennifer, slides, markdown
lang: en
---

# The first slide
```

Because the block is only recognised on line 1, a deck whose first slide opens
with a thematic break is never mistaken for one. An unterminated block is
treated as no front matter at all, so a stray `---` at the top of a file cannot
swallow the deck.

| Key | Used for | Default |
| --- | -------- | ------- |
| `title` | the HTML `<title>`, the PDF title, the PDF footer | the first slide's heading |
| `author` | an HTML `author` meta tag, the PDF author | none |
| `date` | an HTML `date` meta tag | none |
| `theme` | which [theme](themes.md) to render with | `plain` |
| `ratio` | which [aspect ratio](themes.md#ratios) to lay out on | `16:9` |
| `description` | the HTML `description` meta tag, what a search engine shows | the `subject` |
| `subject` | the PDF subject, and the HTML description when there is no `description` | none |
| `keywords` | the PDF keywords and the HTML `keywords` meta tag | none |
| `transition` | which [slide transition](themes.md#transitions) the HTML uses | `fade` |
| `lang` | the HTML `lang` attribute | `en` |
| `notes` | whether the HTML's speaker-notes panel is `open` or `closed` when the page opens | `closed` |
| `slide` | the slide the HTML opens on, from 1 | `1` |
| `overview` | whether the HTML opens in the slide overview, `open` or `closed` | `closed` |

Values may be quoted or bare: `title: "A Deck"` and `title: A Deck` agree. A
value keeps its internal colons, so `ratio: 16:9` reads correctly. Keys are
matched case-insensitively. A line with no colon, and a line starting with `#`,
is skipped, so you can comment inside the block.

Any other key is kept and ignored, which means a deck can carry metadata for
some other tool without upsetting this one.

`--theme`, `--ratio`, and `--transition` on the command line override the file. The file
overrides the built-in default.

### How the slideshow opens

`notes`, `slide` and `overview` set the state the HTML opens in. Three
sources set them, and a later one wins:

1. the front matter: `notes: open`, `slide: 3`, `overview: open`;
2. the command line: `--notes-panel open|closed`, `--start-slide N`,
   `--overview open|closed` on `build` or `html`;
3. the page's URL when it is viewed: `?notes=1` or `?notes=0`,
   `?overview=1` or `?overview=0`, and the slide fragment `#3`.

Values are checked strictly where the author sets them: anything but `open` or
`closed`, a slide number that is not a whole number from 1, or a slide past the
end of the deck fails the build (a bad flag value is exit code `2`, a bad
front-matter value `1`). `notes: open` in a page built with `--no-notes` fails
too, with "notes: open needs the notes". In the URL, which is the viewer's
input, an unknown value is ignored and the built-in start applies.

The notes panel takes the bottom 30% of the window; while it is open, the
slide is scaled into the space above it, so the panel never covers it. On a
window narrower than 800 pixels or lower than 560 (a phone), there is no room
for both, so the page starts with the notes closed even when the deck says
`open`; <kbd>s</kbd> opens them, and `?notes=1` in the URL opens them at
start anyway. <kbd>s</kbd> toggles the panel in every case.

## Speaker notes live in a comment

```markdown
## The slide the audience sees

- a point
- another point

<!-- notes: what to say here, and what to skip -->
```

The comment is lifted out of the slide, so it never appears in the slide body.
Any other Markdown renderer treats it as a comment and shows nothing, which is
the reason for this syntax rather than a marker of its own.

A note may span lines, and a slide may carry several - they join in source
order, separated by a blank line:

```markdown
<!-- notes:
Open with why this exists.
Keep it to about twenty seconds.
-->
```

Notes reach the two outputs differently, and that asymmetry is deliberate:

- In the **HTML** they are embedded but hidden; <kbd>s</kbd> opens the presenter
  panel. `--no-notes` leaves them out of the file entirely, which is what you
  want for the copy you publish.
- In the **PDF** they are omitted by default, because the PDF is the audience's
  copy. `--notes` appends each slide's notes to its page as a quoted block,
  giving you the presenter's copy.

An unterminated `<!-- notes:` is left in the body rather than discarded: losing
the rest of a slide is the worse failure.

The comment is only a note in prose. Inside a fenced code block or an inline
code span it is content, so a slide can show the syntax - as this page does -
without the example being lifted out of it. Blank lines and trailing spaces
inside a fenced block are kept as written, too.

## What Markdown is supported

Rendering goes through the interpreter's own
[`markdown`](https://docs.jennifer-lang.dev/modules/markdown.html) module, a
deliberately small CommonMark subset plus the GFM extensions that earn their
place on a slide.

| Block | Syntax |
| ----- | ------ |
| Headings | `# H` through `###### H` |
| Lists | `- x`, `1. x`, nested by indentation |
| Task lists | `- [ ] todo`, `- [x] done` |
| Definition lists | a term, then `: definition` |
| Blockquotes | `> x`, nesting |
| Callouts | `> [!NOTE]`, `TIP`, `IMPORTANT`, `WARNING`, `CAUTION` |
| Fenced code | ` ```jennifer ` ... ` ``` ` |
| Tables | GFM pipe tables, with per-column alignment |
| Thematic break | `***` or `___` (`---` separates slides) |

| Inline | Syntax |
| ------ | ------ |
| Emphasis | `**bold**`, `*italic*`, `` `code` `` |
| Strikethrough | `~~text~~` |
| Highlight | `==text==` |
| Sub and superscript | `~x~`, `^x^` |
| Links | `[text](url)`, autolinks `<https://x>` |
| Images | `![alt](url)` |
| Attribute lists | `## Title {#anchor .class}` |
| Key caps | `<kbd>Esc</kbd>` |

Reference links (`[text][ref]`) work when the `[ref]: url` definition is on
the same slide. A setext heading works with an `===` underline only, since a
`---` underline is a slide separator. Not supported: bare unbracketed URLs in
prose. For anything beyond the subset, pre-render it.

The PDF is drawn in the standard PDF fonts, which cover Western European
text (Windows-1252). Any other character, such as Greek, Cyrillic, CJK, or an
emoji, prints as `?` on the page, in the running footer too; the PDF's
metadata and bookmarks keep it as written. The HTML shows every character.

### A fenced block's language survives

```markdown
    ```jennifer
    io.printf("hello\n");
    ```
```

becomes `<pre><code class="language-jennifer">`, so a syntax highlighter you add
yourself has something to match on. `cantrip` ships no highlighter and loads
nothing from a CDN.

## Images

`![alt](fig.png)` works in both outputs, with one difference worth knowing.

In the **HTML** the `src` is written as it is, so a relative path has to be
valid relative to wherever you serve or open the HTML from. Only a relative
path or an `http`, `https`, or `mailto` URL is kept; any other scheme
(`javascript:`, `data:`, ...) becomes `#`, for images and links alike.

In the **PDF** the picture has to be read off disk, and `cantrip` resolves its
path against the directory the deck came from (the first file's, for a deck of
several files), never against the working directory. So `![x](img/a.png)`
works from wherever you run `cantrip`.

A picture is read only from the deck's directory or below it. An absolute
path, a path whose `..` steps lead out of the directory, and a symlink that
points out of it are refused, and so is anything that is not a regular file.
A deck from somebody else therefore cannot pull another file on your machine
into the PDF it builds. Keep a deck's pictures beside it or in a folder under
it.

A refused picture, a picture it cannot find, and any `http://`, `https://`,
`data:` or `//` URL fall back to the image's alt text in square brackets - a
missing picture should not cost you the deck. `--verbose` names each one it
skipped, and why.

Only a paragraph that is a single image is drawn into the PDF. An image inline
in a sentence, in a list item, in a quote, or in a table cell keeps the `[alt]`
fallback.

## Raw HTML is escaped

Raw HTML in the source renders as visible text, not markup. That is the right
default for a tool that may be pointed at a deck somebody else wrote: it closes
the obvious injection route. For your own deck, `--raw-html` opts back into
verbatim passthrough in the HTML output, for block HTML such as a `<div>` on
lines of its own and for inline tags inside a paragraph alike. Speaker notes
stay escaped either way. The PDF renderer has no HTML at all.

The one exception is the key cap. `<kbd>Esc</kbd>` renders as a key in the
slideshow and as the key's name in the PDF, with or without `--raw-html`.
Without `--raw-html` only the bare tag is recognised - one with attributes stays
text - and inside a code span or a fenced block it stays as written, so you can
still show it as code.

## The slideshow's own names

Every id and class the slideshow itself uses starts with `cantrip-`
(`#cantrip-deck`, `.cantrip-slide`, `#cantrip-overview`, ...), and its
stylesheet and script look for them only where they put them. An attribute
list on a heading, `## Help {#help .slide}` or even `{#cantrip-help}`, styles
that heading and nothing else; the overview, help, and notes keep working.

## Several files, one deck

```sh
cantrip build intro.md middle.md outro.md
```

The files are read in order and their slides concatenated, numbered straight
through. The **first** file's front matter describes the deck; later files
contribute only slides. Outputs are named after the first file unless `--out`
says otherwise.

## Size limits

A deck file may be at most 2 MiB, and a deck at most 2,000 slides, counted
across all its files. Either limit is checked before the slides are parsed, and
a deck over one is refused with exit code `1` and a message naming the limit.
A 2,000-slide deck is about 270 KB of Markdown, so neither limit is close to a
real talk; they keep a runaway or hostile file from taking minutes and
gigabytes to lay out.

## Page breaks

One slide is one PDF page. A slide with more content than fits continues onto a
second page and `cantrip` warns:

```text
cantrip: warning: 10 slide(s) took 11 pages; 1 extra page(s) mean at least one slide overflowed
```

That is a prompt to split the slide, not an error - the PDF is still correct and
complete. The count comes from the PDF that was written, so a slide pushed over
by a tall picture is caught too. Warnings and errors go to stderr, so they still
show when you redirect the `wrote ...` lines.

A level-1 heading (`#`) below other content on a slide also starts a new PDF
page, because the PDF layout opens a page for every top-level heading. Keep a
slide to one `#` heading, at its top, and use `##` and below for the rest.
