# Themes, ratios, and transitions

```sh
cantrip themes
```

```text
themes:
  plain            light  Black on white with a blue accent; the safe choice for a room you have not seen.
  midnight         dark   Near-black with a soft blue accent; good in a dark room, hard on a sunlit one.
  solar            light  The warm Solarized-light ground with a gold accent.
  contrast         dark   Pure black, pure white, yellow accent; for a bad projector or a large room.
  carbon           light  Graphite and teal, dark-first; built for long technical reference.
  carbon-dark      dark   The dark palette of carbon.
  ember            light  High-contrast mono-neutral with an orange accent; wide measure.
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

Pick one in the deck's front matter, or override it per run:

```markdown
---
theme: nordic-dark
ratio: 16:9
transition: slide
---
```

```sh
cantrip build talk.md --theme solar --ratio 4:3 --transition zoom
```

An unknown name is refused by name, with the known ones listed, rather than
quietly falling back to a default you did not ask for.

## The themes

A theme is a palette, three font stacks, and a corner radius. Each one is a
complete look, the way a projected deck is a single fixed design: there is no
automatic light/dark switch, because the room decides that, not the laptop.

### Cantrip's own

| Theme | Polarity | Looks like |
| ----- | -------- | ---------- |
| `plain` | light | black on white, blue accent. The default, and the safe choice for a room you have not seen. |
| `midnight` | dark | near-black with a soft blue accent. Good in a dark room, hard on a sunlit one. |
| `solar` | light | the warm Solarized-light ground with a gold accent. |
| `contrast` | dark | pure black, pure white, yellow accent. For maximum legibility, a bad projector, or a large room. |

### Matched to Grimoire

The rest are the ten themes of [Grimoire](https://grimoire.jennifer-lang.dev/),
the Jennifer book builder, with the same names and the same colours - so a
talk can wear the look of the manual it sits beside. A Grimoire theme has a
light and a dark palette and picks between them with its `mode`; here each comes
as two themes, `name` for the light palette and `name-dark` for the dark one.

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
or `theme: nordic-dark` for a dark room. As in Grimoire, headings take the
palette's heading colour - near the text colour - and the accent marks links,
rules, callouts, and the progress bar. Cantrip's own four keep headings in their
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

**The page stays white.** A dark theme's background is not painted into the PDF,
because the PDF is the artifact that gets printed, and a black page costs a
cartridge and reads worse on paper. Text in the PDF is black throughout. A
Grimoire-matched theme prints with its light palette, dark variant or not, as
Grimoire's own PDF does.

**The shades are print shades.** `midnight`'s and `contrast`'s code panels are
near-black, chosen to sit on a dark slide; behind black text on paper they would
make code unreadable. So every theme carries a second, light shade for print -
used behind code, callouts, quotes, and table headers - and a quote rule that
shows on white. The light themes use the same colours for both.

**Headings print black.** The interpreter's PDF renderer draws all text in one
colour, so the theme's accent stays on screen. Headings keep their size, though:
each slide is laid out at two thirds of its page and scaled up, so a heading
stands above the body text exactly as the renderer designed it.

The result is that a `midnight` deck gives you a dark slideshow and a
light, legible handout from one source, which is usually what you want.

| | HTML | PDF |
| - | ---- | --- |
| Background | the theme's | white |
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

Themes live in `src/theme.j`: add a `Theme` to the list `all()` returns, and
the tests in `src/theme_test.j` will hold the
new entry to the same contract as the others. They check that every field is
filled, that every colour parses as hex, that a dark palette really is
light-on-dark, that the print shade is light enough for black text, and that
the print quote rule shows on white - so a theme
that passes is a theme that works in both outputs.

The stylesheet itself is one template in `theme.j` with `%name%` placeholders
that `css()` substitutes, so a new theme needs no CSS of its own.
