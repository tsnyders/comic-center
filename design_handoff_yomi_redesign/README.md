# Handoff: Yomi redesign — Sumi first (Cinema and Pastel to follow)

## Overview
Yomi is a manga / manhwa / comic reader (Flutter, Cupertino-flavoured, Android first; repo "comic-center"). This handoff covers a full visual redesign explored as four directions. The product owner liked three: **Sumi**, **Cinema** and **Pastel**. **Build Sumi first**, complete with its animations. Cinema and Pastel are documented here so the theming architecture you build for Sumi can host them later as additional "looks".

Hard requirement from the owner: users must be able to change look and feel in-app — **Theme (Dark / Light)** and **Accent colour**. Build these as runtime user preferences from day one, not compile-time constants.

## About the design files
Everything in `prototypes/` is a **design reference created in HTML** (single-file Design Components with inline styles and a small JS state class). They show intended look, copy, layout and behaviour. They are **not production code** to ship. Recreate them in the app's existing Flutter environment using its established patterns (the current `LUMEN` theme layer, `AppMotion`, existing widgets), or where a widget does not exist, add one following the same conventions. If you build a web companion instead, use the project's existing React/Vue stack; do not port the prototype runtime.

Open `prototypes/redesign-sumi/RedesignSumi.dc.html` in a browser to click through the flow. Tapping the screen chips in the side panel jumps between screens; notes beside the phone describe interaction intent per screen.

## Fidelity
**High-fidelity.** Colours, type sizes, spacing, radii and copy are final for Sumi. Cover art is a placeholder ("COVER" boxes); the real app fills covers from the source. Recreate pixel-precisely, then let the theme layer (dark / light / accent) drive colour.

Sample content uses public-domain works (Hokusai Manga, Chōjū-giga, Sho-chan no Bōken, Nonkina Tōsan, Little Nemo, Krazy Kat, Kwaidan, Journey to the West). Replace with live library data.

---

# Theming architecture (build this first)

One `YomiLook` (direction) × one `ThemeMode` × one `Accent`. Sumi ships first; Cinema and Pastel plug in later as additional looks.

```
YomiTheme {
  look: sumi | cinema | pastel      // ship sumi; enum ready for others
  mode: dark | light                // user setting, default per look
  accent: Color                     // user setting, from the look's curated set
  density: comfortable | compact    // optional, prototype exposes it
  coverSize: small | medium | large // optional, grid columns 4 / 3 / 2 (phone)
  device: phone | tablet            // derived from width, not a setting
}
```

Every colour in the UI resolves through six semantic roles. Never hardcode a hex in a widget.

| Role | Purpose |
|---|---|
| `bg` | canvas |
| `fg` | primary text and primary button fill |
| `fg2` | secondary text |
| `line` | hairlines, borders, dividers |
| `card` | raised surface |
| `ac` | accent: unread, progress, active states, seal |

Provide `onAccent` per accent (Sumi: white on all four accents). Persist `mode` and `accent` (SharedPreferences or the app's existing settings store); apply without restart. The Settings screen row "Theme" and "Accent" must edit these live.

### Tablet
Prototype `device=tablet` uses an 834×1112 frame. Rules: grid columns double (cover size small/medium/large → 8/6/4), horizontal gutter 20→36px, grid gap 14→20px. Everything else reflows. Derive from `MediaQuery` width ≥ 600.

---

# Direction 01 — SUMI (build first)

Japanese ink. Black sumi ink and white paper; kanji brush marks label each surface; a yin-yang is the home button; vermilion appears only as a seal (unread, progress, selection). A washi paper grain overlays every surface.

## Sumi tokens

**Dark (default)**
- bg `#0B0B0A`
- fg `#F2EDE3`
- fg2 `#A9A399`
- line `#2A2825`
- card `#1A1917`

**Light ("Paper")**
- bg `#F2EDE3`
- fg `#0B0B0A`
- fg2 `#6B665C`
- line `#D8D2C6`
- card `#E7E1D5`

**Accents (user-selectable, curated set)**
- Vermilion `#B7282E` (default)
- Indigo `#2B4A7A`
- Gold `#B8892E`
- Jade `#3F7A5E`
- onAccent: `#FFFFFF`

**Reader surface** is always pure black `#000000` with ivory text `#F2EDE3` regardless of theme; page paper is `#F4EFE4`; panel borders `#111111` 3px.

**Washi grain**: full-screen overlay, `mix-blend-mode: overlay`, opacity 0.35, SVG `feTurbulence baseFrequency=0.9 numOctaves=2` tinted to 50% grey. In Flutter: a tiled noise PNG (200×200) in a `BlendMode.overlay` layer at 35% alpha, pointer-transparent.

**Typography**
- Display / kanji: `Yuji Syuku` (Google Fonts; brush face with Latin + kanji). Sizes: 44 (onboarding wordmark), 36 (screen titles), 32 (detail title), 28 (feature title), 26 (continue title / nav kanji), 22 (seal, vertical labels), 20 (chapter numerals). Line-height 1.1.
- Body / UI: `Zen Kaku Gothic New` 400 / 500 / 700. Sizes: 16 (primary button), 15 (row title), 14 (body, row), 13 (secondary), 12 (caption), 11 (overline, letter-spacing 2px, uppercase), 10 (nav label, letter-spacing 1px), 9 (cover badge, letter-spacing 1px).
- Overlines pair Latin + kanji: `LIBRARY · 庫`, `DISCOVER · 探`, `SETTINGS · 設`, `CONTINUE · 続`, `CURATED · 選`, `VOLUMES · 巻`, `ABOUT THE AUTHOR · 作`, `READING · 読`, `APPEARANCE · 姿`, `STORAGE · 蔵`.

**Spacing**: gutter 20 (compact 14), grid gap 14 (compact 8), section spacing 22–26, row padding 14 vertical, card padding 14–16.

**Radius**: 4 (covers, buttons, inputs), 6 (cards, genre tiles), 2 (chips), 50% (dots, yin-yang, avatar). Phone frame 44 (device only).

**Lines**: 1px `line` everywhere; 2px accent border on the seal stamp.

**Shadow**: only on the detail cover (`0 20px 40px rgba(0,0,0,.5)`) and the yin-yang button (`0 10px 30px rgba(0,0,0,.5)`).

## Sumi screens

### 1. Onboarding (genre picker)
Purpose: first launch. Pick genres, continue as guest (sign-in optional).
Layout: column, padding 96 top / 20 sides / 40 bottom.
- Enso mark: 160×160 SVG, two strokes (9px and 3px, `fg`, round caps, 0.9 / 0.5 opacity), kanji 読 centred at 78px Yuji Syuku.
- Wordmark "Yomi" 44px Yuji Syuku; under it `読む · READ` 13px fg2, letter-spacing 2.
- Overline `WHAT DO YOU READ?` 13px fg2, letter-spacing 1, margin-top 40.
- Genre grid 2 columns, gap 14, tiles 112 tall, radius 6, 1px border `line`, padding 14. Content: kanji 40px top-left (闘 Action, 異 Isekai, 笑 Comedy, 宇 Sci-fi), name 14px/700 bottom-left, 22px circle top-right (1.5px border).
  - Selected: border `ac`, background `#1C1213` (dark) / `#FBEFEF` (light), kanji `ac`, circle filled `ac`. Multi-select. Transition all 180ms `cubic-bezier(.16,1,.3,1)`.
- Spacer, then primary button "Continue as guest": 54 tall, radius 6, fill `fg`, text `bg` 16px/700.
- Text link "Sign in to sync across devices" 13px fg2 centred, margin-top 14.

### 2. Library
Layout: scroll view, padding 60 top / 120 bottom (room for nav), gutter 20.
- Header row: overline `LIBRARY · 庫` + title "Your shelf" 36px; right: seal stamp 40×40, 2px `ac` border, radius 4, kanji 読 22px in `ac`, rotated −6°.
- Continue block (tap → Reader at last page): row, gap 16, margin-top 22. Cover 96×140 radius 4 `card` with 1px `line`. Right column bottom-aligned: overline `続 · CONTINUE` in `ac`; title 26px Yuji Syuku; meta "Vol. 3 · Sketch 41 of 62" 13px fg2; progress = hand-drawn stroke: SVG path 220×12, track 3px `line`, fill 5px `ac`, round caps, fill length = progress.
- Filter chips: horizontal scroll, gap 8, margin-top 26. Chip 7×14 padding, radius 2, 13px. Active: fill `fg`, text `bg`, 700. Inactive: 1px `line` border. Labels: "All 8", "Reading", "Finished", "Downloaded".
- Cover grid: columns from coverSize (small 4 / medium 3 / large 2), gap 14, margin-top 22. Tile: 2:3 cover radius 4 `card` + 1px `line`; kanji tag 20px top-left at 70% opacity; unread badge top-right: circle min 18px, fill `ac`, white 10px/700. Below: name 12px/700 (line-height 1.25), author 11px fg2.
- Nav (see Nav below).

### 3. Discover (editorial picks)
- Header overline `DISCOVER · 探`, title "Editor's picks" 36px.
- Search field 44 tall, 1px `line`, radius 4, search icon 18px, placeholder "Search titles, authors" 14px fg2. Margin-top 16.
- Pick of the week plate: 300 tall, radius 6, `card` + 1px `line`, margin-top 22, tap → Detail. Contents: sumi splatter SVG (ellipses displaced by `feTurbulence baseFrequency .04 numOctaves 3` + `feDisplacementMap scale 40`, fill `fg`, opacity .55 — in Flutter use a pre-rendered PNG/SVG asset per theme); vertical title 鳥獣戯画 (writing-mode vertical-rl, 22px, colour `bg`, letter-spacing 4) top-right; bottom-left block: overline `PICK OF THE WEEK` in `ac`, title 28px, blurb 13px fg2 line-height 1.4.
- Overline `CURATED · 選` margin-top 26.
- Curated rows: thumbnail 56×80 radius 3, name 15px/700, author 12px fg2, editor note 12px fg2 (line-height 1.4), single kanji tag 22px `ac` on the right, 1px `line` divider, 14px vertical padding.

### 4. Title detail
- Header plate 340 tall, `card`, 1px bottom `line`. Back button 36px circle `bg` at (16, 56). Cover 150×220 centred, top 70, radius 4, `bg` fill, shadow `0 20px 40px rgba(0,0,0,.5)`. Vertical kanji title 北斎漫画 at right edge (top 64, 20px, fg2, letter-spacing 3).
- Body padding 20 top / 20 sides:
  - Title 32px Yuji Syuku; meta "Katsushika Hokusai · 15 volumes · 1814–1878" 13px fg2.
  - Rating: five 10px dots (4 filled `ac`, 1 outlined 1px `ac`), "4.8" 13px/700, "2,140 ratings" 12px fg2.
  - Buttons row margin-top 18: "Read · Vol. 3" flex 1, 50 tall, radius 4, fill `fg` text `bg` 700; download square 50×50, 1px `line`, download icon 20px.
  - Caption "Download for offline · 1.2 GB · 15 volumes" 11px fg2.
  - Overline `ABOUT THE AUTHOR · 作`; bio 13px fg2 line-height 1.55.
  - Overline `VOLUMES · 巻` with "Newest first" 12px fg2 right.
  - Volume rows: kanji numerals (十五, 十四 …) 20px fg2 width 28; name 14px/700; meta 11px fg2; 8px status dot `ac` when unread. Read rows at 55% opacity. Tap → Reader.

### 5. Reader
- Full black `#000`. Whole page area is a tap target that toggles chrome.
- Page mode: page card `#F4EFE4` radius 2 with 70 top / 14 side / 90 bottom insets; panel grid 2 columns × 3 rows (1.2fr 1fr 1fr), 3px `#111` borders, gap 6, padding 8. (Placeholder for the real page image.)
- Strip mode: continuous vertical scroll of panels on `#F4EFE4`, 3px `#111` separators. For manhwa.
- Progress: 2px line at very top, track `#222`, fill `ac`, width = page/total, transition width 300ms.
- Top chrome: gradient `#000 → transparent`, padding 52 top / 16 sides / 12 bottom. Back (→ Detail) 36px; title 14px/700 "Hokusai Manga"; sub 11px fg2 "Vol. 3 · Sketch N / 62"; right: kanji 巻三 22px `ac`.
- Bottom chrome: gradient transparent → `#000`, padding 14 / 16 / 32. Scrubber: 2px track `#333`, fill `#F2EDE3`, knob 16px circle `#F2EDE3`; page numbers 11px fg2 either side (current, 62). Tap on track seeks. Mode switch centred, margin-top 14: two buttons "Page · 頁" and "Strip · 縦", padding 8×16, radius 2, 12px/700, 1px `#444` border; active fill `#F2EDE3` text `#000`.
- Chrome hidden state: opacity 0, top bar translateY −20, bottom bar translateY +20, pointer-events none. Transition opacity 250ms + transform 250ms `cubic-bezier(.16,1,.3,1)`.

### 6. Settings (full account + prefs)
- Header overline `SETTINGS · 設`, title "You" 36px.
- Account card margin-top 18: 1px `line`, radius 6, padding 16. Avatar 52px circle `fg` with kanji 客 26px in `bg`; "Guest reader" 16px/700; "Sign in to sync progress" 12px fg2; "Sign in" pill 8×14 padding, radius 2, fill `ac`, white 12px/700. After sign-in: name, email, avatar image.
- Groups (overline 11px fg2 letter-spacing 2, then a 1px `line` radius 6 container, rows 14×16 padding, 14px text, 1px `line` dividers, value 13px fg2 right):
  - `READING · 読`: Reading direction (toggle, "Right to left"), Default mode (Page / Strip), Brightness ("Follow system"), Haptics on page turn (toggle).
  - `APPEARANCE · 姿`: **Theme** (Sumi / Paper — edits `mode`), **Accent** (swatch row of the four accents — edits `accent`), Cover size, Density.
  - `STORAGE · 蔵`: Download over Wi-Fi only (toggle), Downloaded ("3.4 GB · 4 titles"), Clear cache ("212 MB").
- Toggle: 40×24, radius 12, on = `ac`, off = `#3A3733` (dark) / `#D8D2C6` (light); knob 18px white, left 3 → 19, 180ms.
- Footer "YOMI 4.0 · SUMI" 11px fg2 letter-spacing 1, centred.

### Nav (Library, Discover, Settings only)
Bottom bar 92 tall, padding 0 40 / 22 bottom, gradient transparent → `bg` from 45%. Three items:
- Left: kanji 探 26px + "Discover" 10px letter-spacing 1. Colour `fg` when active else `fg2`.
- Centre: yin-yang 64px circle raised 14px (translateY −14), shadow `0 10px 30px rgba(0,0,0,.5)`. Ivory `#F2EDE3` and ink `#0B0B0A` halves with two 7px dots. Opacity 1 on Library, 0.7 elsewhere. Rotates 180° when leaving Library and back to 0° on return, 600ms `cubic-bezier(.34,1.56,.64,1)` (spring). Press scale 0.94.
- Right: kanji 設 26px + "Settings".
Reader and Detail hide the nav; Onboarding has none.

## Sumi animations (implement all)
Follow `reference/motion.md` (existing AppMotion tokens) and these specifics:

1. **Screen entrance** (`sumiRise`): each screen's content fades from 0 and rises 10px → 0 over 400ms ease-out (500ms on Onboarding). Only transform + opacity.
2. **Yin-yang nav**: rotation 0° ↔ 180° with the spring curve above, 600ms; opacity 1 ↔ 0.7 on the same beat. Press feedback scale 0.94 over 180ms.
3. **Genre tile select**: border, background, kanji colour and dot fill all transition 180ms `cubic-bezier(.16,1,.3,1)`.
4. **Reader chrome**: tap toggles; 250ms opacity + 20px translate with `cubic-bezier(.16,1,.3,1)`. Exit at least as fast as enter.
5. **Progress line**: width animates 300ms on page change (top line and scrubber fill).
6. **Toggles**: knob slides 180ms; track colour 180ms.
7. **List stagger**: cover grid and rows use the existing `.y-stagger` behaviour (35ms per item, max 6).
8. **Hero cover**: shared-element transition of the cover between Library grid → Detail plate → Reader (Flutter `Hero`), same 4px radius and 2:3 aspect at every end.
9. **Theme / accent change**: crossfade colours 260ms (`--dur-base`), no layout movement.
10. Respect `prefers-reduced-motion`: drop stagger, rotation and scale; keep opacity fades.

## Sumi state
```
screen: onboarding | library | discover | detail | reader | settings
readerMode: page | strip           // persisted per title, default from Settings
chromeVisible: bool                // reader only, resets true on enter
page: int, total: int              // per title progress
selectedGenres: Set<Genre>          // onboarding, persisted
toggles: { rtl, haptics, wifiOnly } // settings
theme: { mode, accent, density, coverSize } // persisted, applied live
```
Data needs: library titles (name, author, kanji tag, unread count, progress), curated picks with editor notes, title detail (bio, rating, volumes with read state, download size), page images / strip segments.

---

# Direction 03 — CINEMA (later)
Warm charcoal, covers run edge to edge in 9:16, condensed uppercase type, film-strip word-only nav with a 2px accent rule over the active item.
- Dark: bg `#1C1917`, fg `#F1EBE2`, fg2 `#B3A99C`, line `#33302B`, card `#2A2521`. Light ("Paper"): bg `#EDE6DC`, fg `#1C1917`, fg2 `#6E645A`, line `#CFC6B8`, card `#DED6CA`.
- Accents: Amber `#E8A33D` (default), Crimson `#C8412B`, Ice `#8FB8C9`, Ivory `#F1EBE2`. onAccent `#1C1917`.
- Type: `Barlow Condensed` 500/700/800 (display, uppercase, tracking 2–5px on labels, −1px on 52–72px titles), `Barlow` 400–600 body. Radius 0 everywhere. Hairline 1px rules instead of cards.
- Signature moments: 560px full-bleed hero on Library, 420px feature still on Discover, 480px cover header on Detail, tick-ruler scrubber (31 ticks, every 5th taller) in the Reader, square toggles and checkboxes.
Reference: `prototypes/redesign-cinema/RedesignCinema.dc.html` (notes per screen in the side panel).

# Direction 04 — PASTEL (later)
Cream canvas, blush lead with sky / mint / butter supporting tints; everything a 24px rounded rect; covers tilt a few degrees like stickers; handwritten headlines.
- Light (default, "Cream"): bg `#FBF6F3`, fg `#3A2E33`, fg2 `#8A7A80`, line `#EADDD8`, card `#FFFFFF`. Dark ("Plum"): bg `#2A2530`, fg `#F4ECEF`, fg2 `#B7A9B0`, line `#4A4150`, card `#372F3B`.
- Accents: Blush `#F6C1CC` (default), Sky `#BFD8F0`, Mint `#CFE8D2`, Butter `#F3E1B8`. Rose `#D9788F` for hearts / on-state toggles. onAccent `#3A2E33`.
- Type: `Gaegu` 700 headlines (40–48px screen titles, 22–28 card titles), `Quicksand` 500–700 body. Radius 24 (cards, buttons, tab bar), 16–20 (covers, tiles), 12–14 (small tiles). Soft shadow `0 4px 14px rgba(80,50,60,.06)` on white tiles.
- Signature moments: floating 72px tab bar with a blush pill behind the active item; blush continue card with a −3° cover; hearts as rating; reader keeps the cream canvas with the page as a white card.
Reference: `prototypes/redesign-pastel/RedesignPastel.dc.html`.

---

## Assets
- Fonts (Google Fonts): Yuji Syuku, Zen Kaku Gothic New (Sumi); Barlow Condensed, Barlow (Cinema); Gaegu, Quicksand (Pastel). Bundle as app fonts.
- Icons: 24-box outline geometry, 2px stroke, round caps (Tabler-style) — search, chevron-left, download, bookmark, play, check. Use the app's existing icon set.
- Washi grain: generate a 200×200 tileable noise PNG (see Sumi tokens) or use `feTurbulence` if rendering SVG.
- Sumi splatter (Discover plate): export one PNG per theme from the prototype SVG, or render with `flutter_svg` using the filter-free fallback (plain ellipses at 55% opacity).
- Yin-yang: SVG in the prototype (`viewBox 0 0 100 100`), draw with `CustomPainter` or ship as SVG.
- Covers: placeholders only; the app supplies real art.

## Files
- `prototypes/redesign-sumi/RedesignSumi.dc.html` — Sumi, all six screens, tappable, with tweaks for device / theme / accent / density / coverSize. **Build this.**
- `prototypes/redesign-cinema/RedesignCinema.dc.html` — Cinema direction.
- `prototypes/redesign-pastel/RedesignPastel.dc.html` — Pastel direction.
- `prototypes/*/support.js`, `ds-base.js` — prototype runtime only; ignore.
- `reference/motion.md` — existing AppMotion duration / curve vocabulary the app already uses; map the animations above onto these tokens.
- `reference/scale.css` — existing spacing, type and motion scale for cross-reference.

## Screenshots
`screenshots/<direction>/0N-<screen>.png` — one capture per screen (onboarding, library, discover, title-detail, reader, settings) for Sumi, Cinema and Pastel. Each shows the phone frame at default tweaks plus the side panel with per-screen interaction notes. Captured at 58% zoom; treat them as visual reference, and use the HTML prototypes for exact measurements.
