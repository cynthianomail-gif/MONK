# Codex 生圖 handoff — 戰鬥背景重生（去雜點版，共 5 張）

日期：2026-07-03。使用者回饋：**現行戰鬥背景為了強調水墨感加了太多雜點（噴濺、飛白、碎墨點），畫面髒。
不需要那麼多雜點——就正常的、有景深、能襯托敵人立繪的戰鬥背景就好。**

## 落點（同名覆蓋，程式零改碼即生效）

`MONK/assets/2d/backgrounds/`
| 檔名 | 場景 |
|---|---|
| `bg_battle_ximen.png` | 西門/神社區戰鬥（櫻木町水墨夜街）——出場頻率最高，優先做這張給使用者確認方向再做其餘 4 張 |
| `bg_battle_wanhua.png` | 萬華老區戰鬥 |
| `bg_battle_linsen.png` | 林森戰鬥 |
| `bg_battle_pantheon.png` | 萬神殿戰鬥 |
| `bg_battle_ares_forge.png` | 阿瑞斯熔爐（boss 戰）|

載入點：`src/screens/BattleScreen/battle_art.gd` 的 `DISTRICT_BG`＋`boss.json` 的 `battle_bg`，皆按檔名載入。

## 輸出格式

背景類：RGB、16:9（1672×941 或等比更高），**不去背**。

## 風格要求（本單的重點）

- 仍是大神 okami 水墨線，但**乾淨版**：雜點/噴墨/飛白紋理大幅減量，只留必要的墨韻。
- **要有景深**：前景（地面/道具剪影）→ 中景（敵人站位帶，保持乾淨低對比，敵人立繪要壓得上去）→ 遠景（街景/建築，霧化推遠）。
- 中景敵人站位帶（畫面中央偏上 1/3 區）避免高對比細節與亮色塊——敵人立繪與傷害漂浮字都疊在這區。
- 保留各區辨識度（夜街霓虹、老區磚木、熔爐火光等），配色仍以墨黑灰為體、朱紅（#C93A2E 系）點綴，不要大面積紅。
- 參考現行同名檔案的構圖與場景內容（就地看 `assets/2d/backgrounds/` 裡的舊圖），本單是「同構圖降噪重畫」不是換場景。

## 交付順序

先交 `bg_battle_ximen.png` 一張 → 使用者過目確認「乾淨程度」方向 → 再出其餘 4 張（避免 5 張全部重來）。

## 交回後 Claude 會做

1. 同名覆蓋 → `--headless --import` → windowed 跑 `test/CaptureOverhaul.tscn` 重截戰鬥全景自檢（敵人立繪/漂浮字在新背景上的可讀性）。
2. 跑 TestBattleArt / TestBattleOverhaul 回歸。
