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
# mode: ?mode= and the m key, which must repaint the slide; and touch: a swipe
# or a tap on the right or left third turns the slide, a pinch does not; and
# the touch bar, shown only for a coarse pointer that cannot hover, whose
# buttons open and close the overview and the notes and switch the mode, and
# which fades out after a few seconds and comes back with a tap in the middle;
# and Escape, which closes an overlay first and then goes back to the page the
# slideshow was opened from.
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

# A slide taller than its area (a long table): the script shrinks its content
# to fit and leaves the short slide and the slide number alone.
{
    printf -- '---\ntitle: Fit\n---\n\n# Short\n\n---\n\n## A long table\n\n| Row | Text |\n| --- | --- |\n'
    i=0
    while [ "$i" -lt 10 ]; do
        printf '| %s | some text in a cell |\n' "$i"
        i=$((i + 1))
    done
} > "$work/fit.md"
"$JENNIFER" run bin/cantrip html "$work/fit.md" --out "$work/fit-deck.html" >/dev/null
# The probe: "<short slide> <long slide> <long slide after> <slide number>".
cat > "$work/fit.js" <<'EOF2'
<script>
window.addEventListener("load", function () {
    setTimeout(function () {
        var all = document.querySelectorAll("body > #cantrip-deck > .cantrip-slide");
        var long = all[1];
        var r = [
            all[0].dataset.fit ? "shrunk" : "untouched",
            long.dataset.fit && Number(long.dataset.fit) < 1 ? "shrunk" : "untouched",
            long.scrollHeight <= long.clientHeight + 1 ? "fits" : "overflows",
            long.querySelector(":scope > .cantrip-slide-number").style.zoom === "" ? "number-kept" : "number-zoomed"
        ];
        var o = document.createElement("output");
        o.id = "probe";
        o.textContent = r.join(" ");
        document.body.appendChild(o);
    }, 300);
});
</script>
EOF2
awk -v probe="$work/fit.js" '
    /<\/body>/ { while ((getline line < probe) > 0) print line }
    { print }
' "$work/fit-deck.html" > "$work/fit.html"

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

# The touch probe: the slide after each gesture, starting on slide 2.
touchprobe='<script>
window.addEventListener("load", function () {
    var d = document.querySelector("body > #cantrip-deck");
    var all = Array.prototype.slice.call(d.querySelectorAll(":scope > .cantrip-slide"));
    var w = window.innerWidth;
    var y = window.innerHeight / 2;
    function at() { return String(all.indexOf(d.querySelector(":scope > .cantrip-current")) + 1); }
    function pt(id, x) {
        return new Touch({ identifier: id, target: d, clientX: x, clientY: y });
    }
    function fire(type, touches, changed) {
        d.dispatchEvent(new TouchEvent(type, {
            bubbles: true, cancelable: true, touches: touches, changedTouches: changed
        }));
    }
    function gesture(x0, x1) {
        fire("touchstart", [pt(1, x0)], [pt(1, x0)]);
        fire("touchend", [], [pt(1, x1)]);
        return at();
    }
    var r = [];
    r.push(gesture(w * 0.6, w * 0.3));
    r.push(gesture(w * 0.3, w * 0.6));
    r.push(gesture(w * 0.9, w * 0.9));
    r.push(gesture(w * 0.1, w * 0.1));
    r.push(gesture(w * 0.5, w * 0.5));
    fire("touchstart", [pt(1, w * 0.6)], [pt(1, w * 0.6)]);
    fire("touchstart", [pt(1, w * 0.6), pt(2, w * 0.4)], [pt(2, w * 0.4)]);
    fire("touchend", [pt(2, w * 0.4)], [pt(1, w * 0.2)]);
    fire("touchend", [], [pt(2, w * 0.1)]);
    r.push(at());
    var o = document.createElement("output");
    o.id = "probe";
    o.textContent = r.join(" ");
    document.body.appendChild(o);
});
</script>'
printf '%s\n' "$touchprobe" > "$work/touch.js"
awk -v probe="$work/touch.js" '
    /<\/body>/ { while ((getline line < probe) > 0) print line }
    { print }
' "$work/deck.html" > "$work/touch.html"

# The bar probe: "<bar> <overview> <overview again> <notes> <mode> <bar after
# a middle tap> <after another> <after 3.5 s>". The bar is "hidden" when the
# stylesheet leaves it out, else "shown" or "faded".
barprobe='<script>
window.addEventListener("load", function () {
    var b = document.querySelector("body > #cantrip-touchbar");
    var ov = document.querySelector("body > #cantrip-overview");
    var n = document.querySelector("body > #cantrip-notes");
    var d = document.querySelector("body > #cantrip-deck");
    function press(act) { b.querySelector("[data-act=" + act + "]").click(); }
    function state() {
        if (getComputedStyle(b).display === "none") { return "hidden"; }
        return b.classList.contains("cantrip-shown") ? "shown" : "faded";
    }
    function tapMiddle() {
        var t = new Touch({ identifier: 1, target: d, clientX: window.innerWidth / 2,
            clientY: window.innerHeight / 2 });
        var o = { bubbles: true, cancelable: true };
        o.touches = [t]; o.changedTouches = [t];
        d.dispatchEvent(new TouchEvent("touchstart", o));
        o.touches = [];
        d.dispatchEvent(new TouchEvent("touchend", o));
        return state();
    }
    var r = [state()];
    press("overview");
    r.push(ov.hidden ? "closed" : "open");
    press("overview");
    r.push(ov.hidden ? "closed" : "open");
    press("notes");
    r.push(n.hidden ? "closed" : "open");
    press("mode");
    r.push(document.documentElement.dataset.mode);
    r.push(tapMiddle());
    r.push(tapMiddle());
    window.setTimeout(function () {
        r.push(state());
        var o = document.createElement("output");
        o.id = "probe";
        o.textContent = r.join(" ");
        document.body.appendChild(o);
    }, 3500);
});
</script>'
printf '%s\n' "$barprobe" > "$work/bar.js"
awk -v probe="$work/bar.js" '
    /<\/body>/ { while ((getline line < probe) > 0) print line }
    { print }
' "$work/deck.html" > "$work/bar.html"

# The Escape probe: "<overview after Esc> <left?> <left after a second Esc>"
# without a referrer, then the same with one. A headless file page has no real
# referrer, so the probe sets one and records history.back instead of leaving.
escprobe='<script>
window.addEventListener("load", function () {
    var ov = document.querySelector("body > #cantrip-overview");
    var left = "stayed";
    history.back = function () { left = "back"; };
    function esc() { document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" })); }
    var r = [];
    function round() {
        left = "stayed";
        document.dispatchEvent(new KeyboardEvent("keydown", { key: "o" }));
        esc();
        r.push(ov.hidden ? "closed" : "open");
        r.push(left);
        esc();
        r.push(left);
    }
    round();
    Object.defineProperty(document, "referrer", { get: function () { return "https://example.org/talks/?q=pdf"; } });
    round();
    var o = document.createElement("output");
    o.id = "probe";
    o.textContent = r.join(" ");
    document.body.appendChild(o);
});
</script>'
printf '%s\n' "$escprobe" > "$work/esc.js"

# The fullscreen probe: a headless browser has no real fullscreen, so the probe
# sends the fullscreenchange a browser sends when it leaves fullscreen on Esc by
# itself (Firefox, Safari). "<overview after it> <left?>" with the overview
# open, then "<left?>" with none open, then how often the page went back after
# an Esc key AND a fullscreenchange for the same press (a browser that delivers
# both must not go back twice).
fsprobe='<script>
window.addEventListener("load", function () {
    var ov = document.querySelector("body > #cantrip-overview");
    var backs = 0;
    history.back = function () { backs = backs + 1; };
    Object.defineProperty(document, "referrer", { get: function () { return "https://example.org/talks/"; } });
    function fsExit() { document.dispatchEvent(new Event("fullscreenchange")); }
    var r = [];
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "o" }));
    fsExit();
    r.push(ov.hidden ? "closed" : "open");
    r.push(backs > 0 ? "back" : "stayed");
    fsExit();
    r.push(backs > 0 ? "back" : "stayed");
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    fsExit();
    r.push(String(backs));
    var o = document.createElement("output");
    o.id = "probe";
    o.textContent = r.join(" ");
    document.body.appendChild(o);
});
</script>'
printf '%s\n' "$fsprobe" > "$work/fs.js"
awk -v probe="$work/fs.js" '
    /<\/body>/ { while ((getline line < probe) > 0) print line }
    { print }
' "$work/deck.html" > "$work/fs.html"
awk -v probe="$work/esc.js" '
    /<\/body>/ { while ((getline line < probe) > 0) print line }
    { print }
' "$work/deck.html" > "$work/esc.html"

status=0
check() {
    label="$1"
    size="$2"
    url="$3"
    want="$4"
    # A fifth argument passes extra browser flags, such as a phone's pointer.
    extra="${5:-}"
    got="$("$browser" --headless=new --no-sandbox --disable-gpu --user-data-dir="$work/profile" $extra \
        --window-size="$size" --virtual-time-budget=6000 --dump-dom "$url" 2>/dev/null |
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
check "a slide taller than its area is shrunk to fit" 1280,800 "file://$work/fit.html" \
    "untouched shrunk fits number-kept"
# auto follows the system until m picks the other mode; --force-dark-mode is a
# system that prefers dark.
check "?mode=auto on a light system, m picks dark" 1280,800 "$page?mode=auto" \
    "open closed full 2 fitted none auto dark"
check "?mode=auto on a dark system, m picks light" 1280,800 "$page?mode=auto" \
    "open closed full 2 fitted none auto light" "--force-dark-mode"
check "long notes stop at 30% of the window" 1280,800 "file://$work/long-probe.html" \
    "open closed full 1 capped none light dark"
check "swipes and taps turn the slide, a pinch does not" 390,844 \
    "file://$work/touch.html" "3 2 3 2 2 2"
# primaryPointerType=2 is coarse, primaryHoverType=1 is none: a phone.
phone="--blink-settings=primaryPointerType=2,primaryHoverType=1"
check "the touch bar works on a phone" 390,844 "file://$work/bar.html?notes=0" \
    "shown open closed open dark faded shown faded" "$phone"
# A ChromeOS tablet: the main pointer is a touchpad (fine, 4; hover, 2), but
# a finger (coarse, 2) is among the pointers, so the bar shows at the start.
tablet="--blink-settings=primaryPointerType=4,primaryHoverType=2,availablePointerTypes=6,availableHoverTypes=3"
check "a touch screen beside a touchpad shows the bar" 1280,800 \
    "file://$work/bar.html?notes=0" "shown open closed open dark faded shown faded" "$tablet"
# With a mouse alone the bar stays out until a touch, which a tap on the
# middle is, and that tap shows it.
check "with a mouse the bar waits for a touch" 1280,800 "file://$work/bar.html?notes=0" \
    "hidden open closed open dark shown faded faded"
# history.length is above 1 in a headless tab that loaded the page, so back.
check "Esc closes an overlay, then goes back only with a referrer" 1280,800 \
    "file://$work/esc.html?notes=0" "closed stayed stayed closed stayed back"
check "Esc in fullscreen ends the presentation, once" 1280,800 \
    "file://$work/fs.html?notes=0" "closed stayed back 1"
exit "$status"
