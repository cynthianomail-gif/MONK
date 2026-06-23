# game_ready 全卡司接進遊戲 — 整合設計

日期：2026-06-23
狀態：設計（待使用者選執行範圍）
關聯：Codex 生的 `assets/art_direction/new_ink_shrine_style/characters/game_ready/`（全卡司新水墨）、`gods/concepts/`（12 神 16:9）、現有立繪系統（[[project-dialogue-vn-style]] VN bust／[[project-battle-standing-figures]] 站姿）、`src/screens/BattleScreen/battle_art.gd`、`dialogue/*.dch`、Codex `ARES_VFX_HANDOFF.md`。

## 目標
把 Codex 已生的整套 game_ready 立繪（半寫實厚塗、全身透明底）接進遊戲，替換現役舊厚塗立繪——VN 對話框、戰鬥站姿、敵人、阿瑞斯 boss。**核心策略＝同路徑覆蓋（in-place），讓 `.dch`／`battle_art`／cutscene 零改碼。**

## 已驗證的關鍵事實
- **裁 bust 機制可行**（PIL 12.2.0）：全身 1024×1536 透明圖 → 取 alpha bbox → 裁 `top → top+0.50×身高`、寬＝高×0.95、水平置中 → 乾淨頭+上半身胸像（已驗 `_bust_test_lao_wang.png` 702×740，臉完整框準）。
- **表情圖有差異**：wujie/cherry 的 `emote_*` 是不同臉（calm/angry/happy/surprised、neutral/smile/angry/sorrow）→ 可 1:1 替換現有 4 表情 VN。
- **現有落點**（替換目標，路徑不動）：`wujie/bust/wujie_ascetic_{calm,angry,happy,surprised}.png`、`cherry/bust/cherry_{neutral,smile,angry,sorrow}.png`、`npcs/bust/npc_{10人}.png`、`wujie/cut/wujie_{ascetic,chanter,beggar}.png`(戰鬥背面)、`enemies/`、`boss/`。
- game_ready 全身 1024×1536 RGBA、舊 bust ~500×526 RGBA。

## 映射規則（game_ready → 遊戲落點，全部 in-place 覆蓋）

### VN 對話胸像（裁 bust，覆蓋現有 bust 路徑；零改碼）
| game_ready 來源 | → 覆蓋 | 數 |
|---|---|---|
| `wujie_ascetic_emote_{calm,angry,happy,surprised}_front` | `2d/portraits/wujie/bust/wujie_ascetic_{calm,angry,happy,surprised}.png` | 4 |
| `cherry_geisha_emote_{neutral,smile,angry,sorrow}_front` | `2d/portraits/cherry/bust/cherry_{neutral,smile,angry,sorrow}.png` | 4 |
| `{ah_ming,rei,jie,zheng_ma,ah_zhong,cai_ma,david,lao_wang,grandma,liaochen}_front_ares_red` | `2d/portraits/npcs/bust/npc_{name}.png` | 10 |
| `ares_emote_{neutral,mocking_laugh,pained}_front_black_red` | `2d/portraits/boss/ares_{base,mocking_laugh,pained}.png` | 3 |
| `tie_shu_{locked,freed}_front_ares_red`（待 Codex） | `2d/portraits/npcs/bust/npc_tie_shu_{locked,freed}.png` | 2 |

### 戰鬥站姿（全身，縮放/去背即用，覆蓋 cut/ 與 enemies/）
| game_ready 來源 | → 覆蓋 | 說明 |
|---|---|---|
| `wujie_{ascetic,chanter,beggar}_back` | `2d/portraits/wujie/cut/wujie_{job}.png` | 玩家背面站姿（戰鬥） |
| `wujie_ascetic_hurt_back` | `2d/portraits/wujie/cut/wujie_ascetic_hurt.png` | 受傷態（僅 ascetic 有；chanter/beggar 受傷暫共用 normal 或缺） |
| `enemy_{punk,guard,vendor,ghost,shrine_ghost}_front_ares_red` | `2d/portraits/enemies/enemy_{name}.png` | 敵人正面站姿 |
| `ares_front_black_red`、`ares_phase2_front_black_red` | `2d/portraits/boss/` + Phase 3 VFX | boss 本體 |

> ⚠ 確切檔名以現有 `battle_art.gd`／`enemies.json`／`boss.json` 既有命名為準，Phase 0 建 manifest 時逐一對齊（避免裁完落錯名）。

## 分階段執行（建議順序＝風險低→高、DEMO 價值高→低）

### Phase 0：裁切工具 + manifest
- `tools/crop_bust.py`：吃 (src, out, top_frac=0.50, aspect=0.95)，alpha bbox → 裁 → 存。已驗證邏輯，formalize 成可重跑腳本。
- `tools/cast_manifest.json`（或 .py dict）：列每張 game_ready → 目標路徑 + 處理方式（bust 裁切 / 全身去背縮放）。對齊現有檔名。

### Phase 1：VN 對話胸像（21 張，零改碼，最高 CP）
裁所有 front/emote → 覆蓋現有 bust 路徑 → `--import` → windowed 開一段對話截圖（如 Cherry 初遇／鄭媽店）自檢 → 確認 VN 左下大胸像換新風格、名牌/文字框不變。鐵叔 2 態也在此（Codex 圖到就裁）。**回歸**：`TestAllDialogue` ALL PASS（路徑沒變、純換圖，不應破）。

### Phase 2：戰鬥站姿（玩家背面 + 敵人正面，零/微改碼）
全身去背縮放到現有 cut/、enemies/ 尺寸 → 覆蓋 → `--import` → windowed 進一場戰鬥截圖（無戒背面雙態 + 敵人正面 + 呼吸）自檢。**回歸**：`TestBattleArt`／`TestBattleStandingFigures` ALL PASS。

### Phase 3：阿瑞斯 boss 靜態 sprite + VFX 層系統（大塊，照 Codex `ARES_VFX_HANDOFF.md`）
本體靜態 sprite（idle/attack/phase2 換圖）+ 10 張 FX overlay（待機霧×2、火星粒子、受擊、攻擊爆發、蓄力、警示圈、彈道、命中爆炸、二階轉場、擊敗溶解）用 Godot Tween/CPUParticles 編排。受擊用程式閃紅+shake（不換 hurt 圖）。節點結構/參數 Codex 都給了。**這是 BattleScreen 的新子系統，建議獨立寫 plan 再執行。**

### Phase 4（DEMO 後，延後）：12 神概念圖
`gods/concepts/*_16x9.png`：DEMO 只做 ch1（阿瑞斯），其餘 11 神屬 ch2-12。先只接阿瑞斯相關（過場/splash），其餘存著待後續章節。16:9 偏 key-art/過場用，非 VN/戰鬥站姿。

## 決策（lazy-correct，待使用者確認）
1. **同路徑覆蓋（in-place）**：Phase 1-2 零改碼（`.dch`/`battle_art` 路徑全不動，只換圖）。← 強烈建議。
2. **PIL 裁切工具**（已驗證）做 bust；全身站姿只縮放去背。
3. **DEMO 範圍**：先 Phase 1-2（＋Phase 3 阿瑞斯），12 神延後。
4. **原圖保留**：`art_direction/.../game_ready/` 當 source 永久留；遊戲用 `2d/portraits/` 下的裁切/縮放副本。舊厚塗立繪被覆蓋前先不另備份（git 可復原）。

## 待使用者選的執行範圍
- **A**：只 Phase 1（VN 胸像，最快見效、零風險）。
- **B**：Phase 1+2（VN＋戰鬥站姿，DEMO 戰鬥/對話全換新皮）。← 建議
- **C**：Phase 1+2+3（再加阿瑞斯 boss VFX 系統，最完整但 Phase 3 工大）。
- 12 神（Phase 4）一律延後到 DEMO 後。

## 驗證慣例
每 Phase：覆蓋 → `--import` → windowed 截圖自檢（VN 對話／戰鬥場）→ 跑對應回歸（TestAllDialogue／TestBattleArt／TestBattleStandingFigures）→ 無 SCRIPT ERROR。鐵叔 bust 待 Codex 圖到補裁。
