# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box tests for the slide-deck model.
 * @module slidesTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;

/** The constants are the delimiters the parser documents. */
func testConstants() {
    testing.assertEqual(FENCE, "---");
    testing.assertEqual(NOTE_OPEN, "<!-- notes:");
    testing.assertEqual(NOTE_CLOSE, "-->");
    testing.assertEqual(PAGE_BREAK, "<!-- pagebreak -->");
}

/** Three or more dashes separate slides; anything else does not. */
func testIsSeparator() {
    testing.assertTrue(isSeparator("---"));
    testing.assertTrue(isSeparator("----------"));
    testing.assertTrue(isSeparator("   ---   "));
    testing.assertFalse(isSeparator("--"));
    testing.assertFalse(isSeparator("- - -"));
    testing.assertFalse(isSeparator("***"));
    testing.assertFalse(isSeparator("___"));
    testing.assertFalse(isSeparator("--- x"));
    testing.assertFalse(isSeparator(""));
    testing.assertFalse(isSeparator("# heading"));
}

/** A `name: value` line yields a lower-cased key. */
func testMetaKey() {
    testing.assertEqual(metaKey("Title: X"), "title");
    testing.assertEqual(metaKey("  THEME : y "), "theme");
    testing.assertEqual(metaKey("# a comment"), "");
    testing.assertEqual(metaKey(""), "");
    testing.assertEqual(metaKey("no colon here"), "");
    testing.assertEqual(metaKey(": leading colon"), "");
}

/** A value keeps internal colons and loses its outer quotes. */
func testMetaValue() {
    testing.assertEqual(metaValue("title: X"), "X");
    testing.assertEqual(metaValue("ratio: 16:9"), "16:9");
    testing.assertEqual(metaValue("title: \"A Deck\""), "A Deck");
    testing.assertEqual(metaValue("title: 'A Deck'"), "A Deck");
    testing.assertEqual(metaValue("empty:"), "");
    testing.assertEqual(metaValue("no colon"), "");
}

/** Only a matching, surrounding pair of quotes is removed. */
func testUnquote() {
    testing.assertEqual(unquote("\"x\""), "x");
    testing.assertEqual(unquote("'x'"), "x");
    testing.assertEqual(unquote("x"), "x");
    testing.assertEqual(unquote("\"x"), "\"x");
    testing.assertEqual(unquote("'x\""), "'x\"");
    testing.assertEqual(unquote(""), "");
    testing.assertEqual(unquote("\"\""), "");
    testing.assertEqual(unquote("say \"hi\" now"), "say \"hi\" now");
}

/** Front matter is read only when the file opens with the fence. */
func testFrontMatter() {
    def got as Split init frontMatter("---\ntitle: T\nauthor: A\n---\n# Body\n");
    testing.assertEqual($got.meta["title"], "T");
    testing.assertEqual($got.meta["author"], "A");
    testing.assertEqual($got.body, "# Body\n");
}

/** A deck whose first slide opens with a break is not front matter. */
func testFrontMatterNotFirstLine() {
    def got as Split init frontMatter("# First\n\n---\n\n# Second\n");
    testing.assertEqual(len(maps.keys($got.meta)), 0);
    testing.assertEqual($got.body, "# First\n\n---\n\n# Second\n");
}

/** An unterminated block is left alone rather than eating the deck. */
func testFrontMatterUnterminated() {
    def src as string init "---\ntitle: T\n# never closed\n";
    def got as Split init frontMatter($src);
    testing.assertEqual(len(maps.keys($got.meta)), 0);
    testing.assertEqual($got.body, $src);
}

/** An empty block is valid and contributes no keys. */
func testFrontMatterEmpty() {
    def got as Split init frontMatter("---\n---\nbody\n");
    testing.assertEqual(len(maps.keys($got.meta)), 0);
    testing.assertEqual($got.body, "body\n");
}

/** A fence marker is the leading run of backticks or tildes. */
func testFenceOf() {
    testing.assertEqual(fenceOf("```"), "```");
    testing.assertEqual(fenceOf("```js"), "```");
    testing.assertEqual(fenceOf("````"), "````");
    testing.assertEqual(fenceOf("~~~"), "~~~");
    testing.assertEqual(fenceOf("  ```yaml  "), "```");
    testing.assertEqual(fenceOf("``"), "");
    testing.assertEqual(fenceOf("text"), "");
    testing.assertEqual(fenceOf(""), "");
}

/** A fence closes only on the same character, at least as long. */
func testClosesFence() {
    testing.assertTrue(closesFence("```", "```"));
    testing.assertTrue(closesFence("````", "```"));
    testing.assertFalse(closesFence("```", "````"));
    testing.assertFalse(closesFence("~~~", "```"));
    testing.assertFalse(closesFence("", "```"));
    testing.assertFalse(closesFence("```", ""));
}

/** Chunking drops separators and never yields a blank slide. */
func testChunks() {
    def got as list of string init chunks("a\n---\nb\n---\nc");
    testing.assertEqual($got, ["a", "b", "c"]);
    testing.assertEqual(chunks(""), []);
    testing.assertEqual(chunks("---\n---\n---"), []);
    testing.assertEqual(chunks("only"), ["only"]);
    testing.assertEqual(chunks("a\n---\n\n\n---\nb"), ["a", "b"]);
    testing.assertEqual(chunks("\n---\na\n---\n"), ["a"]);
}

/** A separator inside a fenced block is content, not a separator. */
func testChunksRespectsFences() {
    def src as string init "# One\n\n```yaml\n---\ntitle: T\n---\n```\n\n---\n\n# Two";
    def got as list of string init chunks($src);
    testing.assertEqual(len($got), 2);
    testing.assertContains($got[0], "title: T");
    testing.assertContains($got[0], "---");
    testing.assertEqual($got[1], "# Two");
}

/** A longer fence can contain a shorter one without closing early. */
func testChunksNestedFences() {
    def src as string init "````\n```\n---\n```\n````\n---\nnext";
    def got as list of string init chunks($src);
    testing.assertEqual(len($got), 2);
    testing.assertContains($got[0], "---");
    testing.assertEqual($got[1], "next");
}

/** A tilde fence protects a separator too. */
func testChunksTildeFence() {
    def got as list of string init chunks("~~~\n---\n~~~\n---\nb");
    testing.assertEqual(len($got), 2);
    testing.assertEqual($got[1], "b");
}

/** Notes are lifted out of the body and joined in source order. */
func testTakeNotes() {
    def got as Slide init takeNotes("# H\n\n<!-- notes: first -->\n\ntext");
    testing.assertEqual($got.notes, "first");
    testing.assertEqual($got.body, "# H\n\ntext");
}

/** Several notes on one slide join with a blank line between them. */
func testTakeNotesSeveral() {
    def got as Slide init takeNotes("<!-- notes: a -->\nx\n<!-- notes: b -->");
    testing.assertEqual($got.notes, "a\n\nb");
    testing.assertEqual($got.body, "x");
}

/** A note may span lines, and its inner text is trimmed. */
func testTakeNotesMultiline() {
    def got as Slide init takeNotes("x\n<!-- notes:\n  line one\n  line two\n-->");
    testing.assertEqual($got.notes, "line one\n  line two");
    testing.assertEqual($got.body, "x");
}

/** A slide with no notes keeps its body byte for byte. */
func testTakeNotesNone() {
    def got as Slide init takeNotes("# H\n\ntext");
    testing.assertEqual($got.notes, "");
    testing.assertEqual($got.body, "# H\n\ntext");
}

/** An unterminated opener is left in place rather than dropping the slide. */
func testTakeNotesUnterminated() {
    def got as Slide init takeNotes("keep me\n<!-- notes: never closed");
    testing.assertEqual($got.notes, "");
    testing.assertContains($got.body, "keep me");
}

/** An empty note contributes nothing. */
func testTakeNotesEmpty() {
    def got as Slide init takeNotes("x\n<!-- notes: -->");
    testing.assertEqual($got.notes, "");
}

/** The notes syntax shown in a fenced code block stays in the code. */
func testTakeNotesSkipsFencedCode() {
    def src as string init "# H\n\n```markdown\n<!-- notes: an example -->\n```\n\n" +
        "<!-- notes: real -->";
    def got as Slide init takeNotes($src);
    testing.assertEqual($got.notes, "real");
    testing.assertEqual($got.body, "# H\n\n```markdown\n<!-- notes: an example -->\n```");
}

/** The notes syntax in an inline code span stays in the prose. */
func testTakeNotesSkipsInlineCode() {
    def got as Slide init takeNotes("Write `<!-- notes: x -->` under a slide. <!-- notes: y -->");
    testing.assertEqual($got.notes, "y");
    testing.assertEqual($got.body, "Write `<!-- notes: x -->` under a slide.");
}

/** A note that opens mid-line keeps the text around it on that line. */
func testTakeNotesMidLine() {
    def got as Slide init takeNotes("before <!-- notes:\nsay\n--> after");
    testing.assertEqual($got.notes, "say");
    testing.assertEqual($got.body, "before  after");
}

/** A note may itself hold a code fence without being split by it. */
func testTakeNotesHoldingAFence() {
    def got as Slide init takeNotes("x\n<!-- notes:\n```\ncode\n```\n-->");
    testing.assertEqual($got.notes, "```\ncode\n```");
    testing.assertEqual($got.body, "x");
}

/** An unterminated opener keeps every line after it, byte for byte. */
func testTakeNotesUnterminatedKeepsLines() {
    def got as Slide init takeNotes("a\n<!-- notes: open\nb\nc");
    testing.assertEqual($got.notes, "");
    testing.assertEqual($got.body, "a\n<!-- notes: open\nb\nc");
}

/** Code-span detection counts the backticks before a position. */
func testInsideCodeSpan() {
    testing.assertTrue(insideCodeSpan("a `b", 4));
    testing.assertFalse(insideCodeSpan("a `b` c", 7));
    testing.assertFalse(insideCodeSpan("plain", 3));
}

/** The next live opener skips any inside a code span. */
func testNoteStart() {
    testing.assertEqual(noteStart("x <!-- notes: a -->", 0), 2);
    testing.assertEqual(noteStart("`<!-- notes: a -->`", 0), -1);
    testing.assertEqual(noteStart("no note here", 0), -1);
}

/** A fence closes only on a bare run at least as long as its opener. */
func testClosesFenceLine() {
    testing.assertTrue(closesFenceLine("```", "```"));
    testing.assertTrue(closesFenceLine("  ````  ", "```"));
    testing.assertFalse(closesFenceLine("```js", "```"));
    testing.assertFalse(closesFenceLine("```", "````"));
    testing.assertFalse(closesFenceLine("text", "```"));
}

/** A fenced block keeps its blank runs and trailing spaces. */
func testTidyKeepsFencedCode() {
    def code as string init "```py\ndef a():\n    pass\n\n\ndef b():  \n    pass\n```";
    testing.assertEqual(tidy("\n\n" + $code + "\n\n\n\nafter\n"), $code + "\n\nafter");
}

/** A key cap in prose becomes a code span the PDF can draw. */
func testKbdToCode() {
    testing.assertEqual(kbdToCode("Press <kbd>s</kbd> or <kbd>Esc</kbd>."), "Press `s` or `Esc`.");
    testing.assertEqual(kbdToCode("| <kbd>Right</kbd> | next |"), "| `Right` | next |");
    testing.assertEqual(kbdToCode("no keys"), "no keys");
    testing.assertEqual(KBD_OPEN, "<kbd>");
    testing.assertEqual(KBD_CLOSE, "</kbd>");
}

/** A key cap shown as code, or left unclosed, is not touched. */
func testKbdToCodeLeavesCode() {
    def fenced as string init "```html\n<kbd>s</kbd>\n```";
    testing.assertEqual(kbdToCode($fenced), $fenced);
    testing.assertEqual(kbdToCode("Write `<kbd>s</kbd>` here"), "Write `<kbd>s</kbd>` here");
    testing.assertEqual(kbdToCode("open <kbd>s"), "open <kbd>s");
    testing.assertEqual(kbdToCode("`<kbd>x</kbd>` then <kbd>y</kbd>"), "`<kbd>x</kbd>` then `y`");
}

/** Tidying collapses blank runs and trims both ends. */
func testTidy() {
    testing.assertEqual(tidy("\n\na\n\n\n\nb\n\n"), "a\n\nb");
    testing.assertEqual(tidy("a"), "a");
    testing.assertEqual(tidy(""), "");
    testing.assertEqual(tidy("\n\n\n"), "");
    testing.assertEqual(tidy("a   \nb\t"), "a\nb");
}

/** The first heading gives a slide its title and level. */
func testHeading() {
    def got as Slide init heading("## Second level\n\ntext");
    testing.assertEqual($got.title, "Second level");
    testing.assertEqual($got.level, 2);
}

/** A heading-less slide reports no title. */
func testHeadingNone() {
    def got as Slide init heading("just a paragraph");
    testing.assertEqual($got.title, "");
    testing.assertEqual($got.level, 0);
}

/** A `#` inside a fenced block is code, not a heading. */
func testHeadingIgnoresCode() {
    def got as Slide init heading("```\n# not a heading\n```\n\n# Real");
    testing.assertEqual($got.title, "Real");
    testing.assertEqual($got.level, 1);
}

/** Inline markup in a heading reduces to its text. */
func testHeadingStripsMarkup() {
    def got as Slide init heading("# A **bold** word");
    testing.assertEqual($got.title, "A bold word");
}

/** A full parse fills the metadata and numbers the slides from one. */
func testParse() {
    def src as string init "---\ntitle: T\nauthor: A\ndate: D\ntheme: midnight\nratio: 4:3\n---\n" +
        "# One\n\n<!-- notes: n1 -->\n\n---\n\n## Two\n";
    def deck as Deck init parse($src);
    testing.assertEqual($deck.title, "T");
    testing.assertEqual($deck.author, "A");
    testing.assertEqual($deck.date, "D");
    testing.assertEqual($deck.theme, "midnight");
    testing.assertEqual($deck.ratio, "4:3");
    testing.assertEqual(len($deck.slides), 2);
    testing.assertEqual($deck.slides[0].number, 1);
    testing.assertEqual($deck.slides[0].title, "One");
    testing.assertEqual($deck.slides[0].notes, "n1");
    testing.assertEqual($deck.slides[1].number, 2);
    testing.assertEqual($deck.slides[1].level, 2);
}

/** With no `title:` the deck borrows the first slide's heading. */
func testParseBorrowsTitle() {
    def deck as Deck init parse("# Borrowed\n\n---\n\n# Later");
    testing.assertEqual($deck.title, "Borrowed");
}

/** Parsing nothing gives a deck with no slides, not an error. */
func testParseEmpty() {
    def deck as Deck init parse("");
    testing.assertEqual(len($deck.slides), 0);
    testing.assertEqual($deck.title, "");
}

/** Front matter alone is metadata with no slides. */
func testParseFrontMatterOnly() {
    def deck as Deck init parse("---\ntitle: T\n---\n");
    testing.assertEqual($deck.title, "T");
    testing.assertEqual(len($deck.slides), 0);
}

/** An unknown front-matter key is kept verbatim for a renderer to read. */
func testParseKeepsUnknownKeys() {
    def deck as Deck init parse("---\nsubject: S\nlang: de\n---\n# H");
    testing.assertEqual($deck.meta["subject"], "S");
    testing.assertEqual($deck.meta["lang"], "de");
}

/** Reading a key falls back when it is absent or blank. */
func testMetaOr() {
    def m as map of string to string init {"a": "x", "b": "   "};
    testing.assertEqual(metaOr($m, "a", "d"), "x");
    testing.assertEqual(metaOr($m, "b", "d"), "d");
    testing.assertEqual(metaOr($m, "missing", "d"), "d");
    testing.assertEqual(metaOr({}, "a", ""), "");
}

/** Concatenation renumbers the appended slides continuously. */
func testConcat() {
    def a as Deck init parse("# A1\n---\n# A2");
    def b as Deck init parse("# B1");
    def got as Deck init concat($a, $b);
    testing.assertEqual(len($got.slides), 3);
    testing.assertEqual($got.slides[2].number, 3);
    testing.assertEqual($got.slides[2].title, "B1");
    testing.assertEqual($got.title, "A1");
}

/** The first deck's metadata wins; a blank title is filled from the second. */
func testConcatTitle() {
    def a as Deck init parse("no heading here");
    def b as Deck init parse("# From B");
    testing.assertEqual(concat($a, $b).title, "From B");
}

/** Concatenation leaves its arguments untouched. */
func testConcatIsValueSemantic() {
    def a as Deck init parse("# A1");
    def b as Deck init parse("# B1");
    concat($a, $b);
    testing.assertEqual(len($a.slides), 1);
    testing.assertEqual(len($b.slides), 1);
}

/** Serializing puts a page break between consecutive slides. */
func testToMarkdown() {
    def deck as Deck init parse("# One\n---\n# Two");
    def got as string init toMarkdown($deck, false);
    testing.assertContains($got, PAGE_BREAK);
    testing.assertContains($got, "# One");
    testing.assertContains($got, "# Two");
    testing.assertEqual(toMarkdown(parse("# Only"), false), "# Only");
}

/** Notes are omitted unless asked for, then appended as a quote. */
func testToMarkdownNotes() {
    def deck as Deck init parse("# One\n\n<!-- notes: say this -->");
    testing.assertFalse(strings.contains(toMarkdown($deck, false), "say this"));
    def withNotes as string init toMarkdown($deck, true);
    testing.assertContains($withNotes, "say this");
    testing.assertContains($withNotes, "> **Notes**");
}

/** An empty deck serializes to an empty string. */
func testToMarkdownEmpty() {
    testing.assertEqual(toMarkdown(parse(""), true), "");
}

/** Notes render as a blockquote, blank lines included. */
func testNotesBlock() {
    testing.assertEqual(notesBlock(""), "");
    testing.assertEqual(notesBlock("   "), "");
    def got as string init notesBlock("a\n\nb");
    testing.assertEqual($got, "> **Notes**\n>\n> a\n>\n> b");
}

/** Counting a deck is counting its slides. */
func testCount() {
    testing.assertEqual(count(parse("# A\n---\n# B")), 2);
    testing.assertEqual(count(parse("")), 0);
}

/** The summary names the deck and counts what carries notes. */
func testDescribe() {
    def deck as Deck init parse("---\ntitle: T\n---\n# A\n\n<!-- notes: x -->\n---\n# B");
    testing.assertEqual(describe($deck), "T: 2 slide(s), 1 with notes");
    testing.assertContains(describe(parse("")), "(untitled)");
}
