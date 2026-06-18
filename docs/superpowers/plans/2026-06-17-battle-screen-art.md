# 戰鬥畫面美術串接 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.
> **本專案非 git repo** → 無 `git commit` 步驟；每個 task 的檢查點＝跑 headless 測試看預期輸出。Godot＝`D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe`，專案 `D:\monk\MONK`。

**Goal:** 把已生成但戰鬥畫面從未顯示的美術（背景／敵人＋Boss 立繪／玩家立繪）全部接上，含阿瑞斯 4 立繪動態切換與一張新生 pantheon 背景。

**Architecture:** 純路徑解析集中到 `battle_art.gd`（可 headless 測）；`Combatant` 帶 `portrait_path`/`portrait_moods`；`EnemyPanel`/`PlayerPanel` 加立繪 TextureRect＋暗金霓虹 StyleBox；`BattleManager` 決定背景與 Boss 表情時機，UI 基元（換圖/暫態 flash）在 panel。

**Tech Stack:** Godot 4.5 GDScript，headless 測試場景，magnific Nano Banana 生圖。

---

## File Structure
- Create `src/screens/BattleScreen/battle_art.gd` — 純函式：背景/立繪路徑解析、暗金霓虹 StyleBox 工廠。
- Modify `src/screens/BattleScreen/Combatant.gd` — `from_enemy` 加 `portrait_path`、`portrait_moods`。
- Modify `src/screens/BattleScreen/EnemyPanel.gd` — 立繪 TextureRect＋neon 框＋`set_base_portrait`/`flash_mood`。
- Modify `src/screens/BattleScreen/BattleUI.gd` — 玩家立繪＋低HP換臉＋`flash_enemy_mood`/`set_enemy_base`。
- Modify `src/screens/BattleScreen/BattleManager.gd` — `setup` 設背景；Boss 表情時機（act/hurt/phase2）。
- Modify `src/screens/BattleScreen/BattleScreen.tscn` — 加 `BattleBg` TextureRect；`PlayerPanel` 改 HBox 含 `PlayerPortrait`。
- Modify `data/boss.json` — ares 加 `portrait_moods`。
- Create `assets/2d/backgrounds/bg_battle_pantheon.png` — magnific 生。
- Create `test/TestBattleArt.gd` + `.tscn` — headless 驗證。

---

## Task 0：生 pantheon 戰鬥背景

**Files:** Create `assets/2d/backgrounds/bg_battle_pantheon.png`

- [ ] magnific `images_generate` mode `imagen-nano-banana-2`，aspectRatio 16:9，resolution 2k，count 2，prompt：「萬神殿保全集團總部內部·軍火庫：冷光金屬貨架與武器箱、企業冷藍光＋暗金、混凝土地面、雨夜玻璃帷幕遠景、半寫實厚塗 noir 厚塗、戲劇打光、無人、無文字浮水印、構圖中央留空給戰鬥單位。16:9」。
- [ ] `creations_wait` → 下載 2 版到 `_art_review/`，挑乾淨無字那版。
- [ ] PIL/System.Drawing 轉/存成 `D:\monk\MONK\assets\2d\backgrounds\bg_battle_pantheon.png`（PNG 直接存即可）。
- [ ] 跑 `& $godot --headless --path D:\monk\MONK --import`，確認生成 `bg_battle_pantheon.png.import`。
- 檢查點：`Test-Path D:\monk\MONK\assets\2d\backgrounds\bg_battle_pantheon.png.import` = True。

---

## Task 1：battle_art.gd 純函式 + 測試

**Files:** Create `src/screens/BattleScreen/battle_art.gd`、Create `test/TestBattleArt.gd`/`.tscn`

- [ ] **Step 1** 寫 `battle_art.gd`：

```gdscript
class_name BattleArt
extends RefCounted

## 戰鬥畫面美術：路徑解析 + 暗金霓虹框工廠（純函式，可 headless 測）

const BG_DIR := "res://assets/2d/backgrounds/"
const ENEMY_DIR := "res://assets/2d/portraits/enemies/"
const BOSS_DIR := "res://assets/2d/portraits/boss/"
const WUJIE_DIR := "res://assets/2d/portraits/wujie/"
const GOLD := Color(0.788, 0.659, 0.38)

const DISTRICT_BG := {
	"ximen": "bg_battle_ximen.png",
	"wanhua_old": "bg_battle_wanhua.png",
	"linsen": "bg_battle_linsen.png",
	"pantheon": "bg_battle_pantheon.png",
}

## boss.json 的 battle_bg 優先；否則依 district；再 fallback ximen。
static func resolve_battle_bg(data: Dictionary) -> String:
	var f: String = String(data.get("battle_bg", ""))
	if f == "":
		f = DISTRICT_BG.get(String(data.get("district", "")), "bg_battle_ximen.png")
	return BG_DIR + f

## 立繪裸檔名 → 先 enemies/ 再 boss/，皆無回 ""。
static func resolve_portrait_path(filename: String) -> String:
	if filename == "":
		return ""
	var e := ENEMY_DIR + filename
	if ResourceLoader.exists(e):
		return e
	var b := BOSS_DIR + filename
	if ResourceLoader.exists(b):
		return b
	return ""

## 玩家立繪：依職業 + 表情（calm/angry）。
static func player_portrait_path(job: String, mood: String = "calm") -> String:
	var j := job if job in ["ascetic", "chanter", "beggar"] else "ascetic"
	return "%swujie_%s_%s.jpg" % [WUJIE_DIR, j, mood]

## 暗金霓虹框：近黑底 + 金邊 + 金光暈。
static func neon_frame() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.043, 0.043, 0.85)
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
	sb.shadow_size = 6
	sb.set_content_margin_all(6)
	return sb
```

- [ ] **Step 2** 寫 `test/TestBattleArt.gd`（先放第 1 批斷言，後續 task 再補）：

```gdscript
extends Node
## headless 驗證：戰鬥畫面美術串接（背景/立繪路徑解析 + 載入 + 面板建構）
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
	_test_neon_frame()
	_test_panels_smoke()
	print("BATTLE_ART_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _enemies() -> Dictionary:
	var d := JsonLoader.load_json("res://data/enemies.json")
	d.merge(JsonLoader.load_json("res://data/boss.json"))
	return d

func _test_bg_resolution() -> void:
	var d := _enemies()
	var cases := {
		"street_punk": "bg_battle_ximen.png", "night_ghost": "bg_battle_wanhua.png",
		"drunk_guard": "bg_battle_linsen.png", "pantheon_guard": "bg_battle_pantheon.png",
		"ares": "bg_battle_boss.png",
	}
	for id in cases:
		var p := BattleArt.resolve_battle_bg(d.get(id, {}))
		_check(p.ends_with(cases[id]), "%s 背景→%s (got %s)" % [id, cases[id], p])
		_check(ResourceLoader.exists(p) and load(p) is Texture2D, "背景可載入：%s" % p)

func _test_portrait_resolution() -> void:
	var d := _enemies()
	for id in ["street_punk", "corrupt_vendor", "night_ghost", "drunk_guard", "temple_ghost", "pantheon_guard", "ares"]:
		var f := String(d.get(id, {}).get("portrait", ""))
		var p := BattleArt.resolve_portrait_path(f)
		_check(p != "" and load(p) is Texture2D, "%s 立繪可載入 (got %s)" % [id, p])
	# ares 三個 mood
	var moods: Dictionary = d.get("ares", {}).get("portrait_moods", {})
	_check(moods.size() >= 3, "ares portrait_moods >=3 (got %d)" % moods.size())
	for k in moods:
		var p := BattleArt.resolve_portrait_path(String(moods[k]))
		_check(p != "" and load(p) is Texture2D, "ares mood %s 可載入" % k)

func _test_player_portrait() -> void:
	for job in ["ascetic", "chanter", "beggar"]:
		for mood in ["calm", "angry"]:
			var p := BattleArt.player_portrait_path(job, mood)
			_check(ResourceLoader.exists(p) and load(p) is Texture2D, "玩家立繪 %s/%s 可載入" % [job, mood])

func _test_neon_frame() -> void:
	var sb := BattleArt.neon_frame()
	_check(sb is StyleBoxFlat and sb.border_width_left == 2, "neon_frame 回 StyleBoxFlat 金邊2")

func _test_panels_smoke() -> void:
	pass  # Task 4/6 補
```

- [ ] **Step 3** `.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/TestBattleArt.gd" id="1_test"]
[node name="TestBattleArt" type="Node"]
script = ExtResource("1_test")
```

- [ ] **Step 4** 跑 `& $godot --headless --path D:\monk\MONK "res://test/TestBattleArt.tscn"`。
  - 預期：`BATTLE_ART_TEST: ALL PASS`（Task 0 的 bg 已存在、ares mood 需 Task 2 補資料——此時 `_test_portrait_resolution` 的 mood 段會 FAIL，屬預期，Task 2 後轉 PASS）。實務上先把 Task 2 一起做完再跑全綠。

---

## Task 2：Combatant 帶 portrait_path / portrait_moods + boss.json moods

**Files:** Modify `Combatant.gd:32-49`、`data/boss.json`

- [ ] **Step 1** `Combatant.gd` 加欄位（在 `var buffs` 後）：

```gdscript
var portrait_path: String = ""
var portrait_moods: Dictionary = {}  # mood_key → 已解析 res:// 路徑
```

- [ ] **Step 2** `from_enemy` 在 `c.is_boss = ...` 後、`return c` 前插入：

```gdscript
	c.portrait_path = BattleArt.resolve_portrait_path(String(data.get("portrait", "")))
	for k in data.get("portrait_moods", {}):
		var rp := BattleArt.resolve_portrait_path(String(data["portrait_moods"][k]))
		if rp != "":
			c.portrait_moods[k] = rp
```

- [ ] **Step 3** `data/boss.json` ares 在 `"portrait": "ares_base.jpg",` 後加：

```json
    "portrait_moods": { "hurt": "ares_pained.jpg", "act": "ares_mocking_laugh.jpg", "phase2": "ares_phase2.jpg" },
```

- [ ] **Step 4** 跑 TestBattleArt → 預期 `ALL PASS`（bg＋全立繪＋ares 3 mood＋玩家 6 圖皆載入）。

---

## Task 3：BattleScreen.tscn — 背景 TextureRect + PlayerPanel 重構

**Files:** Modify `BattleScreen.tscn`

- [ ] **Step 1** 在 `[node name="Background" ...]`（純色 ColorRect）之後、`EnemyArea` 之前，插入背景圖 TextureRect（蓋在純色之上、其餘 UI 之下）：

```
[node name="BattleBg" type="TextureRect" parent="BattleUI"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
expand_mode = 1
stretch_mode = 6
```
（`stretch_mode=6`＝KEEP_ASPECT_COVERED，`expand_mode=1`＝IGNORE_SIZE。）

- [ ] **Step 2** `PlayerPanel` 內把 `Margin` 的子節點由 `VBox` 改成 `HBox`，左加 `PlayerPortrait`：將
```
[node name="VBox" type="VBoxContainer" parent="BattleUI/PlayerPanel/Margin"]
```
改為
```
[node name="HBox" type="HBoxContainer" parent="BattleUI/PlayerPanel/Margin"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="PlayerPortrait" type="TextureRect" parent="BattleUI/PlayerPanel/Margin/HBox"]
unique_name_in_owner = true
custom_minimum_size = Vector2(110, 150)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="VBox" type="VBoxContainer" parent="BattleUI/PlayerPanel/Margin/HBox"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 8
```
並把原 `PlayerName`/`PlayerHPBar`/`PlayerHPText`/`ResourceLabel` 的 `parent` 由 `BattleUI/PlayerPanel/Margin/VBox` 改為 `BattleUI/PlayerPanel/Margin/HBox/VBox`。（`stretch_mode=5`＝KEEP_ASPECT_CENTERED。）

- [ ] **Step 3** 跑 `& $godot --headless --path D:\monk\MONK --editor --quit` → 預期無 parse/scene error（場景能載）。

---

## Task 4：EnemyPanel 立繪 + neon 框 + mood 基元

**Files:** Modify `EnemyPanel.gd`

- [ ] **Step 1** `_init` 開頭 `add_child(vbox)` 後、`_name_label` 前，插入立繪框：

```gdscript
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(200, 150)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_base_portrait = c.portrait_path
	if _base_portrait != "" and ResourceLoader.exists(_base_portrait):
		_portrait_rect.texture = load(_base_portrait)
		add_theme_stylebox_override("panel", BattleArt.neon_frame())
	else:
		_portrait_rect.visible = false
	vbox.add_child(_portrait_rect)
```

- [ ] **Step 2** 宣告成員（檔頭 `var _target_button: Button` 附近）：

```gdscript
var _portrait_rect: TextureRect
var _base_portrait: String = ""
var _mood_timer: SceneTreeTimer = null
```

- [ ] **Step 3** 加方法：

```gdscript
## 持久換底圖（Boss 進階段用）
func set_base_portrait(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	_base_portrait = path
	_portrait_rect.texture = load(path)

## 暫態表情：切 path，secs 後回 _base（新 flash 取消舊的）
func flash_mood(path: String, secs: float) -> void:
	if path == "" or not ResourceLoader.exists(path) or _portrait_rect == null or not _portrait_rect.visible:
		return
	_portrait_rect.texture = load(path)
	_mood_timer = get_tree().create_timer(secs)
	var my := _mood_timer
	await my.timeout
	if my == _mood_timer and is_instance_valid(_portrait_rect):  # 沒被更新的 flash 蓋過
		_portrait_rect.texture = load(_base_portrait)
```

- [ ] **Step 4** TestBattleArt `_test_panels_smoke` 補：

```gdscript
func _test_panels_smoke() -> void:
	var d := _enemies()
	var c := Combatant.from_enemy("pantheon_guard", d["pantheon_guard"])
	var panel := EnemyPanel.new(c, 0)
	add_child(panel)
	_check(panel._portrait_rect != null and panel._portrait_rect.texture != null, "EnemyPanel 有立繪")
	var ares := Combatant.from_enemy("ares", d["ares"])
	var bp := EnemyPanel.new(ares, 0)
	add_child(bp)
	bp.set_base_portrait(ares.portrait_moods.get("phase2", ""))
	_check(bp._base_portrait.ends_with("ares_phase2.jpg"), "Boss set_base_portrait 切 phase2")
	panel.queue_free(); bp.queue_free()
```

- [ ] **Step 5** 跑 TestBattleArt → 預期 `ALL PASS`。

---

## Task 5：BattleManager — 設背景 + Boss 表情時機

**Files:** Modify `BattleManager.gd`

- [ ] **Step 1** `setup` 內 `ui.build(...)` 後加設背景：

```gdscript
	ui.set_battle_bg(BattleArt.resolve_battle_bg(data))
```

- [ ] **Step 2** `setup` 內 `_init_boss_phases(data)` 後，若有 boss 連 hurt：

```gdscript
	if _boss != null and not _boss.portrait_moods.get("hurt", "").is_empty():
		_boss_hp_seen = _boss.current_hp
		_boss.hp_changed.connect(_on_boss_hp_changed)
```
並加成員與 handler：

```gdscript
var _boss_hp_seen: int = 0

func _on_boss_hp_changed(current: int, _mx: int) -> void:
	if current < _boss_hp_seen and current > 0:
		ui.flash_enemy_mood(_boss, _boss.portrait_moods.get("hurt", ""), 0.6)
	_boss_hp_seen = current
```

- [ ] **Step 3** `_enemy_turn` 內 `executor.execute_enemy_action(...)` 後（`battle_log` act 那段附近）加 act 表情：

```gdscript
		if e == _boss and not act.is_empty():
			ui.flash_enemy_mood(_boss, _boss.portrait_moods.get("act", ""), 0.8)
```

- [ ] **Step 4** `_maybe_trigger_boss_phase2` 內 `_apply_boss_phase(next_idx)` 後加持久換 phase2 立繪：

```gdscript
	ui.set_enemy_base(_boss, _boss.portrait_moods.get("phase2", ""))
```

- [ ] **Step 5** 跑 TestBattleArt + `--editor --quit` → 預期 PASS / 無 parse error。

---

## Task 6：BattleUI — 玩家立繪 + 低HP換臉 + enemy mood 轉接

**Files:** Modify `BattleUI.gd`

- [ ] **Step 1** `@onready` 區加：

```gdscript
@onready var battle_bg: TextureRect = %BattleBg
@onready var player_portrait: TextureRect = %PlayerPortrait
```
（`_panels` 已存在；玩家職業換臉需記 job/狀態。）成員加：

```gdscript
var _player_job: String = "ascetic"
var _player_low: bool = false
```

- [ ] **Step 2** `build` 內設玩家立繪（`player_name.text = ...` 後）：

```gdscript
	_player_job = GameManager.player.job
	_player_low = false
	_set_player_portrait("calm")
```
並在 `player.hp_changed` 的 lambda 內（更新 HP 文字後）加低 HP 換臉：

```gdscript
		var low := cur < mx * 0.3
		if low != _player_low:
			_player_low = low
			_set_player_portrait("angry" if low else "calm")
```

- [ ] **Step 3** 加方法：

```gdscript
func set_battle_bg(path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		battle_bg.texture = load(path)

func _set_player_portrait(mood: String) -> void:
	var p := BattleArt.player_portrait_path(_player_job, mood)
	if ResourceLoader.exists(p):
		player_portrait.texture = load(p)
		player_portrait.visible = true
	else:
		player_portrait.visible = false

func _panel_for(c: Combatant) -> EnemyPanel:
	for p in _panels:
		if p.combatant == c:
			return p
	return null

func flash_enemy_mood(c: Combatant, path: String, secs: float) -> void:
	var p := _panel_for(c)
	if p != null:
		p.flash_mood(path, secs)

func set_enemy_base(c: Combatant, path: String) -> void:
	var p := _panel_for(c)
	if p != null:
		p.set_base_portrait(path)
```

- [ ] **Step 4** TestBattleArt `_test_panels_smoke` 末補玩家立繪煙霧（用 BattleScreen 場景太重，改直接驗 path 已在 Task 1 蓋；此處只確認 `BattleArt.player_portrait_path` 對 job 回正確檔，已蓋）。略。

- [ ] **Step 5** 跑 TestBattleArt → 預期 `ALL PASS`。

---

## Task 7：整合驗證 + 匯入 + 回歸

- [ ] `& $godot --headless --path D:\monk\MONK --import`（確保新 bg + 任何新資源匯入）。
- [ ] 跑 `res://test/TestBattleArt.tscn` → `BATTLE_ART_TEST: ALL PASS`。
- [ ] 回歸：`TestMainQuest.tscn`、`TestMenuSystem.tscn`、`TestCh1Expansion.tscn` 皆 ALL PASS。
- [ ] `& $godot --headless --path D:\monk\MONK --editor --quit` → 無 parse error。
- [ ] 更新 `PROJECT_STATUS.md`（戰鬥美術缺口標完成）＋記憶 `project-build-status`。
- [ ] 回報：GPU 待使用者抽驗（背景/立繪/霓虹框觀感、阿瑞斯 4 表情切換時機、玩家低 HP 換臉）。

---

## Self-Review
- **Spec coverage**：背景①→Task3/5/6；敵Boss立繪②→Task2/4；ares 4 mood③→Task2/4/5；玩家立繪④→Task3/6；neon helper⑤→Task1；新 bg⑥→Task0；測試→Task1-7。全覆蓋。
- **型別一致**：`portrait_path`/`portrait_moods`(Combatant)、`set_base_portrait`/`flash_mood`(EnemyPanel)、`set_battle_bg`/`flash_enemy_mood`/`set_enemy_base`/`_set_player_portrait`/`_panel_for`(BattleUI)、`resolve_battle_bg`/`resolve_portrait_path`/`player_portrait_path`/`neon_frame`(BattleArt)——各 task 用法一致。
- **無 placeholder**：每步有實碼/實指令。
- **雷**：新 bg 要 `--import`；headless 不驗觀感；flash 競態用「my==_mood_timer」守衛；phase2 revert 回的是更新後 `_base_portrait`（持久）非寫死。
