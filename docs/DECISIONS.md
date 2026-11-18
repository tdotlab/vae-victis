# Decisions

Newest first. Each entry: the decision, and why.

## 2026-11-17 (world and demo)

- **The world map is a square grid of terrain cells, separate from the hex local maps.** Travel is counted in hours per cell by terrain, like Fallout's world map; hexes would add nothing at that scale.
- **The historical calendar is data (`calendar.json`).** Events fire once on their day and set flags, so dialogue can react to the war's progress without code.
- **Content is checked by tests, not by eye.** A validator rejects unknown dialogue conditions and effects and dangling references to items, quests, nodes, maps and marks; a flood fill proves every actor, container, exit and trigger on a map can be reached; scripted playthroughs walk each quest route through the real `.dlg` files. Writing content is where most bugs will come from, and an agent can't playtest by feel.
- **Dialogue can act on a whole faction (`leave_all`, `fight_all`) and end the demo (`ending`).** Most quest resolutions in the demo send a whole band away or start a fight with it.
- **A reply that leads straight to the end of a conversation closes it**, instead of showing an empty page with a Done button.
- **The demo ends on a text screen when the player reports where the hostages are, then lets them keep playing.** The road north is shown on the world map but closed.

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
