# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * White-box tests for the command line.
 *
 * The tests that need input files write them into a fresh temporary
 * directory, so nothing here depends on the working directory or on the
 * repository's own example deck.
 * @module cliTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;
use maps;
use encoding;
use os;
use json;
use images;

/** A small deck, written to a temporary file by `writeDeck`. */
func sample() {
    return "---\ntitle: Fixture\nauthor: Ada\ntheme: solar\nratio: 16:9\n---\n" +
        "# One\n\nText.\n\n<!-- notes: say this -->\n\n---\n\n## Two\n\n- a\n";
}

/**
 * Write a deck into a test's temporary directory.
 *
 * Each test makes its own directory with `fs.makeTempDir` and removes it with
 * a `defer`, so a run leaves nothing behind, a failing one included.
 * @param dir {string} the directory to write into
 * @param body {string} the Markdown to write
 * @param name {string} the file's base name, extension included
 * @return {string} the path written
 */
func writeDeck(dir as string, body as string, name as string) {
    def target as string init path.join($dir, $name);
    fs.writeString($target, $body);
    return $target;
}

/**
 * Parse an argument vector the way `run` does.
 * @param argv {list of string} arguments, without the program name
 * @return {args.Result} the parsed result
 */
func parsed(argv as list of string) {
    def full as list of string init ["cantrip"];
    for (def one in $argv) {
        $full[] = $one;
    }
    return args.parse(parser(), $full);
}

/**
 * Read a deck and report how it failed.
 * @param paths {list of string} the paths to try
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func readFailure(paths as list of string) {
    try {
        readDeck($paths);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * Read a bookmark depth and report how it failed.
 * @param value {string} the flag value to try
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func depthFailure(value as string) {
    try {
        bookmarkDepth($value);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/** The identity constants are the ones the manifest and docs quote. */
func testConstants() {
    testing.assertEqual(PROGRAM, "cantrip");
    testing.assertEqual(OK, 0);
    testing.assertEqual(FAILED, 1);
    testing.assertEqual(MISUSE, 2);
    testing.assertTrue(len(VERSION) > 0);
    testing.assertContains(REMOTE, "https://");
}

/** The version is a SemVer triple, since releases are tagged from it. */
func testVersionIsSemver() {
    def parts as list of string init strings.split(VERSION, ".");
    testing.assertEqual(len($parts), 3);
    for (def part in $parts) {
        convert.toInt($part);
    }
}

/** Every verb is listed, and the listing is what `run` accepts. */
func testCommands() {
    testing.assertContains(commands(), "build");
    testing.assertContains(commands(), "html");
    testing.assertContains(commands(), "pdf");
    testing.assertContains(commands(), "handout");
    testing.assertContains(commands(), "info");
    testing.assertContains(commands(), "themes");
    testing.assertContains(commands(), "highlight");
    testing.assertContains(commands(), "plugins");
    testing.assertContains(commands(), "serve");
    testing.assertEqual(len(commands()), 9);
}

/** The parser accepts every flag the help text advertises. */
func testParser() {
    def r as args.Result init parsed(["html", "a.md", "--theme", "solar", "-o", "x.html"]);
    testing.assertFalse($r.done);
    testing.assertEqual(args.asList($r, "argv"), ["html", "a.md"]);
    testing.assertEqual(args.asString($r, "theme"), "solar");
    testing.assertEqual(args.asString($r, "out"), "x.html");
}

/** The short forms parse too. */
func testParserShortFlags() {
    def r as args.Result init parsed(["pdf", "a.md", "-t", "sepia", "-r", "4:3", "-n", "-v"]);
    testing.assertEqual(args.asString($r, "theme"), "sepia");
    testing.assertEqual(args.asString($r, "ratio"), "4:3");
    testing.assertTrue(args.asBool($r, "notes"));
    testing.assertTrue(args.asBool($r, "verbose"));
}

/** Asking for help sets `done` and supplies the text to print. */
func testParserHelp() {
    def r as args.Result init parsed(["--help"]);
    testing.assertTrue($r.done);
    testing.assertContains($r.helpText, PROGRAM);
    testing.assertContains($r.helpText, "--theme");
}

/** Remote and inline image URLs are recognised as unreachable. */
func testIsRemote() {
    testing.assertTrue(isRemote("https://example.com/a.png"));
    testing.assertTrue(isRemote("http://example.com/a.png"));
    testing.assertTrue(isRemote("HTTPS://EXAMPLE.COM/A.PNG"));
    testing.assertTrue(isRemote("data:image/png;base64,AAA"));
    testing.assertTrue(isRemote("//cdn.example.com/a.png"));
    testing.assertFalse(isRemote("fig.png"));
    testing.assertFalse(isRemote("img/fig.png"));
    testing.assertFalse(isRemote("/abs/fig.png"));
    testing.assertFalse(isRemote(""));
}

/** A path loses its extension but keeps its directory. */
func testStem() {
    testing.assertEqual(stem("talk.md"), "talk");
    testing.assertEqual(stem("a/b/talk.md"), "a/b/talk");
    testing.assertEqual(stem("./talk.md"), "talk");
    testing.assertEqual(stem("talk"), "talk");
    testing.assertEqual(stem("a/b/talk"), "a/b/talk");
}

/** An output sits beside its input unless `--out` says otherwise. */
func testOutputPath() {
    testing.assertEqual(outputPath("talk.md", "html", ""), "talk.html");
    testing.assertEqual(outputPath("a/b/talk.md", "pdf", ""), "a/b/talk.pdf");
    testing.assertEqual(outputPath("talk.md", "html", "out.html"), "out.html");
    testing.assertEqual(outputPath("talk.md", "html", "  out.html  "), "out.html");
}

/** Reading one file gives its deck. */
func testReadDeck() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    def deck as slides.Deck init readDeck([$target]);
    testing.assertEqual($deck.title, "Fixture");
    testing.assertEqual($deck.theme, "solar");
    testing.assertEqual(len($deck.slides), 2);
}

/** Several files become one deck, numbered straight through. */
func testReadDeckSeveralFiles() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def one as string init path.join($dir, "a.md");
    def two as string init path.join($dir, "b.md");
    fs.writeString($one, "---\ntitle: First\n---\n# A1\n---\n# A2\n");
    fs.writeString($two, "---\ntitle: Second\n---\n# B1\n");
    def deck as slides.Deck init readDeck([$one, $two]);
    testing.assertEqual($deck.title, "First");
    testing.assertEqual(len($deck.slides), 3);
    testing.assertEqual($deck.slides[2].title, "B1");
    testing.assertEqual($deck.slides[2].number, 3);
}

/** A missing path or a directory is a catchable cli error. */
func testReadDeckRejectsBadPaths() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    testing.assertEqual(readFailure(["/nonexistent/nope.md"]), "cli");
    testing.assertEqual(readFailure([$tmp]), "cli");
    testing.assertEqual(readFailure([writeDeck($tmp, sample(), "ok.md")]), "");
}

/** A deck file over the size cap is refused before it is read, as a limit. */
func testReadDeckRefusesAnOversizedFile() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def big as string init writeDeck(
        $tmp,
        "# A\n\n" + strings.replicate("x", MAX_DECK_BYTES),
        "big.md");
    testing.assertEqual(readFailure([$big]), "limit");
    testing.assertEqual(run(["cantrip", "info", $big]), FAILED);
    def edge as string init writeDeck($tmp, strings.replicate("x", MAX_DECK_BYTES), "edge.md");
    testing.assertEqual(readFailure([$edge]), "");
}

/**
 * A deck over the slide cap is refused as a limit, counted across all its
 * files, before any slide is parsed.
 */
func testReadDeckRefusesTooManySlides() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def half as string init strings.replicate("a\n\n---\n\n", MAX_SLIDES // 2);
    def one as string init writeDeck($tmp, $half, "one.md");
    def two as string init writeDeck($tmp, $half + "b\n", "two.md");
    testing.assertEqual(readFailure([$one]), "");
    testing.assertEqual(readFailure([$one, $two]), "limit");
    testing.assertEqual(run(["cantrip", "html", $one, $two]), FAILED);
    testing.assertFalse(fs.exists(path.join($tmp, "one.html")));
}

/** Reading no files gives an empty deck rather than an error. */
func testReadDeckNoFiles() {
    testing.assertEqual(len(readDeck([]).slides), 0);
}

/** An image is found beside the deck, whatever the working directory. */
func testLocate() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def pic as string init path.join($dir, "fig.png");
    fs.writeBytes($pic, onePixelPng());
    def real as string init fs.realpath($pic);
    testing.assertEqual(locate("fig.png", $dir).path, $real);
    testing.assertEqual(locate("fig.png", $dir).reason, "");
    fs.mkdir(path.join($dir, "x"));
    testing.assertEqual(locate("./x/../fig.png", $dir).path, $real);
    testing.assertEqual(locate("../" + path.base($dir) + "/fig.png", $dir).path, $real);
    testing.assertEqual(locate("missing.png", $dir).reason, "not found");
    testing.assertEqual(locate("", $dir).reason, "not found");
}

/** A path that leads out of the deck's directory is refused, and says why. */
func testLocateRefusesPathsOutOfTheDeck() {
    def root as string init fs.makeTempDir();
    defer fs.removeAll($root);
    def dir as string init path.join($root, "deck");
    fs.mkdir($dir);
    def outside as string init path.join($root, "secret.png");
    fs.writeBytes($outside, onePixelPng());
    fs.symlink($outside, path.join($dir, "link.png"));
    testing.assertEqual(locate($outside, $dir).reason, "refused (an absolute path)");
    testing.assertEqual(
        locate("../secret.png", $dir).reason,
        "refused (outside the deck's directory)");
    testing.assertEqual(locate("link.png", $dir).reason, "refused (outside the deck's directory)");
    testing.assertEqual(locate("..", $dir).reason, "refused (outside the deck's directory)");
}

/** A directory or a pipe is not a usable image. */
func testLocateIgnoresDirectories() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    fs.mkdir(path.join($dir, "sub"));
    fs.mkfifo(path.join($dir, "pipe.png"));
    testing.assertEqual(locate("sub", $dir).reason, "refused (not a regular file)");
    testing.assertEqual(locate("pipe.png", $dir).reason, "refused (not a regular file)");
}

/** A path is inside a directory only strictly below it. */
func testWithin() {
    testing.assertTrue(within("/a/b/c.png", "/a/b"));
    testing.assertTrue(within("/a/b/c.png", "/a/b/"));
    testing.assertTrue(within("/x.png", "/"));
    testing.assertFalse(within("/a/bc.png", "/a/b"));
    testing.assertFalse(within("/a/b", "/a/b"));
    testing.assertFalse(within("/a", "/a/b"));
}

/**
 * The PDF reads pictures from the deck's directory and below only: one
 * reached by `..`, by an absolute path, or through a symlink out of the
 * directory keeps its alt text, so an untrusted deck cannot pull another file
 * into the PDF it builds.
 */
func testLoadImagesStaysInsideTheDeck() {
    def root as string init fs.makeTempDir();
    defer fs.removeAll($root);
    def dir as string init path.join($root, "deck");
    fs.mkdirAll(path.join($dir, "img"));
    def outside as string init path.join($root, "secret.png");
    fs.writeBytes($outside, onePixelPng());
    fs.writeBytes(path.join($dir, "img", "ok.png"), onePixelPng());
    fs.symlink($outside, path.join($dir, "link.png"));
    fs.symlink(path.join($dir, "img", "ok.png"), path.join($dir, "inner.png"));
    def urls as list of string init [
        "img/ok.png",
        "inner.png",
        "../secret.png",
        $outside,
        "link.png"
    ];
    def body as list of string init ["# H"];
    for (def url in $urls) {
        $body[] = "![x](" + $url + ")";
    }
    def target as string init writeDeck($dir, strings.join($body, "\n\n"), "deck.md");
    def got as map of string to pdf.Image init loadImages(readDeck([$target]), $dir, true);
    testing.assertTrue(maps.has($got, "img/ok.png"));
    testing.assertTrue(maps.has($got, "inner.png"));
    testing.assertEqual(len(maps.keys($got)), 2);
}

/** A picture beside the deck is loaded and keyed by its source URL. */
func testLoadImages() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def target as string init path.join($dir, "deck.md");
    fs.writeString($target, "# H\n\n![a pic](fig.png)\n");
    fs.writeBytes(path.join($dir, "fig.png"), onePixelPng());
    def got as map of string to pdf.Image init loadImages(readDeck([$target]), $dir, false);
    testing.assertTrue(maps.has($got, "fig.png"));
    testing.assertEqual(len(maps.keys($got)), 1);
}

/** A remote or missing picture is skipped, not fatal. */
func testLoadImagesSkipsWhatItCannotRead() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def target as string init path.join($dir, "deck.md");
    fs.writeString($target, "# H\n\n![a](https://example.com/a.png)\n\n![b](missing.png)\n");
    def got as map of string to pdf.Image init loadImages(readDeck([$target]), $dir, false);
    testing.assertEqual(len(maps.keys($got)), 0);
}

/** A deck with no pictures loads none. */
func testLoadImagesNone() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    def got as map of string to pdf.Image init loadImages(readDeck([$target]), ".", false);
    testing.assertEqual(len(maps.keys($got)), 0);
}

/** The HTML options follow the flags, including the negative ones. */
func testHtmlOptions() {
    def plain as htmlout.Options init htmlOptions(parsed(["html", "a.md"]));
    testing.assertTrue($plain.notes);
    testing.assertTrue($plain.numbers);
    testing.assertFalse($plain.rawHtml);
    testing.assertFalse($plain.credit);
    testing.assertTrue(htmlOptions(parsed(["html", "a.md", "--credit"])).credit);
    def r as args.Result init parsed([
        "html",
        "a.md",
        "--no-notes",
        "--no-numbers",
        "--raw-html",
        "--theme",
        "sepia",
        "--ratio",
        "4:3",
        "--footer",
        "F",
        "--transition",
        "zoom"
    ]);
    def got as htmlout.Options init htmlOptions($r);
    testing.assertFalse($got.notes);
    testing.assertFalse($got.numbers);
    testing.assertTrue($got.rawHtml);
    testing.assertEqual($got.theme, "sepia");
    testing.assertEqual($got.ratio, "4:3");
    testing.assertEqual($got.footer, "F");
    testing.assertEqual($got.transition, "zoom");
    testing.assertEqual($plain.transition, "");
    def placed as htmlout.Options init htmlOptions(
        parsed(["html", "a.md", "--notes-place", "right", "--notes-title", "Script"]));
    testing.assertEqual($placed.notesPlace, "right");
    testing.assertEqual($placed.notesTitle, "Script");
}

/** The PDF options follow the flags, and notes are opt-in. */
func testPdfOptions() {
    def plain as pdfout.Options init pdfOptions(parsed(["pdf", "a.md"]));
    testing.assertFalse($plain.notes);
    testing.assertTrue($plain.numbers);
    testing.assertEqual($plain.bookmarks, 2);
    testing.assertFalse($plain.credit);
    testing.assertTrue(pdfOptions(parsed(["pdf", "a.md", "--credit"])).credit);
    def r as args.Result init parsed(["pdf", "a.md", "-n", "--no-numbers", "--bookmarks", "0"]);
    def got as pdfout.Options init pdfOptions($r);
    testing.assertTrue($got.notes);
    testing.assertFalse($got.numbers);
    testing.assertEqual($got.bookmarks, 0);
}

/** A bookmark depth is a number from zero to six. */
func testBookmarkDepth() {
    testing.assertEqual(bookmarkDepth(""), 0);
    testing.assertEqual(bookmarkDepth("  "), 0);
    testing.assertEqual(bookmarkDepth("0"), 0);
    testing.assertEqual(bookmarkDepth("3"), 3);
    testing.assertEqual(bookmarkDepth("6"), 6);
    testing.assertEqual(depthFailure("7"), "cli");
    testing.assertEqual(depthFailure("-1"), "cli");
    testing.assertEqual(depthFailure("two"), "cli");
    testing.assertEqual(depthFailure("2.5"), "cli");
}

/** An empty deck is refused before anything is written. */
func testRequireSlides() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    requireSlides(readDeck([writeDeck($tmp, sample(), "deck.md")]));
    def kind as string init "";
    try {
        requireSlides(slides.parse("---\ntitle: T\n---\n"));
    } catch (e) {
        $kind = $e.kind;
    }
    testing.assertEqual($kind, "cli");
}

/** Writing the HTML produces a complete document on disk. */
func testWriteHtml() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def target as string init path.join($dir, "out.html");
    def deck as slides.Deck init readDeck([writeDeck($dir, sample(), "deck.md")]);
    def w as Written init writeHtml($deck, parsed(["html", "a.md"]), $target);
    testing.assertTrue($w.bytes > 1000);
    testing.assertEqual($w.pages, 0);
    testing.assertEqual(len(fs.readBytes($target)), $w.bytes);
    def got as string init fs.readString($target);
    testing.assertTrue(strings.startsWith($got, "<!doctype html>"));
    testing.assertContains($got, "Fixture");
}

/** Writing the PDF produces a real PDF on disk. */
func testWritePdf() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def target as string init path.join($dir, "out.pdf");
    def deck as slides.Deck init readDeck([writeDeck($dir, sample(), "deck.md")]);
    def w as Written init writePdf($deck, parsed(["pdf", "a.md"]), $target, $dir);
    testing.assertTrue($w.bytes > 500);
    testing.assertEqual($w.pages, 2);
    def got as bytes init fs.readBytes($target);
    testing.assertEqual(len($got), $w.bytes);
    testing.assertEqual(encoding.decode("utf-8", $got[..5]), "%PDF-");
}

/** The handout reports the slide pages, not its own A4 pages. */
func testWriteHandout() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def target as string init path.join($dir, "out-handout.pdf");
    def deck as slides.Deck init readDeck([writeDeck($dir, sample(), "deck.md")]);
    def w as Written init writeHandout($deck, parsed(["handout", "a.md"]), $target, $dir);
    testing.assertEqual($w.pages, 2);
    def got as bytes init fs.readBytes($target);
    testing.assertEqual(len($got), $w.bytes);
    testing.assertEqual(encoding.decode("utf-8", $got[..5]), "%PDF-");
}

/**
 * The page count includes the pictures: a slide pushed over its page by a
 * tall image is counted from the written file, not from a text-only layout.
 */
func testWritePdfCountsPicturePages() {
    def dir as string init fs.makeTempDir();
    defer fs.removeAll($dir);
    def deck as string init path.join($dir, "deck.md");
    fs.writeString($deck, "# Tall\n\n![tall](tall.png)\n\nText under it.\n\n---\n\n# Two\n");
    fs.writeBytes(path.join($dir, "tall.png"), tallPng());
    def w as Written init writePdf(
        readDeck([$deck]),
        parsed(["pdf", $deck]),
        path.join($dir, "out.pdf"),
        $dir);
    testing.assertTrue($w.pages > 2);
}

/** An output may not land on one of the inputs, however it is spelled. */
func testGuardInputs() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    def kind as string init "";
    try {
        guardInputs(path.join(path.dir($target), ".", "deck.md"), [$target]);
    } catch (e) {
        $kind = $e.kind;
    }
    testing.assertEqual($kind, "cli");
    guardInputs(path.join(path.dir($target), "deck.html"), [$target]);
    guardInputs(writeDeck($tmp, "x", "other.md"), [$target]);
}

/** `-o` naming the input is refused, and the input survives. */
func testRunRefusesToOverwriteInput() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "html", $target, "-o", $target]), FAILED);
    testing.assertEqual(fs.readString($target), sample());
}

/** The overflow text names the extra pages, and is empty when all fit. */
func testOverflowMessage() {
    testing.assertEqual(overflowMessage(10, 10), "");
    testing.assertEqual(overflowMessage(10, 9), "");
    def got as string init overflowMessage(10, 12);
    testing.assertContains($got, "10 slide(s) took 12 pages");
    testing.assertContains($got, "2 extra page(s)");
}

/** Reporting a deck lists every slide and never fails. */
func testReport() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    testing.assertEqual(report(readDeck([writeDeck($tmp, sample(), "deck.md")])), OK);
    testing.assertEqual(report(slides.parse("")), OK);
}

/** Listing the themes never fails. */
func testListThemes() {
    testing.assertEqual(listThemes(), OK);
}

/** The overflow warning is advisory and never changes the outcome. */
func testWarnOverflow() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def deck as slides.Deck init readDeck([writeDeck($tmp, sample(), "deck.md")]);
    warnOverflow($deck, 2);
    warnOverflow($deck, 5);
}

/**
 * A PDF write reports the characters it printed as `?`, and the warning is
 * advisory too; a clean deck reports none, and the HTML never does.
 */
func testWriteReportsLostCharacters() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def deck as slides.Deck init readDeck([writeDeck($tmp, "# A \u2192 B\n", "arrow.md")]);
    def r as args.Result init parsed(["pdf", "arrow.md"]);
    def w as Written init writePdf($deck, $r, path.join($tmp, "arrow.pdf"), $tmp);
    testing.assertEqual(len($w.lost), 1);
    testing.assertContains($w.lost[0], "U+2192");
    def h as Written init writeHandout($deck, $r, path.join($tmp, "arrow-handout.pdf"), $tmp);
    testing.assertTrue(len($h.lost) >= 1);
    warnLost($w.lost);
    def clean as slides.Deck init readDeck([writeDeck($tmp, sample(), "deck.md")]);
    testing.assertEqual(len(writePdf($clean, $r, path.join($tmp, "deck.pdf"), $tmp).lost), 0);
}

/** Announcing a write never fails, quiet or verbose. */
func testAnnounce() {
    announce("x.html", 10, 2, false);
    announce("x.html", 10, 2, true);
}

/** `info` reads the deck and writes nothing. */
func testDispatchInfo() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(dispatch("info", [$target], parsed(["info", $target])), OK);
    testing.assertFalse(fs.exists(stem($target) + ".html"));
}

/** `html` writes the slideshow beside its input. */
func testDispatchHtml() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(dispatch("html", [$target], parsed(["html", $target])), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
    testing.assertFalse(fs.exists(stem($target) + ".pdf"));
}

/** `pdf` writes the PDF beside its input. */
func testDispatchPdf() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(dispatch("pdf", [$target], parsed(["pdf", $target])), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".pdf"));
    testing.assertFalse(fs.exists(stem($target) + ".html"));
}

/** `handout` writes `<stem>-handout.pdf`, and `-o` names it instead. */
func testDispatchHandout() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(dispatch("handout", [$target], parsed(["handout", $target])), OK);
    def out as string init stem($target) + "-handout.pdf";
    testing.assertTrue(fs.isFile($out));
    testing.assertFalse(fs.exists(stem($target) + ".pdf"));
    def head as bytes init fs.readBytes($out);
    testing.assertEqual(encoding.decode("utf-8", $head[0..5]), "%PDF-");
    def named as string init path.join($tmp, "print.pdf");
    testing.assertEqual(
        dispatch("handout", [$target], parsed(["handout", $target, "-o", $named])),
        OK);
    testing.assertTrue(fs.isFile($named));
}

/** `build` writes both, sharing one stem. */
func testDispatchBuild() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(dispatch("build", [$target], parsed(["build", $target])), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
    testing.assertTrue(fs.isFile(stem($target) + ".pdf"));
}

/** For `build`, `--out` is the stem both outputs hang off. */
func testDispatchBuildHonoursOut() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    def base as string init path.join($tmp, "named");
    def r as args.Result init parsed(["build", $target, "-o", $base]);
    testing.assertEqual(dispatch("build", [$target], $r), OK);
    testing.assertTrue(fs.isFile($base + ".html"));
    testing.assertTrue(fs.isFile($base + ".pdf"));
}

/** For `html` and `pdf`, `--out` is the exact file. */
func testDispatchHonoursOut() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    def named as string init path.join($tmp, "exact.htm");
    def r as args.Result init parsed(["html", $target, "-o", $named]);
    testing.assertEqual(dispatch("html", [$target], $r), OK);
    testing.assertTrue(fs.isFile($named));
}

/** An unknown theme reaches the caller as a theme error. */
func testDispatchPropagatesThemeError() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    def kind as string init "";
    try {
        dispatch("html", [$target], parsed(["html", $target, "--theme", "nope"]));
    } catch (e) {
        $kind = $e.kind;
    }
    testing.assertEqual($kind, "theme");
}

/** `themes` needs no input file and succeeds. */
func testRunThemes() {
    testing.assertEqual(run(["cantrip", "themes"]), OK);
}

/** Help and version are reported, not refused. */
func testRunHelp() {
    testing.assertEqual(run(["cantrip", "--help"]), OK);
    testing.assertEqual(run(["cantrip", "--version"]), OK);
}

/** No arguments prints usage and reports misuse. */
func testRunWithoutArguments() {
    testing.assertEqual(run(["cantrip"]), MISUSE);
}

/** An unknown verb is misuse, not a failure to build. */
func testRunUnknownCommand() {
    testing.assertEqual(run(["cantrip", "frobnicate", "a.md"]), MISUSE);
}

/** A verb that needs a file and was given none is misuse. */
func testRunWithoutFiles() {
    testing.assertEqual(run(["cantrip", "html"]), MISUSE);
    testing.assertEqual(run(["cantrip", "build"]), MISUSE);
}

/** An unknown flag is misuse. */
func testRunUnknownFlag() {
    testing.assertEqual(run(["cantrip", "html", "a.md", "--nope"]), MISUSE);
}

/** A missing input file is a failure, having been asked for correctly. */
func testRunMissingFile() {
    testing.assertEqual(run(["cantrip", "html", "/nonexistent/nope.md"]), FAILED);
}

/** An unknown transition is a failure, like an unknown theme. */
func testRunBadTransition() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "html", $target, "--transition", "spin"]), FAILED);
}

/** An unknown theme is a failure, with a message rather than a stack. */
func testRunBadTheme() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "html", $target, "--theme", "nope"]), FAILED);
}

/** A deck with no slides is a failure, and writes nothing. */
func testRunEmptyDeck() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, "---\ntitle: T\n---\n", "empty.md");
    testing.assertEqual(run(["cantrip", "html", $target]), FAILED);
    testing.assertFalse(fs.exists(stem($target) + ".html"));
}

/** A whole run writes both outputs and reports success. */
func testRunBuild() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "build", $target, "-v"]), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
    testing.assertTrue(fs.isFile(stem($target) + ".pdf"));
}

/** A bad `--bookmarks` is misuse, refused before `build` writes the HTML half. */
func testRunBuildBadBookmarksWritesNothing() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "build", $target, "--bookmarks", "x"]), MISUSE);
    testing.assertEqual(run(["cantrip", "html", $target, "--bookmarks", "9"]), MISUSE);
    testing.assertFalse(fs.exists(stem($target) + ".html"));
    testing.assertFalse(fs.exists(stem($target) + ".pdf"));
    testing.assertEqual(run(["cantrip", "build", $target, "--bookmarks", "1"]), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
}

/** Control characters and bidi overrides from a deck are shown escaped. */
func testPrintable() {
    testing.assertEqual(printable("plain é 日本 -> ok"), "plain é 日本 -> ok");
    testing.assertEqual(printable("a\u001B[31mb"), "a\\x1B[31mb");
    testing.assertEqual(printable("x\ny\t\r"), "x\\x0Ay\\x09\\x0D");
    testing.assertEqual(printable("\u0007\u007F\u009B"), "\\x07\\x7F\\x9B");
    testing.assertEqual(printable("\u202Eevil\u2066"), "\\u202Eevil\\u2066");
    testing.assertEqual(hexDigits(10, 2), "0A");
    testing.assertEqual(hexDigits(8238, 4), "202E");
}

/** `info` through the whole run reports success. */
func testRunInfo() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "info", $target]), OK);
}

/**
 * A tall PNG, 60x900 pixels, for the tests that need a picture to overflow.
 * @return {bytes} a greyscale PNG
 */
func tallPng() {
    return encoding.fromText(
        "base64",
        "iVBORw0KGgoAAAANSUhEUgAAADwAAAOECAAAAADY5g0rAAAAAmJLR0QA/4ePzL8AAAAH" +
            "dElNRQfqChQQARoWnyFmAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDI2LTEwLTIwVDE2OjAx" +
            "OjI2KzAwOjAwPOvwIQAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyNi0xMC0yMFQxNjowMToy" +
            "NiswMDowME22SJ0AAAAodEVYdGRhdGU6dGltZXN0YW1wADIwMjYtMTAtMjBUMTY6MDE6" +
            "MjYrMDA6MDAao2lCAAAAvUlEQVR42u3LsQ0AAAQAMDzudT8QW7s3O/bqcGVZlmVZlmVZ" +
            "lmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZ" +
            "lmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZ" +
            "lmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlh/y" +
            "AFvEB4eZ6hNNAAAAAElFTkSuQmCC");
}

/**
 * The smallest valid PNG, for the tests that need real image bytes.
 * @return {bytes} a 1x1 greyscale PNG
 */
func onePixelPng() {
    return encoding.fromText(
        "base64",
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQAB" +
            "lpSm1gAAAABJRU5ErkJggg==");
}

/** The start flags reach the HTML options. */
func testHtmlOptionsStart() {
    def none as htmlout.Options init htmlOptions(parsed(["html", "a.md"]));
    testing.assertEqual($none.startNotes, "");
    def r as args.Result init parsed([
        "html",
        "a.md",
        "--notes-panel",
        "open",
        "--start-slide",
        "2",
        "--overview",
        "closed"
    ]);
    def got as htmlout.Options init htmlOptions($r);
    testing.assertEqual($got.startNotes, "open");
    testing.assertEqual($got.startSlide, "2");
    testing.assertEqual($got.startOverview, "closed");
}

/** A bad start flag is misuse, exit 2, before anything is written. */
func testRunBadStartFlags() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "build", $target, "--notes-panel", "yes"]), MISUSE);
    testing.assertEqual(run(["cantrip", "html", $target, "--overview", "OPEN!"]), MISUSE);
    testing.assertEqual(run(["cantrip", "html", $target, "--start-slide", "0"]), MISUSE);
    testing.assertEqual(run(["cantrip", "html", $target, "--start-slide", "two"]), MISUSE);
    testing.assertFalse(fs.exists(stem($target) + ".html"));
    # Valid as flags, but wrong for this deck: a failed build, exit 1.
    testing.assertEqual(run(["cantrip", "html", $target, "--start-slide", "3"]), FAILED);
    testing.assertEqual(
        run(["cantrip", "html", $target, "--no-notes", "--notes-panel", "open"]),
        FAILED);
    testing.assertFalse(fs.exists(stem($target) + ".html"));
    testing.assertEqual(
        run(["cantrip", "html", $target, "--notes-panel", "open", "--start-slide", "2"]),
        OK);
    testing.assertContains(
        fs.readString(stem($target) + ".html"),
        "data-notes=\"open\" data-slide=\"2\"");
}

/** The start flags take open / closed, a notes place and a slide number from 1. */
func testStartFlags() {
    startFlags(parsed(["html", "a.md"]));
    startFlags(parsed([
        "html",
        "a.md",
        "--notes-panel",
        "closed",
        "--overview",
        "open",
        "--start-slide",
        "12",
        "--notes-place",
        "Right"
    ]));
    for (def bad in [
        ["--notes-place", "side"],
        ["--notes-panel", "Open"],
        ["--overview", "1"],
        ["--start-slide", "-1"],
        ["--start-slide", "1.5"]
    ]) {
        def argv as list of string init ["html", "a.md"];
        $argv[] = $bad[0];
        $argv[] = $bad[1];
        def kind as string init "";
        try {
            startFlags(parsed($argv));
        } catch (e) {
            $kind = $e.kind;
        }
        testing.assertEqual($kind, "cli");
    }
}

/** highlight writes each file below --out as an escaped, highlighted fragment. */
func testHighlightFiles() {
    def src as string init fs.makeTempDir(os.cwd());
    defer fs.removeAll($src);
    def out as string init fs.makeTempDir();
    defer fs.removeAll($out);
    def rel as string init path.base($src);
    fs.mkdirAll(path.join($src, "bin"));
    fs.writeString(path.join($src, "main.j"), "def x as int init 1; # <b>\n");
    fs.writeString(path.join($src, "bin", "tool"), "#!/usr/bin/env jennifer\nreturn 0;\n");
    fs.writeString(path.join($src, "notes.txt"), "a < b\n");
    testing.assertEqual(
        highlightFiles(
            [
                path.join($rel, "main.j"),
                path.join($rel, "bin", "tool"),
                path.join($rel, "notes.txt")
            ],
            $out),
        OK);
    def main as string init fs.readString(path.join($out, $rel, "main.j.html"));
    testing.assertContains($main, "<span class=\"hljs-keyword\">def</span>");
    testing.assertContains($main, "&lt;b&gt;");
    testing.assertContains(fs.readString(path.join($out, $rel, "bin", "tool.html")), "hljs-");
    testing.assertEqual(fs.readString(path.join($out, $rel, "notes.txt.html")), "a &lt; b\n");
}

/** highlight --out refuses a path that would leave the output directory. */
func testHighlightFilesStaysBelowOut() {
    def out as string init fs.makeTempDir();
    defer fs.removeAll($out);
    def kind as string init "";
    try {
        highlightFiles(["../x.j"], $out);
    } catch (e) {
        $kind = $e.kind;
    }
    testing.assertEqual($kind, "cli");
}

# --- preprocessors -----------------------------------------------------

# A plugin in Jennifer, run through `jennifer run`: it checks the request the
# way a Grimoire plugin would, draws a picture into `plugin.files` (an SVG and
# the PNG beside it), and rewrites DIAGRAM and MATHS on the first file.
def const FAKE_PLUGIN as list of string init [
    'use io;',
    'use json;',
    'use fs;',
    'use path;',
    'use strings;',
    'use images;',
    'use convert;',
    'def req as json.Value init json.decode(strings.join(io.readLines(), "\n"));',
    'if (json.asInt($req, "/api") != 1 or json.asString($req, "/kind") != "preprocessor" or',
    '    json.asString($req, "/features/0") != "files" or',
    '    json.asString($req, "/plugin/settings/colour") != "red") {',
    '    io.eprintf("fake: unexpected request\n");',
    '    exit 3;',
    '}',
    'def files as string init json.asString($req, "/plugin/files");',
    'fs.writeString(path.join($files, "d.svg"), "<svg xmlns=\"http://www.w3.org/2000/svg\"/>");',
    'fs.writeBytes(path.join($files, "d.png"), images.encode("png", images.create(4, 4)));',
    'def text as string init json.asString($req, "/chapters/0/content");',
    '$text = strings.replace($text, "DIAGRAM", "![d](_generated/fake/d.svg)");',
    '$text = strings.replace($text, "MATHS", MATHS_ELEMENT);',
    'def open as string init convert.fromCodepoint(123);',
    'def close as string init convert.fromCodepoint(125);',
    'def src as string init json.encode(json.asString($req, "/chapters/0/src"));',
    'io.printf("%s", $open + "\"api\":1,\"chapters\":[" + $open + "\"src\":" + $src +',
    '    ",\"content\":" + json.encode($text) + $close + "]" + $close);'
];

def const MATHS_ELEMENT as string init '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi>' +
    '<annotation encoding="application/x-tex">x^2</annotation></math>';

# pluginDeck writes a deck, the fake plugin and a cantrip.toml naming it.
func pluginDeck(dir as string) {
    def program as string init strings.replace(
        strings.join(FAKE_PLUGIN, "\n") + "\n",
        "MATHS_ELEMENT",
        json.encode(MATHS_ELEMENT));
    fs.writeString(path.join($dir, "fake.j"), $program);
    fs.writeString(
        path.join($dir, "cantrip.toml"),
        "[preprocessor.fake]\n" + 'command = "jennifer"' + "\n" +
            'args = ["run", ' + json.encode(path.join($dir, "fake.j")) + ']' + "\n" +
            'colour = "red"' + "\n");
    return writeDeck(
        $dir,
        "---\ntitle: Plugged\nauthor: Ada\nlang: en\n---\n# One\n\nDIAGRAM\n\n---\n\n## Two\n\nInline MATHS here.\n",
        "talk.md");
}

# scratchCount is how many preprocessor scratch directories exist.
func scratchCount() {
    def n as int init 0;
    for (def name in fs.list(os.tempDir())) {
        if (strings.startsWith($name, "cantrip-plugins-")) {
            $n = $n + 1;
        }
    }
    return $n;
}

func testPreprocessorsRewriteTheDeckAndDrawItsPictures() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init pluginDeck($dir);
    def out as string init path.join($dir, "out");
    def before as int init scratchCount();
    testing.assertEqual(run(["cantrip", "build", $target, "-o", $out]), OK);
    testing.assertEqual(scratchCount(), $before);
    def page as string init fs.readString($out + ".html");
    testing.assertContains($page, 'src="data:image/svg+xml;base64,');
    testing.assertFalse(strings.contains($page, "_generated/fake/d.svg"));
    testing.assertContains($page, '<math xmlns="http://www.w3.org/1998/Math/MathML">');
    testing.assertFalse(strings.contains($page, "DIAGRAM"));
    def printed as bytes init fs.readBytes($out + ".pdf");
    testing.assertEqual(encoding.decode("utf-8", $printed[..4]), "%PDF");
    testing.assertFalse(fs.exists(path.join($dir, "_generated")));
}

func testTheScratchDirectoryIsRemoved() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init pluginDeck($dir);
    def pre as Preprocessed init preprocess(readSources([$target]), $dir, $dir, false);
    testing.assertTrue(fs.isFile(path.join($pre.root, "_generated/fake/d.png")));
    testing.assertContains($pre.sources[0].content, "](_generated/fake/d.svg)");
    def deck as slides.Deck init deckFrom($pre.sources);
    def images as map of string to pdf.Image init loadImagesWith($deck, $dir, false, $pre.root);
    testing.assertTrue(maps.has($images, "_generated/fake/d.svg"));
    def inline as map of string to string init embeddedImages($deck, $pre.root);
    testing.assertTrue(strings.startsWith(
        $inline["_generated/fake/d.svg"],
        "data:image/svg+xml;base64,"));
    discard($pre.root);
    testing.assertFalse(fs.exists($pre.root));
    discard("");
    testing.assertEqual(len(embeddedImages($deck, "")), 0);
}

func testAFailingPluginStopsTheBuildAndSaysWhy() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    fs.writeString(
        path.join($dir, "fail.j"),
        strings.join(['use io;', 'io.eprintf("nope\n");', 'exit 1;'], "\n") + "\n");
    fs.writeString(
        path.join($dir, "cantrip.toml"),
        "[preprocessor.broken]\n" + 'command = "jennifer"' + "\n" +
            'args = ["run", ' + json.encode(path.join($dir, "fail.j")) + ']' + "\n");
    def target as string init writeDeck($dir, sample(), "talk.md");
    def message as string init "";
    try {
        dispatch("html", [$target], parsed(["html", $target]));
    } catch (e) {
        testing.assertEqual($e.kind, "plugin");
        $message = $e.message;
    }
    testing.assertContains($message, "preprocessor broken: exited 1: nope");
    testing.assertFalse(fs.exists(path.join($dir, "talk.html")));
    testing.assertEqual(run(["cantrip", "html", $target]), FAILED);
}

func testAMissingPluginIsNamedBothWays() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    fs.writeString(path.join($dir, "cantrip.toml"), "[preprocessor.zzznothere]\n");
    def target as string init writeDeck($dir, sample(), "talk.md");
    def resolved as list of plugin.Resolved init plan($dir);
    testing.assertEqual($resolved[0].origin, plugin.NOWHERE);
    testing.assertEqual(listPlugins($dir), OK);
    def message as string init "";
    try {
        dispatch("info", [$target], parsed(["info", $target]));
    } catch (e) {
        $message = $e.message;
    }
    testing.assertContains(
        $message,
        "nothing named cantrip-zzznothere or grimoire-zzznothere was found");
}

func testAProgramInTheDeckIsFoundByPath() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    fs.mkdirAll(path.join($dir, "tools"));
    fs.writeString(path.join($dir, "tools/draw"), "#!/bin/sh\n");
    def spec as plugin.Plugin init plugin.Plugin{
        name: "draw",
        command: "./tools/draw",
        args: [],
        settings: '{}'
    };
    def r as plugin.Resolved init resolve($spec, $dir);
    testing.assertEqual($r.origin, plugin.IN_DECK);
    testing.assertEqual($r.path, path.join($dir, "tools/draw"));
    testing.assertTrue(onPath("sh") != "");
    testing.assertEqual(onPath("zzz-no-such-program"), "");
}

func testGeneratedIsReservedInTheDeck() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init pluginDeck($dir);
    fs.mkdirAll(path.join($dir, "_generated"));
    def message as string init "";
    try {
        preprocess(readSources([$target]), $dir, $dir, false);
    } catch (e) {
        $message = $e.message;
    }
    testing.assertContains($message, "is reserved");
}

func testWithoutAConfigNothingRuns() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init writeDeck($dir, sample(), "talk.md");
    testing.assertEqual(len(pluginsFor($dir)), 0);
    def pre as Preprocessed init preprocess(readSources([$target]), $dir, $dir, false);
    testing.assertEqual($pre.root, "");
    testing.assertEqual($pre.sources[0].src, "talk.md");
    def w as Written init writeHandoutWith(
        deckFrom($pre.sources),
        parsed(["handout", $target]),
        path.join($dir, "h.pdf"),
        $dir,
        "");
    testing.assertTrue($w.bytes > 0);
}

func testTheRequestDescribesTheDeck() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init pluginDeck($dir);
    def book as plugin.Book init bookOf(readSources([$target]), $dir, $dir);
    testing.assertEqual($book.title, "Plugged");
    testing.assertEqual($book.authors, ["Ada"]);
    testing.assertEqual($book.language, "en");
    testing.assertEqual($book.src, $dir);
    testing.assertEqual(relativeTo("decks/a/talk.md", "decks/a"), "talk.md");
    testing.assertEqual(relativeTo("decks/a/sub/b.md", "decks/a"), "sub/b.md");
    testing.assertEqual(relativeTo("other/c.md", "decks/a"), "other/c.md");
    testing.assertEqual(relativeTo("talk.md", ""), "talk.md");
}

func testTheWritersTakeARoot() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init writeDeck($dir, sample(), "deck.md");
    def deck as slides.Deck init readDeck([$target]);
    def page as Written init writeHtmlWith(
        $deck,
        parsed(["html", $target]),
        path.join($dir, "a.html"),
        "");
    testing.assertTrue($page.bytes > 0);
    def printed as Written init writePdfWith(
        $deck,
        parsed(["pdf", $target]),
        path.join($dir, "a.pdf"),
        $dir,
        "");
    testing.assertEqual($printed.pages, 2);
}

func testNotesBesideTheHandoutSlides() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(slideNotes(readDeck([$target])), ["say this", ""]);
    def out as string init path.join($tmp, "beside.pdf");
    testing.assertEqual(
        dispatch("handout", [$target], parsed(["handout", $target, "--notes-beside", "-o", $out])),
        OK);
    testing.assertTrue(fs.isFile($out));
    def r as args.Result init parsed(["handout", "a.md", "--notes-beside"]);
    testing.assertTrue(args.asBool($r, "notes-beside"));
}

# The PDF draws no SVG: a deck's own SVG picture is drawn from the PNG beside
# it, and one with no PNG falls back to its alt text.
func testAnSvgIsPrintedFromThePngBesideIt() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init writeDeck(
        $dir,
        "# A\n\n![fig](fig.svg)\n\n---\n\n# B\n\n![lone](lone.svg)\n",
        "deck.md");
    fs.writeString(path.join($dir, "fig.svg"), "<svg xmlns=\"http://www.w3.org/2000/svg\"/>");
    fs.writeString(path.join($dir, "lone.svg"), "<svg xmlns=\"http://www.w3.org/2000/svg\"/>");
    fs.writeBytes(path.join($dir, "fig.png"), images.encode("png", images.create(4, 4)));
    def got as map of string to pdf.Image init loadImages(readDeck([$target]), $dir, false);
    testing.assertTrue(maps.has($got, "fig.svg"));
    testing.assertFalse(maps.has($got, "lone.svg"));
}

func testQuietPrintsNothingOnSuccess() {
    def tmp as string init fs.makeTempDir();
    defer fs.removeAll($tmp);
    def target as string init writeDeck($tmp, sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "html", $target, "-q"]), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
    testing.assertEqual(run(["cantrip", "html", $target, "--quiet", "--verbose"]), MISUSE);
    announceFor("x.html", 10, 2, parsed(["html", "a.md", "--quiet"]));
    announceFor("x.html", 10, 2, parsed(["html", "a.md"]));
}

# A favicon beside the deck is carried inside the page; a URL is linked as
# written; anything unusable stops the build.
func testTheFaviconIsEmbedded() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    fs.writeBytes(path.join($dir, "icon.png"), images.encode("png", images.create(4, 4)));
    def target as string init writeDeck($dir, "---\nfavicon: icon.png\n---\n# A\n", "deck.md");
    testing.assertEqual(dispatch("html", [$target], parsed(["html", $target])), OK);
    def page as string init fs.readString(path.join($dir, "deck.html"));
    testing.assertContains($page, '<link rel="icon" href="data:image/png;base64,');
    def deck as slides.Deck init readDeck([$target]);
    def w as Written init writeHtmlIn(
        $deck,
        parsed(["html", $target]),
        path.join($dir, "b.html"),
        "",
        $dir);
    testing.assertTrue($w.bytes > 0);
    testing.assertEqual(
        faviconHref(slides.parse("---\nfavicon: https://e.test/i.png\n---\n# A\n"), $dir),
        "https://e.test/i.png");
    testing.assertEqual(faviconHref(slides.parse("# A\n"), $dir), "");
    fs.writeString(path.join($dir, "f.ico"), "x");
    testing.assertTrue(strings.startsWith(
        faviconHref(slides.parse("---\nfavicon: f.ico\n---\n# A\n"), $dir),
        "data:image/x-icon;base64,"));
}

func badFavicon(value as string, dir as string) {
    try {
        faviconHref(slides.parse("---\nfavicon: " + $value + "\n---\n# A\n"), $dir);
    } catch (e) {
        testing.assertEqual($e.kind, "cli");
        return $e.message;
    }
    testing.assertTrue(false);
    return "";
}

func testAnUnusableFaviconStopsTheBuild() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    testing.assertContains(badFavicon("missing.png", $dir), "not found");
    testing.assertContains(badFavicon("icon.bmp", $dir), "wants a .png");
    testing.assertContains(badFavicon("data:image/png;base64,AA", $dir), "wants a .png");
    testing.assertContains(badFavicon("../outside.png", $dir), "favicon: ../outside.png");
}

# --- serve ---------------------------------------------------------------

func testServeBuildsWhatIsOnDisk() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init writeDeck($dir, sample(), "deck.md");
    def first as string init fingerprint([$target]);
    testing.assertContains($first, "deck.md:");
    fs.writeString(path.join($dir, "pic.png"), "x");
    testing.assertTrue(fingerprint([$target]) != $first);
    def page as string init servedPage([$target], parsed(["serve", $target]));
    testing.assertContains($page, "<title>Fixture</title>");
    testing.assertContains($page, 'fetch("' + RELOAD_PATH + '"');
    fs.writeString($target, "---\ntheme: nosuchtheme\n---\n# A\n");
    def broken as string init servedPage([$target], parsed(["serve", $target]));
    testing.assertContains($broken, "The deck does not build");
    testing.assertContains($broken, "nosuchtheme");
    testing.assertEqual(DEFAULT_ADDR, "127.0.0.1:8080");
    testing.assertTrue(POLL_MS > 0);
}

func testServeRefusesAnAddressItCannotBind() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init writeDeck($dir, sample(), "deck.md");
    def threw as bool init false;
    try {
        serveDeck([$target], parsed(["serve", $target, "--addr", "256.1.1.1:1"]));
    } catch (e) {
        $threw = true;
    }
    testing.assertTrue($threw);
    testing.assertEqual(args.asString(parsed(["serve", "a.md"]), "addr"), DEFAULT_ADDR);
}

func testRenderHtmlInIsWhatHtmlWrites() {
    def dir as string init fs.realpath(fs.makeTempDir());
    defer fs.removeAll($dir);
    def target as string init writeDeck($dir, sample(), "deck.md");
    def deck as slides.Deck init readDeck([$target]);
    def page as string init renderHtmlIn($deck, parsed(["html", $target]), "", $dir);
    writeHtmlIn($deck, parsed(["html", $target]), path.join($dir, "w.html"), "", $dir);
    testing.assertEqual(fs.readString(path.join($dir, "w.html")), $page);
}
