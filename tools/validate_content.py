#!/usr/bin/env python3
"""데이터 원장 무결성 검사 — data/core·data/content 의 id·참조·범위를 검사한다.

  python3 tools/validate_content.py        # errors=0 이면 종료 코드 0
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

D = Path(__file__).resolve().parents[1] / "data"
MERC_PICK = {"favorite", "rotate", "weakest_point"}
BOON_KEYS = {"castle_hp", "income", "worker_cost", "slots", "blocked_packs_per_captive", "merc_cost", "chapter_gold",
             "beats", "upgrade_cost", "first_hit_bonus"}


def load(rel):
    return json.loads((D / rel).read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    rules = load("core/rules.json")
    fams = load("content/units.json")["families"]
    mercs = load("content/mercenaries.json")["mercenaries"]
    cmds = load("content/commanders.json")["commanders"]
    draft = load("content/draft.json")
    run, cmb, cmd = rules["run"], rules["combat"], rules["commander"]
    attacks, armors = cmb["attack_types"], cmb["armor_types"]

    def dup(items, key, label):
        for k, v in Counter(i[key] for i in items).items():
            if v > 1:
                errors.append(f"{label} {key} 중복 {k}")

    # 규칙 상수
    n = run["chapters"]
    for key in ("castle_hp", "income_pct", "start_defense_budget", "start_workers"):
        if len(cmd[key]) != n:
            errors.append(f"commander.{key} 길이는 장 수 {n} 와 같아야 한다")
    if len(run["timeout_castle_damage"]) != n:
        errors.append("run.timeout_castle_damage 길이는 장 수와 같아야 한다")
    if len(rules["waves"]["pattern"]) != run["rounds_per_chapter"]:
        errors.append("waves.pattern 길이는 장의 판 수와 같아야 한다")
    if not cmb["mult_weak"] < cmb["mult_neutral"] < cmb["mult_strong"]:
        errors.append("상성 배율은 weak < neutral < strong")
    for table in ("strong_against", "weak_against"):
        if set(cmb[table]) != set(attacks) or sorted(cmb[table].values()) != sorted(armors):
            errors.append(f"combat.{table} 는 공격 속성마다 서로 다른 방어 속성 하나씩이어야 한다")
    for a in attacks:
        if cmb["strong_against"].get(a) == cmb["weak_against"].get(a):
            errors.append(f"{a}: 강한 상대와 약한 상대가 같다")
    if max(run["timeout_castle_damage"]) >= run["player_castle_hp"]:
        errors.append("시간 초과 피해가 성 체력 이상이면 버티기가 불가능하다")

    # 유닛
    dup(fams, "id", "유닛")
    dup(fams, "name_ko", "유닛")
    if sorted(f["attack"] for f in fams) != sorted(attacks):
        errors.append("계열마다 공격 속성이 하나씩이어야 한다")
    for f in fams:
        if f["mode"] not in ("single", "splash") or f["hits"] < 1 or f["targets"] < 1:
            errors.append(f"{f['id']}: mode/hits/targets 오류")
        if [t["tier"] for t in f["tiers"]] != [1, 2, 3]:
            errors.append(f"{f['id']}: 단계는 1,2,3")
        dmg = [t["damage"] for t in f["tiers"]]
        if dmg != sorted(dmg) or len(set(dmg)) != 3 or min(t["cost"] for t in f["tiers"]) <= 0:
            errors.append(f"{f['id']}: 피해는 단계마다 커져야 하고 값은 양수")
        # 금화당 피해가 단계가 오를수록 나빠지지 않는다(자리 압박의 보상)
        spent, eff = 0, []
        for t in f["tiers"]:
            spent += t["cost"]
            eff.append(t["damage"] * f["hits"] * f["targets"] / spent)
        if eff != sorted(eff):
            errors.append(f"{f['id']}: 누적 금화당 피해가 단계가 오를수록 줄어든다 {eff}")

    # 용병
    dup(mercs, "id", "용병")
    dup(mercs, "name_ko", "용병")
    if Counter((m["armor"], m["form"]) for m in mercs) != Counter((a, f) for a in armors for f in ("swarm", "elite")):
        errors.append("용병은 방어 속성 × 형태(swarm, elite) 조합이 하나씩이어야 한다")
    for m in mercs:
        if m["id"] != f"m_{m['armor']}_{m['form']}":
            errors.append(f"{m['id']}: id 규칙 m_<armor>_<form>")
        if min(m["count"], m["hp"], m["leak"], m["cost"]) <= 0:
            errors.append(f"{m['id']}: 양수 아님")

    # 지휘관
    dup(cmds, "id", "지휘관")
    dup(cmds, "name_ko", "지휘관")
    for c in cmds:
        if c["merc_pick"] not in MERC_PICK:
            errors.append(f"{c['id']}: merc_pick {c['merc_pick']}")
        splits = [c["split"]["default"]] + list(c["split"].get("rounds", {}).values())
        if "after_damage" in c["split"]:
            splits.append(c["split"]["after_damage"])
        for s in splits:
            if len(s) != 3 or sum(s) != 100 or min(s) < 0:
                errors.append(f"{c['id']}: split 은 [방어, 일꾼, 용병] 합 100 — {s}")
        for k in c["split"].get("rounds", {}):
            if not 0 <= int(k) < run["rounds_per_chapter"]:
                errors.append(f"{c['id']}: rounds 키 {k}")

    # 보상과 편성
    dup(draft["boons"], "id", "증표")
    dup(draft["boons"], "name_ko", "증표")
    for b in draft["boons"]:
        if not set(b["effect"]) <= BOON_KEYS:
            errors.append(f"{b['id']}: 모르는 효과 {set(b['effect']) - BOON_KEYS}")
    fam_ids, merc_ids = {f["id"] for f in fams}, {m["id"] for m in mercs}
    dup(draft["presets"], "id", "편성")
    for p in draft["presets"]:
        if not set(p["families"]) <= fam_ids or not set(p["mercs"]) <= merc_ids:
            errors.append(f"{p['id']}: 없는 계열·용병 참조")
        if len(p["families"]) != 2 or len(p["mercs"]) != 2:
            errors.append(f"{p['id']}: 시작 편성은 계열 2 + 용병 2")
    if not any(p["unlock"]["medals"] == 0 for p in draft["presets"]):
        errors.append("처음부터 열린 편성이 하나는 있어야 한다")
    pool = (len(fams) - 2) + (len(mercs) - 2) + len(draft["boons"])
    if pool < run["draft_choices"] * (n - 1):
        errors.append("장 보상 후보가 부족하다")

    for e in errors:
        print("[ERROR]", e)
    print(f"{'FAIL' if errors else 'PASS'}: errors={len(errors)} "
          f"(계열 {len(fams)}, 용병 {len(mercs)}, 지휘관 {len(cmds)}, 증표 {len(draft['boons'])}, 편성 {len(draft['presets'])})")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
