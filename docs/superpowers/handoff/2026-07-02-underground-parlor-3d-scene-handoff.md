# 交接文件 — 軍火庫地下遊藝場 3D 子場景（✅已實作 2026-07-02）

日期：2026-07-02
給：下一個 session

> **✅ 2026-07-02 同日已實作完畢，全測試 PASS。** 使用者四項決定＝B 方案／長方形10×14／沿用 `ambient_armory.ogg`／共用 `armory_unlocked`。落地檔案：`UndergroundParlor.gd/.tscn`＋`map_npcs.json` `parlor_entrance`＋MapScreen `enter_parlor`＋`ArmoryDistrict._build_parlor_door`＋`SceneRouter.finish_minigame` 加 `context.return_scene`＋`TestUndergroundParlor`。
> **與本文原規劃的兩個落差（實作時修正）**：
> ① **出口不是 `go_to_scene(ArmoryDistrict.tscn)`**——ArmoryDistrict 是 MapScreen 宿主下的子環境，直接當 current_scene 會變成沒 HUD/沒觸發點/沒 NPC 的裸街。改走 `SceneRouter.go_to_map()`：進場時 MapScreen `enter_parlor` 先 `_store_position()`，出場 go_to_map 後 MapScreen 依 `current_area="armory"`＋`last_position` 把玩家放回街上入口。
> ② **加了 `finish_minigame` 的 `return_scene` context**：房內起的小遊戲結束後回房間、不回城市地圖（沒帶照舊回地圖，QuestManager/JobApp 路徑不受影響）。
> 剩餘工作＝**5 個小遊戲本體**（等 Codex 圖，見美術 handoff）。以下原文保留供背景參考。

> 先讀這篇，再讀 [[project-mapscreen-areas]]（既有 area/場景切換架構）與 [[project-3d-environment]]（shader/建物程式化慣例）。美術生圖進度看 `docs/superpowers/handoff/2026-07-02-parlor-minigames-art-handoff.md`（已發給 Codex，等回圖）。

## 一、為什麼要做

5 個新小遊戲（飛鏢/輪盤/21點/棒球/保齡球）已經跟使用者確認要做，2D 小遊戲邏輯照 `MinigameBase` 框架（同 `OfferingToss.gd` 的寫法：純程式幾何+tween，等 Codex 圖回來再套皮）。使用者想要這 5 個的**入口**集中在一個獨立的 3D 房間裡（「軍火庫地下遊藝場」），不是散落在軍火庫街上的路邊互動點。

## 二、要做什麼（範圍）

一個**新的 3D 子場景**——不是新的 `area`（不進 `areas.json`、不用手機捷運/計程車移動到），而是走進 `ArmoryDistrict` 街上某個入口後切換進去的獨立房間：

- **形狀**：正方形或長方形，**不用大**（房間本身只是個容器，供參考量級：長邊 10-16 公尺左右，實際依 5 個賭具擺放站位微調，不用糾結精確數字）。
- **入口**：`ArmoryDistrict` 街上新增一個 `LocationTrigger`（比如一道後門/樓梯口），走近觸發「進場」而非直接彈小遊戲選單。
- **房間內部**：擺 5 個賭具道具，各自是一個獨立 `LocationTrigger`：飛鏢靶（掛牆）、輪盤桌、21點桌、打擊籠入口、保齡球道入口。全部程式化盒體幾何，跟 `ArmoryDistrict._build_district` 那套手法一樣。
- **出口**：房間裡放一個「離開」互動點，走近觸發回到 `ArmoryDistrict` 原本站的位置。
- **美術**：沿用 `ArmoryDistrict` 既有 shader（`ink_toon`/`ink_ground`/`ink_outline`/`ink_corrugated`）跟暗鋼鐵+紅燈籠基調，**不用等 Codex 圖也能先把房間結構做出來**——`parlor_bg_wide.png` 等圖回來後可以當牆面裝飾/招牌貼圖疊上去，非必要阻塞項。

## 三、架構落地建議（照現有慣例，兩個選項）

**A. 當成 ArmoryDistrict 的子區域**：比照 `MapScreen._load_area` 的 area 切換模式局部 swap。較重，要碰 `areas.json`/`MapScreen` 的 area 邏輯，且賭場不是「可移動目的地」意義上的 area，語意不合。

**B.（建議）獨立場景，用現成的 `SceneRouter.go_to_scene(path)` 直接切換**：
```gdscript
func go_to_scene(path: String) -> void:
    await _change_scene(path, Transition.INK_SPLASH)
```
這個 API 已經存在且是通用的（戰鬥結束回原 3D 場景就是用它），完全不用碰 `MapScreen`/`areas.json`。進場＝`ArmoryDistrict` 某觸發點呼叫 `SceneRouter.go_to_scene("res://src/screens/MapScreen/environments/UndergroundParlor.tscn")`；出場＝`UndergroundParlor` 的離開觸發點呼叫 `SceneRouter.go_to_scene("res://src/screens/MapScreen/environments/ArmoryDistrict.tscn")`。**建議走 B，改動最小。**

## 四、新場景檔案（比照既有命名慣例）

- `src/screens/MapScreen/environments/UndergroundParlor.gd`／`.tscn`
- 寫法比照 `ShrineStreet.gd`/`ArmoryDistrict.gd`：`extends Node3D`，`_ready()` 依序呼叫 `_build_env()`/`_build_room()`/`_build_props()` 等，reuse 現有 `Player`/`CameraRig`（跟 shrine/armory 一樣自帶）。

## 五、5 個賭具互動點（+ 1 個出口）

| 互動點 | action id（建議） | 呼叫 |
|---|---|---|
| 飛鏢靶 | `darts_minigame` | `SceneRouter.go_to_minigame("darts")` |
| 輪盤桌 | `roulette_minigame` | `SceneRouter.go_to_minigame("roulette")` |
| 21點桌 | `blackjack_minigame` | `SceneRouter.go_to_minigame("blackjack")` |
| 打擊籠 | `batting_minigame` | `SceneRouter.go_to_minigame("batting")` |
| 保齡球道 | `bowling_minigame` | `SceneRouter.go_to_minigame("bowling")` |
| 出口 | `leave_parlor` | `SceneRouter.go_to_scene(".../ArmoryDistrict.tscn")` |

⚠**這 5 個小遊戲的 2D 場景本身還沒寫**，跟房間是分開的兩件事——房間只是入口容器，小遊戲邏輯/計分（`飛鏢/輪盤/21點/棒球/保齡球.gd`）要另外各寫一個 `MinigameBase` 子類，等 Codex 圖回來後比照 `OfferingToss.gd` 的做法各自實作。可以先做房間結構+觸發點（暫時 `push_warning` 提示「尚未實作」），小遊戲邏輯之後分批補上。

## 六、待決定事項（開工前先問使用者，不要自己假設）

1. 進出機制 A vs B（**建議 B**，最小改動，除非使用者有別的規劃考量）。
2. 房間精確尺寸與 5 個賭具怎麼分布（走位站起來測，不用先精算）。
3. 房間要不要環境音（可以先沿用 `ambient_armory.ogg` 或乾脆不放，不一定要新生一條）。
4. 賭場的解鎖條件——一開場就能進，還是跟主線/`armory_unlocked` 綁在一起（軍火庫本身現在就有 `armory_unlocked` flag 的鎖，賭場合理的話可以共用同一把鎖，不用另開新 flag）。

## 七、驗證方式（沿用專案慣例）

- 改完先跑 `--headless --check-only --script res://.../UndergroundParlor.gd`：**注意 `GameManager` 這類 autoload 在 `--check-only` 模式下會誤報 `Identifier not found`，這是已知假警報**，不代表真的壞（這輪 ShrineStreet/ArmoryDistrict 改動時都踩過），要另外跑完整場景 headless smoke test 才算數。
- ~~windowed 截圖驗收在這個開發環境會卡死~~ → **勘誤（2026-07-02 晚）：windowed 截圖跑得動**（當時卡死是暫時性狀態）。用 `timeout 120 ./tools/godot/..._console.exe --path D:/monk/MONK res://test/CaptureParlor.tscn -- smoke` 即可自驗視覺；本場景已用 `test/CaptureParlor.tscn`（5 角度：spawn/俯瞰/朝北/朝南/街上入口）截圖驗收並據此調亮室內光照。headless smoke test（`TestUndergroundParlor`）仍是結構驗證的主 gate。

## 八、相關文件

- 美術生圖 handoff（等 Codex 回圖）：`docs/superpowers/handoff/2026-07-02-parlor-minigames-art-handoff.md`
- 記憶：[[project-mapscreen-areas]]（area 切換架構）、[[project-3d-environment]]（shader/建物慣例）、[[project-session-handoff]]（本輪總覽）
