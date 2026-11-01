class_name CutHudView
extends Node2D
## Cut UI (Story 008; piece casts since Story 024/026), drawn above the board and the field pieces, below
## the d-pad:
## (1) PREVIEW of the cast being placed on the target half: the piece ghost over the cells it covers
## (green = covers the boss's cell, red = misses, grey = off the board), a corner label with the
## forecast, cell count and expected damage, and (Story 028) the joined second piece and the total;
## (2) CONFIRM button ("Chốt"), dimmed with the swing countdown while a swing runs;
## (3) SKILL MENU panel: countdown bar + one button per skill with its lock reason;
## (4) SWING overlay: covered cells red with the countdown; (5) HIT / MISS marker after a swing;
## (6) the boss's QUEUED combo swing (Story 013) as a hatched lighter-red layer under its running swing;
## (7) Story 023: Rạn / Hàn stacks in the boss status strip, trait readouts under the player HP bar
## (reactor charges, fuse bar, frost aura), cracked / warned cells on the board and the phase banner;
## (8) Story 027: thorn zones (inward sawtooth, light tint) on both halves with a remaining-time bar, plus a short
## flash when a unit enters thorns (the seal zone was deleted 2026-11-01, ADR-0001 Phase 1 cleanup).
## It owns no game state: it reads CombatView and calls confirm_selection() / CutFlow.choose().
##
## Input is read in _input (like DPadView) and consumed, so HandInputController never sees a
## press on the confirm button or the menu panel. Dedup: with emulate_mouse_from_touch a touch
## also arrives as a mouse event, and with emulate_touch_from_mouse a click also arrives as a
## touch. Both emulated copies carry device == InputEvent.DEVICE_ID_EMULATION; they are
## consumed on a button but never act, so one physical press = one action.
## UI strings are translation keys (TEXT_* constants, assets/i18n/strings.csv) passed through tr().

const PREVIEW_TINT: Color = Color(1.0, 0.85, 0.2, 0.35)
const PREVIEW_OUTLINE: Color = Color(1.0, 0.85, 0.2, 0.95)
const PREVIEW_LINE: Color = Color(1.0, 1.0, 1.0, 0.95)
## Story 024 placement ghost: green when the piece covers the boss's cell, red when it does not.
const GHOST_HIT_TINT: Color = Color(0.2, 0.85, 0.3, 0.45)
const GHOST_HIT_OUTLINE: Color = Color(0.1, 0.65, 0.2, 0.95)
const GHOST_MISS_TINT: Color = Color(0.9, 0.2, 0.15, 0.4)
const GHOST_MISS_OUTLINE: Color = Color(0.85, 0.1, 0.1, 0.95)
const GHOST_OFF_FILL: Color = Color(0.7, 0.7, 0.75, 0.35)
const GHOST_OFF_OUTLINE: Color = Color(0.3, 0.3, 0.35, 0.5)
const TEXT_PLACE_HIT: String = "ui.hud.place_hit"
const TEXT_PLACE_MISS: String = "ui.hud.place_miss"
const TEXT_PLACE_OFF: String = "ui.hud.place_off"
## Story 028: join + featured shape.
const TEXT_CAST_TOTAL: String = "ui.hud.cast_total"
const TEXT_CAST_TOTAL_PREVIEW: String = "ui.hud.cast_total_preview"
const TEXT_FEATURED_CORNER: String = "ui.hud.featured_corner"
const TEXT_FEATURED_LABEL: String = "ui.hud.featured_label"
const TEXT_JOIN_CAP: String = "ui.hud.join_cap"
const TEXT_EFFECT_PIN: String = "ui.hud.pinned"
const TEXT_EFFECT_BURN: String = "keyword.burn"
const TEXT_EFFECT_FRAGILE: String = "keyword.fragile"
const TEXT_EFFECT_FROST: String = "keyword.frost"
## Story 027 zone effect names (effect id = StatusEffects.KIND_THORNS).
const TEXT_EFFECT_THORNS: String = "keyword.thorns"
const FEATURED_GOLD: Color = Color(1.0, 0.82, 0.15)
const FEATURED_GOLD_DARK: Color = Color(0.55, 0.42, 0.08)
const FEATURED_IDLE_FILL: Color = Color(0.62, 0.5, 0.2, 0.9)
const FEATURED_BACK: Color = Color(0.1, 0.09, 0.08, 0.8)
const FEATURED_GLOW_HZ: float = 2.0
const FEATURED_FONT_SIZE: int = 15
const FEATURED_ICON_PAD: float = 4.0
## Story 046: the featured tile's padding left of the label, its chamfer and the label's widest width, px.
const FEATURED_TILE_PAD: float = 10.0
const FEATURED_TILE_CUT: float = 8.0
const FEATURED_LABEL_MAX_W: float = 320.0
const FEATURED_LABEL_GAP: float = 8.0
const DETACH_MARK_RADIUS: float = 11.0
const DETACH_MARK_BACK: Color = Color(0.118, 0.106, 0.141, 0.95)
const TEXT_PLACE_HINT: String = "ui.hud.place_hint_short"
## Story 044 Part C: placement hint font (shrinks to fit two lines of the hint band, never below the minimum).
const PLACE_HINT_FONT_SIZE: int = 18
const PLACE_HINT_MIN_FONT_SIZE: int = 12
const PLACE_HINT_MAX_LINES: int = 2
## TD-016: one line on the card menu countdown bar while another piece can still join the cast.
const TEXT_JOIN_HINT: String = "ui.hud.join_hint"
## Overlays that cover the battle (paths under the main scene); the relic strip hides while one is shown.
const OVERLAY_PATHS: Array[String] = ["RewardView", "GameFlow/FateView", "GameFlow/EndingView"]
const TEXT_CANCEL: String = "ui.hud.cancel"
const TEXT_ROTATE: String = "ui.hud.rotate"
## Rotate button (Story 024): fill, glyph radius (share of the button's short side), how far the glyph
## sits above the centre (share of height), glyph line width, the label's top (share) and font size.
const ROTATE_BACK: Color = Color("2B2735", 0.95)
const ROTATE_GLYPH_RADIUS_RATIO: float = 0.2
const ROTATE_GLYPH_UP_RATIO: float = 0.14
const ROTATE_GLYPH_WIDTH: float = 9.0
const ROTATE_LABEL_TOP_RATIO: float = 0.62
const ROTATE_FONT_SIZE: int = 56
## Ring under the dragging finger.
const FINGER_RADIUS: float = 26.0
const FINGER_FILL: Color = Color(1.0, 1.0, 1.0, 0.18)
const FINGER_OUTLINE: Color = Color(1.0, 1.0, 1.0, 0.7)
const SWING_TINT: Color = Color(0.95, 0.12, 0.08, 0.5)
const SWING_OUTLINE: Color = Color(0.95, 0.12, 0.08)
const HIT_TINT: Color = Color(0.95, 0.12, 0.08, 0.6)
const HIT_TEXT: Color = Color(0.9, 0.1, 0.05)
const MISS_TINT: Color = Color(0.2, 0.8, 0.3, 0.5)
const MISS_TEXT: Color = Color(0.1, 0.6, 0.2)
const TEXT_DARK: Color = Color(0.15, 0.12, 0.1)
const TEXT_LIGHT: Color = Color(0.95, 0.9, 0.78)
const TEXT_OUTLINE_LIGHT: Color = Color(1.0, 1.0, 1.0, 0.9)
## Story 044 Part C (art bible 7.2): no dark control band; dark fill (Ink #1B1722 at 85 %) and a 2 px frame only
## under each button and the card menu.
const BUTTON_BACK: Color = Color(0.106, 0.09, 0.133, 0.85)
const BUTTON_FRAME_WIDTH: float = 2.0
const BUTTON_READY_BACK: Color = Color(0.25, 0.5, 0.3, 0.95)
const BUTTON_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const PANEL_BACK: Color = Color(0.106, 0.09, 0.133, 0.85)
const BAR_BACK: Color = HudSkin.HP_GROOVE
const BAR_FILL: Color = Color(0.72, 0.56, 0.2)
## Alpha multiplier of a locked / dimmed button.
const DIM_ALPHA: float = 0.4
const OUTLINE_WIDTH: float = 4.0
const CELL_OUTLINE_WIDTH: float = 3.0
const LINE_WIDTH: float = 4.0
const BIG_FONT_SIZE: int = 44
const FONT_SIZE: int = 26
const SMALL_FONT_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 30
## 2026-10-31: fill alpha of the skin panels (menu frame, labels, notices).
const SKIN_PANEL_ALPHA: float = 0.95
## Hit/miss text size as a share of cell height.
const FEEDBACK_FONT_RATIO: float = 0.4

## Interrupt flash (NGẮT) and the boss-swing label box.
const INTERRUPT_COLOR: Color = Color(1.0, 0.5, 0.0)
const INTERRUPT_TINT: Color = Color(1.0, 0.5, 0.0, 0.55)
const INTERRUPT_X_WIDTH: float = 8.0
const INTERRUPT_X_INSET_RATIO: float = 0.1
const LABEL_BIG_RATIO: float = 0.34
const LABEL_SMALL_RATIO: float = 0.2
const LABEL_PAD: float = 6.0
const LABEL_LINE_SPACING: float = 1.15

## Burning cells (Story 010) are painted on the floor by BurnPainter (Story 046 Part C); its BURN_FLAME_*
## constants also size the flame glyph of the rebirth icon here.

## Pin (Ghim): a thick grey ring with 4 short spokes around the pinned unit, "GHIM x.x s" above.
## Story 046 keyword chips: tile side, chamfer, gap, gap under the feet, time-bar height (px), icon
## scale (55 px icons) and how many chips a unit shows at most.
const CHIP_SIZE: float = 32.0
const CHIP_CUT: float = 6.0
const CHIP_GAP: float = 4.0
const CHIP_FEET_GAP: float = 4.0
const CHIP_BAR_HEIGHT: float = 2.0
const CHIP_ICON_SCALE: float = 0.5
const CHIP_MAX: int = 2
## 2026-10-31 (user, OSFE reference): HP plate under each unit's feet while the corner HP panels are off
## (combat.json hud.corner_panels): the current HP in HP_PLATE_FONT bold (light text player / Ivory boss) with
## HudSkin's ink outline only, centred in a HP_PLATE_HEIGHT-tall slot HP_PLATE_GAP px under the feet. No plate,
## border or bar (user 2026-10-31: "ko thích vạch % máu, xài con số như bên osfe"; "chỉ cần con số không, ko cần
## border"). The keyword chips sit under the slot.
const HP_PLATE_GAP: float = 2.0
const HP_PLATE_HEIGHT: float = 20.0
const HP_PLATE_MIN_W: float = 36.0
const HP_PLATE_PAD_X: float = 6.0
const HP_PLATE_FONT: int = 16
## 2026-10-31 (user: crossing a debuff zone seemed to do nothing): damage from the floor (burning cells, thorns, mire)
## pops a "-N" in the zone's colour above the unit: it rises DOT_POP_RISE px over DOT_POP_SEC and fades in its last
## DOT_POP_FADE share; a cut's own "HIT -N" label is untouched.
const DOT_POP_SEC: float = 0.7
const DOT_POP_RISE: float = 26.0
const DOT_POP_FADE: float = 0.4
const DOT_POP_FONT: int = 20
## Start of the pop above the feet (px) when the unit has no sprite sheet (a sprite: just over its frame, so the
## number reads over the head, clear of the status flames), and the sideways step between pops that overlap.
const DOT_POP_LIFT: float = 40.0
const DOT_POP_HEAD_GAP: float = 4.0
const DOT_POP_STAGGER: float = 10.0
const DOT_BURN_COLOR: Color = Color("FF7A1F")
const DOT_THORN_COLOR: Color = Color("D9B98A")
const DOT_MIRE_COLOR: Color = Color("A8B4C0")
const PIN_RING_COLOR: Color = Color(0.58, 0.58, 0.62, 0.95)
const PIN_RING_DARK: Color = Color(0.2, 0.2, 0.22, 0.95)
const PIN_TEXT_COLOR: Color = Color(0.25, 0.25, 0.28)
const PIN_RING_RADIUS_RATIO: float = 0.42
const PIN_RING_WIDTH: float = 7.0
const PIN_RING_POINTS: int = 48
const PIN_SPOKE_LENGTH_RATIO: float = 0.12
const PIN_SPOKE_WIDTH: float = 6.0
const PIN_FONT_RATIO: float = 0.22
const PIN_TEXT_GAP_RATIO: float = 0.04
## Feint flash (ĐÒN GIẢ): dashed grey outline per cell (never red) and a fading label.
const FEINT_COLOR: Color = Color(0.5, 0.5, 0.52)
const FEINT_TINT: Color = Color(0.6, 0.6, 0.6, 0.2)
const FEINT_DASH_LENGTH: float = 10.0
const FEINT_DASH_WIDTH: float = 4.0
const FEINT_INSET: float = 4.0
## Boss learning debug line (kept in release for now): small text under the boss HP bar,
## right-aligned to the bar's right edge, baseline offset below the HUD band's bottom.
const LEARNING_FONT_SIZE: int = 14
const LEARNING_COLOR: Color = HudSkin.TEXT_DIM
const LEARNING_BASELINE_OFFSET: float = 4.0
## Story 020 boss status readouts under the boss HP bar (ScreenLayout.hud_boss_status_rect):
## "Cháy ×N" in orange, "Ghim" in blue beside it; font and the gap between the two.
const STATUS_FONT_SIZE: int = 16
const STATUS_GAP: float = 16.0
const BURN_STACKS_COLOR: Color = Color(0.95, 0.5, 0.1)
const PINNED_COLOR: Color = Color(0.25, 0.5, 0.95)
## Story 020: the damage number of a hit that got the Ghim multiplier (same blue as "Ghim").
const PIN_BONUS_TEXT: Color = Color(0.2, 0.4, 0.95)
## Gap between a menu card name and its level suffix.
const LEVEL_SEPARATOR: String = " "

## Focus (Story 012). While the match is paused: a cool blue-grey tint over the board area (both
## halves), a soft vignette of a few bands plus a thin frame around the viewport, and the
## "TẬP TRUNG" countdown bar above the CONFIRM button. On cooldown the same place shows a greyed
## bar that fills up as the cooldown recovers; when READY and nothing is selected, a faint dot.
## 2026-10-31 (whole-game skin): Focus keeps a cool identity but in skin colours: an Ink dim over the board, a
## steel (#8FA3B8) frame and bar, the low-time end in Lattice gold (orange is Burn).
const FOCUS_BOARD_TINT: Color = Color("1B1722", 0.35)
const FOCUS_FRAME_COLOR: Color = Color("8FA3B8", 0.9)
const FOCUS_FRAME_WIDTH: float = 6.0
## Vignette: band count, band width (px), alpha of the outermost band (fades toward the centre).
const FOCUS_VIGNETTE_BANDS: int = 3
const FOCUS_VIGNETTE_BAND_WIDTH: float = 10.0
const FOCUS_VIGNETTE_ALPHA: float = 0.3
const FOCUS_BAR_BACK: Color = HudSkin.HP_GROOVE
const FOCUS_BAR_FILL: Color = Color("8FA3B8")
const FOCUS_BAR_LOW_FILL: Color = Color("FFD45C")
const FOCUS_BAR_OUTLINE: Color = HudSkin.MIST
const FOCUS_COOLDOWN_BACK: Color = HudSkin.HP_GROOVE
const FOCUS_COOLDOWN_FILL: Color = Color(0.5, 0.5, 0.53, 0.9)
const FOCUS_COOLDOWN_TEXT: Color = HudSkin.TEXT_DIM
const FOCUS_READY_DOT: Color = Color("8FA3B8", 0.7)
const FOCUS_READY_DOT_RADIUS: float = 6.0
const FOCUS_FONT_SIZE: int = 18
## The countdown fill turns orange when this share of the Focus time (or less) is left
## (a quarter: the last 1 s of a 4 s Focus).
const FOCUS_LOW_RATIO: float = 0.25
## "DỪNG" tag in the tag zone above the Cancel button (ScreenLayout.slot_side_left_rect), right-aligned
## (the FULL label is left-aligned in the same zone): size, pause glyph bar size and gap, inner padding.
const FOCUS_TAG_WIDTH: float = 78.0
const FOCUS_TAG_HEIGHT: float = 26.0
## Story 044 Part C: the tag keeps this gap to the zone's top and bottom (it shrinks to fit a short zone,
## so it never reaches the Cancel button below).
const FOCUS_TAG_V_GAP: float = 2.0
const FOCUS_TAG_GLYPH_WIDTH: float = 4.0
const FOCUS_TAG_GLYPH_HEIGHT: float = 12.0
const FOCUS_TAG_GLYPH_GAP: float = 3.0
const FOCUS_TAG_PAD: float = 6.0

const TEXT_FOCUS: String = "ui.hud.focus"
const TEXT_FOCUS_COOLDOWN: String = "ui.hud.focus_cooldown"
const TEXT_FOCUS_PAUSED_TAG: String = "ui.hud.focus_paused_tag"

const TEXT_PIN: String = "ui.hud.pin"
const TEXT_FEINT: String = "ui.hud.feint"
const TEXT_FEINT_NOTE: String = "ui.hud.feint_note"
const TEXT_LEARNING: String = "ui.hud.learning"

## Row burner warning (Story 014): while RowBurnerTrait announces a row, its cells get a faint
## amber tint, an amber outline that blinks between full and dim alpha (phase from a REAL-time
## accumulator fed in _process, so it blinks even while the simulation is frozen or slowed), a
## thin shrinking bar along the cell's TOP (the fire bar sits at the bottom) and a "SẮP CHÁY"
## tag at the top-right of the cells' bounding box. Amber (yellow-orange) and the blink keep it
## apart from the solid red boss swing and the hatched orange-red fire look that follows it.
const WARN_TINT: Color = Color(1.0, 0.7, 0.15, 0.18)
const WARN_OUTLINE: Color = Color(1.0, 0.68, 0.1, 0.95)
const WARN_BAR_BACK: Color = Color(0.35, 0.22, 0.02, 0.7)
const WARN_BAR_FILL: Color = Color(1.0, 0.75, 0.2)
const WARN_OUTLINE_WIDTH: float = 5.0
const WARN_BLINK_HZ: float = 4.0
const WARN_BLINK_DIM_ALPHA: float = 0.3
## Outline inset (px) and the top bar's height / side inset (shares of cell height).
const WARN_OUTLINE_INSET: float = 4.0
const WARN_BAR_HEIGHT_RATIO: float = 0.06
const WARN_BAR_INSET_RATIO: float = 0.08
const TEXT_ROW_WARNING: String = "ui.hud.row_warning"
## Trait param that holds the warning length (read from the trait, never a local number).
const WARN_SEC_PARAM: String = "warn_sec"

const TEXT_INTERRUPT: String = "ui.hud.interrupt"
const TEXT_INTERRUPT_BOSS: String = "ui.hud.interrupt_boss"
const TEXT_INTERRUPT_PLAYER: String = "ui.hud.interrupt_player"
const TEXT_CONFIRM: String = "ui.hud.cast"
const TEXT_CELLS: String = "ui.hud.cells"
const TEXT_DAMAGE: String = "ui.hud.damage"
const TEXT_NEED_CELLS: String = "ui.hud.need_cells"
const TEXT_NOT_IMPLEMENTED: String = "ui.hud.not_implemented"
## Story 033: the note under a locked curse card in the card menu.
const TEXT_CURSE_LOCKED: String = "ui.hud.curse_locked"
## Story 033: locked curse card look (purple border and tint, code-drawn padlock glyph).
const CURSE_OUTLINE: Color = Color(0.62, 0.32, 0.85)
const CURSE_BACK: Color = Color(0.22, 0.1, 0.3)
const CURSE_LOCK_COLOR: Color = Color(0.85, 0.65, 1.0)
const CURSE_LOCK_SIZE_RATIO: float = 0.3
const TEXT_COOLDOWN: String = "ui.hud.cooldown"
const TEXT_READY: String = "ui.hud.ready"
const TEXT_SWING: String = "ui.hud.swing"
const TEXT_HIT: String = "ui.hud.hit"
const TEXT_MISS: String = "ui.hud.miss"
const TEXT_DAMAGE_NUMBER: String = "ui.hud.damage_number"
## Story 037: "+%d" flash over the player's cell when the Priest's Prayer heals (a green pill that rises and fades).
const TEXT_HEAL_NUMBER: String = "ui.hud.heal_number"
const HEAL_TEXT: Color = HudSkin.HP_FILL
const HEAL_RISE_RATIO: float = 0.5
## Story 020: "Cháy ×%d" (burn stacks on the boss), "Ghim" (boss pinned), "+%d" after a menu card name.
const TEXT_BURN_STACKS: String = "ui.hud.burn_stacks"
## Horizontal padding inside a menu slot for the card name (Story 020: names carry "+N").
const MENU_NAME_PAD: float = 8.0
## Smallest font size the menu name shrinks to before clipping.
const MENU_NAME_MIN_FONT_SIZE: int = 18
const TEXT_PINNED: String = "ui.hud.pinned"
const TEXT_LEVEL_SUFFIX: String = "ui.card.level_suffix"

## Story 021 signature skill HUD. Physical key of the signature button (mirrors the DPadView dev keys;
## not in combat.json: Part 1 owns that file), button fonts, the ready pulse (cycles per second and
## brightness swing), border colour per signature id, border/timer sizes, banner duration / fade /
## font and the colours of the charge and timer bars.
## Fallback when the combat view has no config yet (the real key comes from combat.json signature_key).
const SIGNATURE_KEY_FALLBACK: Key = KEY_Q
const SIGNATURE_FONT_SIZE: int = 20
const SIGNATURE_SMALL_FONT_SIZE: int = 16
const SIGNATURE_MIN_FONT_SIZE: int = 12
const SIGNATURE_PULSE_HZ: float = 1.6
const SIGNATURE_PULSE_ALPHA: float = 0.35
const SIGNATURE_TEXT_PAD: float = 6.0
## Story 046: Awaken diamond half-diagonal, its line width and how much it shrinks while pressed, px.
const SIGNATURE_DIAMOND_R: float = 57.0
const SIGNATURE_DIAMOND_LINE: float = 3.0
const SIGNATURE_PRESS_SHRINK: float = 3.0
const SIGNATURE_COLORS: Dictionary = {
	"tram": Color(0.95, 0.15, 0.1),
	"thien_hoa": Color(1.0, 0.55, 0.1),
	"anh_bo": Color(0.2, 0.45, 1.0),
}
const SIGNATURE_DEFAULT_COLOR: Color = Color(0.95, 0.85, 0.3)
const SIGNATURE_BORDER_WIDTH: float = 6.0
const SIGNATURE_TIMER_BACK: Color = Color(0.1, 0.1, 0.12, 0.7)
const SIGNATURE_CHARGE_BACK: Color = Color(0.08, 0.08, 0.1, 0.85)
const SIGNATURE_CHARGE_FILL: Color = Color(0.95, 0.85, 0.3)
## Seconds the signature name stays in the middle of the board after activation, the last part
## of it fading out, the banner font and its dark backing alpha.
const SIGNATURE_BANNER_SEC: float = 0.8
const SIGNATURE_BANNER_FADE_SEC: float = 0.25
const SIGNATURE_BANNER_FONT_SIZE: int = 64
const SIGNATURE_BANNER_BACK_ALPHA: float = 0.45
const TEXT_SIGNATURE_READY: String = "ui.hud.signature_ready"
const TEXT_SIGNATURE_ACTIVE: String = "ui.hud.signature_active"
const TEXT_SIGNATURE_CHARGE: String = "ui.hud.formation_count"
const TEXT_FORMATION_COMPLETE: String = "ui.hud.formation_complete"
## Story 029 Phần D: "Hồi %d s" while the signature cooldown runs (seconds rounded up).
const TEXT_SIGNATURE_COOLDOWN: String = "ui.hud.signature_cooldown"
## Story 029 formation map on the enemy half: a lit cell gets a turquoise fill and border whose alpha
## scales from FORMATION_FAINT (almost faded) to 1.0 (just covered); below the warn ratio (combat.json
## formation_fade_warn_ratio) the border turns dashed and the whole cell blinks FORMATION_BLINK_HZ
## (real time, alternating FORMATION_WARN_HIGH / FORMATION_WARN_LOW strength). The completion flash is a white wash over the real enemy
## cells with alpha FORMATION_FLASH_ALPHA x the 1..0 flash value.
const FORMATION_FILL: Color = Color(0.1, 0.85, 0.8, 0.38)
const FORMATION_BORDER: Color = Color(0.45, 1.0, 0.95, 1.0)
const FORMATION_FAINT: float = 0.22
const FORMATION_BORDER_WIDTH: float = 4.0
const FORMATION_INSET: float = 3.0
const FORMATION_BLINK_HZ: float = 3.5
const FORMATION_WARN_HIGH: float = 0.6
const FORMATION_WARN_LOW: float = 0.3
const FORMATION_FLASH_ALPHA: float = 0.6
const FORMATION_DASH_LENGTH: float = 9.0

## Story 023 keyword stacks on the boss: "Rạn ×N" (purple) and "Hàn ×N" (ice blue) after "Cháy ×N" /
## "Ghim" in the boss status strip. The strip stays one line: its font shrinks down to
## STATUS_MIN_FONT_SIZE until every part fits the strip's width.
const FRAGILE_COLOR: Color = Color(0.62, 0.32, 0.88)
const FROST_COLOR: Color = Color(0.3, 0.68, 0.95)
const STATUS_MIN_FONT_SIZE: int = 11
const TEXT_FRAGILE_STACKS: String = "ui.hud.fragile_stacks"
const TEXT_FROST_STACKS: String = "ui.hud.frost_stacks"
## Story 023 trait readouts in ScreenLayout.hud_trait_status_rect (the strip under the PLAYER HP
## bar): step_reactor "Phản ứng N/M" (red once full), frost_aura "Khí sương" while it runs,
## fuse_cannon "Ngòi x.x s" followed by a thin fuse bar (red, text too, in the last FUSE_RED_SEC).
const TRAIT_TEXT_COLOR: Color = HudSkin.TEXT_DIM
const TRAIT_FULL_COLOR: Color = Color(0.9, 0.12, 0.08)
const FUSE_BAR_WIDTH: float = 120.0
const FUSE_BAR_HEIGHT: float = 8.0
const FUSE_BAR_BACK: Color = Color(0.25, 0.2, 0.15, 0.8)
const FUSE_BAR_FILL: Color = Color(0.95, 0.6, 0.1)
const FUSE_BAR_LOW_FILL: Color = Color(0.9, 0.12, 0.08)
const FUSE_RED_SEC: float = 3.0
const TEXT_REACTOR_CHARGES: String = "ui.hud.reactor_charges"
const TEXT_FUSE: String = "ui.hud.fuse"
const TEXT_FROST_AURA: String = "ui.hud.frost_aura"
## Story 023 board cells on the player's half: the cells a slam or the fuse blast is about to hit
## get a faint tint and a blinking ORANGE outline (the row warning's amber blink, hotter hue);
## cracked cells (slam) a dark fill with a jagged crack polyline and a short branch.
const TRAIT_WARN_OUTLINE: Color = Color(1.0, 0.5, 0.0, 0.95)
const TRAIT_WARN_TINT: Color = Color(1.0, 0.5, 0.0, 0.15)
const CRACK_TINT: Color = Color(0.12, 0.1, 0.08, 0.6)
const CRACK_LINE: Color = Color(0.05, 0.04, 0.03, 0.95)
const CRACK_LINE_WIDTH: float = 3.0
## Crack shape as shares of the cell rect (main line, then a branch off its second point).
const CRACK_POINTS: Array[Vector2] = [Vector2(0.2, 0.12), Vector2(0.45, 0.4), Vector2(0.36, 0.56), Vector2(0.6, 0.72), Vector2(0.78, 0.9)]
const CRACK_BRANCH: Array[Vector2] = [Vector2(0.45, 0.4), Vector2(0.68, 0.3), Vector2(0.86, 0.36)]
## Story 023 phase banner ("PHA 2", TraitHost.phase_changed): PHASE_BANNER_SEC in the middle of the
## board, same band / fade as the signature banner.
const PHASE_BANNER_SEC: float = 1.0
const PHASE_BANNER_COLOR: Color = Color(0.95, 0.25, 0.2)
const TEXT_PHASE_BANNER: String = "ui.hud.phase_banner"
## Story 034: "the deck does not fit this arena" notice, shown once at match start for
## PIECE_DECK_NOTICE_SEC (presentation timing) in the status row under the HP bars (clear of the
## phase banner in the middle of the board), when CombatView.is_piece_deck_fallback().
const TEXT_PIECE_DECK_FALLBACK: String = "ui.piece_deck.fallback"
const PIECE_DECK_NOTICE_SEC: float = 3.0
const PIECE_DECK_NOTICE_COLOR: Color = Color(1.0, 0.85, 0.35)
## Story 041: Odd Block look on the board (PieceDraw ODD_*): the odd edge around a placement ghost / committed odd
## piece (drawn UNDER the green / red cells so their tint and outline stay readable) and the sparkle mark on the top-left
## corner of an odd ghost / cast / boss telegraph (radius as a share of the cell's short side). The first-pickup hint:
## one line in the status row under the HP bars for ODD_HINT_SEC (after any piece-deck notice), "%s" = the odd name.
const ODD_GHOST_EDGE_WIDTH: float = 3.0
const ODD_CAST_MARK_RATIO: float = 0.14
const TEXT_ODD_HINT: String = "ui.hud.odd_hint"
const ODD_NAME_KEY: String = "piece.odd.name"
const ODD_HINT_SEC: float = 4.0
const ODD_HINT_MARK_RADIUS: float = 8.0
## Dark magenta back of the hint row (the odd light text reads on it over any board colour).
const ODD_HINT_BACK: Color = Color(0.22, 0.03, 0.2, 0.88)
## Story 027 zones (StatusEffects thorns, both halves). The player seal zone and its SEAL_* look were deleted with
## the Wall cards on 2026-11-01 (ADR-0001 Phase 1).
## THORNS = light bramble tint (the cell stays visibly walkable) + a ring of dark-green spikes along
## every edge pointing INWARD (THORN_TEETH per edge, depth THORN_DEPTH_RATIO of the shorter cell side)
## with a light edge line + a lime time bar along the top, below the spikes.
const THORN_TINT: Color = Color(0.55, 0.78, 0.2, 0.2)
const THORN_SPIKE: Color = Color(0.2, 0.45, 0.08, 0.95)
const THORN_EDGE: Color = Color(0.75, 0.95, 0.35, 0.95)
const THORN_EDGE_WIDTH: float = 2.0
const THORN_TEETH: int = 5
const THORN_DEPTH_RATIO: float = 0.17
const THORN_INSET: float = 2.0
const THORN_BAR_BACK: Color = Color(0.12, 0.22, 0.04, 0.75)
const THORN_BAR_FILL: Color = Color(0.72, 0.95, 0.25)
## Zone time bars: height and inset as fractions of the cell height (same scale as the burn bar).
const ZONE_BAR_HEIGHT_RATIO: float = 0.06
const ZONE_BAR_INSET_RATIO: float = 0.08
## Thorn entry flash (StatusEffects.thorn_entered): a red-white fill fading out over THORN_FLASH_SEC
## (presentation only).
const THORN_FLASH: Color = Color(1.0, 0.55, 0.45, 0.6)
const THORN_FLASH_SEC: float = 0.45
## Story 036 tile hazards (TileHazards through CombatView.get_hazards()), drawn under the Story 027 zones. Zones sit
## above units (TD-026), so a mire cell holding a unit or a piece is drawn see-through (MIRE_FILL_OCCUPIED).
## A mire cell that is a drop tile (cracking / hole / returning, StatusEffects) gets no mire at all: the drop-tile
## state drawn by FloorDynamicLayer under this view must stay readable (ADR-0001 Phase 1, 2026-11-01).
## MIRE = dark peat fill with rising bubble rings and NO border or spikes (unlike the sawtooth thorns and the solid
## violet seal); bubbles keep to the cell's edges so a unit in the middle stays readable.
const MIRE_FILL: Color = Color(0.16, 0.19, 0.09, 0.9)
const MIRE_FILL_OCCUPIED: Color = Color(0.16, 0.19, 0.09, 0.42)
const MIRE_BUBBLE: Color = Color(0.64, 0.74, 0.36, 0.95)
const MIRE_BUBBLE_WIDTH: float = 2.5
const MIRE_BUBBLE_POINTS: int = 16
## Bubble anchors: x, y as shares of the cell, z = radius as a share of the shorter cell side.
const MIRE_BUBBLES: Array[Vector3] = [Vector3(0.2, 0.8, 0.075), Vector3(0.8, 0.74, 0.06), Vector3(0.76, 0.3, 0.05), Vector3(0.24, 0.34, 0.055)]
## Each bubble rises this share of the cell side per loop, MIRE_BUBBLE_HZ loops per second, phase-shifted per bubble.
const MIRE_BUBBLE_RISE_RATIO: float = 0.08
const MIRE_BUBBLE_HZ: float = 0.6
const MIRE_BUBBLE_PHASE_STEP: float = 0.37
## SAND: filled = opaque sand block with dune ripples, a darker edge and the zone time bar; warning = a sand tint
## and a thick sand-coloured border blinking at SAND_WARN_BLINK_HZ (on the same blink clock as the row warning).
const SAND_FILL: Color = Color(0.87, 0.72, 0.42, 0.97)
const SAND_RIPPLE: Color = Color(0.64, 0.48, 0.24, 0.9)
const SAND_RIPPLE_WIDTH: float = 3.0
const SAND_RIPPLES: int = 3
const SAND_RIPPLE_POINTS: int = 9
const SAND_RIPPLE_AMP_RATIO: float = 0.05
const SAND_RIPPLE_TOP_RATIO: float = 0.3
const SAND_EDGE_WIDTH: float = 2.0
const SAND_BAR_BACK: Color = Color(0.35, 0.26, 0.1, 0.85)
const SAND_BAR_FILL: Color = Color(1.0, 0.94, 0.75)
const SAND_WARN_BORDER: Color = Color(0.96, 0.78, 0.38, 1.0)
const SAND_WARN_TINT: Color = Color(0.96, 0.78, 0.38, 0.24)
const SAND_WARN_WIDTH: float = 6.0
const SAND_WARN_INSET: float = 4.0
const SAND_WARN_BLINK_HZ: float = 5.0
## Sandstorm: a light sand haze over the player's half while the storm blows, and a draining bar in the trait line.
const STORM_HAZE: Color = Color(0.92, 0.76, 0.45, 0.14)
const STORM_COLOR: Color = Color(0.78, 0.55, 0.15)
const STORM_BAR_BACK: Color = Color(0.3, 0.22, 0.08, 0.8)
const STORM_BAR_FILL: Color = Color(0.95, 0.78, 0.4)
## Wind: a dark badge with an arrow at the RIGHT end of the trait status line (the HUD corner by the band centre),
## its label to the left. The badge side is the strip height clamped to [WIND_BADGE_MIN, WIND_BADGE_MAX].
const WIND_BADGE_MIN: float = 28.0
const WIND_BADGE_MAX: float = 40.0
const WIND_BACK: Color = Color(0.1, 0.09, 0.08, 0.85)
const WIND_ARROW: Color = Color(0.86, 0.95, 1.0)
const WIND_ARROW_WIDTH: float = 5.0
const WIND_ARROW_LENGTH_RATIO: float = 0.34
const WIND_HEAD_RATIO: float = 0.22
const WIND_TEXT: Color = Color(0.66, 0.8, 0.92)
## Region trait cues (W3 traits, read through has_method so the HUD runs before / without them): the hop shadow
## (dark ellipse + white ring closing as the warning runs out), the riposte cell (blinking crimson outline, tint,
## crosshair, bar) and the burrow surface circle (sand ring closing in).
const HOP_TRAIT_ID: String = "hop_skip"
const RIPOSTE_TRAIT_ID: String = "riposte"
const BURROW_TRAIT_ID: String = "burrow"
const STORM_TRAIT_ID: String = "sandstorm"
## Fallback warning totals (mirror schema.md defaults) used only as the bar / ring denominator when a trait lacks the param.
const HOP_WARN_FALLBACK_SEC: float = 0.4
const RIPOSTE_WARN_FALLBACK_SEC: float = 0.4
const SURFACE_WARN_FALLBACK_SEC: float = 0.5
const HOP_SHADOW: Color = Color(0.04, 0.04, 0.08, 0.55)
const HOP_RING: Color = Color(0.95, 0.95, 1.0, 0.95)
const HOP_COLOR: Color = Color(0.25, 0.3, 0.45)
const HOP_SHADOW_RX_RATIO: float = 0.36
const HOP_SHADOW_RY_RATIO: float = 0.15
const HOP_SHADOW_Y_RATIO: float = 0.66
const HOP_RING_RATIO: float = 0.44
const RING_WIDTH: float = 4.0
const RING_POINTS: int = 40
const RIPOSTE_COLOR: Color = Color(0.92, 0.12, 0.38)
const RIPOSTE_TINT: Color = Color(0.92, 0.12, 0.38, 0.3)
const RIPOSTE_CROSS_RATIO: float = 0.28
const RIPOSTE_BAR_BACK: Color = Color(0.3, 0.04, 0.12, 0.8)
const SURFACE_COLOR: Color = Color(0.9, 0.62, 0.18)
const SURFACE_TINT: Color = Color(0.9, 0.62, 0.18, 0.18)
const SURFACE_RING_RATIO: float = 0.46
const SURFACE_INNER_MIN: float = 0.25
const TEXT_WIND: String = "ui.hud.wind"
const TEXT_SANDSTORM: String = "ui.hud.sandstorm"
const TEXT_HOP: String = "ui.hud.hop"
const TEXT_RIPOSTE: String = "ui.hud.riposte"
const TEXT_SURFACE: String = "ui.hud.surface"
const TEXT_BURROWED: String = "ui.hud.burrowed"
## Story 039 (hellfire / sky isles) cues, all read through has_method / call so the HUD runs before and without W1 / W3:
## VENT = a fixed dark-red ember streak on every vent cell, brightening (and a blinking border) through the warning,
## flame orange with a pale border while erupting (the burning layer adds its own flame on top: the pale border and the
## streak are what tell a vent from a player's own burning cell). CRUMBLE = a crack that grows with crumble_progress on
## the cell being stood on, a big blinking crack in the warning. FALLEN = a dark void with a torn rock edge and a time bar
## (a plain missing cell is simply not drawn). ISLAND = a blinking border round the island about to fall. GUST = an
## arrow on the player's cell. SHROUD = a cloud over the boss's cell and grey hit shadows. REBIRTH = a flame badge and
## "1 life" text under the boss HP bar, a rising timer while it revives. BURN_EATER = a green "+N" rising off the boss.
const ISLAND_DROP_TRAIT_ID: String = "island_drop"
const GUST_TRAIT_ID: String = "gust"
const SHROUD_TRAIT_ID: String = "shroud"
const REBIRTH_TRAIT_ID: String = "rebirth"
const VENT_WARN_FALLBACK_SEC: float = 1.0
const ISLAND_WARN_FALLBACK_SEC: float = 1.2
const GUST_WARN_FALLBACK_SEC: float = 0.6
const REVIVE_FALLBACK_SEC: float = 1.5
const VENT_FILL: Color = Color(0.4, 0.04, 0.02, 0.4)
const VENT_STREAK: Color = Color(0.85, 0.2, 0.05, 0.85)
const VENT_HEAT_FILL: Color = Color(0.95, 0.3, 0.05, 0.62)
const VENT_HEAT_STREAK: Color = Color(1.0, 0.7, 0.15, 1.0)
const VENT_ERUPT_FILL: Color = Color(1.0, 0.42, 0.04, 0.68)
const VENT_ERUPT_BORDER: Color = Color(1.0, 0.92, 0.5, 1.0)
const VENT_WARN_BORDER: Color = Color(1.0, 0.45, 0.1, 1.0)
const VENT_STREAK_WIDTH: float = 3.0
const VENT_STREAK_POINTS: int = 7
const VENT_STREAK_AMP_RATIO: float = 0.1
const VENT_BORDER_WIDTH: float = 4.0
const CRUMBLE_TINT: Color = Color(0.25, 0.17, 0.08, 0.34)
const CRUMBLE_CRACK: Color = Color(0.08, 0.05, 0.03, 0.95)
const CRUMBLE_WARN_TINT: Color = Color(1.0, 0.6, 0.1, 0.3)
const CRUMBLE_WARN_BORDER: Color = Color(1.0, 0.6, 0.1, 1.0)
const CRUMBLE_CRACK_WIDTH: float = 3.5
const CRUMBLE_BIG_CRACK_WIDTH: float = 7.0
const FALLEN_VOID: Color = Color(0.02, 0.02, 0.06, 0.97)
const FALLEN_DEPTH: Color = Color(0.1, 0.12, 0.25, 0.9)
const FALLEN_EDGE: Color = Color(0.5, 0.36, 0.2, 1.0)
const FALLEN_EDGE_WIDTH: float = 3.0
const FALLEN_EDGE_STEPS: int = 6
const FALLEN_EDGE_DEPTH_RATIO: float = 0.07
const FALLEN_BAR_BACK: Color = Color(0.04, 0.05, 0.12, 0.9)
const FALLEN_BAR_FILL: Color = Color(0.55, 0.78, 1.0)
const ISLAND_TINT: Color = Color(1.0, 0.85, 0.3, 0.2)
const ISLAND_BORDER: Color = Color(1.0, 0.9, 0.35, 1.0)
const ISLAND_BORDER_WIDTH: float = 6.0
const ISLAND_BAR_BACK: Color = Color(0.35, 0.28, 0.04, 0.8)
const GUST_ARROW: Color = Color(0.82, 0.96, 1.0, 1.0)
const GUST_OUTLINE: Color = Color(0.1, 0.25, 0.4, 0.95)
const GUST_TINT: Color = Color(0.6, 0.85, 1.0, 0.22)
const GUST_BAR_BACK: Color = Color(0.08, 0.2, 0.32, 0.8)
const GUST_ARROW_WIDTH: float = 8.0
const GUST_ARROW_LENGTH_RATIO: float = 0.34
const GUST_HEAD_RATIO: float = 0.3
const GHOST_BLOCKED_TINT: Color = Color(0.62, 0.64, 0.7, 0.42)
const GHOST_BLOCKED_OUTLINE: Color = Color(0.42, 0.44, 0.5, 0.95)
const CLOUD_FILL: Color = Color(0.93, 0.95, 0.98, 0.82)
const CLOUD_EDGE: Color = Color(0.45, 0.48, 0.56, 0.9)
const CLOUD_COVER_ALPHA: float = 0.7
const CLOUD_TEXT: Color = Color(0.72, 0.76, 0.86)
## Cloud puffs: x, y as shares of the cloud box (width x width * 0.6), z = radius as a share of the box width.
const CLOUD_PUFFS: Array[Vector3] = [Vector3(0.25, 0.62, 0.2), Vector3(0.5, 0.4, 0.27), Vector3(0.75, 0.62, 0.2), Vector3(0.5, 0.68, 0.22)]
const CLOUD_EDGE_GROW: float = 2.0
const REBIRTH_COLOR: Color = Color(1.0, 0.62, 0.15)
const REBIRTH_BAR_BACK: Color = Color(0.3, 0.14, 0.02, 0.85)
const REBIRTH_ICON_MIN: float = 18.0
const REBIRTH_ICON_MAX: float = 30.0
const REVIVE_RING_RATIO: float = 0.46
const BOSS_HEAL_COLOR: Color = Color(0.15, 0.85, 0.3)
const BOSS_HEAL_BACK: Color = Color(0.0, 0.1, 0.02, 0.6)
## Burn ticks heal in small steps: they are summed for BOSS_HEAL_BATCH_SEC and shown as one number that lives BOSS_HEAL_SEC.
const BOSS_HEAL_BATCH_SEC: float = 0.4
const BOSS_HEAL_SEC: float = 1.0
const BOSS_HEAL_RISE_RATIO: float = 0.6
const TEXT_VENT_WARN: String = "ui.hud.vent_warn"
const TEXT_CRUMBLE: String = "ui.hud.crumble"
const TEXT_ISLAND_DROP: String = "ui.hud.island_drop"
const TEXT_GUST: String = "ui.hud.gust"
const TEXT_SHROUD: String = "ui.hud.shroud"
const TEXT_FORECAST_HIDDEN: String = "ui.hud.forecast_hidden"
const TEXT_REBIRTH_LIFE: String = "ui.hud.rebirth_life"
const TEXT_REVIVING: String = "ui.hud.reviving"

## Story 039: the TileHazards config cached for the vent warning total, the burn_eater heal numbers ([amount, seconds
## left] each), the heal being summed and the state the enemy_healed signal is connected to.
var _hz_cfg_owner: int = 0
var _hz_cfg: Dictionary = {}
var _boss_heals: Array = []
var _heal_pending: float = 0.0
var _heal_pending_t: float = 0.0
var _heal_state: CombatState = null

@export var combat_view_path: NodePath = NodePath("../CombatView")

var _combat: CombatView
## Real seconds since this view started: phase source of the row-warning blink.
var _blink_time: float = 0.0
## Story 046: longest pin time left seen per side during the current pin (the frozen chip's bar ratio).
var _pin_max: Dictionary = {}
## Story 041: seconds left of the first-pickup Odd Block hint and whether this match's hint was already started.
var _odd_hint_left: float = 0.0
var _odd_hint_started: bool = false
## Story 041 DEV-ONLY (DemoArgs odd_hint): true keeps the hint on screen (no countdown) for a capture.
var debug_odd_hint_hold: bool = false
## Story 021: the same node as _combat, untyped so the signature calls are dynamic (parse-safe).
var _sig: Object
## Story 021: the banner's signature id, translated name and seconds left.
var _banner_id: String = ""
var _banner_text: String = ""
var _banner_left: float = 0.0
## Story 023: the phase banner's text and seconds left, and the TraitHost whose phase_changed is connected.
var _phase_banner_text: String = ""
var _phase_banner_left: float = 0.0
var _phase_host: TraitHost = null
## Story 034: seconds left of the piece-deck fallback notice; checked once, when the match state exists.
var _piece_deck_notice_left: float = 0.0
var _piece_deck_notice_checked: bool = false
## Story 027: the StatusEffects whose thorn_entered is connected, and the entry flashes (cell -> seconds left;
## the halves never share a cell, so the cell alone is the key).
var _zone_status: StatusEffects = null
var _thorn_flashes: Dictionary = {}
## 2026-10-31: floor-damage pops, each {side, text, color, left}.
var _dot_pops: Array[Dictionary] = []
## The TileHazards whose mire_damage is connected (null until the battle has one).
var _pop_hazards: TileHazards = null


## Story 032: the in-match relic strip (display only) and demo-only relic ids used when CombatView has none.
var _relic_strip: RelicStrip = null
var _debug_relics: Array[String] = []


func _ready() -> void:
	_combat = get_node(combat_view_path) as CombatView
	_sig = _combat
	# Story 027: connect thorn_entered as early as possible (the status exists once CombatView is ready).
	if _combat != null:
		_connect_zones()
	if _combat != null and _combat.has_signal("signature_activated"):
		_combat.connect("signature_activated", _on_signature_activated)
	if _combat != null and _combat.has_signal("formation_completed"):
		_combat.connect("formation_completed", _on_formation_completed)
	# Story 032: display-only relic strip along the top edge (no input; icons flash when a relic acts).
	_relic_strip = RelicStrip.new()
	_relic_strip.interactive = false
	add_child(_relic_strip)


func _process(delta: float) -> void:
	_sync_relic_strip()
	_blink_time += delta
	_tick_boss_heals(delta)
	_banner_left = maxf(_banner_left - delta, 0.0)
	_phase_banner_left = maxf(_phase_banner_left - delta, 0.0)
	_piece_deck_notice_left = maxf(_piece_deck_notice_left - delta, 0.0)
	if _combat != null and not _piece_deck_notice_checked and _combat.get_state() != null:
		_piece_deck_notice_checked = true
		if _combat.is_piece_deck_fallback():
			_piece_deck_notice_left = PIECE_DECK_NOTICE_SEC
	# Story 041: the first-pickup hint starts once CombatView fired it and the piece-deck notice (same row) is gone.
	if not debug_odd_hint_hold:
		_odd_hint_left = maxf(_odd_hint_left - delta, 0.0)
	if _combat != null and not _odd_hint_started and _piece_deck_notice_left <= 0.0 and _combat.is_odd_hint_fired():
		_odd_hint_started = true
		_odd_hint_left = ODD_HINT_SEC
	_tick_dot_pops(delta)
	for cell: Vector2i in _thorn_flashes.keys():
		var left: float = float(_thorn_flashes[cell]) - delta
		if left <= 0.0:
			_thorn_flashes.erase(cell)
		else:
			_thorn_flashes[cell] = left
	if _combat != null:
		_connect_phase()
		_connect_zones()
		_connect_burn_heal()
	queue_redraw()


# Story 023: connects TraitHost.phase_changed once the battle has its host (CombatView builds it in
# its own _ready, so the sibling order must not matter); re-connects if the host is replaced.
func _connect_phase() -> void:
	var host: TraitHost = _combat.get_trait_host()
	if host == null or host == _phase_host:
		return
	if _phase_host != null and _phase_host.phase_changed.is_connected(_on_phase_changed):
		_phase_host.phase_changed.disconnect(_on_phase_changed)
	_phase_host = host
	host.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int) -> void:
	_phase_banner_text = tr(TEXT_PHASE_BANNER) % phase
	# Story 035: a boss_phases boss names its phase ("PHA 2 — <name>").
	var phases: BossPhasesTrait = null
	if _phase_host != null:
		phases = _phase_host.get_trait(BossPhasesTrait.ID) as BossPhasesTrait
	if phases != null and not phases.get_phase_name_key().is_empty():
		_phase_banner_text = "%s — %s" % [_phase_banner_text, tr(phases.get_phase_name_key())]
	_phase_banner_left = PHASE_BANNER_SEC


# Story 027: connects StatusEffects.thorn_entered once the battle has its status (and again if it is replaced).
func _connect_zones() -> void:
	_connect_mire()
	var status: StatusEffects = _combat.get_status()
	if status == null or status == _zone_status:
		return
	if _zone_status != null and _zone_status.thorn_entered.is_connected(_on_thorn_entered):
		_zone_status.thorn_entered.disconnect(_on_thorn_entered)
	if _zone_status != null and _zone_status.burn_hurt.is_connected(_on_burn_hurt):
		_zone_status.burn_hurt.disconnect(_on_burn_hurt)
	_zone_status = status
	_thorn_flashes.clear()
	_dot_pops.clear()
	status.thorn_entered.connect(_on_thorn_entered)
	status.burn_hurt.connect(_on_burn_hurt)


# 2026-10-31: connects TileHazards.mire_damage for the floor-damage pops once the battle has hazards.
func _connect_mire() -> void:
	var hazards: TileHazards = _combat.get_hazards() if _combat.has_method("get_hazards") else null
	if hazards == null or hazards == _pop_hazards:
		return
	if _pop_hazards != null and _pop_hazards.mire_damage.is_connected(_on_mire_damage):
		_pop_hazards.mire_damage.disconnect(_on_mire_damage)
	_pop_hazards = hazards
	hazards.mire_damage.connect(_on_mire_damage)


func _on_thorn_entered(side: int, cell: Vector2i, damage: float) -> void:
	_thorn_flashes[cell] = THORN_FLASH_SEC
	add_dot_pop(side, damage, DOT_THORN_COLOR)


func _on_burn_hurt(side: int, _cell: Vector2i, damage: float) -> void:
	add_dot_pop(side, damage, DOT_BURN_COLOR)


func _on_mire_damage(side: int, amount: float) -> void:
	add_dot_pop(side, amount, DOT_MIRE_COLOR)


## 2026-10-31: queues a floor-damage pop "-N" (N rounded up) of [param color] over the unit of [param side]. Ignores
## non-positive damage.
func add_dot_pop(side: int, damage: float, color: Color) -> void:
	if damage <= 0.0:
		return
	_dot_pops.append({"side": side, "text": "-%d" % ceili(damage), "color": color, "left": DOT_POP_SEC})


## The floor-damage pops still showing (read by tests).
func get_dot_pops() -> Array[Dictionary]:
	return _dot_pops


func _tick_dot_pops(delta: float) -> void:
	for i: int in range(_dot_pops.size() - 1, -1, -1):
		_dot_pops[i]["left"] = float(_dot_pops[i]["left"]) - delta
		if float(_dot_pops[i]["left"]) <= 0.0:
			_dot_pops.remove_at(i)


## Offset (px) of a floor-damage pop from the unit's feet after [param elapsed] seconds, [param index]-th of the pops
## showing on that unit: up DOT_POP_LIFT + the rise so far, and DOT_POP_STAGGER sideways per earlier pop. Pure.
static func dot_pop_offset(elapsed: float, index: int) -> Vector2:
	var t: float = clampf(elapsed / DOT_POP_SEC, 0.0, 1.0)
	return Vector2(DOT_POP_STAGGER * index, -DOT_POP_LIFT - DOT_POP_RISE * t)


# Screen px above the feet a floor-damage pop starts for [param side]: the sprite frame's height at the art scale
# plus DOT_POP_HEAD_GAP (over the head); DOT_POP_LIFT for a unit drawn without a sheet.
func _pop_lift(vp: Vector2, side: int) -> float:
	var canvas: BattleCanvas = _combat.get_battle_canvas()
	var units: UnitLayer = canvas.get_unit_layer() if canvas != null else null
	var sheet: SpriteSheet = units.get_sheet(side) if units != null else null
	if sheet == null or units.is_placeholder(side):
		return DOT_POP_LIFT
	return float(sheet.frame_size().y * ScreenLayout.art_scale(vp)) + DOT_POP_HEAD_GAP


## Alpha of a floor-damage pop with [param left] seconds to go: 1 until the last DOT_POP_FADE share, then linear to 0.
static func dot_pop_alpha(left: float) -> float:
	var fade_sec: float = DOT_POP_SEC * DOT_POP_FADE
	return clampf(left / fade_sec, 0.0, 1.0) if fade_sec > 0.0 else 1.0


func _draw_dot_pops(vp: Vector2) -> void:
	if _dot_pops.is_empty():
		return
	var state: CombatState = _combat.get_state()
	var count: Dictionary = {}
	for pop: Dictionary in _dot_pops:
		var side: int = int(pop["side"])
		var index: int = int(count.get(side, 0))
		count[side] = index + 1
		var feet: Vector2 = _unit_feet_screen(vp, side, state)
		var pos: Vector2 = feet + dot_pop_offset(DOT_POP_SEC - float(pop["left"]), index) + Vector2(0.0, DOT_POP_LIFT - _pop_lift(vp, side))
		var color: Color = pop["color"]
		HudSkin.text(self, pos - Vector2(40.0, 0.0), str(pop["text"]), DOT_POP_FONT, Color(color, dot_pop_alpha(float(pop["left"]))), HORIZONTAL_ALIGNMENT_CENTER, 80.0, true)


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if _combat == null or _combat.get_cut_flow() == null:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.physical_keycode == _signature_key():
				_try_activate_signature()
				get_viewport().set_input_as_handled()
			elif _piece_key(key.physical_keycode):
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		# Story 024 is touch-first: nothing here follows a hovering pointer. A drag is driven by
		# HandInputController (it owns the finger that picked the piece up).
		return
	var pos: Vector2
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			# Right click rotates the piece being placed.
			if event.device != InputEvent.DEVICE_ID_EMULATION and _combat.rotate_piece():
				get_viewport().set_input_as_handled()
			return
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		pos = touch.position
	else:
		return
	if _press_at(pos, event.device == InputEvent.DEVICE_ID_EMULATION):
		get_viewport().set_input_as_handled()


# Piece keys (Story 024): 1..3 select a bag slot, R rotates, Esc cancels placing / the card menu.
# Returns true when the key was used (consumed, so Esc does not also pause the run).
func _piece_key(code: Key) -> bool:
	if code == KEY_ESCAPE:
		return _combat.cancel_placement()
	if code == KEY_R:
		return _combat.rotate_piece()
	var index: int = int(code) - int(KEY_1)
	if index >= 0 and index < 9:
		return _combat.select_piece(index, false)
	return false


# Handles a press at [param pos]; returns true if it landed on this UI (consumed). Emulated
# duplicates are consumed but do nothing.
func _press_at(pos: Vector2, emulated: bool) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var flow: CutFlow = _combat.get_cut_flow()
	if _combat.is_placing() and ScreenLayout.rotate_button_rect(vp).has_point(pos):
		# Real touches only act (the emulated mouse copy of the first finger is swallowed). Any finger
		# may press it, including the left thumb while the right finger drags.
		if not emulated:
			_combat.rotate_piece()
		return true
	if (flow.is_menu_open() or _combat.is_placing()) and ScreenLayout.cancel_button_rect(vp).has_point(pos):
		if not emulated:
			_combat.cancel_placement()
		return true
	if flow.is_menu_open() and not _combat.is_placing():
		# Story 028: a tap on the attached second piece takes it off the cast (back to its bag slot).
		var tapped: Vector2i = ScreenLayout.cell_at(_combat.get_grid(), vp, pos)
		if tapped != BoardGrid.NO_CELL and _combat.get_cast_plan().piece_cells(1).has(tapped):
			if not emulated:
				_combat.detach_second_piece()
			return true
	if flow.is_menu_open():
		if not ScreenLayout.skill_menu_panel_rect(vp).has_point(pos):
			# Story 028: tap-fallback for the second piece (select its slot, tap the board / the ghost).
			return _board_press(pos, emulated)
		if not emulated:
			var order: Array[String] = flow.get_hand()
			var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, order.size())
			for i: int in rects.size():
				if rects[i].has_point(pos):
					flow.choose(order[i])
					break
		return true
	if _has_signature() and ScreenLayout.signature_button_rect(vp).has_point(pos):
		if not emulated:
			_try_activate_signature()
		return true
	if _combat.is_confirm_visible() and ScreenLayout.confirm_button_rect(vp).has_point(pos):
		if not emulated:
			_combat.confirm_placement()
		return true
	return _board_press(pos, emulated)


# Story 024: a left press on the board while PLACING. On the ghost (or on the cell it is already
# aimed at) it confirms; elsewhere (a finger tapping a new spot) it aims the ghost there.
func _board_press(pos: Vector2, emulated: bool) -> bool:
	if not _combat.is_placing():
		return false
	var cell: Vector2i = ScreenLayout.cell_at(_combat.get_grid(), get_viewport_rect().size, pos)
	if cell == BoardGrid.NO_CELL:
		return false
	if emulated or _combat.is_dragging():
		# A second finger landing on the board mid-drag must not confirm or re-aim: the drag belongs
		# to the first finger.
		return true
	var placement: PlacementController = _combat.get_placement()
	if placement.get_cells().has(cell) or placement.get_target() == cell:
		_combat.confirm_placement()
	else:
		_combat.aim_at_position(pos)
	return true


# --- Story 021: signature skill ------------------------------------------------


# True when CombatView exposes the signature interface and the character has a signature.
func _has_signature() -> bool:
	return _sig != null and _sig.has_method("get_signature") and _sig.get_signature() != null


func _signature_id() -> String:
	var sig: Variant = _sig.get_signature()
	return str(sig.get_id()) if sig != null else ""


func _on_signature_activated(id: String) -> void:
	_banner_id = id
	_banner_text = _sig.get_signature_name()
	_banner_left = SIGNATURE_BANNER_SEC


# Story 029: the map completed: the signature banner shows "Trận đồ hoàn thành: <signature name>".
func _on_formation_completed() -> void:
	if not _has_signature():
		return
	_banner_id = _signature_id()
	_banner_text = tr(TEXT_FORMATION_COMPLETE) % _sig.get_signature_name()
	_banner_left = SIGNATURE_BANNER_SEC


# Story 029: lit cells of the enemy half (under every other marker) and the completion flash.
func _draw_formation(vp: Vector2) -> void:
	var formation: FormationMap = _combat.get_formation() if _combat.has_method("get_formation") else null
	if formation == null:
		return
	var grid: BoardGrid = _combat.get_grid()
	var flash: float = _combat.get_formation_flash()
	if flash > 0.0 and not _vfx_ok("engraving_complete"):
		for cell: Vector2i in grid.enemy_cells():
			draw_rect(ScreenLayout.cell_rect(grid, vp, cell), Color(1.0, 1.0, 1.0, FORMATION_FLASH_ALPHA * flash))
	if _vfx_ok("engraving_lit"):
		return  # Story 048 F2: FloorDynamicLayer draws the lit engraving under the units
	var warn: float = _combat.get_config().formation_fade_warn_ratio
	var blink_on: bool = fmod(_blink_time * FORMATION_BLINK_HZ, 1.0) < 0.5
	for cell: Vector2i in formation.lit_cells():
		var fraction: float = formation.fraction_left(cell)
		var strength: float = lerpf(FORMATION_FAINT, 1.0, fraction)
		var warning: bool = fraction < warn
		if warning:
			# Flat and low (never the bright fresh look) so a still frame reads as "about to fade".
			strength = FORMATION_WARN_HIGH if blink_on else FORMATION_WARN_LOW
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell).grow(-FORMATION_INSET)
		draw_rect(rect, Color(FORMATION_FILL, FORMATION_FILL.a * strength))
		var border := Color(FORMATION_BORDER, strength)
		if warning:
			_draw_dashed_formation_rect(rect, border)
		else:
			draw_rect(rect, border, false, FORMATION_BORDER_WIDTH)


# Dashed rectangle in the formation colour (the feint dashes are grey and thinner).
func _draw_dashed_formation_rect(rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a).normalized()
		var d: float = 0.0
		while d < length:
			draw_line(a + dir * d, a + dir * minf(d + FORMATION_DASH_LENGTH, length), color, FORMATION_BORDER_WIDTH)
			d += FORMATION_DASH_LENGTH * 2.0


func _try_activate_signature() -> void:
	if _has_signature() and _sig.can_activate_signature():
		_sig.activate_signature()


# Coloured border + thin timer bar on the player's half while a signature runs.
func _draw_signature_effect(vp: Vector2) -> void:
	if not _has_signature() or not _sig.is_signature_active():
		return
	var color: Color = SIGNATURE_COLORS.get(_signature_id(), SIGNATURE_DEFAULT_COLOR)
	var grid: BoardGrid = _combat.get_grid()
	var half: Rect2 = ScreenLayout.player_half_rect(grid, vp)
	draw_rect(half.grow(-SIGNATURE_BORDER_WIDTH * 0.5), color, false, SIGNATURE_BORDER_WIDTH)
	var duration: float = _sig.get_signature_duration()
	var ratio: float = 0.0 if duration <= 0.0 else clampf(_sig.get_signature_time_left() / duration, 0.0, 1.0)
	var bar: Rect2 = ScreenLayout.signature_timer_rect(grid, vp)
	draw_rect(bar, SIGNATURE_TIMER_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color)


# The signature name, large in the middle of the board, for SIGNATURE_BANNER_SEC with a short fade.
func _draw_signature_banner(vp: Vector2) -> void:
	if _banner_left <= 0.0 or _banner_text.is_empty():
		return
	_draw_board_banner(vp, _banner_text, SIGNATURE_COLORS.get(_banner_id, SIGNATURE_DEFAULT_COLOR), _banner_left)


# Story 023: "PHA 2" in the same band for PHASE_BANNER_SEC after TraitHost.phase_changed.
func _draw_phase_banner(vp: Vector2) -> void:
	if _phase_banner_left <= 0.0 or _phase_banner_text.is_empty():
		return
	_draw_board_banner(vp, _phase_banner_text, PHASE_BANNER_COLOR, _phase_banner_left)


# One big line of [param text] on a dark band across the board's middle; fades out over the last
# SIGNATURE_BANNER_FADE_SEC of [param left].
func _draw_board_banner(vp: Vector2, text: String, color: Color, left: float) -> void:
	var alpha: float = clampf(left / SIGNATURE_BANNER_FADE_SEC, 0.0, 1.0)
	var band: Rect2 = ScreenLayout.signature_banner_rect(_combat.get_grid(), vp)
	# 2026-10-31: a Đá Đêm band with Sương rules top and bottom, the name in outlined Bold.
	draw_rect(band, Color(HudSkin.NIGHT_STONE, 0.85 * alpha))
	draw_rect(Rect2(band.position, Vector2(band.size.x, 2.0)), Color(HudSkin.MIST, alpha))
	draw_rect(Rect2(band.position.x, band.end.y - 2.0, band.size.x, 2.0), Color(HudSkin.MIST, alpha))
	var size: int = _fit_signature_font(text, band.size.x, SIGNATURE_BANNER_FONT_SIZE)
	_draw_centered(band, text, size, Color(color.lightened(0.35), alpha))


# Story 046 Part B: the Awaken button is a Đá Đêm diamond (radius SIGNATURE_DIAMOND_R, Ánh Lưới 3 px line)
# centred in ScreenLayout.signature_rect with the "awakening" icon, and the status line under it: "n/N"
# (TEXT_DIM while charging, Ánh Lưới when ready), "Hồi N s" during the cooldown, READY / ACTIVE. Ready and
# usable = a pulsing light fill; active = the signature colour fill with the time left as a thin bar under
# the text; dimmed whenever it cannot be pressed (menu / Focus / pause). Rect and hit test are unchanged.
func _draw_signature_button(vp: Vector2) -> void:
	if not _has_signature():
		return
	var rect: Rect2 = ScreenLayout.signature_button_rect(vp)
	var active: bool = _sig.is_signature_active()
	var is_ready: bool = _sig.is_signature_ready()
	var usable: bool = _sig.can_activate_signature()
	var pressed: bool = usable and UiButtons.is_pressed_at(self, rect)
	var alpha: float = 1.0 if (usable or active) else UiButtons.DIM_ALPHA + 0.2
	var center: Vector2 = rect.get_center()
	var r: float = SIGNATURE_DIAMOND_R - (SIGNATURE_PRESS_SHRINK if pressed else 0.0)
	var fill: Color = HudSkin.NIGHT_STONE
	if active:
		fill = HudSkin.NIGHT_STONE.lerp(SIGNATURE_COLORS.get(_signature_id(), SIGNATURE_DEFAULT_COLOR), 0.45)
	HudSkin.diamond(self, center, r, Color(fill, alpha), Color(HudSkin.GRID_LIGHT, alpha), SIGNATURE_DIAMOND_LINE)
	if is_ready and usable and not active:
		var pulse: float = 0.5 + 0.5 * sin(_blink_time * TAU * SIGNATURE_PULSE_HZ)
		HudSkin.diamond(self, center, r - SIGNATURE_DIAMOND_LINE, Color(HudSkin.GRID_LIGHT, SIGNATURE_PULSE_ALPHA * pulse), Color(0, 0, 0, 0), 0.0)
	HudSkin.icon(self, "awakening", center, 1.0, Color(1.0, 1.0, 1.0, alpha))
	var formation: FormationMap = _combat.get_formation()
	var status: String = ""
	var color: Color = HudSkin.TEXT_DIM
	var cooldown_left: float = _sig.get_signature_cooldown_left() if _sig.has_method("get_signature_cooldown_left") else 0.0
	if cooldown_left > 0.0:
		status = tr(TEXT_SIGNATURE_COOLDOWN) % ceili(cooldown_left)
	elif formation != null:
		status = "%d/%d" % [formation.lit_count(), formation.total()]
	if active:
		status = tr(TEXT_SIGNATURE_ACTIVE)
		color = HudSkin.TEXT
	elif is_ready:
		status = tr(TEXT_SIGNATURE_READY)
		color = HudSkin.GRID_LIGHT
	var text_w: float = SIGNATURE_DIAMOND_R * 2.0 + SIGNATURE_TEXT_PAD * 4.0
	var base_y: float = center.y + SIGNATURE_DIAMOND_R + SIGNATURE_SMALL_FONT_SIZE * 0.5
	HudSkin.text(self, Vector2(center.x - text_w * 0.5, base_y), status,
		_fit_skin_font(status, text_w, SIGNATURE_SMALL_FONT_SIZE), Color(color, alpha), HORIZONTAL_ALIGNMENT_CENTER, text_w, true)
	if active:
		var duration: float = _sig.get_signature_duration()
		var ratio: float = 0.0 if duration <= 0.0 else clampf(_sig.get_signature_time_left() / duration, 0.0, 1.0)
		var bar := Rect2(center.x - SIGNATURE_DIAMOND_R * 0.6, base_y + 4.0, SIGNATURE_DIAMOND_R * 1.2, 3.0)
		draw_rect(bar, SIGNATURE_CHARGE_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), SIGNATURE_COLORS.get(_signature_id(), SIGNATURE_DEFAULT_COLOR))


# Story 046: as _fit_signature_font, measured in the HudSkin Bold font.
func _fit_skin_font(text: String, width: float, size: int) -> int:
	var fitted: int = size
	while fitted > SIGNATURE_MIN_FONT_SIZE and HudSkin.text_width(text, fitted, true) > width:
		fitted -= 1
	return fitted


# Largest font size <= [param size] (never below SIGNATURE_MIN_FONT_SIZE) at which [param text] fits [param width].
func _fit_signature_font(text: String, width: float, size: int) -> int:
	var fitted: int = size
	while fitted > SIGNATURE_MIN_FONT_SIZE and HudSkin.text_width(text, fitted, true) > width:
		fitted -= 1
	return fitted


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if _combat == null or _combat.get_cut_flow() == null or _combat.get_state() == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	# Focus overlay first: the preview, markers and buttons stay fully readable above it.
	_draw_focus_overlay(vp)
	_draw_formation(vp)
	# Story 036: mire and sand under the Story 027 zones (and so under every telegraph below).
	_draw_hazards(vp)
	# Story 027: zones under every telegraph / label / marker below, so a swing over a zone stays readable.
	_draw_zones(vp)
	_draw_featured_icon(vp)
	_draw_preview(vp)
	_draw_swing(vp)
	_draw_boss_queued_swing(vp)
	_draw_boss_swing(vp)
	_draw_feedback(vp)
	_draw_boss_feedback(vp)
	_draw_heal_flash(vp)
	_draw_boss_heals(vp)
	_draw_row_warning(vp)
	_draw_trait_cells(vp)
	_draw_hazard_traits(vp)
	_draw_vent_eruptions(vp)
	_draw_interrupt(vp)
	_draw_feint(vp)
	_draw_hp_plates(vp)
	_draw_pins(vp)
	_draw_dot_pops(vp)
	_draw_confirm(vp)
	_draw_cancel(vp)
	_draw_rotate(vp)
	_draw_focus_bar(vp)
	_draw_focus_tag(vp)
	_draw_signature_effect(vp)
	_draw_signature_button(vp)
	_draw_menu(vp)
	_draw_signature_banner(vp)
	_draw_phase_banner(vp)
	if _combat.debug_overlay:
		_draw_learning_debug(vp)
	_draw_boss_status(vp)
	_draw_rebirth(vp)
	_draw_trait_status(vp)
	_draw_wind_badge(vp)
	_draw_piece_deck_notice(vp)
	_draw_odd_hint(vp)


## Story 041: true while the first-pickup Odd Block hint is on screen (tests / captures).
func is_odd_hint_visible() -> bool:
	return _odd_hint_left > 0.0


# Story 041: the first-pickup hint in the status row (as the piece-deck notice): dark back, a sparkle mark, then the
# line in the odd light colour, fading out over the banner fade time.
func _draw_odd_hint(vp: Vector2) -> void:
	if _odd_hint_left <= 0.0:
		return
	var left: Rect2 = ScreenLayout.hud_trait_status_rect(vp)
	var right: Rect2 = ScreenLayout.hud_boss_status_rect(vp)
	var row := Rect2(left.position, Vector2(right.end.x - left.position.x, left.size.y))
	var alpha: float = clampf(_odd_hint_left / SIGNATURE_BANNER_FADE_SEC, 0.0, 1.0)
	_skin_panel(row, PieceDraw.ODD_MARK_LIGHT, alpha, ODD_HINT_BACK, ODD_HINT_BACK.a)
	var text: String = tr(TEXT_ODD_HINT) % tr(ODD_NAME_KEY)
	var room: float = row.size.x - ODD_HINT_MARK_RADIUS * 3.0
	var size: int = STATUS_FONT_SIZE
	while size > STATUS_MIN_FONT_SIZE and HudSkin.text_width(text, size) > room:
		size -= 1
	var width: float = HudSkin.text_width(text, size)
	var start: float = row.get_center().x - (width + ODD_HINT_MARK_RADIUS * 3.0) * 0.5
	PieceDraw.draw_odd_mark(self, Vector2(start + ODD_HINT_MARK_RADIUS, row.get_center().y), ODD_HINT_MARK_RADIUS)
	HudSkin.text(self, Vector2(start + ODD_HINT_MARK_RADIUS * 3.0, row.get_center().y + size * 0.35), text, size, Color(PieceDraw.ODD_MARK_LIGHT, alpha))


# Story 041: the odd edge along the outer border of board [param cells] (call it BEFORE drawing their green / red
# cells, so the tint and outline stay on top inside and the magenta shows around them).
func _draw_odd_edge_cells(vp: Vector2, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	PieceDraw.draw_odd_edge(self, cells, ScreenLayout.cell_rect(grid, vp, Vector2i.ZERO).position, ScreenLayout.cell_size(grid, vp), ODD_GHOST_EDGE_WIDTH)


# Story 041: the odd sparkle mark inside the top-left corner of the top-most (then left-most) cell of board [param cells],
# so it always sits on the shape itself.
func _draw_odd_corner_mark(vp: Vector2, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var first: Vector2i = cells[0]
	for cell: Vector2i in cells:
		if cell.y < first.y or (cell.y == first.y and cell.x < first.x):
			first = cell
	var unit: Vector2 = ScreenLayout.cell_size(grid, vp)
	var radius: float = minf(unit.x, unit.y) * ODD_CAST_MARK_RATIO
	PieceDraw.draw_odd_mark(self, ScreenLayout.cell_rect(grid, vp, first).position + Vector2(radius, radius) * 1.3, radius)


# Story 041: the shape ids of the boss's RUNNING swing (its combo labels while the combo swing runs).
func _boss_swing_labels(boss: BossController, actor: CutActor) -> Array:
	var last: Dictionary = boss.get_last_cut()
	if actor.get_skill_id() == BossController.COMBO_SKILL and last.has("combo"):
		return (last["combo"] as Dictionary).get("labels", []) as Array
	return last.get("labels", []) as Array


## Story 034: true while the piece-deck fallback notice is on screen (tests / captures).
func is_piece_deck_notice_visible() -> bool:
	return _piece_deck_notice_left > 0.0


# Story 034: one line across the status row under both HP bars (trait strip left edge to boss strip
# right edge) on a dark back, fading over the banner fade time; drawn last so it stays readable.
func _draw_piece_deck_notice(vp: Vector2) -> void:
	if _piece_deck_notice_left <= 0.0:
		return
	var left: Rect2 = ScreenLayout.hud_trait_status_rect(vp)
	var right: Rect2 = ScreenLayout.hud_boss_status_rect(vp)
	var row := Rect2(left.position, Vector2(right.end.x - left.position.x, left.size.y))
	var alpha: float = clampf(_piece_deck_notice_left / SIGNATURE_BANNER_FADE_SEC, 0.0, 1.0)
	_skin_panel(row, HudSkin.MIST, alpha)
	var text: String = tr(TEXT_PIECE_DECK_FALLBACK)
	var size: int = STATUS_FONT_SIZE
	while size > STATUS_MIN_FONT_SIZE and HudSkin.text_width(text, size) > row.size.x:
		size -= 1
	HudSkin.text(self, Vector2(row.position.x, row.get_center().y + size * 0.35), text, size, Color(PIECE_DECK_NOTICE_COLOR, alpha), HORIZONTAL_ALIGNMENT_CENTER, row.size.x)


# --- Story 012: Focus (pause while connecting points) ---------------------------


# Board tint, vignette bands and frame while Focus pauses the match. Nothing otherwise.
func _draw_focus_overlay(vp: Vector2) -> void:
	var focus: FocusController = _combat.get_focus()
	if focus == null or not focus.is_active():
		return
	draw_rect(ScreenLayout.board_area_rect(vp), FOCUS_BOARD_TINT)
	var frame := Rect2(Vector2.ZERO, vp)
	for i: int in FOCUS_VIGNETTE_BANDS:
		var alpha: float = FOCUS_VIGNETTE_ALPHA * float(FOCUS_VIGNETTE_BANDS - i) / float(FOCUS_VIGNETTE_BANDS)
		var inset: float = FOCUS_FRAME_WIDTH + FOCUS_VIGNETTE_BAND_WIDTH * (i + 0.5)
		draw_rect(frame.grow(-inset), Color(FOCUS_FRAME_COLOR, alpha), false, FOCUS_VIGNETTE_BAND_WIDTH)
	draw_rect(frame.grow(-FOCUS_FRAME_WIDTH * 0.5), FOCUS_FRAME_COLOR, false, FOCUS_FRAME_WIDTH)


# Above the CONFIRM button: ACTIVE = "TẬP TRUNG x.x s" countdown (orange in the last quarter);
# COOLDOWN = greyed bar filling up with "Tập trung còn N s"; READY with nothing selected = a
# faint dot at the bar's left. Hidden while the skill menu covers the strip.
func _draw_focus_bar(vp: Vector2) -> void:
	var focus: FocusController = _combat.get_focus()
	if focus == null or _combat.get_cut_flow().is_menu_open():
		return
	var bar: Rect2 = ScreenLayout.focus_bar_rect(vp)
	if focus.is_active():
		var max_sec: float = focus.get_max_sec()
		var ratio: float = 0.0 if max_sec <= 0.0 else clampf(focus.get_time_left() / max_sec, 0.0, 1.0)
		var fill: Color = FOCUS_BAR_LOW_FILL if ratio <= FOCUS_LOW_RATIO else FOCUS_BAR_FILL
		_skin_bar(bar, ratio, fill, FOCUS_BAR_BACK)
		draw_rect(bar, FOCUS_BAR_OUTLINE, false, 1.5)
		_draw_centered(bar, tr(TEXT_FOCUS) % focus.get_time_left(), FOCUS_FONT_SIZE, HudSkin.TEXT)
	elif focus.is_on_cooldown():
		var total: float = focus.get_cooldown_sec()
		var recovered: float = 1.0 if total <= 0.0 else clampf(1.0 - focus.get_cooldown_left() / total, 0.0, 1.0)
		_skin_bar(bar, recovered, FOCUS_COOLDOWN_FILL, FOCUS_COOLDOWN_BACK)
		draw_rect(bar, FOCUS_BAR_OUTLINE, false, 1.5)
		_draw_centered(bar, tr(TEXT_FOCUS_COOLDOWN) % ceili(focus.get_cooldown_left()), FOCUS_FONT_SIZE, FOCUS_COOLDOWN_TEXT)
	elif not _combat.is_confirm_visible():
		var state: CombatState = _combat.get_state()
		if state.is_player_dead() or state.is_enemy_dead():
			return
		draw_circle(Vector2(bar.position.x + FOCUS_READY_DOT_RADIUS, bar.get_center().y), FOCUS_READY_DOT_RADIUS, FOCUS_READY_DOT)


# "DỪNG" tag with a pause glyph while Focus is ACTIVE: right end of the tag zone above the Cancel button
# (the FULL label takes the left end), next to slot T3, so the eye gets it near the thumb too.
func _draw_focus_tag(vp: Vector2) -> void:
	var focus: FocusController = _combat.get_focus()
	if focus == null or not focus.is_active():
		return
	var tag: Rect2 = focus_tag_rect(vp)
	_skin_panel(tag, FOCUS_BAR_FILL)
	var glyph_top: float = tag.get_center().y - FOCUS_TAG_GLYPH_HEIGHT * 0.5
	var glyph_x: float = tag.position.x + FOCUS_TAG_PAD
	draw_rect(Rect2(glyph_x, glyph_top, FOCUS_TAG_GLYPH_WIDTH, FOCUS_TAG_GLYPH_HEIGHT), FOCUS_BAR_FILL)
	draw_rect(Rect2(glyph_x + FOCUS_TAG_GLYPH_WIDTH + FOCUS_TAG_GLYPH_GAP, glyph_top, FOCUS_TAG_GLYPH_WIDTH, FOCUS_TAG_GLYPH_HEIGHT), FOCUS_BAR_FILL)
	var text_left: float = glyph_x + FOCUS_TAG_GLYPH_WIDTH * 2.0 + FOCUS_TAG_GLYPH_GAP + FOCUS_TAG_PAD
	var text_rect := Rect2(text_left, tag.position.y, maxf(tag.end.x - text_left, 0.0), tag.size.y)
	_draw_centered(text_rect, tr(TEXT_FOCUS_PAUSED_TAG), FOCUS_FONT_SIZE, HudSkin.TEXT)


## Story 044 Part C: rectangle of the "DỪNG" focus tag: right-aligned in the tag zone
## (ScreenLayout.slot_side_left_rect), vertically centred, never taller than the zone minus FOCUS_TAG_V_GAP each side.
static func focus_tag_rect(vp: Vector2) -> Rect2:
	var side: Rect2 = ScreenLayout.slot_side_left_rect(vp, HoldSlots.MAX_SLOTS)
	var height: float = maxf(minf(FOCUS_TAG_HEIGHT, side.size.y - FOCUS_TAG_V_GAP * 2.0), 0.0)
	var width: float = minf(FOCUS_TAG_WIDTH, side.size.x)
	return Rect2(Vector2(side.end.x - width, side.get_center().y - height * 0.5), Vector2(width, height))


func _draw_cells(vp: Vector2, cells: Array[Vector2i], tint: Color, outline: Color) -> void:
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, tint)
		draw_rect(rect.grow(-2.0), outline, false, CELL_OUTLINE_WIDTH)


# Centred single-line text; [param size] is the font size.
# Story 046: the largest size <= [param size] (floor SIGNATURE_MIN_FONT_SIZE) at which [param text] fits
# [param width] in the HudSkin font that will draw it (the fallback font measures narrower than Noto Bold).
func _fit_hud_font(text: String, width: float, size: int, bold: bool) -> int:
	var fitted: int = size
	while fitted > SIGNATURE_MIN_FONT_SIZE and HudSkin.text_width(text, fitted, bold) > width:
		fitted -= 1
	return fitted


# 2026-10-31 (user: "chưa apply hud cho toàn bộ màn"): outlined HudSkin Bold text, shrunk to fit the rect's width.
func _draw_centered(rect: Rect2, text: String, size: int, color: Color) -> void:
	var fitted: int = _fit_hud_font(text, rect.size.x, size, true)
	HudSkin.text(self, Vector2(rect.position.x, rect.get_center().y + fitted * 0.35), text, fitted, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


# 2026-10-31: a Đá Đêm panel (cut top-right / bottom-left) with a [param line] frame, [param alpha] fading both.
func _skin_panel(rect: Rect2, line: Color = HudSkin.MIST, alpha: float = 1.0, fill: Color = HudSkin.NIGHT_STONE, fill_alpha: float = SKIN_PANEL_ALPHA) -> void:
	var cut: float = HudSkin.button_cut(rect)
	HudSkin.panel(self, rect, [0.0, cut, 0.0, cut], Color(fill, fill_alpha * alpha), Color(line, line.a * alpha))


# 2026-10-31: a skin bar: ink rim, groove, and the [param ratio] share of [param rect] in [param fill].
func _skin_bar(rect: Rect2, ratio: float, fill: Color, groove: Color = HudSkin.HP_GROOVE) -> void:
	draw_rect(rect.grow(1.0), Color(HudSkin.TEXT_OUTLINE, fill.a))
	draw_rect(rect, Color(groove, maxf(groove.a, 0.9) * fill.a))
	var w: float = floorf(rect.size.x * clampf(ratio, 0.0, 1.0))
	if w > 0.0:
		draw_rect(Rect2(rect.position, Vector2(w, rect.size.y)), fill)


func _draw_preview(vp: Vector2) -> void:
	var flow: CutFlow = _combat.get_cut_flow()
	var enemy_cell: Vector2i = _combat.get_state().enemy_cell
	if flow.is_menu_open():
		_draw_plan_preview(vp, flow, enemy_cell)
		return
	if not _combat.is_placing():
		return
	var placement: PlacementController = _combat.get_placement()
	var cells: Array[Vector2i] = placement.get_cells()
	var info: Rect2 = ScreenLayout.cut_preview_info_rect(vp)
	var top := Rect2(info.position, Vector2(info.size.x, info.size.y * 0.5))
	var bottom := Rect2(info.position + Vector2(0.0, info.size.y * 0.5), Vector2(info.size.x, info.size.y * 0.35))
	if cells.is_empty():
		var off_text: String = tr(TEXT_PLACE_OFF)
		_draw_centered(Rect2(info.position, Vector2(info.size.x, info.size.y * 0.7)), off_text, _fit_signature_font(off_text, info.size.x, FONT_SIZE), HudSkin.TEXT_DIM)
		if _combat.is_dragging():
			# Dim ghost lifted above the finger: releasing here puts the piece back.
			var unit: Vector2 = ScreenLayout.cell_size(_combat.get_grid(), vp)
			var piece: Piece = placement.get_piece()
			var size: Vector2 = Vector2(piece.size()) * minf(unit.x, unit.y)
			var at: Vector2 = _combat.get_drag_point() - Vector2(0.0, _combat.get_drag_lift_px())
			if piece.is_odd():
				PieceDraw.draw_odd_shape(self, piece, Rect2(at - size * 0.5, size), GHOST_OFF_FILL)  # Story 041
			else:
				PieceDraw.draw_shape(self, piece, Rect2(at - size * 0.5, size), GHOST_OFF_FILL, GHOST_OFF_OUTLINE)
			_draw_finger(_combat.get_drag_point())
		return
	var hit: bool = placement.hits(enemy_cell)
	# Story 039 (shroud): the forecast is blocked: a grey shadow with a cloud icon says why there is no green / red.
	var blocked: bool = _forecast_blocked()
	var ghost_outline: Color = GHOST_BLOCKED_OUTLINE if blocked else (GHOST_HIT_OUTLINE if hit else GHOST_MISS_OUTLINE)
	# Story 041: an odd ghost gets the magenta edge under its green / red cells and the sparkle mark.
	var odd_ghost: bool = PieceDraw.is_odd(placement.get_piece())
	if odd_ghost:
		_draw_odd_edge_cells(vp, cells)
	_draw_cells(vp, cells, GHOST_BLOCKED_TINT if blocked else (GHOST_HIT_TINT if hit else GHOST_MISS_TINT), ghost_outline)
	if odd_ghost:
		_draw_odd_corner_mark(vp, cells)
	if blocked:
		_draw_cloud_over_cells(vp, cells)
	# The label rides on the ghost's top-right corner (above a lifted finger, never under it).
	var damage: int = roundi(_combat.get_cut_config().slash_damage(cells.size()))
	var forecast: String = tr(TEXT_FORECAST_HIDDEN) if blocked else (tr(TEXT_PLACE_HIT) if hit else tr(TEXT_PLACE_MISS))
	var label: String = "%s · %s · %s" % [forecast, tr(TEXT_CELLS) % cells.size(), tr(TEXT_DAMAGE_NUMBER) % damage]
	_draw_corner_label(vp, cells, label, ghost_outline, true)
	# Story 044: the column between Awaken and Cancel is ~75 px at 1280x720, so both lines shrink to fit it.
	var cells_text: String = tr(TEXT_CELLS) % cells.size()
	var damage_text: String = tr(TEXT_DAMAGE) % damage
	# Story 046: light outlined text, the column now sits on the dark backdrop instead of the old beige.
	var cells_size: int = _fit_hud_font(cells_text, top.size.x, BIG_FONT_SIZE, true)
	var damage_size: int = _fit_hud_font(damage_text, bottom.size.x, FONT_SIZE, false)
	HudSkin.text(self, Vector2(top.position.x, top.get_center().y + cells_size * 0.35), cells_text, cells_size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_CENTER, top.size.x, true)
	HudSkin.text(self, Vector2(bottom.position.x, bottom.get_center().y + damage_size * 0.35), damage_text, damage_size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_CENTER, bottom.size.x)
	if _combat.is_dragging():
		_draw_finger(_combat.get_drag_point())


# Story 028: the cast under the open card menu: its pieces (green / red by the boss's cell over the UNION
# with the second ghost), the second ghost lifted above the finger, a total readout, the featured glow.
func _draw_plan_preview(vp: Vector2, flow: CutFlow, enemy_cell: Vector2i) -> void:
	var plan: CastPlan = _combat.get_cast_plan()
	var placement: PlacementController = _combat.get_placement()
	var ghost: Array[Vector2i] = placement.get_cells() if _combat.is_placing() else _no_cells()
	var union: Array[Vector2i] = flow.get_cells()
	for cell: Vector2i in ghost:
		union.append(cell)
	var hit: bool = union.has(enemy_cell)
	var blocked: bool = _forecast_blocked()
	var tint: Color = GHOST_BLOCKED_TINT if blocked else (GHOST_HIT_TINT if hit else GHOST_MISS_TINT)
	var outline: Color = GHOST_BLOCKED_OUTLINE if blocked else (GHOST_HIT_OUTLINE if hit else GHOST_MISS_OUTLINE)
	var plan_pieces: Array[Piece] = plan.pieces()
	for i: int in plan.piece_count():
		# Story 041: a committed odd piece keeps its magenta edge and sparkle mark under the open card menu.
		var odd_plan: bool = i < plan_pieces.size() and PieceDraw.is_odd(plan_pieces[i])
		if odd_plan:
			_draw_odd_edge_cells(vp, plan.piece_cells(i))
		_draw_cells(vp, plan.piece_cells(i), tint, outline)
		if odd_plan:
			_draw_odd_corner_mark(vp, plan.piece_cells(i))
	if blocked:
		_draw_cloud_over_cells(vp, union)
	if plan.piece_count() >= 2:
		_draw_detach_mark(vp, plan.piece_cells(1))
	var refusal: Dictionary = _combat.get_join_refusal()
	var refused: bool = false
	if not ghost.is_empty():
		refused = not _combat.can_confirm_placement()
		var odd_second: bool = PieceDraw.is_odd(placement.get_piece())
		if odd_second:
			_draw_odd_edge_cells(vp, ghost)
		_draw_cells(vp, ghost, GHOST_MISS_TINT if refused else tint, GHOST_MISS_OUTLINE if refused else outline)
		if odd_second:
			_draw_odd_corner_mark(vp, ghost)
	elif _combat.is_placing() and _combat.is_dragging():
		var unit: Vector2 = ScreenLayout.cell_size(_combat.get_grid(), vp)
		var piece: Piece = placement.get_piece()
		var size: Vector2 = Vector2(piece.size()) * minf(unit.x, unit.y)
		var at: Vector2 = _combat.get_drag_point() - Vector2(0.0, _combat.get_drag_lift_px())
		if piece.is_odd():
			PieceDraw.draw_odd_shape(self, piece, Rect2(at - size * 0.5, size), GHOST_OFF_FILL)  # Story 041
		else:
			PieceDraw.draw_shape(self, piece, Rect2(at - size * 0.5, size), GHOST_OFF_FILL, GHOST_OFF_OUTLINE)
	if _combat.is_placing() and _combat.is_dragging():
		_draw_finger(_combat.get_drag_point())
	if not refusal.is_empty():
		var refused_cells: Array[Vector2i] = []
		refused_cells.assign(refusal["cells"])
		_draw_cells(vp, refused_cells, GHOST_MISS_TINT, GHOST_MISS_OUTLINE)
		_draw_corner_label(vp, refused_cells, tr(TEXT_JOIN_CAP) % _combat.get_config().max_cast_cells, GHOST_MISS_OUTLINE, true)
	elif refused and not ghost.is_empty():
		_draw_corner_label(vp, ghost, tr(TEXT_JOIN_CAP) % _combat.get_config().max_cast_cells, GHOST_MISS_OUTLINE, true)
	var featured: bool = _combat.joined_is_featured(ghost)
	if featured:
		_draw_featured_glow(vp, union)
	# The readout counts the COMMITTED cast only (what card readiness counts); a piece still being dragged
	# shows as an addition "(+n)".
	var committed: int = flow.get_cells().size()
	var damage: float = _combat.get_cut_config().slash_damage(committed)
	if _combat.is_plan_featured():
		damage *= float((_combat.get_featured()["bonus"] as Dictionary).get("damage_mult", 1.0))
	var total: String
	if ghost.is_empty():
		total = tr(TEXT_CAST_TOTAL) % [committed, roundi(damage)]
	else:
		total = tr(TEXT_CAST_TOTAL_PREVIEW) % [committed, ghost.size(), roundi(damage)]
	# Labels keep off the shape's cells, the x badge and each other.
	var avoid: Array[Rect2] = []
	for cell: Vector2i in union:
		avoid.append(ScreenLayout.cell_rect(_combat.get_grid(), vp, cell))
	if plan.piece_count() >= 2:
		avoid.append(_detach_mark_rect(vp, plan.piece_cells(1)))
	var total_rect: Rect2 = _place_label(vp, union, total, avoid)
	_draw_label_box(total_rect, total, GHOST_HIT_OUTLINE if hit else GHOST_MISS_OUTLINE, vp)
	if featured:
		avoid.append(total_rect)
		var featured_text: String = _featured_label_text(_combat.get_featured()["bonus"] as Dictionary)
		_draw_label_box(_place_label(vp, union, featured_text, avoid), featured_text, FEATURED_GOLD_DARK, vp)


# Size of a one-line board label (same metrics as _draw_corner_label).
func _label_size(vp: Vector2, text: String) -> Vector2:
	var small: int = int(ScreenLayout.cell_size(_combat.get_grid(), vp).y * LABEL_SMALL_RATIO)
	var width: float = HudSkin.text_width(text, small, true) + LABEL_PAD * 2.0
	return Vector2(width, small * LABEL_LINE_SPACING + LABEL_PAD * 2.0)


# Picks the label rect around the bounding box of [param cells] (above / below / beside it, clamped to the
# enemy half of the board) that overlaps the [param avoid] rects least; the first of equal candidates wins.
func _place_label(vp: Vector2, cells: Array[Vector2i], text: String, avoid: Array[Rect2]) -> Rect2:
	var grid: BoardGrid = _combat.get_grid()
	var box: Rect2 = ScreenLayout.cell_rect(grid, vp, cells[0])
	for cell: Vector2i in cells:
		box = box.merge(ScreenLayout.cell_rect(grid, vp, cell))
	var size: Vector2 = _label_size(vp, text)
	var board: Rect2 = ScreenLayout.board_rect(grid, vp)
	var half_w: float = ScreenLayout.cell_size(grid, vp).x * grid.side_cols
	var bounds := Rect2(board.position.x + half_w, board.position.y, board.size.x - half_w, board.size.y)
	var gap: float = 2.0
	var spots: Array[Vector2] = [
		Vector2(box.end.x - size.x, box.position.y - size.y - gap),
		Vector2(box.end.x - size.x, box.end.y + gap),
		Vector2(box.position.x, box.position.y - size.y - gap),
		Vector2(box.position.x, box.end.y + gap),
		Vector2(box.end.x + gap, box.position.y),
		Vector2(box.position.x - size.x - gap, box.position.y),
	]
	var best: Rect2 = Rect2()
	var best_score: float = INF
	for spot: Vector2 in spots:
		var pos := Vector2(
			clampf(spot.x, bounds.position.x, maxf(bounds.end.x - size.x, bounds.position.x)),
			clampf(spot.y, bounds.position.y, maxf(bounds.end.y - size.y, bounds.position.y)))
		var rect := Rect2(pos, size)
		var score: float = 0.0
		for other: Rect2 in avoid:
			var hit: Rect2 = rect.intersection(other)
			score += hit.size.x * hit.size.y
		if score < best_score:
			best_score = score
			best = rect
	return best


func _draw_label_box(back: Rect2, text: String, color: Color, vp: Vector2) -> void:
	var small: int = int(ScreenLayout.cell_size(_combat.get_grid(), vp).y * LABEL_SMALL_RATIO)
	_draw_skin_label(back, text, small, color)


func _no_cells() -> Array[Vector2i]:
	return []


# Square around the x badge (centred on the second piece's first cell), a bit larger than the drawn disc.
func _detach_mark_rect(vp: Vector2, cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var centre: Vector2 = ScreenLayout.cell_rect(_combat.get_grid(), vp, cells[0]).get_center()
	var half: float = DETACH_MARK_RADIUS + 4.0
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


# A small "x" badge on the first cell of the attached second piece: tapping the piece takes it off.
func _draw_detach_mark(vp: Vector2, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var c: Vector2 = _detach_mark_rect(vp, cells).get_center()
	draw_circle(c, DETACH_MARK_RADIUS, DETACH_MARK_BACK)
	draw_arc(c, DETACH_MARK_RADIUS, 0.0, TAU, 24, HudSkin.MIST, 1.5, true)
	var d: float = DETACH_MARK_RADIUS * 0.5
	draw_line(c + Vector2(-d, -d), c + Vector2(d, d), HudSkin.IVORY, 3.0)
	draw_line(c + Vector2(-d, d), c + Vector2(d, -d), HudSkin.IVORY, 3.0)


# Pulsing gold frame on every cell of a featured join (the ghosts and the corner icon glow together).
func _draw_featured_glow(vp: Vector2, cells: Array[Vector2i]) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_blink_time * TAU * FEATURED_GLOW_HZ)
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(_combat.get_grid(), vp, cell)
		draw_rect(rect, Color(FEATURED_GOLD, 0.18 + 0.22 * pulse))
		draw_rect(rect.grow(-1.0), Color(FEATURED_GOLD, 0.7 + 0.3 * pulse), false, CELL_OUTLINE_WIDTH + 2.0)


# "Hinh chu dao x1,5 . Ghim" (the multiplier uses the locale's decimal mark).
func _featured_label_text(bonus: Dictionary) -> String:
	var text: String = tr(TEXT_FEATURED_LABEL) % _mult_text(float(bonus.get("damage_mult", 1.0)))
	var effect: String = _featured_effect_name(str(bonus.get("effect", "")))
	return text if effect.is_empty() else text + " · " + effect


func _mult_text(mult: float) -> String:
	var text: String = ("%.2f" % mult).rstrip("0").rstrip(".")
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("vi") else text


func _featured_effect_name(effect: String) -> String:
	match effect:
		"pin":
			return tr(TEXT_EFFECT_PIN)
		"burn":
			return tr(TEXT_EFFECT_BURN)
		"fragile":
			return tr(TEXT_EFFECT_FRAGILE)
		"frost":
			return tr(TEXT_EFFECT_FROST)
		StatusEffects.KIND_THORNS:
			return tr(TEXT_EFFECT_THORNS)
	return ""


# True while the cast (or the plan plus the dragged second ghost) is a featured join.
func _featured_glowing() -> bool:
	if _combat.get_featured().is_empty() or not _combat.get_cut_flow().is_menu_open():
		return false
	var ghost: Array[Vector2i] = _combat.get_placement().get_cells() if _combat.is_placing() else _no_cells()
	return _combat.joined_is_featured(ghost)


# Story 028: the match's featured shape drawn small at the right end of the player's HP text row, with a
# tiny label to its left; both light up in gold while the cast being built matches it.
func _draw_featured_icon(vp: Vector2) -> void:
	var featured: Dictionary = _combat.get_featured()
	if featured.is_empty():
		return
	var glow: bool = _featured_glowing()
	var rect: Rect2 = ScreenLayout.featured_icon_rect(vp)
	var pulse: float = 0.5 + 0.5 * sin(_blink_time * TAU * FEATURED_GLOW_HZ)
	# Story 046: label + icon share one Đá Đêm chamfered tile ending at the icon's right edge, readable on
	# the canopy; the icon keeps its rect (left of the pause tile) and its size.
	var text: String = _featured_label_text(featured["bonus"] as Dictionary) if glow else tr(TEXT_FEATURED_CORNER)
	var text_w: float = minf(HudSkin.text_width(text, FEATURED_FONT_SIZE, true), FEATURED_LABEL_MAX_W)
	var label := Rect2(rect.position.x - FEATURED_LABEL_GAP - text_w, rect.position.y, text_w, rect.size.y)
	var tile := Rect2(label.position.x - FEATURED_TILE_PAD, rect.position.y, rect.end.x - label.position.x + FEATURED_TILE_PAD, rect.size.y)
	# The label must not run into the player's header panel (at 1280x720 "Resonant shape" / "Hình Cộng Hưởng"
	# would cover the "hp/max" number): when it does not fit, the tile keeps the icon only.
	var panel_end: float = ScreenLayout.hud_panel_rect(vp, 0).end.x
	var show_label: bool = tile.position.x >= panel_end + FEATURED_LABEL_GAP
	if not show_label:
		tile = rect.grow(FEATURED_TILE_PAD)
	HudSkin.panel(self, tile, [FEATURED_TILE_CUT, 0.0, 0.0, FEATURED_TILE_CUT], HudSkin.NIGHT_STONE, HudSkin.MIST)
	var cells: Array[Vector2i] = featured["cells"]
	var box := Vector2i.ZERO
	for cell: Vector2i in cells:
		box = Vector2i(maxi(box.x, cell.x + 1), maxi(box.y, cell.y + 1))
	var inner: Rect2 = rect.grow(-FEATURED_ICON_PAD)
	var unit: float = minf(inner.size.x / float(box.x), inner.size.y / float(box.y))
	var origin: Vector2 = inner.get_center() - Vector2(box) * unit * 0.5
	var fill: Color = Color(FEATURED_GOLD, 0.8 + 0.2 * pulse) if glow else FEATURED_IDLE_FILL
	for cell: Vector2i in cells:
		draw_rect(Rect2(origin + Vector2(cell) * unit, Vector2(unit, unit)).grow(-0.75), fill)
	draw_rect(rect, FEATURED_GOLD if glow else FEATURED_GOLD_DARK, false, 4.0 if glow else 2.0)
	if show_label:
		HudSkin.text(self, Vector2(label.position.x, label.get_center().y + FEATURED_FONT_SIZE * 0.35), text,
			FEATURED_FONT_SIZE, HudSkin.GRID_LIGHT if glow else HudSkin.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, label.size.x, true)


func _draw_swing(vp: Vector2) -> void:
	var actor: CutActor = _combat.get_cut_actor()
	if not actor.is_swinging():
		return
	# Story 048 F5: with the cast_target pack the floor shows the swing cells (no tint, no countdown label here).
	var vfx_swing: bool = _vfx_ok("cast_target")
	if not vfx_swing:
		_draw_cells(vp, actor.get_cells(), SWING_TINT, SWING_OUTLINE)
	if PieceDraw.any_odd_id(_combat.get_cast_piece_ids()):
		_draw_odd_corner_mark(vp, actor.get_cells())  # Story 041: the cast holds an Odd Block
	if vfx_swing:
		return
	var info: Rect2 = ScreenLayout.cut_swing_info_rect(vp)
	var text: String = tr(TEXT_SWING) % [_skill_name(actor.get_skill_id()), actor.get_time_left()]
	_draw_centered(info, text, BIG_FONT_SIZE, SWING_OUTLINE)


# Boss swing on the PLAYER's half. Story 046 Part C: the red cells (fill, stripes, edge, fading in with the
# swing's progress) are painted under the units by TelegraphPainter in the BattleCanvas floor; there is no
# countdown, move-name or cell-count text on the board any more (the pause panel names the move and its cells).
# What stays here, above the units: the Story 041 Odd Block sparkle on a cell corner.
func _draw_boss_swing(vp: Vector2) -> void:
	var boss: BossController = _combat.get_boss()
	var actor: CutActor = boss.get_actor()
	if not actor.is_swinging():
		return
	# Story 041: the boss's red telegraph of a cast holding an Odd Block carries the sparkle mark.
	if PieceDraw.any_odd_id(_boss_swing_labels(boss, actor)):
		_draw_odd_corner_mark(vp, actor.get_cells())


# Boss's queued combo swing (Story 013). Story 046 Part C: its cells are painted on the floor at progress 0 with
# sparser stripes (TelegraphPainter) and the "2: +g s" box is gone with the other board countdowns; only the
# Story 041 Odd Block sparkle stays here.
func _draw_boss_queued_swing(vp: Vector2) -> void:
	var actor: CutActor = _combat.get_boss().get_actor()
	if not actor.is_swinging():
		return
	var queued: Dictionary = _combat.get_boss_queued_swing()
	if queued.is_empty():
		return
	var cells: Array[Vector2i] = queued["cells"]
	var last: Dictionary = _combat.get_boss().get_last_cut()
	if last.has("combo") and PieceDraw.any_odd_id((last["combo"] as Dictionary).get("labels", []) as Array):
		_draw_odd_corner_mark(vp, cells)  # Story 041


# One small line on a white backing, anchored to the bottom-right corner (or, with
# [param top_right], the top-right corner) of the bounding box of [param cells] and clamped
# inside the board.
func _draw_corner_label(vp: Vector2, cells: Array[Vector2i], text: String, color: Color, top_right: bool = false) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var box: Rect2 = ScreenLayout.cell_rect(grid, vp, cells[0])
	for cell: Vector2i in cells:
		box = box.merge(ScreenLayout.cell_rect(grid, vp, cell))
	var small: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_SMALL_RATIO)
	var width: float = HudSkin.text_width(text, small, true) + LABEL_PAD * 2.0
	var height: float = small * LABEL_LINE_SPACING + LABEL_PAD * 2.0
	var board: Rect2 = ScreenLayout.board_rect(grid, vp)
	var pos: Vector2 = box.end - Vector2(width, height)
	if top_right:
		pos.y = box.position.y
	pos.x = clampf(pos.x, board.position.x, maxf(board.end.x - width, board.position.x))
	pos.y = clampf(pos.y, board.position.y, maxf(board.end.y - height, board.position.y))
	var back := Rect2(pos, Vector2(width, height))
	_draw_skin_label(back, text, small, color)


# 2026-10-31: a board tag in the skin: Đá Đêm panel framed in [param color] (green hit / red miss / gold featured),
# the text in a light tint of that colour, outlined Bold.
func _draw_skin_label(back: Rect2, text: String, small: int, color: Color) -> void:
	_skin_panel(back, Color(color, 1.0))
	HudSkin.text(self, back.position + Vector2(0.0, LABEL_PAD + small * 0.85), text, small, Color(color.lightened(0.55), 1.0),
		HORIZONTAL_ALIGNMENT_CENTER, back.size.x, true)


# Story 037: "+N" over the player's cell while CombatView.get_heal_flash() runs: rises a little and fades out.
func _draw_heal_flash(vp: Vector2) -> void:
	var flash: Dictionary = _combat.get_heal_flash()
	if flash.is_empty():
		return
	var fade: float = clampf(float(flash["time_left"]) / CombatView.FEEDBACK_SEC, 0.0, 1.0)
	var cell: Rect2 = ScreenLayout.cell_rect(_combat.get_grid(), vp, _combat.get_state().player_cell)
	var size: int = int(cell.size.y * FEEDBACK_FONT_RATIO * 1.3)
	var rise: float = cell.size.y * HEAL_RISE_RATIO * (1.0 - fade)
	var back := Rect2(cell.position + Vector2(0.0, -size * 1.4 - rise), Vector2(cell.size.x, size * 1.4))
	_draw_centered(back, tr(TEXT_HEAL_NUMBER) % roundi(float(flash["amount"])), size, Color(HEAL_TEXT, fade))


# Boss HIT / MISS on the player's half (same look as the player's feedback).
func _draw_boss_feedback(vp: Vector2) -> void:
	_draw_feedback_for(vp, _combat.get_boss_feedback())


# NGẮT flash over the victim's cancelled swing cells: orange tint, a big X per cell, text fading out.
func _draw_interrupt(vp: Vector2) -> void:
	var flash: Dictionary = _combat.get_interrupt_flash()
	if flash.is_empty():
		return
	var fade: float = clampf(float(flash["time_left"]) / CombatView.FEEDBACK_SEC, 0.0, 1.0)
	var cells: Array[Vector2i] = flash["cells"]
	var grid: BoardGrid = _combat.get_grid()
	if _vfx_ok("interrupt"):
		# Story 048 F8: the interrupt one-shot over the units replaces the tint and the X; a short NGẮT stays.
		_draw_cells_label(vp, cells, tr(TEXT_INTERRUPT), "", INTERRUPT_COLOR, fade)
		return
	_draw_cells(vp, cells, Color(INTERRUPT_TINT, INTERRUPT_TINT.a * fade), Color(INTERRUPT_COLOR, fade))
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell).grow(-rect_inset(vp))
		draw_line(rect.position, rect.end, Color(INTERRUPT_COLOR, fade), INTERRUPT_X_WIDTH)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(INTERRUPT_COLOR, fade), INTERRUPT_X_WIDTH)
	var boss_victim: bool = int(flash["side"]) == CombatState.Side.ENEMY
	_draw_cells_label(vp, cells, tr(TEXT_INTERRUPT), tr(TEXT_INTERRUPT_BOSS) if boss_victim else tr(TEXT_INTERRUPT_PLAYER), INTERRUPT_COLOR, fade)


# Story 048: true when the floor-VFX pack [param id] is drawable, so its old code drawing here is skipped
# (a missing / un-imported pack keeps the old drawing).
func _vfx_ok(id: String) -> bool:
	return _combat != null and _combat.get_floor_vfx().has_pack(id)


func rect_inset(vp: Vector2) -> float:
	return ScreenLayout.cell_size(_combat.get_grid(), vp).y * INTERRUPT_X_INSET_RATIO


# Two lines (big, small) on a white backing, centred on the bounding box of [param cells] and
# clamped inside the board, so it never reaches the strip under the arena. (Story 046 Part C removed the boss
# countdown, the only caller of TD-023's avoid-the-units placement, so that placement went with it.)
func _draw_cells_label(vp: Vector2, cells: Array[Vector2i], line1: String, line2: String, color: Color, alpha: float = 1.0) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var box: Rect2 = ScreenLayout.cell_rect(grid, vp, cells[0])
	for cell: Vector2i in cells:
		box = box.merge(ScreenLayout.cell_rect(grid, vp, cell))
	var font: Font = ThemeDB.fallback_font
	var big: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_BIG_RATIO)
	var small: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_SMALL_RATIO)
	var width: float = maxf(font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x, font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x) + LABEL_PAD * 2.0
	var height: float = (big + small) * LABEL_LINE_SPACING + LABEL_PAD * 2.0
	var board: Rect2 = ScreenLayout.board_rect(grid, vp)
	# Story 048: outlined text floating just above the cells, no white backing (nothing on a cell may cover a unit).
	var x: float = clampf(box.get_center().x - width * 0.5, board.position.x, maxf(board.end.x - width, board.position.x))
	var base: float = box.position.y - 2.0
	if line2 != "":
		HudSkin.text(self, Vector2(x, base), line2, small, Color(HudSkin.TEXT, alpha), HORIZONTAL_ALIGNMENT_CENTER, width)
		base -= small * LABEL_LINE_SPACING
	HudSkin.text(self, Vector2(x, base), line1, big, Color(color, alpha), HORIZONTAL_ALIGNMENT_CENTER, width, true)
	var _unused_height: float = height


func _draw_feedback(vp: Vector2) -> void:
	_draw_feedback_for(vp, _combat.get_cut_feedback())


func _draw_feedback_for(vp: Vector2, fb: Dictionary) -> void:
	if fb.is_empty() or float(fb.get("wait", 0.0)) > 0.0:
		return
	var hit: bool = bool(fb["hit"])
	var cells: Array[Vector2i] = fb["cells"]
	if not _vfx_ok("hit_impact" if hit else "miss_dust"):  # Story 048 F6 / F7 replace the tint
		_draw_cells(vp, cells, HIT_TINT if hit else MISS_TINT, HIT_TEXT if hit else MISS_TEXT)
	var grid: BoardGrid = _combat.get_grid()
	var cell_rect: Rect2 = ScreenLayout.cell_rect(grid, vp, fb["cell"])
	var size: int = int(cell_rect.size.y * FEEDBACK_FONT_RATIO)
	# Story 048: outlined text floating above the cell (no white backing over the unit); Ivory / dim, never red
	# (art bible P3: red is the telegraph only).
	var color: Color = HudSkin.TEXT if hit else HudSkin.TEXT_DIM
	# Burn / pin hits deal no direct damage: no "-0" line.
	var show_damage: bool = hit and float(fb["damage"]) > 0.0
	var label_box: Rect2 = cell_rect.grow_individual(cell_rect.size.x * 0.25, 0.0, cell_rect.size.x * 0.25, 0.0)
	var base: float = cell_rect.position.y - 2.0
	if show_damage:
		# Story 020: a hit multiplied by Ghim shows its number in the pin blue.
		var damage_color: Color = PIN_BONUS_TEXT if bool(fb.get("pin_bonus", false)) else color
		HudSkin.text(self, Vector2(label_box.position.x, base), tr(TEXT_DAMAGE_NUMBER) % roundi(float(fb["damage"])), size, damage_color, HORIZONTAL_ALIGNMENT_CENTER, label_box.size.x, true)
		base -= size * 1.0
	HudSkin.text(self, Vector2(label_box.position.x, base), tr(TEXT_HIT) if hit else tr(TEXT_MISS), size, color, HORIZONTAL_ALIGNMENT_CENTER, label_box.size.x, true)
	var back := Rect2(label_box.position.x, base - size * 2.6, label_box.size.x, size * 1.3)  # the featured pill sits above the text
	if hit and bool(fb.get("featured", false)):
		# Story 028: a featured-shape hit names its bonus under the HIT box.
		var bonus_text: String = _featured_label_text({"damage_mult": fb.get("featured_mult", 1.0), "effect": fb.get("featured_effect", "")})
		var small: int = FEATURED_FONT_SIZE + 3
		var wide: float = HudSkin.text_width(bonus_text, small, true) + LABEL_PAD * 2.0
		var board: Rect2 = ScreenLayout.board_rect(grid, vp)
		var left: float = clampf(cell_rect.get_center().x - wide * 0.5, board.position.x, maxf(board.end.x - wide, board.position.x))
		var pill := Rect2(left, back.end.y, wide, small * 1.5)
		_skin_panel(pill, HudSkin.GRID_LIGHT)
		HudSkin.text(self, pill.position + Vector2(0.0, small * 1.1), bonus_text, small, HudSkin.GRID_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, wide, true)


# --- Story 014: row burner warning ---------------------------------------------


# The row RowBurnerTrait is announcing (nothing when the match has no row_burner or no warning
# runs): faint amber tint, blinking amber outline, shrinking top bar, "SẮP CHÁY" tag. Once the
# row ignites the trait clears its warning and the floor's BurnPainter takes over.
func _draw_row_warning(vp: Vector2) -> void:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return
	var burner: RowBurnerTrait = host.get_trait(RowBurnerTrait.ID) as RowBurnerTrait
	if burner == null:
		return
	var cells: Array[Vector2i] = burner.get_warning_cells()
	if cells.is_empty():
		return
	var warn_sec: float = burner.param_float(WARN_SEC_PARAM, RowBurnerTrait.DEFAULT_WARN_SEC)
	var ratio: float = 0.0 if warn_sec <= 0.0 else clampf(burner.get_warn_left() / warn_sec, 0.0, 1.0)
	var bright: bool = int(_blink_time * WARN_BLINK_HZ * 2.0) % 2 == 0
	var outline := Color(WARN_OUTLINE, WARN_OUTLINE.a * (1.0 if bright else WARN_BLINK_DIM_ALPHA))
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, WARN_TINT)
		draw_rect(rect.grow(-WARN_OUTLINE_INSET), outline, false, WARN_OUTLINE_WIDTH)
		var inset: float = rect.size.y * WARN_BAR_INSET_RATIO
		var bar_h: float = rect.size.y * WARN_BAR_HEIGHT_RATIO
		var bar := Rect2(Vector2(rect.position.x + inset, rect.position.y + inset), Vector2(rect.size.x - inset * 2.0, bar_h))
		draw_rect(bar, WARN_BAR_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), WARN_BAR_FILL)
	_draw_corner_label(vp, cells, tr(TEXT_ROW_WARNING), WARN_OUTLINE, true)


# --- Story 010: burning cells, pins, feint, learning debug ----------------------


# Diagonal hatch lines (x + y = t) clipped to [param rect], [param step] apart, in [param color]
# and [param width] (the combo layer's hatching).
func _draw_hatching(rect: Rect2, step: float, color: Color, width: float) -> void:
	if step <= 0.0:
		return
	var w: float = rect.size.x
	var h: float = rect.size.y
	var t: float = step
	while t < w + h:
		var from := Vector2(rect.position.x + minf(t, w), rect.position.y + maxf(t - w, 0.0))
		var to := Vector2(rect.position.x + maxf(t - h, 0.0), rect.position.y + minf(t, h))
		draw_line(from, to, color, width)
		t += step


# Flame glyph: an outer and an inner triangle, the inner one shifted toward the base.
func _draw_flame(center: Vector2, cell: Vector2) -> void:
	var w: float = cell.x * BurnPainter.BURN_FLAME_WIDTH_RATIO
	var h: float = cell.y * BurnPainter.BURN_FLAME_HEIGHT_RATIO
	var outer: PackedVector2Array = PackedVector2Array([
		center + Vector2(-w * 0.5, h * 0.5), center + Vector2(0.0, -h * 0.5), center + Vector2(w * 0.5, h * 0.5),
	])
	draw_colored_polygon(outer, BurnPainter.BURN_FLAME_OUTER)
	var iw: float = w * BurnPainter.BURN_FLAME_INNER_RATIO
	var ih: float = h * BurnPainter.BURN_FLAME_INNER_RATIO
	var base: Vector2 = center + Vector2(0.0, h * 0.5)
	var inner: PackedVector2Array = PackedVector2Array([
		base + Vector2(-iw * 0.5, 0.0), base + Vector2(0.0, -ih), base + Vector2(iw * 0.5, 0.0),
	])
	draw_colored_polygon(inner, BurnPainter.BURN_FLAME_INNER)


# Story 046 Part B (I-23): keyword chips under each unit's feet replace the old FROZEN ring + tag and the
# boss's keyword text. Per side, the active keywords (priority frozen > burn > chill > fragile > armor, at
# most CHIP_MAX) as HudSkin icons at CHIP_ICON_SCALE on a Đá Đêm chamfered tile, centred CHIP_FEET_GAP px
# under the feet (UnitLayer.unit_feet_art); a frozen chip carries its time left as a 2 px bar, no text.
# Armor has no per-unit state since Story 007 (CombatState), so its chip never shows today.
func _draw_pins(vp: Vector2) -> void:
	var status: StatusEffects = _combat.get_status()
	if status == null:
		return
	var state: CombatState = _combat.get_state()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		if side == CombatState.Side.ENEMY and state.is_enemy_dead():
			continue
		var chips: Array = []
		if status.is_pinned(side):
			var left: float = status.get_pin_left(side)
			_pin_max[side] = maxf(float(_pin_max.get(side, 0.0)), left)
			chips.append(["frozen", clampf(left / maxf(float(_pin_max[side]), 0.001), 0.0, 1.0)])
		else:
			_pin_max.erase(side)
		if side == CombatState.Side.ENEMY and _combat.get_burn_stacks() > 0:
			chips.append(["burn", -1.0])
		if status.get_frost_stacks(side) > 0:
			chips.append(["chill", -1.0])
		if status.get_fragile_stacks(side) > 0:
			chips.append(["fragile", -1.0])
		if chips.is_empty():
			continue
		var feet: Vector2 = _unit_feet_screen(vp, side, state)
		if _hp_plates_on():
			feet.y += HP_PLATE_GAP + HP_PLATE_HEIGHT
		_draw_keyword_chips(feet, chips.slice(0, CHIP_MAX))


# True when the units carry HP plates (combat.json hud.corner_panels is false).
func _hp_plates_on() -> bool:
	var config: CombatConfig = _combat.get_config()
	return config == null or not config.hud_corner_panels


# 2026-10-31 (user, OSFE reference): the current HP of each living unit on a small plate under its feet,
# while the corner HP panels are off. The number only (no bar).
func _draw_hp_plates(vp: Vector2) -> void:
	if not _hp_plates_on():
		return
	var state: CombatState = _combat.get_state()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var hp: float = state.player_hp if side == CombatState.Side.PLAYER else state.enemy_hp
		if hp <= 0.0:
			continue
		var text: String = str(ceili(hp))
		var rect: Rect2 = hp_plate_rect(_unit_feet_screen(vp, side, state), HudSkin.text_width(text, HP_PLATE_FONT, true))
		var is_player: bool = side == CombatState.Side.PLAYER
		HudSkin.text(self, Vector2(rect.position.x, floorf(rect.get_center().y + HP_PLATE_FONT * 0.36)), text, HP_PLATE_FONT, HudSkin.TEXT if is_player else HudSkin.IVORY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


## Screen rect of an HP plate for feet at [param feet] and a number [param text_w] px wide: centred on the
## feet, HP_PLATE_GAP px below them, HP_PLATE_HEIGHT tall, the text plus HP_PLATE_PAD_X each side (at least
## HP_PLATE_MIN_W), whole pixels.
static func hp_plate_rect(feet: Vector2, text_w: float) -> Rect2:
	var w: float = ceilf(maxf(text_w + HP_PLATE_PAD_X * 2.0, HP_PLATE_MIN_W))
	return Rect2(floorf(feet.x - w * 0.5), floorf(feet.y + HP_PLATE_GAP), w, HP_PLATE_HEIGHT)


# Screen position of the feet of [param side]'s unit (the battle canvas's anchor; the bottom-centre of
# its board cell when the canvas is missing).
func _unit_feet_screen(vp: Vector2, side: int, state: CombatState) -> Vector2:
	var canvas: BattleCanvas = _combat.get_battle_canvas()
	if canvas != null and canvas.get_unit_layer() != null:
		var art: Vector2i = canvas.get_unit_layer().unit_feet_art(side)
		if art.x >= 0:
			return ScreenLayout.from_art(vp, Vector2(art))
	var rect: Rect2 = ScreenLayout.cell_rect(_combat.get_grid(), vp, state.cell_of(side))
	return Vector2(rect.get_center().x, rect.end.y)


# A row of [icon_name, bar_ratio] chips centred on [param feet].x, CHIP_FEET_GAP px under it; bar_ratio
# < 0 = no time bar.
func _draw_keyword_chips(feet: Vector2, chips: Array) -> void:
	var total: float = CHIP_SIZE * chips.size() + CHIP_GAP * (chips.size() - 1)
	var x: float = feet.x - total * 0.5
	var y: float = feet.y + CHIP_FEET_GAP
	for chip: Array in chips:
		var rect := Rect2(x, y, CHIP_SIZE, CHIP_SIZE)
		HudSkin.panel(self, rect, [0.0, CHIP_CUT, 0.0, CHIP_CUT], HudSkin.NIGHT_STONE, HudSkin.MIST, HudSkin.PANEL_LINE_WIDTH)
		HudSkin.icon(self, str(chip[0]), rect.get_center(), CHIP_ICON_SCALE)
		# Story 048 (user 2026-10-31): no time bar under the chip; chip[1] is ignored.
		x += CHIP_SIZE + CHIP_GAP


# Feint flash on the player's half: dashed grey outlines (no red, no X) and a fading label.
func _draw_feint(vp: Vector2) -> void:
	var flash: Dictionary = _combat.get_feint_flash()
	if flash.is_empty():
		return
	var fade: float = clampf(float(flash["time_left"]) / CombatView.FEEDBACK_SEC, 0.0, 1.0)
	var cells: Array[Vector2i] = flash["cells"]
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, Color(FEINT_TINT, FEINT_TINT.a * fade))
		_draw_dashed_rect(rect.grow(-FEINT_INSET), Color(FEINT_COLOR, fade))
	_draw_cells_label(vp, cells, tr(TEXT_FEINT), tr(TEXT_FEINT_NOTE), FEINT_COLOR, fade)


# Dashed rectangle outline (manual dashes: no engine API dependency).
func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a).normalized()
		var d: float = 0.0
		while d < length:
			var e: float = minf(d + FEINT_DASH_LENGTH, length)
			draw_line(a + dir * d, a + dir * e, color, FEINT_DASH_WIDTH)
			d += FEINT_DASH_LENGTH * 2.0


# "né: N | ngắt: N | giả: N%" under the boss HP bar, right-aligned to the bar's right edge
# (hud.end.x - CombatView.PAD), in the gap between the HUD band and the board's top.
func _draw_learning_debug(vp: Vector2) -> void:
	var learning: BossLearning = _combat.get_learning()
	if learning == null:
		return
	var hud: Rect2 = ScreenLayout.hud_rect(vp)
	var chance: float = float(learning.get_modifiers().get("feint_chance", 0.0))
	var text: String = tr(TEXT_LEARNING) % [learning.get_dodge_streak(), learning.get_interrupt_count(), roundi(chance * 100.0)]
	var width: float = hud.size.x * 0.5
	var pos := Vector2(hud.end.x - CombatView.PAD - width, hud.end.y + LEARNING_BASELINE_OFFSET + LEARNING_FONT_SIZE * 0.85)
	HudSkin.text(self, pos, text, LEARNING_FONT_SIZE, LEARNING_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, width)


# Story 020 / 023, Story 046: the keywords (burn, pin, fragile, frost) moved to the chips under the
# boss's feet (_draw_pins); only the shroud trait text stays, one
# line left-aligned under the boss HP bar (clear of the right-aligned learning line), font shrunk
# to fit. Nothing while the boss is dead or nothing applies.
func _draw_boss_status(vp: Vector2) -> void:
	if _combat.get_state().is_enemy_dead():
		return
	# Story 046: burn / pin / fragile / frost are keyword chips under the boss's feet (_draw_pins); only
	# the shroud trait stays a text here.
	var parts: Array = []
	var status_host: TraitHost = _combat.get_trait_host()
	if status_host != null and _is_shrouding(status_host):
		parts.append([tr(TEXT_SHROUD), CLOUD_TEXT])
	if parts.is_empty():
		return
	var boss_strip: Rect2 = ScreenLayout.hud_boss_status_rect(vp)
	boss_strip.size.x = maxf(boss_strip.size.x - _rebirth_reserve(vp), 0.0)
	_draw_status_parts(boss_strip, parts)


# One line of [text, colour] [param parts], left-aligned in [param rect] and STATUS_GAP apart, at
# the largest font <= STATUS_FONT_SIZE (never below STATUS_MIN_FONT_SIZE) that fits the width.
# Returns the x right after the last part (plus the gap), so a caller can append a bar.
func _draw_status_parts(rect: Rect2, parts: Array) -> float:
	var size: int = STATUS_FONT_SIZE
	while size > STATUS_MIN_FONT_SIZE and _parts_width(parts, size) > rect.size.x:
		size -= 1
	var pos := Vector2(rect.position.x, rect.get_center().y + size * 0.35)
	for part: Array in parts:
		HudSkin.text(self, pos, str(part[0]), size, part[1])
		pos.x += HudSkin.text_width(str(part[0]), size) + STATUS_GAP
	return pos.x


# Width of [param parts] drawn in a row at [param size], gaps included (none after the last).
func _parts_width(parts: Array, size: int) -> float:
	var width: float = 0.0
	for part: Array in parts:
		width += HudSkin.text_width(str(part[0]), size)
	return width + STATUS_GAP * maxi(parts.size() - 1, 0)


# --- Story 023: trait readouts, trait cells --------------------------------------


# Under the PLAYER HP bar (ScreenLayout.hud_trait_status_rect): "Phản ứng N/M" for step_reactor
# (red at full), "Khí sương" while frost_aura runs, "Ngòi x.x s" plus a thin fuse bar for
# fuse_cannon (bar and text red in the last FUSE_RED_SEC). Nothing without those traits or once a
# unit is dead. The fuse bar's room is reserved before the text is fitted.
func _draw_trait_status(vp: Vector2) -> void:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return
	var state: CombatState = _combat.get_state()
	if state.is_player_dead() or state.is_enemy_dead():
		return
	var parts: Array = []
	var reactor: StepReactorTrait = host.get_trait(StepReactorTrait.ID) as StepReactorTrait
	if reactor != null:
		var full: bool = reactor.get_charges() >= reactor.get_charges_to_fire()
		parts.append([tr(TEXT_REACTOR_CHARGES) % [reactor.get_charges(), reactor.get_charges_to_fire()], TRAIT_FULL_COLOR if full else TRAIT_TEXT_COLOR])
	var aura: FrostAuraTrait = host.get_trait(FrostAuraTrait.ID) as FrostAuraTrait
	if aura != null and aura.is_active():
		parts.append([tr(TEXT_FROST_AURA), FROST_COLOR])
	var fuse: FuseCannonTrait = host.get_trait(FuseCannonTrait.ID) as FuseCannonTrait
	var low: bool = fuse != null and fuse.get_fuse_left() <= FUSE_RED_SEC
	if fuse != null:
		parts.append([tr(TEXT_FUSE) % fuse.get_fuse_left(), FUSE_BAR_LOW_FILL if low else TRAIT_TEXT_COLOR])
	# Story 036: "burrowed" while the burrow trait is under the sand; "sandstorm" + a draining bar during a storm.
	var burrow: BossTrait = host.get_trait(BURROW_TRAIT_ID)
	if burrow != null and burrow.has_method("is_burrowed") and bool(burrow.call("is_burrowed")):
		parts.append([tr(TEXT_BURROWED), SURFACE_COLOR])
	var storm_ratio: float = _storm_fraction()
	if storm_ratio >= 0.0:
		parts.append([tr(TEXT_SANDSTORM), STORM_COLOR])
	if parts.is_empty():
		return
	var rect: Rect2 = ScreenLayout.hud_trait_status_rect(vp)
	var text_width: float = rect.size.x - (FUSE_BAR_WIDTH + STATUS_GAP if fuse != null else 0.0)
	text_width -= (FUSE_BAR_WIDTH + STATUS_GAP if storm_ratio >= 0.0 else 0.0) + _wind_badge_reserve(vp)
	var end_x: float = _draw_status_parts(Rect2(rect.position, Vector2(maxf(text_width, 0.0), rect.size.y)), parts)
	if storm_ratio >= 0.0:
		var storm_x: float = end_x + (FUSE_BAR_WIDTH + STATUS_GAP if fuse != null else 0.0)
		var storm_bar := Rect2(Vector2(storm_x, rect.get_center().y - FUSE_BAR_HEIGHT * 0.5), Vector2(FUSE_BAR_WIDTH, FUSE_BAR_HEIGHT))
		_skin_bar(storm_bar, storm_ratio, STORM_BAR_FILL)
	if fuse != null:
		var total: float = fuse.get_fuse_sec()
		var ratio: float = 0.0 if total <= 0.0 else clampf(fuse.get_fuse_left() / total, 0.0, 1.0)
		var bar := Rect2(Vector2(end_x, rect.get_center().y - FUSE_BAR_HEIGHT * 0.5), Vector2(FUSE_BAR_WIDTH, FUSE_BAR_HEIGHT))
		_skin_bar(bar, ratio, FUSE_BAR_LOW_FILL if low else FUSE_BAR_FILL)


# --- Story 039: vents, crumbling and fallen cells, island drop, gust, shroud, rebirth, burn_eater heals ----


# TileHazards config (combat.json hazards merged with the match), cached per TileHazards instance.
func _hz_config(hazards: TileHazards) -> Dictionary:
	var id: int = hazards.get_instance_id()
	if id != _hz_cfg_owner or _hz_cfg.is_empty():
		_hz_cfg_owner = id
		_hz_cfg = hazards.get_debug().get("cfg", {}) as Dictionary
	return _hz_cfg


# [param method](side) of [param hazards] as cells, empty while the method does not exist yet.
func _hz_cells(hazards: TileHazards, method: String, side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if hazards.has_method(method):
		out.assign(hazards.call(method, side))
	return out


# [param method](side, cell) of [param hazards] as a number, 0 while the method does not exist yet.
func _hz_num(hazards: TileHazards, method: String, side: int, cell: Vector2i) -> float:
	return float(hazards.call(method, side, cell)) if hazards.has_method(method) else 0.0


# [param method](side, cell) of [param hazards] as a flag, false while the method does not exist yet.
func _hz_flag(hazards: TileHazards, method: String, side: int, cell: Vector2i) -> bool:
	return bool(hazards.call(method, side, cell)) if hazards.has_method(method) else false


# Vents (both halves), crumbling cells and fallen cells; called at the end of _draw_hazards (under the zones).
func _draw_hazards_039(vp: Vector2, hazards: TileHazards, grid: BoardGrid, blink_on: bool) -> void:
	var warn_total: float = float(_hz_config(hazards).get("vent_warn_sec", VENT_WARN_FALLBACK_SEC))
	var crumble_on: bool = hazards.has_method("crumble_enabled") and bool(hazards.call("crumble_enabled"))
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var warned: Array[Vector2i] = []
		for cell: Vector2i in _hz_cells(hazards, "vent_cells", side):
			var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
			if _hz_flag(hazards, "is_venting", side, cell):
				_draw_vent_cell(rect, 2, 1.0, blink_on)
			elif _hz_flag(hazards, "is_vent_warning", side, cell):
				var heat: float = 1.0 - clampf(_hz_num(hazards, "vent_warn_left", side, cell) / maxf(warn_total, 0.001), 0.0, 1.0)
				_draw_vent_cell(rect, 1, heat, blink_on)
				warned.append(cell)
			else:
				_draw_vent_cell(rect, 0, 0.0, blink_on)
		_draw_corner_label(vp, warned, tr(TEXT_VENT_WARN), VENT_WARN_BORDER)
		var cracking: Array[Vector2i] = []
		if crumble_on:
			for cell: Vector2i in (grid.player_cells() if side == CombatState.Side.PLAYER else grid.enemy_cells()):
				var warning: bool = _hz_flag(hazards, "is_crumble_warning", side, cell)
				var progress: float = 1.0 if warning else _hz_num(hazards, "crumble_progress", side, cell)
				if progress > 0.0:
					_draw_crumble_cell(ScreenLayout.cell_rect(grid, vp, cell), progress, warning, blink_on)
				if warning:
					cracking.append(cell)
		for cell: Vector2i in _hz_cells(hazards, "fallen_cells", side):
			_draw_fallen_cell(ScreenLayout.cell_rect(grid, vp, cell), _hz_num(hazards, "fallen_left", side, cell), _hz_num(hazards, "fall_total_sec", side, cell))
		_draw_corner_label(vp, cracking, tr(TEXT_CRUMBLE), CRUMBLE_WARN_BORDER)


# Erupting vent cells again ABOVE the burning layer: a pale double border and a bright ember streak, so a vent
# stays different from the player's own burning cell (hatched orange with a flame and a bottom bar).
func _draw_vent_eruptions(vp: Vector2) -> void:
	var hazards: TileHazards = _combat.get_hazards()
	if hazards == null or not hazards.has_method("vent_cells"):
		return
	var grid: BoardGrid = _combat.get_grid()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		for cell: Vector2i in _hz_cells(hazards, "vent_cells", side):
			if not _hz_flag(hazards, "is_venting", side, cell):
				continue
			var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
			draw_rect(rect.grow(-WARN_OUTLINE_INSET), VENT_ERUPT_BORDER, false, VENT_BORDER_WIDTH)
			draw_rect(rect.grow(-WARN_OUTLINE_INSET - VENT_BORDER_WIDTH - 1.0), VENT_WARN_BORDER, false, VENT_BORDER_WIDTH * 0.5)
			var amp: float = rect.size.y * VENT_STREAK_AMP_RATIO
			var points := PackedVector2Array()
			for k: int in VENT_STREAK_POINTS:
				var t: float = float(k) / float(VENT_STREAK_POINTS - 1)
				points.append(Vector2(rect.position.x + rect.size.x * (0.08 + 0.84 * t), rect.get_center().y + rect.size.y * 0.3 + (amp if k % 2 == 0 else -amp)))
			draw_polyline(points, VENT_ERUPT_BORDER, VENT_STREAK_WIDTH + 1.0)


# One vent cell. [param phase]: 0 idle (dark red streak), 1 warning ([param heat] 0..1 brightens it, border blinks),
# 2 erupting (flame fill, pale border).
func _draw_vent_cell(rect: Rect2, phase: int, heat: float, blink_on: bool) -> void:
	var fill: Color = VENT_FILL
	var streak: Color = VENT_STREAK
	if phase == 1:
		fill = VENT_FILL.lerp(VENT_HEAT_FILL, heat)
		streak = VENT_STREAK.lerp(VENT_HEAT_STREAK, heat)
	elif phase == 2:
		fill = VENT_ERUPT_FILL
		streak = VENT_HEAT_STREAK
	draw_rect(rect, fill)
	var amp: float = rect.size.y * VENT_STREAK_AMP_RATIO
	var points := PackedVector2Array()
	for k: int in VENT_STREAK_POINTS:
		var t: float = float(k) / float(VENT_STREAK_POINTS - 1)
		points.append(Vector2(rect.position.x + rect.size.x * (0.08 + 0.84 * t), rect.get_center().y + (amp if k % 2 == 0 else -amp)))
	draw_polyline(points, streak, VENT_STREAK_WIDTH)
	if phase == 1:
		draw_rect(rect.grow(-WARN_OUTLINE_INSET), Color(VENT_WARN_BORDER, 1.0 if blink_on else WARN_BLINK_DIM_ALPHA), false, VENT_BORDER_WIDTH)
	elif phase == 2:
		draw_rect(rect.grow(-WARN_OUTLINE_INSET), VENT_ERUPT_BORDER, false, VENT_BORDER_WIDTH)


# A cell being stood on: a crack growing with [param progress] (0..1); in the warning ([param warning]) a big
# full crack, a tint and a blinking amber border.
func _draw_crumble_cell(rect: Rect2, progress: float, warning: bool, blink_on: bool) -> void:
	draw_rect(rect, CRUMBLE_WARN_TINT if warning else Color(CRUMBLE_TINT, CRUMBLE_TINT.a * progress))
	_draw_crack_partial(rect, progress, CRUMBLE_CRACK, CRUMBLE_BIG_CRACK_WIDTH if warning else CRUMBLE_CRACK_WIDTH)
	if warning:
		draw_rect(rect.grow(-WARN_OUTLINE_INSET), Color(CRUMBLE_WARN_BORDER, 1.0 if blink_on else WARN_BLINK_DIM_ALPHA), false, WARN_OUTLINE_WIDTH)


# CRACK_POINTS then CRACK_BRANCH scaled into [param rect], drawn only as far as [param ratio] (0..1) of their length.
func _draw_crack_partial(rect: Rect2, ratio: float, color: Color, width: float) -> void:
	var total: float = 0.0
	for shape: Array[Vector2] in [CRACK_POINTS, CRACK_BRANCH]:
		for i: int in range(1, shape.size()):
			total += shape[i - 1].distance_to(shape[i])
	var budget: float = clampf(ratio, 0.0, 1.0) * total
	for shape: Array[Vector2] in [CRACK_POINTS, CRACK_BRANCH]:
		var points := PackedVector2Array([rect.position + shape[0] * rect.size])
		for i: int in range(1, shape.size()):
			var seg: float = shape[i - 1].distance_to(shape[i])
			if budget <= 0.0 or seg <= 0.0:
				break
			var share: float = minf(1.0, budget / seg)
			points.append(rect.position + shape[i - 1].lerp(shape[i], share) * rect.size)
			budget -= seg
		if points.size() >= 2:
			draw_polyline(points, color, width)


# A fallen cell: a dark void, bluish depth bands, a torn rock edge and a time bar (full when it fell, empty when it
# is back): nothing like the plain missing cell, which is not drawn at all.
func _draw_fallen_cell(rect: Rect2, left: float, total: float) -> void:
	draw_rect(rect, FALLEN_VOID)
	draw_rect(rect.grow(-rect.size.y * 0.18), FALLEN_DEPTH)
	draw_rect(rect.grow(-rect.size.y * 0.32), FALLEN_VOID)
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var depth: float = minf(rect.size.x, rect.size.y) * FALLEN_EDGE_DEPTH_RATIO
	var edge := PackedVector2Array()
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var inward: Vector2 = (rect.get_center() - (a + b) * 0.5).normalized()
		for k: int in FALLEN_EDGE_STEPS:
			var t: float = float(k) / float(FALLEN_EDGE_STEPS)
			edge.append(a.lerp(b, t) + inward * (depth if k % 2 == 1 else 0.0))
	edge.append(edge[0])
	draw_polyline(edge, FALLEN_EDGE, FALLEN_EDGE_WIDTH)
	_draw_zone_bar(rect, left, total, FALLEN_BAR_BACK, FALLEN_BAR_FILL, FALLEN_EDGE_WIDTH + 1.0)


# Island drop warning, gust arrow and the shroud's cloud over the boss; called at the end of _draw_hazard_traits.
func _draw_hazard_traits_039(vp: Vector2) -> void:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return
	var grid: BoardGrid = _combat.get_grid()
	var drop: BossTrait = host.get_trait(ISLAND_DROP_TRAIT_ID)
	if drop != null and drop.has_method("get_drop_cells") and drop.has_method("get_drop_warn_left"):
		var left: float = float(drop.call("get_drop_warn_left"))
		var cells: Array[Vector2i] = []
		cells.assign(drop.call("get_drop_cells"))
		if left > 0.0 and not cells.is_empty():
			_draw_island_warning(vp, grid, cells, left, drop.param_float(WARN_SEC_PARAM, ISLAND_WARN_FALLBACK_SEC))
	var gust: BossTrait = host.get_trait(GUST_TRAIT_ID)
	if gust != null and gust.has_method("get_gust_dir") and gust.has_method("get_gust_warn_left"):
		var dir: Vector2i = gust.call("get_gust_dir")
		var warn: float = float(gust.call("get_gust_warn_left"))
		if warn > 0.0 and dir != Vector2i.ZERO:
			var from: Vector2i = _combat.get_state().player_cell
			_draw_gust_arrow(vp, grid, from, dir, warn, gust.param_float(WARN_SEC_PARAM, GUST_WARN_FALLBACK_SEC))
	if _is_shrouding(host) and not _combat.get_state().is_enemy_dead():
		var boss_rect: Rect2 = ScreenLayout.cell_rect(grid, vp, _combat.get_state().enemy_cell)
		var width: float = minf(boss_rect.size.x, boss_rect.size.y) * 0.9
		_draw_cloud(Vector2(boss_rect.get_center().x, boss_rect.position.y + boss_rect.size.y * 0.22), width, CLOUD_COVER_ALPHA)


# The island about to fall: a tint, a blinking border along its outer edge, a draining bar and a label.
func _draw_island_warning(vp: Vector2, grid: BoardGrid, cells: Array[Vector2i], left: float, total: float) -> void:
	var on: bool = int(_blink_time * WARN_BLINK_HZ * 2.0) % 2 == 0
	var color := Color(ISLAND_BORDER, 1.0 if on else WARN_BLINK_DIM_ALPHA)
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell).grow(-WARN_OUTLINE_INSET)
		draw_rect(rect, ISLAND_TINT)
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		var steps: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		for i: int in 4:
			if not cells.has(cell + steps[i]):
				draw_line(corners[i], corners[(i + 1) % 4], color, ISLAND_BORDER_WIDTH)
	_draw_zone_bar(ScreenLayout.cell_rect(grid, vp, cells[0]), left, total, ISLAND_BAR_BACK, ISLAND_BORDER, WARN_OUTLINE_INSET + ISLAND_BORDER_WIDTH)
	_draw_corner_label(vp, cells, tr(TEXT_ISLAND_DROP), ISLAND_BORDER)


# Gust warning: a big arrow on the unit's cell [param from] along [param dir] (grid +y = screen down), the cell it
# would push to tinted when it is a board cell, and a draining bar.
func _draw_gust_arrow(vp: Vector2, grid: BoardGrid, from: Vector2i, dir: Vector2i, left: float, total: float) -> void:
	var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, from)
	var target: Vector2i = from + dir
	if grid.is_player_cell(target):
		draw_rect(ScreenLayout.cell_rect(grid, vp, target), GUST_TINT)
	var d := Vector2(dir)
	var side_len: float = minf(rect.size.x, rect.size.y)
	var c: Vector2 = rect.get_center()
	var tail: Vector2 = c - d * side_len * GUST_ARROW_LENGTH_RATIO
	var tip: Vector2 = c + d * side_len * GUST_ARROW_LENGTH_RATIO
	var head: float = side_len * GUST_HEAD_RATIO
	var normal := Vector2(-d.y, d.x)
	var head_pts := PackedVector2Array([tip + d * head * 0.4, tip - d * head * 0.6 + normal * head * 0.7, tip - d * head * 0.6 - normal * head * 0.7])
	draw_line(tail, tip - d * head * 0.3, GUST_OUTLINE, GUST_ARROW_WIDTH + 4.0)
	draw_colored_polygon(PackedVector2Array([head_pts[0] + d * 3.0, head_pts[1] + normal * 3.0, head_pts[2] - normal * 3.0]), GUST_OUTLINE)
	draw_line(tail, tip - d * head * 0.3, GUST_ARROW, GUST_ARROW_WIDTH)
	draw_colored_polygon(head_pts, GUST_ARROW)
	_draw_zone_bar(rect, left, total, GUST_BAR_BACK, GUST_ARROW, WARN_OUTLINE_INSET)
	_draw_corner_label(vp, [from] as Array[Vector2i], tr(TEXT_GUST), GUST_OUTLINE)


# A small cloud icon centred on [param center], [param width] wide: grey-edged white puffs.
func _draw_cloud(center: Vector2, width: float, alpha: float) -> void:
	var origin := Vector2(center.x - width * 0.5, center.y - width * 0.3)
	for fill_pass: bool in [false, true]:
		for puff: Vector3 in CLOUD_PUFFS:
			var radius: float = width * puff.z + (0.0 if fill_pass else CLOUD_EDGE_GROW)
			var color: Color = CLOUD_FILL if fill_pass else CLOUD_EDGE
			draw_circle(origin + Vector2(width * puff.x, width * puff.y), radius, Color(color, color.a * alpha))


# True while the shroud trait covers the boss's cell (W3: is_shrouding(); a present trait counts when it lacks the getter).
func _is_shrouding(host: TraitHost) -> bool:
	var shroud: BossTrait = host.get_trait(SHROUD_TRAIT_ID)
	if shroud == null:
		return false
	return bool(shroud.call("is_shrouding")) if shroud.has_method("is_shrouding") else true


# True while the hit forecast (the green / red piece shadow) is switched off by the shroud (W3 TraitHost model switch).
func _forecast_blocked() -> bool:
	var host: TraitHost = _combat.get_trait_host()
	if host == null or not host.has_method("hit_forecast_blocked"):
		return false
	return bool(host.call("hit_forecast_blocked"))


# A cloud icon over the middle of the bounding box of [param cells] (the grey hit shadow's "why").
func _draw_cloud_over_cells(vp: Vector2, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var box: Rect2 = ScreenLayout.cell_rect(grid, vp, cells[0])
	for cell: Vector2i in cells:
		box = box.merge(ScreenLayout.cell_rect(grid, vp, cell))
	var unit: Vector2 = ScreenLayout.cell_size(grid, vp)
	_draw_cloud(box.get_center(), minf(unit.x, unit.y) * 0.8, 1.0)


# --- Story 039: rebirth badge under the boss HP bar, revive ring, burn_eater heal numbers ----


# "rebirth" trait when the boss has it and it still matters (one life left or reviving), else null.
func _rebirth_active() -> BossTrait:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return null
	var rebirth: BossTrait = host.get_trait(REBIRTH_TRAIT_ID)
	if rebirth == null:
		return null
	var reviving: bool = rebirth.has_method("is_reviving") and bool(rebirth.call("is_reviving"))
	var lives: int = int(rebirth.call("lives_left")) if rebirth.has_method("lives_left") else 1
	if reviving or (lives > 0 and not _combat.get_state().is_enemy_dead()):
		return rebirth
	return null


# Text of the rebirth badge: "1 life" or "reviving 1.2 s".
func _rebirth_text(rebirth: BossTrait) -> String:
	if rebirth.has_method("is_reviving") and bool(rebirth.call("is_reviving")):
		return tr(TEXT_REVIVING) % (float(rebirth.call("revive_left")) if rebirth.has_method("revive_left") else 0.0)
	return tr(TEXT_REBIRTH_LIFE)


func _rebirth_icon_side(vp: Vector2) -> float:
	return clampf(ScreenLayout.hud_boss_status_rect(vp).size.y, REBIRTH_ICON_MIN, REBIRTH_ICON_MAX)


# Width the rebirth badge takes at the right end of the boss status strip (0 without it).
func _rebirth_reserve(vp: Vector2) -> float:
	var rebirth: BossTrait = _rebirth_active()
	if rebirth == null:
		return 0.0
	var reviving: bool = rebirth.has_method("is_reviving") and bool(rebirth.call("is_reviving"))
	var text_w: float = HudSkin.text_width(_rebirth_text(rebirth), STATUS_FONT_SIZE)
	return _rebirth_icon_side(vp) + STATUS_GAP * 2.0 + text_w + (FUSE_BAR_WIDTH + STATUS_GAP if reviving else 0.0)


# The "one life left" flame badge + text right-aligned in the boss status strip (just under the boss HP bar); while it
# revives a bar fills as the timer runs out and a ring closes on the boss's cell.
func _draw_rebirth(vp: Vector2) -> void:
	var rebirth: BossTrait = _rebirth_active()
	if rebirth == null:
		return
	var reviving: bool = rebirth.has_method("is_reviving") and bool(rebirth.call("is_reviving"))
	var rect: Rect2 = ScreenLayout.hud_boss_status_rect(vp)
	var side_len: float = _rebirth_icon_side(vp)
	var text: String = _rebirth_text(rebirth)
	var text_w: float = HudSkin.text_width(text, STATUS_FONT_SIZE)
	var icon := Rect2(Vector2(rect.end.x - side_len, rect.get_center().y - side_len * 0.5), Vector2(side_len, side_len))
	_skin_panel(icon, REBIRTH_COLOR)
	_draw_flame(icon.get_center(), icon.size * 1.3)
	var text_x: float = icon.position.x - STATUS_GAP - text_w
	HudSkin.text(self, Vector2(text_x, rect.get_center().y + STATUS_FONT_SIZE * 0.35), text, STATUS_FONT_SIZE, REBIRTH_COLOR)
	if not reviving:
		return
	var total: float = rebirth.param_float("revive_sec", REVIVE_FALLBACK_SEC)
	var left: float = float(rebirth.call("revive_left")) if rebirth.has_method("revive_left") else 0.0
	var ratio: float = 1.0 - (0.0 if total <= 0.0 else clampf(left / total, 0.0, 1.0))
	var bar := Rect2(Vector2(text_x - STATUS_GAP - FUSE_BAR_WIDTH, rect.get_center().y - FUSE_BAR_HEIGHT * 0.5), Vector2(FUSE_BAR_WIDTH, FUSE_BAR_HEIGHT))
	_skin_bar(bar, ratio, REBIRTH_COLOR)
	var cell: Rect2 = ScreenLayout.cell_rect(_combat.get_grid(), vp, _combat.get_state().enemy_cell)
	var radius: float = minf(cell.size.x, cell.size.y) * REVIVE_RING_RATIO
	draw_arc(cell.get_center(), radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, RING_POINTS, REBIRTH_COLOR, RING_WIDTH * 1.5)


# Connects CombatState.enemy_healed (W3: every heal of the boss, burn_eater's burn heals included) once the state exists.
func _connect_burn_heal() -> void:
	var state: CombatState = _combat.get_state()
	if state == null or state == _heal_state or not state.has_signal("enemy_healed"):
		return
	if _heal_state != null and _heal_state.is_connected("enemy_healed", _on_enemy_healed):
		_heal_state.disconnect("enemy_healed", _on_enemy_healed)
	_heal_state = state
	state.connect("enemy_healed", _on_enemy_healed)


func _on_enemy_healed(amount: float) -> void:
	if amount > 0.0:
		_heal_pending += amount


## A green "+N" rising off the boss, for [param seconds] (dev hook of the burn_eater demo: a long time keeps it on screen).
func debug_show_boss_heal(amount: float, seconds: float = BOSS_HEAL_SEC) -> void:
	_boss_heals.append([amount, seconds])


# Sums the burn heals of a short batch into one number and ages the numbers on screen.
func _tick_boss_heals(delta: float) -> void:
	if _heal_pending > 0.0:
		_heal_pending_t += delta
		if _heal_pending_t >= BOSS_HEAL_BATCH_SEC:
			_boss_heals.append([_heal_pending, BOSS_HEAL_SEC])
			_heal_pending = 0.0
			_heal_pending_t = 0.0
	for entry: Array in _boss_heals:
		entry[1] = float(entry[1]) - delta
	_boss_heals = _boss_heals.filter(func(e: Array) -> bool: return float(e[1]) > 0.0)


# The burn_eater heal numbers: green "+N" over the boss's cell, rising and fading in the last BOSS_HEAL_SEC.
func _draw_boss_heals(vp: Vector2) -> void:
	if _boss_heals.is_empty():
		return
	var cell: Rect2 = ScreenLayout.cell_rect(_combat.get_grid(), vp, _combat.get_state().enemy_cell)
	var size: int = int(cell.size.y * FEEDBACK_FONT_RATIO * 1.3)
	for entry: Array in _boss_heals:
		var fade: float = clampf(float(entry[1]) / BOSS_HEAL_SEC, 0.0, 1.0)
		var rise: float = cell.size.y * BOSS_HEAL_RISE_RATIO * (1.0 - fade)
		var back := Rect2(cell.position + Vector2(0.0, -size * 1.4 - rise), Vector2(cell.size.x, size * 1.4))
		_draw_centered(back, tr(TEXT_HEAL_NUMBER) % maxi(roundi(float(entry[0])), 1), size, Color(BOSS_HEAL_COLOR, fade))


# --- Story 027: thorn zones ------------------------------------------------


# The thorn-entry flashes of BOTH halves (cells are board cells, so ScreenLayout maps them like burning cells).
# Story 047 Part B: the thorn tiles themselves are drawn by FloorLayer (under the units), not here.
func _draw_zones(vp: Vector2) -> void:
	var status: StatusEffects = _combat.get_status()
	if status == null:
		return
	var grid: BoardGrid = _combat.get_grid()
	# Story 048 (user 2026-10-31): no remaining-time bars on thorn cells; players learn the durations.
	if _vfx_ok("thorn_spikes"):
		return  # Story 048 F9: thorn entry = the thorn_spikes one-shot on the floor
	for cell: Vector2i in _thorn_flashes.keys():
		var alpha: float = clampf(float(_thorn_flashes[cell]) / THORN_FLASH_SEC, 0.0, 1.0)
		draw_rect(ScreenLayout.cell_rect(grid, vp, cell), Color(THORN_FLASH, THORN_FLASH.a * alpha))


# True when a unit or a field piece lies on [param cell] of [param side]'s half (drawn under this view).
func _cell_occupied(side: int, cell: Vector2i) -> bool:
	var state: CombatState = _combat.get_state()
	if state.player_cell == cell or state.enemy_cell == cell:
		return true
	var drops: FieldDrops = _combat.get_drops() if side == CombatState.Side.PLAYER else _combat.get_boss().get_drops()
	return drops != null and not drops.is_cell_free(cell)


# --- Story 036: tile hazards (mire, sand, wind) and the region traits' cues ----------------------------


# Mire (bottom), filled sand and sand warnings of BOTH halves, and the storm haze over the player's half.
func _draw_hazards(vp: Vector2) -> void:
	var hazards: TileHazards = _combat.get_hazards()
	if hazards == null:
		return
	var grid: BoardGrid = _combat.get_grid()
	var blink_on: bool = int(_blink_time * SAND_WARN_BLINK_HZ * 2.0) % 2 == 0
	if _storm_fraction() >= 0.0:
		for cell: Vector2i in grid.player_cells():
			draw_rect(ScreenLayout.cell_rect(grid, vp, cell), STORM_HAZE)
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		for cell: Vector2i in hazards.mire_cells(side):
			if _is_drop_tile(side, cell):
				continue
			_draw_mire_cell(ScreenLayout.cell_rect(grid, vp, cell), _cell_occupied(side, cell))
		for cell: Vector2i in hazards.sand_cells(side):
			var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
			_draw_sand_cell(rect)
			_draw_zone_bar(rect, hazards.sand_left(side, cell), hazards.sand_total_sec(side, cell),
				SAND_BAR_BACK, SAND_BAR_FILL, SAND_EDGE_WIDTH)
		for cell: Vector2i in hazards.sand_warning_cells(side):
			_draw_sand_warning(ScreenLayout.cell_rect(grid, vp, cell), blink_on)
	_draw_hazards_039(vp, hazards, grid, blink_on)


# True while [param cell] of [param side] is a drop tile in any phase (crack, hole, return fade): mire is not drawn
# there so the drop tile under this view reads (ADR-0001 Phase 1).
func _is_drop_tile(side: int, cell: Vector2i) -> bool:
	var status: StatusEffects = _combat.get_status()
	if status == null:
		return false
	return status.is_cracking(side, cell) or status.is_hole(side, cell) or status.returning_cells(side).has(cell)


# Mire cell: dark peat fill (see-through when [param occupied]) and bubble rings that rise and fade in a loop.
func _draw_mire_cell(rect: Rect2, occupied: bool) -> void:
	draw_rect(rect, MIRE_FILL_OCCUPIED if occupied else MIRE_FILL)
	var side_len: float = minf(rect.size.x, rect.size.y)
	for i: int in MIRE_BUBBLES.size():
		var b: Vector3 = MIRE_BUBBLES[i]
		var phase: float = fposmod(_blink_time * MIRE_BUBBLE_HZ + float(i) * MIRE_BUBBLE_PHASE_STEP, 1.0)
		var center := rect.position + Vector2(rect.size.x * b.x, rect.size.y * b.y - side_len * MIRE_BUBBLE_RISE_RATIO * phase)
		var radius: float = side_len * b.z * (0.7 + 0.3 * phase)
		var color := Color(MIRE_BUBBLE, MIRE_BUBBLE.a * (1.0 - phase * 0.6))
		draw_arc(center, radius, 0.0, TAU, MIRE_BUBBLE_POINTS, color, MIRE_BUBBLE_WIDTH)
		draw_circle(center - Vector2(radius, radius) * 0.35, radius * 0.25, color)


# Filled sand: opaque sand block, SAND_RIPPLES wavy dune lines below the time bar, darker edge.
func _draw_sand_cell(rect: Rect2) -> void:
	draw_rect(rect, SAND_FILL)
	var amp: float = rect.size.y * SAND_RIPPLE_AMP_RATIO
	for r: int in SAND_RIPPLES:
		var y: float = rect.position.y + rect.size.y * (SAND_RIPPLE_TOP_RATIO + (1.0 - SAND_RIPPLE_TOP_RATIO) * float(r) / float(SAND_RIPPLES))
		var points := PackedVector2Array()
		for k: int in SAND_RIPPLE_POINTS:
			var t: float = float(k) / float(SAND_RIPPLE_POINTS - 1)
			points.append(Vector2(rect.position.x + rect.size.x * (0.1 + 0.8 * t), y + sin(t * TAU) * amp))
		draw_polyline(points, SAND_RIPPLE, SAND_RIPPLE_WIDTH)
	draw_rect(rect.grow(-SAND_EDGE_WIDTH * 0.5), SAND_RIPPLE, false, SAND_EDGE_WIDTH)


# Sand about to fall: sand tint and a thick sand border, both dimmed on the off phase of the blink.
func _draw_sand_warning(rect: Rect2, blink_on: bool) -> void:
	draw_rect(rect, Color(SAND_WARN_TINT, SAND_WARN_TINT.a * (1.0 if blink_on else 0.5)))
	draw_rect(rect.grow(-SAND_WARN_INSET), Color(SAND_WARN_BORDER, 1.0 if blink_on else WARN_BLINK_DIM_ALPHA), false, SAND_WARN_WIDTH)


# Share (0..1) of the running sandstorm left, or -1.0 when no storm blows (or the trait is absent).
func _storm_fraction() -> float:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return -1.0
	var storm: BossTrait = host.get_trait(STORM_TRAIT_ID)
	if storm == null or not storm.has_method("is_storm") or not bool(storm.call("is_storm")):
		return -1.0
	if not storm.has_method("get_storm_fraction"):
		return 1.0
	return clampf(float(storm.call("get_storm_fraction")), 0.0, 1.0)


# Width the wind badge and its label take at the right end of the trait status line (0 while no wind blows).
func _wind_badge_reserve(vp: Vector2) -> float:
	var hazards: TileHazards = _combat.get_hazards()
	if hazards == null or not hazards.wind_enabled() or hazards.wind_dir() == Vector2i.ZERO:
		return 0.0
	var side_len: float = _wind_badge_side(vp)
	return side_len + STATUS_GAP + HudSkin.text_width(tr(TEXT_WIND), STATUS_FONT_SIZE) + STATUS_GAP


func _wind_badge_side(vp: Vector2) -> float:
	return clampf(ScreenLayout.hud_trait_status_rect(vp).size.y, WIND_BADGE_MIN, WIND_BADGE_MAX)


# Wind: a dark square badge with an arrow along TileHazards.wind_dir() (grid +y = screen down), label to its left.
func _draw_wind_badge(vp: Vector2) -> void:
	if _wind_badge_reserve(vp) <= 0.0 or _combat.get_state().is_player_dead() or _combat.get_state().is_enemy_dead():
		return
	var dir := Vector2(_combat.get_hazards().wind_dir())
	var rect: Rect2 = ScreenLayout.hud_trait_status_rect(vp)
	var side_len: float = _wind_badge_side(vp)
	var badge := Rect2(Vector2(rect.end.x - side_len, rect.get_center().y - side_len * 0.5), Vector2(side_len, side_len))
	_skin_panel(badge)
	var c: Vector2 = badge.get_center()
	var tip: Vector2 = c + dir * side_len * WIND_ARROW_LENGTH_RATIO
	var head: float = side_len * WIND_HEAD_RATIO
	draw_line(c - dir * side_len * WIND_ARROW_LENGTH_RATIO, tip - dir * head * 0.5, WIND_ARROW, WIND_ARROW_WIDTH)
	var normal := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * head + normal * head * 0.6, tip - dir * head - normal * head * 0.6]), WIND_ARROW)
	var label: String = tr(TEXT_WIND)
	var width: float = HudSkin.text_width(label, STATUS_FONT_SIZE)
	HudSkin.text(self, Vector2(badge.position.x - STATUS_GAP - width, c.y + STATUS_FONT_SIZE * 0.35), label, STATUS_FONT_SIZE, WIND_TEXT)


# Region trait cues on the board: hop shadow, riposte warning cell, burrow surface circle.
func _draw_hazard_traits(vp: Vector2) -> void:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return
	var grid: BoardGrid = _combat.get_grid()
	var hop: BossTrait = host.get_trait(HOP_TRAIT_ID)
	if hop != null and hop.has_method("get_hop_target"):
		var target: Vector2i = hop.call("get_hop_target")
		if grid.is_enemy_cell(target):
			var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, target)
			_draw_hop_shadow(rect, _warn_ratio(hop, "get_hop_warn_left", "hop_warn_sec", HOP_WARN_FALLBACK_SEC))
			_draw_corner_label(vp, [target] as Array[Vector2i], tr(TEXT_HOP), HOP_COLOR)
	var riposte: BossTrait = host.get_trait(RIPOSTE_TRAIT_ID)
	if riposte != null and riposte.has_method("get_riposte_cell"):
		var cell: Vector2i = riposte.call("get_riposte_cell")
		var left: float = float(riposte.call("get_riposte_warn_left")) if riposte.has_method("get_riposte_warn_left") else 0.0
		# Quick spec 2026-11-01 rule 4: a locked cell (cracking / hole) is not hit, so it shows no warning.
		var locked: bool = _combat.get_status() != null and _combat.get_status().is_locked(cell)
		if grid.is_player_cell(cell) and left > 0.0 and not locked:
			var rect2: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
			_draw_riposte_cell(rect2)
			_draw_zone_bar(rect2, left, riposte.param_float("warn_sec", RIPOSTE_WARN_FALLBACK_SEC), RIPOSTE_BAR_BACK, RIPOSTE_COLOR, WARN_OUTLINE_INSET + WARN_OUTLINE_WIDTH)
			_draw_corner_label(vp, [cell] as Array[Vector2i], tr(TEXT_RIPOSTE), RIPOSTE_COLOR)
	var burrow: BossTrait = host.get_trait(BURROW_TRAIT_ID)
	if burrow != null and burrow.has_method("get_surface_cell"):
		var surface: Vector2i = burrow.call("get_surface_cell")
		var warn: float = float(burrow.call("get_surface_warn_left")) if burrow.has_method("get_surface_warn_left") else 0.0
		if grid.is_enemy_cell(surface) and warn > 0.0:
			_draw_surface_circle(ScreenLayout.cell_rect(grid, vp, surface), _warn_ratio(burrow, "get_surface_warn_left", "surface_warn_sec", SURFACE_WARN_FALLBACK_SEC))
			_draw_corner_label(vp, [surface] as Array[Vector2i], tr(TEXT_SURFACE), SURFACE_COLOR)
	_draw_hazard_traits_039(vp)


# Share (0..1) of a trait's warning left: getter [param getter] over param [param param] (fallback seconds).
func _warn_ratio(trait_instance: BossTrait, getter: String, param: String, fallback: float) -> float:
	if not trait_instance.has_method(getter):
		return 1.0
	var total: float = trait_instance.param_float(param, fallback)
	return 1.0 if total <= 0.0 else clampf(float(trait_instance.call(getter)) / total, 0.0, 1.0)


# Hop landing: a dark ground shadow low in the cell and a white ring that closes on it as [param ratio] runs out.
func _draw_hop_shadow(rect: Rect2, ratio: float) -> void:
	var c := Vector2(rect.get_center().x, rect.position.y + rect.size.y * HOP_SHADOW_Y_RATIO)
	var rx: float = rect.size.x * HOP_SHADOW_RX_RATIO
	var ry: float = rect.size.y * HOP_SHADOW_RY_RATIO
	var points := PackedVector2Array()
	for i: int in RING_POINTS:
		var a: float = TAU * float(i) / float(RING_POINTS)
		points.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, HOP_SHADOW)
	var side_len: float = minf(rect.size.x, rect.size.y)
	draw_arc(rect.get_center(), side_len * HOP_RING_RATIO * maxf(ratio, SURFACE_INNER_MIN), 0.0, TAU, RING_POINTS, HOP_RING, RING_WIDTH)


# Riposte target: crimson tint, blinking crimson outline and a crosshair.
func _draw_riposte_cell(rect: Rect2) -> void:
	var on: bool = int(_blink_time * WARN_BLINK_HZ * 2.0) % 2 == 0
	draw_rect(rect, RIPOSTE_TINT)
	draw_rect(rect.grow(-WARN_OUTLINE_INSET), Color(RIPOSTE_COLOR, 1.0 if on else WARN_BLINK_DIM_ALPHA), false, WARN_OUTLINE_WIDTH)
	var c: Vector2 = rect.get_center()
	var arm: float = minf(rect.size.x, rect.size.y) * RIPOSTE_CROSS_RATIO
	draw_line(c - Vector2(arm, 0.0), c + Vector2(arm, 0.0), RIPOSTE_COLOR, RING_WIDTH)
	draw_line(c - Vector2(0.0, arm), c + Vector2(0.0, arm), RIPOSTE_COLOR, RING_WIDTH)
	draw_arc(c, arm * 0.6, 0.0, TAU, RING_POINTS, RIPOSTE_COLOR, RING_WIDTH * 0.5)


# Burrow surfacing cell: sand tint, a fixed outer sand ring and an inner ring closing in as [param ratio] runs out.
func _draw_surface_circle(rect: Rect2, ratio: float) -> void:
	var c: Vector2 = rect.get_center()
	var r: float = minf(rect.size.x, rect.size.y) * SURFACE_RING_RATIO
	draw_circle(c, r, SURFACE_TINT)
	draw_arc(c, r, 0.0, TAU, RING_POINTS, SURFACE_COLOR, RING_WIDTH)
	draw_arc(c, r * maxf(ratio, SURFACE_INNER_MIN), 0.0, TAU, RING_POINTS, SURFACE_COLOR, RING_WIDTH * 0.75)


# Remaining-time bar along the top of [param rect], [param top_pad] px below the cell's top edge (clear of
# the thorn spikes): full when the zone forms, empty when it expires.
func _draw_zone_bar(rect: Rect2, left: float, total: float, back: Color, fill: Color, top_pad: float) -> void:
	var ratio: float = 0.0 if total <= 0.0 else clampf(left / total, 0.0, 1.0)
	var inset: float = rect.size.y * ZONE_BAR_INSET_RATIO
	var bar_h: float = rect.size.y * ZONE_BAR_HEIGHT_RATIO
	var bar := Rect2(Vector2(rect.position.x + inset, rect.position.y + top_pad + inset * 0.5), Vector2(rect.size.x - inset * 2.0, bar_h))
	draw_rect(bar, back)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)


# Cracked cells (slam) as a dark fill with a crack polyline; the cells a slam or the fuse blast
# announces with a faint orange tint and a blinking orange outline (same blink clock as the row
# warning). Drawn under the burning layer so a burning cracked cell still shows its flame.
func _draw_trait_cells(vp: Vector2) -> void:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return
	var grid: BoardGrid = _combat.get_grid()
	var warned: Array[Vector2i] = []
	var slam: SlamTrait = host.get_trait(SlamTrait.ID) as SlamTrait
	if slam != null:
		if not _vfx_ok("cracked_cell"):  # Story 048 F4: else the floor draws the crack
			for cell: Vector2i in slam.get_cracked_cells():
				var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
				draw_rect(rect, CRACK_TINT)
				_draw_crack(rect)
		warned.append_array(slam.get_warning_cells())
	var fuse: FuseCannonTrait = host.get_trait(FuseCannonTrait.ID) as FuseCannonTrait
	if fuse != null:
		warned.append_array(fuse.get_warning_cells())
	if warned.is_empty():
		return
	var bright: bool = int(_blink_time * WARN_BLINK_HZ * 2.0) % 2 == 0
	var outline := Color(TRAIT_WARN_OUTLINE, TRAIT_WARN_OUTLINE.a * (1.0 if bright else WARN_BLINK_DIM_ALPHA))
	for cell: Vector2i in warned:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, TRAIT_WARN_TINT)
		draw_rect(rect.grow(-WARN_OUTLINE_INSET), outline, false, WARN_OUTLINE_WIDTH)


# Crack glyph: CRACK_POINTS and CRACK_BRANCH scaled into [param rect].
func _draw_crack(rect: Rect2) -> void:
	for shape: Array[Vector2] in [CRACK_POINTS, CRACK_BRANCH]:
		var points := PackedVector2Array()
		for p: Vector2 in shape:
			points.append(rect.position + p * rect.size)
		draw_polyline(points, CRACK_LINE, CRACK_LINE_WIDTH)


func _draw_confirm(vp: Vector2) -> void:
	if not _combat.is_confirm_visible():
		return
	var rect: Rect2 = ScreenLayout.confirm_button_rect(vp)
	var actor: CutActor = _combat.get_cut_actor()
	var swinging: bool = actor.is_swinging()
	var enabled: bool = not (swinging or not _combat.can_confirm_placement())
	var text: String = tr(TEXT_CONFIRM)
	if swinging:
		text = tr(TEXT_COOLDOWN) % actor.get_time_left()
	# 2026-10-31: the game skin's PRIMARY button (gold line), dimmed while it cannot cast.
	HudSkin.button(self, rect, text, 0, enabled and UiButtons.is_pressed_at(self, rect), enabled, BIG_FONT_SIZE)


# Story 024: a soft ring under the dragging finger, so the lifted ghost reads as "held from here".
func _draw_finger(at: Vector2) -> void:
	draw_circle(at, FINGER_RADIUS, FINGER_FILL)
	draw_arc(at, FINGER_RADIUS, 0.0, TAU, 32, FINGER_OUTLINE, 3.0)


# Story 024: the big "Xoay" button over the (locked) d-pad area while PLACING: a clockwise arrow glyph
# and the label. Any finger may press it, also while another one drags.
func _draw_rotate(vp: Vector2) -> void:
	if not _combat.is_placing():
		return
	var rect: Rect2 = ScreenLayout.rotate_button_rect(vp)
	# 2026-10-31: the game skin's SECONDARY button (Sương line); glyph and label in Ngà.
	HudSkin.button(self, rect, "", 1, UiButtons.is_pressed_at(self, rect))
	var c: Vector2 = rect.get_center() - Vector2(0.0, rect.size.y * ROTATE_GLYPH_UP_RATIO)
	var radius: float = minf(rect.size.x, rect.size.y) * ROTATE_GLYPH_RADIUS_RATIO
	var end_angle: float = TAU * 0.8
	draw_arc(c, radius, 0.0, end_angle, 40, HudSkin.IVORY, ROTATE_GLYPH_WIDTH)
	var tip: Vector2 = c + Vector2(cos(end_angle), sin(end_angle)) * radius
	var tangent := Vector2(-sin(end_angle), cos(end_angle))
	var normal := Vector2(cos(end_angle), sin(end_angle))
	var head: float = ROTATE_GLYPH_WIDTH * 2.2
	draw_colored_polygon(PackedVector2Array([tip + tangent * head, tip + normal * head * 0.7, tip - normal * head * 0.7]), HudSkin.IVORY)
	var label_rect := Rect2(rect.position + Vector2(0.0, rect.size.y * ROTATE_LABEL_TOP_RATIO), Vector2(rect.size.x, rect.size.y * (1.0 - ROTATE_LABEL_TOP_RATIO)))
	_draw_centered(label_rect, tr(TEXT_ROTATE), ROTATE_FONT_SIZE, HudSkin.IVORY)
	_draw_place_hint(vp)


# Story 044 Part C: the placement hint in its band at the top of the Rotate button (ScreenLayout.place_hint_rect),
# drawn after the button. The font shrinks until the text fits PLACE_HINT_MAX_LINES lines of the band; the
# line count is capped so nothing spills over the glyph or any other control.
func _draw_place_hint(vp: Vector2) -> void:
	var hint: Rect2 = ScreenLayout.place_hint_rect(vp)
	var pad: float = BUTTON_FRAME_WIDTH * 3.0
	var width: float = maxf(hint.size.x - pad * 2.0, 0.0)
	var text: String = tr(TEXT_PLACE_HINT)
	var font: Font = HudSkin.font_semibold()
	var size: int = PLACE_HINT_FONT_SIZE
	while size > PLACE_HINT_MIN_FONT_SIZE:
		var block: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, size, PLACE_HINT_MAX_LINES)
		var full_lines: float = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, size).y
		if block.y <= hint.size.y - pad and full_lines <= block.y + 0.5:
			break
		size -= 1
	var lines: int = clampi(int((hint.size.y - pad) / font.get_height(size)), 1, PLACE_HINT_MAX_LINES)
	var hint_pos := Vector2(hint.position.x + pad, hint.position.y + pad * 0.5 + font.get_ascent(size))
	draw_multiline_string_outline(font, hint_pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, lines, HudSkin.TEXT_OUTLINE_PX, HudSkin.TEXT_OUTLINE)
	draw_multiline_string(font, hint_pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, lines, HudSkin.TEXT_DIM)


# Story 024: the "Hủy" button while PLACING or while the card menu is open.
func _draw_cancel(vp: Vector2) -> void:
	if not (_combat.is_placing() or _combat.get_cut_flow().is_menu_open()):
		return
	var rect: Rect2 = ScreenLayout.cancel_button_rect(vp)
	# 2026-10-31: the game skin's NEUTRAL button.
	HudSkin.button(self, rect, tr(TEXT_CANCEL), 3, UiButtons.is_pressed_at(self, rect), true, BUTTON_FONT_SIZE)


func _draw_menu(vp: Vector2) -> void:
	var flow: CutFlow = _combat.get_cut_flow()
	if not flow.is_menu_open():
		return
	var panel: Rect2 = ScreenLayout.skill_menu_panel_rect(vp)
	# 2026-10-31: Đá Đêm frame; the menu timer is a skin bar (dark gold) under the join hint.
	_skin_panel(panel)
	var bar: Rect2 = ScreenLayout.skill_menu_bar_rect(vp)
	var ratio: float = 0.0 if flow.get_duration() <= 0.0 else flow.get_time_left() / flow.get_duration()
	_skin_bar(bar, ratio, BAR_FILL, BAR_BACK)
	# TD-016: the panel covers the place hint strip, so the bar says another piece can still be dragged in.
	if _combat.can_join_piece():
		var hint_size: int = maxi(mini(SMALL_FONT_SIZE, int(bar.size.y * 0.9)), 12)
		var hint_pos: Vector2 = bar.position + Vector2(0.0, bar.size.y * 0.5 + hint_size * 0.35)
		HudSkin.text(self, hint_pos, tr(TEXT_JOIN_HINT), hint_size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, true)
	var config: SkillConfig = _combat.get_skill_config()
	var order: Array[String] = flow.get_hand()
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, order.size())
	var cell_count: int = flow.get_cells().size()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var id: String = order[i]
		var status: Dictionary = _skill_status(id, cell_count)
		var available: bool = bool(status["available"])
		var alpha: float = 1.0 if available else DIM_ALPHA
		var cursed: bool = config.is_curse(id)
		if cursed:
			_skin_panel(rect, CURSE_OUTLINE, 1.0, CURSE_BACK, 0.9)
			_draw_lock_glyph(rect)
		else:
			# 2026-10-31: ready = PRIMARY skin button, not ready = NEUTRAL dimmed (name and status drawn below).
			HudSkin.button(self, rect, "", 0 if available else 3, available and UiButtons.is_pressed_at(self, rect), available)
		var name_rect := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.6))
		var note_rect := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.5), Vector2(rect.size.x, rect.size.y * 0.45))
		var menu_name: String = _menu_skill_name(id)
		var name_size: int = _fit_font_size(menu_name, name_rect.size.x - MENU_NAME_PAD * 2.0, BUTTON_FONT_SIZE)
		_draw_centered(name_rect.grow_individual(-MENU_NAME_PAD, 0.0, -MENU_NAME_PAD, 0.0), menu_name, name_size, Color(HudSkin.TEXT, alpha))
		_draw_centered(note_rect.grow_individual(-MENU_NAME_PAD, 0.0, -MENU_NAME_PAD, 0.0), str(status["text"]), SMALL_FONT_SIZE, Color(HudSkin.GRID_LIGHT if available else HudSkin.TEXT_DIM, alpha))


# Story 033: a code-drawn padlock (body + shackle) in the top-right corner of a locked menu card.
func _draw_lock_glyph(rect: Rect2) -> void:
	var edge: float = minf(rect.size.x, rect.size.y) * CURSE_LOCK_SIZE_RATIO
	var body := Rect2(rect.end.x - edge * 1.15, rect.position.y + edge * 0.45, edge * 0.8, edge * 0.6)
	draw_rect(body, CURSE_LOCK_COLOR)
	var center := Vector2(body.position.x + body.size.x * 0.5, body.position.y)
	draw_arc(center, body.size.x * 0.28, PI, TAU, 12, CURSE_LOCK_COLOR, maxf(edge * 0.1, 2.0))
	draw_rect(Rect2(center.x - 1.5, body.position.y + body.size.y * 0.3, 3.0, body.size.y * 0.35), CURSE_BACK)


# {available, text}: "cần N ô" whenever the cut covers fewer cells than the skill needs (even
# if it is also unimplemented), else "chưa có", else the cooldown seconds, else ready.
func _skill_status(id: String, cell_count: int) -> Dictionary:
	var config: SkillConfig = _combat.get_skill_config()
	var check: Dictionary = SkillAvailability.check(config, _combat.get_skill_cooldowns(), id, cell_count, _combat.get_card_level(id))
	var min_cells: int = int(check["need_cells"])
	var text: String = tr(TEXT_READY)
	if str(check["reason"]) == "curse":
		text = tr(TEXT_CURSE_LOCKED)
	elif cell_count < min_cells:
		text = tr(TEXT_NEED_CELLS) % min_cells
	elif str(check["reason"]) == "not_implemented":
		text = tr(TEXT_NOT_IMPLEMENTED)
	elif str(check["reason"]) == "cooldown":
		text = tr(TEXT_COOLDOWN) % float(check["cooldown_left"])
	return {"available": bool(check["available"]), "text": text}


func _skill_name(id: String) -> String:
	return tr(str(_combat.get_skill_config().get_skill(id).get("name_key", id)))


# Story 020: the menu card name with the player's level suffix ("Kiếm khí +2") above level 1.
func _menu_skill_name(id: String) -> String:
	var level: int = _combat.get_card_level(id)
	if level > 1:
		return _skill_name(id) + LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % level
	return _skill_name(id)


# Largest font size <= [param size] (never below MENU_NAME_MIN_FONT_SIZE) at which [param text]
# fits in [param width] pixels (Story 020: "Chấn phong +3" must not clip in a menu slot).
func _fit_font_size(text: String, width: float, size: int) -> int:
	var fitted: int = size
	while fitted > MENU_NAME_MIN_FONT_SIZE and HudSkin.text_width(text, fitted, true) > width:
		fitted -= 1
	return fitted


# The signature hotkey from combat.json (`signature_key`), SIGNATURE_KEY_FALLBACK without a config.
func _signature_key() -> Key:
	if _combat == null or not _combat.has_method("get_config"):
		return SIGNATURE_KEY_FALLBACK
	var config: CombatConfig = _combat.get_config()
	if config == null:
		return SIGNATURE_KEY_FALLBACK
	var code: Key = OS.find_keycode_from_string(config.signature_key)
	return code if code != KEY_NONE else SIGNATURE_KEY_FALLBACK


## Story 032: the in-match relic strip (display only), for demos / tests.
func get_relic_strip() -> RelicStrip:
	return _relic_strip


## DEV-ONLY (Story 032 demos): relic ids to show while CombatView reports no relics.
func debug_show_relics(ids: Array[String]) -> void:
	_debug_relics = ids.duplicate()


# Story 032: mirrors CombatView.get_relics() (when it exists) into the strip and wires each relic's
# `triggered` signal to the 0.4 s flash.
func _sync_relic_strip() -> void:
	if _relic_strip == null:
		return
	var shown: bool = _combat != null and _combat.get_state() != null and not _overlay_shown()
	_relic_strip.visible = shown
	if not shown:
		return
	_relic_strip.area = ScreenLayout.hud_relic_strip_rect(get_viewport_rect().size)
	var ids: Array[String] = []
	if _combat.has_method("get_relics"):
		for relic: Variant in _combat.call("get_relics"):
			if relic is BaseRelic:
				var base := relic as BaseRelic
				ids.append(base.get_id())
				if not base.triggered.is_connected(_on_relic_triggered):
					base.triggered.connect(_on_relic_triggered)
	if ids.is_empty():
		ids = _debug_relics
	_relic_strip.set_relics(ids)


func _on_relic_triggered(relic_id: String) -> void:
	if _relic_strip != null:
		_relic_strip.flash(relic_id)


# True while the reward / fate / ending screen covers the battle (main scene only; false in a bare battle).
func _overlay_shown() -> bool:
	var root: Node = get_tree().current_scene
	if root == null:
		return false
	for path: String in OVERLAY_PATHS:
		var view: Node = root.get_node_or_null(path)
		if view != null and view.has_method("is_shown") and bool(view.call("is_shown")):
			return true
	return false
