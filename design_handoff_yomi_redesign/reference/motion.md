# Motion

Durations are named for how they feel, not how long they are. Use the token, not the number.

| Token | ms | Use |
|---|---|---|
| `--dur-instant` | 80 | toggles, checkboxes, anything that syncs to a tap haptic |
| `--dur-micro` | 120 | icon swap, badge pop |
| `--dur-fast` | 180 | button press, colour change, chip select |
| `--dur-base` | 260 | card reveal, panel open, nav indicator |
| `--dur-page` | 380 | push / pop, bottom sheet |
| `--dur-hero` | 520 | hero entrance, cover zoom on open |
| `--dur-epic` | 700 | rare full-screen moments only |

Curves: `--ease-snap` is the default for UI transitions. `--ease-out` for panels and drawers settling. `--ease-spring` only for the active nav icon pop and pill indicator slide. `--ease-decelerate` for fling and drag release. Never ease-in on an entering element.

Rules:

- Enter with ease-out. Exit faster than enter.
- Repeated and keyboard-driven actions do not animate.
- Press feedback is a scale to `--scale-press` (0.94) over `--dur-fast`; the `.y-press` class does this. Cards use `--scale-active` (0.97).
- Nothing enters from scale(0). Start at 0.95 with opacity 0.
- Only transform and opacity animate. No height, padding or blur animation.
- List entrance staggers by `--stagger-unit` (35ms) per item, capped at `--stagger-max` (6). The `.y-stagger` container applies this using a per-child `--i` index.
- Reader chrome fades over 200ms with an 8px translate; the page pill fades in when chrome is hidden.
- Hero covers animate as shared elements between Library and Title Detail (Flutter `Hero`); keep the cover the same aspect and radius on both ends so the transition is clean.
- `prefers-reduced-motion: reduce` removes stagger and scale feedback and keeps opacity transitions.
