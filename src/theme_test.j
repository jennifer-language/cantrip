# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

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
        theme($name, "");
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
    testing.assertEqual(theme("", "").name, DEFAULT_THEME);
    testing.assertEqual(mode(""), DEFAULT_MODE);
    testing.assertFalse(theme("", "").dark);
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
        testing.assertEqual(theme($name, "light").name, $name);
        testing.assertEqual(theme($name, "dark").name, $name);
    }
    for (def name in ratios()) {
        testing.assertEqual(stage($name).name, $name);
    }
}

/** A theme name and a mode are matched case-insensitively and trimmed. */
func testThemeLookupIsLenient() {
    testing.assertEqual(theme("  NORDIC  ", "").name, "nordic");
    testing.assertTrue(theme("Solar", " Dark ").dark);
    testing.assertEqual(mode(" LIGHT "), "light");
}

/** Every theme has exactly one light and one dark palette, sharing fonts and radius. */
func testEveryThemeHasBothModes() {
    for (def name in names()) {
        def light as Theme init theme($name, "light");
        def dark as Theme init theme($name, "dark");
        testing.assertFalse($light.dark);
        testing.assertTrue($dark.dark);
        testing.assertEqual($dark.headingFont, $light.headingFont);
        testing.assertEqual($dark.bodyFont, $light.bodyFont);
        testing.assertEqual($dark.monoFont, $light.monoFont);
        testing.assertEqual($dark.radius, $light.radius);
    }
    testing.assertEqual(modes(), ["light", "dark", "auto"]);
}

/** A mode other than light, dark or auto is refused, naming the three. */
func testModeUnknown() {
    try {
        mode("sepia");
        testing.assertTrue(false);
    } catch (e) {
        testing.assertEqual($e.kind, "theme");
        testing.assertContains($e.message, "sepia");
        testing.assertContains($e.message, "light, dark, auto");
    }
    try {
        theme("plain", "dim");
        testing.assertTrue(false);
    } catch (e) {
        testing.assertEqual($e.kind, "theme");
    }
}

/** The names of cantrip 0.1 that carried the mode are refused with the new spelling. */
func testOldDarkNamesAreRefusedWithAHint() {
    try {
        theme("nordic-dark", "");
        testing.assertTrue(false);
    } catch (e) {
        testing.assertEqual($e.kind, "theme");
        testing.assertContains($e.message, "use theme: nordic with mode: dark");
    }
    try {
        theme("Midnight", "");
        testing.assertTrue(false);
    } catch (e) {
        testing.assertContains($e.message, "use theme: plain with mode: dark");
    }
    try {
        theme("nope-dark", "");
        testing.assertTrue(false);
    } catch (e) {
        testing.assertContains($e.message, "known: plain");
    }
}

/** An unknown theme names the ones that exist. */
func testThemeUnknown() {
    testing.assertEqual(themeFailure("nope"), "theme");
    testing.assertEqual(themeFailure("Plain "), "");
    try {
        theme("nope", "");
        testing.assertTrue(false);
    } catch (e) {
        testing.assertContains($e.message, "nordic");
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
    for (def t in all()) {
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
    testing.assertEqual(len(all()), 2 * len(names()));
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
        testing.assertTrue(hasTheme($name));
        testing.assertEqual(theme($name, "dark").printCodeBg, theme($name, "light").printCodeBg);
    }
    testing.assertEqual(theme("nordic", "light").accent, "#5e81ac");
    testing.assertEqual(theme("nordic", "dark").background, "#2e3440");
    testing.assertEqual(theme("terminal", "light").bodyFont, MONO);
    testing.assertEqual(theme("grimoire", "light").headingFont, SERIF);
    testing.assertEqual(theme("grimoire", "light").bodyFont, SANS);
}

/** The heading colour and radius reach the stylesheet. */
func testCssCarriesHeadingAndRadius() {
    def out as string init css(theme("nordic", "light"), theme("nordic", "dark"), stage("16:9"));
    testing.assertContains($out, "--heading: #2e3440;");
    testing.assertContains($out, "--radius: 6px;");
    testing.assertContains($out, "color: var(--heading);");
}

/**
 * The help overlay and the notes panel are dark in every theme, so their key
 * caps and code spans carry their own light text colour instead of the
 * theme's code colour, which is dark in a light theme.
 */
func testOverlaysSetTheirOwnTextColour() {
    for (def name in ["plain", "sepia", "carbon"]) {
        def out as string init css(theme($name, "light"), theme($name, "dark"), stage("16:9"));
        def at as int init strings.indexOf($out, 'body > #cantrip-help kbd {');
        testing.assertTrue($at >= 0);
        def rule as string init strings.substring($out, $at, strings.indexOf($out, '}', $at));
        testing.assertContains($rule, "color: #e6e8ee;");
        testing.assertContains($out, 'body > #cantrip-notes code, body > #cantrip-notes kbd {');
    }
}

/** Every transition has its rules, and reduced motion turns them all off. */
func testCssCoversTransitions() {
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    for (def name in ["fade", "slide", "zoom"]) {
        testing.assertContains($out, "body > #cantrip-deck[data-transition=\"" + $name + "\"]");
    }
    testing.assertContains($out, "@media (prefers-reduced-motion: reduce)");
    testing.assertContains(
        $out,
        "body > #cantrip-deck.cantrip-ready:not([data-transition=\"none\"]) > .cantrip-slide");
}

/**
 * A swipe turns the slide, so the page turns off the browser's own swipe
 * gestures, and the touch bar is out of sight until the script shows it.
 */
func testCssKeepsSwipesForTheSlides() {
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    testing.assertContains($out, "overscroll-behavior: none;");
    testing.assertContains($out, 'body > #cantrip-touchbar { display: none; }');
    testing.assertContains($out, '#cantrip-touchbar.cantrip-touch.cantrip-shown { opacity: 1;');
}

/**
 * A column aligned with `:-:` or `--:` keeps its alignment in the browser: the
 * cells carry `align`, which the left-aligning default rule would override.
 */
func testCssHonoursColumnAlignment() {
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    testing.assertContains($out, 'th[align="center"], td[align="center"] { text-align: center; }');
    testing.assertContains($out, 'th[align="right"], td[align="right"] { text-align: right; }');
}

/** A dark theme's background is darker than its text, and the reverse. */
func testPalettePolarity() {
    for (def t in all()) {
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
    for (def t in all()) {
        def c as Rgb init hexRgb($t.printCodeBg);
        testing.assertTrue($c.red + $c.green + $c.blue > 660);
    }
}

/** A print quote rule still shows against white paper. */
func testPrintQuoteBarShows() {
    for (def t in all()) {
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
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    for (def token in strings.split($out, "%")) {
        testing.assertFalse(strings.startsWith($token, "bg%"));
    }
    testing.assertFalse(strings.contains($out, "%light%"));
    testing.assertFalse(strings.contains($out, "%dark%"));
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
            def out as string init css(theme($name, "light"), theme($name, "dark"), stage($ratio));
            testing.assertFalse(strings.contains($out, "%bg%"));
            testing.assertFalse(strings.contains($out, "%w%"));
            testing.assertTrue(len($out) > 1000);
        }
    }
}

/**
 * The stylesheet carries both of the theme's palettes, the light one at the
 * root and the dark one under data-mode="dark", and its geometry.
 */
func testCssCarriesTheTheme() {
    def light as Theme init theme("plain", "light");
    def t as Theme init theme("plain", "dark");
    def s as Stage init stage("4:3");
    def out as string init css($light, $t, $s);
    def at as int init strings.indexOf($out, ':root[data-mode="dark"] {');
    testing.assertTrue($at > 0);
    testing.assertTrue(strings.indexOf($out, "--bg: " + $light.background + ";") < $at);
    testing.assertTrue(strings.indexOf($out, "--bg: " + $t.background + ";") > $at);
    testing.assertContains($out, "color-scheme: dark;");
    testing.assertContains($out, "color-scheme: light;");
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
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    testing.assertContains($out, "left: 50%;");
    testing.assertContains($out, "top: 50%;");
    testing.assertContains(
        $out,
        "margin: calc(var(--stage-h) * -0.5px) 0 0 calc(var(--stage-w) * -0.5px);");
    testing.assertFalse(strings.contains($out, "transform: translate("));
    testing.assertFalse(strings.contains($out, "place-items: center;\n    overflow: hidden;"));
}

/**
 * Every rule for a part of the slideshow names it by its prefixed id or class
 * and anchors it at a child of `body` or at a slide, so a heading carrying
 * `{#help .slide}` or `{#cantrip-help}` from the deck matches none of them.
 */
func testCssSelectorsAreScoped() {
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    for (def line in strings.split($out, "\n")) {
        def bare as string init strings.trim($line);
        if (strings.contains($bare, "#cantrip-") or strings.contains($bare, ".cantrip-")) {
            testing.assertTrue(
                strings.startsWith($bare, "body > #cantrip-") or
                    strings.startsWith($bare, ".cantrip-slide > "));
        }
    }
    def unprefixed as list of string init [
        "#deck",
        "#help",
        "#notes",
        "#overview",
        "#progress",
        ".slide",
        ".thumb"
    ];
    for (def bareName in $unprefixed) {
        testing.assertFalse(strings.contains($out, $bareName));
    }
}

/** The stylesheet styles the structure the HTML renderer emits. */
func testCssCoversTheMarkup() {
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    def selectors as list of string init [
        'body > #cantrip-deck > .cantrip-slide {',
        "body > #cantrip-deck > .cantrip-slide.cantrip-current",
        'body > #cantrip-deck {',
        'body > #cantrip-progress {',
        'body > #cantrip-notes {',
        'body > #cantrip-help {',
        'body > #cantrip-overview {',
        'body > #cantrip-overview > .cantrip-thumb {',
        '.cantrip-slide > div.cantrip-slide-number {',
        '.cantrip-slide > div.cantrip-slide-footer {',
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
    testing.assertContains($raw, "%light%");
    testing.assertContains($raw, "%dark%");
    testing.assertContains($raw, "%w%");
    testing.assertContains($raw, "%monofont%");
}

/** A palette becomes the custom properties of one `:root` rule, with its colour scheme. */
func testPalette() {
    def dark as string init palette(theme("nordic", "dark"));
    testing.assertContains($dark, "    --bg: #2e3440;\n");
    testing.assertContains($dark, "    color-scheme: dark;\n");
    testing.assertContains(palette(theme("nordic", "light")), "    color-scheme: light;\n");
    testing.assertFalse(strings.contains($dark, "%"));
}

/**
 * Every token colour of every palette reaches its contrast against the code
 * background it is drawn on: AA everywhere, AAA in `contrast`; on screen in
 * both modes, and in the PDF on the print shade.
 */
func testTokenColoursAreLegible() {
    def classes as list of string init [
        "comment",
        "keyword",
        "type",
        "literal",
        "string",
        "number",
        "variable",
        "symbol",
        "built_in",
        "title"
    ];
    for (def t in all()) {
        def screen as Syntax init syntax($t);
        def paper as Syntax init printSyntax($t);
        for (def cls in $classes) {
            testing.assertTrue(contrast(tokenColour($screen, $cls), $t.codeBg) >=
                minContrast($t.name));
            testing.assertTrue(
                contrast(tokenColour($paper, $cls), $t.printCodeBg) >= minContrast($t.name));
        }
    }
    testing.assertEqual(minContrast("contrast"), HIGH_CONTRAST);
    testing.assertEqual(minContrast("nordic"), MIN_CONTRAST);
    testing.assertTrue(MIN_CONTRAST >= 4.5);
}

/**
 * The shared themes start from Grimoire's token colours, and a colour that
 * already reads on its background is kept as it is.
 */
func testSyntaxBaseMatchesGrimoire() {
    testing.assertEqual(syntaxBase("nordic", false).keyword, "#a626a4");
    testing.assertEqual(syntaxBase("nordic", true).keyword, "#c678dd");
    testing.assertEqual(syntaxBase("plain", true).quoted, "#98c379");
    testing.assertEqual(syntaxBase("solar", false).keyword, syntaxBase("solar", true).keyword);
    testing.assertNotEqual(
        syntaxBase("contrast", false).keyword,
        syntaxBase("plain", false).keyword);
    testing.assertEqual(syntax(theme("carbon", "dark")).keyword, "#c678dd");
    testing.assertEqual(
        printSyntax(theme("carbon", "dark")),
        printSyntax(theme("carbon", "light")));
}

/** The WCAG arithmetic, on the cases with known answers. */
func testContrast() {
    testing.assertEqual(luminance("#ffffff"), 1.0);
    testing.assertEqual(luminance("#000000"), 0.0);
    testing.assertTrue(contrast("#000000", "#ffffff") > 20.99);
    testing.assertEqual(contrast("#123456", "#abcdef"), contrast("#abcdef", "#123456"));
    testing.assertEqual(contrast("#777777", "#777777"), 1.0);
}

/** A colour too faint is darkened on light ground and lightened on dark. */
func testLegible() {
    testing.assertEqual(legible("#000000", "#ffffff", 4.5), "#000000");
    def dim as string init legible("#9aa0a6", "#f4f5f7", 4.5);
    testing.assertNotEqual($dim, "#9aa0a6");
    testing.assertTrue(contrast($dim, "#f4f5f7") >= 4.5);
    testing.assertTrue(luminance($dim) < luminance("#9aa0a6"));
    def lit as string init legible("#586e75", "#073642", 4.5);
    testing.assertTrue(contrast($lit, "#073642") >= 4.5);
    testing.assertTrue(luminance($lit) > luminance("#586e75"));
}

func testRgbHex() {
    testing.assertEqual(rgbHex(Rgb{red: 1, green: 2, blue: 255}), "#0102ff");
    testing.assertEqual(rgbHex(hexRgb("#A0b1C2")), "#a0b1c2");
}

/** Each highlight.js class maps to a colour; plain text and unknown classes to none. */
func testTokenColour() {
    def s as Syntax init syntax(theme("plain", "light"));
    testing.assertEqual(tokenColour($s, "keyword"), $s.keyword);
    testing.assertEqual(tokenColour($s, "name"), $s.keyword);
    testing.assertEqual(tokenColour($s, "meta"), $s.comment);
    testing.assertEqual(tokenColour($s, "attr"), $s.symbol);
    testing.assertEqual(tokenColour($s, "section"), $s.title);
    testing.assertEqual(tokenColour($s, "string"), $s.quoted);
    testing.assertEqual(tokenColour($s, "type"), $s.typeName);
    testing.assertEqual(tokenColour($s, "built_in"), $s.builtin);
    testing.assertEqual(tokenColour($s, ""), "");
    testing.assertEqual(tokenColour($s, "bogus"), "");
}

/** Both palettes carry their token colours, and the stylesheet uses them. */
func testCssColoursTokens() {
    def dark as Theme init theme("nordic", "dark");
    testing.assertContains(palette($dark), "    --syn-keyword: " + syntax($dark).keyword + ";\n");
    testing.assertContains(syntaxProperties(syntax($dark)), "--syn-title: ");
    def out as string init css(theme("nordic", "light"), $dark, stage("16:9"));
    testing.assertContains($out, "--syn-comment: " + syntax(theme("nordic", "light")).comment);
    testing.assertContains($out, "--syn-comment: " + syntax($dark).comment);
    for (def cls in ["comment", "keyword", "type", "string", "number", "variable", "title"]) {
        testing.assertContains($out, "pre > code > .hljs-" + $cls);
    }
}

/**
 * auto follows the reader's system: the dark palette applies under
 * prefers-color-scheme: dark while the page is in auto, and a palette looked
 * up for auto is the light one.
 */
func testAutoModeFollowsTheSystem() {
    testing.assertEqual(mode(" Auto "), "auto");
    testing.assertFalse(theme("plain", "auto").dark);
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    def at as int init strings.indexOf($out, '@media (prefers-color-scheme: dark) {');
    testing.assertTrue($at > 0);
    def block as string init $out[$at..];
    testing.assertContains($block, ':root[data-mode="auto"] {');
    testing.assertContains($block, "color-scheme: dark;");
}

/**
 * A picture is capped in stage pixels: a percentage height has nothing to
 * resolve against on a slide, and a diagram SVG that only says width="100%"
 * would be stretched to the slide width and run off the bottom.
 */
func testPicturesAreCappedByTheStageHeight() {
    def out as string init css(theme("plain", "light"), theme("plain", "dark"), stage("16:9"));
    def at as int init strings.indexOf($out, "\n" + 'img {');
    testing.assertTrue($at > 0);
    def rest as string init $out[$at..];
    def rule as string init $rest[..strings.indexOf($rest, '}')];
    testing.assertContains($rule, "max-height: calc(var(--stage-h) * 0.6px);");
    testing.assertContains($rule, "width: auto;");
    testing.assertFalse(strings.contains($rule, "max-height: 70%"));
}
