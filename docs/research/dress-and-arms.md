# Dress, appearance, arms and armor in 52 BC

Research track 3 of 4. Covers Gauls (men and women, high and low status), Caesar's legionaries, officers and auxiliaries, and the Germanic horsemen in his pay, measured against what the game currently assumes (`game/data/items.json`, `game/data/npcs.json`, the `Figure` class in `art/sprites.py`, the `GEAR` table in `art/pack.py`, and `docs/DESIGN.md`).

Confidence labels used throughout:

- **Attested**: an ancient text or an excavation says so directly.
- **Inferred**: a reasonable reconstruction from evidence that is indirect, later, earlier, or from another region.
- **Disputed / uncertain**: scholars disagree, or the evidence is too thin to settle it. Who disagrees is named where known.

A note on the written sources. Diodorus V.25–32 and Strabo IV.4 both lean on Posidonius, who traveled in southern Gaul around 100 BC, so they describe Gaul about fifty years before the game and mostly from the Mediterranean side. Polybius describes Gauls of the 220s BC in Italy. Tacitus's *Germania* is from AD 98. Caesar is contemporary but says almost nothing about what anyone wore. Archaeology of La Tène D (roughly 150 to 30 BC) is the best guide, and it is patchy: much of Gaul cremated its dead in this period, so dress is known mostly from metal fittings, a few statues, and Roman coins and monuments.

---

## 1. Summary: the findings that matter most

1. **The base figure carries a moustache and a gold torc, so every person in the game has both:** women, boys, refugees, slaves, Romans and Germans. This is the single biggest error. Diodorus says only *nobles* wore the drooping moustache (V.28.3); torcs were prestige objects, by the first century BC seen mainly in hoards, sanctuaries and on statues of gods and great men, not on every neck. Both must become optional layers. (Section 2.2, 2.3)

2. **There is no female figure.** Women render with trousers, a thigh-length tunic, short hair and a moustache. Gallic women wore a long dress, probably pinned at the shoulders with a pair of brooches, a belt, a cloak or shawl, and long hair. (Section 2.4)

3. **Romans are built on the Gallic body**: trousers, torc, moustache, the Gallic long sword, a javelin standing in for the pilum, and a shield that is too small and the wrong shape. A legionary of 52 BC is bare-legged in a knee-length tunic, clean-shaven or stubbled with short hair, in a mail shirt with doubled shoulders, a bronze Montefortino or Coolus helmet, hobnailed *caligae*, a short sword on the *right* hip, a pilum with a long iron shank, and a tall **oval** curved shield (the rectangular one is later). (Section 4)

4. **One sword model serves both peoples, and it has a medieval crossguard.** La Tène swords have no crossbar: a narrow bell-shaped guard sits on the scabbard mouth. The Gallic blade should be longer than it is now, the Roman blade shorter. (Sections 3.1, 4.3)

5. **Gallic cloth was colorful and patterned, not mud-brown.** Diodorus describes striped or close-checked multicolored cloaks (V.30.1) and Pliny says Gaul invented checked weaving (*scutulis dividere Gallia*, NH VIII.196). Gaul dyed with plants: woad blue (the plant had a Gaulish name, *glastum*, NH XXII.2), madder red, weld yellow, and imitated Tyrian purple with herbs (NH XXII.3). The rich wore bright dyed cloth "sprinkled with gold" (Strabo IV.4.5). The poor wore undyed wool in sheep colors. The mask system can only tint flat colors; the art needs a pattern channel. (Section 2.1)

6. **Hair is the Gallic signature and the model ignores it.** Gauls were "long-haired" to the Romans (*Gallia Comata*); Diodorus describes hair washed in lime-water and swept back from the forehead into a stiff mane (V.28.2). Germans of the Suebi tied their hair in a knot on the side or crown (Tacitus, *Germania* 38). Romans wore it short. Hair is cheap to model and does more for readability than any gear. (Sections 2.2, 5)

7. **Most Gauls fought without helmets or body armor.** Mail existed, and a Roman, Varro, says it was a Gaulish invention (*De Lingua Latina* V.116), but it was rich men's gear; Diodorus says some wore mail and others were content with what nature gave them (V.30.3). Late La Tène Gallic helmets were mostly **iron** (Alesia/Agen type, Port type), and a helmet of the Agen family was found at Agen, next door to the Cadurci. A Port-type helmet turned up at Gondole, the Arverni oppidum three kilometers from Caesar's camp at Gergovia. (Section 3)

8. **The raven helmet's model, the Ciumești helmet, is from Romania and the 3rd century BC**, about 1,500 km and two centuries away. A much better local anchor exists: the **Tintignac** deposit in Corrèze, Lemovices country on the Cadurci's northern border, held a bronze helmet topped by a long-necked bird (swan-like) plus seven carnyxes. Diodorus confirms helmets with bird or animal figures (V.30.2). Keep the item as an heirloom or a sanctuary relic, not as everyday war gear. (Section 6)

9. **Caesar's Germans were spearmen and horsemen with shields, little armor, and hide or fur cloaks.** They often fought dismounted and brought picked foot runners who fought among the horses (BG I.48, IV.2, VII.65). Archery is weakly attested for them. In 52 BC Caesar remounted them on horses taken from his own tribunes and veterans (VII.65), and the ones he recruited that year came from peoples near the Rhine he had "pacified", probably including the Ubii, whom he calls the most Gallicized of the Germans (IV.3). (Section 5)

10. **The Gauls had archers and slingers in numbers.** Vercingetorix ordered every archer in Gaul, "of whom there were very many", sent to him (BG VII.31), mixed them among his cavalry (VII.36, VII.80), and the relief army attacked the Alesia lines with slings, arrows and stones (VII.81). The game's slingers and Gallic bowmen are right. (Section 3.6)

---

## 2. Gauls: clothing, grooming, jewelry

### 2.1 Clothing, cloth, color

**The man's outfit: tunic, trousers, cloak, belt.** *Attested.* Diodorus lists dyed and embroidered tunics, trousers the Gauls call *bracae*, and striped cloaks fastened with a brooch, thick in winter and light in summer, "variegated with close-set checks of many colors" (V.30.1). Strabo: the Gauls wore the *sagos*, let their hair grow long, and wore tight trousers and slit tunics with sleeves that came down to cover the private parts and buttocks (IV.4.3), that is, about mid-thigh. Strabo also says their coarse long-fleeced wool was woven into the thick cloaks called *laenae*, and that by his day Gaul supplied cloaks (*sagi*) to much of Italy (IV.4.3).

Sleeves: Strabo's *cheiridotous* means sleeved. Wrist-length sleeves are the safer default for winter (the game starts in January); elbow-length is plausible in summer. *Inferred.*

**The sagum.** *Attested (statue), inferred (general).* A rectangular wool cloak, pinned at one shoulder so the sword arm is free. The Vachères warrior (Alpes-de-Haute-Provence, second half of the 1st century BC, a Gaul in Roman auxiliary service) wears his *sagum* pinned with a round brooch on the **right** shoulder and thrown over the left (Barruol 1996). Roman soldiers' cloaks were also pinned on the right.

**The hooded cape.** *Inferred, later source.* Roman poets of the 1st century AD know the Gallic hooded cape as a Santonic product (*cucullus Santonicus*, Juvenal VIII.145; *bardocucullus*, Martial XIV.128). The Santones lived on the Atlantic coast north of the Cadurci. A hooded cape is a good, cheap way to dress commoners, travelers and the outlaws in the Grotto in winter, but it is projected back about a century.

**Felt and padding.** *Attested.* Pliny credits the Gauls, as he thinks, with inventing wool flock stuffing (*tomentum*) (NH VIII.192). Felt was used for the Fayum shield's covering (see 4.4).

**Checks and stripes.** *Attested.* Pliny: Alexandria invented multi-heddle weaving, Gaul invented dividing cloth into checks (*scutulis dividere Gallia*, NH VIII.196). Pliny also says the Gauls color wool their own way, different from the Parthians (NH VIII.191). Diodorus: cloaks "striped" and "with small close-set checks of many colors" (V.30.1). No checked textile survives from Late Iron Age Gaul itself; the closest real cloth is from the Hallstatt and Dürrnberg salt mines in Austria (Bronze Age to La Tène), which include checks and stripes in natural light and dark wool, dyed colors, and tablet-woven bands (Grömer et al. 2013). *Inferred* for Gaul.

**Dyes actually available.** *Attested in texts, inferred in detail.*

| Color | Source | Evidence |
|---|---|---|
| Blue | Woad (*Isatis tinctoria*) | Pliny names the plant *glastum* "in Gaul" (NH XXII.2); indigotin, probably from woad, identified on Hallstatt textiles (Hofmann-de Keijzer et al. 2005) |
| Yellow | Weld (*Reseda luteola*), other flavonoid plants | Luteolin dyes on Hallstatt textiles (same) |
| Red | Madder (*Rubia tinctorum*) for brick reds; insect reds (kermes) for luxury crimson | Insect-type red on some Hallstatt textiles; madder is the usual European red but I found no direct La Tène Gaul identification. Inferred |
| Purple | Lichen purples, plant imitations | "Transalpine Gaul dyes Tyrian purple, shellfish purple and all other colors with plants" (Pliny NH XXII.3) |
| Green | Woad over weld | Inferred, standard practice |
| Browns, blacks | Oak bark, walnut, iron-tannin; and undyed brown or black fleeces | Inferred; oak bark used in Hallstatt dye experiments |
| Cream, grey, brown | Undyed wool from mixed-color sheep | Inferred; Iron Age sheep were not uniformly white |

**Who wore what.** *Attested (Strabo), inferred (spread).* Strabo: leaders wore dyed clothes sprinkled with gold (IV.4.5); Diodorus: some cinch their tunics with belts plated in gold or silver (V.30.3). Color, gold and embroidery marked rank. The poor wore undyed or cheaply dyed wool. A chief or a rich salt merchant should be visibly brighter than a farmer.

**Belts.** *Attested.* Leather belts with metal fittings; the sword hung from the belt on the right (Diodorus V.30.3; Vachères). The model's leather belt with a bronze buckle is fine. (The Vachères buckle with a tongue is a Roman military type; Gallic belts often closed with hooks. Inferred, minor.)

**Footwear.** *Attested (name), inferred (form).* Cicero mocks Mark Antony for walking about Rome in *gallicae* and a *lacerna*, Gallic shoes and a cloak (*Philippics* II.76). Gallic shoes were closed, low, soft leather, laced at the ankle. Not hobnailed (hobnails are Roman, see 4.6). The model's short leather boots are acceptable.

**Headgear.** *Inferred.* Gallic men are almost always shown bareheaded. Hoods (above) are the commoners' headgear. There is no evidence one way or the other for leather caps.

### 2.2 Hair, beards, skin

**Hair.** *Attested.* The Romans called free Gaul *Gallia Comata*, long-haired Gaul (Pliny NH IV.105). Strabo: they let their hair grow long (IV.4.3). Diodorus: their hair is naturally fair and they make it fairer by washing it in lime-water, and they draw it back from the forehead to the crown and nape, so they look like satyrs and Pans, and the hair becomes thick and coarse like a horse's mane (V.28.1–2). Pliny calls soap a Gallic invention "for reddening the hair" (NH XXVIII.191). Diodorus's picture probably describes warriors dressing for show; it should be a variant, not universal. Dark hair was certainly common too; the Roman image of the fair Gaul is a stereotype. *Inferred.*

**Moustaches and beards.** *Attested.* Diodorus: some shave their beards, others let them grow a little; the **nobles** shave their cheeks but let the moustache grow until it covers the mouth (V.28.3). The Roman coins of L. Hostilius Saserna (48 BC, RRC 448/2), struck four years after Alesia, show a Gaulish captive with long unkempt hair and a **full beard**, a Gallic shield behind him. The head is often called Vercingetorix; that identification is disputed (see the 2022 article in *Documenta & Instrumenta*). The Vachères warrior has a thick moustache and no beard. So: nobles and warriors with moustache and shaved cheeks; older and poorer men often bearded; young men and many others clean-shaven. Never on women.

**Tattoos and body paint.** *Attested for Britons, no evidence for Gauls.* Caesar says all Britons dye themselves with *vitrum*, which makes them blue and fearsome in battle, and shave everything but the head and upper lip (BG V.14). Pliny says British wives and daughters-in-law smear their whole bodies with *glastum* for certain rites (NH XXII.2). Neither says it of Gauls, and Caesar spent seven years among Gauls. Whether *vitrum* means woad is itself disputed (some argue for a copper-based or other pigment). **Recommendation: no tattoos or blue paint on Gauls.** A druidic ritual daubing would be invention, and should look like it.

**Stature.** *Attested.* The Gauls mocked the Romans for being short (BG II.30.4); Diodorus calls them tall (V.28.1). Skeletal averages for Iron Age men in western Europe are around 1.65 to 1.70 m, so "tall" is relative to Mediterranean Romans. A slightly taller, broader Gallic body than the Roman one would echo the sources without exaggerating. *Inferred.*

### 2.3 Torcs and other jewelry

**What the texts say.** *Attested.* Diodorus: men and women wear gold bracelets on wrists and arms, heavy solid-gold neck rings, finger rings, even gold corslets (V.27.3). Strabo: gold chains round their necks and bracelets on arms and wrists (IV.4.5). Polybius at Telamon (225 BC): the front ranks of the naked Gaesatae were adorned with gold torcs and armlets (II.29.8). All three describe the torc as a mark of the warrior elite and of wealth, and two of them write from before or around 100 BC.

**What archaeology says about the late period.** *Inferred; I could not pin a single synthesis in this session.* Torcs are common in earlier La Tène burials (in Champagne, chiefly women's graves of the 5th to 3rd centuries BC). By La Tène D they are rare in graves and turn up instead in **hoards and sanctuary deposits** and on **statues of gods and heroes**. The southwest is torc country: the gold torcs of Fenouillet near Toulouse and the Lasgraïsses torc and armlet (Tarn) are 3rd century BC (Musée Saint-Raymond, Toulouse); the Tayac hoard (Gironde), mid-2nd to early 1st century BC, put a 762 g gold torc in the ground with about 325 gold coins and 73 small gold ingots (Musée d'Aquitaine). The museum calls Tayac a votive deposit. Statues show torcs still worn as rank: the Vachères warrior wears one (second half of the 1st century BC), and the local curator reads it as a sign of high rank. The game's own Grotto map has old dead wearing torcs, which fits.

**Recommendation.** Torcs on chiefs, nobles, rich warriors, druids, and the occasional rich woman; bronze on the middling; nothing on most people. In 52 BC a torc is also portable wealth that can be offered to the gods or paid to Germans, as the game already has it. The Roman army also gave torcs as military decorations (*torques* among the *dona militaria*), so a decorated Roman veteran could own one, worn on the chest, not the neck. *Inferred.*

**Bracelets and arm rings.** *Attested in text (above).* Gold or bronze arm rings for the rich. For women, **glass bangles** (blue, purple, amber) are the most characteristic La Tène ornament of the 2nd and early 1st centuries BC; one turned up at Gondole (Deberge et al. 2009). *Inferred* as still current in 52 BC, though fading.

**Brooches (fibulae).** *Attested.* What was actually pinning cloaks in central and southern Gaul around 52 BC (Colin 1998; Deberge et al. 2009; Feugère 1985):

- **Nauheim** (Feugère 5a): small one-piece bronze wire brooch with a flat triangular bow. The marker of La Tène D1 (late 2nd to early 1st century BC); still around in 52 BC, but old-fashioned.
- **Filiform and "cambered-bow" iron or bronze wire brooches** with spring and chord: the commonest kind in La Tène D2. At Gondole, of 27 identified brooches, 15 are wire types of this sort and only 2 are Nauheim.
- **Brooches with the bow thickening into small wings, and "Almgren 65"-derived types**: D2.
- **The "Alesia" brooch** (Feugère 21): hinged rather than sprung, with a broad triangular bow, often openwork. Common in the Roman camps at Alesia and associated with the army; it dates to around the middle of the century.
- **Round brooches**: the Vachères warrior's (probably Feugère 11d) is a disc; later than 52 BC but close.

At game scale all of these read as a small bright metal dot or bar at the shoulder. Bronze, not gold, is the norm. The model's gold ball is fine for a chief; make it bronze for others.

**Coins as jewelry.** *Uncertain.* I found no good evidence for pierced Gallic coins worn as ornaments in this period. Don't make it a visual feature.

### 2.4 Women's dress

*Mostly inferred; the evidence is thin and much of it is later.*

- **Texts:** Diodorus and Strabo say women as well as men wore gold (V.27.3; IV.4.5). Diodorus says Gallic women are as tall and as brave as their men (V.32.2). Tacitus says German women dress like men but often in linen trimmed with purple, sleeveless, arms and upper breast bare (*Germania* 17); that is Germany, AD 98.
- **Archaeology:** In earlier La Tène inhumation graves in Switzerland and Champagne, brooches often lie in **pairs at the shoulders**, which points to a tube-shaped dress pinned over each shoulder (a "peplos" type), sometimes over an undertunic, with a belt. For La Tène D cremation hides most of this. Gallo-Roman tombstones of the 1st to 3rd centuries AD show women in long, wide-sleeved tunics ("the Gallic coat"), cloaks, and sometimes caps or veils; the Menimane relief from Mainz (mid-1st century AD, an Ubian woman) shows a shoulder-pinned overdress, an undertunic and a bonnet (Wild 1968; Böhme-Schönberger 1997, not consulted directly).
- **Recommendation for the figure:** an ankle-length dress, belted; two brooches at the shoulders; optional long-sleeved undertunic; a cloak or shawl pinned at the chest; long hair, braided or knotted at the nape; for older or married women an optional cloth head-wrap (inferred from the Gallo-Roman evidence, plausible, not proven). No trousers, no moustache. Glass bangles and a bronze or (for Sulicena) gold neck ring as status markers.

---

## 3. Gallic arms of La Tène D

### 3.1 Swords

- **Shape and size.** *Attested (Gondole), inferred (general).* Long, straight, double-edged slashing swords, typically with blades of roughly 70 to 90 cm in La Tène D, on a short grip with no crossbar. The hilt has a narrow, bell-shaped guard that sits against the scabbard mouth. Of the two Gallic swords at Gondole, the excavators note that few such swords have a marked crossguard (Deberge et al. 2009). The model's 16 cm iron crossbar is a medieval silhouette and should go.
- **Worn on the right.** *Attested.* Diodorus: long swords hung from iron or bronze chains along the right flank (V.30.3). Strabo: a long *machaira* on the right side (IV.4.3). Vachères: long sword in a metal scabbard on the right, hung from the belt. By La Tène D the chain suspension of the 3rd century had mostly given way to leather belts with rings and a loop on the back of the scabbard (Lejars 1994; Rapin; Pernet 2010, not consulted directly). Iron scabbards with a long "ladder" chape are typical of D2.
- **Quality.** *Disputed.* Polybius says Gallic swords bent after the first blow and had to be straightened underfoot, and had no point (II.33.3–5). That is the Battle of Telamon, 225 BC, written by a pro-Roman Greek. Metallurgical study of La Tène swords shows many of them were well made (Pleiner 1993, not consulted directly). The item text "Caesar's men call them soft" is fine as in-world prejudice, but the source of the slur is Polybius, not Caesar, who never says it.

### 3.2 Spears and javelins

*Attested.* Strabo: lances in proportion to their size, and the *madaris*, a kind of javelin (IV.4.3). Diodorus: spearheads over a cubit long and almost two palms wide, some straight, some twisted or wavy so as to tear the wound (V.30.4). Caesar mentions Gallic *gaesa* (heavy javelins) in passing. Spears and javelins were the commonest weapons, far commoner than swords, in Gallic deposits. The game's spear, war spear with wavy edges, and javelin are all well grounded. Whether the big war spear was used two-handed is *uncertain*.

### 3.3 Shields

- **Shape and size.** *Attested.* Diodorus: tall, "man-high" shields, decorated individually, some with bronze animals in relief (V.30.2). Strabo: a long oblong shield (*thyreos*) (IV.4.3). Polybius: the Gallic shield did not cover the whole body (II.30.3). The real shields from La Tène (Switzerland, earlier) run about 1.1 m tall; the Fayum shield (below) is 1.28 by 0.64 m. Oval or long hexagonal boards of planks, covered with leather or felt.
- **Boss.** *Inferred (typology).* A vertical wooden spindle (*spina*) runs the length of the board and swells in the middle over the hand; in La Tène C and D1 an iron band boss with rectangular "wings" covers it. In La Tène D2 round iron bosses appear, a form shared with Germanic and Roman shields; the Vachères shield is oval with a round boss held by ten rivets (Barruol 1996). Either is right for 52 BC.
- **The game's model** (oval board 1.0 tall by 0.62 wide, vertical spine, boss) has the right idea. It is too small: at the figure's 1.94 model-unit height it is 52% of the man; a real one is about 65% (chin to knee). The spine should taper toward the ends rather than be a straight bar.
- **Round shields for Gauls.** *Uncertain.* Small round shields are not characteristic of Gallic infantry. They fit Germans (section 5) and are acceptable as cheap improvised shields for bandits and guards, but the default Gallic shield should be the tall oval.

### 3.4 Helmets

*Mixed; types attested by finds, who wore them inferred.*

- **Late La Tène Gallic helmets were mostly iron.** Robinson grouped them as "Agen/Port"; current French work splits them (Feugère 2011; Pernet 2010):
  - **Alesia type** (also called Western Celtic): an iron cap, a raised ridge around the base, hinged cheek pieces, some with a slightly conical crown and a riveted knob. About six complete examples. The one from **Agen** (Lot-et-Garonne, Nitiobriges country, bordering the Cadurci) is the only one with a crest holder (L'Ermitage, Agen; Feugère 1994; Pernet 2010 pl. 160). This is the right helmet for a Cadurcan or southwestern warrior.
  - **Port type** (after Port bei Nidau, Switzerland): an iron cap with a broad riveted neck guard and embossed "eyebrows" over the forehead, with hinged cheek pieces. In use during the Gallic War; the ancestor of the Roman "Imperial Gallic" helmets. One, nearly complete, with three impact marks, was found at **Gondole** (Deberge et al. 2009), the oppidum 3 km from Caesar's large camp at Gergovia. The excavators, following Feugère, connect the type with the Roman army or its auxiliary cavalry; a Gallic noble horseman is the likely wearer.
  - **Montefortino and Coolus** (bronze): the Montefortino is named after a Gallic (Senonian) cemetery in Italy and came into Roman use from Celtic models; the Coolus is named after a find in the Marne. By 52 BC both are mainly Roman. A Gaul could own one, especially a veteran of Roman service or a looter.
  - **Novo Mesto** (iron with bronze fittings): Slovenia, eastern Celts. Out of region. Don't use.
- **Who wore helmets.** *Inferred.* Few. The handful of known La Tène D helmets against thousands of spearheads and hundreds of swords says helmets were for the rich and for horsemen. Most Gallic fighters fought bareheaded.
- **Crests, horns, birds.** *Attested in text, rare in finds.* Diodorus: bronze helmets with large figures in relief, horns, or the foreparts of birds or animals (V.30.2). The Tintignac deposit is the archaeological confirmation (section 6).

### 3.5 Body armor

- **Mail.** *Attested.* Varro, a contemporary of Caesar, says the Roman *lorica* was first a breastplate of rawhide straps, and that the word later passed to the Gaulish iron tunic of rings (*De Lingua Latina* V.116; the manuscript reading is *gallica e ferro*). Diodorus: some Gauls wear iron mail, others are content with natural protection (V.30.3). The earliest mail in Europe comes from Celtic graves (Ciumești in Romania, 3rd century BC). The Vachères statue wears mail to mid-thigh with a **shoulder cape** fastened across the chest, over a long slit tunic. Mail was expensive: rich men and their best horsemen.
- **Leather armor.** *No evidence either way.* Leather does not survive, and no text mentions it for Gauls. Varro's etymology is about early *Romans* using rawhide breastplates. A leather jerkin is a defensible game convention, not a historical fact.
- **Padded linen.** *No evidence for Gauls.* The quilted linen corslet is Greek and Near Eastern. As an item it is an invention; it should be rare and should not be the elder's signature armor.

### 3.6 Bows and slings

*Attested.* Strabo: some Gauls use bows and slings (IV.4.3). Vercingetorix had all archers, of whom Gaul had a great many, gathered and sent to him (BG VII.31); he fought daily cavalry skirmishes with archers mixed among the horse (VII.36); at Alesia the Gauls put archers and light-armed men among their cavalry (VII.80); the relief army attacked the lines at night with slings, arrows and stones (VII.81). Thousands of arrowheads come from Alesia and from the siege of Uxellodunum at the Puy d'Issolud in Cadurci country (51 BC), though many of those are Roman (Fitzpatrick 2022; Girault 2013). Slings are near-invisible archaeologically except for stones and, on the Roman side, lead bullets. Strabo also mentions a thrown wooden club, used mostly for birds (IV.4.3).

### 3.7 Axes

*Inferred.* Axes are tools; they are rare as weapons in Gallic graves and deposits. An axe appears in a Gallic arms trophy on a coin of Caesar (RRC 452/2, 48–47 BC), possibly as a sacrificial axe. A brigand with a woodsman's axe is exactly right; a warrior class that fights with axes would be wrong.

### 3.8 War trumpets and cavalry gear

- **Carnyx.** *Attested.* Diodorus: harsh-sounding trumpets of a barbarian kind (V.30.3). Polybius: countless horn-blowers and trumpeters at Telamon (II.29.6). Tintignac produced seven, one nearly complete, a bronze tube held upright with a boar's-head bell. A carnyx is carried on Caesar's Gallic trophy coin (RRC 452/2). Good for a war-band leader's retinue or a sanctuary.
- **Horse gear.** Pliny says the Gauls invented tinning and then silvering bronze, mainly for horse trappings, and names the town of Alesia (NH XXXIV.162–163; *attested in text, not re-read in this session*). The four-horned saddle is generally credited to the Celts (Connolly 1986). *Inferred.* Spurs are found in late La Tène and Germanic graves. Gallic cavalry was the best part of the army (Strabo IV.4.2; BG VI.15 on the *equites*).

---

## 4. Romans in 52 BC

### 4.1 Overall look of a legionary

*Inferred from attested pieces.* Knee-length tunic, belted; bare legs; *caligae*; mail shirt to mid-thigh with doubled shoulders; bronze helmet with cheek pieces; oval curved shield; short sword on the right; two pila (Polybius VI.23.8). Short hair, shaven or stubbled. The Altar of Domitius Ahenobarbus in Paris (date disputed, late 2nd to early 1st century BC) is the nearest picture: mail with shoulder doubling, Montefortino-type helmets with crests, tall oval shields, and an officer in a muscled cuirass.

**Trousers.** *Inferred.* No evidence that legionaries wore trousers in 52 BC; Romans saw *bracae* as barbarian, and close-fitting military breeches are an imperial development. Bare legs for Romans is a strong visual tell that the art should use.

**Hair and face.** *Inferred, with one attested anecdote.* Roman men of Caesar's day were normally clean-shaven with short hair; on campaign, stubble. Suetonius says Caesar shaved closely as a rule but, after the destruction of Titurius's legion in 54 BC, let his hair and beard grow until he had avenged it (*Iul.* 45.2, 67.2). Vellaunos's line in the game ("they come back speaking Latin and wearing their hair short") is right.

**Tunic color.** *Disputed.* No source says what color a legionary's tunic was in 52 BC. Fuentes (1987) argued for undyed white or off-white for soldiers and red for centurions; others prefer red for all. The game's red tunic for the forager is a defensible readability choice, but undyed off-white or natural is at least as likely. Caesar gave his men arms decorated with silver and gold (Suetonius *Iul.* 67.1), so a little glitter on a veteran's sword or belt is attested.

### 4.2 Helmets

*Attested types, inferred dating.* Bronze **Montefortino** (a bowl with a knob on top, a small neck guard, hinged cheek pieces; late "Buggenum" variants are plainer) and bronze **Coolus-Mannheim** (a plain round cap, no knob or a small one, slight neck guard) were both in use in Caesar's army. Polybius gives a plume of three upright purple or black feathers a cubit tall (VI.23.12); horsehair crests are shown on the Ahenobarbus altar. Caesar implies crests and plumes were fitted for battle and helmets were not worn on the march: surprised by the Nervii, his men had no time to fit their insignia, put on helmets, or take the covers off their shields (BG II.21.5). The game's bronze helmet model (dome, knob, neck guard, cheek pieces) is a good Montefortino.

### 4.3 Sword

*Inferred (blade size from finds), attested (side).* The *gladius hispaniensis*: straight, double-edged, long-pointed, blade roughly 60 to 68 cm, overall about 75 to 80 cm, with a bone or wooden grip, a rounded guard and a ball pommel (Connolly 1997; Quesada Sanz 1997, not consulted directly). Worn on the right hip (Polybius VI.23.6); officers on the left in imperial evidence, later. Gondole produced a short Roman *gladius* (35 cm blade) from a destruction layer, which the excavators call Roman equipment, perhaps made by Gallic smiths (Deberge et al. 2009).

### 4.4 Shield

*Attested.* Polybius: convex, about 2.5 feet wide and 4 feet long, two layers of wood glued together, covered with canvas and then calfskin, with iron edging at top and bottom and an iron boss (VI.23.2–5). Varro: the scutum is made of small cut boards (LL V.116). The Fayum shield (Kasr el-Harit, Egypt, 1st century BC; Kimmig 1940) is **oval**, 1.28 by about 0.64 m, made of layered wooden strips, covered both sides with felt, with a vertical spine and boss. Kimmig thought it Celtic; whether it is Celtic or Roman is still argued, which is itself telling: the two shapes were close. The **rectangular** curved scutum is an Augustan and later development. For 52 BC: a tall oval, curved, with a long vertical spine and a bronze or iron boss. On the march the face was protected by a leather cover (BG II.21.5).

The game's scutum is a rectangular section of a cylinder, about 1.1 by 0.73 units: wrong shape, and at 57% of the figure's height it is too small. It should be about 75% of a man's height.

Shield color and blazon in Caesar's army are **unknown**. Red with lightning bolts is imperial (and Hollywood). Leave shields in plain leather tones or varied colors.

### 4.5 Pilum

*Attested.* Polybius: two pila per man, heavy and light, the shaft and the barbed iron head each about three cubits, the iron fastened halfway down the shaft with many rivets (VI.23.8–11). Plutarch says Marius replaced one of the two iron rivets with a wooden pin that broke on impact, so the shaft swung down and the weapon dragged (*Marius* 25.1–2). Caesar describes the result against the Helvetii: one volley pierced several overlapping shields, the iron bent, they could not pull them out and fought with the left arm encumbered, and many threw the shields away (BG I.25.3–4). The design doc's "javelins ruin shields" rule is well founded, and the pilum is the right weapon to do it most.

Visually: a wooden shaft about 1.2 to 1.4 m, then a **long thin iron shank** of 0.6 to 0.9 m ending in a small pyramidal point, the junction marked by a wooden block or socket. Total about 2 m. It must not look like the Gallic javelin, which has a short leaf head.

### 4.6 Footwear, belts, other

*Attested.* Hobnails from *caligae* are found at Alesia (Sievers 2001, as cited) and are a standard marker of Roman soldiers on Gallic War sites. Their absence at Gondole is used to argue there was no long occupation there (Deberge et al. 2009). *Caligae* are open-work leather boots on a hobnailed sole, laced up the ankle. Roman military belt buckles found at Gondole match a type from Cáceres el Viejo (80s BC).

### 4.7 Officers

*Mixed.* A general's cloak (*paludamentum*) was distinctive: at Alesia Caesar's men recognized him by the color of the cloak he habitually wore in battle (BG VII.88.1). Caesar doesn't name the color; scarlet is the conventional reading. *Inferred.* Senior officers (legates, tribunes) wore muscled cuirasses (Ahenobarbus altar). Centurions in 52 BC: the vine staff is a centurion's badge in Pliny (NH XIV.19, 1st century AD); transverse crests and greaves are attested only later. *Inferred, use sparingly.*

### 4.8 Auxiliaries

*Attested names, inferred looks.* In 57 BC Caesar had Numidian cavalry, Cretan archers and Balearic slingers (BG II.7, II.10, II.24), and in 54 BC Spanish horsemen (V.26). Book VII names Roman slingers at Alesia, using pound-weight stones, stakes and lead bullets (*fundis librilibus sudibusque ... ac glandibus*, VII.81.4), but not their origin.

- **Balearic slingers:** Diodorus says each carried three slings, one wound round the head, one round the belly, one in the hand, and hurled much heavier stones than other slingers (V.18.3); the islands were called Gymnesiae because the people went naked in summer (V.17.1). Light tunic, no armor, no shield. The game's NPC text ("three slings wound round his head") should read one round the head, one round the waist, one in the hand.
- **Cretan archers:** composite bows, light equipment. *Inferred.*
- **Numidians:** small horses ridden without bridles, javelins, small round shields, tunics; not attested for 52 BC in Book VII. *Inferred.*
- **Gallic allied horse** under Roman command: Gauls in Gallic gear. Caesar uses *decurio* for an officer of Gallic cavalry (BG I.23.2).

---

## 5. Germanic horsemen in Caesar's pay

**Who they were in 52 BC.** *Attested.* About 400 Germanic horsemen had been with Caesar from the start of the campaign (BG VII.13.1). After the defection of the Aedui he sent across the Rhine to the peoples he had pacified in earlier years and brought back horsemen and the light-armed foot who were used to fighting among them (VII.65.4). Their horses were poor, so he took horses from his military tribunes, the other Roman knights and the *evocati* and gave them to the Germans (VII.65.5). They seized a ridge and routed the Gauls before Alesia (VII.67.5), fought the cavalry battle in the plain (VII.70), and broke the Gallic cavalry by a massed charge in the final cavalry battle (VII.80.6). The peoples Caesar had "pacified" across the Rhine include the Ubii, whom he calls more civilized than other Germans and used to Gallic customs because of the Rhine trade (IV.3.3). So many of Caesar's Germans probably looked half-Gallic. Haldo's band ("Batavi, Ubii, a Sueb or two") is plausible; Batavian cavalry is famous only later, which is not a problem for an invented band.

**How they fought.** *Attested.* Germanic horsemen often dismounted in a fight and fought on foot, their horses trained to wait in place (IV.2.3); 800 of them routed 5,000 of Caesar's cavalry by dismounting and stabbing the horses from below (IV.12.2). Ariovistus's 6,000 horse each had a picked runner who fought beside them and could keep pace by holding the horse's mane (I.48.4–7). Tacitus later: few swords or long lances, mainly the *framea*, a short-bladed spear used both thrown and in hand; brightly painted shields; hardly any breastplates and scarcely one or two helmets; cavalry content with shield and *framea* (*Germania* 6).

**Saddles.** *Attested.* Germans thought it shameful to use saddles (*ephippia*) and would attack any number of saddled horsemen (BG IV.2.4). Nice wrinkle for the game: the 52 BC riders were remounted on Roman officers' horses, presumably with their saddles. The ford dialogue has Haldo sitting on a saddle and his men carrying saddles away. That works if it's read as men who've changed in Roman service; a single line acknowledging it would turn an apparent error into characterization.

**Arms in the ground.** *Attested (archaeology).* In 2nd–1st century BC Przeworsk-culture warrior graves (Poland, the best-documented Germanic group of the period), the usual set is one spearhead, rarely two, and a shield boss; swords are rare and mostly Celtic double-edged imports or local single-edged swords; spurs appear; arrowheads are uncommon and bows were probably for hunting, not war (Czarnecka 2010, citing Kontny 2008). The Rhineland groups Caesar recruited from are less well known, but the pattern fits Caesar and Tacitus.

**Appearance.** *Attested (texts), inferred (projection).* Caesar: Gauls and traders described the Germans as huge, brave and practiced in arms, with a stare men could not bear (I.39.1). The Suebi wore little but skins, leaving much of the body bare (IV.1.10), and Germans in general wore hides or small coverings of *reno* fur (VI.21.5). Tacitus: everyone wears a cloak pinned with a brooch or a thorn; the rich wear close-fitting clothes; skins are common (*Germania* 17). The **Suebian knot**: the Suebi comb their hair sideways and tie it in a knot, often on the crown, to look taller and more frightening, and their nobles dress it more elaborately (*Germania* 38). That is a source of AD 98, and the knot is also mentioned by Seneca and Juvenal in the 1st century AD; Caesar does not describe it. Projecting it to 52 BC is reasonable for Suebi and their imitators. *Inferred.*

**Recommendation for the figure.** A fur or hide cape over a plain tunic (or bare-chested in summer); tight trousers acceptable; hair long, fair to red-brown (Tacitus *Germania* 4 says *rutilae comae*), some with the side knot, some loose; beards common. Spear and a few javelins; a round or flat oval painted shield with a round iron boss; a sword only for the leader. No helmets except looted ones. Haldo in a Roman mail shirt and a looted helmet is good. Replace the leather jerkins with hide cloaks.

---

## 6. "raven_helm" and "chief_mail": is there a real basis?

**The Ciumești helmet.** *Attested object, disputed details.* Found in 1961 in a rich warrior grave at Ciumești (Satu Mare, northwest Romania), published by Rusu (1969). An iron cap topped by a large bronze bird with articulated wings that move. Usually called a raven; Rustoiu, who re-examined the grave, calls it a falcon, and others say simply a bird of prey or a corvid. Dates offered run from the late 4th to the early 2nd century BC (Livius gives c. 250–175 BC; Rustoiu calls for a chronological re-evaluation). The same grave produced an early mail shirt. Verdict: **out of region (about 1,500 km east of Quercy) and early (two to three centuries before 52 BC)**. Unique; probably a ceremonial helmet.

**Tintignac: the better anchor.** *Attested object, dating uncertain.* In September 2004 INRAP excavated a pit in the Gallic sanctuary of Tintignac at Naves (Corrèze), Lemovices territory adjoining the Cadurci on the north, about 100 km from the game's home. About 500 fragments of deliberately broken objects: seven carnyxes, about ten helmets (nine bronze, one iron), swords and scabbards, spearheads, a shield boss, animal figures and a cauldron (Maniquet 2004, 2008; Maniquet et al. 2011). One helmet carries a bronze bird with a long neck bent back toward the nape, read as a swan or a crane; another has three rings set in a triangle. INRAP's image notes date the bird helmet between the 4th and 2nd centuries BC; Maniquet places the helmets in the 3rd century BC; the sanctuary was built around the middle of the 2nd century BC and the deposit is later than that, possibly as late as the 1st century BC. Either way, by 52 BC these were **old, sacred objects buried in a sanctuary**, not field gear.

**Verdict on raven_helm.** A Gallic chief's bird-crested helmet is grounded: Diodorus describes exactly that (V.30.2), and Tintignac proves such things existed in the region. What's off is the specific model and the implication of everyday use. Options, in order of preference:

1. Re-anchor it on Tintignac: a bronze helmet with a bird (keep the raven if the story wants it; ravens are not attested on Gallic helmets, but the bird is) that is an heirloom or a sanctuary treasure, taken from a shrine or inherited. The item description can say it's older than anyone's grandfather.
2. Keep the Ciumești inspiration but say so in the fiction: brought back from the east by a mercenary ancestor. Plausible, since Celts served across the Hellenistic world, but a stretch.
3. Leave it as is and accept a known anachronism. Not recommended, given the design rule.

The current description ("Iron, with a bronze raven on the crown whose hinged wings flap") is Ciumești exactly. "Men will remember who wore this" fits an heirloom better than a battle helmet anyway.

**Verdict on chief_mail.** *Well grounded.* Fine mail with a shoulder cape and bronze fasteners is the Vachères warrior's armor, and Varro's "Gaulish" mail. Model it with a flat shoulder cape over both shoulders fastened at the chest, not the round shoulder lumps in the current mail layer. The same shoulder-doubled shape is right for Roman mail (Ahenobarbus altar).

---

## 7. Check against the game

Ordered by how wrong the current version is. "Model" means `art/sprites.py`, `Figure`; "data" means `game/data/*.json`.

### 7.1 Things that are wrong

**1. Moustache and gold torc on every body.** Model: `mous` boxes and `torc` torus are `part()`s of the base body, so every NPC, including all `"sex": "f"` NPCs, the Roman forager, the Balearic slinger and the Germans, gets both. Evidence: Diodorus V.28.3 (moustache is a noble fashion); V.27.3 and Strabo IV.4.5 (torcs are ornament of the wealthy); hoards and statues (section 2.3). Fix: move both out of the body into their own layers (`moustache`, `beard`, `torc_gold`, `torc_bronze`), driven by the NPC `look` (for example `"face": "moustache" | "beard" | "shaven"`, `"torc": "gold" | "bronze"`). Default: shaven, no torc.

**2. No female figure.** Model: one body; `actor.sex` is read by the rules but not by `art.gd`. Women get trousers, a thigh-length tunic and the moustache. Evidence: section 2.4. Fix: a female body variant with an ankle-length belted dress (dress takes the `tunic` mask), no visible trousers, two shoulder brooches, long hair (braid or bun), optional head-wrap; slightly smaller than the male body. Affected NPCs: `refugee_woman`, `matugenta`, `brig_villager_f`, `sulicena`, `banna`, `vind_villager_f`, and a female player character.

**3. Romans use the Gallic body.** Model: the forager gets trousers (the `trousers` mask defaults to brown), torc, moustache. Data: `roman_forager` wears `leather_jerkin`. Evidence: section 4.1. Fix, cheapest first: (a) let `look.trousers` take the skin color, or add `"legs": "bare"`, for Romans and Balearics; (b) drop the torc and moustache via fix 1; (c) give Romans short hair (a `hair` variant) and *caligae* (a darker open-work boot); (d) replace `leather_jerkin` on the forager with `mail_shirt` or with nothing (a forager might well be unarmored, but leather armor is not a Roman thing).

**4. The scutum is the wrong shape and too small.** Model: a 1.1 × ~0.73 rectangular slice of a cylinder (`shell(... keep y > 0.5)`), 57% of the figure's height. Evidence: Polybius VI.23.2–5; Fayum shield 1.28 × 0.64 m, oval; rectangular scutum is Augustan. Fix: tall oval, curved, about 75% of figure height (≈1.45 units at the current body) by about 38% wide (≈0.73), with a vertical spine from rim to rim and a central boss.

**5. One sword for two peoples, with a medieval crossguard.** Model and `pack.py`: `gallic_sword` and `gladius` both map to the `sword` layer: a 0.78 blade with a 0.16 iron crossbar. Evidence: Gondole (few La Tène swords have a marked crossguard); Polybius VI.23.6; finds (sections 3.1, 4.3). Fix: two layers. **Gallic**: blade about 47% of figure height (≈0.9 units), parallel edges, rounded or short point, no crossbar, a narrow bell-shaped guard, a simple grip and a small knob pommel. **Gladius**: blade about 37% (≈0.72 units), slightly waisted with a long tapering point, a rounded bone guard, a ridged bone grip and a ball pommel. Optionally add a scabbard on the right hip whenever a sword is equipped.

**6. The pilum is drawn as a javelin.** `pack.py`: `"pilum": "javelin"`. Evidence: section 4.5. Fix: its own layer, about 105% of figure height, the top 35 to 45% thin iron shank with a small pyramidal point, a block where iron meets wood.

**7. Cloak brooch on the wrong shoulder; cloth is flat color.** Model: brooch at `(0.13, 0.12, 1.47)`; +y is the figure's left (the left hip is at y = +0.11), so the cloak pins on the left. Evidence: Vachères (right shoulder); Roman practice. Fix: move the brooch to y ≈ −0.12 and let the drape hang more over the left arm. Make it bronze by default, gold for chiefs. For pattern: add a fourth mask channel (or a second tint) so a cloak or tunic can be a two-color check or stripe (Diodorus V.30.1; Pliny NH VIII.196). Even a coarse 3–4 pixel check on cloaks will read at game scale and is the most "Gallic" signal available.

**8. Hair has one style.** Model: a cap plus a nape mass, recolored. Fix: variants driven by `look.hair_style`: `swept` (limed, combed back into a stiff mane; Diodorus V.28.2) for warriors; `long` (to the shoulders) for most Gallic men; `short` for Romans; `knot` (side or crown knot) for Suebi; `braid`/`bun` for women; `bald` for old men. Hair color is already per NPC.

**9. Gallic shield too small.** Model: 1.0 tall, 52% of height. Evidence: Diodorus V.30.2 ("man-high"), Fayum, La Tène. Fix: about 65% of height (≈1.25 units), spine tapering at both ends, band boss with small wings or a round boss.

**10. The bow is too short.** Model: chord of about 1.1 units, 57% of height. Evidence: prehistoric and Roman Iron Age self bows run about 1.5 to 1.9 m (Ötzi's unfinished bow 1.82 m; the Nydam bows later). *Inferred.* Fix: about 90–100% of figure height.

**11. One helmet for everyone, and it's the Roman one.** `pack.py`: `bronze_helmet` and `raven_helm` both map to `helmet`. The bronze Montefortino is right for Romans. Fix: add an iron **Agen/Alesia** helmet layer for Gauls (iron cap, raised ridge at the base, a short flared rim widening at the back into a neck guard, hinged cheek pieces; a crest knob for a chief), and give `raven_helm` its own layer (section 6). Consider a separate `iron_helmet` item. The `bronze_helmet` description ("Romans wear the same kind, copied from the Gauls") is defensible for the Montefortino's Celtic origins; keep it.

**12. Leather and linen armor are inventions, and the Germans wear them.** Data: `leather_jerkin` on bandits, outlaws, Dubnacos, the trader's guard and the Germanic riders; `padded_linen` on Vellaunos. Neither has a visual layer, so the art is unaffected. Evidence: section 3.5 and section 5. Fix: keep `leather_jerkin` as a game convention for Gallic bandits; give the Germans a `hide_cloak` instead (a cloak-slot item with a fur texture: Caesar IV.1.10, VI.21.5). Give Vellaunos mail, or nothing; a chief of elders who has a sword would more likely own old mail than padded linen.

**13. Germanic archer.** Data: `rider_archer` with `hunting_bow`. Evidence: Przeworsk graves, arrowheads uncommon, bows for hunting (Czarnecka 2010); Caesar and Tacitus give the Germans spears and javelins. *Inferred.* Fix: make him a javelin rider (`javelin` ×3, `small_shield`). If an archer is wanted at the ford for gameplay, a Gallic or Cretan deserter in the band is better grounded.

**14. Item text that inverts the evidence.** `mail_shirt`: "The Romans say they invented it. The smiths of the Gauls laugh." The Roman who wrote about it, Varro, says the Gauls invented it (LL V.116). Suggested fix: the Romans *admit* the Gauls invented it, and charge them for it anyway, or similar. `gold_torque`: "The kind of thing a man is buried in": by 52 BC torcs went to the gods more often than to graves (Tayac, Fenouillet, Tintignac-type deposits). Suggest "the kind of thing a man gives to the gods, or is buried in." `gallic_sword`: the "soft" slur is Polybius's (II.33), about Gauls of 223 BC; fine in a Roman mouth, but don't attribute it to Caesar's writings. `auxiliary_slinger` desc: three slings, one round the head, one round the waist, one in hand (Diodorus V.18.3).

**15. Colors.** Data: almost every `look` is in a narrow band of dull browns and greys (#4a–#7a). That is right for the poor and for undyed wool, wrong for anyone with status. Suggested palette for dyed wool (approximate, as worn and faded):

| Use | Hex |
|---|---|
| Madder brick red | `#8e3424`, `#a8462c` |
| Madder pink/rose (weak bath) | `#b8766a` |
| Woad blue, dark / mid / light | `#2f4a66`, `#4a6a8a`, `#8aa2b4` |
| Weld yellow | `#c4a23c` |
| Woad over weld green | `#4e6a3a` |
| Lichen or plant purple | `#6a3e5c` |
| Undyed cream / grey / brown / near-black | `#d6cbb0`, `#8a847a`, `#5a4634`, `#2e2620` |

Concretely: Vellaunos, Sulicena, Lugurix and Dubnacos (a noble's son, presumably) should have at least one bright or patterned garment; farmers and refugees stay in undyed and faded colors. The vates in white is supported only by Pliny's description of druids in white at the mistletoe rite (NH XVI.250), and a vates is not a druid, but as a visual convention it's harmless.

### 7.2 Things that are right (confirmations)

- **Gallic male outfit**: tunic to mid-thigh, trousers, cloak with brooch, belt with buckle, leather shoes. Diodorus V.30.1; Strabo IV.4.3.
- **Gallic oval shield with a vertical spine and boss**, planks under leather. Diodorus V.30.2; Strabo IV.4.3; Fayum; Vachères.
- **Javelins and pila fouling shields** (DESIGN.md combat rule; `shield_breaker` values, with the pilum highest). BG I.25.3–4; Plutarch *Marius* 25.
- **Gallic mail as a rich man's armor**, and the design doc's "the Gauls are often credited with inventing mail". Varro LL V.116; Diodorus V.30.3.
- **Spear, war spear with wavy blade, javelin** as the common Gallic weapons. Diodorus V.30.4; Strabo IV.4.3.
- **Gallic slingers and bowmen**. BG VII.31, VII.36, VII.80, VII.81; Strabo IV.4.3.
- **Roman bronze helmet with knob, cheek pieces and neck guard**: a correct Montefortino.
- **Mail with shoulder reinforcement for chief_mail**. Vachères; Ahenobarbus altar.
- **Haldo**: fair hair knotted at the side (Tacitus *Germania* 38), a Roman mail shirt, a looted shield, a spear. Germanic riders with spear and small shield (Tacitus *Germania* 6).
- **The axe as a woodsman's tool used by brigands**, the knife as an everyday tool, the club and staff.
- **The Grotto's old dead with torcs**: torcs as old prestige and votive objects.
- **Dialogue**: Moccos on Romans waiting behind big shields and throwing spears all at once (BG I.25); Vellaunos on returned hostages wearing their hair short; the horse line of "small and shaggy" Germanic horses (BG IV.2.2), though by the game's date Caesar had remounted many of them on Roman horses (VII.65.5).

### 7.3 Art guidance in one place

For the art team, a figure-by-figure target. Proportions are relative to body height (the current body is about 1.94 model units tall before `FIG_SCALE`).

| Figure | Body | Hair / face | Worn | Held |
|---|---|---|---|---|
| Gallic farmer | male, tunic to mid-thigh with long sleeves, trousers, short boots | long or tied back; shaven or beard; **no torc** | undyed or faded wool; hooded cape in winter | spear, staff, sling, axe, knife |
| Gallic warrior | male, as above, brighter tunic | swept-back limed hair or long; moustache | checked or striped cloak pinned at **right** shoulder, bronze brooch; maybe a bronze torc | tall oval shield (65% of height), spear and 2 javelins, or long sword (blade 47%) worn on the **right** |
| Gallic noble | male, as above | moustache, shaved cheeks; swept hair | dyed red or blue tunic, patterned cloak, gold torc, arm ring; gold brooch; mail with shoulder cape for war; iron Agen/Alesia or Port helmet (rare) | long sword, spear, oval shield |
| Gallic woman | female, ankle-length belted dress, two shoulder brooches | long hair, braid or bun; head-wrap for older women | shawl or cloak; glass bangles; bronze or gold neck ring for high status | spindle, basket, or nothing; knife |
| Druid / vates | male, long tunic | long hair, beard optional | white or undyed; torc for a druid of rank | staff |
| Legionary | Roman: bare legs, knee-length tunic, *caligae* | short hair, shaven or stubble | mail with doubled shoulders to mid-thigh; Montefortino or Coolus helmet, crest for battle; belt with dagger; *sagum* pinned right | oval curved scutum (75% of height); gladius (blade 37%) on the **right**; pilum (105% of height, long iron shank) |
| Roman officer | Roman | short hair, shaven | muscled cuirass or fine mail; scarlet cloak for a general (Caesar's is recognized by its color, VII.88) | sword on the left (imperial evidence) |
| Balearic slinger | Roman body, bare legs | dark hair | short tunic, no armor; slings round head and waist | sling, stone bag |
| Germanic rider | male, tight trousers or bare legs | long fair to red-brown hair, Suebian side knot on some; beard | fur or hide cape; little else | spear, 2–3 javelins, round painted shield with round boss; sword only for a leader; no saddle (or a Roman saddle on a Roman horse) |

What to **add** to the layer set: `female_body`, `roman_body` (or bare-leg flag), `moustache`, `beard`, `torc_gold`, `torc_bronze`, `hair_*` variants, `hood`, `hide_cloak`, `gladius` (split from `sword`), `pilum` (split from `javelin`), `helmet_iron` (Agen/Alesia), `helmet_bird` (raven/swan), a pattern channel for cloth, a right-hip scabbard.

What to **drop or change**: the moustache and torc on the base body, the crossguard, the rectangular scutum, the left-shoulder brooch, the leather jerkin on Germans, the Germanic archer.

---

## 8. Sources

### Ancient texts

- Caesar, *Bellum Gallicum*, Latin text, The Latin Library: [Book I](https://www.thelatinlibrary.com/caesar/gall1.shtml) (I.23, I.25, I.39, I.48), [Book II](https://www.thelatinlibrary.com/caesar/gall2.shtml) (II.7, II.10, II.19, II.21, II.24, II.30), [Book IV](https://www.thelatinlibrary.com/caesar/gall4.shtml) (IV.1, IV.2, IV.3, IV.12), [Book V](https://www.thelatinlibrary.com/caesar/gall5.shtml) (V.14, V.26), [Book VI](https://www.thelatinlibrary.com/caesar/gall6.shtml) (VI.13–15, VI.21), [Book VII](https://www.thelatinlibrary.com/caesar/gall7.shtml) (VII.13, VII.31, VII.36, VII.41, VII.65, VII.67, VII.70, VII.80, VII.81, VII.85, VII.88).
- Diodorus Siculus V.17–18, V.25–32, LacusCurtius (Loeb translation, paraphrased): [V.1–23](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Diodorus_Siculus/5A*.html), [V.24–40](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Diodorus_Siculus/5B*.html).
- Strabo IV.4.2–5, LacusCurtius: [Book IV chapter 4](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Strabo/4D*.html).
- Polybius II.28–33, VI.22–23, LacusCurtius: [Book II](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Polybius/2*.html), [Book VI](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Polybius/6*.html).
- Pliny, *Naturalis Historia* VIII.191–196 and XXII.2–3, Latin, Wikisource: [Liber VIII](https://la.wikisource.org/wiki/Naturalis_Historia/Liber_VIII), [Liber XXII](https://la.wikisource.org/wiki/Naturalis_Historia/Liber_XXII). Also cited from standard editions, not re-read in this session: IV.105 (*Gallia Comata*), XIV.19 (vine staff), XVI.250 (druids in white), XXVIII.191 (soap for reddening hair), XXXIV.162–163 (tinning and silvering, Alesia).
- Varro, *De Lingua Latina* V.116 (chapter XXIV in this edition), The Latin Library: [Book V](https://www.thelatinlibrary.com/varro.ll5.html).
- Tacitus, *Germania* 4, 6, 17, 38, The Latin Library: [text](https://www.thelatinlibrary.com/tacitus/tac.ger.shtml).
- Suetonius, *Divus Iulius* 45, 67, LacusCurtius: [text](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Suetonius/12Caesars/Julius*.html).
- Plutarch, *Marius* 25, LacusCurtius: [text](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Lives/Marius*.html).
- Cicero, *Philippics* II.76; Juvenal VIII.145; Martial XIV.128: cited from standard editions, not re-read in this session.

### Archaeology and scholarship

- Barruol, G. 1996. "La statue du guerrier de Vachères (Alpes-de-Haute-Provence)." *Revue archéologique de Narbonnaise* 29: 1–12. Summarized via [fr.wikipedia, Guerrier de Vachères](https://fr.wikipedia.org/wiki/Guerrier_de_Vach%C3%A8res) (pointer only).
- Colin, A. 1998. *Chronologie des oppida de la Gaule non méditerranéenne.* Documents d'archéologie française 71. Paris: MSH. Chapter 2 online: [OpenEdition](https://books.openedition.org/editionsmsh/44658?lang=en).
- Connolly, P. 1986. "A reconstruction of a Roman saddle." *Britannia* 17: 353–355. (Not consulted directly.)
- Connolly, P. 1997. "Pilum, gladius and pugio in the Late Republic." *Journal of Roman Military Equipment Studies* 8: 41–57. (Not consulted directly.)
- Czarnecka, K. 2010 (proceedings published later). "Warriors in this world and the afterlife: Przeworsk culture graves containing weapons." In *Weapons and Military Equipment in a Funerary Context*, Proceedings of the XVIIth ROMEC, Zagreb: 163–175. [PDF](https://a-r-m-e-s.org/wp-content/uploads/2023/08/17-163-175-Czarnecka.pdf).
- Deberge, Y., et al. 2009. "L'oppidum arverne de Gondole (Le Cendre, Puy-de-Dôme). Topographie de l'occupation protohistorique (La Tène D2) et fouille du quartier artisanal : un premier bilan." *Revue archéologique du Centre de la France* 48. [OpenEdition](https://journals.openedition.org/racf/1280).
- Feugère, M. 1985. *Les fibules en Gaule méridionale de la conquête à la fin du Ve s. ap. J.-C.* Supplément à la *RAN* 12. Paris: CNRS. (Not consulted directly.)
- Feugère, M. 2011. *Casques antiques. Les visages de la guerre de Mycènes à la fin de l'Empire romain.* New ed. Paris: Errance. (Not consulted directly; typology via [fr.wikipedia, Casque celtique](https://fr.wikipedia.org/wiki/Casque_celtique), pointer only.)
- Fitzpatrick, A. P. 2022. "Armes romaines tardo-républicaines trouvées au Yaudet à Ploulec'h, Côtes-d'Armor." *Revue archéologique de l'Ouest* 38. [OpenEdition](https://journals.openedition.org/rao/8772).
- Fuentes, N. 1987. "The Roman military tunic." In M. Dawson (ed.), *Roman Military Equipment: The Accoutrements of War*. BAR S336: 41–75. (Not consulted directly.)
- Girault, J.-P. 2013. *La fontaine de Loulié au Puy-d'Issolud. Le dossier archéologique du siège d'Uxellodunum.* Bibracte 23. Glux-en-Glenne. (Not consulted directly; see [uxellodunum.com](https://www.uxellodunum.com/).)
- Grömer, K., Kern, A., Reschreiter, H., Rösel-Mautendorfer, H. (eds.) 2013. *Textiles from Hallstatt: Weaving Culture in Bronze Age and Iron Age Salt Mines.* Budapest: Archaeolingua. (Not consulted directly.)
- Hofmann-de Keijzer, R., van Bommel, M., Joosten, I. 2005. "Dyestuff and element analysis on textiles from the prehistoric salt-mines of Hallstatt." In P. Bichler et al. (eds.), *Hallstatt Textiles*, BAR S1351. Overview via [Hartl et al. 2015, "Searching for blue", *JAS Reports* 2](https://dissem.in/p/25995389/searching-for-blue-experiments-with-woad-fermentation-vats-and-an-explanation-of-the-colours-through-dye-analysis).
- Kimmig, W. 1940. "Ein Keltenschild aus Ägypten." *Germania* 24: 106–111. (Not consulted directly; dimensions via secondary sources.)
- Lejars, T. 1994. *Gournay III. Les fourreaux d'épée.* Paris: Errance. Lejars, T. 2003. "Les fourreaux d'épée laténiens, supports et ornementation." [HAL](https://hal.science/hal-00354822). (Not consulted in detail.)
- Maniquet, C. 2004. *Le sanctuaire antique des Arènes de Tintignac.* Limoges: Culture et Patrimoine en Limousin. Maniquet, C., et al. 2011. "Le carnyx et le casque-oiseau celtiques de Tintignac (Naves-Corrèze). Description et étude technologique." *Aquitania* 27. [Aquitania PDF](https://aquitania.u-bordeaux-montaigne.fr/_jumi/pdf/1191.pdf) (could not open in this session). INRAP image notice for the bird helmet: [images-archeologie.fr](https://www.images-archeologie.fr/Accueil/Recherche/p-3-lg0-notice-IMAGE-Casque-oiseau-en-bronze-entre-le-IVe-et-le-IIe-s.avant-notre-ere-decouvert-dans-un-depot-d-objets-en-bronze-sur-le-site-de-Tintignac-a-Naves-Corr_0ee2945e6a8cd2e59787325cd0aea3ae-15932633.htm?notice_id=4665).
- Musée d'Aquitaine, Bordeaux. "Trésor gaulois de Tayac." [Collection page](https://www.musee-aquitaine-bordeaux.fr/collections/les-oeuvres-phares-retrouver-au-musee/prehistoire-et-protohistoire/tresor-gaulois-de-tayac).
- Musée Saint-Raymond, Toulouse. "Des bijoux de famille ?" (Fenouillet and Lasgraïsses torcs). [Page](https://saintraymond.toulouse.fr/des-bijoux-de-famille/).
- Pernet, L. 2010. *Armement et auxiliaires gaulois (IIe et Ier siècles avant notre ère).* Protohistoire européenne 12. Montagnac: Mergoil. (Not consulted directly; the standard reference for this whole section.)
- Pleiner, R. 1993. *The Celtic Sword.* Oxford. (Not consulted directly.)
- Quesada Sanz, F. 1997. "Gladius hispaniensis: an archaeological view from Iberia." *JRMES* 8: 251–270. (Not consulted directly.)
- Reddé, M., von Schnurbein, S. (eds.) 2001. *Alésia. Fouilles et recherches franco-allemandes sur les travaux militaires romains autour du Mont-Auxois (1991–1997)*, vol. 2, *Le matériel*, incl. S. Sievers, "Les armes d'Alésia." Mémoires de l'Académie des inscriptions et belles-lettres 22. (Not consulted directly; cited via Fitzpatrick 2022 and others.)
- Rusu, M. 1969. "Das keltische Fürstengrab von Ciumești in Rumänien." *Bericht der Römisch-Germanischen Kommission* 50: 267–300. Rustoiu, A. 2006. "A journey to Mediterranean. Peregrinations of a Celtic warrior from Transylvania." *Studia Universitatis Babeș-Bolyai, Historia* 51(1): 42–85. [CEEOL abstract](https://www.ceeol.com/search/article-detail?id=67072). Date range c. 250–175 BC per [Livius](https://www.livius.org/pictures/romania/ciumesti/ciumesti-celtic-helmet/).
- Roman Republican coins: Crawford, *Roman Republican Coinage* (1974), RRC 448/2 (L. Hostilius Saserna, 48 BC) and RRC 452/2 (Caesar, 48–47 BC). Identification of RRC 448 with Vercingetorix questioned in [*Documenta & Instrumenta* (2022)](https://revistas.ucm.es/index.php/DOCU/article/download/80126/4564456560494/4564456642969).
- Wild, J. P. 1968. "Clothing in the north-west provinces of the Roman Empire." *Bonner Jahrbücher* 168: 166–240. Böhme-Schönberger, A. 1997. *Kleidung und Schmuck in Rom und den Provinzen.* Stuttgart. (Neither consulted directly.)

Works marked "not consulted directly" are the standard references behind the inferred statements; check them before turning an inference into in-game text that claims precision.
