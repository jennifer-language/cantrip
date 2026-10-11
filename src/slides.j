# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * The slide-deck model: Markdown source in, an ordered deck of slides out.
 *
 * This module owns the input format and nothing else. It does no I/O and
 * renders nothing, so both renderers and the test suite work on plain values.
 * @module slides
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use strings;
use lists;
use maps;
use convert;

import "markdown.j" as markdown;

/** The fence that opens and closes a front-matter block. */
export def const FENCE as string init "---";

/** Opening delimiter of a speaker-note comment. */
export def const NOTE_OPEN as string init "<!-- notes:";

/** Closing delimiter of a speaker-note comment. */
export def const NOTE_CLOSE as string init "-->";

/** Opening tag of a key cap, the one inline HTML element a deck may use. */
export def const KBD_OPEN as string init "<kbd>";

/** Closing tag of a key cap. */
export def const KBD_CLOSE as string init "</kbd>";

/** The page-break comment the PDF renderer understands. */
export def const PAGE_BREAK as string init "<!-- pagebreak -->";

/**
 * One slide: its Markdown body, plus what was lifted out of it.
 * @field number {int} 1-based position in the deck
 * @field title {string} text of the slide's first heading, else ""
 * @field level {int} level of that heading (1-6), else 0
 * @field body {string} the slide's Markdown, notes removed
 * @field notes {string} speaker notes, joined by blank lines
 */
export def struct Slide {
    number as int,
    title as string,
    level as int,
    body as string,
    notes as string
};

/**
 * A whole deck: its metadata and its slides.
 * @field title {string} deck title, from front matter or the first slide
 * @field author {string} author line, "" when unset
 * @field date {string} date line, "" when unset
 * @field theme {string} theme name, "" when the front matter did not pick one
 * @field ratio {string} aspect-ratio name, "" when unset
 * @field meta {map of string to string} every front-matter key, verbatim
 * @field slides {list of Slide} the slides, in source order
 */
export def struct Deck {
    title as string,
    author as string,
    date as string,
    theme as string,
    ratio as string,
    meta as map of string to string,
    slides as list of Slide
};

/**
 * Source split into its front matter and the body below it.
 * @field meta {map of string to string} the parsed keys, empty when absent
 * @field body {string} everything after the closing fence
 */
export def struct Split {
    meta as map of string to string,
    body as string
};

/**
 * Whether a line is a slide separator: three or more dashes, nothing else.
 *
 * Leading and trailing spaces are ignored, so an editor that trims or pads
 * the line does not change the deck.
 * @param line {string} one source line
 * @return {bool} true when the line separates two slides
 */
export func isSeparator(line as string) {
    def bare as string init strings.trim($line);
    if (len($bare) < 3) {
        return false;
    }
    for (def ch in strings.chars($bare)) {
        if ($ch != "-") {
            return false;
        }
    }
    return true;
}

/**
 * Lift a leading front-matter block off the source.
 *
 * A front-matter block exists only when the very first line is the fence, so
 * a deck whose first slide happens to open with a thematic break is not
 * mistaken for one. Keys are `name: value` lines; a line without a colon, and
 * any comment line, is skipped. An unterminated block is treated as no front
 * matter at all, leaving the source untouched.
 * @param source {string} the whole Markdown source
 * @return {Split} the keys found and the remaining body
 */
export func frontMatter(source as string) {
    def out as Split init Split{meta: {}, body: $source};
    def lines as list of string init strings.split($source, "\n");
    if (len($lines) == 0 or strings.trim($lines[0]) != FENCE) {
        return $out;
    }
    def closed as bool init false;
    def at as int init 0;
    for (def i as int init 1; $i < len($lines); $i = $i + 1) {
        if (strings.trim($lines[$i]) == FENCE) {
            $closed = true;
            $at = $i;
            break;
        }
        def key as string init metaKey($lines[$i]);
        if ($key != "") {
            $out.meta[$key] = metaValue($lines[$i]);
        }
    }
    if (not $closed) {
        return Split{meta: {}, body: $source};
    }
    def rest as list of string init [];
    for (def i as int init $at + 1; $i < len($lines); $i = $i + 1) {
        $rest[] = $lines[$i];
    }
    $out.body = strings.join($rest, "\n");
    return $out;
}

/**
 * The key of a `name: value` front-matter line.
 * @param line {string} one line from inside a front-matter block
 * @return {string} the lower-cased key, or "" when the line carries none
 */
export func metaKey(line as string) {
    def bare as string init strings.trim($line);
    if ($bare == "" or strings.startsWith($bare, "#")) {
        return "";
    }
    def at as int init strings.indexOf($bare, ":");
    if ($at < 1) {
        return "";
    }
    return strings.lower(strings.trim(strings.substring($bare, 0, $at)));
}

/**
 * The value of a `name: value` front-matter line.
 *
 * Surrounding quotes are dropped, so `title: "A Deck"` and `title: A Deck`
 * agree.
 * @param line {string} one line from inside a front-matter block
 * @return {string} the value, or "" when the line carries none
 */
export func metaValue(line as string) {
    def bare as string init strings.trim($line);
    def at as int init strings.indexOf($bare, ":");
    if ($at < 0) {
        return "";
    }
    return unquote(strings.trim(strings.substring($bare, $at + 1)));
}

/**
 * Strip one matching pair of surrounding quotes.
 * @param value {string} a front-matter value
 * @return {string} the value without its outer quotes
 */
export func unquote(value as string) {
    if (len($value) < 2) {
        return $value;
    }
    def head as string init strings.substring($value, 0, 1);
    def tail as string init strings.substring($value, len($value) - 1, len($value));
    if ($head == $tail and ($head == "\"" or $head == "'")) {
        return strings.substring($value, 1, len($value) - 1);
    }
    return $value;
}

/**
 * The code-fence marker a line opens or closes with, if any.
 *
 * Returns the run of fence characters so a caller can tell ```` ``` ```` from
 * ````` ```` `````: CommonMark closes a fence only with a run at least as
 * long as the one that opened it, which is how a fenced block can itself
 * contain a fence.
 * @param line {string} one source line
 * @return {string} the leading run of backticks or tildes, else ""
 */
export func fenceOf(line as string) {
    def bare as string init strings.trim($line);
    if (not strings.startsWith($bare, "```") and not strings.startsWith($bare, "~~~")) {
        return "";
    }
    def mark as string init strings.substring($bare, 0, 1);
    def run as string init "";
    for (def ch in strings.chars($bare)) {
        if ($ch != $mark) {
            break;
        }
        $run = $run + $ch;
    }
    return $run;
}

/**
 * Whether `marker` closes a fence opened by `fence`.
 * @param marker {string} the run of fence characters on the current line
 * @param fence {string} the run that opened the block
 * @return {bool} true when the same character runs at least as long
 */
export func closesFence(marker as string, fence as string) {
    if ($marker == "" or $fence == "") {
        return false;
    }
    if (strings.substring($marker, 0, 1) != strings.substring($fence, 0, 1)) {
        return false;
    }
    return len($marker) >= len($fence);
}

/**
 * Whether a line closes a fence opened by `fence`.
 *
 * Stricter than `closesFence`: a closing fence carries nothing after its run,
 * so a line such as ```` ```js ```` inside an open block is content, the way
 * CommonMark reads it, rather than the end of the block.
 * @param line {string} one source line
 * @param fence {string} the run that opened the block
 * @return {bool} true when the line ends the block
 */
export func closesFenceLine(line as string, fence as string) {
    def marker as string init fenceOf($line);
    return closesFence($marker, $fence) and strings.trim($line) == $marker;
}

/**
 * Split a body into one Markdown chunk per slide.
 *
 * Separator lines are dropped, and a chunk that holds no text is dropped too,
 * so a trailing separator or a run of them does not yield blank slides.
 *
 * A separator inside a fenced code block is content, not a separator - a
 * slide that shows front matter or a YAML snippet would otherwise be torn in
 * half by its own example.
 * @param body {string} the source below any front matter
 * @return {list of string} each slide's Markdown, in order
 */
export func chunks(body as string) {
    def out as list of string init [];
    def current as list of string init [];
    def fence as string init "";
    for (def line in strings.split($body, "\n")) {
        def marker as string init fenceOf($line);
        if ($fence != "") {
            if (closesFenceLine($line, $fence)) {
                $fence = "";
            }
            $current[] = $line;
            continue;
        }
        if ($marker != "") {
            $fence = $marker;
            $current[] = $line;
            continue;
        }
        if (not isSeparator($line)) {
            $current[] = $line;
            continue;
        }
        def joined as string init strings.trim(strings.join($current, "\n"));
        if ($joined != "") {
            $out[] = $joined;
        }
        $current = [];
    }
    def last as string init strings.trim(strings.join($current, "\n"));
    if ($last != "") {
        $out[] = $last;
    }
    return $out;
}

/**
 * Whether a position on a line falls inside an inline code span.
 *
 * Counts the backticks before the position: an odd count means a span is
 * open. That is a line-local view of CommonMark's rule, which is enough to
 * keep `` `<!-- notes: -->` `` in prose from being read as a real note.
 * @param line {string} one source line
 * @param at {int} a rune offset into the line
 * @return {bool} true when an inline code span is open at `at`
 */
export func insideCodeSpan(line as string, at as int) {
    def before as string init strings.substring($line, 0, $at);
    return (len(strings.split($before, "`")) - 1) % 2 == 1;
}

/**
 * Where the next speaker-note opener on a line starts, outside code spans.
 * @param line {string} one source line
 * @param from {int} the rune offset to search from
 * @return {int} the opener's offset, or -1 when the line holds no live opener
 */
export func noteStart(line as string, from as int) {
    def at as int init strings.indexOf($line, NOTE_OPEN, $from);
    while ($at >= 0) {
        if (not insideCodeSpan($line, $at)) {
            return $at;
        }
        $at = strings.indexOf($line, NOTE_OPEN, $at + 1);
    }
    return -1;
}

/**
 * Pull every `<!-- notes: ... -->` comment out of a slide's Markdown.
 *
 * A note may span lines. Several notes on one slide are joined by a blank
 * line, in source order. An unterminated opener is left in the body, on the
 * grounds that discarding the rest of a slide is the worse failure.
 *
 * The opener is only recognised in prose: inside a fenced code block or an
 * inline code span it is content, so a slide can show the notes syntax as
 * an example without the example being lifted out as a note.
 * @param source {string} one slide's Markdown
 * @return {Slide} a slide carrying the cleaned body and the notes
 */
export func takeNotes(source as string) {
    def kept as list of string init [];
    def found as list of string init [];
    def fence as string init "";
    # While a note is open: the text before its opener, its source lines kept
    # verbatim (restored if it never closes), and its text so far.
    def open as bool init false;
    def pre as string init "";
    def raw as list of string init [];
    def noteLines as list of string init [];
    for (def line in strings.split($source, "\n")) {
        def rest as string init $line;
        if ($open) {
            def stop as int init strings.indexOf($rest, NOTE_CLOSE);
            if ($stop < 0) {
                $raw[] = $rest;
                $noteLines[] = $rest;
                continue;
            }
            $noteLines[] = strings.substring($rest, 0, $stop);
            $found[] = strings.trim(strings.join($noteLines, "\n"));
            $rest = $pre + strings.substring($rest, $stop + len(NOTE_CLOSE), len($rest));
            $open = false;
            $pre = "";
            $raw = [];
            $noteLines = [];
        } elseif ($fence != "") {
            if (closesFenceLine($rest, $fence)) {
                $fence = "";
            }
            $kept[] = $rest;
            continue;
        } elseif (fenceOf($rest) != "") {
            $fence = fenceOf($rest);
            $kept[] = $rest;
            continue;
        }
        # Prose: lift each complete note on the line; one left open runs on.
        def start as int init noteStart($rest, 0);
        while ($start >= 0) {
            def after as string init strings.substring($rest, $start + len(NOTE_OPEN), len($rest));
            def stop as int init strings.indexOf($after, NOTE_CLOSE);
            if ($stop < 0) {
                break;
            }
            $found[] = strings.trim(strings.substring($after, 0, $stop));
            $rest = strings.substring($rest, 0, $start) +
                strings.substring($after, $stop + len(NOTE_CLOSE), len($after));
            $start = noteStart($rest, $start);
        }
        if ($start < 0) {
            $kept[] = $rest;
            continue;
        }
        $open = true;
        $pre = strings.substring($rest, 0, $start);
        $raw = [$rest];
        $noteLines = [strings.substring($rest, $start + len(NOTE_OPEN), len($rest))];
    }
    if ($open) {
        for (def line in $raw) {
            $kept[] = $line;
        }
    }
    def body as string init strings.join($kept, "\n");
    def clean as list of string init [];
    for (def note in $found) {
        if ($note != "") {
            $clean[] = $note;
        }
    }
    return Slide{
        number: 0,
        title: "",
        level: 0,
        body: tidy($body),
        notes: strings.join($clean, "\n\n")
    };
}

/**
 * Turn `<kbd>key</kbd>` in prose into a code span: `` `key` ``.
 *
 * A key cap is the one piece of inline HTML a deck commonly needs, and the
 * PDF renderer has no HTML, so it would otherwise print the tags as text. A
 * code span is the nearest thing it can draw. Fenced blocks and code spans
 * are left alone, so a slide can still show the tag as an example. A key
 * that itself holds a backtick, or an opener with no closer on its line, is
 * left as written.
 * @param source {string} Markdown
 * @return {string} the same Markdown with each prose key cap as a code span
 */
export func kbdToCode(source as string) {
    def out as list of string init [];
    def fence as string init "";
    for (def line in strings.split($source, "\n")) {
        if ($fence != "") {
            if (closesFenceLine($line, $fence)) {
                $fence = "";
            }
            $out[] = $line;
            continue;
        }
        if (fenceOf($line) != "") {
            $fence = fenceOf($line);
            $out[] = $line;
            continue;
        }
        def rest as string init $line;
        def at as int init strings.indexOf($rest, KBD_OPEN);
        while ($at >= 0) {
            def inner as int init $at + len(KBD_OPEN);
            def stop as int init strings.indexOf($rest, KBD_CLOSE, $inner);
            if ($stop < 0) {
                break;
            }
            def key as string init strings.substring($rest, $inner, $stop);
            if (insideCodeSpan($rest, $at) or strings.contains($key, "`")) {
                $at = strings.indexOf($rest, KBD_OPEN, $inner);
                continue;
            }
            def swapped as string init "`" + $key + "`";
            $rest = strings.substring($rest, 0, $at) + $swapped +
                strings.substring($rest, $stop + len(KBD_CLOSE), len($rest));
            $at = strings.indexOf($rest, KBD_OPEN, $at + len($swapped));
        }
        $out[] = $rest;
    }
    return strings.join($out, "\n");
}

/**
 * Collapse runs of blank lines and trim the ends of a Markdown block.
 *
 * Removing a note leaves the blank lines that surrounded it behind; without
 * this the gap would widen every time a note is lifted out. Lines inside a
 * fenced code block are kept exactly as written, blank runs and trailing
 * spaces included, since there they are the code.
 * @param source {string} a Markdown block
 * @return {string} the block with no leading, trailing, or doubled blank lines
 */
export func tidy(source as string) {
    def out as list of string init [];
    def blank as bool init true;
    def fence as string init "";
    for (def line in strings.split($source, "\n")) {
        if ($fence != "") {
            if (closesFenceLine($line, $fence)) {
                $fence = "";
            }
            $out[] = $line;
            $blank = false;
            continue;
        }
        $fence = fenceOf($line);
        def empty as bool init strings.trim($line) == "";
        if ($empty and $blank) {
            continue;
        }
        $out[] = strings.trimRight($line);
        $blank = $empty;
    }
    while (len($out) > 0 and strings.trim($out[len($out) - 1]) == "") {
        $out = lists.head($out, len($out) - 1);
    }
    return strings.join($out, "\n");
}

/**
 * The text and level of a slide's first heading.
 *
 * The heading is found by parsing the Markdown rather than by matching `#`,
 * so a `#` inside a fenced code block is not mistaken for a title.
 * @param body {string} one slide's Markdown
 * @return {Slide} a slide carrying only `title` and `level`
 */
export func heading(body as string) {
    def doc as markdown.Node init markdown.parse($body);
    def found as list of markdown.Node init markdown.findAll($doc, "heading");
    if (len($found) == 0) {
        return Slide{number: 0, title: "", level: 0, body: "", notes: ""};
    }
    def first as markdown.Node init $found[0];
    return Slide{
        number: 0,
        title: strings.trim(markdown.text($first)),
        level: markdown.level($first),
        body: "",
        notes: ""
    };
}

/**
 * Parse Markdown source into a deck.
 *
 * Front matter is read from the top of the source; the body below it is cut
 * into slides on separator lines, and each slide's speaker notes and title
 * are lifted out. A deck with no `title` in its front matter borrows the
 * first slide's heading.
 * @param source {string} the whole Markdown source
 * @return {Deck} the parsed deck, possibly with no slides
 */
export func parse(source as string) {
    def split as Split init frontMatter($source);
    def deck as Deck init Deck{
        title: metaOr($split.meta, "title", ""),
        author: metaOr($split.meta, "author", ""),
        date: metaOr($split.meta, "date", ""),
        theme: metaOr($split.meta, "theme", ""),
        ratio: metaOr($split.meta, "ratio", ""),
        meta: $split.meta,
        slides: []
    };
    # Accumulate locally: the `$xs[]` append sugar does not reach through a
    # field chain, and re-assigning the field each pass would copy the list.
    def collected as list of Slide init [];
    def n as int init 0;
    for (def chunk in chunks($split.body)) {
        $n = $n + 1;
        def taken as Slide init takeNotes($chunk);
        def head as Slide init heading($taken.body);
        $collected[] = Slide{
            number: $n,
            title: $head.title,
            level: $head.level,
            body: $taken.body,
            notes: $taken.notes
        };
    }
    $deck.slides = $collected;
    if ($deck.title == "" and len($deck.slides) > 0) {
        $deck.title = $deck.slides[0].title;
    }
    return $deck;
}

/**
 * Read a front-matter key, falling back when it is absent or blank.
 * @param meta {map of string to string} the parsed front matter
 * @param key {string} the key to read
 * @param deflt {string} what to return when the key is absent or blank
 * @return {string} the value, else `deflt`
 */
export func metaOr(meta as map of string to string, key as string, deflt as string) {
    if (not maps.has($meta, $key)) {
        return $deflt;
    }
    def found as string init $meta[$key];
    if (strings.trim($found) == "") {
        return $deflt;
    }
    return strings.trim($found);
}

/**
 * Append one deck's slides onto another, renumbering as it goes.
 *
 * This is how several input files become one deck: the first file's metadata
 * wins, because it is the one that described the deck.
 * @param deck {Deck} the deck to extend
 * @param more {Deck} the deck whose slides are appended
 * @return {Deck} a fresh deck holding both sets of slides
 */
export func concat(deck as Deck, more as Deck) {
    def out as Deck init $deck;
    def collected as list of Slide init $out.slides;
    def n as int init len($collected);
    for (def slide in $more.slides) {
        $n = $n + 1;
        def moved as Slide init $slide;
        $moved.number = $n;
        $collected[] = $moved;
    }
    $out.slides = $collected;
    if ($out.title == "" and $more.title != "") {
        $out.title = $more.title;
    }
    return $out;
}

/**
 * Rejoin a deck's slides as one Markdown document, page-broken per slide.
 *
 * The PDF renderer lays out a single document, so this is how a deck of N
 * slides becomes N pages. Speaker notes are left out; `withNotes` puts them
 * back as a trailing block.
 * @param deck {Deck} the deck to serialize
 * @param withNotes {bool} append each slide's notes under its body
 * @return {string} Markdown with a page break between consecutive slides
 */
export func toMarkdown(deck as Deck, withNotes as bool) {
    def parts as list of string init [];
    for (def slide in $deck.slides) {
        def one as string init $slide.body;
        if ($withNotes and $slide.notes != "") {
            $one = $one + "\n\n" + notesBlock($slide.notes);
        }
        $parts[] = $one;
    }
    return strings.join($parts, "\n\n" + PAGE_BREAK + "\n\n");
}

/**
 * Render speaker notes as a Markdown blockquote, so they print as a panel.
 * @param notes {string} one slide's notes
 * @return {string} the notes as a quoted block, or "" when there are none
 */
export func notesBlock(notes as string) {
    if (strings.trim($notes) == "") {
        return "";
    }
    def out as list of string init ["> **Notes**", ">"];
    for (def line in strings.split($notes, "\n")) {
        if (strings.trim($line) == "") {
            $out[] = ">";
        } else {
            $out[] = "> " + $line;
        }
    }
    return strings.join($out, "\n");
}

/**
 * A deck's slide count, for a caller that only wants the number.
 * @param deck {Deck} the deck to measure
 * @return {int} how many slides it holds
 */
export func count(deck as Deck) {
    return len($deck.slides);
}

/**
 * A one-line summary of a deck, for `--verbose` and for tests.
 * @param deck {Deck} the deck to describe
 * @return {string} the title, slide count, and how many slides carry notes
 */
export func describe(deck as Deck) {
    def noted as int init 0;
    for (def slide in $deck.slides) {
        if ($slide.notes != "") {
            $noted = $noted + 1;
        }
    }
    def title as string init $deck.title;
    if ($title == "") {
        $title = "(untitled)";
    }
    return $title + ": " + convert.toString(len($deck.slides)) + " slide(s), " +
        convert.toString($noted) + " with notes";
}
