extends SceneTree
const Policy = preload("res://application/ad_policy.gd")
const Loader = preload("res://adapters/content_loader.gd")

func _initialize() -> void:
	var gate: Policy = Policy.new(Loader.read_json("res://data/monetization/bm-profile.json"))
	var c: Dictionary = {"online": true, "loaded": true, "market": "google_play", "session_index": 2,
		"phase": "draft_selected", "play_seconds": 180, "now": 1000, "close_policy_verified": true, "mode": "expedition"}
	var enabled: Dictionary = {"interstitial_level_end_enabled": true, "rewarded_continue_enabled": true, "rewarded_result_bonus_enabled": true}
	var failures: int = 0
	var checks: int = 0
	var scenarios: Array = [{"change": {}, "counts": {}, "want": true},
		{"change": {"session_index": 1}, "counts": {}, "want": false},
		{"change": {"phase": "battle"}, "counts": {}, "want": false},
		{"change": {"tutorial": true}, "counts": {}, "want": false},
		{"change": {"play_seconds": 179}, "counts": {}, "want": false},
		{"change": {"close_policy_verified": false}, "counts": {}, "want": false},
		{"change": {"rewarded_this_break": true}, "counts": {}, "want": false},
		{"change": {"online": false}, "counts": {}, "want": false},
		{"change": {}, "counts": {"session": 3}, "want": false},
		{"change": {}, "counts": {"daily": 8}, "want": false},
		{"change": {}, "counts": {"last_shown": 881}, "want": false},
		{"change": {}, "counts": {"last_shown": 880}, "want": true}]
	for scenario in scenarios:
		var context: Dictionary = c.duplicate()
		context.merge(scenario.change, true)
		checks += 1
		if gate.eligible("interstitial_level_end", context, scenario.counts, enabled) != scenario.want: failures += 1
	checks += 1
	if gate.eligible("interstitial_level_end", c, {}): failures += 1
	c.phase = "failed"
	c.mode = "daily"
	checks += 1
	if gate.eligible("rewarded_continue", c, {}, enabled): failures += 1
	c.mode = "expedition"
	checks += 1
	if not gate.eligible("rewarded_continue", c, {}, enabled): failures += 1
	c.continued = true
	checks += 1
	if gate.eligible("rewarded_continue", c, {}, enabled): failures += 1
	print("AD POLICY checks=%d failures=%d live_sdk=false" % [checks, failures])
	quit(0 if failures == 0 else 1)
