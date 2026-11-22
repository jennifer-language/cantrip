# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * Preprocessors: programs that rewrite a deck's Markdown before it is rendered,
 * speaking Grimoire's plugin contract, api 1.
 *
 * A plugin is a separate executable, not a Jennifer module: `import` resolves
 * at parse time, so an installed Cantrip cannot load code it was not built
 * with. The contract is Grimoire's on purpose. A deck is described the way
 * Grimoire describes a book - each input file is a chapter - so a Grimoire
 * preprocessor such as `grimoire-katex` or `grimoire-mermaid` runs over a deck
 * unchanged, and a plugin written for Cantrip runs over a book.
 *
 *     {"api": 1, "kind": "preprocessor", "features": ["files", "mathml"],
 *      "book": {"title": ..., "description": "", "authors": [...],
 *               "language": ..., "src": ..., "out": ..., "generated": ...},
 *      "plugin": {"name": "mermaid", "settings": { ... }, "files": ...},
 *      "entries": [{"kind": "page", "title": ..., "src": "talk.md", ...}],
 *      "chapters": [{"src": "talk.md", "content": "---\ntheme: ..."}]}
 *
 *     {"api": 1, "chapters": [{"src": "talk.md", "content": "..."}]}
 *
 * A deck names its plugins in `cantrip.toml`, beside its first file, as
 * `[preprocessor.NAME]` tables the same as `grimoire.toml`. Nothing runs that
 * the file does not name.
 *
 * This module holds the parts that are values in, values out: reading the
 * configuration, building a request, applying a reply, and describing a plan.
 * Finding a program, running it, and the scratch directory its files go to
 * are I/O, and live in `cli.j`.
 * @module plugin
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */
use strings;
use json;
use toml;
use maps;
use time;
use convert;

/** The contract version this build speaks; Grimoire's api 1. */
export def const API as int init 1;

/** The configuration file Cantrip reads, beside the deck's first file. */
export def const CONFIG_FILE as string init "cantrip.toml";

/** The directory a slide links generated files under, as in Grimoire. */
export def const GENERATED as string init "_generated";

/** Where a program came from, in the words `cantrip plugins` prints. */
export def const IN_DECK as string init "in this deck";

/** A program named by a path outside the deck's directory. */
export def const OUTSIDE as string init "outside this deck";

/** A program found on `PATH`. */
export def const ON_PATH as string init "found on PATH";

/** A program that was not found at all. */
export def const NOWHERE as string init "not found";

/**
 * What this build offers on top of api 1, as Grimoire names it: `files`
 * (`plugin.files` and `book.generated`) and `mathml` (a `<math>` element
 * reaches both outputs).
 * @return {list of string} the feature names
 */
export func features() {
    return ["files", "mathml"];
}

/**
 * One configured preprocessor.
 *
 * `settings` is the whole table from `cantrip.toml`, already converted to JSON,
 * because that is the shape the plugin receives it in; Cantrip reads `command`
 * and `args` out of it and passes the rest through unread.
 * @field name {string} the table name, `[preprocessor.NAME]`
 * @field command {string} the program to run; `cantrip-NAME` by default
 * @field args {list of string} arguments passed before the request
 * @field settings {string} the whole table as a JSON object
 */
export def struct Plugin {
    name as string,
    command as string,
    args as list of string,
    settings as string
};

/**
 * What a request says about the deck.
 * @field title {string} the deck's title
 * @field authors {list of string} the author line, as one name, or none
 * @field language {string} the front matter's `lang`, "" when unset
 * @field src {string} the deck's directory, absolute
 * @field out {string} the directory the outputs are written to, absolute
 */
export def struct Book {
    title as string,
    authors as list of string,
    language as string,
    src as string,
    out as string
};

/**
 * One input file and its current text.
 * @field src {string} the file's path relative to the deck's directory
 * @field content {string} its Markdown, front matter included
 */
export def struct Chapter {
    src as string,
    content as string
};

/**
 * One configured plugin, and the program it would actually run.
 * @field name {string} the table name
 * @field command {string} the command as configured
 * @field args {list of string} the arguments that come before the request
 * @field path {string} the program that will run, "" when nothing was found
 * @field origin {string} where it came from: `IN_DECK`, `OUTSIDE`, `ON_PATH`
 *   or `NOWHERE`
 */
export def struct Resolved {
    name as string,
    command as string,
    args as list of string,
    path as string,
    origin as string
};

# fail raises a plugin error that names the plugin, because "exit 1" on its
# own sends the reader to the wrong repository.
func fail(name as string, message as string) {
    throw Error{
        kind: "plugin",
        message: "preprocessor " + $name + ": " + $message,
        file: "",
        line: 0,
        col: 0
    };
}

# configError raises an error about the configuration file itself.
func configError(file as string, message as string) {
    throw Error{kind: "plugin", message: $file + ": " + $message, file: $file, line: 0, col: 0};
}

/**
 * A TOML key escaped for a JSON Pointer (RFC 6901): `~` and `/` would otherwise
 * read as pointer syntax.
 * @param key {string} the key
 * @return {string} the escaped key
 */
export func pointerKey(key as string) {
    return strings.replace(strings.replace($key, "~", "~0"), "/", "~1");
}

/**
 * A TOML node as JSON text: a plugin receives its own table, and the wire
 * format is JSON. A date-time goes over as its RFC 3339 text.
 * @param doc {toml.Value} the document
 * @param ptr {string} the node's pointer
 * @return {string} the node as JSON
 */
export func jsonOf(doc as toml.Value, ptr as string) {
    match (toml.typeOf($doc, $ptr)) {
        when "map" {
            def parts as list of string;
            for (def key in toml.keys($doc, $ptr)) {
                $parts[] = json.encode($key) + ":" + jsonOf($doc, $ptr + "/" + pointerKey($key));
            }
            return '{' + strings.join($parts, ",") + '}';
        }
        when "list" {
            def parts as list of string;
            for (def i in 0..toml.length($doc, $ptr)) {
                $parts[] = jsonOf($doc, $ptr + "/" + convert.toString($i));
            }
            return "[" + strings.join($parts, ",") + "]";
        }
        when "string" { return json.encode(toml.asString($doc, $ptr)); }
        when "int" { return convert.toString(toml.asInt($doc, $ptr)); }
        when "float" { return json.encode(toml.asFloat($doc, $ptr)); }
        when "bool" { if (toml.asBool($doc, $ptr)) {
            return "true";
        }
        return "false"; }
        when "datetime" { return json.encode(time.iso(toml.asDatetime($doc, $ptr))); }
        else { return "null"; }
    }
}

/**
 * Whether a table name can be a plugin's directory under `_generated`: one
 * path component, not `.` or `..`.
 * @param name {string} the table name
 * @return {bool} true when it is usable
 */
export func usableName(name as string) {
    return $name != "" and $name != "." and $name != ".." and not strings.contains($name, "/") and
        not strings.contains($name, "\\");
}

# argsOf reads a table's `args`: a list of strings, or none.
func argsOf(doc as toml.Value, ptr as string, file as string, name as string) {
    def args as list of string;
    if (not toml.has($doc, $ptr + "/args")) {
        return $args;
    }
    if (toml.typeOf($doc, $ptr + "/args") != "list") {
        configError($file, "preprocessor." + $name + ".args must be a list of strings");
    }
    for (def i in 0..toml.length($doc, $ptr + "/args")) {
        def at as string init $ptr + "/args/" + convert.toString($i);
        if (toml.typeOf($doc, $at) != "string") {
            configError($file, "preprocessor." + $name + ".args must be a list of strings");
        }
        $args[] = toml.asString($doc, $at);
    }
    return $args;
}

/**
 * Read `cantrip.toml`: its `[preprocessor.NAME]` tables, in the order the file
 * lists them, which is the order they run in.
 *
 * Only `preprocessor` is read. A `[renderer.NAME]` table is refused rather
 * than ignored, because a deck that names one expects it to run, and Cantrip
 * runs no renderers yet. Any other top-level key is refused too: the file
 * configures plugins, and presentation stays in the deck's front matter.
 * @param text {string} the file's contents
 * @param file {string} the file's path, for messages
 * @return {list of Plugin} the preprocessors, in order
 * @throws {Error} kind "plugin" for a malformed file, an unknown key, a
 *   renderer table, a bad `command` or `args`, or an unusable table name
 */
export func parseConfig(text as string, file as string) {
    def out as list of Plugin;
    def doc as toml.Value init toml.decode('');
    try {
        $doc = toml.decode($text);
    } catch (e) {
        configError($file, $e.message);
    }
    for (def key in toml.keys($doc, "")) {
        if ($key == "renderer") {
            configError($file, "[renderer.*] is not supported; Cantrip runs preprocessors only");
        }
        if ($key != "preprocessor") {
            configError(
                $file,
                "unknown key \"" + $key + "\"; the file holds [preprocessor.NAME] tables only");
        }
    }
    if (not toml.has($doc, "/preprocessor")) {
        return $out;
    }
    if (toml.typeOf($doc, "/preprocessor") != "map") {
        configError($file, "preprocessor must be a table of [preprocessor.NAME] tables");
    }
    for (def name in toml.keys($doc, "/preprocessor")) {
        def ptr as string init "/preprocessor/" + pointerKey($name);
        if (toml.typeOf($doc, $ptr) != "map") {
            configError($file, "preprocessor." + $name + " must be a table");
        }
        if (not usableName($name)) {
            configError(
                $file,
                "preprocessor \"" + $name + "\": the name has to be usable as a directory name");
        }
        def command as string init "cantrip-" + $name;
        if (toml.has($doc, $ptr + "/command")) {
            if (toml.typeOf($doc, $ptr + "/command") != "string" or
                strings.trim(toml.asString($doc, $ptr + "/command")) == "") {
                configError($file, "preprocessor." + $name + ".command must be a non-empty string");
            }
            $command = toml.asString($doc, $ptr + "/command");
        }
        $out[] = Plugin{
            name: $name,
            command: $command,
            args: argsOf($doc, $ptr, $file, $name),
            settings: jsonOf($doc, $ptr)
        };
    }
    return $out;
}

/**
 * The commands a plugin answers to, in the order they are tried.
 *
 * A table that sets no `command` runs `cantrip-NAME`, and when there is no such
 * program, `grimoire-NAME`: the plugins written for Grimoire speak the same
 * contract, so `[preprocessor.mermaid]` finds an installed `grimoire-mermaid`.
 * A `command` the table sets is tried alone.
 * @param spec {Plugin} the configured plugin
 * @return {list of string} one or two commands
 */
export func candidates(spec as Plugin) {
    if ($spec.command == "cantrip-" + $spec.name) {
        return [$spec.command, "grimoire-" + $spec.name];
    }
    return [$spec.command];
}

# jsonStrings renders a list of strings as a JSON array.
func jsonStrings(items as list of string) {
    def parts as list of string;
    for (def s in $items) {
        $parts[] = json.encode($s);
    }
    return "[" + strings.join($parts, ",") + "]";
}

# The title an entry carries: the first heading of the file's first slide.
func titleOf(content as string) {
    for (def line in strings.split($content, "\n")) {
        def bare as string init strings.trim($line);
        if (strings.startsWith($bare, "# ") or strings.startsWith($bare, "## ")) {
            return strings.trim($bare[strings.indexOf($bare, " ")..]);
        }
    }
    return "";
}

/**
 * The request handed to one preprocessor.
 *
 * Each input file is a chapter and an outline entry of kind `page`, in the
 * order the files were given, so a plugin written for Grimoire sees a book of
 * one or more chapters.
 * @param book {Book} the deck
 * @param spec {Plugin} the plugin being run
 * @param chapters {list of Chapter} every input file, with its current text
 * @param files {string} the plugin's own directory for generated files
 * @param generated {string} the directory standing in for `_generated`
 * @return {string} the request as JSON text
 */
export func request(
    book as Book,
    spec as Plugin,
    chapters as list of Chapter,
    files as string,
    generated as string) {
    def outline as list of string;
    def texts as list of string;
    for (def k in 0..len($chapters)) {
        def c as Chapter init $chapters[$k];
        $outline[] = '{"kind":"page","title":' + json.encode(titleOf($c.content)) +
            ',"src":' + json.encode($c.src) +
            ',"out":' + json.encode($c.src) +
            ',"level":0,"number":' + json.encode(convert.toString($k + 1)) + '}';
        $texts[] = '{"src":' + json.encode($c.src) + ',"content":' + json.encode($c.content) + '}';
    }
    return '{"api":' + convert.toString(API) +
        ',"kind":"preprocessor"' +
        ',"features":' + jsonStrings(features()) +
        ',"book":{"title":' + json.encode($book.title) +
        ',"description":""' +
        ',"authors":' + jsonStrings($book.authors) +
        ',"language":' + json.encode($book.language) +
        ',"src":' + json.encode($book.src) +
        ',"out":' + json.encode($book.out) +
        ',"generated":' + json.encode($generated) + '}' +
        ',"plugin":{"name":' + json.encode($spec.name) +
        ',"settings":' + $spec.settings +
        ',"files":' + json.encode($files) + '}' +
        ',"entries":[' + strings.join($outline, ",") + ']' +
        ',"chapters":[' + strings.join($texts, ",") + ']}';
}

/**
 * Apply a preprocessor's reply to the deck's files.
 *
 * The reply may be sparse: a file it does not mention keeps its text. One the
 * deck does not have is an error rather than a new file, because the command
 * line decides what a deck holds.
 * @param spec {Plugin} the plugin that replied
 * @param chapters {list of Chapter} the files before the reply
 * @param reply {string} what the plugin wrote to stdout
 * @return {list of Chapter} the files after it, in the same order
 * @throws {Error} kind "plugin" for a reply that is not api 1 JSON or that
 *   rewrites a file the deck does not have
 */
export func merge(spec as Plugin, chapters as list of Chapter, reply as string) {
    def doc as json.Value init json.decode('{}');
    try {
        $doc = json.decode($reply);
    } catch (e) {
        fail($spec.name, "reply is not JSON: " + $e.message);
    }
    if (json.typeOf($doc) != "map" or not json.has($doc, "/api")) {
        fail($spec.name, "reply is not an object with an `api` field");
    }
    if (json.typeOf($doc, "/api") != "int" or json.asInt($doc, "/api") != API) {
        fail($spec.name, "reply does not speak api " + convert.toString(API));
    }
    def index as map of string to int;
    for (def k in 0..len($chapters)) {
        $index[$chapters[$k].src] = $k;
    }
    def out as list of Chapter init $chapters;
    if (not json.has($doc, "/chapters")) {
        return $out;
    }
    for (def i in 0..json.length($doc, "/chapters")) {
        def at as string init "/chapters/" + convert.toString($i);
        def src as string init json.asString($doc, $at + "/src");
        if (not maps.has($index, $src)) {
            fail($spec.name, "reply rewrites a file the deck does not have: " + $src);
        }
        $out[$index[$src]].content = json.asString($doc, $at + "/content");
    }
    return $out;
}

# padded pads a column with spaces.
func padded(text as string, width as int) {
    def out as string init $text;
    while (len($out) < $width) {
        $out = $out + " ";
    }
    return $out;
}

/**
 * The plan as aligned lines, one per plugin: its name, what will run, and
 * where that came from.
 * @param plan {list of Resolved} the resolved plugins
 * @return {list of string} one line per plugin
 */
export func listing(plan as list of Resolved) {
    def names as int init 0;
    for (def r in $plan) {
        if (len($r.name) > $names) {
            $names = len($r.name);
        }
    }
    def out as list of string;
    for (def r in $plan) {
        def target as string init $r.path;
        if ($target == "") {
            $target = $r.command;
        }
        def line as string init "preprocessor  " + padded($r.name, $names) + "  ->  " + $target +
            "  (" + $r.origin + ")";
        if (len($r.args) > 0) {
            $line = $line + "\n" + padded("", 14 + $names) + "      args: " +
                strings.join($r.args, " ");
        }
        $out[] = $line;
    }
    return $out;
}

/**
 * The plugins worth a warning before a build runs: one that came from `PATH`
 * or from outside the deck cannot be reviewed by reading the deck, and one
 * that is missing will stop the build.
 * @param plan {list of Resolved} the resolved plugins
 * @return {list of string} one warning per such plugin
 */
export func concerns(plan as list of Resolved) {
    def out as list of string;
    for (def r in $plan) {
        if ($r.origin == IN_DECK) {
            continue;
        }
        if ($r.origin == NOWHERE) {
            $out[] = "preprocessor " + $r.name + ": nothing named " +
                strings.join(
                candidates(Plugin{name: $r.name, command: $r.command, args: [], settings: '{}'}),
                " or ") + " was found; the build will stop when it runs";
            continue;
        }
        if ($r.origin == ON_PATH) {
            $out[] = "preprocessor " + $r.name + ": runs " + $r.path +
                ", found on PATH rather than in this deck";
            continue;
        }
        $out[] = "preprocessor " + $r.name + ": runs " + $r.path + ", which is outside this deck";
    }
    return $out;
}

/**
 * The file a URL names under `_generated`, relative to the generated
 * directory, or "" when it names nothing there. A path that climbs out with
 * `..` names nothing.
 * @param url {string} an image target as the Markdown writes it
 * @return {string} the path below `_generated`, or ""
 */
export func generatedPath(url as string) {
    def prefix as string init GENERATED + "/";
    if (not strings.startsWith($url, $prefix)) {
        return "";
    }
    def rest as string init $url[len($prefix)..];
    for (def part in strings.split($rest, "/")) {
        if ($part == "" or $part == "." or $part == "..") {
            return "";
        }
    }
    return $rest;
}

/**
 * The media type of a generated picture, from its name, or "" for a type the
 * slideshow does not embed.
 * @param name {string} the file name
 * @return {string} the media type
 */
export func mediaType(name as string) {
    def lower as string init strings.lower($name);
    if (strings.endsWith($lower, ".svg")) {
        return "image/svg+xml";
    }
    if (strings.endsWith($lower, ".png")) {
        return "image/png";
    }
    if (strings.endsWith($lower, ".jpg") or strings.endsWith($lower, ".jpeg")) {
        return "image/jpeg";
    }
    if (strings.endsWith($lower, ".gif")) {
        return "image/gif";
    }
    return "";
}

/**
 * The picture the PDF draws for a generated file: the PNG beside an SVG,
 * because the PDF draws no SVG, else the file itself.
 * @param rel {string} the path below `_generated`
 * @return {string} the path to load
 */
export func printable(rel as string) {
    if (strings.endsWith(strings.lower($rel), ".svg")) {
        return $rel[..len($rel) - 4] + ".png";
    }
    return $rel;
}
