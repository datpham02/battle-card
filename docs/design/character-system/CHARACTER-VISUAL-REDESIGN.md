# Character visual redesign — names and identity-driven design

**Status:** PROPOSAL. Nothing generated, nothing in `assets/art` touched, no ID changed, no commit.
**Date:** 2026-11-14
**Reads:** `assets/data/characters.json`, `src/passives/`, `src/signatures/`, `cards.json`,
`design/art/art-bible.md` §4 §5.1, `art_src/palette/tessera_master.gpl`, `design/world-context.md` §6,
and the F1 identity shipped in `7675a6f7`.

---

## 0. Read this before the designs: two conflicts that change the brief

Both were found by reading the Art Bible against the new direction, not by guessing.

### 0.1 "No weapons" removes the Art Bible's primary recognition feature

Art Bible §5.1 states the hero must be **recognisable from the top 20 px alone** — "đầu, vai, vật
cầm" (head, shoulders, **held object**) — and the lower half is "2 tones, shape only". It then assigns
each hero a held object as their identity marker, and is explicit about the Swordsman's: the tell is
**the cross guard, not a wide blade** (a correction made after the v1 read as Cloud from FF7).

So four of the five heroes currently carry their identity in the thing they hold. Removing it does not
just change the costume — it **removes the feature the whole art direction leans on at 40 px**. Each
redesign below therefore has to answer: *what occupies the top 20 px instead?* A costume detail alone
is usually not enough, because §5.1 also caps the accent at ≤ 15 % of pixels.

### 0.2 Two instructions about weapons disagree, and it changes all five designs

- 2026-11-14, your message: *"giờ các char ko cần vũ khí nữa mà cast skill thôi"* — weapons gone.
- This brief, Phase 2 §5: *"Nếu nhân vật có vũ khí trong animation hoặc hình ảnh, nó chỉ là một phần
  của tạo hình, không được tạo ra hệ thống trang bị mới"* — a weapon **may** exist as costume, it just
  must not become an equipment system.

These are different designs. **Reading A** (no weapon shapes at all) forces a new top-20 px marker for
four heroes. **Reading B** (weapons allowed as pure costume, never equipment) changes almost nothing
visually, since no equipment system exists today anyway.

> **DECIDED 2026-11-14 — Reading A, "bỏ hẳn".** No weapon shapes at all, on any of the five. The
> "Under Reading B" lines kept below each character are now dead alternatives, retained only so a later
> reader can see what was considered and rejected rather than re-proposing it.
>
> **Consequence, now live:** conflicts **C1 and C2** in §6 are no longer hypothetical. Art Bible §5.1
> assigns four of the five heroes a held object as their identity in the top 20 px, and its Swordsman
> row still specifies a cross-guard sword. **The Art Bible now disagrees with the direction and must be
> amended** — that is an art-director edit, i.e. yours, not a change I make on my own. Until it is
> amended, `design/art/art-bible.md` §5.1 and these designs describe two different games.
>
> Ilva is unaffected: she already holds only a book and casts with an open hand.

---

## 1. Phase 0 — Names

> **APPROVED 2026-11-14.** The user approved all five: **Vale · Ilva · Quill · Bram · Oriel**. The
> alternates below are kept as the record of what was weighed, not as live options. Nothing has been
> renamed in the game yet — see "What the rename actually costs" at the end of this section.

Role words are not names. The five below are proper names; the technical IDs stay exactly as they are.

### The set

| Character ID | Current role name | **Proposed name** | Meaning | Rationale |
|---|---|---|---|---|
| `kiem_si` | Kiếm sĩ / Swordsman | **Vale** | Latin *vale* = "farewell"; also a valley | One syllable, hard consonant, said the same in every language. A man who kept the oath of an order that no longer exists is carrying a farewell. It names his situation, not his job. |
| `phap_su` | Pháp sư / Mage | **Ilva** | Soft, invented; reads northern-European | Two liquid syllables against Vale's single hard one. Scholarly rather than wizardly — she is a researcher of the new law, not a spell-slinger. Nothing about fire in the name, because fire is her method, not her identity. |
| `sat_thu` | Sát thủ / Assassin | **Quill** | A quill: small, sharp, precise | Her mechanic is small cuts that hit hard. A quill is the smallest sharp thing a person carries, and it is a *tool*, which matches a character doing a paid job rather than living a creed. Avoids every "Shadow / Raven / Vex" assassin cliché. |
| `tho_san` | Thợ săn / Hunter | **Bram** | From *bramble* — thorn scrub | His whole mechanic is thorns and traps, and "Bram" carries that without naming it the way "Thorne" would. Blunt, earthy, one syllable, sounds like a person rather than a title. |
| `giao_si` | Giáo sĩ / Priest | **Oriel** | An *oriel* is a projecting bay window — the home of stained glass | His block material is stained glass. The name says it through architecture instead of religion, so it carries the light without the churchy register. Longest name in the set, which suits the slowest character. |

### Harmony check, five together

**Vale · Ilva · Quill · Bram · Oriel**

- **Initials** V, I, Q, B, O — no two alike, none easily confused in writing.
- **Lengths** 1, 2, 1, 1, 2–3 syllables — varied, not a matched set.
- **Sound** two hard-consonant names (Vale, Bram), one sharp (Quill), two liquid (Ilva, Oriel). They
  sit in the same world without sounding like siblings.
- **Origin** deliberately mixed, per the brief: Latin, invented, English common noun, dialect shortening,
  architectural term. None is Sino-Vietnamese and none is wuxia.

> **This reversed an earlier decision, and the reversal is now the live one.** On 2026-11-13 the user
> approved OD-8 as "keep the Sino-Vietnamese names, they are intentional". The naming brief said the
> opposite — *"Không bị giới hạn trong phong cách Hán-Việt"* — and on 2026-11-14 the user approved
> this set, so **OD-8 is superseded**. It is marked as such in `CHARACTER-SYSTEM-REDESIGN.md` rather
> than left to contradict itself.

### What the rename actually costs

**Correcting my own estimate.** When these names were first put to the user I said only
`character.<id>.name` would change. That was wrong, and the error is the kind worth recording: the
role words are written *inside the prose*, not only in the name field. Measured against
`assets/i18n/strings.csv`:

| Key group | Lines | Example of the embedded role word |
|---|---|---|
| `character.<id>.name` | 5 | `Kiếm sĩ` → `Vale` |
| `character.<id>.lore` | 5 | *"**Kiếm sĩ** leo lên Tâm Lưới để đòi lại cái vung tay tự do ngày trước."* |
| `achievement.win_<id>.name` / `.desc` | 10 | *"**Kiếm sĩ** khải hoàn"* / *"Thắng một chuyến leo với **Kiếm sĩ**"* |
| `achievement.hunter_path.name` | 1 | *"Đường **Thợ săn**"* |

**21 lines, two language columns each — 42 strings.** A partial pass is worse than none: the select
card would read "Vale" with "Kiếm sĩ leo lên Tâm Lưới" directly beneath it.

Not affected, verified rather than assumed:
- `character.<id>.desc` — the five description lines never name the character.
- `boss.frost_mage.name` (*"Pháp Sư Sương" / "Frost Mage"*) — a BOSS, not the hero. It matched a grep
  for "Pháp sư" and must not be touched.
- **The IDs**, and therefore save data: saves key on `kiem_si` … `giao_si`, which do not change.

**Not done yet, and not startable today:** `assets/i18n/strings.csv` is inside the repo-wide file
freeze (2026-11-14, while the UI-style session runs the 315-suite build-health run). The 42 strings
also need the user to read the rewritten lore lines — a rename that changes prose is a writing task,
not a find-and-replace.

### Two alternates each

| ID | Chosen | Alternate 1 | Alternate 2 | Why the chosen one wins |
|---|---|---|---|---|
| `kiem_si` | **Vale** | **Corren** — hard, steel-like, invented | **Aldric** — classic knight | Corren is good but generic-martial; Aldric is the exact fantasy-knight name the brief says to avoid. Vale alone says something about his *condition*. |
| `phap_su` | **Ilva** | **Sereth** — arcane, sibilant | **Wren** — small bird, plain | Sereth sounds like a sorceress from any game; Wren is charming but reads timid, and she is not. Ilva is calm and clever. |
| `sat_thu` | **Quill** | **Sable** — dark, elegant | **Rix** — abrupt, hard | Sable is the assassin cliché in one word. Rix is memorable but harsh beside Bram. Quill is the only one that says *precise* rather than *dangerous*. |
| `tho_san` | **Bram** | **Thorne** — direct | **Hask** — dry, rough | Thorne names his mechanic too literally and would date badly if thorns are retuned. Hask is distinctive but unpleasant to say. |
| `giao_si` | **Oriel** | **Senna** — plant, gentle | **Lumen** — light | Senna reads feminine-soft and loses his firmness; Lumen is on-the-nose and collides with the Lattice-light accent colour. Oriel carries the glass without saying "holy". |

---

## 2. Phase 1 — Identity analysis

Everything below is read from data, not invented. Attributes from `characters.json`, passives from
`src/passives/`, signatures from `src/signatures/`, decks from `starter_deck`.

### Vale — `kiem_si`

| | |
|---|---|
| **Core identity** | A sworn blade of an order that no longer exists, who kept the oath anyway. Before the Cataclysm drawing the sword was enough; now every cut must pass through a steel block he picks up himself. |
| **Personality** | Terse, patient, never taunts. |
| **Combat identity** | Few casts, each heavy. Deck is `do_kiem`, `kiem_vu` ×2, `thiet_kiem` ×2, `chan_phong` — the only opening deck with **zero** copies of the shared base card. |
| **Gameplay identity** | Highest HP band (200), neutral step, 4 s focus. Plays as the one who can afford to be hit while setting up a big cut. |
| **Signature identity** | `second_wind` — +20 HP after a won match, a **run-economy** passive, not a combat one. Signature **Trảm**: 3 s where every cut counts double its cells and lifesteals 20 %. |
| **Emotional impression** | Endurance. The one who is still standing. |
| **Visual keywords** | Steel; symmetry; planted weight; incomplete armour; discipline without rank. |
| **Visual contradictions — avoid** | Any hero-of-destiny read (cape, helm crest, glowing blade). Shoulder spikes. A sheathed sword or empty scabbard, which reads "lost his weapon" — a different character. Tall spiky hair (the v1 Cloud failure, §5.1). |

### Ilva — `phap_su`

| | |
|---|---|
| **Core identity** | Does not mourn the old magic; wants to know how the new law is written. Each ember block set down is an experiment; the fire left behind is the notes. |
| **Personality** | Curious, cool-headed, treats every fight as an experiment. |
| **Combat identity** | Wide burn shapes. Deck `kiem_khi`, `hoa_xa`, `hoa_tinh` ×2, `hoa_tran`, `bang_phong`. |
| **Gameplay identity** | **Longest focus in the roster, 5 s** — she gets more thinking time than anyone. The `attributes` say "deliberate", not "frantic". |
| **Signature identity** | `wide_caster` — casts of ≥ 4 cells wind up 25 % faster, so she is rewarded for *bigger* shapes, not faster ones. Signature **Thiên Hỏa**: detonates existing burn, resets burn cooldowns, re-ignites the engraved half. |
| **Emotional impression** | Composure. The one who is unhurried while things burn. |
| **Visual keywords** | Ember; char; paper and notes; asymmetry of a working scholar; soot on the hands. |
| **Visual contradictions — avoid** | **Do not draw her as fast or frantic.** Her speed is in the *cast*, not the body — this is the brief's own warning about confusing "nhanh nhẹn" with "tính toán". No pointed witch silhouette as a joke, no bubbling potions, no staff crackling with lightning. Her HP is also being lowered to 170 (OD-1), so avoid a bulky protective read. |

### Quill — `sat_thu`

| | |
|---|---|
| **Core identity** | Someone paid to have a Primal Shard brought back, and she took the job. |
| **Personality** | Practical, unattached, in it for the job. |
| **Combat identity** | Small blocks, constant pressure. Deck `kiem_khi` ×2, `kiem_vu`, `thiet_kiem`, `bang_chau`, `han_kiem`. |
| **Gameplay identity** | **Genuinely the fast one** — lowest HP (180) and the only step multiplier below 1.0 (×0.9). Unlike Ilva, the speed is in the *body*. |
| **Signature identity** | `quick_blade` — hits of ≤ 4 cells deal ×1.4, so she is rewarded for *small* shapes. The exact inverse of Ilva, and the designs must make that legible. Signature **Ảnh Bộ**: 2 s of free stepping, small hits ×1.75. |
| **Emotional impression** | Economy of motion. Nothing wasted. |
| **Visual contradictions — avoid** | Heroic posture. Bulk anywhere. Trailing cloth that implies drag. Any "edgy assassin" read — hoods with glowing eyes, skull motifs. She is a contractor, not a creed. |

### Bram — `tho_san`

| | |
|---|---|
| **Core identity** | Does not climb for the Lattice Heart but for the Wardens. The ground does the striking; he only picks the spot. |
| **Personality** | Stubborn, patient, trusts the trap more than the blow. |
| **Combat identity** | Lays thorns and traps. Deck `kiem_khi` ×2, `tran_gai` ×2, `gai_doc`, `ran_kich`. |
| **Gameplay identity** | Middle HP (200), slightly quick step (×0.95). Unlocked by **killing** 3 Wardens — the harsher path. |
| **Signature identity** | `hunter_mark` — the enemy gains Rạn when it steps onto his thorns or when thorns are laid beside it, then a 3 s cooldown. He wins by *where the enemy stands*. Signature **Vây Bắt**: thorns last ×1.5, +1 cell, Rạn consumed at ×2. |
| **Emotional impression** | Preparation. The sense that the ground was already arranged before you arrived. |
| **Visual keywords** | Wood and cord; working hands; things carried in order; weathered, not ragged. |
| **Visual contradictions — avoid** | Noble-ranger romance (elven grace, flowing hair). Pristine gear. A quiver of arrows, which implies the ranged-weapon system that does not exist. Anything that reads "gentle woodsman" — he kills Wardens for their shards. |

### Oriel — `giao_si`

| | |
|---|---|
| **Core identity** | Believes the world can still be put back together. Sparing a Warden is harder than felling one, and he takes the harder road. |
| **Personality** | Calm and firm; merciful without being soft. |
| **Combat identity** | Builds Chill. Deck `kiem_khi` ×2, `han_khi` ×2, `han_kiem` ×2 — only **three distinct cards**, the least varied opening in the roster. |
| **Gameplay identity** | Joint-highest HP (210) and the **slowest step in the roster** (×1.05) — the only character who moves worse than baseline. Unlocked by **sparing** 3 Wardens. |
| **Signature identity** | `prayer` — every Chill burst on the enemy heals him 8. His cue is the only one whose cause and effect are in different places. Signature **Thanh Ấn**: +1 Chill per hit, bursts ×1.5. |
| **Emotional impression** | Steadiness. Someone who will still be there at the end of a long fight. |
| **Visual keywords** | Stained glass; lead came; slow weight; held light. |
| **Visual contradictions — avoid** | Generic fantasy cleric (mitre, tabard crosses, halo). Frailty — he is the *toughest* character, not a healer in robes. Gold, which belongs to the card frames. |

---

## 3. Phase 2 — Visual identity per character

All five obey Art Bible §5.1: chibi ~2.8 heads, 32×48 frame, 40 px tall, 1 px Ink outline, **≤ 8
colours**, accent = block colour at **≤ 15 % of pixels**, eyes 2×2 Ink with no whites, emotion carried
by the body pose. Accent may not use Burn, Frozen, Chill, Lattice-light, odd purple or Red.

> Every colour named below is already in `art_src/palette/tessera_master.gpl`. Where a design needs a
> value that is **not** in the locked palette I have said so instead of inventing one, because
> `export_sheets.py` refuses any opaque pixel outside the list and adding an entry is the art
> director's call (§8.4). See §6.

### Vale — silhouette: **a squared anvil**

- **Top 20 px, the new marker (replacing the cross guard):** both forearms raised and crossed at chest
  height, wrapped in cord, with **bare open hands** — the widest, highest-contrast shape in the frame.
  The read is "the hands are the instrument now". Shoulders stay the squarest in the roster.
- **Body:** widest of the five, lowest centre of gravity, feet planted apart.
- **Face:** short ash-blond hair, flat fringe, 1 px Ivory headband; level brows. Unchanged from the
  approved v3 — it is not the part that failed.
- **Costume:** shoulder plates and bracers kept in Armour mid `#8FA3B8`, but the chest is now a layered
  tabard in Tabard navy `#34406E` rather than a breastplate. **The armour is deliberately incomplete** —
  a knight's plate worn by someone who stopped fighting with steel.
- **Colour identity:** primary Armour mid `#8FA3B8`, secondary Tabard navy `#34406E`, accent Armour
  light `#EEF4FA` on the shoulder plates (big shapes, not trim — trim is invisible at 40 px).
- **Props:** none held. Cord wraps on the forearms are the only addition.
- **Motif:** his blocks are steel plate; the cast forms as a flat slab between the raised hands.
- *Under Reading B:* the cross-guard sword returns to his back and the raised hands become a secondary read.

### Ilva — silhouette: **a tall narrow triangle, already correct**

- **Top 20 px:** the folded pointed hat with its tassel, and the **open book held one-handed** (your
  decision 2026-11-04). Both stay. She is the only hero who needs no new marker.
- **Body:** tallest and thinnest. Slight forward lean of someone reading while walking.
- **Face:** loose silver hair 3 px below the brim; eyes 2×1 — the narrowest in the roster, which reads
  as attention rather than speed.
- **Costume:** charcoal robe `#3A2A26`, amber `#F0A030` on the hat band, hem and belt. Add **soot at
  the cuffs and one hand** — she works with fire and does not keep it tidy.
- **Colour identity:** primary charcoal `#3A2A26`, accent amber `#F0A030` (≤ 15 %).
- **Props:** the open book. Loose pages tucked into the belt — the notes her lore mentions.
- **Motif:** blocks are dark bodies cracked with amber, leaving embers.
- *Under Reading B:* unchanged — she never had a weapon.

### Quill — silhouette: **a flattened spindle, lowest in the frame**

- **Top 20 px, the new marker (replacing the two drawn daggers):** a **high narrow hood with a sharp
  peak**, and both hands held low and close, fingers spread — a reader of distances. The hood becomes
  the whole upper read, so it must be the most angular shape in the roster.
- **Body:** shortest (34–36 px), permanently slightly crouched. Nothing trails.
- **Face:** face wrap; only a 3×1 Ivory eye slit.
- **Costume:** charcoal cloth, strapped close at every joint. **Nothing loose anywhere** — the silhouette
  must read "fast" without a motion effect.
- **Colour identity:** primary charcoal cloth, accent **pale jade-white** at the hood edge and cuffs.
- **Props:** none held. Empty sheaths are **forbidden** — same reason as Vale's scabbard.
- **Motif:** small clear sharp-edged blocks.
- **Palette issue:** her approved accent `#BFF3EC` is a near-Chill value and §5.1 forbids a Chill-like
  accent. It survives today only because the daggers carried it in a tiny area. With the daggers gone
  the accent moves to the hood edge, and it needs to be re-judged. **See §6.**
- *Under Reading B:* the two daggers return across the chest and the hood becomes secondary.

### Bram — silhouette: **a T, widest at the shoulders**

- **Top 20 px, the new marker (replacing the shouldered crossbow):** the **wide hat brim** with its
  single ivory feather, over a **coil of cord across the chest** and a shoulder roll of stakes. The
  brim is already the widest horizontal in the roster; it now carries the identity alone.
- **Body:** squared shoulders, weight on the back foot — a man who waits.
- **Face:** brown hair; 2×1 eyes shadowed under the brim.
- **Costume:** brown leather `#9A7D5E` over olive-grey, worn and mended. Pouches arranged in order,
  not scattered — he is organised.
- **Colour identity:** primary leather `#9A7D5E`, secondary moss grey `#5E6B55`, accent jade cord
  `#46D6A4` kept to ≤ 6 px as §5.1 already specifies.
- **Props:** cord, stakes, a folded frame at the hip. These are **trap-making tools, not weapons** —
  which is the distinction worth confirming in §0.2.
- **Motif:** blocks like a set trap frame of wood and cord.
- *Under Reading B:* the crossbow returns to the shoulder.

### Oriel — silhouette: **a wide bell, heaviest at the base**

- **Top 20 px, the new marker (replacing the square-headed staff):** the **veil**, and both hands
  raised and cupped as if holding a pane — the gesture of carrying something fragile. The veil is the
  only soft shape in the roster and is already distinctive.
- **Body:** widest base, narrowest shoulders — the inverse of Vale. Reads immovable rather than strong.
- **Face:** veil over the hair; eyes closed, 3×1. The only closed eyes in the roster.
- **Costume:** ivory-grey and lead `#B8BCC8` layers falling to the floor. **Lead came lines** — the dark
  strips between stained-glass panes — run as 1 px Ink seams down the robe, so the costume is literally
  built like a window.
- **Colour identity:** primary lead grey `#B8BCC8`, accent pale violet `#B9B0DC` at the veil edge and cuffs.
- **Props:** none held. The cupped hands replace the staff.
- **Motif:** blocks like glowing coloured glass held in lead.
- *Under Reading B:* the square-headed staff returns.

---

## 4. Phase 3 — Five independent generation prompts

Each prompt stands alone. **None of these has been run** and none should be until §0.2 is answered and
the anchor is approved.

Shared art direction, to be appended to every prompt verbatim:

> Pixel art in the style of One Step From Eden: flat lattice, unit standing upright, 3/4 facing right,
> chibi proportions about 2.8 heads, roughly 40 px tall inside a 32×48 frame, feet anchored. 1 px dark
> outline (#1B1722) outside; at most 3 internal separating lines. At most 3 shade steps per material,
> light from the upper left. Eyes are 2×2 dark pixels with no whites. At most 8 colours total. No glow,
> no bloom, no gradients, no anti-aliasing. Full body, standing alone, whole silhouette visible, nothing
> cropped. Plain flat background. No text, no logo, no watermark.

### CHARACTER DESIGN PROMPT — Vale

**Core identity:** A knight of an order that no longer exists, who kept the oath anyway. He no longer
fights with steel; he shapes power with his hands.
**Personality and expression:** Terse, patient, unshowy. Level brows, mouth closed, gaze straight ahead.
**Body and silhouette:** The widest and heaviest of five heroes. Squared anvil shape, broad symmetrical
shoulders, low centre of gravity, feet planted apart.
**Face:** Short ash-blond hair with a flat fringe, a thin ivory headband, level brows, calm eyes.
**Costume:** Steel shoulder plates and forearm bracers over a layered navy tabard. The armour is
deliberately incomplete — plate at the shoulders and arms only, no breastplate, no helm, no cape.
Forearms wrapped in cord, hands bare and open.
**Color palette:** Primary steel grey-blue #8FA3B8; secondary deep navy #34406E; accent pale steel
#EEF4FA on the shoulder plates only; skin #E3B99A; hair #D8CDB0; outline #1B1722.
**Signature details:** Both forearms raised and crossed at chest height, bare palms open and apart, as
if bracing an invisible slab between them. No weapon of any kind, and no scabbard or empty sheath.
**World integration:** After the Cataclysm all power must pass through blocks of square tiles. His
discipline moved from the sword into the stance.
**Avoid:** Swords, scabbards, shields, helms, capes, shoulder spikes, glowing eyes, tall spiky hair,
heroic chest-out posture, gold trim, any chosen-one read.

### CHARACTER DESIGN PROMPT — Ilva

**Core identity:** A scholar of the new law of the world. She does not mourn the old magic; she wants
to know how the new one is written, and each fire she leaves behind is a note.
**Personality and expression:** Curious, cool-headed, unhurried. Attentive narrow eyes, mouth closed.
**Body and silhouette:** The tallest and thinnest of five heroes. A high narrow triangle, slight forward
lean like someone reading while walking. Not frantic, not acrobatic — deliberate.
**Face:** Loose silver hair falling a little below a folded pointed hat with a tassel; narrow eyes.
**Costume:** A charcoal robe with a wide hem, a folded pointed hat with a tassel, a belt with loose
pages tucked into it. Soot stains at the cuffs and on one hand.
**Color palette:** Primary charcoal brown-black #3A2A26; accent amber #F0A030 on the hat band, hem and
belt only; skin #E3B99A; hair #E8D9A8; outline #1B1722.
**Signature details:** An open book held in one hand at chest height; the other hand free, palm
forward. Embers, not flames, at the book's edge.
**World integration:** Her blocks are dark bodies cracked with amber that leave embers behind.
**Avoid:** Any fast or acrobatic pose, a crackling staff, potions, a crooked witch silhouette, bulky
protective layers, large round eyes, sparkles or glow.

### CHARACTER DESIGN PROMPT — Quill

**Core identity:** A contractor paid to retrieve a shard. Not a creed, not a vendetta — a job, done
precisely and without waste.
**Personality and expression:** Practical, unattached, economical. Nothing theatrical.
**Body and silhouette:** The shortest of five heroes and the only crouched one. A flattened spindle,
permanently slightly low, nothing trailing or loose anywhere.
**Face:** A cloth face wrap covering everything but a narrow horizontal eye slit.
**Costume:** Dark charcoal cloth strapped close at every joint — wrists, waist, knees, ankles. A high
narrow hood with a sharp angular peak, the most angular shape of the five. No cloak, no loose fabric.

> **AMENDED 2026-11-16 by the user, who supplied a reference sheet.** The "no cloak, no loose fabric"
> line and the "flowing cloaks" entry in **Avoid** are overturned for Quill: she now wears a **half-cape over
> one shoulder with a pointed tail**, plus a diagonal chest strap with a square buckle, a belt pouch, layered
> forearm wraps and wrapped boots. The reason is legibility, not taste — the first two anchors (2026-11-15,
> `assassin-assets.md`) read as a flat charcoal mass at battle size because nothing broke the torso up. The
> half-cape is the silhouette element the design was missing. Leather browns `#5E4636` and `#8A6A50` come back
> into her palette for the straps and wraps, and `#555064` becomes the cool highlight the user asked for
> ("bạc lạnh"), with `#EFE6D2` reserved for the hood rim and the eyes.
>
> The anti-lookalike rule still applies, and the cape moves her toward the generic cloaked rogue, so what has
> to carry the difference now is the **asymmetry** (one shoulder, not a full cloak), the permanent crouch, and
> the empty open hands. Weapons stay gone: the 2026-11-14 "bỏ hẳn" decision is untouched by this amendment.
**Color palette:** Primary charcoal #3A3744; accent pale jade-white at the hood edge and cuffs only;
skin #E3B99A; outline #1B1722.
**Signature details:** Both hands held low, close to the body, fingers spread and empty — measuring a
distance. No weapons, and no empty sheaths or scabbards.
**World integration:** Her blocks are small, clear and sharp-edged.
**Avoid:** Daggers, knives, sheaths, skull motifs, glowing eyes under the hood, flowing cloaks, heroic
posture, any bulk, any "edgy assassin" styling.

### CHARACTER DESIGN PROMPT — Bram

**Core identity:** A hunter of Wardens. The ground does the striking; he only picks the spot and waits.
**Personality and expression:** Stubborn, patient, unhurried. Watchful, weight on the back foot.
**Body and silhouette:** A T shape, the widest shoulders of the five, squared and settled.
**Face:** Brown hair, eyes shadowed under a wide hat brim.
**Costume:** Worn brown leather over olive-grey cloth, visibly mended. A wide-brimmed hat with a single
ivory feather. A coil of cord across the chest, a roll of wooden stakes at the shoulder, small pouches
arranged in a neat row.
**Color palette:** Primary leather brown #9A7D5E; secondary moss grey #5E6B55; accent jade green
#46D6A4 on the cord only, very small area; skin #E3B99A; outline #1B1722.
**Signature details:** Trap-making tools — cord, stakes, a folded wooden frame at the hip. Hands free
and working. No bow, no crossbow, no quiver, no arrows.
**World integration:** His blocks look like a set trap frame of wood and cord.
**Avoid:** Bows, crossbows, quivers, arrows, elven grace, flowing hair, pristine gear, a gentle
woodsman read.

### CHARACTER DESIGN PROMPT — Oriel

**Core identity:** A man who believes the broken world can be put back together, and who takes the
harder road of sparing what he could destroy.
**Personality and expression:** Calm and firm. Merciful without being soft. Eyes closed, head slightly
bowed, entirely still.
**Body and silhouette:** A wide bell — heaviest at the base, narrowest at the shoulders, the inverse of
the armoured hero. Reads immovable rather than strong. The slowest-looking of the five.
**Face:** A veil over the hair, eyes closed, a composed mouth.
**Costume:** Layered ivory-grey and lead-grey robes falling to the floor. Thin dark seams run down the
robe like the lead came between panes of stained glass, so the garment is built like a window.
**Color palette:** Primary lead grey #B8BCC8; accent pale violet #B9B0DC at the veil edge and cuffs
only; skin #E3B99A; outline #1B1722.
**Signature details:** Both hands raised and cupped in front of the chest as if carrying a fragile pane
of glass. No staff, no weapon.
**World integration:** His blocks look like glowing coloured glass held in lead.
**Avoid:** Mitres, crosses, halos, holy symbols, gold, frailty or thinness, a staff or mace, anything
that reads as a generic fantasy cleric.

---

## 5. Phase 4 — Cross-character consistency

| Character | Core identity | Silhouette | Primary colours | Signature visual motif |
|---|---|---|---|---|
| **Vale** | Knight of a dead order | Squared anvil, widest, lowest | Steel `#8FA3B8` + navy `#34406E` | Raised crossed forearms, bare open hands |
| **Ilva** | Scholar of the new law | Tall narrow triangle, leaning | Charcoal `#3A2A26` + amber `#F0A030` | Pointed hat with tassel + open book |
| **Quill** | Contractor on a job | Flattened spindle, shortest, crouched | Charcoal `#3A3744` + pale jade | Sharp angular hood, empty low hands |
| **Bram** | Warden-hunter | T shape, widest shoulders | Leather `#9A7D5E` + moss `#5E6B55` | Wide brim + feather, cord across chest |
| **Oriel** | Mender of the world | Wide bell, heaviest base | Lead grey `#B8BCC8` + pale violet | Veil, cupped hands, lead-came seams |

**Checks:**
1. **Same world** — one palette file, one outline rule, one shading rule, one proportion rule.
2. **Five different silhouettes** — anvil / triangle / spindle / T / bell. No two share a shape family,
   and each is distinguishable as a black shape with no colour at all.
3. **Colour separation** — steel-blue, charcoal-amber, charcoal-jade, leather-moss, lead-violet. The two
   charcoal characters (Ilva, Quill) are separated by silhouette and accent, which is the weakest pair
   in the set and the one to watch in review.
4. **Gameplay legibility** — Vale is the widest because he is the toughest; Quill is the shortest and
   only crouched one because she is the only genuinely fast one; Ilva leans but does not run because
   her speed is in the cast, not the body; Oriel is the heaviest-based because he is the slowest.
5. **No two concepts repeat** and no character is another with different hair.

---

## 6. Phase 5 — Gaps, conflicts, and the pilot

### Conflicts with the Art Bible — need your decision

| # | Conflict | Why it matters |
|---|---|---|
| **C1** | §5.1 makes the **held object** the hero's primary read in the top 20 px. Reading A removes it from four of five. | The whole art direction's recognition rule is being changed, not just a costume. Each design above proposes a replacement marker, but they are all *less* distinctive than a held object. |
| **C2** | §5.1's Swordsman row still specifies "kiếm thẳng hai lưỡi… chắn tay chữ thập" as his identity. | The Art Bible itself must be amended, or it and the sprites will disagree. That is an art-director edit, not mine. |
| **C3** | Quill's accent `#BFF3EC` is a near-**Chill** value, and §5.1 forbids Chill-like accents. It passes today only because the daggers carried it over a few pixels. | With the daggers gone the accent must grow to stay visible, which makes the conflict real. Either a new accent value or an explicit exception. |
| **C3 — RESOLVED 2026-11-15** | The user chose a new value, not an exception: Quill's accent becomes **bone white `#EFE6D2`**. | It is already in `tessera_master.gpl`, so C4 does not apply to it; it cannot be read as Chill, Frozen or any other status colour mid-battle; and it stays distinct from Vale's and Ilva's cream in practice because Quill wears it as a thin edge line on charcoal rather than as a cloth mass. `#BFF3EC` is retired from this character. |
| **C4** | The palette is **locked** — `export_sheets.py` refuses any opaque pixel outside `tessera_master.gpl`. | New outfits (Vale's cord wraps, Quill's hood, Oriel's lead seams) may need values that do not exist. Each needs an art-director entry with a recorded reason (§8.4). |

### Proposed Art Bible §5.1 amendment — drafted, NOT applied

`design/art/art-bible.md` is clean and I have not touched it: amending the art direction is the art
director's edit, not mine. Below is the exact replacement text, ready to apply on your word.

**Table 1 — `Dáng · vật đặc trưng (nửa trên)` column.** The four weapon rows become:

| Hero | Replacement text |
|---|---|
| Kiếm sĩ | Chữ nhật, HAI vai vuông to đối xứng; **hai cẳng tay giơ bắt chéo ngang ngực, quấn dây, BÀN TAY TRẦN mở** — dấu nhận dạng là đôi tay, không phải vật cầm. *Sửa 2026-11-14: bỏ hẳn kiếm và chắn tay chữ thập; không đeo vỏ kiếm (vỏ không kiếm đọc ra "mất kiếm").* |
| Sát thủ | Thoi dẹt, khom; cao ~34–36 px (thấp nhất nhóm); **mũ trùm nhọn góc cạnh nhất nhóm** làm dấu nhận dạng duy nhất ở 20 px trên; hai tay để thấp, sát người, xoè ngón, **không cầm gì**. *Sửa 2026-11-14: bỏ hai dao; không đeo bao dao rỗng.* |
| Thợ săn | Chữ T; **vành mũ rộng + 1 lông ngà** làm dấu nhận dạng, **cuộn dây vắt ngực** và cuộn cọc ở vai. *Sửa 2026-11-14: bỏ nỏ. Dây và cọc là DỤNG CỤ ĐẶT BẪY, không phải vũ khí.* |
| Giáo sĩ | Chuông đáy rộng; **voan** làm dấu nhận dạng, **hai tay nâng khum trước ngực** như đang đỡ một tấm kính. *Sửa 2026-11-14: bỏ gậy đầu ô vuông.* |

Pháp sư's row is unchanged — she already holds only the book.

**Table 2 — `Cử chỉ niệm` column.** Four rows describe a weapon swing and must become:

| Hero | Replacement text |
|---|---|
| Kiếm sĩ | A: hai tay thu về ngang ngực, lòng bàn tay hướng vào nhau. B: hai tay đẩy ra và tách rộng, ôm lấy chỗ khối hình thành. Hết cử chỉ về **thế thủ tay không**. *Sửa 2026-11-14: thay cho "kiếm rút ngang vai → chém ngang"; clip `draw` rút kiếm không còn nghĩa.* |
| Sát thủ | A: hai tay chéo thấp trước bụng. B: hai tay hất ra hai bên, ngón xoè, người hạ thấp thêm 1 px. |
| Thợ săn | A: một tay rút dây ở ngực. B: hai tay kéo căng dây ngang hông, như lên cò một cái bẫy. |
| Giáo sĩ | A: hai tay khum lại sát ngực. B: hai tay nâng lên ngang đầu, lòng bàn tay ngửa. |

**Table 3 — `Thức Tỉnh`.** Kiếm sĩ's "hai tay cầm kiếm ngang ngực, thủ rồi chém" and Thợ săn's "nỏ
chống đất" both name a weapon and need the same treatment. Giáo sĩ's "hai tay giữ gậy cắm xuống"
becomes "hai tay ấn xuống trước mặt, đầu cúi".

**The `draw` clip becomes meaningless, and the code already handles it.** `unit_layer.gd` has
`CLIP_DRAW` (`:107`), lists it among the known clips (`:231`) and plays it at match start — but only
`if sheet.has_clip(CLIP_DRAW)`, falling back to `CLIP_IDLE` otherwise (`:846`, `:995`). It exists in
`unit_kiem_si_sheet.json` today as "draw the sword into guard", which has no meaning without a sword.

So the new sheet simply **omits** `draw` and the code degrades to idle on its own — **no code change
needed**. Worth knowing because it is the opposite of what the weapon removal looked like it would
cost: this was the one place I expected a code edit and there is none.

**Also needs a line in §5.1's bullet list:** the existing "Bỏ:" list records what was rejected and why.
Add: *"Bỏ mọi vũ khí cầm tay của cả năm anh hùng (người dùng chốt 2026-11-14): sau Biến Cố sức mạnh chỉ
đi qua khối, nên một nhát kiếm vật lý không còn nghĩa. Dấu nhận dạng 20 px trên chuyển sang đôi tay,
mũ/voan và dụng cụ."*

### Insufficient data

- **No ages, no genders, no heights are recorded anywhere.** I have used "she" for Ilva and Quill and
  "he" for Vale, Bram and Oriel purely from the existing sprites' read; nothing in the data states it.
  If any of that is wrong, say so — it changes faces and proportions.
- **`second_wind` has no visual hook.** The other four passives suggest imagery; "heals after a won
  match" suggests nothing to draw, which is why Vale's design leans on stance rather than a motif.

### Pilot recommendation

**Vale, and an anchor only.**

He is the hardest case: the character most defined by the thing being removed, and the one whose
previous version already failed once (the v1 Cloud read). If a weapon-free Vale still reads as "the man
who was a knight" at 40 px, the other four are easier. Starting with Ilva would prove nothing — she
needs no change at all.

Sequence I propose: approve §0.2 → approve the Vale anchor on this page → **one** generation → judge →
only then the clip set, then the other three.

**Nothing here is approved, nothing is generated, nothing in `assets/art` is touched, no ID is changed,
and nothing is committed.**
