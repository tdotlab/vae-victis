# Decisions

Newest first. Each entry: the decision, and why.

## 2026-11-20 (balance)

- **Combat arena instead of guesswork.** A playtester said wolves were too hard. `tools/arena.sh` runs fresh builds against every random encounter headless and prints win rates, so balance changes can be checked in numbers. It copies the turn loop and reuses `CombatRules` for the math, so it drifts if `CombatRunner` changes.
- **Wolves.** A fresh character lost to three wolves nearly every time: wolves had a person's hit points and nine action points, bit three times a turn, and never broke. Now: lower Strength, Endurance and Agility, and a template `nerve` of -45 so a hurt wolf runs. The three-wolf pack is rarer, and a lone wolf was added. Result: a pair is a fair fight, and the pack punishes a bare dagger but loses to a sword and shield.
- **No forced-death encounters.** T's rule: a random encounter must never be "fight this or die" with no way out. Encounters with people carry `parley` options in `world.json`: pay silver, a skill roll (Speech, Latin, Sneak) that costs the fight if it fails, with the chance shown on the button. Animals have none. A content test fails any human encounter without one. Smaller variants (a lone brigand, a brigand and a slinger, one soldier and a slinger) are the common case; the gangs and the Roman parties are rare and hard.
- **`nerve` on NPC templates** is a flat modifier to morale tests. Use it for animals and anyone with no reason to die for you.

## 2026-11-19 (interface)

- **The interface bar is an object in the world, not a debug strip.** A hammered iron plate under a bronze rim cut with a La Tène wave tendril, riveted end caps, sunk wax-dark wells for the log, health and weapon, a row of bronze studs for action points, and END TURN on a round shield boss modelled on the Vachères boss (ten rivets; see research/dress-and-arms.md). Fallout's bar did the same job in its own world's materials. Iron, bronze and verdigris only: T hates brown, so no leather.
- **The UI art is procedural, from `art/ui.py`,** not painted or downloaded: height fields (hammer dents, blurred noise) lit from the upper left, supersampled. Every piece regenerates from one script, and nine-patch centers tile, so the bar fits any window width.
- **Windows sit above the bar when they fit** (barter, gear, journal, loot, dialogue), as in Fallout; a window too tall for that space (the character sheet) covers the whole screen.
- **The world map hides the turn controls.** Action points and END TURN mean nothing on the road.
- **Two fonts, both SIL Open Font License, in `game/assets/fonts/`:** Cinzel, a face drawn from inscribed capitals, for anything cut into the iron (bar labels, buttons, window titles, names, the health number, the title screen); Alegreya Sans, a humanist sans that stays readable small, for everything read. Latin capitals suit Gaul: the Coligny calendar and Gallic coin legends use them.

## 2026-11-18 (art pass: people, props, weather)

- **Hoods and headwraps are their own layers.** Commoners, refugees, carters, miners and slingers wear a hooded cape (`look.hood`, which comes down under a helmet or cap); older women wear a headwrap (`hair_style: "wrap"`). Bare heads everywhere made every crowd look like a war band. The hood replaces the cloak, so a hooded NPC takes the hood's color.
- **Women walk with a shorter stride** (`STRIDE` in `sprites.py`, legs only, so held gear still lines up). At the man's stride the back foot showed under an ankle-length dress.
- **Ten new props from the research,** each a terrain type like the old ones: market stall, Dressel 1A wine amphorae (sherds of them turn up under Gallic hearths and floors), warp-weighted loom, a granary on posts, a quern, a woodpile, a cart, a Roman leather tent, burnt rubble (walkable, cost 2) and a smithy. Hearth, bed, table and the stores were rebuilt: a clay hearth plate with firedogs and a cauldron, a straw pallet on the floor instead of a framed bed, a low table, a barrel with withy hoops and a dolium. Avaricum, its ruins and both Gergovia maps are dressed with them; the ruins' Roman camp gets tents.
- **Dialogue shows the speaker.** The conversation window draws the speaker's own figure, three times map size and turned three-quarters to the reader, from the same sprite layers as the map. A painted portrait per NPC would never keep up with the content; this one is free and always matches what the player just clicked on. It also shows when an NPC's look contradicts their text (Senodonnos's "blue cloak" was a red one; fixed).
- **Roofs at 48 degrees, Brigodunon and Vindomagos dressed.** The research puts Gallic thatch nearer 48 than 42. Vindomagos's salt store, "of real stone" in its arrival text, is now timber and daub on a stone footing, because the research finds no stone buildings in Gaul before the conquest.
- **Weather and fire are a view layer (`Atmos`), not rules.** Smoke rises from every glowing cell, out at the roof ridge for a hearth indoors; fires throw flickering light that matters at night, and an indoor fire's light shows only while the player is inside. A map can rain (`"weather": "rain"`, optionally gated by `weather_flag`). Avaricum rains from the siege on and the ruins rain: Caesar records cold, constant rain through the whole siege (BG VII.24), and the ruins' arrival text already said so. The ruins have `"fires": false`: the city is dead, so its hearths keep their embers but give no smoke or light.

## 2026-11-18 (Avaricum)

- **One world location, three maps by flag (`map_by_flag`).** The rich city and the siege share a map and change by phase texts and flag-gated actors, containers and exits; the ruins are their own map. The first matching flag wins, so the order is fallen, then siege.
- **Siege dates follow Caesar's count:** siege from day 108, the terrace fire on day 133, the breakout stopped on day 136, the fall on day 137. Calendar events only fire on arrival or world-map moves, so a map can now carry a `deadline` that fires its dialogue on the day while the player is on it. Waiting the siege out inside means the fall.
- **Nobody saves Avaricum.** The quests save people out of it (children, a girl, the miners' pride), never the city. History is the clock; the player's choices are who gets out.
- **Epomeduos and his letter are invented,** to carry the Vettius thread from Gergovia's tablets to Noviodunum. An Aeduan buying grain in Avaricum in 52 BC is plausible: the Aedui were still Roman allies until Bibracte.
- **The ruins are held by a Roman sentry who can be passed four ways** (Latin as a sutler, a bribe, the Aeduan letter's horse seal, or posing as an Aeduan) or fought. A Gallic safe-conduct does nothing there.
- **Screenshot runs can `reload` a map** so actors gated on flags set by the run respawn.

## 2026-11-18 (Gergovia)

- **Gergovia is two maps, the lower town and the plateau,** joined by the gate in the wall. The real oppidum is a plateau with settlement below it; one map that size would be mostly empty walking.
- **A world location can be shut until a flag is set (`open_flag`, `shut_text`).** Gergovia opens on day 7, when Vercingetorix holds it. Before that the uncle's party has the gates shut, which is history, and it keeps the first week at home.
- **The king marches north on day 24 (`verc_north`),** inside the research's window for his move into the Bituriges, and the pit sentence is carried out as he goes. A quest with a clock tied to the calendar, like Avaricum will be.
- **NPCs can be `essential`: at zero health they go down unconscious instead of dying.** Vercingetorix and Ollognatos have to survive the player, because history and the quest web need them. Everyone else can die.
- **An item can be read (`read` names a dialogue).** The Vettius tablets open their own talk from the inventory, so reading them with your own Latin needs no NPC.
- **The tablets bring part of the Act I reveal forward,** from Noviodunum to Gergovia: the hostages are already sold, on paper, to Dannotalos. The player gets the stakes of Act II as a document at the Hub, while there is still most of the game to act on it. They also reveal Noviodunum, so a player who skipped the tally isn't stuck.
- **A map actor who travels with the player isn't spawned twice.** Companions now arrive on maps that also list them.

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
- **Quest-fight morale (2026-11-20).** Atepomaros, his cousins and the depot watch had positive template `nerve` (+40 to +60), the opposite of what `nerve` means, so they never broke. Now they're 0 to -20, like other hired men and outlaws, and grotto and ford followers got negative nerve too. A leader's death is a 50-point shock (`leader_shock` in rules.json, was 25 in code), enough to make unhurt followers test. `tools/arena.sh --quest` measures the scripted fights at the levels a player meets them. Group fights are still hard solo; tuning them is open work (see STATUS).
- **Escaping a fight (2026-11-20).** Stepping onto an exit hex in a fight now escapes if no enemy is within `escape_radius` (2) hexes, instead of needing every enemy out of sight within 10. Running for it is now a real choice.
- **Group quest fights get ways out, not weaker bands (2026-11-20).** The arena shows a lone character loses to any band of three or more equals on open ground whatever their stats: numbers decide, and letting the player focus the wounded or making deaths shake the band harder changed nothing measurable. So instead of gutting every band, a fight that a failed roll would start now has outs: caught at the ford's horse line, the player can run (Agility), bluff (Speech), pay Haldo twenty silver or stare him down (Presence); the depot alarm can be outrun. A deliberate fight shows the odds first (pushing past the ford barrier stands the whole band up before it starts). Haldo's five riders stay unwinnable head-on; the ford has six other routes. The depot watch dropped a level each (a level-3 sword-and-shield fighter goes from 28% to 38%). Atepomaros's family (66% at level 3) and the grotto (39% at level 2) stay as they are; both have several other routes.
