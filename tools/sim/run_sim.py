#!/usr/bin/env python3
"""send-lane-duel 규칙 시뮬레이터 — data/ 의 원장을 그대로 실행하는 결정론 코어.

  python3 -I sim/run_sim.py --self-test                    # 규칙 벡터 검사
  python3 -I sim/run_sim.py --runs 400                     # 봇별 완주율·지휘관별 실패율·검산 질문
  python3 -I sim/run_sim.py --vectors sim/out/vectors.json # 구현체 교차 검증 벡터
  python3 -I sim/run_sim.py --runs 400 --json sim/out/run_sim.json

규칙의 원장은 docs/game-design/02-gdd.md 와 data/core/rules.json 이다. 이 파일의 core 부분(Rng ~ Run)은
게임 구현이 그대로 옮겨야 하는 참조 구현이고, bots 부분은 검산용이다.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(rel):
    return json.loads((ROOT / "data" / rel).read_text(encoding="utf-8"))


RULES = _load("core/rules.json")
FAMILIES = {f["id"]: f for f in _load("content/units.json")["families"]}
FAMILY_IDS = list(FAMILIES)
MERCS = {m["id"]: m for m in _load("content/mercenaries.json")["mercenaries"]}
MERC_IDS = list(MERCS)
COMMANDERS = {c["id"]: c for c in _load("content/commanders.json")["commanders"]}
COMMANDER_IDS = list(COMMANDERS)
_DRAFT = _load("content/draft.json")
BOONS = {b["id"]: b for b in _DRAFT["boons"]}
PRESETS = {p["id"]: p for p in _DRAFT["presets"]}

RUN, ECO, CMB, WAV, CMD = RULES["run"], RULES["economy"], RULES["combat"], RULES["waves"], RULES["commander"]
ATTACKS, ARMORS = CMB["attack_types"], CMB["armor_types"]
MULT = {a: {r: CMB["mult_neutral"] for r in ARMORS} for a in ATTACKS}
for _a in ATTACKS:
    MULT[_a][CMB["strong_against"][_a]] = CMB["mult_strong"]
    MULT[_a][CMB["weak_against"][_a]] = CMB["mult_weak"]

# ---------------------------------------------------------------- core: 난수


class Rng:
    """xorshift32. 구현체는 32비트 부호 없는 정수 연산으로 똑같이 옮긴다."""

    def __init__(self, seed: int):
        self.x = (seed & 0xFFFFFFFF) or 1

    def next(self) -> int:
        x = self.x
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self.x = x
        return x

    def below(self, n: int) -> int:
        return self.next() % n

    def pick(self, seq):
        return seq[self.below(len(seq))]

    def sample(self, seq, n):
        pool = list(seq)
        out = []
        for _ in range(min(n, len(pool))):
            out.append(pool.pop(self.below(len(pool))))
        return out


def stream(seed: int, name: str, salt: int = 0) -> Rng:
    tag = RULES["rng"]["streams"][name] + salt * 16
    return Rng((seed * RULES["rng"]["stream_mix_multiplier"] + tag) & 0xFFFFFFFF)


# ---------------------------------------------------------------- core: 웨이브와 전투


def wave_budget(r: int) -> int:
    h = WAV["base_hp"]
    for _ in range(r):
        h = h * WAV["growth_pct"] // 100
    return h


def _ceil_div(a, b):
    return -(-a // b)


def make_wave(r: int, armor: str):
    """런 전체 판 번호 r(0부터)과 장의 방어 속성으로 웨이브를 만든다. 적 = [armor, hp, leak, pack_no(-1)]."""
    k = r % RUN["rounds_per_chapter"]
    h = wave_budget(r)
    kind = WAV["pattern"][k]
    sw_n = WAV["swarm"]["count_base"] + WAV["swarm"]["count_per_round"] * k
    el_n = WAV["elite"]["count_base"] + WAV["elite"]["count_per_3_rounds"] * (k // 3)
    out = []
    if kind == "swarm":
        out += [[armor, _ceil_div(h, sw_n), WAV["swarm"]["leak"], -1] for _ in range(sw_n)]
    elif kind == "elite":
        out += [[armor, _ceil_div(h, el_n), WAV["elite"]["leak"], -1] for _ in range(el_n)]
    elif kind == "mixed":
        n1, n2 = sw_n // 2, max(1, (el_n + 1) // 2)
        out += [[armor, _ceil_div(h // 2, n1), WAV["swarm"]["leak"], -1] for _ in range(n1)]
        out += [[armor, _ceil_div(h - h // 2, n2), WAV["elite"]["leak"], -1] for _ in range(n2)]
    else:
        out += [[armor, h, WAV["boss"]["leak"], -1]]
    return out


def pack_enemies(merc_ids, first_pack_no=0):
    out = []
    for i, mid in enumerate(merc_ids):
        m = MERCS[mid]
        out += [[m["armor"], m["hp"], m["leak"], first_pack_no + i] for _ in range(m["count"])]
    return out


def resolve(board, enemies, beats: int):
    """한 레인의 전투. board: 자리 목록(None 또는 (family_id, tier)). enemies 는 복사해서 쓴다.

    박자마다 자리 순서대로 공격한다. single 은 살아 있는 맨 앞 적을 hits 번, splash 는 앞에서부터 targets 명을
    한 번씩 친다. 피해 = damage × 상성배율 // 10 (최소 1). 박자가 끝났을 때 살아 있는 적은 모두 샌다.
    반환: (성 피해, 전멸한 용병 묶음 번호 목록(보낸 순서), 남은 적 체력 합)
    """
    es = [e[:] for e in enemies]
    n = len(es)
    front = 0
    units = [(FAMILIES[f], FAMILIES[f]["tiers"][t - 1]["damage"]) for s in board if s for f, t in [s]]
    for _ in range(beats):
        if front >= n:
            break
        for fam, dmg in units:
            while front < n and es[front][1] <= 0:
                front += 1
            if front >= n:
                break
            row = MULT[fam["attack"]]
            if fam["mode"] == "single":
                for _h in range(fam["hits"]):
                    while front < n and es[front][1] <= 0:
                        front += 1
                    if front >= n:
                        break
                    e = es[front]
                    e[1] -= max(CMB["min_damage"], dmg * row[e[0]] // CMB["mult_scale"])
            else:
                hit, i = 0, front
                while i < n and hit < fam["targets"]:
                    e = es[i]
                    if e[1] > 0:
                        e[1] -= max(CMB["min_damage"], dmg * row[e[0]] // CMB["mult_scale"])
                        hit += 1
                    i += 1
    damage = sum(e[2] for e in es if e[1] > 0)
    alive_packs = {e[3] for e in es if e[1] > 0 and e[3] >= 0}
    all_packs = sorted({e[3] for e in es if e[3] >= 0})
    blocked = [p for p in all_packs if p not in alive_packs]
    return damage, blocked, sum(e[1] for e in es if e[1] > 0)


# ---------------------------------------------------------------- core: 진영과 경제


class Side:
    def __init__(self, slots: int, base_income: int):
        self.board = [None] * slots
        self.gold = 0
        self.base_income = base_income
        self.workers = 0
        self.merc_income = 0
        self.castle = 0
        self.castle_max = 0

    @property
    def income(self) -> int:
        return self.base_income + self.workers * ECO["worker_income"] + self.merc_income

    def filled(self) -> int:
        return sum(1 for s in self.board if s)


def tier_cost(family_id: str, tier: int, upgrade_discount: int = 0) -> int:
    c = FAMILIES[family_id]["tiers"][tier - 1]["cost"]
    return max(1, c + upgrade_discount) if tier > 1 else c


def unit_value(family_id: str, tier: int) -> int:
    return sum(FAMILIES[family_id]["tiers"][t]["cost"] for t in range(tier))


# ---------------------------------------------------------------- core: 지휘관


class Commander:
    def __init__(self, cmd_id: str, chapter: int, rng: Rng, ascension: int = 0):
        self.id = cmd_id
        self.cfg = COMMANDERS[cmd_id]
        self.chapter = chapter
        pct = CMD["income_pct"][chapter] + ascension * RULES["ascension"]["commander_income_pct_per_level"]
        self.side = Side(RUN["slots"], RUN["base_income"] * pct // 100)
        self.side.castle = self.side.castle_max = (
            CMD["castle_hp"][chapter] + ascension * RULES["ascension"]["commander_castle_hp_per_level"])
        self.side.workers = CMD["start_workers"][chapter]
        self.focus = rng.sample(FAMILY_IDS, 2)
        self.favorite = rng.pick(MERC_IDS)
        self.damaged_last = False
        self._build(CMD["start_defense_budget"][chapter])

    def _build(self, budget: int) -> int:
        """방어 예산을 쓴다. 자리 4개까지는 채우기를 먼저, 그다음은 가장 낮은 단계(같으면 왼쪽)를 강화."""
        b = self.side.board
        while True:
            filled = self.side.filled()
            lows = [(t, i) for i, s in enumerate(b) if s for f, t in [s] if t < 3]
            up = min(lows) if lows else None
            up_cost = tier_cost(b[up[1]][0], up[0] + 1) if up else None
            can_place = filled < len(b) and budget >= tier_cost(self.focus[0], 1)
            if can_place and (filled < CMD["fill_slots_before_upgrade"] or up is None or budget < up_cost):
                b[b.index(None)] = (self.focus[filled % 2], 1)
                budget -= tier_cost(self.focus[0], 1)
            elif up is not None and budget >= up_cost:
                b[up[1]] = (b[up[1]][0], up[0] + 1)
                budget -= up_cost
            else:
                return budget

    def plan(self, k: int, wave, player_board_prev, player_beats: int):
        """이번 판 지휘관의 결정. 방어·일꾼은 즉시 반영하고, 보낼 용병 묶음 목록을 돌려준다(전투 전까지 비공개)."""
        cfg, side = self.cfg["split"], self.side
        if self.damaged_last and "after_damage" in cfg:
            split = cfg["after_damage"]
        else:
            split = cfg.get("rounds", {}).get(str(k), cfg["default"])
        g = side.gold
        d, e = g * split[0] // 100, g * split[1] // 100
        s = g - d - e
        left = self._build(d)
        n_w = min(e // ECO["worker_cost"], ECO["worker_cap"] - side.workers)
        side.workers += n_w
        left += e - n_w * ECO["worker_cost"]
        pick = self.cfg["merc_pick"]
        if pick == "favorite":
            mid = self.favorite
        elif pick == "rotate":
            fav = MERCS[self.favorite]
            armor = ARMORS[(ARMORS.index(fav["armor"]) + k) % len(ARMORS)]
            form = ("swarm", "elite")[(("swarm", "elite").index(fav["form"]) + k) % 2]
            mid = f"m_{armor}_{form}"
        else:  # weakest_point
            best = None
            for cand in MERC_IDS:
                dmg, _, rem = resolve(player_board_prev, wave + pack_enemies([cand] * 3), player_beats)
                key = (dmg, rem)
                if best is None or key > best[0]:
                    best = (key, cand)
            mid = best[1]
        budget = s + left
        n = budget // MERCS[mid]["cost"] if split[2] > 0 else 0
        side.gold = budget - n * MERCS[mid]["cost"]
        side.merc_income += n * ECO["merc_income_per_pack"]
        return [mid] * n


# ---------------------------------------------------------------- core: 런


class IllegalAction(Exception):
    pass


class Run:
    """한 런의 상태 기계. begin_chapter → (begin_round → apply_action) × 판 → 장 종료 → draft → 다음 장."""

    def __init__(self, seed: int, preset_id: str = "preset_a", ascension: int = 0):
        self.seed, self.ascension = seed, ascension
        p = PRESETS[preset_id]
        self.families, self.mercs = list(p["families"]), list(p["mercs"])
        self.boons: list[str] = []
        self.mod = {"worker_cost": 0, "merc_cost": 0, "upgrade_cost": 0, "beats": 0, "chapter_gold": 0,
                    "first_hit_bonus": 0, "blocked_packs_per_captive": RULES["capture"]["blocked_packs_per_captive"]}
        self.player = Side(RUN["slots"], RUN["base_income"])
        self.player.castle = self.player.castle_max = RUN["player_castle_hp"]
        self.player.gold = RUN["start_gold"]
        self.chapter, self.k, self.rounds_used = 0, 0, 0
        self.status = "route"            # route → round → (draft → route) → won / lost
        self.fail_reason = None
        self.cmd: Commander | None = None
        self.armor = None
        self.captives: list[str] = []
        self.pending: list[str] = []
        self.first_hit_used = False
        self.history: list[list[str]] = []   # 이번 장에서 지휘관이 보낸 묶음(전투 뒤 공개)
        self.prev_board = list(self.player.board)
        self.log: list[tuple[str, str]] = []
        self.matchlog: list[tuple[str, bool]] = []   # 검산용: (장 상성, 통과 여부)

    # --- 조회
    @property
    def r(self) -> int:
        return self.chapter * RUN["rounds_per_chapter"] + self.k

    def player_beats(self) -> int:
        return CMB["beats"] + self.mod["beats"]

    def merc_cost(self, mid: str) -> int:
        return max(1, MERCS[mid]["cost"] + self.mod["merc_cost"])

    def worker_cost(self) -> int:
        return max(1, ECO["worker_cost"] + self.mod["worker_cost"])

    def upgrade_cost(self, slot: int) -> int:
        f, t = self.player.board[slot]
        return tier_cost(f, t + 1, self.mod["upgrade_cost"])

    def wave(self):
        return make_wave(self.r, self.armor)

    # --- 길 선택
    def route_options(self):
        rng = stream(self.seed, "route", self.chapter)
        out = []
        for i in range(RUN["route_choices"]):
            cid = rng.pick(COMMANDER_IDS)
            armor = rng.pick(ARMORS)
            c = Commander(cid, self.chapter, stream(self.seed, "commander", self.chapter * 4 + i), self.ascension)
            out.append({"index": i, "commander": c, "armor": armor})
        return out

    def choose_route(self, index: int):
        if self.status != "route":
            raise IllegalAction("길 선택 단계가 아니다")
        opt = self.route_options()[index]
        self.cmd, self.armor = opt["commander"], opt["armor"]
        self.k, self.history, self.captives, self.first_hit_used = 0, [], [], False
        self.player.gold += self.mod["chapter_gold"]
        self.status = "round"
        self._begin_round()

    def _begin_round(self):
        if self.rounds_used > 0:
            self.player.gold += self.player.income
        self.cmd.side.gold += self.cmd.side.income
        self.pending = self.cmd.plan(self.k, self.wave(), self.prev_board, self.player_beats())

    # --- 한 판
    def apply_action(self, action: dict):
        """action = {"builds": [["place", slot, family] | ["upgrade", slot] | ["replace", slot, family]],
                     "workers": n, "packs": [merc_id, ...]}"""
        if self.status != "round":
            raise IllegalAction("판 진행 단계가 아니다")
        p = self.player
        for b in action.get("builds", []):
            if b[0] == "place":
                _, slot, fam = b
                if p.board[slot] is not None or fam not in self.families:
                    raise IllegalAction(f"배치 불가 {b}")
                cost = tier_cost(fam, 1)
                p.board[slot] = (fam, 1)
            elif b[0] == "upgrade":
                slot = b[1]
                if p.board[slot] is None or p.board[slot][1] >= 3:
                    raise IllegalAction(f"강화 불가 {b}")
                cost = self.upgrade_cost(slot)
                p.board[slot] = (p.board[slot][0], p.board[slot][1] + 1)
            elif b[0] == "replace":
                _, slot, fam = b
                if p.board[slot] is None or fam not in self.families:
                    raise IllegalAction(f"교체 불가 {b}")
                cost = tier_cost(fam, 1) - unit_value(*p.board[slot]) * ECO["replace_refund_pct"] // 100
                p.board[slot] = (fam, 1)
            else:
                raise IllegalAction(f"모르는 건설 {b}")
            p.gold -= cost
        n_w = action.get("workers", 0)
        if n_w < 0 or p.workers + n_w > ECO["worker_cap"]:
            raise IllegalAction("일꾼 한도")
        p.gold -= n_w * self.worker_cost()
        packs = list(action.get("packs", []))
        for mid in packs:
            if mid not in self.mercs:
                raise IllegalAction(f"편성에 없는 용병 {mid}")
            p.gold -= self.merc_cost(mid)
        if p.gold < 0:
            raise IllegalAction("금화 부족")
        p.workers += n_w

        wave = self.wave()
        sent = self.captives + packs
        my_dmg, my_blocked, _ = resolve(p.board, wave + pack_enemies(self.pending), self.player_beats())
        cmd_dmg, _, _ = resolve(self.cmd.side.board, wave + pack_enemies(sent), CMB["beats"])
        if cmd_dmg > 0 and not self.first_hit_used:
            cmd_dmg += self.mod["first_hit_bonus"]
            self.first_hit_used = True
        p.castle -= my_dmg
        self.cmd.side.castle -= cmd_dmg
        self.cmd.damaged_last = cmd_dmg > 0
        step = self.mod["blocked_packs_per_captive"]
        self.captives = [self.pending[i] for n, i in enumerate(my_blocked, 1) if n % step == 0]
        p.merc_income += len(packs) * ECO["merc_income_per_pack"]
        self.history.append(list(self.pending))
        tag = self.matchup_tag()
        self.prev_board = list(p.board)
        self.rounds_used += 1
        result = {"my_damage": my_dmg, "cmd_damage": cmd_dmg, "revealed": list(self.pending),
                  "captives": list(self.captives)}
        if p.castle <= 0:
            self._end("lost", "성 함락")
        elif self.cmd.side.castle <= 0:
            self.log.append((self.cmd.id, "깸"))
            saved = RUN["rounds_per_chapter"] - 1 - self.k
            p.gold += saved * RUN["early_clear_gold_per_round"]      # 전리품: 아낀 판만큼 금화
            result["spoils"] = saved * RUN["early_clear_gold_per_round"]
            if self.chapter + 1 == RUN["chapters"]:
                self.status = "won"
            else:
                p.castle = min(p.castle_max, p.castle + RUN["heal_between_chapters"])
                self.status = "draft"
        elif self.k + 1 == RUN["rounds_per_chapter"]:
            # 제한 판 수 안에 못 깨면 지휘관이 물러나며 내 성을 크게 깎는다. 버티면 장은 넘어간다(회복 없음).
            p.castle -= RUN["timeout_castle_damage"][self.chapter]
            result["timeout"] = True
            if p.castle <= 0:
                self._end("lost", "시간 초과")
            else:
                self.log.append((self.cmd.id, "버팀"))
                self.status = "won" if self.chapter + 1 == RUN["chapters"] else "draft"
        else:
            self.k += 1
            self._begin_round()
        if self.status != "round":
            self.matchlog.append((tag, self.status != "lost"))
        return result

    def _end(self, status, reason):
        self.status, self.fail_reason = status, reason
        self.log.append((self.cmd.id, reason))

    def matchup_tag(self) -> str:
        """이 장의 웨이브 방어 속성에 대한 내 편성의 상성. 검산 집계용."""
        atks = {FAMILIES[f]["attack"] for f in self.families}
        if any(CMB["strong_against"][a] == self.armor for a in atks):
            return "유리"
        if all(CMB["weak_against"][a] == self.armor or MULT[a][self.armor] == CMB["mult_neutral"] for a in atks) and \
                any(CMB["weak_against"][a] == self.armor for a in atks):
            return "불리"
        return "보통"

    # --- 장 보상
    def draft_options(self):
        rng = stream(self.seed, "draft", self.chapter)
        pool = ([["family", f] for f in FAMILY_IDS if f not in self.families]
                + [["merc", m] for m in MERC_IDS if m not in self.mercs]
                + [["boon", b] for b in BOONS if b not in self.boons])
        return rng.sample(pool, RUN["draft_choices"])

    def choose_draft(self, index: int):
        if self.status != "draft":
            raise IllegalAction("보상 단계가 아니다")
        kind, x = self.draft_options()[index]
        if kind == "family":
            self.families.append(x)
        elif kind == "merc":
            self.mercs.append(x)
        else:
            self.boons.append(x)
            for key, v in BOONS[x]["effect"].items():
                if key == "castle_hp":
                    self.player.castle_max += v
                    self.player.castle += v
                elif key == "income":
                    self.player.base_income += v
                elif key == "slots":
                    self.player.board += [None] * v
                elif key == "blocked_packs_per_captive":
                    self.mod[key] = v
                else:
                    self.mod[key] += v
        self.chapter += 1
        self.status = "route"

    def score(self) -> int:
        d = RULES["daily"]
        cleared = self.chapter + (1 if self.status == "won" else 0)
        saved = RUN["chapters"] * RUN["rounds_per_chapter"] - self.rounds_used if self.status == "won" else 0
        return (cleared * d["score_per_chapter"] + max(0, self.player.castle) * d["score_per_castle_hp"]
                + saved * d["score_per_saved_round"])


# ---------------------------------------------------------------- bots (검산용)

STYLES = {"수비": (150, 35, 100, 0), "균형": (100, 60, 100, 0), "공격": (100, 90, 200, 0)}
# 예상 용병 배수 %, 보내기 금화 상한 %, 목표 피해 %, 감수하는 성 피해


def predict_packs(run: Run, memory: str):
    """지휘관이 이번 판에 보낼 묶음 예측. memory: none(예측 안 함) / dex(도감 지식 + 이번 장 기록) / oracle(정답)."""
    if memory == "oracle":
        return list(run.pending)
    if memory == "none":
        return []
    cmd = run.cmd
    cfg = cmd.cfg["split"]
    split = cfg["after_damage"] if (cmd.damaged_last and "after_damage" in cfg) else cfg.get("rounds", {}).get(str(run.k), cfg["default"])
    est = cmd.side.income * split[2] // 100 // 8
    seen = [m for packs in run.history for m in packs]
    if cmd.cfg["merc_pick"] == "rotate" and run.history and run.history[-1]:
        last = MERCS[run.history[-1][0]]
        armor = ARMORS[(ARMORS.index(last["armor"]) + 1) % len(ARMORS)]
        mid = f"m_{armor}_{'elite' if last['form'] == 'swarm' else 'swarm'}"
    elif seen:
        mid = Counter(seen).most_common(1)[0][0]
    else:
        # 아직 본 적이 없으면 내 진영에 가장 아픈 종류로 가정한다
        mid = max(MERC_IDS, key=lambda c: resolve(run.player.board, run.wave() + pack_enemies([c] * max(1, est)), run.player_beats())[::2])
    return [mid] * est


def make_bot(style: str = "균형", memory: str = "dex"):
    margin, cap, aim, tolerate = STYLES[style]

    def act(run: Run):
        p = run.player
        gold = p.gold
        wave = run.wave()
        pred = predict_packs(run, memory)
        pred = pred[:1] * (len(pred) * margin // 100) if pred else []
        expect = wave + pack_enemies(pred)
        board = list(p.board)
        builds = []
        beats = run.player_beats()

        def value(b):
            dmg, _, rem = resolve(b, expect, beats)
            return dmg * 1000 + rem

        cur = value(board)
        while cur // 1000 > tolerate:
            best = None
            for i, s in enumerate(board):
                if s is None:
                    for f in run.families:
                        c = tier_cost(f, 1)
                        if c <= gold:
                            nb = board[:i] + [(f, 1)] + board[i + 1:]
                            gain = (cur - value(nb)) / c
                            if best is None or gain > best[0]:
                                best = (gain, c, nb, ["place", i, f])
                    break
            for i, s in enumerate(board):
                if s and s[1] < 3:
                    c = tier_cost(s[0], s[1] + 1, run.mod["upgrade_cost"])
                    if c <= gold:
                        nb = board[:i] + [(s[0], s[1] + 1)] + board[i + 1:]
                        gain = (cur - value(nb)) / c
                        if best is None or gain > best[0]:
                            best = (gain, c, nb, ["upgrade", i])
            if best is None or best[0] <= 0:
                break
            _, c, board, b = best
            gold -= c
            builds.append(b)
            cur = value(board)

        cmd = run.cmd.side
        left = RUN["rounds_per_chapter"] - run.k
        target = max(1, -(-cmd.castle // left) * aim // 100)
        bonus = 0 if run.first_hit_used else run.mod["first_hit_bonus"]

        def cmd_damage(packs):
            d, _, _ = resolve(cmd.board, wave + pack_enemies(run.captives + packs), CMB["beats"])
            return d + (bonus if d > 0 else 0)

        packs = []
        best = None
        for limit, goal in ((gold, cmd.castle), (gold * cap // 100, target)):
            for mid in run.mercs:
                c = run.merc_cost(mid)
                for n in range(0, limit // c + 1):
                    d = cmd_damage([mid] * n)
                    if d >= goal:
                        if best is None or n * c < best[0]:
                            best = (n * c, [mid] * n)
                        break
            if best:
                break
        if best is None:
            top = (cmd_damage([]), [])
            for mid in run.mercs:
                n = (gold * cap // 100) // run.merc_cost(mid)
                d = cmd_damage([mid] * n)
                if n and d > top[0]:
                    top = (d, [mid] * n)
            packs = top[1]
        else:
            packs = best[1]
        gold -= sum(run.merc_cost(m) for m in packs)
        rounds_left_run = (RUN["chapters"] - run.chapter) * RUN["rounds_per_chapter"] - run.k - 1
        workers = 0
        if rounds_left_run >= 4:
            workers = min(gold // run.worker_cost(), ECO["worker_cap"] - p.workers)
        return {"builds": builds, "workers": workers, "packs": packs}

    def route(run: Run, options):
        best = (-1, 0)
        for o in options:
            w = make_wave(run.chapter * RUN["rounds_per_chapter"], o["armor"])
            d = max(resolve(o["commander"].side.board, w + pack_enemies([m] * 3), CMB["beats"])[0] for m in run.mercs)
            if d > best[0]:
                best = (d, o["index"])
        return best[1]

    def draft(run: Run, options):
        order = {"merc": 0, "family": 1, "boon": 2}
        if len(run.mercs) >= 4:
            order = {"boon": 0, "family": 1, "merc": 2}
        return min(range(len(options)), key=lambda i: (order[options[i][0]], i))

    act.route, act.draft = route, draft
    act.__name__ = f"{style}" + {"dex": "", "none": " 기억없음", "oracle": " 정보상한"}[memory]
    return act


def make_random_bot(seed: int):
    rng = Rng(seed)

    def act(run: Run):
        p = run.player
        gold, board, builds, packs, workers = p.gold, list(p.board), [], [], 0
        for _ in range(12):
            choice = rng.below(4)
            if choice == 0 and None in board:
                f = rng.pick(run.families)
                if tier_cost(f, 1) <= gold:
                    i = board.index(None)
                    board[i] = (f, 1)
                    builds.append(["place", i, f])
                    gold -= tier_cost(f, 1)
            elif choice == 1:
                ups = [i for i, s in enumerate(board) if s and s[1] < 3]
                if ups:
                    i = rng.pick(ups)
                    c = tier_cost(board[i][0], board[i][1] + 1, run.mod["upgrade_cost"])
                    if c <= gold:
                        board[i] = (board[i][0], board[i][1] + 1)
                        builds.append(["upgrade", i])
                        gold -= c
            elif choice == 2 and p.workers + workers < ECO["worker_cap"] and run.worker_cost() <= gold:
                workers += 1
                gold -= run.worker_cost()
            elif choice == 3:
                m = rng.pick(run.mercs)
                if run.merc_cost(m) <= gold:
                    packs.append(m)
                    gold -= run.merc_cost(m)
        return {"builds": builds, "workers": workers, "packs": packs}

    act.route = lambda run, options: rng.below(len(options))
    act.draft = lambda run, options: rng.below(len(options))
    act.__name__ = "무작위"
    return act


def play(bot, seed: int, preset="preset_a", ascension=0, record=None, restrict=None):
    run = Run(seed, preset, ascension)
    if restrict:
        restrict(run)
    while run.status not in ("won", "lost"):
        if run.status == "route":
            i = bot.route(run, run.route_options())
            if record is not None:
                record.append({"step": "route", "index": i})
            run.choose_route(i)
        elif run.status == "draft":
            i = bot.draft(run, run.draft_options())
            if record is not None:
                record.append({"step": "draft", "index": i})
            run.choose_draft(i)
        else:
            a = bot(run)
            res = run.apply_action(a)
            if record is not None:
                record.append({"step": "round", "action": a, "result": res,
                               "after": {"gold": run.player.gold, "castle": run.player.castle,
                                         "cmd_castle": run.cmd.side.castle, "status": run.status}})
    return run


# ---------------------------------------------------------------- 검산 리포트


def evaluate(bot, runs, seed0, **kw):
    wins = 0
    per = defaultdict(Counter)
    fails = Counter()
    match = defaultdict(Counter)
    chapters = 0
    scores = []
    for i in range(runs):
        run = play(bot, seed0 + i * 7919, **kw)
        wins += run.status == "won"
        chapters += run.chapter + (run.status == "won")
        scores.append(run.score())
        for cid, res in run.log:
            per[cid][res] += 1
        for tag, ok in run.matchlog:
            match[tag][ok] += 1
        if run.fail_reason:
            fails[run.fail_reason] += 1
    return {
        "완주": wins / runs,
        "평균 장": chapters / runs,
        "실패 원인": dict(fails),
        "지휘관별 장 실패율": {COMMANDERS[c]["name_ko"]: round(1 - (v["깸"] + v["버팀"]) / sum(v.values()), 3) for c, v in per.items()},
        "지휘관별 버팀 비율": {COMMANDERS[c]["name_ko"]: round(v["버팀"] / sum(v.values()), 3) for c, v in per.items()},
        "점수 중앙값": sorted(scores)[len(scores) // 2],
        "장 상성별 실패율": {t: round(c[False] / (c[True] + c[False]), 3) for t, c in sorted(match.items())},
        "장 상성별 표본": {t: c[True] + c[False] for t, c in sorted(match.items())},
    }


def report(runs, seed0, out_json=None):
    out = {"runs": runs, "seed": seed0}
    bots = [make_bot(s, m) for s in STYLES for m in ("dex",)] + [make_bot("균형", "none"), make_bot("균형", "oracle"),
                                                                 make_random_bot(7)]
    res = {b.__name__: evaluate(b, runs, seed0) for b in bots}
    out["bots"] = res
    print(f"== 봇별 결과 ({runs}런, 첫 출정대, 격 0) ==")
    for n, v in res.items():
        print(f"  {n:12s} 완주 {v['완주']:6.1%}  평균 장 {v['평균 장']:4.2f}  점수 중앙값 {v['점수 중앙값']:5d}  실패 {v['실패 원인']}")
    print("\n== 지휘관별 장 실패율 ==")
    names = [c["name_ko"] for c in COMMANDERS.values()]
    for n in ("수비", "균형", "공격"):
        print(f"  {n}: " + "  ".join(f"{k} {res[n]['지휘관별 장 실패율'].get(k, float('nan')):.2f}" for k in names))
    near = {}
    for k in names:
        vals = {n: res[n]["지휘관별 장 실패율"].get(k, 1.0) for n in STYLES}
        best = min(vals.values())
        near[k] = [n for n, v in vals.items() if v <= best + 0.05]
    out["지휘관별 최선 근처 운영"] = near
    print("  최선 5%p 안의 운영:", near)
    print("\n== 장의 웨이브 속성과 내 방어 편성의 상성별 장 실패율 ==")
    for n in STYLES:
        print(f"  {n}: {res[n]['장 상성별 실패율']}  표본 {res[n]['장 상성별 표본']}")

    print("\n== 출정 편성별 완주율(균형) ==")
    out["presets"] = {}
    for pid, p in PRESETS.items():
        v = evaluate(make_bot("균형"), runs, seed0, preset=pid)
        out["presets"][p["name_ko"]] = v["완주"]
        print(f"  {p['name_ko']:8s} {v['완주']:6.1%}  지휘관별 {v['지휘관별 장 실패율']}")

    print("\n== 용병 한 종류를 못 쓸 때(균형, 첫 출정대) ==")
    out["merc_ban"] = {}
    for mid in PRESETS["preset_a"]["mercs"]:
        def restrict(run, mid=mid):
            run.mercs = [m for m in run.mercs if m != mid]
        v = evaluate(make_bot("균형"), runs, seed0, restrict=restrict)
        out["merc_ban"][MERCS[mid]["name_ko"]] = v["완주"]
        print(f"  {MERCS[mid]['name_ko']} 없이 {v['완주']:6.1%}")

    print("\n== 격(난이도 단계)별 완주율(균형) ==")
    out["ascension"] = {}
    for lv in range(RULES["ascension"]["levels"] + 1):
        v = evaluate(make_bot("균형"), max(100, runs // 2), seed0, ascension=lv)
        out["ascension"][lv] = v["완주"]
        print(f"  격 {lv}: {v['완주']:6.1%}")

    print("\n== 일일 도전 점수: 같은 시드 30일 × 봇 6종 ==")
    rows = []
    for day in range(30):
        rows.append([play(b, 900000 + day).score() for b in bots])
    distinct = sum(len(set(r)) for r in rows) / sum(len(r) for r in rows)
    out["daily"] = {"서로 다른 점수 비율": distinct, "하루 평균 점수 폭": sum(max(r) - min(r) for r in rows) / len(rows)}
    print(f"  서로 다른 점수 비율 {distinct:.1%}, 하루 평균 최고-최저 폭 {out['daily']['하루 평균 점수 폭']:.0f}점")
    if out_json:
        Path(out_json).write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- self-test · vectors


def self_test():
    r = Rng(1)
    assert [r.next() for _ in range(3)] == [270369, 67634689, 2647435461], "xorshift32"
    assert MULT["pierce"]["plate"] == 15 and MULT["pierce"]["light"] == 6 and MULT["pierce"]["hide"] == 10
    assert wave_budget(0) == 36 and wave_budget(1) == 39 and wave_budget(7) == 66
    w = make_wave(0, "plate")
    assert len(w) == 8 and w[0] == ["plate", 5, 1, -1]
    assert make_wave(6, "ward") == [["ward", wave_budget(6), 8, -1]]
    # 전투: 저격대 1단계(7) vs 중갑 = 10 피해. 체력 5 적 8기, 8박 → 박자마다 1기씩 전멸
    assert resolve([("fam_pierce", 1)], w, 8) == (0, [], 0)
    # 경갑에는 7*6//10 = 4 피해 → 2박에 1기. 8박에 4기, 4기가 샌다
    assert resolve([("fam_pierce", 1)], make_wave(0, "light"), 8)[0] == 4
    # 포격대(2, 3명) vs 경갑 3 피해: 8박 × 3명 × 3 = 72 ≥ 40 → 전멸
    assert resolve([("fam_blast", 1)], make_wave(0, "light"), 8)[0] == 0
    # 용병 묶음 전멸 판정과 번호
    e = pack_enemies(["m_plate_elite", "m_plate_swarm"])
    dmg, blocked, rem = resolve([("fam_pierce", 3)], e, 8)
    assert blocked == [0, 1] and dmg == 0, (dmg, blocked, rem)
    dmg, blocked, _ = resolve([("fam_pierce", 1)], e, 8)
    assert blocked == [0] and dmg == 2, (dmg, blocked)
    # 런: 결정론, 금화 검사, 포로 규칙
    a = play(make_bot("균형"), 12345)
    b = play(make_bot("균형"), 12345)
    assert (a.status, a.score(), a.rounds_used) == (b.status, b.score(), b.rounds_used), "결정론"
    run = Run(1)
    run.choose_route(0)
    try:
        run.apply_action({"builds": [["place", 0, "fam_pierce"], ["place", 1, "fam_blast"], ["place", 2, "fam_blast"]]})
        raise AssertionError("금화 부족을 잡지 못함")
    except IllegalAction:
        pass
    run = Run(1)
    run.choose_route(0)
    try:
        run.apply_action({"packs": ["m_ward_elite"]})
        raise AssertionError("편성에 없는 용병을 잡지 못함")
    except IllegalAction:
        pass
    assert unit_value("fam_pierce", 3) == 46 and tier_cost("fam_pierce", 2, -3) == 11
    print("self-test OK: 난수 1, 상성 1, 웨이브 3, 전투 5, 런 3, 비용 1")


def export_vectors(path, seed0=20261010):
    combat = []
    rng = Rng(seed0)
    for i in range(60):
        board = []
        for _ in range(RUN["slots"]):
            board.append(None if rng.below(4) == 0 else [rng.pick(FAMILY_IDS), 1 + rng.below(3)])
        r = rng.below(RUN["chapters"] * RUN["rounds_per_chapter"])
        armor = rng.pick(ARMORS)
        packs = [rng.pick(MERC_IDS) for _ in range(rng.below(6))]
        beats = CMB["beats"] + rng.below(2)
        dmg, blocked, rem = resolve([tuple(s) if s else None for s in board], make_wave(r, armor) + pack_enemies(packs), beats)
        combat.append({"board": board, "round": r, "armor": armor, "packs": packs, "beats": beats,
                       "expect": {"castle_damage": dmg, "blocked_packs": blocked, "remaining_hp": rem}})
    runs = []
    bots = [make_bot("균형"), make_bot("공격"), make_bot("수비"), make_random_bot(3)]
    for i in range(40):
        rec = []
        preset = list(PRESETS)[i % len(PRESETS)]
        run = play(bots[i % len(bots)], seed0 + i, preset=preset, ascension=i % 3, record=rec)
        runs.append({"seed": seed0 + i, "preset": preset, "ascension": i % 3, "steps": rec,
                     "expect": {"status": run.status, "score": run.score(), "rounds_used": run.rounds_used,
                                "chapter": run.chapter, "fail_reason": run.fail_reason}})
    Path(path).write_text(json.dumps({"seed": seed0, "combat": combat, "runs": runs}, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"vectors: 전투 {len(combat)}, 런 {len(runs)} -> {path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=400)
    ap.add_argument("--seed", type=int, default=20261010)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--vectors")
    ap.add_argument("--json")
    args = ap.parse_args()
    if args.self_test:
        self_test()
        return 0
    if args.vectors:
        export_vectors(args.vectors)
        return 0
    report(args.runs, args.seed, args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
