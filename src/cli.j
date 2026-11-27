# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

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
use os;
use meta;
use encoding;
use httpd;

import "args.j" as args;
import "pdf.j" as pdf;
import "./slides.j" as slides;
import "./theme.j" as theme;
import "./htmlout.j" as htmlout;
import "./pdfout.j" as pdfout;
import "./highlight.j" as highlight;
import "./plugin.j" as plugin;

/** The application version, and the version `--version` reports. */
export def const VERSION as string init "0.10.0";

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
 * @field lost {list of string} a warning per character a PDF prints as `?`
 */
export def struct Written {
    bytes as int,
    pages as int,
    lost as list of string
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

/** Where `serve` listens unless `--addr` says otherwise: this machine only. */
export def const DEFAULT_ADDR as string init "127.0.0.1:8080";

/** The path the page `serve` hands out polls for the build token. */
export def const RELOAD_PATH as string init "/.cantrip-reload";

/** How often that page asks, in milliseconds. */
export def const POLL_MS as int init 700;

/** The most slides a deck may hold, across all its files. */
export def const MAX_SLIDES as int init 2000;

/**
 * Every verb the command accepts, in help order.
 * @return {list of string} the subcommand names
 */
export func commands() {
    return ["build", "html", "pdf", "handout", "highlight", "info", "plugins", "serve", "themes"];
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
            strings.join(commands(), " | ") +
            ") followed by Markdown files (for highlight, source files)");
    $p = args.flag(
        $p,
        "out",
        "o",
        "",
        "output path; for build, the path without an extension; for highlight, a directory");
    $p = args.flag($p, "theme", "t", "", "theme name (default: the deck's own, else plain)");
    $p = args.flag($p, "mode", "", "", "HTML: light, dark or auto (the system's) mode at start");
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
    $p = args.boolFlag(
        $p,
        "notes-beside",
        "",
        "handout: print each slide's speaker notes in the column beside it");
    $p = args.boolFlag($p, "no-notes", "", "leave speaker notes out of the HTML");
    $p = args.flag($p, "notes-panel", "", "", "HTML: speaker notes open or closed at start");
    $p = args.flag($p, "start-slide", "", "", "HTML: the slide to open on, from 1");
    $p = args.flag($p, "overview", "", "", "HTML: overview open or closed at start");
    $p = args.flag(
        $p,
        "notes-place",
        "",
        "",
        "HTML: where the notes panel starts: bottom, top, left or right");
    $p = args.flag($p, "notes-title", "", "", "HTML: the notes panel's heading");
    $p = args.boolFlag($p, "no-numbers", "", "omit slide numbers");
    $p = args.boolFlag($p, "credit", "", "name cantrip, with a link, on the first slide");
    $p = args.boolFlag($p, "raw-html", "", "pass raw HTML in the Markdown through unescaped");
    $p = args.flag($p, "addr", "a", DEFAULT_ADDR, "serve: the address to listen on");
    $p = args.boolFlag($p, "verbose", "v", "report what was written");
    $p = args.boolFlag(
        $p,
        "quiet",
        "q",
        "print nothing on success; warnings and errors still go to stderr");
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
    def digits as string init strings.upper(io.sprintf("%d|base=16", $n));
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
 * Read the input files, each with its path relative to the deck's directory.
 *
 * Every file is checked before anything is parsed: it must exist, be a regular
 * file, and be no larger than `MAX_DECK_BYTES`.
 * @param paths {list of string} the input files, in order
 * @return {list of plugin.Chapter} each file's relative path and text
 * @throws {Error} kind "cli" for a missing file or a directory, kind "limit"
 *     for a file over `MAX_DECK_BYTES`
 */
export func readSources(paths as list of string) {
    def out as list of plugin.Chapter;
    if (len($paths) == 0) {
        return $out;
    }
    def base as string init path.dir($paths[0]);
    for (def p in $paths) {
        if (not fs.exists($p)) {
            throw Error{kind: "cli", message: "no such file: " + $p, file: $p, line: 0, col: 0};
        }
        if (not fs.isFile($p)) {
            throw Error{kind: "cli", message: "not a file: " + $p, file: $p, line: 0, col: 0};
        }
        def size as int init fs.stat($p).size;
        if ($size > MAX_DECK_BYTES) {
            throw tooLarge($p, $size);
        }
        $out[] = plugin.Chapter{src: relativeTo($p, $base), content: fs.readString($p)};
    }
    return $out;
}

# tooLarge is the error for a deck file, or a preprocessor's rewrite of one,
# over `MAX_DECK_BYTES`.
func tooLarge(p as string, size as int) {
    return Error{
        kind: "limit",
        message: $p + " is " + convert.toString($size) + " bytes; a deck may be at most " +
            convert.toString(MAX_DECK_BYTES) + " (2 MiB)",
        file: $p,
        line: 0,
        col: 0
    };
}

/**
 * A path as the request names it: relative to the deck's directory when it
 * lies below it, else as given.
 * @param p {string} an input file
 * @param base {string} the deck's directory, the first file's
 * @return {string} the relative path
 */
export func relativeTo(p as string, base as string) {
    def dir as string init $base;
    if ($dir == "" or $dir == ".") {
        return path.clean($p);
    }
    def clean as string init path.clean($p);
    def prefix as string init path.clean($dir) + "/";
    if (strings.startsWith($clean, $prefix)) {
        return $clean[len($prefix)..];
    }
    return $clean;
}

/**
 * Parse the deck's files, in order, into one deck.
 * @param sources {list of plugin.Chapter} the files' texts
 * @return {slides.Deck} the deck; the first file's front matter wins
 * @throws {Error} kind "limit" when the deck holds more than `MAX_SLIDES`
 */
export func deckFrom(sources as list of plugin.Chapter) {
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
    for (def c in $sources) {
        # Counted before the parse, which costs a Markdown parse per slide: a
        # file of a million one-line slides would otherwise take hours to refuse.
        $total = $total + slides.slideCount($c.content);
        if ($total > MAX_SLIDES) {
            throw Error{
                kind: "limit",
                message: "the deck has more than " + convert.toString(MAX_SLIDES) +
                    " slides, the most it may have",
                file: $c.src,
                line: 0,
                col: 0
            };
        }
        def one as slides.Deck init slides.parse($c.content);
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
 * Read and parse the input files into one deck, with no plugins run.
 * @param paths {list of string} the input files, in order
 * @return {slides.Deck} the deck; the first file's front matter wins
 * @throws {Error} kind "cli" for a missing file or a directory, kind "limit"
 *     for a file over `MAX_DECK_BYTES` or a deck over `MAX_SLIDES` slides
 */
export func readDeck(paths as list of string) {
    return deckFrom(readSources($paths));
}

/**
 * The deck's files after its preprocessors ran, and where their files are.
 * @field sources {list of plugin.Chapter} each file's text, rewritten
 * @field root {string} the scratch directory holding `_generated`, "" when no
 *     preprocessor ran; the caller removes it
 */
export def struct Preprocessed {
    sources as list of plugin.Chapter,
    root as string
};

/**
 * The preprocessors a deck names in `cantrip.toml` beside its first file.
 * @param baseDir {string} the directory the first input file came from
 * @return {list of plugin.Plugin} the configured plugins, none without a file
 * @throws {Error} kind "plugin" for a malformed file
 */
export func pluginsFor(baseDir as string) {
    def file as string init path.join(dirOf($baseDir), plugin.CONFIG_FILE);
    if (not fs.isFile($file)) {
        def none as list of plugin.Plugin;
        return $none;
    }
    return plugin.parseConfig(fs.readString($file), $file);
}

# dirOf is a directory as a path can be joined to: "." for the empty string.
func dirOf(dir as string) {
    if ($dir == "") {
        return ".";
    }
    return $dir;
}

/**
 * Find a program on `PATH`: a regular file with an execute bit.
 * @param command {string} a bare program name
 * @return {string} its path, or "" when there is none
 */
export func onPath(command as string) {
    def raw as string init os.getEnv("PATH");
    for (def dir in strings.split($raw, ":")) {
        if ($dir == "") {
            continue;
        }
        def candidate as string init path.join($dir, $command);
        if (fs.isFile($candidate) and fs.stat($candidate).mode & 0o111 != 0) {
            return $candidate;
        }
    }
    return "";
}

/**
 * Work out the program one configured plugin would run.
 *
 * A command with a `/` in it is a path, relative to the deck's directory, and
 * is used as written; a bare name is looked for on `PATH`. A table that sets
 * no `command` tries `cantrip-NAME`, then `grimoire-NAME` (`plugin.candidates`).
 * @param spec {plugin.Plugin} the configured plugin
 * @param baseDir {string} the deck's directory
 * @return {plugin.Resolved} the program, and where it came from
 */
export func resolve(spec as plugin.Plugin, baseDir as string) {
    def out as plugin.Resolved init plugin.Resolved{
        name: $spec.name,
        command: $spec.command,
        args: $spec.args,
        path: "",
        origin: plugin.NOWHERE
    };
    for (def command in plugin.candidates($spec)) {
        if (strings.contains($command, "/")) {
            def full as string init $command;
            if (not path.isAbs($full)) {
                $full = path.join(dirOf($baseDir), $full);
            }
            if (not fs.isFile($full)) {
                continue;
            }
            $out.path = fs.realpath($full);
            $out.origin = plugin.OUTSIDE;
            if (within($out.path, fs.realpath(dirOf($baseDir)))) {
                $out.origin = plugin.IN_DECK;
            }
            return $out;
        }
        def found as string init onPath($command);
        if ($found != "") {
            $out.path = $found;
            $out.origin = plugin.ON_PATH;
            return $out;
        }
    }
    return $out;
}

/**
 * Every plugin a deck would run, in order.
 * @param baseDir {string} the deck's directory
 * @return {list of plugin.Resolved} one entry per configured plugin
 * @throws {Error} kind "plugin" for a malformed `cantrip.toml`
 */
export func plan(baseDir as string) {
    def out as list of plugin.Resolved;
    for (def spec in pluginsFor($baseDir)) {
        $out[] = resolve($spec, $baseDir);
    }
    return $out;
}

/**
 * The `plugins` verb: what the deck would run, and where each program came
 * from, without running anything.
 * @param baseDir {string} the deck's directory
 * @return {int} always `OK`
 * @throws {Error} kind "plugin" for a malformed `cantrip.toml`
 */
export func listPlugins(baseDir as string) {
    def resolved as list of plugin.Resolved init plan($baseDir);
    if (len($resolved) == 0) {
        io.printf(
            "no plugins: there is no %s beside the deck, or it names none\n",
            plugin.CONFIG_FILE);
        return OK;
    }
    for (def line in plugin.listing($resolved)) {
        io.printf("%s\n", printable($line));
    }
    return OK;
}

# pluginError is a plugin failure, named for the plugin.
func pluginError(name as string, message as string) {
    return Error{
        kind: "plugin",
        message: "preprocessor " + $name + ": " + $message,
        file: "",
        line: 0,
        col: 0
    };
}

# absolute is a directory as an absolute, symlink-free path.
func absolute(dir as string) {
    return fs.realpath(dirOf($dir));
}

/**
 * What the request says about the deck: its title, author and language from
 * the front matter, its directory, and where the outputs go.
 * @param sources {list of plugin.Chapter} the files as read
 * @param baseDir {string} the deck's directory
 * @param outDir {string} the directory the outputs are written to
 * @return {plugin.Book} the deck as a book
 */
export func bookOf(sources as list of plugin.Chapter, baseDir as string, outDir as string) {
    def deck as slides.Deck init deckFrom($sources);
    def authors as list of string;
    if ($deck.author != "") {
        $authors[] = $deck.author;
    }
    return plugin.Book{
        title: $deck.title,
        authors: $authors,
        language: slides.metaOr($deck.meta, "lang", ""),
        src: absolute($baseDir),
        out: absolute($outDir)
    };
}

# runOne feeds one request to one plugin and returns its reply.
func runOne(found as plugin.Resolved, body as string, verbose as bool) {
    if ($found.path == "") {
        throw pluginError(
            $found.name,
            "nothing named " + plugin.wanted($found) + " was found (see `cantrip plugins`)");
    }
    if ($verbose) {
        io.printf("  plugin  preprocessor %s  ->  %s\n", $found.name, printable($found.path));
    }
    def argv as list of string init [$found.path];
    for (def arg in $found.args) {
        $argv[] = $arg;
    }
    def result as os.Result;
    try {
        $result = os.run($argv, $body);
    } catch (e) {
        throw pluginError($found.name, "could not run " + $found.path + " (" + $e.message + ")");
    }
    if ($result.exitCode != 0) {
        throw pluginError(
            $found.name,
            "exited " + convert.toString($result.exitCode) + ": " + strings.trim($result.stderr));
    }
    return $result.stdout;
}

/**
 * Run the deck's preprocessors over its files, in the order `cantrip.toml`
 * lists them, each over what the last produced.
 *
 * Each is handed an empty directory of its own, `_generated/NAME/` in a scratch
 * directory, and what it writes there is what a slide links as
 * `_generated/NAME/...`. The caller removes `root` when the build is done; a
 * failed run removes it here.
 * @param sources {list of plugin.Chapter} the files as read
 * @param baseDir {string} the deck's directory
 * @param outDir {string} the directory the outputs are written to
 * @param verbose {bool} say what runs, by its path
 * @return {Preprocessed} the rewritten files and the scratch directory
 * @throws {Error} kind "plugin" when a plugin is missing, fails, or replies
 *     with something api 1 does not allow, when this interpreter cannot run
 *     programs, or when the deck's directory has a `_generated` of its own;
 *     kind "limit" when a rewritten file is over `MAX_DECK_BYTES`
 */
export func preprocess(
    sources as list of plugin.Chapter,
    baseDir as string,
    outDir as string,
    verbose as bool) {
    def specs as list of plugin.Plugin init pluginsFor($baseDir);
    if (len($specs) == 0) {
        return Preprocessed{sources: $sources, root: ""};
    }
    if (not meta.hasCapability("exec")) {
        throw pluginError(
            $specs[0].name,
            "this interpreter cannot run programs; preprocessors need the default `jennifer`");
    }
    def taken as string init path.join(dirOf($baseDir), plugin.GENERATED);
    if (fs.exists($taken)) {
        throw pluginError(
            $specs[0].name,
            $taken + " exists, but `" + plugin.GENERATED +
                "` is reserved for the files preprocessors generate; rename it");
    }
    for (def warning in plugin.concerns(plan($baseDir))) {
        io.eprintf("%s: warning: %s\n", PROGRAM, printable($warning));
    }
    def book as plugin.Book init bookOf($sources, $baseDir, $outDir);
    def root as string init fs.realpath(fs.makeTempDir(os.tempDir(), "cantrip-plugins-"));
    errdefer fs.removeAll($root);
    def generated as string init path.join($root, plugin.GENERATED);
    def out as list of plugin.Chapter init $sources;
    for (def spec in $specs) {
        def files as string init path.join($generated, $spec.name);
        fs.mkdirAll($files);
        def reply as string init runOne(
            resolve($spec, $baseDir),
            plugin.request($book, $spec, $out, $files, $generated),
            $verbose);
        $out = plugin.merge($spec, $out, $reply);
    }
    for (def c in $out) {
        def size as int init len(encoding.encode("utf-8", $c.content));
        if ($size > MAX_DECK_BYTES) {
            throw tooLarge($c.src, $size);
        }
    }
    return Preprocessed{sources: $out, root: $root};
}

/**
 * Remove the scratch directory a build's preprocessors wrote into.
 * @param root {string} the directory, or "" when no preprocessor ran
 */
export func discard(root as string) {
    if ($root != "") {
        fs.removeAll($root);
    }
}

/**
 * The pictures the preprocessors generated that the slides link, as `data:`
 * URLs keyed by the target the Markdown writes, for the slideshow to carry.
 * @param deck {slides.Deck} the deck
 * @param root {string} the scratch directory, "" when no preprocessor ran
 * @return {map of string to string} image target to `data:` URL
 */
export func embeddedImages(deck as slides.Deck, root as string) {
    def out as map of string to string init {};
    if ($root == "") {
        return $out;
    }
    for (def url in pdfout.imageUrls($deck)) {
        def rel as string init plugin.generatedPath($url);
        def kind as string init plugin.mediaType($rel);
        if ($rel == "" or $kind == "") {
            continue;
        }
        def file as string init path.join($root, path.join(plugin.GENERATED, $rel));
        if (fs.isFile($file)) {
            $out[$url] = "data:" + $kind + ";base64," +
                encoding.toText("base64", fs.readBytes($file));
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
    return loadImagesWith($deck, $baseDir, $verbose, "");
}

/**
 * `loadImages`, also drawing the pictures preprocessors generated.
 *
 * A target under `_generated/` is read from the scratch directory rather than
 * beside the deck. An SVG, generated or the deck's own, is drawn from the PNG
 * beside it, because the PDF draws no SVG (`plugin.printable`); without one,
 * the PDF shows the alt text.
 * @param deck {slides.Deck} the deck to scan
 * @param baseDir {string} the directory the first input file came from
 * @param verbose {bool} report each picture that was skipped, and why
 * @param root {string} the scratch directory, "" when no preprocessor ran
 * @return {map of string to pdf.Image} pictures keyed by their source URL
 */
export func loadImagesWith(
    deck as slides.Deck,
    baseDir as string,
    verbose as bool,
    root as string) {
    def out as map of string to pdf.Image init {};
    def n as int init 0;
    for (def url in pdfout.imageUrls($deck)) {
        def rel as string init plugin.generatedPath($url);
        if ($root != "" and $rel != "") {
            def file as string init path.join(
                $root,
                path.join(plugin.GENERATED, plugin.printable($rel)));
            if (not fs.isFile($file)) {
                note($verbose, "  generated image missing, using alt text: " + printable($url));
                continue;
            }
            $n = $n + 1;
            try {
                $out[$url] = pdf.loadImage("img" + convert.toString($n), fs.readBytes($file));
            } catch (e) {
                note(
                    $verbose,
                    "  could not load " + printable($url) + ": " + printable($e.message));
            }
            continue;
        }
        if (isRemote($url)) {
            if ($verbose) {
                io.eprintf("  skipped remote image %s\n", printable($url));
            }
            continue;
        }
        # The PDF draws no SVG, so an SVG is drawn from the PNG beside it.
        def where as Located init locate(plugin.printable($url), $baseDir);
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

# note prints a line on stderr under --verbose.
func note(verbose as bool, line as string) {
    if ($verbose) {
        io.eprintf("%s\n", $line);
    }
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
    $out.credit = args.asBool($r, "credit");
    $out.rawHtml = args.asBool($r, "raw-html");
    $out.transition = args.asString($r, "transition");
    $out.startNotes = args.asString($r, "notes-panel");
    $out.startSlide = args.asString($r, "start-slide");
    $out.startOverview = args.asString($r, "overview");
    $out.notesPlace = args.asString($r, "notes-place");
    $out.notesTitle = args.asString($r, "notes-title");
    return $out;
}

/**
 * Check the slideshow's start flags, `--notes-panel`, `--overview`,
 * `--notes-place` and `--start-slide`. Whether the slide exists is checked
 * against the deck later.
 * @param r {args.Result} the parsed command line
 * @throws {Error} kind "cli" on a value other than open / closed, a place
 *     other than bottom / top / left / right, or a slide number that is not a
 *     whole number from 1
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
    def place as string init strings.lower(strings.trim(args.asString($r, "notes-place")));
    if ($place != "" and not lists.contains(htmlout.NOTES_PLACES, $place)) {
        throw Error{
            kind: "cli",
            message: "--notes-place wants " + strings.join(htmlout.NOTES_PLACES, ", ") +
                ", got \"" +
                $place + "\"",
            file: "",
            line: 0,
            col: 0
        };
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
    $out.credit = args.asBool($r, "credit");
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
    return writeHtmlWith($deck, $r, $target, "");
}

/**
 * `writeHtml`, carrying the pictures preprocessors generated inside the page.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param target {string} where to write
 * @param root {string} the scratch directory, "" when no preprocessor ran
 * @return {Written} the byte count; an HTML file has no pages
 * @throws {Error} kind "theme" when a name is unknown
 */
export func writeHtmlWith(deck as slides.Deck, r as args.Result, target as string, root as string) {
    return writeHtmlIn($deck, $r, $target, $root, ".");
}

/**
 * `writeHtmlWith` for a deck in `baseDir`, which its `favicon:` is read from.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param target {string} where to write
 * @param root {string} the scratch directory, "" when no preprocessor ran
 * @param baseDir {string} the directory the first input file came from
 * @return {Written} the byte count; an HTML file has no pages
 * @throws {Error} kind "theme" when a name is unknown, kind "cli" when the
 *     deck's `favicon:` cannot be used
 */
export func writeHtmlIn(
    deck as slides.Deck,
    r as args.Result,
    target as string,
    root as string,
    baseDir as string) {
    def out as string init renderHtmlIn($deck, $r, $root, $baseDir);
    fs.writeString($target, $out);
    return Written{bytes: len(encoding.encode("utf-8", $out)), pages: 0, lost: []};
}

/**
 * The slideshow for a deck in `baseDir`, as `html` writes it: generated
 * pictures and the favicon carried inside the page.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param root {string} the scratch directory, "" when no preprocessor ran
 * @param baseDir {string} the directory the first input file came from
 * @return {string} the whole HTML document
 * @throws {Error} kind "theme" when a name is unknown, kind "cli" when the
 *     deck's `favicon:` cannot be used
 */
export func renderHtmlIn(deck as slides.Deck, r as args.Result, root as string, baseDir as string) {
    def opts as htmlout.Options init htmlOptions($r);
    $opts.embedded = embeddedImages($deck, $root);
    $opts.favicon = faviconHref($deck, $baseDir);
    return htmlout.render($deck, $opts);
}

/**
 * The page's icon from the deck's `favicon:` key, ready for the `href` of a
 * `<link rel="icon">`.
 *
 * An http(s) URL is linked as written. Anything else is a picture beside the
 * deck, found by the rule pictures follow (`locate`: inside the deck's
 * directory only), and carried inside the page as a `data:` URL, so the
 * slideshow stays one file. A key that names nothing usable stops the build:
 * the author asked for an icon, and a silently missing one is a mistake found
 * late.
 * @param deck {slides.Deck} the deck
 * @param baseDir {string} the directory the first input file came from
 * @return {string} the `href`, "" when the deck sets no favicon
 * @throws {Error} kind "cli" for a missing or refused file, or a type that is
 *     not .png, .svg, .ico, .gif or .jpg
 */
export func faviconHref(deck as slides.Deck, baseDir as string) {
    def value as string init strings.trim(slides.metaOr($deck.meta, "favicon", ""));
    if ($value == "") {
        return "";
    }
    def lower as string init strings.lower($value);
    if (strings.startsWith($lower, "https://") or strings.startsWith($lower, "http://")) {
        return $value;
    }
    def kind as string init plugin.mediaType($value);
    if (strings.endsWith($lower, ".ico")) {
        $kind = "image/x-icon";
    }
    if ($kind == "" or isRemote($value)) {
        throw Error{
            kind: "cli",
            message: "favicon: wants a .png, .svg, .ico, .gif or .jpg file beside the deck, " +
                "or an http(s) URL; got \"" + $value + "\"",
            file: "",
            line: 0,
            col: 0
        };
    }
    def where as Located init locate($value, $baseDir);
    if ($where.path == "") {
        throw Error{
            kind: "cli",
            message: "favicon: " + $value + " " + $where.reason,
            file: "",
            line: 0,
            col: 0
        };
    }
    return "data:" + $kind + ";base64," + encoding.toText("base64", fs.readBytes($where.path));
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
    return writePdfWith($deck, $r, $target, $baseDir, "");
}

/**
 * `writePdf`, also drawing the pictures preprocessors generated.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param target {string} where to write
 * @param baseDir {string} the directory the first input file came from
 * @param root {string} the scratch directory, "" when no preprocessor ran
 * @return {Written} the byte count and the page count
 * @throws {Error} kind "theme" when a name is unknown
 */
export func writePdfWith(
    deck as slides.Deck,
    r as args.Result,
    target as string,
    baseDir as string,
    root as string) {
    def opts as pdfout.Options init pdfOptions($r);
    $opts.images = loadImagesWith($deck, $baseDir, args.asBool($r, "verbose"), $root);
    def laid as pdfout.Laid init pdfout.laidOut($deck, $opts);
    def out as bytes init pdf.render($laid.doc);
    fs.writeBytes($target, $out);
    return Written{bytes: len($out), pages: pdf.getTotalPages($laid.doc), lost: $laid.lost};
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
    return writeHandoutWith($deck, $r, $target, $baseDir, "");
}

/**
 * `writeHandout`, also drawing the pictures preprocessors generated.
 * @param deck {slides.Deck} the deck to render
 * @param r {args.Result} the parsed command line
 * @param target {string} where to write
 * @param baseDir {string} the directory the first input file came from
 * @param root {string} the scratch directory, "" when no preprocessor ran
 * @return {Written} the byte count and the slide page count
 * @throws {Error} kind "theme" when a name is unknown
 */
export func writeHandoutWith(
    deck as slides.Deck,
    r as args.Result,
    target as string,
    baseDir as string,
    root as string) {
    def opts as pdfout.Options init pdfOptions($r);
    $opts.images = loadImagesWith($deck, $baseDir, args.asBool($r, "verbose"), $root);
    # Notes printed beside the slides are not printed under them as well.
    def beside as list of string init [];
    if (args.asBool($r, "notes-beside")) {
        $opts.notes = false;
        $beside = slideNotes($deck);
    }
    # The handout draws its own title, footer and notes column, not the slides' footer.
    def extra as map of string to string init {
        "the handout's title": pdfout.handoutTitle($deck),
        "the footer": $opts.footer
    };
    for (def i in 0..len($beside)) {
        $extra["the notes beside slide " + convert.toString($i + 1)] = $beside[$i];
    }
    def laid as pdfout.Laid init pdfout.laidOutWith($deck, $opts, $extra);
    def slidesDoc as pdf.Document init $laid.doc;
    def doc as pdf.Document init pdfout.handoutWith(
        $slidesDoc,
        pdfout.pickStage($deck, $opts),
        pdfout.handoutTitle($deck),
        pdfout.handoutFooter($deck, $opts),
        $beside);
    def out as bytes init pdf.render($doc);
    fs.writeBytes($target, $out);
    return Written{bytes: len($out), pages: pdf.getTotalPages($slidesDoc), lost: $laid.lost};
}

/**
 * Each slide's speaker notes, by slide, for the handout's notes column.
 * @param deck {slides.Deck} the deck
 * @return {list of string} one entry per slide, "" for a slide without notes
 */
export func slideNotes(deck as slides.Deck) {
    def out as list of string init [];
    for (def slide in $deck.slides) {
        $out[] = $slide.notes;
    }
    return $out;
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
 * Warn about every character the PDF printed as `?`, one line each.
 * @param lost {list of string} the warnings from the render
 */
export func warnLost(lost as list of string) {
    for (def message in $lost) {
        io.eprintf("%s: warning: %s\n", PROGRAM, printable($message));
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
    def files as list of string init $rest[len($rest) - (len($rest) - 1)..];
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
    if ($verb == "highlight") {
        try {
            return highlightFiles($files, args.asString($r, "out"));
        } catch (e) {
            io.eprintf("%s: %s\n", PROGRAM, printable($e.message));
            return FAILED;
        }
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
        if (args.asBool($r, "quiet") and args.asBool($r, "verbose")) {
            throw Error{
                kind: "cli",
                message: "--quiet and --verbose ask for opposite things; give one",
                file: "",
                line: 0,
                col: 0
            };
        }
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
 * The `highlight` verb: source files as highlighted HTML fragments, for a page
 * that shows code outside a deck (a site's code listings, say).
 *
 * Each fragment is the escaped text with highlight.js class names, ready to go
 * inside `<pre><code>`; the language comes from the file's name or its `#!`
 * line (`highlight.guess`), and a file in no known language is escaped plain
 * text. With `--out DIR`, each FILE is written to `DIR/FILE.html`, so FILE must
 * be a relative path that stays below DIR; DIR must exist, the directories
 * below it are made. Without `--out`, the one FILE given goes to standard
 * output.
 * @param files {list of string} the source files
 * @param out {string} the output directory, "" for standard output
 * @return {int} `OK`, or `MISUSE` for a bad command line
 * @throws {Error} kind "cli" for a missing file or directory or a path outside `out`, kind
 *   "limit" for a file over `MAX_DECK_BYTES`
 */
export func highlightFiles(files as list of string, out as string) {
    if (len($files) == 0) {
        io.eprintf("%s: highlight needs at least one file\n", PROGRAM);
        return MISUSE;
    }
    def dir as string init strings.trim($out);
    if ($dir == "") {
        if (len($files) != 1) {
            io.eprintf("%s: highlight writes more than one file only with --out\n", PROGRAM);
            return MISUSE;
        }
        io.printf("%s", highlightOne($files[0]));
        return OK;
    }
    if (not fs.isDir($dir)) {
        throw Error{
            kind: "cli",
            message: "no such directory: " + $dir,
            file: $dir,
            line: 0,
            col: 0
        };
    }
    for (def f in $files) {
        if (path.isAbs($f) or lists.contains(strings.split($f, "/"), "..")) {
            throw Error{
                kind: "cli",
                message: "highlight --out takes paths below the current directory, got " + $f,
                file: $f,
                line: 0,
                col: 0
            };
        }
    }
    for (def f in $files) {
        def target as string init path.join($dir, $f + ".html");
        def html as string init highlightOne($f);
        fs.mkdirAll(path.dir($target));
        fs.writeString($target, $html);
    }
    return OK;
}

# highlightOne reads one source file, with readDeck's checks and size cap, and
# returns it highlighted.
func highlightOne(p as string) {
    if (not fs.isFile($p)) {
        throw Error{kind: "cli", message: "no such file: " + $p, file: $p, line: 0, col: 0};
    }
    def size as int init fs.stat($p).size;
    if ($size > MAX_DECK_BYTES) {
        throw Error{
            kind: "limit",
            message: $p + " is " + convert.toString($size) + " bytes; highlight reads at most " +
                convert.toString(MAX_DECK_BYTES) + " (2 MiB)",
            file: $p,
            line: 0,
            col: 0
        };
    }
    def text as string init fs.readString($p);
    return highlight.toHtml($text, highlight.guess($p, $text));
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
    def baseDir as string init path.dir($files[0]);
    if ($verb == "plugins") {
        return listPlugins($baseDir);
    }
    if ($verb == "serve") {
        return serveDeck($files, $r);
    }
    def given as string init args.asString($r, "out");
    def verbose as bool init args.asBool($r, "verbose");
    def outDir as string init $baseDir;
    if (strings.trim($given) != "") {
        $outDir = path.dir(strings.trim($given));
    }
    def pre as Preprocessed init preprocess(readSources($files), $baseDir, $outDir, $verbose);
    # At function level: a `defer` runs when its own block exits, so one
    # inside an `if` would remove the directory before anything read it.
    defer discard($pre.root);
    def deck as slides.Deck init deckFrom($pre.sources);
    if ($verb == "info") {
        return report($deck);
    }
    requireSlides($deck);
    if ($verb == "html") {
        def target as string init outputPath($files[0], "html", $given);
        guardInputs($target, $files);
        def w as Written init writeHtmlIn($deck, $r, $target, $pre.root, $baseDir);
        announceFor($target, $w.bytes, len($deck.slides), $r);
        return OK;
    }
    if ($verb == "handout") {
        def target as string init stem($files[0]) + "-handout.pdf";
        if (strings.trim($given) != "") {
            $target = strings.trim($given);
        }
        guardInputs($target, $files);
        def w as Written init writeHandoutWith($deck, $r, $target, $baseDir, $pre.root);
        announceFor($target, $w.bytes, len($deck.slides), $r);
        warnOverflow($deck, $w.pages);
        warnLost($w.lost);
        return OK;
    }
    if ($verb == "pdf") {
        def target as string init outputPath($files[0], "pdf", $given);
        guardInputs($target, $files);
        def w as Written init writePdfWith($deck, $r, $target, $baseDir, $pre.root);
        announceFor($target, $w.bytes, len($deck.slides), $r);
        warnOverflow($deck, $w.pages);
        warnLost($w.lost);
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
    def page as Written init writeHtmlIn($deck, $r, $htmlTarget, $pre.root, $baseDir);
    announceFor($htmlTarget, $page.bytes, len($deck.slides), $r);
    def printed as Written init writePdfWith($deck, $r, $pdfTarget, $baseDir, $pre.root);
    announceFor($pdfTarget, $printed.bytes, len($deck.slides), $r);
    warnOverflow($deck, $printed.pages);
    warnLost($printed.lost);
    return OK;
}

/**
 * The build token `serve` compares: the modification times of the deck's
 * files and of every file beside the first one, so saving the deck, its
 * `cantrip.toml` or a picture changes it.
 * @param files {list of string} the input files
 * @return {string} the token
 */
export func fingerprint(files as list of string) {
    def parts as list of string init [];
    for (def f in $files) {
        if (fs.isFile($f)) {
            $parts[] = $f + ":" + convert.toString(fs.stat($f).mtimeNanos);
        }
    }
    def dir as string init dirOf(path.dir($files[0]));
    for (def name in fs.list($dir)) {
        def p as string init path.join($dir, $name);
        if (fs.isFile($p)) {
            $parts[] = $name + ":" + convert.toString(fs.stat($p).mtimeNanos);
        }
    }
    return strings.join($parts, ",");
}

/**
 * The slideshow `serve` hands out: built as `html` builds it, plugins and all,
 * with the reload script added; or, when the deck does not build, a page that
 * says why and reloads once it does.
 * @param files {list of string} the input files
 * @param r {args.Result} the parsed command line
 * @return {string} the page
 */
export func servedPage(files as list of string, r as args.Result) {
    def script as string init htmlout.reloadScript(RELOAD_PATH, POLL_MS);
    def baseDir as string init path.dir($files[0]);
    try {
        def pre as Preprocessed init preprocess(readSources($files), $baseDir, $baseDir, false);
        defer discard($pre.root);
        def deck as slides.Deck init deckFrom($pre.sources);
        requireSlides($deck);
        return htmlout.withScript(renderHtmlIn($deck, $r, $pre.root, $baseDir), $script);
    } catch (e) {
        io.eprintf("%s: %s\n", PROGRAM, printable($e.message));
        return htmlout.withScript(htmlout.errorPage($e.message), $script);
    }
    return "";
}

# servedUrl turns a listen address into something a reader can click.
func servedUrl(addr as string) {
    def host as string init $addr;
    if (strings.startsWith($host, ":")) {
        $host = "localhost" + $host;
    } elseif (strings.startsWith($host, "0.0.0.0:")) {
        $host = "localhost" + $host[7..];
    }
    return "http://" + $host + "/";
}

/**
 * The `serve` verb: show the deck in a browser while it is being written.
 *
 * The slideshow is built when the browser asks for it, so it is always the
 * deck as it is on disk, and the page carries a script that polls the build
 * token and reloads when a file changes. Anything else is a file from the
 * deck's directory, so pictures beside the deck load as they will from the
 * published copy. One request is answered at a time: a deck is one page, and a
 * build is not shared between spawned workers, each of which would hold its
 * own copy. Nothing is written to disk.
 * @param files {list of string} the input files
 * @param r {args.Result} the parsed command line, for `--addr` and the HTML flags
 * @return {int} `OK` once the server stops
 * @throws {Error} kind "cli" on `jennifer-tiny`, which has no network; kind
 *     "httpd" when the address cannot be bound
 */
export func serveDeck(files as list of string, r as args.Result) {
    if (not meta.hasCapability("net")) {
        throw Error{
            kind: "cli",
            message: "serve needs the default `jennifer`; this interpreter has no network",
            file: "",
            line: 0,
            col: 0
        };
    }
    readSources($files);
    def addr as string init strings.trim(args.asString($r, "addr"));
    def baseDir as string init dirOf(path.dir($files[0]));
    def srv as httpd.Server init httpd.listen($addr);
    if (not args.asBool($r, "quiet")) {
        io.printf("serving %s at %s (ctrl-c to stop)\n", $files[0], servedUrl($addr));
    }
    def token as string init "";
    def page as string init "";
    def running as bool init true;
    while ($running) {
        def req as httpd.Request init httpd.Request{};
        try {
            $req = httpd.accept($srv);
        } catch (e) {
            $running = false;
            continue;
        }
        def at as string init httpd.path($req);
        httpd.setHeader($req, "Cache-Control", "no-store");
        if ($at == RELOAD_PATH) {
            httpd.setHeader($req, "Content-Type", "text/plain; charset=utf-8");
            httpd.respond($req, 200, fingerprint($files));
            continue;
        }
        if ($at == "/" or $at == "/index.html") {
            def now as string init fingerprint($files);
            if ($now != $token or $page == "") {
                $page = servedPage($files, $r);
                $token = $now;
            }
            httpd.setHeader($req, "Content-Type", "text/html; charset=utf-8");
            httpd.respond($req, 200, $page);
            continue;
        }
        httpd.serveDir($req, $baseDir);
    }
    return OK;
}

/**
 * Say what was written, unless `--quiet` asked for silence.
 * @param target {string} the path written
 * @param n {int} how many bytes it holds
 * @param count {int} how many slides it covers
 * @param r {args.Result} the parsed command line, for `--quiet` and `--verbose`
 */
export func announceFor(target as string, n as int, count as int, r as args.Result) {
    if (not args.asBool($r, "quiet")) {
        announce($target, $n, $count, args.asBool($r, "verbose"));
    }
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
