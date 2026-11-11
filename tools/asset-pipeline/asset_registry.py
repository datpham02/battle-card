#!/usr/bin/env python
"""Asset registry tool — the single source of truth for art asset lifecycle.

Registry file: design/assets/asset-registry.yaml (schema in its header comment and
docs/art/ASSET_REGISTRY.md). Pure Python 3 standard library: this machine has no
PyYAML, so the registry is written in a strict YAML subset that this file reads
and writes deterministically (2-space indent, `key: value`, `- item` lists,
double-quoted strings where needed, `[]` / `{}` for empties, `#` comments).

Run as `python -X utf8 -I tools/asset-pipeline/asset_registry.py <command>`.

Commands
  validate            parse the registry, check the schema, lifecycle states and
                      history transitions.                     exit 1 on error
  check               validate + files exist, duplicate ids / paths, orphaned
                      production art, registry-vs-disk drift (frames, clips,
                      counts, manifests).                       exit 1 on error
  manifest            render design/assets/asset-manifest.md from the registry.
  bootstrap           print skeleton entries for production art that is not in
                      the registry; --add-missing appends them (never overwrites
                      an existing entry; new entries carry status "installed"
                      and acceptance "unknown").
  set-status ID STATE [--clip NAME] --on DATE --by WHO --evidence TEXT
                      move an asset (or one clip) to STATE through a valid
                      transition and append a history event. accepted /
                      approved require --by user and --evidence; the tool only
                      records what the user said — run it after their word.
  set-acceptance ID VALUE [--clip NAME] --on DATE --by WHO --evidence TEXT
                      record the user's verdict (accepted | rejected | pending)
                      on an asset or clip WITHOUT moving its state — for art
                      that is already installed, or a candidate the user
                      rejected. accepted / rejected require --by user and
                      --evidence.
  log-event ID EVENT [--clip NAME] [--on DATE] [--by WHO] [--evidence TEXT]
                     [--note TEXT] [--candidate PATH] [--job-id ID]
                      append a history event that does not change state
                      (generation_started, generation_completed,
                      candidate_created, qa_completed, note …); a --candidate
                      path is also added to the entry's candidates list.
  set-production ID PATH [PATH...]
                      add production paths to an entry (after an install); never removes one.
  show ID             print one entry.
  export-json [PATH]  write the parsed registry as JSON (for Godot tests).

Helpers in tools/ emit observations, never verdicts (CLAUDE.md): a FAIL here means
"the registry and the disk disagree", not "the art is bad".
"""
from __future__ import annotations

import argparse
import json
import os
import re
import struct
import sys
import zlib
from datetime import date

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
REGISTRY_PATH = os.path.join("design", "assets", "asset-registry.yaml")
MANIFEST_PATH = os.path.join("design", "assets", "asset-manifest.md")
ART_DIR = os.path.join("assets", "art")
SRC_DIR = os.path.join("art_src", "units")
PALETTE_PATH = "art_src/palette/tessera_master.gpl"

SCHEMA_VERSION = 1

# ─── Lifecycle ───────────────────────────────────────────────────────────────
STATES = ["candidate", "accepted", "installed", "approved", "legacy"]
TRANSITIONS = {
    "candidate": ["accepted", "legacy"],
    "accepted": ["installed", "candidate", "legacy"],
    "installed": ["approved", "candidate", "legacy"],
    "approved": ["legacy"],
    "legacy": [],
}
# States that only the user may grant (set-status demands --by user + --evidence).
USER_ONLY_STATES = {"accepted", "approved"}
ACCEPTANCE_VALUES = ["unknown", "pending", "accepted", "rejected"]
EVENTS = [
    "generation_started", "generation_completed", "candidate_created", "qa_completed",
    "user_accepted", "integration_completed", "user_approved", "candidate_rejected",
    "version_retired", "registered", "note",
]
TYPES = ["unit", "vfx_pack", "env", "ui", "card", "portrait", "texture", "other"]
TIERS = ["hero", "monster", "elite", "boss", "n/a"]
# Who made the asset. Every asset names one; the per-call tools stay in `generation` / `pixellab` / `pixelfx`.
PROVIDERS = ["pixellab", "pixelfx", "fx-pipeline", "script", "hand", "data", "mixed", "unknown"]
# pixelfx.origin: upstream = an unmodified upstream effect; adapted = an upstream effect changed for Tessera
# (keep its header notice); original = a Tessera effect written with the pixelfx toolkit / method.
PIXELFX_ORIGINS = ["upstream", "adapted", "original"]
PIXELFX_REQUIRED = ["origin", "effect_id", "category", "source_path", "upstream_repo", "upstream_commit"]

ENTRY_KEY_ORDER = [
    "id", "type", "name", "entity_id", "tier", "legacy_asset_id", "provider", "status", "acceptance",
    "accepted_on", "accepted_by", "accepted_evidence", "approved_on", "approved_by",
    "approved_evidence", "attention", "spec", "reference", "production", "source",
    "candidates", "evidence", "frame", "palette", "pixellab", "pixelfx", "generation", "manifest",
    "index_entry", "qa", "clips", "versions", "history", "notes",
]
CLIP_KEY_ORDER = [
    "name", "frames", "loop", "ms", "source_dir", "status", "acceptance", "accepted_on",
    "accepted_by", "accepted_evidence", "approved_on", "approved_by", "approved_evidence",
    "attention", "generation", "note",
]


# ─── YAML subset reader ──────────────────────────────────────────────────────
class YamlError(Exception):
    pass


_SCALAR_INT = re.compile(r"^-?\d+$")
_SCALAR_FLOAT = re.compile(r"^-?\d+\.\d+$")


def _parse_scalar(text: str):
    text = text.strip()
    if text == "" or text == "~" or text == "null":
        return None
    if text == "true":
        return True
    if text == "false":
        return False
    if text == "[]":
        return []
    if text == "{}":
        return {}
    if text[0] == '"':
        return json.loads(text)
    if text[0] == "'":
        if not text.endswith("'"):
            raise YamlError("unterminated single-quoted string: %s" % text)
        return text[1:-1].replace("''", "'")
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        if not inner:
            return []
        return [_parse_scalar(p) for p in _split_flow(inner)]
    if _SCALAR_INT.match(text):
        return int(text)
    if _SCALAR_FLOAT.match(text):
        return float(text)
    return text


def _split_flow(inner: str):
    parts, depth, cur, quote = [], 0, "", None
    for ch in inner:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            cur += ch
        elif ch == "[":
            depth += 1
            cur += ch
        elif ch == "]":
            depth -= 1
            cur += ch
        elif ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return parts


def _strip_comment(line: str) -> str:
    """Remove a trailing ` # comment` outside quotes."""
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote and (quote != '"' or line[i - 1] != "\\"):
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i].rstrip()
    return line.rstrip()


def _split_key(line: str):
    """Split `key: value` outside quotes; returns (key, value) or None."""
    quote = None
    escaped = False
    for i, ch in enumerate(line):
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\" and quote == '"':
                escaped = True
            elif ch == quote:
                quote = None
        elif ch in "\"'" and i == 0:
            quote = ch
        elif ch == ":" and (i + 1 == len(line) or line[i + 1] == " "):
            key = line[:i].strip()
            if key.startswith('"') or key.startswith("'"):
                key = _parse_scalar(key)
            return key, line[i + 1:].strip()
    return None


def yaml_load(text: str):
    lines = []
    for raw in text.splitlines():
        line = _strip_comment(raw.rstrip("\r"))
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        lines.append((indent, line.strip()))
    pos = [0]

    def parse_block(indent):
        if pos[0] >= len(lines):
            return None
        ind, content = lines[pos[0]]
        if ind < indent:
            return None
        if content.startswith("- ") or content == "-":
            return parse_list(ind)
        return parse_map(ind)

    def parse_map(indent):
        result = {}
        while pos[0] < len(lines):
            ind, content = lines[pos[0]]
            if ind < indent:
                break
            if ind > indent:
                raise YamlError("unexpected indent at line: %s" % content)
            if content.startswith("- "):
                break
            kv = _split_key(content)
            if kv is None:
                raise YamlError("expected `key: value`, got: %s" % content)
            key, value = kv
            if key in result:
                raise YamlError("duplicate key %r in mapping" % key)
            pos[0] += 1
            if value == "":
                nxt = lines[pos[0]] if pos[0] < len(lines) else None
                if nxt and (nxt[0] > indent or (nxt[0] == indent and nxt[1].startswith("- "))):
                    result[key] = parse_block(nxt[0]) if nxt[0] > indent else parse_list(indent)
                else:
                    result[key] = None
            else:
                result[key] = _parse_scalar(value)
        return result

    def parse_list(indent):
        result = []
        while pos[0] < len(lines):
            ind, content = lines[pos[0]]
            if ind != indent or not (content.startswith("- ") or content == "-"):
                break
            item = content[2:].strip() if content != "-" else ""
            pos[0] += 1
            if item == "":
                nxt = lines[pos[0]] if pos[0] < len(lines) else None
                result.append(parse_block(nxt[0]) if nxt and nxt[0] > indent else None)
            elif not item.startswith(("'", '"', "[")) and _split_key(item) is not None:
                # inline mapping start: "- key: value" then deeper keys at indent+2
                key, value = _split_key(item)
                child_indent = indent + 2
                lines.insert(pos[0], (child_indent, item))
                result.append(parse_map(child_indent))
            else:
                result.append(_parse_scalar(item))
        return result

    data = parse_block(0) if lines else {}
    if pos[0] != len(lines):
        raise YamlError("could not parse near: %s" % lines[pos[0]][1])
    return data


# ─── YAML subset writer ──────────────────────────────────────────────────────
_PLAIN_OK = re.compile(r"^[A-Za-z_][A-Za-z0-9_./+\-]*$")


def _dump_scalar(v) -> str:
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int) and not isinstance(v, bool):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    s = str(v)
    if _PLAIN_OK.match(s) and s not in ("null", "true", "false", "~") and not _SCALAR_INT.match(s):
        return s
    return json.dumps(s, ensure_ascii=False)


def _is_simple_list(v) -> bool:
    return isinstance(v, list) and all(
        x is None or isinstance(x, (str, int, float, bool)) for x in v
    ) and len(v) <= 12 and sum(len(str(x)) for x in v) < 90


def yaml_dump(data, indent=0, key_order=None) -> str:
    out = []
    pad = " " * indent
    if isinstance(data, dict):
        keys = list(data.keys())
        if key_order:
            keys = [k for k in key_order if k in data] + [k for k in keys if k not in key_order]
        for k in keys:
            v = data[k]
            ks = _dump_scalar(k) if not isinstance(k, str) else (k if _PLAIN_OK.match(k) else json.dumps(k))
            if isinstance(v, dict):
                if not v:
                    out.append("%s%s: {}" % (pad, ks))
                else:
                    out.append("%s%s:" % (pad, ks))
                    sub_order = CLIP_KEY_ORDER if k == "clips" else None
                    out.append(yaml_dump(v, indent + 2, sub_order))
            elif isinstance(v, list):
                if not v:
                    out.append("%s%s: []" % (pad, ks))
                elif _is_simple_list(v):
                    out.append("%s%s: [%s]" % (pad, ks, ", ".join(_dump_scalar(x) for x in v)))
                else:
                    out.append("%s%s:" % (pad, ks))
                    sub_order = CLIP_KEY_ORDER if k == "clips" else (ENTRY_KEY_ORDER if k == "assets" else None)
                    out.append(yaml_dump(v, indent, sub_order))
            else:
                out.append("%s%s: %s" % (pad, ks, _dump_scalar(v)))
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                body = yaml_dump(item, indent + 2, key_order).split("\n")
                if body and body[0]:
                    out.append("%s- %s" % (pad, body[0][indent + 2:]))
                    out.extend(body[1:])
                else:
                    out.append("%s- {}" % pad)
            elif isinstance(item, list):
                out.append("%s-" % pad)
                out.append(yaml_dump(item, indent + 2))
            else:
                out.append("%s- %s" % (pad, _dump_scalar(item)))
    else:
        out.append(pad + _dump_scalar(data))
    return "\n".join(x for x in out if x != "")


HEADER = """# Asset Registry — single source of truth for art asset lifecycle (P0, 2026-11-11).
#
# RULES:
#   - Edit with tools/asset-pipeline/asset_registry.py or by hand in this exact
#     YAML subset (2-space indent, no anchors, no multi-line scalars). Run
#     `python -X utf8 -I tools/asset-pipeline/asset_registry.py check` after every edit.
#   - Never delete an entry: set status: legacy and record a version_retired event.
#   - status is where the asset IS (candidate | accepted | installed | approved |
#     legacy). acceptance is what the USER said about it (unknown | pending |
#     accepted | rejected). "installed" means the file sits under assets/art/;
#     it is NOT approval. Only the user grants accepted / approved, and every
#     such field carries the file + quote that records their word (evidence).
#     An asset nobody recorded as approved stays acceptance: unknown — never
#     guess.
#   - Unknown facts stay null or "unknown". Never invent PixelLab ids, dates
#     or approvals.
#   - legacy_asset_id keeps the old ASSET-NNN number from the 2026-10-31 manifest
#     and the spec headers (ASSET-020 is used twice there: Chill overlay and
#     Forest Witch). Registry ids are the stable keys.
#   - provider names who made the asset (pixellab | pixelfx | fx-pipeline |
#     script | hand | data | mixed | unknown); `providers` at the top records
#     each tool's version and source. A pixelfx asset carries a `pixelfx` block
#     (origin upstream | adapted | original, effect_id, category, source_path,
#     upstream_repo, upstream_commit, seed, options, palette, adapter_version,
#     attribution) so an adapted upstream effect is never passed off as original.
#   - design/assets/asset-manifest.md is GENERATED from this file (`manifest`).
#
# WRITTEN BY: asset_registry.py (bootstrap / set-status), the game-art workflow
#             skills (P2), the user through Claude.
# READ BY:    asset_registry.py check / manifest, /asset-audit, /asset-spec,
#             /pixellab-animation-engineer, the art-director and technical-artist
#             agents, tools/qa/art_check.sh (P3).
#
# SEARCH PATTERNS:
#   One asset:            Grep pattern="^  - id: unit.kiem_si"
#   Everything approved:  Grep pattern="^    status: approved"
#   Needs the user:       Grep pattern="attention:"
#   PixelLab character:   Grep pattern="character_id:"
"""


# ─── IO ───────────────────────────────────────────────────────────────────────
def load_registry(root=ROOT):
    path = os.path.join(root, REGISTRY_PATH)
    with open(path, "r", encoding="utf-8") as fh:
        data = yaml_load(fh.read())
    if not isinstance(data, dict):
        raise YamlError("registry root must be a mapping")
    return data


def save_registry(data, root=ROOT):
    path = os.path.join(root, REGISTRY_PATH)
    top_order = ["schema_version", "updated", "palette", "lifecycle", "providers", "assets", "backlog"]
    text = HEADER + "\n" + yaml_dump(data, 0, top_order) + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def read_json(rel, root=ROOT):
    with open(os.path.join(root, rel), "r", encoding="utf-8") as fh:
        return json.load(fh)


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(33)
    if len(head) < 33 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    w, h = struct.unpack(">II", head[16:24])
    return w, h, head[25]


def rel(path, root=ROOT):
    return os.path.relpath(path, root).replace("\\", "/")


# ─── Validation ──────────────────────────────────────────────────────────────
class Report:
    def __init__(self):
        self.fail, self.warn, self.info = [], [], []

    def f(self, msg):
        self.fail.append(msg)

    def w(self, msg):
        self.warn.append(msg)

    def i(self, msg):
        self.info.append(msg)

    def print(self, title):
        print("== %s ==" % title)
        for m in self.fail:
            print("FAIL  " + m)
        for m in self.warn:
            print("WARN  " + m)
        for m in self.info:
            print("INFO  " + m)
        print("-- %d FAIL, %d WARN, %d INFO" % (len(self.fail), len(self.warn), len(self.info)))
        return 0 if not self.fail else 1


def _check_status_fields(obj, label, rep):
    status = obj.get("status")
    if status not in STATES:
        rep.f("%s: status %r not in %s" % (label, status, STATES))
    acc = obj.get("acceptance", "unknown")
    if acc not in ACCEPTANCE_VALUES:
        rep.f("%s: acceptance %r not in %s" % (label, acc, ACCEPTANCE_VALUES))
    if status == "approved":
        if not obj.get("approved_evidence") or not obj.get("approved_by"):
            rep.f("%s: status approved without approved_by + approved_evidence" % label)
    if acc == "accepted" and not obj.get("accepted_evidence"):
        rep.f("%s: acceptance accepted without accepted_evidence" % label)
    if obj.get("approved_evidence") and status not in ("approved", "legacy"):
        rep.w("%s: has approved_evidence but status is %s" % (label, status))


def validate(data, rep: Report):
    if data.get("schema_version") != SCHEMA_VERSION:
        rep.f("schema_version must be %d" % SCHEMA_VERSION)
    provs = data.get("providers")
    if not isinstance(provs, dict):
        rep.f("providers block missing (tool / version / source per provider)")
    else:
        for name in ("pixellab", "pixelfx", "fx-pipeline"):
            if name not in provs:
                rep.w("providers.%s not described" % name)
    life = data.get("lifecycle") or {}
    if life.get("states") != STATES:
        rep.f("lifecycle.states must equal %s" % STATES)
    if life.get("transitions") != TRANSITIONS:
        rep.f("lifecycle.transitions differ from the tool's table")
    assets = data.get("assets")
    if not isinstance(assets, list):
        rep.f("assets must be a list")
        return
    ids, prods = {}, {}
    for a in assets:
        aid = a.get("id")
        label = "asset %s" % aid
        if not aid or not re.match(r"^[a-z0-9_]+(\.[a-z0-9_]+)+$", str(aid)):
            rep.f("%s: id must look like type.name[.sub]" % label)
        if aid in ids:
            rep.f("%s: duplicate id" % label)
        ids[aid] = a
        if a.get("type") not in TYPES:
            rep.f("%s: type %r not in %s" % (label, a.get("type"), TYPES))
        if a.get("tier") not in TIERS and a.get("tier") is not None:
            rep.f("%s: tier %r not in %s" % (label, a.get("tier"), TIERS))
        if not a.get("name"):
            rep.f("%s: name missing" % label)
        if a.get("provider") not in PROVIDERS:
            rep.f("%s: provider %r not in %s" % (label, a.get("provider"), PROVIDERS))
        pf = a.get("pixelfx")
        if a.get("provider") == "pixelfx" and not isinstance(pf, dict):
            rep.f("%s: provider pixelfx needs a pixelfx block" % label)
        if isinstance(pf, dict):
            for key in PIXELFX_REQUIRED:
                if not pf.get(key):
                    rep.f("%s: pixelfx.%s missing" % (label, key))
            if pf.get("origin") not in PIXELFX_ORIGINS:
                rep.f("%s: pixelfx.origin %r not in %s" % (label, pf.get("origin"), PIXELFX_ORIGINS))
            if pf.get("origin") in ("upstream", "adapted") and not pf.get("attribution"):
                rep.f("%s: pixelfx.origin %s needs attribution (the upstream file's notice)" % (label, pf.get("origin")))
            if a.get("status") in ("installed", "approved") and not pf.get("adapter_version"):
                rep.f("%s: installed pixelfx asset without pixelfx.adapter_version" % label)
        _check_status_fields(a, label, rep)
        for key in ("production", "source", "candidates", "evidence"):
            v = a.get(key)
            if v is not None and not isinstance(v, list):
                rep.f("%s: %s must be a list of paths" % (label, key))
        for p in a.get("production") or []:
            if p in prods and a.get("status") != "legacy" and ids[prods[p]].get("status") != "legacy":
                rep.f("%s: production path %s also claimed by %s" % (label, p, prods[p]))
            prods.setdefault(p, aid)
        for c in a.get("clips") or []:
            if not c.get("name"):
                rep.f("%s: clip without name" % label)
            _check_status_fields(c, "%s clip %s" % (label, c.get("name")), rep)
            if c.get("status") == "approved" and a.get("status") in ("candidate",):
                rep.w("%s clip %s approved while the asset is %s" % (label, c.get("name"), a.get("status")))
        hist = a.get("history") or []
        prev = {}  # chain per target: the asset itself ("") or one clip name
        for ev in hist:
            if ev.get("event") not in EVENTS:
                rep.f("%s: history event %r not in %s" % (label, ev.get("event"), EVENTS))
            if not ev.get("on"):
                rep.f("%s: history event without date" % label)
            frm, to = ev.get("from"), ev.get("to")
            chain = ev.get("clip") or ""
            if to is not None:
                if to not in STATES:
                    rep.f("%s: history to=%r not a state" % (label, to))
                if frm is not None and to not in TRANSITIONS.get(frm, []):
                    rep.f("%s: invalid transition %s -> %s in history" % (label, frm, to))
                if prev.get(chain) is not None and frm is not None and frm != prev[chain]:
                    rep.w("%s%s: history chain broken (%s then from %s)" % (label, (" clip " + chain) if chain else "", prev[chain], frm))
                prev[chain] = to
        if a.get("status") in USER_ONLY_STATES and a.get("acceptance") not in ("accepted",) and a.get("status") == "accepted":
            rep.f("%s: status accepted requires acceptance: accepted" % label)
    for b in data.get("backlog") or []:
        if not b.get("id") or not b.get("required_by"):
            rep.f("backlog entry %r needs id and required_by" % b.get("id"))
        if b.get("id") in ids:
            rep.f("backlog id %s also exists as an asset" % b.get("id"))


# ─── Disk checks ─────────────────────────────────────────────────────────────
def _exists(root, p):
    return os.path.exists(os.path.join(root, p))


def scan_production(root=ROOT):
    """Every PNG / JSON under assets/art (relative, forward slashes)."""
    files = []
    for dp, _dn, fn in os.walk(os.path.join(root, ART_DIR)):
        for f in fn:
            if f.endswith((".png", ".json")):
                files.append(rel(os.path.join(dp, f), root))
    return sorted(files)


def check(data, rep: Report, root=ROOT):
    validate(data, rep)
    assets = data.get("assets") or []
    claimed = set()
    for a in assets:
        aid = a.get("id")
        for key in ("production", "source", "candidates", "evidence"):
            for p in a.get(key) or []:
                if key == "production":
                    claimed.add(p)
                    if os.path.isdir(os.path.join(root, p)):
                        for dp, _dn, fn in os.walk(os.path.join(root, p)):
                            for f in fn:
                                claimed.add(rel(os.path.join(dp, f), root))
                if not _exists(root, p):
                    (rep.f if key == "production" else rep.w)("%s: %s path missing: %s" % (aid, key, p))
        for key in ("spec", "reference"):
            p = a.get(key)
            if p and not _exists(root, p):
                rep.w("%s: %s missing: %s" % (aid, key, p))
        if a.get("type") == "unit":
            _check_unit(a, rep, root)
        if a.get("type") == "vfx_pack":
            _check_pack(a, rep, root)
        if not a.get("spec"):
            rep.i("%s: no spec recorded" % aid)
        if a.get("status") == "installed" and a.get("acceptance") == "unknown":
            rep.i("%s: installed, acceptance unknown (needs the user's word)" % aid)
    # orphans: production art nobody claims
    for f in scan_production(root):
        if f in claimed:
            continue
        if f.endswith(".import"):
            continue
        rep.w("orphan production file (not in registry): %s" % f)


def _check_unit(a, rep, root):
    aid = a.get("id")
    uid = a.get("entity_id")
    clips_path = "art_src/units/%s/clips.json" % uid
    sheet_json = "assets/art/units/unit_%s_sheet.json" % uid
    if not _exists(root, clips_path) or not _exists(root, sheet_json):
        rep.f("%s: clips.json or sheet json missing" % aid)
        return
    clips = read_json(clips_path, root)
    sheet = read_json(sheet_json, root)
    frame = a.get("frame") or {}
    fw, fh = clips["frame"]["w"], clips["frame"]["h"]
    if (frame.get("w"), frame.get("h")) != (fw, fh):
        rep.f("%s: registry frame %sx%s != clips.json %sx%s" % (aid, frame.get("w"), frame.get("h"), fw, fh))
    if frame.get("facing") != clips.get("facing"):
        rep.f("%s: registry facing %r != clips.json %r" % (aid, frame.get("facing"), clips.get("facing")))
    if a.get("legacy_asset_id") != clips.get("asset"):
        rep.w("%s: legacy_asset_id %r != clips.json asset %r" % (aid, a.get("legacy_asset_id"), clips.get("asset")))
    reg_clips = {c["name"]: c for c in a.get("clips") or []}
    src_clips = {c["name"]: c for c in clips["clips"]}
    tags = {t["name"]: t for t in sheet["meta"]["frameTags"]}
    for name, c in src_clips.items():
        if name not in reg_clips:
            rep.f("%s: clip %s in clips.json but not in registry" % (aid, name))
            continue
        if reg_clips[name].get("frames") != len(c["frames"]):
            rep.f("%s: clip %s frames %s != clips.json %d" % (aid, name, reg_clips[name].get("frames"), len(c["frames"])))
        if reg_clips[name].get("loop") != c.get("loop"):
            rep.f("%s: clip %s loop %r != clips.json %r" % (aid, name, reg_clips[name].get("loop"), c.get("loop")))
        if name not in tags:
            rep.f("%s: clip %s not in the exported sheet" % (aid, name))
        elif tags[name]["to"] - tags[name]["from"] + 1 != len(c["frames"]):
            rep.f("%s: clip %s sheet tag length != clips.json" % (aid, name))
    for name in reg_clips:
        if name not in src_clips:
            rep.f("%s: registry clip %s not in clips.json" % (aid, name))
    pal = a.get("palette") or {}
    sheet_pal = sheet["meta"].get("tessera", {}).get("palette")
    if sheet_pal and pal.get("colours") and sorted(pal["colours"]) != sorted(sheet_pal):
        rep.w("%s: registry palette differs from the sheet's meta.tessera.palette" % aid)


def _check_pack(a, rep, root):
    aid = a.get("id")
    prod = a.get("production") or []
    pack_dir = next((p for p in prod if os.path.isdir(os.path.join(root, p))), None)
    if not pack_dir and a.get("status") in ("candidate", "accepted"):
        # not installed yet: the pack lives in its newest candidate folder
        pack_dir = next((p for p in reversed(a.get("candidates") or []) if os.path.isdir(os.path.join(root, p))), None)
    if not pack_dir:
        rep.f("%s: no pack directory in production%s" % (aid, " or candidates" if a.get("status") in ("candidate", "accepted") else ""))
        return
    mpath = os.path.join(root, pack_dir, "manifest.json")
    if not os.path.exists(mpath):
        rep.f("%s: manifest.json missing in %s" % (aid, pack_dir))
        return
    m = read_json(rel(mpath, root), root)
    reg_m = a.get("manifest") or {}
    if reg_m.get("frames") != m.get("frames") or reg_m.get("frame_ms") != m.get("frame_ms"):
        rep.f("%s: registry manifest frames/frame_ms differ from %s/manifest.json" % (aid, pack_dir))
    shipped = {c["name"] for c in m.get("clips", []) if all(
        os.path.exists(os.path.join(root, pack_dir, s.get("file", ""))) for s in c.get("sheets", []))}
    declared = {c["name"] for c in m.get("clips", [])}
    missing = sorted(declared - shipped)
    if missing and sorted(reg_m.get("clips_not_shipped") or []) != missing:
        rep.w("%s: manifest clips without files %s (record them in manifest.clips_not_shipped)" % (aid, missing))


# ─── Bootstrap (skeletons from disk) ─────────────────────────────────────────
def _palette_from_gpl(root=ROOT):
    cols = []
    try:
        with open(os.path.join(root, PALETTE_PATH), "r", encoding="utf-8") as fh:
            for line in fh:
                m = re.match(r"^\s*(\d+)\s+(\d+)\s+(\d+)", line)
                if m:
                    cols.append("#%02X%02X%02X" % tuple(int(x) for x in m.groups()))
    except OSError:
        pass
    return cols


def _base_entry(aid, typ, name):
    return {
        "id": aid, "type": typ, "name": name, "entity_id": None, "tier": "n/a",
        "legacy_asset_id": None, "provider": "unknown", "status": "installed", "acceptance": "unknown",
        "accepted_on": None, "accepted_by": None, "accepted_evidence": None,
        "approved_on": None, "approved_by": None, "approved_evidence": None,
        "attention": None, "spec": None, "reference": None,
        "production": [], "source": [], "candidates": [], "evidence": [],
        "history": [{"on": date.today().isoformat(), "event": "registered",
                     "note": "bootstrapped from disk by asset_registry.py; status by location only"}],
        "notes": [],
    }


def _tier_for(uid, frame_h):
    heroes = {"kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"}
    if uid in heroes:
        return "hero"
    if frame_h >= 120:
        return "boss"
    if frame_h >= 80:
        return "elite"
    return "monster"


def bootstrap_units(root=ROOT):
    entries = []
    udir = os.path.join(root, SRC_DIR)
    for uid in sorted(os.listdir(udir)):
        cpath = os.path.join(udir, uid, "clips.json")
        if not os.path.exists(cpath):
            continue
        clips = read_json(rel(cpath, root), root)
        sheet_png = "assets/art/units/unit_%s_sheet.png" % uid
        sheet_json = "assets/art/units/unit_%s_sheet.json" % uid
        sheet = read_json(sheet_json, root) if _exists(root, sheet_json) else None
        e = _base_entry("unit.%s" % uid, "unit", uid.replace("_", " ").title())
        e["entity_id"] = uid
        e["tier"] = _tier_for(uid, clips["frame"]["h"])
        e["legacy_asset_id"] = clips.get("asset")
        e["production"] = [sheet_png, sheet_json]
        e["source"] = ["art_src/units/%s/clips.json" % uid]
        src_text = clips.get("source") or ""
        m = re.search(r"character ([0-9a-f]{8}(?:-[0-9a-f-]{27})?)", src_text)
        e["pixellab"] = {
            "character_id": m.group(1) if m else None,
            "image_ids": [], "job_ids": sorted(set(re.findall(r"job ([0-9a-f]{8}(?:-[0-9a-f-]{27})?)", src_text))),
            "style_lineage": None,
        }
        e["frame"] = {"w": clips["frame"]["w"], "h": clips["frame"]["h"],
                      "body_h": clips.get("body_h"), "facing": clips.get("facing")}
        e["palette"] = {"file": PALETTE_PATH, "max": 8,
                        "colours": sorted(sheet["meta"]["tessera"].get("palette", [])) if sheet else []}
        e["generation"] = {"source_note": src_text or None}
        cands = sorted(set(re.findall(r"design/assets/candidates/[A-Za-z0-9_\-/.<>]+", src_text)))
        e["candidates"] = [c.replace("/<clip>/<n>.png", "") for c in cands]
        e["clips"] = []
        for c in clips["clips"]:
            ce = {
                "name": c["name"], "frames": len(c["frames"]), "loop": c.get("loop"),
                "ms": c["ms"], "source_dir": "art_src/units/%s/%s" % (uid, c["name"]),
                "status": "installed", "acceptance": "unknown",
                "accepted_on": None, "accepted_by": None, "accepted_evidence": None,
                "approved_on": None, "approved_by": None, "approved_evidence": None,
                "attention": None, "generation": None, "note": c.get("note"),
            }
            e["clips"].append(ce)
        for k, v in clips.items():
            if k.startswith("_doc"):
                e["notes"].append("%s: %s" % (k, v))
        entries.append(e)
    return entries


def bootstrap_packs(root=ROOT):
    entries = []
    for kind in ("cast", "floor", "status"):
        kdir = os.path.join(root, ART_DIR, "vfx", kind)
        if not os.path.isdir(kdir):
            continue
        index = read_json("assets/art/vfx/%s/index.json" % kind, root)
        for pack in sorted(os.listdir(kdir)):
            pdir = os.path.join(kdir, pack)
            mpath = os.path.join(pdir, "manifest.json")
            if not os.path.isdir(pdir) or not os.path.exists(mpath):
                continue
            m = read_json(rel(mpath, root), root)
            e = _base_entry("vfx.%s.%s" % (kind, pack), "vfx_pack", m.get("name") or pack)
            e["production"] = ["assets/art/vfx/%s/%s" % (kind, pack)]
            shipped, not_shipped = [], []
            for c in m.get("clips", []):
                ok = all(os.path.exists(os.path.join(pdir, s.get("file", ""))) for s in c.get("sheets", []))
                (shipped if ok else not_shipped).append(c["name"])
            e["manifest"] = {
                "app": m.get("app"), "frames": m.get("frames"), "frame_ms": m.get("frame_ms"),
                "loop": m.get("loop"), "canvas": [m.get("canvas", {}).get("w"), m.get("canvas", {}).get("h")],
                "anchor": [m.get("anchor", {}).get("kind"), m.get("anchor", {}).get("x"), m.get("anchor", {}).get("y")],
                "clips_shipped": shipped, "clips_not_shipped": not_shipped,
            }
            tess = m.get("tessera") or {}
            if tess:
                e["generation"] = {"tool": "tools/fx-pipeline", "recipe": tess.get("recipe"),
                                   "component": tess.get("component"), "material": tess.get("material"),
                                   "cell": tess.get("cell")}
            else:
                e["generation"] = {"tool": m.get("app"), "source": m.get("source")}
            entry = None
            if kind == "status":
                for kname, sides in index.items():
                    for side, d in sides.items():
                        if d == pack:
                            entry = {"index": "assets/art/vfx/status/index.json", "key": "%s.%s" % (kname, side)}
            elif kind == "floor":
                if pack in (index.get("packs") or {}):
                    entry = {"index": "assets/art/vfx/floor/index.json", "key": "packs.%s" % pack}
            else:
                for pname, pd in (index.get("packs") or {}).items():
                    if pd.get("dir") == pack:
                        entry = {"index": "assets/art/vfx/cast/index.json", "key": "packs.%s" % pname}
            e["index_entry"] = entry
            if entry is None:
                e["notes"].append("not referenced by its index.json")
            entries.append(e)
    return entries


def bootstrap_files(root=ROOT):
    """Env, UI, cards, loose textures: one entry per file (grouped later by hand)."""
    entries = []
    for f in scan_production(root):
        if f.startswith(("assets/art/units/", "assets/art/vfx/cast/", "assets/art/vfx/floor/", "assets/art/vfx/status/")):
            continue
        if f.endswith(".json"):
            continue
        name = os.path.splitext(os.path.basename(f))[0]
        if f.startswith("assets/art/env/"):
            region = f.split("/")[3]
            e = _base_entry("env.%s.%s" % (region, name), "env", name)
            e["entity_id"] = region
        elif f.startswith("assets/art/cards/"):
            e = _base_entry("card.%s" % name, "card", name)
            e["entity_id"] = name
        elif f.startswith("assets/art/ui/"):
            group = f.split("/")[3] if f.count("/") >= 4 else "root"
            e = _base_entry("ui.%s.%s" % (group, name), "ui", name)
        else:
            e = _base_entry("texture.%s" % name, "texture", name)
        e["production"] = [f]
        size = png_size(os.path.join(root, f))
        if size:
            e["frame"] = {"w": size[0], "h": size[1], "colour_type": size[2]}
        entries.append(e)
    return entries


def bootstrap(data, root=ROOT):
    have = {a["id"] for a in data.get("assets") or []}
    claimed = set()
    for a in data.get("assets") or []:
        for p in a.get("production") or []:
            claimed.add(p)
            if os.path.isdir(os.path.join(root, p)):
                for dp, _dn, fn in os.walk(os.path.join(root, p)):
                    for f in fn:
                        claimed.add(rel(os.path.join(dp, f), root))
    new = []
    for e in bootstrap_units(root) + bootstrap_packs(root) + bootstrap_files(root):
        if e["id"] in have:
            continue
        if all(p in claimed for p in e["production"]):
            continue
        new.append(e)
    return new


# ─── Manifest ────────────────────────────────────────────────────────────────
TYPE_TITLES = [("unit", "Units (heroes, enemies, bosses)"), ("vfx_pack", "VFX packs"),
               ("env", "Environment"), ("ui", "UI"), ("card", "Card art"),
               ("portrait", "Portraits"), ("texture", "Loose textures"), ("other", "Other")]


def _md(s):
    if s is None:
        return "—"
    return str(s).replace("|", "\\|").replace("\n", " ")


def render_manifest(data):
    assets = data.get("assets") or []
    counts = {s: 0 for s in STATES}
    acc = {v: 0 for v in ACCEPTANCE_VALUES}
    for a in assets:
        counts[a.get("status")] = counts.get(a.get("status"), 0) + 1
        acc[a.get("acceptance", "unknown")] = acc.get(a.get("acceptance", "unknown"), 0) + 1
    out = []
    out.append("# Asset Manifest (GENERATED)")
    out.append("")
    out.append("> **Generated** from `design/assets/asset-registry.yaml` by "
               "`python -X utf8 -I tools/asset-pipeline/asset_registry.py manifest` on %s. "
               "Do not edit by hand — edit the registry and regenerate. The previous hand-written "
               "manifest (2026-10-31) is archived as `asset-manifest-2026-10-31-archive.md`." % date.today().isoformat())
    out.append("")
    out.append("Lifecycle: `candidate → accepted → installed → approved`; `legacy` = replaced. "
               "**installed is not approved**: `Accepted` / `Approved` columns show what the user "
               "recorded; `unknown` means no record exists.")
    out.append("")
    out.append("## Summary")
    out.append("")
    out.append("| Total | " + " | ".join(s.title() for s in STATES) + " |")
    out.append("|---|" + "---|" * len(STATES))
    out.append("| %d | " % len(assets) + " | ".join(str(counts[s]) for s in STATES) + " |")
    out.append("")
    out.append("Acceptance recorded: " + ", ".join("%s %d" % (k, v) for k, v in acc.items()) + ".")
    attention = [(a["id"], a.get("attention")) for a in assets if a.get("attention")]
    for a in assets:
        for c in a.get("clips") or []:
            if c.get("attention"):
                attention.append(("%s / %s" % (a["id"], c["name"]), c["attention"]))
    if attention:
        out.append("")
        out.append("## Needs the user's decision")
        out.append("")
        out.append("| Asset | Open point |")
        out.append("|---|---|")
        for aid, att in attention:
            out.append("| `%s` | %s |" % (aid, _md(att)))
    for typ, title in TYPE_TITLES:
        rows = [a for a in assets if a.get("type") == typ]
        if not rows:
            continue
        out.append("")
        out.append("## %s" % title)
        out.append("")
        if typ == "unit":
            out.append("| Registry id | Legacy id | Tier | Frame | Facing | Status | Accepted | Approved | Clips (status) | Spec |")
            out.append("|---|---|---|---|---|---|---|---|---|---|")
            for a in rows:
                fr = a.get("frame") or {}
                clips = ", ".join("%s %d%s" % (c["name"], c.get("frames") or 0, _clip_mark(c)) for c in a.get("clips") or [])
                out.append("| `%s` | %s | %s | %sx%s | %s | **%s** | %s | %s | %s | %s |" % (
                    a["id"], _md(a.get("legacy_asset_id")), _md(a.get("tier")), fr.get("w"), fr.get("h"),
                    _md(fr.get("facing")), a.get("status"), _acc(a), _appr(a), clips, _link(a.get("spec"))))
            out.append("")
            out.append("Clip marks: `*` approved by the user, `+` accepted, `?` acceptance unknown, `!` needs a decision.")
        elif typ == "vfx_pack":
            out.append("| Registry id | Index | Frames × ms | Canvas | Provider | Status | Accepted | Approved | Note |")
            out.append("|---|---|---|---|---|---|---|---|---|")
            for a in rows:
                m = a.get("manifest") or {}
                ie = a.get("index_entry") or {}
                pf = a.get("pixelfx") or {}
                prov = a.get("provider") or "unknown"
                if pf:
                    prov += " (%s %s)" % (pf.get("origin"), pf.get("effect_id"))
                out.append("| `%s` | %s | %s × %s | %sx%s | %s | **%s** | %s | %s | %s |" % (
                    a["id"], _md(ie.get("key")), m.get("frames"), m.get("frame_ms"),
                    (m.get("canvas") or [None, None])[0], (m.get("canvas") or [None, None])[1],
                    _md(prov), a.get("status"), _acc(a), _appr(a),
                    _md("; ".join(a.get("notes") or []))))
        else:
            out.append("| Registry id | Name | File(s) | Size | Status | Accepted | Approved | Spec | Note |")
            out.append("|---|---|---|---|---|---|---|---|---|")
            for a in rows:
                fr = a.get("frame") or {}
                size = "%sx%s" % (fr.get("w"), fr.get("h")) if fr.get("w") else "—"
                out.append("| `%s` | %s | %s | %s | **%s** | %s | %s | %s | %s |" % (
                    a["id"], _md(a.get("name")), ", ".join("`%s`" % p for p in a.get("production") or []),
                    size, a.get("status"), _acc(a), _appr(a), _link(a.get("spec")),
                    _md("; ".join(a.get("notes") or []))))
    backlog = data.get("backlog") or []
    if backlog:
        out.append("")
        out.append("## Backlog — required, no production file yet")
        out.append("")
        out.append("| Id | What | Required by | Note |")
        out.append("|---|---|---|---|")
        for b in backlog:
            out.append("| `%s` | %s | %s | %s |" % (b["id"], _md(b.get("name")), _md(b.get("required_by")), _md(b.get("note"))))
    out.append("")
    return "\n".join(out)


def _clip_mark(c):
    if c.get("attention"):
        return "!"
    if c.get("status") == "approved":
        return "*"
    if c.get("acceptance") == "accepted":
        return "+"
    return "?"


def _acc(a):
    if a.get("acceptance") == "accepted":
        return "yes %s" % (a.get("accepted_on") or "")
    return a.get("acceptance") or "unknown"


def _appr(a):
    if a.get("status") == "approved":
        return "yes %s" % (a.get("approved_on") or "")
    return "no record" if not a.get("approved_evidence") else "see evidence"


def _link(p):
    return "`%s`" % p if p else "—"


# ─── set-status ──────────────────────────────────────────────────────────────
def set_status(data, aid, state, clip=None, on=None, by=None, evidence=None, note=None):
    if state not in STATES:
        raise SystemExit("state must be one of %s" % STATES)
    target_asset = next((a for a in data["assets"] if a["id"] == aid), None)
    if target_asset is None:
        raise SystemExit("unknown asset id %s" % aid)
    target = target_asset
    if clip:
        target = next((c for c in target_asset.get("clips") or [] if c["name"] == clip), None)
        if target is None:
            raise SystemExit("unknown clip %s on %s" % (clip, aid))
    cur = target.get("status")
    if state not in TRANSITIONS.get(cur, []):
        raise SystemExit("invalid transition %s -> %s (allowed: %s)" % (cur, state, TRANSITIONS.get(cur)))
    if state in USER_ONLY_STATES:
        if by != "user" or not evidence:
            raise SystemExit("%s needs --by user and --evidence (the file + the user's words)" % state)
    on = on or date.today().isoformat()
    target["status"] = state
    event = {"candidate": "candidate_created", "accepted": "user_accepted", "installed": "integration_completed",
             "approved": "user_approved", "legacy": "version_retired"}[state]
    if state == "accepted":
        target["acceptance"] = "accepted"
        target["accepted_on"], target["accepted_by"], target["accepted_evidence"] = on, by, evidence
    if state == "approved":
        target["approved_on"], target["approved_by"], target["approved_evidence"] = on, by, evidence
    ev = {"on": on, "event": event, "from": cur, "to": state}
    if clip:
        ev["clip"] = clip
    if by:
        ev["by"] = by
    if evidence:
        ev["evidence"] = evidence
    if note:
        ev["note"] = note
    target_asset.setdefault("history", []).append(ev)
    data["updated"] = on


def set_acceptance(data, aid, value, clip=None, on=None, by=None, evidence=None, note=None):
    if value not in ACCEPTANCE_VALUES:
        raise SystemExit("acceptance must be one of %s" % ACCEPTANCE_VALUES)
    target_asset = next((a for a in data["assets"] if a["id"] == aid), None)
    if target_asset is None:
        raise SystemExit("unknown asset id %s" % aid)
    target = target_asset
    if clip:
        target = next((c for c in target_asset.get("clips") or [] if c["name"] == clip), None)
        if target is None:
            raise SystemExit("unknown clip %s on %s" % (clip, aid))
    if value in ("accepted", "rejected") and (by != "user" or not evidence):
        raise SystemExit("%s needs --by user and --evidence (the file + the user's words)" % value)
    on = on or date.today().isoformat()
    target["acceptance"] = value
    if value == "accepted":
        target["accepted_on"], target["accepted_by"], target["accepted_evidence"] = on, by, evidence
    ev = {"on": on, "event": {"accepted": "user_accepted", "rejected": "candidate_rejected"}.get(value, "note")}
    if clip:
        ev["clip"] = clip
    if by:
        ev["by"] = by
    if evidence:
        ev["evidence"] = evidence
    ev["note"] = note or ("acceptance set to %s" % value)
    target_asset.setdefault("history", []).append(ev)
    data["updated"] = on


def log_event(data, aid, event, clip=None, on=None, by=None, evidence=None, note=None, candidate=None, job_id=None):
    if event not in EVENTS:
        raise SystemExit("event must be one of %s" % EVENTS)
    if event in ("user_accepted", "user_approved", "integration_completed", "version_retired"):
        raise SystemExit("%s changes state: use set-status / set-acceptance" % event)
    a = next((x for x in data["assets"] if x["id"] == aid), None)
    if a is None:
        raise SystemExit("unknown asset id %s" % aid)
    if clip and not any(c["name"] == clip for c in a.get("clips") or []):
        raise SystemExit("unknown clip %s on %s" % (clip, aid))
    on = on or date.today().isoformat()
    ev = {"on": on, "event": event}
    if clip:
        ev["clip"] = clip
    if by:
        ev["by"] = by
    if evidence:
        ev["evidence"] = evidence
    if job_id:
        ev["job_id"] = job_id
    if candidate:
        ev["candidate"] = candidate
        cands = a.setdefault("candidates", [])
        if candidate not in cands:
            cands.append(candidate)
    if note:
        ev["note"] = note
    a.setdefault("history", []).append(ev)
    data["updated"] = on


# ─── CLI ─────────────────────────────────────────────────────────────────────
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=ROOT)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("validate")
    sub.add_parser("check")
    sub.add_parser("manifest")
    b = sub.add_parser("bootstrap")
    b.add_argument("--add-missing", action="store_true")
    s = sub.add_parser("set-status")
    s.add_argument("id")
    s.add_argument("state")
    s.add_argument("--clip")
    s.add_argument("--on")
    s.add_argument("--by")
    s.add_argument("--evidence")
    s.add_argument("--note")
    sa = sub.add_parser("set-acceptance")
    sa.add_argument("id")
    sa.add_argument("value")
    sa.add_argument("--clip")
    sa.add_argument("--on")
    sa.add_argument("--by")
    sa.add_argument("--evidence")
    sa.add_argument("--note")
    sp = sub.add_parser("set-production")
    sp.add_argument("id")
    sp.add_argument("paths", nargs="+")
    le = sub.add_parser("log-event")
    le.add_argument("id")
    le.add_argument("event")
    le.add_argument("--clip")
    le.add_argument("--on")
    le.add_argument("--by")
    le.add_argument("--evidence")
    le.add_argument("--note")
    le.add_argument("--candidate")
    le.add_argument("--job-id")
    sh = sub.add_parser("show")
    sh.add_argument("id")
    ej = sub.add_parser("export-json")
    ej.add_argument("path", nargs="?")
    args = ap.parse_args(argv)
    root = args.root

    if args.cmd == "bootstrap" and not os.path.exists(os.path.join(root, REGISTRY_PATH)):
        data = {"schema_version": SCHEMA_VERSION, "updated": date.today().isoformat(),
                "palette": {"file": PALETTE_PATH, "colours": _palette_from_gpl(root)},
                "lifecycle": {"states": STATES, "transitions": TRANSITIONS,
                              "user_only": sorted(USER_ONLY_STATES), "events": EVENTS},
                "assets": [], "backlog": []}
    else:
        try:
            data = load_registry(root)
        except (OSError, YamlError) as exc:
            print("FAIL  cannot read %s: %s" % (REGISTRY_PATH, exc))
            return 1

    if args.cmd == "validate":
        rep = Report()
        validate(data, rep)
        return rep.print("validate %s" % REGISTRY_PATH)
    if args.cmd == "check":
        rep = Report()
        check(data, rep, root)
        return rep.print("check %s" % REGISTRY_PATH)
    if args.cmd == "manifest":
        text = render_manifest(data)
        with open(os.path.join(root, MANIFEST_PATH), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        print("wrote %s (%d assets, %d backlog)" % (MANIFEST_PATH, len(data.get("assets") or []), len(data.get("backlog") or [])))
        return 0
    if args.cmd == "bootstrap":
        new = bootstrap(data, root)
        if args.add_missing:
            data.setdefault("assets", []).extend(new)
            data["updated"] = date.today().isoformat()
            save_registry(data, root)
            print("added %d entries to %s" % (len(new), REGISTRY_PATH))
        else:
            print(yaml_dump({"assets": new}, 0))
            print("# %d entries not in the registry" % len(new))
        return 0
    if args.cmd == "set-status":
        set_status(data, args.id, args.state, args.clip, args.on, args.by, args.evidence, args.note)
        save_registry(data, root)
        print("%s%s -> %s" % (args.id, (" / " + args.clip) if args.clip else "", args.state))
        return 0
    if args.cmd == "set-acceptance":
        set_acceptance(data, args.id, args.value, args.clip, args.on, args.by, args.evidence, args.note)
        save_registry(data, root)
        print("%s%s acceptance -> %s" % (args.id, (" / " + args.clip) if args.clip else "", args.value))
        return 0
    if args.cmd == "set-production":
        a = next((x for x in data.get("assets") or [] if x["id"] == args.id), None)
        if a is None:
            print("unknown id %s" % args.id)
            return 1
        prod = a.setdefault("production", [])
        for p in args.paths:
            p = p.replace("\\", "/")
            if p not in prod:
                prod.append(p)
        data["updated"] = date.today().isoformat()
        save_registry(data, root)
        print("%s production: %s" % (args.id, prod))
        return 0
    if args.cmd == "log-event":
        log_event(data, args.id, args.event, args.clip, args.on, args.by, args.evidence, args.note, args.candidate, args.job_id)
        save_registry(data, root)
        print("%s%s: %s logged" % (args.id, (" / " + args.clip) if args.clip else "", args.event))
        return 0
    if args.cmd == "show":
        a = next((x for x in data.get("assets") or [] if x["id"] == args.id), None)
        if a is None:
            print("unknown id %s" % args.id)
            return 1
        print(yaml_dump(a, 0, ENTRY_KEY_ORDER))
        return 0
    if args.cmd == "export-json":
        path = args.path or os.path.join(root, "design", "assets", "asset-registry.json")
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=1)
        print("wrote %s" % path)
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
