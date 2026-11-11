#!/usr/bin/env python3
"""Write region and monster specs from the live roster. No new colours."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROSTER = ROOT / "docs" / "art" / "FLOOR-MAP-ROSTER.md"
REGIONS = ROOT / "design" / "assets" / "regions"
CHARACTERS = ROOT / "design" / "assets" / "characters"

FLOORS = {
    "forest": 1,
    "hellfire": 2,
    "sands": 3,
    "swamp": 4,
    "dungeon": 5,
    "ice_tower": 6,
    "sky_isles": 7,
    "lattice_heart": None,
}
NAMES = {
    "forest": "Rừng Sương",
    "hellfire": "Thành Hỏa Ngục",
    "sands": "Sa Mạc Cát Vùi",
    "swamp": "Đầm Lầy Độc",
    "dungeon": "Hầm Ngục",
    "ice_tower": "Tháp Sương",
    "sky_isles": "Không Đảo",
    "lattice_heart": "Tâm Lưới",
}
ENV = {
    "forest": "present",
}
OUT_OF_POOL = ["wolf", "goblin_chief", "goblin_warrior", "goblin_shaman", "goblin_brute"]
LOCKED = {"goblin_scout"}


def q(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def tier_frame(entity_id: str, role: str) -> tuple[str, int, int]:
    if entity_id == "dire_wolf":
        return "monster", 68, 52
    if role.startswith("boss"):
        return "keeper", 160, 130
    if role.startswith("miniboss"):
        return "elite", 80, 80
    return "monster", 64, 52


def parse() -> list[tuple[str, list[tuple[str, str, str, str]]]]:
    text = ROSTER.read_text(encoding="utf-8")
    found: list[tuple[str, list[tuple[str, str, str, str]]]] = []
    current = None
    rows: list[tuple[str, str, str, str]] = []
    for line in text.splitlines():
        art = re.search(r"Art: `([a-z_]+)`", line)
        if art:
            if current:
                found.append((current, rows))
            current = art.group(1)
            rows = []
            continue
        if current and line.startswith("| `"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            entity_id = cells[0].strip("`")
            rows.append((entity_id, cells[1], cells[2], cells[6]))
    if current:
        found.append((current, rows))
    for i, (region, region_rows) in enumerate(found):
        if region == "lattice_heart" and not region_rows:
            found[i] = (region, [("an_dai_keeper", "Người Giữ Tâm Lưới", "boss", "không")])
    return found


def write_character(region: str, row: tuple[str, str, str, str]) -> None:
    entity_id, name, role, sheet = row
    tier, w, h = tier_frame(entity_id, role)
    has_sheet = sheet.strip() == "có"
    if region != "forest":
        palette = "needs_art_director_review"
    elif entity_id in LOCKED:
        palette = "locked"
    else:
        palette = "group_assigned_not_per_creature"
    ref = ROOT / "design" / "assets" / "references" / "characters" / f"{entity_id}.md"
    lines = [
        f"id: {entity_id}",
        f"name: {q(name)}",
        f"region: {region}",
        f"role: {q(role)}",
        f"tier: {tier}",
        "frame: [%d, %d]" % (w, h),
        "anchor: bottom_center",
        "outline: \"#1B1722\"",
        f"sheet: {'present' if has_sheet else 'absent'}",
        f"palette_status: {palette}",
        "colours: []",
        "silhouette: unknown",
        "materials: unknown",
        "approval: unknown",
        "sources:",
        "  - docs/art/FLOOR-MAP-ROSTER.md",
        "  - docs/art/RENDER-STANDARDS.md",
        "  - docs/art/REGION-MATERIALS-AND-PALETTE.md",
    ]
    if ref.is_file():
        lines.append(f"master_reference: design/assets/references/characters/{entity_id}.md")
    if entity_id == "an_dai_keeper":
        lines.append("frame_conflict: \"brief still says 48x64; RENDER-STANDARDS wins at 160x130\"")
    path = CHARACTERS / region / f"{entity_id}.yaml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_region(region: str, rows: list[tuple[str, str, str, str]]) -> None:
    floor = FLOORS[region]
    env = ENV.get(region, "missing")
    palette = "partial_see_palette_doc" if region == "forest" else "needs_art_director_review"
    lines = [
        f"id: {region}",
        f"name: {q(NAMES[region])}",
        "floor: %s" % ("null" if floor is None else floor),
        "final_battle: %s" % ("true" if region == "lattice_heart" else "false"),
        f"environment: {env}",
        "background: \"800x360, max 3 layers, no outline, no gameplay overlay\"",
        "floor_tiles: \"nine-slice 16x16, no outline\"",
        f"sprite_palette_status: {palette}",
        "sprite_colours: []",
        "monsters:",
    ]
    for entity_id, _name, _role, _sheet in rows:
        lines.append(f"  - {entity_id}")
    if region == "forest":
        lines.append("out_of_pool:")
        for entity_id in OUT_OF_POOL:
            lines.append(f"  - {entity_id}")
    lines += [
        "sources:",
        "  - docs/art/FLOOR-MAP-ROSTER.md",
        "  - docs/art/REGION-MATERIALS-AND-PALETTE.md",
        "  - docs/art/RENDER-STANDARDS.md",
        "  - design/art/region-visual-brief-2026-11-05.md",
    ]
    path = REGIONS / f"{region}.yaml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    found = parse()
    if [r for r, _ in found] != list(FLOORS):
        raise SystemExit("roster regions %s" % [r for r, _ in found])
    for region, rows in found:
        if not rows:
            raise SystemExit("no monsters for " + region)
        write_region(region, rows)
        for row in rows:
            write_character(region, row)
    print("regions", len(found), "monsters", sum(len(r) for _, r in found))


if __name__ == "__main__":
    main()
