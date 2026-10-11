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
| `subject` | the PDF subject | none |
| `keywords` | the PDF keywords | none |
| `transition` | which [slide transition](themes.md#transitions) the HTML uses | `fade` |
| `lang` | the HTML `lang` attribute | `en` |

Values may be quoted or bare: `title: "A Deck"` and `title: A Deck` agree. A
value keeps its internal colons, so `ratio: 16:9` reads correctly. Keys are
matched case-insensitively. A line with no colon, and a line starting with `#`,
is skipped, so you can comment inside the block.

Any other key is kept and ignored, which means a deck can carry metadata for
some other tool without upsetting this one.

`--theme`, `--ratio`, and `--transition` on the command line override the file. The file
overrides the built-in default.

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

Not supported: reference links (`[text][ref]`), setext headings, and bare
unbracketed URLs in prose. For anything beyond the subset, pre-render it.

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

In the **HTML** the `src` is written through untouched, so a relative path has
to be valid relative to wherever you serve or open the HTML from.

In the **PDF** the picture has to be read off disk, and `cantrip` looks for it
twice: as written, then relative to the directory the deck came from. So
`![x](img/a.png)` works from any working directory. A picture it cannot find,
and any `http://`, `https://`, `data:` or `//` URL, falls back to the image's
alt text in square brackets - a missing picture should not cost you the deck.
`--verbose` names each one it skipped.

Only a paragraph that is a single image is drawn into the PDF. An image inline
in a sentence, in a list item, in a quote, or in a table cell keeps the `[alt]`
fallback.

## Raw HTML is escaped

Raw HTML in the source renders as visible text, not markup. That is the right
default for a tool that may be pointed at a deck somebody else wrote: it closes
the obvious injection route. For your own deck, `--raw-html` opts back into
verbatim passthrough in the HTML output - for **block** HTML, such as a `<div>`
on lines of its own. Inline tags inside a paragraph stay escaped either way;
that is how the interpreter's Markdown renderer works. The PDF renderer has no
HTML at all.

The one exception is the key cap. `<kbd>Esc</kbd>` renders as a key in the
slideshow and as the key's name in the PDF, with or without `--raw-html`. Only
the bare tag is recognised - one with attributes stays text - and inside a code
span or a fenced block it stays as written, so you can still show it as code.

## Several files, one deck

```sh
cantrip build intro.md middle.md outro.md
```

The files are read in order and their slides concatenated, numbered straight
through. The **first** file's front matter describes the deck; later files
contribute only slides. Outputs are named after the first file unless `--out`
says otherwise.

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
