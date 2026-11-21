# Vae Victis

A turn-based, isometric, open-world role-playing game in the mold of Fallout 1, set in Gaul during the Great Revolt of 52 BC. You can't change who wins. You can change who's left.

Status: Act I is playable start to finish, from the village that sends you out to Caesar's depot at Noviodunum and back to the assembly at home, with every quest solvable several ways. Act II is designed and not yet built. See [docs/STATUS.md](docs/STATUS.md).

## Docs

- [docs/DESIGN.md](docs/DESIGN.md): what the game is. Setting, story, systems, scale.
- [docs/ROADMAP.md](docs/ROADMAP.md): build order, milestone by milestone.
- [docs/DECISIONS.md](docs/DECISIONS.md): decisions and the reasons for them.
- [docs/STATUS.md](docs/STATUS.md): where things stand.
- [docs/research/](docs/research/README.md): source-cited history and material culture, with the corrections the game still needs.
- [docs/shots/](docs/shots/README.md): screenshots over time, a visual history of development.

## Layout

- `game/`: the Godot 4.7 project (GDScript only).
  - `src/core/`: rules with no scene dependencies (character sheet, combat math, dialogue engine, hex math, pathfinding, inventory, trade, game state). Tested headless.
  - `src/game/`: the local map, combat runner, world map, scenarios used by tests and screenshots.
  - `src/ui/`: every screen and window, built in code.
  - `src/view/`: drawing. `art.gd` draws the rendered sprites and switches art styles (F2 on a map); `pixelate.gdshader` makes the pixel styles; `paint.gd` is the code-drawn placeholder art, used for anything without a sprite.
  - `assets/art/`: generated sprite sheets, ground textures and their manifest `art.json`. Don't edit by hand; rebuild with `tools/build-art.sh`.
  - `data/`: all game content. JSON for rules, items, NPCs, quests, local maps, the world map (`world.json`), the historical calendar (`calendar.json`) and story; `.dlg` files for dialogue (format documented at the top of `src/core/dialogue.gd`); `.txt` for longer text.
  - `tests/`: headless test suite. Rule tests, content validation (`test_content.gd`: every reference in dialogue, maps and NPCs resolves, everything is reachable) and scripted playthroughs of the quest routes (`test_playthrough.gd`).
- `art/`: the art pipeline. `sprites.py` models and renders everything in Blender, headless, from the game's own camera angle; `pack.py` packs the renders into sheets and generates the ground textures; `ui.py` generates the interface art (the bar, wells, buttons, studs, the END TURN boss, window panels) into `game/assets/ui/`. Run `python art/ui.py`, then open the project once (or run Godot with `--headless --import`) so the new PNGs are imported.
- `tools/`: shell scripts (Git Bash) for testing, screenshots, the web build and the art build.
- `build/`: export output, not in Git.

## Running

The engine is `C:\Users\ringd\tools\godot\4.7\Godot_v4.7-stable_win64_console.exe` (override with `GODOT=...`).

```bash
tools/test.sh
```

```bash
tools/shot.sh sandbox /tmp/shot.png 40 "walk:12:5,fight"
```

`shot.sh` runs the game windowed in a scenario, performs the listed actions and saves a screenshot. Scenarios and actions are in `game/src/game/scenarios.gd` (`sandbox`, `fight`, `world`, `newgame`, `create`, or any map id). Actions include `talk:<uid>`, `key:<n>` (a dialogue reply), `walk:x:y`, `encounter:<id>` (world map) and `press:<button text>`, and state setters such as `quest:<id>:<stage>`, `flag:<name>`, `give:<item>`, `known:<location>`.

```bash
tools/arena.sh
```

The combat arena: fresh character builds fight every random encounter a few hundred times each on open ground, and the table shows win rates. Use it after touching enemy stats, weapons or `rules.json`. Options: `--runs=N`, `--only=<encounter id>`, `--turns`; `--quest` runs the scripted quest fights instead, at the levels a player usually has by then, and `--group=a,b,c --level=N` any group of NPC templates. It's `game/tests/arena.gd`; the turn loop is a stripped copy of `CombatRunner`'s, the math is `CombatRules`'s.

```bash
tools/export-web.sh && tools/serve-web.sh
```

That builds the browser version into `build/web` and serves it on http://localhost:8060. The web build is single-threaded, so any static host works without special headers.

The demo is online at https://vae-victis.vercel.app (Vercel project `vae-victis`, public). `tools/deploy-web.sh` publishes the current `build/web` there; it needs the Vercel CLI login.

```bash
tools/build-art.sh
```

That re-renders all sprites with Blender (portable, `C:\Users\ringd\tools\blender\`, override with `BLENDER=...`) and repacks them; a few minutes. Pass groups to render only some: `tools/build-art.sh trees,props`. `STYLE=pixel tools/shot.sh ...` takes a screenshot in a given art style.

To play from the editor, open `game/project.godot` in Godot 4.7 and press F5.

## Controls

Left click walks, talks, opens and attacks. Right click examines, or in a fight opens the aimed-attack menu. Space ends your turn, Enter ends a fight when no enemy is aware of you, A starts a fight, S toggles sneaking. C, I, J open the character sheet, gear and journal; M opens the world map; walking off a map's edge does too. On the world map, click a known place or open country to travel, E enters where you stand, R rests, Space or right click stops. Arrow keys pan the camera, the wheel zooms, Home recenters. F5 and F9 quicksave and quickload; Save and Load in the menu open the slots. F2 cycles the art style. Escape closes windows or opens the menu. Number keys pick dialogue replies.
