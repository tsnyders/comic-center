#!/usr/bin/env python3
"""Generate Yomi design-system preview cards into ds-bundle/components.

One template per screen, rendered for each direction (ink / print / signal).
Re-run after editing templates or styles.css:  python .design-sync/gen_previews.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "ds-bundle"
OUT = ROOT / "components"

THEMES = {
    "ink":    "Ink",
    "print":  "Print",
    "signal": "Signal",
}

ICONS = """<svg style="display:none" xmlns="http://www.w3.org/2000/svg">
<symbol id="i-search" viewBox="0 0 24 24"><circle cx="10" cy="10" r="7"/><path d="M21 21l-6-6"/></symbol>
<symbol id="i-chevron-left" viewBox="0 0 24 24"><path d="M15 6l-6 6l6 6"/></symbol>
<symbol id="i-chevron-right" viewBox="0 0 24 24"><path d="M9 6l6 6l-6 6"/></symbol>
<symbol id="i-x" viewBox="0 0 24 24"><path d="M18 6L6 18M6 6l12 12"/></symbol>
<symbol id="i-dots" viewBox="0 0 24 24"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></symbol>
<symbol id="i-bookmark" viewBox="0 0 24 24"><path d="M18 7v14l-6-4l-6 4V7a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4z"/></symbol>
<symbol id="i-play" viewBox="0 0 24 24"><path d="M7 4v16l13-8z"/></symbol>
<symbol id="i-download" viewBox="0 0 24 24"><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2M7 11l5 5l5-5M12 4v12"/></symbol>
<symbol id="i-settings" viewBox="0 0 24 24"><circle cx="14" cy="6" r="2"/><path d="M4 6h8M16 6h4"/><circle cx="8" cy="12" r="2"/><path d="M4 12h2M10 12h10"/><circle cx="17" cy="18" r="2"/><path d="M4 18h11M19 18h1"/></symbol>
<symbol id="i-compass" viewBox="0 0 24 24"><path d="M8 16l2-6l6-2l-2 6l-6 2"/><circle cx="12" cy="12" r="9"/></symbol>
<symbol id="i-stack" viewBox="0 0 24 24"><path d="M12 4l-8 4l8 4l8-4l-8-4M4 12l8 4l8-4M4 16l8 4l8-4"/></symbol>
<symbol id="i-filter" viewBox="0 0 24 24"><path d="M4 4h16v2.172a2 2 0 0 1-.586 1.414L15 12v7l-6 2v-8.5L4.52 7.572A2 2 0 0 1 4 6.227V4z"/></symbol>
<symbol id="i-check" viewBox="0 0 24 24"><path d="M5 12l5 5L20 7"/></symbol>
<symbol id="i-clock" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/></symbol>
<symbol id="i-plus" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></symbol>
</svg>"""


def icon(name, cls=""):
    return f'<svg class="y-icon {cls}"><use href="#i-{name}"/></svg>'


def nav(active):
    items = [("stack", 0), ("compass", 1), ("download", 2), ("settings", 3)]
    out = []
    for name, i in items:
        cls = "y-nav__item is-active" if i == active else "y-nav__item"
        out.append(f'<div class="{cls}">{icon(name)}</div>')
    return '<nav class="y-nav">' + "".join(out) + "</nav>"


def page(theme, group, title, body, width=390, height=844):
    return f"""<!-- @dsCard group="{group}" -->
<!doctype html>
<html lang="en" data-theme="{theme}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · {THEMES[theme]}</title>
<link rel="stylesheet" href="../../../styles.css">
<style>html,body{{background:transparent}} body{{display:grid;place-items:start}} </style>
</head>
<body>
{ICONS}
{body}
</body>
</html>
"""


# ---------------------------------------------------------------- screens

def library(theme):
    hero_label = "Continue · Ch 142"
    return f"""
<div class="y-app">
  <div class="y-scroll">
    <section class="y-hero-cover">
      <div class="y-cover__art y-art-1"></div>
      <div class="y-hero-cover__top"><span class="y-meta" style="color:var(--text-1);letter-spacing:3px;font-weight:700">Yomi</span>{icon("filter","y-icon--sm")}</div>
      <div class="y-hero-cover__content">
        <div class="y-meta y-meta--art">{hero_label}</div>
        <h1 class="y-display-m" style="margin-top:8px">Solo Leveling</h1>
        <div style="display:flex;align-items:center;gap:12px;margin-top:14px">
          <div class="y-progress" style="flex:1"><i style="width:64%"></i></div><span class="y-meta-sm">64%</span>
        </div>
      </div>
    </section>

    <div class="y-page" style="padding-top:16px">
      <div class="y-search">{icon("search","y-icon--sm")}<span>Search your library</span></div>
    </div>

    <div style="margin-top:20px">
      <div class="y-page"><div class="y-overline" style="margin-bottom:12px">Continue reading</div></div>
      <div class="y-shelf">
        <div class="y-cover y-art-2" style="--art-tile:#23304F"><div class="y-cover__overlay"><div class="y-label-xl" style="font-size:12px">Omniscient Reader</div></div></div>
        <div class="y-cover y-art-3" style="--art-tile:#5A2433"><div class="y-cover__overlay"><div class="y-label-xl" style="font-size:12px">Jujutsu Kaisen</div></div><span class="y-badge">12</span></div>
        <div class="y-cover y-art-4" style="--art-tile:#1F5A52"><div class="y-cover__overlay"><div class="y-label-xl" style="font-size:12px">Vinland Saga</div></div></div>
        <div class="y-cover y-art-5" style="--art-tile:#8A5A12"><div class="y-cover__overlay"><div class="y-label-xl" style="font-size:12px">Dungeon Meshi</div></div><span class="y-badge">3</span></div>
      </div>
    </div>

    <div class="y-page" style="margin-top:20px">
      <div class="y-chips">
        <span class="y-chip is-active">All 128</span><span class="y-chip">Reading</span><span class="y-chip">Completed</span><span class="y-chip">Manhwa</span>
      </div>
    </div>

    <div class="y-page" style="margin-top:20px">
      <h2 class="y-section" style="margin-bottom:12px">Your collection</h2>
      <div class="y-stagger" style="display:flex;flex-direction:column;gap:12px">
        <div class="y-row" style="--i:0"><div class="y-cover y-art-6"></div><div class="y-row__body"><span class="y-label-xl">Berserk</span><span class="y-label-sm">Kentaro Miura · Ch 375</span></div><span class="y-row__count">4 new</span>{icon("chevron-right","y-icon--sm y-text-3")}</div>
        <div class="y-row" style="--i:1"><div class="y-cover y-art-7"></div><div class="y-row__body"><span class="y-label-xl">Tower of God</span><span class="y-label-sm">SIU · Ch 611</span></div>{icon("chevron-right","y-icon--sm y-text-3")}</div>
        <div class="y-row" style="--i:2"><div class="y-cover y-art-8"></div><div class="y-row__body"><span class="y-label-xl">Chainsaw Man</span><span class="y-label-sm">Tatsuki Fujimoto · Ch 182</span></div><span class="y-row__count">1 new</span>{icon("chevron-right","y-icon--sm y-text-3")}</div>
      </div>
    </div>
  </div>
  {nav(0)}
</div>"""


def detail(theme):
    return f"""
<div class="y-app">
  <section class="y-hero-cover" style="height:390px">
    <div class="y-cover__art y-art-4"></div>
    <div class="y-hero-cover__top">
      <button class="y-btn y-btn--ghost y-btn--sm">{icon("chevron-left","y-icon--sm")} Back</button>
      <button class="y-btn y-btn--ghost y-btn--sm y-btn--icon" style="width:36px">{icon("bookmark","y-icon--sm")}</button>
    </div>
  </section>
  <div class="y-sheet">
    <div class="y-grabber"></div>
    <h1 class="y-display-s">Jujutsu Kaisen</h1>
    <div class="y-meta" style="margin-top:10px">Gege Akutami · Ongoing · 263 ch</div>
    <p class="y-body-s" style="margin:14px 0 0">A boy swallows a cursed talisman and becomes host to a powerful curse. He enrols at a school for sorcerers to find the rest of its fingers.</p>
    <div class="y-tags" style="margin-top:14px"><span class="y-tag">Action</span><span class="y-tag">Supernatural</span><span class="y-tag">Shonen</span></div>
    <div style="display:flex;gap:10px;margin-top:18px">
      <button class="y-btn y-btn--block">{icon("play","y-icon--sm")} Continue · Ch 142</button>
      <button class="y-btn y-btn--ghost y-btn--icon">{icon("download","y-icon--sm")}</button>
    </div>
    <div style="display:flex;justify-content:space-between;align-items:baseline;margin-top:24px">
      <h2 class="y-section" style="font-size:18px">Chapters</h2>
      <div class="y-chips"><span class="y-chip is-active" style="height:28px;padding:0 10px;font-size:11px">All</span><span class="y-chip" style="height:28px;padding:0 10px;font-size:11px">Unread</span></div>
    </div>
    <div style="margin-top:6px">
      <div class="y-chapter"><span class="y-chapter__dot"></span><span class="y-chapter__num">263</span><div class="y-chapter__body"><div class="y-chapter__title">The Final Battle</div><div class="y-caption">2 days ago</div></div><span class="y-chapter__status">{icon("download","y-icon--sm")}</span></div>
      <div class="y-chapter"><span class="y-chapter__dot"></span><span class="y-chapter__num">262</span><div class="y-chapter__body"><div class="y-chapter__title">Inhuman Makyo, Shinjuku Showdown</div><div class="y-caption">1 week ago</div></div><span class="y-chapter__status">{icon("clock","y-icon--sm")}</span></div>
      <div class="y-chapter is-read"><span class="y-chapter__dot is-read"></span><span class="y-chapter__num">261</span><div class="y-chapter__body"><div class="y-chapter__title">Hidden Inventory</div><div class="y-caption">2 weeks ago</div></div><span class="y-chapter__status is-done">{icon("check","y-icon--sm")}</span></div>
      <div class="y-chapter is-read"><span class="y-chapter__dot is-read"></span><span class="y-chapter__num">260</span><div class="y-chapter__body"><div class="y-chapter__title">Shibuya Incident</div><div class="y-caption">3 weeks ago</div></div><span class="y-chapter__status is-done">{icon("check","y-icon--sm")}</span></div>
    </div>
  </div>
</div>"""


def reader(theme):
    # abstract page panels, clearly placeholders
    panels = """
    <div class="y-panel" style="left:12px;top:110px;width:220px;height:300px;background:#1A1A24"></div>
    <div class="y-panel" style="left:240px;top:110px;width:138px;height:160px;background:#242433"></div>
    <div class="y-panel" style="left:240px;top:278px;width:138px;height:132px;background:#20202B"></div>
    <div class="y-panel" style="left:12px;top:420px;width:120px;height:230px;background:#22222E"></div>
    <div class="y-panel" style="left:140px;top:420px;width:238px;height:230px;background:#191922"></div>
    """
    return f"""
<div class="y-app y-app--reader">
  <div class="y-progress-line" style="width:35%"></div>
  {panels}
  <div class="y-reader-top">{icon("x")}<span class="y-nav-title">Ch. 142 · Arise</span>{icon("dots")}</div>
  <div class="y-reader-bottom">
    <div class="y-scrubber"><i style="width:35%"></i><b style="left:35%"></b></div>
    <div style="display:flex;justify-content:space-between;margin-top:8px"><span class="y-meta" style="color:rgba(255,255,255,.6)">Page 7</span><span class="y-meta" style="color:rgba(255,255,255,.6)">of 20</span></div>
  </div>
</div>"""


def browse(theme):
    return f"""
<div class="y-app">
  <div class="y-scroll">
    <div class="y-safe-top"></div>
    <div class="y-page">
      <div class="y-meta y-meta--signal">Discover</div>
      <h1 class="y-display-m" style="margin-top:6px">Browse</h1>
      <div class="y-search" style="margin-top:16px">{icon("search","y-icon--sm")}<span>Search all sources</span></div>
    </div>
    <div class="y-page" style="margin-top:22px">
      <h2 class="y-section" style="margin-bottom:12px">Featured</h2>
    </div>
    <div class="y-shelf" style="gap:12px">
      <div class="y-source-card y-grad-teal" style="width:250px;flex:none"><div class="y-title">MangaDex</div><div class="y-caption">Multi-language · 50,000+ titles</div></div>
      <div class="y-source-card y-grad-ember" style="width:250px;flex:none"><div class="y-title">Asura Scans</div><div class="y-caption">Manhwa · English</div></div>
    </div>
    <div class="y-page" style="margin-top:24px">
      <h2 class="y-section" style="margin-bottom:4px">Installed</h2>
      <div class="y-source-row"><div class="y-source-row__mark y-grad-teal"></div><div class="y-row__body"><span class="y-label-xl">MangaDex</span><span class="y-label-sm">v5 · Multi-language</span></div>{icon("chevron-right","y-icon--sm y-text-3")}</div>
      <div class="y-source-row"><div class="y-source-row__mark y-grad-ember"></div><div class="y-row__body"><span class="y-label-xl">Asura Scans</span><span class="y-label-sm">English · Manhwa</span></div>{icon("chevron-right","y-icon--sm y-text-3")}</div>
      <div class="y-source-row"><div class="y-source-row__mark y-grad-rose"></div><div class="y-row__body"><span class="y-label-xl">Reaper Scans</span><span class="y-label-sm">English · Manhwa</span></div>{icon("chevron-right","y-icon--sm y-text-3")}</div>
      <h2 class="y-section" style="margin:24px 0 4px">Available</h2>
      <div class="y-source-row"><div class="y-source-row__mark y-grad-azure"></div><div class="y-row__body"><span class="y-label-xl">ComicK</span><span class="y-label-sm">Multi-language</span></div><button class="y-btn y-btn--sm">Get</button></div>
      <div class="y-source-row"><div class="y-source-row__mark y-grad-gold"></div><div class="y-row__body"><span class="y-label-xl">ReadComicOnline</span><span class="y-label-sm">English · Comics</span></div><button class="y-btn y-btn--sm">Get</button></div>
    </div>
  </div>
  {nav(1)}
</div>"""


SCREENS = {
    "Library": library,
    "TitleDetail": detail,
    "Reader": reader,
    "Browse": browse,
}

# ------------------------------------------------------------- foundations

def colors(theme):
    sw = [
        ("Canvas", "var(--canvas)", "--canvas"), ("Surface 1", "var(--surface-1)", "--surface-1"),
        ("Surface 2", "var(--surface-2)", "--surface-2"), ("Surface 3", "var(--surface-3)", "--surface-3"),
        ("Signal", "var(--signal)", "--signal"), ("Art (per cover)", "var(--art)", "--art"),
        ("Unread", "var(--unread)", "--unread"), ("Downloaded", "var(--downloaded)", "--downloaded"),
        ("Warning", "var(--warning)", "--warning"), ("Danger", "var(--danger)", "--danger"),
    ]
    boxes = "".join(
        f'<div class="y-swatch" style="background:{v};color:{"var(--on-signal)" if n in ("Signal",) else "var(--text-1)"}"><b>{n}</b><small>{tok}</small></div>'
        for n, v, tok in sw)
    text = "".join(
        f'<div class="y-spec-row"><span class="y-meta-sm">{tok}</span><span style="color:{v};font-size:18px;font-weight:600">The quick brown fox</span></div>'
        for tok, v in [("--text-1", "var(--text-1)"), ("--text-2", "var(--text-2)"), ("--text-3", "var(--text-3)"), ("--text-4", "var(--text-4)")])
    return f'<div class="y-spec" style="width:760px"><h2 class="y-section">Colour · {THEMES[theme]}</h2><p class="y-body-s">Surfaces, the one interactive signal, and the art slot the app fills from each cover.</p><div class="y-swatches">{boxes}</div><div style="margin-top:24px">{text}</div></div>'


def typography(theme):
    rows = [
        ("y-display-xl", "56 / 0.92 / -2.5", "Arise"),
        ("y-display-l", "44 / 0.96 / -2.0", "Solo Leveling"),
        ("y-display-m", "36 / 1.0 / -1.5", "Jujutsu Kaisen"),
        ("y-display-s", "28 / 1.05 / -1.0", "Omniscient Reader"),
        ("y-section", "22 / 700", "Your collection"),
        ("y-title", "18 / 600", "MangaDex"),
        ("y-label-xl", "14 / 600", "Berserk · Kentaro Miura"),
        ("y-body-l", "16 / 1.65", "A boy swallows a cursed talisman and becomes host to a powerful curse."),
        ("y-body", "15 / 1.6", "Chapter lists, metadata prose, settings copy."),
        ("y-body-s", "13 / 1.55", "Secondary descriptions and helper text."),
        ("y-caption", "11", "2 days ago"),
        ("y-overline", "10 / 600 / +0.8 upper", "Continue reading"),
        ("y-meta", "Mono 11 / +1.2 upper", "Ch 142 · Ongoing · 263 ch"),
        ("y-meta-sm", "Mono 9 / +1.0 upper", "64%"),
    ]
    body = "".join(f'<div class="y-spec-row"><span class="y-meta-sm">.{c} · {spec}</span><span class="{c}">{t}</span></div>' for c, spec, t in rows)
    return f'<div class="y-spec" style="width:860px"><h2 class="y-section">Type · {THEMES[theme]}</h2><p class="y-body-s">One family, Hanken Grotesk, carries display and interface. Space Mono is the metadata voice. The direction changes weight and case, not the family.</p>{body}</div>'


def spacing(theme):
    sp = "".join(f'<div class="y-spec-row"><span class="y-meta-sm">--space-{i} · {v}px</span><div class="y-spacing-bar" style="width:{v*3}px"></div></div>' for i, v in enumerate([2,4,6,8,12,16,20,24,32,40,48,64], start=1))
    rad = "".join(f'<div style="text-align:center"><div class="y-radius-box" style="border-radius:var(--radius-{r})"></div><div class="y-meta-sm" style="margin-top:6px">--radius-{r}</div></div>' for r in ["xs","sm","cover","md","lg","xl","pill"])
    sh = "".join(f'<div style="text-align:center"><div class="y-radius-box" style="box-shadow:var(--shadow-{s});background:var(--surface-1);border-radius:var(--radius-md)"></div><div class="y-meta-sm" style="margin-top:12px">--shadow-{s}</div></div>' for s in ["1","2","3","4","float"])
    return f'<div class="y-spec" style="width:760px"><h2 class="y-section">Space, radius, elevation · {THEMES[theme]}</h2><p class="y-body-s">4pt grid shared by every direction. Radius and shadow are where the directions diverge: Ink is soft and layered, Print uses ink rules, Signal is flat and square.</p>{sp}<div style="display:flex;gap:28px;margin-top:28px;flex-wrap:wrap">{rad}</div><div style="display:flex;gap:36px;margin-top:36px;padding:20px 8px 8px;flex-wrap:wrap">{sh}</div></div>'


def motion(theme):
    durs = [("instant", 80, "toggle, checkbox"), ("micro", 120, "icon swap, badge pop"), ("fast", 180, "press, chip select"), ("base", 260, "card reveal, panel"), ("page", 380, "push / pop, sheet"), ("hero", 520, "hero entrance, cover zoom"), ("epic", 700, "rare full-screen")]
    rows = "".join(f'<div class="y-spec-row"><span class="y-meta-sm">--dur-{n} · {ms}ms</span><span class="y-body-s">{use}</span></div>' for n, ms, use in durs)
    curves = "".join(f'<div class="y-spec-row"><span class="y-meta-sm">--ease-{n}</span><div style="width:240px"><div class="y-motion-dot" style="animation-timing-function:var(--ease-{n})"></div></div><span class="y-body-s">{use}</span></div>' for n, use in [("snap","default UI"),("out","panels settle"),("spring","active icon pop"),("decelerate","fling settle")])
    return f'<div class="y-spec" style="width:760px"><h2 class="y-section">Motion · {THEMES[theme]}</h2><p class="y-body-s">Durations describe the feel. Enter with ease-out, never ease-in. Keyboard and repeated actions do not animate. Press feedback is a 0.94 scale at 180ms. Stagger 35ms per item, max six.</p>{rows}<div style="margin-top:24px">{curves}</div><div class="y-spec-row" style="margin-top:12px"><span class="y-meta-sm">press</span><button class="y-btn">Press me</button><button class="y-btn y-btn--ghost">Ghost</button><span class="y-chip is-active">Active chip</span><span class="y-chip">Chip</span></div></div>'


FOUNDATIONS = {"Colors": colors, "Typography": typography, "SpacingRadius": spacing, "Motion": motion}

PROMPTS = {
    "Library": "Home screen. Full-bleed cover hero for the most recent read (title, mono 'Continue · Ch N' label, art-coloured progress), then search, a 'Continue reading' shelf of 84px covers, category chips, and the collection as rich rows (cover, title, author · chapter, unread count).",
    "TitleDetail": "Blurred cover fills the top; a draggable sheet carries title (display-s), mono metadata line, synopsis (body-s), genre tags, a primary 'Continue · Ch N' button beside a ghost download button, then the chapter list with unread dots, mono chapter numbers and download status.",
    "Reader": "Immersive page canvas on true black. A 2px art-coloured progress line at the top edge. Tap reveals top chrome (close, chapter title, more) and bottom scrubber with page counts; both fade over the canvas with scrims. Hidden chrome shows a mono page pill.",
    "Browse": "Mono 'Discover' label over a display-m 'Browse' title, search, a horizontal shelf of gradient source cards, then Installed and Available source rows with a 'Get' button.",
}


def prompt_md(name, theme):
    return f"""# {name} · {THEMES[theme]}

{PROMPTS[name]}

Direction: **{THEMES[theme]}**. Set `data-theme="{theme}"` on `<html>` (omit for Ink, the default).
Build with the `.y-*` classes in `styles.css`; every colour, radius, shadow and duration comes from the token variables, never from literals.
"""


def main():
    written = []
    for theme in THEMES:
        for name, fn in SCREENS.items():
            d = OUT / f"Screens {THEMES[theme]}" / name
            d.mkdir(parents=True, exist_ok=True)
            (d / f"{name}.html").write_text(page(theme, f"Screens · {THEMES[theme]}", name, fn(theme)), encoding="utf-8")
            (d / f"{name}.prompt.md").write_text(prompt_md(name, theme), encoding="utf-8")
            written.append(d / f"{name}.html")
        for name, fn in FOUNDATIONS.items():
            d = OUT / f"Foundations {THEMES[theme]}" / name
            d.mkdir(parents=True, exist_ok=True)
            (d / f"{name}.html").write_text(page(theme, f"Foundations · {THEMES[theme]}", name, fn(theme)), encoding="utf-8")
            written.append(d / f"{name}.html")
    for p in written:
        print(p.relative_to(ROOT))


if __name__ == "__main__":
    main()
