# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

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
        "theme: midnight\nratio: 4:3\n---\n" +
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
    testing.assertEqual(pickTheme(fixture(), $opts).name, "midnight");
    $opts.theme = "solar";
    testing.assertEqual(pickTheme(fixture(), $opts).name, "solar");
    testing.assertEqual(pickTheme(slides.parse("# H"), defaults()).name, theme.DEFAULT_THEME);
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
    testing.assertContains($got, "<section class=\"slide\" id=\"slide-1\"");
    testing.assertContains($got, "data-n=\"1\"");
    testing.assertContains($got, "aria-label=\"One &amp; Only\"");
    testing.assertContains($got, "<div class=\"slide-number\">1 / 2</div>");
    testing.assertContains($got, "Foot &amp; Co");
    testing.assertContains($got, "slide-notes");
    testing.assertContains($got, "</section>");
}

/** Turning the furniture off leaves it out. */
func testSectionWithoutFurniture() {
    def slide as slides.Slide init fixture().slides[0];
    def opts as Options init defaults();
    $opts.numbers = false;
    $opts.notes = false;
    def got as string init section($slide, 2, $opts);
    testing.assertFalse(strings.contains($got, "slide-number"));
    testing.assertFalse(strings.contains($got, "slide-notes"));
    testing.assertFalse(strings.contains($got, "slide-footer"));
}

/** A slide with no notes carries no notes element even when notes are on. */
func testSectionNoNotes() {
    def slide as slides.Slide init fixture().slides[1];
    testing.assertFalse(strings.contains(section($slide, 2, defaults()), "slide-notes"));
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
    testing.assertContains($got, "id=\"overview\"");
    testing.assertContains($got, "hidden");
    testing.assertContains($got, "data-go=\"1\"");
    testing.assertContains($got, "data-go=\"2\"");
    testing.assertEqual(len(strings.split($got, "data-go=")), 3);
}

/** An empty deck still produces a well-formed, empty overview. */
func testOverviewEmpty() {
    def got as string init overview(slides.parse(""));
    testing.assertContains($got, "id=\"overview\"");
    testing.assertFalse(strings.contains($got, "data-go="));
}

/** The head carries the metadata, escaped, plus the stylesheet. */
func testHead() {
    def deck as slides.Deck init fixture();
    def got as string init head($deck, theme.theme("midnight"), theme.stage("4:3"));
    testing.assertContains($got, "<meta charset=\"utf-8\">");
    testing.assertContains($got, "name=\"viewport\"");
    testing.assertContains($got, "content=\"cantrip\"");
    testing.assertContains($got, "content=\"A &lt;a@b&gt;\"");
    testing.assertContains($got, "content=\"2026-01-01\"");
    testing.assertContains($got, "content=\"dark\"");
    testing.assertContains($got, "<title>T &amp; \"Q\"</title>");
    testing.assertContains($got, "<style>");
    testing.assertContains($got, "</head>");
}

/** A deck with no metadata gets a usable title and no empty meta tags. */
func testHeadWithoutMetadata() {
    def deck as slides.Deck init slides.parse("no heading at all");
    def got as string init head($deck, theme.theme("plain"), theme.stage("16:9"));
    testing.assertContains($got, "<title>Slides</title>");
    testing.assertFalse(strings.contains($got, "name=\"author\""));
    testing.assertFalse(strings.contains($got, "name=\"date\""));
}

/** The colour scheme follows the theme's polarity. */
func testColorScheme() {
    testing.assertEqual(colorScheme(theme.theme("midnight")), "dark");
    testing.assertEqual(colorScheme(theme.theme("contrast")), "dark");
    testing.assertEqual(colorScheme(theme.theme("plain")), "light");
    testing.assertEqual(colorScheme(theme.theme("sepia")), "light");
}

/** The help panel documents the keys the script actually binds. */
func testHelpPanel() {
    def got as string init helpPanel();
    def js as string init script();
    testing.assertContains($got, "id=\"help\"");
    testing.assertContains($got, "hidden");
    for (def key in ["o", "s", "f", "?"]) {
        testing.assertContains($got, "<kbd>" + $key + "</kbd>");
        testing.assertContains($js, "=== \"" + $key + "\"");
    }
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
    testing.assertContains($got, "<html lang=\"en\">");
    testing.assertEqual(len(strings.split($got, "<section class=\"slide\"")), 3);
    testing.assertEqual(len(strings.split($got, "</section>")), 3);
    testing.assertContains($got, "id=\"progress\"");
    testing.assertContains($got, "id=\"deck\"");
    testing.assertContains($got, "id=\"notes\"");
    testing.assertContains($got, "id=\"overview\"");
    testing.assertContains($got, "id=\"help\"");
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
    testing.assertFalse(strings.contains($got, "id=\"notes\""));
    testing.assertContains($got, "notes && !notes.hidden");
}

/** An empty deck renders a valid document with no slides. */
func testRenderEmpty() {
    def got as string init render(slides.parse(""), defaults());
    testing.assertTrue(strings.startsWith($got, "<!doctype html>"));
    testing.assertFalse(strings.contains($got, "<section class=\"slide\""));
}

/** Every theme and ratio renders without leaving a placeholder behind. */
func testRenderEveryTheme() {
    for (def name in theme.names()) {
        def opts as Options init defaults();
        $opts.theme = $name;
        def got as string init render(fixture(), $opts);
        testing.assertFalse(strings.contains($got, "%bg%"));
        testing.assertContains($got, theme.theme($name).background);
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
    testing.assertContains($got, "querySelectorAll(\".slide\")");
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
    testing.assertContains($got, "toggle(\"past\", i < at)");
    testing.assertContains($got, "toggle(\"current\", i === at)");
    testing.assertContains($got, "toggle(\"future\", i > at)");
    testing.assertContains($got, "deck.classList.add(\"ready\")");
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
