# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * White-box tests for `locale.j`, run by `jennifer test src/locale_test.j`.
 * @module locale_test
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */
use testing;

# every field of a table, in order, so a test can look at all twenty
func all(w as Words) {
    return [
        $w.slide,
        $w.overview,
        $w.shortcuts,
        $w.nextSlide,
        $w.previousSlide,
        $w.firstLast,
        $w.jump,
        $w.overviewKey,
        $w.notesKey,
        $w.modeKey,
        $w.fullscreenKey,
        $w.helpKey,
        $w.escKey,
        $w.controls,
        $w.overviewButton,
        $w.notes,
        $w.modeButton,
        $w.fullscreenButton,
        $w.noNotes,
        $w.untitled
    ];
}

# Every language fills every word, and no word carries markup characters,
# because some go into the page as they are.
func testEveryLanguageHasEveryWord() {
    for (def lang in languages()) {
        def got as list of string init all(words($lang));
        testing.assertEqual(len($got), 20);
        for (def w in $got) {
            testing.assertTrue(strings.trim($w) != "");
            testing.assertFalse(strings.contains($w, "<") or strings.contains($w, ">") or
                strings.contains($w, "&"));
        }
    }
    testing.assertEqual(len(languages()), 11);
}

func testTheLanguagesDiffer() {
    testing.assertEqual(words("de").notes, "Sprechernotizen");
    testing.assertEqual(words("fr").slide, "Diapositive");
    testing.assertEqual(words("ja").fullscreenButton, "全画面");
    testing.assertEqual(words("en").noNotes, "No notes for this slide.");
}

# Only the primary subtag counts, and an unknown language is English.
func testTagsAndFallback() {
    testing.assertEqual(primary(" pt-BR "), "pt");
    testing.assertEqual(primary("zh_Hant"), "zh");
    testing.assertEqual(primary(""), "");
    testing.assertEqual(words("pt-BR").slide, "Slide");
    testing.assertEqual(words("de-AT").untitled, "Folien");
    testing.assertEqual(words("sv").slide, "Slide");
    testing.assertEqual(words("").overview, "Slide overview");
    testing.assertTrue(knows("DE"));
    testing.assertFalse(knows("sv"));
}
