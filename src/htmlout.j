# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

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
use lists;
use convert;

import "html.j" as html;
import "markdown.j" as markdown;
import "./slides.j" as slides;
import "./theme.j" as theme;

/** The generator name written into the document's meta tags. */
export def const GENERATOR as string init "cantrip";

/** The transition used when neither the deck nor the caller picks one. */
export def const DEFAULT_TRANSITION as string init "fade";

/**
 * What the HTML renderer needs beyond the deck itself.
 * @field theme {string} theme name, "" for the deck's own or the default
 * @field ratio {string} ratio name, "" for the deck's own or the default
 * @field footer {string} text shown bottom-left on every slide
 * @field notes {bool} embed speaker notes for the presenter panel
 * @field numbers {bool} show the slide counter bottom-right
 * @field rawHtml {bool} pass raw HTML in the Markdown through unescaped
 * @field transition {string} transition name, "" for the deck's own or the default
 */
export def struct Options {
    theme as string,
    ratio as string,
    footer as string,
    notes as bool,
    numbers as bool,
    rawHtml as bool,
    transition as string
};

/**
 * The default options: safe, numbered, with notes embedded.
 * @return {Options} a fresh option set a caller can copy and adjust
 */
export func defaults() {
    return Options{
        theme: "",
        ratio: "",
        footer: "",
        notes: true,
        numbers: true,
        rawHtml: false,
        transition: ""
    };
}

/**
 * Resolve the theme a deck should render with.
 *
 * An explicit option wins over the deck's front matter, which wins over the
 * default, so `--theme` always overrides what the file asked for.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {theme.Theme} the theme to use
 * @throws {Error} kind "theme" when either name is unknown
 */
export func pickTheme(deck as slides.Deck, opts as Options) {
    if (strings.trim($opts.theme) != "") {
        return theme.theme($opts.theme);
    }
    return theme.theme($deck.theme);
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
 * Render one slide's Markdown body to HTML.
 * @param slide {slides.Slide} the slide to render
 * @param opts {Options} the caller's options, for `rawHtml`
 * @return {string} the slide's inner HTML
 */
export func body(slide as slides.Slide, opts as Options) {
    return keyCaps(markdown.toHtmlWith(
        $slide.body,
        markdown.HtmlOptions{allowRawHtml: $opts.rawHtml}));
}

/**
 * Restore `<kbd>` key caps that the Markdown renderer escaped.
 *
 * The renderer escapes every inline tag - even with raw HTML allowed, which
 * covers block HTML only - so `<kbd>s</kbd>` would show its own tags. A key
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
 * @return {string} one `<section class="slide">` element
 */
export func section(slide as slides.Slide, total as int, opts as Options) {
    def out as string init "<section class=\"slide\" id=\"slide-" +
        convert.toString($slide.number) + "\" data-n=\"" +
        convert.toString($slide.number) + "\" aria-label=\"" +
        attrValue(label($slide)) + "\">";
    $out = $out + body($slide, $opts);
    if (strings.trim($opts.footer) != "") {
        $out = $out + "<div class=\"slide-footer\">" + html.escape($opts.footer) + "</div>";
    }
    if ($opts.numbers) {
        $out = $out + "<div class=\"slide-number\">" + convert.toString($slide.number) +
            " / " + convert.toString($total) + "</div>";
    }
    if ($opts.notes and $slide.notes != "") {
        $out = $out + "<div class=\"slide-notes\" hidden>" +
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
    if (strings.trim($slide.title) != "") {
        return $slide.title;
    }
    return "Slide " + convert.toString($slide.number);
}

/**
 * The overview grid: one clickable thumbnail per slide.
 * @param deck {slides.Deck} the deck to summarize
 * @return {string} the `<div id="overview">` element, hidden by default
 */
export func overview(deck as slides.Deck) {
    def out as string init "<div id=\"overview\" hidden aria-label=\"Slide overview\">";
    for (def slide in $deck.slides) {
        $out = $out + "<div class=\"thumb\" tabindex=\"0\" role=\"button\" data-go=\"" +
            convert.toString($slide.number) + "\"><div class=\"n\">" +
            convert.toString($slide.number) + "</div><div class=\"t\">" +
            html.escape(label($slide)) + "</div></div>";
    }
    return $out + "</div>";
}

/**
 * The document head: metadata, the title, and the theme's stylesheet.
 * @param deck {slides.Deck} the deck being rendered, for its metadata
 * @param t {theme.Theme} the resolved theme
 * @param s {theme.Stage} the resolved stage
 * @return {string} everything from `<head>` to `</head>`
 */
export func head(deck as slides.Deck, t as theme.Theme, s as theme.Stage) {
    def title as string init $deck.title;
    if (strings.trim($title) == "") {
        $title = "Slides";
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
    $out = $out + "<meta name=\"color-scheme\" content=\"" + colorScheme($t) + "\">";
    $out = $out + "<title>" + html.escape($title) + "</title>";
    $out = $out + "<style>" + theme.css($t, $s) + "</style></head>";
    return $out;
}

/**
 * The `color-scheme` value matching a theme's polarity.
 *
 * Declaring it keeps the browser from painting a light scrollbar and form
 * furniture over a dark deck.
 * @param t {theme.Theme} the resolved theme
 * @return {string} "dark" or "light"
 */
export func colorScheme(t as theme.Theme) {
    if ($t.dark) {
        return "dark";
    }
    return "light";
}

/**
 * The keyboard-help overlay.
 * @return {string} the `<div id="help">` element, hidden by default
 */
export func helpPanel() {
    return '<div id="help" hidden aria-label="Keyboard shortcuts"><table>' +
        '<tr><td><kbd>&rarr;</kbd> <kbd>space</kbd> <kbd>n</kbd></td><td>next slide</td></tr>' +
        '<tr><td><kbd>&larr;</kbd> <kbd>p</kbd></td><td>previous slide</td></tr>' +
        '<tr><td><kbd>home</kbd> <kbd>end</kbd></td><td>first / last slide</td></tr>' +
        '<tr><td><kbd>1</kbd>..<kbd>9</kbd> <kbd>enter</kbd></td><td>jump to a slide</td></tr>' +
        '<tr><td><kbd>o</kbd></td><td>overview</td></tr>' +
        '<tr><td><kbd>s</kbd></td><td>speaker notes</td></tr>' +
        '<tr><td><kbd>f</kbd></td><td>fullscreen</td></tr>' +
        '<tr><td><kbd>?</kbd></td><td>this help</td></tr>' +
        '<tr><td><kbd>esc</kbd></td><td>close an overlay</td></tr>' +
        '</table></div>';
}

/**
 * Render a whole deck as one HTML document.
 *
 * The result is a complete, self-contained file; a caller writes it as-is.
 * @param deck {slides.Deck} the deck to render
 * @param opts {Options} how to render it
 * @return {string} the whole HTML document, ending in a newline
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 */
export func render(deck as slides.Deck, opts as Options) {
    def t as theme.Theme init pickTheme($deck, $opts);
    def s as theme.Stage init pickStage($deck, $opts);
    def motion as string init pickTransition($deck, $opts);
    def total as int init len($deck.slides);
    def parts as list of string init [];
    $parts[] = "<!doctype html>";
    $parts[] = "<html lang=\"" + attrValue(language($deck)) + "\">";
    $parts[] = head($deck, $t, $s);
    $parts[] = "<body><div id=\"progress\"></div>";
    $parts[] = "<main id=\"deck\" data-w=\"" + convert.toString($s.width) + "\" data-h=\"" +
        convert.toString($s.height) + "\" data-transition=\"" + $motion + "\">";
    for (def slide in $deck.slides) {
        $parts[] = section($slide, $total, $opts);
    }
    $parts[] = "</main>";
    $parts[] = overview($deck);
    if ($opts.notes) {
        $parts[] = '<aside id="notes" hidden aria-label="Speaker notes">' +
            "<h2>Speaker notes</h2><div id=\"notes-body\"></div></aside>";
    }
    $parts[] = helpPanel();
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
    var deck = document.getElementById("deck");
    var slides = Array.prototype.slice.call(document.querySelectorAll(".slide"));
    if (!slides.length) { return; }
    var progress = document.getElementById("progress");
    var notes = document.getElementById("notes");
    var notesBody = document.getElementById("notes-body");
    var overview = document.getElementById("overview");
    var help = document.getElementById("help");
    var stageW = parseInt(deck.dataset.w, 10) || 1280;
    var stageH = parseInt(deck.dataset.h, 10) || 720;
    var at = 0;
    var pending = "";

    function clamp(n) { return Math.max(0, Math.min(slides.length - 1, n)); }

    function fit() {
        var k = Math.min(window.innerWidth / stageW, window.innerHeight / stageH);
        slides.forEach(function (s) { s.style.transform = "scale(" + k + ")"; });
    }

    function showNotes() {
        if (!notes) { return; }
        var src = slides[at].querySelector(".slide-notes");
        notesBody.innerHTML = src ? src.innerHTML : "<p>No notes for this slide.</p>";
    }

    function show(n, push) {
        at = clamp(n);
        slides.forEach(function (s, i) {
            s.classList.toggle("past", i < at);
            s.classList.toggle("current", i === at);
            s.classList.toggle("future", i > at);
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
        return isNaN(n) ? 0 : n - 1;
    }

    function close() {
        overview.hidden = true;
        help.hidden = true;
    }

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
        else if (k === "s" && notes) { notes.hidden = !notes.hidden; showNotes(); }
        else if (k === "f") {
            if (document.fullscreenElement) { document.exitFullscreen(); }
            else if (document.documentElement.requestFullscreen) {
                document.documentElement.requestFullscreen();
            }
        } else if (k === "?") { toggle(help); }
        else if (k === "Escape") { close(); }
    });

    overview.addEventListener("click", function (e) {
        var hit = e.target.closest("[data-go]");
        if (!hit) { return; }
        close();
        show(parseInt(hit.dataset.go, 10) - 1);
    });

    overview.addEventListener("keydown", function (e) {
        if (e.key !== "Enter" && e.key !== " ") { return; }
        var hit = e.target.closest("[data-go]");
        if (!hit) { return; }
        e.preventDefault();
        // Handled here: the deck-wide handler would otherwise read the same
        // space as "next slide" and land one past the slide just chosen.
        e.stopPropagation();
        close();
        show(parseInt(hit.dataset.go, 10) - 1);
    });

    help.addEventListener("click", close);
    window.addEventListener("resize", fit);
    window.addEventListener("hashchange", function () { show(fromHash(), false); });
    show(fromHash(), false);
    // Transitions start after the first frame, so the deck opens on its slide.
    window.requestAnimationFrame(function () {
        window.requestAnimationFrame(function () { deck.classList.add("ready"); });
    });
})();
';
}
