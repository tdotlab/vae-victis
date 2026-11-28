# Roadmap

The target is the full game described in [DESIGN.md](DESIGN.md), roughly Fallout 1 in size. Each milestone ends in something playable and tested. Systems come first because content written against unstable systems gets rewritten.

## Phase 1: Foundation and systems

| Milestone | Done when |
|---|---|
| **M0 Foundation** | Godot project in place; a hex map renders in isometric view; a character walks around it with pathfinding and camera control; data files load; the headless test runner works; a web export builds and runs in a browser. |
| **M1 Character** | Character creation screen (attributes, tagged skills, traits, name); derived stats; experience, leveling, and perks; character sheet screen. Rules covered by tests. |
| **M2 Combat** | Turn-based combat on the hex map: sequence, AP, melee, ranged, thrown weapons, shields, aimed attacks, criticals, morale, death; basic enemy AI. A test arena with a few enemy types. |
| **M3 Dialogue and quests** | Dialogue engine on the chosen data format, with skill and attribute checks, conditions, and effects; quest log; Honor, renown, and faction standing. |
| **M4 Items** | Inventory, equipping, weight; barter screen; loot; consumables and healing. |
| **M5 World** | World map travel in days; terrain and seasons; random encounters; the historical calendar; save and load. |

## Phase 2: The first region (vertical slice)

| Milestone | Done when |
|---|---|
| **M6 Leaving home** | Brigodunon, the Grotto, Vindomagos, and the ford at the Oltis are playable start to finish with real content and every quest route working. This is the proof that the game is fun, and it's the first thing worth handing to people. |
| **M7 Art pipeline** | Blender-to-sprite pipeline: one character and one building rendered into six-direction sprite sheets under the fixed camera and lighting, in the game. Then replace the first region's placeholders. |

## Phase 3: The rest of Gaul

One milestone per location or pair of locations, in roughly the order a player meets them: Gergovia (built 2026-11-18); Avaricum (timed; built 2026-11-18); Cenabum and the Carnute forest (built 2026-11-20); Noviodunum and the assembly at home, closing Act I (built 2026-11-20). Then Act II (designed 2026-11-20), then Alesia. Companions are added as their home locations arrive.

Act II, in build order:

| Milestone | Done when |
|---|---|
| **A2.1 Systems** (done 2026-11-21) | Allied bands fight on the player's side; several companions follow at once, with opinion, parting and a Presence cap; the guest-bond Honor rule; calendar-dependent prices; scripted day changes to maps; the Act II clock events in `calendar.json`. Covered by tests and the arena. |
| **A2.2 The house arrives** (done 2026-11-26) | The opening at Brigodunon (The House Collects, the runner), the Line for Brigodunon in the journal, and Cabillonum before the riot: Vettius, the Countinghouse, Theron's Debt. |
| **A2.3 The partner** (done 2026-11-28) | Bibracte's two maps before day 196, Dannotalos and The Partner's routes (those that don't need later content stubbed as unavailable). |
| **A2.4 The road east** | The Bone Field (the God's Iron, the dog) and the Germanic camp (Wages, Haldo's debt, Gundo). |
| **A2.5 The Pens** | The compound, its captives, every route, and where freed people go. |
| **A2.6 The war arrives** | Gergovia besieged (the Sutler, the Wall, the King's Errand), the Aeduan column, and Cabillonum's riot and after (the Tribune's Road). The first to cut if Act II has to shrink. |
| **A2.7 The reckoning** | Noviodunum's fall on day 196 and its burned map, Bibracte after 196 (the Children of Gaul, the Bard's Disgrace), the council, and the Act II slides. Act II playable start to finish. |

## Phase 4: Finish

Ending slides, balance passes, a full playthrough per major build style (fighter, talker, sneak), sound and music, performance, and the web and Windows releases.

## Parked

Wanted, not now. Pick up when the time is right.

Nothing parked right now.

## Working notes

Model guidance (advice, not rules): systems design, combat rules, and architecture on Opus at high effort; large batches of content entry and data files on Sonnet at medium; Codex: Sol high for systems, Luna medium for bulk content.
