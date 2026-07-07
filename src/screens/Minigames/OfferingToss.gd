extends "res://src/screens/Minigames/MinigameBase.gd"
## 香火投擲 OfferingToss —— 飛鏢原型：力度計來回擺盪，按鍵鎖定出手，
## 香油錢拋物線飛向賽錢箱，風向左右吹偏。5 擲，中箱得功德、正中投入口加倍。
## 純程式幾何（賽錢箱/銅錢皆 Polygon2D/ColorRect），零新美術。

const THROWS: int = 5
const GAUGE_SPEED: float = 1.4          # 力度計往返頻率(Hz)
const FLIGHT_SECS: float = 0.9
const START_POS := Vector2(960, 900)
const BOX_MOUTH_Y: float = 380.0        # 投入口的落點深度(力度剛好時)
const BOX_HALF_W: float = 110.0         # 投入口半寬(落點 x 容許)
const MOUTH_HALF_H: float = 28.0        # 落點深度容許(力度窗)
const PERFECT_HALF_W: float = 35.0
const PERFECT_HALF_H: float = 12.0
const POWER_SWEET: float = 0.66         # 甜蜜點力度(落點剛好在投入口)
const WIND_MAX_DRIFT: float = 170.0     # 滿級風的橫向吹偏(px)

var throws_done: int = 0
var hits: int = 0
var perfects: int = 0
var _phase: String = "aim"              # aim / fly / done
var _gauge_t: float = 0.0
var _wind: float = 0.0                  # -1..1
var _coin: Node2D
var _gauge_fill: ColorRect
var _hud: Label
var _wind_label: Label
var _judge_popup: Label
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "offering_toss"

func _ready() -> void:
	_rng.randomize()
	_build_scene()
	_new_throw()

# --- 純邏輯（測試用）---

## 力度計相位(秒)→0..1 往返值（t=0 從空開始漲）。
func gauge_value(t: float) -> float:
	return 1.0 - abs(fmod(t * GAUGE_SPEED, 2.0) - 1.0)

## 出手力度+風 → 落點。
func landing_point(power: float, wind: float) -> Vector2:
	var y: float = START_POS.y - (power / POWER_SWEET) * (START_POS.y - BOX_MOUTH_Y)
	return Vector2(START_POS.x + wind * WIND_MAX_DRIFT, y)

## 落點判定：perfect / hit / miss。
func judge_landing(p: Vector2) -> String:
	var dx: float = absf(p.x - START_POS.x)
	var dy: float = absf(p.y - BOX_MOUTH_Y)
	if dx <= PERFECT_HALF_W and dy <= PERFECT_HALF_H:
		return "perfect"
	if dx <= BOX_HALF_W and dy <= MOUTH_HALF_H:
		return "hit"
	return "miss"

func build_result() -> Dictionary:
	var won: bool = hits >= 3
	return make_result({
		"score": hits * 100 + perfects * 100, "win": won,
		"merit": hits + perfects + (3 if won else 0),
	})

# --- 流程 ---

func _process(delta: float) -> void:
	if _phase != "aim":
		return
	_gauge_t += delta
	var v := gauge_value(_gauge_t)
	_gauge_fill.size.y = 300.0 * v
	_gauge_fill.position.y = 760.0 - _gauge_fill.size.y

func _input(event: InputEvent) -> void:
	if _phase != "aim":
		return
	var tap: bool = (event.is_action_pressed("confirm")
		or event.is_action_pressed("interact")
		or (event is InputEventKey and event.pressed and not event.echo
			and event.keycode in [KEY_F, KEY_J, KEY_SPACE])
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT))
	if tap:
		_throw(gauge_value(_gauge_t))

func _new_throw() -> void:
	if throws_done >= THROWS:
		_end()
		return
	_phase = "aim"
	_gauge_t = _rng.randf()  # 隨機起始相位，不能背拍
	_wind = _rng.randf_range(-1.0, 1.0)
	_update_wind_label()
	_coin.position = START_POS
	_coin.scale = Vector2.ONE
	_coin.modulate.a = 1.0
	_update_hud()

func _throw(power: float) -> void:
	_phase = "fly"
	var land := landing_point(power, _wind)
	var judgement := judge_landing(land)
	var start := START_POS
	var tw := create_tween()
	tw.tween_method(func(t: float):
		_coin.position = start.lerp(land, t) + Vector2(0, -sin(t * PI) * 240.0)
		_coin.scale = Vector2.ONE * lerpf(1.0, 0.45, t),
		0.0, 1.0, FLIGHT_SECS)
	tw.tween_callback(func(): _on_landed(judgement))

func _on_landed(judgement: String) -> void:
	throws_done += 1
	match judgement:
		"perfect":
			hits += 1
			perfects += 1
			AudioManager.play_sfx("merit_chime")
			_show_judge("正中投入口！", Color(1, 0.85, 0.4))
			_sink_coin()
		"hit":
			hits += 1
			AudioManager.play_sfx("gold_collect")
			_show_judge("投進了", Color(0.7, 0.85, 1))
			_sink_coin()
		_:
			AudioManager.play_sfx("wooden_fish_tap")
			_show_judge("沒進……", Color(0.8, 0.3, 0.3))
			_bounce_coin()
	_update_hud()
	await get_tree().create_timer(0.7).timeout
	_new_throw()

func _end() -> void:
	_phase = "done"
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	var rating := "功德圓滿" if result.win else "改日再來"
	show_result_panel("香火投擲", rating, [
		{"label": "命中", "value": "%d/%d" % [hits, THROWS]},
		{"label": "正中投入口", "value": "%d" % perfects},
		{"label": "功德", "value": "+%d" % result.merit},
	], result)

## 重開一局：歸零計數，重新開始擲香油錢。
func restart() -> void:
	throws_done = 0
	hits = 0
	perfects = 0
	_finished = false
	_new_throw()

# --- 視覺（全程式幾何）---

func _sink_coin() -> void:
	var tw := create_tween()
	tw.tween_property(_coin, "position:y", _coin.position.y + 30.0, 0.18)
	tw.parallel().tween_property(_coin, "modulate:a", 0.0, 0.18)

func _bounce_coin() -> void:
	var tw := create_tween()
	tw.tween_property(_coin, "position:y", _coin.position.y + 90.0, 0.3) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_coin, "modulate:a", 0.0, 0.35)

func _build_scene() -> void:
	# 背景：夜色神社前(幾何)
	var bg := ColorRect.new()
	bg.size = Vector2(1920, 1080)
	bg.color = Color(0.10, 0.10, 0.13)
	add_child(bg)
	# 賽錢箱：箱體+直櫺投入口+紅緣
	var box := Node2D.new()
	box.position = Vector2(960, 430)
	add_child(box)
	var body := ColorRect.new()
	body.size = Vector2(360, 190)
	body.position = Vector2(-180, -70)
	body.color = Color(0.30, 0.21, 0.13)
	box.add_child(body)
	var trim := ColorRect.new()
	trim.size = Vector2(376, 16)
	trim.position = Vector2(-188, -80)
	trim.color = Color(0.55, 0.14, 0.11)
	box.add_child(trim)
	for i in 7:
		var slat := ColorRect.new()
		slat.size = Vector2(14, 46)
		slat.position = Vector2(-140 + i * 44, -58)
		slat.color = Color(0.16, 0.11, 0.07)
		box.add_child(slat)
	# 銅錢
	_coin = Node2D.new()
	var disc := Polygon2D.new()
	var pts := PackedVector2Array()
	for a in range(20):
		var ang := TAU * a / 20.0
		pts.append(Vector2(cos(ang), sin(ang)) * 30.0)
	disc.polygon = pts
	disc.color = Color(0.788, 0.659, 0.38)
	_coin.add_child(disc)
	var hole := ColorRect.new()
	hole.size = Vector2(16, 16)
	hole.position = Vector2(-8, -8)
	hole.color = Color(0.10, 0.10, 0.13)
	_coin.add_child(hole)
	_coin.position = START_POS
	add_child(_coin)
	# 力度計
	var gauge_bg := ColorRect.new()
	gauge_bg.size = Vector2(36, 300)
	gauge_bg.position = Vector2(1520, 460)
	gauge_bg.color = Color(0.2, 0.2, 0.24)
	add_child(gauge_bg)
	_gauge_fill = ColorRect.new()
	_gauge_fill.size = Vector2(36, 0)
	_gauge_fill.position = Vector2(1520, 760)
	_gauge_fill.color = Color(0.788, 0.659, 0.38)
	add_child(_gauge_fill)
	# 佈局工具 v2（P4）：力度計整塊登記代表（gauge_bg/sweet 疊在同位置，
	# 隨此塊視覺同步，不重複登記）。父節點是本場景根節點（Node2D，非
	# Container），is_free()==true。
	LayoutStore.register(_gauge_fill, "minigame/offeringtoss/gauge")
	var sweet := ColorRect.new()   # 甜蜜點刻度
	sweet.size = Vector2(48, 4)
	sweet.position = Vector2(1514, 760.0 - 300.0 * POWER_SWEET)
	sweet.color = Color(0.95, 0.3, 0.3)
	add_child(sweet)
	_build_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(48, 36)
	_hud.add_theme_font_size_override("font_size", 40)
	_hud.add_theme_color_override("font_color", Color(0.788, 0.659, 0.38))
	layer.add_child(_hud)
	# 佈局工具 v2（P4）：左上 HUD 文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud, "minigame/offeringtoss/hud_label")
	_wind_label = Label.new()
	_wind_label.position = Vector2(820, 120)
	_wind_label.add_theme_font_size_override("font_size", 44)
	layer.add_child(_wind_label)
	# 佈局工具 v2（P4）：風向標籤整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_wind_label, "minigame/offeringtoss/wind_label")
	_judge_popup = Label.new()
	_judge_popup.position = Vector2(830, 560)
	_judge_popup.add_theme_font_size_override("font_size", 52)
	_judge_popup.modulate.a = 0.0
	layer.add_child(_judge_popup)
	# 佈局工具 v2（P4）：判定彈出字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_judge_popup, "minigame/offeringtoss/judge_popup")
	var tip := Label.new()
	tip.text = "看準力度與風向，按〔空白鍵〕投出香油錢"
	tip.position = Vector2(660, 990)
	tip.add_theme_font_size_override("font_size", 30)
	tip.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	layer.add_child(tip)
	_update_hud()

func _update_hud() -> void:
	if _hud:
		_hud.text = "投擲 %d/%d   命中 %d" % [throws_done, THROWS, hits]

func _update_wind_label() -> void:
	if _wind_label == null:
		return
	var n: int = clampi(int(ceil(absf(_wind) * 3.0)), 0, 3)
	var arrow: String = "←" if _wind < 0.0 else "→"
	_wind_label.text = "風  " + arrow.repeat(maxi(n, 1)) if n > 0 else "風  無"
	_wind_label.add_theme_color_override("font_color",
		Color(0.9, 0.55, 0.4) if n >= 2 else Color(0.7, 0.85, 1.0))

func _show_judge(text: String, color: Color) -> void:
	_judge_popup.text = text
	_judge_popup.modulate = color
	_judge_popup.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_judge_popup, "modulate:a", 0.0, 0.4)
