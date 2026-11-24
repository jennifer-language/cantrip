# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * White-box tests for the code highlighter.
 *
 * The Jennifer cases are Grimoire's (`apps/grimoire/src/highlight_test.j`),
 * each a rule a simpler lexer gets wrong; the other languages get one test
 * each for the shapes their table switches on. Every language is also held to
 * the two promises the renderers rely on: the tokens give the source back
 * unchanged, and the HTML never lets source text become markup.
 * @module highlightTest
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use testing;
use maps;
use regex;

/**
 * The class of the first token whose text is exactly `text`.
 * @param code {string} the source to lex
 * @param tag {string} the language tag
 * @param text {string} the token text to find
 * @return {string} its class, "" when plain, "missing" when no token has that text
 */
func classOf(code as string, tag as string, text as string) {
    for (def t in tokens($code, $tag)) {
        if ($t.text == $text) {
            return $t.cls;
        }
    }
    return "missing";
}

/**
 * The tokens' texts joined back together.
 * @param code {string} the source to lex
 * @param tag {string} the language tag
 * @return {string} what the tokens spell
 */
func rejoined(code as string, tag as string) {
    def parts as list of string init [];
    for (def t in tokens($code, $tag)) {
        $parts[] = $t.text;
    }
    return strings.join($parts, "");
}

/**
 * Read a `highlight:` value and report how it failed.
 * @param value {string} the front-matter value
 * @return {string} the Error kind it threw, "" when it did not throw
 */
func enabledFailure(value as string) {
    try {
        enabled($value);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

/**
 * A sample written as a raw string: `\n` stands for a line break and `~` for
 * a single quote, which a raw string cannot hold.
 * @param raw {string} the sample as written
 * @return {string} the source it stands for
 */
func src(raw as string) {
    return strings.replace(strings.replace($raw, '\n', "\n"), "~", "'");
}

/**
 * One sample per language, each touching most of its rules.
 * @return {map of string to string} source by language tag
 */
func samples() {
    return {
        "jennifer": src('use io;\n# hi\ndef x as int init 0x1f;\n' +
            'io.printf("a\n", $x, ~r~);\n/* a /* b */ c */'),
        "php": src('<?php\n$x = strlen(~a~); // c\n# d\n' +
            'function f(int $a) { return null; } /* e */'),
        "sh": src('for f in *.md; do echo "$f" ${HOME} $1 ~raw~; done # c\napt-get install x'),
        "console": src('$ cantrip build talk.md\nwrote talk.html (3 slide(s))'),
        "go": src('package main\n// c\nfunc main() { fmt.Println(`raw`, nil, 1.5) }'),
        "python": src('@dec\ndef f(x):\n    return """doc""" + ~a~ # c'),
        "ts": src('const x: number = 1; // c\nfunction f() { return `t`; } /* d */'),
        "json": src('{"name": "x", "n": -1.5e3, "ok": true, "no": null}'),
        "toml": src('[package]\nname = "x" # c\nversion = 1\n[[bin]]\nraw = ~a~'),
        "yaml": src('jobs:\n  - name: test\n    runs-on: ubuntu # c\n    on: true'),
        "sql": src('SELECT a, COUNT(*) FROM t WHERE x = ~y~ AND n > 1 -- c\n/* d */'),
        "html": src('<!doctype html>\n<p class="x" id=~y~>a &amp; b</p><!-- c -->'),
        "dockerfile": src('FROM alpine AS b\nRUN echo $X ${Y} "q"\n# c'),
        "c": src('#include <stdio.h>\nint main(void) { printf("%d", MAX); return 0; } // c')
    };
}

# --- the table -------------------------------------------------------

/** Every tag the docs promise selects a language, any case and spacing. */
func testLanguageTags() {
    def tags as list of string init [
        "jennifer",
        "j",
        "php",
        "sh",
        "bash",
        "shell",
        "console",
        "go",
        "python",
        "py",
        "js",
        "javascript",
        "ts",
        "typescript",
        "json",
        "toml",
        "yaml",
        "yml",
        "sql",
        "html",
        "xml",
        "dockerfile",
        "c"
    ];
    for (def tag in $tags) {
        testing.assertTrue(handles($tag));
    }
    testing.assertTrue(handles("  JENNIFER "));
    testing.assertEqual(language("Bash").name, "sh");
    testing.assertEqual(language("ts").name, "javascript");
}

/** No language, or one not in the table, is not highlighted. */
func testUnknownLanguage() {
    testing.assertFalse(handles(""));
    testing.assertFalse(handles("rust"));
    testing.assertFalse(handles("text"));
    testing.assertEqual(language("cobol").name, "");
    def got as list of Token init tokens('fn main() {}', "rust");
    testing.assertEqual(len($got), 1);
    testing.assertEqual($got[0].cls, "");
    testing.assertEqual(len(tokens("", "rust")), 0);
    testing.assertEqual(toHtml("a < b & c", "text"), "a &lt; b &amp; c");
}

/** No tag selects two languages, and every language names itself. */
func testAliasesAreUnique() {
    def seen as list of string init [];
    for (def l in languages()) {
        testing.assertTrue($l.name != "");
        testing.assertTrue(len($l.aliases) > 0);
        for (def a in $l.aliases) {
            testing.assertFalse(lists.contains($seen, $a));
            testing.assertEqual(strings.lower($a), $a);
            $seen[] = $a;
        }
        if ($l.ignoreCase) {
            for (def w in $l.keywords) {
                testing.assertEqual(strings.lower($w), $w);
            }
        }
    }
}

/** The tokens of every sample give the source back, character for character. */
func testTokensRoundTrip() {
    def all as map of string to string init samples();
    for (def tag in maps.keys($all)) {
        testing.assertEqual(rejoined($all[$tag], $tag), $all[$tag]);
        def prev as string init "x";
        for (def t in tokens($all[$tag], $tag)) {
            testing.assertTrue($t.text != "");
            # Plain text comes as one run, never two in a row.
            testing.assertFalse($prev == "" and $t.cls == "");
            $prev = $t.cls;
        }
    }
}

# --- Jennifer, as Grimoire highlights it --------------------------------

func testJenniferWords() {
    def code as string init 'def x as int init 1; return true; MAX_N; io.printf(); len($l); f();';
    testing.assertEqual(classOf($code, "j", "def"), "keyword");
    testing.assertEqual(classOf($code, "j", "int"), "type");
    testing.assertEqual(classOf($code, "j", "true"), "literal");
    testing.assertEqual(classOf($code, "j", "len"), "built_in");
    testing.assertEqual(classOf($code, "j", "io"), "built_in");
    testing.assertEqual(classOf($code, "j", "MAX_N"), "symbol");
    testing.assertEqual(classOf($code, "j", "printf"), "title");
    testing.assertEqual(classOf($code, "j", "$l"), "variable");
    testing.assertEqual(classOf("return (1);", "j", "return"), "keyword");
    testing.assertEqual(classOf("Mixed;", "j", "Mixed"), "missing");
}

func testJenniferComments() {
    testing.assertEqual(classOf("# a note", "j", "# a note"), "comment");
    testing.assertEqual(classOf("/* a /* b */ c */ d", "j", "/* a /* b */ c */"), "comment");
}

func testJenniferStrings() {
    testing.assertEqual(classOf("x = \"a\\\"b\";", "j", "\"a\\\"b\""), "string");
    # A raw string has no escapes: the backslash does not swallow the quote.
    testing.assertEqual(classOf("x = 'a\\'", "j", "'a\\'"), "string");
}

func testJenniferNumbers() {
    testing.assertEqual(classOf("0xff;", "j", "0xff"), "number");
    testing.assertEqual(classOf("1e-9;", "j", "1e-9"), "number");
    testing.assertEqual(classOf("3.14;", "j", "3.14"), "number");
    testing.assertEqual(classOf("1.max", "j", "1"), "number");
}

func testJenniferPrompt() {
    testing.assertEqual(classOf(">>> 1 + 1", "j", ">>> "), "meta");
    testing.assertEqual(classOf(">>> a\n... b", "j", "... "), "meta");
    testing.assertEqual(classOf("a >>> b", "j", ">>> "), "missing");
}

/** A keyword at the end of a longer word is part of that word. */
func testKeywordSuffixStaysInItsWord() {
    testing.assertEqual(toHtml("plain", "j"), "plain");
    testing.assertEqual(toHtml("domain", "j"), "domain");
    testing.assertContains(toHtml("plain in domain", "j"), '<span class="hljs-keyword">in</span>');
}

/** Source that ends inside a token still highlights, without throwing. */
func testUnterminatedInput() {
    for (def tag in ["j", "php", "sh", "python", "html", "sql", "c", "toml"]) {
        for (def code in [
            '"a\\',
            "/* open",
            "'open",
            '"open',
            "$",
            ">>>",
            "<",
            "<!-- x",
            "[x",
            "&a"
        ]) {
            testing.assertEqual(rejoined($code, $tag), $code);
        }
    }
}

# --- the other languages ---------------------------------------------

func testPhp() {
    def code as string init samples()["php"];
    testing.assertEqual(classOf($code, "php", "<?php"), "meta");
    testing.assertEqual(classOf($code, "php", "$x"), "variable");
    testing.assertEqual(classOf($code, "php", "strlen"), "built_in");
    testing.assertEqual(classOf($code, "php", "'a'"), "string");
    testing.assertEqual(classOf($code, "php", "// c"), "comment");
    testing.assertEqual(classOf($code, "php", "# d"), "comment");
    testing.assertEqual(classOf($code, "php", "/* e */"), "comment");
    testing.assertEqual(classOf($code, "php", "function"), "keyword");
    testing.assertEqual(classOf($code, "php", "f"), "title");
    testing.assertEqual(classOf($code, "php", "int"), "type");
    testing.assertEqual(classOf($code, "php", "null"), "literal");
    testing.assertEqual(classOf('FUNCTION f() {}', "php", "FUNCTION"), "keyword");
}

func testShell() {
    def code as string init samples()["sh"];
    testing.assertEqual(classOf($code, "sh", "for"), "keyword");
    testing.assertEqual(classOf($code, "sh", "echo"), "built_in");
    testing.assertEqual(classOf($code, "sh", "\"$f\""), "string");
    testing.assertEqual(classOf($code, "sh", '${HOME}'), "variable");
    testing.assertEqual(classOf($code, "sh", "$1"), "variable");
    testing.assertEqual(classOf($code, "sh", "'raw'"), "string");
    testing.assertEqual(classOf($code, "sh", "# c"), "comment");
    # A word with a dash is one word, so `install` in `apt-get` is not split.
    testing.assertEqual(classOf("a#b", "sh", "#b"), "missing");
    testing.assertEqual(classOf("echo $?", "bash", "$?"), "variable");
}

func testConsole() {
    def code as string init samples()["console"];
    testing.assertEqual(classOf($code, "console", "$ "), "meta");
    testing.assertEqual(classOf($code, "console", "3"), "missing");
}

func testGo() {
    def code as string init samples()["go"];
    testing.assertEqual(classOf($code, "go", "package"), "keyword");
    testing.assertEqual(classOf($code, "go", "// c"), "comment");
    testing.assertEqual(classOf($code, "go", "Println"), "title");
    testing.assertEqual(classOf($code, "go", "`raw`"), "string");
    testing.assertEqual(classOf($code, "go", "nil"), "literal");
    testing.assertEqual(classOf($code, "go", "1.5"), "number");
    # Only Jennifer reads a word before `.` as a library prefix.
    testing.assertEqual(classOf($code, "go", "fmt"), "missing");
}

func testPython() {
    def code as string init samples()["python"];
    testing.assertEqual(classOf($code, "python", "@dec"), "meta");
    testing.assertEqual(classOf($code, "python", "def"), "keyword");
    testing.assertEqual(classOf($code, "python", "f"), "title");
    testing.assertEqual(classOf($code, "python", "\"\"\"doc\"\"\""), "string");
    testing.assertEqual(classOf($code, "python", "# c"), "comment");
}

func testJavaScript() {
    def code as string init samples()["ts"];
    testing.assertEqual(classOf($code, "ts", "const"), "keyword");
    testing.assertEqual(classOf($code, "ts", "number"), "type");
    testing.assertEqual(classOf($code, "ts", "`t`"), "string");
    testing.assertEqual(classOf($code, "javascript", "/* d */"), "comment");
}

func testJson() {
    def code as string init samples()["json"];
    testing.assertEqual(classOf($code, "json", "\"name\""), "attr");
    testing.assertEqual(classOf($code, "json", "\"x\""), "string");
    testing.assertEqual(classOf($code, "json", "1.5e3"), "number");
    testing.assertEqual(classOf($code, "json", "true"), "literal");
    testing.assertEqual(classOf($code, "json", "null"), "literal");
}

func testToml() {
    def code as string init samples()["toml"];
    testing.assertEqual(classOf($code, "toml", "[package]"), "section");
    testing.assertEqual(classOf($code, "toml", "[[bin]]"), "section");
    testing.assertEqual(classOf($code, "toml", "name"), "attr");
    testing.assertEqual(classOf($code, "toml", "\"x\""), "string");
    testing.assertEqual(classOf($code, "toml", "'a'"), "string");
    testing.assertEqual(classOf($code, "toml", "# c"), "comment");
    testing.assertEqual(classOf("a = [1]", "toml", "[1]"), "missing");
}

func testYaml() {
    def code as string init samples()["yaml"];
    testing.assertEqual(classOf($code, "yaml", "jobs"), "attr");
    testing.assertEqual(classOf($code, "yaml", "name"), "attr");
    testing.assertEqual(classOf($code, "yaml", "runs-on"), "attr");
    testing.assertEqual(classOf($code, "yaml", "on"), "attr");
    testing.assertEqual(classOf($code, "yaml", "true"), "literal");
    testing.assertEqual(classOf($code, "yaml", "# c"), "comment");
    # A colon later in a value is not a key.
    testing.assertEqual(classOf("image: node:20", "yaml", "node"), "missing");
}

func testSql() {
    def code as string init samples()["sql"];
    testing.assertEqual(classOf($code, "sql", "SELECT"), "keyword");
    testing.assertEqual(classOf($code, "sql", "COUNT"), "built_in");
    testing.assertEqual(classOf($code, "sql", "'y'"), "string");
    testing.assertEqual(classOf($code, "sql", "-- c"), "comment");
    testing.assertEqual(classOf($code, "sql", "/* d */"), "comment");
    testing.assertEqual(classOf("select 1", "sql", "select"), "keyword");
}

func testMarkup() {
    def code as string init samples()["html"];
    testing.assertEqual(classOf($code, "html", "<!doctype html>"), "meta");
    testing.assertEqual(classOf($code, "html", "p"), "name");
    testing.assertEqual(classOf($code, "html", "class"), "attr");
    testing.assertEqual(classOf($code, "html", "\"x\""), "string");
    testing.assertEqual(classOf($code, "html", "'y'"), "string");
    testing.assertEqual(classOf($code, "html", "&amp;"), "symbol");
    testing.assertEqual(classOf($code, "html", "<!-- c -->"), "comment");
    # Text between tags is plain, words that look like attributes included.
    testing.assertEqual(classOf("<b>class</b>", "xml", "class"), "missing");
}

func testDockerfile() {
    def code as string init samples()["dockerfile"];
    testing.assertEqual(classOf($code, "dockerfile", "FROM"), "keyword");
    testing.assertEqual(classOf($code, "dockerfile", "RUN"), "keyword");
    # An instruction counts only as the first word of its line.
    testing.assertEqual(classOf("RUN echo from", "dockerfile", "from"), "missing");
    testing.assertEqual(classOf($code, "dockerfile", "$X"), "variable");
    testing.assertEqual(classOf($code, "dockerfile", '${Y}'), "variable");
    testing.assertEqual(classOf($code, "dockerfile", "# c"), "comment");
}

func testC() {
    def code as string init samples()["c"];
    testing.assertEqual(classOf($code, "c", "#include <stdio.h>"), "meta");
    testing.assertEqual(classOf($code, "c", "int"), "type");
    testing.assertEqual(classOf($code, "c", "main"), "title");
    testing.assertEqual(classOf($code, "c", "printf"), "built_in");
    testing.assertEqual(classOf($code, "c", "MAX"), "symbol");
    testing.assertEqual(classOf($code, "c", "return"), "keyword");
    testing.assertEqual(classOf($code, "c", "// c"), "comment");
}

# --- HTML ----------------------------------------------------------------

func testToHtmlWrapsTokens() {
    def got as string init toHtml("def x as int init 1;", "jennifer");
    testing.assertContains($got, '<span class="hljs-keyword">def</span>');
    testing.assertContains($got, '<span class="hljs-type">int</span>');
    testing.assertContains($got, '<span class="hljs-number">1</span>');
    testing.assertEqual(toHtml("", "jennifer"), "");
}

/** Source text is escaped exactly once, whatever token it lands in. */
func testToHtmlEscapes() {
    def hostile as string init "</code><script>alert(1)</script> & \"q\" '<b>' # </pre>";
    for (def l in languages()) {
        def got as string init toHtml($hostile, $l.name);
        testing.assertFalse(strings.contains($got, "<script"));
        testing.assertFalse(strings.contains($got, "</code>"));
        testing.assertFalse(strings.contains($got, "</pre>"));
        testing.assertFalse(strings.contains($got, "<b>"));
        testing.assertContains($got, "&lt;/");
        testing.assertContains($got, "&amp;");
        testing.assertFalse(strings.contains($got, "&amp;lt;"));
        # With the spans taken out, the text is the source, escaped.
        def bare as string init regex.replace('<span class="hljs-[a-z_]+">|</span>', $got, "");
        testing.assertEqual(html.unescape($bare), $hostile);
    }
}

# --- the front-matter switch --------------------------------------------

func testEnabled() {
    testing.assertTrue(enabled(""));
    testing.assertTrue(enabled("true"));
    testing.assertTrue(enabled(" TRUE "));
    testing.assertFalse(enabled("false"));
    testing.assertFalse(enabled("False"));
    for (def bad in ["yes", "no", "0", "1", "off", "on", "maybe"]) {
        testing.assertEqual(enabledFailure($bad), "highlight");
    }
    testing.assertEqual(enabledFailure("false"), "");
}

/** A file's language comes from its extension, else its #! line. */
func testGuess() {
    testing.assertEqual(guess("src/main.j", ""), "jennifer");
    testing.assertEqual(guess("tools/run.sh", ""), "sh");
    testing.assertEqual(guess("deck.toml", ""), "toml");
    testing.assertEqual(guess("ci.YML", ""), "yaml");
    testing.assertEqual(guess("page.tmpl", ""), "html");
    testing.assertEqual(guess("app/Dockerfile", ""), "dockerfile");
    testing.assertEqual(
        guess("bin/serve", "#!/usr/bin/env jennifer\nio.println(1);\n"),
        "jennifer");
    testing.assertEqual(guess("bin/run", "#!/bin/bash\necho\n"), "sh");
    testing.assertEqual(guess("notes.md", "#!/bin/sh\n"), "sh");
    testing.assertEqual(guess("README.md", "# Title\n"), "");
    testing.assertEqual(guess(".env.example", "A=1\n"), "");
    testing.assertEqual(guess("bin/tool", "no shebang\n"), "");
}
