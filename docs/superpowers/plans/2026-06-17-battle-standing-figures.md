# 戰鬥站立立繪 + 程式呼吸 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans。Steps 用 `- [ ]`。
> **本專案非 git repo** → 無 commit step；檢查點＝跑 headless 測試/看截圖。Godot＝`D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe`，專案 `D:\monk\MONK`。

**Goal:** 戰鬥畫面改成站立對峙——敵我去背戰姿立繪站在背景上、程式呼吸微動、點立繪選敵；立繪重生（品質優先），先定無戒基底再批量。

**Architecture:** 新 `BreathingFigure`(TextureRect 子類，sine 呼吸)；`EnemyPanel` 重構成「站立敵方單位」(figure+浮動名牌/HP+點擊選敵)；`battle_art` 加 cut 透明圖解析；`BattleScreen.tscn` 改 EnemyField 站列 + 前景 PlayerFigure。立繪 magnific Nano Banana 重生→remove_background→`…/cut/`。

**Tech Stack:** Godot 4.5 GDScript、magnific（images_generate / images_remove_background）。

---

## ⚠ 方向更新 + 進度（2026-06-17）

- **無戒改背面視角、取消 calm/angry，改正常/受傷兩態**：每職 2 張背面圖 `wujie_<job>.png`（戰姿）＋`wujie_<job>_hurt.png`（HP<30% 換的踉蹌護腹受傷姿）。→ Task 3/7 的 `player_figure_path(job, mood)`／`_set_player_portrait(mood)` 的 `mood` 改成 **state ∈ {normal, hurt}**：normal→`wujie_<job>.png`、hurt→`wujie_<job>_hurt.png`；HP<30% 傳 `hurt`。測試 `_test_figure_paths` 用 `player_figure_path(job, "normal")`。
- **生圖工具**：實際走 higgsfield `nano_banana_pro`（吃鎖定基底參考）生圖 + magnific `images_remove_background` 去背（非 plan 原寫的全 magnific）。
- **✅ Task 1 完成**：無戒 ascetic 背面基底鎖定＝v3 微側版。
- **✅ Task 2 完成**：9 張全部生成→去背→存 `cut/`→`--import`。檔案：`wujie/cut/wujie_{ascetic,chanter,beggar}.png` ＋ `wujie_{ascetic,chanter,beggar}_hurt.png`、`enemies/cut/enemy_guard.png`、`boss/cut/ares_{base,phase2}.png`（皆 RGBA 1696×2528，已驗邊緣）。生圖：base+6張 higgsfield、3張 hurt 改 magnific `imagen-nano-banana-2`（higgsfield 額度耗盡，0.58 cr）。
- **✅ Task 3–8 完成（2026-06-17）**：`battle_art`(resolve_figure_path/player_figure_path state)、`BreathingFigure`、`EnemyPanel` 站立單位、`BattleScreen.tscn` 站列+前景 PlayerFigure、`BattleUI`/`BattleManager` 接線、`CaptureBattle` 修 phase2 走 cut。
  - 測試：TestBattleArt / TestMainQuest / TestMenuSystem / TestCh1Expansion **皆 ALL PASS**；`--editor --quit` parse clean。
  - GPU 截圖：站立對峙成形（無戒背面前景、敵人浮動名牌、Boss base→phase2 cut 換圖）。
  - 雷：(1) 新 `class_name` 要先 `--editor --quit` 掃描註冊才認得（否則 BreathingFigure 解析失敗）；(2) GDScript lambda 按值捕捉值型別 local → 測試 signal 用陣列 `[false]` 捕捉；(3) CaptureBattle phase2 須自行 `resolve_figure_path` 包裝（資料是原 jpg bust）。
  - **待調**：敵人站位偏高/偏小（人類敵人浮空感；Ares 浮空 OK）；呼吸節奏 GPU 微調。

## File Structure
- Create `src/screens/BattleScreen/breathing_figure.gd` — `BreathingFigure`，呼吸微動。
- Modify `src/screens/BattleScreen/battle_art.gd` — 加 `resolve_figure_path`/`player_figure_path`。
- Modify `src/screens/BattleScreen/EnemyPanel.gd` — 重構成站立單位。
- Modify `src/screens/BattleScreen/BattleScreen.tscn` — EnemyField 站列 + PlayerFigure 前景 + PlayerPanel 還原成狀態列。
- Modify `src/screens/BattleScreen/BattleUI.gd` — PlayerFigure 換圖/呼吸、移除 v1 小頭像邏輯。
- Create 透明立繪 `assets/2d/portraits/{enemies,boss,wujie}/cut/*.png`（magnific 重生）。
- Modify `test/TestBattleArt.gd` — 擴充 cut/呼吸/站立單位。
- Modify `test/CaptureBattle.gd` — 重截站立圖（沿用）。

---

## Task 1：無戒戰姿「定基底」（★使用者畫風檢查點）

**Files:** Create `assets/2d/portraits/wujie/cut/wujie_ascetic_calm.png`

- [ ] magnific `images_generate` `imagen-nano-banana-2`，aspectRatio 2:3，resolution 2k，count 2，prompt：「光頭武僧無戒，破舊僧袍，**馬步沉肩、單拳前引的少林羅漢拳戰鬥架式**，全身入鏡腳踩地、面向前方略 3/4，半寫實厚塗 noir、暗金×黑、冷光輪廓光，**站在純中灰純色背景上**（方便去背），無文字浮水印。」
- [ ] `creations_wait`→下載 2 版到 `_art_review/`，挑姿勢/畫風好的。
- [ ] `images_remove_background` 那張→下載透明 PNG→存 `wujie/cut/wujie_ascetic_calm.png`。
- [ ] `--headless --import`。
- [ ] **停**：把圖開給使用者看，確認畫風/比例/戰姿。**通過才做 Task 2。** 不過則改 prompt 重生本步。

---

## Task 2：批量重生 phase-1 立繪（畫風鎖定後）

**Files:** Create `…/wujie/cut/wujie_{ascetic,chanter,beggar}.png`（背面，無 mood）、`…/enemies/cut/enemy_guard.png`、`…/boss/cut/ares_{base,phase2}.png` — ✅ 全部完成

- [ ] 沿用 T1 鎖定的畫風參數，逐一 `images_generate`（2:3/2k/純中灰底）：
  - 無戒：ascetic_angry（怒目同架式）、chanter（念珠/誦經僧袍同武僧架式）calm+angry、beggar（破衣托缽僧同架式）calm+angry。
  - `pantheon_guard`：萬神殿重裝保全，電擊棍戒備架式，黑灰戰術裝。
  - 阿瑞斯 base：現代戰神西裝戰甲、紅能量、傲慢戰鬥站姿；phase2：狂怒爆發版（紅光更盛）。
- [ ] 各 `images_remove_background`→下載透明 PNG→存對應 `cut/`。
- [ ] `--headless --import`。
- [ ] 檢查點：`Test-Path` 全部 cut PNG + `.import` 存在。

---

## Task 3：battle_art 加 cut 立繪解析

**Files:** Modify `src/screens/BattleScreen/battle_art.gd`、`test/TestBattleArt.gd`

- [ ] **Step 1** `battle_art.gd` 加常數與函式：

```gdscript
## 站立戰姿透明圖優先用 cut/，缺則退回原框圖（安全）。
static func resolve_figure_path(group_dir: String, filename: String) -> String:
	if filename == "":
		return ""
	var cut := group_dir + "cut/" + filename.get_basename() + ".png"
	if ResourceLoader.exists(cut):
		return cut
	var orig := group_dir + filename
	if ResourceLoader.exists(orig):
		return orig
	return resolve_portrait_path(filename)  # 最後退回 enemies/ 或 boss/ 探測

## 玩家站立圖：wujie/cut/wujie_<job>_<mood>.png，缺則退回 _nobg / 原 jpg。
static func player_figure_path(job: String, mood: String = "calm") -> String:
	var j: String = job if job in ["ascetic", "chanter", "beggar"] else "ascetic"
	var cut := "%scut/wujie_%s_%s.png" % [WUJIE_DIR, j, mood]
	if ResourceLoader.exists(cut):
		return cut
	return player_portrait_path(j, mood)  # 退回原 jpg
```

- [ ] **Step 2** `TestBattleArt.gd` `_test_player_portrait` 後加 `_test_figure_paths`：

```gdscript
func _test_figure_paths() -> void:
	# 本輪已生的 cut 圖：無戒 3 職、guard、ares base/phase2
	for job in ["ascetic", "chanter", "beggar"]:
		var p := BattleArt.player_figure_path(job, "calm")
		_check(p.find("/cut/") != -1 and load(p) is Texture2D, "無戒 %s cut 站立圖載入 (got %s)" % [job, p])
	var g := BattleArt.resolve_figure_path(BattleArt.ENEMY_DIR, "enemy_guard.png")
	_check(g.find("/cut/") != -1 and load(g) is Texture2D, "guard cut 站立圖載入 (got %s)" % g)
	var a := BattleArt.resolve_figure_path(BattleArt.BOSS_DIR, "ares_base.jpg")
	_check(a.find("/cut/") != -1 and load(a) is Texture2D, "ares base cut 站立圖載入 (got %s)" % a)
	# 缺 cut 退回：不存在的檔退回探測
	_check(BattleArt.resolve_figure_path(BattleArt.ENEMY_DIR, "enemy_punk.png") != "", "未生 cut 的 punk 退回原圖")
```
並在 `_ready` 的呼叫串加 `_test_figure_paths()`。

- [ ] **Step 3** 跑 `TestBattleArt.tscn` → `ALL PASS`。

---

## Task 4：BreathingFigure 呼吸元件

**Files:** Create `src/screens/BattleScreen/breathing_figure.gd`、`test/TestBattleArt.gd`

- [ ] **Step 1** 寫 `breathing_figure.gd`：

```gdscript
class_name BreathingFigure
extends TextureRect

## 站立立繪呼吸微動：腳踩地，sine 上下浮+胸口縮放+輕搖。各圖隨機相位不同步。

@export var amp_y: float = 5.0       # 垂直浮動 px
@export var period: float = 3.4      # 一個呼吸秒數
@export var sway: float = 0.009      # 輕搖弧度（≈0.5°）
@export var breathing: bool = true

var _base_y: float = 0.0
var _phase: float = 0.0
var _t: float = 0.0
var _ready_done: bool = false

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_base_y = position.y
	_phase = randf() * TAU
	_set_pivot_bottom_center()
	_ready_done = true

func _set_pivot_bottom_center() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)

func _process(delta: float) -> void:
	if not breathing:
		return
	_t += delta
	var w: float = TAU / max(period, 0.1)
	var s: float = sin(_t * w + _phase)
	position.y = _base_y - s * amp_y
	scale = Vector2(1.0 - s * 0.008, 1.0 + s * 0.015)
	rotation = sin(_t * w * 0.5 + _phase) * sway

## 換圖後重設基準（避免 shake/換圖殘留位移）。
func reset_base() -> void:
	_base_y = position.y
	_set_pivot_bottom_center()
```

- [ ] **Step 2** `TestBattleArt.gd` 加 `_test_breathing`：

```gdscript
func _test_breathing() -> void:
	var f := BreathingFigure.new()
	f.size = Vector2(200, 300)
	f.position = Vector2(0, 100)
	add_child(f)
	await get_tree().process_frame
	_check(f.pivot_offset.is_equal_approx(Vector2(100, 300)), "pivot 設底部中央")
	f._process(0.85)  # 約 1/4 週期，sin≠0
	_check(abs(f.position.y - 100.0) > 0.0 or f.scale != Vector2.ONE, "呼吸有位移/縮放")
	_check(f._base_y == 100.0, "_base_y 不漂移")
	f.queue_free()
```
並在 `_ready` 串加 `await _test_breathing()`（注意 `_ready` 改成依序 await）。

- [ ] **Step 3** 跑 `TestBattleArt.tscn` → `ALL PASS`。

---

## Task 5：EnemyPanel 重構成站立單位

**Files:** Modify `src/screens/BattleScreen/EnemyPanel.gd`（整檔重寫 `_init` 結構）

- [ ] **Step 1** 重寫 `EnemyPanel.gd`（根改 `Control`，組 figure＋浮動名牌；點 figure 選敵）：

```gdscript
class_name EnemyPanel
extends Control

## 站立敵方單位：去背戰姿立繪(BreathingFigure) + 下方浮動名牌/HP + 點擊選目標。

signal target_pressed(panel: EnemyPanel)

var combatant: Combatant
var index: int = 0
var _figure: BreathingFigure
var _hit_button: Button
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _status_label: Label
var _down_label: Label
var _base_portrait: String = ""
var _mood_timer: SceneTreeTimer = null

func _init(c: Combatant, idx: int) -> void:
	combatant = c
	index = idx
	custom_minimum_size = Vector2(240, 420)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_figure = BreathingFigure.new()
	_figure.custom_minimum_size = Vector2(220, 320)
	_figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_base_portrait = BattleArt.resolve_figure_path(_group_dir(c), _portrait_file(c))
	if _base_portrait != "" and ResourceLoader.exists(_base_portrait):
		_figure.texture = load(_base_portrait)
	else:
		_figure.visible = false
	vbox.add_child(_figure)

	# 點擊立繪選目標（覆蓋在 figure 上）
	_hit_button = Button.new()
	_hit_button.flat = true
	_hit_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit_button.modulate = Color(1, 1, 1, 0)
	_hit_button.visible = false
	_hit_button.pressed.connect(func(): target_pressed.emit(self))
	add_child(_hit_button)

	# 浮動名牌（暗金霓虹）
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", BattleArt.neon_frame())
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	plate.add_child(pv)

	_name_label = Label.new()
	_name_label.text = c.display_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	pv.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = c.max_hp
	_hp_bar.value = c.current_hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(180, 12)
	pv.add_child(_hp_bar)

	_hp_text = Label.new()
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 16)
	pv.add_child(_hp_text)

	_down_label = Label.new()
	_down_label.text = "DOWN!"
	_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down_label.add_theme_font_size_override("font_size", 22)
	_down_label.add_theme_color_override("font_color", Color("#FFD700"))
	_down_label.visible = false
	pv.add_child(_down_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("#FF6B00"))
	pv.add_child(_status_label)

	vbox.add_child(plate)

	c.hp_changed.connect(_on_hp_changed)
	c.down_changed.connect(_on_down_changed)
	_on_hp_changed(c.current_hp, c.max_hp)

func _group_dir(c: Combatant) -> String:
	return BattleArt.BOSS_DIR if c.is_boss else BattleArt.ENEMY_DIR

func _portrait_file(c: Combatant) -> String:
	# combatant.portrait_path 是 from_enemy 解析過的原圖路徑，取檔名給 cut 解析
	return c.portrait_path.get_file() if c.portrait_path != "" else ""

func _on_hp_changed(current: int, max_hp: int) -> void:
	_hp_bar.value = current
	_hp_text.text = "%d / %d" % [current, max_hp]
	if current <= 0:
		modulate = Color(0.4, 0.4, 0.4, 0.45)
		_figure.breathing = false
		_down_label.visible = false
		_hit_button.visible = false

func _on_down_changed(is_down: bool) -> void:
	_down_label.visible = is_down and combatant.is_alive()

func set_statuses(statuses: Array) -> void:
	_status_label.text = "、".join(statuses)

func set_target_mode(enabled: bool) -> void:
	_hit_button.visible = enabled and combatant.is_alive()

## 持久換站姿（Boss 進階段）。
func set_base_portrait(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path) or _figure == null:
		return
	_base_portrait = path
	if _figure.visible:
		_figure.texture = load(path)

## 暫態表情：切 path，secs 後回 _base（新 flash 取消舊的）。
func flash_mood(path: String, secs: float) -> void:
	if path == "" or not ResourceLoader.exists(path) or _figure == null or not _figure.visible:
		return
	_figure.texture = load(path)
	_mood_timer = get_tree().create_timer(secs)
	var my := _mood_timer
	await my.timeout
	if my == _mood_timer and is_instance_valid(_figure):
		_figure.texture = load(_base_portrait)
```

註：Boss 的 `portrait_moods` 值是 `resolve_portrait_path` 解析的原圖路徑；`set_enemy_base`/`flash_mood` 收到後若要 cut 版，由 `BattleManager` 改傳 cut 路徑（見 Task 7 Step）。

- [ ] **Step 2** `TestBattleArt.gd` `_test_panels_smoke` 改測站立單位：

```gdscript
func _test_panels_smoke() -> void:
	var d := _enemies()
	var c := Combatant.from_enemy("pantheon_guard", d["pantheon_guard"])
	var panel := EnemyPanel.new(c, 0)
	add_child(panel)
	await get_tree().process_frame
	_check(panel._figure != null and panel._figure.texture != null, "站立單位有 figure 立繪")
	var got := false
	panel.target_pressed.connect(func(_p): got = true)
	panel.set_target_mode(true)
	panel._hit_button.pressed.emit()
	_check(got, "點立繪發 target_pressed")
	panel.queue_free()
```

- [ ] **Step 3** 跑 `TestBattleArt.tscn` → `ALL PASS`。

---

## Task 6：BattleScreen.tscn 站立版面

**Files:** Modify `src/screens/BattleScreen/BattleScreen.tscn`

- [ ] **Step 1** `EnemyArea` 改成上方站列容器（沿用節點名 `EnemyArea`＝unique，BattleUI 不必改參照），調 anchor 到上半、底部對齊：把 `EnemyArea` 的 `offset_top/offset_bottom` 改成上半區（如 top=80, bottom=560），`alignment=1`，`separation=80`。
- [ ] **Step 2** 還原 v1 的 PlayerPanel 小頭像：把 `PlayerPanel/Margin/HBox/PlayerPortrait` 移除，HBox 改回單純 VBox（或保留 HBox 只留 VBox 子）；PlayerPanel 仍是底部狀態列。
- [ ] **Step 3** 新增前景大立繪 `PlayerFigure`（在 BattleUI 下、EnemyArea 之後、PlayerPanel 之前）：

```
[node name="PlayerFigure" type="TextureRect" parent="BattleUI"]
unique_name_in_owner = true
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 60.0
offset_top = -560.0
offset_right = 460.0
offset_bottom = -40.0
expand_mode = 1
stretch_mode = 5
script = ExtResource("<breathing_figure>")
```
（需在 .tscn 頂端 `[ext_resource type="Script" path="res://src/screens/BattleScreen/breathing_figure.gd" id="X"]` 並把上面 `script = ExtResource("X")`。）

- [ ] **Step 4** `--headless --path … --editor --quit` → 無 parse/scene error。

---

## Task 7：BattleUI / BattleManager 站立接線

**Files:** Modify `src/screens/BattleScreen/BattleUI.gd`、`BattleManager.gd`

- [ ] **Step 1** `BattleUI.gd`：把 v1 `@onready var player_portrait` 改指 `%PlayerFigure`（型別 BreathingFigure）；`_set_player_portrait` 改用 `BattleArt.player_figure_path`：

```gdscript
@onready var player_figure: BreathingFigure = %PlayerFigure

func _set_player_portrait(mood: String) -> void:
	var p: String = BattleArt.player_figure_path(_player_job, mood)
	if ResourceLoader.exists(p):
		player_figure.texture = load(p)
		player_figure.visible = true
		player_figure.reset_base()
	else:
		player_figure.visible = false
```
移除舊 `player_portrait` 參照（PlayerPortrait 節點已刪）。`build` 內 `_set_player_portrait("calm")` 不變。

- [ ] **Step 2** `BattleManager.gd`：Boss 表情改傳 cut 路徑（用 `resolve_figure_path` 包一層），確保切到的是去背站姿：

```gdscript
func _boss_fig(filename_path: String) -> String:
	return BattleArt.resolve_figure_path(BattleArt.BOSS_DIR, filename_path.get_file())
```
並把三處 `ui.flash_enemy_mood(_boss, X, t)` / `ui.set_enemy_base(_boss, X)` 的 `X`（原為 `_boss.portrait_moods.get(...)`）包成 `_boss_fig(_boss.portrait_moods.get(...))`。

- [ ] **Step 3** 跑 `TestBattleArt.tscn` + `--editor --quit` → PASS / 無 error。

---

## Task 8：整合驗證 + 截圖

- [ ] `--headless --import`（確保 cut PNG 匯入）。
- [ ] `TestBattleArt.tscn` → `BATTLE_ART_TEST: ALL PASS`。
- [ ] 回歸：TestMainQuest/TestMenuSystem/TestCh1Expansion ALL PASS；`--editor --quit` parse clean。
- [ ] `CaptureBattle.gd`（修掉 T 之前的 first-capture race：第一個 `_capture` 前 `await get_tree().process_frame`，svc 用 `add_child.call_deferred` 後再 await）→ 跑視窗版重截 ares/guard 站立圖 → Read 開給使用者看呼吸/站位。
- [ ] 更新 `PROJECT_STATUS.md`＋記憶 `project-build-status`。
- [ ] 回報 GPU 待抽驗。

---

## Self-Review
- **Spec coverage**：重生戰姿→T1/T2；先定基底→T1 檢查點；程式呼吸→T4；版面站立→T6；站立單位/點擊選敵→T5；cut 解析→T3；Boss 換站姿→T7；玩家站立換臉→T7；測試→T3/4/5/8。覆蓋。
- **型別一致**：`resolve_figure_path`/`player_figure_path`(BattleArt)、`BreathingFigure.reset_base`/`breathing`、`EnemyPanel.set_base_portrait`/`flash_mood`/`set_target_mode`/`_figure`/`_hit_button`、`%PlayerFigure`(BattleUI.player_figure)、`_boss_fig`(BattleManager)——一致。
- **placeholder**：無；phase-2 額外立繪明列不擋驗收。
- **雷**：先定基底未過勿批量；shake 不污染 `_base_y`（reset_base）；cut 缺退回原圖；新 png 要 import；headless 不驗觀感。
