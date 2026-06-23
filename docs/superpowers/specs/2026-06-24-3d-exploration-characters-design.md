# 3D 探索角色（可見 NPC + 主角重做）— 設計

日期：2026-06-24
狀態：設計（待使用者複審 → writing-plans）
關聯：3D 探索（`ShrineStreet`/`ArmoryDistrict`、[[project-3d-environment]]）、`LocationTrigger`、`MapScreen`、okami shader（`assets/shaders/okami/ink_toon.gdshader`）、既有主角 3D 管線（`Player.tscn`/`PlayerAnimTree`，[[project-art-direction]] 的 game_ready 立繪）、Meshy MCP。

## 目標
讓 3D 探索世界「有角色站著」：6 個地點各放一個**可見的 3D NPC**（走近觸發＝現有 LocationTrigger 流程不變），全套 okami toon、靜態+程式呼吸搖擺。**主角無戒的 3D 模型重做**（現有那隻是 pivot 前舊圖做的）成新 okami 版。**VN 對話框維持 2D 水墨胸像不變。**

## 決策（與使用者確認）
1. 3D 角色出現在**探索世界**（站立可見、走近對話），不是 VN 對話框（框內維持 2D 胸像）。
2. NPC＝**每地點一個代表**（6 個），不是全部 12 個、不是一地多人。
3. NPC＝**靜態模型（不綁骨）+ 程式輕微呼吸搖擺**。
4. 產法＝**Meshy image-to-3d ← 現有 okami 2D 立繪**（臉/衣著貼合 2D 美術）。
5. **主角也重做**：image→3D 但要綁骨（走路），來源＝**Codex 生 okami T-pose 正+背**參考圖。
6. **順序：先 6 NPC（低風險、純加），再主角重做（動到綁骨玩家管線）。**

## 架構（元件、各自單一職責）
- **`assets/3d/characters/npcs/<name>.glb`**（×6）：Meshy image-to-3d 靜態模型。
- **`src/screens/MapScreen/npc_figure.gd`（Node3D，新）**：`setup(model_path)` → 載 GLB → `_fix_meshy_materials()`（修 Meshy base-color alpha→整模型透明雷）→ 走訪 MeshInstance3D 套 `ink_toon` `material_override`（同 `ShrineStreet._apply_toon`）→ `_process` 對整個模型做 sin 呼吸/輕搖（免綁骨）。preload okami toon shader（不用 class_name，避註冊雷）。
- **`LocationTrigger.setup(id, data)` 加掛**：若 `data.has("npc_model")` → instantiate NpcFigure、`setup(model 路徑)`、加為子節點、`rotation.y` 轉向街心（朝 +Z 或依資料）。觸發球/NameLabel 維持。
- **`data/map_locations.json`**：6 地點各加 `"npc_model": "<name>"`（指 `npcs/<name>.glb`）。
- **okami toon 套法**：重用 `ShrineStreet.gd` 既有「走訪 mesh→`material_override = _toon_mat(color)`」做法（NpcFigure 自帶同邏輯，色給暗墨）。

### NPC→地點對應
| 地點 | NPC | 來源立繪(game_ready) | GLB |
|---|---|---|---|
| old_temple 荒廢神社 | 了塵 | `liaochen_front` | `npcs/liaochen.glb` |
| wannian_mall 萬年大樓 | 鄭媽 | `zheng_ma_front_ares_red` | `npcs/zheng_ma.glb` |
| ximen_mrt 櫻木町站 | 阿明 | `ah_ming_front_ares_red` | `npcs/ah_ming.glb` |
| zen_bbq 禪味燒肉 | 阿忠 | `ah_zhong_front_ares_red` | `npcs/ah_zhong.glb` |
| zuijin_club 紫醉金迷 | Cherry | `cherry_geisha_front` | `npcs/cherry.glb` |
| armory_worker 軍火庫 | 鐵叔 | `tie_shu_locked_front_ares_red`（駝背態） | `npcs/tie_shu.glb` |

## 管線

### Phase 1：6 個 NPC（現在可做）
1. **Meshy image-to-3d**：每張正面立繪 → 靜態紋理化 GLB（單張正面、背面 Meshy 推算＝背景 NPC 夠用，不綁骨）。**先生 1 隻（鐵叔或了塵）→ 下載→截圖驗水墨立繪轉 3D 的品質/比例 → OK 再批量 5 隻。** 每次 Meshy 呼叫前報價確認（Meshy 規則）。估 ~6×20-25cr ≈ **120-150 credits**（餘 657）。
2. **接遊戲**：建 NpcFigure、map_locations 加 npc_model、LocationTrigger 掛載；`--import`；headless 驗 + windowed 截圖。

### Phase 2：主角重做（待 Codex T-pose 參考圖）
1. **Codex handoff**：生 okami 無戒 **T-pose 正面 + 背面**（雙臂微張、透明底、同 cast 水墨風）→ 落 `art_direction/.../game_ready/`。
2. **Meshy**：`multi_image_to_3d`(正+背, PBR) → 面數超 rig 上限則 `remesh` 到 ~30k → `rig`(含 walk+run) → 取 walk GLB。估 ~30-50cr。
3. **換進遊戲**：覆蓋 `assets/3d/characters/wujie/wujie_walk.glb` → **重接驗證 `PlayerAnimTree`**（blend idle↔walk、`_make_idle` 手臂旋轉軸——記憶記載這段骨骼軸 finicky，新 rig 骨名/軸可能要重調）+ `_fix_meshy_materials`/okami toon。
> ⚠ 主角這段動到目前**能跑的綁骨玩家管線**＝最高風險，故排 Phase 1 之後、單獨驗證 walk+idle。

## 資料流
`map_locations.json.npc_model` → `MapScreen._spawn_triggers` 灑 LocationTrigger → `LocationTrigger.setup` 見 npc_model → NpcFigure 載 GLB/修材質/套 toon/擺位/搖擺。主角＝`Player.tscn` 換 GLB（資料流不變，重點在 AnimTree 重接）。

## 測試
- **headless**：NpcFigure 載入一個 GLB + 套材質不 crash；MapScreen 灑含 npc_model 的觸發點不報錯；既有 `TestMapScreen3D`/`TestMainQuest`/`TestDemoScope` 等回歸 PASS。
- **windowed 截圖**：神社街看到 3D NPC（了塵/鄭媽…）站著、套水墨 toon、轉向街心；主角重做後走路+idle 正常。
- **Meshy 品質關**：每隻下載後單體截圖驗比例/朝向/材質（沿用 `CapturePropSolo` 式）再擺街。

## Meshy 踩雷（沿用記憶）
- **base-color alpha→整模型透明** bug：載入後 `_fix_meshy_materials`（surface material `transparency=DISABLED`、`albedo.a=1`，保 emission）。
- **Meshy 正面預設 +Z**：擺街要 `rotation.y` 轉向。
- 成本：任何 Meshy 生成前報價確認。
- class_name 註冊雷：NpcFigure 用 preload 引用，不靠 class_name。

## YAGNI（本輪不做）
- NPC 不綁骨/不走動（站立+搖擺足矣）。
- 不動 VN 對話框（維持 2D 胸像）。
- 不做全 12 NPC、不做一地多 NPC（每地點一代表）。
- Boss 阿瑞斯不放探索世界（他在 boss 戰）。
- 主角重做不改 Player 控制邏輯，只換模型+重接 AnimTree。

## 順序
**Phase 1（6 NPC）先做並驗證 → Phase 2（主角重做）待 Codex T-pose 圖到再做。** 兩階段各自 Meshy 報價確認、各自截圖驗證。
