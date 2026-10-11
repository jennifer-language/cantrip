# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

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

import "args.j" as args;
import "pdf.j" as pdf;
import "./slides.j" as slides;
import "./theme.j" as theme;
import "./htmlout.j" as htmlout;
import "./pdfout.j" as pdfout;

/** The application version, and the version `--version` reports. */
export def const VERSION as string init "0.1.0";

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
 * Every verb the command accepts, in help order.
 * @return {list of string} the subcommand names
 */
export func commands() {
    return ["build", "html", "pdf", "info", "themes"];
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
 * @throws {Error} kind "cli" when a path is missing or is not a file
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
    for (def p in $paths) {
        if (not fs.exists($p)) {
            throw Error{kind: "cli", message: "no such file: " + $p, file: $p, line: 0, col: 0};
        }
        if (not fs.isFile($p)) {
            throw Error{kind: "cli", message: "not a file: " + $p, file: $p, line: 0, col: 0};
        }
        def one as slides.Deck init slides.parse(fs.readString($p));
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
 * Load the pictures a deck refers to, so the PDF can draw them.
 *
 * A path is tried as written and then relative to the deck's own directory,
 * which is what makes `![x](img/a.png)` work from any working directory. A
 * remote URL, or a file that will not load, is skipped rather than fatal: the
 * PDF renderer falls back to the image's alt text, and losing a picture
 * should not lose the deck.
 * @param deck {slides.Deck} the deck to scan
 * @param baseDir {string} the directory the first input file came from
 * @param verbose {bool} report each picture that was skipped
 * @return {map of string to pdf.Image} pictures keyed by their source URL
 */
export func loadImages(deck as slides.Deck, baseDir as string, verbose as bool) {
    def out as map of string to pdf.Image init {};
    def n as int init 0;
    for (def url in pdfout.imageUrls($deck)) {
        if (isRemote($url)) {
            if ($verbose) {
                io.eprintf("  skipped remote image %s\n", $url);
            }
            continue;
        }
        def found as string init locate($url, $baseDir);
        if ($found == "") {
            if ($verbose) {
                io.eprintf("  image not found, using alt text: %s\n", $url);
            }
            continue;
        }
        try {
            $n = $n + 1;
            $out[$url] = pdf.loadImage("img" + convert.toString($n), fs.readBytes($found));
        } catch (e) {
            if ($verbose) {
                io.eprintf("  could not load %s: %s\n", $found, $e.message);
            }
        }
    }
    return $out;
}

/**
 * Find an image file, as written or beside the deck.
 * @param url {string} the path as written in the Markdown
 * @param baseDir {string} the directory the first input file came from
 * @return {string} the readable path, or "" when neither candidate exists
 */
export func locate(url as string, baseDir as string) {
    if (fs.exists($url) and fs.isFile($url)) {
        return $url;
    }
    if ($baseDir == "" or $baseDir == ".") {
        return "";
    }
    def beside as string init path.join($baseDir, $url);
    if (fs.exists($beside) and fs.isFile($beside)) {
        return $beside;
    }
    return "";
}

/**
 * Build the HTML renderer's options from the parsed arguments.
 * @param r {args.Result} the parsed command line
 * @return {htmlout.Options} the options to render with
 */
export func htmlOptions(r as args.Result) {
    def out as htmlout.Options init htmlout.defaults();
    $out.theme = args.asString($r, "theme");
    $out.ratio = args.asString($r, "ratio");
    $out.footer = args.asString($r, "footer");
    $out.notes = not args.asBool($r, "no-notes");
    $out.numbers = not args.asBool($r, "no-numbers");
    $out.rawHtml = args.asBool($r, "raw-html");
    $out.transition = args.asString($r, "transition");
    return $out;
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
    return Written{bytes: len(convert.bytesFromString($out, "utf-8")), pages: 0};
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
    io.printf("%s\n", slides.describe($deck));
    for (def slide in $deck.slides) {
        def title as string init $slide.title;
        if ($title == "") {
            $title = "(no heading)";
        }
        def mark as string init " ";
        if ($slide.notes != "") {
            $mark = "*";
        }
        io.printf("  %d|pad=2 %s %s\n", $slide.number, $mark, $title);
    }
    return OK;
}

/**
 * List the themes, ratios, and transitions this build ships.
 * @return {int} always `OK`
 */
export func listThemes() {
    io.printf("themes:\n");
    for (def t in theme.all()) {
        def kind as string init "light";
        if ($t.dark) {
            $kind = "dark";
        }
        io.printf("  %s|pad=16 %s|pad=6 %s\n", $t.name, $kind, $t.description);
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
    try {
        return dispatch($verb, $files, $r);
    } catch (e) {
        io.eprintf("%s: %s\n", PROGRAM, $e.message);
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
    if ($verb == "pdf") {
        def target as string init outputPath($files[0], "pdf", $given);
        guardInputs($target, $files);
        def w as Written init writePdf($deck, $r, $target, $baseDir);
        announce($target, $w.bytes, len($deck.slides), $verbose);
        warnOverflow($deck, $w.pages);
        return OK;
    }
    # build: both, sharing one parse and one base stem.
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
