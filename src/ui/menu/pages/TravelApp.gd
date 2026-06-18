extends VBoxContainer
## 手機「移動」頁：捷運（便宜+耗1時段，到區中心）＋ 計程車（貴+即時，直達已解鎖地點）。
## 付費邏輯抽成 _pay_mrt/_pay_taxi（回 bool，不換場）供測試；按鈕成功後才真的 travel。

const GOLD := Color(0.788, 0.659, 0.38)
const DIM := Color(0.55, 0.52, 0.46)
const MRT_FARE := 5
const TAXI_FARE := 30

var _toast: Label
var _locs: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_toast = Label.new()
	_toast.add_theme_color_override("font_color", GOLD)
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.visible = false

	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	_locs = JsonLoader.load_json("res://data/map_locations.json")
	var cur_area: String = String(GameManager.player.get("current_area", ""))

	_section("🚇 捷運　（%d 金 ｜ 耗 1 時段）" % MRT_FARE)
	for id in areas:
		var area: Dictionary = areas[id]
		if area.has("unlock_flag") and not GameManager.get_flag(area.unlock_flag):
			continue
		var here: bool = (id == cur_area)
		var btn := _btn("%s%s" % [String(area.get("name", id)), "（目前）" if here else ""])
		btn.disabled = here or GameManager.player.gold < MRT_FARE
		var aid: String = id
		btn.pressed.connect(func() -> void:
			if _pay_mrt(aid): _go(aid))
		add_child(btn)

	add_child(HSeparator.new())
	_section("🚕 計程車　（%d 金 ｜ 即時直達）" % TAXI_FARE)
	for id in _locs:
		var loc: Dictionary = _locs[id]
		if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag):
			continue
		if not _period_ok(loc):
			continue
		var btn := _btn("%s（%s）" % [String(loc.get("name", id)), String(loc.get("district", ""))])
		btn.disabled = GameManager.player.gold < TAXI_FARE
		var lid: String = id
		btn.pressed.connect(func() -> void:
			if _pay_taxi(lid): _go(String(_loc(lid).get("district", ""))))
		add_child(btn)

	add_child(_toast)

# === 付費邏輯（回 bool，不換場；供測試）===

func _pay_mrt(area_id: String) -> bool:
	if not GameManager.spend_gold(MRT_FARE):
		_warn("金幣不足")
		return false
	GameManager.advance_time(1)
	return true

func _pay_taxi(loc_id: String) -> bool:
	if not GameManager.spend_gold(TAXI_FARE):
		_warn("金幣不足")
		return false
	var loc: Dictionary = _loc(loc_id)
	var sp: Dictionary = loc.get("scene_pos", {"x": 0.5})
	GameManager.pending_arrival = {"area": String(loc.get("district", "")), "x": float(sp.get("x", 0.5))}
	return true

# === helpers ===

func _loc(loc_id: String) -> Dictionary:
	return _locs.get(loc_id, {})

func _period_ok(loc: Dictionary) -> bool:
	var arr: Array = loc.get("available_periods", [0, 1, 2, 3])
	for v in arr:
		if int(v) == int(GameManager.player.period):
			return true
	return false

func _go(area_id: String) -> void:
	get_tree().paused = false
	var map := get_tree().current_scene
	if map and map.has_method("travel_to"):
		map.travel_to(area_id)

func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_font_size_override("font_size", 26)
	add_child(l)

func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	return b

func _warn(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
