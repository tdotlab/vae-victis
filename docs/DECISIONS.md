# Decisions

Newest first. Each entry: the decision, and why.

## 2026-11-18 (figure rework and grit pass)

- **Bodies, heads and ornaments are layers too.** Three bodies (man in trousers, woman in an ankle-length dress, bare-legged Roman), seven hairstyles, moustache or beard, gold or bronze torc, each its own render; the game builds the stack from the NPC's `look` (`body`, `hair_style`, `face`, `torc`, `hide`, `cloak2`) in `Art.figure_layers`. Torcs and moustaches were baked into every figure; the research says they belong to nobles. Hair does more for telling people apart than gear does.
- **Romans get their own kit:** gladius, a tall curved scutum, the pilum with its long shank, the bronze Montefortino. Gauls get an iron Agen-type helmet (new item `iron_helmet`); the raven helm is an iron cap with a bronze bird, re-anchored on the Tintignac find as an heirloom.
- **Cloaks carry a check.** The cloak mask has a second channel for a woven check, so each NPC can have two cloak colors. The Germans wear hide capes instead.
- **Fallout grit, not a filter.** Harder light (a small sun at 4.5 over a 0.32 fill, so shadows read), a one-pixel dark outline on figures, beasts, trees and props (not walls or rock, which join across hexes and would show seams), a darker winter ground with straw patches and lit pebbles, and a color grade per style in `art_styles.json` (contrast, saturation, warm tint, vignette) in the same screen shader the pixel styles use. Roofs follow the harder light.
- **Gear that changes stats waits for T.** The research suggests javelins for the rider archers, hide cloaks for the German riders and padded linen for Vellaunos; those change fights, so they're noted, not done. The Roman forager's leather jerkin became a scutum and helmet with the same protection.

## 2026-11-18 (cleanup pass after the research)

- **The clock follows Caesar, not 240 days.** Caesar's own day counts don't fit in 240; Alesia surrenders about day 284. Events moved: Cevennes 56, scorched earth 105, Avaricum 137, Gergovia 190, new Noviodunum event 196. Seasons: winter to day 70, spring to 160, summer to 255. Roman foragers start at day 45. The "spring assembly" deadline (120) stays as an invented in-game deadline.
- **The Grotto's hanged dead belong to Esus**, the one god the sources tie to hanging. Shrine theft is a capital crime judged by druids, so pardoning Dubnacos is a heavier ask. Epona is now Eponina (the girl's-name form that is attested). Haldo's saddle is explained: Caesar's tribunes gave the Germans their horses and saddles (BG VII.65), because his people think saddles soft (IV.2).
- **Enemies hear their friends fight.** A hostile within 10 hexes of a same-faction fighter joins the fight even if it hasn't seen the player. When a faction's last member dies the game sets `wiped_<faction>`, which Sulicena accepts as proof the riders are dead, so winning the ford by force no longer needs the pay tablet. The toll rider remembers being paid.

## 2026-11-18 (T's first playtest)

- **No brown in the interface.** T hates it. Panels are charcoal iron with iron-gray edges, bone text and brass accents (`src/ui/ui_theme.gd`). The map itself stays earthy; this is about the interface.
- **A hex is half a stride.** The walk cycle used to restart on every hex, so figures stepped with one leg and shuffled. Now each hex moves one leg forward and back, alternating, and a step takes 0.2 s instead of 0.13 s. Facing looks two cells ahead with some slack, so zigzag paths don't flip the figure every step.
- **See-through walls as an oval, not single segments.** Tall things in front of the player thin out smoothly by distance (`LocalMap._see_through`), the way Fallout 2 cuts a window around the player, instead of fading one hex at a time.

## 2026-11-18 (dressing the demo, M7)

- **People are drawn 1.3 times life size against the hexes.** At true scale a person was a smudge next to a house; Fallout cheats the same way. Walls and trees keep their scale.
- **Gear is layers, not variants.** Cloak, mail, cap, helmet, each weapon and each shield are rendered on their own with the body as a holdout, and the game stacks the ones an NPC has equipped (`GEAR` in `art/pack.py` maps items to layers). Cloaks and shields carry color masks, so they recolor like tunics.
- **Cliffs and cave walls are rock masses that join like walls** (a boulder at the center and two toward each rocky neighbor, 64 frames), so cave maps stay plain terrain letters. Loose rocks are random clusters, like trees.
- **Roofs are built in the game, not rendered.** Each house (a wall ring around cells the outside can't reach) gets a hip roof whose height follows each cell's distance from the outside, lit by the same sun as the sprites. Any floor plan gets a roof with no art work. A roof disappears while the player is inside its house and turns see-through while they stand behind it.

## 2026-11-18 (art style proof, M7)

- **The art style is Rendered** (T's pick, from the four in the proof): the Blender sprites drawn as they are, no pixel filter. The pixel styles and placeholders stay behind F2 for now as a comparison and a debugging aid; they are not maintained as alternatives.

- **Sprites come from a Blender script, not hand modeling.** `art/sprites.py` builds every model from primitives and renders it headless under one camera and sun; `art/pack.py` packs the renders into sheets plus `assets/art/art.json`. The whole art set rebuilds with one command, so a style change is an edit and a rerun, not a redraw.
- **Walls auto-tile by neighbor mask.** Each wall type is rendered 64 times (a center post plus any of six arms), and the game picks the frame from which neighbors continue the wall. Maps stay plain terrain letters; no hand-placed wall pieces.
- **One neutral figure, recolored in the game.** The body is rendered once in gray with ID-color masks for tunic, trousers, hair and shield; the game tints those layers from each NPC's `look`. Weapons and shields are separate layers. One render set covers every person in the game.
- **Ground is tiling textures with soft fringes**, not per-hex tiles, so terrain edges don't show the hex grid.
- **The pixel styles are a screen shader over the same sprites**, not separate art. The pixel grid is anchored to the map so standing things don't shimmer when the camera moves. This keeps the choice of style cheap and reversible.
- **Several styles side by side, T picks.** F2 cycles Rendered, Pixel, Pixel with a fixed palette, and the old placeholders. The style is a setting, so the losers can stay as options or be cut.

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
