# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * The slideshow's own words, in the deck's language.
 *
 * The help panel, the touch bar, the overview, the notes panel and the
 * accessible names of the slides speak the language the deck's `lang:` names,
 * in the eleven languages Grimoire's interface has. Only the primary subtag
 * counts (`pt-BR` is Portuguese), and a language without a table falls back to
 * English, as a page with no `lang:` does.
 *
 * The words are plain text, without `<`, `>` or `&`, because some of them go
 * into the page as they are.
 * @module locale
 * @author mplx <mplx@jennifer-lang.dev>
 * @license LGPL-3.0-only
 */
use strings;
use lists;

/**
 * The slideshow's words in one language.
 * @field slide {string} a slide without a heading is named this, then its number
 * @field overview {string} the accessible name of the slide overview
 * @field shortcuts {string} the accessible name of the keyboard help
 * @field nextSlide {string} help: the next-slide keys
 * @field previousSlide {string} help: the previous-slide keys
 * @field firstLast {string} help: home and end
 * @field jump {string} help: a number, then enter
 * @field overviewKey {string} help: the overview key
 * @field notesKey {string} help: the speaker-notes key
 * @field modeKey {string} help: the light / dark key
 * @field fullscreenKey {string} help: the fullscreen key
 * @field helpKey {string} help: the help key itself
 * @field escKey {string} help: escape
 * @field controls {string} the accessible name of the touch bar
 * @field overviewButton {string} the touch bar's overview button
 * @field notes {string} the notes panel's heading, and its touch-bar button
 * @field modeButton {string} the touch bar's light / dark button
 * @field fullscreenButton {string} the touch bar's fullscreen button
 * @field noNotes {string} what the notes panel shows for a slide without notes
 * @field untitled {string} the page title of a deck with no title at all
 * @field notesMoveKey {string} help: the key that moves the speaker notes
 */
export def struct Words {
    slide as string,
    overview as string,
    shortcuts as string,
    nextSlide as string,
    previousSlide as string,
    firstLast as string,
    jump as string,
    overviewKey as string,
    notesKey as string,
    modeKey as string,
    fullscreenKey as string,
    helpKey as string,
    escKey as string,
    controls as string,
    overviewButton as string,
    notes as string,
    modeButton as string,
    fullscreenButton as string,
    noNotes as string,
    untitled as string,
    notesMoveKey as string
};

/**
 * The languages with a table of their own, by primary subtag.
 * @return {list of string} the codes `words` knows
 */
export func languages() {
    return ["en", "de", "es", "fr", "it", "ja", "nl", "pl", "pt", "ru", "zh"];
}

/**
 * The primary subtag of a language tag, lower-cased: `pt-BR` gives `pt`.
 * @param tag {string} a BCP 47 tag, as a deck's `lang:` writes it
 * @return {string} the language code, "" for an empty tag
 */
export func primary(tag as string) {
    def bare as string init strings.lower(strings.trim($tag));
    def cut as string init strings.replace($bare, "_", "-");
    def parts as list of string init strings.split($cut, "-");
    return $parts[0];
}

# one builds a table from its twenty words, in the field order of `Words`.
func one(w as list of string) {
    return Words{
        slide: $w[0],
        overview: $w[1],
        shortcuts: $w[2],
        nextSlide: $w[3],
        previousSlide: $w[4],
        firstLast: $w[5],
        jump: $w[6],
        overviewKey: $w[7],
        notesKey: $w[8],
        modeKey: $w[9],
        fullscreenKey: $w[10],
        helpKey: $w[11],
        escKey: $w[12],
        controls: $w[13],
        overviewButton: $w[14],
        notes: $w[15],
        modeButton: $w[16],
        fullscreenButton: $w[17],
        noNotes: $w[18],
        untitled: $w[19],
        notesMoveKey: $w[20]
    };
}

/**
 * The slideshow's words for a deck's `lang:`.
 * @param tag {string} the deck's language tag, "" for none
 * @return {Words} that language's words, or English
 */
export func words(tag as string) {
    match (primary($tag)) {
        when "de" {
            return one([
                "Folie",
                "Folienübersicht",
                "Tastenkürzel",
                "nächste Folie",
                "vorige Folie",
                "erste / letzte Folie",
                "zu einer Folie springen",
                "Übersicht",
                "Sprechernotizen",
                "heller / dunkler Modus",
                "Vollbild",
                "diese Hilfe",
                "Overlay schließen oder zurück",
                "Steuerung der Präsentation",
                "Übersicht",
                "Sprechernotizen",
                "Hell oder dunkel",
                "Vollbild",
                "Keine Notizen zu dieser Folie.",
                "Folien",
                "Sprechernotizen verschieben"
            ]);
        }
        when "es" {
            return one([
                "Diapositiva",
                "Vista general de las diapositivas",
                "Atajos de teclado",
                "diapositiva siguiente",
                "diapositiva anterior",
                "primera / última diapositiva",
                "ir a una diapositiva",
                "vista general",
                "notas del orador",
                "modo claro / oscuro",
                "pantalla completa",
                "esta ayuda",
                "cerrar un panel o volver",
                "Controles de la presentación",
                "Vista general",
                "Notas del orador",
                "Modo claro u oscuro",
                "Pantalla completa",
                "No hay notas para esta diapositiva.",
                "Diapositivas",
                "mover las notas del orador"
            ]);
        }
        when "fr" {
            return one([
                "Diapositive",
                "Vue d'ensemble des diapositives",
                "Raccourcis clavier",
                "diapositive suivante",
                "diapositive précédente",
                "première / dernière diapositive",
                "aller à une diapositive",
                "vue d'ensemble",
                "notes de l'orateur",
                "mode clair / sombre",
                "plein écran",
                "cette aide",
                "fermer un panneau ou revenir",
                "Commandes du diaporama",
                "Vue d'ensemble",
                "Notes de l'orateur",
                "Mode clair ou sombre",
                "Plein écran",
                "Pas de notes pour cette diapositive.",
                "Diapositives",
                "déplacer les notes de l'orateur"
            ]);
        }
        when "it" {
            return one([
                "Diapositiva",
                "Panoramica delle diapositive",
                "Scorciatoie da tastiera",
                "diapositiva successiva",
                "diapositiva precedente",
                "prima / ultima diapositiva",
                "vai a una diapositiva",
                "panoramica",
                "note del relatore",
                "modalità chiara / scura",
                "schermo intero",
                "questo aiuto",
                "chiudi un pannello o torna indietro",
                "Controlli della presentazione",
                "Panoramica",
                "Note del relatore",
                "Modalità chiara o scura",
                "Schermo intero",
                "Nessuna nota per questa diapositiva.",
                "Diapositive",
                "spostare le note del relatore"
            ]);
        }
        when "ja" {
            return one([
                "スライド",
                "スライド一覧",
                "キーボードショートカット",
                "次のスライド",
                "前のスライド",
                "最初 / 最後のスライド",
                "スライドへ移動",
                "一覧",
                "発表者ノート",
                "ライト / ダークモード",
                "全画面",
                "このヘルプ",
                "パネルを閉じる、または戻る",
                "スライドショーの操作",
                "一覧",
                "発表者ノート",
                "ライトまたはダークモード",
                "全画面",
                "このスライドにはノートがありません。",
                "スライド",
                "発表者ノートを移動"
            ]);
        }
        when "nl" {
            return one([
                "Dia",
                "Overzicht van de dia's",
                "Sneltoetsen",
                "volgende dia",
                "vorige dia",
                "eerste / laatste dia",
                "naar een dia springen",
                "overzicht",
                "sprekersnotities",
                "lichte / donkere modus",
                "volledig scherm",
                "deze hulp",
                "een paneel sluiten of teruggaan",
                "Bediening van de presentatie",
                "Overzicht",
                "Sprekersnotities",
                "Lichte of donkere modus",
                "Volledig scherm",
                "Geen notities bij deze dia.",
                "Dia's",
                "sprekersnotities verplaatsen"
            ]);
        }
        when "pl" {
            return one([
                "Slajd",
                "Przegląd slajdów",
                "Skróty klawiszowe",
                "następny slajd",
                "poprzedni slajd",
                "pierwszy / ostatni slajd",
                "przejdź do slajdu",
                "przegląd",
                "notatki prelegenta",
                "tryb jasny / ciemny",
                "pełny ekran",
                "ta pomoc",
                "zamknij panel lub wróć",
                "Sterowanie prezentacją",
                "Przegląd",
                "Notatki prelegenta",
                "Tryb jasny lub ciemny",
                "Pełny ekran",
                "Brak notatek do tego slajdu.",
                "Slajdy",
                "przesuń notatki prelegenta"
            ]);
        }
        when "pt" {
            return one([
                "Slide",
                "Visão geral dos slides",
                "Atalhos de teclado",
                "próximo slide",
                "slide anterior",
                "primeiro / último slide",
                "ir para um slide",
                "visão geral",
                "notas do apresentador",
                "modo claro / escuro",
                "tela cheia",
                "esta ajuda",
                "fechar um painel ou voltar",
                "Controles da apresentação",
                "Visão geral",
                "Notas do apresentador",
                "Modo claro ou escuro",
                "Tela cheia",
                "Sem notas para este slide.",
                "Slides",
                "mover as notas do apresentador"
            ]);
        }
        when "ru" {
            return one([
                "Слайд",
                "Обзор слайдов",
                "Сочетания клавиш",
                "следующий слайд",
                "предыдущий слайд",
                "первый / последний слайд",
                "перейти к слайду",
                "обзор",
                "заметки докладчика",
                "светлый / тёмный режим",
                "полный экран",
                "эта справка",
                "закрыть панель или вернуться",
                "Управление презентацией",
                "Обзор",
                "Заметки докладчика",
                "Светлый или тёмный режим",
                "Полный экран",
                "Нет заметок к этому слайду.",
                "Слайды",
                "переместить заметки докладчика"
            ]);
        }
        when "zh" {
            return one([
                "幻灯片",
                "幻灯片概览",
                "键盘快捷键",
                "下一张幻灯片",
                "上一张幻灯片",
                "第一张 / 最后一张幻灯片",
                "跳转到幻灯片",
                "概览",
                "演讲者备注",
                "浅色 / 深色模式",
                "全屏",
                "此帮助",
                "关闭浮层或返回",
                "幻灯片控制",
                "概览",
                "演讲者备注",
                "浅色或深色模式",
                "全屏",
                "此幻灯片没有备注。",
                "幻灯片",
                "移动演讲者备注"
            ]);
        }
        else {
            return one([
                "Slide",
                "Slide overview",
                "Keyboard shortcuts",
                "next slide",
                "previous slide",
                "first / last slide",
                "jump to a slide",
                "overview",
                "speaker notes",
                "light / dark mode",
                "fullscreen",
                "this help",
                "close an overlay, or go back",
                "Slideshow controls",
                "Overview",
                "Speaker notes",
                "Light or dark mode",
                "Fullscreen",
                "No notes for this slide.",
                "Slides",
                "move the speaker notes"
            ]);
        }
    }
}

/**
 * Whether a language has a table of its own rather than English.
 * @param tag {string} a language tag
 * @return {bool} true when `words` speaks it
 */
export func knows(tag as string) {
    return lists.contains(languages(), primary($tag));
}
