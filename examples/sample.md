---
title: Cantrip
author: mplx
date: 2026-10-10
theme: grimoire-dark
ratio: 16:9
transition: slide
subject: A worked example deck
keywords: jennifer, slides, markdown
lang: en
---

# Cantrip

One Markdown file in. A slideshow and a PDF out.

<!-- notes:
Open with why this exists: a deck belongs in version control, as text.
Keep this slide to about twenty seconds.
-->

---

## The format is just Markdown

Slides are separated by a line of three dashes. Everything else is ordinary
Markdown, so the file still reads as a document.

- **Bold**, *italic*, `code`, ~~struck~~ and ==highlighted== text
- Lists, nested lists, and task lists
- Tables, code blocks, blockquotes, images
- Key caps: <kbd>Ctrl</kbd> <kbd>C</kbd>

<!-- notes: Stress that the file is readable even without the tool. -->

---

## Front matter sets the deck up

```yaml
---
title: Cantrip
author: mplx
theme: grimoire-dark
ratio: 16:9
transition: slide
---
```

A `--theme`, `--ratio`, or `--transition` on the command line overrides the
file.

---

## Lists and tasks

- A first point
  - with a sub-point
  - and another
- A second point

<!-- notes: Nested lists indent under the parent item. -->

---

## Tasks and tables

- [x] Parse the Markdown
- [x] Render the HTML
- [x] Render the PDF
- [ ] Present it

| Output | Command | Default name |
| :----- | :------ | :----------- |
| HTML | `cantrip html talk.md` | `talk.html` |
| PDF | `cantrip pdf talk.md` | `talk.pdf` |
| Both | `cantrip build talk.md` | both of the above |

---

## Code reads as code

```jennifer
use io;

func greet(name as string) {
    io.printf("hello, %s\n", $name);
}

greet("ada");
```

Fenced blocks keep their language, so the HTML carries a
`class="language-jennifer"` for a highlighter to pick up.

---

## Callouts

> [!NOTE]
> A blockquote that opens with an alert marker becomes a callout.

> [!WARNING] One slide, one page
> A slide that outgrows its page continues onto the next, and the tool says so.

---

## Themes that match your manual

Cantrip ships the ten themes of the Grimoire book builder under their own
names, each light and dark, so a talk can wear the look of its docs:

| In `grimoire.toml` | In the deck |
| :----------------- | :---------- |
| `theme = "grimoire"` | `theme: grimoire` or `theme: grimoire-dark` |
| `theme = "nordic"` | `theme: nordic` or `theme: nordic-dark` |
| `theme = "terminal"` | `theme: terminal` or `theme: terminal-dark` |

`cantrip themes` lists all 24. This deck wears `grimoire-dark`, like the manual
it came with.

<!-- notes:
Try `cantrip build examples/sample.md --theme nordic` to show the same deck
in another theme. The PDF stays light whichever palette the screen uses.
-->

---

## Transitions

The slideshow animates between slides. This deck asks for `slide`:

- `fade` cross-fades, and is the default
- `slide` pushes sideways, from the right going forward
- `zoom` scales the old slide out and the new one in
- `none` switches at once

> [!TIP]
> A viewer whose system asks for reduced motion gets no animation at all.

---

## Speaker notes

Notes live in an HTML comment, so every other Markdown renderer ignores them:

```markdown
<!-- notes: what to say here, and what to skip -->
```

Press <kbd>s</kbd> in the slideshow to see them. Pass `--notes` to print them
into the PDF.

<!-- notes:
This is the slide about notes, which is itself carrying a note.
Mention that notes never reach the audience's copy unless asked for.
-->

---

## Driving the slideshow

| Key | Does |
| :-- | :--- |
| <kbd>Right</kbd> <kbd>Space</kbd> | next slide |
| <kbd>Left</kbd> | previous slide |
| <kbd>o</kbd> | overview |
| <kbd>s</kbd> | speaker notes |
| <kbd>f</kbd> | fullscreen |
| <kbd>?</kbd> | every shortcut |

---

# Thank you

The source of this deck is `examples/sample.md`.

<!-- notes: Stop here and take questions. -->
