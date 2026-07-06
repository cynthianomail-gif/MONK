# Codex 生圖 handoff — 接缽化緣落物與角色（共 5 張）

日期：2026-07-04。化緣小遊戲已重寫為「接缽化緣」（和尚捧缽左右移動，接住路人與樓上住戶
丟下的錢、躲垃圾；combo 倍率、業障懲罰）。目前落物與玩家是程式繪製佔位
（黑描邊色塊＋單字標記），本單生正式圖。

## 落點（新資料夾，交回後由 Claude 加載入掛點接線）

`MONK/assets/2d/minigames/beggar/`
- `item_coin.png` — 銅板（+15，常見）
- `item_ingot.png` — 元寶（+80，稀有）
- `item_riceball.png` — 飯糰（功德 +1）
- `item_trash.png` — 垃圾（懲罰物）
- `player_bowl.png` — 玩家：無戒捧缽側身立姿

檔名照上表，不能變。

## 輸出格式

- **透明底 PNG（去背）**：白底出圖再去背，邊緣乾淨。
- 4 個落物：正方形構圖（建議 512×512），單一物件置中、佔畫面 70% 左右——遊戲內縮小顯示，輪廓要粗、剪影要一眼可辨（這 4 顆會高速墜落，辨識度優先於細節）。
- `player_bowl.png`：直式 2:3（建議 683×1024），全身、**側身朝左**（遊戲中落物從上方來，玩家橫向移動），雙手在身前捧一個化緣缽，缽口朝上明顯可見。

## 風格

與遊戲既有水墨線一致：**大神 okami 水墨/半寫實厚塗、game-ready**。
參考錨點：
- 遊戲內此關背景＝`MONK/assets/2d/backgrounds/bg_battle_wanhua.png`（水墨神社街雨夜）——落物與角色要壓得住這張底
- 無戒本人長相＝`MONK/assets/2d/portraits/wujie/cut/wujie_ascetic.png`（player_bowl 的臉/袍照這張）
- 落物配色沿用佔位的辨識邏輯：銅板亮金、元寶橘金、飯糰近白（海苔深色）、垃圾濁色（避免與錢同色系）

## 要生什麼（5 張）

| 檔名 | 說明 |
|---|---|
| `item_coin.png` | 中式方孔銅錢，亮金色，微透視斜角（墜落感），粗墨線 |
| `item_ingot.png` | 金元寶（船形），橘金色高光，比銅板更「貴」的存在感 |
| `item_riceball.png` | 三角飯糰，白飯＋海苔帶，可愛但不 Q 版（跟水墨底相容） |
| `item_trash.png` | 皺紙團／爛菜葉小垃圾袋，濁綠褐色，一看就不想接 |
| `player_bowl.png` | 無戒側身捧缽立姿：黑袈裟、光頭、表情專注微窘（化緣的尷尬感），缽為深色木缽 |

5 張墨線粗細、完成度一致；4 個落物彼此剪影差異要大（圓／船形／三角／不規則）。

## 交回後我（Claude）會做

1. 去背品質檢查 → 入資料夾 → 在 `BeggarChallenge.gd` 的 `_add_drop()`／玩家節點加
   `ResourceLoader.exists` 載入掛點（缺檔仍走佔位，零風險）→ `--headless --import`。
2. 跑 `TestMinigames`＋`TestResultPanel` 回歸、重截 `CaptureBeggarBowl` 自檢辨識度。
3. 落物實際顯示尺寸與佔位不同的話，微調 scale 常數（僅視覺層）。
