# Yomi design system: how to build with it

Yomi is a manga and manhwa reader for phones. Every design is a 390x844 phone screen unless told otherwise. There is no React component bundle in this project: build screens from plain HTML using the `.y-*` classes and `--` tokens in `styles.css`. Read `styles.css` first; it is the whole vocabulary.

## Setup

- Load `styles.css` once. It imports the fonts and all three token sets.
- Pick a direction by setting `data-theme` on `<html>`: omit it for **Ink** (default), or use `data-theme="print"` or `data-theme="signal"`. One direction per screen. Read `guidelines/directions.md` for what each one means.
- Wrap a screen in `<div class="y-app">` (390x844, clipped, canvas background). For the reader use `<div class="y-app y-app--reader">` (true black).
- Everything is styled through CSS custom properties. Never write a hex colour, pixel radius, shadow or millisecond literal. Use the token.

## Tokens you will use most

- Surfaces: `--canvas`, `--surface-1`, `--surface-2`, `--surface-3`, `--surface-sunken`, `--nav-pill`
- Text: `--text-1` (primary), `--text-2`, `--text-3`, `--text-4`
- Lines: `--border-1` to `--border-4`, `--hairline` (0.75px)
- Interactive colour: `--signal`, `--signal-hover`, `--signal-press`, `--signal-subtle`, `--on-signal`
- Cover-derived colour: `--art`, `--art-subtle`, `--art-line`, `--on-art`. Use for progress bars, unread badges, ambient washes. The app fills it from each cover; the CSS value is a fallback.
- Status: `--unread`, `--downloaded`, `--warning`, `--info`, `--danger`
- Space: `--space-1` (2px) to `--space-12` (64px), `--gutter` (20px), `--grid-gap` (14px)
- Radius: `--radius-xs`, `--radius-sm`, `--radius-cover`, `--radius-md`, `--radius-lg`, `--radius-xl`, `--radius-pill`
- Elevation: `--shadow-1` to `--shadow-4`, `--shadow-float`
- Motion: `--dur-instant`, `--dur-micro`, `--dur-fast`, `--dur-base`, `--dur-page`, `--dur-hero`; `--ease-snap`, `--ease-out`, `--ease-spring`, `--ease-decelerate`; `--scale-press`, `--scale-active`

## Classes

- Type: `.y-display-xl` `.y-display-l` `.y-display-m` `.y-display-s` `.y-hero` `.y-section` `.y-title` `.y-nav-title` `.y-label-xl` `.y-label` `.y-label-sm` `.y-overline` `.y-body-l` `.y-body` `.y-body-s` `.y-caption` `.y-meta` `.y-meta-sm` (mono metadata; add `.y-meta--art` or `.y-meta--signal` to colour it)
- Controls: `.y-btn` (add `.y-btn--ghost`, `.y-btn--art`, `.y-btn--block`, `.y-btn--icon`, `.y-btn--sm`), `.y-chip` (`.is-active`), `.y-chips`, `.y-search`, `.y-tag`, `.y-tags`
- Covers: `.y-cover` with `.y-cover__art` inside, optional `.y-cover__overlay` (title block) and `.y-badge` (unread count). `.y-shelf` for a horizontal row of 84px covers; `.y-grid-2` / `.y-grid-3` for grids.
- Lists: `.y-row` (cover thumb + `.y-row__body` + `.y-row__count`), `.y-chapter` (`.y-chapter__dot`, `.y-chapter__num`, `.y-chapter__body`, `.y-chapter__title`, `.y-chapter__status`; add `.is-read`), `.y-source-row` with `.y-source-row__mark`
- Layout: `.y-page` (gutter padding), `.y-safe-top`, `.y-hero-cover` with `.y-hero-cover__top` and `.y-hero-cover__content`, `.y-sheet` with `.y-grabber`, `.y-card`, `.y-nav` with `.y-nav__item` (`.is-active`)
- Reader: `.y-progress-line`, `.y-reader-top`, `.y-reader-bottom`, `.y-scrubber`, `.y-page-pill`
- Feedback: `.y-press` (scale on press), `.y-stagger` (children rise in with a per-child `--i` index), `.y-progress` (bar, inner `<i>` sets width)
- Icons: 24-box Tabler outline geometry as `<svg class="y-icon"><use href="#i-search"/></svg>`. Copy the `<symbol>` sprite from any preview in `components/`. Sizes: `.y-icon--sm`, `.y-icon--xs`.

## One idiomatic screen

```html
<html data-theme="ink">
<link rel="stylesheet" href="styles.css">
<div class="y-app">
  <section class="y-hero-cover">
    <div class="y-cover__art" style="background:var(--surface-3)"></div>
    <div class="y-hero-cover__content">
      <div class="y-meta y-meta--art">Continue · Ch 142</div>
      <h1 class="y-display-m" style="margin-top:var(--space-4)">Solo Leveling</h1>
      <div class="y-progress" style="margin-top:var(--space-5)"><i style="width:64%"></i></div>
    </div>
  </section>
  <div class="y-page" style="padding-top:var(--space-6)">
    <div class="y-search"><svg class="y-icon y-icon--sm"><use href="#i-search"/></svg><span>Search your library</span></div>
    <div class="y-chips" style="margin-top:var(--space-7)"><span class="y-chip is-active">All</span><span class="y-chip">Reading</span></div>
  </div>
  <nav class="y-nav"><div class="y-nav__item is-active"><svg class="y-icon"><use href="#i-stack"/></svg></div></nav>
</div>
</html>
```

## Where the truth lives

`styles.css` and `tokens/*.css` are the source. `tokens/tokens.json` is the same data in W3C token format. `guidelines/directions.md`, `guidelines/motion.md` and `guidelines/anti-patterns.md` explain the decisions. Each `components/Screens <Direction>/<Screen>/` folder holds a rendered example and a `.prompt.md` describing how it is composed.
