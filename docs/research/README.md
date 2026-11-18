# Research: what Gaul in 52 BC actually looked like

Four source-cited reports, written 2026-11-18 to check the game against primary sources (Caesar, Hirtius, Diodorus, Strabo, Pliny, excavation reports) instead of general knowledge. Each one tags its claims as attested, inferred or disputed, and ends with a "check against the game" section.

| File | Covers |
|---|---|
| [chronology-52bc.md](chronology-52bc.md) | Campaign dates for 52 BC, the Cadurci and Lucterius, Uxellodunum (51 BC), travel and news speeds |
| [settlements-and-houses.md](settlements-and-houses.md) | Oppida, murus gallicus, Quercy forts, houses, interiors, hearths, roofs, landscape |
| [dress-and-arms.md](dress-and-arms.md) | Gallic, Roman and Germanic dress, hair, arms and armor; the raven_helm and chief_mail items |
| [society-and-language.md](society-and-language.md) | Clientship, law, druids, religion, food, salt, coinage, time-keeping, names |

Applied so far: the clock, the content and name fixes, and the figure art (2026-11-18). Still waiting: the rampart, interiors and props.

## Corrections, by how much they matter

**The historical clock.** Caesar gives no calendar dates, but the best reconstruction (Raaflaub and Ramsey, Histos 2017) puts the year at about 284 days from Cenabum to the Alesia surrender, not 240. The game is roughly right for the first month, then runs 50 to 70 days fast: the Cevennes crossing is about day 56, Avaricum falls about day 137, Gergovia about day 190, Alesia about day 284. Seasons should shift with it. Also: Vercingetorix drove his opponents out of Gergovia rather than "taking" it; the starving Mandubii come from Dio, not Caesar; the Aedui and Arverni were exempt from the captive handout; the men at Uxellodunum lost their hands but kept their lives. Touches calendar.json, the gergovia_taken event, and the season boundaries in game_state.gd.

**Art that is wrong everywhere.** Every figure has a moustache and a gold torc because both are baked into the base body; both should be optional layers worn by nobles. There is no female body. Romans are drawn as Gauls with a small rectangular scutum; a Roman of 52 BC is bare-legged and short-haired, with a tall oval shield and a pilum with a long iron shank. The shared sword has a medieval crossguard. The cloak is pinned on the wrong shoulder and the cloth is flat brown where Gallic cloth was checked, striped and dyed. Hair variants would do more for readability than any gear.

**The rampart.** A Cadurci murus gallicus (Murcens, l'Impernal) was about 5 m high and 12 to 15 m thick, cut a spur off where cliffs did the rest, and had an inturned gate. Ours is a one-tile ring lower than the house eaves. Forty houses need 2 to 4 ha; the drawn fort is 0.15 ha, so either treat the map as a slice or cut the number.

**Interiors and props.** Low tables and straw-and-linen pallets, not chairs and bed frames. A clay hearth slab with firedogs, not a ring of stones. No stone altar and no fully stone salt store. Roofs nearer 48 degrees. Add amphorae, a loom, raised granaries, a quern, wattle hurdles. No dry-stone field walls on the causses; those are 18th and 19th century.

**Content and names.** The hanging god at the Grotto should be Esus, not Taranis (Berne scholia on Lucan). Shrine theft was a capital crime judged by druids, so Dubnacos's offense is heavier than the dialogue makes it. Uxellodunum was in Lucterius's clientela, which is the model for who runs Brigodunon. Cahors (Divona) did not exist yet. Salt was boiled into cakes, not pan-evaporated. Epona as a girl's name is unattested; Eponina is the safe form. Haldo's saddle contradicts BG IV.2 unless he got it from Caesar's officers (VII.65). raven_helm should be re-anchored on the Tintignac bird helmet as a relic; chief_mail is solid. Several item descriptions misattribute their jokes (mail was credited to the Gauls by a Roman; the "soft sword" slur is Polybius on 225 BC).

**What already holds up.** Rectangular wattle-and-daub houses with thatched hip roofs and earth floors, an unwalled Vindomagos, the cave shrine, the guest-bond, wine and salt and silver as the economy, Gallic archers and slingers, the oval Gallic shield, mail as a rich man's armor, the Cadurci's role in the first month of the revolt, and most of the DESIGN.md history.
