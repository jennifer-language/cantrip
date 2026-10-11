#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Report doc-comment coverage and drift across the project's Jennifer source.
 *
 * The `docblock` module reports rather than enforces, so this is the half that
 * decides what is fatal: any diagnostic, or any exported construct with no doc
 * comment, exits non-zero. That makes it a pre-commit hook and the CI gate the
 * deck specification asks for.
 *
 * Usage: `jennifer run scripts/docblock-check.j [path...]`, where a path is a
 * `.j` file or a directory to walk. With no path it checks `src/` and `bin/`.
 * @module docblockCheck
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */

use io;
use fs;
use os;
use path;
use strings;
use lists;
use convert;

import "docblock.j" as docblock;

/** Paths checked when the caller names none. */
def const DEFAULT_PATHS as list of string init ["src", "bin", "scripts"];

/**
 * Every `.j` file under a path, or the path itself when it is a file.
 * @param target {string} a file or directory
 * @return {list of string} the files to check, in walk order
 */
func sources(target as string) {
    def out as list of string init [];
    if (fs.isFile($target)) {
        $out[] = $target;
        return $out;
    }
    if (not fs.isDir($target)) {
        return $out;
    }
    for (def found in fs.walk($target)) {
        if (not $found.isDir and isJennifer($found.path)) {
            $out[] = $found.path;
        }
    }
    return $out;
}

/**
 * Whether a path is Jennifer source this check should read.
 *
 * `bin/cantrip` has no extension - it is run through its shebang - so an
 * extension test alone would skip the launcher.
 * @param p {string} the path to test
 * @return {bool} true for a `.j` file or an extensionless file under `bin`
 */
func isJennifer(p as string) {
    if (path.ext($p) == ".j") {
        return true;
    }
    return path.ext($p) == "" and path.base(path.dir($p)) == "bin";
}

/**
 * Whether a file is a test overlay.
 *
 * An overlay documents its own test methods, which are not a public surface,
 * so it is checked for drift but not for coverage.
 * @param p {string} the path to test
 * @return {bool} true when the file is a `MODULE_test.j` overlay
 */
func isOverlay(p as string) {
    return strings.endsWith(path.stem($p), "_test");
}

/**
 * Count the constructs in a file that carry no summary.
 * @param doc {docblock.FileDoc} the parsed documentation
 * @return {int} how many exported constructs are undocumented
 */
func undocumented(doc as docblock.FileDoc) {
    def n as int init 0;
    for (def one in $doc.funcs) {
        if ($one.exported and strings.trim($one.summary) == "") {
            $n = $n + 1;
        }
    }
    for (def one in $doc.structs) {
        if ($one.exported and strings.trim($one.summary) == "") {
            $n = $n + 1;
        }
    }
    for (def one in $doc.enums) {
        if ($one.exported and strings.trim($one.summary) == "") {
            $n = $n + 1;
        }
    }
    for (def one in $doc.consts) {
        if ($one.exported and strings.trim($one.summary) == "") {
            $n = $n + 1;
        }
    }
    return $n;
}

/**
 * Check one file and print its line of the report.
 * @param p {string} the file to check
 * @return {int} how many problems the file has
 */
func checkFile(p as string) {
    def doc as docblock.FileDoc init docblock.parse(fs.readString($p));
    def problems as int init 0;
    def notes as list of string init [];
    for (def d in $doc.diagnostics) {
        if ($d.severity != "info") {
            $problems = $problems + 1;
        }
        $notes[] = "    line " + convert.toString($d.line) + ": [" + $d.severity +
            "] " + $d.message;
    }
    if (strings.trim($doc.module.summary) == "") {
        $problems = $problems + 1;
        $notes[] = "    no @module preamble";
    }
    if (not isOverlay($p)) {
        def bare as int init undocumented($doc);
        if ($bare > 0) {
            $problems = $problems + 1;
            $notes[] = "    " + convert.toString($bare) +
                " exported construct(s) with no summary";
        }
    }
    def mark as string init "ok  ";
    if ($problems > 0) {
        $mark = "WARN";
    }
    io.printf(
        "%s %s (%d func, %d struct, %d const)\n",
        $mark,
        $p,
        len($doc.funcs),
        len($doc.structs),
        len($doc.consts));
    for (def note in $notes) {
        io.printf("%s\n", $note);
    }
    return $problems;
}

/**
 * Check every path given, or the defaults, and report the total.
 * @param targets {list of string} files and directories to check
 * @return {int} 0 when everything is clean, 1 otherwise
 */
func check(targets as list of string) {
    def files as list of string init [];
    for (def target in $targets) {
        for (def found in sources($target)) {
            if (not lists.contains($files, $found)) {
                $files[] = $found;
            }
        }
    }
    if (len($files) == 0) {
        io.printf("docblock-check: no Jennifer source found in %s\n", strings.join($targets, ", "));
        return 1;
    }
    def problems as int init 0;
    for (def one in lists.sort($files)) {
        $problems = $problems + checkFile($one);
    }
    io.printf("\n%d file(s), %d problem(s)\n", len($files), $problems);
    if ($problems > 0) {
        return 1;
    }
    return 0;
}

/**
 * The paths to check: the ones given on the command line, else the defaults.
 * @return {list of string} the targets
 */
func targets() {
    def out as list of string init [];
    for (def i as int init 1; $i < len(os.ARGS); $i = $i + 1) {
        $out[] = os.ARGS[$i];
    }
    if (len($out) == 0) {
        return DEFAULT_PATHS;
    }
    return $out;
}

exit check(targets());
