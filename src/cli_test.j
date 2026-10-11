# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

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
use binary;
use encoding;

/** A small deck, written to a temporary file by `writeDeck`. */
func sample() {
    return "---\ntitle: Fixture\nauthor: Ada\ntheme: solar\nratio: 16:9\n---\n" +
        "# One\n\nText.\n\n<!-- notes: say this -->\n\n---\n\n## Two\n\n- a\n";
}

/**
 * Write a deck into a fresh temporary directory.
 * @param body {string} the Markdown to write
 * @param name {string} the file's base name, extension included
 * @return {string} the path written
 */
func writeDeck(body as string, name as string) {
    def dir as string init fs.makeTempDir();
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
    testing.assertContains(commands(), "info");
    testing.assertContains(commands(), "themes");
    testing.assertEqual(len(commands()), 5);
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
    def target as string init writeDeck(sample(), "deck.md");
    def deck as slides.Deck init readDeck([$target]);
    testing.assertEqual($deck.title, "Fixture");
    testing.assertEqual($deck.theme, "solar");
    testing.assertEqual(len($deck.slides), 2);
}

/** Several files become one deck, numbered straight through. */
func testReadDeckSeveralFiles() {
    def dir as string init fs.makeTempDir();
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
    testing.assertEqual(readFailure(["/nonexistent/nope.md"]), "cli");
    testing.assertEqual(readFailure([fs.makeTempDir()]), "cli");
    testing.assertEqual(readFailure([writeDeck(sample(), "ok.md")]), "");
}

/** Reading no files gives an empty deck rather than an error. */
func testReadDeckNoFiles() {
    testing.assertEqual(len(readDeck([]).slides), 0);
}

/** An image is found as written, or beside the deck. */
func testLocate() {
    def dir as string init fs.makeTempDir();
    def pic as string init path.join($dir, "fig.png");
    fs.writeBytes($pic, onePixelPng());
    testing.assertEqual(locate($pic, ""), $pic);
    testing.assertEqual(locate("fig.png", $dir), $pic);
    testing.assertEqual(locate("missing.png", $dir), "");
    testing.assertEqual(locate("fig.png", ""), "");
    testing.assertEqual(locate("fig.png", "."), "");
}

/** A directory is not a usable image. */
func testLocateIgnoresDirectories() {
    def dir as string init fs.makeTempDir();
    testing.assertEqual(locate($dir, ""), "");
}

/** A picture beside the deck is loaded and keyed by its source URL. */
func testLoadImages() {
    def dir as string init fs.makeTempDir();
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
    def target as string init path.join($dir, "deck.md");
    fs.writeString($target, "# H\n\n![a](https://example.com/a.png)\n\n![b](missing.png)\n");
    def got as map of string to pdf.Image init loadImages(readDeck([$target]), $dir, false);
    testing.assertEqual(len(maps.keys($got)), 0);
}

/** A deck with no pictures loads none. */
func testLoadImagesNone() {
    def target as string init writeDeck(sample(), "deck.md");
    def got as map of string to pdf.Image init loadImages(readDeck([$target]), ".", false);
    testing.assertEqual(len(maps.keys($got)), 0);
}

/** The HTML options follow the flags, including the negative ones. */
func testHtmlOptions() {
    def plain as htmlout.Options init htmlOptions(parsed(["html", "a.md"]));
    testing.assertTrue($plain.notes);
    testing.assertTrue($plain.numbers);
    testing.assertFalse($plain.rawHtml);
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
}

/** The PDF options follow the flags, and notes are opt-in. */
func testPdfOptions() {
    def plain as pdfout.Options init pdfOptions(parsed(["pdf", "a.md"]));
    testing.assertFalse($plain.notes);
    testing.assertTrue($plain.numbers);
    testing.assertEqual($plain.bookmarks, 2);
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
    requireSlides(readDeck([writeDeck(sample(), "deck.md")]));
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
    def target as string init path.join($dir, "out.html");
    def deck as slides.Deck init readDeck([writeDeck(sample(), "deck.md")]);
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
    def target as string init path.join($dir, "out.pdf");
    def deck as slides.Deck init readDeck([writeDeck(sample(), "deck.md")]);
    def w as Written init writePdf($deck, parsed(["pdf", "a.md"]), $target, $dir);
    testing.assertTrue($w.bytes > 500);
    testing.assertEqual($w.pages, 2);
    def got as bytes init fs.readBytes($target);
    testing.assertEqual(len($got), $w.bytes);
    testing.assertEqual(convert.stringFromBytes(binary.slice($got, 0, 5), "utf-8"), "%PDF-");
}

/**
 * The page count includes the pictures: a slide pushed over its page by a
 * tall image is counted from the written file, not from a text-only layout.
 */
func testWritePdfCountsPicturePages() {
    def dir as string init fs.makeTempDir();
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
    def target as string init writeDeck(sample(), "deck.md");
    def kind as string init "";
    try {
        guardInputs(path.join(path.dir($target), ".", "deck.md"), [$target]);
    } catch (e) {
        $kind = $e.kind;
    }
    testing.assertEqual($kind, "cli");
    guardInputs(path.join(path.dir($target), "deck.html"), [$target]);
    guardInputs(writeDeck("x", "other.md"), [$target]);
}

/** `-o` naming the input is refused, and the input survives. */
func testRunRefusesToOverwriteInput() {
    def target as string init writeDeck(sample(), "deck.md");
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
    testing.assertEqual(report(readDeck([writeDeck(sample(), "deck.md")])), OK);
    testing.assertEqual(report(slides.parse("")), OK);
}

/** Listing the themes never fails. */
func testListThemes() {
    testing.assertEqual(listThemes(), OK);
}

/** The overflow warning is advisory and never changes the outcome. */
func testWarnOverflow() {
    def deck as slides.Deck init readDeck([writeDeck(sample(), "deck.md")]);
    warnOverflow($deck, 2);
    warnOverflow($deck, 5);
}

/** Announcing a write never fails, quiet or verbose. */
func testAnnounce() {
    announce("x.html", 10, 2, false);
    announce("x.html", 10, 2, true);
}

/** `info` reads the deck and writes nothing. */
func testDispatchInfo() {
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(dispatch("info", [$target], parsed(["info", $target])), OK);
    testing.assertFalse(fs.exists(stem($target) + ".html"));
}

/** `html` writes the slideshow beside its input. */
func testDispatchHtml() {
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(dispatch("html", [$target], parsed(["html", $target])), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
    testing.assertFalse(fs.exists(stem($target) + ".pdf"));
}

/** `pdf` writes the PDF beside its input. */
func testDispatchPdf() {
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(dispatch("pdf", [$target], parsed(["pdf", $target])), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".pdf"));
    testing.assertFalse(fs.exists(stem($target) + ".html"));
}

/** `build` writes both, sharing one stem. */
func testDispatchBuild() {
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(dispatch("build", [$target], parsed(["build", $target])), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
    testing.assertTrue(fs.isFile(stem($target) + ".pdf"));
}

/** For `build`, `--out` is the stem both outputs hang off. */
func testDispatchBuildHonoursOut() {
    def target as string init writeDeck(sample(), "deck.md");
    def base as string init path.join(fs.makeTempDir(), "named");
    def r as args.Result init parsed(["build", $target, "-o", $base]);
    testing.assertEqual(dispatch("build", [$target], $r), OK);
    testing.assertTrue(fs.isFile($base + ".html"));
    testing.assertTrue(fs.isFile($base + ".pdf"));
}

/** For `html` and `pdf`, `--out` is the exact file. */
func testDispatchHonoursOut() {
    def target as string init writeDeck(sample(), "deck.md");
    def named as string init path.join(fs.makeTempDir(), "exact.htm");
    def r as args.Result init parsed(["html", $target, "-o", $named]);
    testing.assertEqual(dispatch("html", [$target], $r), OK);
    testing.assertTrue(fs.isFile($named));
}

/** An unknown theme reaches the caller as a theme error. */
func testDispatchPropagatesThemeError() {
    def target as string init writeDeck(sample(), "deck.md");
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
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "html", $target, "--transition", "spin"]), FAILED);
}

/** An unknown theme is a failure, with a message rather than a stack. */
func testRunBadTheme() {
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "html", $target, "--theme", "nope"]), FAILED);
}

/** A deck with no slides is a failure, and writes nothing. */
func testRunEmptyDeck() {
    def target as string init writeDeck("---\ntitle: T\n---\n", "empty.md");
    testing.assertEqual(run(["cantrip", "html", $target]), FAILED);
    testing.assertFalse(fs.exists(stem($target) + ".html"));
}

/** A whole run writes both outputs and reports success. */
func testRunBuild() {
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "build", $target, "-v"]), OK);
    testing.assertTrue(fs.isFile(stem($target) + ".html"));
    testing.assertTrue(fs.isFile(stem($target) + ".pdf"));
}

/** `info` through the whole run reports success. */
func testRunInfo() {
    def target as string init writeDeck(sample(), "deck.md");
    testing.assertEqual(run(["cantrip", "info", $target]), OK);
}

/**
 * A tall PNG, 60x900 pixels, for the tests that need a picture to overflow.
 * @return {bytes} a greyscale PNG
 */
func tallPng() {
    return encoding.fromText(
        "iVBORw0KGgoAAAANSUhEUgAAADwAAAOECAAAAADY5g0rAAAAAmJLR0QA/4ePzL8AAAAH" +
            "dElNRQfqChQQARoWnyFmAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDI2LTEwLTIwVDE2OjAx" +
            "OjI2KzAwOjAwPOvwIQAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyNi0xMC0yMFQxNjowMToy" +
            "NiswMDowME22SJ0AAAAodEVYdGRhdGU6dGltZXN0YW1wADIwMjYtMTAtMjBUMTY6MDE6" +
            "MjYrMDA6MDAao2lCAAAAvUlEQVR42u3LsQ0AAAQAMDzudT8QW7s3O/bqcGVZlmVZlmVZ" +
            "lmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZ" +
            "lmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZ" +
            "lmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlmVZlh/y" +
            "AFvEB4eZ6hNNAAAAAElFTkSuQmCC",
        "base64");
}

/**
 * The smallest valid PNG, for the tests that need real image bytes.
 * @return {bytes} a 1x1 greyscale PNG
 */
func onePixelPng() {
    return encoding.fromText(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGMAAQAABQAB" +
            "lpSm1gAAAABJRU5ErkJggg==",
        "base64");
}
