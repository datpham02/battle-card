# Animation QA

Two halves, both required: **measured** (`scripts/anim_qa.py`) and **looked at**
(contact sheet at game size and at 4×). Thresholds were adapted from
agent-sprite-forge and perfectpixel-studio (both MIT), then simplified.

## Verdict

Ranked **FAIL > WARN > NOT ASSESSED > PASS**; the worst that applies wins.
- **FAIL** — a defect that needs a retake (or a redesign).
- **WARN** — a defect that free cleanup fixes (palette snap, speck removal,
  re-seat, crop, alpha clean). Re-run QA after cleanup.
- **NOT ASSESSED** — a check could not run. The script prints `NOT RUN: <reason>`;
  a visual item you could not judge counts too. Name each. PASS is unreachable
  while any check is NOT RUN.
- **PASS** — every check ran, no threshold crossed, visual list clean.

Report every crossed threshold verbatim. Never write "all checks passed"
while one is crossed or not run.

## Measured checks (`anim_qa.py`)

The script prints numbers and which thresholds were crossed; it does not decide.
Defaults below; a profile may override them.

| Check | Measure | Crossed when | Usual verdict | Corrective clause / fix |
|---|---|---|---|---|
| frame count | frames found vs `--expect-frames` (± the source frame) | differs | FAIL if fewer, WARN if one extra source frame | set `frame_count` / `keep_first_frame` correctly |
| frame size | every frame W×H vs `--size` | any differs | WARN (crop) / FAIL if smaller than the pose | crop to the project frame; never scale |
| background | partial-alpha pixels (0 < a < 255); opaque pixels touching all four corners | > 0 partial / opaque corners | WARN | alpha clean; `no_background=true`; "only the character, transparent background" |
| palette | opaque pixels whose colour is not in the palette (exact), and how many of them are **far** (RGB distance > 48 from every palette colour) | > 0.5 % of opaque px off-palette | WARN when the off pixels are near shades (far ≤ 0.5 %: a snap fixes them; PixMiniMax drifts 10–15 % this way on every clip); FAIL when far colours > 0.5 % (a new colour family, e.g. a skin-coloured cape) or any reserved colour appears | snap (check the snapped frame: a near shade can land in the wrong family); clause "uses only the reference's colours; the <part> stays <colour>" |
| identity (colour) | 64-bin RGB histogram intersection of each frame vs the anchor | < 0.65 warn, < 0.45 error | WARN / FAIL | "same character as the reference: same <hair/armour/cape> colours and shapes" |
| size drift | opaque-area ratio vs the anchor | outside 0.72–1.32 | FAIL (unless the pose explains it: crouch, lunge) | "stays the same size; camera does not zoom" |
| outlier frame | opaque area vs the clip median | < 0.35× or > 2.75× | FAIL | usually a merged or broken frame: retake |
| edge clipping | opaque px within 1 px of the frame edge | > 24 px | WARN (bigger canvas / crop) | "the whole sword stays inside the frame" |
| foot contact | lowest opaque row per frame; planted clips also the x of the lowest pixels | row deviation > max(2 px, 10 % of height) or x drift > 2 px | FAIL for planted clips, info for jumps/steps | "feet stay planted on the same spot" / pin the end frame |
| jitter | frame-to-frame jump of the lower-body centroid vs the clip's mean step | a single step > 3× the mean and > 2 px | WARN / FAIL | "the body moves smoothly; no shaking" |
| near-duplicates | mean absolute difference between neighbours | ≤ 1.5 (0–255 scale) | WARN (drop or hold instead) | reduce `frame_count`; hold via ticks |
| loop seam | step last→first ÷ mean step (`wrap_ratio`) | > 2.0 (pop) or < 0.3 (duplicated end) | FAIL for cycles | "the last frame leads smoothly back into the first" / drop the duplicate |

## Visual checklist (contact sheet, 1× and 4×)

Answer each with yes / no / could not judge (→ NOT ASSESSED):
1. **Identity:** same face, hair, armour, cape, weapon shape as the anchor in every frame?
2. **Proportions:** head, torso, limbs, weapon the same size throughout (smear frame excepted)?
3. **Motion reads:** anticipation visible before the action? follow-through after it? key pose silhouette different from idle?
4. **Natural:** joints bend the right way; weight shifts before the limbs; no limb teleports between frames?
5. **Feet:** planted feet stay put; steps land where they should?
6. **Jitter:** no 1 px shimmer on still parts (unless a breathing idle)?
7. **Background / effects:** transparent; no baked glow, sparks, blood, speed lines in a reserved colour?
8. **Palette:** no new colour families (skin-coloured cape, coloured glow)?
9. **Loop:** for cycles, the seam is invisible when played at speed?
10. **Size / framing:** nothing cut off at the frame edge; same scale as the other clips of this character?
11. **The brief's own failure:** the user's original complaint (Phase 1) is gone?

## Corrective prompts, not blind re-rolls

1. List the failed checks.
2. Pick at most 3 clauses (table above) that target them; put them at the end
   of the motion text after "Most important:".
3. If the motion itself is wrong (wrong key poses), fix the design sheet first,
   then the prompt. If identity drifts but the motion is right, escalate the
   engine (skeleton-v3) instead of adding words.
4. Consider pinning poses: `custom_start_frame_*` / `end_frame_*` (single
   direction) when the start or end drifts.
5. Show the revised prompt and its cost; the retake needs its own yes. Max 3
   retakes per clip, then redesign or change engine (ask).

## Report format

```text
QA — <character>/<clip> (<tool>, job <id>, <N> frames)
Measured: <one line per check: value, threshold, crossed | ok | NOT RUN: reason>
Visual:   <1–11: yes/no/could not judge, with frame numbers>
Verdict:  FAIL | WARN | NOT ASSESSED | PASS — <the reasons, verbatim>
Next:     <cleanup steps | corrective clauses + cost | engine change>
```
