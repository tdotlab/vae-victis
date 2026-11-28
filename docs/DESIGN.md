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

These events happen on schedule. The player can witness them, take part in them, and change their local consequences, but not their outcome. Day numbers follow the research, which reconstructs them from Caesar's own day counts and seasons; Caesar gives no calendar dates, so each is approximate. Every event through Alesia is in `data/calendar.json`, as news on its day and as the flags content checks (`gergovia_besieged`, `litaviccus_column`, `column_turned`, `cabillonum_riot`, `gergovia_lifted`, `aedui_defected`, `volcae_raid`, `german_horse`, `council_of_gaul`, `alesia_begun`, `act2_over`).

| Day | Event | Effect on the game |
|---|---|---|
| ~1 | Carnutes massacre the Roman traders at Cenabum. News crosses Gaul by men shouting from field to field and reaches the Arverni by nightfall. | Game start. The revolt is lit. |
| ~7 | Vercingetorix, expelled from Gergovia by his own uncle, raises the rural poor, comes back, drives out his opponents and is hailed king. | Gergovia changes hands; its quests change. |
| ~56 | Caesar crosses the Cevennes through deep snow and appears where no one expected him. | Roman patrols appear on the world map. |
| ~105 | Scorched earth: the Bituriges burn more than twenty of their own towns in one day to starve Caesar. They beg to spare Avaricum, and are allowed to. | Several world-map locations burn. Refugees appear. |
| ~108–137 | Siege and sack of Avaricum. Caesar says barely 800 of about 40,000 escaped. | Avaricum is a timed location: after it falls, it's ruins. |
| ~144 | Caesar settles the disputed Aeduan magistracy at Decetia in favor of Convictolitavis (VII.33). | The Aedui start to waver. |
| ~161 | Caesar reaches Gergovia and camps under it; Vercingetorix holds the slopes behind a six-foot stone wall (VII.36). | Gergovia's besieged face. |
| ~172–180 | Convictolitavis, paid by the Arverni, sends Litaviccus with the Aeduan levy toward Caesar; Litaviccus tells it Caesar has killed its nobles, and the Roman citizens with it are tortured and killed (VII.37-38). At home the Aedui plunder the Romans, and the tribune Aristius and the traders are led out of Cabillonum under a promise and attacked on the road (VII.42). | The column on the roads; Cabillonum's riot. |
| ~190 | Caesar is beaten at Gergovia. | Revolt morale peaks; Roman standing drops everywhere. |
| ~196 | The Aedui, Rome's oldest allies, defect. They seize the Roman depot at Noviodunum, kill its garrison and the Roman traders, split the army's money and horses, and take the hostages to Bibracte (VII.55). | Hostages move to Bibracte. Without its pay chest, Caesar's army sells the war forward to the house of Vettius (invented; Act II). |
| ~205 | Caesar sends across the Rhine for German horse and light infantry and mounts them on his officers' horses (VII.65). Vercingetorix sends the Cadurci and Ruteni to raid the Volcae Arecomici (VII.64). | Brigodunon's young men go south; the Germanic camp's choice gets urgent. |
| ~215 | Vercingetorix is confirmed supreme commander at a council of all Gaul at Bibracte. The Aedui, who wanted the command, submit unwillingly (VII.63). | Act II's set piece. |
| ~230 | Vercingetorix's cavalry attacks Caesar's column and is routed when the Germans take the ridge (VII.67). He falls back into Alesia. | Act II ends. |
| ~231–284 | Siege of Alesia. The Mandubii expel their women and children, and Caesar refuses to take them in (that they starved between the lines is Cassius Dio's detail, not Caesar's). A relief army fails. Vercingetorix surrenders. Caesar gives one captive to each of his soldiers, except the Aedui and Arverni, whose men he sends home. | Act III. The game ends here. |
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

### Act II: The ledger (days ~120 to ~230)

Fallout's second act is the discovery that the water chip was never the real problem. Ours is the same move. The real enemy isn't Rome, which no one can beat. It's the people who turned the conquest into a market and are positioned to profit from every outcome, including the revolt. Dannotalos helps arm the rebels, because a bigger war means more captives.

**The turn.** A few days after the assembly, the house of Vettius sends a man to Brigodunon, and Vellaunos seats him at his own hearth, because a guest is a guest. He is polite. Rome will win, he explains, and when it does, the Cadurci will be sold like everyone else. For a price the house will write Brigodunon down as not for sale. It is protection from a list that doesn't exist yet, sold by the people who are going to write it. Whatever happened at Noviodunum, this works: if the hostages came home, the house wants its half-paid property or its price; if they didn't, it offers to sell them back. Either way the hill itself is now on the table. That is Act II's water chip: **get Brigodunon off the house's book before the harvest.**

**The escalation.** On about day 196 the Aedui seize Noviodunum and Caesar loses the hostages, his grain and the army's pay chest (VII.55). An army that can't pay its soldiers sells what it hasn't taken yet. The house of Vettius has the coin, lent to it by Massiliot bankers, and buys the war forward: the future captives of whole peoples, at a discount, from the quartermasters who will sell them (the forward sale is invented; the lost pay chest is Caesar's). The revolt's best summer is what makes the market. After day 196 the list is real, Brigodunon is a line on it, and the price of striking it off goes up tenfold.

**The house.** Vettius's network has five parts, and each can be broken in Act II:
- **The partner:** Dannotalos at Bibracte, who supplies Gallic captives and protects the house in Aeduan country.
- **The paper:** the master book at Cabillonum, which proves every purchase.
- **The stock:** the Pens, where what the house has already bought waits for the boats south.
- **The muscle:** the Germanic horsemen who guard the Pens and catch runaways.
- **The credit:** the Massiliot money behind it all.

The player can't stop the harvest at Alesia. What they break decides what Vettius brings to it in Act III, and what he can collect.

**The council.** Act I ends at a village assembly; Act II's set piece is the assembly of all Gaul at Bibracte on about day 215, where Vercingetorix is confirmed and the Aedui swallow it (VII.63). The hostages of Gaul are in Bibracte by then, and the Aedui are using them to frighten peoples who hesitate (VII.63: "horum supplicio dubitantes territant"). The player can be in the crowd or on their feet: for the hostages, against Dannotalos, for Brigodunon's name.

**The end.** On about day 230 Vercingetorix's cavalry breaks against Caesar's new Germans, and he falls back into Alesia (VII.67-68). Act II closes with slides, and everyone converges on Alesia. The details are under Quests, in "Act II: the house of Vettius".

### Act III: Alesia (days ~230 to ~284)

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
| **Bibracte** | Aeduan capital. Rich, Romanized, collaborating until it isn't. Endless intrigue. Dannotalos's house, the hostages of Gaul after day 196, the council of all Gaul. | The Boneyard / Adytum politics |
| **Cabillonum** | Aeduan river port on the Arar, full of Roman traders until the riot of about day 178. The house of Vettius and its master book. | The Hub's water merchants: the people who sell what everyone needs |
| **Noviodunum** | Caesar's depot on the Loire. Hostages, baggage, horses. Seized by the Aedui around day 196. | Military Base, act one version |
| **The Germanic camp** | Mounted mercenaries in Caesar's pay, and deserters from them. Raiders, horse thieves. | The Khans |
| **The Bone Field** | An old battlefield shrine where the victors displayed the dead. Robbers selling the gods' iron to arm the revolt, and a sickness they call a curse. | The Glow |
| **The Pens** | Vettius's captive depot at a river crossing below Cabillonum. Hidden until found. | Mariposa: the place where people are turned into product |
| **Alesia** | The siege. Several areas: the town, the Roman lines, the relief camp. | The Master's lair |

Plus random encounters: refugees, patrols, foragers, deserters, wolves, bandits, a traveling bard, a Greek merchant from Massilia, and occasional strange ones, as in Fallout.

## Factions

| Faction | Wants | Notes |
|---|---|---|
| **Brigodunon** | To survive the year with its children back | The player's standing at home is its own reputation track |
| **Vercingetorix's revolt** | A united Gaul under one command, at any cost | Burns its own towns, executes waverers. Admirable and frightening. |
| **Rome (Caesar's army)** | Pacification, plunder, glory for Caesar | Not a monolith: legionaries, officers, auxiliaries, quartermasters |
| **The Aedui** | To come out on top whoever wins | Split between pro-Roman and pro-revolt nobles; defects at day ~196 |
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

The guest-bond is a rule, not just a dialogue option. A map declares its roofs (`"hospitality"`: a host faction, optionally the marked area or list of marks it covers, and optionally an `if_flag` that has to be set). Attacking anyone under a roof who wasn't already fighting you, or a dialogue `~ violate <host>`, costs 60 Honor and 40 standing with the host's people, logs it, and sets `guest_murder`, which every companion with a view on it reacts to. A map with no roof declared has no guest-bond, so content has to declare it where it applies.

**Renown** is how widely your deeds are known, good or bad, and the bards decide what the story is. High renown opens doors and draws challenges. Named reputation titles appear in dialogue ("Guest-Slayer," "the one who came back from Avaricum").

**Faction standing** is tracked per faction, separately.

## Combat

Turn-based, on a hex grid, with action points, like Fallout. Sequence decides who moves first. Moving costs AP per hex; attacking, reloading a sling, switching weapons, and using items cost AP.

Additions that fit the period:

- **Shields.** A shield blocks a share of attacks from the front and sides, depending on Shield skill. Facing matters.
- **Javelins ruin shields.** A thrown javelin that hits a shield can stick in it and make it useless until the bearer spends AP to drop it. Caesar describes exactly this against the Helvetii, and the Roman pilum is built to do it.
- **Aimed attacks** at head, eyes, arms, legs, torso, and groin, with Fallout-style effects: crippled limbs, knockdown, blindness.
- **Morale.** Most enemies flee when their side breaks or a leader falls. Ancient battles were decided by panic. Fleeing enemies can be let go, which affects Honor and later encounters.
- **Getting out.** Stepping onto a map exit mid-fight escapes if no enemy is within two hexes. A band of three or more equals beats a lone character on open ground almost every time, so a fight a failed roll would start always offers a way out first (run, talk, pay), and a deliberate one shows the odds before it starts.
- **Allies.** Friendly bands fight on the player's side: a dialogue `~ ally` or `~ ally_all <faction>` turns people into allies, who join any fight that starts within ten hexes of the player or that they can see, and act on their own turn. They wear a blue ring, can't be attacked by a misclick, and don't count as enemies for escaping or ending the fight. This is what the Wall at Gergovia, the Tribune's Road and storming the Pens are built on.
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

### Cenabum (built)

Cenabum is the Junktown: a Carnute river town on the Liger with a wooden bridge, where the revolt began. The Roman traders' houses are gutted and nobody has rebuilt them; the people who killed them still walk past every day. Caesar takes Vellaunodunum around day 94-97 and Cenabum on day 100: the townsfolk try to slip out over the narrow bridge at night, are caught, and the town is plundered and burned (BG VII.11). The world map switches it to a burned map (`map_by_flag`). The leaders of the massacre (Caesar's Cotuatus and Conconnetodumnus) are talked about, not met.

- **The Roman's Widow.** Litumara, a Carnute woman, was married to a freedman of the dead commissary Fufius Cita. She hides with her son, who has a Roman name and a Gallic one, and with her husband's seal and grain ledger. Atepomaros, whose brother went to the Romans as a debt slave, wants the boy. Routes: get them out at night (Sneak), argue for them before the elder (Speech, or Lore: blood of the tribe is the druids' to judge), pay Atepomaros the blood price, betray her, or fight. Saving her gets the commissary's seal and the ledger (which names the depot at Noviodunum); betraying her gets the seal off her body. The seal is a way into Noviodunum and a tool for a forged order there.
- **The Narrow Bridge.** From day 94 the news of Vellaunodunum says Caesar is two days off. Senuacos the elder means to take the town out over the bridge at night, which is how they're all caught. Routes: talk him into leaving by day (Speech, or Renown), find the old ford upstream (Survival or Lore), or pay Onnacos the boatman to ferry the families downstream at night. Fails if the town is still inside on day 100.

### The Carnute forest (built)

The Brotherhood: the sacred grove where the druids of all Gaul hold their yearly session (BG VI.13). Not the session yet; the grove is never empty. A ditched enclosure with a pit and racks of offered weapons, after Gournay-sur-Aronde. Hidden on the world map until the vates at home, the Cenabum elder, or the road shows it.

- **The Judgment.** Bring Brigodunon's case: does a pledge still bind when Rome has sold the pledged? Senouindos the druid hears it. Routes: show the evidence (the tablets, the factor's list, the letter, Hermeros's day book), argue the law (Lore), argue the case (Speech or Presence), keep the vigil in the grove for a night (Fortitude or Endurance), or give to the gods first for a better hearing. A verdict that the pledge is void carries weight at the assembly at home; a straight answer that it still binds is an argument too, for keeping faith. The druid's token gets you past an Aeduan gate.
- Bitugenos the bard sings your deeds back to you, mostly wrong, from what you've done. Pay him for a better version (renown) or correct him (Speech).

### Noviodunum: the end of Act I (built)

Caesar's depot on the Liger in Aeduan country: a palisade and ditch on the river flat below the Aeduan town, with horse lines, granaries, the paymaster's hut, the quartermaster's office, and a long low house by the river where the hostages of all Gaul are kept (BG VII.55). Lucius Orbius, the quartermaster, is the officer who cut Brigodunon's tally five years ago. Dagolitos keeps the gate for Dannotalos.

Getting in: Dannotalos's letter, a bribe to Dagolitos, the druid's token, offering yourself to Orbius as an interpreter (Latin), the dead commissary's seal (Latin or Speech), or the river at night (Sneak).

Inside are Eponina, fourteen and fluent in Latin; Iccios, who works the depot forge and is afraid to run; and Ateula, who copies Orbius's rolls and won't leave the others unrecorded. Each needs something: Iccios his father's word (Cobnertos's token) or a good argument; Ateula a strong argument, or she stays and gives you a copy of the roll of every hostage and who has bought them (the Act II thread).

Getting them out:
- **Orbius's word.** Show him his own tally. He promised they would go home if the Cadurci kept faith. Speech or Honor; he writes them off as dead of fever.
- **Buy them.** Silver per head, less with Barter.
- **Dannotalos's claim.** With the letter, ask for early delivery on Dannotalos's account (Speech, or automatic if Epomeduos wrote you in as partner). Dannotalos will remember.
- **Paper.** Forge a release in the proconsul's name with the commissary's seal or Orbius's own (Latin).
- **By night.** Prepare them, then lead them out through the river (Sneak), helped if Neitin the Spanish horse-boy turns the horses loose. Failure means fighting the house guards.
- **Leave them.** They are safe until the autumn; the Aedui will take them to Bibracte on about day 196 (Act II).

Freed hostages walk home and are in Brigodunon when the player gets there.

**The assembly.** Back home, Vellaunos calls the assembly, with Lucterius's man in the hall. The player speaks: rise with Lucterius, hold back while Rome has hostages, or send the young men and keep the village's name out of it. Evidence and the druid's verdict make arguments easier. The Cadurci rise either way, as they did; the choice is how Brigodunon goes into it. If the player is not home by day 120, the assembly meets without them and rises. The act closes with Fallout-style slides (one per thing the player changed) and play continues.

### Act II: the house of Vettius (designed)

Act II is open from the start and gets tighter as history arrives. Days ~120 to ~160 are free: the house is intact, the Aedui are still Rome's friends, and every place in this section can be visited in any order. Days ~160 to ~200 are history-heavy: the siege of Gergovia, Litaviccus's column, the Cabillonum riot, the fall of Noviodunum. Days ~200 to ~230 are the reckoning: the forward sale, the council, the retreat into Alesia.

Two rules bind it. **Act I's slides are canon**: they narrate day 196 in advance, so Orbius dies at Noviodunum in every game, Iccios and Ateula go to Bibracte if they stayed, and Act II can't undo it. **History doesn't wait**: a quest whose moment passes fails, the way the bridge at Cenabum does.

#### The main line

- **The House Collects** (opening). The house's man comes to Brigodunon as Vellaunos's guest. He is Epomeduos if he's alive and wasn't exposed (if he was turned in Act I, he comes half to warn you, as your "partner"); otherwise he's Diodotos, another of the house's freedmen (Hermeros stays at Avaricum). What he asks for depends on Act I. If the hostages came out by fraud or by night, he wants the house's property or its price. If Orbius wrote them off as dead of fever, or sold them to you, he has no claim on them, so he only sells protection. If they're still held, he offers to sell them back, delivered on Dannotalos's word. Routes:
  - Pay the first price (cheap now, and it funds the machine).
  - Read his paper (Latin): the protection runs "on Dannotalos's account", which points to Bibracte, and the seal is the house's at Cabillonum.
  - Show him the door. The house doubles the price, and from about day 150 riders who don't speak Gallic drive off Brigodunon's cattle as a reminder.
  - Follow him when he leaves (Sneak): twelve days on his trail to Cabillonum, and he stops at the Pens on the way, so the player hears of them early. Followed clumsily, he gets there anyway and the house knows the player's face (`house_warned`).
  - Kill him. Under Vellaunos's roof that is guest-murder, the worst crime in the game: Honor collapses and the vates curses the hall. On the road afterward it is only murder, and the house knows who did it. Vellaunos says so ("do it on the road... Not at my hearth"): wait for him there, then rob him of his paper, kill him, or let him pass.

  If the player doesn't come home by about day 150, a runner from Vellaunos finds them on the road with the news.

  As built (A2.2): the house's man arrives on day 121 (`house_due`) and waits at Brigodunon until the player comes. Paying, the door, the paper and the kill each close The House Collects; the hall is a roof (`hospitality` over the hall, the elders and the guest's place by the fire) only while he's there.
- **The Line for Brigodunon** (main). Get the hill off the book before the harvest. The price is low before day 196, ten times higher after it, and gone at Alesia. Routes:
  - Buy it off (silver; Barter lowers the price).
  - Burn or steal the master book (The Countinghouse).
  - Forge the line struck (Latin and the house's seal, through Paconius or the seal ring).
  - Have Dannotalos strike it, since it's on his account: as his partner, under threat (the Bone Field, Ateula's roll), or as the price of his life.
  - The law: a people that kept faith isn't booty. With `brig_faith`, or `pledge_bound` plus Latin or Speech, a Roman officer (the auxiliary companion's centurion, or the officer whose seal is on Orbius's copy) writes Brigodunon down as friends of the Roman people, and the line is void.
  - Starve the house of coin before day 196 (Theron's Debt). It can't buy the forward sale, and the line is never written.

  Whether the line stands decides Brigodunon's epilogue slide (Uxellodunum, 51 BC).
- **The House of Vettius** (umbrella). The journal tracks the five parts (partner, paper, stock, muscle, credit) and what the player has done to each. Nothing forces any of them. All five broken means Vettius comes to Alesia a ruined man with a few freedmen. All five intact means he comes with a camp of buyers and paper on half of Gaul.

Joining is a full path, as joining the Master is in Fallout: become Dannotalos's or Vettius's partner. The price of a partnership is your own line struck. The reward is silver and a share of the trade. The consequence is everything else on the book, and the bards. Act III's "slavers' camp" stand starts here.

#### Brigodunon (Act II)

The village as the assembly left it. If it rose or split, the young men go south to Lucterius, and on about day 205 they're sent with the Ruteni to raid the Volcae Arecomici (VII.64). That is news here, and a reunion in Act III, where the Cadurci are counted inside the Arverni's thirty-five thousand at the relief of Alesia (VII.75). Dubnacos, if he was pardoned, rides with them. The house's man and its reminders arrive here, and so does the epilogue.

#### Cabillonum (designed)

The house's seat: an Aeduan river port on the Arar (Saône), east of Bibracte, where Italian wine comes upriver and people go down it. The riverbed at Chalon-sur-Saône is famous for the mass of Republican wine amphorae dredged from it (verify the numbers before using them in text). There is a Roman traders' quarter, warehouses of amphorae, and Vettius's house with its strongroom. Three faces: open until the riot; the riot on about day 178 (VII.42); and after it, when Vettius is the last Roman in Cabillonum, alive because Dannotalos's spearmen stand at his door. That one image is the whole act. Vettius himself is here: met once, polite, tired, precise ("we pay on time and we write everything down"), and killable. Killing him doesn't kill the house: Hermeros inherits the book and runs the harvest. Only the paper stops the machine.

- **The Countinghouse** (the paper). The master book is in the strongroom, kept by the house's own slaves. Routes:
  - Steal it at night (Locks, Sneak).
  - Get in under cover of the riot, or lead the mob to the door. Then the book burns: destroyed, not held.
  - Use an inside hand: Paconius if he was saved in Act I, or a slave clerk offered his freedom.
  - Sign on as the house's factor for the Cadurci hills and read it from inside.
  - Copy the pages that matter in place (Latin and Wits). The house never knows, and the player holds the evidence.

  Destroyed, held and copied are three different states for Act III. A held book names the officers who sold the war forward.

  As built (A2.2, the open face): Paconius is here as the house's clerk if he was saved in Act I (he ran south for Narbo and his money ran out at Vettius's door), and Felix is the slave clerk. The strongroom opens by night (Sneak, Locks and Sneak, Felix, a bribe, or talking or knocking the keeper out of the way; a warned house keeps a dog and takes no bribes), by day for the house's factor or with the seal ring, or on Paconius's arm. At the lectern: read (Latin or Theron), copy (Latin and Wits, Theron, or Felix over three nights), strike the line (Latin and the seal, or Paconius), take, or burn. Taking the book after Paconius let you in makes him run. The riot routes come with the riot (A2.6).
- **Theron's Debt** (the credit; Theron's personal quest). Theron's elder brother, a Massiliot banker at Cabillonum, lends the house the coin it lends to soldiers. Theron owes the family for a ship of wine he lost and won't talk about. Routes:
  - Persuade the brother to call the loan. Before the riot this needs the player's warning about the Aedui and Theron's word; after the riot the brother believes it.
  - Buy the debt, so that the player and Theron become the house's creditors.
  - Settle Theron's own debt (reconciliation; no effect on the house).
  - If Theron thinks little of the player, or the player has joined the house, Theron sells them out and goes home to his family.

  The loan called before day 196 means no forward sale. Called later, it squeezes the house in Act III.

  As built (A2.2): the brother is Demarchos. Theron decides at the gate on arrival (opinion below zero, or the player is the house's factor, and he sells them out); otherwise the quest starts there. Before the riot, calling the loan takes Theron's word plus either the news that the Aedui are wavering (`aedui_wavering`, day 144) or Speech.
- **The Tribune's Road** (about day 178). The Aedui plunder the Romans. The tribune Aristius and the traders are led out of town under a promise and attacked on the road, and they hold out for a day and a night (VII.42). Routes:
  - Hold the road with them (a fight with Roman allies).
  - Get a trader's Aeduan wife and children out by the river (Sneak); it echoes Litumara.
  - Join the plunder (silver, Aeduan standing).
  - Stand aside.

  The next day the Aedui claim it was the mob (VII.43).

#### The Pens (designed)

A fenced compound on the river flat at a crossing below Cabillonum, where what the house has bought waits for the boats down the Arar and the Rhodanus to the Province. Iron gang-chains, which are known from Late Iron Age Gaul and Britain. Hidden until found: the master book, the house's man followed, the Germans, Hermeros, or the boatmen at Cabillonum show the way.

The overseer is a Gaul, one of Dannotalos's ambacti, doing a job. The captives are debtors sold by Gallic nobles (some of them Dannotalos's own clients), runaways caught on the roads, Avaricum's few, and a Roman deserter: the machine eats its own. Among them are a Cadurcan from a fort near Brigodunon, a Biturigan boy, and a Senone woman who keeps count of the days.

- **The Pens** (the stock). Routes:
  - Turn the guards with their wages (see the camp): they walk off or open the gate.
  - Break them out by night (Sneak, Locks, the boats). The hard part is where sixty people go: the druids' grove, Bibracte as free Gauls after day 196, Brigodunon if the village agrees, or scattered on the roads, where many are caught again.
  - Storm it, with allies: Haldo's riders if hired, the war band if Brigodunon rose, the Germans if turned, or the Aeduan mob after the riot.
  - Move them out "legally" on a forged order of the house (Latin and the seal).
  - Buy people: one, a few, or all of them, at a price that ruins anyone.
  - Burn it. Freed in the chaos, some die.
  - Sell runaways to it, or take the overseer's job (joining).

  Freeing the Pens' captives has its own slides. A stock the house can't replace is a camp it can't fill at Alesia.

#### The Germanic camp (designed)

Horse lines and hide shelters in a forest clearing toward the Dubis: a band of Germanic horsemen who rode for Caesar, are between masters now, and earn their bread catching and guarding for the house. Their leader (placeholder) is an older man who is careful with his men and doesn't care about anyone else's. They aren't savages and they aren't noble. They're professionals a long way from home, paid late.

- **Wages** (the muscle). The house pays late, and later still if Theron's brother squeezes it. Routes:
  - Outbid it: a month's pay and they ride for the player once.
  - Rob the house's paymaster on the road. Unpaid, they turn on the house, and plunder the Pens for themselves unless the player is there first: freed from the house is not the same as freed.
  - Tell them what's coming (Latin from the Roman lines, Lore, or Speech): Caesar has sent across the Rhine for fresh horsemen, who are being given Roman officers' horses (VII.65) and will be set to hunt deserters. They go home now, the Pens lose their guards, and Gundo's way home begins.
  - Fight their champion one on one (fair, and the arena should show it): they stand aside at the Pens.
  - Hire them to the house yourself (joining).
- **Haldo's debt.** With `ford_lied`, Haldo's band is here and knows there was no Arvernian army: pay, fight Haldo alone, or own it to his face (Honor or Presence). With `riders_recalled`, one rider who stayed behind knows what happened to the men who went to their "pardon" (Roman deserters' deaths), and knows whose order it was: talk, pay or fight. With `riders_hired`, the camp knows them, and you, and that buys respect.
- **The Way Home.** Gundo (placeholder), a young rider who wants to go back across the Rhine "the hard way", joins once the wages are settled or the band breaks up. His quest resolves in Act III.

#### The Bone Field (designed)

A bare ridge between Bibracte and the Carnute country with a square ditched enclosure, where, long ago, the victors of a battle nobody remembers displayed the beaten army's dead and their arms. The bones were later stacked into square ossuaries, and the weapons left on racks and in the ditch. The model is the sanctuary at Ribemont-sur-Ancre (verify details before writing text). Caesar says Gauls heap their spoils in consecrated places, that hardly anyone dares touch them, and that the penalty is death with torture (VI.17).

Robbers are pulling the old iron out and selling it to Dannotalos's agent, who sells it to the revolt's smiths to fill the king's arms quotas (VII.4). The gods' iron is arming Gaul against Rome, which makes it a good question. The robbers are sick: men cut on the old iron clench up and die. It's lockjaw, and they call it the god. The old keeper is dead, and his dog won't leave him.

- **The God's Iron.** Routes:
  - Drive them off (a fight against a few men, some too sick to stand).
  - Scare them off (Lore: name the god whose iron it is; Fortune).
  - Tend the sick (Surgery or Healing). Lockjaw can't be cured, but the wounds of the others can be cleaned, and the dying man, grateful, names the buyer and gives up the robbers' tally.
  - Take the tally and a sworn robber to the druids. It is evidence of sacrilege, and it can finish Dannotalos (The Partner).
  - Buy the iron yourself for Brigodunon's spears. If the druids learn of it, the interdiction falls on you.
  - Leave it be: the iron goes to war (a slide).
- **The keeper's dog.** Bury the keeper (Lore, or just a spade and an hour) or feed the dog, and it follows you: the war dog companion.

#### Gergovia besieged (designed; days ~161-190)

Gergovia's third face, made with `map_by_flag` like Avaricum's. Caesar's camps are in the plain, and his men take the small hill opposite by night and link it to the camp with a double ditch (VII.36). The Gallic camps fill the slope up to the wall behind a six-foot stone wall (VII.46). A new map covers the slope, the stone wall and the valley; the lower town and the plateau change.

- **The Sutler** (about days 161-185). Someone is selling grain across the valley to the Roman camp, which is short and waiting for the Aeduan column. It's the house's new man in the lower town, buying from the old uncle's party. With `verc_surety`, the accused is Eppillos, and the king calls in the player's surety. Routes:
  - Find the real sutler (Perception, Latin overheard at the Roman lines, the potter).
  - Turn him, and feed the Roman camp false word.
  - Smuggle the accused out to the Romans (Honor with the king, lost).
  - Take the king's sentence in his place: as surety, the cost is real.
  - Hand over whoever is convenient.
- **The Wall** (day 190). The assault. The legions come over the stone wall and take three camps; Teutomatus, king of the Nitiobriges, the Cadurci's neighbors, is caught napping at noon and gets away half-dressed on a wounded horse (VII.46). The women on the wall, who a moment ago were holding out their hands to the Romans, turn to their own men and hold up their children (VII.47-48). Allied Aedui come up on the Roman flank with their right shoulders bared as the agreed sign, and the Romans take them for the enemy anyway (VII.50). The centurion Petronius dies at a gate to buy his men time (VII.50). Routes:
  - Hold the wall in the line (an allied battle).
  - Carry the wounded (Healing, Surgery).
  - Bring the old men and boys up to the gate (Presence).
  - Watch it from the Roman lines as an interpreter (Latin), and hear what they say afterward.

  The outcome is fixed: the Romans fall back, with 46 centurions and nearly 700 men lost (VII.51), and in his account Caesar scolds his soldiers for being too brave (VII.52). The reward is a title: "who stood at Gergovia".
- **The King's Errand.** With renown, or as his pledge (`levy_self`), Vercingetorix sends the player to Bibracte to watch the Aedui before the council, with a token that gets them into it.
- Brigodunon's two children, if pledged (`levy_pledged`), are in the hostage yard: well fed, and going wherever the king goes. In Act III that is Alesia.

#### The Aeduan column (designed; road event, days ~172-180)

On the Aeduan roads toward Gergovia: Litaviccus and the Aeduan levy, after he has told them Caesar killed their nobles. The Roman citizens traveling under their protection are tortured and killed, and the grain is plundered (VII.38). Routes:
- Get the Romans out before it starts (Sneak, Speech).
- Expose the lie. The player may have seen Eporedorix alive (at Bibracte or Noviodunum), or have the bard's news; Speech carries it.
- Ride with the column.
- Take the dead traders' papers in the confusion: the house's grain contracts with the Roman camp, which tie back to the sutler.

Whatever the player does, Caesar intercepts the column and Litaviccus escapes to Gergovia (VII.40).

#### The fall of Noviodunum (designed; day ~196)

The depot from Act I, on its last day. Eporedorix and Viridomarus come in, Dagolitos opens the gate for Dannotalos's men, the garrison and the Roman traders are killed, the money and the horses are shared out, the hostages are sent to the magistrate at Bibracte, and the town is burned (VII.55). Before day 196 every Act I route still works. A player inside on the day can:
- Go with the hostages: a way into Bibracte's hostage house from inside.
- Save the Gallic-born auxiliary, whom the Aedui would kill with the garrison, by claiming him as kin (Speech, Presence) or hiding him. He becomes the auxiliary companion.
- Be with Orbius in his last hour. He gives the player his own copy of the forward sales, the army's half of the house's paper, naming the officers.
- Take a share of the pay chest in the confusion. It's enough silver to buy the line, and Eporedorix's men will look for it.
- Help the Aedui open the river gate (Aeduan standing).

After day 196 it's a burned map: ash, the ditch, looters.

#### Bibracte (designed; before day 196 built in A2.3)

The Aeduan capital on its mountain. The murus gallicus runs for miles, and the Porte du Rebout is a gate corridor nineteen meters wide. There is the craftsmen's quarter of smiths and enamelers, the noble houses on the upper ground, and wine jars everywhere. Two maps: the lower town and the gate, and the upper town with Dannotalos's house, the magistrate's hall and the council ground. Before day 196 it's a city of Rome's friends with a lot of young men talking about the Arverni. After it, it holds the hostages of Gaul. Real people, sparingly: Convictolitavis the vergobret, and Eporedorix seen once. The druid's token from the forest opens the gate. The vergobret was chosen "through the priests" (VII.33), so a druid of Bibracte matters here.

- **The Partner** (Dannotalos). Met at his house, at any time. He is an old house gone poor and made rich again, and a man who was a hostage himself: as a boy he was given to the Sequani, by a city that swore never to ask for its hostages back (I.31), and nobody did. He knows what a hostage is worth from the inside, he buys people forward so they're on his book rather than someone worse's, and sometimes that's even true: the girl Epomeduos "lost in transit" at Avaricum is alive. He arms the revolt because a long war raises prices, and because he wants the Aedui, meaning himself, to lead Gaul. He treats the player as a partner (`factor_turned`), a thief (`dannotalos_cheated`), or a curiosity. Routes to break him:
  - Interdiction: take the Bone Field's evidence to the druids, who bar him from the sacrifices (VI.13). Nobody speaks to him, no court hears him, and he's finished without a drop of blood.
  - The council: show Ateula's roll to all Gaul. An Aeduan noble bought Gaul's hostages forward from Rome, and the Aedui, who want the command, give him up.
  - Set the partners on each other: show Vettius that Dannotalos skims (the girl at Avaricum, Epomeduos's double books, or a forged letter with Latin and Wits). The house cuts him off, and paper on his account is void.
  - Challenge him at a feast. He names a champion, and it's one on one. Win, and he strikes the line as his forfeit.
  - Kill him at night. His account passes to the house: murder makes Vettius bigger. That consequence is the honest one.
  - Join him. He wants to cut Vettius out and own the trade himself, a Gallic house in place of a Roman one. Bring him the book or the Pens.

  As built (A2.3, before day 196): Dannotalos is not yet thirty (a boy hostage in about 61 BC). The lower town is the Rebout corridor, the craftsmen's quarter (Gobannos the smith, an enameler), and Esugenos the druid at the spring; the inner gate's warden lets the player up for the druid's token, Dannotalos's letter, the house's factor, Speech, fifteen silver, or as a visitor walked up by the steward Moricos (who then knows their face), and by night only for the token or over the bank (Sneak). The upper town has Dannotalos's hall (a roof once the player has eaten), his chamber behind a hide curtain, Convictolitavis's hall and the council ground. Built routes:
  - The feast and the champion's portion: eating first is the custom (Diodorus V.28), and a guest can claim the thigh joint from Cingetos, his champion (Posidonius in Athenaeus IV.40). The duel is one on one and nobody dies of it: whoever drops yields. Win, and the forfeit strikes the line (`brig_line` done_released), or pays 150 silver if the line is already gone, with a title and renown. Lose, and Honor pays.
  - The roll: threaten him with Ateula's roll (Speech or Presence), or sell it to him for the line.
  - The iron: put the Bone Field to him (strikes the line, makes an enemy), or take it to Esugenos for interdiction (`brig_line` done_barred). Both wait on `iron_tally`, which A2.4 sets.
  - The chamber by night (Sneak, harder if Moricos walked you up): a knife at his throat buys the release; his chest (the key or the lock) holds his own tally of the skim; or murder in his sleep, which passes his account to the house (and breaks the guest-bond if you ate).
  - Vettius: show him the skim with Dannotalos's tally, the girl from Avaricum (Speech, easier once Dannotalos has bragged about "losses in transit"), or a forged letter (Latin and Wits). The house cuts him off and the line is void.
  - Join him with the master book. Joining with the Pens comes with A2.5; the council route with A2.7.
  - Draw a knife in his hall (a fight, and guest-murder if you ate).

  Dannotalos stands in his hall day and night; the chamber's routes take the player off the map, and he's gone on return if he's dead.
- **The Children of Gaul** (after day 196). The hostages of a dozen peoples are kept by the vergobret, and the ones on Dannotalos's account are in his own house as property. With `ateula_stays`, Ateula keeps the vergobret's rolls. With `brig_faith`, Brigodunon is a people that hesitates, and the Aedui threaten its hostages to make the village send men (VII.63). Routes:
  - Argue at the council for the hostages of peoples in the revolt (Speech, the roll, the druid's verdict).
  - Druid law: with `pledge_void`, hostages under a pledge Rome broke must go home.
  - Out by night through the Rebout gate or over the rampart (Sneak), with Ateula inside.
  - Ransom from Dannotalos.
  - Trade the vergobret something he wants more: the master book's page of Aeduan nobles' debts, or the Pens' stock (joining).
  - For Brigodunon, send word home to rise. It changes the village, not just the quest.

  For a player whose three came home, this is Ateula's hundred names.
- **The Council of All Gaul** (day ~215). Fixed: Vercingetorix is confirmed by a vote of the multitude; the Aedui resent it; the Remi, Lingones and Treveri stay away (VII.63). The player gets in with a patron: Lucterius's man, the king's errand, the druid's token, Ateula, or Dannotalos himself. Inside, they can raise up to three matters: the hostages, Dannotalos, and Brigodunon's name, the way the assembly at home works (evidence and arguments add up). A player who isn't there gets the defaults: the hostages are kept as threats, and Dannotalos rises among the Aedui.
- **The Bard's Disgrace.** Bitugenos has come to sing at the council and sings a satire on the wrong Aeduan: Dannotalos, if the player told him the story at the forest, and otherwise a kinsman of the vergobret. He's beaten and thrown out at the gate. Routes: speak for him before the vergobret (Speech), pay his debts, or give him a better story (renown). He follows, writing it. He's the bard companion; once an act he can sing a satire that ruins someone's standing.

#### How Act II ends

On day ~230 the news of the cavalry battle and the retreat into Alesia closes the act, whatever the player is doing. The slides wait for the next safe moment, as the assembly's do. The slides (`data/endings/act2.json`): the line, Dannotalos, each part of the house, the Pens, the gods' iron, Gergovia, Cabillonum, Noviodunum, the children of Gaul, the council, and each companion. Quests whose moment has passed fail; the rest stay open into Act III where history allows (the Pens can be raided later; the council can't be attended later).

What Act III reads: the line (struck or standing), Dannotalos (interdicted, disgraced, dead, a partner, or standing), the book (destroyed, held, copied, or standing), the credit (called early, called late, or intact), the Pens (freed, burned, taken by the Germans, or standing), the camp (gone home, the player's, or the house's), Vettius (alive, or dead with Hermeros running the harvest), the hostages of Gaul, the war band, the levy's children, and the companions.

#### Act I threads and where they pay

| Act I flag | Pays off in Act II |
|---|---|
| `epo_out`, `iccios_out`, `ateula_out`, `ateula_stays`, `hostages_left` | Who is in Bibracte after day 196; how personal The Children of Gaul is |
| `hostage_roll`, `roll_read` | Evidence at the council and against Dannotalos |
| `brig_rising`, `brig_split`, `brig_faith`, `quest hostages=done_late` | The war band; the law route for the line (faith); the Aedui threatening Brigodunon's hostages (faith) |
| `pledge_void`, `pledge_bound` | Druid law for the hostages; the Roman-law route for the line |
| `druid_shown` and the druid's token | The Bibracte gate; a patron at the council |
| `factor_turned`, `factor_gone`, `factor_unmasked` | Who comes to Brigodunon; how Dannotalos receives you |
| `dannotalos_cheated`, `orbius_mercy`, `hostages_bought` | What the house claims at the opening |
| `clerk_saved`, `clerk_betrayed` | The inside hand at the Countinghouse, or a house that knows your name |
| `theron_joined` | Theron's Debt |
| `ford_lied`, `riders_recalled`, `riders_hired` | Haldo's debt at the camp; allies for the Pens |
| `levy_pledged`, `levy_self` | The children in the king's hostage yard; the King's Errand as an order |
| `verc_surety` | The accused in The Sutler |
| `dubnacos_pardoned` | Rides with the war band |

## Items and economy

- **Weapons:** daggers, swords (Gallic long swords and Roman short swords), axes, spears, javelins and pila, slings, bows, clubs. Quality tiers: crude, common, fine, masterwork.
- **Armor:** leather, padded linen, mail, Roman helmet types, Gallic helmets, shields of several sizes.
- **Consumables:** healing herbs, poultices, bandages, wine (Roman wine is a luxury and a trade currency), mead, beer, preserved food.
- **Currency:** silver. Gallic coins and Roman denarii both exist as flavor, but there is one money value. Prices depend on location, faction standing, and Barter. Wine trades high in Gaul and low in Roman camps.
- **Prices move with the story** (`data/prices.json`). Named prices are what dialogue charges for one particular thing: striking Brigodunon's line from the house's book costs 60, ten times that once the Aedui take Noviodunum and the forward sale is real, and can't be bought at all after Alesia; Barter brings it down. Markets scale traders' prices for some goods on some maps while their conditions hold: food and medicine cost three times as much in besieged Gergovia.
- **Quest items:** hostage tokens, the ledger, orders, sealed tablets, druidic objects.

## Companions

Fallout 1 has four or five companions. We aim for five, each with a personal quest, an opinion of the player, and an ending slide.

- **A war dog**, because some things are universal. The dead keeper's dog at the Bone Field (Act II).
- **Theron**, a Greek trader from Massilia: interpreter, coward, bookkeeper, the funniest person in the game. Joins at Gergovia (Act I); his personal quest is Theron's Debt at Cabillonum.
- **Bitugenos** (placeholder), a disgraced bard who will make you famous for a price, and who is writing your story whether you like it or not. Joins at Bibracte after The Bard's Disgrace; once an act he can sing a satire that ruins someone's standing.
- **Gundo** (placeholder), a Germanic deserter who wants to go home across the Rhine, the hard way. Joins at the Germanic camp; The Way Home resolves in Act III.
- **Cintillus** (placeholder), a Roman auxiliary of Gallic birth from the Province, with a Roman name, a conscience problem and a good sword arm. Joins if saved at the fall of Noviodunum.

Act II has the player traveling with several of them at once, so the companion rules (`src/core/companions.gd`, the `"companion"` block on an NPC template) are:

- **Presence sets the cap.** Half the player's Presence, at least one, will follow. The war dog is a pet and doesn't count. A full party is turned away in dialogue (`[room]`).
- **Opinion.** Each companion has a score, starting where their template says (Theron at 10). Changes in the player's Honor move it, scaled by how much that companion cares (Theron 0.3; someone who likes a scoundrel can have a negative scale). Named deeds that content reports with `~ deed <tag>` (`guest_murder`, `joined_house`, `sold_captives`, `freed_captives`, `cruelty`) move it by each companion's own table, and only for companions who are there. Dialogue reads it with `[opinion theron >= 10]` and moves it with `~ opinion theron n`. The character sheet shows it in words ("Theron thinks well of you"), never as a number.
- **Parting.** At or below the companion's `leave_at` (Theron -30), they raise it at the next quiet moment, out of combat and not mid-dialogue, through their parting dialogue, which has its own routes to keep them (Theron: Speech, Barter, or Honor if you have some left; or let him go; or take his purse). Each companion asks once per low; they ask again only if opinion recovers and falls again. A parted companion stays on the map where they left, can be talked back if opinion allows, and stays there across saves. `~ part` in a companion's own dialogue ("Wait for me here") does the same thing deliberately.

## Presentation

### View and art

Isometric 2D, as in Fallout 1. Fallout's character art was actually pre-rendered 3D: models rendered to sprites from six directions, one for each hex direction. We do the same, with low-poly models in Blender (already set up locally, with an MCP connection) rendered to sprite sheets under one fixed camera, one lighting rig, and one palette. Every asset comes out of the same pipeline, so the art stays consistent, which is the hardest problem in AI-made 2D art.

The pipeline exists (M7): `art/sprites.py` renders walls, cliffs, cave walls, rocks, trees, props, a recolorable figure with its gear as separate layers, and beasts; `art/pack.py` packs them; `tools/build-art.sh` does both. Walls and rock join their neighbors automatically, people are a gray body (man, woman or Roman, drawn 1.3 times life size) tinted per NPC, with hair, face, torc and equipped gear stacked on top as layers chosen from the NPC's look, and ground is tiling textures with soft edges. Roofs are built in the game from each house's outline (`src/view/roofs.gd`), vanish while the player is inside, and go see-through when the player is behind them. A view layer (`src/view/atmos.gd`) adds smoke from every fire (out at the ridge for a hearth indoors), flickering firelight that counts at night, and rain on maps that ask for it (`weather`, `weather_flag`). The dialogue window shows the speaker's figure, drawn from the same layers. The style is Rendered: the Blender sprites under a hard sun, outlined, with a color grade (contrast, desaturation, warm tint, vignette) over the map. F2 on a map still cycles it with the rejected Pixel and fixed-palette filters and the code-drawn placeholders, for comparison and debugging. Anything without a sprite yet (beasts other than the wolf) falls back to the placeholder drawing. Nothing about the art blocks the systems.

Interface: iron and bronze, no brown. The bar is a hammered iron plate with a bronze La Tène rim, wells for the log, health and weapon, bronze studs for action points and a shield boss for END TURN, all generated by `art/ui.py`. Windows are iron panels and sit above the bar when they fit. Cinzel for carved labels and titles, Alegreya Sans for reading. Dialogue uses portraits with a text box. Fallout's animated talking heads are out of scope at first; static portraits are in.

### Sound

Placeholder at first, then a small original or CC0 set: ambience per region, combat sounds, a few musical themes. A low priority until the game is fun.

### Text

The game is text-heavy, like Fallout. All text lives in data files, never hard-coded, so T can rewrite every line later without touching code, and so translation stays possible.

## Technical summary

The architecture will get its own document when the code exists. The commitments:

- **Engine:** Godot 4.7, GDScript only (C# doesn't export to the web), exported to Windows and to the web. Web is the easy way to share it.
- **Rules separated from presentation:** combat, skill checks, stats, and quest state are pure GDScript with no scene dependencies, run headless, and covered by tests. Random rolls go through one seeded generator so fights can be replayed.
- **Data-driven content:** items, characters, quests, dialogue, encounters, and maps are data files in the repo, readable by a person and writable by an agent. A dialogue format is to be chosen; the requirement is that a writer can read and edit it comfortably.
- **Saves:** plain JSON files, versioned, in `user://saves`: an autosave on every arrival, a quicksave and six slots, each carrying a summary (name, level, date, place, time saved) for the save and load windows.

## Scale target for the full game

Roughly Fallout 1's size: about a dozen locations, 60 or more named characters with real dialogue, 60 to 80 quests, a hundred-odd items, five companions, and complete ending slides. Built in milestones, each one playable.

Length, by Fallout 1's HowLongToBeat figures (T's reference): about 16 hours for the main line, 23 with side quests, 32 for everything.

## Open questions for T

- Real names for Brigodunon, Vindomagos, Vettius, Dannotalos, and the companions. Placeholders are in use until then. The demo adds more placeholders: Vellaunos (chief elder), Matugenta (the player's mother), Cintugnatos (vates), Cobnertos (smith), Moccos (gate guard), Dubnacos (the exile), Sulicena (headwoman of Vindomagos), Lugurix (salt merchant), Banna (healer), Haldo (the deserters' leader), and the hostages Ateula and Iccios. The player's sister is Eponina. Gergovia adds: Theron (the Greek), Paconius (the Vettius clerk), Ollognatos (hostage-master), Ategnatos and his son Eppillos, Senognatos (levy captain), Excingos (smith), Nammia (food seller) and Uxellos (potter). Avaricum adds: Senodonnos (Biturigan magistrate), Epomeduos (the Aeduan factor), Nertomara (weaver), Andecamulos (master of the mines), Vindos (boatman), Sumelis (market woman) and Hermeros (Vettius's freedman). Act II's design adds: Bitugenos (the bard), Gundo (the German rider), Cintillus (the auxiliary), Diodotos (the house's freedman), Demarchos (Theron's elder brother), Felix (Vettius's slave clerk), and at Bibracte Cingetos (Dannotalos's champion), Moricos (his steward), Esugenos (the druid of the spring) and Gobannos (smith); and still-unnamed roles: the Germanic band's leader, the overseer of the Pens, the Pens' named captives, and the sutler at Gergovia.
- Act II's scope: about eight new or changed maps (Cabillonum in three faces, the Pens, the Germanic camp, the Bone Field, Gergovia's slope, Noviodunum burned, Bibracte's two maps) and about seventeen quests. If it has to shrink, Gergovia besieged and the Aeduan column are the first to cut, since the act's spine (the line, the house, the council) doesn't depend on them.
- Facts to verify before they go into game text: the Chalon-sur-Saône amphora numbers, the details of Ribemont-sur-Ancre, and the width of the Porte du Rebout.
- The secret ahistorical path: yes or no. Default no.
- Is the player character fixed (a named person) or player-made? Default: player-made name and sex, fixed origin in Brigodunon, like Fallout.
- How dark the Avaricum and Alesia sequences may get. Default: shown plainly, never lingered on.
