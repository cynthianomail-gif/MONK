# 缺漏盤點＋小遊戲重試流程 tracking（2026-07-07）

需求（使用者原話拆解）：
1. 檢查還有什麼缺漏的地方
2. 劇情不合理的地方
3. 小遊戲開場/結束影片是不是有還沒套到的
4. 新流程：小遊戲結束後停在 win/lose 過場影片最後一幀→跳「要不要再一次」視窗，不要回到小遊戲本身的畫面

| 項目 | 狀態 | 產出路徑 | 下一步 |
|---|---|---|---|
| 小遊戲過場接線盤點 | ✅ 零缺口 | _minigame_cutscene_audit_20260707.md | —（使用者印象來自今天稍早已修的 8a/8b 繞過 bug） |
| 劇情合理性＋缺漏盤點 | ✅ | _story_gap_audit_20260707.md | 使用者已拍板，修正見下節 |
| 盤點後修正批（使用者拍板 2026-07-07） | ✅ | 見下「盤點修正批記錄」 | 等使用者過目→commit |
| 重試視窗實作（需求4） | ✅ | MinigameBase.gd＋CutsceneScreen.gd/.tscn＋TestMinigameCutscene.gd＋CaptureRetryPanel.* | 等使用者過目截圖→commit |
| 驗收＋截圖 | ✅ | _cap_retry_panel.png | — |

## 需求4 實作記錄（2026-07-07，主對話親做＋親驗）

改動：
1. `MinigameBase.gd`：`_play_end_cutscene` 不再播完即 dismiss——overlay 存 `_end_cutscene_overlay`
   停在最後一幀當結算底圖；結算面板 layer 100→200（過場在 128，否則被蓋）；底下有停格時
   壓暗降為 0.45（原 0.72）讓最後一幀看得見；「再玩一次」`_dismiss_end_cutscene()` 淡出停格、
   「離開」隨場景切換自然帶走（overlay 是 current_scene 子節點）。
2. `CutsceneScreen.gd/.tscn`：修掉既有「雙跳過提示重疊」bug（場景烤了「空白鍵跳過 ▶」、
   程式又動態建「ESC 跳過」）——合併為場景的 SkipHint 一顆（文字「空白鍵／ESC 跳過 ▶」），
   `_finish()` 播畢隱藏（停格當底圖時提示不殘留）。
3. `TestMinigameCutscene.gd` 測試 7 斷言改為新規格：面板開啟時 overlay 留存當底、
   `_on_result_restart()` 後 overlay 淡出移除＋面板關閉。

驗證：TestMinigameCutscene／TestResultPanel／TestMinigames／TestCutscene／TestStoryCutscene
全 ALL PASS；GPU 截圖 `_cap_retry_panel.png` 親讀（飛鏢 win 停格當底＋壓暗＋再玩一次/離開視窗，
無提示殘留）。⚠雷：`--quit-after` 幀數太小會讓測試沒跑完就 exit 0 假通過——過場類測試要給
4800+ 幀再看 stdout 有無 ALL PASS 字樣。
既有問題（非本次引入，基準對照確認）：TestMinigames 的 LayoutStore apply_override 失效物件
錯誤 ×5（屬佈局工具 v3 未 commit 工作），已開 spawn_task 章。

## 盤點修正批記錄（2026-07-07，使用者拍板後主對話親做）

使用者決定：①統一叫「水野」②「櫻解鎖為戰鬥後援」砍掉 ③破戒改成就式＝支線完成自動觸發
（不彈金錢確認框、不走近就觸發）④殘留 Cherry 字樣改「櫻」。

1. **破戒系統重寫**（src/systems/BreakVowSystem.gd 全檔重寫）：
   - 訂閱 EventBus.quest_updated("completed")；QUEST_VOWS 對照＝ah_zhong→食戒、
     zheng_ma→貪戒、cherry_debt→色戒（require_flag=cherry_escape，只有逃跑分支破）。
   - 拆除：金錢門檻/ConfirmDialog 確認框/gold_cost/desc、cherry_combat_ally 效果
     （cherry_unlocked 死旗標隨之消失）、vow_no_gold/vow_already_broken 缺檔路徑。
   - 保留演出：業障＋旗標＋broke_any_vow（iron_shirt 解鎖沿用）＋vow_break_* 獨白＋
     break_* 過場；food=berserker、greed=gold_multiplier 效果保留。trigger() 冪等。
   - 舊入口全拆：GameManager "vow:" 訊號分支、MapScreen ambient_break/_broken_zones、
     MapScreen *_break_trigger 三個 action、map_npcs.json 三個 ambient_break 欄位、
     MapHUD 三個 break_trigger 標籤、quest_cherry_debt_choice.dtl 的 [signal arg="vow:lust"]。
2. **鄭媽→水野**：map_npcs.json 互動點名、MapHUD quest_zheng_ma 標籤、MapScreen toast、
   ShopScreen 標題+檔頭註解、GenDch.gd 產生器資料。
3. **Cherry→櫻**：map_npcs.json NPC 名、MapHUD「與 櫻 說話」「櫻的債」、MapScreen toast。
   （.dtl 的 Cherry 說話者 token 是識別字不動；Cherry.dch display_name 本就是「櫻」。）
4. **阿瑞斯開場文案**（cutscenes.json ares_intro）：無戒台詞改「果然是你……戰神。」
   呼應了塵已爆雷，消除二次初見感。
5. quests.json：escape 分支拿掉 trigger_vow、三支線 cross_effect 同步註明自動破戒。

驗證：TestMapInteraction/TestMenuSystem/TestShop/TestQuestLocationWiring/TestCh1Expansion/
TestMainQuest/TestDemoScope/TestAllDialogue 八支全 PASS（exit 0，無 segfault）。
未 commit。⚠map_locations.json（死資料，B2 懸決）仍殘留 *_break_trigger 字樣，不影響行為。
