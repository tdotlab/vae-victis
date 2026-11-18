# Status

Updated 2026-11-18.

**Phase:** T has played the demo ("a damn solid foundation"). The cleanup pass is done (the clock follows Caesar, the research's text fixes, three bugs). The figure rework and grit pass are done: women, Roman kit, optional torcs, moustaches and beards, seven hairstyles, hide capes, checked cloaks, an iron Gallic helmet and a bird helm; harder light, outlines, a darker winter ground and a color grade. Next: Phase 3, starting at Gergovia. Not yet applied from [research/](research/README.md): the rampart redraw, interiors and props. Gear swaps the research suggests but that change balance are left for T: rider archers with javelins, the German riders' leather jerkins for hide cloaks, padded linen for Vellaunos, and a sword worn on the right hip (the sword layer has no scabbard).

**Working:**
- M0 Foundation: hex map in isometric view, click-to-walk with A* pathfinding, camera pan and zoom, data loading, headless test runner (fails on any script error), web export that runs in a browser.
- M1 Character: creation screen, derived stats, XP and leveling, perks, character sheet.
- M2 Combat: sequence, AP, melee, ranged and thrown weapons with range falloff and ammo, shields with a facing arc and fouling, aimed attacks, criticals and fumbles, knockdown, morale and fleeing, death screen, basic AI. Sneaking and detection start fights.
- M3 Dialogue and quests: `.dlg` dialogue engine with skill and attribute checks, conditions and effects; quest log and journal; Honor, renown and faction standing.
- M4 Items: inventory, equipping, weight, barter with skill-based prices, containers with locks and owners, looting bodies, healing items.
- M5 World: world map of central Gaul traveled in days (terrain costs, seasons), fog of war and discovery, random encounters on two encounter maps, the historical calendar (news arrives on its day), resting, entering locations.
- M6 Leaving home: the demo. Intro, Brigodunon (Vellaunos, the vates, the smith, the gate), the Grotto of the Hanging Dead, Vindomagos (Sulicena, the salt merchant, the healer), the ford at the Oltis, and an ending screen when the player learns where the hostages are and reports it.
  - The Three Hostages: find the tally, get it read (Lugurix, Haldo, or your own Latin), report.
  - The Grotto: fight, buy, barter, pardon through Vellaunos, lie with the elder's ring, scare with the idol or with Lore, or pick the chest.
  - The Ford: fight, toll (or haggle), the Arverni lie, Sulicena's forged recall order, recruit, threaten, steal the horses at night.

**Tests:** 71 headless tests, including content validation (every dialogue, map, NPC and quest reference resolves; everything on a map is reachable; the ford barrier can't be walked around) and scripted playthroughs of every quest route through the real dialogue files.

**Partial:** save and load (quick slot and title-screen Continue; no slot browser yet).

**Known rough edges:**
- Art: water is a plain texture, skin tone is not recolored, hair can show under a cloak in back views, and gear cut by the body holdout gets a thin outline on the body edge, only the wolf has a beast sprite (other beasts fall back to the placeholder), and the world map and title screen are unchanged.
- Consequences that pay off later (hired riders in Act III, the discovered lie, the pardoned exile) are recorded as flags; the content that uses them doesn't exist yet.
- Balance is untested by a human: check odds, enemy strength, prices.

**Waiting on T:** the open questions at the end of [DESIGN.md](DESIGN.md), including real names for the placeholders.
