# 主畫面微動態設計規格（2026-07-09，使用者拍板 A 案）

## 概要

TitleScreen 從純黑底+程式字升級為「一僧當關」分層動態畫面：
無戒背影立於前景，山門框景，遠眺新梵市天際線＋萬神殿大樓霓虹，暮色水墨晚霞。
微動態全程式（tween/shader/GPUParticles2D），零生成點數、無縫循環、不動 addons。
題字採 Codex 書法圖（L4），取代程式 Label。

## 分層（Codex 交付，詳見 handoff/2026-07-09-title-art-handoff.md）

全部層同畫布 **2304×1296**（=1920×1080 的 120%，超出部分是視差與雲移邊距），
同座標對位、疊起來＝合成版。落點 `assets/2d/title/`：

| 層 | 檔名 | 透明 | 內容 |
|---|---|---|---|
| L0 | bg_sky.png | 否 | 暮色水墨晚霞＋雲 |
| L1 | city.png | 是 | 新梵市天際線＋萬神殿大樓（霓虹） |
| L2 | gate.png | 是 | 山門/簷 左側框景 |
| L3 | monk.png | 是 | 無戒背影（右下前景） |
| L4 | logo_calligraphy.png | 是 | 書法「和尚逆天」直排＋Monk Go Rogue 落款（右上） |

## 微動態（穩重版參數，全部檔頭常數可調）

| # | 元素 | 做法 | 參數 |
|---|---|---|---|
| 1 | 雲層流動 | L0 shader UV 水平捲動 | 90s/輪無縫 |
| 2 | 霓虹明滅 | L1 上疊 additive 小光點（程式生成，非美術） | 每點 3–7s 隨機 |
| 3 | 香灰/花瓣粒子 | GPUParticles2D | 8–12 顆慢降+橫飄 |
| 4 | 主角呼吸 | L3 掛 BreathingFigure（戰鬥既有元件） | 4s 週期、幅度 0.5% |
| 5 | 滑鼠視差 | 各層依深度反向偏移＋lerp 平滑 | L0=1px→L3=6px；L4 不動 |
| 6 | 題字入場 | L4 淡入+墨暈擴散（一次性），idle 金邊呼吸 | 入場 1.2s |

## 版面配置

- 題字 L4＝右上直排；按鈕移到左中下（該區背景要求暗色沉穩，金字可讀）；
  主角 L3＝右下前景；城市＝中景偏中右；山門 L2＝左側框景
- 現有三按鈕文字/邏輯（含 J3 多槽「繼續」）**不動**，只動位置與容器
- Version 標籤右下角保留

## 實作

- `TitleScreen.tscn`：Background ColorRect 之上加 `AmbientLayers` 節點組；
  新 `src/screens/TitleScreen/TitleAmbient.gd` 管全部動態
- 全層 `ResourceLoader.exists` fallback：任一層缺檔→跳過該層；全缺＝現行黑底＋程式字照舊
- L4 到位時隱藏程式 Title/Subtitle Label；缺 L4 則保留程式字
- 不動 addons/；BreathingFigure 沿用不改

## 驗收

- 間隔 3s 雙截圖 diff 非零（動態確實在跑）＋逐層目視
- TestMainEntry、TestMenuSystem 回歸零新增 FAIL
- 新 TestTitleAmbient：層節點存在性/缺檔 fallback/按鈕功能不受影響
- 實機：動態幅度手感（參數全為常數，穩重版起步再調）

## 流程

Codex 兩階段：①先交 1 張合成定調版（使用者過目構圖/色調）②過了再交分層。
分層回來後 Claude 接線（campture 疊層對位驗證）→ fresh review → commit。
