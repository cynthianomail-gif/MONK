# 小遊戲全面改版設計規格（2026-07-04，使用者已拍板）

## 0. 背景與決策記錄

使用者需求（2026-07-03 提出）＋四項拍板（2026-07-04）：

| 決策點 | 拍板結果 |
|---|---|
| 化緣處置 | **C 案：大改「接缽化緣」**（接落物玩法） |
| 結尾過場短片 | **每個遊戲都做**（勝/敗兩版），播完停最後一幀再出結算面板 |
| 美術方向 | **只有木魚小遊戲本身走 Q 版可愛風**（flat color＋粗輪廓）；**27 支過場短片走寫實風、與原遊戲風格一致**（2026-07-04 使用者二次澄清，覆蓋先前「短片也 Q 版」的誤解） |
| 木魚支線重玩 | 結算面板允許「再玩一次」（輸了可重試）；**支線結束後保留常駐入口可回頭再玩** |

現況盤點依據（2026-07-03 subagent 實查）：
- 9 個小遊戲共用 `MinigameBase.finish()` → `SceneRouter.finish_minigame()`（SceneRouter.gd:156-179）管線。
- 全專案**沒有**「結算面板＋再玩一次/離開」元件；只有端湯有 3.5 秒自動關閉文字牌，化緣結束直接切走。
- `SceneRouter.play_battle_cutscene()`（SceneRouter.gd:94-132）的 CanvasLayer 疊加播放模式可直接仿作小遊戲過場。
- 木魚入口＝劇情觸發（data/quests.json:11 ah_ming、:77 jie）；端湯＝105 打工；化緣＝打工＋地圖點雙入口。
- Magnific 餘額 101,553 點；Kling 2.5 5s/1080p＝325 點/支。

節奏天國研究筆記：scratchpad\rhythm_heaven_research.md（示範×2→跟拍、判定綁音訊時間軸、Try Again/OK/Superb 評級、回饋做在角色動畫）。

**木魚 Q 版美術基底已定案（2026-07-04 使用者選 V1）**：`docs/superpowers/specs/2026-07-04-minigame-style-base-v1.jpg`（三和尚黃昏街景，flat color＋粗輪廓＋點點眼）。**僅限木魚小遊戲**的美術（三和尚立繪差分、背景）生成時以此圖作 style reference（creation identifier 記錄在 _tracking.md）。過場短片不用它。

## 1. 第一期：共用結算面板（全 9 遊戲）

### 設計
- `MinigameBase` 新增 `show_result_panel(rating: String, rows: Array, result: Dictionary)`：
  - CanvasLayer（layer 高於遊戲 UI）＋半透明黑幕＋面板：遊戲名、評級大字（金）、分項明細列、兩鈕 **再玩一次 / 離開**。
  - 鍵盤左右選＋confirm，滑鼠可點。
- 流程改變：各遊戲 `_end()` **不再直接 `finish()`**，改呼叫 `show_result_panel(...)`：
  - **離開** → `finish(result)`（獎勵在此刻才結算，維持原契約 {id, score, win, gold, merit, karma}）。
  - **再玩一次** → 面板關閉＋遊戲場景內部 reset（各遊戲實作 `restart()`），**獎勵以最後一次為準**；105 打工的時段成本只在進場收一次，重玩不重扣。
- 21 點特例：多局制，維持局內橫幅；共用面板改掛在「離開賭桌」動作上，顯示整場統計（贏/輸局數、淨損益）。
- 支線觸發場次（木魚）：允許無限重試，離開時以最後一次勝負走 quest_win/quest_lose。

### 驗收
- 9 遊戲結束都停在面板，無任何遊戲直接跳出。
- 再玩一次可連續多輪、獎勵只算最後一次（以 gold/merit 斷言驗證）。
- TestMinigames 全數不退步；新增 TestResultPanel（面板出現、按鈕行為、獎勵時點）。

## 2. 第二期：木魚 → 「三僧木魚」（節奏天國式 call-and-response）

### 玩法（整支重寫 WoodenFishRhythm 的表現層，判定常數沿用）
- 畫面：黃昏街景，三個 Q 版和尚並排（構圖同使用者提供的三車截圖）：大師兄（高瘦）、二師兄（圓胖）示範，右側 = 無戒 Q 版（玩家）。
- 回合結構：大師兄敲 pattern → 二師兄原樣重複 → 玩家無縫跟拍（聽兩遍才上場，節奏天國慣例）。
- 12 回合曲目表：
  - R1–3：BPM 90，三連拍等間隔（摳 摳 摳）
  - R4–6：BPM 105，四連拍
  - R7–9：BPM 105，切分型（摳摳．摳／摳．摳摳）
  - R10–12：BPM 120，混合型＋背景干擾（煙火、路人穿過）但節奏不變
- 判定：±60ms Perfect(100)/±120ms Good(50)/其外 Miss，**時間基準取 AudioStreamPlayer 播放位置**（get_playback_position + AudioServer 補償），非幀數累計。顯示 Early/Perfect/Late。
- 回饋在角色上：Perfect＝木魚金光＋和尚彈跳微笑；Good＝點頭；Miss＝冒汗歪頭＋連段斷。
- 評級（按命中得分率）：<60% Try Again／60–79 OK／80+ Superb／全 Perfect 隱藏「入定圓滿」。win = OK 以上（維持 merit=3 契約）。

### 入口
- 既有劇情觸發不動（quests.json ah_ming/jie）。
- **新增常駐入口**：ah_ming 支線完成後，街頭藝人地圖互動點保留「再切磋一場」選項 → `go_to_minigame("wooden_fish_rhythm")` 無 quest context（休閒場，獎勵 intrinsic：win merit+1）。

### 美術/音訊資產（Q 版可愛風：flat colors, thick bold outlines, minimalist expressive faces）
- 三和尚立圖各 3–4 幀差分（idle/舉槌/敲擊/表情），木魚×3、黃昏街景背景 1 張（Magnific images_generate 生成，去背）。
- 音效：三個音高的「摳」×3、判定音、BGM 簡單 loop（magnific 音訊或現有素材）。

## 3. 第三期：端湯 → 第一人稱 3D 平衡

### 玩法（畫面/輸入重寫，計分公式沿用）
- Camera3D 第一人稱，畫面下緣手持托盤＋湯碗模型；WASD 移動、滑鼠左右＝托盤平衡修正（湯有慣性反向盪）、Shift 穩步（減速降晃）保留。
- 晃動模型：沿用 `step_slosh()` 公式，輸入源改為 3D 移動加速度＋滑鼠修正量；`settle_payout()` 分級計費、完美/連續 bonus 原樣保留（既有 TestSoupCarry 純邏輯測試繼續護航）。
- 場景：麵館內景一間（照 UndergroundParlor 室內做法＋現行 stylized 材質）：6–8 桌、NPC 客人（NpcFigure 重用，2–3 名會走動＝移動障礙，撞到 bump）、廚房出餐口。
- 流程：出餐口取碗 → 目標桌頭頂金箭頭 → 走到桌邊按 E 上菜 → 計費 → 下一碗；75 秒計時，看送幾桌。
- HUD：湯量條、平衡計（弧形儀表）、時間、已送桌數/收入。
- 評級接共用面板：沿用現有 payout 評級文字（神之端湯等）。

### 驗收
- TestSoupCarry 純邏輯全過不改斷言；新增 3D 場景冒煙（instantiate＋幀進不崩）＋GPU 截圖 QC。

## 4. 第四期：過場短片（開場 9 支＋結尾 18 支）

### 播放機制
- 新 `SceneRouter.play_minigame_cutscene(clip_id) -> Signal`：仿 play_battle_cutscene 的 CanvasLayer(128) 疊加逐幀播放（CutsceneScreen 格式：frame_%04d.png 12fps＋audio.ogg），**播完停在最後一幀**，await 後由呼叫端接手；按任意鍵可跳過（直接跳最後一幀）。
- 接線：
  - 開場：`go_to_minigame` 載入小遊戲場景後、遊戲開始前播 `minigame_<id>_intro`，最後一幀淡入遊戲。
  - 結尾：`_end()` → 依勝敗播 `minigame_<id>_win` / `minigame_<id>_lose` → 停最後一幀 → 結算面板疊上。
  - 「再玩一次」的重玩：開場片不重播；結尾片仍播（可跳過）。
  - 找不到片目錄時優雅跳過（沿用鳥居缺檔模式），不擋遊戲。

### 生成管線（**寫實風，與原遊戲一致**；主角＝無戒本尊）
1. `images_generate` 出每支片的起始格（16:9）：**雙參照**＝①該小遊戲**遊戲內實際背景圖**（去程式碼裡找它真正 load 的素材，如打擊場=art_direction/new_ink_shrine_style/minigames/shrine_games/batting_bg_shrine_v2.png）＋②無戒 cut 立繪（portraits/wujie/cut/wujie_ascetic.png）。prompt 要求把角色放進該場景、沿用兩參照的水墨水彩風（2026-07-04 使用者指正：不准憑文字想像場景，一律以遊戲內畫面為根據）。先出樣張給使用者確認再放量。木魚的 Q 版基底圖**不用於短片**。
2. `video_generate` slug=kling-25，5s/1080p/16:9，keyframes.start=起始格；每支 2 個 take 挑優。
3. ffmpeg 抽幀 12fps → `assets/cutscenes/minigame_<id>_<intro|win|lose>/`＋libvorbis 抽 audio.ogg（沿用既有過場管線）。

### 片單（27 支）
| 遊戲 | intro | win | lose |
|---|---|---|---|
| 木魚 | 盤坐持槌深呼吸 | 三僧齊敲金光沖天 | 和尚敲到自己手指 |
| 端湯 | 綁頭巾捧托盤上工 | 客滿鼓掌拋碗接住 | 滑倒湯灑一身 |
| 化緣 | 捧缽九十度鞠躬 | 缽滿元寶笑瞇眼 | 頭頂垃圾苦瓜臉 |
| 打擊 | 戴棒球帽舉棒（使用者例） | 全壘打目送球飛 | 揮空轉圈跌坐 |
| 保齡 | 捧球瞇眼瞄準 | 全倒跳躍擊掌 | 洗溝雙手抱頭 |
| 飛鏢 | 持鏢單眼瞄準 | 紅心三連中比讚 | 鏢插到牆上木板 |
| 輪盤 | 推籌碼吹口哨 | 籌碼堆成山 | 籌碼被耙走風中凌亂 |
| 21點 | 彈牌入手指尖轉 | 21 點亮牌攤手 | 爆牌牌散一地 |
| 香火 | 持香拜三拜 | 香入爐青煙成蓮花 | 香丟歪砸到銅鐘 |

### 預算（實測單價）
27 支 × 325 點 × 平均 2.5 take ≈ **22,000 點**；起始格生圖另約 1–2 千點。合計 <25% 餘額，可行。生成前逐支 simulate_cost 複核。

## 5. 第五期：化緣 → 「接缽化緣」（C 案重寫 BeggarChallenge）

### 玩法
- 2D 側視街景：和尚捧缽在畫面下緣，←→/A·D 左右移動；路人與二樓住戶往下丟落物。
- 落物表：銅板（+15，常見）、元寶（+80，稀有）、飯糰（功德 +1，偶爾）、垃圾（接到＝金 −30、combo 歸零、業障 +1）。
- combo：連續接到錢/飯糰 ×1.1 遞增倍率（上限 ×3），接垃圾或漏接歸零。
- 60 秒；難度曲線：後 20 秒落物加速加密、垃圾比例升。
- 計分：gold=score；merit=飯糰數＋(最高 combo/10)；karma=接到垃圾數。評級：分數門檻三級＋滿 combo 隱藏評級。
- 入口不變（105 打工＋地圖互動點），接共用結算面板。

### 驗收
- 純邏輯測試（落物判定、combo 倍率、業障計算）＋場景冒煙；TestMinigames 化緣段改寫。

## 6. 分期與驗收總表

| 期 | 內容 | 前置 | 驗收 |
|---|---|---|---|
| P1 | 共用結算面板＋9 遊戲接線 | — | fresh review＋TestResultPanel＋全回歸 |
| P2 | 三僧木魚重寫＋美術 | P1 | 純邏輯測試＋GPU 截圖＋fresh review |
| P3 | 端湯 3D 重寫 | P1 | TestSoupCarry 不退步＋冒煙＋截圖 |
| P4 | 過場管線＋27 支生成 | P1（P2/P3 完成後才生對應片） | 缺檔跳過測試＋實機播放 QC |
| P5 | 接缽化緣重寫 | P1 | 純邏輯測試＋fresh review |

共通鐵則：改動前跑基準測試；未經 fresh review 不結案；全程不 commit 等使用者實機過目；生成類先出 1 樣本確認方向再放量。
