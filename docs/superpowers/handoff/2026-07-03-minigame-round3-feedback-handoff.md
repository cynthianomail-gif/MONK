# 交接文件 — 小遊戲第三輪使用者回饋（給下一個 Claude session/帳號）

日期：2026-07-03 深夜
狀態：**✅已全部完工（2026-07-03 接手 session）**——三項修正＋FX 5 張圖（已交回）全接上，
TestMinigames ALL PASS、GPU 截圖驗證完畢（新工具 `test/CaptureBlackjackUI.tscn`／
`test/CaptureBowlingRoll.tscn`）。詳見 `PROJECT_STATUS.md` 2026-07-03 三度同日段。
剩餘＝21點程式版 UI 等使用者過目，不滿意才開 Codex UI 素材單（第五節 2）。
以下原文保留供追溯。

## 一、目前程式狀態（動工前先知道）

- 5 個小遊戲（darts/roulette/blackjack/batting/bowling）都在 `src/screens/Minigames/`，
  皆 `extends MinigameBase`，結束走 `finish(result)`。
- 2026-07-03 已完成兩輪大改：①Codex 近景圖全部接上（見
  `2026-07-03-parlor-minigames-implementation-handoff.md`）；②飛鏢改人中之龍式（滑鼠瞄準+
  力度條+301/COUNT-UP）、輪盤改點格下注（49 格點擊層+籌碼+真數字開獎）、保齡球改 Wii 式
  （移位+直/曲球+5局×2球補瓶制）、21點文字集中左上+結算底板。
- `test/TestMinigames.tscn` headless **ALL PASS**（跑法：
  `& "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestMinigames.tscn`）。
- GPU 截圖：`test/CaptureParlorGames.tscn -- smoke` → 專案根 `_darts/_roulette/_blackjack/_batting/_bowling_shot.png`。
- **未 commit**（整個 repo 累積多輪 session 的量，使用者沒要求就不要 commit）。
- 給 Codex 的 FX 需求已寫好但**圖還沒回來**：`2026-07-03-minigame-rework-fx-art-handoff.md`
  （chip_100/chip_500/fx_impact_burst/fx_gold_sparkle/fx_speed_trail 共 5 張）。
  程式已有 fallback（籌碼=程式畫圓片 `ChipDraw`），圖到即生效零改碼。

## 二、這輪使用者回饋（附人中之龍 21 點參考截圖，重點依序）

### A. 21點 → 改人中之龍式完整 UI（最大工程）

使用者給了兩張 Yakuza 21 點截圖當方向，要求四件事：

1. **左側直排動作選單**取代底部「〔空白鍵〕要牌」文字提示——
   仿截圖樣式：HIT／STAND／DOUBLE DOWN／SURRENDER 直排按鈕（深色底、選中項白底+
   ◆ 標記）。滑鼠點擊＋鍵盤↑↓/Enter 都要能操作。
   - 現有邏輯只有 要牌/停牌。**DOUBLE DOWN**（加倍：注×2、強制只補一張then停）跟
     **SURRENDER**（投降：拿回半注、棄局）邏輯簡單建議一起做；**SPLIT 不做**（要管兩手牌，
     複雜度不成比例）。
2. **開局下注階段**：點籌碼下注、籌碼淡入桌面中央下注圈，**一次 +100、最多點 10 次
   （上限 1000）**，右鍵收回；下好按「發牌」開局。籌碼圖沿用 FX handoff 的
   `chip_100_game_ready.png`（沒到之前用 Roulette.gd 裡的 `ChipDraw` 程式圓片，
   直接抄那段 class）。注額影響輸贏（BET 從 const 改成變數）。
3. **結算面板**：仿截圖 RESULT 樣式＝橫向半透明深色帶+金框標題+三行「押注／賠付／合計」
   數字右對齊。程式畫（Panel+StyleBoxFlat+Label）可以做到八成像；金藤蔓裝飾角要更華麗
   才需要 Codex（見第五節）。
4. **發牌動畫**：牌不能憑空出現——從**莊家牌靴飛出**（背景右上烤好的紅色牌靴，
   螢幕座標約 **(1490, 210)**）tween 到牌位（0.25s，帶少許旋轉），落定時翻面
   （scale.x 1→0 換貼圖→0→1 假 3D 翻牌）＋每張 `ui_select` 音效。莊家暗牌保持牌背。
   - 現在的 `_redraw_cards()` 是「全清掉重畫」——要改成**增量**：新牌才播動畫，
     舊牌不動；翻開暗牌時只翻那張（`_hole_card` 引用已存在）。

**21點桌面地標（螢幕座標 1920×1080，之前量好的）**：
莊家牌列 y=300、玩家牌列 y=705、中線 x=955、牌距 190、牌 scale 0.14；
中央下注圈（玩家唯一座位）≈ **(945, 735)**——下注籌碼疊這裡；
牌靴（發牌動畫起點）≈ **(1490, 210)**；左上 HUD 兩行維持現狀。

### B. 保齡球：瓶陣排反了＋位置偏差

- **排反**：現在 `_setup_pins()` 的 rows=[4,3,2,1] 配 `y = PIN_ROW_Y - r*26` ＝
  4 支瓶在最前面（最靠玩家）——**錯**。真保齡球是 1 號瓶（頭瓶）在最前、4 支在最後排。
  修法：改成前到後 1-2-3-4（`rows=[1,2,3,4]` 或 y 反向），且**前排瓶 scale 最大**
  （近大遠小，現在的 `0.042 - r*0.003` 方向也要跟著反）。
- **位置偏差**：瓶陣沒對準背景球道盡頭的暗色拱門瓶區。修法＝重跑格線量測
  （PowerShell System.Drawing 疊格線那招，本 session 用了三次都很準，
  參考 PROJECT_STATUS 2026-07-03 段）確認拱門開口的實際中心/深度，
  調 `LANE_CENTER_X`（現 976）跟 `PIN_ROW_Y`（現 590）。
  ⚠ PIN_ROW_Y 這個值本 session 已疊代三次（480→545→590），瓶陣整體有貼進拱門，
  但「排反」修正後行距/基準 y 都會變，要重新目測校一次。

### C. 飛鏢：鏢釘上去位置偏差（根因已查明）

`darts_dart_game_ready.png`（1254×1254）的鏢是斜放的：**針尖在右上 (1144,116)、
尾羽在左下 (156,1100)**（已用像素掃描確認：右上端非透明像素少=細針尖）。
現在程式把「貼圖中心 (627,627)」釘在落點 → 視覺上針尖偏離落點約 (+39,-39)px
（scale 0.076 時）。
**修法**：`Darts.gd` 裡所有鏢 sprite（`_dart` 和留靶的 `pin`）設
`offset = Vector2(-517, +511)`（=中心−針尖），讓「針尖」對齊 position。
留靶 pin 的隨機 rotation 會繞針尖轉（offset 之後 rotation 軸心就是針尖）——正好是對的行為。
判定本身（`dart_value`）沒錯，純視覺偏移。

### D. UI 美觀度原則（使用者原話）

「你可以做這種美觀簡單的ui嗎 不行的話 我一樣叫codex生圖片你套」——
方針：**先全程式畫**（深色板+金邊 StyleBoxFlat 的既有風格，Yakuza UI 本身就是扁平風，
程式畫可達八成）；做完截圖給使用者看，不夠好再開 Codex UI 素材單。
若要開單，建議項目：結算面板金藤蔓橫幅框（9-slice）、動作選單按鈕底框、
籌碼下注圈光環。**先不要主動生，等使用者看過程式版再說。**

## 三、建議施工順序

1. 飛鏢鏢尖 offset（5 分鐘，一行改動×2 處）
2. 保齡球瓶陣反向+重校位（半小時內）
3. 21點 Yakuza UI 全套（下注→動作選單→發牌動畫→結算面板，最大塊）
4. 每步跑 `TestMinigames` 回歸＋`CaptureParlorGames` 截圖目測
5. TestMinigames 的 21 點測試段要跟著改：BET 變成變數後，`round_payout` 簽名可能要帶注額；
   新增 double down/surrender 的純邏輯測試（加倍後注×2、投降拿回半注）

## 四、慣例提醒（每輪都要做）

- 改完同步 `PROJECT_STATUS.md`（探索地圖那一大行的尾巴）＋記憶
  `project_session_handoff.md`＋`MEMORY.md` 索引行（使用者的 feedback 記憶有明定：
  改程式必同步文件+記憶）。
- Label 疊複雜印刷背景必加 LabelSettings 描邊或深色底板（本 session 踩過）。
- 座標校正用「PowerShell System.Drawing 疊格線量背景圖」＋「量完換算 ×SX(1.14833)/×SY(1.14772)」。
- Godot：`--editor --quit --headless` 先跑一次讓新圖產 .import；
  截圖場景 root.add_child 要 call_deferred。

## 五、等 Codex 的圖（兩張單子都還沒交回）

1. `2026-07-03-minigame-rework-fx-art-handoff.md`：chip_100／chip_500／fx_impact_burst／
   fx_gold_sparkle／fx_speed_trail（5 張）。21點下注籌碼也吃 chip_100。
2. （尚未開單）21點 UI 素材——等程式版 UI 給使用者看過再決定要不要開。
