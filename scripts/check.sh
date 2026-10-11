#!/bin/sh
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# The whole gate, in the order a failure is cheapest to read: formatting,
# then lint, then docs, then tests, then a real build of the example deck.
# This is what CI runs, so a green run here is a green run there.
#
# Set JENNIFER=/path/to/jennifer to test against a specific interpreter.

set -eu

JENNIFER="${JENNIFER:-jennifer}"
cd "$(dirname "$0")/.."

SOURCES="src/*.j scripts/*.j bin/cantrip"
status=0

step() {
    printf '\n==> %s\n' "$1"
}

step "jennifer version"
"$JENNIFER" version

step "fmt --check"
# shellcheck disable=SC2086
if unformatted="$("$JENNIFER" fmt -l $SOURCES)" && [ -z "$unformatted" ]; then
    echo "all files formatted"
else
    echo "$unformatted" | sed 's/^/  needs fmt: /'
    echo "run: $JENNIFER fmt -w $SOURCES"
    status=1
fi

step "lint"
# shellcheck disable=SC2086
"$JENNIFER" lint $SOURCES || status=1

step "docblocks"
"$JENNIFER" run scripts/docblock-check.j || status=1

step "tests"
for overlay in src/*_test.j; do
    module="${overlay%_test.j}.j"
    if [ ! -f "$module" ]; then
        echo "orphaned overlay with no module: $overlay"
        status=1
    fi
done
for module in src/*.j; do
    case "$module" in
        *_test.j) continue ;;
    esac
    if [ ! -f "${module%.j}_test.j" ]; then
        echo "module with no test overlay: $module"
        status=1
    fi
done
# Every exported name must at least be reached from its overlay. This is a
# coverage floor, not proof of a good test, but it catches the common case:
# a new export landing with no test beside it.
for module in src/*.j; do
    case "$module" in
        *_test.j) continue ;;
    esac
    overlay="${module%.j}_test.j"
    [ -f "$overlay" ] || continue
    missing=""
    for name in $(sed -n 's/^export func \([A-Za-z][A-Za-z0-9]*\).*/\1/p' "$module"); do
        grep -q "[^A-Za-z0-9]$name(" "$overlay" || missing="$missing $name"
    done
    for name in $(sed -n 's/^export def const \([A-Z][A-Z0-9_]*\).*/\1/p' "$module"); do
        grep -q "[^A-Za-z0-9_]$name[^A-Za-z0-9_]" "$overlay" || missing="$missing $name"
    done
    if [ -n "$missing" ]; then
        echo "$module: exports not reached from $overlay:$missing"
        status=1
    fi
done

for overlay in src/*_test.j; do
    "$JENNIFER" test "$overlay" || status=1
done

step "build the example deck"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
./bin/cantrip build examples/sample.md -o "$out/sample" -v || status=1
for artifact in "$out/sample.html" "$out/sample.pdf"; do
    if [ -s "$artifact" ]; then
        echo "  ok $(basename "$artifact") ($(wc -c <"$artifact" | tr -d ' ') bytes)"
    else
        echo "  MISSING $artifact"
        status=1
    fi
done
head -c 5 "$out/sample.pdf" | grep -q '%PDF-' || {
    echo "  sample.pdf is not a PDF"
    status=1
}
grep -q '^<!doctype html>' "$out/sample.html" || {
    echo "  sample.html is not an HTML document"
    status=1
}

if [ "$status" -eq 0 ]; then
    printf '\n==> all checks passed\n'
else
    printf '\n==> FAILED\n'
fi
exit "$status"
