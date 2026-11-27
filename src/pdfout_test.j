# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * White-box tests for the PDF renderer.
 * @module pdfoutTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;
use maps;
use convert;
use regex;
use encoding;

/**
 * A three-slide deck with notes, an image, and a code block.
 * @return {slides.Deck} the fixture most tests here render
 */
func fixture() {
    return slides.parse("---\ntitle: Deck T\nauthor: Ada\nsubject: S\n" +
        "keywords: a, b\ntheme: plain\nmode: dark\nratio: 16:9\n---\n" +
        "# One\n\nText.\n\n<!-- notes: say this -->\n\n" +
        "---\n\n## Two\n\n![a pic](fig.png)\n\n" +
        "---\n\n## Three\n\n```js\nconst x = 1;\n```\n");
}

/**
 * Resolve a theme and report how it failed.
 * @param name {string} the theme name to put in the options
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func themeFailure(name as string) {
    def opts as Options init defaults();
    $opts.theme = $name;
    try {
        pickTheme(fixture(), $opts);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * Resolve a ratio and report how it failed.
 * @param name {string} the ratio name to put in the options
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func ratioFailure(name as string) {
    def opts as Options init defaults();
    $opts.ratio = $name;
    try {
        pickStage(fixture(), $opts);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * Parse a colour into a fill and report how it failed.
 * @param hex {string} the colour to try
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func fillFailure(hex as string) {
    try {
        fill($hex);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/** The layout constants are sane for a slide-sized page. */
func testConstants() {
    testing.assertEqual(CREATOR, "cantrip");
    testing.assertTrue(BODY_SIZE > 11);
    testing.assertTrue(MARGIN > 0);
    testing.assertTrue(MARGIN * 2 < shrink(theme.stage("16:9").pageHeight));
    testing.assertEqual(IMAGE_DPI, 96 * SCALE_NUM // SCALE_DEN);
}

/** The defaults print the audience's copy: no notes, numbered, bookmarked. */
func testDefaults() {
    def opts as Options init defaults();
    testing.assertFalse($opts.notes);
    testing.assertTrue($opts.numbers);
    testing.assertEqual($opts.bookmarks, 2);
    testing.assertEqual(len(maps.keys($opts.images)), 0);
}

/** An option overrides front matter, which overrides the default. */
func testPickThemeAndStage() {
    def opts as Options init defaults();
    testing.assertEqual(pickTheme(fixture(), $opts).name, "plain");
    testing.assertFalse(pickTheme(fixture(), $opts).dark);
    testing.assertEqual(pickStage(fixture(), $opts).name, "16:9");
    $opts.theme = "sepia";
    $opts.ratio = "4:3";
    testing.assertEqual(pickTheme(fixture(), $opts).name, "sepia");
    testing.assertEqual(pickStage(fixture(), $opts).name, "4:3");
}

/** An unknown name is a catchable theme error. */
func testPickRejectsUnknown() {
    testing.assertEqual(themeFailure("nope"), "theme");
    testing.assertEqual(themeFailure("sepia"), "");
    testing.assertEqual(ratioFailure("21:9"), "theme");
    testing.assertEqual(ratioFailure("4:3"), "");
}

/** A theme colour becomes a fill; anything else is an error. */
func testFill() {
    fill("#102030");
    fill("#abc");
    testing.assertEqual(fillFailure("#102030"), "");
    testing.assertEqual(fillFailure("nope"), "theme");
    testing.assertEqual(fillFailure(""), "theme");
}

/** Image targets are found wherever they sit, without repeats. */
func testImageUrls() {
    testing.assertEqual(imageUrls(fixture()), ["fig.png"]);
    testing.assertEqual(imageUrls(slides.parse("# no pictures")), []);
}

/** The same picture used twice is reported once, in first-seen order. */
func testImageUrlsDeduplicates() {
    def src as string init "![a](one.png)\n\n![b](two.png)\n\n---\n\n![c](one.png)\n";
    testing.assertEqual(imageUrls(slides.parse($src)), ["one.png", "two.png"]);
}

/** An image nested in a list, quote, or table is still found. */
func testImageUrlsFindsNested() {
    def src as string init "- item ![a](in-list.png)\n\n> quote ![b](in-quote.png)\n\n";
    $src = $src + "| h |\n| --- |\n| ![c](in-cell.png) |\n";
    def got as list of string init imageUrls(slides.parse($src));
    testing.assertContains($got, "in-list.png");
    testing.assertContains($got, "in-quote.png");
    testing.assertContains($got, "in-cell.png");
}

/** A bare paragraph holds no images. */
func testCollectImagesEmpty() {
    testing.assertEqual(collectImages(markdown.parse("just text")), []);
}

/** Walking a tree returns every image below the node, in document order. */
func testCollectImages() {
    def doc as doctree.Node init markdown.parse("![a](1.png)\n\n![b](2.png)\n");
    testing.assertEqual(collectImages($doc), ["1.png", "2.png"]);
}

/** The layout is two thirds of the printed page and carries the metadata. */
func testLayout() {
    def deck as slides.Deck init fixture();
    def got as doctree.PdfOptions init layout($deck, defaults());
    testing.assertEqual($got.pageWidth, 640);
    testing.assertEqual($got.pageHeight, 360);
    testing.assertEqual($got.imageDpi, IMAGE_DPI);
    testing.assertEqual($got.margin, MARGIN);
    testing.assertEqual($got.bodySize, BODY_SIZE);
    testing.assertEqual($got.title, "Deck T");
    testing.assertEqual($got.author, "Ada");
    testing.assertEqual($got.subject, "S");
    testing.assertEqual($got.keywords, "a, b");
    testing.assertEqual($got.creator, CREATOR);
    testing.assertEqual($got.bookmarkLevel, 2);
}

/**
 * A deck in dark mode still prints its light palette: the PDF draws black text
 * on the panels, so the dark code shade of the screen would be unreadable on paper.
 */
func testLayoutUsesPrintShades() {
    def got as doctree.PdfOptions init layout(fixture(), defaults());
    def t as theme.Theme init theme.theme("plain", "light");
    testing.assertEqual($got.codeFill, fill($t.printCodeBg));
    testing.assertEqual($got.quoteFill, fill($t.printCodeBg));
    testing.assertEqual($got.tableHeaderFill, fill($t.printCodeBg));
    testing.assertEqual($got.quoteRule, fill($t.printQuoteBar));
    testing.assertNotEqual($got.codeFill, fill(theme.theme("plain", "dark").codeBg));
}

/** Every stage scales exactly: its printed size is a whole 3/2 of the layout. */
func testScaleIsExactForEveryStage() {
    testing.assertEqual(SCALE_NUM, 3);
    testing.assertEqual(SCALE_DEN, 2);
    for (def name in theme.ratios()) {
        def s as theme.Stage init theme.stage($name);
        testing.assertEqual(grow(shrink($s.pageWidth)), $s.pageWidth);
        testing.assertEqual(grow(shrink($s.pageHeight)), $s.pageHeight);
    }
}

/** Shrinking and growing are each other's inverse on whole multiples. */
func testShrinkAndGrow() {
    testing.assertEqual(shrink(960), 640);
    testing.assertEqual(grow(640), 960);
    testing.assertEqual(grow(10), 15);
}

/** Magnifying sets the printed page size and wraps the content in one scale. */
func testMagnify() {
    def pg as pdf.Page init pdf.page(640, 360);
    $pg = pdf.text($pg, 10, 20, "Helvetica", 12, "hi");
    $pg = pdf.link($pg, 10, 20, 100, 30, "https://example.com/");
    def doc as pdf.Document init pdf.addPage(pdf.document(), $pg);
    $doc = pdf.bookmark($doc, 0, 300, "Hi", 1);
    def got as pdf.Document init magnify($doc, theme.stage("16:9"));
    def big as pdf.Page init $got.pages[0];
    testing.assertEqual($big.width, 960);
    testing.assertEqual($big.height, 540);
    testing.assertTrue(strings.startsWith($big.content, "q\n1.5 0 0 1.5 0 0 cm\n"));
    testing.assertTrue(strings.endsWith($big.content, "\nQ\n"));
    testing.assertContains($big.content, $pg.content);
    testing.assertEqual($big.annots[0].x, 15);
    testing.assertEqual($big.annots[0].width, 150);
    testing.assertEqual($got.outline[0].y, 450);
}

/**
 * A deck of slide pages, each with a line of text, a link, and a bookmark.
 * @param n {int} how many slide pages
 * @return {pdf.Document} the slide document
 */
func slidePages(n as int) {
    def doc as pdf.Document init pdf.document();
    for (def i in 0..$n) {
        def pg as pdf.Page init pdf.page(960, 540);
        $pg = pdf.text($pg, 10, 20, "Helvetica", 12, "slide " + convert.toString($i));
        $pg = pdf.link($pg, 100, 200, 300, 40, "https://example.com/");
        $doc = pdf.addPage($doc, $pg);
        $doc = pdf.bookmark($doc, $i, 540, "S" + convert.toString($i), 1);
    }
    return $doc;
}

/** Three slides fit on an A4 portrait page; a fourth starts the next page. */
func testHandoutPutsThreeSlidesOnA4() {
    def got as pdf.Document init handout(slidePages(4), theme.stage("16:9"), "", pdf.pageLabel());
    testing.assertEqual(len($got.pages), (4 + HANDOUT_PER_PAGE - 1) // HANDOUT_PER_PAGE);
    def first as pdf.Page init $got.pages[0];
    testing.assertEqual($first.width, HANDOUT_WIDTH);
    testing.assertEqual($first.height, HANDOUT_HEIGHT);
    testing.assertEqual(len(strings.split($first.content, " re W n\n")), 4);
    testing.assertContains($first.content, "slide 0");
    testing.assertContains($first.content, "slide 2");
    testing.assertFalse(strings.contains($first.content, "slide 3"));
    testing.assertContains($got.pages[1].content, "slide 3");
    testing.assertEqual(len($first.annots), 3);
    testing.assertEqual(encoding.decode("utf-8", pdf.render($got)[0..5]), "%PDF-");
}

/** A slide keeps its proportions, fits the margins, and leaves room for notes. */
func testHandoutScalesInsideTheMargins() {
    def got as pdf.Document init handout(slidePages(1), theme.stage("16:9"), "", pdf.pageLabel());
    def a as pdf.LinkAnnot init $got.pages[0].annots[0];
    # the link sat at 100,200 (300 x 40) on a 960 x 540 slide; scaled, it keeps
    # its 7.5:1 shape and lies inside the slide's part of the page
    testing.assertTrue($a.x > HANDOUT_MARGIN);
    testing.assertTrue($a.x + $a.width < HANDOUT_WIDTH - HANDOUT_MARGIN - HANDOUT_NOTES_MIN);
    testing.assertTrue($a.width > 7 * $a.height and $a.width < 8 * $a.height);
    testing.assertContains($got.pages[0].content, " l S\n");
    # note lines are HANDOUT_LINE_STEP apart, and slides HANDOUT_GAP apart
    testing.assertTrue(HANDOUT_LINE_STEP > 0 and HANDOUT_GAP > 0);
    def two as pdf.Document init handout(slidePages(2), theme.stage("16:9"), "", pdf.pageLabel());
    def upper as int init $two.pages[0].annots[0].y;
    def lower as int init $two.pages[0].annots[1].y;
    testing.assertTrue($upper - $lower > HANDOUT_GAP);
}

/** Bookmarks follow their slides onto the handout pages. */
func testHandoutMovesBookmarks() {
    def got as pdf.Document init handout(slidePages(5), theme.stage("4:3"), "", pdf.pageLabel());
    testing.assertEqual(len($got.outline), 5);
    testing.assertEqual($got.outline[0].page, 0);
    testing.assertEqual($got.outline[2].page, 0);
    testing.assertEqual($got.outline[3].page, 1);
    testing.assertTrue($got.outline[0].y > $got.outline[1].y);
    testing.assertTrue($got.outline[1].y > $got.outline[2].y);
}

/**
 * The credit is off by default. Turned on, it is drawn on the first page only,
 * grey, at the footer's left margin one line above the footer text (on the
 * footer's line when that is empty), with a link over the address.
 */
func testCredit() {
    def plain as pdf.Document init document(fixture(), defaults());
    def opts as Options init defaults();
    $opts.credit = true;
    def got as pdf.Document init document(fixture(), $opts);
    testing.assertFalse(strings.contains($plain.pages[0].content, "Powered by"));
    testing.assertContains($got.pages[0].content, "Powered by Jennifer's Cantrip");
    testing.assertFalse(strings.contains($got.pages[1].content, "Powered by"));
    testing.assertEqual(len($got.pages[0].annots), len($plain.pages[0].annots) + 1);
    def a as pdf.LinkAnnot init $got.pages[0].annots[len($got.pages[0].annots) - 1];
    testing.assertEqual($a.uri, "https://github.com/jennifer-language/cantrip");
    testing.assertTrue($a.x > 36);
    # The deck has a title, so the footer's left holds it and the credit goes above.
    testing.assertEqual($a.y, 36 + 9 + 4 - CREDIT_SIZE // 4);
    def bare as pdf.PageLabel init pdf.pageLabel();
    def low as pdf.Document init credit($plain, $bare);
    testing.assertEqual(
        $low.pages[0].annots[len($low.pages[0].annots) - 1].y,
        36 - CREDIT_SIZE // 4);
    testing.assertEqual(len(credit(pdf.document(), $bare).pages), 0);
}

/** The handout footer carries the --footer text and always numbers its pages. */
func testHandoutFooterNumbersPages() {
    def opts as Options init defaults();
    $opts.numbers = false;
    def plain as pdf.PageLabel init handoutFooter(fixture(), $opts);
    testing.assertEqual($plain.left, "");
    testing.assertEqual($plain.right, "%page% / %pages%");
    $opts.footer = "Jennifer Academy, https://academy.jennifer-lang.dev/";
    testing.assertEqual(handoutFooter(fixture(), $opts).left, $opts.footer);
    testing.assertEqual(handoutTitle(fixture()), "Deck T");
}

/** The title heads every page, and the slides move down to make room for it. */
func testHandoutTitleOnEveryPage() {
    def bare as pdf.Document init handout(slidePages(4), theme.stage("16:9"), "", pdf.pageLabel());
    def titled as pdf.Document init handout(
        slidePages(4),
        theme.stage("16:9"),
        "Deck T",
        pdf.pageLabel());
    testing.assertContains($titled.pages[0].content, "(Deck T) Tj");
    testing.assertContains($titled.pages[1].content, "(Deck T) Tj");
    testing.assertFalse(strings.contains($bare.pages[0].content, "Deck T"));
    testing.assertTrue($titled.pages[0].annots[0].y < $bare.pages[0].annots[0].y);
    # the slides move down by the room the title takes, scaled into the slot
    testing.assertTrue(HANDOUT_TITLE_SPACE > HANDOUT_TITLE_SIZE);
    testing.assertContains(
        $titled.pages[0].content,
        "/Helvetica-Bold " + convert.toString(HANDOUT_TITLE_SIZE) + " Tf");
    def long as string init strings.replicate("A very long title ", 12);
    def cut as pdf.Document init handout(
        slidePages(1),
        theme.stage("16:9"),
        $long,
        pdf.pageLabel());
    testing.assertContains($cut.pages[0].content, "...) Tj");
}

/** Coordinates are written with at most three decimals. */
func testNum() {
    testing.assertEqual(num(36.0), "36");
    testing.assertEqual(num(0.4417), "0.442");
    testing.assertEqual(num(12.5), "12.5");
    testing.assertEqual(num(0.05), "0.05");
}

/** Key caps print as code, not as their tags. */
func testDocumentDrawsKeyCaps() {
    def deck as slides.Deck init slides.parse("# Keys\n\nPress <kbd>s</kbd>.");
    def doc as pdf.Document init document($deck, defaults());
    testing.assertFalse(strings.contains($doc.pages[0].content, "kbd"));
    testing.assertContains($doc.pages[0].content, "(s)");
}

/** The finished document is at the printed page size, one page per slide. */
func testDocument() {
    def doc as pdf.Document init document(fixture(), defaults());
    testing.assertEqual(pdf.getTotalPages($doc), 3);
    testing.assertEqual($doc.pages[0].width, 960);
    testing.assertEqual($doc.pages[0].height, 540);
    testing.assertEqual(pdf.render($doc), render(fixture(), defaults()));
}

/** Pictures the caller loaded reach the layout. */
func testLayoutCarriesImages() {
    def opts as Options init defaults();
    $opts.images["fig.png"] = pdf.loadImage("fig", onePixelPng());
    def got as doctree.PdfOptions init layout(fixture(), $opts);
    testing.assertTrue(maps.has($got.images, "fig.png"));
}

/** The bookmark depth is the caller's, including none. */
func testLayoutBookmarkDepth() {
    def opts as Options init defaults();
    $opts.bookmarks = 0;
    testing.assertEqual(layout(fixture(), $opts).bookmarkLevel, 0);
    $opts.bookmarks = 3;
    testing.assertEqual(layout(fixture(), $opts).bookmarkLevel, 3);
}

/** The footer labels the deck and numbers the pages. */
func testFooter() {
    def got as pdf.PageLabel init footer(fixture(), defaults());
    testing.assertEqual($got.left, "Deck T");
    testing.assertEqual($got.right, "%page% / %pages%");
}

/** An explicit footer wins over the deck's title. */
func testFooterOverride() {
    def opts as Options init defaults();
    $opts.footer = "ACME";
    testing.assertEqual(footer(fixture(), $opts).left, "ACME");
}

/** Turning numbers off empties the right slot. */
func testFooterWithoutNumbers() {
    def opts as Options init defaults();
    $opts.numbers = false;
    testing.assertEqual(footer(fixture(), $opts).right, "");
}

/** A deck with no title and no footer gets an empty label. */
func testFooterEmpty() {
    def opts as Options init defaults();
    $opts.numbers = false;
    def got as pdf.PageLabel init footer(slides.parse("no heading"), $opts);
    testing.assertEqual($got.left, "");
    testing.assertEqual($got.right, "");
}

/**
 * A title or footer the standard fonts cannot draw still renders: the footer
 * shows a substitute instead of the whole PDF failing to encode.
 */
func testFooterOutsideWinAnsi() {
    def deck as slides.Deck init slides.parse("---\ntitle: Café 日本\n---\n# 日本\n");
    testing.assertEqual(footer($deck, defaults()).left, "Café ??");
    testing.assertTrue(len(render($deck, defaults())) > 500);
    def opts as Options init defaults();
    $opts.footer = "Ελλάδα ok";
    testing.assertEqual(footer($deck, $opts).left, "?????? ok");
    testing.assertTrue(len(render($deck, $opts)) > 500);
}

/** A rendered deck is a PDF of one page per slide. */
func testRender() {
    def out as bytes init render(fixture(), defaults());
    testing.assertTrue(len($out) > 500);
    def head as string init encoding.decode("utf-8", $out[..5]);
    testing.assertEqual($head, "%PDF-");
    testing.assertEqual(pageCount(fixture(), defaults()), 3);
}

/** The render is deterministic, so a golden comparison is meaningful. */
func testRenderIsByteIdentical() {
    testing.assertEqual(render(fixture(), defaults()), render(fixture(), defaults()));
}

/** Notes are omitted unless asked for. */
func testRenderNotes() {
    def opts as Options init defaults();
    $opts.notes = true;
    testing.assertNotEqual(render(fixture(), $opts), render(fixture(), defaults()));
}

/** An empty deck still renders a readable PDF. */
func testRenderEmpty() {
    def out as bytes init render(slides.parse(""), defaults());
    testing.assertTrue(len($out) > 0);
}

/** Every theme and ratio renders without throwing. */
func testRenderEveryTheme() {
    for (def name in theme.names()) {
        def opts as Options init defaults();
        $opts.theme = $name;
        $opts.ratio = "4:3";
        testing.assertTrue(len(render(fixture(), $opts)) > 500);
    }
}

/** One slide is one page, so the counts agree for a deck that fits. */
func testPageCountMatchesSlides() {
    def deck as slides.Deck init slides.parse("# A\n---\n# B\n---\n# C\n---\n# D");
    testing.assertEqual(pageCount($deck, defaults()), 4);
}

/** A slide too tall for its page overflows, and the count says so. */
func testPageCountDetectsOverflow() {
    def body as string init "# Tall\n";
    for (def i as int init 0; $i < 120; $i = $i + 1) {
        $body = $body + "\nA line of prose that takes up vertical room on the page.\n";
    }
    def deck as slides.Deck init slides.parse($body);
    testing.assertEqual(len($deck.slides), 1);
    testing.assertTrue(pageCount($deck, defaults()) > 1);
}

/** The summary names the page size, the page count, and the theme. */
func testDescribe() {
    def got as string init describe(fixture(), defaults());
    testing.assertContains($got, "960x540pt");
    testing.assertContains($got, "3 page(s)");
    testing.assertContains($got, "theme plain");
}

/**
 * The smallest valid PNG, for the tests that need real image bytes.
 * @return {bytes} a 1x1 greyscale PNG
 */
func onePixelPng() {
    return encoding.fromText(
        "base64",
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQAB" +
            "lpSm1gAAAABJRU5ErkJggg==");
}

/**
 * Lay a deck out and report how it failed.
 * @param deck {slides.Deck} the deck
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func documentFailure(deck as slides.Deck) {
    try {
        document($deck, defaults());
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * Every page's content stream, joined.
 * @param doc {pdf.Document} the document
 * @return {string} the content of all its pages
 */
func contentOf(doc as pdf.Document) {
    def parts as list of string init [];
    for (def pg in $doc.pages) {
        $parts[] = $pg.content;
    }
    return strings.join($parts, "\n");
}

/**
 * The options with highlighting off.
 * @return {Options} the defaults, unhighlighted
 */
func plainOptions() {
    def opts as Options init defaults();
    $opts.highlight = false;
    return $opts;
}

/** The panel marker is a colour no theme uses, and none is left in the output. */
func testCodeMarkIsNoThemeColour() {
    for (def t in theme.all()) {
        for (def c in [
            $t.background,
            $t.foreground,
            $t.accent,
            $t.codeBg,
            $t.printCodeBg,
            $t.printQuoteBar
        ]) {
            testing.assertNotEqual(theme.hexRgb($c), theme.hexRgb(CODE_MARK));
        }
    }
    def got as string init contentOf(document(fixture(), defaults()));
    testing.assertFalse(strings.contains($got, colourOp(CODE_MARK)));
    testing.assertContains($got, colourOp(theme.theme("plain", "light").printCodeBg));
}

/** Code in a known language is drawn in the theme's print token colours. */
func testDocumentColoursCode() {
    def deck as slides.Deck init slides.parse(
        "---\ntheme: nordic\nmode: dark\n---\n# C\n\n" +
            "```jennifer\n# note\ndef x as int init 1;\n```\n");
    def doc as pdf.Document init document($deck, defaults());
    def got as string init contentOf($doc);
    def s as theme.Syntax init theme.printSyntax(theme.theme("nordic", "light"));
    testing.assertContains($got, colourOp($s.keyword) + "\n(def) Tj");
    testing.assertContains($got, colourOp($s.typeName) + "\n(int) Tj");
    testing.assertContains($got, colourOp($s.number) + "\n(1) Tj");
    testing.assertContains($got, "/Courier-Oblique 13 Tf\n(# note) Tj");
    testing.assertTrue(lists.contains($doc.pages[0].fonts, "Courier-Oblique"));
    testing.assertContains($got, colourOp("") + "\nET");
    def plain as string init contentOf(document($deck, plainOptions()));
    testing.assertFalse(strings.contains($plain, colourOp($s.keyword)));
    testing.assertContains($plain, "(def x as int init 1;) Tj");
    testing.assertTrue(len(render($deck, defaults())) > 500);
}

/**
 * Turning highlighting off, by option or front matter, gives exactly the PDF
 * Cantrip drew before it highlighted; so does a block in no known language.
 */
func testUnhighlightedIsUnchanged() {
    def quiet as slides.Deck init slides.parse("---\nhighlight: false\n---\n" +
        "# C\n\n```js\nlet x;\n```\n");
    testing.assertFalse(pickHighlight($quiet, defaults()));
    testing.assertEqual(render($quiet, defaults()), render($quiet, plainOptions()));
    def other as slides.Deck init slides.parse("# C\n\n```rust\nfn main() \{\}\n```\n\n" +
        "```\nplain\n```\n");
    testing.assertEqual(render($other, defaults()), render($other, plainOptions()));
    testing.assertEqual(
        documentFailure(slides.parse("---\nhighlight: 1\n---\n# C\n")),
        "highlight");
    testing.assertEqual(documentFailure($quiet), "");
}

/**
 * A line too long for the panel is wrapped by the layout; both pieces are
 * coloured, and the text drawn is still the line.
 */
func testWrappedLineIsColoured() {
    def long as string init "io.printf(\"" + strings.replicate("word ", 40) + "\", $value);";
    def deck as slides.Deck init slides.parse("# W\n\n```jennifer\n" + $long + "\n```\n");
    def got as string init contentOf(document($deck, defaults()));
    def s as theme.Syntax init theme.printSyntax(theme.theme("plain", "light"));
    testing.assertContains($got, colourOp($s.builtin) + "\n(io) Tj");
    testing.assertContains($got, colourOp($s.variable) + "\n($value) Tj");
    testing.assertEqual(
        pageCount($deck, defaults()),
        pdf.getTotalPages(document($deck, plainOptions())));
}

/** Highlighting adds no page, so the overflow warning counts the same. */
func testOverflowCountIsUnchanged() {
    def body as string init "# Tall\n\n```sh\n";
    for (def i as int init 0; $i < 60; $i = $i + 1) {
        $body = $body + "echo \"line {$i}\" # and a comment\n";
    }
    def deck as slides.Deck init slides.parse($body + "```\n");
    def coloured as int init pageCount($deck, defaults());
    testing.assertTrue($coloured > 1);
    testing.assertEqual($coloured, pdf.getTotalPages(document($deck, plainOptions())));
    def got as string init contentOf(document($deck, defaults()));
    testing.assertContains($got, "(\"line 59\") Tj");
    testing.assertEqual(render($deck, defaults()), render($deck, defaults()));
}

/** The plan lists every block in document order, coloured or not. */
func testPaintPlan() {
    def tree as doctree.Node init markdown.parse(
        "```js\nlet a;\n```\n\n- x\n\n  ```\n  b\n  ```\n\n```sh\necho →\n```\n");
    testing.assertEqual(len(codeNodes($tree)), 3);
    def s as theme.Syntax init theme.printSyntax(theme.theme("plain", "light"));
    def plan as list of Painted init paintPlan($tree, $s, "?");
    testing.assertEqual(len($plan), 3);
    testing.assertTrue($plan[0].coloured);
    testing.assertFalse($plan[1].coloured);
    testing.assertTrue($plan[2].coloured);
    # The arrow cannot be drawn; the layout prints "?", and so does the plan.
    def last as PaintLine init $plan[2].lines[0];
    testing.assertEqual(strings.join($last.chars, ""), "echo ?");
    testing.assertEqual($last.colours[0], colourOp($s.builtin));
    testing.assertEqual($last.colours[5], colourOp(""));
}

/** Lines split where the source breaks, one colour and slant per character. */
func testPaintLines() {
    def s as theme.Syntax init theme.printSyntax(theme.theme("plain", "light"));
    def lines as list of PaintLine init paintLines("# a\n\nx = 1", "python", $s, "?");
    testing.assertEqual(len($lines), 3);
    testing.assertEqual(len($lines[1].chars), 0);
    testing.assertTrue($lines[0].italic[0]);
    testing.assertFalse($lines[2].italic[0]);
    testing.assertEqual($lines[2].colours[4], colourOp($s.number));
}

/** A colour operator is the one `pdf` writes. */
func testColourOp() {
    testing.assertEqual(colourOp(""), "0 0 0 rg");
    testing.assertEqual(colourOp("#ff0000"), "1 0 0 rg");
    testing.assertEqual(colourOp("#000"), "0 0 0 rg");
}

/** A character is escaped the way `pdf` escapes text for a standard font. */
func testPdfChar() {
    testing.assertEqual(pdfChar("a"), "a");
    testing.assertEqual(pdfChar("("), "\\(");
    testing.assertEqual(pdfChar(")"), "\\)");
    testing.assertEqual(pdfChar("\\"), "\\\\");
    testing.assertEqual(pdfChar("é"), "\\351");
    testing.assertEqual(pdfChar("\t"), "\\011");
}

/**
 * A run that is not the expected text leaves the rest of its block as it was
 * laid out; the panel still gets its real shade.
 */
func testPaintCodeMismatchStaysPlain() {
    def lay as doctree.PdfOptions init doctree.pdfDefaults();
    def real as doctree.Fill init doctree.rgb(240, 240, 240);
    def mark as theme.Rgb init theme.hexRgb(CODE_MARK);
    def pg as pdf.Page init pdf.color(pdf.page(200, 200), $mark.red, $mark.green, $mark.blue);
    $pg = pdf.text($pg, 10, 100, "Courier", $lay.bodySize, "other text");
    def doc as pdf.Document init pdf.addPage(pdf.document(), $pg);
    def s as theme.Syntax init theme.printSyntax(theme.theme("plain", "light"));
    def plan as Plan init Plan{blocks: paintPlan(markdown.parse("```js\nlet x;\n```\n"), $s, "?")};
    def got as pdf.Document init paintCode($doc, $plan, $lay, $real);
    testing.assertContains($got.pages[0].content, "(other text) Tj");
    testing.assertFalse(strings.contains($got.pages[0].content, colourOp(CODE_MARK)));
    testing.assertContains($got.pages[0].content, colourOp("#f0f0f0"));
}

/** The pen writes the mono font, its oblique face, and the real shade. */
func testInk() {
    def lay as doctree.PdfOptions init doctree.pdfDefaults();
    $lay.bodySize = 13;
    def pen as Ink init ink($lay, doctree.rgb(255, 0, 0));
    testing.assertEqual($pen.fontLine, "/Courier 13 Tf");
    testing.assertEqual($pen.slantLine, "/Courier-Oblique 13 Tf");
    testing.assertEqual($pen.shade[0], "1 0 0 rg");
    testing.assertEqual($pen.shade[1], "1 0 0 RG");
    testing.assertEqual($pen.mark[0], colourOp(CODE_MARK));
    testing.assertEqual($pen.black, "0 0 0 rg");
    $lay.monoFont = "Times-Roman";
    testing.assertEqual(ink($lay, doctree.noFill()).slantLine, "");
}

/** A run is matched against the line it continues, escapes included. */
func testRunEnd() {
    def s as theme.Syntax init theme.printSyntax(theme.theme("plain", "light"));
    def pl as PaintLine init paintLines("f(a) b", "js", $s, "?")[0];
    testing.assertEqual(runEnd($pl, 0, "f\\(a\\) b"), 6);
    testing.assertEqual(runEnd($pl, 0, "f\\(a"), 3);
    testing.assertEqual(runEnd($pl, 3, "\\) b"), 6);
    testing.assertEqual(runEnd($pl, 0, "g"), -1);
    testing.assertEqual(runEnd($pl, 0, ""), -1);
    def empty as PaintLine init PaintLine{chars: [], colours: [], italic: []};
    testing.assertEqual(runEnd($empty, 0, ""), 0);
}

/** A run is drawn one `Tj` per colour, and the colour is reset after it. */
func testDrawRun() {
    def s as theme.Syntax init theme.printSyntax(theme.theme("plain", "light"));
    def lay as doctree.PdfOptions init doctree.pdfDefaults();
    def pen as Ink init ink($lay, doctree.noFill());
    def pl as PaintLine init paintLines("let x; // c", "js", $s, "?")[0];
    def got as list of string init drawRun($pl, 0, len($pl.chars), $pen);
    testing.assertEqual($got[0], colourOp($s.keyword));
    testing.assertEqual($got[1], "(let) Tj");
    testing.assertEqual($got[2], "0 0 0 rg");
    testing.assertEqual($got[3], "( x; ) Tj");
    testing.assertTrue(lists.contains($got, $pen.slantLine));
    testing.assertTrue(lists.contains($got, "(// c) Tj"));
    testing.assertEqual($got[len($got) - 1], "0 0 0 rg");
    testing.assertEqual(drawRun($pl, 2, 2, $pen), ["() Tj"]);
}

/** A page is painted from where the previous one left off. */
func testPaintPage() {
    def s as theme.Syntax init theme.printSyntax(theme.theme("plain", "light"));
    def lay as doctree.PdfOptions init doctree.pdfDefaults();
    def pen as Ink init ink($lay, doctree.rgb(240, 240, 240));
    def plan as Plan init Plan{
        blocks: paintPlan(markdown.parse("```js\nlet a\nlet b\n```\n"), $s, "?")
    };
    def blank as pdf.Page init pdf.page(9, 9);
    def run as string init pdf.text($blank, 1, 2, "Courier", $lay.bodySize, "let a").content;
    def src as list of string init [$pen.mark[0], $pen.mark[1]];
    for (def line in strings.split(strings.trimRight($run), "\n")) {
        $src[] = $line;
    }
    def start as Cursor init Cursor{
        next: 0,
        active: false,
        block: 0,
        line: 0,
        at: 0,
        slanted: false
    };
    def got as PagePaint init paintPage($src, $plan, $pen, $start);
    testing.assertEqual(
        $got.lines[0],
        "0.9411764705882353 0.9411764705882353 0.9411764705882353 rg");
    testing.assertTrue(lists.contains($got.lines, "(let) Tj"));
    testing.assertTrue($got.cursor.active);
    testing.assertEqual($got.cursor.line, 1);
    testing.assertEqual($got.cursor.next, 1);
}

/** A slide's number sits under its right edge, not at the left margin with the footer. */
func testHandoutNumbersOnTheRight() {
    def got as pdf.Document init handout(slidePages(3), theme.stage("16:9"), "", pdf.pageLabel());
    def body as string init $got.pages[0].content;
    def m as regex.Match init regex.find('([0-9.]+) [0-9.]+ Td\n\(3\) Tj', $body);
    testing.assertTrue($m.start >= 0);
    def frame as regex.Match init regex.find('RG ([0-9.]+) [0-9.]+ ([0-9.]+) [0-9.]+ re S', $body);
    def right as float init convert.toFloat($frame.groups[0]) + convert.toFloat($frame.groups[1]);
    def numX as float init convert.toFloat($m.groups[0]);
    testing.assertTrue($numX > convert.toFloat(HANDOUT_MARGIN) + 100.0);
    testing.assertTrue($numX < $right and $right - $numX < 10.0);
}

# --- MathML ------------------------------------------------------------

def const MATH as string init '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi>' +
    '<annotation encoding="application/x-tex">x^2</annotation></math>';

# The PDF prints the TeX source a MathML element carries, in monospace; a deck
# without maths is laid out untouched.
func testMathMlPrintsItsTexSource() {
    def deck as slides.Deck init slides.parse("# M\n\nInline " + MATH + " here.\n");
    def lay as doctree.PdfOptions init layout($deck, defaults());
    def tree as doctree.Node init printableMaths(markdown.parse($deck.slides[0].body), $lay);
    def text as string init doctree.text($tree);
    testing.assertContains($text, "x^2");
    testing.assertFalse(strings.contains($text, "<math"));
    def plain as doctree.Node init markdown.parse("# P\n\ntext\n");
    testing.assertEqual(printableMaths($plain, $lay), $plain);
    def pages as int init pageCount($deck, defaults());
    testing.assertEqual($pages, 1);
}

# --- notes beside handout slides --------------------------------------

func testNotesAreWrappedIntoTheColumn() {
    def lines as list of string init noteLayout(
        "Open with why this exists: a deck belongs in version control.",
        90.0,
        200.0);
    testing.assertTrue(len($lines) > 1);
    for (def line in $lines) {
        testing.assertTrue(pdf.measureText("Helvetica", HANDOUT_NOTE_SIZE, $line) <= 90);
    }
    testing.assertEqual(
        strings.join($lines, " "),
        "Open with why this exists: a deck belongs in version control.");
}

func testABlankLineStartsAParagraph() {
    def lines as list of string init noteLayout("one\ntwo\n\nthree", 200.0, 200.0);
    testing.assertEqual($lines, ["one two", "", "three"]);
}

func testNotesTooLongForTheSlideAreCut() {
    def long as string init "";
    for (def i in 0..80) {
        $long = $long + "word" + convert.toString($i) + " ";
    }
    def room as float init convert.toFloat(5 * HANDOUT_NOTE_LEADING);
    def lines as list of string init noteLayout($long, 90.0, $room);
    testing.assertEqual(len($lines), 5);
    testing.assertTrue(strings.endsWith($lines[4], "..."));
}

func testNothingToPrintIsNoLines() {
    testing.assertEqual(len(noteLayout("", 90.0, 200.0)), 0);
    testing.assertEqual(len(noteLayout("  \n ", 90.0, 200.0)), 0);
    testing.assertEqual(len(noteLayout("text", 90.0, 5.0)), 0);
    def word as list of string init noteLayout("abcdefghijklmnopqrstuvwxyz", 30.0, 200.0);
    testing.assertTrue(len($word) > 1);
    testing.assertEqual(strings.join($word, ""), "abcdefghijklmnopqrstuvwxyz");
}

# The notes go on the handout page beside their slide; the page count does not
# change, and a slide without notes keeps its ruled column.
func testHandoutWithPrintsTheNotes() {
    def plain as pdf.Document init handout(slidePages(4), theme.stage("16:9"), "", pdf.pageLabel());
    def got as pdf.Document init handoutWith(
        slidePages(4),
        theme.stage("16:9"),
        "",
        pdf.pageLabel(),
        ["Say hello first.", "", "Third slide notes."]);
    testing.assertEqual(len($got.pages), len($plain.pages));
    testing.assertContains($got.pages[0].content, "Say hello first.");
    testing.assertContains($got.pages[0].content, "Third slide notes.");
    testing.assertFalse(strings.contains($plain.pages[0].content, "Say hello"));
    testing.assertTrue(HANDOUT_NOTE_LEADING > HANDOUT_NOTE_SIZE);
}
