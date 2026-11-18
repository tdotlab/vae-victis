# Decisions

Newest first. Each entry: the decision, and why.

## 2026-11-17

- **Full game, not a demo.** T's call. The target is roughly Fallout 1 in scale. The vertical slice (M6) is a step on the way, kept because it proves the game is fun before the bulk of the content is written.
- **Godot 4.7 first, export to the web.** T's call, and correct: Godot exports to HTML5, so there's no need to build a separate browser version first. GDScript only, because Godot 4 C# projects can't export to the web. Use the single-threaded web export unless threads are needed, so hosting doesn't need special cross-origin headers.
- **Claude writes the story and dialogue; T may rewrite later.** T's call. Consequence: every line of text lives in data files, never in code, so a full rewrite never touches code.
- **Rules separated from presentation.** Combat, checks, and stats are plain GDScript with no scene dependencies, so they run headless under tests and an agent can verify them without screenshots.
- **Hex grid, isometric presentation.** Hexes give fair movement and range in every direction, as in Fallout's combat, and Godot's tile maps support hex layouts. Provisional until M0 shows it working.
- **Pre-rendered 3D for art.** Fallout did this. A single Blender camera and lighting rig makes consistent sprites, which is the weak point of AI-made 2D art. Placeholders until M7.
- **History is fixed; local outcomes are not.** The fixed ending is the game's spine and the meaning of the title.
- **Setting: Gaul, 52 BC, the Great Revolt.** T's setting. Fits Fallout's shape: a world ending, factions, a clock.
- **Name: Vae Victis.** T's name. A French wargaming magazine already uses the name; check for conflicts before any commercial release.
