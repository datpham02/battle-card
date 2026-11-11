# design/assets/references — Master References and consistency rules

| File | Content |
|---|---|
| `characters/<id>.md` | one Master Reference per animated character (16 on 2026-11-11): identity, approved concept and anchor, facing and frame, palette, PixelLab configuration and style lineage, animation contract with per-clip status, visual constraints, generation lineage, versions, approval history, open points |
| `CHARACTER_CONSISTENCY.md` | the reusable rules every new image or clip must keep |

The registry (`design/assets/asset-registry.yaml`, entry `unit.<id>`) is the
source for status, acceptance, ids and paths; a Master Reference explains the
character and quotes the spec. When they disagree, fix the registry first, then
edit the reference by hand (they were generated once on 2026-11-11 from the
registry, `clips.json`, the sheet JSON and the specs; since then they are plain
Markdown — keep the section numbers so skills can find §2 anchor, §4 palette,
§5 PixelLab configuration, §6 animation contract, §7 constraints).

Characters (links from `reference:` in the registry):

| Tier | Ids |
|---|---|
| Heroes | `kiem_si`, `phap_su`, `sat_thu`, `tho_san`, `giao_si` |
| Normal enemies | `goblin_scout`, `goblin_archer`, `rootling`, `greycap_sporeling`, `mossbound_sentry`, `dire_wolf` |
| Elites | `ancient_root_sentinel`, `mistbriar_matron`, `wolf_alpha` |
| Bosses / wardens | `goblin_warlock`, `forest_witch` |

A new character gets its reference when its anchor is approved: copy the
section layout of an existing file of the same tier, fill only what the spec
and the registry record, and leave the rest `unknown`.
