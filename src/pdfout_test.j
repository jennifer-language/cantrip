# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box tests for the PDF renderer.
 * @module pdfoutTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;
use maps;
use binary;
use convert;
use encoding;

/**
 * A three-slide deck with notes, an image, and a code block.
 * @return {slides.Deck} the fixture most tests here render
 */
func fixture() {
    return slides.parse("---\ntitle: Deck T\nauthor: Ada\nsubject: S\n" +
        "keywords: a, b\ntheme: midnight\nratio: 16:9\n---\n" +
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
    testing.assertEqual(pickTheme(fixture(), $opts).name, "midnight");
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
    def doc as markdown.Node init markdown.parse("![a](1.png)\n\n![b](2.png)\n");
    testing.assertEqual(collectImages($doc), ["1.png", "2.png"]);
}

/** The layout is two thirds of the printed page and carries the metadata. */
func testLayout() {
    def deck as slides.Deck init fixture();
    def got as markdown.PdfOptions init layout($deck, defaults());
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
 * A dark theme still prints light panels: the PDF draws black text on them,
 * so the screen's dark code shade would make code unreadable on paper.
 */
func testLayoutUsesPrintShades() {
    def got as markdown.PdfOptions init layout(fixture(), defaults());
    def t as theme.Theme init theme.theme("midnight");
    testing.assertEqual($got.codeFill, fill($t.printCodeBg));
    testing.assertEqual($got.quoteFill, fill($t.printCodeBg));
    testing.assertEqual($got.tableHeaderFill, fill($t.printCodeBg));
    testing.assertEqual($got.quoteRule, fill($t.printQuoteBar));
    testing.assertNotEqual($got.codeFill, fill($t.codeBg));
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
    def got as markdown.PdfOptions init layout(fixture(), $opts);
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

/** A rendered deck is a PDF of one page per slide. */
func testRender() {
    def out as bytes init render(fixture(), defaults());
    testing.assertTrue(len($out) > 500);
    def head as string init convert.stringFromBytes(binary.slice($out, 0, 5), "utf-8");
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
    testing.assertContains($got, "midnight");
}

/**
 * The smallest valid PNG, for the tests that need real image bytes.
 * @return {bytes} a 1x1 greyscale PNG
 */
func onePixelPng() {
    return encoding.fromText(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQAB" +
            "lpSm1gAAAABJRU5ErkJggg==",
        "base64");
}
