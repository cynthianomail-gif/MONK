# 3D 水墨神社街・獨立可玩場景 — Design

- Date: 2026-06-20
- Status: Approved (design)
- Supersedes exploration approach in retired specs (cyberpunk ximen / 2D maple / hd2d pilot — already deleted)

## Purpose

把 `test/OkamiShaderTest.gd` 的水墨 3D look-dev 原型，正式化成一個**獨立、可走動的成品場景**：玩家用 3D 無戒沿神社街走動、相機跟隨、全程水墨 shader。用來驗證「3D 水墨探索」的實際手感，作為日後接回遊戲的基礎。

## Scope

**In**
- 4 個水墨 shader 從內嵌字串抽成 `.gdshader` 檔。
- 程式化環境腳本 `ShrineStreet.gd`（`extends Node3D`）建整條神社街。
- 場景 `ShrineStreet.tscn`：環境 ＋ 玩家 ＋ 跟隨相機，方向鍵可走。
- 玩家 3D GLB 套水墨 toon 材質。
- 截圖驗證（靜態＋走動連拍）。

**Out（之後另開專案）**
- 接回遊戲 `MapScreen`（現為 2D Control，需改回 3D 宿主）。
- data-driven 讓 wanhua/linsen 三街共用同一 builder。
- 正牌水墨 3D 角色（現用既有 GLB 套 shader 代替）。

## Design

做法：沿用既有 `XimenStreet` 模式＝**程式化環境腳本 ＋ 薄 `.tscn` ＋ shader 抽檔**。不把整場景手刻成節點（檔案爆大、無法用 RNG 迭代）。

### 1. 檔案佈局
- `assets/shaders/okami/ink_toon.gdshader` — spatial toon：世界座標墨染斑駁＋直向筆刷紋＋自訂 `light()` 兩階墨色（交界 vnoise 打毛）。`albedo` uniform。
- `assets/shaders/okami/ink_ground.gdshader` — 地面：墨染 ＋ 石板格紋接縫（XZ fract，~2.2m）＋每塊輕微色差 ＋ 同款 `light()`。
- `assets/shaders/okami/ink_outline.gdshader` — 螢幕空間描邊（unshaded quad）：depth 用二階差分 Laplacian ＋ normal sobel；筆鋒低頻變寬、飛白、墨色濃淡、遠景隨距離淡入紙色。
- `assets/shaders/okami/ink_paper.gdshader` — canvas_item 和紙顆粒 overlay。
- `src/screens/MapScreen/environments/ShrineStreet.gd` — `extends Node3D`，`_ready` 載 4 shader → 建場景。
- `src/screens/MapScreen/environments/ShrineStreet.tscn` — 根節點掛 `ShrineStreet.gd`，子節點：`Player`（instance `Player.tscn`）、`CameraRig`。

### 2. 環境（ShrineStreet.gd）
把 look-dev 的建構函式搬過來整理：`_build_env`（WorldEnvironment：暖米白 BG＋FILMIC＋glow threshold 1.3＋fog 0.006＋DirectionalLight）、`_build_ground`（石板 shader 大盒）、`_build_street`（兩排矮店家 3.5–6.5＋gable 屋頂＋店面三件套 emissive 暖光/暖簾/披簷＋木格格子戸＋掛看板）、`_build_torii`、`_build_lanterns`、`_build_stone_lanterns`、`_build_backdrop`（杉林 cone＋山 PrismMesh 沒入霧）、`_build_props`（幟＋酒樽/木箱）、`_build_paper_overlay`（CanvasLayer）。RNG 固定種子＝可重現。材質統一走 `ink_toon`（地面走 `ink_ground`）。

### 3. 玩家 ＋ 相機
- 沿用 `Player.tscn`（CharacterBody3D ＋ `wujie_walk.glb` ＋ `PlayerController` 方向鍵 ＋ `PlayerAnimTree` 待機/走）與 `CameraRig`（第三人稱跟隨，抓 group `player`）。
- `_apply_ink(player)`：延一幀後走訪玩家所有 `MeshInstance3D` 的 surface，`material_override = ink_toon 材質`（沿用既有 `_make_opaque` 的走訪法；先確保不透明再套）。
- **描邊整合（關鍵）**：`ink_outline` 後處理 quad 必須掛在「當前作用中的相機」。`_ready` 延一幀後 `get_viewport().get_camera_3d()`（＝CameraRig 的 Camera3D）→ 把 outline quad add 進該相機、`extra_cull_margin` 拉大、render_priority 高。相機移動描邊自動跟對。

### 4. 碰撞 / 走動
- 地面加 `StaticBody3D ＋ CollisionShape3D`（BoxShape，與石板地同尺寸）讓玩家站得住。
- 街兩側先**不**擋牆（proto 走出街無妨；要再加 side wall StaticBody）。
- 走動沿用 `PlayerController`（已是 CharacterBody3D 方向鍵移動）。

### 5. 驗證
- `test/CaptureShrineStreet.gd/.tscn`：載 `ShrineStreet.tscn` → 等 ~30 frame → 存靜態截圖；另一段模擬按住 `ui_up` 幾秒連拍 2–3 張驗證走動＋相機跟隨。
- 流程：先 `--headless` 跑（過 parse／印 `READY`），再視窗截圖、grep `*_SAVED` 確認，Read 圖自檢。**不可只看 exit code＋讀圖**（壞時讀到舊圖）。

### 6. look-dev 去留
- shader 真源＝`.gdshader` 檔。`ShrineStreet` 驗證通過後，`OkamiShaderTest.gd/.tscn` 即可刪除（被取代）。

## Acceptance Criteria
1. 4 個 `.gdshader` 檔存在，`ShrineStreet.gd` 載入它們、無內嵌 shader 字串。
2. 視窗截圖：神社街水墨外觀與 look-dev 等價（屋頂/店面/石燈籠/鳥居/石板地/遠景杉林/描邊/和紙）。
3. 玩家 3D 無戒站在街上、套了水墨 toon、被描邊圈到、風格與環境一致。
4. 走動連拍：按 `ui_up` 玩家沿街移動、相機跟隨、描邊持續正確（不脫鉤、不噴雜訊）。
5. headless 跑無 parse error；驗證腳本印出 `_SAVED`。

## Notes / Risks
- 描邊 quad 與相機綁定的時序：CameraRig 在 `_ready` 之後才 make_current，故 outline 掛載要**延幀**抓 `get_viewport().get_camera_3d()`。
- 玩家套 toon 後若仍透明＝Meshy GLB base color alpha bug，需先 `TRANSPARENCY_DISABLED ＋ albedo.a=1`（沿用 `_make_opaque`）。
- GDScript 雷：`var x := [字面陣列][索引]` 推不出型別→用 `var x: Color = …`；腳本 parse error 時視窗版 Godot 會卡死，先 headless 逼錯。
