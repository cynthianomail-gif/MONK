# 佈局工具 v2 追蹤（2026-07-07 開工）

需求來源：使用者要「遊戲內拖曳調 UI，同類一起動、永久套用、調完立刻生效」。
拍板：**A 務實版**——工具專攻「可自由定位的大塊」，容器內小元件走樣板（改樣板一次全套用）。
涵蓋：先做戰鬥畫面，再擴 地圖HUD／對話框立繪／小遊戲。

spec：docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md

| 項目 | 狀態 | 產出路徑 | 下一步 |
|---|---|---|---|
| 需求釐清＋方向拍板 | ✅ 完成 | （對話中，含視覺化確認） | — |
| spec 撰寫 | ✅ 完成 | specs/2026-07-07-layout-tuner-v2-design.md | — |
| P1 系統：LayoutStore autoload | ✅ 完成 | src/autoloads/LayoutStore.gd（167行） | — |
| P1 系統：LayoutTuner 升級（全框標註/綠拖琥珀擋） | ✅ 完成 | src/autoloads/LayoutTuner.gd（129→588行） | — |
| P1 戰鬥登記 7 塊 | ✅ 完成 | BattleUI.gd:82-95、EnemyPanel.gd 樣板 meta | — |
| P1 測試＋GPU 驗證 | ✅ 完成＋主對話親驗 | TestLayoutStore、_cap_tuner_v2*.png、報告 _tuner_v2_p1_report.md | 等使用者實機 |
| P2 地圖 HUD | ✅ 完成＋親驗 | MapHUD.gd 登記 6 塊、_cap_tuner_v2_map.png | — |
| P3 對話框立繪 | ✅ 完成＋親驗 | speaker_bust_layer.gd 登記 3 塊、_cap_tuner_v2_dialogue.png | — |
| P4 小遊戲 | ✅ 完成＋親驗 | MinigameBase+9款、_cap_tuner_v2_minigame_blackjack.png | — |
| **全數 commit** | ✅ **7621848**（38 檔/1603 行） | 分支 hd2d-exploration | 等使用者實機 |

## 收尾（2026-07-07）
P1–P4 全完工、主對話親驗（9 支測試 exit=0 全 ALL PASS＋5 場景 GPU 截圖目視）、
已 commit 7621848。截圖被 .gitignore 擋、報告/tracking 未進 commit（dev 產物）。
**小瑕疵待使用者決定要不要修**：①琥珀標籤與血條「弱?」徽章字重疊 ②地圖 action_menu
框過大（空容器撐開）③頂端 combo_label 名牌被操作說明擋。都是標籤擺放的小事。

## 前一批（LayoutTuner 全物件可選修正，2026-07-07 上午）
已完成、已驗證、**未 commit**：LayoutTuner.gd 改 `_input` 攔截＋整棵樹命中測試；
TestLayoutTuner +2 測試；CaptureLayoutTunerDialogic GPU 證明；5 測試全綠。
報告：D:\monk\_tuner_fix_report.md。此為 v2 的基礎。

## 雷／約定
- 派實作 prompt 開頭必加「指揮官不下場不適用於你」禁令（否則轉包空轉）。
- Godot 檔案用 Write/Edit 工具，不用 PowerShell 寫中文（AGENTS.md 編碼規則）。
- Godot 執行檔：D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe（headless 測試）／
  Godot_v4.5-stable_win64.exe（GPU 截圖）。
