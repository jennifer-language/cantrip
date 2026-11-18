# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * White-box tests for the HTML slideshow renderer.
 * @module htmloutTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;

/**
 * A two-slide deck with notes, metadata, and inline markup to escape.
 * @return {slides.Deck} the fixture every test here renders
 */
func fixture() {
    return slides.parse("---\ntitle: T & \"Q\"\nauthor: A <a@b>\ndate: 2026-01-01\n" +
        "theme: plain\nmode: dark\nratio: 4:3\n---\n" +
        "# One & Only\n\nText with **bold**.\n\n<!-- notes: say this -->\n\n" +
        "---\n\n## Two\n\n- a\n- b\n");
}

/**
 * Render a theme or ratio and report how it failed.
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

/** The generator name is the command's own name. */
func testGenerator() {
    testing.assertEqual(GENERATOR, "cantrip");
}

/** The defaults are safe: notes on, numbers on, raw HTML off. */
func testDefaults() {
    def opts as Options init defaults();
    testing.assertEqual($opts.theme, "");
    testing.assertEqual($opts.ratio, "");
    testing.assertEqual($opts.footer, "");
    testing.assertTrue($opts.notes);
    testing.assertTrue($opts.numbers);
    testing.assertFalse($opts.rawHtml);
}

/** An option overrides front matter, which overrides the default. */
func testPickTheme() {
    def opts as Options init defaults();
    testing.assertEqual(pickTheme(fixture(), $opts).name, "plain");
    testing.assertTrue(pickTheme(fixture(), $opts).dark);
    $opts.theme = "solar";
    testing.assertEqual(pickTheme(fixture(), $opts).name, "solar");
    $opts.mode = "light";
    testing.assertFalse(pickTheme(fixture(), $opts).dark);
    testing.assertEqual(pickTheme(slides.parse("# H"), defaults()).name, theme.DEFAULT_THEME);
    testing.assertFalse(pickTheme(slides.parse("# H"), defaults()).dark);
}

/** The same precedence holds for the stage. */
func testPickStage() {
    def opts as Options init defaults();
    testing.assertEqual(pickStage(fixture(), $opts).name, "4:3");
    $opts.ratio = "16:9";
    testing.assertEqual(pickStage(fixture(), $opts).name, "16:9");
    testing.assertEqual(pickStage(slides.parse("# H"), defaults()).name, theme.DEFAULT_RATIO);
}

/** An unknown name is a catchable theme error, not a silent default. */
func testPickRejectsUnknown() {
    testing.assertEqual(themeFailure("nope"), "theme");
    testing.assertEqual(themeFailure("solar"), "");
    testing.assertEqual(ratioFailure("21:9"), "theme");
    testing.assertEqual(ratioFailure("16:9"), "");
}

/** An attribute value escapes the quote that would end it. */
func testAttrValue() {
    testing.assertEqual(attrValue("a \" b"), "a &quot; b");
    testing.assertEqual(attrValue("a & b"), "a &amp; b");
    testing.assertEqual(attrValue("<x>"), "&lt;x&gt;");
    testing.assertEqual(attrValue("plain"), "plain");
    testing.assertEqual(attrValue(""), "");
}

/** Escaping an attribute leaves no bare quote behind. */
func testAttrValueCannotBreakOut() {
    def hostile as string init "\" onload=\"alert(1)";
    def got as string init attrValue($hostile);
    testing.assertFalse(strings.contains($got, "\""));
    testing.assertContains($got, "&quot;");
}

/** A slide body renders as Markdown, with raw HTML escaped by default. */
func testBody() {
    def slide as slides.Slide init fixture().slides[0];
    def got as string init body($slide, defaults());
    testing.assertContains($got, "<h1>");
    testing.assertContains($got, "<strong>bold</strong>");
}

/** Raw HTML is escaped unless the caller opts in. */
func testBodyRawHtml() {
    def slide as slides.Slide init slides.parse("<div>raw</div>").slides[0];
    testing.assertContains(body($slide, defaults()), "&lt;div&gt;");
    def opts as Options init defaults();
    $opts.rawHtml = true;
    testing.assertContains(body($slide, $opts), "<div>raw</div>");
}

/** A section carries its number, its label, and its furniture. */
func testSection() {
    def slide as slides.Slide init fixture().slides[0];
    def opts as Options init defaults();
    $opts.footer = "Foot & Co";
    def got as string init section($slide, 2, $opts);
    testing.assertContains($got, "<section class=\"cantrip-slide\" id=\"cantrip-slide-1\"");
    testing.assertContains($got, "data-n=\"1\"");
    testing.assertContains($got, "aria-label=\"One &amp; Only\"");
    testing.assertContains($got, "<div class=\"cantrip-slide-number\">1 / 2</div>");
    testing.assertContains($got, "Foot &amp; Co");
    testing.assertContains($got, "cantrip-slide-notes");
    testing.assertContains($got, "</section>");
}

/** Turning the furniture off leaves it out. */
func testSectionWithoutFurniture() {
    def slide as slides.Slide init fixture().slides[0];
    def opts as Options init defaults();
    $opts.numbers = false;
    $opts.notes = false;
    def got as string init section($slide, 2, $opts);
    testing.assertFalse(strings.contains($got, "cantrip-slide-number"));
    testing.assertFalse(strings.contains($got, "cantrip-slide-notes"));
    testing.assertFalse(strings.contains($got, "cantrip-slide-footer"));
}

/** A slide with no notes carries no notes element even when notes are on. */
func testSectionNoNotes() {
    def slide as slides.Slide init fixture().slides[1];
    testing.assertFalse(strings.contains(section($slide, 2, defaults()), "cantrip-slide-notes"));
}

/** A slide's label is its heading, else its number. */
func testLabel() {
    testing.assertEqual(label(fixture().slides[0]), "One & Only");
    def bare as slides.Slide init slides.parse("no heading").slides[0];
    testing.assertEqual(label($bare), "Slide 1");
}

/** The overview holds one jump target per slide. */
func testOverview() {
    def got as string init overview(fixture());
    testing.assertContains($got, "id=\"cantrip-overview\"");
    testing.assertContains($got, "hidden");
    testing.assertContains($got, "data-go=\"1\"");
    testing.assertContains($got, "data-go=\"2\"");
    testing.assertEqual(len(strings.split($got, "data-go=")), 3);
}

/** An empty deck still produces a well-formed, empty overview. */
func testOverviewEmpty() {
    def got as string init overview(slides.parse(""));
    testing.assertContains($got, "id=\"cantrip-overview\"");
    testing.assertFalse(strings.contains($got, "data-go="));
}

/** The head carries the metadata, escaped, plus the stylesheet. */
func testHead() {
    def deck as slides.Deck init fixture();
    def got as string init head($deck, "plain", theme.stage("4:3"));
    testing.assertContains($got, "<meta charset=\"utf-8\">");
    testing.assertContains($got, "name=\"viewport\"");
    testing.assertContains($got, "content=\"cantrip\"");
    testing.assertContains($got, "content=\"A &lt;a@b&gt;\"");
    testing.assertContains($got, "content=\"2026-01-01\"");
    testing.assertContains($got, ':root[data-mode="dark"] {');
    testing.assertContains($got, "<title>T &amp; &quot;Q&quot;</title>");
    testing.assertContains($got, "<style>");
    testing.assertContains($got, "</head>");
}

/** A deck with no metadata gets a usable title and no empty meta tags. */
func testHeadWithoutMetadata() {
    def deck as slides.Deck init slides.parse("no heading at all");
    def got as string init head($deck, "plain", theme.stage("16:9"));
    testing.assertContains($got, "<title>Slides</title>");
    testing.assertFalse(strings.contains($got, "name=\"author\""));
    testing.assertFalse(strings.contains($got, "name=\"date\""));
    testing.assertFalse(strings.contains($got, "name=\"description\""));
    testing.assertFalse(strings.contains($got, "name=\"keywords\""));
}

/** `description` and `keywords` become meta tags; `subject` stands in for a missing description. */
func testHeadSearchMetadata() {
    def own as slides.Deck init slides.parse("---\ndescription: Why <this>\nsubject: S\n" +
        "keywords: a, b\n---\n# X\n");
    def got as string init head($own, "plain", theme.stage("16:9"));
    testing.assertContains($got, "<meta name=\"description\" content=\"Why &lt;this&gt;\">");
    testing.assertContains($got, "<meta name=\"keywords\" content=\"a, b\">");
    def fallback as slides.Deck init slides.parse("---\nsubject: From the PDF\n---\n# X\n");
    testing.assertContains(
        head($fallback, "plain", theme.stage("16:9")),
        "<meta name=\"description\" content=\"From the PDF\">");
}

/**
 * The page opens in the mode `--mode` or the `mode:` of the deck names, else light,
 * and the script lets the viewer switch it with m or `?mode=`.
 */
func testModeInPage() {
    testing.assertContains(render(fixture(), defaults()), "<html lang=\"en\" data-mode=\"dark\">");
    def opts as Options init defaults();
    $opts.mode = "light";
    testing.assertContains(render(fixture(), $opts), "data-mode=\"light\">");
    testing.assertContains(render(slides.parse("# H"), defaults()), "data-mode=\"light\">");
    $opts.mode = "auto";
    def kind as string init "";
    try {
        render(fixture(), $opts);
    } catch (e) {
        $kind = $e.kind;
    }
    testing.assertEqual($kind, "theme");
    def js as string init script();
    testing.assertContains($js, "query.get(\"mode\")");
    testing.assertContains($js, "root.dataset.mode");
}

/** The help panel documents the keys the script actually binds. */
func testHelpPanel() {
    def got as string init helpPanel();
    def js as string init script();
    testing.assertContains($got, "id=\"cantrip-help\"");
    testing.assertContains($got, "hidden");
    for (def key in ["o", "s", "m", "f", "?"]) {
        testing.assertContains($got, "<kbd>" + $key + "</kbd>");
        testing.assertContains($js, "=== \"" + $key + "\"");
    }
}

/** The touch bar has a button per key action, notes only with the panel. */
func testTouchBar() {
    def got as string init touchBar(true);
    def js as string init script();
    testing.assertContains($got, "id=\"cantrip-touchbar\"");
    for (def act in ["overview", "notes", "mode", "fullscreen"]) {
        testing.assertContains($got, "data-act=\"" + $act + "\"");
        testing.assertContains($js, "act === \"" + $act + "\"");
    }
    testing.assertFalse(strings.contains(touchBar(false), "data-act=\"notes\""));
    def page as string init render(slides.parse("# One"), defaults());
    testing.assertContains($page, "id=\"cantrip-touchbar\"");
}

/** The document language comes from front matter, defaulting to English. */
func testLanguage() {
    testing.assertEqual(language(slides.parse("---\nlang: de\n---\n# H")), "de");
    testing.assertEqual(language(slides.parse("# H")), "en");
}

/** A rendered deck is one well-formed document holding every slide. */
func testRender() {
    def got as string init render(fixture(), defaults());
    testing.assertTrue(strings.startsWith($got, "<!doctype html>"));
    testing.assertTrue(strings.endsWith($got, "</html>\n"));
    testing.assertContains($got, "<html lang=\"en\" data-mode=\"dark\">");
    testing.assertEqual(len(strings.split($got, "<section class=\"cantrip-slide\"")), 3);
    testing.assertEqual(len(strings.split($got, "</section>")), 3);
    testing.assertContains($got, "id=\"cantrip-progress\"");
    testing.assertContains($got, "id=\"cantrip-deck\"");
    testing.assertContains($got, "id=\"cantrip-notes\"");
    testing.assertContains($got, "id=\"cantrip-overview\"");
    testing.assertContains($got, "id=\"cantrip-help\"");
    testing.assertContains($got, "<script>");
}

/** The stage's geometry reaches the script through the deck element. */
func testRenderCarriesGeometry() {
    def got as string init render(fixture(), defaults());
    testing.assertContains($got, "data-w=\"1024\"");
    testing.assertContains($got, "data-h=\"768\"");
}

/** With notes off there is no notes panel for the script to find. */
func testRenderWithoutNotes() {
    def opts as Options init defaults();
    $opts.notes = false;
    def got as string init render(fixture(), $opts);
    testing.assertFalse(strings.contains($got, "id=\"cantrip-notes\""));
    testing.assertContains($got, "notes && !notes.hidden");
}

/**
 * Ids and classes a deck gives its headings cannot stand in for the
 * slideshow's own parts: the parts are prefixed, the script finds each one as
 * a child of `body` (a heading never is), and the slides as children of the
 * deck element, so the heading keeps its attributes and the slide count holds.
 */
func testHeadingAttributesCannotCollide() {
    # Raw strings: a brace in a cooked string opens an interpolation slot.
    def src as string init strings.join(
        [
            '## A {#cantrip-help .cantrip-slide}',
            "",
            "---",
            "",
            '## B {#help .slide}',
            "",
            '## C {#cantrip-deck .cantrip-slide-notes}',
            "",
            '## D {#overview}',
            "",
            "<!-- notes: n -->"
        ],
        "\n");
    def got as string init render(slides.parse($src), defaults());
    testing.assertEqual(len(strings.split($got, "<section class=\"cantrip-slide\"")), 3);
    testing.assertContains($got, "<h2 id=\"cantrip-help\" class=\"cantrip-slide\">A</h2>");
    testing.assertContains($got, "<h2 id=\"help\" class=\"slide\">B</h2>");
    def js as string init script();
    testing.assertFalse(strings.contains($js, "getElementById"));
    testing.assertFalse(strings.contains($js, "document.querySelectorAll"));
    testing.assertContains($js, "document.querySelector(\"body > #cantrip-\" + id)");
    testing.assertContains($js, "deck.querySelectorAll(\":scope > .cantrip-slide\")");
    testing.assertContains($js, "querySelector(\":scope > div.cantrip-slide-notes:last-child\")");
    testing.assertContains($js, "notes.querySelector(\":scope > #cantrip-notes-body\")");
}

/** An empty deck renders a valid document with no slides. */
func testRenderEmpty() {
    def got as string init render(slides.parse(""), defaults());
    testing.assertTrue(strings.startsWith($got, "<!doctype html>"));
    testing.assertFalse(strings.contains($got, "<section class=\"cantrip-slide\""));
}

/** Every theme and ratio renders without leaving a placeholder behind. */
func testRenderEveryTheme() {
    for (def name in theme.names()) {
        def opts as Options init defaults();
        $opts.theme = $name;
        def got as string init render(fixture(), $opts);
        testing.assertFalse(strings.contains($got, "%bg%"));
        testing.assertContains($got, theme.theme($name, "light").background);
        testing.assertContains($got, theme.theme($name, "dark").background);
    }
}

/** The script opens and closes its own braces, and binds what it needs. */
func testScript() {
    def got as string init script();
    # Braces need a raw literal: a cooked "{" opens an interpolation slot.
    testing.assertEqual(len(strings.split($got, '{')), len(strings.split($got, '}')));
    testing.assertEqual(len(strings.split($got, "(")), len(strings.split($got, ")")));
    testing.assertFalse(strings.contains($got, "'"));
    testing.assertContains($got, "keydown");
    testing.assertContains($got, "hashchange");
    testing.assertContains($got, "resize");
    testing.assertContains($got, "querySelectorAll(\":scope > .cantrip-slide\")");
}

/** A key cap in prose renders as a real `<kbd>` element. */
func testKeyCaps() {
    def got as string init body(slides.parse("Press <kbd>s</kbd> now.").slides[0], defaults());
    testing.assertContains($got, "<kbd>s</kbd>");
    testing.assertFalse(strings.contains($got, "&lt;kbd&gt;"));
}

/** A key cap shown as code stays escaped, inline or in a block. */
func testKeyCapsLeavesCode() {
    def src as string init "Write `<kbd>x</kbd>`.\n\n```html\n<kbd>y</kbd>\n```\n\n<kbd>z</kbd>";
    def got as string init body(slides.parse($src).slides[0], defaults());
    testing.assertContains($got, "<code>&lt;kbd&gt;x&lt;/kbd&gt;</code>");
    testing.assertContains($got, "&lt;kbd&gt;y&lt;/kbd&gt;");
    testing.assertContains($got, "<kbd>z</kbd>");
    testing.assertEqual(keyCaps("<p>plain</p>"), "<p>plain</p>");
}

/** Only the bare tags are restored; anything carrying attributes stays text. */
func testUnescapeKbd() {
    testing.assertEqual(unescapeKbd("&lt;kbd&gt;s&lt;/kbd&gt;"), "<kbd>s</kbd>");
    def hostile as string init "&lt;kbd onclick=&quot;x&quot;&gt;s&lt;/kbd&gt;";
    testing.assertFalse(strings.contains(unescapeKbd($hostile), "<kbd onclick"));
}

/** Notes render their key caps too. */
func testKeyCapsInNotes() {
    def deck as slides.Deck init slides.parse("# A\n\n<!-- notes: press <kbd>f</kbd> -->");
    testing.assertContains(section($deck.slides[0], 1, defaults()), "<kbd>f</kbd>");
}

/**
 * The script fits with a bare scale about the slide centre, and marks every
 * slide past, current, or future for the transitions to animate.
 */
func testScriptMarksSlidesForTransitions() {
    def got as string init script();
    testing.assertContains($got, "s.style.transform = \"scale(\" + k + \")\"");
    testing.assertFalse(strings.contains($got, "translate(-50%"));
    testing.assertContains($got, "toggle(\"cantrip-past\", i < at)");
    testing.assertContains($got, "toggle(\"cantrip-current\", i === at)");
    testing.assertContains($got, "toggle(\"cantrip-future\", i > at)");
    testing.assertContains($got, "deck.classList.add(\"cantrip-ready\")");
}

/** Every transition is known, and the default is one of them. */
func testTransitions() {
    testing.assertEqual(transitions(), ["none", "fade", "slide", "zoom"]);
    testing.assertContains(transitions(), DEFAULT_TRANSITION);
    testing.assertEqual(defaults().transition, "");
}

/** An option beats the front matter, which beats the default. */
func testPickTransition() {
    def plain as slides.Deck init slides.parse("# A");
    def asked as slides.Deck init slides.parse("---\ntransition: Zoom\n---\n# A");
    testing.assertEqual(pickTransition($plain, defaults()), DEFAULT_TRANSITION);
    testing.assertEqual(pickTransition($asked, defaults()), "zoom");
    def opts as Options init defaults();
    $opts.transition = " slide ";
    testing.assertEqual(pickTransition($asked, $opts), "slide");
}

/** An unknown transition is refused by name, with the known ones listed. */
func testPickTransitionUnknown() {
    def opts as Options init defaults();
    $opts.transition = "spin";
    def message as string init "";
    try {
        pickTransition(slides.parse("# A"), $opts);
    } catch (e) {
        testing.assertEqual($e.kind, "theme");
        $message = $e.message;
    }
    testing.assertContains($message, "spin");
    testing.assertContains($message, "zoom");
}

/** The chosen transition lands on the deck element, where the CSS reads it. */
func testRenderCarriesTransition() {
    def opts as Options init defaults();
    $opts.transition = "slide";
    testing.assertContains(render(slides.parse("# A"), $opts), "data-transition=\"slide\"");
    testing.assertContains(render(slides.parse("# A"), defaults()), "data-transition=\"fade\"");
}

/**
 * A key handled on an overview thumbnail stops there, so a space that picks a
 * slide is not also read by the deck as "next slide".
 */
func testScriptStopsThumbnailKeys() {
    testing.assertContains(script(), "e.stopPropagation();");
}

/** The script never carries a stray interpolation slot. */
func testScriptHasNoTemplatePlaceholders() {
    testing.assertFalse(strings.contains(script(), "%w%"));
    testing.assertFalse(strings.contains(script(), "%h%"));
}

/**
 * A two-slide deck whose front matter sets the start options.
 * @param lines {string} front-matter lines, each ending in a newline
 * @return {slides.Deck} the deck
 */
func startDeck(lines as string) {
    return slides.parse("---\n" + $lines + "---\n# One\n\n<!-- notes: n -->\n\n---\n\n## Two\n");
}

/**
 * Resolve the start options and report how they failed.
 * @param deck {slides.Deck} the deck
 * @param opts {Options} the options
 * @return {string} "kind: message", "" when it did not throw
 */
func startFailure(deck as slides.Deck, opts as Options) {
    try {
        pickStart($deck, $opts);
    } catch (e) {
        return $e.kind + ": " + $e.message;
    }
    return "";
}

/** With nothing set, the slideshow opens closed on slide 1, as before. */
func testPickStartDefaults() {
    testing.assertEqual(
        pickStart(fixture(), defaults()),
        Start{notes: false, slide: 1, overview: false});
    def got as string init render(fixture(), defaults());
    testing.assertContains(
        $got,
        " data-notes=\"closed\" data-slide=\"1\" data-overview=\"closed\">");
}

/** The front matter sets the start; values are case-insensitive. */
func testPickStartFromFrontMatter() {
    def deck as slides.Deck init startDeck("notes: Open\nslide: 2\noverview: open\n");
    testing.assertEqual(pickStart($deck, defaults()), Start{notes: true, slide: 2, overview: true});
    testing.assertContains(
        render($deck, defaults()),
        " data-notes=\"open\" data-slide=\"2\" data-overview=\"open\">");
}

/** An option (the command line) wins over the front matter. */
func testPickStartOptionsWin() {
    def deck as slides.Deck init startDeck("notes: open\nslide: 2\noverview: open\n");
    def opts as Options init defaults();
    $opts.startNotes = "closed";
    $opts.startSlide = "1";
    $opts.startOverview = "closed";
    testing.assertEqual(pickStart($deck, $opts), Start{notes: false, slide: 1, overview: false});
    def only as Options init defaults();
    $only.startNotes = "open";
    testing.assertEqual(
        pickStart(startDeck("slide: 2\n"), $only),
        Start{notes: true, slide: 2, overview: false});
}

/** A bad value in the front matter is refused at build time. */
func testPickStartRejectsBadValues() {
    testing.assertEqual(
        startFailure(startDeck("notes: yes\n"), defaults()),
        "start: notes wants open or closed, got \"yes\"");
    testing.assertContains(
        startFailure(startDeck("overview: 1\n"), defaults()),
        "overview wants open or closed");
    testing.assertContains(
        startFailure(startDeck("slide: 0\n"), defaults()),
        "slide wants a slide number from 1");
    testing.assertContains(
        startFailure(startDeck("slide: two\n"), defaults()),
        "slide wants a slide number");
    testing.assertEqual(
        startFailure(startDeck("slide: 3\n"), defaults()),
        "start: slide 3 is past the end; the deck has 2 slide(s)");
}

/** Open notes in a page built without them are an error, not ignored. */
func testPickStartOpenNotesNeedNotes() {
    def opts as Options init defaults();
    $opts.notes = false;
    testing.assertContains(
        startFailure(startDeck("notes: open\n"), $opts),
        "notes: open needs the notes");
    testing.assertEqual(startFailure(startDeck("notes: closed\n"), $opts), "");
    $opts.startNotes = "open";
    testing.assertContains(startFailure(fixture(), $opts), "notes: open needs the notes");
}

/** The script reads the start from the deck, lets the URL override it, and keeps s. */
func testScriptStart() {
    def js as string init script();
    testing.assertContains($js, 'var query = new URLSearchParams(location.search);');
    testing.assertContains($js, 'if (v === "1") { return true; }');
    testing.assertContains($js, 'if (v === "0") { return false; }');
    testing.assertContains(
        $js,
        'var startNotes = asked("notes", deck.dataset.notes === "open" && roomy);');
    testing.assertContains(
        $js,
        'var startOverview = asked("overview", deck.dataset.overview === "open");');
    testing.assertContains($js, 'return isNaN(n) ? startSlide : n - 1;');
    testing.assertContains($js, 'else if (k === "s" && notes) { setNotes(notes.hidden); }');
    testing.assertContains($js, '(min-width: 800px) and (min-height: 560px)');
}

/** open / closed is case-insensitive; "" is closed; anything else is refused. */
func testOpenClosed() {
    testing.assertTrue(openClosed("notes", "open"));
    testing.assertTrue(openClosed("notes", "OPEN"));
    testing.assertFalse(openClosed("notes", "closed"));
    testing.assertFalse(openClosed("notes", ""));
    testing.assertThrowsWith("openClosed", ["notes", "1"], "start");
}

/** `--theme` and `--mode` win over the front matter, which wins over the defaults. */
func testThemeNameAndPickMode() {
    def opts as Options init defaults();
    testing.assertEqual(themeName(fixture(), $opts), "plain");
    testing.assertEqual(pickMode(fixture(), $opts), "dark");
    testing.assertEqual(themeName(slides.parse("# H"), $opts), "");
    testing.assertEqual(pickMode(slides.parse("# H"), $opts), "light");
    $opts.theme = "ivy";
    $opts.mode = " Light ";
    testing.assertEqual(themeName(fixture(), $opts), "ivy");
    testing.assertEqual(pickMode(fixture(), $opts), "light");
}
