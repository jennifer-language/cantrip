# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Render a deck as one self-contained HTML slideshow.
 *
 * Everything lands in a single file: the stylesheet, the navigation script,
 * and the slides. Nothing is fetched at view time, so a deck opens over
 * `file://` as readily as from a web server.
 * @module htmlout
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use strings;
use maps;
use lists;
use convert;
use regex;

import "html.j" as html;
import "markdown.j" as markdown;
import "doctree.j" as doctree;
import "./slides.j" as slides;
import "./theme.j" as theme;
import "./highlight.j" as highlight;
import "./mathml.j" as mathml;
import "./locale.j" as locale;

/** The generator name written into the document's meta tags. */
export def const GENERATOR as string init "cantrip";

/** The transition used when neither the deck nor the caller picks one. */
export def const DEFAULT_TRANSITION as string init "fade";

/**
 * What the HTML renderer needs beyond the deck itself.
 * @field theme {string} theme name, "" for the deck's own or the default
 * @field mode {string} the mode the page opens in, "light", "dark" or "auto"; "" for the
 *     deck's own or the default
 * @field ratio {string} ratio name, "" for the deck's own or the default
 * @field footer {string} text shown bottom-left on every slide
 * @field notes {bool} embed speaker notes for the presenter panel
 * @field numbers {bool} show the slide counter bottom-right
 * @field rawHtml {bool} pass raw HTML in the Markdown through unescaped
 * @field highlight {bool} colour code blocks in a language `highlight` knows;
 *     the deck's `highlight: false` turns it off too
 * @field transition {string} transition name, "" for the deck's own or the default
 * @field startNotes {string} notes panel at start, "open" or "closed"; "" for the deck's own
 * @field startSlide {string} the slide to open on, 1-based; "" for the deck's own
 * @field startOverview {string} overview at start, "open" or "closed"; "" for the deck's own
 * @field favicon {string} the page's icon, as the `href` of its
 *     `<link rel="icon">`: a `data:` URL the caller built from the deck's
 *     `favicon:` file, or an http(s) URL; "" for none
 * @field embedded {map of string to string} pictures to carry inside the page:
 *     a slide's image target, as the Markdown writes it, to the `data:` URL
 *     that replaces it. The caller fills it with the files plugins generated,
 *     so the slideshow stays one file.
 */
export def struct Options {
    theme as string,
    mode as string,
    ratio as string,
    footer as string,
    notes as bool,
    numbers as bool,
    rawHtml as bool,
    highlight as bool,
    transition as string,
    startNotes as string,
    startSlide as string,
    startOverview as string,
    favicon as string,
    embedded as map of string to string
};

/**
 * How the slideshow opens: resolved from the options, the front matter and
 * the defaults (closed, slide 1, closed). The page's URL can still override
 * each when it is viewed.
 * @field notes {bool} the speaker-notes panel starts open
 * @field slide {int} the slide to open on, 1-based
 * @field overview {bool} the overview starts open
 */
export def struct Start {
    notes as bool,
    slide as int,
    overview as bool
};

/**
 * The default options: safe, numbered, highlighted, with notes embedded.
 * @return {Options} a fresh option set a caller can copy and adjust
 */
export func defaults() {
    return Options{
        theme: "",
        mode: "",
        ratio: "",
        footer: "",
        notes: true,
        numbers: true,
        rawHtml: false,
        highlight: true,
        transition: "",
        startNotes: "",
        startSlide: "",
        startOverview: "",
        favicon: "",
        embedded: {}
    };
}

/**
 * An option value when given, else the deck's front-matter value, else "".
 * @param deck {slides.Deck} the deck being rendered
 * @param given {string} the option's value, "" when not given
 * @param key {string} the front-matter key
 * @return {string} the trimmed value, or ""
 */
func startValue(deck as slides.Deck, given as string, key as string) {
    def want as string init strings.trim($given);
    if ($want != "") {
        return $want;
    }
    return slides.metaOr($deck.meta, $key, "");
}

/**
 * A start error: kind "start", naming the setting and the value it got.
 * @param message {string} what is wrong
 * @return {Error} the error to throw
 */
func startError(message as string) {
    return Error{kind: "start", message: $message, file: "", line: 0, col: 0};
}

/**
 * Read an `open` / `closed` value, case-insensitively.
 * @param name {string} the setting, for the message
 * @param value {string} the value, "" for the default
 * @return {bool} true for open; false for closed or ""
 * @throws {Error} kind "start" for any other value
 */
export func openClosed(name as string, value as string) {
    def v as string init strings.lower($value);
    if ($v == "" or $v == "closed") {
        return false;
    }
    if ($v == "open") {
        return true;
    }
    throw startError($name + " wants open or closed, got \"" + $value + "\"");
}

/**
 * Resolve how the slideshow opens. An option (from the command line) wins
 * over the deck's `notes:`, `slide:` and `overview:` front-matter keys, which
 * win over the defaults.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {Start} the start state written into the page
 * @throws {Error} kind "start" on a bad value, a slide past the end, or open
 *     notes in a page built without them
 */
export func pickStart(deck as slides.Deck, opts as Options) {
    def out as Start init Start{notes: false, slide: 1, overview: false};
    $out.notes = openClosed("notes", startValue($deck, $opts.startNotes, "notes"));
    $out.overview = openClosed("overview", startValue($deck, $opts.startOverview, "overview"));
    def slide as string init startValue($deck, $opts.startSlide, "slide");
    if ($slide != "") {
        if (not regex.matches('^[1-9][0-9]{0,5}$', $slide)) {
            throw startError("slide wants a slide number from 1, got \"" + $slide + "\"");
        }
        $out.slide = convert.toInt($slide);
        def total as int init len($deck.slides);
        if ($out.slide > $total) {
            throw startError("slide " + $slide + " is past the end; the deck has " +
                convert.toString($total) + " slide(s)");
        }
    }
    if ($out.notes and not $opts.notes) {
        throw startError("notes: open needs the notes; drop --no-notes or set notes: closed");
    }
    return $out;
}

/**
 * The start state as `data-` attributes on the deck element.
 * @param start {Start} the resolved start
 * @return {string} the attributes, each preceded by a space
 */
func startAttributes(start as Start) {
    def notes as string init "closed";
    if ($start.notes) {
        $notes = "open";
    }
    def overview as string init "closed";
    if ($start.overview) {
        $overview = "open";
    }
    return " data-notes=\"" + $notes + "\" data-slide=\"" + convert.toString($start.slide) +
        "\" data-overview=\"" + $overview + "\"";
}

/**
 * The name of the theme a deck should render with, "" for the default.
 *
 * An explicit option wins over the deck's front matter, which wins over the
 * default, so `--theme` always overrides what the file asked for.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {string} the theme name as given
 */
export func themeName(deck as slides.Deck, opts as Options) {
    if (strings.trim($opts.theme) != "") {
        return $opts.theme;
    }
    return $deck.theme;
}

/**
 * Resolve the mode the page opens in: `--mode`, else the deck's `mode:`, else
 * light. The viewer can still switch it with m, or with `?mode=` in the URL.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {string} "light" or "dark"
 * @throws {Error} kind "theme" on any other value
 */
export func pickMode(deck as slides.Deck, opts as Options) {
    return theme.mode(startValue($deck, $opts.mode, "mode"));
}

/**
 * Resolve the palette the page opens with.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {theme.Theme} the theme's palette for the opening mode
 * @throws {Error} kind "theme" when the theme or the mode is unknown
 */
export func pickTheme(deck as slides.Deck, opts as Options) {
    return theme.theme(themeName($deck, $opts), pickMode($deck, $opts));
}

/**
 * Resolve the stage a deck should render on.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {theme.Stage} the geometry to use
 * @throws {Error} kind "theme" when either name is unknown
 */
export func pickStage(deck as slides.Deck, opts as Options) {
    if (strings.trim($opts.ratio) != "") {
        return theme.stage($opts.ratio);
    }
    return theme.stage($deck.ratio);
}

/**
 * Every slide transition the slideshow knows, in listing order.
 * @return {list of string} the names `pickTransition` accepts
 */
export func transitions() {
    return ["none", "fade", "slide", "zoom"];
}

/**
 * Resolve the transition a deck should present with.
 *
 * An explicit option wins over the deck's `transition:` front-matter key,
 * which wins over the default. A name is matched case-insensitively.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {string} one of `transitions()`
 * @throws {Error} kind "theme" when the chosen name is unknown
 */
export func pickTransition(deck as slides.Deck, opts as Options) {
    def want as string init strings.lower(strings.trim($opts.transition));
    if ($want == "") {
        $want = strings.lower(slides.metaOr($deck.meta, "transition", DEFAULT_TRANSITION));
    }
    if (lists.contains(transitions(), $want)) {
        return $want;
    }
    throw Error{
        kind: "theme",
        message: "unknown transition \"" + $want + "\"; known: " +
            strings.join(transitions(), ", "),
        file: "",
        line: 0,
        col: 0
    };
}

/**
 * Escape a string for use inside a double-quoted HTML attribute.
 *
 * `html.escape` covers a text node - `&`, `<`, `>` - but leaves `"` alone, so
 * a deck title holding a quotation mark would end the attribute early and let
 * the rest of it be read as markup. Every attribute value goes through here.
 * @param value {string} the raw value
 * @return {string} the value with `&`, `<`, `>` and `"` replaced by entities
 */
export func attrValue(value as string) {
    return strings.replace(html.escape($value), "\"", "&quot;");
}

/**
 * Whether code blocks are highlighted: the caller's option, and the deck's
 * `highlight:` front-matter key, which is checked even when the option is off.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {bool} true when both allow it
 * @throws {Error} kind "highlight" when the deck's value is not true or false
 */
export func pickHighlight(deck as slides.Deck, opts as Options) {
    def wanted as bool init highlight.enabled(slides.metaOr($deck.meta, "highlight", ""));
    return $opts.highlight and $wanted;
}

/**
 * Render one slide's Markdown body to HTML.
 *
 * A MathML element (see `mathml.j`) is lifted out before the tree is rendered
 * and put back afterwards, so it reaches the page as markup whatever
 * `rawHtml` says, while any other HTML keeps the treatment `rawHtml` gives it.
 * A picture named in `embedded` is carried inside the page.
 * @param slide {slides.Slide} the slide to render
 * @param opts {Options} the caller's options, for `rawHtml`, `highlight` and
 *     `embedded`
 * @return {string} the slide's inner HTML
 */
export func body(slide as slides.Slide, opts as Options) {
    def tree as doctree.Node init markdown.parse($slide.body);
    def maths as list of string init [];
    if (mathml.holds($tree)) {
        def taken as mathml.Rewritten init mathml.rewrite($tree, "mark", 0);
        $tree = $taken.node;
        $maths = $taken.taken;
    }
    def out as string init "";
    if ($opts.highlight) {
        $out = highlightedTree($tree, $slide.body, $opts.rawHtml);
    } else {
        def options as doctree.HtmlOptions;
        $options.allowRawHtml = $opts.rawHtml;
        $out = doctree.renderHtml($tree, $options);
    }
    return embed(withMaths(keyCaps($out), $maths), $opts.embedded);
}

/**
 * Put the MathML elements `mathml.rewrite` took out back in place of their
 * placeholders. A display element's placeholder may come back wrapped in a
 * paragraph, which a block of maths does not belong in, so that is undone
 * first.
 * @param html {string} the rendered slide
 * @param maths {list of string} the elements, in placeholder order
 * @return {string} the slide with its maths
 */
export func withMaths(html as string, maths as list of string) {
    def out as string init $html;
    for (def k in 0..len($maths)) {
        def mark as string init mathml.placeholder($k);
        $out = strings.replace($out, "<p>" + $mark + "</p>", $maths[$k]);
        $out = strings.replace($out, $mark, $maths[$k]);
    }
    return $out;
}

/**
 * Carry pictures inside the page: each `src` attribute that names a key of
 * `embedded` exactly is pointed at its `data:` URL instead.
 * @param html {string} the rendered slide
 * @param embedded {map of string to string} image target to `data:` URL
 * @return {string} the slide with those pictures inline
 */
export func embed(html as string, embedded as map of string to string) {
    def out as string init $html;
    for (def url in maps.keys($embedded)) {
        $out = strings.replace(
            $out,
            'src="' + attrValue($url) + '"',
            'src="' + attrValue($embedded[$url]) + '"');
    }
    return $out;
}

/**
 * One fenced code block lifted out of a slide for highlighting.
 * @field lang {string} the fence's language tag
 * @field text {string} the block's source
 */
export def struct CodeBlock {
    lang as string,
    text as string
};

/**
 * A Markdown tree with its highlightable code blocks swapped for placeholders.
 * @field node {doctree.Node} the tree, each such block's text a placeholder
 * @field codes {list of CodeBlock} the blocks taken out, in document order
 */
export def struct Marked {
    node as doctree.Node,
    codes as list of CodeBlock
};

/**
 * Render Markdown to HTML with every code block in a known language
 * highlighted.
 *
 * Each such block's text is swapped for a placeholder made of letters and
 * digits before the tree is rendered, and the placeholder is replaced by the
 * highlighted HTML afterwards. The renderer's escaping is therefore never
 * undone: the highlighter escapes the source itself, and raw HTML the deck
 * writes elsewhere (with `--raw-html`) is never mistaken for a code block.
 * @param md {string} the Markdown source
 * @param rawHtml {bool} pass raw HTML in the Markdown through unescaped
 * @return {string} the rendered HTML
 */
export func highlighted(md as string, rawHtml as bool) {
    return highlightedTree(markdown.parse($md), $md, $rawHtml);
}

/**
 * `highlighted` over a tree that is already parsed.
 * @param tree {doctree.Node} the parsed Markdown
 * @param md {string} its source, which the placeholders must not occur in
 * @param rawHtml {bool} pass raw HTML in the Markdown through unescaped
 * @return {string} the rendered HTML
 */
export func highlightedTree(tree as doctree.Node, md as string, rawHtml as bool) {
    def prefix as string init placeholderPrefix($md);
    def marked as Marked init markCode($tree, $prefix, 0);
    # A zero value, as `markdown.toHtmlWith` builds it: a literal of another
    # module's struct must name every field unless that module is installed.
    def options as doctree.HtmlOptions;
    $options.allowRawHtml = $rawHtml;
    def out as string init doctree.renderHtml($marked.node, $options);
    for (def k in 0..len($marked.codes)) {
        def c as CodeBlock init $marked.codes[$k];
        $out = strings.replace(
            $out,
            ">" + placeholder($prefix, $k) + "</code>",
            ">" + highlight.toHtml($c.text, $c.lang) + "</code>");
    }
    return $out;
}

/**
 * A placeholder stem that occurs nowhere in the source, so no text of the
 * deck can be taken for a placeholder.
 * @param md {string} the Markdown source
 * @return {string} letters only
 */
export func placeholderPrefix(md as string) {
    def prefix as string init "cantripcode";
    while (strings.contains($md, $prefix)) {
        $prefix = $prefix + "q";
    }
    return $prefix;
}

/**
 * The placeholder for one code block. The index is closed off on both sides,
 * so the first block's placeholder is not part of the eleventh's.
 * @param prefix {string} the stem from `placeholderPrefix`
 * @param index {int} the block's 0-based position
 * @return {string} letters and digits only
 */
func placeholder(prefix as string, index as int) {
    return $prefix + "x" + convert.toString($index) + "x";
}

/**
 * Swap each highlightable code block below a node for its placeholder.
 * @param node {doctree.Node} the subtree to walk
 * @param prefix {string} the placeholder stem
 * @param first {int} the index the first block found here takes
 * @return {Marked} the rewritten subtree and the blocks taken out of it
 */
export func markCode(node as doctree.Node, prefix as string, first as int) {
    def out as doctree.Node init $node;
    def codes as list of CodeBlock init [];
    if ($node.kind == "code" and highlight.handles($node.lang)) {
        $codes[] = CodeBlock{lang: $node.lang, text: $node.text};
        $out.text = placeholder($prefix, $first);
    }
    def kids as list of doctree.Node init [];
    for (def child in $node.children) {
        def m as Marked init markCode($child, $prefix, $first + len($codes));
        $kids[] = $m.node;
        for (def c in $m.codes) {
            $codes[] = $c;
        }
    }
    $out.children = $kids;
    return Marked{node: $out, codes: $codes};
}

/**
 * Restore `<kbd>` key caps that the Markdown renderer escaped.
 *
 * Unless raw HTML is allowed the renderer escapes every inline tag, so
 * `<kbd>s</kbd>` would show its own tags. A key
 * cap is the one inline element a slide about software keeps needing, and an
 * attribute-free `<kbd>` can carry no script, so exactly the escaped
 * `&lt;kbd&gt;` and `&lt;/kbd&gt;` become tags again. Text inside a `<code>`
 * element, inline or in a block, is left escaped, so a slide can still show
 * the tag as an example.
 * @param html {string} HTML from the Markdown renderer
 * @return {string} the same HTML with prose key caps as real elements
 */
export func keyCaps(html as string) {
    def parts as list of string init [];
    def at as int init 0;
    while ($at < len($html)) {
        def open as int init strings.indexOf($html, "<code", $at);
        if ($open < 0) {
            $parts[] = unescapeKbd(strings.substring($html, $at, len($html)));
            break;
        }
        $parts[] = unescapeKbd(strings.substring($html, $at, $open));
        def close as int init strings.indexOf($html, "</code>", $open);
        if ($close < 0) {
            $parts[] = strings.substring($html, $open, len($html));
            break;
        }
        $parts[] = strings.substring($html, $open, $close + len("</code>"));
        $at = $close + len("</code>");
    }
    return strings.join($parts, "");
}

/**
 * Turn escaped `<kbd>` and `</kbd>` tags back into markup.
 * @param text {string} HTML known to hold no code element
 * @return {string} the text with its escaped key-cap tags restored
 */
export func unescapeKbd(text as string) {
    def out as string init strings.replace($text, "&lt;kbd&gt;", "<kbd>");
    return strings.replace($out, "&lt;/kbd&gt;", "</kbd>");
}

/**
 * Render one slide as a `<section>`, with its furniture and notes.
 * @param slide {slides.Slide} the slide to render
 * @param total {int} the deck's slide count, for the counter
 * @param opts {Options} the caller's options
 * @return {string} one `<section class="cantrip-slide">` element
 */
export func section(slide as slides.Slide, total as int, opts as Options) {
    return sectionIn($slide, $total, $opts, locale.words("en"));
}

/**
 * `section`, naming a slide without a heading in the deck's language.
 * @param slide {slides.Slide} the slide to render
 * @param total {int} how many slides the deck has, for the counter
 * @param opts {Options} the caller's options
 * @param words {locale.Words} the slideshow's words
 * @return {string} one `<section class="cantrip-slide">` element
 */
export func sectionIn(slide as slides.Slide, total as int, opts as Options, words as locale.Words) {
    def out as string init "<section class=\"cantrip-slide\" id=\"cantrip-slide-" +
        convert.toString($slide.number) + "\" data-n=\"" +
        convert.toString($slide.number) + "\" aria-label=\"" +
        attrValue(labelIn($slide, $words)) + "\">";
    $out = $out + body($slide, $opts);
    if (strings.trim($opts.footer) != "") {
        $out = $out + "<div class=\"cantrip-slide-footer\">" + html.escape($opts.footer) + "</div>";
    }
    if ($opts.numbers) {
        $out = $out + "<div class=\"cantrip-slide-number\">" + convert.toString($slide.number) +
            " / " + convert.toString($total) + "</div>";
    }
    if ($opts.notes and $slide.notes != "") {
        $out = $out + "<div class=\"cantrip-slide-notes\" hidden>" +
            keyCaps(markdown.toHtmlWith($slide.notes, markdown.HtmlOptions{allowRawHtml: false})) +
            "</div>";
    }
    return $out + "</section>";
}

/**
 * A human label for one slide, used as its accessible name.
 * @param slide {slides.Slide} the slide to label
 * @return {string} the slide's title, else "Slide N"
 */
export func label(slide as slides.Slide) {
    return labelIn($slide, locale.words("en"));
}

/**
 * `label` in the deck's language.
 * @param slide {slides.Slide} the slide to label
 * @param words {locale.Words} the slideshow's words
 * @return {string} the slide's title, else the word for a slide and its number
 */
export func labelIn(slide as slides.Slide, words as locale.Words) {
    if (strings.trim($slide.title) != "") {
        return $slide.title;
    }
    return $words.slide + " " + convert.toString($slide.number);
}

/**
 * The overview grid: one clickable thumbnail per slide.
 * @param deck {slides.Deck} the deck to summarize
 * @return {string} the `<div id="cantrip-overview">` element, hidden by default
 */
export func overview(deck as slides.Deck) {
    def words as locale.Words init locale.words(language($deck));
    # Collected and joined once: growing one string per slide copied the
    # whole grid on every pass, quadratic in the slide count.
    def parts as list of string init [
        "<div id=\"cantrip-overview\" hidden aria-label=\"" + attrValue($words.overview) + "\">"
    ];
    for (def slide in $deck.slides) {
        $parts[] = "<div class=\"cantrip-thumb\" tabindex=\"0\" role=\"button\" data-go=\"" +
            convert.toString($slide.number) + "\"><div class=\"cantrip-thumb-n\">" +
            convert.toString($slide.number) + "</div><div class=\"cantrip-thumb-t\">" +
            html.escape(labelIn($slide, $words)) + "</div></div>";
    }
    $parts[] = "</div>";
    return strings.join($parts, "");
}

/**
 * The document head: metadata, the title, and the theme's stylesheet with
 * both of its palettes.
 * @param deck {slides.Deck} the deck being rendered, for its metadata
 * @param name {string} the theme name, "" for the default
 * @param s {theme.Stage} the resolved stage
 * @return {string} everything from `<head>` to `</head>`
 * @throws {Error} kind "theme" when the theme name is unknown
 */
export func head(deck as slides.Deck, name as string, s as theme.Stage) {
    return headWith($deck, $name, $s, "");
}

/**
 * `head`, with the page's icon.
 * @param deck {slides.Deck} the deck, for its title and metadata
 * @param name {string} the theme name
 * @param s {theme.Stage} the stage geometry
 * @param favicon {string} the icon's `href`, "" for none
 * @return {string} the `<head>` element
 * @throws {Error} kind "theme" when the theme name is unknown
 */
export func headWith(deck as slides.Deck, name as string, s as theme.Stage, favicon as string) {
    def light as theme.Theme init theme.theme($name, "light");
    def dark as theme.Theme init theme.theme($name, "dark");
    def title as string init $deck.title;
    if (strings.trim($title) == "") {
        $title = locale.words(language($deck)).untitled;
    }
    def out as string init "<head><meta charset=\"utf-8\">";
    $out = $out + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">";
    $out = $out + "<meta name=\"generator\" content=\"" + GENERATOR + "\">";
    if (strings.trim($deck.author) != "") {
        $out = $out + "<meta name=\"author\" content=\"" + attrValue($deck.author) + "\">";
    }
    if (strings.trim($deck.date) != "") {
        $out = $out + "<meta name=\"date\" content=\"" + attrValue($deck.date) + "\">";
    }
    # What a search engine shows under the title: `description`, else the PDF's
    # `subject`, so one key serves both outputs.
    def description as string init strings.trim(slides.metaOr(
        $deck.meta,
        "description",
        slides.metaOr($deck.meta, "subject", "")));
    if ($description != "") {
        $out = $out + "<meta name=\"description\" content=\"" + attrValue($description) + "\">";
    }
    def keywords as string init strings.trim(slides.metaOr($deck.meta, "keywords", ""));
    if ($keywords != "") {
        $out = $out + "<meta name=\"keywords\" content=\"" + attrValue($keywords) + "\">";
    }
    $out = $out + "<title>" + html.escape($title) + "</title>";
    if ($favicon != "") {
        $out = $out + "<link rel=\"icon\" href=\"" + attrValue($favicon) + "\">";
    }
    $out = $out + "<style>" + theme.css($light, $dark, $s) + "</style></head>";
    return $out;
}

/**
 * The keyboard-help overlay.
 * @return {string} the `<div id="cantrip-help">` element, hidden by default
 */
export func helpPanel() {
    return helpPanelIn(locale.words("en"));
}

/**
 * The keyboard-help overlay in the deck's language.
 * @param words {locale.Words} the slideshow's words
 * @return {string} the `<div id="cantrip-help">` element, hidden by default
 */
export func helpPanelIn(words as locale.Words) {
    def rows as list of string init [
        helpRow('<kbd>&rarr;</kbd> <kbd>space</kbd> <kbd>n</kbd>', $words.nextSlide),
        helpRow('<kbd>&larr;</kbd> <kbd>p</kbd>', $words.previousSlide),
        helpRow('<kbd>home</kbd> <kbd>end</kbd>', $words.firstLast),
        helpRow('<kbd>1</kbd>..<kbd>9</kbd> <kbd>enter</kbd>', $words.jump),
        helpRow('<kbd>o</kbd>', $words.overviewKey),
        helpRow('<kbd>s</kbd>', $words.notesKey),
        helpRow('<kbd>m</kbd>', $words.modeKey),
        helpRow('<kbd>f</kbd>', $words.fullscreenKey),
        helpRow('<kbd>?</kbd>', $words.helpKey),
        helpRow('<kbd>esc</kbd>', $words.escKey)
    ];
    return '<div id="cantrip-help" hidden aria-label="' + attrValue($words.shortcuts) +
        '"><table>' +
        strings.join($rows, "") + '</table></div>';
}

# helpRow is one line of the keyboard help: the keys, and what they do.
func helpRow(keys as string, what as string) {
    return '<tr><td>' + $keys + '</td><td>' + html.escape($what) + '</td></tr>';
}

/**
 * The button bar for touch screens, which have no keys to press: overview,
 * speaker notes (when the page has them), light / dark mode and fullscreen,
 * each doing what its key does. The stylesheet shows it only once the script
 * has seen a finger (at once on a device with a touch screen, otherwise at the
 * first touch), and the script removes the fullscreen button where the browser
 * has no fullscreen.
 * @param withNotes {bool} whether the page carries the notes panel
 * @return {string} the `<nav id="cantrip-touchbar">` element
 */
export func touchBar(withNotes as bool) {
    return touchBarIn($withNotes, locale.words("en"));
}

/**
 * The touch bar, labelled in the deck's language.
 * @param withNotes {bool} whether the page carries the notes panel
 * @param words {locale.Words} the slideshow's words
 * @return {string} the `<nav id="cantrip-touchbar">` element
 */
export func touchBarIn(withNotes as bool, words as locale.Words) {
    def svg as string init '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
        'stroke-width="2" aria-hidden="true">';
    def parts as list of string init [
        '<nav id="cantrip-touchbar" aria-label="' + attrValue($words.controls) + '">',
        '<button type="button" data-act="overview" aria-label="' +
            attrValue($words.overviewButton) +
            '">' + $svg +
            '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/>' +
            '<rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>' +
            '</svg></button>'
    ];
    if ($withNotes) {
        $parts[] = '<button type="button" data-act="notes" aria-label="' + attrValue($words.notes) +
            '">' + $svg +
            '<path d="M4 6h16M4 12h16M4 18h10"/></svg></button>';
    }
    $parts[] = '<button type="button" data-act="mode" aria-label="' + attrValue($words.modeButton) +
        '">' + $svg +
        '<circle cx="12" cy="12" r="8"/><path d="M12 4a8 8 0 0 1 0 16z" fill="currentColor"/>' +
        '</svg></button>';
    $parts[] = '<button type="button" data-act="fullscreen" aria-label="' +
        attrValue($words.fullscreenButton) + '">' + $svg +
        '<path d="M4 9V4h5M15 4h5v5M20 15v5h-5M9 20H4v-5"/></svg></button>';
    $parts[] = "</nav>";
    return strings.join($parts, "");
}

/**
 * Render a whole deck as one HTML document.
 *
 * The result is a complete, self-contained file; a caller writes it as-is.
 * @param deck {slides.Deck} the deck to render
 * @param opts {Options} how to render it
 * @return {string} the whole HTML document, ending in a newline
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 * @throws {Error} kind "highlight" when the deck's `highlight:` is not true or false
 */
export func render(deck as slides.Deck, opts as Options) {
    def name as string init themeName($deck, $opts);
    def mode as string init pickMode($deck, $opts);
    def s as theme.Stage init pickStage($deck, $opts);
    def motion as string init pickTransition($deck, $opts);
    def start as Start init pickStart($deck, $opts);
    def total as int init len($deck.slides);
    def options as Options init $opts;
    $options.highlight = pickHighlight($deck, $opts);
    def words as locale.Words init locale.words(language($deck));
    def parts as list of string init [];
    $parts[] = "<!doctype html>";
    $parts[] = "<html lang=\"" + attrValue(language($deck)) + "\" data-mode=\"" + $mode + "\">";
    $parts[] = headWith($deck, $name, $s, $opts.favicon);
    $parts[] = "<body><div id=\"cantrip-progress\"></div>";
    $parts[] = "<main id=\"cantrip-deck\" data-w=\"" + convert.toString($s.width) + "\" data-h=\"" +
        convert.toString($s.height) + "\" data-transition=\"" + $motion + "\"" +
        startAttributes($start) + ">";
    for (def slide in $deck.slides) {
        $parts[] = sectionIn($slide, $total, $options, $words);
    }
    $parts[] = "</main>";
    $parts[] = overview($deck);
    if ($opts.notes) {
        $parts[] = '<aside id="cantrip-notes" hidden aria-label="' + attrValue($words.notes) +
            '" data-empty="' + attrValue($words.noNotes) + '"><h2>' + html.escape($words.notes) +
            '</h2><div id="cantrip-notes-body"></div></aside>';
    }
    $parts[] = touchBarIn($opts.notes, $words);
    $parts[] = helpPanelIn($words);
    $parts[] = "<script>" + script() + "</script>";
    $parts[] = "</body></html>";
    return strings.join($parts, "\n") + "\n";
}

/**
 * The document language, from front matter or defaulting to English.
 * @param deck {slides.Deck} the deck being rendered
 * @return {string} a BCP 47 language tag
 */
export func language(deck as slides.Deck) {
    return slides.metaOr($deck.meta, "lang", "en");
}

/**
 * The navigation script embedded in every deck.
 *
 * Held as a raw string so neither braces nor backslashes need escaping; it
 * therefore uses double quotes throughout, since a raw Jennifer string cannot
 * contain a single quote.
 * @return {string} the slideshow's JavaScript, without its `<script>` tags
 */
export func script() {
    return '
(function () {
    "use strict";
    // Every lookup is anchored at a child of body, so an {#id .class} list on
    // a heading in the deck can never be taken for a part of the slideshow.
    function part(id) { return document.querySelector("body > #cantrip-" + id); }
    var deck = part("deck");
    if (!deck) { return; }
    var slides = Array.prototype.slice.call(deck.querySelectorAll(":scope > .cantrip-slide"));
    if (!slides.length) { return; }
    var progress = part("progress");
    var notes = part("notes");
    var notesBody = notes ? notes.querySelector(":scope > #cantrip-notes-body") : null;
    var overview = part("overview");
    var help = part("help");
    var bar = part("touchbar");
    var stageW = parseInt(deck.dataset.w, 10) || 1280;
    var stageH = parseInt(deck.dataset.h, 10) || 720;
    var at = 0;
    var pending = "";
    // How the page opens: data-notes, data-slide and data-overview on the deck
    // (front matter or command line), overridden by ?notes=1|0 and
    // ?overview=1|0 in the URL and by a #<slide> hash. An unknown URL value is
    // ignored: it comes from the viewer, not from the author.
    var query = new URLSearchParams(location.search);
    function asked(name, fallback) {
        var v = query.get(name);
        if (v === "1") { return true; }
        if (v === "0") { return false; }
        return fallback;
    }
    // Notes the deck opens on a narrow or short window would cover the slide,
    // so there they start closed unless the URL asks for them; s opens them.
    var roomy = window.matchMedia("(min-width: 800px) and (min-height: 560px)").matches;
    var startNotes = asked("notes", deck.dataset.notes === "open" && roomy);
    var startOverview = asked("overview", deck.dataset.overview === "open");
    // The mode the page was built with, unless ?mode=light|dark|auto asks for
    // another; m switches it. Both palettes are in the stylesheet, and "auto"
    // follows the system setting until m picks one.
    var root = document.documentElement;
    var askedMode = query.get("mode");
    if (askedMode === "light" || askedMode === "dark" || askedMode === "auto") {
        root.dataset.mode = askedMode;
    }
    function shownMode() {
        if (root.dataset.mode !== "auto") { return root.dataset.mode; }
        return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }
    function toggleMode() {
        root.dataset.mode = shownMode() === "dark" ? "light" : "dark";
    }
    var startSlide = (parseInt(deck.dataset.slide, 10) || 1) - 1;

    function clamp(n) { return Math.max(0, Math.min(slides.length - 1, n)); }

    // The panel is as tall as the longest notes in the deck (the CSS caps it
    // at 30% of the window), measured once per opening and window size, so it
    // keeps its height from slide to slide and the slide is not rescaled on
    // every step. While it is open the deck ends above it.
    function notesText(i) {
        var src = slides[i].querySelector(":scope > div.cantrip-slide-notes:last-child");
        if (src) { return src.innerHTML; }
        var empty = document.createElement("p");
        empty.textContent = part("notes").dataset.empty;
        return empty.outerHTML;
    }

    function sizeNotes() {
        if (!notes || notes.hidden) {
            deck.style.bottom = "";
            return;
        }
        notes.style.height = "";
        var tallest = 0;
        for (var i = 0; i < slides.length; i++) {
            notesBody.innerHTML = notesText(i);
            tallest = Math.max(tallest, notes.offsetHeight);
        }
        notesBody.innerHTML = notesText(at);
        notes.style.height = tallest + "px";
        deck.style.bottom = tallest + "px";
    }

    // While the notes are open the deck ends above them, so the slide is
    // scaled into the space that is left.
    function fit() {
        var w = deck.clientWidth || window.innerWidth;
        var h = deck.clientHeight || window.innerHeight;
        var k = Math.min(w / stageW, h / stageH);
        slides.forEach(function (s) { s.style.transform = "scale(" + k + ")"; });
    }

    function setNotes(open) {
        if (!notes) { return; }
        notes.hidden = !open;
        deck.classList.toggle("cantrip-notes-open", open);
        sizeNotes();
        fit();
    }

    function showNotes() {
        if (!notes) { return; }
        notesBody.innerHTML = notesText(at);
    }

    function show(n, push) {
        at = clamp(n);
        slides.forEach(function (s, i) {
            s.classList.toggle("cantrip-past", i < at);
            s.classList.toggle("cantrip-current", i === at);
            s.classList.toggle("cantrip-future", i > at);
        });
        progress.style.width = ((at + 1) / slides.length * 100) + "%";
        if (notes && !notes.hidden) { showNotes(); }
        if (push !== false) {
            var want = "#" + (at + 1);
            if (location.hash !== want) { history.replaceState(null, "", want); }
        }
        fit();
    }

    function fromHash() {
        var n = parseInt(location.hash.replace("#", ""), 10);
        return isNaN(n) ? startSlide : n - 1;
    }

    // Fullscreen is how a deck is presented, and there the browser keeps Esc
    // for itself. Where it lets a page claim the key (the Keyboard Lock API,
    // in Chromium) the slideshow does, so Esc behaves as it does in a window; a
    // long press still leaves fullscreen. ownExit tells a fullscreen exit the
    // slideshow asked for (f, the touch bar) from one the browser made on its
    // own, which is Esc where the key cannot be claimed.
    var ownExit = false;
    function lockEscape() {
        if (navigator.keyboard && navigator.keyboard.lock) {
            navigator.keyboard.lock(["Escape"]).catch(function () {});
        }
    }
    function exitFullscreen() {
        ownExit = true;
        document.exitFullscreen();
    }
    function toggleFullscreen() {
        if (document.fullscreenElement) { exitFullscreen(); }
        else if (document.documentElement.requestFullscreen) {
            var p = document.documentElement.requestFullscreen();
            if (p && p.then) { p.then(lockEscape, function () {}); }
        }
    }

    function close() {
        overview.hidden = true;
        help.hidden = true;
    }

    // Escape with no overlay open leaves the slideshow for the page that
    // opened it. Slides change the address with replaceState, so one step back
    // is that page, with its own state (a search, a scroll position); a deck
    // opened in a new tab goes to it instead. Opened directly, nothing happens.
    var leaving = false;
    function leave() {
        var from = document.referrer;
        if (leaving || !from || from.split("#")[0] === location.href.split("#")[0]) { return; }
        leaving = true;
        if (history.length > 1) { history.back(); } else { location.href = from; }
    }

    // Esc, in a window or in fullscreen: close an open overlay, else end the
    // presentation (leave fullscreen and go back).
    function escape() {
        if (!overview.hidden || !help.hidden) { close(); return; }
        if (document.fullscreenElement) { exitFullscreen(); }
        leave();
    }

    // Fullscreen ended without the slideshow asking: the browser took Esc.
    document.addEventListener("fullscreenchange", function () {
        if (document.fullscreenElement) { ownExit = false; return; }
        if (navigator.keyboard && navigator.keyboard.unlock) { navigator.keyboard.unlock(); }
        if (ownExit) { ownExit = false; return; }
        escape();
    });

    function toggle(el) {
        var wasHidden = el.hidden;
        close();
        el.hidden = !wasHidden;
    }

    document.addEventListener("keydown", function (e) {
        if (e.metaKey || e.ctrlKey || e.altKey) { return; }
        var k = e.key;
        if (k >= "0" && k <= "9") { pending = pending + k; return; }
        if (k === "Enter") {
            if (pending) { show(parseInt(pending, 10) - 1); }
            pending = "";
            return;
        }
        pending = "";
        if (k === "ArrowRight" || k === "PageDown" || k === " " || k === "n") {
            show(at + 1); e.preventDefault();
        } else if (k === "ArrowLeft" || k === "PageUp" || k === "p") {
            show(at - 1); e.preventDefault();
        } else if (k === "Home") { show(0); e.preventDefault(); }
        else if (k === "End") { show(slides.length - 1); e.preventDefault(); }
        else if (k === "o") { toggle(overview); }
        else if (k === "s" && notes) { setNotes(notes.hidden); }
        else if (k === "m") { toggleMode(); }
        else if (k === "f") { toggleFullscreen(); }
        else if (k === "?") { toggle(help); }
        else if (k === "Escape") { escape(); }
    });

    overview.addEventListener("click", function (e) {
        var hit = e.target.closest(".cantrip-thumb[data-go]");
        if (!hit) { return; }
        close();
        show(parseInt(hit.dataset.go, 10) - 1);
    });

    overview.addEventListener("keydown", function (e) {
        if (e.key !== "Enter" && e.key !== " ") { return; }
        var hit = e.target.closest(".cantrip-thumb[data-go]");
        if (!hit) { return; }
        e.preventDefault();
        // Handled here: the deck-wide handler would otherwise read the same
        // space as "next slide" and land one past the slide just chosen.
        e.stopPropagation();
        close();
        show(parseInt(hit.dataset.go, 10) - 1);
    });

    // The touch bar shows for a moment when the page opens and after each
    // press of one of its buttons, then fades out so it does not cover the
    // slide; a tap on the middle third of the window shows or hides it. It
    // stays while the overview is open, since its button closes the overview.
    var barTimer = 0;
    function showBar(on) {
        if (!bar) { return; }
        on = on && bar.classList.contains("cantrip-touch");
        window.clearTimeout(barTimer);
        bar.classList.toggle("cantrip-shown", on);
        if (on) { barTimer = window.setTimeout(fadeBar, 3000); }
    }
    function fadeBar() {
        if (!overview.hidden) { showBar(true); return; }
        showBar(false);
    }

    // Touch, for a phone or tablet with no keyboard: a swipe left or right
    // turns the slide, and a tap on the right or left third of the window goes
    // forward or back, and one on the middle third shows or hides the bar.
    // Touch events rather than pointer events, because the browser cancels a
    // pointer once it treats the gesture as a pan. A swipe
    // that starts in a code block that scrolls sideways scrolls it instead, a
    // tap on a link follows the link, and a gesture with two fingers (a pinch)
    // turns nothing. Mouse clicks are left alone, so text stays selectable.
    var touch = null;
    function scrollsSideways(el) {
        for (; el && el !== deck; el = el.parentElement) {
            if (el.scrollWidth > el.clientWidth + 1) { return true; }
        }
        return false;
    }
    deck.addEventListener("touchstart", function (e) {
        if (e.touches.length !== 1) { touch = null; return; }
        var t = e.touches[0];
        touch = { x: t.clientX, y: t.clientY, scrolls: scrollsSideways(e.target) };
    }, { passive: true });
    deck.addEventListener("touchcancel", function () { touch = null; }, { passive: true });
    deck.addEventListener("touchend", function (e) {
        if (!touch || e.touches.length !== 0) { touch = null; return; }
        var t = e.changedTouches[0];
        var dx = t.clientX - touch.x;
        var dy = t.clientY - touch.y;
        var scrolls = touch.scrolls;
        touch = null;
        if (Math.abs(dx) > 40 && Math.abs(dx) > 1.5 * Math.abs(dy)) {
            if (!scrolls) { show(dx < 0 ? at + 1 : at - 1); }
            return;
        }
        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) { return; }
        if (e.target.closest("a, button, summary, input, textarea, select")) { return; }
        var box = deck.getBoundingClientRect();
        var x = t.clientX - box.left;
        if (x > box.width * 2 / 3) { show(at + 1); e.preventDefault(); }
        else if (x < box.width / 3) { show(at - 1); e.preventDefault(); }
        else if (bar) { showBar(!bar.classList.contains("cantrip-shown")); e.preventDefault(); }
    });

    // The touch bar is for fingers. Any device with a touch screen gets it
    // from the start, including one whose main pointer is a touchpad or a
    // mouse (a ChromeOS tablet, a touch laptop); where the browser reports no
    // finger at all, the first touch brings it in.
    function useTouch() { if (bar) { bar.classList.add("cantrip-touch"); } }
    if (window.matchMedia && window.matchMedia("(pointer: coarse), (any-pointer: coarse)").matches) {
        useTouch();
    }
    document.addEventListener("touchstart", useTouch, { passive: true, once: true });

    // The touch bar does what the keys do. A browser without fullscreen (the
    // iPhone) gets no fullscreen button.
    if (bar) {
        var fs = bar.querySelector(":scope > [data-act=fullscreen]");
        if (fs && !document.documentElement.requestFullscreen) { fs.remove(); }
        bar.addEventListener("click", function (e) {
            var b = e.target.closest("button[data-act]");
            if (!b) { return; }
            var act = b.dataset.act;
            showBar(true);
            if (act === "overview") { toggle(overview); }
            else if (act === "notes" && notes) { close(); setNotes(notes.hidden); }
            else if (act === "mode") { toggleMode(); }
            else if (act === "fullscreen") { toggleFullscreen(); }
        });
    }

    help.addEventListener("click", close);
    window.addEventListener("resize", function () { sizeNotes(); fit(); });
    window.addEventListener("hashchange", function () { show(fromHash(), false); });
    setNotes(startNotes && !!notes);
    show(fromHash(), false);
    if (startOverview) { overview.hidden = false; }
    showBar(true);
    // Transitions start after the first frame, so the deck opens on its slide.
    window.requestAnimationFrame(function () {
        window.requestAnimationFrame(function () { deck.classList.add("cantrip-ready"); });
    });
})();
';
}

/**
 * The script `cantrip serve` adds to the page it serves, and only to that
 * copy: it asks `path` for the build token every `ms` milliseconds and
 * reloads the page when the token changes. A file written by `html` or
 * `build` never carries it.
 * @param path {string} the token endpoint, such as `/.cantrip-reload`
 * @param ms {int} the polling interval in milliseconds
 * @return {string} the JavaScript, without its `<script>` tags
 */
export func reloadScript(path as string, ms as int) {
    return '(function () {
    "use strict";
    var seen = null;
    function poll() {
        fetch("' + $path +
        '", { cache: "no-store" }).then(function (r) { return r.text(); })
            .then(function (t) {
                if (seen !== null && t !== seen) { location.reload(); return; }
                seen = t;
                setTimeout(poll, ' + convert.toString($ms) +
        ');
            }, function () { setTimeout(poll, ' + convert.toString($ms) +
        '); });
    }
    poll();
})();';
}

/**
 * Splice a script into a page before its last `</body>`: the slideshow's own
 * closing tag, which a slide's text cannot produce, since the renderer escapes
 * it there.
 * @param page {string} the whole HTML document
 * @param script {string} the JavaScript to add
 * @return {string} the page with the script, or with it appended when the page
 *     has no `</body>`
 */
export func withScript(page as string, script as string) {
    def tag as string init "<script>" + $script + "</script>";
    def parts as list of string init strings.split($page, "</body>");
    if (len($parts) < 2) {
        return $page + $tag;
    }
    def at as int init len($page) - len($parts[len($parts) - 1]) - len("</body>");
    return $page[..$at] + $tag + $page[$at..];
}

/**
 * The page `cantrip serve` shows while the deck does not build: the error,
 * escaped, so the reader sees what to fix, and the next save tries again.
 * @param message {string} the error message
 * @return {string} a small HTML document
 */
export func errorPage(message as string) {
    return '<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>cantrip: the deck does not build</title>
<style>body { font: 16px/1.5 sans-serif; margin: 3em; color: #1a1a1a; background: #fff; }
pre { white-space: pre-wrap; background: #f4f5f7; padding: 1em; border-left: 4px solid #c0392b; }</style>
</head><body><h1>The deck does not build</h1><pre>' + html.escape($message) +
        '</pre><p>Fix the deck and save; this page reloads.</p></body></html>
';
}
