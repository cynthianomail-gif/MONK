# 修行盤曼荼羅重設計 tracking（2026-07-07）

需求：使用者說「點擊技能的樹長得很怪」＝修行盤 BoardApp；參考知名 JRPG 重做。
拍板：曼荼羅法輪盤方向（視覺稿已確認）；只優化修行盤，經書 19 招不併入。
spec：docs/superpowers/specs/2026-07-07-cultivation-board-mandala-design.md

| 項目 | 狀態 | 產出路徑 | 下一步 |
|---|---|---|---|
| 現況盤點（兩套系統釐清） | ✅ | D:\monk\_skilltree_inventory.md | — |
| 視覺稿＋使用者拍板 | ✅ | 對話 SVG mockup | — |
| spec 落檔 | ✅ | 上列 spec | — |
| 實作 | ✅ | data/cultivation_board.json、src/ui/menu/pages/BoardApp.gd、test/TestBoardMandala.*、test/CaptureBoardMandala.* | — |
| 驗收（**親驗違例**，見下） | ✅ | 本檔驗收記錄 | 額度重置後視需要補嚴格 fresh review |
| GPU 截圖給使用者過目 | ✅ 使用者滿意 | _cap_board_v2_full.png / _cap_board_v2_selected.png | — |
| 視覺打磨 v2.1（使用者回饋「字不清楚、配色再精緻」） | ✅ 2026-07-07 | BoardApp.gd（純視覺，佈局/解鎖零改動） | — |
| commit | ✅ dae87d0 | 9 檔（json/BoardApp/測試×6/spec） | **全案結案**；本 tracking 可刪 |

## 視覺打磨 v2.1 記錄（2026-07-07，主對話親做＋親驗）

改動全在 BoardApp.gd 繪製層：①全 app 深墨底 BG_DEEP（原本吃選單殼中灰底＝字糊主因）；
②盤上文字 13px→15px 隨盤面等比縮放＋4px 深色描邊（draw_string_outline）；③配色提亮
（金 GOLD_BRIGHT/朱紅帶光暈/灰態提亮）；④盤心暖光暈+師鎖環 72 刻度+核心蓮瓣環；
⑤解鎖節點朱紅柔光、可解鎖金光呼吸、空心節點深色底盤；⑥解鎖連線亮金+底光、
通往師鎖節點改紫虛線（補上 spec 第2節原漏做項）；⑦橫脈標籤改「節點正上/正下置中交錯」
（原貼側邊排法在字級放大後會橫躺鏈線壓節點，截圖親驗發現後修正）。
驗證：TestBoardMandala/TestBoard/TestMenuSystem 全 ALL PASS；兩張截圖重拍親讀確認。

## 驗收記錄（2026-07-07，主對話親驗）

**親驗違例理由**：實作 agent 被伺服器限流砍死未留回報檔（本日第 1 次 agent 額度死亡），
照 50-letter.md 踩坑記錄 [2026-07-05] 做法，改主對話親驗重點項；額度重置後視需要補嚴格 fresh review。

逐條對 spec 驗收條件：
1. JSON 只動佈局欄位 — ✅ git diff 全檔核對：僅 angle_deg 改值＋新增 radius＋ring 預設半徑調整；cost/requires/effect/unlock_flag/name/desc 零變動。四脈同鏈同角度（剛270°上/體0°右/迅90°下/柔180°左）、半徑嚴格遞增（100→155→210→260→310→380）。
2. headless 佈局測試 — ✅ TestBoardMandala：`BOARD_MANDALA_TEST: ALL PASS`（exit 0）。
3. 視覺（GPU 截圖親驗）— ✅ 兩張截圖親讀：十字四脈直線、盤心置中、菱形技能旁枝、雙圓被動、紫虛線師鎖環＋環頂標語、四態色語彙、名字常駐、圖例常駐、選中白圈＋面板結構（badge→名→描述→花費→前置✓→E提示→圖例）全符合。
4. 既有測試零回歸 — ✅ TestBoard `ALL PASS`、TestMenuSystem `ALL PASS`（brahma_resonance 警告為測試自身既有訊息）。
5. 兩張截圖交付 — ✅ 已在，親讀確認內容對題。
6. 不 commit、無舊碼殘骸 — ✅ git status 未 commit；BoardApp.gd grep 無舊佈局註解殘碼。
