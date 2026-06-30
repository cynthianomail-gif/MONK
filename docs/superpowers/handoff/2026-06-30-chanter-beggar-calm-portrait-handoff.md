# Codex 生圖 handoff — 無戒 chanter / beggar 的「calm 正面表情」(2 張)

日期：2026-06-30
給：Codex（角色立繪生成）
落點：`MONK/assets/art_direction/new_ink_shrine_style/characters/game_ready/`

## 要生什麼

無戒(主角)有三套職業立繪：**ascetic(苦行僧)/ chanter(誦經僧)/ beggar(行腳僧)**。
表情立繪目前狀態：

| 職 | neutral/calm | angry | happy | surprised |
|---|---|---|---|---|
| ascetic | ✅ | ✅ | ✅ | ✅ |
| **chanter** | ❌ **缺** | ✅ | ✅ | ✅ |
| **beggar** | ❌ **缺** | ✅ | ✅ | ✅ |

→ **只缺 chanter 與 beggar 的「calm(平靜)正面表情」各 1 張，共 2 個角色 × 各 2 檔（source + game_ready）。**

**為什麼要補**：戰鬥畫面玩家立繪預設載入 `wujie_<職>_calm`（HP 正常時的臉），低 HP 才換 `_angry`。chanter/beggar 沒有 calm → 切到這兩職時戰鬥預設臉會缺。

## 輸出檔（命名＋格式，務必照既有規格）

每個角色 2 檔（同既有表情立繪的雙檔慣例）：

```
wujie_chanter_emote_calm_front_source_chromakey.png   # 生成原檔：色鍵(綠幕)底, RGB, ~941×1672
wujie_chanter_emote_calm_front_game_ready.png         # 去背成品：透明底, RGBA, ~1024×1536
wujie_beggar_emote_calm_front_source_chromakey.png
wujie_beggar_emote_calm_front_game_ready.png
```

- 全部落 `MONK/assets/art_direction/new_ink_shrine_style/characters/game_ready/`
- `source_chromakey` = 純色鍵背景（同既有 `*_source_chromakey.png`，便於去背）
- `game_ready` = 去背透明 PNG（RGBA），尺寸/裁切對齊既有 game_ready 表情立繪

## 參考圖（鎖風格＋身份，務必餵給生成）

**表情(calm 長怎樣)** ← 對齊這張：
- `wujie_ascetic_emote_calm_front_game_ready.png`（苦行僧的 calm＝平靜、眼神沉穩、無怒無驚，半垂眼的禪定感）

**該職的身份/袈裟/臉** ← 對齊這幾張（同一個無戒、同一套該職服裝，只是換 calm 表情）：
- chanter：`wujie_chanter_front_game_ready.png` ＋ `wujie_chanter_emote_angry/happy/surprised_front_game_ready.png`
- beggar：`wujie_beggar_front_game_ready.png` ＋ `wujie_beggar_emote_angry/happy/surprised_front_game_ready.png`

## 規格重點

- **同一個主角無戒**：光頭、風霜的臉、破舊水墨厚塗 game_ready 畫風（okami 暗金 tone）。**不可畫風漂移**——必須跟既有 game_ready 全卡司同一條線。
- **構圖/景別**：正面、與既有 `*_emote_*_front` 同框（半身～全身一致，臉部位置/比例對齊既有 3 表情，這樣引擎切表情不會跳）。
- **表情＝calm**：平靜、放鬆、禪定；不是微笑(happy)、不是皺眉(angry)、不是瞪眼(surprised)。直接參考 ascetic_calm 的神態，換成該職的袈裟與身形。
- **服裝差異**：chanter＝誦經僧（持珠/法衣感）；beggar＝行腳僧（破舊、行腳裝）——照各職既有立繪的服裝，別混。

## 交回後我(Claude)會做

拿到 game_ready 透明檔後我直接接引擎（同路徑覆蓋/新增，戰鬥 PlayerPortrait 依 `wujie_<職>_calm` 自動載入，零改碼或極小改）。先丟一張看方向對齊再補另一張也可以。

---

### 附：本 DEMO 其餘缺口（非 Codex，記著就好）
- 12 神介紹 CG 接線（概念圖 `gods/concepts/*_16x9.png` 已生＝Codex 早做好，**只差我接進 `main_ch1_aftermath.dtl`**，非 Codex 工）。
- ch1 阿瑞斯總部 HQ 背景 okami 化（`hq_exterior` 是**背景**＝走 Magnific，非 Codex）。
- 實機 GPU 跑一次 ch1（驗收，非生圖）。
