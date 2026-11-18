# Status

Updated 2026-11-17.

**Phase:** systems (Phase 1). M0 through M4 are working; M5 is next.

**Working:**
- M0 Foundation: hex map in isometric view, click-to-walk with A* pathfinding, camera pan and zoom, data loading, headless test runner (fails on any script error), web export that runs in a browser.
- M1 Character: creation screen, derived stats, XP and leveling, perks, character sheet.
- M2 Combat: sequence, AP, melee, ranged and thrown weapons with range falloff and ammo, shields with a facing arc and fouling, aimed attacks, criticals and fumbles, knockdown, morale and fleeing, death screen, basic AI. Sneaking and detection start fights.
- M3 Dialogue and quests: `.dlg` dialogue engine with skill and attribute checks, conditions and effects; quest log and journal; Honor, renown and faction standing.
- M4 Items: inventory, equipping, weight, barter with skill-based prices, containers with locks, looting bodies, healing items.

**Partial:** save and load (quick slot and title-screen Continue work; no slot browser yet). The world map is a stub.

**Next:** M5 World (world map travel, seasons, random encounters, historical calendar), then M6 content: Brigodunon, the Grotto, Vindomagos, the ford at the Oltis.

**Known rough edges:** placeholder art drawn in code (walls read as a jumble of prisms); enemies that haven't noticed you stay out of a fight even when their friends are in it.

**Waiting on T:** the open questions at the end of [DESIGN.md](DESIGN.md). None of them block M5 or M6.
