# Working on Cantrip

## Layout

```text
cantrip/
├── bin/cantrip           the launcher (shebang; `bin` in deck.toml)
├── src/                  every module, with a co-located *_test.j overlay
│   ├── slides.j            the input format: Markdown in, a Deck out
│   ├── theme.j             palettes, stage geometry, the stylesheet
│   ├── htmlout.j           Deck -> one self-contained HTML slideshow
│   ├── pdfout.j            Deck -> a paginated PDF
│   └── cli.j               arguments, files, dispatch, exit codes
├── scripts/
│   ├── check.sh            the whole gate, in one command
│   ├── docblock-check.j    doc coverage and drift
│   └── install-jennifer.sh the interpreter CI pins: a release, or a commit
├── docs/                 this book
├── examples/sample.md    a worked deck, built by the gate
├── deck.toml             the manifest
└── grimoire.toml         how this book is built
```

The launcher is a thin adapter: it hands `os.ARGS` to `cli.run` and turns the
code it returns into an exit status. All the logic, and all the tests, live in
`src/`.

## The shape of it

Data flows one way, and only one module does I/O.

```text
Markdown  ->  slides.parse  ->  Deck  ->  htmlout.render  ->  string
                                      ->  pdfout.render   ->  bytes
```

`slides.j` owns the input format and renders nothing. `theme.j` holds values
only. `htmlout.j` and `pdfout.j` take a `Deck` and return a string or bytes, and
neither opens a file. `cli.j` is the only module that reads or writes anything,
so every failure that depends on the filesystem happens in one place with one
message and one exit code.

That is also what makes the renderers testable: a test builds a `Deck` from a
string and asserts on the output, with no temporary files involved. The
`pdfout` module takes its images as pre-loaded bytes for the same reason, and
exposes `imageUrls` so `cli.j` knows what to load - the same split the
interpreter's own `markdown` module makes.

## The gate

```sh
./scripts/check.sh
```

That runs, in order: formatting, lint, docblocks, the structural rule that every
module has an overlay and every overlay a module, the rule that every exported
name is reached from its overlay, every overlay, and a real build of
`examples/sample.md` whose outputs are checked for their magic bytes. CI runs
the same script, so a green run locally is a green run there.

The export-coverage rule is a floor rather than proof of a good test - calling a
function once satisfies it - but it catches the case that actually happens: a
new export landing with no test beside it.

The pieces, if you want them one at a time:

```sh
jennifer fmt -w src/*.j scripts/*.j bin/cantrip    # format in place
jennifer lint src/*.j scripts/*.j bin/cantrip      # suspect patterns
jennifer run scripts/docblock-check.j                # doc coverage and drift
for t in src/*_test.j; do jennifer test "$t"; done   # the overlays
```

## Conventions

The project follows the [Jennifer style
guide](https://docs.jennifer-lang.dev/user-guide/style-guide.html) as
`jennifer fmt` produces it, and the gate enforces it. Three rules beyond
formatting:

**Every committed `.j` file opens with the two-line SPDX header**, license then
copyright, with one blank line before the first code line.

**Every exported construct carries a `/** ... */` doc comment**, and every file
carries an `@module` preamble. `scripts/docblock-check.j` fails the build on a
missing summary, a missing preamble, or drift between a `@param` and the real
signature - so a stale doc is a caught bug rather than a silent one.

**Every module under `src/` has a co-located `src/MODULE_test.j`.** This is not
a preference: `jennifer test` finds the module under test by stripping `_test`
from the overlay's own path, so an overlay anywhere else would look for a module
beside itself and fail. Co-location is also what gives an overlay access to the
module's private names, and what the deck specification requires of anything
published.

An overlay inherits the module's `use` and `import` namespaces but not more, so
an overlay that needs `maps` or `binary` declares it itself.

## Writing tests

An overlay is `use testing;` plus `func test*` methods. Module names are
called unqualified, private ones included.

```jennifer
use testing;

func testIsSeparator() {
    testing.assertTrue(isSeparator("---"));
    testing.assertFalse(isSeparator("***"));
}
```

This build's `testing.assertThrows` takes a **zero-argument** method name, so
for a throwing call with arguments the overlays use a small helper that catches
in place and returns the error's `kind`:

```jennifer
func themeFailure(name as string) {
    try {
        theme($name);
    } catch (e) {
        return $e.kind;
    }
    return "";
}

func testThemeUnknown() {
    testing.assertEqual(themeFailure("nope"), "theme");
    testing.assertEqual(themeFailure("midnight"), "");
}
```

Asserting the success case in the same test is what keeps the helper honest - a
helper that always returned `""` would otherwise pass.

> [!TIP]
> Braces in a cooked string are interpolation slots, so a test that needs a
> literal `{` uses a raw string: `strings.split($got, '{')`. The same goes for
> any Markdown fixture holding an attribute list.

## Building this book

The documentation is a [Grimoire](https://grimoire.jennifer-lang.dev/) book.
`docs/SUMMARY.md` is the outline and `grimoire.toml` the configuration:

```sh
grimoire build --config grimoire.toml        # the site, into docs-site/
grimoire build --config grimoire.toml --pdf  # the site plus a printable book
grimoire serve --config grimoire.toml        # preview on :8080
```

Grimoire needs Jennifer 0.25.0 or newer, the same floor as `cantrip` itself.
Any `-dev` build bypasses the floor.

## Releasing

The version lives in two places that must agree: `VERSION` in `src/cli.j` and
`version` in `deck.toml`. The release workflow checks that both match the tag
and refuses the release if they do not, so a mislabelled release is caught
before it is published.

```sh
# 1. bump both, and let the gate confirm nothing broke
./scripts/check.sh

# 2. commit, tag, push
git commit -am "release 0.2.0"
git tag 0.2.0
git push origin main --tags
```

Tags are plain SemVer (`0.2.0`), which is what `jvc app install --version`
matches against. Do not move a published tag: an installed app records the
commit its tag pointed at, so moving it makes the repository's history disagree
with what people are running.
