# 選單系統設計 spec — 手機（入世）× 經書（出世）

日期：2026-06-14
關聯：[[project-monk-game]]、[[project-build-status]]、[[project-art-direction]]

## 願景
和尚無戒活在兩個世界，選單分成兩個「裝置殼」反映這個對立：
- **手機 · 入世**：現代台北的都市生活 app（任務／計程車／捷運／105 打工／設定）。
- **經書 · 出世**：隨身的修行之書，經書材質（技能／狀態／成就）。

## 範圍切分（本 spec 只涵蓋「這輪」）
使用者定的開工順序＝**先地基＋經書（成長優先）**。

| 階段 | 內容 | 本 spec |
|------|------|---------|
| **這輪** | 選單外殼框架 `MenuShell` ＋ 經書·技能頁 ＋ 經書·狀態頁 | ✅ 詳設計 |
| 階段2 | 手機 app：任務 log／計程車＋捷運移動／105 打工接小遊戲／設定 | 概述（下一輪 spec） |
| 階段3 | AchievementSystem ＋ 經書·成就圖鑑 | 概述 |
| 並行 | 主線劇情設計 → main_quests.json | 阻塞：大綱待定位 |

## 這輪詳細設計

### A. 選單外殼 MenuShell
- 檔案：`src/ui/menu/MenuShell.tscn` + `MenuShell.gd`（CanvasLayer，`process_mode = ALWAYS`）。
- 開啟：新增輸入動作 `open_menu`（鍵盤 `M` ＋手把 Start/button_index 6）。**只在 MapScreen 探索中、且無對話進行時可開**（避免和 Dialogic/戰鬥衝突）。開啟時 `get_tree().paused = true`，關閉時還原。
- 結構：頂部「裝置切換列」（手機 ｜ 經書）；中央內容區 `DeviceContainer` 依選定裝置載入對應頁面；底部操作提示列。
- 裝置介面 `MenuDevice`（共用契約）：每個裝置是一個 `Control`，提供 `func get_pages() -> Array[Dictionary]`（[{id,title,icon,scene}]）。MenuShell 負責頁籤與導航，不管頁面內部。
- 導航：滑鼠點擊；鍵盤 `confirm`/`cancel`/方向（沿用既有 input map，`cancel` 關選單）。
- 本輪：**經書裝置做實，手機裝置只放空殼佔位頁**（顯示「入世功能建置中」），讓切換與框架可驗證、phase 2 直接掛 app。

### B. 經書 · 技能頁 SkillsPage
- 檔案：`src/ui/menu/pages/SkillsPage.tscn` + `.gd`。
- 資料：讀 `skills.json`，依 `job`（ascetic 苦行／chanter 念經／beggar 化緣）分三組。
- 版面：左＝三職分頁/分欄的技能清單（已解鎖正常色、未解鎖暗灰加鎖）；右＝選定技能的詳情（名稱／說明／消耗 cost／傷害類型／特殊效果／解鎖條件文字＋**解鎖進度**）。
- **解鎖進度（重點，修現有缺口）**：目前 `SkillUnlockManager._conditions` 是不透明 lambda，UI 無法顯示「還差幾次」。本輪**把條件改成資料驅動**：新增 `SkillUnlockManager.get_unlock_state(skill_id) -> {unlocked: bool, kind: String, label: String, current: int, target: int}`，由同一份條件表同時推導「是否解鎖」與「進度」（單一真相源，取代散落 lambda）。kind ∈ initial/behavior/quest/achievement/vow。behavior 類（如 weakness_hit_count≥10、kill_count≥20、karma_skill_count≥10）回傳 current/target；quest/achievement/vow 回傳對應 label 與 達成布林。`check_unlocks()` 改讀同表，行為等價。
- 互動：解鎖技能僅供檢視（這遊戲技能綁行為自動解鎖、戰鬥內選用，**不在此配置/裝備**）。YAGNI：不做技能裝備槽。

### C. 經書 · 狀態頁 StatusPage（結構已使用者拍板）
- 檔案：`src/ui/menu/pages/StatusPage.tscn` + `.gd`。
- **三角雷達 = 三職修為**：每職 mastery = 該職已解鎖技能數 ÷ 該職總技能數（讀 skills.json 的 job 統計 player.skills_unlocked）。三軸：苦行/念經/化緣。程式繪製 Polygon2D/SVG 式三角。
- **業障 ↔ 功德 拔河條**：單條水平，業障（karma 0-100）由左、功德（merit 0-100）由右，比例填色。
- **數值卡**：HP current/max、金幣、技能 X/21、成就 X/12。
- 成就 X/12：AchievementSystem 尚未實作（階段3），本輪先顯示 `0 / 12` 並標註；待階段3 接真值。
- 即時更新：連 `GameManager.stat_changed`/`job_changed` 重算。

### D. 美術
程式繪製的暗金×黑佔位框（沿用 [[project-art-direction]] 色票：box 近黑、暗金 Color(0.788,0.659,0.38)、暖白）。經書材質正式圖（封面/內頁紙紋/邊框）之後生，做成**可抽換 export 路徑**，與小遊戲同套路。手機 app 圖示同理先用 Tabler 風佔位。

### E. 驗證（headless）
`test/TestMenuSystem.tscn`（沿用既有測試模式）：
- SkillUnlockManager 資料驅動：每個 skill 的 get_unlock_state 結構正確；初始技能 unlocked=true；behavior 類 current/target 合理；改 flag 後 unlocked 翻轉；`check_unlocks()` 行為與舊版等價（初始解鎖集合一致）。
- StatusPage 計算：三職 mastery% 正確（給定 skills_unlocked 子集）；業障/功德比例。
- 場景煙霧：MenuShell 能 instantiate、切換兩裝置、開關不崩；SkillsPage/StatusPage 能建。
跑法：`Godot --headless res://test/TestMenuSystem.tscn` → `MENU_TEST: ALL PASS`。

## 架構邊界
- MenuShell 不知道頁面內部，只透過 MenuDevice 契約取得頁面清單 → 易加 app。
- 頁面只讀 GameManager/JsonLoader/SkillUnlockManager，不反向改外殼。
- SkillUnlockManager 重構為單一真相源，技能頁與解鎖邏輯共用。

## 附錄：目前缺口（全盤，含未來階段）
1. **主線劇情未寫**（無統整大綱；只有流程＋Boss 阿瑞斯＋多結局旗標＋支線 cross_effect）。階段2 任務 app 前置；需獨立敘事設計，大綱待使用者定位。
2. 街頭藝人 `busking_crowd` 小遊戲未做（使用者定調＝對話觸發，第 4 個小遊戲）。
3. AchievementSystem 未實作（只有 12 筆資料）。
4. 3D 環境/角色 0 檔；計程車/捷運在目前單一 MapScreen＝移動 player 座標即可，多 .glb 才需載場景。
5. AudioManager 無音量 bus 控制 API（設定頁音量滑桿前置）。

## 階段2/3 概述（非本輪實作，僅留接口）
- 手機·任務：讀 quests.json 顯示 10 支線進度；主線分頁待 main_quests.json。
- 手機·計程車：付費移動 player 到任意已解鎖地點（map_locations.json）。
- 手機·捷運：便宜/站點連線移動（西門/萬華/林森）。
- 手機·105 打工：打工板列「端湯 soup_carry／化緣 beggar_challenge」→ 啟動小遊戲（沿用 SceneRouter.go_to_minigame）；街頭藝人走對話觸發不進此板。
- 手機·設定：音量（需先補 AudioManager bus API）、全螢幕、文字速度。
- 經書·成就：AchievementSystem 追蹤 12 因緣解鎖 + 圖鑑 UI。
