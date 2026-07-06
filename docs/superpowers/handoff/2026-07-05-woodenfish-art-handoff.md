# Codex 生圖 handoff — 三僧木魚全套美術重生（共 14 張）

日期：2026-07-05。使用者對現行木魚小遊戲美術不滿意，全套重生。
玩法背景：節奏天國式 call-and-response——大師兄（monk_a）、二師兄（monk_b）先示範敲木魚，
玩家（player）跟拍。角色圖依遊戲狀態換幀（idle→raise 舉槌→hit 敲下），MISS 時兩位師兄
會轉頭斜眼看玩家（look_right）。

## 落點（同名覆蓋，檔名不能變）

`MONK/assets/2d/minigames/woodenfish/`

| 檔名 | 內容 | 尺寸 |
|---|---|---|
| `bg.png` | 禪房背景（三個蒲團位、木魚擺位、暖色燭光） | 1376×768，不透明 |
| `monk_a_idle.png` | 大師兄 盤坐持槌待機 | 1024×1024，透明底 |
| `monk_a_raise.png` | 大師兄 舉槌 | 1024×1024，透明底 |
| `monk_a_hit.png` | 大師兄 敲下（槌觸木魚瞬間） | 1024×1024，透明底 |
| `monk_a_look_right.png` | 大師兄 轉頭向畫面右方斜眼（面癱嫌棄） | 1024×1024，透明底 |
| `monk_b_idle.png` / `_raise` / `_hit` | 二師兄 同上三態 | 1024×1024，透明底 |
| `monk_b_look_right.png` | 二師兄 轉頭斜眼（驚訝張嘴） | 1024×1024，透明底 |
| `player_idle.png` / `_raise` / `_hit` | 玩家無戒 同上三態 | 1024×1024，透明底 |
| `player_happy.png` | 無戒 開心（連擊/Perfect 用） | 1024×1024，透明底 |
| `player_sweat.png` | 無戒 冒汗尷尬（MISS 用） | 1024×1024，透明底 |

## 風格

**Q 版可愛風：flat colors、粗黑輪廓、極簡表情五官**（節奏天國/リズム天国 系美術邏輯：
回饋靠姿勢與表情誇張，不靠細節）。
風格基底（使用者已拍板 V1）：`MONK/docs/superpowers/specs/2026-07-04-minigame-style-base-v1.jpg`。

角色辨識：三人都是光頭小和尚 Q 版。大師兄＝灰袍、體型壯；二師兄＝綠袍、瘦高；
玩家無戒＝黑袍（呼應本尊黑袈裟）。每人身前一顆木魚＋手持木槌。

## 一致性鐵則（上一版最大的問題）

1. **同一角色跨幀完全同一人**：臉、袍色、木魚、槌，只有姿勢/表情變。強烈建議每個角色
   一次生一張四格 pose sheet（idle/raise/hit/look_right）再切圖，別四張分開生。
2. 三個角色彼此的線寬、頭身比、上色風格一致（同一批生）。
3. 角色在 1024×1024 內置中、腳底對齊（遊戲直接同位置換圖，位移會抖動）。
4. hit 幀可以加簡單的敲擊星星/音波小特效，raise 幀槌子舉過頭。

## ⚠ 目錄現況注意

資料夾裡有一批 `regen_*` 檔案（regen_characters/、regen_frames/、regen_*_strip.png）——
來源待確認，**不要**覆蓋或引用它們；只交付上表 14 個正式檔名。

## 交回後 Claude 會做

1. 逐張 QC（跨幀一致性、去背邊緣）→ 同名覆蓋 → `--headless --import`。
2. 跑 TestWoodenFish/TestMinigames/TestResultPanel 回歸 → GPU 重截 3 張對照。
