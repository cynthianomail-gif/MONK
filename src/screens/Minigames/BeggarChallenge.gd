extends "res://src/screens/Minigames/MinigameBase.gd"
## 化緣 BeggarChallenge —— 「接缽化緣」接落物玩法（P5 重寫，2026-07-04）。
## 2D 側視街景：和尚捧缽在畫面下緣，←→/A·D 左右移動；路人（地面層）與二樓
## 住戶（上方）往下丟落物，和尚移動接住缽中。
## 規格：docs/superpowers/specs/2026-07-04-minigame-overhaul-design.md 第 5 節。

const DURATION: float = 60.0
const HARD_PHASE_AT: float = 40.0     # 剩 20 秒（60-40）進入後段難度曲線
const PLAY_LEFT: float = 120.0
const PLAY_RIGHT: float = 1800.0
const BOWL_Y: float = 940.0           # 缽所在高度（畫面下緣）
const BOWL_HALF_W: float = 90.0       # 缽的接取半寬（判定用）
const BOWL_SPEED: float = 780.0
const SPAWN_Y: float = 40.0           # 落物生成高度（貼近二樓住戶/路人拋擲點）
const FALL_SPEED_BASE: float = 340.0
const FALL_SPEED_HARD: float = 520.0
const SPAWN_INTERVAL_BASE: float = 0.85
const SPAWN_INTERVAL_HARD: float = 0.45
const TRASH_CHANCE_BASE: float = 0.18
const TRASH_CHANCE_HARD: float = 0.34
const COMBO_STEP: float = 1.1
const COMBO_CAP: float = 3.0
const TRASH_GOLD_PENALTY: int = 30

const MINIGAME_ART_DIR: String = "res://assets/art_direction/new_ink_shrine_style/minigames/"
## 接缽化緣正式美術（2026-07-04 Codex 交回，5 張）：缺檔仍走程式繪製佔位，零風險。
const BEGGAR_ART_DIR: String = "res://assets/2d/minigames/beggar/"
const PLAYER_BOWL_ART_PATH: String = BEGGAR_ART_DIR + "player_bowl.png"
## 落物正式圖：512x512 透明底，內容約佔畫面 70%。縮放到與佔位（半徑16~30、外框x1.3）
## 相近的顯示尺寸，讓辨識度與難度手感不因換圖而變。
const DROP_ART_SCALE: float = 0.16
const DROP_ART_PATHS: Dictionary = {
	"coin": BEGGAR_ART_DIR + "item_coin.png",
	"ingot": BEGGAR_ART_DIR + "item_ingot.png",
	"riceball": BEGGAR_ART_DIR + "item_riceball.png",
	"trash": BEGGAR_ART_DIR + "item_trash.png",
}

## 落物表：type -> {reward(金幣,飯糰用0)/merit_gain/weight/color(高飽和佔位色)/
## label/mark(落物中心單字標記)/mark_color}。佔位視覺＝粗黑描邊＋單字標記，正式美術後補。
const DROP_TYPES: Dictionary = {
	"coin":     {"gold": 15, "merit": 0, "weight": 0.55, "color": Color(1.0, 0.84, 0.10), "label": "銅板", "mark": "錢", "mark_color": Color(0.16, 0.10, 0.02)},
	"ingot":    {"gold": 80, "merit": 0, "weight": 0.12, "color": Color(1.0, 0.56, 0.10), "label": "元寶", "mark": "寶", "mark_color": Color(0.18, 0.08, 0.02)},
	"riceball": {"gold": 0,  "merit": 1, "weight": 0.15, "color": Color(0.99, 0.98, 0.93), "label": "飯糰", "mark": "米", "mark_color": Color(0.16, 0.12, 0.10)},
	"trash":    {"gold": -TRASH_GOLD_PENALTY, "merit": 0, "weight": 0.18, "color": Color(0.23, 0.30, 0.19), "label": "垃圾", "mark": "圾", "mark_color": Color(0.95, 0.95, 0.90)},
}

# 可抽換美術（留空＝用程式繪製的佔位）。
@export var background_path: String = "res://assets/2d/backgrounds/bg_battle_wanhua.png"
@export var monk_portrait_path: String = MINIGAME_ART_DIR + "wujie_beggar_front_game_ready.png"
@export var begging_sprite_path: String = MINIGAME_ART_DIR + "beggar_wujie_begging.png"
@export var citizen_sprite_paths: Dictionary = {
	"office_worker": [MINIGAME_ART_DIR + "beggar_ped_office_worker_a.png", MINIGAME_ART_DIR + "beggar_ped_office_worker_b.png"],
	"tourist": [MINIGAME_ART_DIR + "beggar_ped_tourist_a.png", MINIGAME_ART_DIR + "beggar_ped_tourist_b.png"],
	"rich_lady": [MINIGAME_ART_DIR + "beggar_ped_rich_lady_a.png", MINIGAME_ART_DIR + "beggar_ped_rich_lady_b.png"],
	"drunk_man": [MINIGAME_ART_DIR + "beggar_ped_drunk_man_a.png", MINIGAME_ART_DIR + "beggar_ped_drunk_man_b.png"],
}
@export var auto_start: bool = true   # 測試時設 false 以停用計時/生成

var score: int = 0                    # gold（下限 0，過程中即時夾）
var time_left: float = DURATION
var combo_mult: float = 1.0
var max_combo_mult: float = 1.0
var combo_count: int = 0              # 連續接到錢/飯糰的次數（merit 加成／連段紀錄用）
var max_combo_count: int = 0
var riceball_count: int = 0
var trash_caught: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false
var _bowl_x: float = 960.0
var _drops: Array[Dictionary] = []
var _hud_score: Label
var _hud_time: Label
var _hud_combo: Label
var _world: Node2D
var _bowl_node: Node2D
var _monk_sprite: Sprite2D           # 玩家捧缽立繪（水平翻轉轉向用，見 _move_bowl）
var _facing_right: bool = false      # player_bowl.png 原圖側身朝左＝false；往右移動翻轉為 true
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "beggar_challenge"

func _ready() -> void:
	_rng.randomize()
	_build_scene()
	if auto_start:
		_running = true

# --- 純邏輯（給測試直接呼叫，不依賴 SceneTree）---

## 是否進入後段難度曲線（剩 20 秒）。
func is_hard_phase(t_left: float) -> bool:
	return t_left <= (DURATION - HARD_PHASE_AT)

func current_fall_speed(t_left: float) -> float:
	return FALL_SPEED_HARD if is_hard_phase(t_left) else FALL_SPEED_BASE

func current_spawn_interval(t_left: float) -> float:
	return SPAWN_INTERVAL_HARD if is_hard_phase(t_left) else SPAWN_INTERVAL_BASE

func current_trash_chance(t_left: float) -> float:
	return TRASH_CHANCE_HARD if is_hard_phase(t_left) else TRASH_CHANCE_BASE

## 依權重（含難度曲線調整的垃圾比例）抽一種落物型別。
func weighted_pick_drop(t_left: float) -> String:
	var trash_chance: float = current_trash_chance(t_left)
	var non_trash_total: float = 0.0
	for type in DROP_TYPES:
		if type != "trash":
			non_trash_total += DROP_TYPES[type].weight
	var r: float = randf()
	if r < trash_chance:
		return "trash"
	# 剩餘機率依非垃圾權重比例分配
	var rem: float = (r - trash_chance) / maxf(0.0001, 1.0 - trash_chance)
	var acc: float = 0.0
	for type in DROP_TYPES:
		if type == "trash":
			continue
		acc += DROP_TYPES[type].weight / non_trash_total
		if rem <= acc:
			return type
	return "coin"

## 缽（中心 bowl_x，半寬 BOWL_HALF_W）是否接到掉在 drop_x 的落物。
func bowl_catches(bowl_x: float, drop_x: float) -> bool:
	return absf(bowl_x - drop_x) <= BOWL_HALF_W

## combo 倍率遞增一步（上限 COMBO_CAP）。
func step_combo_up(mult: float) -> float:
	return minf(COMBO_CAP, mult * COMBO_STEP)

## 是否已達 combo 倍率上限（滿 combo 隱藏評級用）。
func is_combo_maxed(mult: float) -> bool:
	return mult >= COMBO_CAP - 0.0001

## 接到一個落物的純邏輯處理：回傳 {gold_delta, merit_delta, karma_delta, new_combo, label}
## gold 下限在呼叫端（_apply_catch/測試）自行 clamp 到 0，這裡只回傳 delta。
func resolve_catch(type: String, mult: float) -> Dictionary:
	if not DROP_TYPES.has(type):
		return {"gold_delta": 0, "merit_delta": 0, "karma_delta": 0, "new_combo": mult, "label": ""}
	var info: Dictionary = DROP_TYPES[type]
	if type == "trash":
		return {"gold_delta": info.gold, "merit_delta": 0, "karma_delta": 1, "new_combo": 1.0, "label": info.label}
	var gold_delta: int = int(round(info.gold * mult))
	var merit_delta: int = info.merit
	return {
		"gold_delta": gold_delta, "merit_delta": merit_delta, "karma_delta": 0,
		"new_combo": step_combo_up(mult), "label": info.label,
	}

## 漏接（落物落地未被接到）：只斷 combo，不罰分。
func resolve_miss() -> float:
	return 1.0

## 結算 result：gold=score(下限0)；merit=飯糰數+(最高連擊次數/10)；karma=接到垃圾數。
func build_result() -> Dictionary:
	var merit_gain: int = riceball_count + int(max_combo_count / 10.0)
	return make_result({
		"score": score, "win": score >= win_threshold(),
		"gold": score, "merit": merit_gain, "karma": trash_caught,
	})

## 勝利門檻：分數三級評級的中檔（詳見 rating_for_score 說明）。
func win_threshold() -> int:
	return 500

## 三級評級（分數門檻）＋滿 combo 隱藏評級（達 ×3 上限）。
func rating_for_score(final_score: int, combo_maxed: bool) -> String:
	if combo_maxed:
		return "功德無量"   # 隱藏評級：全程幾乎不斷 combo
	if final_score >= 900:
		return "廣結善緣"
	if final_score >= 500:
		return "功德圓滿"
	return "空手而回"

# --- 遊戲流程 ---

func _process(delta: float) -> void:
	if not _running:
		return
	time_left -= delta
	if _hud_time:
		_hud_time.text = "%02d" % maxi(0, int(ceil(time_left)))
	if time_left <= 0.0:
		_end()
		return
	_spawn_timer += delta
	var interval: float = current_spawn_interval(time_left)
	if _spawn_timer >= interval:
		_spawn_timer = 0.0
		_spawn_drop()
	_move_bowl(delta)
	_update_drops(delta)

func _move_bowl(delta: float) -> void:
	var dir: float = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir += 1.0
	if dir == 0.0:
		return
	_bowl_x = clampf(_bowl_x + dir * BOWL_SPEED * delta, PLAY_LEFT, PLAY_RIGHT)
	if _bowl_node:
		_bowl_node.position.x = _bowl_x
	_update_facing(dir)

## 依移動方向翻轉玩家立繪（水平翻轉，不生新圖）。player_bowl.png 原圖側身朝左，
## 往左移動＝原圖朝向；往右移動＝翻轉。停住（dir==0，呼叫端已提早 return）保持最後朝向。
## 只翻 _monk_sprite 這個視覺節點，_bowl_node 本身（位置/碰撞判定邏輯）不受影響。
func _update_facing(dir: float) -> void:
	var want_right: bool = dir > 0.0
	if want_right == _facing_right:
		return
	_facing_right = want_right
	if _monk_sprite and is_instance_valid(_monk_sprite):
		_monk_sprite.flip_h = _facing_right

func _update_drops(delta: float) -> void:
	for i in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		var node: Node2D = d.node
		node.position.y += current_fall_speed(time_left) * delta
		# 落點陰影隨接近地面放大變深（墜落線索）
		if d.has("shadow") and is_instance_valid(d.shadow):
			var t: float = clampf(node.position.y / BOWL_Y, 0.0, 1.0)
			d.shadow.scale = Vector2.ONE * (0.45 + 0.55 * t)
			d.shadow.color.a = 0.18 + 0.32 * t
		if node.position.y >= BOWL_Y:
			if bowl_catches(_bowl_x, node.position.x):
				_apply_catch(d.type)
			else:
				_apply_miss()
			_free_drop(d)
			_drops.remove_at(i)

func _free_drop(d: Dictionary) -> void:
	if is_instance_valid(d.node):
		d.node.queue_free()
	if d.has("shadow") and is_instance_valid(d.shadow):
		d.shadow.queue_free()

func _apply_catch(type: String) -> void:
	var r: Dictionary = resolve_catch(type, combo_mult)
	score = maxi(0, score + int(r.gold_delta))
	if type == "riceball":
		riceball_count += 1
	if type == "trash":
		trash_caught += 1
		combo_count = 0
		AudioManager.play_sfx("ui_cancel")
	else:
		combo_count += 1
		max_combo_count = maxi(max_combo_count, combo_count)
		AudioManager.play_sfx("gold_collect")
	combo_mult = r.new_combo
	max_combo_mult = maxf(max_combo_mult, combo_mult)
	_popup_catch(type, r)
	_update_hud()

func _apply_miss() -> void:
	combo_mult = resolve_miss()
	combo_count = 0
	_update_hud()

func _spawn_drop() -> void:
	var type: String = weighted_pick_drop(time_left)
	# 生成 X 範圍 [PLAY_LEFT+40, PLAY_RIGHT-40] 嚴格落在缽的可移動範圍
	# [PLAY_LEFT, PLAY_RIGHT]（見 _move_bowl 的 clampf）內，保證每顆落物都接得到。
	var x: float = _rng.randf_range(PLAY_LEFT + 40.0, PLAY_RIGHT - 40.0)
	_add_drop(type, Vector2(x, SPAWN_Y))

## 建立一顆落物，加進 _drops。有正式美術（item_*.png）就用 Sprite2D 顯示，
## 剪影本身已粗墨線／高辨識度，不再疊黑描邊與單字標記；缺圖才走程式繪製佔位
## （黑描邊＋中心單字標記，2026-07-04 前的舊視覺）。地面落點陰影兩種情況都留，
## 是「往哪接」的落點提示，跟美術風格無關。
func _add_drop(type: String, pos: Vector2) -> void:
	var info: Dictionary = DROP_TYPES[type]
	var node := Node2D.new()
	node.position = pos
	var art_path: String = String(DROP_ART_PATHS.get(type, ""))
	var art_tex: Texture2D = _try_load(art_path)
	if art_tex:
		if type == "trash":
			# 業障警示圈（fresh review F1）：trash 正式圖是濁色系，暗區會融進水墨底、
			# 辨識度低於其他落物；墊一圈暗紅 rim 讓「不要接」一眼可辨。純視覺不碰判定。
			var warn := Line2D.new()
			warn.points = _ellipse_points(46.0, 46.0)
			warn.closed = true
			warn.width = 5.0
			warn.default_color = Color(0.62, 0.14, 0.18, 0.85)
			node.add_child(warn)
		var sp := Sprite2D.new()
		sp.texture = art_tex
		sp.scale = Vector2.ONE * DROP_ART_SCALE
		node.add_child(sp)
	else:
		var outline := Polygon2D.new()
		outline.polygon = _drop_shape(type)
		outline.scale = Vector2(1.3, 1.3)
		outline.color = Color(0.05, 0.04, 0.05)
		node.add_child(outline)
		var shape := Polygon2D.new()
		shape.polygon = _drop_shape(type)
		shape.color = info.color
		node.add_child(shape)
		var mark := Label.new()
		mark.text = String(info.mark)
		mark.size = Vector2(60, 40)
		mark.position = Vector2(-30, -21)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var mark_ls := LabelSettings.new()
		mark_ls.font_size = 26
		mark_ls.font_color = info.mark_color
		mark.label_settings = mark_ls
		node.add_child(mark)
	_world.add_child(node)
	# 地面落點陰影：標在缽的高度、落物的 X，玩家一眼看出要去哪裡接。
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_points(30.0, 9.0)
	shadow.color = Color(0.05, 0.04, 0.05, 0.30)
	if type == "trash":
		# 垃圾的落點陰影染紅（_update_drops 只動 alpha，紅色會保留）——「別站這」訊號。
		shadow.color = Color(0.45, 0.07, 0.10, 0.40)
	shadow.position = Vector2(pos.x, BOWL_Y + 16.0)
	_world.add_child(shadow)
	_drops.append({"node": node, "type": type, "shadow": shadow})

func _drop_shape(type: String) -> PackedVector2Array:
	match type:
		"ingot":
			return PackedVector2Array([
				Vector2(-24, -12), Vector2(24, -12), Vector2(30, 12), Vector2(-30, 12)])
		"riceball":
			var pts := PackedVector2Array()
			for a in range(10):
				var ang: float = TAU * a / 10.0
				pts.append(Vector2(cos(ang), sin(ang)) * 22.0)
			return pts
		"trash":
			return PackedVector2Array([
				Vector2(-20, -20), Vector2(20, -20), Vector2(24, 18), Vector2(-24, 18)])
		_:
			var pts2 := PackedVector2Array()
			for a in range(12):
				var ang2: float = TAU * a / 12.0
				pts2.append(Vector2(cos(ang2), sin(ang2)) * 16.0)
			return pts2

func _popup_catch(type: String, r: Dictionary) -> void:
	var info: Dictionary = DROP_TYPES[type]
	var text: String
	var color: Color
	if type == "trash":
		text = "%s -%d" % [info.label, TRASH_GOLD_PENALTY]
		color = Color(0.85, 0.4, 0.35)
	elif type == "riceball":
		text = "%s 功德+1" % info.label
		color = Color(0.95, 0.92, 0.85)
	else:
		text = "%s +%d" % [info.label, int(r.gold_delta)]
		color = Color(1, 0.9, 0.4)
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(_bowl_x - 40, BOWL_Y - 120)
	lbl.label_settings = _hud_label_settings(32, color)
	_world.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 70, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)

func _end() -> void:
	_running = false
	var r: Dictionary = build_result()
	var combo_maxed: bool = is_combo_maxed(max_combo_mult)
	var rating: String = rating_for_score(score, combo_maxed)
	show_result_panel("化緣", rating, [
		{"label": "功德金", "value": "%d" % score},
		{"label": "飯糰", "value": "%d" % riceball_count},
		{"label": "最高連擊", "value": "x%.1f" % max_combo_mult},
		{"label": "接到垃圾", "value": "%d" % trash_caught},
		{"label": "業障", "value": "+%d" % r.karma},
	], r)

## 重開一局：清空落物（含落點陰影）、歸零計分/連擊/計時，重新開始倒數。
func restart() -> void:
	for d in _drops:
		_free_drop(d)
	_drops.clear()
	score = 0
	time_left = DURATION
	combo_mult = 1.0
	max_combo_mult = 1.0
	combo_count = 0
	max_combo_count = 0
	riceball_count = 0
	trash_caught = 0
	_spawn_timer = 0.0
	_bowl_x = 960.0
	if _bowl_node:
		_bowl_node.position.x = _bowl_x
	_facing_right = false
	if _monk_sprite and is_instance_valid(_monk_sprite):
		_monk_sprite.flip_h = false
	_finished = false
	_update_hud()
	_running = true

# --- 場景搭建（純程式，方便抽換）---

func _build_scene() -> void:
	_add_background(background_path, Color(0.12, 0.1, 0.14))
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_build_bowl()
	_build_hud()

func _build_bowl() -> void:
	_bowl_node = Node2D.new()
	_bowl_node.position = Vector2(_bowl_x, BOWL_Y)
	var monk := Sprite2D.new()
	# 正式美術優先序：player_bowl.png（2026-07-04 Codex 交回，683x1024 側身朝左捧缽）
	# → 舊 art_direction 佔位路徑（begging_sprite_path，目前無檔）→ 程式繪製佔位。
	var player_tex: Texture2D = _try_load(PLAYER_BOWL_ART_PATH)
	var tex: Texture2D = player_tex if player_tex else _try_load(begging_sprite_path)
	if player_tex:
		# player_bowl.png 缽口實測位在畫面 (28.55%, 32.61%)（centered Sprite2D 原點在中心，
		# 換算成相對缽節點原點的偏移），對齊到與舊佔位相同的接取判定高度 (0, -78)。
		monk.texture = player_tex
		monk.scale = Vector2.ONE * 0.33203125
		monk.position = Vector2(48.64, -18.87)
		_bowl_node.add_child(monk)
		_monk_sprite = monk
		var hint := Polygon2D.new()
		hint.polygon = _ellipse_points(BOWL_HALF_W, 22.0)
		hint.color = Color(0.95, 0.85, 0.5, 0.16)
		hint.position = Vector2(0.0, -78.0)
		_bowl_node.add_child(hint)
	elif tex:
		# 側視捧缽立繪本身已畫出缽（缽在胸前偏左），program-drawn 判定範圍只需
		# 淡淡疊一層半透明提示圈，避免蓋掉美術本身的缽造型。
		monk.texture = tex
		monk.position = Vector2(0, -100)
		monk.scale = Vector2(0.31, 0.31)
		_bowl_node.add_child(monk)
		_monk_sprite = monk
		var hint := Polygon2D.new()
		hint.polygon = _ellipse_points(BOWL_HALF_W, 22.0)
		hint.color = Color(0.95, 0.85, 0.5, 0.16)
		hint.position = Vector2(-56.0, -78.0)   # 對齊立繪中缽的位置
		_bowl_node.add_child(hint)
	else:
		# 無美術時的程式繪製佔位：簡化人形＋碗狀缽（窄底寬口）。
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-40, 0), Vector2(40, 0), Vector2(30, -180), Vector2(-30, -180)])
		body.color = Color(0.75, 0.6, 0.3)
		_bowl_node.add_child(body)
		var bowl := Polygon2D.new()
		bowl.polygon = PackedVector2Array([
			Vector2(-BOWL_HALF_W, -34), Vector2(BOWL_HALF_W, -34),
			Vector2(BOWL_HALF_W * 0.55, 6), Vector2(-BOWL_HALF_W * 0.55, 6)])
		bowl.color = Color(0.4, 0.28, 0.12)
		bowl.position = Vector2(0, -60)
		_bowl_node.add_child(bowl)
		var rim := Polygon2D.new()
		rim.polygon = PackedVector2Array([
			Vector2(-BOWL_HALF_W, -38), Vector2(BOWL_HALF_W, -38),
			Vector2(BOWL_HALF_W, -30), Vector2(-BOWL_HALF_W, -30)])
		rim.color = Color(0.55, 0.4, 0.18)
		rim.position = Vector2(0, -60)
		_bowl_node.add_child(rim)
	_world.add_child(_bowl_node)

func _ellipse_points(rx: float, ry: float, segments: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var ang: float = TAU * i / float(segments)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# HUD 一律走 LabelSettings 描邊（MapScreen/Batting HUD 慣例），
	# 否則金色字疊米黃水墨背景會同調不可讀。
	_hud_score = Label.new()
	_hud_score.text = "功德金：0"
	_hud_score.position = Vector2(48, 36)
	_hud_score.label_settings = _hud_label_settings(40, Color(0.95, 0.80, 0.42))
	layer.add_child(_hud_score)
	# 佈局工具 v2（P4）：功德金 HUD 整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud_score, "minigame/beggarchallenge/hud_score")
	_hud_combo = Label.new()
	_hud_combo.text = "連擊 x1.0"
	_hud_combo.position = Vector2(48, 90)
	_hud_combo.label_settings = _hud_label_settings(28, Color(0.92, 0.88, 0.80))
	layer.add_child(_hud_combo)
	# 佈局工具 v2（P4）：連擊 HUD 整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud_combo, "minigame/beggarchallenge/hud_combo")
	_hud_time = Label.new()
	_hud_time.text = "%02d" % int(DURATION)
	_hud_time.position = Vector2(1820, 36)
	_hud_time.label_settings = _hud_label_settings(48, Color(0.97, 0.94, 0.88))
	layer.add_child(_hud_time)
	# 佈局工具 v2（P4）：倒數計時 HUD 整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud_time, "minigame/beggarchallenge/hud_time")

func _hud_label_settings(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 10
	ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	return ls

func _update_hud() -> void:
	if _hud_score:
		_hud_score.text = "功德金：%d" % score
	if _hud_combo:
		_hud_combo.text = "連擊 x%.1f" % combo_mult

func _add_background(path: String, fallback: Color) -> void:
	var tex := _try_load(path)
	if tex:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		var sz: Vector2 = tex.get_size()
		sp.scale = Vector2(1920.0 / sz.x, 1080.0 / sz.y)
		add_child(sp)
	else:
		var bg := ColorRect.new()
		bg.size = Vector2(1920, 1080)
		bg.color = fallback
		add_child(bg)

func _try_load(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
