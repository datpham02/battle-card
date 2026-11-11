# State resolution and the next-step table

## 1. Resolve the target to a registry entry

```
python -X utf8 -I tools/asset-pipeline/asset_registry.py show <id>
```

Id forms: `unit.<entity>` (clips inside), `vfx.<cast|floor|status>.<pack>`,
`env.<region>.<file>`, `ui.<group>[.<name>]`, `card.<card_id>`, `other.<name>`.
A phrase resolves in this order (stop at the first hit, say which rule matched):

1. exact registry id;
2. `entity_id` (Knight / Kiếm sĩ / kiem_si → `unit.kiem_si`; use the display
   names in `design/assets/references/characters/*.md` §1 and
   `assets/data/characters.json`, `assets/data/cards.json`);
3. a clip name after a character ("Knight cast_forward" → `unit.kiem_si`, clip
   `cast_forward`);
4. a VFX pack dir or index key (`cast/index.json` `packs.*`, `floor/index.json`
   `packs.*`, `status/index.json`);
5. a backlog id (`backlog[]`) → the asset does not exist yet: `create` mode.

No match → ask the user which asset they mean, listing the closest ids.

## 2. State card

```
## State — <registry id> [/ <clip>]
| Field | Value | Source |
| type / tier / provider | … | registry |
| status / acceptance | installed / unknown | registry |
| attention | <text or none> | registry |
| production | <paths> (exist: yes/no) | registry + disk |
| anchor / reference | art_src/units/<id>/idle/0.png; design/assets/references/characters/<id>.md §2 | registry `reference` |
| frame / palette | 96x70, right; 8 colours | reference §3–§4 / clips.json |
| pixellab / pixelfx ids | character …; job … | registry |
| spec, last log row | design/assets/specs/…: "<last row verdict>" | spec |
| latest candidate | design/assets/candidates/<group>/<x>-v3-2026-11-10 — QA.md verdict … | registry `candidates` + disk |
| QA | pixelfx_check / fxc_check / anim_qa … or NOT ASSESSED | registry `qa`, candidate QA.md |
| last events | 2026-11-10 user_approved (cast_hand) … | registry `history` |
| missing | <fields null / unknown / contradicted by check> | registry + check |
```

Read the newest candidate folder by its `-v<N>-<date>` suffix; older folders
without the suffix are listed by the registry and read only when named.

## 3. Next valid step by state

| Situation (from the card) | Next step | Who performs it | Gate |
|---|---|---|---|
| `attention` set | put the question to the user verbatim, then record the answer (`set-acceptance`, `log-event note`, or a registry edit with "May I write") | orchestrator | user |
| latest candidate has `QA.md` verdict FAIL | corrective retake (max 3 per clip, per the skill) | `/pixellab-animation-engineer` or `pixelfx` skill or `fxc build` | paid: user yes |
| latest candidate has QA PASS / WARN and `acceptance: pending|unknown` | review package → user verdict | art-director prepares; user decides | user |
| candidate `accepted` | integrate | `references/integration.md` | overwrite check |
| `installed`, acceptance `unknown`, user now asks for a change | ask whether the current asset is accepted as the base (record) before generating from it | orchestrator | user |
| `installed` / `approved`, request is `revise` | new version: next `-v<N>`; the old stays; route by type | specialised skill | paid: user yes |
| unit without the clip the user names | `animation` from the anchor (Master Reference §2, §5, §6 contract) | `/pixellab-animation-engineer --mode animation` | paid: user yes |
| unit missing entirely (backlog `unit.*` or new) | `anchor` first (likeness check, pre-gen checklist), never clips before the anchor is approved | `/pixellab-animation-engineer --mode anchor` | user approves the still |
| `vfx` request | VFX decision rule (`docs/art/PIXELFX_INTEGRATION.md` §2), then the chosen route | pixelfx skill / fxc / workbench | paid only for the workbench's paid siblings |
| `audit` | `asset_registry.py check` + `/asset-audit <id>` + the type's checker (`export_sheets.py --check`, `fxc check`) | orchestrator + skill | none |
| registry `check` FAIL on this id | fix the record or the disk first; no generation | technical-artist | "May I write" |
| registry unreadable / entry absent for an installed file | **NOT ASSESSED** — run `bootstrap` (lists, never overwrites) and stop | orchestrator | "May I write" for `--add-missing` |

## 4. Continuity ("continue <phrase>")

1. Resolve the entry (§1). Read, in order: registry entry → Master Reference
   (§2 anchor, §6 contract, §8 lineage, §11 open points) → spec's last
   generation-log row → newest candidate folder (`metadata.json`, `QA.md`,
   `raw/`, `clean/`) → `production/session-state/active.md` lines that name the
   asset (quote them; they are notes, not approvals) → the latest history event.
2. Derive the step from §3. Say what was already produced and what it cost,
   and what is still waiting (QA not run, review not shown, user not asked).
3. Never regenerate what exists: a raw folder with the requested clip and no
   QA → run QA; QA done and no verdict → show the review; verdict recorded →
   integrate or retake. A new generation happens only when nothing usable
   exists or the user asked for a change.

Worked example (2026-11-11 state): "Continue Knight cast_forward" →
`unit.kiem_si` clip `cast_forward`: status approved (2026-11-08,
skill-checklist + clips.json), installed in the sheet, candidates
`design/assets/candidates/swordsman/cast-forward/raw`, no `attention` →
**nothing to continue**; offer `revise` (new version) or `audit`. No hero
has `cast_hand`. The user dropped every one on 2026-11-11, including Kiếm sĩ
PixMiniMax v3. Do not put it back. A hand cast on a weapon body holds idle.
