class_name DuelRules
extends RefCounted
## Pure integer rules. Content is injected; no nodes, files, clocks or SDKs.

var rules: Dictionary
var families: Dictionary = {}
var mercs: Dictionary = {}
var commanders: Dictionary = {}
var boons: Dictionary = {}
var presets: Dictionary = {}
var multipliers: Dictionary = {}

func _init(content: Dictionary) -> void:
	rules = content.rules
	for entry in content.units.families: families[entry.id] = entry
	for entry in content.mercenaries.mercenaries: mercs[entry.id] = entry
	for entry in content.commanders.commanders: commanders[entry.id] = entry
	for entry in content.draft.boons: boons[entry.id] = entry
	for entry in content.draft.presets: presets[entry.id] = entry
	for attack in rules.combat.attack_types:
		var row: Dictionary = {}
		for armor in rules.combat.armor_types: row[armor] = rules.combat.mult_neutral
		row[rules.combat.strong_against[attack]] = rules.combat.mult_strong
		row[rules.combat.weak_against[attack]] = rules.combat.mult_weak
		multipliers[attack] = row

class Rng:
	extends RefCounted
	var x: int
	func _init(seed_value: int) -> void:
		x = seed_value & 0xFFFFFFFF
		if x == 0: x = 1
	func next() -> int:
		x = (x ^ ((x << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF
		x = (x ^ (x >> 17)) & 0xFFFFFFFF
		x = (x ^ ((x << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF
		return x
	func below(n: int) -> int: return next() % n
	func pick(values: Array) -> Variant: return values[below(values.size())]
	func sample(values: Array, n: int) -> Array:
		var pool: Array = values.duplicate()
		var out: Array = []
		for _i in range(mini(n, pool.size())): out.append(pool.pop_at(below(pool.size())))
		return out

func stream(seed_value: int, name: String, salt: int = 0) -> Rng:
	var tag: int = rules.rng.streams[name] + salt * 16
	return Rng.new((seed_value * int(rules.rng.stream_mix_multiplier) + tag) & 0xFFFFFFFF)

func tier_cost(family: String, tier: int, discount: int = 0) -> int:
	var cost: int = families[family].tiers[tier - 1].cost
	return maxi(1, cost + discount) if tier > 1 else cost

func unit_value(family: String, tier: int) -> int:
	var total: int = 0
	for t in range(tier): total += families[family].tiers[t].cost
	return total

func wave_budget(round_no: int) -> int:
	var hp: int = rules.waves.base_hp
	for _i in range(round_no): hp = hp * int(rules.waves.growth_pct) / 100
	return hp

func make_wave(round_no: int, armor: String) -> Array:
	var w: Dictionary = rules.waves
	var k: int = round_no % int(rules.run.rounds_per_chapter)
	var hp: int = wave_budget(round_no)
	var kind: String = w.pattern[k]
	var swarm: int = w.swarm.count_base + w.swarm.count_per_round * k
	var elite: int = w.elite.count_base + w.elite.count_per_3_rounds * (k / 3)
	var out: Array = []
	if kind == "swarm": _add_enemies(out, armor, hp, swarm, w.swarm.leak)
	elif kind == "elite": _add_enemies(out, armor, hp, elite, w.elite.leak)
	elif kind == "mixed":
		_add_enemies(out, armor, hp / 2, swarm / 2, w.swarm.leak)
		_add_enemies(out, armor, hp - hp / 2, maxi(1, (elite + 1) / 2), w.elite.leak)
	else: out.append([armor, hp, w.boss.leak, -1])
	return out

func _add_enemies(out: Array, armor: String, hp: int, count_value: int, leak: int) -> void:
	var each_hp: int = (hp + count_value - 1) / count_value
	for _i in range(count_value): out.append([armor, each_hp, leak, -1])

func pack_enemies(packs: Array, first_pack: int = 0) -> Array:
	var out: Array = []
	for i in range(packs.size()):
		var m: Dictionary = mercs[packs[i]]
		for _j in range(m.count): out.append([m.armor, m.hp, m.leak, first_pack + i])
	return out

func resolve(board: Array, enemies: Array, beats: int, record_events: bool = false) -> Dictionary:
	var es: Array = enemies.duplicate(true)
	var front: int = 0
	var events: Array = []
	for beat in range(beats):
		if front >= es.size(): break
		for slot in range(board.size()):
			var unit: Variant = board[slot]
			if unit == null: continue
			while front < es.size() and es[front][1] <= 0: front += 1
			if front >= es.size(): break
			var fam: Dictionary = families[unit[0]]
			var dmg: int = fam.tiers[int(unit[1]) - 1].damage
			if fam.mode == "single":
				for _hit in range(fam.hits):
					while front < es.size() and es[front][1] <= 0: front += 1
					if front >= es.size(): break
					_hit_enemy(es, front, fam, dmg, beat, slot, events, record_events)
			else:
				var hit_count: int = 0
				var i: int = front
				while i < es.size() and hit_count < int(fam.targets):
					if es[i][1] > 0:
						_hit_enemy(es, i, fam, dmg, beat, slot, events, record_events)
						hit_count += 1
					i += 1
	var damage: int = 0
	var hp: int = 0
	var all_packs: Array = []
	var alive_packs: Array = []
	var leaked: Array = []
	for i in range(es.size()):
		var e: Array = es[i]
		if e[3] >= 0 and not e[3] in all_packs: all_packs.append(e[3])
		if e[1] > 0:
			damage += e[2]
			hp += e[1]
			leaked.append({"enemy": i, "armor": e[0], "hp": e[1], "damage": e[2], "pack": e[3]})
			if e[3] >= 0 and not e[3] in alive_packs: alive_packs.append(e[3])
	all_packs.sort()
	var blocked: Array = []
	for pack in all_packs:
		if not pack in alive_packs: blocked.append(pack)
	return {"castle_damage": damage, "blocked_packs": blocked, "remaining_hp": hp,
		"events": events, "leaked": leaked, "enemies": enemies.duplicate(true)}

func _hit_enemy(es: Array, index: int, fam: Dictionary, dmg: int, beat: int, slot: int, events: Array, record_events: bool) -> void:
	var damage: int = maxi(rules.combat.min_damage,
		dmg * int(multipliers[fam.attack][es[index][0]]) / int(rules.combat.mult_scale))
	es[index][1] -= damage
	if record_events: events.append({"beat": beat, "slot": slot, "enemy": index, "damage": damage,
		"hp": maxi(0, es[index][1]), "killed": es[index][1] <= 0})

class Army:
	extends RefCounted
	var board: Array = []
	var gold: int = 0
	var base_income: int
	var workers: int = 0
	var merc_income: int = 0
	var castle: int = 0
	var castle_max: int = 0
	var worker_income: int
	func _init(slots: int, base: int, worker_gain: int) -> void:
		board.resize(slots)
		base_income = base
		worker_income = worker_gain
	func income() -> int: return base_income + workers * worker_income + merc_income
	func filled() -> int:
		var n: int = 0
		for unit in board:
			if unit != null: n += 1
		return n
	func snapshot() -> Dictionary:
		return {"board": board.duplicate(true), "gold": gold, "base_income": base_income,
			"workers": workers, "merc_income": merc_income, "castle": castle, "castle_max": castle_max}

class Commander:
	extends RefCounted
	var core: Variant
	var id: String
	var cfg: Dictionary
	var chapter: int
	var side: Army
	var focus: Array
	var favorite: String
	var damaged_last: bool = false
	func _init(c: Variant, cmd_id: String, chapter_no: int, rng: Rng, ascension: int = 0) -> void:
		core = c
		id = cmd_id
		cfg = core.commanders[id]
		chapter = chapter_no
		var r: Dictionary = core.rules
		var pct: int = r.commander.income_pct[chapter] + ascension * r.ascension.commander_income_pct_per_level
		side = Army.new(r.run.slots, int(r.run.base_income) * pct / 100, r.economy.worker_income)
		side.castle = r.commander.castle_hp[chapter] + ascension * r.ascension.commander_castle_hp_per_level
		side.castle_max = side.castle
		side.workers = r.commander.start_workers[chapter]
		focus = rng.sample(core.families.keys(), 2)
		favorite = rng.pick(core.mercs.keys())
		build(r.commander.start_defense_budget[chapter])
	func build(budget: int) -> int:
		while true:
			var filled_count: int = side.filled()
			var low_slot: int = -1
			var low_tier: int = 4
			for i in range(side.board.size()):
				if side.board[i] != null and side.board[i][1] < low_tier and side.board[i][1] < 3:
					low_slot = i
					low_tier = side.board[i][1]
			var up_cost: int = core.tier_cost(side.board[low_slot][0], low_tier + 1) if low_slot >= 0 else 0
			var can_place: bool = filled_count < side.board.size() and budget >= core.tier_cost(focus[0], 1)
			if can_place and (filled_count < int(core.rules.commander.fill_slots_before_upgrade) or low_slot < 0 or budget < up_cost):
				side.board[side.board.find(null)] = [focus[filled_count % 2], 1]
				budget -= core.tier_cost(focus[0], 1)
			elif low_slot >= 0 and budget >= up_cost:
				side.board[low_slot] = [side.board[low_slot][0], low_tier + 1]
				budget -= up_cost
			else: return budget
		return budget
	func plan(k: int, wave: Array, previous_board: Array, player_beats: int) -> Array:
		var split: Array = cfg.split.get("after_damage") if damaged_last and cfg.split.has("after_damage") else cfg.split.get("rounds", {}).get(str(k), cfg.split.default)
		var defense: int = side.gold * int(split[0]) / 100
		var economy: int = side.gold * int(split[1]) / 100
		var sending: int = side.gold - defense - economy
		var left: int = build(defense)
		var n_workers: int = mini(economy / int(core.rules.economy.worker_cost), int(core.rules.economy.worker_cap) - side.workers)
		side.workers += n_workers
		left += economy - n_workers * int(core.rules.economy.worker_cost)
		var mid: String = favorite
		if cfg.merc_pick == "rotate":
			var fav: Dictionary = core.mercs[favorite]
			var armors: Array = core.rules.combat.armor_types
			var armor: String = armors[(armors.find(fav.armor) + k) % armors.size()]
			var forms: Array = ["swarm", "elite"]
			mid = "m_%s_%s" % [armor, forms[(forms.find(fav.form) + k) % 2]]
		elif cfg.merc_pick == "weakest_point":
			var best_damage: int = -1
			var best_hp: int = -1
			for candidate in core.mercs:
				var res: Dictionary = core.resolve(previous_board, wave + core.pack_enemies([candidate, candidate, candidate]), player_beats)
				if res.castle_damage > best_damage or (res.castle_damage == best_damage and res.remaining_hp > best_hp):
					mid = candidate
					best_damage = res.castle_damage
					best_hp = res.remaining_hp
		var budget: int = sending + left
		var packs: int = budget / int(core.mercs[mid].cost) if split[2] > 0 else 0
		side.gold = budget - packs * int(core.mercs[mid].cost)
		side.merc_income += packs * int(core.rules.economy.merc_income_per_pack)
		var out: Array = []
		for _i in range(packs): out.append(mid)
		return out

func new_run(seed_value: int, preset: String = "preset_a", ascension: int = 0) -> Run:
	return Run.new(self, seed_value, preset, ascension)

class Run:
	extends RefCounted
	var core: Variant
	var seed: int
	var preset_id: String
	var ascension: int
	var families: Array
	var mercs: Array
	var boons: Array = []
	var mod: Dictionary
	var player: Army
	var chapter: int = 0
	var k: int = 0
	var rounds_used: int = 0
	var status: String = "route"
	var fail_reason: Variant = null
	var cmd: Commander
	var armor: String = ""
	var captives: Array = []
	var pending: Array = []
	var first_hit_used: bool = false
	var history: Array = []
	var prev_board: Array
	var log: Array = []
	var last_combat: Dictionary = {}
	func _init(c: Variant, seed_value: int, preset: String, level: int) -> void:
		core = c
		seed = seed_value
		preset_id = preset
		ascension = level
		families = core.presets[preset].families.duplicate()
		mercs = core.presets[preset].mercs.duplicate()
		mod = {"worker_cost": 0, "merc_cost": 0, "upgrade_cost": 0, "beats": 0, "chapter_gold": 0,
			"first_hit_bonus": 0, "blocked_packs_per_captive": core.rules.capture.blocked_packs_per_captive}
		player = Army.new(core.rules.run.slots, core.rules.run.base_income, core.rules.economy.worker_income)
		player.castle = core.rules.run.player_castle_hp
		player.castle_max = player.castle
		player.gold = core.rules.run.start_gold
		prev_board = player.board.duplicate(true)
	func r() -> int: return chapter * int(core.rules.run.rounds_per_chapter) + k
	func player_beats() -> int: return core.rules.combat.beats + mod.beats
	func merc_cost(mid: String) -> int: return maxi(1, int(core.mercs[mid].cost) + int(mod.merc_cost))
	func worker_cost() -> int: return maxi(1, int(core.rules.economy.worker_cost) + int(mod.worker_cost))
	func wave() -> Array: return core.make_wave(r(), armor)
	func route_options() -> Array:
		var rng: Rng = core.stream(seed, "route", chapter)
		var out: Array = []
		for i in range(core.rules.run.route_choices):
			var cid: String = rng.pick(core.commanders.keys())
			var chosen_armor: String = rng.pick(core.rules.combat.armor_types)
			var commander: Commander = Commander.new(core, cid, chapter, core.stream(seed, "commander", chapter * 4 + i), ascension)
			out.append({"index": i, "commander": commander, "armor": chosen_armor})
		return out
	func choose_route(index: int) -> Dictionary:
		if status != "route" or index < 0 or index >= int(core.rules.run.route_choices): return _error("길 선택 불가")
		var opt: Dictionary = route_options()[index]
		cmd = opt.commander
		armor = opt.armor
		k = 0
		history = []
		captives = []
		first_hit_used = false
		player.gold += mod.chapter_gold
		status = "round"
		_begin_round()
		return {"ok": true}
	func _begin_round() -> void:
		if rounds_used > 0: player.gold += player.income()
		cmd.side.gold += cmd.side.income()
		pending = cmd.plan(k, wave(), prev_board, player_beats())
	func _error(message: String) -> Dictionary: return {"ok": false, "error": message}
	func prepare_action(action: Dictionary) -> Dictionary:
		if status != "round": return _error("판 진행 단계가 아니다")
		var board: Array = player.board.duplicate(true)
		var gold: int = player.gold
		var builds: Variant = action.get("builds", [])
		var workers: Variant = action.get("workers", 0)
		var packs: Variant = action.get("packs", [])
		if not builds is Array or not packs is Array or not workers is int: return _error("행동 형식 오류")
		if workers < 0 or player.workers + workers > int(core.rules.economy.worker_cap): return _error("일꾼 한도")
		for b in builds:
			if not b is Array or b.size() < 2 or not b[1] is int: return _error("건설 형식 오류")
			var slot: int = b[1]
			if slot < 0 or slot >= board.size(): return _error("자리 범위 오류")
			var cost: int = 0
			if b[0] == "place" or b[0] == "replace":
				if b.size() != 3 or not b[2] in families: return _error("편성에 없는 계열")
				if (b[0] == "place" and board[slot] != null) or (b[0] == "replace" and board[slot] == null): return _error("배치 불가")
				cost = core.tier_cost(b[2], 1)
				if b[0] == "replace": cost -= core.unit_value(board[slot][0], board[slot][1]) * int(core.rules.economy.replace_refund_pct) / 100
				board[slot] = [b[2], 1]
			elif b[0] == "upgrade":
				if b.size() != 2 or board[slot] == null or board[slot][1] >= 3: return _error("강화 불가")
				cost = core.tier_cost(board[slot][0], board[slot][1] + 1, mod.upgrade_cost)
				board[slot] = [board[slot][0], board[slot][1] + 1]
			else: return _error("모르는 건설")
			gold -= cost
			if gold < 0: return _error("금화 부족")
		gold -= workers * worker_cost()
		for mid in packs:
			if not mid in mercs: return _error("편성에 없는 용병")
			gold -= merc_cost(mid)
		if gold < 0: return _error("금화 부족")
		return {"ok": true, "board": board, "gold": gold, "workers": workers, "packs": packs.duplicate()}
	func apply_action(action: Dictionary) -> Dictionary:
		var prepared: Dictionary = prepare_action(action)
		if not prepared.ok: return prepared
		player.board = prepared.board
		player.gold = prepared.gold
		player.workers += prepared.workers
		var sent: Array = captives + prepared.packs
		var my_res: Dictionary = core.resolve(player.board, wave() + core.pack_enemies(pending), player_beats(), true)
		var cmd_res: Dictionary = core.resolve(cmd.side.board, wave() + core.pack_enemies(sent), core.rules.combat.beats, true)
		last_combat = {"player": my_res, "commander": cmd_res}
		var my_damage: int = my_res.castle_damage
		var cmd_damage: int = cmd_res.castle_damage
		if cmd_damage > 0 and not first_hit_used:
			cmd_damage += mod.first_hit_bonus
			first_hit_used = true
		player.castle -= my_damage
		cmd.side.castle -= cmd_damage
		cmd.damaged_last = cmd_damage > 0
		captives = []
		for n in range(my_res.blocked_packs.size()):
			if (n + 1) % int(mod.blocked_packs_per_captive) == 0: captives.append(pending[my_res.blocked_packs[n]])
		player.merc_income += prepared.packs.size() * int(core.rules.economy.merc_income_per_pack)
		history.append(pending.duplicate())
		prev_board = player.board.duplicate(true)
		rounds_used += 1
		var result: Dictionary = {"my_damage": my_damage, "cmd_damage": cmd_damage, "revealed": pending.duplicate(), "captives": captives.duplicate()}
		if player.castle <= 0: _end("성 함락")
		elif cmd.side.castle <= 0:
			log.append([cmd.id, "깸"])
			var saved: int = int(core.rules.run.rounds_per_chapter) - 1 - k
			result.spoils = saved * int(core.rules.run.early_clear_gold_per_round)
			player.gold += result.spoils
			if chapter + 1 == int(core.rules.run.chapters): status = "won"
			else:
				player.castle = mini(player.castle_max, player.castle + int(core.rules.run.heal_between_chapters))
				status = "draft"
		elif k + 1 == int(core.rules.run.rounds_per_chapter):
			player.castle -= core.rules.run.timeout_castle_damage[chapter]
			result.timeout = true
			if player.castle <= 0: _end("시간 초과")
			else:
				log.append([cmd.id, "버팀"])
				status = "won" if chapter + 1 == int(core.rules.run.chapters) else "draft"
		else:
			k += 1
			_begin_round()
		return result
	func _end(reason: String) -> void:
		status = "lost"
		fail_reason = reason
		log.append([cmd.id, reason])
	func draft_options() -> Array:
		var pool: Array = []
		for f in core.families:
			if not f in families: pool.append(["family", f])
		for m in core.mercs:
			if not m in mercs: pool.append(["merc", m])
		for b in core.boons:
			if not b in boons: pool.append(["boon", b])
		return core.stream(seed, "draft", chapter).sample(pool, core.rules.run.draft_choices)
	func choose_draft(index: int) -> Dictionary:
		if status != "draft" or index < 0 or index >= int(core.rules.run.draft_choices): return _error("보상 선택 불가")
		var choice: Array = draft_options()[index]
		if choice[0] == "family": families.append(choice[1])
		elif choice[0] == "merc": mercs.append(choice[1])
		else:
			boons.append(choice[1])
			for key in core.boons[choice[1]].effect:
				var value: int = core.boons[choice[1]].effect[key]
				if key == "castle_hp":
					player.castle_max += value
					player.castle += value
				elif key == "income": player.base_income += value
				elif key == "slots":
					for _i in range(value): player.board.append(null)
				elif key == "blocked_packs_per_captive": mod[key] = value
				else: mod[key] += value
		chapter += 1
		status = "route"
		return {"ok": true}
	func score() -> int:
		var cleared: int = chapter + (1 if status == "won" else 0)
		var saved: int = int(core.rules.run.chapters) * int(core.rules.run.rounds_per_chapter) - rounds_used if status == "won" else 0
		return cleared * int(core.rules.daily.score_per_chapter) + maxi(0, player.castle) * int(core.rules.daily.score_per_castle_hp) + saved * int(core.rules.daily.score_per_saved_round)
	func snapshot() -> Dictionary:
		return {"seed": seed, "preset": preset_id, "ascension": ascension, "status": status, "chapter": chapter,
			"k": k, "rounds_used": rounds_used, "player": player.snapshot(), "families": families.duplicate(),
			"mercs": mercs.duplicate(), "boons": boons.duplicate(), "mod": mod.duplicate(), "captives": captives.duplicate(),
			"cmd": cmd.side.snapshot() if cmd != null else {}, "pending": pending.duplicate(), "prev_board": prev_board.duplicate(true),
			"history": history.duplicate(true), "first_hit_used": first_hit_used, "fail_reason": fail_reason}
