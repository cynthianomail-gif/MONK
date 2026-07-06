# Codex 生圖 handoff — 具名配角立繪（3 張）

日期：2026-07-06。背景：全劇情旁白改成有立繪的人物對話後，原本「無立繪、只在旁白裡用引號講話」
的配角，全部升級成正式 Dialogic 說話者。其中「打手型」配角直接沿用既有敵人立繪即可
（無須生圖，見文末），但以下 3 個**具名、有戲份**的配角目前暫借了身分不符的立繪佔位，需生正式圖。

## 落點與檔名（交回後由 Claude 接線：去背→放檔→改 .dch image 路徑→--import）

`MONK/assets/2d/portraits/npcs/bust/`（與其他 NPC 胸像同目錄）

| 檔名 | 角色 | 目前暫借（要換掉） |
|---|---|---|
| `npc_hayashida.png` | 林田 | 暫借 enemy_vendor.png |
| `npc_lao_zhang.png` | 老張 | 暫借 npc_lao_wang.png |
| `npc_kenta_father.png` | 健太父 | 暫借 npc_david.png |

## 輸出格式（與現有 NPC 胸像一致）

- 透明底 PNG（去背），胸像裁切（頭＋上半身），直式 2:3 或近正方，尺寸對齊 `npcs/bust/` 現有檔
- 風格：**大神 okami 水墨/半寫實厚塗、game-ready**，與 `npc_david.png`／`npc_zheng_ma.png` 等同一畫師同一遊戲
- 一律帶無戒基準當畫風參考鎖風格（`assets/2d/portraits/wujie/cut/wujie_ascetic.png`），避免跑成寫真

## 三個角色設定（供 prompt）

| 角色 | 設定 | 神情 |
|---|---|---|
| **林田**（`npc_hayashida`） | 「林田投資」的老闆，六十上下、髮鬢斑白、西裝筆挺的生意人。二十年前侵吞了合夥人源造的錢財致其潦倒，晚年設帳戶暗中償還、夜夜難眠。 | 表面體面、眼底藏著二十年的愧疚與不安，一個「衣冠楚楚卻良心未泯」的老人 |
| **老張**（`npc_lao_zhang`） | 櫻木町巷子裡賣了半世紀醬料的老攤主，滿臉風霜、渾濁的眼。與另一支線的老廚師大村是舊識，念舊重情。 | 溫厚、憨直、帶點市井老攤販的江湖氣，笑起來眼睛瞇成一條縫 |
| **健太父**（`npc_kenta_father`） | 中年男人，風塵僕僕，為生計長年在外地工作、丟下兒子健太與老母（婆婆）。辭了工作回來相認，手裡提著水果。 | 侷促、愧疚、想彌補卻不知如何開口的中年父親，眼眶泛紅 |

## 打手型配角（無須生圖，已沿用敵人立繪，供參考）

以下 3 個已直接指向既有敵人立繪，貼題（本就是保全／混混），**除非你想要專屬圖，否則不用生**：
- 警衛（Guard）／安保隊長（SecurityChief）→ `assets/2d/portraits/enemies/enemy_guard.png`
- 討債的（DebtCollector）→ `assets/2d/portraits/enemies/enemy_punk.png`

## 交回後我（Claude）會做

1. 去背/裁切一致性檢查 → 放入 `npcs/bust/` → 改對應 .dch（Hayashida/LaoZhang/Kenta_Father）的 image 路徑 → `--headless --import`。
2. 跑 TestAllDialogue／TestDialogueSlice 回歸，確認角色載入正常。
