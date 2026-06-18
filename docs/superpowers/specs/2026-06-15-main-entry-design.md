# 主線進入點設計（手機「任務」app ＋ AchievementSystem）

> 2026-06-15。承 [`PROJECT_STATUS.md`](../../../PROJECT_STATUS.md) 缺口 #7、第五節「ch1 收尾」。
> 關聯：[`2026-06-14-main-story-design.md`](2026-06-14-main-story-design.md)、[`2026-06-14-menu-system-design.md`](2026-06-14-menu-system-design.md)。

## 目標
讓主線可從遊戲內選單進入，並讓「十二因緣」成就會解鎖、會回饋給玩家。

## 範圍校正（讀碼後確認）
- **開場自動起 ch1 — 已完成**：`TitleScreen._on_start_pressed()` 已是 `GameManager.new_game()` → `MainQuestManager.continue_story()`，而 ch1 第一幕即開場過場。本案只驗證，不寫碼。
- 真正新增：**① 手機「任務」app　② AchievementSystem**。

## 關鍵前提（已驗證）
- `main_quests.json` 12 章的 `complete_flag` 與 `achievements.json` 12 個 `unlock_flag` **一字不差、章序一致**（ares_purified…ending_true）。
- `SaveManager` 整包存 `GameManager.player`（含 `flags`）。→ 成就狀態可純從旗標推導，自動隨存檔走，不需另存。

## 元件一：AchievementSystem（新 autoload）
- 檔：`src/systems/AchievementSystem.gd`；註冊於 `project.godot` autoload（排在 GameManager 之後）。
- 讀 `data/achievements.json`，依 `chapter` 排序。
- **狀態純推導**：`is_unlocked(id)` ⟺ `GameManager.get_flag(該成就 unlock_flag)` 為真。不另存。單一真相源。
- API：
  - `total() -> int`（=12）
  - `unlocked_count() -> int`
  - `is_unlocked(id) -> bool`
  - `get_all() -> Array`：依章序，每項 `{id, name, chapter, desc, unlock_flag, unlocked}`
- **解鎖偵測（給彈窗）**：`GameManager.set_flag` 新增 `signal flag_changed(key, value)`，**只在值真的變動時**發。AchievementSystem 監聽；當 key 命中某成就 `unlock_flag` 且 value 為真 → `EventBus.achievement_unlocked.emit(id)` ＋ `pending_toasts.append(id)`。
  - 變動守門天然去重：同值再 set 不重發 → 不會重複跳彈窗。
  - 讀檔（SaveManager 直接覆寫 dict，不經 set_flag）不觸發 → 不會把舊成就重跳一次。

## 元件二：手機「任務」app
- 檔：`src/ui/menu/pages/QuestsApp.gd`（Control 工廠，與 SkillsPage/StatusPage 同模式）。
- `MenuShell` 手機裝置：原單一 `入世` 空殼 → 改兩頁籤 **任務**(做實) ＋ **其他**(計程車/捷運/105/設定 佔位)。
- 任務 app 三區（暗金×黑佔位風，沿用既有 helper 樣式）：
  1. **主線**：目前章（標題／神祇／當前 stage 描述／進度 X/N）＋「繼續主線」按鈕。按下：先關選單解暫停（`MenuShell.close()`）再 `MainQuestManager.continue_story()`。全破→「主線已圓滿」。＝PROJECT_STATUS 要的正式入口（古廟 `main_quest` 動作保留為世界內備援）。
  2. **十二因緣**：12 列自 AchievementSystem（神祇名／已超渡·未超渡／章序）＝兼成就圖鑑，不另開經書頁。
  3. **支線**：唯讀列出 `active_quests`。

## 連動修改
- `EventBus.gd`：`signal achievement_unlocked(achievement_id: String)`。
- `MapScreen.gd`：`_ready` 補播 `AchievementSystem.pending_toasts`（離開地圖時解的成就回地圖才跳）＋連 live 訊號即時 `hud.show_toast(...)`。
- `StatusPage.gd`：`_achievement_count_text()` 改走 `AchievementSystem.unlocked_count()/total()`（去掉內聯重複計算，單一真相源）。

## 不做（YAGNI / 範圍外）
- 經書另開成就頁（成就已在任務 app）。
- 計程車／捷運／105 打工／設定 四 app（佔位）。
- 對話 UI 美化、ch2–12 內容、3D。

## 驗證
- headless `test/TestMainEntry.tscn`：
  - `total()==12`；清空 12 旗標後 `unlocked_count()==0`；`get_all()` 12 項依序、首項 ignorance/ch1。
  - `set_flag("ares_purified", true)` → `is_unlocked("ignorance")` 真、`unlocked_count()==1`、`achievement_unlocked` 發出 "ignorance"、`pending_toasts` 含之。
  - 再 set 同值 → 不重發（去重）。
  - 直接設 `hermes_purified` → `is_unlocked("formation")` 真（推導正確）。
  - QuestsApp / MenuShell(phone) 場景煙霧。
- 全專案 `--editor --quit` 無 parse error。
- ⚠ 實機 GPU 跑一次主線（協程串接時序）仍需手動，本案標註不涵蓋。

## 動到的檔案
新增：`src/systems/AchievementSystem.gd`、`src/ui/menu/pages/QuestsApp.gd`、`test/TestMainEntry.gd`＋`.tscn`。
修改：`src/autoloads/GameManager.gd`、`src/autoloads/EventBus.gd`、`src/ui/menu/MenuShell.gd`、`src/screens/MapScreen/MapScreen.gd`、`src/ui/menu/pages/StatusPage.gd`、`project.godot`。
純程式，不花 AI credits。
