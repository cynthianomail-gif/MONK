# 佈局工具 v3 tracking（小遊戲圖素材可調）2026-07-07

使用者需求：小遊戲內的圖素材（最容易有偏差的）也要能在遊戲內拖曳校正。
拍板範圍：綠框可拖＝A 靜態＋B1（build 只設一次）；琥珀不可拖＝B2（每回合重設）/C（會動）/動態生成。
不做錨點機制；端湯 3D 內景不做（只有 2D HUD）；純幾何（香火投擲）照樣登記。

| 項目 | 狀態 | 產出路徑 | 下一步 |
|---|---|---|---|
| 盤點 9 款圖素材分類 | ✅ 完成 | D:\monk\_minigame_art_inventory.md | — |
| v3 設計拍板 | ✅ 完成（使用者拍板 B1 切法） | 本檔＋派工單 | — |
| 實作（登記＋琥珀標註＋tuner 巢狀拖曳修正） | ✅ 完成（未 commit） | src/screens/Minigames/*、LayoutTuner.gd、test/TestMinigameArtLayout.gd(.tscn) | 等 fresh review |
| fresh review 驗收 | ✅ 通過（0 阻斷 finding） | D:\monk\_layout_v3_review.md | — |
| GPU 截圖親驗 | ✅ reviewer 已親驗（CaptureLayoutTunerMinigame，覆蓋 Blackjack；bg 綠框確認存在） | 見 review 報告 | — |
| 使用者實機驗收 | ⬜ | — | 進各小遊戲按 ` 拖圖、S 存檔、重進確認；OK 後 commit |

## 實作結果摘要（2026-07-07）

- 9 款全數補登記綠框（bg 全部含 fallback 分支同 key）＋琥珀標註，完整清單見 D:\monk\_layout_v3_impl_report.md。
- LayoutTuner._set_pos/_get_screen_pos 新增：拖曳目標一律換算到父節點座標系（Node2D 用
  get_global_transform_with_canvas().affine_inverse()，Control 用父層同法），修正巢狀節點
  （化緣 _monk_sprite 掛 _bowl_node 下）跳位問題；方向鍵微調（_apply_move）維持 local delta，
  不經過座標轉換。
- 耦合查證結論：OfferingToss box＝琥珀（判定用 START_POS 等常數，不讀節點位置，拖了會脫鉤）；
  WoodenFishRhythm fish 錨點＝安全綠框（fx/判定已經讀節點 position，非獨立常數，零風險）。
- 新測試 test/TestMinigameArtLayout.gd(.tscn)：9 款逐一 instantiate 斷言 key/meta，另含巢狀
  拖曳座標正確性驗證（BeggarChallenge _monk_sprite）。
- 基準（TestLayoutStore/TestLayoutTuner/TestMinigames/TestMinigamePause）與新測試全數 ALL PASS，
  零新增 FAIL。

## 關鍵技術點（派工單已含）
- Tuner 拖曳座標 bug 風險：現行 `_set_pos` 直接把 viewport 座標塞進 `position`（local），父節點不在原點/有變換的巢狀節點（化緣 _monk_sprite、21點 _chip_zone 內籌碼）會跳位。要改成換算父節點座標系。
- 耦合檢查：輪盤 WHEEL_CENTER 同時驅動珠路徑→_wheel 琥珀；香火箱體 vs 銅錢拋物線目標要查證；木魚 fx 出點用常數還是節點位置要查證。
