# 端湯改版（2D 俯視限時送湯）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans（或 subagent-driven-development）task-by-task。步驟用 `- [ ]`。
> （writing-plans skill 本次不可用，依其格式手寫。）

**Goal:** 把 `SoupCarry` 從「端湯上塔」改寫成 2D 俯視限時送味增湯：WASD 移動、晃動由加速/急停/急轉驅動、送桌結算收入、75 秒總結算。保留同 id `soup_carry`/`SoupCarry.tscn`/MinigameBase 整合。

**Architecture:** 重寫 `SoupCarry.gd`(extends MinigameBase)。純邏輯(晃動 step/結算 payout/總計)抽成可測函式先 TDD；再程式建場景(地圖 bg + 玩家 sprite + 資料驅動桌/障礙/濕滑 Area2D)、玩家移動(含緩步鍵+碰撞)、遊戲迴圈(指定桌/送達/計時)、HUD+總結算。

**Tech Stack:** Godot 4.5 GDScript、Node2D/Sprite2D/Area2D/CanvasLayer、MinigameBase。

**驗證慣例：** `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK <test.tscn>`；windowed 才看 render；grep 同時看 `TEST FAIL`+`SCRIPT ERROR`；新素材先 `--import`。**常數(下方)先給可玩起點、playtest 再調。**

---

### Task 1: 重寫 SoupCarry.gd 純邏輯核心 + 單元測

**Files:**
- Modify(整檔重寫): `src/screens/Minigames/SoupCarry.gd`
- Create: `test/TestSoupCarry.gd` / `.tscn`

- [ ] **Step 1: 整檔重寫 `SoupCarry.gd`（先只純邏輯 + 空 _ready，視覺/迴圈後續 Task 補）**

```gdscript
extends "res://src/screens/Minigames/MinigameBase.gd"
## 端湯改版：2D 俯視限時送味增湯。晃動由玩家加速/急停/急轉驅動(deadzone 平穩走安全)。
## 純邏輯(step_slosh/settle_payout/reset_bowl/build_summary)抽出可測；場景/迴圈見後續 Task。

# ── 可調常數(playtest 再調) ──
const GAME_TIME := 75.0
const MAX_SPEED := 320.0          # px/s
const ACCEL := 1700.0             # px/s^2
const STEADY_SPEED_MULT := 0.45   # 緩步鍵速度上限
const STEADY_SLOSH_MULT := 0.30   # 緩步鍵晃動衰減
const WET_SLOSH_MULT := 1.8       # 濕滑區晃動加成
const SLOSH_DEADZONE := 600.0     # 加速度低於此幾乎不晃
const SLOSH_FACTOR := 0.020
const SLOSH_DAMP := 3.2           # 衰減率(指數)
const SLOSH_MAX := 30.0
const SPILL_THRESHOLD := 12.0
const SPILL_RATE := 7.0
const BUMP_IMPULSE := 9.0
const COLLISION_PENALTY := 10

# ── 每碗狀態 ──
var soup_amount := 100.0
var soup_slosh := 0.0
var soup_velocity := 0.0
var collision_penalty := 0
# ── 全局結算 ──
var income := 0
var delivered_count := 0
var failed_count := 0
var total_spill := 0.0
var total_collision := 0
var total_bonus := 0
var low_streak := 0

func minigame_id() -> String:
	return "soup_carry"

## 推進晃動一幀。accel_mag=玩家本幀加速度大小；wet=在濕滑區；steady=按緩步鍵。
func step_slosh(delta: float, accel_mag: float, wet: bool, steady: bool) -> void:
	var factor := SLOSH_FACTOR * (WET_SLOSH_MULT if wet else 1.0) * (STEADY_SLOSH_MULT if steady else 1.0)
	if accel_mag > SLOSH_DEADZONE:
		soup_velocity += (accel_mag - SLOSH_DEADZONE) * factor * delta
	soup_velocity *= exp(-SLOSH_DAMP * delta)
	soup_slosh += soup_velocity
	soup_slosh = clampf(soup_slosh, -SLOSH_MAX, SLOSH_MAX)
	if absf(soup_slosh) > SPILL_THRESHOLD:
		var spill := (absf(soup_slosh) - SPILL_THRESHOLD) * SPILL_RATE * delta
		soup_amount = maxf(soup_amount - spill, 0.0)

## 撞到桌/障礙/牆：晃一下 + 扣款。
func bump() -> void:
	soup_velocity += BUMP_IMPULSE * (1.0 if soup_velocity >= 0.0 else -1.0)
	collision_penalty += COLLISION_PENALTY

## 送達結算當前碗，回傳本碗 payout(int)，並累計總計。
func settle_payout() -> int:
	var spill_percent := 100.0 - soup_amount
	var base := 100.0
	var penalty := spill_percent
	var payout: float
	if spill_percent >= 70.0:
		payout = 0.0
		failed_count += 1
	elif spill_percent >= 40.0:
		payout = base * 0.5 - penalty
	else:
		payout = base - penalty
	var bonus := 0
	if spill_percent <= 5.0:
		bonus += 20
	if spill_percent < 10.0:
		low_streak += 1
		if low_streak % 3 == 0:
			bonus += 50
	else:
		low_streak = 0
	payout += bonus
	payout = maxf(payout - float(collision_penalty), 0.0)
	# 累計
	delivered_count += 1
	income += int(payout)
	total_spill += spill_percent
	total_collision += collision_penalty
	total_bonus += bonus
	return int(payout)

## 拿下一碗：重置每碗狀態。
func reset_bowl() -> void:
	soup_amount = 100.0
	soup_slosh = 0.0
	soup_velocity = 0.0
	collision_penalty = 0

## 評價文字(依淨收入)。
func rating_text() -> String:
	if income >= 700: return "神之端湯"
	elif income >= 500: return "穩如老僧"
	elif income >= 300: return "勉強上工"
	return "湯比業障還重"

## 結算 result(MinigameBase 契約)：gold=淨收入；win=能上工(>=300)；打工不給 merit。
func build_result() -> Dictionary:
	return make_result({"score": income, "win": income >= 300, "gold": income, "merit": 0})

func _ready() -> void:
	pass  # 場景/迴圈於 Task 2-4 補
```

- [ ] **Step 2: 建 `test/TestSoupCarry.gd`（驗純邏輯）**

```gdscript
extends Node
## 端湯純邏輯：晃動溢出、各灑出門檻 payout、完美/streak bonus、碰撞扣到 0。
const SC := preload("res://src/screens/Minigames/SoupCarry.gd")

func _ready() -> void:
	_test_slosh_spills()
	_test_payout_thresholds()
	_test_perfect_and_streak()
	_test_collision_floor()
	print("ALL PASS: SoupCarry 純邏輯")
	get_tree().quit(0)

func _new() -> Object:
	var s = SC.new(); return s

func _ck(cond: bool, msg: String) -> void:
	if not cond:
		push_error("TEST FAIL: %s" % msg); get_tree().quit(1)

func _test_slosh_spills() -> void:
	var s = _new()
	# 平穩(accel 在 deadzone 內)→幾乎不灑
	for i in 120: s.step_slosh(1.0/60.0, 300.0, false, false)
	_ck(s.soup_amount > 99.0, "平穩移動不該灑(got %.1f)" % s.soup_amount)
	# 猛操作(大加速度)→會灑
	var s2 = _new()
	for i in 120: s2.step_slosh(1.0/60.0, 6000.0, false, false)
	_ck(s2.soup_amount < 95.0, "猛操作該灑(got %.1f)" % s2.soup_amount)
	# 緩步鍵→比不按少灑
	var s3 = _new()
	for i in 120: s3.step_slosh(1.0/60.0, 6000.0, false, true)
	_ck(s3.soup_amount > s2.soup_amount, "緩步該比一般少灑")

func _test_payout_thresholds() -> void:
	# <40%: base - spill
	var a = _new(); a.soup_amount = 80.0  # spill 20
	_ck(a.settle_payout() == 80, "spill20 應 80(got %d)" % a.income)
	# 40-70%: base*0.5 - spill
	var b = _new(); b.soup_amount = 50.0  # spill 50
	_ck(b.settle_payout() == 0, "spill50 應 max(50-50,0)=0")  # 100*0.5-50=0
	var b2 = _new(); b2.soup_amount = 55.0  # spill 45 → 50-45=5
	_ck(b2.settle_payout() == 5, "spill45 應 5")
	# >=70%: 作廢
	var c = _new(); c.soup_amount = 20.0  # spill 80
	_ck(c.settle_payout() == 0 and c.failed_count == 1, "spill80 應作廢")

func _test_perfect_and_streak() -> void:
	var s = _new()
	# spill 3% → base-3 +20(完美) = 117；streak 第1碗
	s.soup_amount = 97.0
	_ck(s.settle_payout() == 117, "spill3 完美應 117(got %d)" % s.income)
	# 連續到第3碗 spill<10 → +50
	s.reset_bowl(); s.soup_amount = 95.0; s.settle_payout()  # 2nd
	s.reset_bowl(); s.soup_amount = 95.0
	var p3 = s.settle_payout()  # 3rd → base-5=95 +50 streak = 145
	_ck(p3 == 145, "第3碗連續低灑應 +50(got %d)" % p3)

func _test_collision_floor() -> void:
	var s = _new(); s.soup_amount = 90.0  # spill10 → base-10=90
	s.collision_penalty = 200
	_ck(s.settle_payout() == 0, "碰撞扣到 0 不負")
```

- [ ] **Step 3: 建 `test/TestSoupCarry.tscn`**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test/TestSoupCarry.gd" id="1"]
[node name="TestSoupCarry" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: 跑**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/TestSoupCarry.tscn 2>&1 | grep -aiE "ALL PASS|TEST FAIL|SCRIPT ERROR"`
Expected: `ALL PASS: SoupCarry 純邏輯`，無 FAIL/SCRIPT ERROR。
（若門檻數字對不上：依實際公式微調測試期望值或常數；payout 取 int 注意 floor。）

- [ ] **Step 5: Commit**（待使用者指示）

---

### Task 2: 場景建構 + 玩家移動(WASD/加速/緩步/碰撞)

**Files:** Modify `src/screens/Minigames/SoupCarry.gd`（加場景+移動）

- [ ] **Step 1: 場景常數 + 佈局資料**（在 SoupCarry.gd 加）

地圖 fit 1920×1080；出餐口/桌/障礙/濕滑用相對地圖的座標(對齊 Codex 圖、playtest 微調)：
```gdscript
const MAP_PATH := "res://assets/art_direction/new_ink_shrine_style/minigames/minigame_sushi_shop_topdown_map_concept.png"
const PLAYER_TEX := "res://assets/art_direction/new_ink_shrine_style/minigames/minigame_wujie_topdown_carry_soup_game_ready.png"
const PICKUP_POS := Vector2(300, 250)              # 出餐口(吧台旁)
const TABLES := [Vector2(700,400),Vector2(1200,380),Vector2(1500,650),Vector2(900,750),Vector2(1350,900),Vector2(550,820)]
const OBSTACLES := [  # 靜態障礙 {pos, size}
	{"pos": Vector2(960,540), "size": Vector2(180,80)},  # 吧台角/中島
]
const WET_ZONES := [Vector2(800,600)]              # 濕滑區中心(半徑 WET_R)
const WET_R := 110.0
const TABLE_R := 70.0      # 送達/碰撞半徑
const PLAYER_R := 34.0
```

- [ ] **Step 2: `_build_scene()`（背景 + 玩家 + 桌/障礙視覺）**

```gdscript
var _player: Sprite2D
var _vel := Vector2.ZERO
var _prev_vel := Vector2.ZERO
var _accel_mag := 0.0

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.centered = false
	if ResourceLoader.exists(MAP_PATH):
		bg.texture = load(MAP_PATH)
		var sz: Vector2 = bg.texture.get_size()
		bg.scale = Vector2(1920.0/sz.x, 1080.0/sz.y)
	add_child(bg)
	# 桌(半透明圈標互動範圍，第一版 placeholder)
	for t in TABLES:
		var m := _ring(t, TABLE_R, Color(0.8,0.7,0.4,0.25)); add_child(m)
	for o in OBSTACLES:
		var r := ColorRect.new(); r.size = o.size; r.position = o.pos - o.size*0.5
		r.color = Color(0.3,0.2,0.18,0.0); add_child(r)  # 透明(地圖已畫)，只作碰撞參考
	for w in WET_ZONES:
		add_child(_ring(w, WET_R, Color(0.4,0.6,0.9,0.18)))
	_player = Sprite2D.new()
	if ResourceLoader.exists(PLAYER_TEX):
		_player.texture = load(PLAYER_TEX)
		_player.scale = Vector2(0.12,0.12)  # 1254px→~150px
	_player.position = PICKUP_POS
	add_child(_player)

func _ring(c: Vector2, r: float, col: Color) -> Node2D:
	var n := Node2D.new(); n.position = c
	# 用 Polygon2D 近似圓(16 邊)做半透明標記
	var pts := PackedVector2Array()
	for i in 16: pts.append(Vector2(r,0).rotated(TAU*i/16.0))
	var p := Polygon2D.new(); p.polygon = pts; p.color = col; n.add_child(p)
	return n
```

- [ ] **Step 3: 玩家移動 + 加速度計算 + 緩步 + 碰撞**（_process 前半，後半 Task 3 接迴圈）

```gdscript
func _move_player(delta: float) -> void:
	var dir := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	var steady := Input.is_key_pressed(KEY_SHIFT)
	var top := MAX_SPEED * (STEADY_SPEED_MULT if steady else 1.0)
	_prev_vel = _vel
	_vel = _vel.move_toward(dir * top, ACCEL * delta)
	_accel_mag = (_vel - _prev_vel).length() / maxf(delta, 0.0001)
	var next := _player.position + _vel * delta
	# 牆界
	if next.x < PLAYER_R or next.x > 1920-PLAYER_R or next.y < PLAYER_R or next.y > 1080-PLAYER_R:
		bump(); _vel = _vel * -0.3
		next = _player.position
	# 障礙/桌 碰撞(圓-矩/圓-圓近似)
	for o in OBSTACLES:
		if Rect2(o.pos - o.size*0.5 - Vector2(PLAYER_R,PLAYER_R), o.size + Vector2(PLAYER_R,PLAYER_R)*2).has_point(next):
			bump(); _vel *= -0.3; next = _player.position; break
	_player.position = next
	if absf(_vel.x) > 5.0:
		_player.flip_h = _vel.x < 0.0
	var wet := false
	for w in WET_ZONES:
		if _player.position.distance_to(w) < WET_R: wet = true; break
	step_slosh(delta, _accel_mag, wet, steady)
```
（碰撞冷卻：bump 後加個 0.3s timer 避免每幀狂扣——`_bump_cd` 變數，<=0 才 bump。）

- [ ] **Step 4: headless parse 健檢**

Run: `./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK --import 2>&1 | grep -aiE "SCRIPT ERROR|Parse Error"`（無輸出）
- [ ] **Step 5: Commit**（待指示）

---

### Task 3: 遊戲迴圈(指定桌/送達/計時/結束)

**Files:** Modify `SoupCarry.gd`

- [ ] **Step 1: 迴圈狀態 + 指定目標桌**

```gdscript
var _running := false
var _time_left := GAME_TIME
var _target_idx := -1
var _carrying := true   # true=手上有碗往目標；送達後回出餐口拿下一碗
var _bump_cd := 0.0

func _start_game() -> void:
	_running = true
	_time_left = GAME_TIME
	reset_bowl()
	_assign_target()

func _assign_target() -> void:
	_target_idx = randi() % TABLES.size()
	_carrying = true
```

- [ ] **Step 2: `_process` 主迴圈**

```gdscript
func _process(delta: float) -> void:
	if not _running:
		return
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game(); return
	_move_player(delta)
	# 送達判定：carrying 且進入目標桌範圍
	if _carrying and _target_idx >= 0:
		if _player.position.distance_to(TABLES[_target_idx]) < TABLE_R:
			var pay := settle_payout()
			AudioManager.play_sfx("gold_collect" if pay > 0 else "wooden_fish_tap")
			_show_toast("+%d" % pay)
			_carrying = false
			reset_bowl()
			_assign_target()   # 直接指下一桌(回出餐口拿碗=回到附近即可,簡化:立即拿下一碗)
	_update_hud()
```
（`bump()` 在 _move_player 內呼叫時改成 `if _bump_cd<=0: bump(); _bump_cd=0.3`。）

- [ ] **Step 3: `_end_game` → 總結算 → finish**

```gdscript
func _end_game() -> void:
	_running = false
	_show_summary()        # Task 4
	# 玩家看完按鍵/計時後 finish
```
（summary 顯示後，等 2.5s 或按鍵 → `finish(build_result())`。）

- [ ] **Step 4: parse 健檢**（同 Task2 Step4）
- [ ] **Step 5: Commit**（待指示）

---

### Task 4: HUD + 晃動 meter + 目標標示 + 碗視覺 + 總結算畫面

**Files:** Modify `SoupCarry.gd`

- [ ] **Step 1: HUD(CanvasLayer)**：剩餘時間、目前收入、目標桌箭頭/高亮、這碗湯量、**晃動 meter(ColorRect 寬度+綠/黃/紅依 |soup_slosh|/SLOSH_MAX)**、streak。`_update_hud()` 每幀更新。
- [ ] **Step 2: 目標桌標示**：目標桌 ring 高亮(金色閃爍)+畫面邊緣箭頭指向(若桌在畫面內可省箭頭，全螢幕都看得到→只高亮 ring)。
- [ ] **Step 3: 碗晃動視覺**：玩家身上小碗 icon 或 `_player` 子 Sprite 依 `soup_slosh` 傾斜/偏移。
- [ ] **Step 4: 總結算畫面**：半透明蓋板 + 送達/作廢碗數、總灑出%(平均=total_spill/max(delivered,1))、碰撞扣款、bonus 合計、淨收入、`rating_text()`。等 2.5s 或任意鍵 → `finish(build_result())`。
- [ ] **Step 5: `_ready` 串起來**：`_build_scene(); _build_hud(); _start_game()`。
- [ ] **Step 6: windowed 截圖**

Run: 建 `test/CaptureSoupCarry.gd/.tscn`(load SoupCarry.tscn→add→等 60 frame→存 png)，windowed 跑 grep `_SAVED`，Read 圖：地圖+無戒+碗+HUD(時間/收入/目標高亮/晃動 meter) 都在、無 SHADER/SCRIPT ERROR。
- [ ] **Step 7: Commit**（待指示）

---

### Task 5: 整合 + 回歸

**Files:** Modify `src/ui/menu/pages/JobApp.gd`

- [ ] **Step 1: JobApp 描述更新**

把 `{"id": "soup_carry", "name": "端湯小弟", "desc": "把熱湯端上塔頂，別溢出來。"}` 的 desc 改成 `"限時把味增湯送上桌，灑越少賺越多。"`

- [ ] **Step 2: 回歸**

Run（逐一）：`TestSoupCarry`(ALL PASS)、`TestMenuSystem`(JobApp 改字後仍 ALL PASS)。
Run: 全專案 `--import` 無 SCRIPT ERROR。
（minigame 結束流程 `finish`→`SceneRouter.finish_minigame`→回地圖：沿用既有，gold 自動入袋。可手動或既有 minigame 流程測試覆蓋。）

- [ ] **Step 3: Commit**（待指示）

---

## 完工驗收
1. ✅ WASD 俯視移動、晃動由加速/急停/急轉驅動(平穩走安全、緩步鍵+濕滑區生效)。（T1-2）
2. ✅ 隨機指定桌、送達結算(你的公式)、75s 總結算+評價。（T1,3,4）
3. ✅ 淨收入→gold、JobApp 入口描述更新、回地圖流程沿用。（T3,5）
4. ✅ 純邏輯單元測 ALL PASS、windowed 截圖自檢、回歸 PASS。（T1,4,5）

## YAGNI / 範圍外
- 移動 NPC 顧客、真實流體、複雜動畫、多關卡難度曲線。
- 「回出餐口拿碗」第一版簡化成送達即自動拿下一碗(若要強制回吧台再加一個 pickup 判定)。
