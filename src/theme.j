# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Presentation appearance: the named themes and the stage each deck is laid
 * out on.
 *
 * A theme is a palette plus three font stacks; a stage is the slide's pixel
 * geometry and the PDF page size that matches it. Both are plain values, so a
 * renderer asks for one and never decides what it looks like.
 * @module theme
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use strings;
use lists;
use convert;

/** The theme used when a deck names none. */
export def const DEFAULT_THEME as string init "plain";

/** The stage used when a deck names no ratio. */
export def const DEFAULT_RATIO as string init "16:9";

/**
 * A theme's palette and fonts.
 * @field name {string} the theme's name, as a caller would ask for it
 * @field description {string} one line on what it looks like, for `themes`
 * @field dark {bool} whether the palette is dark-on-light or light-on-dark
 * @field background {string} slide background colour
 * @field foreground {string} body text colour
 * @field heading {string} heading colour on screen
 * @field accent {string} link, rule, and progress-bar colour on screen
 * @field muted {string} secondary text (footer, slide numbers)
 * @field codeBg {string} background behind code
 * @field codeFg {string} code text colour
 * @field quoteBar {string} the rule down a blockquote's left edge
 * @field printCodeBg {string} code, quote, and table-header shade on white
 *     paper, for the PDF; light enough for the black text the PDF draws on it
 * @field printQuoteBar {string} the blockquote rule on white paper, for the PDF
 * @field headingFont {string} CSS font stack for headings
 * @field bodyFont {string} CSS font stack for body text
 * @field monoFont {string} CSS font stack for code
 * @field radius {int} corner radius of panels, in CSS pixels
 */
export def struct Theme {
    name as string,
    description as string,
    dark as bool,
    background as string,
    foreground as string,
    heading as string,
    accent as string,
    muted as string,
    codeBg as string,
    codeFg as string,
    quoteBar as string,
    printCodeBg as string,
    printQuoteBar as string,
    headingFont as string,
    bodyFont as string,
    monoFont as string,
    radius as int
};

/**
 * A slide's geometry, in CSS pixels and in PDF points.
 * @field name {string} the ratio's name, as a caller would ask for it
 * @field width {int} stage width in CSS pixels
 * @field height {int} stage height in CSS pixels
 * @field pageWidth {int} PDF page width in points
 * @field pageHeight {int} PDF page height in points
 */
export def struct Stage {
    name as string,
    width as int,
    height as int,
    pageWidth as int,
    pageHeight as int
};

/** A serif stack, for the book-like themes. */
export def const SERIF as string init "Iowan Old Style, Palatino, Georgia, serif";

/** A sans stack, for the screen themes. */
export def const SANS as string init "Inter, Helvetica Neue, Helvetica, Arial, sans-serif";

/** A monospace stack, for code. */
export def const MONO as string init "SFMono-Regular, Menlo, Consolas, monospace";

/**
 * Every theme this build ships, in listing order.
 *
 * The first four are Cantrip's own. The rest match the themes of
 * [Grimoire](https://grimoire.jennifer-lang.dev/), the Jennifer book builder,
 * name for name, so a deck can wear the same look as the manual beside it:
 * each Grimoire theme comes as `name` (its light palette) and `name-dark` (its
 * dark one). Whatever the screen palette, the PDF prints with the light
 * palette's code shade and accent, as Grimoire's own PDF does.
 * @return {list of Theme} the themes
 */
export func all() {
    return [
        Theme{
            name: "plain",
            description: "Black on white with a blue accent; the safe choice for a room you " +
                "have not seen.",
            dark: false,
            background: "#ffffff",
            foreground: "#1a1a1a",
            heading: "#1a4fa0",
            accent: "#1a4fa0",
            muted: "#6b7280",
            codeBg: "#f4f5f7",
            codeFg: "#1a1a1a",
            quoteBar: "#c7ccd4",
            printCodeBg: "#f4f5f7",
            printQuoteBar: "#c7ccd4",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 8
        },
        Theme{
            name: "midnight",
            description: "Near-black with a soft blue accent; good in a dark room, hard on a " +
                "sunlit one.",
            dark: true,
            background: "#11131a",
            foreground: "#e6e8ee",
            heading: "#7aa2f7",
            accent: "#7aa2f7",
            muted: "#8b93a7",
            codeBg: "#1b1f2a",
            codeFg: "#e6e8ee",
            quoteBar: "#3a4154",
            printCodeBg: "#eef1f7",
            printQuoteBar: "#a9b4cc",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 8
        },
        Theme{
            name: "solar",
            description: "The warm Solarized-light ground with a gold accent.",
            dark: false,
            background: "#fdf6e3",
            foreground: "#073642",
            heading: "#b58900",
            accent: "#b58900",
            muted: "#657b83",
            codeBg: "#eee8d5",
            codeFg: "#073642",
            quoteBar: "#d3cbb7",
            printCodeBg: "#eee8d5",
            printQuoteBar: "#d3cbb7",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 8
        },
        Theme{
            name: "contrast",
            description: "Pure black, pure white, yellow accent; for a bad projector or a large " +
                "room.",
            dark: true,
            background: "#000000",
            foreground: "#ffffff",
            heading: "#ffd400",
            accent: "#ffd400",
            muted: "#c8c8c8",
            codeBg: "#141414",
            codeFg: "#ffffff",
            quoteBar: "#5a5a5a",
            printCodeBg: "#f0f0f0",
            printQuoteBar: "#5a5a5a",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 8
        },
        Theme{
            name: "carbon",
            description: "Graphite and teal, dark-first; built for long technical reference.",
            dark: false,
            background: "#fbfbfc",
            foreground: "#31363f",
            heading: "#14171c",
            accent: "#0f8f8f",
            muted: "#6a7079",
            codeBg: "#f0f1f3",
            codeFg: "#2a2f36",
            quoteBar: "#d8dbe0",
            printCodeBg: "#f0f1f3",
            printQuoteBar: "#0f8f8f",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 5
        },
        Theme{
            name: "carbon-dark",
            description: "The dark palette of carbon.",
            dark: true,
            background: "#08090b",
            foreground: "#c8ccd4",
            heading: "#f2f4f8",
            accent: "#2fd4d4",
            muted: "#7b828d",
            codeBg: "#0c0e11",
            codeFg: "#c8ccd4",
            quoteBar: "#24282f",
            printCodeBg: "#f0f1f3",
            printQuoteBar: "#0f8f8f",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 5
        },
        Theme{
            name: "ember",
            description: "High-contrast mono-neutral with an orange accent; wide measure.",
            dark: false,
            background: "#ffffff",
            foreground: "#2b2b2b",
            heading: "#111111",
            accent: "#d2451e",
            muted: "#6b6b6b",
            codeBg: "#f6f6f6",
            codeFg: "#262626",
            quoteBar: "#e2e2e2",
            printCodeBg: "#f6f6f6",
            printQuoteBar: "#d2451e",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 3
        },
        Theme{
            name: "ember-dark",
            description: "The dark palette of ember.",
            dark: true,
            background: "#0a0a0a",
            foreground: "#d4d4d4",
            heading: "#fafafa",
            accent: "#ff7a45",
            muted: "#8a8a8a",
            codeBg: "#101010",
            codeFg: "#d4d4d4",
            quoteBar: "#2a2a2a",
            printCodeBg: "#f6f6f6",
            printQuoteBar: "#d2451e",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 3
        },
        Theme{
            name: "grimoire",
            description: "Warm parchment and ink with a rust accent; serif headings.",
            dark: false,
            background: "#fbf7f0",
            foreground: "#3a332b",
            heading: "#241f19",
            accent: "#a8531f",
            muted: "#7d7263",
            codeBg: "#f3ece0",
            codeFg: "#4a4038",
            quoteBar: "#ded1bd",
            printCodeBg: "#f3ece0",
            printQuoteBar: "#a8531f",
            headingFont: SERIF,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 7
        },
        Theme{
            name: "grimoire-dark",
            description: "The dark palette of grimoire.",
            dark: true,
            background: "#171412",
            foreground: "#ddd3c6",
            heading: "#f5ede1",
            accent: "#e8974e",
            muted: "#9b8e7e",
            codeBg: "#1c1917",
            codeFg: "#ddd3c6",
            quoteBar: "#372f29",
            printCodeBg: "#f3ece0",
            printQuoteBar: "#a8531f",
            headingFont: SERIF,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 7
        },
        Theme{
            name: "ivy",
            description: "Cream paper and forest green; serif body for long-form prose.",
            dark: false,
            background: "#fdfdf8",
            foreground: "#2f342c",
            heading: "#1a2018",
            accent: "#2f6b42",
            muted: "#6e7768",
            codeBg: "#f1f4ec",
            codeFg: "#333a30",
            quoteBar: "#d9e0d0",
            printCodeBg: "#f1f4ec",
            printQuoteBar: "#2f6b42",
            headingFont: SERIF,
            bodyFont: SERIF,
            monoFont: MONO,
            radius: 4
        },
        Theme{
            name: "ivy-dark",
            description: "The dark palette of ivy.",
            dark: true,
            background: "#10130f",
            foreground: "#ccd4c6",
            heading: "#eef3ea",
            accent: "#78c48d",
            muted: "#8b9584",
            codeBg: "#141812",
            codeFg: "#ccd4c6",
            quoteBar: "#2b3226",
            printCodeBg: "#f1f4ec",
            printQuoteBar: "#2f6b42",
            headingFont: SERIF,
            bodyFont: SERIF,
            monoFont: MONO,
            radius: 4
        },
        Theme{
            name: "meridian",
            description: "Deep navy on white with a steel-blue accent; the product-handbook " +
                "register.",
            dark: false,
            background: "#ffffff",
            foreground: "#1e3050",
            heading: "#0a1e3d",
            accent: "#175c96",
            muted: "#5a6d8c",
            codeBg: "#eff4fb",
            codeFg: "#213652",
            quoteBar: "#c8d7ea",
            printCodeBg: "#eff4fb",
            printQuoteBar: "#175c96",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 6
        },
        Theme{
            name: "meridian-dark",
            description: "The dark palette of meridian.",
            dark: true,
            background: "#0d1b30",
            foreground: "#c4d5ea",
            heading: "#e9f2ff",
            accent: "#6fb2e8",
            muted: "#7d95b5",
            codeBg: "#101f36",
            codeFg: "#c4d5ea",
            quoteBar: "#264066",
            printCodeBg: "#eff4fb",
            printQuoteBar: "#175c96",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 6
        },
        Theme{
            name: "nordic",
            description: "Arctic blue-grey after the Nord palette; muted, even, low-glare.",
            dark: false,
            background: "#fbfcfd",
            foreground: "#3b4252",
            heading: "#2e3440",
            accent: "#5e81ac",
            muted: "#6b7688",
            codeBg: "#edf1f5",
            codeFg: "#3b4252",
            quoteBar: "#d3dde7",
            printCodeBg: "#edf1f5",
            printQuoteBar: "#5e81ac",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 6
        },
        Theme{
            name: "nordic-dark",
            description: "The dark palette of nordic.",
            dark: true,
            background: "#2e3440",
            foreground: "#d8dee9",
            heading: "#eceff4",
            accent: "#88c0d0",
            muted: "#93a1b5",
            codeBg: "#313846",
            codeFg: "#d8dee9",
            quoteBar: "#4c566a",
            printCodeBg: "#edf1f5",
            printQuoteBar: "#5e81ac",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 6
        },
        Theme{
            name: "obsidian",
            description: "Cool slate with a violet accent; sans-serif throughout.",
            dark: false,
            background: "#ffffff",
            foreground: "#333a45",
            heading: "#10141b",
            accent: "#5b46d6",
            muted: "#6c7686",
            codeBg: "#f4f5f8",
            codeFg: "#2c3340",
            quoteBar: "#e0e3ea",
            printCodeBg: "#f4f5f8",
            printQuoteBar: "#5b46d6",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 6
        },
        Theme{
            name: "obsidian-dark",
            description: "The dark palette of obsidian.",
            dark: true,
            background: "#0d1017",
            foreground: "#c6cedb",
            heading: "#f0f4fa",
            accent: "#9d8bff",
            muted: "#7e8a9d",
            codeBg: "#111621",
            codeFg: "#c6cedb",
            quoteBar: "#262f40",
            printCodeBg: "#f4f5f8",
            printQuoteBar: "#5b46d6",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 6
        },
        Theme{
            name: "orchid",
            description: "Mauve-tinted paper with a violet-pink accent; friendly and light.",
            dark: false,
            background: "#faf5f9",
            foreground: "#403345",
            heading: "#251a2b",
            accent: "#a03a92",
            muted: "#756579",
            codeBg: "#f4ecf3",
            codeFg: "#3d3342",
            quoteBar: "#dccbdb",
            printCodeBg: "#f4ecf3",
            printQuoteBar: "#a03a92",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 8
        },
        Theme{
            name: "orchid-dark",
            description: "The dark palette of orchid.",
            dark: true,
            background: "#1a1220",
            foreground: "#e0d2e2",
            heading: "#f8ecf6",
            accent: "#e492d5",
            muted: "#a08faa",
            codeBg: "#1e1526",
            codeFg: "#e0d2e2",
            quoteBar: "#402e48",
            printCodeBg: "#f4ecf3",
            printQuoteBar: "#a03a92",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 8
        },
        Theme{
            name: "sepia",
            description: "Yellowed paper and deep coffee brown; full serif, warm through both " +
                "modes.",
            dark: false,
            background: "#f2e9d2",
            foreground: "#3d3222",
            heading: "#2a2114",
            accent: "#7a4a24",
            muted: "#6f6047",
            codeBg: "#ece2c8",
            codeFg: "#463a28",
            quoteBar: "#cfbf9a",
            printCodeBg: "#ece2c8",
            printQuoteBar: "#7a4a24",
            headingFont: SERIF,
            bodyFont: SERIF,
            monoFont: MONO,
            radius: 5
        },
        Theme{
            name: "sepia-dark",
            description: "The dark palette of sepia.",
            dark: true,
            background: "#221a12",
            foreground: "#e6d8bd",
            heading: "#f6ecd6",
            accent: "#cfa76a",
            muted: "#a4906f",
            codeBg: "#261d14",
            codeFg: "#e6d8bd",
            quoteBar: "#453626",
            printCodeBg: "#ece2c8",
            printQuoteBar: "#7a4a24",
            headingFont: SERIF,
            bodyFont: SERIF,
            monoFont: MONO,
            radius: 5
        },
        Theme{
            name: "terminal",
            description: "Monospace everywhere with a phosphor-green accent; a console in a " +
                "browser.",
            dark: false,
            background: "#fcfdfb",
            foreground: "#2c3329",
            heading: "#131912",
            accent: "#2f7d32",
            muted: "#6b7566",
            codeBg: "#f1f4ee",
            codeFg: "#2c3329",
            quoteBar: "#d3dbcc",
            printCodeBg: "#f1f4ee",
            printQuoteBar: "#2f7d32",
            headingFont: MONO,
            bodyFont: MONO,
            monoFont: MONO,
            radius: 2
        },
        Theme{
            name: "terminal-dark",
            description: "The dark palette of terminal.",
            dark: true,
            background: "#07090a",
            foreground: "#b9e6c2",
            heading: "#d8ffe0",
            accent: "#35e06a",
            muted: "#6f8f78",
            codeBg: "#0a0d0f",
            codeFg: "#b9e6c2",
            quoteBar: "#1f272a",
            printCodeBg: "#f1f4ee",
            printQuoteBar: "#2f7d32",
            headingFont: MONO,
            bodyFont: MONO,
            monoFont: MONO,
            radius: 2
        }
    ];
}

/**
 * Every theme name this build ships, in listing order.
 * @return {list of string} the names `theme` accepts
 */
export func names() {
    def out as list of string init [];
    for (def t in all()) {
        $out[] = $t.name;
    }
    return $out;
}

/**
 * Every ratio name this build ships, in listing order.
 * @return {list of string} the names `stage` accepts
 */
export func ratios() {
    return ["16:9", "16:10", "4:3"];
}

/**
 * Look up a theme by name.
 *
 * An empty name selects the default, so a deck with no `theme:` key and a
 * caller passing no `--theme` both land here.
 * @param name {string} a theme name, or "" for the default
 * @return {Theme} the named theme
 * @throws {Error} kind "theme" when the name is not one of `names()`
 */
export func theme(name as string) {
    def want as string init strings.lower(strings.trim($name));
    if ($want == "") {
        $want = DEFAULT_THEME;
    }
    for (def t in all()) {
        if ($t.name == $want) {
            return $t;
        }
    }
    throw Error{
        kind: "theme",
        message: "unknown theme \"" + $name + "\"; known: " +
            strings.join(names(), ", "),
        file: "",
        line: 0,
        col: 0
    };
}

/**
 * Look up a stage by ratio name.
 *
 * PDF page sizes are the pixel geometry scaled to a comfortable projected
 * size: 16:9 lands on 960x540 points, which is the slide size every PDF
 * viewer shows full-bleed without re-fitting.
 * @param name {string} a ratio name, or "" for the default
 * @return {Stage} the matching geometry
 * @throws {Error} kind "theme" when the name is not one of `ratios()`
 */
export func stage(name as string) {
    def want as string init strings.trim($name);
    if ($want == "") {
        $want = DEFAULT_RATIO;
    }
    if ($want == "16:9") {
        return Stage{name: "16:9", width: 1280, height: 720, pageWidth: 960, pageHeight: 540};
    }
    if ($want == "16:10") {
        return Stage{name: "16:10", width: 1280, height: 800, pageWidth: 960, pageHeight: 600};
    }
    if ($want == "4:3") {
        return Stage{name: "4:3", width: 1024, height: 768, pageWidth: 792, pageHeight: 594};
    }
    throw Error{
        kind: "theme",
        message: "unknown ratio \"" + $name + "\"; known: " +
            strings.join(ratios(), ", "),
        file: "",
        line: 0,
        col: 0
    };
}

/**
 * One colour, as the three channels a PDF wants.
 * @field red {int} 0-255
 * @field green {int} 0-255
 * @field blue {int} 0-255
 */
export def struct Rgb {
    red as int,
    green as int,
    blue as int
};

/**
 * Parse a `#rrggbb` colour into its channels.
 *
 * The CSS side of this module speaks hex, the PDF side speaks three ints;
 * this is the one place that converts between them. A three-digit `#rgb` is
 * expanded, since the palettes may shorten a colour.
 * @param hex {string} a colour as `#rgb` or `#rrggbb`, case-insensitive
 * @return {Rgb} the three channels
 * @throws {Error} kind "theme" when the string is not a hex colour
 */
export func hexRgb(hex as string) {
    def bare as string init strings.lower(strings.trim($hex));
    if (strings.startsWith($bare, "#")) {
        $bare = strings.substring($bare, 1, len($bare));
    }
    if (len($bare) == 3) {
        def wide as string init "";
        for (def ch in strings.chars($bare)) {
            $wide = $wide + $ch + $ch;
        }
        $bare = $wide;
    }
    if (len($bare) != 6) {
        throw Error{
            kind: "theme",
            message: "not a hex colour: \"" + $hex + "\"",
            file: "",
            line: 0,
            col: 0
        };
    }
    return Rgb{red: channel($bare, 0), green: channel($bare, 2), blue: channel($bare, 4)};
}

/**
 * One two-digit channel of a six-digit hex colour.
 * @param bare {string} six hex digits, no leading `#`
 * @param at {int} the index of the channel's first digit
 * @return {int} the channel's value, 0-255
 * @throws {Error} kind "theme" when the pair is not hexadecimal
 */
export func channel(bare as string, at as int) {
    def pair as string init strings.substring($bare, $at, $at + 2);
    try {
        return convert.toInt($pair, 16);
    } catch (e) {
        throw Error{
            kind: "theme",
            message: "not a hex colour pair: \"" + $pair + "\"",
            file: "",
            line: 0,
            col: 0
        };
    }
}

/**
 * Whether a name is a theme this build ships.
 * @param name {string} the name to test
 * @return {bool} true when `theme` would accept it
 */
export func hasTheme(name as string) {
    return lists.contains(names(), strings.lower(strings.trim($name)));
}

/**
 * Whether a name is a ratio this build ships.
 * @param name {string} the name to test
 * @return {bool} true when `stage` would accept it
 */
export func hasRatio(name as string) {
    return lists.contains(ratios(), strings.trim($name));
}

/**
 * The stylesheet for one theme on one stage.
 *
 * The CSS is held as a single template with `%name%` placeholders rather than
 * built by concatenation, so it reads as a stylesheet and the substitution is
 * one pass. Percent delimiters are used because a cooked Jennifer string
 * treats braces as interpolation slots, and a stylesheet is mostly braces.
 * @param t {Theme} the palette to render
 * @param s {Stage} the geometry to render for
 * @return {string} a complete stylesheet, no selectors outside the deck
 */
export func css(t as Theme, s as Stage) {
    def out as string init template();
    $out = strings.replace($out, "%bg%", $t.background);
    $out = strings.replace($out, "%fg%", $t.foreground);
    $out = strings.replace($out, "%heading%", $t.heading);
    $out = strings.replace($out, "%accent%", $t.accent);
    $out = strings.replace($out, "%muted%", $t.muted);
    $out = strings.replace($out, "%codebg%", $t.codeBg);
    $out = strings.replace($out, "%codefg%", $t.codeFg);
    $out = strings.replace($out, "%quotebar%", $t.quoteBar);
    $out = strings.replace($out, "%headingfont%", $t.headingFont);
    $out = strings.replace($out, "%bodyfont%", $t.bodyFont);
    $out = strings.replace($out, "%monofont%", $t.monoFont);
    $out = strings.replace($out, "%w%", convert.toString($s.width));
    $out = strings.replace($out, "%h%", convert.toString($s.height));
    $out = strings.replace($out, "%radius%", convert.toString($t.radius));
    return $out;
}

/**
 * The raw stylesheet template, before a theme is substituted into it.
 *
 * Separated from `css` so a test can assert that every placeholder the
 * template uses is one `css` actually replaces.
 * @return {string} the stylesheet with `%name%` placeholders intact
 */
export func template() {
    return '
:root {
    --bg: %bg%;
    --fg: %fg%;
    --heading: %heading%;
    --accent: %accent%;
    --muted: %muted%;
    --code-bg: %codebg%;
    --code-fg: %codefg%;
    --quote-bar: %quotebar%;
    --stage-w: %w%;
    --stage-h: %h%;
    --radius: %radius%px;
    --radius-small: calc(var(--radius) * 0.6);
    --speed: 420ms;
}

* { box-sizing: border-box; }

html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    background: #0b0b0d;
    color: var(--fg);
    font-family: %bodyfont%;
    -webkit-font-smoothing: antialiased;
}

#deck {
    position: fixed;
    inset: 0;
    overflow: hidden;
}

/*
 * Centred by position rather than by a grid: a grid track never shrinks
 * below the stage, so on a window smaller than the stage it would pin the
 * slide to the top-left and the scaled slide would spill off the far edges.
 * The negative margins put the centre of the slide on the centre of the
 * window, so the fitting scale() and the scale or translate of a transition
 * all work about that centre; a translate(-50%) inside the transform would
 * drift as it scaled.
 */
.slide {
    visibility: hidden;
    position: absolute;
    left: 50%;
    top: 50%;
    margin: calc(var(--stage-h) * -0.5px) 0 0 calc(var(--stage-w) * -0.5px);
    width: calc(var(--stage-w) * 1px);
    height: calc(var(--stage-h) * 1px);
    padding: 64px 80px 88px;
    background: var(--bg);
    color: var(--fg);
    transform-origin: center center;
    overflow: hidden;
}

.slide.current { visibility: visible; z-index: 1; }

/*
 * Transitions, chosen by `data-transition` on the deck. Every slide is laid
 * out and only the current one is visible; the script marks the others
 * `past` or `future`, and a transition animates the individual opacity,
 * translate, and scale properties, which compose with the fitting transform
 * instead of replacing it. A slide being left stays visible for the length of
 * one transition, so it can animate out. `ready` arrives just after the first
 * slide is shown, so a deck opens on its slide rather than animating to it.
 */
#deck.ready:not([data-transition="none"]) .slide {
    transition: visibility 0s linear var(--speed);
}
#deck.ready:not([data-transition="none"]) .slide.current { transition: visibility 0s; }

#deck[data-transition="fade"] .slide { opacity: 0; }
#deck[data-transition="fade"] .slide.current { opacity: 1; }
#deck.ready[data-transition="fade"] .slide {
    transition: opacity var(--speed) ease, visibility 0s linear var(--speed);
}
#deck.ready[data-transition="fade"] .slide.current {
    transition: opacity var(--speed) ease, visibility 0s;
}

#deck[data-transition="slide"] .slide.past { translate: -100vw 0; }
#deck[data-transition="slide"] .slide.future { translate: 100vw 0; }
#deck.ready[data-transition="slide"] .slide {
    transition: translate var(--speed) ease-in-out, visibility 0s linear var(--speed);
}
#deck.ready[data-transition="slide"] .slide.current {
    transition: translate var(--speed) ease-in-out, visibility 0s;
}

#deck[data-transition="zoom"] .slide { opacity: 0; }
#deck[data-transition="zoom"] .slide.past { scale: 1.12; }
#deck[data-transition="zoom"] .slide.future { scale: 0.88; }
#deck[data-transition="zoom"] .slide.current { opacity: 1; scale: 1; }
#deck.ready[data-transition="zoom"] .slide {
    transition: opacity var(--speed) ease, scale var(--speed) ease,
        visibility 0s linear var(--speed);
}
#deck.ready[data-transition="zoom"] .slide.current {
    transition: opacity var(--speed) ease, scale var(--speed) ease, visibility 0s;
}

@media (prefers-reduced-motion: reduce) {
    #deck .slide {
        transition: none !important;
        translate: none !important;
        scale: none !important;
    }
}

.slide > :first-child { margin-top: 0; }

h1, h2, h3, h4, h5, h6 {
    font-family: %headingfont%;
    color: var(--heading);
    line-height: 1.15;
    margin: 0 0 0.6em;
    text-wrap: balance;
}

h1 { font-size: 64px; letter-spacing: -0.02em; }
h2 { font-size: 46px; letter-spacing: -0.01em; }
h3 { font-size: 34px; }
h4 { font-size: 28px; }
h5, h6 { font-size: 24px; }

p, li, dd, dt, td, th { font-size: 26px; line-height: 1.5; }
p { margin: 0 0 0.7em; }

ul, ol { margin: 0 0 0.7em; padding-left: 1.4em; }
li { margin: 0 0 0.3em; }
li > ul, li > ol { margin-top: 0.3em; }

li.task-list-item { list-style: none; margin-left: -1.3em; }
li.task-list-item input { margin-right: 0.5em; }

a { color: var(--accent); text-decoration-thickness: 1px; text-underline-offset: 3px; }

code {
    font-family: %monofont%;
    font-size: 0.86em;
    background: var(--code-bg);
    color: var(--code-fg);
    padding: 0.12em 0.34em;
    border-radius: var(--radius-small);
}

pre {
    margin: 0 0 0.7em;
    padding: 20px 24px;
    background: var(--code-bg);
    color: var(--code-fg);
    border-radius: var(--radius);
    overflow: auto;
    max-height: 70%;
}

pre code {
    background: none;
    padding: 0;
    font-size: 20px;
    line-height: 1.45;
}

blockquote {
    margin: 0 0 0.7em;
    padding: 0.2em 0 0.2em 1em;
    border-left: 4px solid var(--quote-bar);
    color: var(--muted);
}

blockquote p { margin-bottom: 0.4em; }

hr { border: 0; border-top: 2px solid var(--quote-bar); margin: 1em 0; }

table { border-collapse: collapse; margin: 0 0 0.7em; }
th, td { border: 1px solid var(--quote-bar); padding: 8px 14px; text-align: left; }
th { background: var(--code-bg); font-weight: 600; }

img { max-width: 100%; max-height: 70%; height: auto; display: block; }

mark { background: var(--accent); color: var(--bg); padding: 0 0.2em; }

kbd {
    font-family: %monofont%;
    font-size: 0.8em;
    padding: 0.08em 0.4em;
    border: 1px solid var(--quote-bar);
    border-bottom-width: 3px;
    border-radius: var(--radius-small);
    background: var(--code-bg);
    color: var(--code-fg);
    white-space: nowrap;
}

dl { margin: 0 0 0.7em; }
dt { font-weight: 600; }
dd { margin: 0 0 0.5em 1.4em; }

.admonition {
    margin: 0 0 0.7em;
    padding: 16px 22px;
    border-left: 5px solid var(--accent);
    background: var(--code-bg);
    border-radius: 0 var(--radius) var(--radius) 0;
}

.admonition > :first-child { margin-top: 0; }
.admonition > :last-child { margin-bottom: 0; }
.admonition-title { font-weight: 700; color: var(--accent); }

.slide-number {
    position: absolute;
    right: 80px;
    bottom: 44px;
    font-size: 18px;
    color: var(--muted);
    font-variant-numeric: tabular-nums;
}

.slide-footer {
    position: absolute;
    left: 80px;
    bottom: 44px;
    font-size: 18px;
    color: var(--muted);
    max-width: 70%;
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
}

#progress {
    position: fixed;
    left: 0;
    top: 0;
    height: 3px;
    background: var(--accent);
    width: 0;
    transition: width 120ms linear;
    z-index: 10;
}

#notes {
    position: fixed;
    inset: auto 0 0 0;
    max-height: 38%;
    overflow: auto;
    padding: 18px 24px;
    background: #14161c;
    color: #e6e8ee;
    border-top: 2px solid var(--accent);
    font-size: 16px;
    line-height: 1.5;
    z-index: 11;
}

#notes[hidden] { display: none; }
#notes h2 {
    font-size: 15px;
    margin: 0 0 8px;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.08em;
}
#notes p { font-size: 16px; }

#help {
    position: fixed;
    inset: 0;
    display: grid;
    place-items: center;
    background: rgba(8, 9, 12, 0.88);
    color: #e6e8ee;
    z-index: 20;
    font-size: 17px;
}

#help[hidden] { display: none; }
#help table { border-collapse: collapse; }
#help td { border: 0; padding: 6px 18px 6px 0; font-size: 17px; }
#help kbd {
    font-family: %monofont%;
    background: #23262f;
    border: 1px solid #3a3f4b;
    border-radius: 4px;
    padding: 2px 7px;
    font-size: 15px;
}

#overview {
    position: fixed;
    inset: 0;
    overflow: auto;
    padding: 28px;
    background: #0b0b0d;
    z-index: 15;
    display: grid;
    gap: 20px;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    align-content: start;
}

#overview[hidden] { display: none; }

#overview .thumb {
    cursor: pointer;
    border: 2px solid transparent;
    border-radius: var(--radius);
    background: var(--bg);
    color: var(--fg);
    padding: 16px 18px;
    min-height: 140px;
    overflow: hidden;
}

#overview .thumb:hover,
#overview .thumb:focus-visible { border-color: var(--accent); outline: none; }
#overview .thumb .n { font-size: 13px; color: var(--muted); font-variant-numeric: tabular-nums; }
#overview .thumb .t { font-size: 19px; font-weight: 600; color: var(--accent); margin-top: 6px; }

@media print {
    html, body { background: #fff; height: auto; }
    #progress, #notes, #help, #overview { display: none !important; }
    #deck { position: static; display: block; overflow: visible; }
    .slide {
        visibility: visible !important;
        opacity: 1 !important;
        translate: none !important;
        scale: none !important;
        transition: none !important;
        position: relative;
        left: auto;
        top: auto;
        margin: 0;
        transform: none !important;
        page-break-after: always;
        break-after: page;
        width: 100%;
        height: 100vh;
    }
    .slide:last-child { page-break-after: auto; break-after: auto; }
}

@page { size: %w%px %h%px; margin: 0; }
';
}

