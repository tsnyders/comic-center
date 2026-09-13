# design-sync notes for Yomi (comic-center)

- This is a Flutter app (Cupertino widgets, Riverpod, Isar). There is no React `dist/`, no Storybook, no esbuild target. The sync is fully off-script: tokens, `styles.css`, fonts, guidelines and hand-authored HTML screen previews. No `_ds_bundle.js` and no `_ds_sync.json` are uploaded, so every future sync re-verifies and re-uploads everything (small: ~35 files).
- Generator: `python .design-sync/gen_previews.py` writes `ds-bundle/components/**` from templates. Edit the templates there, not the generated HTML.
- Render check: `python -m http.server 8765` inside `ds-bundle/`, then headless Chrome (`chrome.exe --headless=new --screenshot=... --window-size=390,844 <url>`). The Paseo browser tab never painted in a background session; headless Chrome is reliable. Screenshots land in `.design-sync/render/` (gitignored).
- Fonts uploaded: HankenGrotesk.ttf (variable), SpaceMono Regular + Bold. The app also bundles Inter, Sora, Poppins, Cormorant Garamond and Fraunces but none are used by the design system; they are legacy.
- Flutter token files (`lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_text_styles.dart`) still describe the previous LUMEN teal-signal system. The Ink direction changes the signal to ivory; the Dart side has not been updated. Do that as a separate change if Ink is adopted.
- Dart comments call the system "Obsidian" in spacing/text files and "LUMEN" in colors; both refer to the same current build.
- Windows gotcha: Chrome `--screenshot=` path must use forward slashes when built inside a bash `for` loop; `\\$name` swallows the variable.
