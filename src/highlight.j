# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * Build-time syntax highlighting for fenced code blocks.
 *
 * One table-driven lexer serves every language: a `Lang` says which words are
 * keywords, types, literals and built-ins, how comments and strings open and
 * close, and which few shapes the language has (a `$name` variable, a `key:`
 * in front of a value, a `[section]`, a tag). The lexer turns a block into
 * `Token`s; `toHtml` wraps them in highlight.js class names for the slideshow,
 * and the PDF renderer colours the same tokens itself, so both outputs agree
 * on what every token is.
 *
 * The Jennifer rules are those of Grimoire's highlighter
 * (`apps/grimoire/src/highlight.j`), itself a port of the project's
 * highlight.js definition (`jennifer/editors/highlightjs/jennifer.js`): the
 * same lexical sets, nested block comments, raw `'...'` strings without
 * escapes, a number that stops before `.max`, and the REPL prompt. The class
 * names are highlight.js's own (`hljs-keyword`, `hljs-string`, ...), which is
 * what Grimoire emits too. The other languages are deliberately small: enough
 * to colour a slide, not a parser.
 * @module highlight
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use strings;
use lists;

import "html.j" as html;

/**
 * One highlighted run of a code block.
 * @field cls {string} the highlight.js class without its `hljs-` prefix
 *     (`keyword`, `string`, ...), "" for plain text
 * @field text {string} the source text of the run, unescaped
 */
export def struct Token {
    cls as string,
    text as string
};

/**
 * The lexical rules of one language: the table the lexer reads.
 * @field name {string} the canonical name, "" for no language
 * @field aliases {list of string} every fence tag that selects it, lower-case
 * @field keywords {list of string} words shown as `keyword`
 * @field types {list of string} words shown as `type`
 * @field literals {list of string} words shown as `literal`
 * @field builtins {list of string} words shown as `built_in`
 * @field ignoreCase {bool} the four word lists match case-insensitively; they
 *     are then written in lower case
 * @field firstWord {bool} a keyword counts only as the first word of a line
 * @field lineComments {list of string} markers that comment out the rest of a line
 * @field commentSpace {bool} a line comment needs a space or a line start before it
 * @field blockOpen {string} the opening marker of a block comment, "" for none
 * @field blockClose {string} the closing marker of a block comment
 * @field blockNests {bool} block comments nest
 * @field quotes {list of string} string delimiters a backslash escapes in,
 *     longest first
 * @field rawQuotes {list of string} string delimiters with no escapes
 * @field sigil {string} the character that opens a variable (`$`), "" for none
 * @field sigilBraces {bool} a variable may be written `${name}`
 * @field sigilSpecial {string} characters that make a one-character variable
 *     after the sigil (`$1`, `$?`)
 * @field identExtra {string} characters allowed inside a word besides letters,
 *     digits and `_`
 * @field calls {bool} a word followed by `(` is a `title` (a call or definition)
 * @field namespaces {bool} a word followed by `.` is a `built_in` (a library prefix)
 * @field constants {bool} an all-capitals word is a `symbol`
 * @field keySep {string} the separator after a key (`:` or `=`), "" for none;
 *     a word or string just before it is an `attr`
 * @field keyFirst {bool} a key counts only at the start of a line
 * @field dashItems {bool} a `- ` list marker still leaves the line's start open
 * @field sections {bool} a line opening with `[` is a `section` up to its `]`
 * @field lineMeta {string} a line opening with this is `meta` to its end
 *     (a C preprocessor line), "" for none
 * @field metaMarks {list of string} fixed strings shown as `meta` (`<?php`)
 * @field annotation {string} the character that opens an annotation shown as
 *     `meta` (`@decorator`), "" for none
 * @field prompts {list of string} line prefixes shown as `meta` (`>>> `, `$ `)
 * @field output {bool} a line with no prompt is program output, left plain
 * @field markup {bool} the language is tags and text (HTML, XML)
 */
export def struct Lang {
    name as string,
    aliases as list of string,
    keywords as list of string,
    types as list of string,
    literals as list of string,
    builtins as list of string,
    ignoreCase as bool,
    firstWord as bool,
    lineComments as list of string,
    commentSpace as bool,
    blockOpen as string,
    blockClose as string,
    blockNests as bool,
    quotes as list of string,
    rawQuotes as list of string,
    sigil as string,
    sigilBraces as bool,
    sigilSpecial as string,
    identExtra as string,
    calls as bool,
    namespaces as bool,
    constants as bool,
    keySep as string,
    keyFirst as bool,
    dashItems as bool,
    sections as bool,
    lineMeta as string,
    metaMarks as list of string,
    annotation as string,
    prompts as list of string,
    output as bool,
    markup as bool
};

/**
 * A language with no rules at all, the start of every table entry.
 * @param name {string} the canonical name
 * @param aliases {list of string} the fence tags that select it
 * @return {Lang} the empty rule set
 */
func blank(name as string, aliases as list of string) {
    return Lang{
        name: $name,
        aliases: $aliases,
        keywords: [],
        types: [],
        literals: [],
        builtins: [],
        ignoreCase: false,
        firstWord: false,
        lineComments: [],
        commentSpace: false,
        blockOpen: "",
        blockClose: "",
        blockNests: false,
        quotes: [],
        rawQuotes: [],
        sigil: "",
        sigilBraces: false,
        sigilSpecial: "",
        identExtra: "",
        calls: false,
        namespaces: false,
        constants: false,
        keySep: "",
        keyFirst: false,
        dashItems: false,
        sections: false,
        lineMeta: "",
        metaMarks: [],
        annotation: "",
        prompts: [],
        output: false,
        markup: false
    };
}

/**
 * Jennifer, as Grimoire highlights it: the lexical sets are verbatim from the
 * highlight.js definition, so the two highlighters cannot disagree.
 * @return {Lang} the rules
 */
func rulesJennifer() {
    def l as Lang init blank("jennifer", ["jennifer", "j"]);
    $l.keywords = [
        "export",
        "def",
        "const",
        "func",
        "struct",
        "enum",
        "use",
        "include",
        "import",
        "as",
        "of",
        "to",
        "init",
        "if",
        "elseif",
        "else",
        "while",
        "for",
        "in",
        "repeat",
        "until",
        "match",
        "when",
        "break",
        "continue",
        "return",
        "exit",
        "try",
        "catch",
        "throw",
        "defer",
        "errdefer",
        "spawn",
        "and",
        "or",
        "not"
    ];
    $l.types = ["int", "float", "string", "bool", "bytes", "list", "map", "task", "channel"];
    $l.literals = ["true", "false", "null"];
    $l.builtins = ["len"];
    $l.lineComments = ["#"];
    $l.blockOpen = "/*";
    $l.blockClose = "*/";
    $l.blockNests = true;
    $l.quotes = ['"'];
    $l.rawQuotes = ["'"];
    $l.sigil = "$";
    $l.calls = true;
    $l.namespaces = true;
    $l.constants = true;
    $l.prompts = [">>> ", "... "];
    return $l;
}

/**
 * PHP: `$variables`, three comment styles, and the `<?php` tag.
 * @return {Lang} the rules
 */
func rulesPhp() {
    def l as Lang init blank("php", ["php"]);
    $l.keywords = [
        "abstract",
        "and",
        "as",
        "break",
        "case",
        "catch",
        "class",
        "clone",
        "const",
        "continue",
        "declare",
        "default",
        "do",
        "echo",
        "else",
        "elseif",
        "empty",
        "enum",
        "extends",
        "final",
        "finally",
        "fn",
        "for",
        "foreach",
        "function",
        "global",
        "if",
        "implements",
        "include",
        "include_once",
        "instanceof",
        "interface",
        "isset",
        "match",
        "namespace",
        "new",
        "or",
        "print",
        "private",
        "protected",
        "public",
        "readonly",
        "require",
        "require_once",
        "return",
        "static",
        "switch",
        "throw",
        "trait",
        "try",
        "unset",
        "use",
        "while",
        "xor",
        "yield"
    ];
    $l.types = [
        "array",
        "bool",
        "callable",
        "float",
        "int",
        "iterable",
        "mixed",
        "never",
        "object",
        "self",
        "string",
        "void"
    ];
    $l.literals = ["true", "false", "null"];
    $l.builtins = [
        "count",
        "explode",
        "implode",
        "in_array",
        "json_decode",
        "json_encode",
        "printf",
        "sprintf",
        "str_replace",
        "strlen",
        "var_dump"
    ];
    $l.ignoreCase = true;
    $l.lineComments = ["//", "#"];
    $l.blockOpen = "/*";
    $l.blockClose = "*/";
    $l.quotes = ['"', "'"];
    $l.sigil = "$";
    $l.calls = true;
    $l.metaMarks = ["<?php", "<?=", "?>"];
    return $l;
}

/**
 * The POSIX shell and bash.
 * @return {Lang} the rules
 */
func rulesShell() {
    def l as Lang init blank("sh", ["sh", "bash", "shell", "zsh"]);
    $l.keywords = [
        "case",
        "do",
        "done",
        "elif",
        "else",
        "esac",
        "export",
        "fi",
        "for",
        "function",
        "if",
        "in",
        "local",
        "readonly",
        "return",
        "select",
        "then",
        "until",
        "while"
    ];
    $l.builtins = [
        "cd",
        "echo",
        "eval",
        "exec",
        "exit",
        "printf",
        "read",
        "set",
        "shift",
        "source",
        "test",
        "trap",
        "unset"
    ];
    $l.lineComments = ["#"];
    $l.commentSpace = true;
    $l.quotes = ['"', "`"];
    $l.rawQuotes = ["'"];
    $l.sigil = "$";
    $l.sigilBraces = true;
    $l.sigilSpecial = "0123456789@?#$!*-";
    $l.identExtra = "-";
    return $l;
}

/**
 * A terminal session: `$ ` prompts with shell after them, output plain.
 * @return {Lang} the rules
 */
func rulesConsole() {
    def l as Lang init rulesShell();
    $l.name = "console";
    $l.aliases = ["console", "shell-session"];
    $l.prompts = ["$ ", "% "];
    $l.output = true;
    return $l;
}

/**
 * Go.
 * @return {Lang} the rules
 */
func rulesGo() {
    def l as Lang init blank("go", ["go", "golang"]);
    $l.keywords = [
        "break",
        "case",
        "chan",
        "const",
        "continue",
        "default",
        "defer",
        "else",
        "fallthrough",
        "for",
        "func",
        "go",
        "goto",
        "if",
        "import",
        "interface",
        "map",
        "package",
        "range",
        "return",
        "select",
        "struct",
        "switch",
        "type",
        "var"
    ];
    $l.types = [
        "any",
        "bool",
        "byte",
        "complex64",
        "complex128",
        "error",
        "float32",
        "float64",
        "int",
        "int8",
        "int16",
        "int32",
        "int64",
        "rune",
        "string",
        "uint",
        "uint8",
        "uint16",
        "uint32",
        "uint64",
        "uintptr"
    ];
    $l.literals = ["true", "false", "nil", "iota"];
    $l.builtins = [
        "append",
        "cap",
        "clear",
        "close",
        "copy",
        "delete",
        "len",
        "make",
        "max",
        "min",
        "new",
        "panic",
        "print",
        "println",
        "recover"
    ];
    $l.lineComments = ["//"];
    $l.blockOpen = "/*";
    $l.blockClose = "*/";
    $l.quotes = ['"', "'"];
    $l.rawQuotes = ["`"];
    $l.calls = true;
    return $l;
}

/**
 * Python, with triple-quoted strings and decorators.
 * @return {Lang} the rules
 */
func rulesPython() {
    def l as Lang init blank("python", ["python", "py", "python3"]);
    $l.keywords = [
        "and",
        "as",
        "assert",
        "async",
        "await",
        "break",
        "case",
        "class",
        "continue",
        "def",
        "del",
        "elif",
        "else",
        "except",
        "finally",
        "for",
        "from",
        "global",
        "if",
        "import",
        "in",
        "is",
        "lambda",
        "match",
        "nonlocal",
        "not",
        "or",
        "pass",
        "raise",
        "return",
        "try",
        "while",
        "with",
        "yield"
    ];
    $l.literals = ["True", "False", "None"];
    $l.builtins = [
        "dict",
        "enumerate",
        "float",
        "int",
        "isinstance",
        "len",
        "list",
        "open",
        "print",
        "range",
        "self",
        "set",
        "sorted",
        "str",
        "super",
        "tuple",
        "zip"
    ];
    $l.lineComments = ["#"];
    $l.quotes = ['"""', "'''", '"', "'"];
    $l.calls = true;
    $l.annotation = "@";
    return $l;
}

/**
 * JavaScript and TypeScript, as one table.
 * @return {Lang} the rules
 */
func rulesJavaScript() {
    def l as Lang init blank(
        "javascript",
        ["javascript", "js", "jsx", "mjs", "typescript", "ts", "tsx"]);
    $l.keywords = [
        "abstract",
        "as",
        "async",
        "await",
        "break",
        "case",
        "catch",
        "class",
        "const",
        "continue",
        "debugger",
        "declare",
        "default",
        "delete",
        "do",
        "else",
        "enum",
        "export",
        "extends",
        "finally",
        "for",
        "from",
        "function",
        "if",
        "implements",
        "import",
        "in",
        "instanceof",
        "interface",
        "keyof",
        "let",
        "namespace",
        "new",
        "of",
        "private",
        "protected",
        "public",
        "readonly",
        "return",
        "static",
        "super",
        "switch",
        "this",
        "throw",
        "try",
        "type",
        "typeof",
        "var",
        "void",
        "while",
        "yield"
    ];
    $l.types = ["any", "bigint", "boolean", "never", "number", "object", "string", "unknown"];
    $l.literals = ["true", "false", "null", "undefined", "NaN", "Infinity"];
    $l.builtins = [
        "Array",
        "JSON",
        "Map",
        "Math",
        "Object",
        "Promise",
        "Set",
        "console",
        "document",
        "require",
        "window"
    ];
    $l.lineComments = ["//"];
    $l.blockOpen = "/*";
    $l.blockClose = "*/";
    $l.quotes = ['"', "'", "`"];
    $l.calls = true;
    $l.annotation = "@";
    return $l;
}

/**
 * JSON: keys, strings, numbers and the three literals.
 * @return {Lang} the rules
 */
func rulesJson() {
    def l as Lang init blank("json", ["json", "jsonc"]);
    $l.literals = ["true", "false", "null"];
    $l.quotes = ['"'];
    $l.keySep = ":";
    return $l;
}

/**
 * TOML: `[sections]`, `key =` lines, and its four string forms.
 * @return {Lang} the rules
 */
func rulesToml() {
    def l as Lang init blank("toml", ["toml"]);
    $l.literals = ["true", "false"];
    $l.lineComments = ["#"];
    $l.quotes = ['"""', '"'];
    $l.rawQuotes = ["'''", "'"];
    $l.identExtra = "-.";
    $l.keySep = "=";
    $l.keyFirst = true;
    $l.sections = true;
    return $l;
}

/**
 * YAML: `key:` at the start of a line or a `- ` item, comments, strings.
 * @return {Lang} the rules
 */
func rulesYaml() {
    def l as Lang init blank("yaml", ["yaml", "yml"]);
    $l.literals = ["true", "false", "null", "yes", "no"];
    $l.lineComments = ["#"];
    $l.commentSpace = true;
    $l.quotes = ['"'];
    $l.rawQuotes = ["'"];
    $l.identExtra = "-./";
    $l.keySep = ":";
    $l.keyFirst = true;
    $l.dashItems = true;
    return $l;
}

/**
 * SQL, whose words match in any case.
 * @return {Lang} the rules
 */
func rulesSql() {
    def l as Lang init blank("sql", ["sql", "sqlite", "postgresql", "mysql"]);
    $l.keywords = [
        "add",
        "all",
        "alter",
        "and",
        "as",
        "asc",
        "begin",
        "between",
        "by",
        "case",
        "check",
        "commit",
        "constraint",
        "create",
        "cross",
        "default",
        "delete",
        "desc",
        "distinct",
        "drop",
        "else",
        "end",
        "exists",
        "foreign",
        "from",
        "full",
        "group",
        "having",
        "if",
        "in",
        "index",
        "inner",
        "insert",
        "into",
        "is",
        "join",
        "key",
        "left",
        "like",
        "limit",
        "not",
        "offset",
        "on",
        "or",
        "order",
        "outer",
        "primary",
        "references",
        "returning",
        "right",
        "rollback",
        "select",
        "set",
        "table",
        "then",
        "transaction",
        "union",
        "unique",
        "update",
        "values",
        "view",
        "when",
        "where",
        "with"
    ];
    $l.types = [
        "bigint",
        "blob",
        "bool",
        "boolean",
        "char",
        "date",
        "decimal",
        "double",
        "float",
        "int",
        "integer",
        "json",
        "numeric",
        "real",
        "serial",
        "smallint",
        "text",
        "timestamp",
        "varchar"
    ];
    $l.literals = ["null", "true", "false"];
    $l.builtins = [
        "avg",
        "coalesce",
        "count",
        "length",
        "lower",
        "max",
        "min",
        "now",
        "sum",
        "upper"
    ];
    $l.ignoreCase = true;
    $l.lineComments = ["--"];
    $l.blockOpen = "/*";
    $l.blockClose = "*/";
    $l.rawQuotes = ["'"];
    $l.quotes = ['"'];
    return $l;
}

/**
 * HTML and XML: tags, attributes, attribute values, entities, comments.
 * @return {Lang} the rules
 */
func rulesMarkup() {
    def l as Lang init blank("html", ["html", "xml", "xhtml", "svg"]);
    $l.blockOpen = "<!--";
    $l.blockClose = "-->";
    $l.identExtra = "-:.";
    $l.markup = true;
    return $l;
}

/**
 * A Dockerfile: its instructions open a line, the rest is shell-like.
 * @return {Lang} the rules
 */
func rulesDockerfile() {
    def l as Lang init blank("dockerfile", ["dockerfile", "docker"]);
    $l.keywords = [
        "add",
        "arg",
        "cmd",
        "copy",
        "entrypoint",
        "env",
        "expose",
        "from",
        "healthcheck",
        "label",
        "maintainer",
        "onbuild",
        "run",
        "shell",
        "stopsignal",
        "user",
        "volume",
        "workdir"
    ];
    $l.ignoreCase = true;
    $l.firstWord = true;
    $l.lineComments = ["#"];
    $l.commentSpace = true;
    $l.quotes = ['"'];
    $l.rawQuotes = ["'"];
    $l.sigil = "$";
    $l.sigilBraces = true;
    $l.identExtra = "-";
    return $l;
}

/**
 * C, with its preprocessor lines and upper-case macros.
 * @return {Lang} the rules
 */
func rulesC() {
    def l as Lang init blank("c", ["c", "h"]);
    $l.keywords = [
        "auto",
        "break",
        "case",
        "const",
        "continue",
        "default",
        "do",
        "else",
        "enum",
        "extern",
        "for",
        "goto",
        "if",
        "inline",
        "register",
        "restrict",
        "return",
        "sizeof",
        "static",
        "struct",
        "switch",
        "typedef",
        "union",
        "volatile",
        "while"
    ];
    $l.types = [
        "FILE",
        "bool",
        "char",
        "double",
        "float",
        "int",
        "int8_t",
        "int16_t",
        "int32_t",
        "int64_t",
        "long",
        "short",
        "signed",
        "size_t",
        "uint8_t",
        "uint16_t",
        "uint32_t",
        "uint64_t",
        "unsigned",
        "void"
    ];
    $l.literals = ["NULL", "true", "false"];
    $l.builtins = ["free", "malloc", "memcpy", "memset", "printf", "puts", "strlen"];
    $l.lineComments = ["//"];
    $l.blockOpen = "/*";
    $l.blockClose = "*/";
    $l.quotes = ['"', "'"];
    $l.calls = true;
    $l.constants = true;
    $l.lineMeta = "#";
    return $l;
}

/**
 * Every language this highlighter knows, in listing order.
 * @return {list of Lang} the rule tables
 */
export func languages() {
    return [
        rulesJennifer(),
        rulesPhp(),
        rulesShell(),
        rulesConsole(),
        rulesGo(),
        rulesPython(),
        rulesJavaScript(),
        rulesJson(),
        rulesToml(),
        rulesYaml(),
        rulesSql(),
        rulesMarkup(),
        rulesDockerfile(),
        rulesC()
    ];
}

/**
 * Look up the rules for a fence's language tag.
 * @param tag {string} the tag as written after the fence, any case
 * @return {Lang} the language's rules; an empty `name` when it is not known
 */
export func language(tag as string) {
    def want as string init strings.lower(strings.trim($tag));
    if ($want != "") {
        for (def l in languages()) {
            if (lists.contains($l.aliases, $want)) {
                return $l;
            }
        }
    }
    return blank("", []);
}

/**
 * Whether a fenced block's language tag is one this highlighter colours.
 * @param tag {string} the fence's language tag
 * @return {bool} true when the block can be highlighted
 */
export func handles(tag as string) {
    return language($tag).name != "";
}

/**
 * The language tag for a source file, from its name or, without a known
 * extension, its `#!` line: what a file outside a deck is highlighted as.
 * @param name {string} the file's name or path
 * @param text {string} its contents
 * @return {string} a tag `handles` accepts, or "" for plain text
 */
export func guess(name as string, text as string) {
    def parts as list of string init strings.split(strings.lower($name), "/");
    def base as string init $parts[len($parts) - 1];
    if ($base == "dockerfile" or strings.startsWith($base, "dockerfile.")) {
        return "dockerfile";
    }
    def pieces as list of string init strings.split($base, ".");
    if (len($pieces) > 1 and $pieces[0] != "") {
        def ext as string init $pieces[len($pieces) - 1];
        if ($ext == "tmpl") {
            return "html";
        }
        if (handles($ext)) {
            return language($ext).name;
        }
    }
    if (not strings.startsWith($text, "#!")) {
        return "";
    }
    def line as string init strings.split($text, "\n")[0];
    for (def w in strings.split(strings.replace($line, "/", " "), " ")) {
        if ($w == "jennifer" or $w == "python3" or $w == "python" or $w == "php") {
            return language($w).name;
        }
        if ($w == "sh" or $w == "bash" or $w == "zsh") {
            return "sh";
        }
    }
    return "";
}

/**
 * Read the deck's `highlight:` front-matter value.
 *
 * Highlighting is on unless the deck turns it off, and the value is checked
 * strictly: `true` or `false` in any case, nothing else.
 * @param value {string} the value as written, "" when the key is absent
 * @return {bool} whether code blocks are highlighted
 * @throws {Error} kind "highlight" for any other value
 */
export func enabled(value as string) {
    def v as string init strings.lower(strings.trim($value));
    if ($v == "" or $v == "true") {
        return true;
    }
    if ($v == "false") {
        return false;
    }
    throw Error{
        kind: "highlight",
        message: "highlight wants true or false, got \"" + $value + "\"",
        file: "",
        line: 0,
        col: 0
    };
}

# --- characters -----------------------------------------------------

func isDigit(ch as string) {
    return $ch >= "0" and $ch <= "9";
}

func isAlpha(ch as string) {
    return ($ch >= "a" and $ch <= "z") or ($ch >= "A" and $ch <= "Z");
}

func isUpper(ch as string) {
    return $ch >= "A" and $ch <= "Z";
}

# A word starts with a letter or `_` and goes on with those, digits, and the
# language's extra characters (`-` in a shell command or a YAML key).
func isWordChar(ch as string, extra as string) {
    return isAlpha($ch) or isDigit($ch) or $ch == "_" or
        ($extra != "" and strings.contains($extra, $ch));
}

func isBlank(ch as string) {
    return $ch == " " or $ch == "\t";
}

# startsAt tells whether the characters from `at` spell `s`.
func startsAt(cs as list of string, at as int, s as string) {
    def k as int init len($s);
    if ($k == 0 or $at + $k > len($cs)) {
        return false;
    }
    return strings.join($cs[$at..$at + $k], "") == $s;
}

# --- scanners -------------------------------------------------------
#
# Each returns the index just past the token it consumed, never past the end,
# so the main loop only dispatches on what starts at `at`.

func scanToLineEnd(cs as list of string, at as int) {
    def i as int init $at;
    while ($i < len($cs) and $cs[$i] != "\n") {
        $i = $i + 1;
    }
    return $i;
}

# A block comment runs to its closing marker; a nesting one counts depth, so
# Jennifer's `/* /* */ */` is one comment.
func scanBlock(cs as list of string, at as int, l as Lang) {
    def i as int init $at + len($l.blockOpen);
    def depth as int init 1;
    while ($i < len($cs)) {
        if ($l.blockNests and startsAt($cs, $i, $l.blockOpen)) {
            $depth = $depth + 1;
            $i = $i + len($l.blockOpen);
            continue;
        }
        if (startsAt($cs, $i, $l.blockClose)) {
            $depth = $depth - 1;
            $i = $i + len($l.blockClose);
            if ($depth == 0) {
                return $i;
            }
            continue;
        }
        $i = $i + 1;
    }
    return len($cs);
}

# A string runs to its closing delimiter; where escapes apply, a backslash
# takes the character after it along, so `\"` does not end it.
func scanString(cs as list of string, at as int, quote as string, escapes as bool) {
    def i as int init $at + len($quote);
    while ($i < len($cs)) {
        if ($escapes and $cs[$i] == "\\") {
            $i = $i + 2;
            continue;
        }
        if (startsAt($cs, $i, $quote)) {
            return $i + len($quote);
        }
        $i = $i + 1;
    }
    return len($cs);
}

# A number takes letters and `_` too (`0xff`, `1_000`, `10ms`), a `.` only
# when a digit follows (so `1.max` is a number then a field access), and a
# sign straight after an exponent's `e`.
func scanNumber(cs as list of string, at as int) {
    def i as int init $at;
    while ($i < len($cs)) {
        def ch as string init $cs[$i];
        if (isDigit($ch) or isAlpha($ch) or $ch == "_") {
            $i = $i + 1;
            continue;
        }
        if ($ch == "." and $i + 1 < len($cs) and isDigit($cs[$i + 1])) {
            $i = $i + 1;
            continue;
        }
        if (($ch == "+" or $ch == "-") and $i > $at and
            ($cs[$i - 1] == "e" or $cs[$i - 1] == "E")) {
            $i = $i + 1;
            continue;
        }
        return $i;
    }
    return $i;
}

# scanVariable returns the end of a variable at a sigil, or `at` when the sigil
# opens none (a lone `$`).
func scanVariable(cs as list of string, at as int, l as Lang) {
    def n as int init len($cs);
    if ($at + 1 >= $n) {
        return $at;
    }
    def next as string init $cs[$at + 1];
    if ($l.sigilBraces and $next == '{') {
        def i as int init $at + 2;
        while ($i < $n and $cs[$i] != '}' and $cs[$i] != "\n") {
            $i = $i + 1;
        }
        if ($i < $n and $cs[$i] == '}') {
            return $i + 1;
        }
        return $at;
    }
    if (isAlpha($next) or $next == "_") {
        def i as int init $at + 1;
        while ($i < $n and isWordChar($cs[$i], "")) {
            $i = $i + 1;
        }
        return $i;
    }
    if ($l.sigilSpecial != "" and strings.contains($l.sigilSpecial, $next)) {
        return $at + 2;
    }
    return $at;
}

# nextChar is the first character after `at` that is not a space or a tab, ""
# at the end.
func nextChar(cs as list of string, at as int) {
    def i as int init $at;
    while ($i < len($cs) and isBlank($cs[$i])) {
        $i = $i + 1;
    }
    if ($i < len($cs)) {
        return $cs[$i];
    }
    return "";
}

# inWords looks a word up in one of a language's lists, honouring ignoreCase.
func inWords(words as list of string, word as string, l as Lang) {
    if ($l.ignoreCase) {
        return lists.contains($words, strings.lower($word));
    }
    return lists.contains($words, $word);
}

# classifyWord decides what a word is. A key is a key whatever its spelling;
# then the word lists, in Grimoire's order; then the shapes - a library prefix,
# a constant, a call - which is why `return (` stays a keyword.
func classifyWord(word as string, next as string, fresh as bool, l as Lang) {
    if ($l.keySep != "" and $next == $l.keySep and ($fresh or not $l.keyFirst)) {
        return "attr";
    }
    if (inWords($l.keywords, $word, $l) and ($fresh or not $l.firstWord)) {
        return "keyword";
    }
    if (inWords($l.types, $word, $l)) {
        return "type";
    }
    if (inWords($l.literals, $word, $l)) {
        return "literal";
    }
    if (inWords($l.builtins, $word, $l)) {
        return "built_in";
    }
    if ($l.namespaces and $next == ".") {
        return "built_in";
    }
    if ($l.constants and isUpper($word[..1]) and
        strings.upper($word) == $word) {
        return "symbol";
    }
    if ($l.calls and $next == "(") {
        return "title";
    }
    return "";
}

# firstMatch returns the first of the markers that starts at `at`, "" for none.
func firstMatch(cs as list of string, at as int, markers as list of string) {
    for (def m in $markers) {
        if (startsAt($cs, $at, $m)) {
            return $m;
        }
    }
    return "";
}

# wordEnd returns the index just past the word starting at `at`.
func wordEnd(cs as list of string, at as int, extra as string) {
    def i as int init $at;
    while ($i < len($cs) and isWordChar($cs[$i], $extra)) {
        $i = $i + 1;
    }
    return $i;
}

# One step of the lexer: the token found at a position. `start` is where the
# token begins, which is past the position for a tag's name (the `<` before
# it stays plain); `stop` is the index just past it, at most `start` when
# nothing was found; `inTag` is whether an HTML tag is open after it.
def struct Step {
    cls as string,
    start as int,
    stop as int,
    inTag as bool
};

# scanMarkup finds the token at `i` in HTML or XML: inside a tag its
# attributes and values, outside it a tag's name, a declaration, an entity.
func scanMarkup(cs as list of string, i as int, l as Lang, inTag as bool) {
    def n as int init len($cs);
    def ch as string init $cs[$i];
    def out as Step init Step{cls: "", start: $i, stop: $i, inTag: $inTag};
    if ($inTag) {
        if ($ch == ">") {
            $out.inTag = false;
            $out.stop = $i + 1;
        } elseif ($ch == '"' or $ch == "'") {
            $out.cls = "string";
            $out.stop = scanString($cs, $i, $ch, false);
        } elseif (isWordChar($ch, $l.identExtra)) {
            $out.cls = "attr";
            $out.stop = wordEnd($cs, $i, $l.identExtra);
        }
        return $out;
    }
    if ($ch == "<" and $i + 1 < $n and ($cs[$i + 1] == "!" or $cs[$i + 1] == "?")) {
        # A declaration or processing instruction, `<!DOCTYPE html>`.
        def end as int init $i;
        while ($end < $n and $cs[$end] != ">") {
            $end = $end + 1;
        }
        $out.cls = "meta";
        $out.stop = $end + 1;
        if ($end >= $n) {
            $out.stop = $n;
        }
        return $out;
    }
    if ($ch == "<") {
        # `<` or `</` stays plain; the tag's name is a `name`.
        def at as int init $i + 1;
        if ($at < $n and $cs[$at] == "/") {
            $at = $at + 1;
        }
        if ($at < $n and isAlpha($cs[$at])) {
            return Step{
                cls: "name",
                start: $at,
                stop: wordEnd($cs, $at, $l.identExtra),
                inTag: true
            };
        }
        return $out;
    }
    if ($ch == "&") {
        def end as int init $i + 1;
        while ($end < $n and $end - $i < 12 and
            (isAlpha($cs[$end]) or isDigit($cs[$end]) or $cs[$end] == "#")) {
            $end = $end + 1;
        }
        if ($end < $n and $cs[$end] == ";") {
            $out.cls = "symbol";
            $out.stop = $end + 1;
        }
    }
    return $out;
}

# scanSection finds the end of a `[section]` or `[[table]]` header.
func scanSection(cs as list of string, at as int) {
    def i as int init $at;
    while ($i < len($cs) and $cs[$i] != "]" and $cs[$i] != "\n") {
        $i = $i + 1;
    }
    while ($i < len($cs) and $cs[$i] == "]") {
        $i = $i + 1;
    }
    return $i;
}

# scanCode finds the token at `i` in a language that is not markup.
func scanCode(cs as list of string, i as int, l as Lang, fresh as bool) {
    def ch as string init $cs[$i];
    def out as Step init Step{cls: "", start: $i, stop: $i, inTag: false};
    def comment as string init firstMatch($cs, $i, $l.lineComments);
    if ($comment != "" and $l.commentSpace and $i > 0 and not isBlank($cs[$i - 1]) and
        $cs[$i - 1] != "\n") {
        $comment = "";
    }
    def quote as string init firstMatch($cs, $i, $l.quotes);
    def raw as string init firstMatch($cs, $i, $l.rawQuotes);
    if ($fresh and $l.lineMeta != "" and startsAt($cs, $i, $l.lineMeta)) {
        $out.cls = "meta";
        $out.stop = scanToLineEnd($cs, $i);
    } elseif ($fresh and $l.sections and $ch == "[") {
        $out.cls = "section";
        $out.stop = scanSection($cs, $i);
    } elseif ($comment != "") {
        $out.cls = "comment";
        $out.stop = scanToLineEnd($cs, $i);
    } elseif ($quote != "") {
        $out.cls = "string";
        $out.stop = scanString($cs, $i, $quote, true);
    } elseif ($raw != "") {
        $out.cls = "string";
        $out.stop = scanString($cs, $i, $raw, false);
    } elseif ($l.sigil != "" and $ch == $l.sigil) {
        $out.cls = "variable";
        $out.stop = scanVariable($cs, $i, $l);
    } elseif ($l.annotation != "" and $ch == $l.annotation and $i + 1 < len($cs) and
        isAlpha($cs[$i + 1])) {
        $out.cls = "meta";
        $out.stop = wordEnd($cs, $i + 1, ".");
    } elseif (isDigit($ch)) {
        $out.cls = "number";
        $out.stop = scanNumber($cs, $i);
    } elseif (isAlpha($ch) or $ch == "_") {
        $out.stop = wordEnd($cs, $i, $l.identExtra);
        $out.cls = classifyWord(
            strings.join($cs[$i..$out.stop], ""),
            nextChar($cs, $out.stop),
            $fresh,
            $l);
    }
    # A key is the string in front of the separator too (JSON's `"name":`).
    if ($out.cls == "string" and $l.keySep != "" and nextChar($cs, $out.stop) == $l.keySep and
        ($fresh or not $l.keyFirst)) {
        $out.cls = "attr";
    }
    return $out;
}

# scanAt finds the token at `i`: first what a line can open with (a prompt,
# program output), then what any language can have (a fixed meta mark, a
# block comment), then the markup or code rules.
func scanAt(cs as list of string, i as int, l as Lang, fresh as bool, inTag as bool) {
    def col0 as bool init $i == 0 or $cs[$i - 1] == "\n";
    def out as Step init Step{cls: "", start: $i, stop: $i, inTag: $inTag};
    def prompt as string init "";
    if ($col0) {
        $prompt = firstMatch($cs, $i, $l.prompts);
    }
    def mark as string init firstMatch($cs, $i, $l.metaMarks);
    if ($prompt != "") {
        $out.cls = "meta";
        $out.stop = $i + len($prompt);
    } elseif ($fresh and $l.output and len($l.prompts) > 0) {
        # Program output in a terminal session: the whole line, plain.
        $out.stop = scanToLineEnd($cs, $i);
    } elseif ($mark != "") {
        $out.cls = "meta";
        $out.stop = $i + len($mark);
    } elseif ($l.blockOpen != "" and startsAt($cs, $i, $l.blockOpen)) {
        $out.cls = "comment";
        $out.stop = scanBlock($cs, $i, $l);
    } elseif ($l.markup) {
        return scanMarkup($cs, $i, $l, $inTag);
    } else {
        return scanCode($cs, $i, $l, $fresh);
    }
    return $out;
}

# keepsFresh tells whether the character at `i` leaves the line's start open:
# a blank does, and so does a YAML list item's `- `.
func keepsFresh(cs as list of string, i as int, l as Lang) {
    if (not $l.dashItems or $cs[$i] != "-") {
        return false;
    }
    return $i + 1 >= len($cs) or isBlank($cs[$i + 1]) or $cs[$i + 1] == "\n";
}

/**
 * Split a code block into highlighted runs.
 *
 * Joining the texts of the result gives the block back unchanged, character
 * for character; adjacent plain text comes as one run. An unknown language
 * comes back as one plain run.
 * @param code {string} the source of one code block
 * @param tag {string} the fence's language tag
 * @return {list of Token} the runs, in order
 */
export func tokens(code as string, tag as string) {
    def l as Lang init language($tag);
    def out as list of Token init [];
    if ($l.name == "") {
        if ($code != "") {
            $out[] = Token{cls: "", text: $code};
        }
        return $out;
    }
    def cs as list of string init strings.chars($code);
    def n as int init len($cs);
    def i as int init 0;
    def plain as int init 0;
    # Nothing but blanks (and, in YAML, `- ` markers) before `i` on this line.
    def fresh as bool init true;
    # Inside an HTML or XML tag, between its name and its `>`.
    def inTag as bool init false;
    while ($i < $n) {
        if ($cs[$i] == "\n" or isBlank($cs[$i])) {
            $fresh = $fresh or $cs[$i] == "\n";
            $i = $i + 1;
            continue;
        }
        def step as Step init scanAt($cs, $i, $l, $fresh, $inTag);
        $inTag = $step.inTag;
        $fresh = $fresh and keepsFresh($cs, $i, $l);
        if ($step.cls == "" or $step.stop <= $step.start) {
            # Plain text accumulates into one run. A word that classified as
            # nothing has still been consumed, so the loop steps over all of
            # it: restarting inside it would find `in` at the end of `plain`.
            $i = $i + 1;
            if ($step.stop > $i) {
                $i = $step.stop;
            }
            continue;
        }
        if ($plain < $step.start) {
            $out[] = Token{cls: "", text: strings.join($cs[$plain..$step.start], "")};
        }
        $out[] = Token{cls: $step.cls, text: strings.join($cs[$step.start..$step.stop], "")};
        $i = $step.stop;
        $plain = $i;
    }
    if ($plain < $n) {
        $out[] = Token{cls: "", text: strings.join($cs[$plain..$n], "")};
    }
    return $out;
}

/**
 * Highlight a code block as HTML with highlight.js class names.
 *
 * Every run is escaped here and nowhere else, so the result is safe to drop
 * inside a `<code>` element: source text never becomes markup.
 * @param code {string} the source of one code block
 * @param tag {string} the fence's language tag
 * @return {string} the escaped, highlighted HTML
 */
export func toHtml(code as string, tag as string) {
    def parts as list of string init [];
    for (def t in tokens($code, $tag)) {
        if ($t.cls == "") {
            $parts[] = html.escape($t.text);
        } else {
            $parts[] = '<span class="hljs-' + $t.cls + '">' + html.escape($t.text) + "</span>";
        }
    }
    return strings.join($parts, "");
}
