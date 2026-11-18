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

One milestone per location or pair of locations, in roughly the order a player meets them: Gergovia; Avaricum (timed); Cenabum and the Carnute forest; Bibracte and Noviodunum; the Germanic camp and the Bone Field; the Pens; Alesia. Companions are added as their home locations arrive.

## Phase 4: Finish

Ending slides, balance passes, a full playthrough per major build style (fighter, talker, sneak), sound and music, performance, and the web and Windows releases.

## Working notes

Model guidance (advice, not rules): systems design, combat rules, and architecture on Opus at high effort; large batches of content entry and data files on Sonnet at medium; Codex: Sol high for systems, Luna medium for bulk content.
