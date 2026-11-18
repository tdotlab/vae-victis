# Vae Victis

A turn-based, isometric, open-world role-playing game in the mold of Fallout 1, set in Gaul during the Great Revolt of 52 BC. You can't change who wins. You can change who's left.

Status: see [docs/STATUS.md](docs/STATUS.md).

## Docs

- [docs/DESIGN.md](docs/DESIGN.md): what the game is. Setting, story, systems, scale.
- [docs/ROADMAP.md](docs/ROADMAP.md): build order, milestone by milestone.
- [docs/DECISIONS.md](docs/DECISIONS.md): decisions and the reasons for them.
- [docs/STATUS.md](docs/STATUS.md): where things stand.

## Layout

- `game/`: the Godot 4.7 project (GDScript only).
  - `src/core/`: rules with no scene dependencies (character sheet, combat math, dialogue engine, hex math, pathfinding, inventory, trade, game state). Tested headless.
  - `src/game/`: the local map, combat runner, world map, scenarios used by tests and screenshots.
  - `src/ui/`: every screen and window, built in code.
  - `src/view/paint.gd`: placeholder drawing until the art pipeline (M7).
  - `data/`: all game content. JSON for rules, items, NPCs, quests, maps and story; `.dlg` files for dialogue (format documented at the top of `src/core/dialogue.gd`); `.txt` for longer text.
  - `tests/`: headless test suite.
- `tools/`: shell scripts (Git Bash) for testing, screenshots and the web build.
- `build/`: export output, not in Git.

## Running

The engine is `C:\Users\ringd\tools\godot\4.7\Godot_v4.7-stable_win64_console.exe` (override with `GODOT=...`).

```bash
tools/test.sh
```

```bash
tools/shot.sh sandbox /tmp/shot.png 40 "walk:12:5,fight"
```

`shot.sh` runs the game windowed in a scenario, performs the listed actions and saves a screenshot. Scenarios and actions are in `game/src/game/scenarios.gd` (`sandbox`, `fight`, `world`, `newgame`, `create`, or any map id).

```bash
tools/export-web.sh && tools/serve-web.sh
```

That builds the browser version into `build/web` and serves it on http://localhost:8060. The web build is single-threaded, so any static host works without special headers.

To play from the editor, open `game/project.godot` in Godot 4.7 and press F5.

## Controls

Left click walks, talks, opens and attacks. Right click examines, or in a fight opens the aimed-attack menu. Space ends your turn, Enter ends a fight when no enemy is aware of you, A starts a fight, S toggles sneaking. C, I, J open the character sheet, gear and journal; M opens the world map from a map's edge. Arrow keys pan the camera, the wheel zooms, Home recenters. F5 and F9 quicksave and quickload. Escape closes windows or opens the menu. Number keys pick dialogue replies.
