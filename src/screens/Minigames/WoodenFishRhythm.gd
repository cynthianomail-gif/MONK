extends "res://src/screens/Minigames/MinigameBase.gd"
## 三僧木魚 WoodenFishRhythm —— 節奏天國式 call-and-response。
## 每回合：大師兄敲一次 pattern → 二師兄原樣重複一次（玩家看兩遍）→
## 玩家無縫跟拍同一 pattern。12 回合曲目表見 ROUNDS（規格 2026-07-04 第 2 節）。
## 判定：時間基準取 AudioStreamPlayer 播放位置（有 BGM stream 時）；
## 沒有 stream（例如 headless 測試環境）則退回累計計時器，純邏輯照樣可測。

const PERFECT_MS: float = 60.0
const GOOD_MS: float = 120.0
const PERFECT_SCORE: int = 100
const GOOD_SCORE: int = 50
const NEW_ART_DIR: String = "res://assets/2d/minigames/woodenfish/"

## --- 12 回合曲目表 ---
## 每回合：{bpm, beats:[敲擊拍點，相對回合起點的「拍數」], distract:bool}
## R1-3 BPM90 三連拍等間隔／R4-6 BPM105 四連拍／R7-9 BPM105 切分／
## R10-12 BPM120 混合＋背景干擾（干擾只影響畫面，節奏不變）。
const ROUNDS: Array = [
	{"bpm": 90.0,  "beats": [0.0, 1.0, 2.0], "distract": false},
	{"bpm": 90.0,  "beats": [0.0, 1.0, 2.0], "distract": false},
	{"bpm": 90.0,  "beats": [0.0, 1.0, 2.0], "distract": false},
	{"bpm": 105.0, "beats": [0.0, 1.0, 2.0, 3.0], "distract": false},
	{"bpm": 105.0, "beats": [0.0, 1.0, 2.0, 3.0], "distract": false},
	{"bpm": 105.0, "beats": [0.0, 1.0, 2.0, 3.0], "distract": false},
	{"bpm": 105.0, "beats": [0.0, 0.5, 2.0], "distract": false},          # 摳摳．摳
	{"bpm": 105.0, "beats": [0.0, 1.5, 2.0], "distract": false},          # 摳．摳摳
	{"bpm": 105.0, "beats": [0.0, 0.5, 1.5, 2.0], "distract": false},     # 摳摳．摳摳
	{"bpm": 120.0, "beats": [0.0, 1.0, 1.5, 2.5], "distract": true},
	{"bpm": 120.0, "beats": [0.0, 0.5, 1.5, 2.0, 3.0], "distract": true},
	{"bpm": 120.0, "beats": [0.0, 0.5, 1.0, 2.0, 2.5], "distract": true},
]

## 回合內段落：大師兄示範 → 二師兄重複 → 玩家跟拍。段落間留 1 拍銜接緩衝。
enum Phase { DEMO_A, DEMO_B, PLAYER, ROUND_GAP, DONE }

@export var background_path: String = "res://assets/2d/backgrounds/bg_battle_temple.png"
@export var monk_a_idle_path: String = NEW_ART_DIR + "monk_a_idle.png"
@export var monk_a_raise_path: String = NEW_ART_DIR + "monk_a_raise.png"
@export var monk_a_hit_path: String = NEW_ART_DIR + "monk_a_hit.png"
@export var monk_a_look_right_path: String = NEW_ART_DIR + "monk_a_look_right.png"
@export var monk_b_idle_path: String = NEW_ART_DIR + "monk_b_idle.png"
@export var monk_b_raise_path: String = NEW_ART_DIR + "monk_b_raise.png"
@export var monk_b_hit_path: String = NEW_ART_DIR + "monk_b_hit.png"
@export var monk_b_look_right_path: String = NEW_ART_DIR + "monk_b_look_right.png"
@export var player_idle_path: String = NEW_ART_DIR + "player_idle.png"
@export var player_raise_path: String = NEW_ART_DIR + "player_raise.png"
@export var player_hit_path: String = NEW_ART_DIR + "player_hit.png"
@export var player_happy_path: String = NEW_ART_DIR + "player_happy.png"
@export var player_sweat_path: String = NEW_ART_DIR + "player_sweat.png"
@export var bg_path_v2: String = NEW_ART_DIR + "bg.png"
@export var bgm_id: String = "wooden_fish_loop"
@export var auto_start: bool = true

const MONK_A_POS := Vector2(560, 620)
const MONK_B_POS := Vector2(960, 620)
const PLAYER_POS := Vector2(1400, 620)
const FISH_A_POS := Vector2(560, 780)
const FISH_B_POS := Vector2(960, 820)
const FISH_PLAYER_POS := Vector2(1400, 780)

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var hits: int = 0            # perfect + good（玩家段命中數）
var perfects: int = 0
var total_taps: int = 0      # 玩家段應敲總拍數（評級分母）
var judged: int = 0          # 玩家段已判定拍數（含 miss）

var _round_idx: int = 0
var _phase: int = Phase.DEMO_A
var _round_start_ms: float = 0.0
var _running: bool = false
var _demo_taps_done: int = 0
var _player_beats: Array = []       # 玩家段的拍點副本（judge 用，含 done 旗標）
var _distract_active: bool = false

var _bgm_player: AudioStreamPlayer = null
var _clock_start_ms: float = 0.0    # 累計計時器模式（無 BGM stream）的起點

var _monk_a: Sprite2D
var _monk_b: Sprite2D
var _player_sprite: Sprite2D
var _fish_a: Node2D
var _fish_b: Node2D
var _fish_player: Node2D
var _hud: Label
var _judge_popup: Label
var _round_label: Label
var _distract_layer: Node2D
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "wooden_fish_rhythm"

func _ready() -> void:
	_rng.randomize()
	_build_scene()
	if auto_start:
		_start_game()

# ════════════════════════════════════════════════════════════════
# 純邏輯（測試用，不依賴 SceneTree）
# ════════════════════════════════════════════════════════════════

## 依離判定時刻的毫秒差判定。offset 取絕對值前可帶正負（正=晚 Late，負=早 Early）。
func judge_offset(offset_ms: float) -> String:
	var a := absf(offset_ms)
	if a <= PERFECT_MS:
		return "perfect"
	elif a <= GOOD_MS:
		return "good"
	return "miss"

## Early/Perfect/Late 顯示文字（offset_ms 為 有號 差值：實際時間 - 目標時間）。
func timing_label(offset_ms: float) -> String:
	var j := judge_offset(offset_ms)
	if j == "miss":
		return "MISS"
	if j == "perfect":
		return "PERFECT"
	return "EARLY" if offset_ms < 0.0 else "LATE"

func score_for(judgement: String) -> int:
	match judgement:
		"perfect": return PERFECT_SCORE
		"good": return GOOD_SCORE
		_: return 0

## 一回合的拍點時間表（毫秒，相對回合起點）。
func round_beat_times_ms(round_data: Dictionary) -> Array:
	var beat_ms: float = 60000.0 / float(round_data.bpm)
	var out: Array = []
	for b in round_data.beats:
		out.append(float(b) * beat_ms)
	return out

## 一回合三段落（示範A/示範B/玩家）各自的時長（毫秒）：
## 最後一拍時間 + 1 拍收尾緩衝。
func round_phase_duration_ms(round_data: Dictionary) -> float:
	var times: Array = round_beat_times_ms(round_data)
	var beat_ms: float = 60000.0 / float(round_data.bpm)
	var last: float = times[times.size() - 1] if times.size() > 0 else 0.0
	return last + beat_ms

## 命中得分率（0..1）：玩家段總得分 / 滿分。用於評級門檻。
func hit_rate() -> float:
	var total_beats := total_beats_count()
	if total_beats <= 0:
		return 0.0
	return float(score) / float(total_beats * PERFECT_SCORE)

func total_beats_count() -> int:
	var n := 0
	for r in ROUNDS:
		n += r.beats.size()
	return n

## 評級門檻（Megamix 式）：<60% Try Again／60-79 OK／80-99 Superb／100(全 Perfect) 入定圓滿。
func rating_for(rate: float, all_perfect: bool) -> String:
	if all_perfect and rate >= 0.999:
		return "入定圓滿"
	if rate < 0.60:
		return "Try Again"
	if rate < 0.80:
		return "OK"
	return "Superb"

## win = OK 以上（rate >= 0.60）。
func decide_win(rate: float) -> bool:
	return rate >= 0.60

## 支線場（quests.json ah_ming/jie 帶 quest context）win merit=3；
## 常駐休閒重玩（地圖「再切磋一場」，無 quest context）win merit=1。
## 沒有 SceneRouter autoload 的環境（headless 純邏輯測試）視同支線場，merit=3，
## 維持既有測試斷言與行為。
func _is_casual_replay() -> bool:
	if not is_inside_tree():
		return false
	if get_node_or_null("/root/SceneRouter") == null:
		return false
	return not SceneRouter.has_minigame_quest_context()

func build_result() -> Dictionary:
	var rate := hit_rate()
	var won := decide_win(rate)
	var all_perfect: bool = judged > 0 and perfects == total_beats_count()
	var rating := rating_for(rate, all_perfect)
	var win_merit := 1 if _is_casual_replay() else 3
	return make_result({
		"score": score, "win": won,
		"merit": win_merit if won else 0,
		"rating": rating,
	})

# ════════════════════════════════════════════════════════════════
# 時間基準：優先用 AudioStreamPlayer 播放位置，沒有 stream 時退回累計計時器。
# ════════════════════════════════════════════════════════════════

## 絕對時鐘（毫秒）：有播放中的 BGM stream 用播放位置＋延遲補償；
## 否則退回 Engine.get_ticks_msec 累計計時器（headless 測試路徑）。
func _clock_ms() -> float:
	if _bgm_player != null and is_instance_valid(_bgm_player) and _bgm_player.playing and _bgm_player.stream != null:
		var pos: float = _bgm_player.get_playback_position()
		pos += AudioServer.get_time_since_last_mix()
		pos -= AudioServer.get_output_latency()
		return maxf(0.0, pos * 1000.0)
	return Time.get_ticks_msec() - _clock_start_ms

## 相對目前段落起點（示範A/示範B/玩家段各自歸零）的毫秒數。
## BGM loop 迴繞時播放位置會歸零、時鐘倒退——偵測到就把段落起點重釘到當下
## 自我修復（本段拍點重播一次），避免拍點停擺。
func _now_ms() -> float:
	var now := _clock_ms() - _round_start_ms
	if now < -50.0:
		_round_start_ms = _clock_ms()
		now = 0.0
	return now

# ════════════════════════════════════════════════════════════════
# 流程
# ════════════════════════════════════════════════════════════════

func _start_game() -> void:
	_round_idx = 0
	_clock_start_ms = Time.get_ticks_msec()
	# BGM 是無節拍禪意底墊，只當氛圍不當節奏時鐘（_bgm_player 留 null，
	# 判定走累計計時器：確定性高、無 loop 迴繞問題；音訊時鐘路徑保留給
	# 未來真正對拍的曲目用）。缺檔時 switch_bgm 靜默跳過。
	if is_inside_tree():
		AudioManager.switch_bgm(bgm_id, 0.3)
	_running = true
	_start_round()

func _start_round() -> void:
	if _round_idx >= ROUNDS.size():
		_end()
		return
	_enter_phase(Phase.DEMO_A)
	var rd: Dictionary = ROUNDS[_round_idx]
	_distract_active = bool(rd.get("distract", false))
	_set_distraction(_distract_active)
	_update_round_label()
	_update_hud()

func _process(_delta: float) -> void:
	if not _running:
		return
	var rd: Dictionary = ROUNDS[_round_idx]
	var now := _now_ms()
	var times: Array = round_beat_times_ms(rd)
	var dur := round_phase_duration_ms(rd)
	match _phase:
		Phase.DEMO_A:
			_drive_demo(_monk_a, _tex_a, _fish_a, times, now, 0.85)
			if now >= dur:
				_enter_phase(Phase.DEMO_B)
		Phase.DEMO_B:
			_drive_demo(_monk_b, _tex_b, _fish_b, times, now, 1.0)
			if now >= dur:
				_enter_phase(Phase.PLAYER)
		Phase.PLAYER:
			_check_player_miss(now)
			if now >= dur:
				_enter_phase(Phase.ROUND_GAP)
		Phase.ROUND_GAP:
			_round_idx += 1
			_start_round()
		_:
			pass

## 切到指定段落：把段落起點釘在目前絕對時鐘（下個段落的拍點都相對這個時刻算）。
func _enter_phase(next: int) -> void:
	_phase = next
	_round_start_ms = _clock_ms()
	_demo_taps_done = 0
	_update_round_label()
	# 輪到誰，誰就換「舉槌」預備姿；其他人回 idle。
	_set_pose(_monk_a, _tex_a, "raise" if next == Phase.DEMO_A else "idle")
	_set_pose(_monk_b, _tex_b, "raise" if next == Phase.DEMO_B else "idle")
	_set_pose(_player_sprite, _tex_p, "raise" if next == Phase.PLAYER else "idle")
	if next == Phase.PLAYER:
		var rd: Dictionary = ROUNDS[_round_idx]
		_player_beats = []
		for t in round_beat_times_ms(rd):
			_player_beats.append({"target_ms": t, "done": false})

## 示範段：到了拍點就播放敲擊動作＋音效（大師兄/二師兄不會漏拍、不會被判定）。
func _drive_demo(monk: Sprite2D, tex_set: Dictionary, fish: Node2D, times: Array, now: float, pitch: float = 1.0) -> void:
	if _demo_taps_done < times.size() and now >= float(times[_demo_taps_done]):
		_demo_taps_done += 1
		_animate_demo_hit(monk, tex_set, fish)
		AudioManager.play_sfx("wooden_fish_tap", pitch)

func _check_player_miss(now: float) -> void:
	for b in _player_beats:
		if b.done:
			continue
		if now - b.target_ms > GOOD_MS:
			_register_player(b, "miss")

func _input(event: InputEvent) -> void:
	if not _running or _phase != Phase.PLAYER:
		return
	var tap: bool = (event.is_action_pressed("confirm")
		or event.is_action_pressed("interact")
		or (event is InputEventKey and event.pressed and not event.echo
			and event.keycode in [KEY_F, KEY_J, KEY_SPACE])
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT))
	if tap:
		_on_tap()

func _on_tap() -> void:
	var now := _now_ms()
	var best: Dictionary = {}
	var best_abs: float = GOOD_MS + 1.0
	for b in _player_beats:
		if b.done:
			continue
		var off: float = absf(now - b.target_ms)
		if off <= GOOD_MS and off < best_abs:
			best_abs = off
			best = b
	if best.is_empty():
		return   # 空敲不罰（節奏遊戲慣例）
	_register_player(best, judge_offset(now - best.target_ms), now - best.target_ms)

func _register_player(beat: Dictionary, judgement: String, signed_offset: float = 999.0) -> void:
	beat.done = true
	judged += 1
	total_taps += 1
	if judgement == "miss":
		combo = 0
		_show_judge("MISS", Color(0.8, 0.3, 0.3))
		_react_monk_look()
		_react_player("sweat")
		return
	hits += 1
	score += score_for(judgement)
	if judgement == "perfect":
		perfects += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	AudioManager.play_sfx("wooden_fish_tap", 1.15)
	if combo > 0 and combo % 10 == 0:
		AudioManager.play_sfx("combo_up")
	_animate_player_hit(judgement)
	var label := timing_label(signed_offset) if signed_offset != 999.0 else judgement.to_upper()
	_show_judge("%s  x%d" % [label, combo],
		Color(1, 0.85, 0.4) if judgement == "perfect" else Color(0.7, 0.85, 1))

func _end() -> void:
	_running = false
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	var rate := hit_rate()
	show_result_panel("三僧木魚", String(result.get("rating", "")), [
		{"label": "分數", "value": "%d" % score},
		{"label": "最大連段", "value": "%d" % max_combo},
		{"label": "命中率", "value": "%d%%" % int(rate * 100.0)},
		{"label": "功德", "value": "+%d" % result.merit},
	], result)

## 重開一局：歸零計分與回合進度，重新開始。
func restart() -> void:
	score = 0
	combo = 0
	max_combo = 0
	hits = 0
	perfects = 0
	total_taps = 0
	judged = 0
	_finished = false
	_set_distraction(false)
	_start_game()

# ════════════════════════════════════════════════════════════════
# 視覺
# ════════════════════════════════════════════════════════════════

## 三角色各自的姿勢差分組（idle/raise/hit），缺檔的鍵為 null（占位模式不換圖）。
var _tex_a: Dictionary = {}
var _tex_b: Dictionary = {}
var _tex_p: Dictionary = {}

func _build_scene() -> void:
	_add_background()
	_monk_a = _make_char_sprite(monk_a_idle_path, MONK_A_POS, "師", Color(0.5, 0.42, 0.3))
	_monk_b = _make_char_sprite(monk_b_idle_path, MONK_B_POS, "師", Color(0.45, 0.5, 0.35))
	_player_sprite = _make_char_sprite(player_idle_path, PLAYER_POS, "我", Color(0.35, 0.4, 0.55))
	# 佈局工具 v3：三立繪＝B1（position 只在 _make_char_sprite 建立時設一次，之後
	# 只換 texture/rotation），登記為可拖綠框。
	LayoutStore.register(_monk_a, "minigame/woodenfishrhythm/monk_a")
	LayoutStore.register(_monk_b, "minigame/woodenfishrhythm/monk_b")
	LayoutStore.register(_player_sprite, "minigame/woodenfishrhythm/player")
	_tex_a = _load_tex_set(monk_a_idle_path, monk_a_raise_path, monk_a_hit_path)
	_tex_b = _load_tex_set(monk_b_idle_path, monk_b_raise_path, monk_b_hit_path)
	_tex_p = _load_tex_set(player_idle_path, player_raise_path, player_hit_path)
	_fish_a = _make_fish(FISH_A_POS)
	_fish_b = _make_fish(FISH_B_POS)
	_fish_player = _make_fish(FISH_PLAYER_POS)
	# 佈局工具 v3：三個木魚錨點＝B1（position 只在 _make_fish 建立時設一次，敲擊
	# 只做 scale tween，不改 position；fx/判定彈出字都讀節點目前 position，
	# 例如 spawn_fx_sparkle(_fish_player.position, ...)，非獨立常數，拖曳安全），
	# 登記為可拖綠框（校正木魚 vs 立繪的對位）。
	LayoutStore.register(_fish_a, "minigame/woodenfishrhythm/fish_a")
	LayoutStore.register(_fish_b, "minigame/woodenfishrhythm/fish_b")
	LayoutStore.register(_fish_player, "minigame/woodenfishrhythm/fish_player")
	_distract_layer = Node2D.new()
	add_child(_distract_layer)
	_build_hud()

func _add_background() -> void:
	var tex := _try_load(bg_path_v2)
	if tex == null:
		tex = _try_load(background_path)
	if tex:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		var sz: Vector2 = tex.get_size()
		sp.scale = Vector2(1920.0 / sz.x, 1080.0 / sz.y)
		add_child(sp)
		# 佈局工具 v3：背景整塊登記（A 靜態，父節點是本場景根節點，非 Container，
		# is_free()==true）。不論走哪個 fallback 分支，建出來的節點都登記同一個 key。
		LayoutStore.register(sp, "minigame/woodenfishrhythm/bg")
	else:
		# 程式占位：黃昏漸層街景（純色塊，缺美術時的防呆）。
		var bg := ColorRect.new()
		bg.size = Vector2(1920, 1080)
		bg.color = Color(0.62, 0.45, 0.32)
		add_child(bg)
		LayoutStore.register(bg, "minigame/woodenfishrhythm/bg")
		var ground := ColorRect.new()
		ground.position = Vector2(0, 760)
		ground.size = Vector2(1920, 320)
		ground.color = Color(0.32, 0.24, 0.18)
		add_child(ground)

func _load_tex_set(idle_p: String, raise_p: String, hit_p: String) -> Dictionary:
	return {"idle": _try_load(idle_p), "raise": _try_load(raise_p), "hit": _try_load(hit_p)}

## 換姿勢差分；該幀缺檔就不動（占位角色保持原剪影）。
func _set_pose(sprite: Sprite2D, tex_set: Dictionary, pose: String) -> void:
	var tex: Texture2D = tex_set.get(pose)
	if tex != null and is_instance_valid(sprite):
		sprite.texture = tex

## 建立一個和尚/玩家角色的 Sprite2D 佔位（缺圖時用色塊+圓形頭畫出剪影）。
func _make_char_sprite(path: String, pos: Vector2, fallback_label: String, fallback_color: Color) -> Sprite2D:
	var sp := Sprite2D.new()
	var tex := _try_load(path)
	if tex:
		sp.texture = tex
		sp.position = pos
		sp.scale = Vector2(0.55, 0.55)
	else:
		sp.texture = _draw_placeholder_character(fallback_color, fallback_label)
		sp.position = pos
	add_child(sp)
	return sp

## 程式繪製佔位角色：body 色塊＋頭部圓形＋兩個點點眼（照專案「純色塊+圓形」慣例）。
func _draw_placeholder_character(color: Color, _label: String) -> ImageTexture:
	var w := 220
	var h := 320
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, Vector2(w * 0.5, h * 0.62), 90.0, color)
	_fill_circle(img, Vector2(w * 0.5, h * 0.22), 58.0, color.lightened(0.15))
	_fill_circle(img, Vector2(w * 0.5 - 20.0, h * 0.20), 6.0, Color(0.05, 0.05, 0.05))
	_fill_circle(img, Vector2(w * 0.5 + 20.0, h * 0.20), 6.0, Color(0.05, 0.05, 0.05))
	return ImageTexture.create_from_image(img)

func _fill_circle(img: Image, center: Vector2, r: float, color: Color) -> void:
	var x0 := maxi(0, int(center.x - r))
	var x1 := mini(img.get_width() - 1, int(center.x + r))
	var y0 := maxi(0, int(center.y - r))
	var y1 := mini(img.get_height() - 1, int(center.y + r))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if Vector2(x, y).distance_to(center) <= r:
				img.set_pixel(x, y, color)

## 純位置錨點（不畫任何木魚圖形）：Q 版生成的角色立繪本身已畫出木魚，
## 不再疊加寫實道具圖或程式繪製的色塊木魚。錨點保留給敲擊時的縮放彈跳動畫
## （_animate_demo_hit/_animate_player_hit 對這個 Node2D 做 scale tween）與
## Perfect 判定的 sparkle 特效定位（spawn_fx_sparkle(_fish_player.position, ...)）用。
func _make_fish(pos: Vector2) -> Node2D:
	var fish := Node2D.new()
	fish.position = pos
	add_child(fish)
	return fish

## 示範者敲擊：換「敲擊」幀＋木魚跳一下，收尾回「舉槌」預備姿（段落結束由 _enter_phase 收回 idle）。
func _animate_demo_hit(monk: Sprite2D, tex_set: Dictionary, fish: Node2D) -> void:
	_set_pose(monk, tex_set, "hit")
	var tw := create_tween()
	tw.tween_property(monk, "rotation_degrees", -6.0, 0.05)
	tw.tween_property(monk, "rotation_degrees", 0.0, 0.10)
	tw.tween_callback(func(): _set_pose(monk, tex_set, "raise"))
	var tw2 := create_tween()
	tw2.tween_property(fish, "scale", Vector2(0.85, 0.85), 0.05)
	tw2.tween_property(fish, "scale", Vector2(1, 1), 0.1)

## 玩家命中回饋：先換「敲擊」幀；Perfect=金光＋接微笑差分；Good=點頭後回「舉槌」；Miss 走 _react_player("sweat")。
func _animate_player_hit(judgement: String) -> void:
	_set_pose(_player_sprite, _tex_p, "hit")
	var tw := create_tween()
	tw.tween_property(_fish_player, "scale", Vector2(0.85, 0.85), 0.05)
	tw.tween_property(_fish_player, "scale", Vector2(1, 1), 0.1)
	if judgement == "perfect":
		spawn_fx_sparkle(_fish_player.position, 0.4)
	else:
		var tw2 := create_tween()
		tw2.tween_property(_player_sprite, "rotation_degrees", 4.0, 0.05)
		tw2.tween_property(_player_sprite, "rotation_degrees", 0.0, 0.12)
	var t := get_tree().create_timer(0.15)
	t.timeout.connect(func():
		if not is_instance_valid(_player_sprite):
			return
		if judgement == "perfect":
			_react_player("happy")
		else:
			_set_pose(_player_sprite, _tex_p, "raise" if _phase == Phase.PLAYER else "idle"))

## 切換玩家立繪到指定情緒差分（happy/sweat），播完自動切回 idle。
func _react_player(mood: String) -> void:
	var path := player_happy_path if mood == "happy" else player_sweat_path
	var tex := _try_load(path)
	if tex == null:
		return
	_player_sprite.texture = tex
	var idle_tex := _try_load(player_idle_path)
	if idle_tex == null:
		return
	var t := get_tree().create_timer(0.35)
	t.timeout.connect(func():
		if not is_instance_valid(_player_sprite):
			return
		# 玩家段內回「舉槌」預備姿，段落外才回 idle。
		var raise_tex: Texture2D = _tex_p.get("raise")
		if _phase == Phase.PLAYER and raise_tex != null:
			_player_sprite.texture = raise_tex
		else:
			_player_sprite.texture = idle_tex)

func _react_monk_look() -> void:
	var tex_a := _try_load(monk_a_look_right_path)
	var tex_b := _try_load(monk_b_look_right_path)
	if tex_a != null:
		_monk_a.texture = tex_a
	if tex_b != null:
		_monk_b.texture = tex_b
	var idle_a := _try_load(monk_a_idle_path)
	var idle_b := _try_load(monk_b_idle_path)
	var t := get_tree().create_timer(0.45)
	t.timeout.connect(func():
		if is_instance_valid(_monk_a) and idle_a != null:
			_monk_a.texture = idle_a
		if is_instance_valid(_monk_b) and idle_b != null:
			_monk_b.texture = idle_b)

## 背景干擾（R10-12）：煙火/路人穿場等純視覺元素，不影響節奏判定。
func _set_distraction(active: bool) -> void:
	for c in _distract_layer.get_children():
		c.queue_free()
	if not active:
		return
	var passerby := ColorRect.new()
	passerby.color = Color(0.15, 0.13, 0.12, 0.55)
	passerby.size = Vector2(40, 140)
	passerby.position = Vector2(-60, 780)
	# 佈局工具 v3：背景干擾路人＝C 類（loop tween 橫向掃過整個畫面），標樣板不可拖。
	passerby.set_meta("layout_template", "minigame/woodenfishrhythm/passerby")
	_distract_layer.add_child(passerby)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(passerby, "position:x", 1980.0, 3.2).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func(): passerby.position.x = -60.0)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_round_label = Label.new()
	_round_label.position = Vector2(48, 30)
	_round_label.add_theme_font_size_override("font_size", 30)
	_round_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	layer.add_child(_round_label)
	# 佈局工具 v2（P4）：回合標籤整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_round_label, "minigame/woodenfishrhythm/round_label")
	_hud = Label.new()
	_hud.text = "分數 0"
	_hud.position = Vector2(48, 76)
	_hud.add_theme_font_size_override("font_size", 40)
	_hud.add_theme_color_override("font_color", Color(0.788, 0.659, 0.38))
	layer.add_child(_hud)
	# 佈局工具 v2（P4）：分數 HUD 整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud, "minigame/woodenfishrhythm/hud_label")
	_judge_popup = Label.new()
	_judge_popup.position = Vector2(FISH_PLAYER_POS.x - 120, FISH_PLAYER_POS.y - 160)
	_judge_popup.add_theme_font_size_override("font_size", 44)
	_judge_popup.modulate.a = 0.0
	layer.add_child(_judge_popup)
	# 佈局工具 v2（P4）：判定彈出字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_judge_popup, "minigame/woodenfishrhythm/judge_popup")
	var t := Timer.new()
	t.wait_time = 0.1
	t.autostart = true
	t.timeout.connect(func() -> void:
		if _hud:
			_hud.text = "分數 %d   連段 %d" % [score, combo])
	add_child(t)

func _update_round_label() -> void:
	if _round_label:
		var phase_name: String = ["示範", "示範", "跟拍", "", ""][mini(_phase, 4)]
		_round_label.text = "第 %d/%d 回合　%s" % [_round_idx + 1, ROUNDS.size(), phase_name]

func _update_hud() -> void:
	if _hud:
		_hud.text = "分數 %d   連段 %d" % [score, combo]

func _show_judge(text: String, color: Color) -> void:
	if not _judge_popup:
		return
	_judge_popup.text = text
	_judge_popup.modulate = color
	_judge_popup.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_judge_popup, "modulate:a", 0.0, 0.5)

func _try_load(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
