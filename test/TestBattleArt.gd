extends Node
## headless 驗證：戰鬥畫面美術串接（背景/立繪路徑解析 + 載入 + 面板建構）。
## 跑法：Godot --headless res://test/TestBattleArt.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_bg_resolution()
	_test_portrait_resolution()
	_test_player_portrait()
	_test_figure_paths()
	_test_neon_frame()
	await _test_breathing()
	await _test_panels_smoke()
	print("BATTLE_ART_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _enemies() -> Dictionary:
	var d: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	d.merge(JsonLoader.load_json("res://data/boss.json"))
	return d

func _test_bg_resolution() -> void:
	var d := _enemies()
	var cases := {
		"street_punk": "bg_battle_ximen.png", "night_ghost": "bg_battle_wanhua.png",
		"drunk_guard": "bg_battle_linsen.png", "pantheon_guard": "bg_battle_pantheon.png",
		"ares": "bg_battle_ares_forge.png",
	}
	for id in cases:
		var p: String = BattleArt.resolve_battle_bg(d.get(id, {}))
		_check(p.ends_with(cases[id]), "%s 背景→%s (got %s)" % [id, cases[id], p])
		_check(ResourceLoader.exists(p) and load(p) is Texture2D, "背景可載入：%s" % p)

func _test_portrait_resolution() -> void:
	var d := _enemies()
	for id in ["street_punk", "corrupt_vendor", "night_ghost", "drunk_guard", "temple_ghost", "pantheon_guard", "ares"]:
		var f: String = String(d.get(id, {}).get("portrait", ""))
		var p: String = BattleArt.resolve_portrait_path(f)
		_check(p != "" and load(p) is Texture2D, "%s 立繪可載入 (got %s)" % [id, p])
	var moods: Dictionary = d.get("ares", {}).get("portrait_moods", {})
	_check(moods.size() >= 3, "ares portrait_moods >=3 (got %d)" % moods.size())
	for k in moods:
		var p: String = BattleArt.resolve_portrait_path(String(moods[k]))
		_check(p != "" and load(p) is Texture2D, "ares mood %s 可載入" % k)

func _test_player_portrait() -> void:
	for job in ["ascetic", "chanter", "beggar"]:
		for mood in ["calm", "angry"]:
			var p: String = BattleArt.player_portrait_path(job, mood)
			_check(ResourceLoader.exists(p) and load(p) is Texture2D, "玩家立繪 %s/%s 可載入" % [job, mood])
	# 未知職業 fallback ascetic
	_check(BattleArt.player_portrait_path("nonsense", "calm").ends_with("wujie_ascetic_calm.jpg"), "未知職業 fallback ascetic")

## 站立 cut 立繪解析：無戒 3 職正常/受傷、guard、ares base/phase2；缺 cut 退回原圖。
func _test_figure_paths() -> void:
	for job in ["ascetic", "chanter", "beggar"]:
		var p := BattleArt.player_figure_path(job, "normal")
		_check(p.find("/cut/") != -1 and load(p) is Texture2D, "無戒 %s 正常 cut 站立圖載入 (got %s)" % [job, p])
		var h := BattleArt.player_figure_path(job, "hurt")
		_check(h.find("/cut/") != -1 and h.find("_hurt") != -1 and load(h) is Texture2D, "無戒 %s 受傷 cut 站立圖載入 (got %s)" % [job, h])
	var g := BattleArt.resolve_figure_path(BattleArt.ENEMY_DIR, "enemy_guard.png")
	_check(g.find("/cut/") != -1 and load(g) is Texture2D, "guard cut 站立圖載入 (got %s)" % g)
	var a := BattleArt.resolve_figure_path(BattleArt.BOSS_DIR, "ares_base.jpg")
	_check(a.find("/cut/") != -1 and load(a) is Texture2D, "ares base cut 站立圖載入 (got %s)" % a)
	var a2 := BattleArt.resolve_figure_path(BattleArt.BOSS_DIR, "ares_phase2.jpg")
	_check(a2.find("/cut/") != -1 and load(a2) is Texture2D, "ares phase2 cut 站立圖載入 (got %s)" % a2)
	# 缺 cut 退回原圖：punk 無 cut → 退回 enemies/enemy_punk.png
	var punk := BattleArt.resolve_figure_path(BattleArt.ENEMY_DIR, "enemy_punk.png")
	_check(punk.ends_with("enemies/enemy_punk.png"), "未生 cut 的 punk 退回原圖 (got %s)" % punk)

## BreathingFigure：pivot 底部中央、_process 一幀後有位移/縮放、_base_y 不漂移。
func _test_breathing() -> void:
	var f := BreathingFigure.new()
	f.size = Vector2(200, 300)
	f.position = Vector2(0, 100)
	add_child(f)
	await get_tree().process_frame
	_check(f.pivot_offset.is_equal_approx(Vector2(100, 300)), "BreathingFigure pivot 設底部中央 (got %s)" % f.pivot_offset)
	f._process(0.85)
	_check(abs(f.position.y - 100.0) > 0.0 or f.scale != Vector2.ONE, "呼吸有位移/縮放")
	_check(f._base_y == 100.0, "_base_y 不漂移 (got %s)" % f._base_y)
	f.queue_free()

func _test_neon_frame() -> void:
	var sb: StyleBoxFlat = BattleArt.neon_frame()
	_check(sb is StyleBoxFlat and sb.border_width_left == 2, "neon_frame 回 StyleBoxFlat 金邊2")

func _test_panels_smoke() -> void:
	var d := _enemies()
	var c := Combatant.from_enemy("pantheon_guard", d["pantheon_guard"])
	_check(c.portrait_path.ends_with("enemy_guard.png"), "Combatant.portrait_path 解析 (got %s)" % c.portrait_path)
	var panel := EnemyPanel.new(c, 0)
	add_child(panel)
	await get_tree().process_frame
	_check(panel._figure is BreathingFigure and panel._figure.texture != null, "站立單位有 figure 立繪")
	_check(panel._base_portrait.find("/cut/") != -1, "guard 站立用 cut 透明圖 (got %s)" % panel._base_portrait)
	var got := [false]  # 陣列＝參考型別，避開 GDScript lambda 對值型別 local 的「按值捕捉」
	panel.target_pressed.connect(func(_p): got[0] = true)
	panel.set_target_mode(true)
	panel._hit_button.pressed.emit()
	_check(got[0], "點立繪發 target_pressed")
	var ares := Combatant.from_enemy("ares", d["ares"])
	_check(ares.portrait_moods.size() >= 3, "ares Combatant.portrait_moods 解析 (got %d)" % ares.portrait_moods.size())
	var bp := EnemyPanel.new(ares, 0)
	add_child(bp)
	await get_tree().process_frame
	_check(bp._base_portrait.ends_with("ares_base.png"), "Boss 站立用 cut base (got %s)" % bp._base_portrait)
	# phase2 經 _boss_fig 包裝（get_file→resolve_figure_path）解析成 cut png
	var ph2 := BattleArt.resolve_figure_path(BattleArt.BOSS_DIR, String(ares.portrait_moods.get("phase2", "")).get_file())
	bp.set_base_portrait(ph2)
	_check(bp._base_portrait.ends_with("ares_phase2.png"), "Boss set_base_portrait 切 phase2 cut (got %s)" % bp._base_portrait)
	panel.queue_free()
	bp.queue_free()
	await _test_scene_smoke()

## 載入重構過的 BattleScreen.tscn，確認新 unique-name 節點解析正確（驗 .tscn 手改）。
func _test_scene_smoke() -> void:
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	_check(scene != null, "BattleScreen.tscn 可載入")
	if scene == null:
		return
	var inst: Node = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	var bui: Node = inst.get_node("BattleUI")
	_check(bui.battle_bg is TextureRect, "%BattleBg 解析為 TextureRect")
	_check(bui.player_figure is BreathingFigure, "%PlayerFigure 解析為 BreathingFigure")
	inst.queue_free()
