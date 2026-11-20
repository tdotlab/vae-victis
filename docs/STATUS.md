# Status

Updated 2026-11-20.

**Phase:** T has played the demo ("a damn solid foundation"). The cleanup pass is done (the clock follows Caesar, the research's text fixes, three bugs). The figure rework and grit pass are done: women, Roman kit, optional torcs, moustaches and beards, seven hairstyles, hide capes, checked cloaks, an iron Gallic helmet and a bird helm; harder light, outlines, a darker winter ground and a color grade. Phase 3 has started: Gergovia and Avaricum are built. An art pass followed: hoods and headwraps, a shorter stride for women, ten new props and rebuilt furniture on every town map, smoke, firelight and rain, steeper roofs, and the speaker's figure in the dialogue window. The interface was then rebuilt: an iron and bronze bar with a La Tène rim, action-point studs and a shield boss for END TURN, iron window panels, windows that sit above the bar, and two real fonts (Cinzel, Alegreya Sans). All of it is pushed and live online since 2026-11-19. Next: T plays both, then Cenabum and the Carnute forest. Not yet applied from [research/](research/README.md): the rampart redraw. Gear swaps the research suggests but that change balance are left for T: rider archers with javelins, the German riders' leather jerkins for hide cloaks, padded linen for Vellaunos, and a sword worn on the right hip (the sword layer has no scabbard).

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
- Phase 3, Gergovia: two maps (the lower town with the levy camp, and the plateau inside the wall), shut on the world map until day 7, when Vercingetorix takes it. Vercingetorix is there until he marches north on day 24. 17 new NPCs, four quests, Theron as the first companion.
  - A Roman in Gergovia (main): find Paconius, the Vettius clerk hiding as Theron's bookkeeper (Latin, Perception, the potter's hint, Theron's confession), then get his tablets: smuggle him out (sneak, bribe, Speech), buy them, frighten him, betray him to Ollognatos, pick his satchel, or kill him. Read them with Latin, Theron, Paconius or Lugurix. They name Dannotalos and also reveal Noviodunum, so they can stand in for the tally.
  - The King's Levy: pledge two children, give yourself as the pledge (Honor or Presence), send it to Lucterius (Lore), pay in iron, sell out Vindomagos (Sulicena remembers), or refuse. Vellaunos reacts to each.
  - The Uncle's Man: plead with the king (Speech spares him, Honor stands surety, a plain plea costs his ears), bribe the pit guard, free him at night by stealth, or betray his father. He burns if the king marches first.
  - The Greek: Theron joins if Paconius was saved, by Speech, by a blades check, or as a paid escort; never if Paconius was betrayed.
- Phase 3, Avaricum: a timed city with three faces on one location. Rich and open until day 108; under siege from day 108 (entered at night through the marsh); ruins from day 137, a separate map with a Roman sentry, the Vettius agent's slave pen and a girl hiding in a granary. A player still inside on day 137 lives through the fall and comes out one of the eight hundred. 17 new NPCs, four quests, four items.
  - The Empty Line (main): Epomeduos, an Aeduan grain buyer, is Vettius's factor filling the blank Avaricum line in the tablets. Unmask him (the tablets, Lore, Perception, or his own list), then expose him to Senodonnos, turn him (Presence, Speech, or the list), buy him off, kill him, or steal his letter. The letter, read with Wits, Lore or Theron, confirms Noviodunum. In the ruins he's still there, buying.
  - Under the Terrace: help Andecamulos's miners against the Roman siege terrace by digging (Strength or Endurance), listening for the Roman tunnels (Perception or Lore), bringing pitch, or a night sortie with the blades. Fails if the city falls first.
  - The Most Beautiful City: get Nertomara's children out to her sister at Argentomagus: early, before the siege (Speech or Honor); by Vindos's boat at night (sneak); through the miners' adit; or with the king's runners (Speech or Renown). Fails if they're still inside when it falls.
  - What the Soldiers Left: get the girl out of the ruins by stealth at night, by a Latin lie at the gate, by paying a legionary, by Epomeduos's word, or by fighting the camp.
  - Hermeros, the Vettius freedman, sells wine and bread and the people in his pen; the player can buy them free, read his day book (which shows Brigodunon's three at Noviodunum), or pay him to read the factor's letter.

**Tests:** 114 headless tests, including content validation (every dialogue, map, NPC and quest reference resolves; everything on a map is reachable; the ford barrier can't be walked around) and scripted playthroughs of every quest route through the real dialogue files.

**Partial:** save and load (quick slot and title-screen Continue; no slot browser yet).

**Known rough edges:**
- Art: the indoor firelight (shown only while the player is inside) is untested on screen, water is a plain texture, skin tone is not recolored, hair can show under a cloak in back views, and gear cut by the body holdout gets a thin outline on the body edge, only the wolf has a beast sprite (other beasts fall back to the placeholder), and the world map and title screen are unchanged.
- Consequences that pay off later (hired riders in Act III, the discovered lie, the pardoned exile, Brigodunon's levy, the king's surety, the betrayed clerk) are recorded as flags; the content that uses them doesn't exist yet.
- Theron has no personal quest beyond joining, no way to part ways, and no ending slide yet.
- Balance: one playtester found the road wolves too deadly, and `tools/arena.sh` agreed, so wolves were softened (2026-11-20). The arena also shows fresh characters lose nearly every fight against the road brigands and the Roman foragers (0 to 4% even with a sword and shield); not yet decided whether that is intended, since the player can avoid them if they spot them first. Prices and quest-fight odds are untested.

**Waiting on T:** the open questions at the end of [DESIGN.md](DESIGN.md), including real names for the placeholders.
