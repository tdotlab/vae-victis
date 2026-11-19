# Vae Victis: design document

*Vae victis*, "woe to the conquered," is what the Gallic chieftain Brennus said in 390 BC. He had just sacked Rome, the Romans complained that his scales for weighing their ransom were rigged, and he threw his sword onto the weights. Three hundred and thirty-eight years later, Rome came back for the Gauls. The title is a Gallic boast that history turned into a Gallic epitaph, and the game lives inside that irony.

This document is the source of truth for what the game is. The build order lives in [ROADMAP.md](ROADMAP.md), and the reasons behind choices live in [DECISIONS.md](DECISIONS.md). All names of invented people and places are placeholders until T says otherwise.

## The pitch

A turn-based, isometric, open-world role-playing game in the mold of Fallout 1, set in Gaul during the Great Revolt of 52 BC. You leave an isolated hill village to bring home the hostages it surrendered to Rome years ago. Along the way you walk into the largest uprising Gaul ever mounted, against an enemy that has already won.

The player can't change who wins. Alesia falls, and Vercingetorix lays his arms at Caesar's feet. What the player changes is who is left standing when it's over: which towns burn, who gets sold, what the bards remember, and what becomes of the village that sent you.

## What Fallout 1 is, and what we keep

Building this game should teach Fallout 1 along the way. Here is what makes Fallout 1 work, and how each piece carries over.

| Fallout 1 does this | Why it works | Vae Victis version |
|---|---|---|
| Seven stats (SPECIAL) feed eighteen skills; three skills are "tagged" at creation | Character creation is a real decision that shapes every playthrough | Seven attributes, sixteen skills, three tagged, plus optional traits |
| Turn-based combat with action points (AP) and aimed shots at body parts | Every turn is a small puzzle; a weak character can win with a good plan | Same, plus shields, thrown weapons that ruin shields, and enemy morale |
| Almost every quest has several solutions: fight, talk, sneak, steal, use a skill | Your build *is* your playstyle; a diplomat and a brute play different games | Every quest is designed with at least three routes (see the quest standard below) |
| A world map you cross in days, with random encounters | The world feels big and dangerous between towns | Same, across central Gaul, with seasons |
| A ticking clock (the water chip) | Urgency; you can't wander forever | History is the clock: real events happen on real dates whether you're there or not |
| Karma plus reputation titles | The world reacts to who you've been | Honor (oaths, hospitality, courage) plus standing with each faction, spread by bards |
| Ending slides for every town you visited | Your choices pay off visibly, place by place | Same |
| The hero comes home changed and is not welcomed | The bleak, earned last beat | Your village's verdict on you is the final slide |
| Bleak world, dry dark humor | Keeps the misery from going flat | Caesar's own propaganda, contradicted by what you see |

What we deliberately don't copy: the names (SPECIAL, Pip-Boy, Vault, and so on), the story, the setting, or any specific quest. The genre and its mechanics are fair game; Fallout's specifics are not.

## Setting

### Where and when

Central Gaul, from midwinter to mid-autumn of 52 BC, which is the Great Revolt from its first spark to its end at Alesia. Roughly 285 in-game days; day 1 is the Cenabum massacre, about 9 January. Dates follow [research/chronology-52bc.md](research/chronology-52bc.md).

Gaul in 52 BC is a patchwork of rival peoples (Caesar's *civitates*) ruled by aristocrats, advised and judged by druids, wealthy from trade, and six years into Roman conquest. Caesar has spent those years playing tribes against each other, taking hostages to guarantee loyalty, and selling entire defeated populations into slavery. Some Gallic nobles got rich alongside him. Gallic aristocrats had been selling slaves to Roman traders for wine long before the legions came.

### The historical clock

These events happen on schedule. The player can witness them, take part in them, and change their local consequences, but not their outcome. Day numbers follow the research, which reconstructs them from Caesar's own day counts and seasons; Caesar gives no calendar dates, so each is approximate.

| Day | Event | Effect on the game |
|---|---|---|
| ~1 | Carnutes massacre the Roman traders at Cenabum. News crosses Gaul by men shouting from field to field and reaches the Arverni by nightfall. | Game start. The revolt is lit. |
| ~7 | Vercingetorix, expelled from Gergovia by his own uncle, raises the rural poor, comes back, drives out his opponents and is hailed king. | Gergovia changes hands; its quests change. |
| ~56 | Caesar crosses the Cevennes through deep snow and appears where no one expected him. | Roman patrols appear on the world map. |
| ~105 | Scorched earth: the Bituriges burn more than twenty of their own towns in one day to starve Caesar. They beg to spare Avaricum, and are allowed to. | Several world-map locations burn. Refugees appear. |
| ~108–137 | Siege and sack of Avaricum. Caesar says barely 800 of about 40,000 escaped. | Avaricum is a timed location: after it falls, it's ruins. |
| ~190 | Caesar is beaten at Gergovia. | Revolt morale peaks; Roman standing drops everywhere. |
| ~196 | The Aedui, Rome's oldest allies, defect. They seize the Roman depot at Noviodunum, kill its garrison, and take the hostages to Bibracte. | The Act I goal changes location. |
| ~215 | Vercingetorix is confirmed supreme commander at an assembly at Bibracte. | Political endgame begins. |
| ~230–284 | Siege of Alesia. The Mandubii expel their women and children, and Caesar refuses to take them in (that they starved between the lines is Cassius Dio's detail, not Caesar's). A relief army fails. Vercingetorix surrenders. Caesar gives one captive to each of his soldiers, except the Aedui and Arverni, whose men he sends home. | Act III. The game ends here. |
| Epilogue | Next year, at Uxellodunum in Cadurci country, Caesar cuts off the town's water by tunneling into its spring, then cuts off the hands of every defender who bore arms, and spares their lives. | The final ending slide for the player's home region. |

### Tone

Fallout's tone is a bleak world played with a dry, dark sense of humor. Ours is the same.

The main source of humor is Caesar himself. He wrote his own account of the war, the *Commentaries*, as propaganda for readers in Rome. Loading screens and some item descriptions quote his version of events, written in his flat, third-person, self-congratulating voice, and the game keeps contradicting him. Other sources: the bards, who report your deeds badly and to your face; Roman paperwork applied to atrocity; the traders who sell to both sides and complain about margins; and Gallic aristocrats whose patriotism has a price.

Guardrails:

- **No Asterix.** No magic potion, no comic boars, no slapstick Romans. The Asterix comics have colonized everyone's picture of Gaul, and every step toward them cheapens the game.
- **No noble savages, no cartoon villains.** Gauls practice slavery, take heads, and betray each other. Romans can be decent people inside an indecent machine. The villain is the machine and those who profit from it.
- **Atrocity is shown, never played for laughs.** The humor targets the powerful and the self-deceiving, never the victims.
- **No sexual violence content,** not even as background flavor.
- **Real history where it matters.** Where the record is thin, invent plausibly and don't contradict what's known. Real figures (Vercingetorix, Caesar, Commius, Lucterius, Litaviccus, Labienus) can appear, sparingly. Caesar is mostly offstage: a rumor, a voice, a signature on orders. Seeing him once should land hard.

## Story

### The premise

The player is from **Brigodunon** (placeholder name), a small hill fort of the Cadurci in the limestone country of the southwest, the region of modern Lot. Five years ago, when Caesar's influence reached the Cadurci, Brigodunon gave three hostages to Rome as a guarantee of good behavior. One of them is the player's sibling.

The game opens on the day the news from Cenabum arrives, shouted across the hills. The elders understand at once: if the Cadurci join the revolt, Rome's hostages die or are sold. If they don't join, Vercingetorix will treat them as traitors. Brigodunon will be forced to choose a side at the spring assembly, about 120 days away (an invented deadline, not Caesar's). The elders send the player out to bring the hostages home before that choice is made, or at least to learn where they are and what it would take to free them.

That is the water chip: personal, specific, and on a clock.

### Act I: The hostages (days 1 to ~120)

The player leaves home, learns the world, and follows the hostages' trail: Gergovia, where Vercingetorix is rising; Avaricum, the rich city that won't burn itself; and the roads between, full of refugees, deserters, and Roman patrols. The trail leads to the Roman depot at **Noviodunum** on the Loire, where Caesar keeps hostages, baggage, horses, and grain.

Along the way the player discovers that the hostages' fate is a business matter. A Roman trading house, run by **Aulus Vettius Calvus** (placeholder) with a Gallic partner, the Aeduan noble **Dannotalos** (placeholder), is buying the future: contracts on the captives from towns that haven't been besieged yet. Vettius's ledger lists Avaricum before it falls. Brigodunon's hostages are in it too, already sold.

### Act II: The ledger (days ~120 to ~180)

Fallout's second act is the discovery that the water chip was never the real problem. Ours is the same move. The real enemy isn't Rome, which no one can beat. It's the people who turned the conquest into a market and are positioned to profit from every outcome, including the revolt. Dannotalos helps arm the rebels, because a bigger war means more captives.

The Aedui defection at around day 196 scrambles everything. The player can be inside Noviodunum when it falls, help seize it, or arrive after. The hostages move to Bibracte. The player can go after Vettius's network through its funding, its Gallic partners, its depot (**The Pens**, a holding compound at a river crossing), or its paper. The druids, the Germanic mercenaries, and the Aeduan factions each offer a different way in, at a different price.

### Act III: Alesia (days ~180 to ~240)

Everyone converges on Alesia. The player chooses where to stand: inside the town with Vercingetorix, with the relief army, inside Caesar's siege lines as a spy or a collaborator, or in the slavers' camp waiting for the harvest. The historical outcome is fixed. The player's goal is what can be saved from it: the hostages, a town's people, the ledger's buyers, or only themselves.

The confrontation with Vettius happens at the captive distribution after the surrender, or earlier if the player has broken his network. The best outcomes are hard to reach and partial. That is the point.

### Endings

Ending slides, Fallout-style: one per location the player affected, one per surviving companion, one for Vettius's house, one for the player, and a final one for Brigodunon. That last slide also carries the epilogue: Uxellodunum, the next summer, and what the village's choices led to.

The home-coming beat mirrors Fallout's: whatever the player achieved, the village that sent them out may not want back what came home.

### Optional idea for later

A secret ahistorical path, very hard to reach, in which the revolt holds a little longer somewhere. Open for T to decide. The default is no: the fixed outcome is the game's backbone.

## World

### Map

A world map of central Gaul on a grid, like Fallout's, traveled in days. Travel time depends on terrain (Roman roads don't exist yet, but Gallic roads do), season, and the player's Survival skill. Snow in the Cevennes in Act I; mud in spring; dust and heat at Alesia. Rivers are crossed at fords and bridges, and some crossings are held by someone who wants a toll.

### Locations (full game, about a dozen like Fallout 1)

| Location | Role | Fallout 1 analog |
|---|---|---|
| **Brigodunon** (home) | Tutorial and the ending's home slide. Small, tight-knit, suspicious. | Vault 13 |
| **The Grotto of the Hanging Dead** | First dungeon near home. A cave shrine used by bandits, and worse. | The rat caves |
| **Vindomagos** (placeholder) | Small farming and salt-trading village, the first friendly outsiders | Shady Sands |
| **Gergovia** | Arverni capital. Vercingetorix's rise, politics, recruitment, a big market. | The Hub |
| **Avaricum** | The richest city in Gaul. Timed: sacked around day 137. | Necropolis (a place that changes or ends on a timer) |
| **The Carnute forest** | Annual assembly of the druids, the closest thing Gaul has to a center. Knowledge, judgment, initiation. | Brotherhood of Steel |
| **Cenabum** | Burned trade town where the revolt began. Scavengers and grudges. | Junktown |
| **Bibracte** | Aeduan capital. Rich, Romanized, collaborating until it isn't. Endless intrigue. | The Boneyard / Adytum politics |
| **Noviodunum** | Caesar's depot on the Loire. Hostages, baggage, horses. Seized by the Aedui around day 196. | Military Base, act one version |
| **The Germanic camp** | Mounted mercenaries in Caesar's pay, and deserters from them. Raiders, horse thieves. | The Khans |
| **The Bone Field** | An old battlefield shrine where the victors displayed the dead. Superstition, plague, and grave robbers. | The Glow |
| **The Pens** | Vettius's captive depot at a river crossing. | The Cathedral / Mariposa |
| **Alesia** | The siege. Several areas: the town, the Roman lines, the relief camp. | The Master's lair |

Plus random encounters: refugees, patrols, foragers, deserters, wolves, bandits, a traveling bard, a Greek merchant from Massilia, and occasional strange ones, as in Fallout.

## Factions

| Faction | Wants | Notes |
|---|---|---|
| **Brigodunon** | To survive the year with its children back | The player's standing at home is its own reputation track |
| **Vercingetorix's revolt** | A united Gaul under one command, at any cost | Burns its own towns, executes waverers. Admirable and frightening. |
| **Rome (Caesar's army)** | Pacification, plunder, glory for Caesar | Not a monolith: legionaries, officers, auxiliaries, quartermasters |
| **The Aedui** | To come out on top whoever wins | Split between pro-Roman and pro-revolt nobles; defects at day ~130 |
| **The druids** | Their authority over Gaul, which Rome will end | Keepers of law, medicine, and secrets. Initiation is a long quest line. |
| **The house of Vettius** | Captives, contracts, profit | The main antagonist. Gallic partners make it everyone's problem. |
| **Germanic horsemen** | Pay, plunder, a way home | Caesar's cavalry; their deserters raid the roads |
| **The Greek traders** | Trade, neutrality, safe passage | From Massilia. Interpreters, bankers, information brokers. |

## Character system

### Attributes

Seven attributes, rated 1 to 10. All start at 5, and the player gets 5 extra points (any can be lowered to 1 to free points). The names are deliberately plain.

| Attribute | Governs |
|---|---|
| Strength | Melee damage, carry weight, heavy weapons and shields |
| Endurance | Hit points, resistances, recovery |
| Agility | Action points, defense, sneaking |
| Perception | Ranged accuracy, sequence (turn order), noticing things |
| Wits | Skill points per level, dialogue options, lore |
| Presence | Speech, barter, followers, how people first react to you |
| Fortune | Critical hits, random encounters, the favor of the gods |

### Skills

Sixteen skills, 0 to 200%, with starting values derived from attributes. The player tags three; tagged skills start +20 and grow twice as fast, as in Fallout.

| Group | Skills |
|---|---|
| Combat | Blades (swords, daggers, axes), Spears (thrusting and polearms), Missiles (javelins, slings, bows), Brawling, Shield |
| Covert | Sneak, Locks, Steal, Traps |
| Body | Healing (herbs and bandages, field use), Surgery (wounds, broken limbs, sickness) |
| Social | Speech, Barter, Gambling (dice and knucklebones) |
| Knowledge | Lore (druidic knowledge, sacred sites, plants, omens), Latin (speaking it and reading it) |

Two more are under consideration: Survival (travel speed, foraging, ambushes; Fallout's Outdoorsman), and Craft (repairing gear). Survival is likely in.

**Latin** is this game's unusual skill and gets real use. With it you understand Roman soldiers talking to each other in front of you, read orders and contracts, forge documents, and talk to officers without an interpreter. Without it, Romans speak in untranslated Latin and you rely on interpreters, who can lie to you. Writing Gaulish in Greek letters, as the Gauls and druids actually did, is folded into Lore.

### Traits

Up to two optional traits at creation, each with a benefit and a cost. A first list:

- **Once Sold**: You were a slave and bought your freedom. Better Latin and Barter; Romans and slavers recognize the brand, Gallic nobles look down on you.
- **Raised in the Grove**: A druid's foster child. +Lore and Healing; can't use some weapons without losing Honor.
- **Champion's Pride**: Bonus damage in single combat; you can't refuse a challenge without losing Honor.
- **Born in the Saddle**: Faster world-map travel; worse on foot in combat.
- **Hostage-Bred**: You grew up as a hostage among another people. A second people treats you as kin; your own trusts you less.
- **Gods-Touched**: Very high Fortune swings. Spectacular critical hits and spectacular failures.

### Derived stats

Hit points, action points, armor class (here called Defense), carry weight, sequence, critical chance, healing rate, and resistances, all computed from attributes, much as in Fallout. The exact formulas live in the code's rules module and its tests, not here.

### Leveling

Experience from combat, quests, and skill use (picking a lock, winning an argument). Skill points every level; a perk every three levels. Perks are where the setting's flavor goes: *Head-Taker* (morale damage to enemies who see you take a trophy), *Bard's Friend* (your renown spreads faster and kinder), *Speaks Like a Roman*, *Shield Wall*, *Knows the Fords*.

### Honor and renown

**Honor** replaces Fallout's Karma, measured against Gallic values rather than modern ones: keep your oaths, honor the guest-bond, show courage, be generous. Killing a host or a guest under your roof is the worst crime in the game. Lying is not dishonorable in itself, but oath-breaking is.

**Renown** is how widely your deeds are known, good or bad, and the bards decide what the story is. High renown opens doors and draws challenges. Named reputation titles appear in dialogue ("Guest-Slayer," "the one who came back from Avaricum").

**Faction standing** is tracked per faction, separately.

## Combat

Turn-based, on a hex grid, with action points, like Fallout. Sequence decides who moves first. Moving costs AP per hex; attacking, reloading a sling, switching weapons, and using items cost AP.

Additions that fit the period:

- **Shields.** A shield blocks a share of attacks from the front and sides, depending on Shield skill. Facing matters.
- **Javelins ruin shields.** A thrown javelin that hits a shield can stick in it and make it useless until the bearer spends AP to drop it. Caesar describes exactly this against the Helvetii, and the Roman pilum is built to do it.
- **Aimed attacks** at head, eyes, arms, legs, torso, and groin, with Fallout-style effects: crippled limbs, knockdown, blindness.
- **Morale.** Most enemies flee when their side breaks or a leader falls. Ancient battles were decided by panic. Fleeing enemies can be let go, which affects Honor and later encounters.
- **Formations, lightly.** Allies adjacent to each other with shields get a defense bonus. Legionaries fight as a unit and are dangerous in groups and much weaker alone.
- **Ammunition is cheap and finite.** Sling stones, javelins, arrows. Javelins can be recovered after a fight.

No firearms, no power armor. The iconic endgame armor is a Celtic war-chief's mail shirt with a raven-crested helmet (inspired by the real Ciumești helmet, whose bronze raven has hinged wings that flap). The Gauls are often credited with inventing mail armor, and the game leans on that.

## Quests

### The quest standard

Every non-trivial quest is designed with at least three routes, chosen from: fight, talk (Speech, Presence, a reputation), sneak or steal, a knowledge skill (Lore, Latin, Healing, Surgery), pay or barter, and betray. Every route has a consequence the world remembers. Write the routes first, then the dialogue.

### Example quest: The ford at the Oltis

A band of Germanic horsemen, deserters from Caesar's cavalry, holds the ford below Vindomagos and takes a toll from everyone crossing, including grain meant for Brigodunon.

- **Fight:** Kill or rout them. Hard at low level; they're mounted. The ford is free, and their surviving friends remember you later.
- **Talk (Speech):** Convince them the Arverni are coming in force. They leave, and the ford is free until the lie is discovered.
- **Latin:** They're deserters. Forge a Roman recall order promising amnesty, and they ride off to turn themselves in. Gruesome ending slide.
- **Steal:** Run off their horses at night. They're stuck on foot and open to negotiation, or to the villagers.
- **Barter:** Pay their toll for Brigodunon's grain for the season. Cheap now; they're richer and stronger later.
- **Recruit:** With high renown or Presence, hire them. They show up in Act III, for better or worse.

### Gergovia (built)

Gergovia is the Hub: the first big place, and the first time the player sees the revolt from inside. Two maps: the lower town below the wall (Theron's stall, the market, the smith, the levy camp) and the plateau (the king's hall, the hostage-master, the hostage yard, the pit, the granaries). It is shut until day 7, when Vercingetorix has taken it from his uncle; he is there until day 24, when he marches north into the Bituriges and carries out his sentences first (Caesar BG VII.4: fire for great faults, ears or an eye for lesser ones).

- **A Roman in Gergovia** (main line). The clerk of the house of Vettius hides as Theron's bookkeeper with his master's tablets. They show Brigodunon's hostages sold forward from Noviodunum to Dannotalos, and a blank line for Avaricum: the Act I reveal, early and on paper. Routes: unmask him (Latin, Perception, the potter, Theron), then smuggle him out, buy, threaten, betray to the king's men, steal, or kill. Reading needs Latin or a reader, each with a price.
- **The King's Levy.** The king wants two children and ten spears from Brigodunon. Routes: pledge, give yourself, Lore (Lucterius gives for the Cadurci), pay, sell out Vindomagos, refuse. Home remembers.
- **The Uncle's Man.** An old noble's son is condemned to burn. Routes: argue (Speech), stand surety (Honor), beg (and he loses his ears), bribe, sneak, betray. The clock is the king's march.
- **The Greek.** Theron joins on terms; never if the clerk was betrayed.

### Avaricum (built)

Avaricum is the Necropolis: one location, three states. The world map picks the map and entry by flag (`map_by_flag`). Before day 108 it's the rich city: graveled lanes, carved door-posts, the ironworks, the murus gallicus at the south gate. From day 108 (the siege calendar event) it's full: refugees from the twenty burned towns, the king's picked men, the miners under the terrace; the player comes in at night through the marsh. On day 133 the terrace burns and on day 136 the breakout is stopped (Caesar BG VII.24-26). A map can end on a day (`deadline`): on day 137 a player still inside sees the fall (VII.27-28) and is put out on the world map, titled "One of the eight hundred". After that it's the ruins map, held by a Roman camp.

- **The Empty Line** (main line). The tablets left a blank for Avaricum; Epomeduos fills it. Routes: expose him to Senodonnos, turn him, buy him, kill him, steal his letter. Each way, the trail points to Noviodunum.
- **Under the Terrace.** The countermine, four ways: dig, listen, pitch, sortie.
- **The Most Beautiful City.** Nertomara's children: early with a good word, by boat, by the adit, by the king's runners. The city itself can't be saved; the clock is history's.
- **What the Soldiers Left.** A girl in the ruins: stealth, Latin, silver, the factor's word, or force.

## Items and economy

- **Weapons:** daggers, swords (Gallic long swords and Roman short swords), axes, spears, javelins and pila, slings, bows, clubs. Quality tiers: crude, common, fine, masterwork.
- **Armor:** leather, padded linen, mail, Roman helmet types, Gallic helmets, shields of several sizes.
- **Consumables:** healing herbs, poultices, bandages, wine (Roman wine is a luxury and a trade currency), mead, beer, preserved food.
- **Currency:** silver. Gallic coins and Roman denarii both exist as flavor, but there is one money value. Prices depend on location, faction standing, and Barter. Wine trades high in Gaul and low in Roman camps.
- **Quest items:** hostage tokens, the ledger, orders, sealed tablets, druidic objects.

## Companions

Fallout 1 has four or five companions. We aim for five, each with a personal quest, an opinion of the player, and an ending slide.

- **A war dog**, because some things are universal.
- **Theron**, a Greek trader from Massilia: interpreter, coward, bookkeeper, the funniest person in the game.
- **A disgraced bard** who will make you famous for a price, and who is writing your story whether you like it or not.
- **A Germanic deserter** who wants to go home across the Rhine, the hard way.
- **A Roman auxiliary** of Gallic birth, with a conscience problem and a good sword arm.

## Presentation

### View and art

Isometric 2D, as in Fallout 1. Fallout's character art was actually pre-rendered 3D: models rendered to sprites from six directions, one for each hex direction. We do the same, with low-poly models in Blender (already set up locally, with an MCP connection) rendered to sprite sheets under one fixed camera, one lighting rig, and one palette. Every asset comes out of the same pipeline, so the art stays consistent, which is the hardest problem in AI-made 2D art.

The pipeline exists (M7): `art/sprites.py` renders walls, cliffs, cave walls, rocks, trees, props, a recolorable figure with its gear as separate layers, and beasts; `art/pack.py` packs them; `tools/build-art.sh` does both. Walls and rock join their neighbors automatically, people are a gray body (man, woman or Roman, drawn 1.3 times life size) tinted per NPC, with hair, face, torc and equipped gear stacked on top as layers chosen from the NPC's look, and ground is tiling textures with soft edges. Roofs are built in the game from each house's outline (`src/view/roofs.gd`), vanish while the player is inside, and go see-through when the player is behind them. The style is Rendered: the Blender sprites under a hard sun, outlined, with a color grade (contrast, desaturation, warm tint, vignette) over the map. F2 on a map still cycles it with the rejected Pixel and fixed-palette filters and the code-drawn placeholders, for comparison and debugging. Anything without a sprite yet (beasts other than the wolf) falls back to the placeholder drawing. Nothing about the art blocks the systems.

Interface: an earthy, bronze-and-leather feel to match Fallout's. Dialogue uses portraits with a text box. Fallout's animated talking heads are out of scope at first; static portraits are in.

### Sound

Placeholder at first, then a small original or CC0 set: ambience per region, combat sounds, a few musical themes. A low priority until the game is fun.

### Text

The game is text-heavy, like Fallout. All text lives in data files, never hard-coded, so T can rewrite every line later without touching code, and so translation stays possible.

## Technical summary

The architecture will get its own document when the code exists. The commitments:

- **Engine:** Godot 4.7, GDScript only (C# doesn't export to the web), exported to Windows and to the web. Web is the easy way to share it.
- **Rules separated from presentation:** combat, skill checks, stats, and quest state are pure GDScript with no scene dependencies, run headless, and covered by tests. Random rolls go through one seeded generator so fights can be replayed.
- **Data-driven content:** items, characters, quests, dialogue, encounters, and maps are data files in the repo, readable by a person and writable by an agent. A dialogue format is to be chosen; the requirement is that a writer can read and edit it comfortably.
- **Saves:** plain data files, versioned.

## Scale target for the full game

Roughly Fallout 1's size: about a dozen locations, 60 or more named characters with real dialogue, 60 to 80 quests, a hundred-odd items, five companions, and complete ending slides. Built in milestones, each one playable.

Length, by Fallout 1's HowLongToBeat figures (T's reference): about 16 hours for the main line, 23 with side quests, 32 for everything.

## Open questions for T

- Real names for Brigodunon, Vindomagos, Vettius, Dannotalos, and the companions. Placeholders are in use until then. The demo adds more placeholders: Vellaunos (chief elder), Matugenta (the player's mother), Cintugnatos (vates), Cobnertos (smith), Moccos (gate guard), Dubnacos (the exile), Sulicena (headwoman of Vindomagos), Lugurix (salt merchant), Banna (healer), Haldo (the deserters' leader), and the hostages Ateula and Iccios. The player's sister is Eponina. Gergovia adds: Theron (the Greek), Paconius (the Vettius clerk), Ollognatos (hostage-master), Ategnatos and his son Eppillos, Senognatos (levy captain), Excingos (smith), Nammia (food seller) and Uxellos (potter). Avaricum adds: Senodonnos (Biturigan magistrate), Epomeduos (the Aeduan factor), Nertomara (weaver), Andecamulos (master of the mines), Vindos (boatman), Sumelis (market woman) and Hermeros (Vettius's freedman).
- The secret ahistorical path: yes or no. Default no.
- Is the player character fixed (a named person) or player-made? Default: player-made name and sex, fixed origin in Brigodunon, like Fallout.
- How dark the Avaricum and Alesia sequences may get. Default: shown plainly, never lingered on.
