# 了塵為師：技能「可學 → 習得」學習系統 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把技能解鎖從「條件達成就無聲自動會」改成「幫了人/練到位 → 回經書跟了塵習得才真正會」，並修掉 `c1_armory_gate` 的雙重假門檻（7 招誤標 initial 一次灌 + 支線送鬼招灌 gate）。

**Architecture:** `SkillUnlockManager` 把舊的單一 `unlocked` 拆成 `condition_met / learnable / learned` 三態；`check_unlocks()` 只自動學 `initial`，其餘條件達成只標「可學」並 toast；新 `learn_skill()` 給經書「習得」鈕、`grant_skill()`（含 skills.json 存在性防呆）給劇情直給（羅漢拳）與擋鬼招。羅漢拳改 `story` 類沿用既有 `skill:` signal——**完全不動任何 .dtl**。重構期以過渡相容鍵 `unlocked = condition_met or learned` 讓舊 `check_unlocks`/舊 `SkillsPage` 不中斷，最後一步移除。

**Tech Stack:** Godot 4.5 / GDScript；資料驅動 JSON（`data/skills.json`、`data/quests.json`）；autoload 系統（SkillUnlockManager / GameManager / EventBus / SceneRouter）；Dialogic 2 signal；自製 headless 測試場景（`test/TestMenuSystem.tscn`、`test/TestCh1Expansion.tscn`）。

**關聯 spec:** `MONK/docs/superpowers/specs/2026-06-17-skill-learning-system-design.md`

---

## 前置慣例（每個 task 都適用）

**專案不在 git 下。** 本計畫**不含 git commit 步驟**；每個 task 的「收尾」＝跑相關 headless 測試套件確認 `ALL PASS`。

**測試跑法（標準指令）：**

```powershell
# 選單系統（SkillUnlockManager / SkillsPage / 習得）
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestMenuSystem.tscn
# 第一章整合（gate / 湊 5 路徑 / 鬼招防呆）
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestCh1Expansion.tscn
```

判定：輸出含 `MENU_TEST: ALL PASS` ／ `CH1_EXPANSION_TEST: ALL PASS`。
（headless teardown 退碼非 0 屬引擎 bug，以印出的字串為準，不看 exit code。）

**編輯器 parse 檢查（腳本/JSON 改動後）：**

```powershell
& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" --editor --quit
```

判定：無 `SCRIPT ERROR` / `Parse Error` / JSON 解析錯誤。

---

## File Structure

| 檔案 | 動作 | 責任 |
|------|------|------|
| `src/systems/SkillUnlockManager.gd` | 修改 | 三態模型、`story` 類、5 表改、`learn_skill`/`learnable_skills`/`grant_skill`、`check_unlocks(announce)` 改邏輯、`_announced_learnable`。 |
| `src/autoloads/EventBus.gd` | 修改 | 新 `signal skill_learnable`。 |
| `src/autoloads/GameManager.gd` | 修改 | `skill:` signal 分支改走 `grant_skill`。 |
| `src/systems/QuestManager.gd` | 修改 | `unlock_skill` 改走 `grant_skill`。 |
| `src/autoloads/SceneRouter.gd` | 修改 | `unlock_skill` 改走 `grant_skill`。 |
| `data/quests.json` | 修改 | 移除 2 個鬼招 `unlock_skill`。 |
| `data/skills.json` | 修改 | 5 招 `unlock_condition` 文案同步。 |
| `src/ui/menu/pages/SkillsPage.gd` | 修改 | `✦可學` 狀態 + 「習得」鈕 + `_rows`/`_style_row`/`_on_learn`；移除 `unlocked` 依賴。 |
| `src/screens/MapScreen/MapHUD.gd` | 修改 | 接 `skill_learnable` toast。 |
| `test/TestMenuSystem.gd` | 修改 | `_test_unlock_states`/`_test_check_unlocks` 改寫 + 新 `_test_learn_skill`。 |
| `test/TestCh1Expansion.gd` | 修改 | 新 `_test_skill_learning`。 |

**不動：** 所有 `.dtl`（含 `main_ch1_intel.dtl` 的 `skill:arhat_strike`）、`data/main_quests.json`、`BattleManager`/`SkillExecutor`、`StatusPage`。

---

## Task 1: 狀態模型三態 + 5 表改 + skills.json 文案

`get_unlock_state` 回傳改為三態（含過渡相容 `unlocked`）；`UNLOCK_TABLE` 5 招改綁、新增 `story` 類；`skills.json` 同步 5 招條件文案。先把 `TestMenuSystem._test_unlock_states` 改寫成新模型（失敗），再實作。

**Files:**
- Modify: `src/systems/SkillUnlockManager.gd`（`UNLOCK_TABLE`、`get_unlock_state`、新增 `LEARNABLE_KINDS`）
- Modify: `data/skills.json`（5 招 `unlock_condition`）
- Test: `test/TestMenuSystem.gd`（`_test_unlock_states` 改寫）

- [ ] **Step 1: 改寫失敗測試 `_test_unlock_states`**

把 `test/TestMenuSystem.gd` 的 `_test_unlock_states()`（line 27-54）整段替換為新模型：

```gdscript
func _test_unlock_states() -> void:
	var sum := SkillUnlockManager
	# initial：開局已學
	var s := sum.get_unlock_state("basic_punch")
	_check(s.kind == "initial" and s.learned and s.condition_met, "basic_punch initial learned")
	# heat：恆 condition_met、不可學、不入池
	var h := sum.get_unlock_state("tathagata_palm")
	_check(h.kind == "heat" and h.condition_met and not h.learnable, "tathagata_palm heat not learnable")
	# story：羅漢拳未授予時 condition 不成立、不可學、未學
	GameManager.player.skills_unlocked.erase("arhat_strike")
	var st := sum.get_unlock_state("arhat_strike")
	_check(st.kind == "story" and not st.condition_met and not st.learnable and not st.learned,
		"arhat_strike story locked before grant")
	# behavior：5 招改綁之一（ascetic_temper：weakness_hit_count >= 10）
	GameManager.player.skills_unlocked.erase("ascetic_temper")
	GameManager.set_flag("weakness_hit_count", 5)
	var b := sum.get_unlock_state("ascetic_temper")
	_check(b.kind == "behavior" and b.target == 10 and b.current == 5
		and not b.condition_met and not b.learnable,
		"ascetic_temper 5/10 not met (got %d/%d met=%s)" % [b.current, b.target, b.condition_met])
	GameManager.set_flag("weakness_hit_count", 10)
	var b2 := sum.get_unlock_state("ascetic_temper")
	_check(b2.condition_met and b2.learnable and not b2.learned, "ascetic_temper met→learnable at 10")
	# 5 招改綁的 kind 正確
	_check(sum.get_unlock_state("sound_wave").kind == "quest", "sound_wave now quest")
	_check(sum.get_unlock_state("lions_roar").kind == "quest", "lions_roar now quest")
	var bb := sum.get_unlock_state("broken_bowl_beg")
	_check(bb.kind == "behavior" and bb.target == 6, "broken_bowl_beg behavior target 6")
	var sh := sum.get_unlock_state("self_harm")
	_check(sh.kind == "behavior" and sh.target == 5, "self_harm behavior target 5")
	# flag（vajra_glare：ah_ming_saved）
	GameManager.player.skills_unlocked.erase("vajra_glare")
	GameManager.player.flags.erase("ah_ming_saved")
	_check(not sum.get_unlock_state("vajra_glare").learnable, "vajra_glare not learnable w/o flag")
	GameManager.set_flag("ah_ming_saved", true)
	_check(sum.get_unlock_state("vajra_glare").learnable, "vajra_glare learnable w/ flag")
	# quest（great_compassion_shield：完成 zheng_ma）
	GameManager.player.skills_unlocked.erase("great_compassion_shield")
	_check(not sum.get_unlock_state("great_compassion_shield").learnable, "compassion not learnable w/o quest")
	if "zheng_ma" not in GameManager.player.completed_quests:
		GameManager.player.completed_quests.append("zheng_ma")
	_check(sum.get_unlock_state("great_compassion_shield").learnable, "compassion learnable w/ quest")
```

- [ ] **Step 2: 跑測試確認失敗**

Run（`TestMenuSystem.tscn`）。
Expected: 因舊 `get_unlock_state` 無 `learnable`/`condition_met` 鍵 → `Invalid get index 'condition_met'` 之類 `SCRIPT ERROR`，且 `arhat_strike`/`broken_bowl_beg` 等 kind 斷言不符；不會印 `MENU_TEST: ALL PASS`。

- [ ] **Step 3: 改 `SkillUnlockManager.gd` 表與 `get_unlock_state`**

3a. `UNLOCK_TABLE` 內 5 行改綁（其餘不動）：

```gdscript
	"arhat_strike":    {"kind": "story"},
	...
	"sound_wave":      {"kind": "quest", "quest": "ah_zhong"},
	...
	"broken_bowl_beg": {"kind": "behavior", "flag": "kill_count", "target": 6},
	"lions_roar":      {"kind": "quest", "quest": "lao_wang"},
	"self_harm":       {"kind": "behavior", "flag": "weakness_hit_count", "target": 5},
```

並更新 `UNLOCK_TABLE` 上方的 kind 註解，加一行：
```gdscript
##   story    — 劇情當場親授（羅漢拳，c1_intel signal 直給），不入習得。
```

3b. 在 `UNLOCK_TABLE` 之後新增常數：

```gdscript
const LEARNABLE_KINDS := ["flag", "quest", "behavior"]
```

3c. 整個 `get_unlock_state()`（line 50-75）替換為：

```gdscript
## 學習狀態（給技能頁）：{learned, learnable, condition_met, kind, label, current, target, unlocked}。
## learned＝已進 skills_unlocked（戰鬥能用、計入 gate）。
## condition_met＝解鎖條件達成（initial/heat 恆 true；story＝已被劇情授予）。
## learnable＝condition_met 且未學 且屬須習得類（flag/quest/behavior）。
## unlocked＝過渡相容鍵（＝condition_met or learned），SkillsPage 改寫後（Task 5）移除。
func get_unlock_state(skill_id: String) -> Dictionary:
	var e: Dictionary = UNLOCK_TABLE.get(skill_id, {"kind": "initial"})
	var kind: String = e.get("kind", "initial")
	var label: String = _skills.get(skill_id, {}).get("unlock_condition", "")
	var learned: bool = skill_id in GameManager.player.skills_unlocked
	var condition_met: bool = false
	var current: int = 0
	var target: int = 0
	match kind:
		"initial":
			condition_met = true
		"heat":
			condition_met = true
			if label == "":
				label = "滿值發動"
		"story":
			condition_met = learned
		"flag":
			condition_met = bool(GameManager.get_flag(e.flag))
		"quest":
			condition_met = e.quest in GameManager.player.completed_quests
		"behavior":
			target = int(e.target)
			current = int(GameManager.get_flag(e.flag, 0))
			condition_met = current >= target
	var learnable: bool = condition_met and not learned and kind in LEARNABLE_KINDS
	return {
		"learned": learned,
		"learnable": learnable,
		"condition_met": condition_met,
		"kind": kind,
		"label": label,
		"current": current,
		"target": target,
		"unlocked": condition_met or learned,
	}
```

3d. `data/skills.json` 同步 5 招 `unlock_condition`：

| skill_id | 新 `unlock_condition` |
|---|---|
| `arhat_strike` | `了塵親授（第一章劇情）` |
| `sound_wave` | `完成支線「師傅阿忠的最後一鍋」` |
| `lions_roar` | `完成支線「流浪漢老王的過去」` |
| `broken_bowl_beg` | `累計擊倒 6 名敵人` |
| `self_harm` | `弱點連擊累積 5 次` |

（4 招原文是 `"初始解鎖"`、arhat 原文 `"初始解鎖"`，逐一替換對應 entry 的 `unlock_condition` 字串。）

- [ ] **Step 4: 跑測試確認通過**

Run（`TestMenuSystem.tscn`）。
Expected: `_test_unlock_states` 全 PASS；`_test_job_mastery`（每職 6 非 heat，未受 kind 改動影響）、`_test_check_unlocks`（舊版仍靠過渡 `unlocked` 自動學）、`_smoke_scenes`（SkillsPage 靠過渡 `unlocked` 仍可 instantiate）回歸 PASS；結尾 `MENU_TEST: ALL PASS`。

- [ ] **Step 5: 跑編輯器 parse 檢查**

Run（parse 指令）。Expected: 無 `SCRIPT ERROR` / JSON 解析錯誤。

---

## Task 2: 習得方法 `learn_skill` / `learnable_skills` / `grant_skill`

新增三方法與 `_notify_learned`。先寫 `_test_learn_skill`（失敗），再實作。

**Files:**
- Modify: `src/systems/SkillUnlockManager.gd`（新增三方法 + `_notify_learned`）
- Test: `test/TestMenuSystem.gd`（新增 `_test_learn_skill`，並在 `_ready` 呼叫）

- [ ] **Step 1: 寫失敗測試 `_test_learn_skill`**

在 `test/TestMenuSystem.gd` 的 `_ready()`，於 `_test_check_unlocks()` 之後加一行呼叫：

```gdscript
	_test_check_unlocks()
	_test_learn_skill()
```

並新增函式（放在 `_test_check_unlocks` 之後）：

```gdscript
func _test_learn_skill() -> void:
	var sum := SkillUnlockManager
	# 準備：underdog（flag:david_listened）未學、條件未達
	GameManager.player.skills_unlocked.erase("underdog")
	GameManager.player.flags.erase("david_listened")
	# 條件未達 → 不可學、learn_skill 失敗
	_check(not sum.learn_skill("underdog"), "learn_skill fails when condition unmet")
	_check("underdog" not in GameManager.player.skills_unlocked, "underdog not learned when unmet")
	# 條件達成 → learnable，但尚未 learned
	GameManager.set_flag("david_listened", true)
	var st := sum.get_unlock_state("underdog")
	_check(st.learnable and not st.learned, "underdog learnable but not learned after condition")
	_check("underdog" in sum.learnable_skills(), "underdog in learnable_skills()")
	# 習得 → 成功、進池、不再可學
	_check(sum.learn_skill("underdog"), "learn_skill succeeds when learnable")
	var st2 := sum.get_unlock_state("underdog")
	_check(st2.learned and not st2.learnable, "underdog learned, no longer learnable")
	# 重複習得 → 失敗
	_check(not sum.learn_skill("underdog"), "learn_skill fails when already learned")
	# grant_skill 防呆：不存在的招不授予
	_check(not sum.grant_skill("brahma_resonance"), "grant_skill rejects non-existent skill")
	_check("brahma_resonance" not in GameManager.player.skills_unlocked, "junk skill not in pool")
	# grant_skill 授予真招（story）：羅漢拳直給
	GameManager.player.skills_unlocked.erase("arhat_strike")
	_check(sum.grant_skill("arhat_strike"), "grant_skill grants arhat_strike")
	_check("arhat_strike" in GameManager.player.skills_unlocked, "arhat_strike granted into pool")
```

- [ ] **Step 2: 跑測試確認失敗**

Run（`TestMenuSystem.tscn`）。
Expected: `Invalid call. Nonexistent function 'learn_skill'`（或 `learnable_skills`/`grant_skill`）`SCRIPT ERROR`；不印 `MENU_TEST: ALL PASS`。

- [ ] **Step 3: 在 `SkillUnlockManager.gd` 新增三方法 + `_notify_learned`**

於 `get_unlock_state()` 之後新增：

```gdscript
## 玩家在經書點「習得」：驗證可學 → 進 skills_unlocked。回傳是否成功。
func learn_skill(skill_id: String) -> bool:
	if skill_id in GameManager.player.skills_unlocked:
		return false
	if not get_unlock_state(skill_id).learnable:
		return false
	GameManager.player.skills_unlocked.append(skill_id)
	_notify_learned(skill_id)
	return true

## 目前可學（condition_met 且未學、屬須習得類）的招清單。
func learnable_skills() -> Array:
	var out: Array = []
	for skill_id in UNLOCK_TABLE:
		if get_unlock_state(skill_id).learnable:
			out.append(skill_id)
	return out

## 劇情/系統直接授予（了塵傳羅漢拳、未來劇情招）：進池 + 報「已學」toast。
## 防呆：skills.json 不存在的招不授予（擋鬼招灌 gate）。
func grant_skill(skill_id: String) -> bool:
	if not _skills.has(skill_id):
		push_warning("SkillUnlockManager: 嘗試授予不存在的技能 %s" % skill_id)
		return false
	if skill_id in GameManager.player.skills_unlocked:
		return false
	GameManager.player.skills_unlocked.append(skill_id)
	_notify_learned(skill_id)
	return true
```

於檔尾 `_notify_unlock()` 之後新增（暫與 `_notify_unlock` 並存，Task 3 移除舊者）：

```gdscript
func _notify_learned(skill_id: String) -> void:
	EventBus.skill_unlocked.emit(_skill_names.get(skill_id, skill_id))
```

- [ ] **Step 4: 跑測試確認通過**

Run（`TestMenuSystem.tscn`）。Expected: `_test_learn_skill` 全 PASS；其餘回歸 PASS；結尾 `MENU_TEST: ALL PASS`。

- [ ] **Step 5: 跑編輯器 parse 檢查**

Run（parse 指令）。Expected: 無 `SCRIPT ERROR`。

---

## Task 3: `check_unlocks` 改邏輯 + `skill_learnable` toast

`check_unlocks` 改成只自動學 initial、其餘只標可學並 toast；新增 EventBus 信號與 MapHUD 接收。先改寫 `_test_check_unlocks`（失敗），再實作。

**Files:**
- Modify: `src/autoloads/EventBus.gd`（新 signal）
- Modify: `src/systems/SkillUnlockManager.gd`（`check_unlocks`、`_announced_learnable`、`_notify_learnable`、`_ready`、移除 `_notify_unlock`）
- Modify: `src/screens/MapScreen/MapHUD.gd`（接 toast）
- Test: `test/TestMenuSystem.gd`（`_test_check_unlocks` 改寫）

- [ ] **Step 1: 改寫失敗測試 `_test_check_unlocks`**

把 `test/TestMenuSystem.gd` 的 `_test_check_unlocks()`（line 63-71）整段替換為：

```gdscript
func _test_check_unlocks() -> void:
	var sum := SkillUnlockManager
	# initial 會被自動學（erase 後 check_unlocks 補回）
	GameManager.player.skills_unlocked.erase("basic_punch")
	sum.check_unlocks(false)
	_check("basic_punch" in GameManager.player.skills_unlocked, "initial basic_punch auto-learned")
	# heat 不自動學
	_check("tathagata_palm" not in GameManager.player.skills_unlocked, "heat not auto-learned")
	# behavior 條件達成後 check_unlocks 不自動學，只標可學
	GameManager.player.skills_unlocked.erase("rolling_taunt")
	GameManager.set_flag("karma_skill_count", 10)
	sum.check_unlocks(false)
	_check("rolling_taunt" not in GameManager.player.skills_unlocked,
		"rolling_taunt NOT auto-learned (learnable only)")
	_check(sum.get_unlock_state("rolling_taunt").learnable, "rolling_taunt is learnable")
	# 習得後才入池
	_check(sum.learn_skill("rolling_taunt"), "learn rolling_taunt")
	_check("rolling_taunt" in GameManager.player.skills_unlocked, "rolling_taunt learned after learn_skill")
```

- [ ] **Step 2: 跑測試確認失敗**

Run（`TestMenuSystem.tscn`）。
Expected: 舊 `check_unlocks` 仍自動學 behavior → `FAIL: rolling_taunt NOT auto-learned (learnable only)`；結尾 `MENU_TEST: HAS FAILURES`。

- [ ] **Step 3: `EventBus.gd` 新增信號**

在 `signal skill_unlocked(skill_name: String)`（line 21）之後加：

```gdscript
signal skill_learnable(skill_name: String)
```

- [ ] **Step 4: 改 `SkillUnlockManager.gd` 的 `check_unlocks` / `_ready` / 通知**

4a. 在成員區（`var _skill_names ...` 之後）新增：

```gdscript
var _announced_learnable: Dictionary = {}   # 已 toast 過「可學」的 skill_id（runtime 去重）
```

4b. `_ready()` 內把 `check_unlocks()` 改為 `check_unlocks(false)`：

```gdscript
func _ready() -> void:
	_skills = JsonLoader.load_json("res://data/skills.json")
	for id in _skills:
		_skill_names[id] = _skills[id].get("name", id)
	check_unlocks(false)
```

4c. 整個 `check_unlocks()`（line 77-85）替換為：

```gdscript
## 掃表：initial 自動學；flag/quest/behavior 條件達成只標「可學」（不入池）並 toast；
## story/heat 跳過。announce=false（_ready/載入）只建立狀態不洗 toast。
func check_unlocks(announce: bool = true) -> void:
	for skill_id in UNLOCK_TABLE:
		var kind: String = UNLOCK_TABLE[skill_id].get("kind", "initial")
		if kind == "initial":
			if skill_id not in GameManager.player.skills_unlocked:
				GameManager.player.skills_unlocked.append(skill_id)
			continue
		if kind == "story" or kind == "heat":
			continue
		if skill_id in GameManager.player.skills_unlocked:
			continue
		if not get_unlock_state(skill_id).condition_met:
			continue
		# 條件達成、未學 → 可學。本輪新可學才 toast（去重）。
		if skill_id in _announced_learnable:
			continue
		_announced_learnable[skill_id] = true
		if announce:
			_notify_learnable(skill_id)
```

4d. 把檔尾 `_notify_unlock()` 整個函式替換為 `_notify_learnable()`（`_notify_learned` 已於 Task 2 新增）：

```gdscript
func _notify_learnable(skill_id: String) -> void:
	EventBus.skill_learnable.emit(_skill_names.get(skill_id, skill_id))
```

（確認檔內已無對 `_notify_unlock` 的呼叫——舊 `check_unlocks` 已被替換掉。）

- [ ] **Step 5: `MapHUD.gd` 接 toast**

在 `MapHUD._ready()` line 49 之後新增：

```gdscript
	EventBus.skill_learnable.connect(func(n): show_toast("可學新招：%s（去經書習得）" % n))
```

- [ ] **Step 6: 跑測試確認通過**

Run（`TestMenuSystem.tscn`）。
Expected: `_test_check_unlocks` 全 PASS（behavior 不再自動學、習得後才入池）；`_test_unlock_states`/`_test_learn_skill`/`_test_job_mastery`/`_smoke_scenes` 回歸 PASS；結尾 `MENU_TEST: ALL PASS`。

- [ ] **Step 7: 跑編輯器 parse 檢查**

Run（parse 指令）。Expected: 無 `SCRIPT ERROR`。

---

## Task 4: 鬼招防呆（統一走 `grant_skill`）+ 移除 quests.json 死欄位

`skill:` signal 與 `unlock_skill` 獎勵改走 `grant_skill`（存在性防呆）；移除 quests.json 兩個鬼招欄位。

**Files:**
- Modify: `src/autoloads/GameManager.gd`（`skill:` 分支）
- Modify: `src/systems/QuestManager.gd`（`unlock_skill`）
- Modify: `src/autoloads/SceneRouter.gd`（`unlock_skill`）
- Modify: `data/quests.json`（移除 2 鬼招）
- Test: `test/TestCh1Expansion.gd`（新增 1 段鬼招防呆斷言，併入 Task 6 的 `_test_skill_learning`；此 task 先加最小斷言）

- [ ] **Step 1: 寫失敗測試（鬼招防呆，暫置 TestCh1Expansion）**

在 `test/TestCh1Expansion.gd` 的 `_ready()`，於 `_test_opening_wakeup()` 之後加一行呼叫：

```gdscript
	_test_opening_wakeup()
	_test_skill_learning()
```

並新增（Task 6 會在同一函式續寫，先放鬼招段）：

```gdscript
func _test_skill_learning() -> void:
	# 鬼招防呆：完成 ah_ming（送 brahma_resonance）不該把不存在的招灌進池
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish"]
	SkillUnlockManager.grant_skill("brahma_resonance")
	_check("brahma_resonance" not in GameManager.player.skills_unlocked, "junk brahma_resonance not granted")
	SkillUnlockManager.grant_skill("wooden_fish_fury")
	_check("wooden_fish_fury" not in GameManager.player.skills_unlocked, "junk wooden_fish_fury not granted")
```

（`grant_skill` 已於 Task 2 存在，此段在 Task 4 開始時即應 PASS——本 task 真正的「失敗→通過」是資料/接線改動不破壞既有測試。先確認 quests.json 改動前後測試皆綠。）

- [ ] **Step 2: 跑測試確認現況**

Run（`TestCh1Expansion.tscn`）。Expected: 上述兩斷言 PASS（grant_skill 已防呆）；結尾 `CH1_EXPANSION_TEST: ALL PASS`。

- [ ] **Step 3: `GameManager.gd` `skill:` 分支改走 `grant_skill`**

`_on_dialogic_signal` 的 `"skill"` 分支（line 54-57）替換為：

```gdscript
		"skill":
			SkillUnlockManager.grant_skill(val)
```

- [ ] **Step 4: `QuestManager.gd` `unlock_skill` 改走 `grant_skill`**

`_advance_quest` 內（line 67-68）替換為：

```gdscript
		if s.has("unlock_skill"):
			SkillUnlockManager.grant_skill(s.unlock_skill)
```

- [ ] **Step 5: `SceneRouter.gd` `unlock_skill` 改走 `grant_skill`**

line 143-147 的區塊替換為：

```gdscript
	if reward.has("unlock_skill"):
		SkillUnlockManager.grant_skill(reward.unlock_skill)
```

（移除原本的 `if sk not in ...: append + check_unlocks`；`grant_skill` 已含「已學則略過」與存在性防呆。）

- [ ] **Step 6: `data/quests.json` 移除 2 鬼招欄位**

- `ah_ming` 第二 stage（line 17-20）：移除 `"unlock_skill": "brahma_resonance",`，保留 `"merit": 10` 與 `"flag": "ah_ming_saved"`。
- `jie` stage 的 `"win"`（line 79）：移除 `"unlock_skill": "wooden_fish_fury", `，保留 `"gold": 500` 與 `"flag": "jie_defeated"`。

確保移除後逗號正確、整檔仍是合法 JSON（無尾逗號）。

- [ ] **Step 7: 跑測試確認通過**

Run（`TestCh1Expansion.tscn` 與 `TestMenuSystem.tscn`）。
Expected: 兩套皆 `ALL PASS`；鬼招斷言維持綠；`_test_new_dialogues`（arhat signal）回歸綠（dtl 未動）。

- [ ] **Step 8: 跑編輯器 parse 檢查**

Run（parse 指令）。Expected: 無 `SCRIPT ERROR` / JSON 解析錯誤。

---

## Task 5: 經書技能頁加「習得」鈕 + 移除過渡 `unlocked`

`SkillsPage` 改用三態、加 `✦可學`/「習得」鈕；改寫後移除 `get_unlock_state` 的過渡相容 `unlocked`。

**Files:**
- Modify: `src/ui/menu/pages/SkillsPage.gd`（重寫列樣式與詳情、加習得鈕）
- Modify: `src/systems/SkillUnlockManager.gd`（移除 `unlocked` 鍵）
- Test: `test/TestMenuSystem.gd`（`_smoke_scenes` 既有；新增 SkillsPage 習得邏輯煙霧斷言）

- [ ] **Step 1: 寫煙霧斷言（SkillsPage 習得流程）**

在 `test/TestMenuSystem.gd` 的 `_smoke_scenes()` 內、instantiate `SkillsPage` 那段（line 144-155 的迴圈）**之後**，新增針對 SkillsPage 的功能煙霧（直接呼叫其 helper，不模擬點擊）：

```gdscript
	# SkillsPage 習得流程煙霧：可學招按「習得」後變已學
	var sp = load("res://src/ui/menu/pages/SkillsPage.gd").new()
	get_tree().root.add_child(sp)
	await get_tree().process_frame
	GameManager.player.skills_unlocked.erase("alms_wave")
	if "grandma" not in GameManager.player.completed_quests:
		GameManager.player.completed_quests.append("grandma")
	_check(SkillUnlockManager.get_unlock_state("alms_wave").learnable, "alms_wave learnable for page test")
	if sp.has_method("_on_learn"):
		sp._on_learn("alms_wave")
		await get_tree().process_frame
		_check("alms_wave" in GameManager.player.skills_unlocked, "SkillsPage _on_learn learns skill")
	sp.queue_free()
	await get_tree().process_frame
```

- [ ] **Step 2: 跑測試確認失敗**

Run（`TestMenuSystem.tscn`）。
Expected: `SkillsPage` 尚無 `_on_learn` → `_check(... has_method)` 不進分支，`alms_wave` 未被學 → 後續無斷言；但本意是驗證新方法存在。為使其真正失敗，斷言改寫成硬要求方法存在：在 Step 1 的 `if sp.has_method(...)` 之前加 `_check(sp.has_method("_on_learn"), "SkillsPage has _on_learn")`。此刻應 `FAIL: SkillsPage has _on_learn`。

- [ ] **Step 3: 重寫 `SkillsPage.gd`**

整檔替換為（保留既有 `_add_label`/`_add_progress`/`_type_text`/`_cost_text`/`_hsep`，新增 `_rows`/`_style_row`/`_select`/`_on_learn`、改 `_skill_row`/`_show_detail`）：

```gdscript
extends Control
## 經書·技能頁：三職分組列出技能，顯示學習狀態（🔒未達 / ✦可學 / ✓已學），
## 可學的招提供「習得」鈕。真相源＝SkillUnlockManager.get_unlock_state()。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const LOCKED := Color(0.45, 0.43, 0.4)
const LEARNABLE := Color(0.55, 0.78, 0.95)   # 可學＝冷亮藍
const LEARNED := Color(0.55, 0.82, 0.55)     # 已學＝綠

const JOB_ORDER := ["ascetic", "chanter", "beggar"]
const JOB_NAMES := {"ascetic": "苦行僧", "chanter": "念經僧", "beggar": "化緣僧"}

var _skills: Dictionary = {}
var _detail_box: VBoxContainer
var _rows: Dictionary = {}        # skill_id -> Button
var _selected: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_skills = JsonLoader.load_json("res://data/skills.json")
	_build()

func _build() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 24)
	add_child(hb)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for job in JOB_ORDER:
		var header := Label.new()
		header.text = "— %s —" % JOB_NAMES[job]
		header.add_theme_color_override("font_color", GOLD)
		header.add_theme_font_size_override("font_size", 26)
		list.add_child(header)
		for skill_id in _skills:
			if _skills[skill_id].get("job", "") != job:
				continue
			list.add_child(_skill_row(skill_id))

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(detail_panel)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(_detail_box)
	_show_detail("")

func _skill_row(skill_id: String) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color_hover", GOLD)
	var sid: String = skill_id
	btn.pressed.connect(func() -> void: _select(sid))
	_rows[skill_id] = btn
	_style_row(skill_id)
	return btn

func _style_row(skill_id: String) -> void:
	var btn: Button = _rows[skill_id]
	var st: Dictionary = SkillUnlockManager.get_unlock_state(skill_id)
	var data: Dictionary = _skills[skill_id]
	var prefix := ""
	var col := WARM
	if st.kind == "heat":
		prefix = "【處決】"; col = GOLD
	elif st.learned:
		prefix = "✓ "; col = WARM
	elif st.learnable:
		prefix = "✦ "; col = LEARNABLE
	else:
		prefix = "🔒 "; col = LOCKED
	var suffix := ""
	if st.kind == "behavior" and not st.condition_met:
		suffix = "  (%d/%d)" % [st.current, st.target]
	btn.text = "%s%s%s" % [prefix, data.get("name", skill_id), suffix]
	btn.add_theme_color_override("font_color", col)

func _select(skill_id: String) -> void:
	_selected = skill_id
	_show_detail(skill_id)

func _show_detail(skill_id: String) -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	if skill_id == "":
		var hint := Label.new()
		hint.text = "選擇左側技能以檢視詳情。"
		hint.add_theme_color_override("font_color", DIM)
		hint.add_theme_font_size_override("font_size", 22)
		_detail_box.add_child(hint)
		return
	var d: Dictionary = _skills[skill_id]
	var st: Dictionary = SkillUnlockManager.get_unlock_state(skill_id)
	_add_label(d.get("name", skill_id), 34, GOLD)
	_add_label("%s ｜ %s" % [JOB_NAMES.get(d.get("job", ""), ""), _type_text(d)], 20, DIM)
	_add_label("消耗：%s" % _cost_text(d.get("cost", {})), 20, WARM)
	var desc := _add_label(d.get("description", ""), 22, WARM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(700, 0)
	_detail_box.add_child(_hsep())
	if st.kind == "heat":
		_add_label("滿值處決技：戰鬥中達條件自動發動。", 20, GOLD)
	elif st.learned:
		_add_label("✓ 已學會", 22, LEARNED)
		if st.label != "" and st.label != "初始解鎖":
			_add_label("習得方式：%s" % st.label, 18, DIM)
	elif st.learnable:
		_add_label("✦ 可習得", 22, LEARNABLE)
		_add_label("條件已達成：%s" % st.label, 18, DIM)
		var learn_btn := Button.new()
		learn_btn.text = "習得"
		learn_btn.add_theme_font_size_override("font_size", 24)
		var sid: String = skill_id
		learn_btn.pressed.connect(func() -> void: _on_learn(sid))
		_detail_box.add_child(learn_btn)
	else:
		_add_label("🔒 未達", 22, LOCKED)
		_add_label("解鎖條件：%s" % st.label, 20, WARM)
		if st.kind == "behavior":
			_add_progress(st.current, st.target)

func _on_learn(skill_id: String) -> void:
	if SkillUnlockManager.learn_skill(skill_id):
		_style_row(skill_id)
		_show_detail(skill_id)

func _add_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_detail_box.add_child(l)
	return l

func _add_progress(current: int, target: int) -> void:
	var bar := ProgressBar.new()
	bar.max_value = target
	bar.value = current
	bar.custom_minimum_size = Vector2(400, 24)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	_detail_box.add_child(bar)
	_add_label("進度 %d / %d" % [current, target], 18, DIM)

func _type_text(d: Dictionary) -> String:
	var dt: String = d.get("damage_type", "")
	var map := {"physical": "物理", "karma": "業障", "merit": "功德",
		"support": "輔助", "passive": "被動"}
	return map.get(dt, dt)

func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "無"
	var parts: Array = []
	for k in cost:
		match k:
			"karma": parts.append("業障 %d" % int(cost[k]))
			"merit": parts.append("功德 %d" % int(cost[k]))
			"hp": parts.append("HP %d%%" % int(float(cost[k]) * 100))
			"gold_required": parts.append("持金 %d" % int(cost[k]))
			_: parts.append("%s %s" % [k, str(cost[k])])
	return "、".join(parts)

func _hsep() -> Control:
	var line := ColorRect.new()
	line.color = GOLD.darkened(0.5)
	line.custom_minimum_size = Vector2(0, 2)
	return line
```

- [ ] **Step 4: 移除 `get_unlock_state` 過渡 `unlocked` 鍵**

確認無其他消費者後移除。先 grep：

```powershell
Select-String -Path "D:\monk\MONK\src","D:\monk\MONK\test" -Pattern "\.unlocked" -Recurse
```

Expected: 僅命中已改寫的測試/無命中（`StatusPage` 用 `get_job_mastery`，不讀 `get_unlock_state`）。確認後，在 `SkillUnlockManager.get_unlock_state` 回傳 dict 移除 `"unlocked": condition_met or learned,` 該行，並把 doc 註解末行「unlocked＝過渡相容鍵…」刪除。

- [ ] **Step 5: 跑測試確認通過**

Run（`TestMenuSystem.tscn`）。
Expected: SkillsPage 煙霧（`_on_learn` 存在、習得後入池）PASS；`_smoke_scenes` instantiate 不崩；全套 `MENU_TEST: ALL PASS`。

- [ ] **Step 6: 跑編輯器 parse 檢查**

Run（parse 指令）。Expected: 無 `SCRIPT ERROR`。

---

## Task 6: TestCh1Expansion 整合測試（gate / 湊 5 / 無 softlock）

把 ch1 門檻流走一遍：開局 2 → 了塵授羅漢拳 3 → 保底湊 5 → gate 開；驗證純刷無 softlock。續寫 Task 4 起的 `_test_skill_learning`。

**Files:**
- Test: `test/TestCh1Expansion.gd`（`_test_skill_learning` 續寫）

- [ ] **Step 1: 續寫 `_test_skill_learning`（gate 流程）**

在 `_test_skill_learning()`（Task 4 已建立、含鬼招段）末尾續加：

```gdscript
	# ch1 門檻流：開局 2 招
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish"]
	GameManager.player.completed_quests = []
	GameManager.player.flags.erase("kill_count")
	GameManager.player.flags.erase("weakness_hit_count")
	SkillUnlockManager._announced_learnable.clear()
	var gate := {"type": "skills", "min": 5}
	_check(not MainQuestManager.gate_passed(gate), "gate blocked at 2 skills")
	# 了塵 c1_intel 親授羅漢拳（story 直給）→ 3 招
	SkillUnlockManager.grant_skill("arhat_strike")
	_check(GameManager.player.skills_unlocked.size() == 3, "3 skills after arhat granted")
	_check(not MainQuestManager.gate_passed(gate), "gate still blocked at 3")
	# 保底純刷：打 6 場 + 弱點 5 次 → 破碗乞討 / 苦肉計「可學」（不自動學）
	GameManager.set_flag("kill_count", 6)
	GameManager.set_flag("weakness_hit_count", 5)
	SkillUnlockManager.check_unlocks(false)
	_check("broken_bowl_beg" not in GameManager.player.skills_unlocked, "broken_bowl_beg not auto-learned")
	_check(SkillUnlockManager.get_unlock_state("broken_bowl_beg").learnable, "broken_bowl_beg learnable via grind")
	_check(SkillUnlockManager.get_unlock_state("self_harm").learnable, "self_harm learnable via grind")
	_check(not MainQuestManager.gate_passed(gate), "gate still blocked before learning (learnable≠learned)")
	# 去經書習得兩招 → 5 招 → gate 開（純刷即可，無 softlock）
	_check(SkillUnlockManager.learn_skill("broken_bowl_beg"), "learn broken_bowl_beg")
	_check(SkillUnlockManager.learn_skill("self_harm"), "learn self_harm")
	_check(GameManager.player.skills_unlocked.size() == 5, "5 skills after learning 2")
	_check(MainQuestManager.gate_passed(gate), "gate passes at 5 (grind-only path, no softlock)")
```

- [ ] **Step 2: 跑測試確認**

Run（`TestCh1Expansion.tscn`）。
Expected: 全段 PASS（gate 在 2/3/learnable 階段擋住、學滿 5 放行）；`_test_gate_logic`、`_test_new_dialogues`、`_test_god_intel`、opening wakeup 等既有斷言回歸；結尾 `CH1_EXPANSION_TEST: ALL PASS`。

- [ ] **Step 3: 跑全套回歸**

Run（`TestMenuSystem.tscn` 與 `TestCh1Expansion.tscn`）。Expected: 兩套皆 `ALL PASS`。

- [ ] **Step 4: 跑編輯器 parse 檢查**

Run（parse 指令）。Expected: 無 `SCRIPT ERROR` / JSON 解析錯誤。

---

## Task 7: 同步文件/記憶 + 實機抽驗

依 [[feedback-sync-docs-memory]] 同步文件與記憶，並人工抽驗習得體驗。

**Files:**
- Modify: `MONK/docs/PROJECT_STATUS`（或等效進度文件）
- Update: 記憶 `project_build_status.md`、`project_skill_learning_system.md`
- （選）標註 `monk_go_rogue_GDD_v5.md` §八·五 舊 lambda 解鎖表

- [ ] **Step 1: 同步進度文件**

- `PROJECT_STATUS`：標記「了塵為師·技能習得系統已實作；c1_armory_gate 真門檻生效」。
- 把 GDD v5 §八·五 的舊 lambda `SKILL_UNLOCKS` 旁標一行「（已被 `SkillUnlockManager.UNLOCK_TABLE` 資料驅動取代；新增 learn/grant 習得制，見 spec 2026-06-17）」，避免文件誤導。

- [ ] **Step 2: 更新記憶**

- `project_skill_learning_system.md`：狀態由「設計待實作」→「已實作並驗證」；補實作落點（`learn_skill`/`grant_skill`/`story` 類/`skill_learnable` signal）與雷點（過渡 `unlocked` 已移除、戰鬥中可學無 toast、舊存檔不遷移、grant_skill 存在性防呆擋鬼招）。
- `project_build_status.md`：技能系統缺口勾掉；註明「dtl 零改、孤招 brahma_resonance/wooden_fish_fury 已自 quests.json 移除」。

- [ ] **Step 3: 實機 GPU 人工抽驗（GUI 啟動，非 headless）**

新遊戲跑 ch1，目視確認：
- [ ] 開局技能頁＝拳/木魚 ✓已學、羅漢拳 🔒（標「了塵親授」）、其餘 🔒/✦。
- [ ] 跑完 c1_intel（了塵授拳）→ 羅漢拳變 ✓已學、HUD 出「新技能解鎖：羅漢伏虎」toast。
- [ ] 完成一條支線（如鄭媽）/打幾場 → HUD 出「可學新招：…（去經書習得）」toast；經書該招顯 ✦可學＋「習得」鈕。
- [ ] 點「習得」→ 招變 ✓已學會、可在戰鬥技能列選用。
- [ ] 湊滿 5 招前，主線 gate 仍擋（播 fail 對話回地圖）；湊滿後放行。
- [ ] behavior 招（破碗乞討/苦肉計）達標顯 ✦可學（非自動會），符合「都跟了塵學」。

- [ ] **Step 4: 收尾確認**

Run（兩套測試 + parse）。Expected: 全 `ALL PASS`、無 parse error。記錄實機抽驗結果於記憶/PROJECT_STATUS。

---

## Self-Review

**1. Spec coverage**（逐節核對）：
- §架構1 三態 `get_unlock_state` → Task 1。✓
- §架構2 5 表改 + `story` 類 → Task 1。✓
- §架構3 `learn_skill`/`learnable_skills`/`grant_skill` → Task 2。✓
- §架構4 `check_unlocks(announce)` 改邏輯 + `_announced_learnable` + `_ready(false)` → Task 3。✓
- §架構5 統一入口（GameManager skill: / QuestManager / SceneRouter / quests.json 移鬼招）→ Task 4。✓
- §架構6 SkillsPage 習得鈕 → Task 5。✓
- §架構7 EventBus `skill_learnable` + MapHUD toast → Task 3。✓
- §測試（TestMenuSystem 三函式、TestCh1Expansion 整合）→ Task 1/2/3/4/6。✓
- §skills.json 文案 → Task 1 Step 3d。✓
- §風險（過渡鍵移除、舊存檔、戰鬥中無 toast）→ Task 5 Step 4 移除 + 文件/記憶（Task 7）。✓
- §備註（GDD 標註、記憶同步）→ Task 7。✓

**2. Placeholder scan:** 無 TBD/TODO；所有 code step 含完整程式碼與確切指令、預期輸出。Task 7 實機抽驗為人工收尾（非程式佔位），已列清單。✓

**3. Type consistency:**
- `get_unlock_state` 回傳鍵 `learned/learnable/condition_met/kind/label/current/target`（Task 1 定義）在 `learn_skill`/`learnable_skills`（Task 2）、`check_unlocks`（Task 3）、`SkillsPage`（Task 5）、測試（Task 1/3/6）一致引用。過渡 `unlocked` 僅 Task 1 加、Task 5 移除（grep 驗證）。✓
- 方法名 `learn_skill`/`learnable_skills`/`grant_skill`（Task 2）在 SkillsPage `_on_learn`（Task 5）、GameManager/QuestManager/SceneRouter（Task 4）、測試（Task 2/4/6）一致。✓
- `EventBus.skill_learnable`（Task 3 定義）由 `_notify_learnable`（Task 3）emit、`MapHUD`（Task 3）connect。✓
- `_notify_learned`（Task 2）/`_notify_learnable`（Task 3）並存；舊 `_notify_unlock` 於 Task 3 移除且確認無呼叫。✓
- `_announced_learnable`（Task 3 成員）於 `check_unlocks`（Task 3）讀寫、測試（Task 6）`.clear()`。✓
- 測試函式 `_test_skill_learning`（Task 4 建立、Task 6 續寫）在同一函式累加，`_ready` 只呼叫一次。✓
