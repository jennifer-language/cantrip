# Plugins

A plugin is a program Cantrip runs before it renders a deck. It reads the deck
on standard input as JSON, writes the rewritten Markdown back on standard
output, and can be written in any language. It is how a deck gets diagrams
drawn from text, typeset maths, or anything else Cantrip does not do itself.

Cantrip speaks [Grimoire's plugin contract](https://grimoire.jennifer-lang.dev/plugins.html),
api 1, unchanged. Each file of a deck is a chapter, so a preprocessor written
for Grimoire runs over a deck as it is, and one written for Cantrip runs over a
book. Two that work today:

| | |
| - | - |
| [`grimoire-mermaid`](https://github.com/mplx/grimoire-mermaid) | draws a `mermaid` fence as a picture |
| [`grimoire-katex`](https://github.com/mplx/grimoire-katex) | typesets `` $`...`$ `` and a `math` fence as MathML |

Cantrip runs **preprocessors** only. Grimoire's renderers (a sitemap, an EPUB, a
feed) are about books, and a `[renderer.NAME]` table is refused rather than
ignored.

## Using one

Name it in `cantrip.toml`, beside the deck's first file. An empty table is
enough:

```toml
[preprocessor.mermaid]
```

That runs `cantrip-mermaid`, and when there is no such program,
`grimoire-mermaid`: a plugin is found by name on `PATH`. Set `command` for
anything else, and `args` for arguments that come before the request:

```toml
[preprocessor.katex]
command = "./tools/grimoire-katex"
args = ["--strict"]
inline = true
```

A `command` with a `/` in it is a path, relative to the deck's directory, used
as written - which is how a deck points at a plugin it keeps beside itself.
Every other key in the table is the plugin's own; Cantrip passes the whole
table through as `plugin.settings` without reading it. The file holds
`[preprocessor.NAME]` tables and nothing else: presentation stays in the deck's
front matter.

Preprocessors run in the order the file lists them, each over what the last
produced, once per build, before anything is rendered. A plugin that exits
non-zero stops the build, and its standard error is reported:

```
cantrip: preprocessor katex: exited 1: grimoire-katex: talk.md:12: unclosed math fence
```

Nothing is discovered automatically. A program has to be named in
`cantrip.toml` before Cantrip will run it - and once it is, it runs with your
permissions and can do anything you can. A deck from somebody else that comes
with a `cantrip.toml` is a program to read before you build it.

Which is why Cantrip says what it runs:

```sh
cantrip plugins talk.md     # what this deck would run, and where each came from
cantrip build -v talk.md    # the same path, printed as each one starts
```

```
preprocessor  mermaid  ->  /usr/bin/grimoire-mermaid  (found on PATH)
preprocessor  katex    ->  /home/ada/talk/tools/grimoire-katex  (in this deck)
```

A plugin whose program came from `PATH`, or from outside the deck's directory,
is reported as a warning on every build - not refused, because the deck naming
it is the gate, but said out loud. One inside the deck's directory passes
without comment.

Plugins need the default `jennifer` binary. `jennifer-tiny` cannot start a
process, so a deck that names a plugin is refused there rather than built with
the plugin silently skipped. A deck without `cantrip.toml` builds on both.

## Generated pictures

A plugin that draws pictures writes them into `plugin.files`, a directory of its
own that Cantrip creates empty for each build, and a slide links them as
`_generated/NAME/FILE`, where `NAME` is the table name:

```markdown
![Build flow](_generated/mermaid/3f9c2a.svg)
```

- The **slideshow** carries the picture inside the page, as a `data:` URL, so
  the HTML stays one file that works offline. Pictures you add yourself stay
  relative links, as before.
- The **PDF** draws the PNG beside an SVG, because it draws no SVG;
  `grimoire-mermaid` writes both unless `png = false`.

The directory is removed when the build ends, so nothing from an earlier build
is left over. `_generated` is reserved while any preprocessor is configured: a
deck whose directory already has a `_generated` entry stops the build, and the
fix is to rename it.

## MathML

A `<math>` element in the MathML namespace reaches the slideshow as markup,
inline in a paragraph or as a block of its own, with or without `--raw-html`.
That is what `grimoire-katex` writes. An element is taken as MathML only when it
is well-formed XML, every element in it is in the MathML namespace, and no
attribute can run or fetch anything (`on...`, `href`, `src`, `style`, or one in
another namespace); anything else is raw HTML, escaped unless `--raw-html` says
otherwise.

The PDF cannot typeset maths, so it prints the TeX source the element carries in
`<annotation encoding="application/x-tex">`, in monospace: in the line for
inline maths, centred on its own lines for display maths.

## Writing one

The request and the reply are Grimoire's, described in full in
[Grimoire's plugin chapter](https://grimoire.jennifer-lang.dev/plugins.html#writing-one).
What a deck puts in the request:

| | |
| - | - |
| `kind` | `"preprocessor"` |
| `features` | `["files", "mathml"]` |
| `book.title`, `book.authors`, `book.language` | the front matter's `title`, `author` and `lang` |
| `book.description` | `""` |
| `book.src` | the deck's directory, absolute |
| `book.out` | the directory the outputs are written to, absolute |
| `book.generated` | the directory standing in for `_generated` |
| `plugin.files` | the plugin's own directory for generated files, absolute and empty |
| `entries` | one `page` per input file, titled by its first heading |
| `chapters` | every input file, front matter included, with its path relative to the deck's directory |

The reply may be sparse: a file it does not mention is unchanged, and naming one
the deck does not have is an error. A plugin must be deterministic, and write
nothing but its reply to standard output.

To be found by name from both tools, publish a plugin as `grimoire-NAME` or
`cantrip-NAME`: each tries its own prefix first and the other's second.
