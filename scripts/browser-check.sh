#!/bin/sh
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# Run the slideshow's start options in a real browser: headless Chromium (or
# Chrome) loads a built deck with a probe script appended, which reads the
# notes panel and the current slide, presses s, and reads them again. Covers
# the front-matter default, ?notes=0 / ?notes=1, the #<slide> hash, the
# narrow-window rule, the s key, the panel's height (as tall as the longest
# notes, capped at 30% of the window, with the deck ending above it), and the
# mode: ?mode= and the m key, which must repaint the slide.
#
# Skips (exit 0) when no Chromium is installed. Set JENNIFER and CHROMIUM to
# pick the interpreter and the browser.

set -eu

JENNIFER="${JENNIFER:-jennifer}"
cd "$(dirname "$0")/.."

browser="${CHROMIUM:-}"
if [ -z "$browser" ]; then
    for b in chromium chromium-browser google-chrome google-chrome-stable; do
        if command -v "$b" >/dev/null 2>&1; then
            browser="$b"
            break
        fi
    done
fi
if [ -z "$browser" ]; then
    echo "browser check: no Chromium found, skipped"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/deck.md" <<'EOF'
---
title: Start options
notes: open
slide: 2
---

# One

<!-- notes: first -->

---

## Two

<!-- notes: second -->

---

## Three

<!-- notes: third -->
EOF
"$JENNIFER" run bin/cantrip html "$work/deck.md" --out "$work/deck.html" >/dev/null

# Notes longer than the cap: the panel stops at 30% of the window and scrolls.
{
    printf -- '---\ntitle: Long notes\nnotes: open\n---\n\n# Long\n\n<!-- notes:\n'
    i=0
    while [ "$i" -lt 60 ]; do
        printf 'Paragraph %s of the notes.\n\n' "$i"
        i=$((i + 1))
    done
    printf -- '-->\n'
} > "$work/long.md"
"$JENNIFER" run bin/cantrip html "$work/long.md" --out "$work/long.html" >/dev/null

# The probe: "<notes at load> <notes after s> <deck space after s> <slide>
# <panel at load> <panel after s> <mode at load> <mode after m>". A panel is "none" when closed with the deck
# at full height, "fitted" when shorter than the cap with the deck ending at its
# top, "capped" when at 30% of the window, and "stale" otherwise.
probe='<script>
window.addEventListener("load", function () {
    var n = document.querySelector("body > #cantrip-notes");
    var d = document.querySelector("body > #cantrip-deck");
    var all = Array.prototype.slice.call(d.querySelectorAll(":scope > .cantrip-slide"));
    function panel() {
        if (n.hidden) { return d.style.bottom === "" ? "none" : "stale"; }
        var h = n.offsetHeight;
        var cap = window.innerHeight * 0.3;
        if (d.style.bottom !== h + "px") { return "stale"; }
        if (Math.abs(h - cap) <= 1) { return "capped"; }
        return h < cap ? "fitted" : "stale";
    }
    var r = [n.hidden ? "closed" : "open"];
    var before = panel();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "s" }));
    r.push(n.hidden ? "closed" : "open");
    r.push(d.classList.contains("cantrip-notes-open") ? "reserved" : "full");
    r.push(String(all.indexOf(d.querySelector(":scope > .cantrip-current")) + 1));
    r.push(before);
    r.push(panel());
    var cur = d.querySelector(":scope > .cantrip-current");
    var bg = getComputedStyle(cur).backgroundColor;
    r.push(document.documentElement.dataset.mode);
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "m" }));
    var repainted = getComputedStyle(cur).backgroundColor !== bg;
    r.push(document.documentElement.dataset.mode + (repainted ? "" : "-unpainted"));
    var o = document.createElement("output");
    o.id = "probe";
    o.textContent = r.join(" ");
    document.body.appendChild(o);
});
</script>'
printf '%s\n' "$probe" > "$work/probe.js"
awk -v probe="$work/probe.js" '
    /<\/body>/ { while ((getline line < probe) > 0) print line }
    { print }
' "$work/deck.html" > "$work/probe.html"
awk -v probe="$work/probe.js" '
    /<\/body>/ { while ((getline line < probe) > 0) print line }
    { print }
' "$work/long.html" > "$work/long-probe.html"

status=0
check() {
    label="$1"
    size="$2"
    url="$3"
    want="$4"
    got="$("$browser" --headless=new --no-sandbox --disable-gpu --user-data-dir="$work/profile" \
        --window-size="$size" --virtual-time-budget=3000 --dump-dom "$url" 2>/dev/null |
        sed -n 's#.*<output id="probe">\([^<]*\)</output>.*#\1#p')"
    if [ "$got" = "$want" ]; then
        echo "  ok   $label: $got"
    else
        echo "  FAIL $label: want \"$want\", got \"$got\""
        status=1
    fi
}

page="file://$work/probe.html"
check "front matter: notes open, slide 2" 1280,800 "$page" "open closed full 2 fitted none light dark"
check "?notes=0 overrides the deck" 1280,800 "$page?notes=0" "closed open reserved 2 none fitted light dark"
check "?notes=yes is ignored" 1280,800 "$page?notes=yes" "open closed full 2 fitted none light dark"
check "#3 overrides the start slide" 1280,800 "$page#3" "open closed full 3 fitted none light dark"
check "narrow window starts closed" 390,844 "$page" "closed open reserved 2 none fitted light dark"
check "?notes=1 opens it there anyway" 390,844 "$page?notes=1" "open closed full 2 fitted none light dark"
check "?mode=dark opens in dark, m back to light" 1280,800 "$page?mode=dark" \
    "open closed full 2 fitted none dark light"
check "?mode=sepia is ignored" 1280,800 "$page?mode=sepia" "open closed full 2 fitted none light dark"
check "long notes stop at 30% of the window" 1280,800 "file://$work/long-probe.html" \
    "open closed full 1 capped none light dark"
exit "$status"
