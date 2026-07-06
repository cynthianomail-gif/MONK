# 戰鬥系統全面改版設計（2026-07-03，使用者已確認）

參考研究：`D:\monk\_research_battle_design.md`（人龍7/8 × P5R 機制拆解＋來源）。
使用者拍板：四期全做｜成長走「修行盤單軌」（無傳統等級）｜護法召喚先做 2 尊。
風格鐵則：水墨黑白＋朱印紅（#C93A2E 系）單一強調色；UI 動態全用 Control+Tween，不新增繪圖素材（護法立繪除外，走 Codex）。

## 已完成的前置修復

- 黑畫面根因＝`go_to_battle` 換場後只等一幀就找 `battle_manager` 群組（找到 null → `setup()` 未執行）。
  已修：`SceneRouter.gd` 等待迴圈（同 `play_cutscene` 模式）＋回歸測試 `test/TestBattleEntry.tscn`（headless ALL PASS）。

## 現況可沿用（不重做）

- One More（弱點→再行動）、全倒→總攻擊、Hold Up、Boss 二階段（`BattleManager.gd`）
- 三系屬性 物理/karma(業)/merit(淨)＋敵人 weaknesses/resistances（`enemies.json`）——**維持三系不擴**
- BreathingFigure 站立立繪、okami 戰鬥背景 8 張、阿瑞斯 VFX
- 「了塵為師」習得管線（`SkillUnlockManager.gd`）——**不動**；修行盤只放「新技能」節點，點下即習得，避免雙重門檻

## 第一期：戰鬥畫面重構（人龍7 版面 × P5 動態）

版面（mockup 已過目）：
- ~~**TurnOrderBar**（左上）：行動順序圓 chip 橫排，當前行動者放大＋朱紅底＋金邊；下一輪的用虛線邊。~~（2026-07-03 使用者體感回饋後移除：左上不顯示回合歸屬，佇列機制保留、僅除視覺層）
- **EnemyList**（右上）：每敵一列＝名字＋Lv＋HP 條＋弱點徽章。弱點**要探知**：命中過該屬性才顯示「弱 淨」，否則「弱 ？」；探知記錄存 `GameManager.player.weakness_intel`（依 enemy_id，跨戰鬥保留、進存檔）。
- **CommandMenu**（貼玩家立繪右側）：縱向斜切按鈕（skew -10°）攻擊／技能／防禦／道具／護法。選中項放大＋位移＋朱紅底；未選深灰。鍵盤上下＋E 確認，滑鼠可點。出現時從左滑入 0.15s。
  - 攻擊＝免費基本攻擊（依職業取 basic 技）；技能＝現有技能子選單（補：顯示屬性圖示＋消耗）；防禦＝本回合減傷 50%＋完美格擋加成（見第二期）；道具＝現有；護法＝第四期接。
- **傷害演出**：漂浮大字（斜體、彈跳上飄淡出）；爆擊放大 1.4x 變朱紅；命中弱點附斜切「WEAK！」標籤＋金色「ONE MORE 再行動」橫幅；Miss 灰字。
- **聚焦演出**：選技能選目標時背景 modulate 壓暗 0.6、目標立繪亮起；行動者出招瞬間立繪 scale 1.06 彈一下。
- **PlayerPanel**（左下）：現有面板重排——名字／HP 條／業障紫條／功德金條，加「道行」顯示（第三期接）。
- **LogLabel** 保留改窄條（底部中央，金色左框線）。
- 佈局全部錨點驅動，適應 16:9。

## 第二期：戰鬥機制強化

1. **行動佇列**：`Combatant.speed` 新欄位；`enemies.json` 每敵補 `speed`（暫值＝10＋level×2，第四期調）；玩家 speed 基礎 15＋修行盤加成。回合開始把所有存活戰鬥者按 speed 降冪排成佇列，依序行動（取代固定我方→敵方）；One More 規則不變（玩家弱點命中→插入一次額外行動）。（TurnOrderBar 視覺已於 2026-07-03 依使用者回饋移除，佇列純邏輯運作。）
2. **防禦＋完美格擋**（人龍式、靜態立繪解法＝明確視覺提示取代動畫前搖）：
   - 敵人出招前：目標處紅色警示光圈閃 0.5s＋音效（提示窗）。
   - 提示窗內按 E＝完美格擋：減傷 70%、立繪閃白＋斜切「格擋！」字樣＋短 hit-stop（沿用 MinigameBase 的體感模式）。
   - 本回合有選「防禦」指令：普通減傷 50%；防禦＋完美格擋疊加＝減傷 90%。
   - 沒選防禦也能完美格擋（70%），敵人回合永遠有事做。headless 測試用可注入的假輸入驗判定窗。
3. **總攻擊演出升級**：觸發時全畫面白閃→玩家立繪多重殘影快速交錯掃過（複製 TextureRect＋Tween）＋速度線 ColorRect 條紋→水墨定格（背景急停壓暗、立繪定格、朱印「超渡」大字）→結算傷害。
4. **戰利品**：勝利加發「**道行**」（新成長貨幣）：基準＝敵 level×15＋Boss 加成；結算畫面顯示 金幣/功德/道行 三行。

## 第三期：修行盤（人龍0 式圓盤，成長單軌）

- **資料**：`data/cultivation_board.json`
  ```json
  {"board_name":"修行盤","currency":"daoxing",
   "rings":[{"ring":0},{"ring":1,"radius":120},{"ring":2,"radius":220},{"ring":3,"radius":320,"unlock_flag":"c1_master_trial"}],
   "nodes":[{"id":"atk_1","ring":1,"angle_deg":30,"type":"stat","effect":{"stat":"atk","add":8},"cost":300,"requires":["core"],"name":"金剛力・壹","desc":"攻擊力+8"}]}
  ```
  節點 type：`stat`（hp/atk/def/spd）｜`skill`（`effect.learn_skill`，點下直接習得）｜`passive`（旗標，戰鬥讀取）。`requires` 陣列＝解鎖前置＝連線渲染的邊。ch1 盤面規模：核心＋2 環約 24~30 節點＋外環師鎖 4~6 節點。
- **玩家資料**（`GameManager.player` 新鍵，SaveManager 走既有逐鍵防呆）：`daoxing:int`、`board_unlocked:Array[String]`（含 "core"）、`weakness_intel:Dictionary`（第一期）。
- **效果套用**：`CultivationBoard`（autoload 或 GameManager 內模組）讀 json＋`board_unlocked` 計算 `bonus = {hp,atk,def,spd,passives[]}`；`Combatant.from_player()` 改吃 基礎值＋bonus（基礎：HP500／攻100／防10／敏15 不變，成長全靠盤）。讀檔重放，零遷移。
- **UI**：`BoardScreen`（Control 場景）：極座標算節點位置、`_draw`/Line2D 畫環與邊；節點狀態四態（已解鎖朱紅實心／可解鎖金框＋顯示花費／未達前置灰框／劇情鎖紫虛線）。選中節點右側面板顯示名稱/效果/花費/前置。**按住 E 灌注道行**：進度條充能 0.6s＋音效，滿→節點綻放（scale 彈跳＋白閃）＋扣款。入口：手機選單新 app「修行」（沿用 phone apps 模式）。
- 存檔相容：舊檔缺鍵→預設空盤＋道行 0，不炸。

## 第四期：護法召喚＋數值平衡＋總驗收

1. **護法召喚**（人龍7 Poundmates 式，花**金幣**＝香油錢請神，不動業/淨資源）：
   - 指令「護法」子選單，2 尊：**伏虎羅漢**（單體大傷＋擊倒，金幣 800）／**韋馱天**（我方大補＋防禦 buff，金幣 600）。
   - 演出：立繪從側面滑入＋全屏色閃＋震動＋傷害/治療結算；立繪先用佔位圖接線，正式圖開 Codex 單（水墨、白底 3/4 身、去背後入 `assets/2d/portraits/summons/`）。
   - 每場戰鬥每尊限 1 次。
2. **平衡**：敵 speed/道行表定稿；盤面節點花費曲線（環1 約 200~400、環2 約 600~1200）；業/淨回復稀缺化（基本攻擊產生量下修、道具價格上調）——以「ch1 全支線通關約點完 2 環」為準。
3. **驗收**：headless 全測試（新增 TestBattleFlow／TestBoard／TestSummon＋既有全套）＋ GPU 截圖（戰鬥新 UI、完美格擋瞬間、總攻擊定格、修行盤）交使用者過目。

## 測試與跑法慣例

`./tools/godot/Godot_v4.5-stable_win64_console.exe --headless --path D:/monk/MONK res://test/<T>.tscn 2>&1 | grep -aiE "ALL PASS|FAIL|SCRIPT ERROR"`；改 .tscn/新資產先 `--headless --import`；GPU 截圖用 Capture* 模式。既有測試不准新增 FAIL。
