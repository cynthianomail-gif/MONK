extends Node3D
## 程式化「軍火庫地下遊藝場」室內房間（幾何盒體＋stylized 程序材質，無 toon/描邊）。
## ⚠**刻意不沿用 ArmoryDistrict 的暗鋼鐵浪板調**——設定是「藏在軍火庫底下的
## 金碧輝煌賭場」，反差就是賣點：外頭仍是軍火庫街的骯髒工業風入口，走進來
## 卻是酒紅絨牆＋金色包邊＋水晶吊燈的賭窟。室內＝10×14m 長方形房、四面牆
## (玩家碰撞+相機遮擋)、天花板、無月光全靠吊燈/燭台/吊燈撐光。
## 3 個賭具互動點(飛鏢/輪盤/21點)＋1 個出口，各自一個 LocationTrigger
## （打擊籠/保齡球 2026-07-03 搬到神社街當店家，見 ShrineStreet._build_minigame_signs）；
## 輪盤桌後站一個程式化荷官假人（無新美術，等 Codex 真人立繪再換）。
##
## ⚠與 shrine/armory 不同：本場景「不是」MapScreen 宿主下的子環境，而是
## SceneRouter.go_to_scene() 直切的獨立 current_scene（進場端＝MapScreen 的
## enter_parlor 動作，先 _store_position 再切過來）。所以互動(E 鍵)/提示 UI
## 由本腳本自理，不經 map_npcs.json；出口走 SceneRouter.go_to_map()——
## MapScreen 會照 current_area="armory"＋last_position 把玩家放回街上入口
## （直接 go_to_scene(ArmoryDistrict.tscn) 會變成沒 HUD 沒觸發點的裸街，不能走那條）。

const PLASTER_SHADER := preload("res://assets/shaders/stylized/plaster.gdshader")
const LOCATION_TRIGGER := preload("res://src/screens/MapScreen/LocationTrigger.tscn")

const SELF_SCENE := "res://src/screens/MapScreen/environments/UndergroundParlor.tscn"
const PARLOR_ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"

# 房間版型（世界座標，房中心＝原點）：x∈[-HALF_W,HALF_W]、z∈[-HALF_D,HALF_D]
const HALF_W := 5.0    # 寬 10m
const HALF_D := 7.0    # 深 14m
const WALL_H := 5.0

## 賭具互動點（+出口）。minigame=""＝出口。id 沿交接文件的 action id。
const STATIONS: Array = [
	{"id": "darts_minigame",     "name": "飛鏢靶",   "minigame": "darts",
		"pos": Vector3(0.0, 0.0, -5.6), "radius": 1.6},
	{"id": "roulette_minigame",  "name": "輪盤桌",   "minigame": "roulette",
		"pos": Vector3(-3.2, 0.0, -1.8), "radius": 1.6},
	{"id": "blackjack_minigame", "name": "21點桌",   "minigame": "blackjack",
		"pos": Vector3(3.2, 0.0, -1.8), "radius": 1.6},
	{"id": "leave_parlor",       "name": "離開遊藝場", "minigame": "",
		"pos": Vector3(0.0, 0.0, 6.0), "radius": 1.6},
]

var _current_station: Dictionary = {}
var _prompt: Label = null
var _toast: Label = null
var _toast_tween: Tween = null

func _ready() -> void:
	_register_interact_action()
	_build_env(self)
	_build_room(self)
	_build_ceiling_beams(self)
	_build_pillars(self)
	_build_carpet(self)
	_build_medallion(self)
	_build_props(self)
	_build_decor(self)
	_build_chandelier(self)
	_build_hanging_lanterns(self)
	_build_slots(self)
	_build_signs(self)
	_build_dealer(self)
	_build_triggers(self)
	_build_prompt_ui()
	_build_ambient(self)
	_fix_player_deferred()
	print("UNDERGROUND_PARLOR ready")

# ── 互動（自理，不經 MapScreen）────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()

func _interact() -> void:
	if _current_station.is_empty():
		return
	var mg := String(_current_station.get("minigame", ""))
	if mg == "":
		SceneRouter.go_to_map()   # 回軍火庫街（MapScreen 依 last_position 落回入口）
		return
	var path: String = "res://src/screens/Minigames/%s.tscn" % mg.to_pascal_case()
	if not ResourceLoader.exists(path):
		_show_toast("「%s」還在籌備中…" % String(_current_station.get("name", mg)))
		return
	# 帶 return_scene：小遊戲結束回遊藝場房間，而不是回城市地圖。
	SceneRouter.go_to_minigame(mg, {"return_scene": SELF_SCENE})

func _on_trigger_entered(station: Dictionary) -> void:
	_current_station = station
	_prompt.text = "〔E〕%s" % String(station.get("name", ""))
	_prompt.visible = true

func _on_trigger_exited(station: Dictionary) -> void:
	if _current_station.get("id", "") == station.get("id", ""):
		_current_station = {}
		_prompt.visible = false

## 執行期註冊「interact」(E)——與 MapScreen 相同手法；平常從 MapScreen 進來時
## 動作已存在，這裡是保險（測試/直開場景時也要能互動）。
func _register_interact_action() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)

func _build_triggers(root: Node3D) -> void:
	for s in STATIONS:
		var trig: Area3D = LOCATION_TRIGGER.instantiate()
		root.add_child(trig)
		var p: Vector3 = s.pos
		trig.setup(String(s.id), {
			"name": String(s.name),
			"position_3d": {"x": p.x, "y": p.y, "z": p.z},
			"trigger_radius": float(s.radius),
		})
		trig.player_entered.connect(_on_trigger_entered.bind(s))
		trig.player_exited.connect(_on_trigger_exited.bind(s))

# ── 提示/吐司 UI（無 MapScreen HUD，自帶最小版）────────────
func _build_prompt_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_prompt = _make_label(Color(1.0, 0.93, 0.78))
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.86
	_prompt.anchor_bottom = 0.92
	_prompt.visible = false
	layer.add_child(_prompt)
	_toast = _make_label(Color(0.95, 0.82, 0.55))
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.10
	_toast.anchor_bottom = 0.16
	_toast.visible = false
	layer.add_child(_toast)

func _make_label(col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 26
	ls.font_color = col
	ls.outline_size = 8
	ls.outline_color = Color(0.06, 0.05, 0.06, 0.9)
	l.label_settings = ls
	return l

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)

# ── 環境音：沿用軍火庫夜調單一軌。音檔缺就靜默跳過 ──────────
func _build_ambient(root: Node3D) -> void:
	var path := "res://assets/audio/ambient/ambient_armory.ogg"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.volume_db = -12.0
	player.stream = stream
	root.add_child(player)
	player.play()

# ── 環境：封閉室內，無月光，全靠吊燈/燭台/吊燈撐光（金色調賭窟）──────
func _build_env(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.41, 0.32)          # 偏金的環境光，取代原本偏灰白
	env.ambient_light_energy = 0.95                            # 室內無月光，ambient 要撐住可視度（0.55 實測全黑）
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.75                                  # 拉高，讓金屬包邊/水晶燈有賭場該有的浮光
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.30                               # ⚠踩雷：1.05 太低，連皮膚色一般漫反射面都被糊成光斑（荷官頭變一團），
	                                                             # 拉回接近 armory 原值(1.18)再加一點，只讓真正 emissive(金邊/吊燈) 發光
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.15, 0.10)             # 室內雪茄煙霧，偏暖金
	env.fog_density = 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08                            # 紅絨/金色要飽和一點才「金碧輝煌」
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

# ── 房體：地板(碰撞)+四牆(碰撞+相機遮擋)+天花板（酒紅絨牆＋金色包邊）───
func _build_room(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(HALF_W * 2 + 0.8, 0.2, HALF_D * 2 + 0.8)
	ground.mesh = gb
	ground.position = Vector3(0, -0.1, 0)
	ground.material_override = _ground_mat()
	root.add_child(ground)
	var floor_body := StaticBody3D.new()
	var cshape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = gb.size
	cshape.shape = box
	floor_body.add_child(cshape)
	floor_body.position = ground.position
	root.add_child(floor_body)

	# 四面牆：酒紅絨面（取代軍火庫浪板鐵皮）＋玩家碰撞＋相機 spring-arm 遮擋
	var wall_col := Color(0.26, 0.06, 0.09)
	var specs: Array = [
		[Vector3(0, WALL_H * 0.5, -HALF_D - 0.2), Vector3(HALF_W * 2 + 0.8, WALL_H, 0.4)],  # 北
		[Vector3(0, WALL_H * 0.5, HALF_D + 0.2), Vector3(HALF_W * 2 + 0.8, WALL_H, 0.4)],   # 南
		[Vector3(-HALF_W - 0.2, WALL_H * 0.5, 0), Vector3(0.4, WALL_H, HALF_D * 2 + 0.8)],  # 西
		[Vector3(HALF_W + 0.2, WALL_H * 0.5, 0), Vector3(0.4, WALL_H, HALF_D * 2 + 0.8)],   # 東
	]
	for sp in specs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sp[1]
		mi.mesh = bm
		mi.position = sp[0]
		mi.material_override = _flat_mat(wall_col)
		root.add_child(mi)
		_wall(root, sp[0], sp[1])
		_cam_blocker(root, sp[0], sp[1])

	# 金色頂線(天花板下)＋踢腳線(近地)，沿房間內側四面走一圈（各自算貼內牆座標，比在迴圈裡算內縮方向清楚）
	var trims: Array = [
		[Vector3(0, 0, -HALF_D - 0.02), Vector3(HALF_W * 2, 0.14, 0.06)],   # 北
		[Vector3(0, 0, HALF_D + 0.02), Vector3(HALF_W * 2, 0.14, 0.06)],    # 南
		[Vector3(-HALF_W - 0.02, 0, 0), Vector3(0.06, 0.14, HALF_D * 2)],   # 西
		[Vector3(HALF_W + 0.02, 0, 0), Vector3(0.06, 0.14, HALF_D * 2)],    # 東
	]
	for t in trims:
		var base: Vector3 = t[0]
		var size: Vector3 = t[1]
		_gold_box(root, base + Vector3(0, WALL_H - 0.2, 0), size, 0.35)   # 頂線
		_gold_box(root, base + Vector3(0, 0.14, 0), size, 0.20)          # 踢腳線

	# 天花板（暗酒紅，不加相機遮擋——相機在室內天花板下運作）
	_box(root, Vector3(0, WALL_H + 0.1, 0), Vector3(HALF_W * 2 + 0.8, 0.2, HALF_D * 2 + 0.8), Color(0.09, 0.05, 0.06))

## 桌具實體碰撞（圓柱/方桌都用 box 近似）：玩家不能穿桌而過；觸發半徑(1.6)
## 比桌身大，隔著桌沿一樣能互動。
func _table_collider(root: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = center
	root.add_child(body)

# ── 賭具道具＋燈光（鎏金包邊＋籌碼點綴，取代軍火庫調的素樸盒體）───────
func _build_props(root: Node3D) -> void:
	var wood := Color(0.34, 0.26, 0.16)

	# 飛鏢靶（北牆）：Codex 真圖上牆（自帶鐵框），兩側紅絨簾幕
	_tex_quad(root, PARLOR_ART + "darts_board_game_ready.png",
		Vector3(0, 1.75, -HALF_D + 0.16), Vector2(1.7, 1.7), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		for k in range(3):
			var cx: float = side * (1.5 + float(k) * 0.22)
			_box(root, Vector3(cx, 2.0, -HALF_D + 0.10 + float(k % 2) * 0.04),
				Vector3(0.18, 3.6, 0.12), Color(0.30, 0.05, 0.08) if k % 2 == 0 else Color(0.22, 0.04, 0.06))

	# 輪盤桌（西中）：木圓桌＋Codex 輪盤面真圖平放＋金邊＋籌碼
	_table_collider(root, Vector3(-3.2, 0.45, -1.8), Vector3(1.9, 0.9, 1.9))
	_cylinder(root, Vector3(-3.2, 0.42, -1.8), 0.95, 0.84, wood)
	_gold_cylinder(root, Vector3(-3.2, 0.90, -1.8), 0.92, 0.06, 0.4)
	_tex_quad(root, PARLOR_ART + "roulette_wheel_top_game_ready.png",
		Vector3(-3.2, 0.945, -1.8), Vector2(1.72, 1.72), Vector3(-90, 0, 0))
	_chip_stack(root, Vector3(-2.5, 0.96, -2.3))

	# 21點桌（東中）：方桌＋墨綠絨面＋金邊框＋牌背真圖＋籌碼
	_table_collider(root, Vector3(3.2, 0.45, -1.8), Vector3(1.9, 0.9, 1.2))
	_box(root, Vector3(3.2, 0.45, -1.8), Vector3(1.9, 0.9, 1.2), wood)
	_gold_box(root, Vector3(3.2, 0.905, -1.8), Vector3(1.94, 0.03, 1.24), 0.4)
	_box(root, Vector3(3.2, 0.93, -1.8), Vector3(1.8, 0.06, 1.1), Color(0.12, 0.30, 0.20))
	_tex_quad(root, PARLOR_ART + "card_back_game_ready.png",
		Vector3(2.95, 0.965, -1.65), Vector2(0.24, 0.24), Vector3(-90, 18, 0))
	_tex_quad(root, PARLOR_ART + "card_back_game_ready.png",
		Vector3(3.45, 0.965, -1.95), Vector2(0.24, 0.24), Vector3(-90, -12, 0))
	_chip_stack(root, Vector3(2.5, 0.96, -2.2))
	_chip_stack(root, Vector3(3.8, 0.96, -1.4))
	# 兩桌各配紅絨圓凳
	for sp in [Vector3(-2.15, 0, -1.1), Vector3(-2.55, 0, -2.65), Vector3(2.2, 0, -1.1), Vector3(2.6, 0, -2.6)]:
		_stool(root, sp)

	# 出口（南牆）：金框門洞＋暖光＋一盞紅燈籠（唯一留下的軍火庫連結，暗示「這道
	# 門通回外頭那個世界」）
	_gold_box(root, Vector3(-0.85, 1.3, HALF_D - 0.05), Vector3(0.22, 2.6, 0.3), 0.35)
	_gold_box(root, Vector3(0.85, 1.3, HALF_D - 0.05), Vector3(0.22, 2.6, 0.3), 0.35)
	_gold_box(root, Vector3(0, 2.7, HALF_D - 0.05), Vector3(1.9, 0.24, 0.3), 0.4)
	_emissive(root, Vector3(0, 1.25, HALF_D - 0.02), Vector3(1.5, 2.3, 0.08), Color(0.85, 0.48, 0.24), 1.0)
	_emissive(root, Vector3(1.4, 2.3, HALF_D - 0.5), Vector3(0.38, 0.5, 0.38), Color(0.85, 0.20, 0.12), 1.7)
	_omni(root, Vector3(1.4, 2.3, HALF_D - 0.5), Color(0.95, 0.34, 0.20), 2.0, 9.0)

	# 吊燈：兩張賭桌上方各一盞水晶吊燈（金框＋暖白光，取代原本純鐵罩暖橘燈）
	for x in [-3.2, 3.2]:
		_gold_box(root, Vector3(x, 4.3, -1.8), Vector3(0.05, 1.4, 0.05), 0.2)
		_gold_cylinder(root, Vector3(x, 3.5, -1.8), 0.42, 0.3, 0.45)
		_emissive(root, Vector3(x, 3.32, -1.8), Vector3(0.24, 0.10, 0.24), Color(1.0, 0.88, 0.62), 2.4)
		_omni(root, Vector3(x, 3.1, -1.8), Color(1.0, 0.82, 0.55), 2.8, 10.0)
	# 房中央補光（照亮地板/走道，室內無月光時的主可視度來源）
	_omni(root, Vector3(0, 4.0, 1.5), Color(1.0, 0.85, 0.62), 1.5, 13.0)
	# 飛鏢靶上打光
	_omni(root, Vector3(0, 2.8, -5.4), Color(1.0, 0.78, 0.48), 2.0, 7.0)
	# 房間三角落金燭台（取代軍火庫調的紅燈籠——賭窟氣氛改走暖金，非工業紅）
	for corner in [Vector3(-4.2, 3.2, -6.2), Vector3(4.2, 3.2, -6.2), Vector3(-4.2, 3.2, 6.2)]:
		_sconce(root, corner)

# ── 裝飾層（2026-07-03 使用者反饋「房間有點空」）：南半段補滿 ─────────
## 全部純視覺無觸發：裝飾第二桌×2（21點/輪盤，客人視角「還有別桌在開」）、
## 東南角吧台酒架、紅毯兩側絨繩圍欄柱、東西牆金框掛畫、裝飾桌上方吊燈籠。
## 位置都避開 4 個觸發點(r1.6)與紅毯動線(x∈±1.25)。
func _build_decor(root: Node3D) -> void:
	var wood := Color(0.34, 0.26, 0.16)
	# 裝飾 21 點桌（東南，鏡射北邊那張真桌）
	_table_collider(root, Vector3(3.2, 0.45, 2.6), Vector3(1.9, 0.9, 1.2))
	_box(root, Vector3(3.2, 0.45, 2.6), Vector3(1.9, 0.9, 1.2), wood)
	_gold_box(root, Vector3(3.2, 0.905, 2.6), Vector3(1.94, 0.03, 1.24), 0.4)
	_box(root, Vector3(3.2, 0.93, 2.6), Vector3(1.8, 0.06, 1.1), Color(0.12, 0.30, 0.20))
	_tex_quad(root, PARLOR_ART + "card_back_game_ready.png",
		Vector3(3.0, 0.965, 2.75), Vector2(0.24, 0.24), Vector3(-90, 30, 0))
	_tex_quad(root, PARLOR_ART + "card_back_game_ready.png",
		Vector3(3.42, 0.965, 2.42), Vector2(0.24, 0.24), Vector3(-90, -8, 0))
	_chip_stack(root, Vector3(2.6, 0.96, 2.2))
	_chip_stack(root, Vector3(3.75, 0.96, 3.0))
	for sp in [Vector3(2.25, 0, 1.95), Vector3(2.35, 0, 3.3), Vector3(4.1, 0, 1.95)]:
		_stool(root, sp)
	# 裝飾輪盤桌（西南）
	_table_collider(root, Vector3(-2.9, 0.45, 4.6), Vector3(1.9, 0.9, 1.9))
	_cylinder(root, Vector3(-2.9, 0.42, 4.6), 0.95, 0.84, wood)
	_gold_cylinder(root, Vector3(-2.9, 0.90, 4.6), 0.92, 0.06, 0.4)
	_tex_quad(root, PARLOR_ART + "roulette_wheel_top_game_ready.png",
		Vector3(-2.9, 0.945, 4.6), Vector2(1.72, 1.72), Vector3(-90, 65, 0))
	_chip_stack(root, Vector3(-2.3, 0.96, 4.15))
	for sp2 in [Vector3(-1.75, 0, 5.3), Vector3(-2.2, 0, 3.5)]:
		_stool(root, sp2)
	# 裝飾桌上方吊燈籠＋暖光
	for lp in [Vector3(3.2, 3.8, 2.6), Vector3(-2.9, 3.8, 4.6)]:
		var chain_h: float = WALL_H - lp.y - 0.15
		_box(root, Vector3(lp.x, lp.y + 0.15 + chain_h * 0.5, lp.z), Vector3(0.035, chain_h, 0.035), Color(0.16, 0.13, 0.10))
		_red_lantern(root, lp, 1.0)
		_omni(root, lp, Color(0.98, 0.44, 0.24), 1.0, 5.5)
	# 吧台（東南角沿東牆）：檯身+金檯面+背牆雙層酒架+發光酒瓶+高腳凳
	_table_collider(root, Vector3(4.35, 0.525, 5.4), Vector3(0.62, 1.05, 2.0))
	_box(root, Vector3(4.35, 0.525, 5.4), Vector3(0.55, 1.05, 1.9), Color(0.16, 0.07, 0.08))
	_gold_box(root, Vector3(4.35, 1.06, 5.4), Vector3(0.62, 0.05, 2.0), 0.35)
	for shelf_y in [1.9, 2.5]:
		_gold_box(root, Vector3(4.72, shelf_y, 5.4), Vector3(0.16, 0.04, 1.7), 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var bottle_cols := [Color(0.20, 0.55, 0.30), Color(0.62, 0.30, 0.12), Color(0.30, 0.35, 0.62), Color(0.60, 0.16, 0.18)]
	for shelf_y2 in [1.92, 2.52]:
		var bz := 4.65
		while bz < 6.15:
			var col: Color = bottle_cols[rng.randi() % bottle_cols.size()]
			var bh := rng.randf_range(0.22, 0.34)
			var b := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.035
			cm.bottom_radius = 0.05
			cm.height = bh
			b.mesh = cm
			b.position = Vector3(4.72, shelf_y2 + bh * 0.5, bz)
			var bm := StandardMaterial3D.new()
			bm.albedo_color = col
			bm.roughness = 0.15
			bm.emission_enabled = true
			bm.emission = col
			bm.emission_energy_multiplier = 0.55   # 微透光酒液感
			b.material_override = bm
			root.add_child(b)
			bz += rng.randf_range(0.14, 0.22)
	_omni(root, Vector3(4.4, 2.9, 5.4), Color(1.0, 0.72, 0.42), 1.3, 5.0)   # 酒架氣氛光
	for bs in [Vector3(3.75, 0, 4.8), Vector3(3.75, 0, 5.9)]:
		_stool(root, bs)
	# 紅毯兩側絨繩圍欄柱（金柱+球頭+紅絨繩），從南口引到紋章前
	for side in [-1.0, 1.0]:
		var posts: Array = []
		for z in [2.9, 4.2, 5.5]:
			var px: float = side * 1.55
			_gold_cylinder(root, Vector3(px, 0.45, z), 0.045, 0.9, 0.3)
			_gold_cylinder(root, Vector3(px, 0.06, z), 0.14, 0.06, 0.25)
			var knob := _sphere(root, Vector3(px, 0.93, z), 0.06, Color(0.85, 0.68, 0.28))
			knob.material_override = _gold_material(0.3)
			posts.append(Vector3(px, 0.82, z))
		for i in range(posts.size() - 1):
			var a: Vector3 = posts[i]
			var b2: Vector3 = posts[i + 1]
			var rope := _box(root, (a + b2) * 0.5 - Vector3(0, 0.06, 0), Vector3(0.05, 0.05, a.distance_to(b2) - 0.12), Color(0.52, 0.08, 0.10))
			rope.rotation.x = 0.08   # 微垂墜感
	# 東西牆金框掛畫（北段賭桌區的牆面留白補起來）
	for art in [[Vector3(-HALF_W + 0.07, 2.5, -4.4), 90.0], [Vector3(HALF_W - 0.07, 2.5, -4.4), -90.0]]:
		var apos: Vector3 = art[0]
		_gold_box(root, apos, Vector3(0.06, 1.25, 0.95), 0.3)
		_box(root, apos + Vector3(signf(-apos.x) * 0.02, 0, 0), Vector3(0.04, 1.05, 0.75), Color(0.30, 0.07, 0.10))
		_emissive(root, apos + Vector3(signf(-apos.x) * 0.05, 0, 0), Vector3(0.015, 0.55, 0.38), Color(0.85, 0.55, 0.30), 0.5)
		_omni(root, apos + Vector3(signf(-apos.x) * 0.5, 0.9, 0), Color(1.0, 0.80, 0.55), 0.9, 3.5)

func _chip_stack(root: Node3D, pos: Vector3) -> void:
	var colors := [Color(0.80, 0.14, 0.14), Color(0.16, 0.34, 0.72), Color(0.88, 0.85, 0.78)]
	var y := pos.y
	for c in colors:
		_cylinder(root, Vector3(pos.x, y, pos.z), 0.085, 0.045, c)
		y += 0.05

func _sconce(root: Node3D, pos: Vector3) -> void:
	_gold_box(root, pos, Vector3(0.22, 0.30, 0.14), 0.35)
	_emissive(root, pos + Vector3(0, 0.20, 0.06), Vector3(0.14, 0.20, 0.14), Color(1.0, 0.86, 0.58), 1.8)
	_omni(root, pos + Vector3(0, 0.20, 0.10), Color(1.0, 0.80, 0.52), 1.5, 6.5)

# ── 金頂柱：沿東西牆內側各站 3 根裝飾柱，撐出「大廳」的縱深感 ─────
## 集中在入口到桌區之間（南半段），飛鏢靶所在的北牆角落(z<-4)
## 刻意不擺柱子——呼應真實賭場「大廳氣派、機檯區純功能」的分區直覺。
## 純視覺，無碰撞（同其餘桌具道具慣例，牆本身已擋人）。
func _build_pillars(root: Node3D) -> void:
	for x in [-4.3, 4.3]:
		for z in [-3.0, 0.5, 4.0]:
			_pillar(root, x, z)

func _pillar(root: Node3D, x: float, z: float) -> void:
	var h := WALL_H - 0.3
	_box(root, Vector3(x, h * 0.5 + 0.1, z), Vector3(0.32, h, 0.32), Color(0.08, 0.04, 0.06))
	_gold_cylinder(root, Vector3(x, 0.12, z), 0.26, 0.22, 0.30)   # 柱基
	_gold_cylinder(root, Vector3(x, h + 0.05, z), 0.26, 0.16, 0.5)  # 柱頭

# ── 紅毯：從南口鋪到房中段（讓位給中央地板金紋章），金邊收邊 ──
func _build_carpet(root: Node3D) -> void:
	var z0 := HALF_D - 0.6
	var z1 := 0.6
	var cz := (z0 + z1) * 0.5
	var clen := z0 - z1
	_gold_box(root, Vector3(0, 0.012, cz), Vector3(2.9, 0.02, clen), 0.15)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.5, 0.024, clen)
	mi.mesh = bm
	mi.position = Vector3(0, 0.02, cz)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.05, 0.08)
	m.roughness = 0.85
	mi.material_override = m
	root.add_child(mi)

# ── 地板金紋章：概念圖的中央金色圓紋大理石地標（雙金環＋圓心）──
func _build_medallion(root: Node3D) -> void:
	var c := Vector3(0, 0.015, -1.8)
	_flat_ring(root, c, 1.75, 0.05)
	_flat_ring(root, c, 1.15, 0.035)
	_gold_cylinder(root, c, 0.30, 0.015, 0.25)
	# 環間放射短刻線
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		var mid := c + Vector3(cos(ang) * 1.45, 0, sin(ang) * 1.45)
		var seg := _box(root, mid, Vector3(0.5, 0.012, 0.04), Color(0.55, 0.42, 0.18))
		seg.rotation.y = -ang

func _flat_ring(root: Node3D, center: Vector3, radius: float, thickness: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - thickness
	tm.outer_radius = radius
	mi.mesh = tm
	mi.position = center
	mi.material_override = _gold_material(0.3)
	root.add_child(mi)

# ── 紅燈籠吊燈環：概念圖的主視覺——金環吊架＋一圈紅燈籠 ──────
func _build_chandelier(root: Node3D) -> void:
	var pos := Vector3(0, WALL_H - 1.15, -1.8)
	# 吊鏈×3 從天花板垂到金環
	for i in range(3):
		var ang := TAU * float(i) / 3.0
		var chain_h := WALL_H - pos.y
		_box(root, Vector3(pos.x + cos(ang) * 1.05, pos.y + chain_h * 0.5, pos.z + sin(ang) * 1.05),
			Vector3(0.04, chain_h, 0.04), Color(0.16, 0.13, 0.10))
	# 金環吊架
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.02
	tm.outer_radius = 1.14
	ring.mesh = tm
	ring.position = pos
	ring.material_override = _gold_material(0.5)
	root.add_child(ring)
	# 一圈 8 顆紅燈籠掛環下
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var lp := pos + Vector3(cos(ang) * 1.05, -0.30, sin(ang) * 1.05)
		_red_lantern(root, lp, 0.85)
	# 環心金燈籠＋主暖光（能量壓 1.3：2.0 會在天花板炸出一大團白 bloom）
	_emissive(root, pos + Vector3(0, -0.25, 0), Vector3(0.24, 0.34, 0.24), Color(1.0, 0.85, 0.55), 1.3)
	_omni(root, pos + Vector3(0, -0.3, 0), Color(1.0, 0.80, 0.55), 2.0, 9.0)
	_omni(root, pos + Vector3(0, -0.5, 0), Color(1.0, 0.42, 0.28), 1.0, 7.0)   # 紅燈籠暈染

## 紅燈籠（小吊桿＋紅殼＋金頂蓋），scale 控大小。
func _red_lantern(root: Node3D, pos: Vector3, s: float = 1.0) -> void:
	_gold_box(root, pos + Vector3(0, 0.14 * s, 0), Vector3(0.06, 0.05, 0.06) * s, 0.3)
	_emissive(root, pos, Vector3(0.20, 0.26, 0.20) * s, Color(0.95, 0.28, 0.14), 1.6)

# ── 吊鏈紅燈籠：沿房間兩側從天花板垂掛（概念圖滿天燈籠感的簡化版）──
func _build_hanging_lanterns(root: Node3D) -> void:
	for lp in [Vector3(-2.2, 3.9, -4.6), Vector3(2.2, 4.1, -4.6),
			Vector3(-2.2, 4.05, 1.6), Vector3(2.2, 3.85, 1.6)]:
		var chain_h: float = WALL_H - lp.y - 0.15
		_box(root, Vector3(lp.x, lp.y + 0.15 + chain_h * 0.5, lp.z), Vector3(0.035, chain_h, 0.035), Color(0.16, 0.13, 0.10))
		_red_lantern(root, lp, 1.0)
		_omni(root, lp, Color(0.98, 0.40, 0.22), 0.9, 5.0)

# ── 天花板鐵桁架樑＋吊鏈（概念圖的工業屋頂骨架，提醒這裡仍在軍火庫地下）──
func _build_ceiling_beams(root: Node3D) -> void:
	for bz in [-5.0, -1.8, 1.6, 4.8]:
		_box(root, Vector3(0, WALL_H - 0.08, bz), Vector3(HALF_W * 2 + 0.6, 0.16, 0.24), Color(0.07, 0.05, 0.05))

# ── 拉霸機列（西牆南段，純裝飾）＋前排圓凳 ──────────────────
func _build_slots(root: Node3D) -> void:
	for i in range(3):
		var z := 1.2 + float(i) * 0.85
		var x := -HALF_W + 0.42
		_box(root, Vector3(x, 0.8, z), Vector3(0.55, 1.6, 0.55), Color(0.10, 0.08, 0.09))
		_gold_box(root, Vector3(x + 0.02, 1.62, z), Vector3(0.56, 0.05, 0.56), 0.3)
		_emissive(root, Vector3(x + 0.26, 1.15, z), Vector3(0.05, 0.34, 0.38), Color(0.98, 0.62, 0.22), 1.5)   # 發光面板
		_emissive(root, Vector3(x, 1.70, z), Vector3(0.10, 0.10, 0.10), Color(0.92, 0.18, 0.12), 1.6)          # 頂上紅燈
		_stool(root, Vector3(x + 0.85, 0, z))

## 紅絨圓凳（賭桌/拉霸機前）。
func _stool(root: Node3D, pos: Vector3) -> void:
	_cylinder(root, pos + Vector3(0, 0.25, 0), 0.14, 0.5, Color(0.10, 0.08, 0.09))
	_gold_cylinder(root, pos + Vector3(0, 0.50, 0), 0.185, 0.03, 0.25)
	_cylinder(root, pos + Vector3(0, 0.55, 0), 0.19, 0.08, Color(0.55, 0.10, 0.12))

# ── 匾額與霓虹（Label3D 中文字，概念圖的招牌群）─────────────
func _build_signs(root: Node3D) -> void:
	# 出口上方橫匾「地下遊藝場」（金字紅底，面向房內）
	_box(root, Vector3(0, 3.3, HALF_D - 0.10), Vector3(2.6, 0.62, 0.10), Color(0.32, 0.06, 0.08))
	_gold_box(root, Vector3(0, 3.63, HALF_D - 0.11), Vector3(2.66, 0.05, 0.11), 0.35)
	_gold_box(root, Vector3(0, 2.97, HALF_D - 0.11), Vector3(2.66, 0.05, 0.11), 0.35)
	_sign_text(root, "地下遊藝場", Vector3(0, 3.3, HALF_D - 0.16), 180.0, 88, Color(1.35, 1.05, 0.42))
	# 西牆直匾「遊藝」（金字黑匾）
	_box(root, Vector3(-HALF_W + 0.05, 2.7, 2.2), Vector3(0.08, 1.5, 0.62), Color(0.10, 0.08, 0.07))
	_sign_text(root, "遊\n藝", Vector3(-HALF_W + 0.11, 2.7, 2.2), 90.0, 96, Color(1.3, 1.0, 0.4))
	# 東牆菱形「賭」紅霓虹（過 glow 閾值會發光暈）
	var plaque := _box(root, Vector3(HALF_W - 0.05, 2.7, 0.8), Vector3(0.08, 1.0, 1.0), Color(0.07, 0.05, 0.06))
	plaque.rotation_degrees.x = 45.0
	_sign_text(root, "賭", Vector3(HALF_W - 0.12, 2.7, 0.8), -90.0, 150, Color(2.2, 0.42, 0.30))
	_omni(root, Vector3(HALF_W - 0.5, 2.7, 0.8), Color(1.0, 0.25, 0.16), 1.2, 4.5)
	# 南口西側酒水箱（概念圖左下角的酒瓶托盤）
	_box(root, Vector3(-4.2, 0.26, 5.7), Vector3(0.75, 0.52, 0.75), Color(0.30, 0.22, 0.13))
	for i in range(3):
		_cylinder(root, Vector3(-4.4 + float(i) * 0.2, 0.68, 5.6 + float(i % 2) * 0.2), 0.05, 0.32, Color(0.14, 0.26, 0.16))

func _sign_text(root: Node3D, text: String, pos: Vector3, yaw_deg: float, size: int, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD   # 同 _tex_quad 的雷：透明 pass 會被 ink_outline 蓋掉
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	root.add_child(l)

## 貼圖 quad（Codex game_ready 去背圖直接上牆/平放桌面）。圖缺就靜默跳過。
## ⚠透明度必須用 ALPHA_SCISSOR（走不透明 pass）——本場景相機掛著 ink_outline
## 全螢幕後處理，它會把「不透明 pass 的螢幕紋理」整張不透明蓋回去，任何
## transparent-pass 物件（TRANSPARENCY_ALPHA/預設 Label3D）都會被蓋掉消失。
func _tex_quad(root: Node3D, path: String, pos: Vector3, size: Vector2, rot_deg: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	root.add_child(mi)

# ── 荷官（程式化假人佔位，等 Codex 真人立繪再替換為 NpcFigure）───────
## 立在輪盤桌北側、面向玩家常見的進場方向，緩慢左右轉頭表示「還在盯場」。
func _build_dealer(root: Node3D) -> void:
	var body := Node3D.new()
	body.position = Vector3(-3.2, 0.0, -3.15)
	body.rotation_degrees.y = 180.0
	root.add_child(body)
	_box(body, Vector3(0, 1.0, 0), Vector3(0.5, 1.15, 0.30), Color(0.05, 0.05, 0.07))     # 黑西裝身軀
	_box(body, Vector3(-0.32, 0.95, 0.05), Vector3(0.16, 0.85, 0.16), Color(0.05, 0.05, 0.07))  # 左臂
	_box(body, Vector3(0.32, 0.95, 0.05), Vector3(0.16, 0.85, 0.16), Color(0.05, 0.05, 0.07))   # 右臂
	_box(body, Vector3(0, 1.55, 0.09), Vector3(0.22, 0.16, 0.14), Color(0.92, 0.90, 0.86))       # 白襯衫領口
	_gold_box(body, Vector3(0, 1.48, 0.17), Vector3(0.14, 0.06, 0.04), 0.12)                      # 金領結（能量調低,近距離會跟頭部bloom糊一起）
	_sphere(body, Vector3(0, 1.78, 0), 0.18, Color(0.58, 0.44, 0.35))                             # 頭（膚色調暗，強光下才不過曝）
	_box(body, Vector3(0, 1.90, -0.03), Vector3(0.20, 0.10, 0.20), Color(0.08, 0.07, 0.08))       # 梳整背頭
	# 不額外加聚光燈——房間吊燈+牆燭台的環境光已夠看清輪廓；貼身小燈近距離
	# 一律被 bloom 糊成光斑（試過 1.2/0.5 能量都一樣），不如乾脆不點。
	# 待機微動：緩慢左右轉頭巡視賭桌，不用等骨架動畫
	var tw := body.create_tween()
	tw.set_loops()
	tw.tween_property(body, "rotation:y", deg_to_rad(192.0), 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "rotation:y", deg_to_rad(168.0), 2.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "rotation:y", deg_to_rad(180.0), 1.4).set_trans(Tween.TRANS_SINE)

# ── 玩家材質修正：延幀等玩家進場（同 shrine/armory）────────
func _fix_player_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_fix_figure_materials(player)

## 玩家材質：保留 Meshy 貼圖＋修透明雷，消光防塑膠感。
func _fix_figure_materials(node: Node) -> void:
	for c in node.get_children():
		_fix_figure_materials(c)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var sc: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
		for i in sc:
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var b := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				b.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				b.albedo_color.a = 1.0
				b.roughness = 1.0
				b.metallic = 0.0
				b.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, b)

# ── 材質/幾何 helper（同 ArmoryDistrict 慣例）───────────────
func _flat_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLASTER_SHADER
	m.set_shader_parameter("albedo", color)
	return m

## 打磨大理石地：低粗糙 StandardMaterial，吊燈/燭光會在地上拉出反光。
func _ground_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.07, 0.07)
	m.roughness = 0.25
	m.metallic = 0.0
	return m

func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _flat_mat(color)
	root.add_child(mi)
	return mi

func _cylinder(root: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _flat_mat(color)
	root.add_child(mi)

func _sphere(root: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _flat_mat(color)
	root.add_child(mi)
	return mi

## 金色包邊材質（StandardMaterial3D metallic，非 toon——賭場鎏金要有真反光，
## 跟其餘 cel 幾何刻意不同調，同 `_emissive` 走 PBR 發光路線的既有慣例）。
func _gold_material(energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.68, 0.28)
	m.metallic = 0.75
	m.roughness = 0.28
	m.emission_enabled = true
	m.emission = Color(0.90, 0.72, 0.30)
	m.emission_energy_multiplier = energy
	return m

func _gold_box(root: Node3D, pos: Vector3, size: Vector3, energy: float = 0.35) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _gold_material(energy)
	root.add_child(mi)

func _gold_cylinder(root: Node3D, pos: Vector3, radius: float, height: float, energy: float = 0.35) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _gold_material(energy)
	root.add_child(mi)

func _emissive(root: Node3D, pos: Vector3, size: Vector3, col: Color, energy: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	mi.material_override = m
	root.add_child(mi)

func _omni(root: Node3D, pos: Vector3, col: Color, energy: float, rng_: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_
	root.add_child(l)

func _wall(root: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = center
	root.add_child(body)

func _cam_blocker(root: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = center
	root.add_child(body)

## SceneRouter 戰前存位慣例（本房無戰鬥，仍提供以防未來擴充）。
func get_player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player else Vector3.ZERO
