# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * White-box tests for `plugin.j`, run by `jennifer test src/plugin_test.j`.
 *
 * The request is checked field by field against Grimoire's contract, because
 * a Grimoire plugin reading it is the point of the module.
 * @module plugin_test
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */
use testing;
use json;
use toml;
use strings;

# --- configuration -----------------------------------------------------

func testTablesAreReadInOrderWithDefaults() {
    def text as string init '[preprocessor.mermaid]' + "\n" + 'theme = "dark"' + "\n" +
        'scale = 1.5' + "\n\n" + '[preprocessor.katex]' + "\n" +
        'command = "./tools/katex"' + "\n" + 'args = ["--strict"]' + "\n";
    def got as list of Plugin init parseConfig($text, "cantrip.toml");
    testing.assertEqual(len($got), 2);
    testing.assertEqual($got[0].name, "mermaid");
    testing.assertEqual($got[0].command, "cantrip-mermaid");
    testing.assertEqual(len($got[0].args), 0);
    def s as json.Value init json.decode($got[0].settings);
    testing.assertEqual(json.asString($s, "/theme"), "dark");
    testing.assertEqual(json.asFloat($s, "/scale"), 1.5);
    testing.assertEqual($got[1].command, "./tools/katex");
    testing.assertEqual($got[1].args, ["--strict"]);
}

func testAnEmptyFileNamesNothing() {
    testing.assertEqual(len(parseConfig("", "cantrip.toml")), 0);
    testing.assertEqual(len(parseConfig("[preprocessor]\n", "cantrip.toml")), 0);
}

func badConfig(text as string) {
    try {
        parseConfig($text, "cantrip.toml");
    } catch (e) {
        testing.assertEqual($e.kind, "plugin");
        testing.assertContains($e.message, "cantrip.toml");
        return $e.message;
    }
    testing.assertTrue(false);
    return "";
}

func testARendererIsRefusedNotIgnored() {
    testing.assertContains(badConfig("[renderer.sitemap]\n"), "preprocessors only");
}

func testAnythingElseIsRefused() {
    testing.assertContains(badConfig('theme = "ivy"' + "\n"), "unknown key");
    testing.assertContains(badConfig("preprocessor = 1\n"), "table");
    testing.assertContains(badConfig("[preprocessor]\nmermaid = 1\n"), "must be a table");
    testing.assertContains(badConfig('[preprocessor.x]' + "\n" + 'command = ""' + "\n"), "command");
    testing.assertContains(badConfig('[preprocessor.x]' + "\n" + 'command = 3' + "\n"), "command");
    testing.assertContains(badConfig('[preprocessor.x]' + "\n" + 'args = "a"' + "\n"), "args");
    testing.assertContains(badConfig('[preprocessor.x]' + "\n" + 'args = [1]' + "\n"), "args");
    testing.assertContains(badConfig('[preprocessor."a/b"]' + "\n"), "directory name");
    testing.assertContains(badConfig("[preprocessor\n"), "cantrip.toml");
}

func testNamesAndPointers() {
    testing.assertTrue(usableName("mermaid"));
    testing.assertFalse(usableName(""));
    testing.assertFalse(usableName(".."));
    testing.assertFalse(usableName("a/b"));
    testing.assertFalse(usableName("a\\b"));
    testing.assertEqual(pointerKey("a/b~c"), "a~1b~0c");
}

func testJsonOfCarriesEveryTomlType() {
    def doc as toml.Value init toml.decode('a = [1, true, "x"]' + "\n" + 'b = 2.5' + "\n" +
        'c = 1979-05-27T07:32:00Z' + "\n" + '[t]' + "\n" + 'k = false' + "\n");
    def back as json.Value init json.decode(jsonOf($doc, ""));
    testing.assertEqual(json.asInt($back, "/a/0"), 1);
    testing.assertTrue(json.asBool($back, "/a/1"));
    testing.assertEqual(json.asString($back, "/a/2"), "x");
    testing.assertEqual(json.asFloat($back, "/b"), 2.5);
    testing.assertContains(json.asString($back, "/c"), "1979-05-27");
    testing.assertFalse(json.asBool($back, "/t/k"));
}

# --- lookup ------------------------------------------------------------

func testADefaultCommandFallsBackToGrimoire() {
    def spec as Plugin init Plugin{
        name: "mermaid",
        command: "cantrip-mermaid",
        args: [],
        settings: '{}'
    };
    testing.assertEqual(candidates($spec), ["cantrip-mermaid", "grimoire-mermaid"]);
    $spec.command = "grimoire-mermaid";
    testing.assertEqual(candidates($spec), ["grimoire-mermaid"]);
    $spec.command = "./tools/draw";
    testing.assertEqual(candidates($spec), ["./tools/draw"]);
}

# --- the request and the reply ----------------------------------------

func deckBook() {
    return Book{
        title: "A Talk",
        authors: ["Ada"],
        language: "en",
        src: "/decks/talk",
        out: "/decks/talk"
    };
}

func spec() {
    return Plugin{
        name: "mermaid",
        command: "cantrip-mermaid",
        args: [],
        settings: '{"theme":"dark"}'
    };
}

func chapters() {
    return [
        Chapter{src: "talk.md", content: "---\ntheme: ivy\n---\n\n# Hello\n\ntext"},
        Chapter{src: "more.md", content: "## More\n\nx"}
    ];
}

func testTheRequestIsGrimoiresShape() {
    def req as json.Value init json.decode(request(
        deckBook(),
        spec(),
        chapters(),
        "/tmp/s/_generated/mermaid",
        "/tmp/s/_generated"));
    testing.assertEqual(json.asInt($req, "/api"), 1);
    testing.assertEqual(json.asString($req, "/kind"), "preprocessor");
    testing.assertEqual(json.asString($req, "/features/0"), "files");
    testing.assertEqual(json.asString($req, "/features/1"), "mathml");
    testing.assertEqual(json.asString($req, "/book/title"), "A Talk");
    testing.assertEqual(json.asString($req, "/book/description"), "");
    testing.assertEqual(json.asString($req, "/book/authors/0"), "Ada");
    testing.assertEqual(json.asString($req, "/book/language"), "en");
    testing.assertEqual(json.asString($req, "/book/src"), "/decks/talk");
    testing.assertEqual(json.asString($req, "/book/out"), "/decks/talk");
    testing.assertEqual(json.asString($req, "/book/generated"), "/tmp/s/_generated");
    testing.assertEqual(json.asString($req, "/plugin/name"), "mermaid");
    testing.assertEqual(json.asString($req, "/plugin/settings/theme"), "dark");
    testing.assertEqual(json.asString($req, "/plugin/files"), "/tmp/s/_generated/mermaid");
    testing.assertEqual(json.length($req, "/entries"), 2);
    testing.assertEqual(json.asString($req, "/entries/0/kind"), "page");
    testing.assertEqual(json.asString($req, "/entries/0/title"), "Hello");
    testing.assertEqual(json.asString($req, "/entries/1/title"), "More");
    testing.assertEqual(json.asString($req, "/entries/1/number"), "2");
    testing.assertEqual(json.asInt($req, "/entries/1/level"), 0);
    testing.assertEqual(json.asString($req, "/chapters/1/src"), "more.md");
    testing.assertContains(json.asString($req, "/chapters/0/content"), "theme: ivy");
    testing.assertEqual(API, 1);
    testing.assertEqual(features(), ["files", "mathml"]);
}

func testAReplyIsMergedSparsely() {
    def got as list of Chapter init merge(
        spec(),
        chapters(),
        '{"api":1,"chapters":[{"src":"more.md","content":"## New"}]}');
    testing.assertContains($got[0].content, "# Hello");
    testing.assertEqual($got[1].content, "## New");
    testing.assertEqual(merge(spec(), chapters(), '{"api":1}')[1].content, "## More\n\nx");
}

func badReply(reply as string) {
    try {
        merge(spec(), chapters(), $reply);
    } catch (e) {
        testing.assertEqual($e.kind, "plugin");
        testing.assertContains($e.message, "preprocessor mermaid: ");
        return $e.message;
    }
    testing.assertTrue(false);
    return "";
}

func testABadReplyIsRefused() {
    testing.assertContains(badReply("not json"), "not JSON");
    testing.assertContains(badReply("[1]"), "`api`");
    testing.assertContains(badReply('{"api":2}'), "api 1");
    testing.assertContains(
        badReply('{"api":1,"chapters":[{"src":"new.md","content":""}]}'),
        "does not have: new.md");
}

# --- reporting ---------------------------------------------------------

func testThePlanIsListedWithItsOrigin() {
    def plan as list of Resolved init [
        Resolved{
            name: "mermaid",
            command: "cantrip-mermaid",
            args: [],
            path: "/usr/bin/grimoire-mermaid",
            origin: ON_PATH
        },
        Resolved{
            name: "k",
            command: "./tools/k",
            args: ["-v"],
            path: "/d/tools/k",
            origin: IN_DECK
        }
    ];
    def lines as list of string init listing($plan);
    testing.assertEqual(
        $lines[0],
        "preprocessor  mermaid  ->  /usr/bin/grimoire-mermaid  (found on PATH)");
    testing.assertContains($lines[1], "->  /d/tools/k  (in this deck)");
    testing.assertContains($lines[1], "args: -v");
}

func testOnlyWhatCannotBeReviewedIsAConcern() {
    def plan as list of Resolved init [
        Resolved{name: "a", command: "./a", args: [], path: "/d/a", origin: IN_DECK},
        Resolved{
            name: "b",
            command: "cantrip-b",
            args: [],
            path: "/usr/bin/cantrip-b",
            origin: ON_PATH
        },
        Resolved{name: "c", command: "/opt/c", args: [], path: "/opt/c", origin: OUTSIDE},
        Resolved{name: "d", command: "cantrip-d", args: [], path: "", origin: NOWHERE}
    ];
    def got as list of string init concerns($plan);
    testing.assertEqual(len($got), 3);
    testing.assertContains($got[0], "found on PATH");
    testing.assertContains($got[1], "outside this deck");
    testing.assertContains($got[2], "cantrip-d or grimoire-d was found");
}

# --- generated files ---------------------------------------------------

func testGeneratedPathsAreRecognised() {
    testing.assertEqual(generatedPath("_generated/mermaid/a1.svg"), "mermaid/a1.svg");
    testing.assertEqual(generatedPath("img/a.png"), "");
    testing.assertEqual(generatedPath("_generated/../secret.png"), "");
    testing.assertEqual(generatedPath("_generated/m//a.png"), "");
    testing.assertEqual(GENERATED, "_generated");
    testing.assertEqual(CONFIG_FILE, "cantrip.toml");
    testing.assertTrue(strings.contains(OUTSIDE, "outside"));
}

func testMediaTypesAndThePrintedPicture() {
    testing.assertEqual(mediaType("a.SVG"), "image/svg+xml");
    testing.assertEqual(mediaType("a.png"), "image/png");
    testing.assertEqual(mediaType("a.jpeg"), "image/jpeg");
    testing.assertEqual(mediaType("a.gif"), "image/gif");
    testing.assertEqual(mediaType("a.pdf"), "");
    testing.assertEqual(printable("mermaid/a.svg"), "mermaid/a.png");
    testing.assertEqual(printable("mermaid/a.png"), "mermaid/a.png");
}

func testTheOriginWords() {
    testing.assertEqual(ON_PATH, "found on PATH");
    testing.assertEqual(IN_DECK, "in this deck");
    testing.assertEqual(NOWHERE, "not found");
}
