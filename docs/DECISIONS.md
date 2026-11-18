# Decisions

Newest first. Each entry: the decision, and why.

## 2026-11-17 (engine)

- **Dialogue in a custom plain-text format (`.dlg`), not JSON or Ink.** Reads like a script, so T can rewrite it in any editor; conditions, checks and effects are one-line tags. The parser is small, pure GDScript and tested. Format reference: the header of `game/src/core/dialogue.gd`.
- **UI built in code, not in scene files.** Agents can read and change it as text; screenshots via `tools/shot.sh` check the result.
- **The test runner counts engine errors through a custom `Logger`.** GDScript keeps running after a script error, so without this a broken test passed silently. A test that loads every script catches compile errors.
- **Web export includes `data/*.json, *.dlg, *.txt` explicitly.** They are read as raw files, which Godot doesn't pack unless told to.
- **Placeholder art is drawn in code** until M7, so the game runs with no asset files at all.

## 2026-11-17 (design)

- **Full game, not a demo.** T's call. The target is roughly Fallout 1 in scale. The vertical slice (M6) is a step on the way, kept because it proves the game is fun before the bulk of the content is written.
- **Godot 4.7 first, export to the web.** T's call, and correct: Godot exports to HTML5, so there's no need to build a separate browser version first. GDScript only, because Godot 4 C# projects can't export to the web. Use the single-threaded web export unless threads are needed, so hosting doesn't need special cross-origin headers.
- **Claude writes the story and dialogue; T may rewrite later.** T's call. Consequence: every line of text lives in data files, never in code, so a full rewrite never touches code.
- **Rules separated from presentation.** Combat, checks, and stats are plain GDScript with no scene dependencies, so they run headless under tests and an agent can verify them without screenshots.
- **Hex grid, isometric presentation.** Hexes give fair movement and range in every direction, as in Fallout's combat, and Godot's tile maps support hex layouts. Provisional until M0 shows it working.
- **Pre-rendered 3D for art.** Fallout did this. A single Blender camera and lighting rig makes consistent sprites, which is the weak point of AI-made 2D art. Placeholders until M7.
- **History is fixed; local outcomes are not.** The fixed ending is the game's spine and the meaning of the title.
- **Setting: Gaul, 52 BC, the Great Revolt.** T's setting. Fits Fallout's shape: a world ending, factions, a clock.
- **Name: Vae Victis.** T's name. A French wargaming magazine already uses the name; check for conflicts before any commercial release.
