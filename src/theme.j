# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * Presentation appearance: the named themes and the stage each deck is laid
 * out on.
 *
 * A theme is a light and a dark palette plus three font stacks; a stage is the
 * slide's pixel geometry and the PDF page size that matches it. Both are plain values, so a
 * renderer asks for one and never decides what it looks like.
 * @module theme
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use strings;
use lists;
use convert;
use math;
use io;

/** The theme used when a deck names none. */
export def const DEFAULT_THEME as string init "plain";

/** The mode a deck opens in when it names none. */
export def const DEFAULT_MODE as string init "light";

/** The stage used when a deck names no ratio. */
export def const DEFAULT_RATIO as string init "16:9";

/**
 * One palette of a theme, with its fonts. Every theme has two, a light and a
 * dark one, under the same name; the fonts and the radius are the theme's and
 * the same in both.
 * @field name {string} the theme's name, as a caller would ask for it
 * @field description {string} one line on what this palette looks like, for `themes`
 * @field dark {bool} whether this is the theme's dark palette
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

/**
 * The token colours of one code palette, by highlight.js class: what the
 * slideshow's `.hljs-*` rules and the PDF's coloured code draw with. A
 * class not listed shares a colour with one that is (`meta` with `comment`,
 * `name` with `keyword`, `attr` with `symbol`, `section` with `title`).
 * @field comment {string} comments and `meta` (prompts, preprocessor lines)
 * @field keyword {string} keywords and markup tag names
 * @field typeName {string} type names
 * @field literal {string} `true`, `false`, `null` and the like
 * @field quoted {string} string literals
 * @field number {string} numbers
 * @field variable {string} `$variables`
 * @field symbol {string} constants, keys and markup attributes
 * @field builtin {string} built-ins and library prefixes
 * @field title {string} called or defined functions, and sections
 */
export def struct Syntax {
    comment as string,
    keyword as string,
    typeName as string,
    literal as string,
    quoted as string,
    number as string,
    variable as string,
    symbol as string,
    builtin as string,
    title as string
};

/** The contrast every token colour keeps against its code background (WCAG AA). */
export def const MIN_CONTRAST as float init 4.5;

/** The contrast the `contrast` theme keeps instead (WCAG AAA). */
export def const HIGH_CONTRAST as float init 7.0;

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
            name: "plain",
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
            name: "solar",
            description: "The deep Solarized-dark ground with the same gold accent.",
            dark: true,
            background: "#002b36",
            foreground: "#eee8d5",
            heading: "#b58900",
            accent: "#b58900",
            muted: "#93a1a1",
            codeBg: "#073642",
            codeFg: "#eee8d5",
            quoteBar: "#2f505a",
            printCodeBg: "#eee8d5",
            printQuoteBar: "#d3cbb7",
            headingFont: SANS,
            bodyFont: SANS,
            monoFont: MONO,
            radius: 8
        },
        Theme{
            name: "contrast",
            description: "Pure white, pure black, deep-blue accent; for a bad projector in a " +
                "bright room.",
            dark: false,
            background: "#ffffff",
            foreground: "#000000",
            heading: "#0033b3",
            accent: "#0033b3",
            muted: "#3c3c3c",
            codeBg: "#ececec",
            codeFg: "#000000",
            quoteBar: "#5a5a5a",
            printCodeBg: "#f0f0f0",
            printQuoteBar: "#5a5a5a",
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
            name: "carbon",
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
            name: "ember",
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
            name: "grimoire",
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
            name: "ivy",
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
            name: "meridian",
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
            name: "nordic",
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
            name: "obsidian",
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
            name: "orchid",
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
            name: "sepia",
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
            name: "terminal",
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
        if (not lists.contains($out, $t.name)) {
            $out[] = $t.name;
        }
    }
    return $out;
}

/**
 * The modes every theme comes in.
 * @return {list of string} the names `theme` accepts as a mode
 */
export func modes() {
    return ["light", "dark", "auto"];
}

/**
 * A theme error: kind "theme".
 * @param message {string} what is wrong
 * @return {Error} the error to throw
 */
func themeError(message as string) {
    return Error{kind: "theme", message: $message, file: "", line: 0, col: 0};
}

/**
 * Check a mode name.
 *
 * An empty name selects the default, so a deck with no `mode:` key and a
 * caller passing no `--mode` both land here. `auto` is the mode the reader's
 * system asks for (`prefers-color-scheme`), decided in the browser; a palette
 * looked up for it is the light one, which is also what the PDF prints.
 * @param name {string} "light", "dark", "auto", or "" for the default
 * @return {string} the mode, lower-cased
 * @throws {Error} kind "theme" for any other name
 */
export func mode(name as string) {
    def want as string init strings.lower(strings.trim($name));
    if ($want == "") {
        return DEFAULT_MODE;
    }
    if (not lists.contains(modes(), $want)) {
        throw themeError("unknown mode \"" + $name + "\"; known: " + strings.join(modes(), ", "));
    }
    return $want;
}

/**
 * Every ratio name this build ships, in listing order.
 * @return {list of string} the names `stage` accepts
 */
export func ratios() {
    return ["16:9", "16:10", "4:3"];
}

/**
 * Look up one palette of a theme.
 *
 * An empty name selects the default theme, and an empty mode the default
 * mode, so a deck with no `theme:` key and a caller passing no `--theme` both
 * land here. The names of cantrip 0.1, which put the mode into the name
 * (`nordic-dark`, `midnight`), are refused with the spelling to use instead.
 * @param name {string} a theme name, or "" for the default
 * @param modeName {string} "light", "dark", or "" for the default
 * @return {Theme} the named theme's palette for that mode
 * @throws {Error} kind "theme" when the name or the mode is unknown
 */
export func theme(name as string, modeName as string) {
    def want as string init strings.lower(strings.trim($name));
    if ($want == "") {
        $want = DEFAULT_THEME;
    }
    def dark as bool init mode($modeName) == "dark";
    for (def t in all()) {
        if ($t.name == $want and $t.dark == $dark) {
            return $t;
        }
    }
    def instead as string init "";
    if ($want == "midnight") {
        $instead = "plain";
    }
    if (strings.endsWith($want, "-dark")) {
        def base as string init $want[..len($want) - 5];
        if (lists.contains(names(), $base)) {
            $instead = $base;
        }
    }
    if ($instead != "") {
        throw themeError("unknown theme \"" + $name + "\"; every theme is light and dark " +
            "now: use theme: " + $instead + " with mode: dark");
    }
    throw themeError("unknown theme \"" + $name + "\"; known: " + strings.join(names(), ", "));
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
        $bare = $bare[1..len($bare)];
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
    def pair as string init $bare[$at..$at + 2];
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
 * The token colours a palette starts from, before `legible` adjusts them to
 * its code background.
 *
 * The Grimoire themes and `plain` take Grimoire's own pair
 * (`apps/grimoire/src/palette.j`, "The syntax palette"): Atom One Light on a
 * light palette, Atom One Dark on a dark one. `solar` takes the Solarized
 * accents, which that palette shares between its two modes, and `contrast`
 * a saturated set picked for a poor projector.
 * @param name {string} the theme's name
 * @param dark {bool} whether the palette is the theme's dark one
 * @return {Syntax} the unadjusted token colours
 */
export func syntaxBase(name as string, dark as bool) {
    if ($name == "solar") {
        def comment as string init "#93a1a1";
        if ($dark) {
            $comment = "#839496";
        }
        return Syntax{
            comment: $comment,
            keyword: "#859900",
            typeName: "#b58900",
            literal: "#2aa198",
            quoted: "#2aa198",
            number: "#d33682",
            variable: "#268bd2",
            symbol: "#cb4b16",
            builtin: "#dc322f",
            title: "#268bd2"
        };
    }
    if ($name == "contrast" and $dark) {
        return Syntax{
            comment: "#c8c8c8",
            keyword: "#ffe14d",
            typeName: "#5fe3ff",
            literal: "#ffa657",
            quoted: "#8dff8d",
            number: "#ffa657",
            variable: "#ff9ecb",
            symbol: "#ffd27f",
            builtin: "#ffd27f",
            title: "#8cc8ff"
        };
    }
    if ($name == "contrast") {
        return Syntax{
            comment: "#4a4a4a",
            keyword: "#0000b0",
            typeName: "#00566e",
            literal: "#8a2a00",
            quoted: "#005f00",
            number: "#8a2a00",
            variable: "#9a004a",
            symbol: "#5e3c00",
            builtin: "#5e3c00",
            title: "#0035a0"
        };
    }
    if ($dark) {
        return Syntax{
            comment: "#7f848e",
            keyword: "#c678dd",
            typeName: "#56b6c2",
            literal: "#d19a66",
            quoted: "#98c379",
            number: "#d19a66",
            variable: "#e06c75",
            symbol: "#e5c07b",
            builtin: "#e5c07b",
            title: "#61afef"
        };
    }
    return Syntax{
        comment: "#9aa0a6",
        keyword: "#a626a4",
        typeName: "#0184bc",
        literal: "#986801",
        quoted: "#50a14f",
        number: "#986801",
        variable: "#e45649",
        symbol: "#b26a00",
        builtin: "#c18401",
        title: "#4078f2"
    };
}

/**
 * The contrast a theme's token colours keep: AAA for `contrast`, AA for the rest.
 * @param name {string} the theme's name
 * @return {float} the minimum contrast ratio
 */
export func minContrast(name as string) {
    if ($name == "contrast") {
        return HIGH_CONTRAST;
    }
    return MIN_CONTRAST;
}

/**
 * A palette's token colours on screen, each legible on its code background.
 * @param t {Theme} the palette
 * @return {Syntax} the colours the slideshow uses in that palette
 */
export func syntax(t as Theme) {
    return legibleSyntax(syntaxBase($t.name, $t.dark), $t.codeBg, minContrast($t.name));
}

/**
 * A theme's token colours in the PDF: the light palette's, each legible on
 * the print code shade, since the PDF always prints light.
 * @param t {Theme} either palette of the theme
 * @return {Syntax} the colours the PDF draws code with
 */
export func printSyntax(t as Theme) {
    return legibleSyntax(syntaxBase($t.name, false), $t.printCodeBg, minContrast($t.name));
}

/**
 * Adjust every colour of a token palette to a background.
 * @param s {Syntax} the colours to adjust
 * @param bg {string} the code background
 * @param minimum {float} the contrast each colour must reach
 * @return {Syntax} the adjusted colours
 */
func legibleSyntax(s as Syntax, bg as string, minimum as float) {
    return Syntax{
        comment: legible($s.comment, $bg, $minimum),
        keyword: legible($s.keyword, $bg, $minimum),
        typeName: legible($s.typeName, $bg, $minimum),
        literal: legible($s.literal, $bg, $minimum),
        quoted: legible($s.quoted, $bg, $minimum),
        number: legible($s.number, $bg, $minimum),
        variable: legible($s.variable, $bg, $minimum),
        symbol: legible($s.symbol, $bg, $minimum),
        builtin: legible($s.builtin, $bg, $minimum),
        title: legible($s.title, $bg, $minimum)
    };
}

/**
 * The colour a token class is drawn in, "" for plain text.
 * @param s {Syntax} the token colours
 * @param cls {string} a highlight.js class without its `hljs-` prefix
 * @return {string} the colour, or "" when the class has none
 */
export func tokenColour(s as Syntax, cls as string) {
    match ($cls) {
        when "comment", "meta" { return $s.comment; }
        when "keyword", "name" { return $s.keyword; }
        when "type" { return $s.typeName; }
        when "literal" { return $s.literal; }
        when "string" { return $s.quoted; }
        when "number" { return $s.number; }
        when "variable" { return $s.variable; }
        when "symbol", "attr" { return $s.symbol; }
        when "built_in" { return $s.builtin; }
        when "title", "section" { return $s.title; }
    }
    return "";
}

/**
 * A colour's relative luminance, as WCAG 2 defines it.
 * @param hex {string} a colour as `#rgb` or `#rrggbb`
 * @return {float} 0 for black to 1 for white
 * @throws {Error} kind "theme" when the string is not a hex colour
 */
export func luminance(hex as string) {
    def c as Rgb init hexRgb($hex);
    return 0.2126 * linear($c.red) + 0.7152 * linear($c.green) + 0.0722 * linear($c.blue);
}

/**
 * One sRGB channel, linearised.
 * @param v {int} the channel, 0-255
 * @return {float} its linear value, 0-1
 */
func linear(v as int) {
    def c as float init $v / 255;
    if ($c <= 0.04045) {
        return $c / 12.92;
    }
    return math.pow(($c + 0.055) / 1.055, 2.4);
}

/**
 * The contrast ratio of two colours, as WCAG 2 defines it.
 * @param a {string} one colour
 * @param b {string} the other
 * @return {float} 1 (no contrast) to 21 (black on white)
 * @throws {Error} kind "theme" when either is not a hex colour
 */
export func contrast(a as string, b as string) {
    def la as float init luminance($a);
    def lb as float init luminance($b);
    if ($la < $lb) {
        def swap as float init $la;
        $la = $lb;
        $lb = $swap;
    }
    return ($la + 0.05) / ($lb + 0.05);
}

/**
 * A colour made legible on a background: the colour itself when it already
 * reaches the contrast, else the first mix of it towards black (on a light
 * background) or white (on a dark one), in steps of 5%, that does.
 * @param fg {string} the colour wanted
 * @param bg {string} the background it sits on
 * @param minimum {float} the contrast ratio to reach
 * @return {string} a `#rrggbb` colour reaching the ratio
 * @throws {Error} kind "theme" when either is not a hex colour
 */
export func legible(fg as string, bg as string, minimum as float) {
    if (contrast($fg, $bg) >= $minimum) {
        return $fg;
    }
    def towards as int init 255;
    if (contrast("#000000", $bg) > contrast("#ffffff", $bg)) {
        $towards = 0;
    }
    def c as Rgb init hexRgb($fg);
    def out as string init $fg;
    for (def keep as int init 95; $keep >= 0; $keep = $keep - 5) {
        $out = rgbHex(Rgb{
            red: mix($c.red, $towards, $keep),
            green: mix($c.green, $towards, $keep),
            blue: mix($c.blue, $towards, $keep)
        });
        if (contrast($out, $bg) >= $minimum) {
            return $out;
        }
    }
    return $out;
}

/**
 * One channel mixed towards another.
 * @param value {int} the channel's value
 * @param target {int} the value it moves towards
 * @param keep {int} how much of `value` stays, in percent
 * @return {int} the mixed value
 */
func mix(value as int, target as int, keep as int) {
    return ($value * $keep + $target * (100 - $keep) + 50) // 100;
}

/**
 * Write three channels as a `#rrggbb` colour.
 * @param c {Rgb} the channels, each 0-255
 * @return {string} the colour, lower-case
 */
export func rgbHex(c as Rgb) {
    return "#" + hexPair($c.red) + hexPair($c.green) + hexPair($c.blue);
}

/**
 * One channel as two hex digits.
 * @param v {int} 0-255
 * @return {string} two lower-case digits
 */
func hexPair(v as int) {
    def digits as string init io.sprintf("%d|base=16", $v);
    if (len($digits) < 2) {
        return "0" + $digits;
    }
    return $digits;
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
 * The stylesheet for one theme on one stage, in both its modes.
 *
 * The CSS is held as a single template with `%name%` placeholders rather than
 * built by concatenation, so it reads as a stylesheet and the substitution is
 * one pass. Percent delimiters are used because a cooked Jennifer string
 * treats braces as interpolation slots, and a stylesheet is mostly braces.
 * The light palette is the root's; the dark one applies while the page's
 * `<html>` carries `data-mode="dark"`, which the viewer flips with m, and
 * under `data-mode="auto"` when the reader's system prefers dark.
 * @param light {Theme} the theme's light palette, whose fonts and radius are used
 * @param dark {Theme} the theme's dark palette
 * @param s {Stage} the geometry to render for
 * @return {string} a complete stylesheet, no selectors outside the deck
 */
export func css(light as Theme, dark as Theme, s as Stage) {
    def out as string init template();
    $out = strings.replace($out, "%light%", palette($light));
    $out = strings.replace($out, "%dark%", palette($dark));
    $out = strings.replace($out, "%headingfont%", $light.headingFont);
    $out = strings.replace($out, "%bodyfont%", $light.bodyFont);
    $out = strings.replace($out, "%monofont%", $light.monoFont);
    $out = strings.replace($out, "%w%", convert.toString($s.width));
    $out = strings.replace($out, "%h%", convert.toString($s.height));
    $out = strings.replace($out, "%radius%", convert.toString($light.radius));
    return $out;
}

/**
 * One palette as CSS custom properties, for a `:root` rule.
 * @param t {Theme} the palette
 * @return {string} the declarations, one per line
 */
export func palette(t as Theme) {
    def scheme as string init "light";
    if ($t.dark) {
        $scheme = "dark";
    }
    return "    --bg: " + $t.background + ";\n" +
        "    --fg: " + $t.foreground + ";\n" +
        "    --heading: " + $t.heading + ";\n" +
        "    --accent: " + $t.accent + ";\n" +
        "    --muted: " + $t.muted + ";\n" +
        "    --code-bg: " + $t.codeBg + ";\n" +
        "    --code-fg: " + $t.codeFg + ";\n" +
        "    --quote-bar: " + $t.quoteBar + ";\n" +
        syntaxProperties(syntax($t)) +
        "    color-scheme: " + $scheme + ";\n";
}

/**
 * A palette's token colours as CSS custom properties.
 * @param s {Syntax} the token colours
 * @return {string} the declarations, one per line
 */
export func syntaxProperties(s as Syntax) {
    return "    --syn-comment: " + $s.comment + ";\n" +
        "    --syn-keyword: " + $s.keyword + ";\n" +
        "    --syn-type: " + $s.typeName + ";\n" +
        "    --syn-literal: " + $s.literal + ";\n" +
        "    --syn-string: " + $s.quoted + ";\n" +
        "    --syn-number: " + $s.number + ";\n" +
        "    --syn-variable: " + $s.variable + ";\n" +
        "    --syn-symbol: " + $s.symbol + ";\n" +
        "    --syn-builtin: " + $s.builtin + ";\n" +
        "    --syn-title: " + $s.title + ";\n";
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
%light%    --stage-w: %w%;
    --stage-h: %h%;
    --radius: %radius%px;
    --radius-small: calc(var(--radius) * 0.6);
    --speed: 420ms;
}

:root[data-mode="dark"] {
%dark%}

@media (prefers-color-scheme: dark) {
    :root[data-mode="auto"] {
%dark%    }
}

* { box-sizing: border-box; }

/*
 * overscroll-behavior: a swipe turns the slide, so the browser must not also
 * take a sideways swipe as its back or forward gesture (Chrome on Android
 * does, on a page that cannot scroll sideways) or pull the page to reload it.
 */
html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    overscroll-behavior: none;
    background: #0b0b0d;
    color: var(--fg);
    font-family: %bodyfont%;
    -webkit-font-smoothing: antialiased;
}

body > #cantrip-deck {
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
body > #cantrip-deck > .cantrip-slide {
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

body > #cantrip-deck > .cantrip-slide.cantrip-current { visibility: visible; z-index: 1; }

/*
 * Transitions, chosen by `data-transition` on the deck. Every slide is laid
 * out and only the current one is visible; the script marks the others
 * `cantrip-past` or `cantrip-future`, and a transition animates the individual
 * opacity, translate, and scale properties, which compose with the fitting
 * transform instead of replacing it. A slide being left stays visible for the
 * length of one transition, so it can animate out. `cantrip-ready` arrives just
 * after the first slide is shown, so a deck opens on its slide rather than
 * animating to it.
 *
 * Every id and class the slideshow owns is prefixed `cantrip-`, and every rule
 * is anchored at a child of `body`, so an `{#id .class}` list on a heading in
 * the deck cannot take on the styling of the parts of the slideshow.
 */
body > #cantrip-deck.cantrip-ready:not([data-transition="none"]) > .cantrip-slide {
    transition: visibility 0s linear var(--speed);
}
body > #cantrip-deck.cantrip-ready:not([data-transition="none"]) > .cantrip-slide.cantrip-current {
    transition: visibility 0s;
}

body > #cantrip-deck[data-transition="fade"] > .cantrip-slide { opacity: 0; }
body > #cantrip-deck[data-transition="fade"] > .cantrip-slide.cantrip-current { opacity: 1; }
body > #cantrip-deck.cantrip-ready[data-transition="fade"] > .cantrip-slide {
    transition: opacity var(--speed) ease, visibility 0s linear var(--speed);
}
body > #cantrip-deck.cantrip-ready[data-transition="fade"] > .cantrip-slide.cantrip-current {
    transition: opacity var(--speed) ease, visibility 0s;
}

body > #cantrip-deck[data-transition="slide"] > .cantrip-slide.cantrip-past { translate: -100vw 0; }
body > #cantrip-deck[data-transition="slide"] > .cantrip-slide.cantrip-future {
    translate: 100vw 0;
}
body > #cantrip-deck.cantrip-ready[data-transition="slide"] > .cantrip-slide {
    transition: translate var(--speed) ease-in-out, visibility 0s linear var(--speed);
}
body > #cantrip-deck.cantrip-ready[data-transition="slide"] > .cantrip-slide.cantrip-current {
    transition: translate var(--speed) ease-in-out, visibility 0s;
}

body > #cantrip-deck[data-transition="zoom"] > .cantrip-slide { opacity: 0; }
body > #cantrip-deck[data-transition="zoom"] > .cantrip-slide.cantrip-past { scale: 1.12; }
body > #cantrip-deck[data-transition="zoom"] > .cantrip-slide.cantrip-future { scale: 0.88; }
body > #cantrip-deck[data-transition="zoom"] > .cantrip-slide.cantrip-current {
    opacity: 1;
    scale: 1;
}
body > #cantrip-deck.cantrip-ready[data-transition="zoom"] > .cantrip-slide {
    transition: opacity var(--speed) ease, scale var(--speed) ease,
        visibility 0s linear var(--speed);
}
body > #cantrip-deck.cantrip-ready[data-transition="zoom"] > .cantrip-slide.cantrip-current {
    transition: opacity var(--speed) ease, scale var(--speed) ease, visibility 0s;
}

@media (prefers-reduced-motion: reduce) {
    body > #cantrip-deck > .cantrip-slide {
        transition: none !important;
        translate: none !important;
        scale: none !important;
    }
}

.cantrip-slide > :first-child { margin-top: 0; }

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
    /*
     * A share of the content height of the slide (the slide has a set
     * height, so the percentage resolves): a block longer than this scrolls
     * rather than pushing the slide past its page. 75% shows the longest
     * blocks in the academy talks (about 417px of 568) without a scrollbar.
     */
    max-height: 75%;
}

pre code {
    background: none;
    padding: 0;
    font-size: 20px;
    line-height: 1.45;
}

/* Token colours of the build-time highlighter, highlight.js class names. */
pre > code > .hljs-comment { color: var(--syn-comment); font-style: italic; }
pre > code > .hljs-meta { color: var(--syn-comment); }
pre > code > .hljs-keyword, pre > code > .hljs-name { color: var(--syn-keyword); }
pre > code > .hljs-type { color: var(--syn-type); }
pre > code > .hljs-literal { color: var(--syn-literal); }
pre > code > .hljs-string { color: var(--syn-string); }
pre > code > .hljs-number { color: var(--syn-number); }
pre > code > .hljs-variable { color: var(--syn-variable); }
pre > code > .hljs-symbol, pre > code > .hljs-attr { color: var(--syn-symbol); }
pre > code > .hljs-built_in { color: var(--syn-builtin); }
pre > code > .hljs-title, pre > code > .hljs-section { color: var(--syn-title); }

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
th[align="center"], td[align="center"] { text-align: center; }
th[align="right"], td[align="right"] { text-align: right; }
th { background: var(--code-bg); font-weight: 600; }

/*
 * A picture fits the slide: no wider than the content, and no taller than 60%
 * of the stage, which leaves room for a heading and a line of text. The cap is
 * in stage pixels because a percentage height has nothing to resolve against
 * here (the slide content has no set height), and a picture whose SVG says
 * only width="100%", as a diagram plugin writes it, would otherwise be
 * stretched to the slide width and run off the bottom. With both caps, the
 * browser shrinks such a picture in proportion.
 */
img {
    max-width: 100%;
    max-height: calc(var(--stage-h) * 0.6px);
    width: auto;
    height: auto;
    display: block;
}

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

.cantrip-slide > div.cantrip-slide-number {
    position: absolute;
    right: 80px;
    bottom: 44px;
    font-size: 18px;
    color: var(--muted);
    font-variant-numeric: tabular-nums;
}

.cantrip-slide > div.cantrip-slide-footer {
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

body > #cantrip-progress {
    position: fixed;
    left: 0;
    top: 0;
    height: 3px;
    background: var(--accent);
    width: 0;
    transition: width 120ms linear;
    z-index: 12;
}

/*
 * The notes panel sits where its data-at says: below the slide (the default),
 * above it, or beside it on the left or right. Below or above, it is as tall as
 * the longest notes in the deck, at most 30% of the window; beside the slide it
 * is the full height and about a quarter of the width. Longer notes scroll.
 * While it is open the deck ends where it begins (the script measures the
 * panel, marks the deck cantrip-notes-open and fits the slide into what is
 * left), so the panel never covers the slide.
 */
body > #cantrip-notes {
    position: fixed;
    inset: auto 0 0 0;
    max-height: 30vh;
    box-sizing: border-box;
    overflow: auto;
    padding: 18px 24px;
    background: #14161c;
    color: #e6e8ee;
    border-top: 2px solid var(--accent);
    font-size: 16px;
    line-height: 1.5;
    z-index: 11;
}

body > #cantrip-notes[hidden] { display: none; }
body > #cantrip-notes[data-at="top"] {
    inset: 0 0 auto 0;
    border-top: 0;
    border-bottom: 2px solid var(--accent);
}
body > #cantrip-notes[data-at="left"],
body > #cantrip-notes[data-at="right"] {
    width: clamp(240px, 28vw, 480px);
    max-height: none;
    border-top: 0;
}
body > #cantrip-notes[data-at="left"] { inset: 0 auto 0 0; border-right: 2px solid var(--accent); }
body > #cantrip-notes[data-at="right"] { inset: 0 0 0 auto; border-left: 2px solid var(--accent); }
body > #cantrip-notes > h2 {
    font-size: 15px;
    margin: 0 0 8px;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.08em;
}
body > #cantrip-notes p { font-size: 16px; }
body > #cantrip-notes code, body > #cantrip-notes kbd {
    background: #23262f;
    color: #e6e8ee;
    border-color: #3a3f4b;
}
body > #cantrip-notes a { color: #8ab4ff; }

body > #cantrip-help {
    position: fixed;
    inset: 0;
    display: grid;
    place-items: center;
    background: rgba(8, 9, 12, 0.88);
    color: #e6e8ee;
    z-index: 20;
    font-size: 17px;
}

body > #cantrip-help[hidden] { display: none; }
body > #cantrip-help table { border-collapse: collapse; }
body > #cantrip-help td { border: 0; padding: 6px 18px 6px 0; font-size: 17px; }
/* The help overlay and the notes panel are always dark, whatever the theme,
   so everything inside them sets its own colours: a key cap or code span that
   inherited the code colours of the theme would be dark on dark in a light theme. */
body > #cantrip-help kbd {
    font-family: %monofont%;
    background: #23262f;
    color: #e6e8ee;
    border: 1px solid #3a3f4b;
    border-radius: 4px;
    padding: 2px 7px;
    font-size: 15px;
}

/*
 * The touch bar: keys for a device without a keyboard. Hidden until the script
 * marks it cantrip-touch: at once on a device with a touch screen (a phone, a
 * tablet, a touch laptop), otherwise at the first touch, so a mouse alone
 * never brings it up.
 * It sits above the notes and the overview,
 * so its buttons also close what they opened, and is always dark, like the
 * help overlay. The script adds cantrip-shown for a few seconds at a time; without
 * it the bar is transparent and lets taps through to the slide.
 */
body > #cantrip-touchbar { display: none; }
body > #cantrip-touchbar.cantrip-touch {
    position: fixed;
    top: 8px;
    right: 8px;
    display: flex;
    gap: 4px;
    padding: 4px;
    background: rgba(20, 22, 28, 0.72);
    border-radius: 10px;
    z-index: 16;
    opacity: 0;
    pointer-events: none;
    transition: opacity 300ms ease;
}
body > #cantrip-touchbar.cantrip-touch.cantrip-shown { opacity: 1; pointer-events: auto; }
body > #cantrip-touchbar > button {
    width: 40px;
    height: 40px;
    padding: 8px;
    border: 0;
    border-radius: 8px;
    background: transparent;
    color: #e6e8ee;
    cursor: pointer;
}
body > #cantrip-touchbar > button:active { background: rgba(255, 255, 255, 0.16); }
body > #cantrip-touchbar svg { display: block; width: 24px; height: 24px; }

body > #cantrip-overview {
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

body > #cantrip-overview[hidden] { display: none; }

body > #cantrip-overview > .cantrip-thumb {
    cursor: pointer;
    border: 2px solid transparent;
    border-radius: var(--radius);
    background: var(--bg);
    color: var(--fg);
    padding: 16px 18px;
    min-height: 140px;
    overflow: hidden;
}

body > #cantrip-overview > .cantrip-thumb:hover,
body > #cantrip-overview > .cantrip-thumb:focus-visible {
    border-color: var(--accent);
    outline: none;
}
body > #cantrip-overview > .cantrip-thumb > .cantrip-thumb-n {
    font-size: 13px;
    color: var(--muted);
    font-variant-numeric: tabular-nums;
}
body > #cantrip-overview > .cantrip-thumb > .cantrip-thumb-t {
    font-size: 19px;
    font-weight: 600;
    color: var(--accent);
    margin-top: 6px;
}

@media print {
    html, body { background: #fff; height: auto; }
    body > #cantrip-progress,
    body > #cantrip-notes,
    body > #cantrip-help,
    body > #cantrip-touchbar,
    body > #cantrip-overview {
        display: none !important;
    }
    body > #cantrip-deck { position: static; display: block; overflow: visible; }
    body > #cantrip-deck > .cantrip-slide {
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
    body > #cantrip-deck > .cantrip-slide:last-child { page-break-after: auto; break-after: auto; }
}

@page { size: %w%px %h%px; margin: 0; }
';
}

