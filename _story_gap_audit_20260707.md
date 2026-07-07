# 第一章（DEMO）劇情合理性＋內容缺漏總審 — 2026-07-07

範圍：全 34 支 demo 範圍 .dtl（主線 10 支＋支線/hub/vow 24 支）逐字通讀＋對照
`data/main_quests.json`／`quests.json`／`map_npcs.json`／`areas.json`／`skills.json`／
`SkillUnlockManager.gd`／`MainQuestManager.gd`／`QuestManager.gd`／`BreakVowSystem.gd`／
`MapScreen.gd`／`DistrictScene.gd`。headless 測試全跑：TestAllDialogue／TestMainQuest／
TestDemoScope／TestQuestLocationWiring／TestCh1Expansion／TestBattleTutorial／
TestStoryCutscene，**全部 ALL PASS**（TestAllDialogue 本次跑無 segfault，僅既有的
ObjectDB leak 警告，非新增問題）。

## 總結（最嚴重前 3 件）

1. **【B，會影響劇情兌現】`quest_cherry_debt_choice.dtl` 的「帶櫻逃跑」分支**：`[signal arg="vow:lust"]`
   會呼叫 `BreakVowSystem.try_trigger("lust")`，此函式要求玩家有 5,000 金才能「破戒成功」
   （`BreakVowSystem.gd:39`），金額不足會靜默失敗（只 push_warning，`vow_no_gold.dtl`／
   `vow_already_broken.dtl` 兩支對應對話**根本不存在**於 dialogue/ 目錄）。但緊接著的
   `[signal arg="flag:cherry_escape"]` 不受影響照樣執行，導致「劇情判定櫻已跟你逃走」
   但 `broke_lust_vow`／`cherry_unlocked`（櫻變戰鬥後援）從未被設定、也不會播對應內心戲
   與過場。此外，破戒確認彈窗文案是「破戒（5,000金）是/否」的**交易措辭**，套在這個
   「情急拉手」的敘事時刻上下文不合。
2. **【A，玩家可見的角色名分裂】佛具店老闆娘的顯示名稱系統性分裂**：`map_npcs.json:23`／
   `MapHUD.gd:21`／`MapScreen.gd:293`／`ShopScreen.gd:63` 四處玩家可見 UI（互動提示、
   任務選單標籤、Toast、商店標題）全部顯示「**鄭媽**／佛具店鄭媽」，但她的 Dialogic
   角色資源 `ZhengMa.dch` 的 `display_name` 是「**水野**」，且 `quest_zheng_ma_s1/s2.dtl`
   共 5 處對話自稱／被稱皆為「水野」，`quests.json` 該支線的 `name`/`npc`/`desc` 欄位
   也全寫「水野」。玩家會在地圖上看到「鄭媽」，一開口對話卻聽她自稱「水野」——同一角色
   兩個名字並存，且沒有任何劇情理由（如藝名/曾用名）解釋。對照組：其餘 9 個支線 NPC
   （阿明/阿忠師傅/大衛/蔡媽/陳阿嬤/老王/澪/小傑/Cherry）在 UI 標籤與對話中的名字
   全部一致，證實這是單一角色的孤立錯誤，不是設計慣例。
3. **【B，好消息但需更正紀錄】舊 `_gap_todo_20260706.md` 條目 #3「了塵表情差分」已解，
   應更正為「已解」**：`Liaochen.dch` 已註冊 `stern`/`smile`/`surprised` 三個 mood，
   對應 PNG 三張皆存在且已 import（mtime 2026-07-06 17:46，早於該份 gap doc 18:26
   的落檔時間）；`BattleTutorial.gd` 已接 `PORTRAIT_PATH_SMILE` 給勝利點用。**但**
   `stern`／`surprised` 兩個表情雖已生圖入庫、`.dch` 也註冊了 mood key，教學戰彈窗目前
   仍只用 `smile`，其餘教學點維持 default（`BattleTutorial.gd:117` 註解自承此事）——
   屬於「素材已備妥但尚未全部接線」的小尾巴，非阻塞項。

---

## A 類：劇情不合理 / 資訊矛盾

### A1（中）佛具店 NPC「鄭媽」vs「水野」雙名並存 — 見上方總結 #2
- 證據：`MONK/data/map_npcs.json:23`、`MONK/src/screens/MapScreen/MapHUD.gd:21`、
  `MONK/src/screens/MapScreen/MapScreen.gd:293`、`MONK/src/ui/menu/ShopScreen.gd:63`
  （全顯示「鄭媽」）vs `MONK/dialogue/ZhengMa.dch:9`（`display_name: "水野"`）、
  `MONK/dialogue/quest_zheng_ma_s1.dtl`（4 處自稱/被稱水野）、
  `MONK/dialogue/quest_zheng_ma_s2.dtl`（2 處）、`MONK/dialogue/zheng_ma_hub.dtl:3`
  （選項文字「水野的事」，但這是 hub 選單非 NPC 名稱牌）。
- 附帶風險：`MONK/test/GenDch.gd:93` 的一次性 .dch 產生器仍硬編「鄭媽」為顯示名，
  若未來有人重跑此 script 產生新 .dch 會把 `display_name` 打回「鄭媽」，與現在手改的
  「水野」對話衝突（目前 .dch 是手動維護版本，非 script 產物，暫無風險，但要小心
  誤重跑）。
- 玩家可感知情境：地圖上看到互動提示「與佛具店鄭媽說話」／任務日誌顯示「佛具店鄭媽」，
  進對話後角色開口卻自稱「水野」，且無任何解釋（非藝名/化名劇情設計）。
- 建議：挑一個名字定案（水野在對話密度上占多數，改 UI 端 4 處成本較低），或若刻意做
  「本名/暱稱」雙軌需在對話裡補一句解釋，否則會被當成 bug 回報。

### A2（低）「阿瑞斯揭示身份」與了塵已提前爆雷的順序重複
- 證據：`MONK/dialogue/main_ch1_aftermath.dtl:15`（了塵在雨夜茶攤已明確告知
  「拆你神社、奪你塔的，是集團的拳頭——戰神，阿瑞斯」）發生在 stage `c1_aftermath`；
  但 `MONK/data/cutscenes.json:33-44`（`ares_intro` 過場字幕）在其後的 `c1_ares_intro`
  stage 讓阿瑞斯本人向無戒「揭曉」："……也罷。讓你死個明白——我是阿瑞斯，戰爭之神。"
  無戒回應也表現得像是新資訊確認而非早知道的宿敵重逢。
- 影響：非阻斷性，但讀起來像是兩次不同版本的「初次認識反派」橋段疊在一起，削弱了
  「早已認出宿敵」該有的張力（無戒此時應更冷靜、帶著「終於見到你」的態度，而非驚訝
  式確認）。
- 建議：`ares_intro` 的無戒台詞可以改成呼應式的「果然是你」而非單純接收新資訊，成本
  低（純文案調整，無需動程式或資產）。

### A3（低，記錄性）「萬神殿保全總部」與「城西軍火庫」在地理上的敘事縫合
- 證據：`main_ares_lead.dtl`（stage `c1_confront`）背景 `assets/cutscenes/ch1_ares/hq_exterior.jpg`，
  劇情描述保全總部外圍被電擊棍包圍、無戒被「請出去」；緊接 `main_ch1_armory_breach.dtl`
  （stage `c1_armory_breach`）描述「一路避開追兵，摸到了城西……沒有招牌的灰色廠房」，
  暗示這是兩個不同地點的連續逃亡／滲透。但 `MainQuestManager.gd:18-20` 的
  `STAGE_LOCATION_DISTRICT` 把 `pantheon_security_hq` 這個 stage-location id 唯一對應到
  遊戲內同一個 `armory`（軍火庫）3D 場景——玩家兩個 stage 都是站在同一個現實中的
  「軍火庫街」觸發，只是過場文字把它敘述成兩段旅程。
- 影響：純敘事層面的地理縫合痕跡，玩家不會在遊戲互動上卡關（fail-open 且 3D 空間本身
  沒有露出「這裡其實是同一棟」的破綻），但劇情文本邏輯上稍微牽強。
- 建議：可選——若要更嚴謹，可把 `main_ares_lead.dtl` 的敘述改成本來就在軍火庫外圍
  （去掉「總部」的獨立地點暗示），或補一行「保全總部的分駐點就設在軍火庫街」解釋兩者
  同一區。優先度低，demo 定稿前若時間有限可跳過。

### 已查過沒問題的區塊
- 主線 10 個 stage（c1_demolition → c1_ares）因果鏈連貫：舍利被奪→流浪遇了塵→教學戰→
  intel 引介 3 位支線 NPC→修為門檻（5 技能）→總部交鋒被逐→軍火庫兩波雜兵→阿瑞斯現身→
  擊敗。旗標鏈（`relic_stolen`→`armory_unlocked`→`ares_encountered`→`ares_purified`）
  無斷點、無需求無法滿足的死鎖。
- 破戒三段（食/貪/色）的獨白文字彼此獨立、風格一致、無交叉矛盾。
- 支線「八重找孫子」(grandma) 與「電玩少年」(jie) 的完成順序依賴
  （`require_completed: "jie"`）在對話文本裡有互相引用支撐（grandma_s2 提到「上次輸給你」），
  非資料庫孤立設定，邏輯自洽。
- 「大村師傅」(ah_zhong) 揭露是無戒師父的同門師兄，與「老廚師」人設、「解鎖師父背景」
  的 cross_effect 承諾一致且在 demo 內完整兌現（quest_ah_zhong_final.dtl 有完整收尾，
  非斷尾）。
- 「老王復仇/放下」二選一分支各自邏輯自洽，兩條路都有對應獨立收尾台詞，無穿幫。
- 稱謂/敬語：「貧僧」「施主」「阿彌陀佛」等僧侶用語在全部 34 支 timeline 中使用一致，
  無角色錯用他人專屬稱謂。
- 時間線：`c1_aftermath`（雨夜、天快亮）→`c1_tutorial_brawl`（同一夜延續）→`c1_intel`
  （天快亮，了塵桌上畫地圖）→`c1_armory_gate`（訓練期，時間跳躍但無具體天數矛盾）→
  `c1_confront`（訓練後再訪）順序合理，無回溯矛盾。

---

## B 類：流程死角 / 卡關風險

### B1（中）破戒觸發與敘事選擇脫鉤，見上方總結 #1
- 證據同 A 類條目，程式面：`MONK/src/systems/BreakVowSystem.gd:17-24`（`try_trigger`
  始終彈金錢確認框，不分「主動選擇」與「劇情既定事件」兩種呼叫情境）、
  `MONK/dialogue/quest_cherry_debt_choice.dtl:23-24`（signal 順序：先 vow 後 flag，
  彼此不互相檢查對方是否成功）。
- 玩家會遇到的具體情境：選「不還也不談，直接帶櫻逃」分支時，若身上金幣 < 5000
  （demo 初期完全可能，尤其若之前已經花錢資助過水野的 zheng_ma_saved_gold 分支
  -2000 金），彈出「破戒（5,000金）是/否」；選「是」但錢不夠 → 系統嘗試 `spend_gold`
  失敗 → 只留一句 debug 警告（`push_warning`），畫面上沒有任何玩家可見回饋，直接跳到
  `flag:cherry_escape` 生效，劇情繼續往「已破戒」分支的 `quest_cherry_debt_final.dtl`
  播放（該檔第 2 行是用 `GameManager.get_flag("cherry_escape")` 判斷，不檢查
  `broke_lust_vow`），造成「劇情上兩人已私奔，但破戒特效/加成/過場全部沒發生」的
  不一致結局。
- 驗收建議：情境測試——刻意把金幣壓到 5000 以下，選 cherry_debt 的 escape 分支，
  觀察是否仍正常收尾（目前推斷不會，需修正）。
- 建議修法二選一：(a) 讓 `quest_cherry_debt_choice.dtl` 這個分支改用「劇情直接
  set_flag」而非呼叫 `BreakVowSystem.try_trigger`（跳過金錢確認/花費，畢竟這裡沒有
  「消費」語境，只是選擇）；(b) 若要保留花費機制，`quest_cherry_debt_final.dtl` 該分支
  的判斷應改成 `broke_lust_vow` 而非 `cherry_escape`，且 escape 選項要顯示金幣不足時
  的替代文案。

### B2（低）支線的 `available_periods` 時段限制形同虛設
- 證據：`MONK/data/quests.json` 多筆支線設有 `available_periods`（如 `ah_zhong`:[2,3]、
  `cai_ma`/`cherry_debt`:[3]、`ah_ming`/`rei`:部分時段限定），但實際 3D 探索觸發改走
  `map_npcs.json`（見 `MONK/src/systems/QuestManager.gd:1-146`），此檔案的互動點
  **完全沒有 `available_periods` 欄位**，而 `MONK/src/screens/MapScreen/MapScreen.gd:67`
  的註解自承「不按時段過濾觸發點」。舊 2D 版（`DistrictScene.gd`／`map_locations.json`）
  才有時段過濾邏輯，但該場景現已是孤兒（無任何地方 instantiate `DistrictScene.tscn`，
  純 2D 探索時代遺留死代碼）。
- 影響：不是卡關（更寬鬆而非更嚴），但代表 `quests.json` 裡的 `available_periods` 是
  **對玩家不生效的死資料**——支線在任何時段都可觸發，設計文件（quests.json 本身）與
  實際行為不符。若之後有人依賴這個欄位去平衡遊戲節奏（例如「大村只在下午/晚上出現」
  的用意），實際上並未生效。
- 建議：非阻塞，記錄即可；若要恢復時段限定，需在 `map_npcs.json` 補欄位並在
  `MapScreen.gd:_spawn_triggers` 加時段檢查（仿 `DistrictScene.gd:_has_period` 邏輯）。
  若決定「支線隨時可做」是刻意簡化，則可以直接砍掉 `quests.json` 裡的
  `available_periods`／`cross_effect` 死欄位減少誤導。

### B3（低）`cross_effect: "櫻 解鎖為戰鬥後援"` 承諾未兌現
- 證據：`MONK/data/quests.json:161`（"cherry_debt" 的 cross_effect 文字）承諾「櫻解鎖
  為戰鬥後援（破色戒後）」；`MONK/src/systems/BreakVowSystem.gd:60` 確實有
  `GameManager.set_flag("cherry_unlocked", true)`，但全專案搜尋 `cherry_unlocked`
  只有這一處寫入，**沒有任何讀取端**（戰鬥召喚系統 summons.json/SummonChain 均未引用
  這個 flag）。
- 影響：非卡關（玩家不會被擋住任何流程），是「文件承諾的功能沒有實作」的內容缺口，
  屬於 demo 定稿前該決定「做/砍」的項目，不是技術債。
- 建議：demo 範圍決定要嘛實作 Cherry 戰鬥召喚（有 summons 系統可掛，工作量中），要嘛
  把 `quests.json` 的 cross_effect 文字改成不承諾這個功能（純文字改動，成本最低）。

### 已查過沒問題的區塊
- `c1_armory_gate` 的技能數門檻（≥5）：`initial`×2（basic_punch/wooden_fish）+
  `story`×1（arhat_strike，c1_intel 授予即計入 skills_unlocked）+ 側線可得
  `vajra_glare`(ah_ming)/`sound_wave`(ah_zhong)/`great_compassion_shield`(zheng_ma)/
  `lions_roar`(lao_wang)/`alms_wave`(grandma) 等 5 個支線技能，demo 範圍內完全可湊滿
  5 個，無死鎖（`SkillUnlockManager.gd:14-39` UNLOCK_TABLE 逐條核對，無循環依賴）。
- `quest_location_passed`／`stage_location_passed` 兩處門檻皆 fail-open 設計，找不到對應
  district 時不擋（`QuestManager.gd:31-38`、`MainQuestManager.gd:147-159`），目前所有
  demo 範圍 NPC 都在 `shrine`，恆通過，無隱性卡關風險。
- `armory_worker_locked/freed` 依 `ares_purified` 旗標正確切換（`MapScreen.gd:177-178`），
  邏輯單純無死角。
- 主線 10 stage 沒有互相衝突的 set_flag／require_flag 命名撞名。

---

## C 類：內容缺漏（資產/文字）

### C1（低，已確認非缺口，需更正舊紀錄）了塵表情差分 — 見總結 #3
- 三張 mood PNG 全部存在且已 import；`.dch` 已註冊；`BattleTutorial.gd` 的 smile
  已接線。**唯一剩餘尾巴**：`stern`/`surprised` 兩個 mood 目前只在 `.dch` 註冊、
  資產已備妥，但 `MONK/src/screens/BattleScreen/BattleTutorial.gd:117` 的教學小視窗
  除了勝利點外都還是 default，沒有把 stern/surprised 接到對應教學點（例如「別跟他們
  講理」訓斥台詞、亂入登場的意外感）。純接線工作，無需再生圖。
- 對照：`main_ch1_tutorial_brawl.dtl:4` 裡 `Liaochen (stern)` 這個對話內台詞已經在用
  stern mood（Dialogic 對話框本身，非 BattleTutorial 小視窗），這條路徑沒問題——缺的
  只是 BattleTutorial 彈窗那一層的表情切換。

### C2（低）Codex 單裡的「街景互動提示框水墨紋理」仍是可選未做項
- 舊 gap doc #4 標記「可選，看使用者意願」，本次未見任何新素材落檔
  （`assets/2d/ui/prompt_panel_ink.png` 不存在），維持「使用者未決定」狀態，非新發現。

### C3（極低，世界觀用詞疑似遺漏統一）「剝皮寮」單一出現的真實地名
- 證據：`MONK/dialogue/quest_rei_choice.dtl:7`「貧僧帶你穿過剝皮寮」——這是唯一一處
  出現真實台北地名（剝皮寮為萬華區真實歷史街區），全專案其餘地名均為虛構的「新梵京」
  世界觀用詞（櫻木町/萬年大樓/歌舞坂/門前町等）。搜尋全 dialogue/data 只有這一筆真實
  地名殘留，推測是世界觀從真實台北改編為虛構「新梵京」時的漏改。
- 影響：極輕微，這句話是背景環境描述、不影響任何遊戲邏輯，多數玩家不會特別在意，但
  嚴格定稿檢查應該抓出來統一（比照其他虛構地名風格改掉，如「巷弄」或另造一個虛構
  街區名）。

### 已查過沒問題的區塊
- 全 34 支 .dtl 文字掃描 TODO/FIXME/佔位/placeholder/暫定/待補/xxx/待定：**0 命中**。
- 全 data/*.json 同關鍵字掃描：**0 命中**。
- .dtl 內顯式 `res://` 資產路徑（背景圖等）16 筆全部實際存在，無死連結。
- `boss.json` 的 ares 圖片/背景引用（`ares_base.jpg`／`ares_pained.jpg`／
  `ares_mocking_laugh.jpg`／`ares_phase2.jpg`／`bg_battle_ares_forge.png`）與
  `defeat_cutscene`/`transition_cutscene`（`ares_defeated`/`ares_phase2`）走的是獨立
  video-frame 資料夾機制（`assets/cutscenes/ares_defeated/`、`assets/cutscenes/ares_phase2/`
  皆存在），非 `cutscenes.json` 登錄制，兩套機制不衝突，非缺口。
- 27 支小遊戲過場、11 個角色 .dch 資源、27 個 timeline，皆由 TestAllDialogue 驗證
  「全部載入正確／全部解析成功」。

---

## 舊 `_gap_todo_20260706.md` 逐條狀態

| # | 條目 | 狀態（本次查證） |
|---|---|---|
| 1 | 使用者側三件未 commit（滑鼠加固/教學戰/雨段跳過） | **未變動，仍待使用者驗收**——本次審查不涉及此範圍，維持原狀，實機清單見 `_acceptance_checklist_20260706.md`。 |
| 2 | 4 支過場短片記錄性瑕疵 | **未變動**，非本次審查範圍（美術/影片品質問題，非劇情邏輯或流程死角）。 |
| 3 | 了塵表情差分 | **已解**——三張 mood 已生圖/import/`.dch` 註冊，`BattleTutorial.gd` 的 smile 已接線。剩 stern/surprised 兩個教學點未接線，降級為本報告 C1（低優先度尾巴），建議 gap doc 更新此條為「已解（尾巴見 _story_gap_audit C1）」。 |
| 4 | 街景互動提示框水墨紋理（可選） | **仍開放**，維持原判定（使用者未決定是否要做）。 |
| 5 | C3/C4 死資料欄位 | **已解**（gap doc 自己也標記完成，本次未發現回歸）。 |
| 6 | TestAllDialogue shutdown segfault | **狀態不變**——本次 7 次 headless 執行**皆未觸發 segfault**（含 TestAllDialogue），可能與具體執行環境/次數有關，不代表已根治，仍建議維持「記錄在案」而非改判已解。 |
| 7 | docstring 26/27 筆誤 | 舊紀錄稱「本日順手修掉」，本次 TestAllDialogue 輸出顯示「27 個 timeline」與程式碼一致，**確認已修**。 |

## 本次新增發現（不在舊 gap doc 中）

- A1／B1／B3：佛具店 NPC 雙名分裂、cherry_debt escape 分支破戒判定脫鉤、
  cherry_unlocked 死旗標——三者互相關聯（都圍繞 zheng_ma 與 cherry_debt 兩條支線），
  建議合併排入下一輪修正。
- A2／A3：文案層面的順序/地理小瑕疵，成本低，可與其他文案潤飾一併處理。
- B2：`available_periods` 死欄位，建議與使用者確認是否要恢復或直接砍除欄位。
- C3：「剝皮寮」單一真實地名殘留，一行文字修正。

## 沒能覆蓋的死角

- 未實機（GPU/視窗）遊玩驗證，僅 headless 測試＋逐字讀 dtl/json/gd 源碼，
  無法確認 UI 呈現層是否有本次審查方法覆蓋不到的視覺穿幫（例如過場字幕與語音對不上、
  Dialogic 對話框排版溢出等）——這類需要實機或截圖 QC，非本輪任務範圍。
  Cherry escape 分支的金幣不足情境（B1）僅靠讀碼推導，未實際跑一次 headless 情境測試
  驗證「彈窗後靜默失敗」的確切畫面表現，建議下一輪找人實機重現一次。
- ch2-12（11 神）內容依指示排除在外，僅確認 `main_quests.json` 裡它們的 stage
  沒有 dialogue/battle/boss 欄位（純敘事佔位，不會被 demo 玩家碰到，因為
  `_demo_last_chapter: "ch01_ares"` 已封頂），未逐條檢查其文字品質。
- 小遊戲本體（9 款）與過場短片的實際手感/演出品質不在本次「劇情合理性＋內容缺漏」
  範圍內，僅確認資料存在與觸發連線正確。
