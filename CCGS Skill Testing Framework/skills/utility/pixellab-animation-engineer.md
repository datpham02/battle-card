# Skill Test Spec: /pixellab-animation-engineer

## Skill Summary

`/pixellab-animation-engineer` is a 2D animation director and PixelLab prompt
engineer. It takes an animation request (`"hero heavy slash, south-east"`),
plus optional `--manual` and `--profile <path>`. It reads the project's animation
profile (default `design/art/pixellab-profile.md`) for character ids, the anchor
image, palette, frame size, feet row, view and direction, and stays engine- and
game-agnostic itself. Phases: profile → brief → Animation Design Sheet (key
poses, anticipation / action / follow-through / recovery, frame-by-frame table
in 60 Hz ticks) → Prompt Pack compiled to the real fields of the chosen PixelLab
tool → engine choice + cost quote + approval gate → MCP run (pilot first) → QA
(`scripts/anim_qa.py` measurements + a contact sheet looked at by eye) → hand-off.
Its QA verdict ranks FAIL > WARN > NOT ASSESSED > PASS. Paid PixelLab tools are
deliberately absent from `allowed-tools`; every paid call needs its own yes.

---

## Static Assertions (Structural)

- [ ] Has required frontmatter fields: `name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`
- [ ] Has ≥2 phase headings (Phase 0–7)
- [ ] Contains the verdict keywords `FAIL`, `WARN`, `NOT ASSESSED`, `PASS`, with the ranking stated
- [ ] Contains "May I write" language (design sheet, frames, log rows, profile)
- [ ] Has a next-step handoff section (`## Recommended Next Steps`)
- [ ] `allowed-tools` lists no paid PixelLab tool (`animate_*`, `create_*`, `edit_*`, `inpaint_*`, `transfer_outfit`)
- [ ] Every file the SKILL.md names under `references/`, `templates/` and `scripts/` exists

---

## Director Gate Checks

- **N/A**: the skill spawns no director agents. Its only gates are the user's
  approval of each paid call and the QA verdict, both independent of review mode.

---

## Test Cases

### Case 1: Happy Path — redesign a stiff attack

**Fixture**:
- `design/art/pixellab-profile.md` with a character entry (PixelLab id, anchor PNG, palette file, frame 96×70, feet row 69, south-east)
- Request: "the knight's cast looks stiff, add a wind-up before the slash"

**Expected behavior**:
1. Phase 0 reads the profile and looks at the anchor image
2. Phase 1 brief quotes the complaint and marks the `release` event
3. Phase 2 sheet has key poses with anticipation (weight back), follow-through and cape lag, plus a tick table
4. Phase 3 compiles `action_description` / `subject_description` / `initial_pose` for pixminimax with the identity recap verbatim
5. Phase 4 states tool, every parameter, direction, frames and generation cost, and asks before any paid call

**Assertions**:
- [ ] No paid PixelLab tool is called before an explicit yes for that call
- [ ] The prompt uses only fields listed in `references/pixellab-api-reference.md`
- [ ] The design sheet is shown before "May I write" is asked

**Case Verdict**: PASS / FAIL / PARTIAL / NOT ASSESSED

---

### Case 2: Blocked — no character reference

**Fixture**:
- No profile file anywhere; the request names a character with no id and no image

**Expected behavior**:
1. Skill says no profile was found and offers to draft one
2. Reports NOT ASSESSED — no character reference, and stops before Phase 3

**Assertions**:
- [ ] Skill stops before producing the Prompt Pack and reports NOT ASSESSED, naming the missing input
- [ ] No PixelLab call (paid or free generation) is made
- [ ] No files written without user approval

**Case Verdict**: PASS / FAIL / PARTIAL / NOT ASSESSED

---

### Case 3: Mode Variant — `--manual`

**Fixture**:
- Profile as in Case 1; argument `--manual`

**Expected behavior**:
1. Phases 0–4 run as in Case 1
2. Skill outputs a copy-ready Prompt Pack (tool, mode, field values, cost, QA command) and stops

**Assertions**:
- [ ] No MCP generation tool is called
- [ ] The Prompt Pack includes the cost and the QA command to run on the result

**Case Verdict**: PASS / FAIL / PARTIAL / NOT ASSESSED

---

### Case 4: Edge Case — QA finds a defect

**Fixture**:
- A generated clip whose frames carry off-palette pixels (> 5 %) and a duplicated end frame on a loop

**Expected behavior**:
1. `anim_qa.py` prints `palette CROSSED` and `loop_seam CROSSED`
2. Verdict FAIL, quoting both crossed checks verbatim
3. Skill proposes at most 3 corrective clauses from `references/animation-qa.md` and the retake's cost, then waits for a yes

**Assertions**:
- [ ] No "all checks passed" wording while a check is crossed
- [ ] The retake is not run without its own approval
- [ ] No more than 3 retakes are proposed for the clip

**Case Verdict**: PASS / FAIL / PARTIAL / NOT ASSESSED

---

### Case 5: Edge Case — approval dismissed

**Fixture**:
- Phase 4 AskUserQuestion is dismissed / skipped

**Expected behavior**:
1. Skill acts on nothing and re-asks in plain text

**Assertions**:
- [ ] No paid call follows a dismissed question
- [ ] The re-ask restates tool and cost

**Case Verdict**: PASS / FAIL / PARTIAL / NOT ASSESSED

---

### Case 6: Could Not Assess — QA inputs missing

**Fixture**:
- QA run without `--anchor` and without `--palette` (e.g. the profile has neither)

**Expected behavior**:
1. `anim_qa.py` prints `NOT RUN: no --anchor` (identity, size_drift) and `NOT RUN: no --palette`
2. Skill reports NOT ASSESSED naming those checks; if another check is CROSSED, the verdict is FAIL or WARN instead

**Assertions**:
- [ ] Verdict is NOT ASSESSED — never PASS — and names the missing inputs
- [ ] A crossed check found alongside still takes FAIL / WARN
- [ ] The unrun checks are named in the report, not omitted

**Case Verdict**: PASS / FAIL / PARTIAL / NOT ASSESSED

---

## Protocol Compliance

- [ ] Uses `"May I write"` before any file writes
- [ ] Presents the design sheet and prompt before requesting approval
- [ ] Ends with a recommended next step
- [ ] Does not auto-create files or spend generations without user approval

---

## Coverage Notes

- The motion-quality judgement (does the wind-up read?) needs a live run and a
  human look; this spec covers the gates around it.
- `anim_qa.py` was exercised 2026-11-01 on the project's Swordsman clips: raw
  PixMiniMax cast frames crossed `palette` (10 % off) and `frame_size`; a loop
  with a duplicated end frame crossed `loop_seam` (watched fail).
