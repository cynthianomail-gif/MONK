# 手機選單 app（移動／105 打工／設定）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 補完手機裝置剩餘 app：移動（捷運+計程車）、105 打工、設定（音量/全螢幕/文字速度），含 AudioManager 音量 bus 與 SettingsManager 偏好持久化。

**Architecture:** 沿用 `MenuShell` 的 `MenuDevice` 頁面契約（每頁＝一個 `Control`，`.new()` 出來、`_ready` 內建 UI）。新增 `SettingsManager` autoload 為設定單一真相源（讀寫 `user://settings.cfg`、開機 `apply_all()`）；AudioManager 加執行期音量 bus（Master→BGM/SFX）＋ linear setter/getter。計程車「直達地點」靠 GameManager 暫存 `pending_arrival` → MapScreen 載入時把無戒生在該地點門口。

**Tech Stack:** Godot 4.5 / GDScript；既有 `GameManager`/`SceneRouter`/`AudioManager`/`Dialogic`/`MenuShell`。

**設計來源：** `docs/superpowers/specs/2026-06-16-phone-apps-design.md`

---

## 前置說明

- **Godot：** `D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe`（headless），專案 `D:/monk/MONK`。
- **版控：** 專案不在 git 下；各 Task 的「Commit」步驟為**選用 checkpoint，可略**。
- **測試＝** 擴充既有 `test/TestMenuSystem.tscn`（root Node＋腳本，`_check(cond,msg)`，結尾印 `MENU_TEST: ALL PASS`）。跑法：
  `& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestMenuSystem.tscn`
  ⚠ headless 跑完 teardown 偶有 segfault（退碼非 0），**以印出的 `MENU_TEST: ALL PASS` 為準**。
- **parse 檢查：** 新增/改 .gd 後跑一次
  `& "...console.exe" --headless --path "D:\monk\MONK" --editor --quit`，確認無 `SCRIPT ERROR`/parse error。
- **TDD 流程說明：** 本專案只有單一測試場景。各 Task「先寫測試」＝在 `TestMenuSystem.gd` 加測試函式＋於 `_ready` 呼叫；「跑測試看失敗」＝跑整個場景，因目標 API/頁面未實作 → 出現 `FAIL:`／runtime error／非 `ALL PASS`；實作後重跑 → `ALL PASS`。

---

## 檔案結構

**新增：**
- `src/autoloads/SettingsManager.gd` — 設定單一真相源（load/save `user://settings.cfg`、`apply_all`、`get_setting`/`set_setting`）
- `src/ui/menu/pages/TravelApp.gd` — 移動頁（捷運區塊＋計程車區塊），取代 FastTravelApp
- `src/ui/menu/pages/JobApp.gd` — 105 打工頁
- `src/ui/menu/pages/SettingsApp.gd` — 設定頁

**修改：**
- `src/autoloads/AudioManager.gd` — 加 `_ensure_buses()`＋player 指派 bus＋`set_bus_volume_linear`/`get_bus_volume_linear`
- `src/autoloads/GameManager.gd` — 加暫存欄位 `pending_arrival`（不存檔）
- `src/screens/MapScreen/MapScreen.gd` — `_ready` 讀 `pending_arrival`；`show_district` 加 spawn 覆寫參數
- `src/screens/MapScreen/DistrictScene.gd` — `setup` 加 `spawn_x_frac` 參數
- `src/ui/menu/MenuShell.gd` — 手機頁籤改 `任務/情報/移動/打工/設定`；preload 換 TravelApp、加 JobApp/SettingsApp；移除 `其他` 佔位
- `project.godot` — `[autoload]` 末尾加 `SettingsManager`
- `test/TestMenuSystem.gd` — 加新測試函式

**刪除：**
- `src/ui/menu/pages/FastTravelApp.gd`（＋ `.uid`）— 由 TravelApp 取代

**不動：** SceneRouter、MapHUD、其他頁面、戰鬥/對話系統。

---

## Task 1: AudioManager 音量 bus ＋ linear API

**Files:**
- Modify: `src/autoloads/AudioManager.gd`
- Modify: `test/TestMenuSystem.gd`

- [ ] **Step 1: 寫失敗測試**

在 `test/TestMenuSystem.gd` 的 `_ready()`，於 `_test_check_unlocks()` 後加一行 `_test_audio_buses()`；並新增函式：

```gdscript
func _test_audio_buses() -> void:
	# 三條 bus 都存在（Master 內建 + 執行期建 BGM/SFX）
	_check(AudioServer.get_bus_index("BGM") != -1, "BGM bus exists")
	_check(AudioServer.get_bus_index("SFX") != -1, "SFX bus exists")
	# linear setter/getter 往返
	AudioManager.set_bus_volume_linear("BGM", 0.5)
	var v := AudioManager.get_bus_volume_linear("BGM")
	_check(absf(v - 0.5) < 0.02, "BGM bus volume ~0.5 (got %f)" % v)
	# 0 → 靜音、不報錯
	AudioManager.set_bus_volume_linear("SFX", 0.0)
	_check(AudioManager.get_bus_volume_linear("SFX") < 0.01, "SFX muted at 0")
	# 還原
	AudioManager.set_bus_volume_linear("BGM", 1.0)
	AudioManager.set_bus_volume_linear("SFX", 1.0)
```

- [ ] **Step 2: 跑測試看失敗**

Run: `& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestMenuSystem.tscn`
Expected: 非 `ALL PASS`（`set_bus_volume_linear` 未定義 → runtime error / FAIL）。

- [ ] **Step 3: 實作 AudioManager bus**

在 `src/autoloads/AudioManager.gd` 的 `_ready()` 內，於載入 lib 之後加上 bus 初始化與指派：

```gdscript
func _ready() -> void:
	_bgm_lib = JsonLoader.load_json("res://data/audio_bgm.json")
	_sfx_lib = JsonLoader.load_json("res://data/audio_sfx.json")
	_ensure_buses()
	bgm_player.bus = "BGM"
	sfx_player.bus = "SFX"
	voice_player.bus = "SFX"   # 語音併 SFX 條（設定只有 3 條滑桿）
```

並在檔案末尾新增：

```gdscript
## 執行期建立 BGM/SFX 兩條子匯流排（送往 Master），避免依賴 .tres bus layout。
func _ensure_buses() -> void:
	for bus_name in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

## 設某 bus 音量（linear 0~1）。0 視為靜音（-80dB）。
func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear) if linear > 0.0005 else -80.0)

## 讀某 bus 目前音量（linear 0~1）。bus 不存在回 1.0。
func get_bus_volume_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)
```

註：`switch_bgm`/`fade_bgm_to` 仍操作 `bgm_player.volume_db`；player volume_db 與 bus 音量相加，互不衝突，不需改。

- [ ] **Step 4: 跑測試看通過**

Run: 同 Step 2。
Expected: `MENU_TEST: ALL PASS`。

- [ ] **Step 5（選用）: checkpoint**

---

## Task 2: SettingsManager autoload

**Files:**
- Create: `src/autoloads/SettingsManager.gd`
- Modify: `project.godot`（`[autoload]` 末尾）
- Modify: `test/TestMenuSystem.gd`

- [ ] **Step 1: 寫失敗測試**

`_ready()` 加 `_test_settings_manager()`；新增函式：

```gdscript
func _test_settings_manager() -> void:
	# set→get 往返
	SettingsManager.set_setting("bgm_vol", 0.3)
	_check(absf(float(SettingsManager.get_setting("bgm_vol")) - 0.3) < 0.001, "settings bgm_vol roundtrip")
	# set 後即時套到 bus
	_check(absf(AudioManager.get_bus_volume_linear("BGM") - 0.3) < 0.02, "settings applied to BGM bus")
	# 文字速度反轉：UI 2.0x（更快）→ Dialogic delay 0.5
	SettingsManager.set_setting("text_speed", 2.0)
	if Dialogic.has_subsystem("Settings"):
		_check(absf(float(Dialogic.Settings.text_speed) - 0.5) < 0.001, "text_speed inverted to 0.5")
	# 持久化：寫檔後另一個實例載入應一致
	var sm2 = load("res://src/autoloads/SettingsManager.gd").new()
	get_tree().root.add_child(sm2)
	await get_tree().process_frame
	_check(absf(float(sm2.get_setting("bgm_vol")) - 0.3) < 0.001, "settings persisted across instance")
	sm2.queue_free()
	# 還原
	SettingsManager.set_setting("bgm_vol", 1.0)
	SettingsManager.set_setting("text_speed", 1.0)
```

並把 `_test_settings_manager()` 設為 `await`（它有 `await`）：在 `_ready` 寫 `await _test_settings_manager()`。

- [ ] **Step 2: 跑測試看失敗**

Run: 同上。Expected: 非 `ALL PASS`（`SettingsManager` autoload 不存在 → error）。

- [ ] **Step 3: 建立 SettingsManager.gd**

`src/autoloads/SettingsManager.gd`：

```gdscript
extends Node
## 全域偏好設定單一真相源。讀寫 user://settings.cfg（獨立於存檔），開機 apply_all。
## 音量存 linear 0~1；text_speed 存「速度倍率」（越大越快，0.5~2.0），套用時反轉成 Dialogic 的延遲倍率。

const PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULTS := {
	"master_vol": 1.0,
	"bgm_vol": 1.0,
	"sfx_vol": 1.0,
	"fullscreen": false,
	"text_speed": 1.0,
}

var _data: Dictionary = {}

func _ready() -> void:
	_load()
	apply_all()

func _load() -> void:
	_data = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			_data[k] = cfg.get_value(SECTION, k, DEFAULTS[k])

func _save() -> void:
	var cfg := ConfigFile.new()
	for k in _data:
		cfg.set_value(SECTION, k, _data[k])
	cfg.save(PATH)

func get_setting(key: String) -> Variant:
	return _data.get(key, DEFAULTS.get(key))

func set_setting(key: String, value: Variant) -> void:
	_data[key] = value
	_apply_one(key)
	_save()

func apply_all() -> void:
	for k in _data:
		_apply_one(k)

func _apply_one(key: String) -> void:
	match key:
		"master_vol":
			AudioManager.set_bus_volume_linear("Master", float(_data[key]))
		"bgm_vol":
			AudioManager.set_bus_volume_linear("BGM", float(_data[key]))
		"sfx_vol":
			AudioManager.set_bus_volume_linear("SFX", float(_data[key]))
		"fullscreen":
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_data[key])
				else DisplayServer.WINDOW_MODE_WINDOWED)
		"text_speed":
			_apply_text_speed(float(_data[key]))

func _apply_text_speed(speed_mult: float) -> void:
	speed_mult = clampf(speed_mult, 0.5, 2.0)
	# Dialogic text_speed = 每字延遲倍率（越大越慢）；我們的 speed_mult 越大越快 → 取倒數。
	if Dialogic.has_subsystem("Settings"):
		Dialogic.Settings.text_speed = 1.0 / speed_mult
```

- [ ] **Step 4: 註冊 autoload（排在 AudioManager 與 Dialogic 之後）**

編輯 `project.godot` 的 `[autoload]` 區塊，在**最後一行**加入：

```
SettingsManager="*res://src/autoloads/SettingsManager.gd"
```

（確認此行在 `AudioManager` 與 `Dialogic` 之後；apply_all 需要兩者已就緒。）

- [ ] **Step 5: 跑測試看通過**

Run: 同上。Expected: `MENU_TEST: ALL PASS`。

- [ ] **Step 6（選用）: checkpoint**

---

## Task 3: SettingsApp 設定頁

**Files:**
- Create: `src/ui/menu/pages/SettingsApp.gd`
- Modify: `test/TestMenuSystem.gd`（smoke）

- [ ] **Step 1: 寫失敗測試（smoke）**

在 `_smoke_scenes()` 末尾、`SkillsPage/StatusPage` 迴圈之後加：

```gdscript
	# 新手機 app smoke（含設定頁）
	for path in ["res://src/ui/menu/pages/TravelApp.gd",
			"res://src/ui/menu/pages/JobApp.gd",
			"res://src/ui/menu/pages/SettingsApp.gd"]:
		var gs2 = load(path)
		if gs2 == null:
			_check(false, "load %s" % path); continue
		var page2 = gs2.new()
		get_tree().root.add_child(page2)
		for i in 3:
			await get_tree().process_frame
		_check(is_instance_valid(page2), "phone app alive %s" % path)
		page2.queue_free()
		await get_tree().process_frame
```

- [ ] **Step 2: 跑測試看失敗**

Run: 同上。Expected: 非 `ALL PASS`（`SettingsApp.gd` 等不存在 → `FAIL: load ...`）。

- [ ] **Step 3: 建立 SettingsApp.gd**

`src/ui/menu/pages/SettingsApp.gd`：

```gdscript
extends VBoxContainer
## 手機「設定」頁：主/BGM/SFX 音量、全螢幕、文字速度。即時套用＋寫檔（SettingsManager）。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)

func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "設定"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)

	_add_slider("主音量", "master_vol", 0.0, 1.0, 0.05)
	_add_slider("背景音樂", "bgm_vol", 0.0, 1.0, 0.05)
	_add_slider("音效", "sfx_vol", 0.0, 1.0, 0.05)
	_add_fullscreen_toggle()
	_add_slider("文字速度", "text_speed", 0.5, 2.0, 0.1)

func _add_slider(label_text: String, key: String, mn: float, mx: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_color_override("font_color", WARM)
	lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = step
	slider.value = float(SettingsManager.get_setting(key))
	slider.custom_minimum_size = Vector2(360, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var k := key
	slider.value_changed.connect(func(v: float) -> void: SettingsManager.set_setting(k, v))
	row.add_child(slider)
	add_child(row)

func _add_fullscreen_toggle() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = "全螢幕"
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_color_override("font_color", WARM)
	lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(SettingsManager.get_setting("fullscreen"))
	cb.toggled.connect(func(on: bool) -> void: SettingsManager.set_setting("fullscreen", on))
	row.add_child(cb)
	add_child(row)
```

- [ ] **Step 4: 跑測試看通過**

Run: 同上。Expected: `MENU_TEST: ALL PASS`（注意：TravelApp/JobApp 此時還沒建，smoke 會對它們 FAIL；可先只放 SettingsApp 到迴圈，或接著做 Task 5/6 後本步才全綠。**建議：本 Task Step 1 迴圈先只放 SettingsApp，Task 5/6 完成時再把 TravelApp/JobApp 加回**。）

> 修正 Step 1：本 Task 先只測 SettingsApp：
> ```gdscript
> 	for path in ["res://src/ui/menu/pages/SettingsApp.gd"]:
> ```
> Task 5 完成後改成 `[..., "TravelApp.gd"]`，Task 6 完成後加 `"JobApp.gd"`。

- [ ] **Step 5（選用）: checkpoint**

---

## Task 4: 計程車落點（GameManager + MapScreen + DistrictScene）

**Files:**
- Modify: `src/autoloads/GameManager.gd`
- Modify: `src/screens/MapScreen/MapScreen.gd`
- Modify: `src/screens/MapScreen/DistrictScene.gd`
- Modify: `test/TestMenuSystem.gd`

- [ ] **Step 1: 寫失敗測試**

`_ready()` 加 `_test_pending_arrival()`；新增：

```gdscript
func _test_pending_arrival() -> void:
	# GameManager 有可寫的暫存欄位，預設空
	GameManager.pending_arrival = {}
	_check(GameManager.pending_arrival.is_empty(), "pending_arrival starts empty")
	GameManager.pending_arrival = {"area": "ximen", "x": 0.66}
	_check(float(GameManager.pending_arrival.get("x", -1.0)) == 0.66, "pending_arrival writable")
	GameManager.pending_arrival = {}
	# DistrictScene.setup 接受 spawn_x_frac 參數（簽章存在即可，煙霧）
	var ds = load("res://src/screens/MapScreen/DistrictScene.tscn").instantiate()
	get_tree().root.add_child(ds)
	await get_tree().process_frame
	_check(ds.has_method("setup"), "DistrictScene has setup")
	ds.queue_free()
	await get_tree().process_frame
```

把 `_test_pending_arrival()` 以 `await` 呼叫。

- [ ] **Step 2: 跑測試看失敗**

Run: 同上。Expected: 非 `ALL PASS`（`GameManager.pending_arrival` 不存在 → error）。

- [ ] **Step 3a: GameManager 加暫存欄位**

在 `src/autoloads/GameManager.gd`、`player` 字典宣告**之後**加（檔案層級變數，不放進 player dict、不存檔）：

```gdscript
## 計程車落點暫存：{area, x}。MapScreen 載入時讀一次後清空。不寫進 player、不存檔。
var pending_arrival: Dictionary = {}
```

- [ ] **Step 3b: DistrictScene.setup 加 spawn 覆寫**

`src/screens/MapScreen/DistrictScene.gd`，把 `setup` 簽章與 wujie 定位改成：

```gdscript
func setup(area: Dictionary, locations: Array, period: int, locked_areas: Dictionary = {}, spawn_x_frac: float = -1.0) -> void:
	var tex := _load_tex(String(area.get("scene_2d", "")))
	var vp := get_viewport_rect().size
	if tex:
		bg.texture = tex
		_map_w = tex.get_width()
	else:
		_map_w = vp.x * 2.5
		bg.texture = _placeholder_tex(int(_map_w), int(vp.y))
	bg.scale = Vector2.ONE
	var bh := bg.texture.get_height()
	var sp: Dictionary = area.get("scene_spawn", {"x": 0.1, "y": 0.82})
	var spawn_frac_x: float = float(sp.x) if spawn_x_frac < 0.0 else clampf(spawn_x_frac, 0.0, 1.0)
	wujie.position = Vector2(_map_w * spawn_frac_x, bh * float(sp.y))
	_ground_y = wujie.position.y
	_target_x = wujie.position.x
	_auto = false; _pending = null
	cam.limit_left = 0; cam.limit_right = int(_map_w)
	cam.limit_top = 0; cam.limit_bottom = bh
	_build_portals(area, locations, period, bh, locked_areas)
	apply_period_tint(period)
	_update_camera()
```

（只改 wujie 水平位置來源；y 仍用 `scene_spawn.y` 地面帶。其餘行為不變。）

- [ ] **Step 3c: MapScreen 串接**

`src/screens/MapScreen/MapScreen.gd`：把 `show_district` 改成可帶 spawn 覆寫，並在 `_ready` 讀 `pending_arrival`。

`show_district`：

```gdscript
## 載入某區街景。spawn_x_frac >= 0 時覆寫無戒水平落點（計程車直達地點用）。
func show_district(area_id: String, spawn_x_frac: float = -1.0) -> void:
	_current_area = area_id
	GameManager.player.current_area = area_id
	var area: Dictionary = _areas.get(area_id, {})
	district.setup(area, _locs_in(area_id), int(GameManager.player.period), _locked_areas(), spawn_x_frac)
	AudioManager.switch_bgm(String(area.get("bgm", "temple_ambient")))
```

`_ready` 內，把原本的 `show_district(_current_area)` 換成：

```gdscript
	var arrival_x := -1.0
	if not GameManager.pending_arrival.is_empty() \
			and String(GameManager.pending_arrival.get("area", "")) == _current_area:
		arrival_x = float(GameManager.pending_arrival.get("x", -1.0))
	GameManager.pending_arrival = {}
	show_district(_current_area, arrival_x)
```

（`_on_time_advanced` 內對 `district.setup(...)` 的呼叫**不動**＝沿用預設 spawn。）

- [ ] **Step 4: 跑測試看通過**

Run: 同上。Expected: `MENU_TEST: ALL PASS`。

- [ ] **Step 5（選用）: checkpoint**

---

## Task 5: TravelApp 移動頁（捷運＋計程車），取代 FastTravelApp

**Files:**
- Create: `src/ui/menu/pages/TravelApp.gd`
- Delete: `src/ui/menu/pages/FastTravelApp.gd`（＋ `.uid`）
- Modify: `test/TestMenuSystem.gd`

- [ ] **Step 1: 寫失敗測試**

`_ready()` 加 `_test_travel_app()`；新增：

```gdscript
func _test_travel_app() -> void:
	var app = load("res://src/ui/menu/pages/TravelApp.gd").new()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	# 捷運扣款＋耗時（_pay_mrt 只處理付費/推時，不換場）
	GameManager.player.gold = 100
	var p0: int = GameManager.player.period
	var ok_mrt: bool = app._pay_mrt("wanhua_old")
	_check(ok_mrt and GameManager.player.gold == 95, "MRT charges 5 gold (got %d)" % GameManager.player.gold)
	_check(GameManager.player.period == (p0 + 1) % 4, "MRT advances 1 period")
	# 計程車扣款＋設 pending_arrival、不耗時
	GameManager.player.gold = 100
	GameManager.pending_arrival = {}
	var p1: int = GameManager.player.period
	var ok_taxi: bool = app._pay_taxi("old_temple")
	_check(ok_taxi and GameManager.player.gold == 70, "taxi charges 30 gold (got %d)" % GameManager.player.gold)
	_check(GameManager.player.period == p1, "taxi no time cost")
	_check(String(GameManager.pending_arrival.get("area", "")) == "wanhua_old", "taxi sets pending area")
	# 錢不夠：不扣款、不動作
	GameManager.player.gold = 2
	GameManager.pending_arrival = {}
	_check(not app._pay_taxi("old_temple"), "taxi fails when broke")
	_check(GameManager.player.gold == 2, "broke: gold unchanged")
	_check(GameManager.pending_arrival.is_empty(), "broke: no pending")
	app.queue_free()
	GameManager.player.gold = 1000
	await get_tree().process_frame
```

以 `await` 呼叫。

- [ ] **Step 2: 跑測試看失敗**

Run: 同上。Expected: 非 `ALL PASS`（TravelApp 不存在）。

- [ ] **Step 3: 建立 TravelApp.gd**

`src/ui/menu/pages/TravelApp.gd`：

```gdscript
extends VBoxContainer
## 手機「移動」頁：捷運（便宜+耗1時段，到區中心）＋ 計程車（貴+即時，直達已解鎖地點）。
## 付費邏輯抽成 _pay_mrt/_pay_taxi（回 bool，不換場）供測試；按鈕成功後才真的 travel。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.55, 0.52, 0.46)
const MRT_FARE := 5
const TAXI_FARE := 30

var _toast: Label

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_toast = Label.new()
	_toast.add_theme_color_override("font_color", GOLD)
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.visible = false

	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var locs: Dictionary = JsonLoader.load_json("res://data/map_locations.json")
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
	for id in locs:
		var loc: Dictionary = locs[id]
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
	return JsonLoader.load_json("res://data/map_locations.json").get(loc_id, {})

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
```

- [ ] **Step 4: 刪除 FastTravelApp**

```bash
rm -f "D:/monk/MONK/src/ui/menu/pages/FastTravelApp.gd" "D:/monk/MONK/src/ui/menu/pages/FastTravelApp.gd.uid"
```

（MenuShell 對它的 preload 在 Task 7 一起移除；此刻 MenuShell 仍 preload FastTravelApp → 先別跑 MenuShell smoke 會壞。**本 Task 跑測試前先做 Task 7 的 MenuShell 改動，或暫時保留 FastTravelApp.gd 到 Task 7**。建議：**本 Task 先不刪 FastTravelApp，改在 Task 7 刪**，避免中途 MenuShell preload 失敗。）

> 修正：本 Task 略過 Step 4，FastTravelApp 留到 Task 7 一起處理。

- [ ] **Step 5: 跑測試看通過**

把 Task 3 smoke 迴圈加入 `"res://src/ui/menu/pages/TravelApp.gd"`。
Run: 同上。Expected: `MENU_TEST: ALL PASS`。

- [ ] **Step 6（選用）: checkpoint**

---

## Task 6: JobApp 105 打工頁

**Files:**
- Create: `src/ui/menu/pages/JobApp.gd`
- Modify: `test/TestMenuSystem.gd`

- [ ] **Step 1: 寫失敗測試**

`_ready()` 加 `_test_job_app()`；新增：

```gdscript
func _test_job_app() -> void:
	var app = load("res://src/ui/menu/pages/JobApp.gd").new()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	# 打工板列兩工
	_check(app.JOBS.size() == 2, "job board has 2 jobs")
	var ids := []
	for j in app.JOBS:
		ids.append(j.id)
	_check("soup_carry" in ids and "beggar_challenge" in ids, "jobs = soup_carry + beggar_challenge")
	# 開工耗 1 時段（_start_job_time 只推時，不換場）
	var p0: int = GameManager.player.period
	app._start_job_time()
	_check(GameManager.player.period == (p0 + 1) % 4, "job advances 1 period")
	app.queue_free()
	await get_tree().process_frame
```

以 `await` 呼叫。

- [ ] **Step 2: 跑測試看失敗**

Run: 同上。Expected: 非 `ALL PASS`（JobApp 不存在）。

- [ ] **Step 3: 建立 JobApp.gd**

`src/ui/menu/pages/JobApp.gd`：

```gdscript
extends VBoxContainer
## 手機「105 打工」頁：打工板列兩工（端湯/化緣），選工耗 1 時段→啟動小遊戲，獎勵走小遊戲 intrinsic。
## 木魚節奏＝街頭藝人對話觸發，不進板。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.55, 0.52, 0.46)

const JOBS := [
	{"id": "soup_carry", "name": "端湯小弟", "desc": "把熱湯端上塔頂，別溢出來。"},
	{"id": "beggar_challenge", "name": "街頭托缽", "desc": "化緣修行，看人下菜。"},
]

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = "105 打工　（每份工耗 1 時段）"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)

	for job in JOBS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var btn := Button.new()
		btn.text = job.name
		btn.add_theme_font_size_override("font_size", 24)
		var jid: String = job.id
		btn.pressed.connect(func() -> void: _take_job(jid))
		box.add_child(btn)
		var desc := Label.new()
		desc.text = job.desc
		desc.add_theme_color_override("font_color", DIM)
		desc.add_theme_font_size_override("font_size", 18)
		box.add_child(desc)
		add_child(box)

## 開工：耗 1 時段（抽出供測試，不換場）。
func _start_job_time() -> void:
	GameManager.advance_time(1)

func _take_job(minigame_id: String) -> void:
	get_tree().paused = false
	_start_job_time()
	SceneRouter.go_to_minigame(minigame_id)
```

- [ ] **Step 4: 跑測試看通過**

把 Task 3 smoke 迴圈加入 `"res://src/ui/menu/pages/JobApp.gd"`（此時迴圈＝SettingsApp/TravelApp/JobApp 三個）。
Run: 同上。Expected: `MENU_TEST: ALL PASS`。

- [ ] **Step 5（選用）: checkpoint**

---

## Task 7: MenuShell 接線（手機 5 頁籤）

**Files:**
- Modify: `src/ui/menu/MenuShell.gd`
- Delete: `src/ui/menu/pages/FastTravelApp.gd`（＋ `.uid`）
- Modify: `test/TestMenuSystem.gd`（驗證手機 5 頁）

- [ ] **Step 1: 寫失敗測試**

`_smoke_scenes()` 內、切到手機裝置那段之後加上頁數驗證：

```gdscript
			# 手機應有 5 頁：任務/情報/移動/打工/設定
			if shell.has_method("_show_device"):
				shell._show_device("phone")
				await get_tree().process_frame
				var phone_pages: Array = shell._devices["phone"]["pages"]
				_check(phone_pages.size() == 5, "phone has 5 pages (got %d)" % phone_pages.size())
				var titles := []
				for p in phone_pages:
					titles.append(p.title)
				_check("移動" in titles and "打工" in titles and "設定" in titles,
					"phone tabs include 移動/打工/設定")
				# 逐頁開啟不崩
				for i in phone_pages.size():
					shell._show_page(i)
					await get_tree().process_frame
				shell._show_device("book")
				await get_tree().process_frame
```

（取代原本只切換裝置的那段。）

- [ ] **Step 2: 跑測試看失敗**

Run: 同上。Expected: 非 `ALL PASS`（手機仍 4 頁、含「其他」佔位；且若已刪 FastTravelApp 則 preload 失敗）。

- [ ] **Step 3: 改 MenuShell 手機頁籤**

`src/ui/menu/MenuShell.gd`：

把 preload 區改成：

```gdscript
const SkillsPage := preload("res://src/ui/menu/pages/SkillsPage.gd")
const StatusPage := preload("res://src/ui/menu/pages/StatusPage.gd")
const QuestsApp := preload("res://src/ui/menu/pages/QuestsApp.gd")
const IntelApp := preload("res://src/ui/menu/pages/IntelApp.gd")
const TravelApp := preload("res://src/ui/menu/pages/TravelApp.gd")
const JobApp := preload("res://src/ui/menu/pages/JobApp.gd")
const SettingsApp := preload("res://src/ui/menu/pages/SettingsApp.gd")
```

把 `_devices` 的 `phone` 頁清單改成：

```gdscript
		"phone": {"name": "手機", "pages": [
			{"title": "任務", "factory": func() -> Control: return QuestsApp.new()},
			{"title": "情報", "factory": func() -> Control: return IntelApp.new()},
			{"title": "移動", "factory": func() -> Control: return TravelApp.new()},
			{"title": "打工", "factory": func() -> Control: return JobApp.new()},
			{"title": "設定", "factory": func() -> Control: return SettingsApp.new()},
		]},
```

移除 `_placeholder()` 函式（不再被引用）。

- [ ] **Step 4: 刪除 FastTravelApp**

```bash
rm -f "D:/monk/MONK/src/ui/menu/pages/FastTravelApp.gd" "D:/monk/MONK/src/ui/menu/pages/FastTravelApp.gd.uid"
```

- [ ] **Step 5: 跑測試看通過 ＋ parse 檢查**

Run: `& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestMenuSystem.tscn`
Expected: `MENU_TEST: ALL PASS`。
Run: `& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" --editor --quit`
Expected: 無 `SCRIPT ERROR`／parse error（FastTravelApp 已無引用）。

- [ ] **Step 6（選用）: checkpoint**

---

## Task 8: 全量回歸 ＋ 視窗實機抽驗

**Files:** 無新增（驗證）

- [ ] **Step 1: 全量 headless 回歸**

Run: 逐一跑
```
res://test/TestMenuSystem.tscn
res://test/TestMainEntry.tscn
res://test/TestDemoScope.tscn
```
Expected: 各自印 `ALL PASS`（注意 teardown 退碼，看印出字串）。

- [ ] **Step 2: 視窗實機抽驗（人工看一眼）**

Run: `& "D:\monk\tools\godot\Godot_v4.5-stable_win64.exe" --path "D:\monk\MONK" res://test/PlayStreet.tscn`
操作：按 `M` 開選單 → 手機 → 逐頁看 移動／打工／設定：
- 設定拉音量滑桿，BGM 音量即時變化；切全螢幕生效；文字速度滑桿可動。
- 移動點捷運→扣 5 金+跳時段+換區；點計程車→扣 30 金+落在該地點門口。
- 打工點端湯/化緣→跳時段+進小遊戲。
Expected: 行為符合；無報錯。

- [ ] **Step 3: 更新文件＋記憶（依 [[feedback-sync-docs-memory]]）**

- 更新 `MONK/PROJECT_STATUS.md`：把「手機其餘 app 待實作」標為 ✅ 完成（移動/打工/設定 + AudioManager 音量 bus + SettingsManager），bump 日期。
- 更新記憶 `project-build-status`：加本次完成項與踩雷（Dialogic text_speed＝延遲倍率需取倒數、執行期 AudioServer 建 bus、SettingsManager 排 autoload 最後）。
- spec 標記為已實作。

- [ ] **Step 4（選用）: checkpoint**

---

## Self-Review（已對照 spec）

- **Spec 覆蓋：** 移動(捷運+計程車)=Task 5；105 打工=Task 6；設定(音量3/全螢幕/文字速度)=Task 3+2；AudioManager bus=Task 1；SettingsManager=Task 2；計程車落點 pending_arrival=Task 4；MenuShell 5 頁=Task 7；測試=各 Task + Task 8。全覆蓋。
- **型別一致：** `set_bus_volume_linear/get_bus_volume_linear`、`pending_arrival`(Dictionary {area,x})、`_pay_mrt/_pay_taxi`(回 bool)、`_start_job_time`、`JOBS`、`SettingsManager.get_setting/set_setting/apply_all` 跨 Task 名稱一致。
- **無 placeholder：** 各步含完整程式碼與指令。
- **已知相依順序：** Task 1(bus)→Task 2(SettingsManager 需 bus)→Task 3(設定頁需 SettingsManager)；Task 4(落點)獨立；Task 5/6 需 Task 4 的 pending_arrival/既有 go_to_minigame；Task 7 需 5/6 頁面存在才接線並刪 FastTravelApp。建議照 Task 編號順序執行。
- **smoke 迴圈漸進：** Task 3 先只測 SettingsApp，Task 5/6 各自把 TravelApp/JobApp 加回迴圈，避免中途 load 不存在頁面而誤 FAIL。
