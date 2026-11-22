# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

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
use maps;
use convert;
use encoding;
use lists;
use math;

import "markdown.j" as markdown;
import "doctree.j" as doctree;
import "pdf.j" as pdf;
import "./slides.j" as slides;
import "./theme.j" as theme;
import "./highlight.j" as highlight;
import "./mathml.j" as mathml;

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
 * The fill a code panel is laid out with while code is highlighted: a colour
 * no theme uses, so the panels can be found in the laid-out pages and given
 * their real shade. See `paintCode`.
 */
export def const CODE_MARK as string init "#010203";

/**
 * What the PDF renderer needs beyond the deck itself.
 * @field theme {string} theme name, "" for the deck's own or the default
 * @field ratio {string} ratio name, "" for the deck's own or the default
 * @field footer {string} text shown bottom-left on every page
 * @field notes {bool} print each slide's speaker notes under its body
 * @field numbers {bool} draw a `page / total` footer
 * @field bookmarks {int} heading depth to add to the PDF outline, 0 for none
 * @field highlight {bool} colour code blocks in a language `highlight` knows;
 *     the deck's `highlight: false` turns it off too
 * @field images {map of string to pdf.Image} pictures, keyed by source URL
 */
export def struct Options {
    theme as string,
    ratio as string,
    footer as string,
    notes as bool,
    numbers as bool,
    bookmarks as int,
    highlight as bool,
    images as map of string to pdf.Image
};

/**
 * The default options: numbered, highlighted, bookmarked two levels deep,
 * notes omitted.
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
        highlight: true,
        images: {}
    };
}

/**
 * Resolve the theme a deck should print with.
 *
 * Paper is white, so a PDF always prints the theme's light palette; the
 * deck's `mode:` is still checked, so a typo there fails here too.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {theme.Theme} the theme's light palette
 * @throws {Error} kind "theme" when the theme or the deck's mode is unknown
 */
export func pickTheme(deck as slides.Deck, opts as Options) {
    theme.mode(slides.metaOr($deck.meta, "mode", ""));
    if (strings.trim($opts.theme) != "") {
        return theme.theme($opts.theme, "light");
    }
    return theme.theme($deck.theme, "light");
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
 * @return {doctree.Fill} the matching fill
 * @throws {Error} kind "theme" when the string is not a hex colour
 */
export func fill(hex as string) {
    def c as theme.Rgb init theme.hexRgb($hex);
    return doctree.rgb($c.red, $c.green, $c.blue);
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
    def seen as map of string to bool init {};
    for (def slide in $deck.slides) {
        def doc as doctree.Node init markdown.parse($slide.body);
        for (def url in collectImages($doc)) {
            if (not maps.has($seen, $url)) {
                $seen[$url] = true;
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
 * rather than asking for a fixed path. It reads the node's fields rather than
 * calling `doctree.typeOf` and `doctree.children`: each call into `doctree`
 * rebuilds the node it is handed, which made the walk the costliest part of
 * the PDF's image scan.
 * @param node {doctree.Node} the subtree to walk
 * @return {list of string} the `src` of every image below `node`, in order
 */
export func collectImages(node as doctree.Node) {
    def found as list of string init [];
    if ($node.kind == "image") {
        def src as string init $node.url;
        if ($src == "" and maps.has($node.attrs, "src")) {
            $src = $node.attrs["src"];
        }
        if ($src != "") {
            $found[] = $src;
        }
    }
    for (def child in $node.children) {
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
 * @return {doctree.PdfOptions} options ready for `doctree.renderPdfDoc`
 * @throws {Error} kind "theme" when the theme or ratio name is unknown
 */
export func layout(deck as slides.Deck, opts as Options) {
    def t as theme.Theme init pickTheme($deck, $opts);
    def s as theme.Stage init pickStage($deck, $opts);
    def out as doctree.PdfOptions init doctree.pdfDefaults();
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

/** Handout page width: A4 portrait, in points. */
export def const HANDOUT_WIDTH as int init 595;

/** Handout page height: A4 portrait, in points. */
export def const HANDOUT_HEIGHT as int init 842;

/** Slides per handout page, stacked top to bottom. */
export def const HANDOUT_PER_PAGE as int init 3;

/** Handout margin on every side, in points; the footer sits inside it. */
export def const HANDOUT_MARGIN as int init 36;

/** Space between two slides, and above the footer, in points. */
export def const HANDOUT_GAP as int init 18;

/** The narrowest column of note lines worth drawing beside a slide, in points. */
export def const HANDOUT_NOTES_MIN as int init 80;

/** Distance between two note lines, in points. */
export def const HANDOUT_LINE_STEP as int init 20;

/** Room at the top of a handout page for the deck's title, in points. */
export def const HANDOUT_TITLE_SPACE as int init 22;

/** The handout title's font size, in points. */
export def const HANDOUT_TITLE_SIZE as int init 11;

/** The font size of speaker notes printed beside a handout slide, in points. */
export def const HANDOUT_NOTE_SIZE as int init 8;

/** The distance between two lines of printed notes, in points. */
export def const HANDOUT_NOTE_LEADING as int init 10;

/**
 * A handout: the slide pages, three to an A4 portrait page.
 *
 * Each slide keeps its own content stream, wrapped in one scaling transform
 * and clipped to the slide, so text stays text and pictures stay sharp. A thin
 * frame marks each slide, its number sits under its right edge, and where the slide leaves
 * room on the right, ruled lines give space for notes. The deck's title heads
 * every page, above its first slide. Links and bookmarks move with their slides.
 * @param doc {pdf.Document} the slide document from `document`
 * @param s {theme.Stage} the stage the slides were printed at
 * @param title {string} the title over each page's first slide, "" for none
 * @param label {pdf.PageLabel} the handout's running footer
 * @return {pdf.Document} the handout document
 */
export func handout(
    doc as pdf.Document,
    s as theme.Stage,
    title as string,
    label as pdf.PageLabel) {
    return handoutWith($doc, $s, $title, $label, []);
}

/**
 * A handout with each slide's speaker notes printed beside it.
 *
 * The notes take the top of the column the ruled lines are drawn in, wrapped to
 * its width in a small sans-serif, and the lines fill the room left below them,
 * for the reader's own notes. Notes longer than the slide is tall are cut, the
 * last line ending in "...". Where a ratio leaves no column, nothing is printed
 * beside the slides, as with `handout`.
 * @param doc {pdf.Document} the slide document from `document`, one page per
 *     slide; render it without notes, since they are printed beside it
 * @param s {theme.Stage} the stage the slides were printed at
 * @param title {string} the title over each page's first slide, "" for none
 * @param label {pdf.PageLabel} the handout's running footer
 * @param notes {list of string} each slide's notes, by slide; "" or a missing
 *     entry leaves that slide's column ruled only
 * @return {pdf.Document} the handout document
 */
export func handoutWith(
    doc as pdf.Document,
    s as theme.Stage,
    title as string,
    label as pdf.PageLabel,
    notes as list of string) {
    def top as int init HANDOUT_HEIGHT - HANDOUT_MARGIN;
    def heading as string init fitTitle(pdf.toWinAnsi(strings.trim($title), "?"));
    if ($heading != "") {
        $top = $top - HANDOUT_TITLE_SPACE;
    }
    def usableW as int init HANDOUT_WIDTH - 2 * HANDOUT_MARGIN;
    def scale as float init slotHeight($top) / convert.toFloat($s.pageHeight);
    if (convert.toFloat($s.pageWidth) * $scale > convert.toFloat($usableW)) {
        $scale = convert.toFloat($usableW) / convert.toFloat($s.pageWidth);
    }
    def w as float init convert.toFloat($s.pageWidth) * $scale;
    def h as float init convert.toFloat($s.pageHeight) * $scale;
    def x as float init convert.toFloat(HANDOUT_MARGIN);
    def notesX as float init $x + $w + convert.toFloat(HANDOUT_GAP);
    def withNotes as bool init convert.toFloat(HANDOUT_WIDTH - HANDOUT_MARGIN) -
        $notesX >=
        convert.toFloat(HANDOUT_NOTES_MIN);
    def pages as list of pdf.Page init [];
    def total as int init len($doc.pages);
    def sheets as int init ($total + HANDOUT_PER_PAGE - 1) // HANDOUT_PER_PAGE;
    for (def n in 0..$sheets) {
        def sheet as pdf.Page init pdf.page(HANDOUT_WIDTH, HANDOUT_HEIGHT);
        def body as string init "";
        def fonts as list of string init [];
        def glyphs as list of pdf.GlyphUse init [];
        def links as list of pdf.LinkAnnot init [];
        def written as list of NoteLine init [];
        def count as int init 0;
        for (def k in 0..HANDOUT_PER_PAGE) {
            def i as int init $n * HANDOUT_PER_PAGE + $k;
            if ($i >= $total) {
                break;
            }
            $count = $count + 1;
            def pg as pdf.Page init $doc.pages[$i];
            def y as float init slotY($k, $h, $top);
            $body = $body + "q\n" + num($scale) + " 0 0 " + num($scale) + " " + num($x) + " " +
                num($y) + " cm\n0 0 " + convert.toString($s.pageWidth) + " " +
                convert.toString($s.pageHeight) + " re W n\n" + $pg.content + "\nQ\n";
            $body = $body + "q 0.5 w 0.6 0.6 0.6 RG " + num($x) + " " + num($y) + " " + num($w) +
                " " + num($h) + " re S Q\n";
            if ($withNotes) {
                def col as Column init noteColumn(noteAt($notes, $i), $notesX, $y, $h);
                $body = $body + $col.ops;
                $written = lists.concat($written, $col.lines);
            }
            for (def f in $pg.fonts) {
                if (not lists.contains($fonts, $f)) {
                    $fonts[] = $f;
                }
            }
            for (def g in $pg.glyphUses) {
                $glyphs[] = $g;
            }
            for (def a in $pg.annots) {
                $links[] = pdf.LinkAnnot{
                    x: place($x, $a.x, $scale),
                    y: place($y, $a.y, $scale),
                    width: place(0.0, $a.width, $scale),
                    height: place(0.0, $a.height, $scale),
                    uri: $a.uri
                };
            }
        }
        $sheet.content = $body;
        $sheet.fonts = $fonts;
        $sheet.glyphUses = $glyphs;
        $sheet.annots = $links;
        if ($heading != "") {
            $sheet = pdf.color($sheet, 40, 40, 40);
            $sheet = pdf.text(
                $sheet,
                HANDOUT_MARGIN,
                HANDOUT_HEIGHT - HANDOUT_MARGIN - HANDOUT_TITLE_SIZE,
                "Helvetica-Bold",
                HANDOUT_TITLE_SIZE,
                $heading);
        }
        if (len($written) > 0) {
            $sheet = pdf.color($sheet, 50, 50, 50);
            for (def line in $written) {
                $sheet = pdf.text(
                    $sheet,
                    $line.x,
                    $line.y,
                    "Helvetica",
                    HANDOUT_NOTE_SIZE,
                    $line.text);
            }
        }
        $sheet = pdf.color($sheet, 110, 110, 110);
        # Each slide's number sits under its right edge, clear of the footer
        # text that starts at the left margin under the last slide.
        for (def k in 0..$count) {
            def y as float init slotY($k, $h, $top);
            def shown as string init convert.toString($n * HANDOUT_PER_PAGE + $k + 1);
            $sheet = pdf.text(
                $sheet,
                convert.toInt(math.round($x + $w - pdf.measureText("Helvetica", 7, $shown))),
                convert.toInt($y) - 10,
                "Helvetica",
                7,
                $shown);
        }
        $pages[] = $sheet;
    }
    def marks as list of pdf.OutlineEntry init [];
    for (def m in $doc.outline) {
        def moved as pdf.OutlineEntry init $m;
        $moved.page = $m.page // HANDOUT_PER_PAGE;
        $moved.y = place(slotY($m.page % HANDOUT_PER_PAGE, $h, $top), $m.y, $scale);
        $marks[] = $moved;
    }
    def out as pdf.Document init $doc;
    $out.pages = $pages;
    $out.outline = $marks;
    $out.headerOn = false;
    $out.footerOn = false;
    if ($label.left != "" or $label.right != "") {
        $out = pdf.setFooter($out, $label);
    }
    return $out;
}

# One line of notes on a handout sheet, placed in points.
def struct NoteLine {
    x as int,
    y as int,
    text as string
};

# What one slide's column holds: the ruled-line drawing operators, and the
# lines of notes to print over them.
def struct Column {
    ops as string,
    lines as list of NoteLine
};

# noteAt is slide i's notes, or "" past the end of the list.
func noteAt(notes as list of string, i as int) {
    if ($i < len($notes)) {
        return $notes[$i];
    }
    return "";
}

# noteColumn lays one slide's notes out at the top of its column, from notesX
# to the right margin beside a slide whose bottom edge is at y and which is h
# points high, and rules the room left below them.
func noteColumn(note as string, notesX as float, y as float, h as float) {
    def text as list of string init noteLayout(
        $note,
        convert.toFloat(HANDOUT_WIDTH - HANDOUT_MARGIN) - $notesX,
        $h);
    def lines as list of NoteLine init [];
    for (def j in 0..len($text)) {
        $lines[] = NoteLine{
            x: convert.toInt(math.round($notesX)),
            y: convert.toInt(math.round($y + $h)) - HANDOUT_NOTE_SIZE - $j * HANDOUT_NOTE_LEADING,
            text: $text[$j]
        };
    }
    def used as float init 0.0;
    if (len($text) > 0) {
        $used = convert.toFloat(len($text) * HANDOUT_NOTE_LEADING) +
            convert.toFloat(HANDOUT_NOTE_LEADING) / 2.0;
    }
    return Column{ops: noteLines($notesX, $y, $h - $used), lines: $lines};
}

/**
 * Speaker notes as the lines a handout prints beside a slide.
 *
 * The notes are plain text here: a blank line starts a paragraph, other line
 * breaks are spaces, and a paragraph is wrapped to `width` at
 * `HANDOUT_NOTE_SIZE`. A word wider than the column is broken where it has to
 * be. Lines that do not fit `height` are dropped, the last one kept ending in
 * "...". Text outside WinAnsi prints as "?", as everywhere in the PDF.
 * @param notes {string} the slide's notes
 * @param width {float} the column width, in points
 * @param height {float} the room down the column, in points
 * @return {list of string} the lines, top to bottom
 */
export func noteLayout(notes as string, width as float, height as float) {
    def out as list of string init [];
    def room as int init convert.toInt(math.floor($height / convert.toFloat(HANDOUT_NOTE_LEADING)));
    if ($room <= 0 or strings.trim($notes) == "") {
        return $out;
    }
    def all as list of string init [];
    for (def para in paragraphs(pdf.toWinAnsi($notes, "?"))) {
        if (len($all) > 0) {
            $all[] = "";
        }
        for (def line in wrapped($para, $width)) {
            $all[] = $line;
        }
    }
    if (len($all) <= $room) {
        return $all;
    }
    $out = $all[..$room];
    def last as string init $out[$room - 1];
    while ($last != "" and fits($last + "...", $width) == false) {
        $last = $last[..len($last) - 1];
    }
    $out[$room - 1] = strings.trim($last) + "...";
    return $out;
}

# paragraphs splits notes at blank lines and joins each paragraph's lines.
func paragraphs(text as string) {
    def out as list of string init [];
    def current as list of string init [];
    for (def line in strings.split($text, "\n")) {
        def bare as string init strings.trim($line);
        if ($bare == "") {
            if (len($current) > 0) {
                $out[] = strings.join($current, " ");
                $current = [];
            }
            continue;
        }
        $current[] = $bare;
    }
    if (len($current) > 0) {
        $out[] = strings.join($current, " ");
    }
    return $out;
}

# fits says whether text is no wider than width at the notes' size.
func fits(text as string, width as float) {
    return convert.toFloat(pdf.measureText("Helvetica", HANDOUT_NOTE_SIZE, $text)) <= $width;
}

# wrapped breaks one paragraph into lines no wider than width.
func wrapped(para as string, width as float) {
    def out as list of string init [];
    def line as string init "";
    for (def word in strings.split($para, " ")) {
        if ($word == "") {
            continue;
        }
        def tried as string init $word;
        if ($line != "") {
            $tried = $line + " " + $word;
        }
        if (fits($tried, $width)) {
            $line = $tried;
            continue;
        }
        if ($line != "") {
            $out[] = $line;
        }
        $line = $word;
        while (not fits($line, $width) and len($line) > 1) {
            def cut as int init len($line) - 1;
            while ($cut > 1 and not fits($line[..$cut], $width)) {
                $cut = $cut - 1;
            }
            $out[] = $line[..$cut];
            $line = $line[$cut..];
        }
    }
    if ($line != "") {
        $out[] = $line;
    }
    return $out;
}

# slotHeight is the height one slide may take on a handout page whose slides
# start at `top`.
func slotHeight(top as int) {
    def free as int init $top - HANDOUT_MARGIN - HANDOUT_GAP -
        (HANDOUT_PER_PAGE - 1) * HANDOUT_GAP;
    return convert.toFloat($free) / convert.toFloat(HANDOUT_PER_PAGE);
}

# slotY is the bottom edge of the k-th slide on a handout page whose slides are
# h points high and start at `top`.
func slotY(k as int, h as float, top as int) {
    def step as float init slotHeight($top) + convert.toFloat(HANDOUT_GAP);
    return convert.toFloat($top) - convert.toFloat($k) * $step - $h;
}

# place maps a slide coordinate onto the handout: origin plus the scaled value,
# rounded to whole points as link rectangles and bookmarks need.
func place(origin as float, v as int, scale as float) {
    return convert.toInt(math.round($origin + convert.toFloat($v) * $scale));
}

# noteLines draws light ruled lines from notesX to the right margin, over the
# height of a slide whose bottom edge is at y.
func noteLines(notesX as float, y as float, h as float) {
    def right as string init num(convert.toFloat(HANDOUT_WIDTH - HANDOUT_MARGIN));
    def out as string init "q 0.5 w 0.82 0.82 0.82 RG\n";
    def at as float init $y + $h - convert.toFloat(HANDOUT_LINE_STEP);
    while ($at >= $y) {
        $out = $out + num($notesX) + " " + num($at) + " m " + $right + " " + num($at) + " l S\n";
        $at = $at - convert.toFloat(HANDOUT_LINE_STEP);
    }
    return $out + "Q\n";
}

# fitTitle shortens a title that would not fit the page width, ending it in
# "...".
func fitTitle(title as string) {
    def room as int init HANDOUT_WIDTH - 2 * HANDOUT_MARGIN;
    if ($title == "" or pdf.measureText("Helvetica-Bold", HANDOUT_TITLE_SIZE, $title) <= $room) {
        return $title;
    }
    def cut as string init $title;
    while (len($cut) > 1 and
        pdf.measureText("Helvetica-Bold", HANDOUT_TITLE_SIZE, $cut + "...") > $room) {
        $cut = strings.trim($cut[..len($cut) - 1]);
    }
    return $cut + "...";
}

# num writes a non-negative coordinate with at most three decimals, the way a
# content stream takes it.
func num(v as float) {
    def milli as int init convert.toInt(math.round($v * 1000.0));
    def whole as int init $milli // 1000;
    def frac as int init $milli % 1000;
    if ($frac == 0) {
        return convert.toString($whole);
    }
    def digits as string init convert.toString($frac);
    while (len($digits) < 3) {
        $digits = "0" + $digits;
    }
    while (strings.endsWith($digits, "0")) {
        $digits = $digits[..len($digits) - 1];
    }
    return convert.toString($whole) + "." + $digits;
}

/**
 * The handout's title: the deck's own, printed above each page's first slide.
 * @param deck {slides.Deck} the deck being rendered
 * @return {string} the title, "" when the deck has none
 */
export func handoutTitle(deck as slides.Deck) {
    return strings.trim($deck.title);
}

/**
 * The handout's footer: the caller's `--footer` text on the left (the title
 * already heads the page), and page numbers on the right, always, since a
 * printed handout needs them to be put back in order.
 * @param deck {slides.Deck} the deck being rendered
 * @param opts {Options} the caller's options
 * @return {pdf.PageLabel} the footer for every handout page
 */
export func handoutFooter(deck as slides.Deck, opts as Options) {
    def out as pdf.PageLabel init footer($deck, $opts);
    $out.left = pdf.toWinAnsi(strings.trim($opts.footer), "?");
    $out.right = "%page% / %pages%";
    $out.size = 8;
    $out.red = 110;
    $out.green = 110;
    $out.blue = 110;
    return $out;
}

/**
 * The running footer: the deck's own label on the left, pages on the right.
 *
 * The label is drawn in a standard font, which encodes only WinAnsi, so a
 * character outside it becomes `?` the way body text does; left as written it
 * would fail the whole PDF.
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
    $out.left = pdf.toWinAnsi($left, "?");
    if ($opts.numbers) {
        $out.right = "%page% / %pages%";
    }
    return $out;
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
 * One line of a code block as the PDF draws it, with a colour per character.
 * @field chars {list of string} the line's characters, as the layout draws them
 *     (a character the fonts cannot encode already replaced)
 * @field colours {list of string} per character, the content-stream operator
 *     that sets its colour (`r g b rg`)
 * @field italic {list of bool} per character, whether it is set oblique (a comment)
 */
export def struct PaintLine {
    chars as list of string,
    colours as list of string,
    italic as list of bool
};

/**
 * One code block's colouring, in the order the layout draws the blocks.
 * @field coloured {bool} false for a block in no known language, left as laid out
 * @field lines {list of PaintLine} the block's lines
 */
export def struct Painted {
    coloured as bool,
    lines as list of PaintLine
};

/**
 * Every code block's colouring, in document order. A struct, so passing it
 * borrows the nested lists rather than copying them.
 * @field blocks {list of Painted} one entry per code block
 */
export def struct Plan {
    blocks as list of Painted
};

/**
 * Work out how every code block in a tree is to be coloured.
 *
 * The tree is walked in the order the layout draws it, so the n-th entry is
 * the n-th code panel on the pages. A block in a language `highlight` does
 * not know still has an entry, uncoloured, so the count stays in step.
 * @param tree {doctree.Node} the parsed deck
 * @param colours {theme.Syntax} the token colours to draw with
 * @param unencodable {string} what the layout draws for a character the fonts
 *     cannot encode
 * @return {list of Painted} one entry per code block
 */
export func paintPlan(tree as doctree.Node, colours as theme.Syntax, unencodable as string) {
    def out as list of Painted init [];
    for (def block in codeNodes($tree)) {
        def p as Painted init Painted{coloured: false, lines: []};
        if (highlight.handles($block.lang)) {
            $p.coloured = true;
            $p.lines = paintLines($block.text, $block.lang, $colours, $unencodable);
        }
        $out[] = $p;
    }
    return $out;
}

/**
 * Every code block below a node, in document order.
 * @param node {doctree.Node} the subtree to walk
 * @return {list of doctree.Node} the `code` nodes
 */
export func codeNodes(node as doctree.Node) {
    def out as list of doctree.Node init [];
    if ($node.kind == "code") {
        $out[] = $node;
    }
    for (def child in $node.children) {
        for (def found in codeNodes($child)) {
            $out[] = $found;
        }
    }
    return $out;
}

/**
 * Colour one code block's lines, split where the layout splits them.
 * @param text {string} the block's source
 * @param lang {string} its fence's language tag
 * @param colours {theme.Syntax} the token colours to draw with
 * @param unencodable {string} the layout's stand-in for an unencodable character
 * @return {list of PaintLine} one entry per source line
 */
export func paintLines(
    text as string,
    lang as string,
    colours as theme.Syntax,
    unencodable as string) {
    def ops as map of string to string init {};
    def lines as list of PaintLine init [PaintLine{chars: [], colours: [], italic: []}];
    for (def t in highlight.tokens($text, $lang)) {
        if (not maps.has($ops, $t.cls)) {
            $ops[$t.cls] = colourOp(theme.tokenColour($colours, $t.cls));
        }
        def op as string init $ops[$t.cls];
        def slanted as bool init $t.cls == "comment";
        for (def ch in strings.chars($t.text)) {
            if ($ch == "\n") {
                $lines[] = PaintLine{chars: [], colours: [], italic: []};
                continue;
            }
            def last as int init len($lines) - 1;
            # The layout replaces what the fonts cannot draw, so the colours
            # follow the characters it really draws.
            for (def drawn in strings.chars(pdf.toWinAnsi($ch, $unencodable))) {
                $lines[$last].chars[] = $drawn;
                $lines[$last].colours[] = $op;
                $lines[$last].italic[] = $slanted;
            }
        }
    }
    return $lines;
}

/**
 * The content-stream operator that sets a fill colour, as `pdf` writes it.
 * @param hex {string} the colour, "" for the text colour (black)
 * @return {string} the `r g b rg` line, without its newline
 */
export func colourOp(hex as string) {
    def c as theme.Rgb init theme.Rgb{red: 0, green: 0, blue: 0};
    if ($hex != "") {
        $c = theme.hexRgb($hex);
    }
    return colourLines($c)[0];
}

/**
 * The two content-stream lines `pdf.color` writes for a colour: fill, then stroke.
 * @param c {theme.Rgb} the colour
 * @return {list of string} the `rg` line and the `RG` line
 */
func colourLines(c as theme.Rgb) {
    def pg as pdf.Page init pdf.color(pdf.page(1, 1), $c.red, $c.green, $c.blue);
    return strings.split(strings.trimRight($pg.content), "\n");
}

/**
 * One character as it appears inside a PDF string literal, the way `pdf`
 * escapes text for a standard font: WinAnsi bytes, with `\`, `(`, `)` and
 * every byte outside printable ASCII escaped.
 * @param ch {string} one character the standard fonts can encode
 * @return {string} its escaped form
 */
export func pdfChar(ch as string) {
    def parts as list of string init [];
    for (def b in encoding.encode("windows-1252", $ch)) {
        if ($b == 92) {
            $parts[] = "\\\\";
        } elseif ($b == 40) {
            $parts[] = "\\(";
        } elseif ($b == 41) {
            $parts[] = "\\)";
        } elseif ($b == 13) {
            $parts[] = "\\r";
        } elseif ($b == 10) {
            $parts[] = "\\n";
        } elseif ($b < 32 or $b >= 127) {
            $parts[] = "\\" + convert.toString(($b >> 6) & 7) + convert.toString(($b >> 3) & 7) +
                convert.toString($b & 7);
        } else {
            $parts[] = convert.fromCodepoint($b);
        }
    }
    return strings.join($parts, "");
}

/**
 * What `paintCode` writes with, worked out once per document.
 * @field mark {list of string} the two colour lines of a `CODE_MARK` panel
 * @field shade {list of string} the two colour lines of the real panel shade
 * @field black {string} the operator that sets the text colour back to black
 * @field fontLine {string} the mono font at body size, as the layout selects it
 * @field slantLine {string} the oblique mono font at body size, "" when the mono
 *     font has no oblique face
 */
export def struct Ink {
    mark as list of string,
    shade as list of string,
    black as string,
    fontLine as string,
    slantLine as string
};

/**
 * Where `paintCode` is in the plan, carried from page to page.
 * @field next {int} the index of the next code panel to be met
 * @field active {bool} whether the runs being read belong to a coloured block
 * @field block {int} the block being read
 * @field line {int} the line of that block the next run continues
 * @field at {int} the character of that line the next run starts at
 * @field slanted {bool} whether the page being painted uses the oblique face
 */
export def struct Cursor {
    next as int,
    active as bool,
    block as int,
    line as int,
    at as int,
    slanted as bool
};

/**
 * The colours and fonts `paintCode` writes with.
 * @param lay {doctree.PdfOptions} the layout options, for the mono font and size
 * @param real {doctree.Fill} the shade the panels really have
 * @return {Ink} the operators, ready to write
 */
export func ink(lay as doctree.PdfOptions, real as doctree.Fill) {
    def size as string init convert.toString($lay.bodySize);
    def out as Ink init Ink{
        mark: colourLines(theme.hexRgb(CODE_MARK)),
        shade: colourLines(theme.Rgb{red: $real.r, green: $real.g, blue: $real.b}),
        black: colourOp(""),
        fontLine: "/" + $lay.monoFont + " " + $size + " Tf",
        slantLine: ""
    };
    if (not $real.on) {
        $out.shade = colourLines(theme.Rgb{red: 0, green: 0, blue: 0});
    }
    if ($lay.monoFont == "Courier") {
        $out.slantLine = "/Courier-Oblique " + $size + " Tf";
    }
    return $out;
}

/**
 * How far one drawn run reaches into the line it continues.
 * @param pl {PaintLine} the line the run belongs to
 * @param at {int} the character the run starts at
 * @param payload {string} the run's text as the content stream holds it, escaped
 * @return {int} the index just past the run's last character, -1 when the run
 *     is not the next piece of the line
 */
export func runEnd(pl as PaintLine, at as int, payload as string) {
    def acc as string init "";
    def k as int init $at;
    while ($k < len($pl.chars) and len($acc) < len($payload)) {
        $acc = $acc + pdfChar($pl.chars[$k]);
        $k = $k + 1;
    }
    if ($acc != $payload or ($payload == "" and $at < len($pl.chars))) {
        return -1;
    }
    return $k;
}

/**
 * The operators that draw characters `first` to `stop` of a line, one `Tj` per
 * run of one colour and slant, after the run's `BT`, font and position lines.
 * @param pl {PaintLine} the line
 * @param first {int} the first character
 * @param stop {int} the index just past the last
 * @param pen {Ink} the operators to write with
 * @return {list of string} the lines that replace the run's `Tj` line
 */
export func drawRun(pl as PaintLine, first as int, stop as int, pen as Ink) {
    def out as list of string init [];
    def current as string init "";
    def oblique as bool init false;
    def r as int init $first;
    while ($r < $stop) {
        def op as string init $pl.colours[$r];
        def it as bool init $pl.italic[$r] and $pen.slantLine != "";
        def e as int init $r;
        def text as list of string init [];
        while ($e < $stop and $pl.colours[$e] == $op and
            ($pl.italic[$e] and $pen.slantLine != "") == $it) {
            $text[] = pdfChar($pl.chars[$e]);
            $e = $e + 1;
        }
        if ($op != $current) {
            $out[] = $op;
            $current = $op;
        }
        if ($it != $oblique) {
            $out[] = slantOrNot($pen, $it);
            $oblique = $it;
        }
        $out[] = "(" + strings.join($text, "") + ") Tj";
        $r = $e;
    }
    if ($stop == $first) {
        $out[] = "() Tj";
    }
    if ($current != "" and $current != $pen.black) {
        $out[] = $pen.black;
    }
    return $out;
}

/**
 * The font line for an oblique or an upright run.
 * @param pen {Ink} the operators to write with
 * @param oblique {bool} whether the run is a comment
 * @return {string} the `Tf` line
 */
func slantOrNot(pen as Ink, oblique as bool) {
    if ($oblique) {
        return $pen.slantLine;
    }
    return $pen.fontLine;
}

/**
 * Whether the content lines from `i` are one text run in the mono font at
 * body size: `BT`, the font, the position, one `(...) Tj`, `ET`.
 * @param src {list of string} a page's content lines
 * @param i {int} where the run would start
 * @param pen {Ink} for the font line to match
 * @return {bool} true for such a run
 */
func isMonoRun(src as list of string, i as int, pen as Ink) {
    if ($i + 4 >= len($src) or $src[$i] != "BT" or $src[$i + 4] != "ET") {
        return false;
    }
    return $src[$i + 1] == $pen.fontLine and strings.startsWith($src[$i + 3], "(") and
        strings.endsWith($src[$i + 3], ") Tj");
}

/**
 * Start the next block at a code panel.
 * @param c {Cursor} where painting is
 * @param plan {Plan} the colouring of every block
 * @return {Cursor} the cursor at the start of the panel's block
 */
func enterPanel(c as Cursor, plan as Plan) {
    def out as Cursor init $c;
    $out.active = false;
    if ($c.next < len($plan.blocks)) {
        $out.block = $c.next;
        $out.active = $plan.blocks[$c.next].coloured and len($plan.blocks[$c.next].lines) > 0;
        $out.line = 0;
        $out.at = 0;
    }
    $out.next = $c.next + 1;
    return $out;
}

/**
 * The result of painting one page.
 * @field lines {list of string} the page's new content lines
 * @field cursor {Cursor} where painting goes on from on the next page
 */
export def struct PagePaint {
    lines as list of string,
    cursor as Cursor
};

/**
 * Paint the code on one page's content lines.
 * @param src {list of string} the page's content, split into lines
 * @param plan {Plan} the colouring of every block
 * @param pen {Ink} the operators to write with
 * @param start {Cursor} where painting stands as the page begins
 * @return {PagePaint} the new lines and where painting stands after them
 */
export func paintPage(src as list of string, plan as Plan, pen as Ink, start as Cursor) {
    def c as Cursor init $start;
    def out as list of string init [];
    def i as int init 0;
    while ($i < len($src)) {
        if ($i + 1 < len($src) and $src[$i] == $pen.mark[0] and $src[$i + 1] == $pen.mark[1]) {
            $out[] = $pen.shade[0];
            $out[] = $pen.shade[1];
            $c = enterPanel($c, $plan);
            $i = $i + 2;
            continue;
        }
        if (not $c.active or not isMonoRun($src, $i, $pen)) {
            $out[] = $src[$i];
            $i = $i + 1;
            continue;
        }
        def pl as PaintLine init $plan.blocks[$c.block].lines[$c.line];
        def tj as string init $src[$i + 3];
        def k as int init runEnd($pl, $c.at, $tj[1..len($tj) - 4]);
        if ($k < 0) {
            # Not the text expected: leave the rest of this block as laid out.
            $c.active = false;
            continue;
        }
        $out[] = "BT";
        $out[] = $pen.fontLine;
        $out[] = $src[$i + 2];
        for (def op in drawRun($pl, $c.at, $k, $pen)) {
            $out[] = $op;
            $c.slanted = $c.slanted or $op == $pen.slantLine;
        }
        $out[] = "ET";
        $c.at = $k;
        if ($k >= len($pl.chars)) {
            $c.line = $c.line + 1;
            $c.at = 0;
            $c.active = $c.line < len($plan.blocks[$c.block].lines);
        }
        $i = $i + 5;
    }
    return PagePaint{lines: $out, cursor: $c};
}

/**
 * Colour the code panels of a laid-out document.
 *
 * `doctree` draws a code block in one colour and offers no hook to change
 * that, so this works on what it produced. While highlighting, every code
 * panel is laid out with the fill `CODE_MARK`, which no theme uses; each
 * panel's two colour lines are turned back into the real shade here, and the
 * text lines that follow it, each a `BT ... (text) Tj ET` run in the mono font
 * at body size, are split into one `Tj` per colour run inside the same text
 * object (comments in the oblique face). A `Tj` advances the pen by the glyphs
 * it drew, and the oblique face has the same widths, so the runs land exactly
 * where the one run stood: nothing moves, no page is added, and the overflow
 * count is unchanged.
 *
 * A wrapped line arrives as several runs; each must be the next piece of the
 * expected line, so a run that does not match leaves the rest of that block
 * as laid out rather than colouring the wrong text. The output depends only
 * on the input, so a rebuild is byte-identical.
 * @param doc {pdf.Document} the document `doctree` laid out with `CODE_MARK`
 * @param plan {Plan} the colouring of every code block, in document order
 * @param lay {doctree.PdfOptions} the layout options, for the mono font and size
 * @param real {doctree.Fill} the shade the panels really have
 * @return {pdf.Document} the same document with its panels shaded and coloured
 */
export func paintCode(
    doc as pdf.Document,
    plan as Plan,
    lay as doctree.PdfOptions,
    real as doctree.Fill) {
    def pen as Ink init ink($lay, $real);
    def c as Cursor init Cursor{next: 0, active: false, block: 0, line: 0, at: 0, slanted: false};
    def pages as list of pdf.Page init [];
    for (def pg in $doc.pages) {
        $c.slanted = false;
        def painted as PagePaint init paintPage(strings.split($pg.content, "\n"), $plan, $pen, $c);
        $c = $painted.cursor;
        def out as pdf.Page init $pg;
        $out.content = strings.join($painted.lines, "\n");
        if ($c.slanted and not lists.contains($out.fonts, "Courier-Oblique")) {
            $out.fonts[] = "Courier-Oblique";
        }
        $pages[] = $out;
    }
    def result as pdf.Document init $doc;
    $result.pages = $pages;
    return $result;
}

/**
 * A parsed deck with its maths made printable.
 *
 * The layout draws text, not MathML, and drops raw HTML without a word, so each
 * MathML element becomes the TeX source it carries, in monospace: a code span
 * inline, and centred lines for display maths. A deck without maths is handed
 * back untouched.
 * @param tree {doctree.Node} the parsed deck
 * @param lay {doctree.PdfOptions} the layout, for the column and the mono font
 * @return {doctree.Node} the tree to lay out
 */
export func printableMaths(tree as doctree.Node, lay as doctree.PdfOptions) {
    if (not mathml.holds($tree)) {
        return $tree;
    }
    def column as float init convert.toFloat($lay.pageWidth - 2 * $lay.margin);
    def glyph as float init pdf.measureText($lay.monoFont, $lay.bodySize, "0");
    def chars as int init math.floor($column / $glyph);
    return mathml.rewrite($tree, "tex", $chars).node;
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
 * @throws {Error} kind "highlight" when the deck's `highlight:` is not true or false
 * @throws {Error} kind "limit" when a document exceeds the parser's budget
 */
export func document(deck as slides.Deck, opts as Options) {
    def source as string init slides.kbdToCode(slides.toMarkdown($deck, $opts.notes));
    def lay as doctree.PdfOptions init layout($deck, $opts);
    def tree as doctree.Node init printableMaths(markdown.parse($source), $lay);
    def laid as pdf.Document;
    if (pickHighlight($deck, $opts)) {
        def real as doctree.Fill init $lay.codeFill;
        $lay.codeFill = fill(CODE_MARK);
        $laid = doctree.renderPdfDoc($tree, $lay);
        def blocks as list of Painted init paintPlan(
            $tree,
            theme.printSyntax(pickTheme($deck, $opts)),
            $lay.unencodable);
        $laid = paintCode($laid, Plan{blocks: $blocks}, $lay, $real);
    } else {
        $laid = doctree.renderPdfDoc($tree, $lay);
    }
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
 * @throws {Error} kind "limit" when a document exceeds the parser's budget
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
