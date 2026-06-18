# 小遊戲設計 spec（Step 9）

日期：2026-06-14
依據：GDD v5 Step 9（`化緣 BeggarChallenge` / `端湯上塔 SoupCarry2D` / `木魚節奏戰 WoodenFishRhythm`）、v4_P5 §10 的程式原型。

## 範圍與授權
使用者睡前授權「三個都實作 + headless 驗證」。視覺：今晚用**純 2D 程式繪製的佔位圖形**（人形/碗/音符），貼圖做成可抽換 export 變數；**正式新美術留給使用者醒後指揮生圖**（見附錄 C 的 prompt 清單）。

## ⚠️ 待使用者拍板的落差（早上第一件事）
- `data/quests.json` 的 `trigger_minigame` 欄位**原本沒有任何程式在讀**（QuestManager 不處理）。本次新增了讀取邏輯（見下）。
- 阿明支線 s1 的 `trigger_minigame` 是 **`busking_crowd`（街頭藝人聚眾）**，但它**不在** GDD Step 9 設計的三個小遊戲內。
- GDD 設計的 **`SoupCarry2D`（端湯上塔）反而沒有任何支線/地圖觸發點**。
- **要決定的事：** 阿明那關到底要接哪個？(a) 把 `busking_crowd` 改成 `soup_carry`，讓端湯有歸宿；(b) 另外把 busking 也做出來（第 4 個）；(c) 端湯改由別的支線/地圖點觸發。今晚三個都先做成可獨立啟動，接線等拍板。

## 共用架構：結果回傳契約
所有小遊戲繼承 `MinigameBase`（`src/screens/Minigames/MinigameBase.gd`），結束時呼叫：

```
finish({ "id": String, "score": int, "win": bool,
         "gold": int, "merit": int, "karma": int })
```

- `MinigameBase.finish()` → 委派 `SceneRouter.finish_minigame(result)`。
- `SceneRouter.finish_minigame(result)`：① 套用 result 內的 `gold/merit/karma`（intrinsic 獎勵，透過 GameManager）；② 若啟動時帶了 `context.quest_win`/`quest_lose`（quests.json 的 win/lose dict），依 `result.win` 套用對應那組；③ `emit minigame_finished(id, result)`；④ `go_to_map()`。
- 小遊戲本身**不直接改遊戲狀態**（純邏輯、好測試），只回報 result。

### 啟動與情境
- `SceneRouter.go_to_minigame(id, context := {})`：存 `context`，NEON_FLASH 轉場進場。
- QuestManager 新增：某 stage 的對話結束後，若該 stage 有 `trigger_minigame`，**先啟動小遊戲**（把 stage 的 `win`/`lose` 放進 context），等 `minigame_finished` 再套用 win/lose 並推進 stage；沒有 `trigger_minigame` 時維持原本立即推進的行為。
- 地圖「化緣」動作（非支線）：直接 `go_to_minigame("beggar_challenge")`，結果的 gold 由 intrinsic 路徑發。

## 三個小遊戲

### 1. 化緣 BeggarChallenge（`beggar_challenge`）
- 2D 側視固定鏡頭，背景 `bg_battle_wanhua`，乞討的無戒用 `wujie_beggar_calm` 立繪。
- 路人從右往左走入，進入畫面中央「化緣區」時頭上亮施捨圖示；按 `interact`/`confirm`/滑鼠左鍵化緣收金幣。
- 路人 4 型（GDD 數值）：office_worker 50 / tourist 100 / rich_lady 500 / drunk_man 10，權重 0.4/0.3/0.1/0.2。
- `has_qr_code` flag → 獎勵 ×3。
- 60 秒計時。**貪婪懲罰**：在沒有路人於化緣區時猛按（空揮）累計，>X 次 → 該局 karma +、merit −（呼應業障/功德主題）。
- result：`score`=總金幣 → `gold`；merit/karma 依表現。

### 2. 端湯上塔 SoupCarry（`soup_carry`）
- 背景 `bg_battle_temple`，逐層往上的塔。碗＝程式繪製（碗 + 湯面 Polygon2D），溢出＝`CPUParticles2D`。
- 滑鼠左右移動（或 A/D）控制碗傾斜 `bowl_tilt`（±MAX_TILT=25）；每幀 lerp 自然回正（阻尼 2.5）。
- 每層有風干擾 `_get_floor_wind(floor)`：7 樓以上加強。傾斜超過上限 → `spillage` 累加。
- `spillage >= 100` → game over（失敗）；爬完 10 層 → 成功。
- result：win=是否登頂；merit 依剩餘湯量（端得越穩功德越高）。

### 3. 木魚節奏戰 WoodenFishRhythm（`wooden_fish_rhythm`）
- 背景 `bg_battle_temple`；對手小傑 `npc_jie`、無戒 `wujie_chanter_calm` 立繪左右站。
- 單軌「太鼓/木魚」節奏：音符沿軌道落向判定線，於時間窗按 `confirm`/滑鼠/`interact` 敲擊。
- 判定窗（距判定時刻）：perfect ≤60ms（+100）、good ≤120ms（+50）、否則 miss（連段歸零）。`wooden_fish_tap` 音效、`combo_up` 連段。
- 對手小傑：固定命中率（預設 0.82）模擬其分數。**「誰漏的少誰贏」**＝玩家準確率 ≥ 對手 → win。
- 譜面：跟著 BGM 拍點程式生成（預設 BPM 與音符數，可調）。
- result：win → jie 支線發 `{gold:500, unlock_skill:wooden_fish_fury, flag:jie_defeated}`；lose → `{gold:-500}`（由 context 的 quest_win/quest_lose 套用）。

## 驗證（headless）
`test/TestMinigames.tscn`：把每個小遊戲的**計分/判定純邏輯**抽成可直接呼叫的方法，測試：
- Beggar：各型路人 reward 正確、QR ×3、貪婪懲罰累計。
- Soup：傾斜超限累加 spillage、達 100 觸發失敗、登頂成功。
- WoodenFish：時間窗 → perfect/good/miss 正確、連段、勝負判定（玩家 vs 對手準確率）。
- 三場景能 instantiate、跑數幀、呼叫 finish 不崩、result 結構正確。
跑法：`Godot --headless res://test/TestMinigames.tscn`，印 `MINIGAME_TEST: ALL PASS`。

## 附錄 C：待生成的正式美術（醒後指揮）
依 [[project-art-direction]] 半寫實厚塗 + 暗金×黑 UI：
- 化緣：4 型路人全身像（上班族/觀光客/貴婦/醉漢，台北街頭、側身行走可切兩幀）、施捨金幣特效。
- 端湯：托缽湯碗（俯側 45°，可旋轉）、湯面/熱氣、各層塔內景或一張可垂直捲動的塔身。
- 木魚：木魚敲擊兩幀（knock/rest）、音符圖示、判定線/連段霓虹特效。
（背景與人物立繪沿用現有戰鬥背景與 Wujie/Jie 立繪，先不重生。）
