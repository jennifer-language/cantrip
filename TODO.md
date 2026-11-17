# To do

## A `#` heading below the top of a slide breaks the PDF page

A slide that has a level-1 heading anywhere but at its top, or two of them,
comes out as two PDF pages, and `cantrip` then warns that the slide
"overflowed" although it fits.

**Cause.** The PDF is laid out by the interpreter's `doctree` module
(`renderHeading` in `modules/doctree.j`), which starts a fresh page for every
level-1 heading unless the page is still empty. Cantrip joins the slides into
one document with a page break between them, so a slide's first `#` lands on an
empty page, but any later one opens a new page.

**Options.**

1. A `doctree.PdfOptions` field that turns the page-per-h1 rule off (a change
   in jennifer, filed as an M-entry there), which cantrip then sets.
2. Cantrip demotes every level-1 heading that is not the first block of its
   slide to level 2, in the Markdown it hands to the PDF renderer only. No
   interpreter change, but the PDF then shows that heading at h2 size and
   bookmarks it one level down.

Until then the behaviour is documented in `docs/format.md`, "Page breaks".

## Characters outside Western European print as `?` in the PDF

Any character the PDF's fonts cannot encode comes out as `?`, silently: an
arrow (`→`), an emoji, Greek, Cyrillic, Chinese. The HTML slideshow shows them
correctly. The academy's checker refuses such characters for now, which also
rules out talks in languages that use other scripts.

**Cause.** The PDF is laid out by the interpreter's `doctree` module, whose
`PdfOptions` take only the 14 standard PDF fonts (`bodyFont`, `monoFont`,
...). Those use the WinAnsi encoding (cp1252), so nothing outside it can be
drawn. The `pdf` module itself already embeds TrueType fonts (`loadFont`,
`addFont`, `textUnicode`, a Type0 font with only the used glyphs); `doctree`
does not use that path.

**Options.**

1. A `doctree.PdfOptions` field for embedded TrueType faces (body, bold,
   italic, mono, heading), drawn with `textUnicode` and measured with the
   font's own metrics (jennifer M29.20).
   Cantrip then embeds a free Unicode font such as DejaVu Sans / Sans Mono,
   either shipped with cantrip or chosen by the theme, with a fallback for a
   glyph the font lacks.
2. Until then: cantrip warns, naming the slide and the character, whenever
   text in the PDF cannot be encoded, instead of printing `?`. A build then
   fails the academy's "no warnings" rule on its own, without a separate check.

Option 2 is small and worth doing first; option 1 is the fix.
