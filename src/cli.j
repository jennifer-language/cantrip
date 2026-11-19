# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * The command line: parse arguments, read the Markdown, write the outputs.
 *
 * This is the only module that touches the filesystem. The renderers take
 * values and return strings or bytes, so everything that could fail on I/O
 * fails here, with one message and one exit code.
 * @module cli
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use io;
use fs;
use path;
use strings;
use lists;
use convert;
use regex;

import "args.j" as args;
import "pdf.j" as pdf;
import "./slides.j" as slides;
import "./theme.j" as theme;
import "./htmlout.j" as htmlout;
import "./pdfout.j" as pdfout;

/** The application version, and the version `--version` reports. */
export def const VERSION as string init "0.5.0";

/** The command name, as installed on PATH. */
export def const PROGRAM as string init "cantrip";

/** Exit code for a successful run. */
export def const OK as int init 0;

/** Exit code for a run that failed while doing the work. */
export def const FAILED as int init 1;

/** Exit code for a run that was asked for incorrectly. */
export def const MISUSE as int init 2;

/**
 * What writing one output produced.
 * @field bytes {int} how many bytes were written
 * @field pages {int} how many pages the output holds; 0 for the HTML
 */
export def struct Written {
    bytes as int,
    pages as int
};

/** Image URL schemes that cannot be loaded from the filesystem. */
export def const REMOTE as list of string init ["http://", "https://", "data:", "//"];

/**
 * The largest deck file read, in bytes (2 MiB); a larger one is refused. A
 * 2,000-slide deck is about 270 KB, and a file of several MiB takes minutes and
 * gigabytes to lay out, if the Markdown parser's own node budget does not
 * refuse it first.
 */
export def const MAX_DECK_BYTES as int init 2097152;

/** The most slides a deck may hold, across all its files. */
export def const MAX_SLIDES as int init 2000;

/**
 * Every verb the command accepts, in help order.
 * @return {list of string} the subcommand names
 */
export func commands() {
    return ["build", "html", "pdf", "handout", "info", "themes"];
}

/**
 * Build the argument parser.
 *
 * Positionals are taken as one list rather than declared one by one: the
 * first is the verb and the rest are input files, which keeps a single
 * parser serving every subcommand instead of one parser each.
 * @return {args.Parser} the parser `run` parses with
 */
export func parser() {
    def p as args.Parser init args.parser(
        PROGRAM,
        "Turn Markdown into an HTML slideshow and a PDF.");
    $p = args.version($p, VERSION);
    $p = args.positionalList(
        $p,
        "argv",
        "a command (" +
            strings.join(commands(), " | ") + ") followed by Markdown files");
    $p = args.flag($p, "out", "o", "", "output path; for build, the path without an extension");
    $p = args.flag($p, "theme", "t", "", "theme name (default: the deck's own, else plain)");
    $p = args.flag($p, "mode", "", "", "HTML: light or dark mode at start");
    $p = args.flag($p, "ratio", "r", "", "aspect ratio: 16:9, 16:10 or 4:3");
    $p = args.flag(
        $p,
        "transition",
        "",
        "",
        "HTML slide transition: " + strings.join(htmlout.transitions(), ", "));
    $p = args.flag($p, "footer", "f", "", "text shown at the foot of every slide");
    $p = args.flag($p, "bookmarks", "", "2", "PDF outline depth, 0 for none");
    $p = args.boolFlag($p, "notes", "n", "include speaker notes in the PDF");
    $p = args.boolFlag($p, "no-notes", "", "leave speaker notes out of the HTML");
    $p = args.flag($p, "notes-panel", "", "", "HTML: speaker notes open or closed at start");
    $p = args.flag($p, "start-slide", "", "", "HTML: the slide to open on, from 1");
    $p = args.flag($p, "overview", "", "", "HTML: overview open or closed at start");
    $p = args.boolFlag($p, "no-numbers", "", "omit slide numbers");
    $p = args.boolFlag($p, "raw-html", "", "pass raw HTML in the Markdown through unescaped");
    $p = args.boolFlag($p, "verbose", "v", "report what was written");
    return $p;
}

/**
 * Whether an image URL points somewhere the filesystem cannot reach.
 * @param url {string} the URL as written in the Markdown
 * @return {bool} true when it carries a remote or inline scheme
 */
export func isRemote(url as string) {
    def lower as string init strings.lower(strings.trim($url));
    for (def prefix in REMOTE) {
        if (strings.startsWith($lower, $prefix)) {
            return true;
        }
    }
    return false;
}

/**
 * Deck text made safe to print on a terminal.
 *
 * A title or an image path comes from the deck, which may be somebody else's,
 * so control characters and the bidirectional overrides are shown as `\xNN`
 * or `\uNNNN` escapes rather than written raw, where they could drive the
 * terminal or reorder what it shows.
 * @param text {string} text taken from a deck
 * @return {string} the same text with every control character escaped
 */
export func printable(text as string) {
    def out as list of string init [];
    for (def ch in strings.chars($text)) {
        def cp as int init convert.toCodepoint($ch);
        if ($cp < 32 or ($cp >= 127 and $cp < 160)) {
            $out[] = "\\x" + hexDigits($cp, 2);
        } elseif (($cp >= 8206 and $cp <= 8207) or ($cp >= 8234 and $cp <= 8238) or
            ($cp >= 8294 and $cp <= 8297)) {
            $out[] = "\\u" + hexDigits($cp, 4);
        } else {
            $out[] = $ch;
        }
    }
    return strings.join($out, "");
}

/**
 * A number in upper-case hex, zero-padded.
 * @param n {int} a non-negative number
 * @param width {int} the least number of digits
 * @return {string} the digits
 */
export func hexDigits(n as int, width as int) {
    def digits as string init strings.upper(convert.toString($n, 16));
    while (len($digits) < $width) {
        $digits = "0" + $digits;
    }
    return $digits;
}

/**
 * The path an output should be written to.
 *
 * An explicit `--out` wins. Otherwise the input's extension is swapped for
 * the output's, so `talk.md` becomes `talk.html` beside it.
 * @param input {string} the first input file's path
 * @param ext {string} the wanted extension, without a dot
 * @param override {string} the caller's `--out`, or "" for none
 * @return {string} where to write
 */
export func outputPath(input as string, ext as string, override as string) {
    if (strings.trim($override) != "") {
        return strings.trim($override);
    }
    return stem($input) + "." + $ext;
}

/**
 * A path with its extension removed, directory intact.
 *
 * `path.stem` drops the directory too, which would move an output next to the
 * working directory instead of next to its input.
 * @param p {string} a file path
 * @return {string} the path without its final extension
 */
export func stem(p as string) {
    def dir as string init path.dir($p);
    def base as string init path.stem($p);
    if ($dir == "" or $dir == ".") {
        return $base;
    }
    return path.join($dir, $base);
}

/**
 * Read every input file and parse them into one deck.
 *
 * The first file's front matter describes the deck; later files contribute
 * only slides, which is what lets a long talk live in one file per section.
 * @param paths {list of string} the input files, in order
 * @return {slides.Deck} the combined deck
 * @throws {Error} kind "cli" when a path is missing or is not a file, kind
 *   "limit" when a file is over `MAX_DECK_BYTES` or the deck over `MAX_SLIDES`
 */
export func readDeck(paths as list of string) {
    def out as slides.Deck init slides.Deck{
        title: "",
        author: "",
        date: "",
        theme: "",
        ratio: "",
        meta: {},
        slides: []
    };
    def first as bool init true;
    def total as int init 0;
    for (def p in $paths) {
        if (not fs.exists($p)) {
            throw Error{kind: "cli", message: "no such file: " + $p, file: $p, line: 0, col: 0};
        }
        if (not fs.isFile($p)) {
            throw Error{kind: "cli", message: "not a file: " + $p, file: $p, line: 0, col: 0};
        }
        def size as int init fs.stat($p).size;
        if ($size > MAX_DECK_BYTES) {
            throw Error{
                kind: "limit",
                message: $p + " is " + convert.toString($size) + " bytes; a deck may be at most " +
                    convert.toString(MAX_DECK_BYTES) + " (2 MiB)",
                file: $p,
                line: 0,
                col: 0
            };
        }
        def text as string init fs.readString($p);
        # Counted before the parse, which costs a Markdown parse per slide: a
        # file of a million one-line slides would otherwise take hours to refuse.
        $total = $total + slides.slideCount($text);
        if ($total > MAX_SLIDES) {
            throw Error{
                kind: "limit",
                message: "the deck has more than " + convert.toString(MAX_SLIDES) +
                    " slides, the most it may have",
                file: $p,
                line: 0,
                col: 0
            };
        }
        def one as slides.Deck init slides.parse($text);
        if ($first) {
            $out = $one;
            $first = false;
        } else {
            $out = slides.concat($out, $one);
        }
    }
    return $out;
}

/**
 * Where an image path led: the file to read, or why there is none.
 * @field path {string} the resolved file to read, "" when there is none
 * @field reason {string} why nothing is read, "" when `path` is set
 */
export def struct Located {
    path as string,
    reason as string
};

/**
 * Load the pictures a deck refers to, so the PDF can draw them.
 *
 * A path is resolved against the deck's own directory, which is what makes
 * `![x](img/a.png)` work from any working directory, and is read only when it
 * stays inside that directory (see `locate`). A remote URL, a refused path, or
 * a file that will not load is skipped rather than fatal: the PDF renderer
 * falls back to the image's alt text, and losing a picture should not lose the
 * deck.
 * @param deck {slides.Deck} the deck to scan
 * @param baseDir {string} the directory the first input file came from
 * @param verbose {bool} report each picture that was skipped, and why
 * @return {map of string to pdf.Image} pictures keyed by their source URL
 */
export func loadImages(deck as slides.Deck, baseDir as string, verbose as bool) {
    def out as map of string to pdf.Image init {};
    def n as int init 0;
    for (def url in pdfout.imageUrls($deck)) {
        if (isRemote($url)) {
            if ($verbose) {
                io.eprintf("  skipped remote image %s\n", printable($url));
            }
            continue;
        }
        def where as Located init locate($url, $baseDir);
        if ($where.path == "") {
            if ($verbose) {
                io.eprintf("  image %s, using alt text: %s\n", $where.reason, printable($url));
            }
            continue;
        }
        try {
            $n = $n + 1;
            $out[$url] = pdf.loadImage("img" + convert.toString($n), fs.readBytes($where.path));
        } catch (e) {
            if ($verbose) {
                io.eprintf("  could not load %s: %s\n", printable($url), printable($e.message));
            }
        }
    }
    return $out;
}

/**
 * Find an image file beside the deck, refusing any path that leads out of it.
 *
 * A deck may come from somebody else, and the PDF it builds may be shared, so
 * a picture is read only from the deck's own directory or below it. An
 * absolute path is refused outright. A relative one is joined to the deck's
 * directory, its `..` steps and symlinks resolved, and refused when the result
 * lies outside that directory or is not a regular file. The working directory
 * plays no part.
 * @param url {string} the path as written in the Markdown
 * @param baseDir {string} the directory the first input file came from
 * @return {Located} the file to read, or the reason there is none
 */
export func locate(url as string, baseDir as string) {
    if (strings.trim($url) == "") {
        return Located{path: "", reason: "not found"};
    }
    if (path.isAbs($url)) {
        return Located{path: "", reason: "refused (an absolute path)"};
    }
    def dir as string init $baseDir;
    if ($dir == "") {
        $dir = ".";
    }
    def candidate as string init path.join($dir, $url);
    if (not fs.exists($candidate)) {
        return Located{path: "", reason: "not found"};
    }
    def root as string init "";
    def real as string init "";
    try {
        $root = fs.realpath($dir);
        $real = fs.realpath($candidate);
    } catch (e) {
        return Located{path: "", reason: "not found"};
    }
    if (not within($real, $root)) {
        return Located{path: "", reason: "refused (outside the deck's directory)"};
    }
    if (not fs.isFile($real)) {
        return Located{path: "", reason: "refused (not a regular file)"};
    }
    return Located{path: $real, reason: ""};
}

/**
 * Whether a resolved path lies strictly below a resolved directory.
 * @param target {string} an absolute, symlink-free path
 * @param root {string} an absolute, symlink-free directory
 * @return {bool} true when `target` is inside `root`
 */
export func within(target as string, root as string) {
    def prefix as string init $root;
    if (not strings.endsWith($prefix, "/")) {
        $prefix = $prefix + "/";
    }
    return strings.startsWith($target, $prefix);
}

/**
 * Build the HTML renderer's options from the parsed arguments.
 * @param r {args.Result} the parsed command line
 * @return {htmlout.Options} the options to render with
 */
export func htmlOptions(r as args.Result) {
    def out as htmlout.Options init htmlout.defaults();
    $out.theme = args.asString($r, "theme");
    $out.mode = args.asString($r, "mode");
    $out.ratio = args.asString($r, "ratio");
    $out.footer = args.asString($r, "footer");
    $out.notes = not args.asBool($r, "no-notes");
    $out.numbers = not args.asBool($r, "no-numbers");
    $out.rawHtml = args.asBool($r, "raw-html");
    $out.transition = args.asString($r, "transition");
    $out.startNotes = args.asString($r, "notes-panel");
    $out.startSlide = args.asString($r, "start-slide");
    $out.startOverview = args.asString($r, "overview");
    return $out;
}

/**
 * Check the slideshow's start flags, `--notes-panel`, `--overview` and
 * `--start-slide`. Whether the slide exists is checked against the deck later.
 * @param r {args.Result} the parsed command line
 * @throws {Error} kind "cli" on a value other than open / closed, or a slide
 *     number that is not a whole number from 1
 */
export func startFlags(r as args.Result) {
    for (def name in ["notes-panel", "overview"]) {
        def v as string init strings.trim(args.asString($r, $name));
        if ($v != "" and $v != "open" and $v != "closed") {
            throw Error{
                kind: "cli",
                message: "--" + $name + " wants open or closed, got \"" + $v + "\"",
                file: "",
                line: 0,
                col: 0
            };
        }
    }
    def slide as string init strings.trim(args.asString($r, "start-slide"));
    if ($slide != "" and not regex.matches('^[1-9][0-9]{0,5}$', $slide)) {
        throw Error{
            kind: "cli",
            message: "--start-slide wants a slide number from 1, got \"" + $slide + "\"",
            file: "",
            line: 0,
            col: 0
        };
    }
}

/**
 * Build the PDF renderer's options from the parsed arguments.
 * @param r {args.Result} the parsed command line
 * @return {pdfout.Options} the options to render with
 * @throws {Error} kind "cli" when `--bookmarks` is not a number
 */
export func pdfOptions(r as args.Result) {
    def out as pdfout.Options init pdfout.defaults();
    $out.theme = args.asString($r, "theme");
    $out.ratio = args.asString($r, "ratio");
    $out.footer = args.asString($r, "footer");
    $out.notes = args.asBool($r, "notes");
    $out.numbers = not args.asBool($r, "no-numbers");
    $out.bookmarks = bookmarkDepth(args.asString($r, "bookmarks"));
    return $out;
}

/**
 * Read the `--bookmarks` depth.
 * @param value {string} the flag's value
 * @return {int} the depth, 0 when the flag was blank
 * @throws {Error} kind "cli" when the value is not a non-negative number
 */
export func bookmarkDepth(value as string) {
    def bare as string init strings.trim($value);
    if ($bare == "") {
        return 0;
    }
    def depth as int init 0;
    try {
        $depth = convert.toInt($bare);
    } catch (e) {
        throw Error{
            kind: "cli",
            message: "--bookmarks wants a number, got \"" + $bare + "\"",
            file: "",
            line: 0,
            col: 0
        };
    }
    if ($depth < 0 or $depth > 6) {
        throw Error{
            kind: "cli",
            message: "--bookmarks wants a depth of 0 to 6, got " + convert.toString($depth),
            file: "",
            line: 0,
            col: 0
        };
    }
    return $depth;
}

/**
 * Refuse a deck that holds no slides.
 * @param deck {slides.Deck} the deck to check
 * @throws {Error} kind "cli" when the deck is empty
 */
export func requireSlides(deck as slides.Deck) {
    if (len($deck.slides) == 0) {
        throw Error{
            kind: "cli",
            message: "no slides found; separate slides with a line of three dashes",
            file: "",
            line: 0,
            col: 0
        };
    }
}

/**
 * Write the HTML slideshow.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param target {string} where to write
 * @return {Written} the byte count; an HTML file has no pages
 * @throws {Error} kind "theme" when a name is unknown
 */
export func writeHtml(deck as slides.Deck, r as args.Result, target as string) {
    def out as string init htmlout.render($deck, htmlOptions($r));
    fs.writeString($target, $out);
    return Written{bytes: len(convert.bytesFromString("utf-8", $out)), pages: 0};
}

/**
 * Write the PDF, loading any pictures the deck refers to first.
 *
 * The page count comes from the very document that was written, pictures
 * and all, so an overflow warning describes the file on disk.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param target {string} where to write
 * @param baseDir {string} the directory the first input file came from
 * @return {Written} the byte count and the page count
 * @throws {Error} kind "theme" when a name is unknown
 */
export func writePdf(deck as slides.Deck, r as args.Result, target as string, baseDir as string) {
    def opts as pdfout.Options init pdfOptions($r);
    $opts.images = loadImages($deck, $baseDir, args.asBool($r, "verbose"));
    def doc as pdf.Document init pdfout.document($deck, $opts);
    def out as bytes init pdf.render($doc);
    fs.writeBytes($target, $out);
    return Written{bytes: len($out), pages: pdf.getTotalPages($doc)};
}

/**
 * Write the handout: the slides three to an A4 portrait page.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param target {string} where to write
 * @param baseDir {string} the directory the first input file came from
 * @return {Written} the byte count and the slide page count
 * @throws {Error} kind "theme" when a name is unknown
 */
export func writeHandout(
    deck as slides.Deck,
    r as args.Result,
    target as string,
    baseDir as string) {
    def opts as pdfout.Options init pdfOptions($r);
    $opts.images = loadImages($deck, $baseDir, args.asBool($r, "verbose"));
    def slidesDoc as pdf.Document init pdfout.document($deck, $opts);
    def doc as pdf.Document init pdfout.handout(
        $slidesDoc,
        pdfout.pickStage($deck, $opts),
        pdfout.handoutFooter($deck, $opts));
    def out as bytes init pdf.render($doc);
    fs.writeBytes($target, $out);
    return Written{bytes: len($out), pages: pdf.getTotalPages($slidesDoc)};
}

/**
 * Refuse to write an output over one of the input files.
 *
 * `-o talk.md` on `cantrip html talk.md` would otherwise replace the deck
 * with its own slideshow. The comparison is on resolved paths, so `./talk.md`
 * and a symlink to it are caught too. A target that does not exist yet cannot
 * be an input, so it passes.
 * @param target {string} where an output is about to be written
 * @param files {list of string} the input files
 * @throws {Error} kind "cli" when the target is one of the inputs
 */
export func guardInputs(target as string, files as list of string) {
    if (not fs.exists($target)) {
        return;
    }
    def resolved as string init fs.realpath($target);
    for (def p in $files) {
        if (fs.exists($p) and fs.realpath($p) == $resolved) {
            throw Error{
                kind: "cli",
                message: "refusing to overwrite the input file " + $p + " with an output",
                file: $p,
                line: 0,
                col: 0
            };
        }
    }
}

/**
 * Warn when a slide grew past its page.
 *
 * One slide is meant to be one page, so more pages than slides means
 * something overflowed, and that is worth saying out loud rather than
 * leaving to be discovered on a projector. The warning goes to stderr, so it
 * survives a build whose stdout is redirected.
 * @param deck {slides.Deck} the deck that was rendered
 * @param pages {int} the page count of the PDF just written
 */
export func warnOverflow(deck as slides.Deck, pages as int) {
    def message as string init overflowMessage(len($deck.slides), $pages);
    if ($message != "") {
        io.eprintf("%s: warning: %s\n", PROGRAM, $message);
    }
}

/**
 * The overflow warning's text, or "" when every slide fit.
 * @param slideCount {int} how many slides the deck holds
 * @param pages {int} how many pages the PDF came to
 * @return {string} a sentence naming the extra pages, else ""
 */
export func overflowMessage(slideCount as int, pages as int) {
    if ($pages <= $slideCount) {
        return "";
    }
    return convert.toString($slideCount) + " slide(s) took " + convert.toString($pages) +
        " pages; " + convert.toString($pages - $slideCount) +
        " extra page(s) mean at least one slide overflowed";
}

/**
 * Print a deck's shape without rendering anything.
 * @param deck {slides.Deck} the deck to report on
 * @return {int} always `OK`
 */
export func report(deck as slides.Deck) {
    io.printf("%s\n", printable(slides.describe($deck)));
    for (def slide in $deck.slides) {
        def title as string init $slide.title;
        if ($title == "") {
            $title = "(no heading)";
        }
        def mark as string init " ";
        if ($slide.notes != "") {
            $mark = "*";
        }
        io.printf("  %d|pad=2 %s %s\n", $slide.number, $mark, printable($title));
    }
    return OK;
}

/**
 * List the themes, ratios, and transitions this build ships.
 * @return {int} always `OK`
 */
export func listThemes() {
    io.printf("themes (each light and dark):\n");
    for (def t in theme.all()) {
        def name as string init $t.name;
        def kind as string init "light";
        if ($t.dark) {
            $name = "";
            $kind = "dark";
        }
        io.printf("  %s|pad=16 %s|pad=6 %s\n", $name, $kind, $t.description);
    }
    io.printf("ratios:\n");
    for (def name in theme.ratios()) {
        def s as theme.Stage init theme.stage($name);
        io.printf(
            "  %s|pad=16 %dx%d px, %dx%d pt\n",
            $name,
            $s.width,
            $s.height,
            $s.pageWidth,
            $s.pageHeight);
    }
    io.printf("transitions:\n");
    for (def name in htmlout.transitions()) {
        def mark as string init "";
        if ($name == htmlout.DEFAULT_TRANSITION) {
            $mark = " (default)";
        }
        io.printf("  %s%s\n", $name, $mark);
    }
    return OK;
}

/**
 * Run the command line.
 *
 * Every failure path comes back as an exit code rather than an `exit`, so the
 * launcher owns the process and a test can call this directly.
 * @param argv {list of string} the arguments, as `os.ARGS` gives them
 * @return {int} `OK`, `FAILED`, or `MISUSE`
 */
export func run(argv as list of string) {
    def r as args.Result init args.Result{
        command: "",
        values: {},
        lists: {},
        counts: {},
        present: {},
        helpText: "",
        done: false
    };
    try {
        $r = args.parse(parser(), $argv);
    } catch (e) {
        io.eprintf("%s: %s\n", PROGRAM, $e.message);
        return MISUSE;
    }
    if ($r.done) {
        io.printf("%s\n", $r.helpText);
        return OK;
    }
    def rest as list of string init args.asList($r, "argv");
    if (len($rest) == 0) {
        io.eprintf("%s\n", args.usage(parser()));
        return MISUSE;
    }
    def verb as string init $rest[0];
    def files as list of string init lists.tail($rest, len($rest) - 1);
    if (not lists.contains(commands(), $verb)) {
        io.eprintf(
            "%s: unknown command \"%s\"; try one of: %s\n",
            PROGRAM,
            $verb,
            strings.join(commands(), ", "));
        return MISUSE;
    }
    if ($verb == "themes") {
        return listThemes();
    }
    if (len($files) == 0) {
        io.eprintf("%s: %s needs at least one Markdown file\n", PROGRAM, $verb);
        return MISUSE;
    }
    # A malformed flag value is a mistake in the command line, like an
    # unknown flag, so it is misuse whichever verb it came with.
    try {
        bookmarkDepth(args.asString($r, "bookmarks"));
        startFlags($r);
    } catch (e) {
        io.eprintf("%s: %s\n", PROGRAM, $e.message);
        return MISUSE;
    }
    try {
        return dispatch($verb, $files, $r);
    } catch (e) {
        # The message can quote the deck (a theme name, a path), so it is
        # escaped like any other deck text before it reaches the terminal.
        io.eprintf("%s: %s\n", PROGRAM, printable($e.message));
        return FAILED;
    }
}

/**
 * Carry out one verb against one set of input files.
 *
 * Separated from `run` so the argument handling and the work are testable
 * apart from each other, and so every throw from here lands on one handler.
 * @param verb {string} the subcommand, already known to be valid
 * @param files {list of string} the input files, at least one
 * @param r {args.Result} the parsed command line
 * @return {int} `OK`, or `FAILED` when nothing could be produced
 * @throws {Error} kind "cli" or "theme" on bad input or an unknown name
 */
export func dispatch(verb as string, files as list of string, r as args.Result) {
    def deck as slides.Deck init readDeck($files);
    def verbose as bool init args.asBool($r, "verbose");
    if ($verb == "info") {
        return report($deck);
    }
    requireSlides($deck);
    def baseDir as string init path.dir($files[0]);
    def given as string init args.asString($r, "out");
    if ($verb == "html") {
        def target as string init outputPath($files[0], "html", $given);
        guardInputs($target, $files);
        def w as Written init writeHtml($deck, $r, $target);
        announce($target, $w.bytes, len($deck.slides), $verbose);
        return OK;
    }
    if ($verb == "handout") {
        def target as string init stem($files[0]) + "-handout.pdf";
        if (strings.trim($given) != "") {
            $target = strings.trim($given);
        }
        guardInputs($target, $files);
        def w as Written init writeHandout($deck, $r, $target, $baseDir);
        announce($target, $w.bytes, len($deck.slides), $verbose);
        warnOverflow($deck, $w.pages);
        return OK;
    }
    if ($verb == "pdf") {
        def target as string init outputPath($files[0], "pdf", $given);
        guardInputs($target, $files);
        def w as Written init writePdf($deck, $r, $target, $baseDir);
        announce($target, $w.bytes, len($deck.slides), $verbose);
        warnOverflow($deck, $w.pages);
        return OK;
    }
    # build: both, sharing one parse and one base stem. The PDF's own flags are
    # read first, so a bad one fails the run before the HTML half is written.
    pdfOptions($r);
    def base as string init stem($files[0]);
    if (strings.trim($given) != "") {
        $base = strings.trim($given);
    }
    def htmlTarget as string init $base + ".html";
    def pdfTarget as string init $base + ".pdf";
    guardInputs($htmlTarget, $files);
    guardInputs($pdfTarget, $files);
    def page as Written init writeHtml($deck, $r, $htmlTarget);
    announce($htmlTarget, $page.bytes, len($deck.slides), $verbose);
    def printed as Written init writePdf($deck, $r, $pdfTarget, $baseDir);
    announce($pdfTarget, $printed.bytes, len($deck.slides), $verbose);
    warnOverflow($deck, $printed.pages);
    return OK;
}

/**
 * Say what was written.
 *
 * Quiet by default beyond the one line naming the file, because a build step
 * that prints nothing leaves you wondering whether it ran.
 * @param target {string} the path written
 * @param n {int} how many bytes it holds
 * @param count {int} how many slides it covers
 * @param verbose {bool} add the byte count
 */
export func announce(target as string, n as int, count as int, verbose as bool) {
    if ($verbose) {
        io.printf("wrote %s (%d slide(s), %d bytes)\n", $target, $count, $n);
    } else {
        io.printf("wrote %s (%d slide(s))\n", $target, $count);
    }
}
