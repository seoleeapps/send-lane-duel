extends RefCounted
## Eligibility only. SDK display/reward signals are handled by the market adapter.
var profile: Dictionary
var minimum_play_seconds: int = 180
func _init(bm_profile: Dictionary) -> void:
	profile = bm_profile
	for key in profile.remote_config:
		if key.key == "interstitial_min_play_seconds": minimum_play_seconds = key.default

func eligible(id: String, context: Dictionary, counts: Dictionary, remote: Dictionary = {}) -> bool:
	var placement: Dictionary = {}
	for candidate in profile.ad_placements:
		if candidate.placement_id == id: placement = candidate
	if placement.is_empty() or not context.get("online", false) or not context.get("loaded", false): return false
	var bindings: Dictionary = placement.rc_bindings
	if not remote.get(bindings.enabled, placement.enabled_default): return false
	if not context.get("market", "") in placement.markets: return false
	if context.get("tutorial", false) or context.get("phase", "") in ["battle", "round", "startup", "loading"]: return false
	if context.get("session_index", 0) < int(placement.first_eligible_at.session_index): return false
	var cooldown: int = maxi(placement.cooldown_s, int(remote.get(bindings.cooldown_s, placement.cooldown_s)))
	var session_cap: int = mini(placement.session_cap, int(remote.get(bindings.session_cap, placement.session_cap)))
	var daily_cap: int = mini(placement.daily_cap, int(remote.get(bindings.daily_cap, placement.daily_cap)))
	if counts.get("session", 0) >= session_cap or counts.get("daily", 0) >= daily_cap: return false
	if counts.has("last_shown") and int(context.get("now", 0)) - int(counts.last_shown) < cooldown: return false
	if placement.format == "interstitial":
		return context.get("phase") in ["draft_selected", "settlement_closed"] and context.get("play_seconds", 0) >= maxi(minimum_play_seconds, int(remote.get("interstitial_min_play_seconds", minimum_play_seconds))) \
			and not context.get("rewarded_this_break", false) and context.get("close_policy_verified", false)
	if id == "rewarded_continue":
		return context.get("phase") == "failed" and context.get("mode") == "expedition" and not context.get("continued", false)
	return context.get("phase") == "settlement" and not context.get("result_bonus_granted", false)
