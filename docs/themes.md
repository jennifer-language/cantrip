# Themes, modes, ratios, and transitions

```sh
cantrip themes
```

```text
themes (each light and dark):
  plain            light  Black on white with a blue accent; the safe choice for a room you have not seen.
                   dark   Near-black with a soft blue accent; good in a dark room, hard on a sunlit one.
  solar            light  The warm Solarized-light ground with a gold accent.
                   dark   The deep Solarized-dark ground with the same gold accent.
  ...
ratios:
  16:9             1280x720 px, 960x540 pt
  16:10            1280x800 px, 960x600 pt
  4:3              1024x768 px, 792x594 pt
transitions:
  none
  fade (default)
  slide
  zoom
```

Pick them in the deck's front matter, or override them per run:

```markdown
---
theme: nordic
mode: dark
ratio: 16:9
transition: slide
---
```

```sh
cantrip build talk.md --theme solar --mode dark --ratio 4:3 --transition zoom
```

An unknown name is refused by name, with the known ones listed, rather than
quietly falling back to a default you did not ask for.

## The themes

A theme is a light and a dark palette, three font stacks, and a corner radius.
The fonts and the radius are the same in both palettes, so switching the mode
changes the colours and nothing else.

## Light and dark mode

The deck's author picks the theme and the mode the slideshow opens in:
`mode: light` (the default) or `mode: dark`, or `--mode` for one run. Whoever
watches can switch it: <kbd>m</kbd> flips between light and dark, and
`?mode=light` or `?mode=dark` in the URL opens the page in that mode. The room
decides what reads best, so the choice stays with the person in front of the
screen. Both palettes are in the page, so the switch needs no reload and works
offline.

Cantrip 0.1 had a separate theme per mode (`nordic-dark`, `midnight`). Those
names are refused now with the spelling to use instead: `theme: nordic` with
`mode: dark`, and `theme: plain` with `mode: dark` for `midnight`.

### Cantrip's own

| Theme | Light | Dark |
| ----- | ----- | ---- |
| `plain` | black on white, blue accent. The default, and the safe choice for a room you have not seen. | near-black with a soft blue accent. Good in a dark room, hard on a sunlit one. |
| `solar` | the warm Solarized-light ground with a gold accent. | the deep Solarized-dark ground with the same gold. |
| `contrast` | pure white, pure black, deep-blue accent. For a bad projector in a bright room. | pure black, pure white, yellow accent. For a bad projector or a large room. |

### Matched to Grimoire

The rest are the ten themes of [Grimoire](https://grimoire.jennifer-lang.dev/),
the Jennifer book builder, with the same names and the same colours - so a
talk can wear the look of the manual it sits beside. A Grimoire theme has a
light and a dark palette and picks between them with its `mode`, and so does a
cantrip theme.

| Theme | Fonts | Looks like |
| ----- | ----- | ---------- |
| `carbon` | sans | graphite and teal, designed dark-first |
| `ember` | sans | high-contrast neutral with an orange accent and near-square corners |
| `grimoire` | serif headings, sans body | warm parchment and ink with a rust accent; Grimoire's default |
| `ivy` | serif | cream paper and forest green |
| `meridian` | sans | deep navy on white with a steel-blue accent, and a navy dark mode |
| `nordic` | sans | the Nord palette: arctic blue-greys, and a dark mode that is not black |
| `obsidian` | sans | cool slate with a violet accent |
| `orchid` | sans | mauve-tinted paper with a violet-pink accent; the roundest corners |
| `sepia` | serif | yellowed paper and coffee brown, with a dark-brown dark mode |
| `terminal` | monospace | phosphor green; a console on a projector |

So a book built with `theme = "nordic"` pairs with a deck saying `theme: nordic`,
with `mode: dark` for a dark room. As in Grimoire, headings take the
palette's heading colour - near the text colour - and the accent marks links,
rules, callouts, and the progress bar. Cantrip's own three keep headings in their
accent.

Fonts are system stacks - no web font is fetched, so a deck renders identically
offline.

## Ratios

A ratio fixes two things: the slideshow's stage in CSS pixels, and the PDF's
page size in points.

`16:9` is the default and is what a modern projector and nearly every video
call expects. `4:3` is for older fixed installations. `16:10` suits a laptop
screen when the deck is mostly read rather than projected.

The stage is a fixed box scaled to fit the window, so the layout never reflows
between your screen and the room's - what you rehearse is what they see. The
PDF page sizes are that geometry at a comfortable projected size, which is why
`16:9` is 960x540 points rather than a letter page turned sideways: a viewer
shows it full-bleed with no re-fitting.

## How the PDF differs from the screen

The PDF is not a screenshot of the slideshow, and two differences are
deliberate.

**The page stays white.** The PDF always prints the theme's light palette,
whatever mode the slideshow opens in, as Grimoire's own PDF does: the PDF is
the artifact that gets printed, and a black page costs a cartridge and reads
worse on paper. Text in the PDF is black throughout.

**The shades are print shades.** Every palette carries a light shade for print,
used behind code, callouts, quotes, and table headers, and a quote rule that
shows on white; for most light palettes it is the screen colour itself.

**Headings print black.** The interpreter's PDF renderer draws all text in one
colour, so the theme's accent stays on screen. Headings keep their size, though:
each slide is laid out at two thirds of its page and scaled up, so a heading
stands above the body text exactly as the renderer designed it.

The result is that a deck with `mode: dark` gives you a dark slideshow and a
light, legible handout from one source, which is usually what you want.

| | HTML | PDF |
| - | ---- | --- |
| Background | the theme's, in the current mode | white |
| Headings | the theme's accent | black |
| Code panels | the theme's shade | the theme's print shade |
| Speaker notes | embedded, hidden, <kbd>s</kbd> to show | omitted unless `--notes` |
| Slide numbers | bottom right | in the running footer |
| Footer text | bottom left | footer left, else the deck's title |

## Transitions

The HTML slideshow animates between slides. Pick a transition in the front
matter with `transition:`, or per run with `--transition`:

| Transition | Does |
| ---------- | ---- |
| `fade` | cross-fades the two slides. The default. |
| `slide` | pushes the slides sideways: forward comes in from the right, back from the left |
| `zoom` | the old slide grows and fades out while the new one settles in from slightly smaller |
| `none` | switches at once |

A transition takes under half a second and never delays a key press: press
again mid-transition and the deck simply heads for the next slide. Opening a
deck, or reloading it on a slide, shows that slide straight away rather than
animating to it. If the viewer's system asks for reduced motion, every
transition is switched off - that setting wins over the deck's.

The PDF and the browser's print view have no transitions; they are pages.

## Adding a theme

Themes live in `src/theme.j`: add two `Theme`s to the list `all()` returns, a
light and a dark palette under the same name, and the tests in
`src/theme_test.j` will hold the new entry to the same contract as the others.
They check that every name has both palettes with the same fonts and radius,
that every field is filled, that every colour parses as hex, that a dark
palette really is light-on-dark, that the print shade is light enough for black text, and that
the print quote rule shows on white - so a theme
that passes is a theme that works in both outputs.

The stylesheet itself is one template in `theme.j` with `%name%` placeholders
that `css()` substitutes, so a new theme needs no CSS of its own.
