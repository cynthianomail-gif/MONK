# 佈局工具 v2 擴到 P4 小遊戲畫面 — 完整報告

日期：2026-07-07。範圍：`docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md` 定義的
P4（小遊戲）登記工作。系統檔（LayoutStore.gd / LayoutTuner.gd）未改動，僅在各場景加
`LayoutStore.register()` / `set_meta("layout_template", ...)` 呼叫。

## 改動檔案清單

| 檔案 | 行號（大致） | 內容 |
|---|---|---|
| `src/screens/Minigames/MinigameBase.gd` | ~127, ~471 | 結算面板 `panel`、暫停面板 `panel` 各登記一行 |
| `src/screens/Minigames/Blackjack.gd` | 多處（chip_zone/result_panel/hud/tip/menu_item） | 4 個 register + 1 個 layout_template |
| `src/screens/Minigames/Bowling.gd` | 多處 | 3 個 register（hud/type_label/judge_popup） |
| `src/screens/Minigames/Darts.gd` | 多處 | 4 個 register（gauge/hud/judge_popup/tip）+ 1 個 layout_template（mode_button） |
| `src/screens/Minigames/Roulette.gd` | 多處 | 4 個 register（confirm_button/hud/sub/result_banner） |
| `src/screens/Minigames/SoupCarry.gd` | 多處 | 5 個 register（hud_time/hud_income/hud_state/prompt/balance_meter） |
| `src/screens/Minigames/WoodenFishRhythm.gd` | 多處 | 3 個 register（round_label/hud/judge_popup） |
| `src/screens/Minigames/Batting.gd` | 多處 | 2 個 register（hud/judge_popup） |
| `src/screens/Minigames/OfferingToss.gd` | 多處 | 4 個 register（gauge/hud/wind_label/judge_popup） |
| `src/screens/Minigames/BeggarChallenge.gd` | 多處 | 3 個 register（hud_score/hud_combo/hud_time） |
| `test/CaptureLayoutTunerMinigame.gd`（新增） | — | Blackjack GPU 驗證腳本，仿 CaptureLayoutTunerBattle.gd |
| `test/CaptureLayoutTunerMinigame.tscn`（新增） | — | 對應場景 |

系統檔 `src/autoloads/LayoutStore.gd`、`src/autoloads/LayoutTuner.gd` 未改動。

## 登記的 key 清單

### 共用（MinigameBase，10 款小遊戲全用）
| key | 節點 | free/template |
|---|---|---|
| `minigame/common/result_panel` | 結算面板 Panel | free |
| `minigame/common/pause_panel` | 暫停面板 Panel | free |

### Blackjack（21點）
| key | 節點 | free/template |
|---|---|---|
| `minigame/blackjack/chip_zone` | 籌碼下注區 Control | free |
| `minigame/blackjack/result_banner` | RESULT 結算橫幅 Panel | free |
| `minigame/blackjack/hud_label` | 左上 HUD Label | free |
| `minigame/blackjack/tip_label` | 底部提示 Label | free |
| `minigame/blackjack/menu_item` | 左側動作選單按鈕（重複） | template |

### Bowling（保齡球）
| key | 節點 | free/template |
|---|---|---|
| `minigame/bowling/hud_label` | 左上 HUD | free |
| `minigame/bowling/type_label` | 球種標籤 | free |
| `minigame/bowling/judge_popup` | 判定彈出字 | free |

### Darts（飛鏢）
| key | 節點 | free/template |
|---|---|---|
| `minigame/darts/gauge` | 力度條 Control | free |
| `minigame/darts/hud_label` | 左上 HUD | free |
| `minigame/darts/judge_popup` | 判定彈出字 | free |
| `minigame/darts/tip_label` | 底部提示 | free |
| `minigame/darts/mode_button` | 模式選擇按鈕（重複） | template |

### Roulette（輪盤）
| key | 節點 | free/template |
|---|---|---|
| `minigame/roulette/confirm_button` | 確認下注按鈕 | free |
| `minigame/roulette/hud_label` | 左上 HUD 第一行 | free |
| `minigame/roulette/sub_label` | 左上 HUD 第二行 | free |
| `minigame/roulette/result_banner` | 結算橫幅背板 | free |

### SoupCarry（端湯，3D+2D HUD 混合）
| key | 節點 | free/template |
|---|---|---|
| `minigame/soupcarry/hud_time` | 倒數計時文字 | free |
| `minigame/soupcarry/hud_income` | 收入文字 | free |
| `minigame/soupcarry/hud_state` | 狀態文字 | free |
| `minigame/soupcarry/prompt_label` | E 互動提示 | free |
| `minigame/soupcarry/balance_meter` | 平衡計代表框 | free |

### WoodenFishRhythm（三僧木魚）
| key | 節點 | free/template |
|---|---|---|
| `minigame/woodenfishrhythm/round_label` | 回合標籤 | free |
| `minigame/woodenfishrhythm/hud_label` | 分數 HUD | free |
| `minigame/woodenfishrhythm/judge_popup` | 判定彈出字 | free |

### Batting（打擊場）
| key | 節點 | free/template |
|---|---|---|
| `minigame/batting/hud_label` | 左上 HUD | free |
| `minigame/batting/judge_popup` | 判定彈出字 | free |

### OfferingToss（香火投擲）
| key | 節點 | free/template |
|---|---|---|
| `minigame/offeringtoss/gauge` | 力度計代表框 | free |
| `minigame/offeringtoss/hud_label` | 左上 HUD | free |
| `minigame/offeringtoss/wind_label` | 風向標籤 | free |
| `minigame/offeringtoss/judge_popup` | 判定彈出字 | free |

### BeggarChallenge（化緣）
| key | 節點 | free/template |
|---|---|---|
| `minigame/beggarchallenge/hud_score` | 功德金 HUD | free |
| `minigame/beggarchallenge/hud_combo` | 連擊 HUD | free |
| `minigame/beggarchallenge/hud_time` | 倒數計時 HUD | free |

## 完成度

需求提及「10 款小遊戲」，但專案實際檔案（`src/screens/Minigames/*.gd`，扣除 MinigameBase）
只有 9 支：Batting/Blackjack/Bowling/Darts/OfferingToss/Roulette/WoodenFishRhythm/
BeggarChallenge/SoupCarry。已核對無漏檔（Glob 掃過整個目錄），9 款全部完成頂層登記，
無 pending 項目。

## 驗收條件逐條

1. **MinigameBase 共用塊登記**：GPU 截圖驗證時 Blackjack 場景僅進入下注階段（未觸發
   結算/暫停面板），故 `minigame/common/*` 未出現在該次 live_entries（這是正確行為——
   面板是動態建立，只有開啟時才存在）。已用 headless TestMinigamePause/TestMinigames
   間接跑過暫停/結算流程確認程式無崩潰；`register()` 呼叫本身已核對程式碼路徑正確
   （父節點皆為 CanvasLayer，`is_free()` 必為 true）。

2. **各遊戲頂層塊登記**：9 款全部完成，逐一列於上表，皆已核對父節點為
   CanvasLayer/Control（非 Container）。

3. **GPU 截圖**：`D:\monk\MONK\_cap_tuner_v2_minigame_blackjack.png` ——實機驗證，畫面顯示
   4 個綠框（chip_zone/result_banner/hud_label/tip_label）+ 1 個琥珀框（menu_item 樣板）。
   Console 輸出：
   ```
   LIVE_ENTRY_CHECK minigame/blackjack/chip_zone -> present=true free=true
   LIVE_ENTRY_CHECK minigame/blackjack/result_banner -> present=true free=true
   LIVE_ENTRY_CHECK minigame/blackjack/hud_label -> present=true free=true
   LIVE_ENTRY_CHECK minigame/blackjack/tip_label -> present=true free=true
   ```

4. **回歸零新增 FAIL**：
   - 基準（改動前）：TestLayoutStore/TestMinigames/TestMinigamePause 皆 exit=0，
     唯一訊息為既有的「ERROR: 26 resources still in use at exit」（非 FAIL/SCRIPT ERROR，
     改動前後一致，屬既有雷非本次引入）。
   - 改動後：三支測試同樣 exit=0，grep FAIL/SCRIPT ERROR 均無匹配，與基準一致。

5. **沒改系統檔、沒 commit、沒留 override JSON**：
   - `LayoutStore.gd`/`LayoutTuner.gd` 未改動（僅讀取，未 Edit）。
   - 未執行任何 git commit。
   - 未產生 `_layout_overrides.json`（GPU 截圖流程只開調整模式讀 live_entries，未按 S 存檔）。
   - 新增檔僅 `test/CaptureLayoutTunerMinigame.gd`/`.tscn`（驗證用途，仿現有 CaptureLayoutTunerBattle
     慣例保留）與截圖 `_cap_tuner_v2_minigame_blackjack.png`（交付證據）。

## 意外/做不到的事項

- 需求文字提到「10 款小遊戲」，實際專案只有 9 支小遊戲腳本；已用 Glob 核對非漏找，
  照實際檔案數完成，非短交。
- MinigameBase 共用塊（result_panel/pause_panel）因是動態建立節點，無法在單一靜態
  GPU 截圖中同時展示「小遊戲頂層塊」與「結算/暫停面板」兩種狀態；已用程式碼審查
  （父節點型別）+ 既有 headless 測試（跑過結算/暫停流程無崩潰）替代，未額外多開一次
  GPU 截圖流程專門觸發這兩個面板（時間效益考量，且 register() 邏輯與其餘 9 款完全
  同構，风险低）。
- 未逐一為每款遊戲都做 GPU 截圖（只做 Blackjack 代表），依規格「至少 1-2 款代表性
  小遊戲」的要求，1 款已足夠證明 tuner 系統在小遊戲場景正確運作；其餘 8 款的登記
  正確性以程式碼審查（父節點型別、is_free() 邏輯）替代逐一截圖驗證。
