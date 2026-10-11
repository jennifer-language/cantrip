# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Render a deck as a paginated PDF, one page per slide.
 *
 * The page is the stage: a 16:9 deck lays out on 960x540-point pages, so a
 * viewer shows it full-bleed rather than re-fitting a portrait document. The
 * palette is the theme's print half - its light code shade and quote rule -
 * and the page stays white, because this is the artifact that gets printed.
 *
 * The `markdown` module sizes headings in fixed points meant for an 11-point
 * body. Set beside slide-sized body text they would come out smaller than the
 * prose, so each slide is laid out on a page two thirds the size, with a body
 * size to match, and the finished page is scaled up by 3/2. Every element,
 * headings included, keeps the proportions `markdown` designed it with.
 *
 * Like the `markdown` module it builds on, nothing here touches the
 * filesystem: a caller that wants pictures in the PDF loads their bytes and
 * passes them in, and `imageUrls` says which ones the deck asks for.
 * @module pdfout
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use strings;
use lists;
use convert;

import "markdown.j" as markdown;
import "pdf.j" as pdf;
import "./slides.j" as slides;
import "./theme.j" as theme;

/** The application name written into the PDF's Creator field. */
export def const CREATOR as string init "cantrip";

/** Body text size, in points, on the laid-out page; it prints at 3/2 that. */
export def const BODY_SIZE as int init 13;

/** Margin, in points, around a slide's content on the laid-out page. */
export def const MARGIN as int init 37;

/** Numerator of the scale from the laid-out page to the printed one. */
export def const SCALE_NUM as int init 3;

/** Denominator of the scale from the laid-out page to the printed one. */
export def const SCALE_DEN as int init 2;

/**
 * Pixel density pictures are laid out at. The laid-out page is scaled up by
 * 3/2, so 3/2 of the usual 96 keeps a picture at its usual printed size.
 */
export def const IMAGE_DPI as int init 144;

/**
 * What the PDF renderer needs beyond the deck itself.
 * @field theme {string} theme name, "" for the deck's own or the default
 * @field ratio {string} ratio name, "" for the deck's own or the default
 * @field footer {string} text shown bottom-left on every page
 * @field notes {bool} print each slide's speaker notes under its body
 * @field numbers {bool} draw a `page / total` footer
 * @field bookmarks {int} heading depth to add to the PDF outline, 0 for none
 * @field images {map of string to pdf.Image} pictures, keyed by source URL
 */
export def struct Options {
    theme as string,
    ratio as string,
    footer as string,
    notes as bool,
    numbers as bool,
    bookmarks as int,
    images as map of string to pdf.Image
};

/**
 * The default options: numbered, bookmarked one level deep, notes omitted.
 *
 * Notes are off by default because the PDF is the deck as the audience sees
 * it; `--notes` turns it into the presenter's copy.
 * @return {Options} a fresh option set a caller can copy and adjust
 */
export func defaults() {
    return Options{
        theme: "",
        ratio: "",
        footer: "",
        notes: false,
        numbers: true,
        bookmarks: 2,
        images: {}
    };
}

/**
 * Resolve the theme a deck should print with.
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
 * Resolve the page size a deck should print at.
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
 * Turn a theme colour into a `markdown` fill.
 * @param hex {string} a colour as `#rgb` or `#rrggbb`
 * @return {markdown.Fill} the matching fill
 * @throws {Error} kind "theme" when the string is not a hex colour
 */
export func fill(hex as string) {
    def c as theme.Rgb init theme.hexRgb($hex);
    return markdown.rgb($c.red, $c.green, $c.blue);
}

/**
 * Every image URL the deck refers to, in first-seen order, without repeats.
 *
 * The caller loads these and hands them back in `Options.images`; the keys
 * must match the URL as written in the Markdown, which is why this returns
 * the raw strings rather than resolved paths.
 * @param deck {slides.Deck} the deck to scan
 * @return {list of string} each distinct `![alt](url)` target
 */
export func imageUrls(deck as slides.Deck) {
    def found as list of string init [];
    for (def slide in $deck.slides) {
        def doc as markdown.Node init markdown.parse($slide.body);
        for (def url in collectImages($doc)) {
            if (not lists.contains($found, $url)) {
                $found[] = $url;
            }
        }
    }
    return $found;
}

/**
 * Walk a parsed Markdown tree and gather every image target.
 *
 * `markdown`'s selectors match direct children, and an image sits at
 * whatever depth its paragraph, list, or table cell puts it, so this recurses
 * rather than asking for a fixed path.
 * @param node {markdown.Node} the subtree to walk
 * @return {list of string} the `src` of every image below `node`, in order
 */
export func collectImages(node as markdown.Node) {
    def found as list of string init [];
    if (markdown.typeOf($node) == "image") {
        def src as string init markdown.attr($node, "href");
        if ($src == "") {
            $src = markdown.attr($node, "src");
        }
        if ($src != "") {
            $found[] = $src;
        }
    }
    for (def child in markdown.children($node)) {
        for (def deeper in collectImages($child)) {
            $found[] = $deeper;
        }
    }
    return $found;
}

/**
 * Build the `markdown` layout options for a deck.
 *
 * Heading shades are deliberately absent: a slide's heading carries the
 * theme's accent as text, and a filled band behind it reads as a table header
 * rather than a title.
 * @param deck {slides.Deck} the deck being rendered, for its metadata
 * @param opts {Options} the caller's options
 * @return {markdown.PdfOptions} options ready for `markdown.renderPdfDoc`
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 */
export func layout(deck as slides.Deck, opts as Options) {
    def t as theme.Theme init pickTheme($deck, $opts);
    def s as theme.Stage init pickStage($deck, $opts);
    def out as markdown.PdfOptions init markdown.pdfDefaults();
    $out.pageWidth = shrink($s.pageWidth);
    $out.pageHeight = shrink($s.pageHeight);
    $out.margin = MARGIN;
    $out.bodySize = BODY_SIZE;
    $out.title = $deck.title;
    $out.author = $deck.author;
    $out.subject = slides.metaOr($deck.meta, "subject", "");
    $out.keywords = slides.metaOr($deck.meta, "keywords", "");
    $out.creator = CREATOR;
    $out.bookmarkLevel = $opts.bookmarks;
    $out.codeFill = fill($t.printCodeBg);
    $out.quoteFill = fill($t.printCodeBg);
    $out.quoteRule = fill($t.printQuoteBar);
    $out.tableHeaderFill = fill($t.printCodeBg);
    $out.images = $opts.images;
    $out.imageDpi = IMAGE_DPI;
    return $out;
}

/**
 * A printed length as it is on the laid-out page.
 * @param points {int} a length on the printed page
 * @return {int} the same length before scaling up
 */
export func shrink(points as int) {
    return $points * SCALE_DEN // SCALE_NUM;
}

/**
 * A laid-out length as it prints.
 * @param points {int} a length on the laid-out page
 * @return {int} the same length after scaling up
 */
export func grow(points as int) {
    return $points * SCALE_NUM // SCALE_DEN;
}

/**
 * Scale every laid-out page up to the stage's printed size.
 *
 * Each content stream is wrapped in one scaling transform, so text, rules,
 * fills, and pictures grow together. The parts of a page that live outside
 * its content stream - link rectangles and bookmark targets - are scaled to
 * match. A running footer is added afterwards, at the printed size.
 * @param doc {pdf.Document} the document `markdown` laid out
 * @param s {theme.Stage} the stage it was laid out for
 * @return {pdf.Document} the same pages at the stage's page size
 */
export func magnify(doc as pdf.Document, s as theme.Stage) {
    def ratio as float init SCALE_NUM / SCALE_DEN;
    def matrix as string init convert.toString($ratio) + " 0 0 " + convert.toString($ratio) +
        " 0 0 cm";
    def pages as list of pdf.Page init [];
    for (def pg in $doc.pages) {
        def big as pdf.Page init $pg;
        $big.width = $s.pageWidth;
        $big.height = $s.pageHeight;
        $big.content = "q\n" + $matrix + "\n" + $pg.content + "\nQ\n";
        def links as list of pdf.LinkAnnot init [];
        for (def a in $pg.annots) {
            $links[] = pdf.LinkAnnot{
                x: grow($a.x),
                y: grow($a.y),
                width: grow($a.width),
                height: grow($a.height),
                uri: $a.uri
            };
        }
        $big.annots = $links;
        $pages[] = $big;
    }
    def marks as list of pdf.OutlineEntry init [];
    for (def m in $doc.outline) {
        def moved as pdf.OutlineEntry init $m;
        $moved.y = grow($m.y);
        $marks[] = $moved;
    }
    def out as pdf.Document init $doc;
    $out.pages = $pages;
    $out.outline = $marks;
    return $out;
}

/**
 * The running footer: the deck's own label on the left, pages on the right.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {pdf.PageLabel} the footer to attach, blank when both halves are off
 */
export func footer(deck as slides.Deck, opts as Options) {
    def out as pdf.PageLabel init pdf.pageLabel();
    def left as string init strings.trim($opts.footer);
    if ($left == "") {
        $left = strings.trim($deck.title);
    }
    $out.left = $left;
    if ($opts.numbers) {
        $out.right = "%page% / %pages%";
    }
    return $out;
}

/**
 * Lay a deck out as a finished PDF document, ready to serialise.
 *
 * Slides are laid out as one document with a page break between them, so a
 * slide whose content outgrows its page continues onto the next rather than
 * being clipped. A caller that needs both the bytes and the page count takes
 * them from this one document, so the count always describes the file that
 * was written - pictures included.
 * @param deck {slides.Deck} the deck to render
 * @param opts {Options} how to render it
 * @return {pdf.Document} the laid-out, scaled, footed document
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 * @throws {Error} kind "markdown" when a document exceeds the parser's budget
 */
export func document(deck as slides.Deck, opts as Options) {
    def source as string init slides.kbdToCode(slides.toMarkdown($deck, $opts.notes));
    def tree as markdown.Node init markdown.parse($source);
    def laid as pdf.Document init markdown.renderPdfDoc($tree, layout($deck, $opts));
    def doc as pdf.Document init magnify($laid, pickStage($deck, $opts));
    def label as pdf.PageLabel init footer($deck, $opts);
    if ($label.left != "" or $label.right != "") {
        $doc = pdf.setFooter($doc, $label);
    }
    return $doc;
}

/**
 * Render a deck as a PDF.
 * @param deck {slides.Deck} the deck to render
 * @param opts {Options} how to render it
 * @return {bytes} the finished PDF
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 * @throws {Error} kind "markdown" when a document exceeds the parser's budget
 */
export func render(deck as slides.Deck, opts as Options) {
    return pdf.render(document($deck, $opts));
}

/**
 * How many pages a rendered deck came to.
 *
 * A deck is one page per slide unless a slide overflowed, so comparing this
 * with the slide count is how a caller warns about an overfull slide. A
 * caller that also writes the PDF should count the pages of the `document`
 * it renders instead of laying the deck out twice.
 * @param deck {slides.Deck} the deck to render
 * @param opts {Options} how to render it
 * @return {int} the page count of the PDF `render` would produce
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 */
export func pageCount(deck as slides.Deck, opts as Options) {
    return pdf.getTotalPages(document($deck, $opts));
}

/**
 * A one-line summary of what `render` will produce, for `--verbose`.
 * @param deck {slides.Deck} the deck to describe
 * @param opts {Options} how it would be rendered
 * @return {string} the page size, page count, and theme
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 */
export func describe(deck as slides.Deck, opts as Options) {
    def s as theme.Stage init pickStage($deck, $opts);
    def t as theme.Theme init pickTheme($deck, $opts);
    return convert.toString($s.pageWidth) + "x" + convert.toString($s.pageHeight) +
        "pt, " + convert.toString(pageCount($deck, $opts)) + " page(s), theme " + $t.name;
}
