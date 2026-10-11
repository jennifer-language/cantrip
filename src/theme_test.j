# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box tests for the themes and the stage geometry.
 * @module themeTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;

/**
 * Assert that a call threw a catchable error of `kind`.
 *
 * `testing.assertThrows` takes a zero-argument method name, so a per-case
 * wrapper would be needed for each bad input; catching in place is shorter
 * and keeps the input beside its expectation.
 * @param kind {string} the Error kind the call should carry
 * @param threw {bool} whether the call threw
 * @param got {string} the kind it threw, "" when it did not throw
 */
func assertThrewKind(kind as string, threw as bool, got as string) {
    testing.assertTrue($threw);
    testing.assertEqual($got, $kind);
}

/**
 * Look up a theme and report how it failed.
 * @param name {string} the theme name to try
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func themeFailure(name as string) {
    try {
        theme($name);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * Look up a stage and report how it failed.
 * @param name {string} the ratio name to try
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func stageFailure(name as string) {
    try {
        stage($name);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * Parse a colour and report how it failed.
 * @param hex {string} the colour to try
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func hexFailure(hex as string) {
    try {
        hexRgb($hex);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * Read a channel and report how it failed.
 * @param bare {string} six hex digits to try
 * @param at {int} the channel offset
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func channelFailure(bare as string, at as int) {
    try {
        channel($bare, $at);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/** The defaults name real entries, so a blank request always resolves. */
func testDefaults() {
    testing.assertTrue(hasTheme(DEFAULT_THEME));
    testing.assertTrue(hasRatio(DEFAULT_RATIO));
    testing.assertEqual(theme("").name, DEFAULT_THEME);
    testing.assertEqual(stage("").name, DEFAULT_RATIO);
}

/** The font stacks end in a generic family, so text renders everywhere. */
func testFontStacks() {
    testing.assertContains(SERIF, "serif");
    testing.assertContains(SANS, "sans-serif");
    testing.assertContains(MONO, "monospace");
}

/** The listings are non-empty and every name they hold resolves. */
func testNames() {
    testing.assertTrue(len(names()) > 0);
    testing.assertTrue(len(ratios()) > 0);
    for (def name in names()) {
        testing.assertEqual(theme($name).name, $name);
    }
    for (def name in ratios()) {
        testing.assertEqual(stage($name).name, $name);
    }
}

/** A theme name is matched case-insensitively and trimmed. */
func testThemeLookupIsLenient() {
    testing.assertEqual(theme("  MIDNIGHT  ").name, "midnight");
    testing.assertEqual(theme("Solar").name, "solar");
}

/** An unknown theme names the ones that exist. */
func testThemeUnknown() {
    testing.assertEqual(themeFailure("nope"), "theme");
    testing.assertEqual(themeFailure("Midnight "), "");
    try {
        theme("nope");
        testing.assertTrue(false);
    } catch (e) {
        testing.assertContains($e.message, "midnight");
        testing.assertContains($e.message, "nope");
    }
}

/** An unknown ratio names the ones that exist. */
func testStageUnknown() {
    testing.assertEqual(stageFailure("21:9"), "theme");
    testing.assertEqual(stageFailure("16x9"), "theme");
    testing.assertEqual(stageFailure("16:9"), "");
}

/** Every palette fills every field, and the colours are hex. */
func testPalettesAreComplete() {
    for (def name in names()) {
        def t as Theme init theme($name);
        def colours as list of string init [
            $t.background,
            $t.foreground,
            $t.accent,
            $t.muted,
            $t.codeBg,
            $t.codeFg,
            $t.quoteBar,
            $t.printCodeBg,
            $t.printQuoteBar
        ];
        for (def colour in $colours) {
            testing.assertTrue(strings.startsWith($colour, "#"));
            testing.assertTrue(len($colour) == 7 or len($colour) == 4);
            hexRgb($colour);
        }
        testing.assertTrue(len($t.headingFont) > 0);
        testing.assertTrue(len($t.bodyFont) > 0);
        testing.assertTrue(len($t.monoFont) > 0);
    }
}

/** Every theme names itself, describes itself, and has a usable radius. */
func testThemesDescribeThemselves() {
    for (def t in all()) {
        testing.assertTrue(len($t.description) > 10);
        testing.assertTrue($t.radius >= 0 and $t.radius <= 16);
        hexRgb($t.heading);
    }
    testing.assertEqual(len(all()), len(names()));
}

/**
 * Every Grimoire theme is here under its own name, light and dark, so a deck
 * can match the manual it sits beside.
 */
func testMatchesGrimoire() {
    def grimoire as list of string init [
        "carbon",
        "ember",
        "grimoire",
        "ivy",
        "meridian",
        "nordic",
        "obsidian",
        "orchid",
        "sepia",
        "terminal"
    ];
    for (def name in $grimoire) {
        testing.assertFalse(theme($name).dark);
        testing.assertTrue(theme($name + "-dark").dark);
        testing.assertEqual(theme($name + "-dark").printCodeBg, theme($name).printCodeBg);
    }
    testing.assertEqual(theme("nordic").accent, "#5e81ac");
    testing.assertEqual(theme("nordic-dark").background, "#2e3440");
    testing.assertEqual(theme("terminal").bodyFont, MONO);
    testing.assertEqual(theme("grimoire").headingFont, SERIF);
    testing.assertEqual(theme("grimoire").bodyFont, SANS);
}

/** The heading colour and radius reach the stylesheet. */
func testCssCarriesHeadingAndRadius() {
    def out as string init css(theme("nordic"), stage("16:9"));
    testing.assertContains($out, "--heading: #2e3440;");
    testing.assertContains($out, "--radius: 6px;");
    testing.assertContains($out, "color: var(--heading);");
}

/** Every transition has its rules, and reduced motion turns them all off. */
func testCssCoversTransitions() {
    def out as string init css(theme("plain"), stage("16:9"));
    for (def name in ["fade", "slide", "zoom"]) {
        testing.assertContains($out, "#deck[data-transition=\"" + $name + "\"]");
    }
    testing.assertContains($out, "@media (prefers-reduced-motion: reduce)");
    testing.assertContains($out, "#deck.ready:not([data-transition=\"none\"]) .slide");
}

/** A dark theme's background is darker than its text, and the reverse. */
func testPalettePolarity() {
    for (def name in names()) {
        def t as Theme init theme($name);
        def bg as Rgb init hexRgb($t.background);
        def fg as Rgb init hexRgb($t.foreground);
        def bgSum as int init $bg.red + $bg.green + $bg.blue;
        def fgSum as int init $fg.red + $fg.green + $fg.blue;
        if ($t.dark) {
            testing.assertTrue($bgSum < $fgSum);
        } else {
            testing.assertTrue($bgSum > $fgSum);
        }
    }
}

/**
 * The PDF draws black text on white paper, so a theme's print shade must be
 * light enough to read black text on, whatever its screen polarity.
 */
func testPrintShadesAreLight() {
    for (def name in names()) {
        def t as Theme init theme($name);
        def c as Rgb init hexRgb($t.printCodeBg);
        testing.assertTrue($c.red + $c.green + $c.blue > 660);
    }
}

/** A print quote rule still shows against white paper. */
func testPrintQuoteBarShows() {
    for (def name in names()) {
        def t as Theme init theme($name);
        def c as Rgb init hexRgb($t.printQuoteBar);
        testing.assertTrue($c.red + $c.green + $c.blue < 660);
    }
}

/** Every stage has a positive, landscape geometry in both units. */
func testStageGeometry() {
    for (def name in ratios()) {
        def s as Stage init stage($name);
        testing.assertTrue($s.width > $s.height);
        testing.assertTrue($s.pageWidth > $s.pageHeight);
        testing.assertTrue($s.pageWidth > 0);
        testing.assertTrue($s.pageHeight > 0);
    }
    testing.assertEqual(stage("16:9").width, 1280);
    testing.assertEqual(stage("16:9").pageWidth, 960);
    testing.assertEqual(stage("4:3").pageHeight, 594);
}

/** A six-digit hex colour splits into its three channels. */
func testHexRgb() {
    def c as Rgb init hexRgb("#7aa2f7");
    testing.assertEqual($c.red, 122);
    testing.assertEqual($c.green, 162);
    testing.assertEqual($c.blue, 247);
    testing.assertEqual(hexRgb("#000000").red, 0);
    testing.assertEqual(hexRgb("ffffff").blue, 255);
}

/** A three-digit colour is expanded, not misread. */
func testHexRgbShort() {
    def c as Rgb init hexRgb("#abc");
    testing.assertEqual($c.red, 170);
    testing.assertEqual($c.green, 187);
    testing.assertEqual($c.blue, 204);
}

/** Case and surrounding space do not matter. */
func testHexRgbLenient() {
    testing.assertEqual(hexRgb("  #FFAA00  ").green, 170);
}

/** Anything that is not a hex colour is a catchable theme error. */
func testHexRgbRejects() {
    testing.assertEqual(hexFailure("#12345"), "theme");
    testing.assertEqual(hexFailure("#zzzzzz"), "theme");
    testing.assertEqual(hexFailure(""), "theme");
    testing.assertEqual(hexFailure("blue"), "theme");
    assertThrewKind("theme", hexFailure("#1") != "", hexFailure("#1"));
}

/** One channel is read from its own two digits. */
func testChannel() {
    testing.assertEqual(channel("ff8000", 0), 255);
    testing.assertEqual(channel("ff8000", 2), 128);
    testing.assertEqual(channel("ff8000", 4), 0);
    testing.assertEqual(channelFailure("gg0000", 0), "theme");
    testing.assertEqual(channelFailure("ff8000", 0), "");
}

/** Membership tests agree with the listings. */
func testHasThemeAndRatio() {
    testing.assertTrue(hasTheme("plain"));
    testing.assertTrue(hasTheme("  PLAIN "));
    testing.assertFalse(hasTheme("nope"));
    testing.assertFalse(hasTheme(""));
    testing.assertTrue(hasRatio("16:9"));
    testing.assertFalse(hasRatio("21:9"));
}

/** Every placeholder the template uses is one `css` substitutes. */
func testTemplateHasNoLeftoverPlaceholders() {
    def out as string init css(theme("plain"), stage("16:9"));
    for (def token in strings.split($out, "%")) {
        testing.assertFalse(strings.startsWith($token, "bg%"));
    }
    testing.assertFalse(strings.contains($out, "%bg%"));
    testing.assertFalse(strings.contains($out, "%fg%"));
    testing.assertFalse(strings.contains($out, "%accent%"));
    testing.assertFalse(strings.contains($out, "%muted%"));
    testing.assertFalse(strings.contains($out, "%codebg%"));
    testing.assertFalse(strings.contains($out, "%codefg%"));
    testing.assertFalse(strings.contains($out, "%quotebar%"));
    testing.assertFalse(strings.contains($out, "%headingfont%"));
    testing.assertFalse(strings.contains($out, "%bodyfont%"));
    testing.assertFalse(strings.contains($out, "%monofont%"));
    testing.assertFalse(strings.contains($out, "%w%"));
    testing.assertFalse(strings.contains($out, "%h%"));
}

/** No theme leaves a placeholder behind. */
func testEveryThemeSubstitutesFully() {
    for (def name in names()) {
        for (def ratio in ratios()) {
            def out as string init css(theme($name), stage($ratio));
            testing.assertFalse(strings.contains($out, "%bg%"));
            testing.assertFalse(strings.contains($out, "%w%"));
            testing.assertTrue(len($out) > 1000);
        }
    }
}

/** The stylesheet carries the theme's own colours and geometry. */
func testCssCarriesTheTheme() {
    def t as Theme init theme("midnight");
    def s as Stage init stage("4:3");
    def out as string init css($t, $s);
    testing.assertContains($out, $t.background);
    testing.assertContains($out, $t.accent);
    testing.assertContains($out, $t.monoFont);
    testing.assertContains($out, "1024");
    testing.assertContains($out, "768");
}

/**
 * A slide is centred by position, not by a grid: a grid track would not
 * shrink below the stage, pinning a slide to the corner of a small window.
 */
func testCssCentresTheStage() {
    def out as string init css(theme("plain"), stage("16:9"));
    testing.assertContains($out, "left: 50%;");
    testing.assertContains($out, "top: 50%;");
    testing.assertContains(
        $out,
        "margin: calc(var(--stage-h) * -0.5px) 0 0 calc(var(--stage-w) * -0.5px);");
    testing.assertFalse(strings.contains($out, "transform: translate("));
    testing.assertFalse(strings.contains($out, "place-items: center;\n    overflow: hidden;"));
}

/** The stylesheet styles the structure the HTML renderer emits. */
func testCssCoversTheMarkup() {
    def out as string init css(theme("plain"), stage("16:9"));
    def selectors as list of string init [
        ".slide",
        ".slide.current",
        "#deck",
        "#progress",
        "#notes",
        "#help",
        "#overview",
        ".slide-number",
        ".slide-footer",
        ".admonition",
        "li.task-list-item",
        "@media print",
        "@page"
    ];
    for (def selector in $selectors) {
        testing.assertContains($out, $selector);
    }
}

/** The raw template still holds its placeholders. */
func testTemplate() {
    def raw as string init template();
    testing.assertContains($raw, "%bg%");
    testing.assertContains($raw, "%w%");
    testing.assertContains($raw, "%monofont%");
}
