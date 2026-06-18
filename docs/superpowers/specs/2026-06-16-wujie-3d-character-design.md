# 無戒 3D 角色 — 設計文件

日期：2026-06-16
狀態：設計核可（待寫實作計畫）
關聯：[[project-art-direction]]（定版立繪）、[[project-3d-environment]]（西門街/Meshy 道具管線）、[[project-mapscreen-areas]]（MapScreen 常駐 Player）、[[reference-ai-asset-tools]]

## 目標
把地圖探索的玩家角色從膠囊／暗袈裟佔位換成正牌 3D 無戒（苦行僧），會待機與走路，接上現有 `PlayerController`，站進已是真環境的西門街。

## 背景 / 現況
- 玩家現況：`MapScreen.tscn` 的 Player ＝ CharacterBody3D＋`PlayerController`，`MeshRoot/BodyMesh` 是橘色膠囊；`StreetProto`（測試場景）用程式組的暗袈裟人形。皆佔位。
- `PlayerController.gd`：吃 `$MeshRoot`(model) 與**選用** `$AnimationTree`；移動時 `model.rotation.y = lerp_angle(...)`、`anim_tree.set("parameters/blend/blend_amount", v)`（0 靜止 / 1 移動）。固定 `SPEED=5`，無衝刺。
- 既有無戒美術：12 張立繪（3 職 ascetic/chanter/beggar × 4 表情）＋定版 `assets/2d/portraits/wujie/_LOCKED_base_reference.jpg`。**全是半身、抱胸、無下半身**＝不能直接拿去 image-to-3d＋綁骨（抱胸手分不開、缺腿腳、非 T-pose）。
- 戰鬥是 2D 回合制（用立繪），**3D 角色只需地圖探索動作**＝待機＋走路。

## 決策（已與使用者確認）
1. **造型**：苦行僧 ascetic（遊戲預設職業、定版基底那件灰綠袍）。
2. **動畫**：待機＋走路（對上 PlayerController 的 idle↔walk 混合）。run 隨 rig 附帶、之後要衝刺再接。
3. **image_to_3d 餵圖**：正面＋背面兩張（`multi_image_to_3d`，幾何/貼圖較準）。
4. **參考圖**：因定版基底不可用，先生**全身正/背 T-pose**苦行無戒當 3D 來源（拿定版基底當角色參考保臉/袍），此步走非 Meshy 服務。

## 管線（資料流）
**Phase 1 — 全身 T-pose 參考圖（非 Meshy，higgsfield／magnific，便宜）**
- 生正面＋背面：全身、T-pose（手臂外展）、苦行袍、正面平視、乾淨背景、與定版一致的臉/光頭/灰綠袍＋白內襟。用 `_LOCKED_base_reference.jpg` 當角色/風格參考。
- 一致性可能要生幾張挑；存 `assets/2d/portraits/wujie/3d_ref/front.png`、`back.png`。
- **閘門：參考圖先給使用者看、點頭才進 Phase 2（才開始花 Meshy）。**

**Phase 2 — Meshy 3D（花 credit）**
1. `multi_image_to_3d`（front+back，`ai_model: meshy-6`，`pose_mode: t-pose`，`target_formats:["glb"]`，PBR）→ 預覽/模型
2. `meshy_rig`（綁骨，含 walk/run）
3. `meshy_animate`（待機 idle clip）
4. 下載綁骨＋動畫 GLB(+貼圖) → `assets/3d/characters/wujie/wujie_ascetic.glb`
- 過 `_fix_meshy_materials` 等同道具的透明修正（若 base color 帶 alpha）。

**Phase 3 — Godot 整合（純 code）**
- 新建 **`src/screens/MapScreen/Player.tscn`**：CharacterBody3D（script `PlayerController`，群組 `player`）＋ CapsuleShape 碰撞（r0.4/h1.8，沿用）＋ `MeshRoot`(Node3D，掛 `wujie_ascetic.glb` 實例，縮放到 ~1.8m、腳底對齊 y=0)＋ `AnimationTree`。
- **AnimationTree**：`tree_root` ＝ `AnimationNodeBlendTree`，內含 `idle`／`walk` 兩個 `AnimationNodeAnimation` → `Blend2`（節點名 **`blend`**）→ output；`anim_player` 指向 GLB 的 AnimationPlayer。如此參數路徑 ＝ `parameters/blend/blend_amount`，與 `PlayerController._set_blend` 一致；`active=true`。
  - clip 名以 rig/animate 實際輸出為準（生成後查 GLB AnimationPlayer 的 clip 名再填 idle/walk 兩個 Animation 節點）。
- `MapScreen.tscn`：把 inline 的 Player 子樹換成 `instance Player.tscn`（玩家是常駐節點、街景環境不含玩家，故只動此處）。`StreetProto.gd` 的程式佔位人形可選擇性改用 Player.tscn（非必要、測試場景）。

## 資產配置
- 參考圖：`assets/2d/portraits/wujie/3d_ref/{front,back}.png`
- 3D 模型：`assets/3d/characters/wujie/wujie_ascetic.glb`(+ `_*.png` 貼圖)

## 錯誤處理 / 風險
- **參考圖一致性**：半身抱胸→全身 T-pose 還要保住定版臉/袍，AI 可能要生幾張挑（閘門讓使用者把關）。
- **寬袖長袍 auto-rig**：飄逸長袍綁骨走路可能微飄/穿插；過肩距離可接受，真糟再考慮收袖版或降權重。
- **AnimationTree clip 名**：rig/animate 輸出的 clip 名未知，生成後對照實際名再接（plan 內處理）。
- **比例/朝向**：GLB 匯入後量 AABB 縮放到 ~1.8m、`origin_at bottom` 腳貼地；面向以 PlayerController 的 model.rotation.y 控制（+Z 朝向慣例）。
- 載入失敗（GLB 缺）：MeshRoot 退回膠囊佔位，避免空玩家。

## 測試
- **headless**：①GLB 匯入成功②`Player.tscn` 實例化＝有 `AnimationTree`、含 `parameters/blend/blend_amount`、GLB AnimationPlayer 有 idle/walk clip③把 Player.tscn 放進 MapScreen、`PlayerController` 收方向鍵能改 velocity/位移（模擬 Input 或直接呼叫）。
- **視窗截圖**：無戒站西門街（待機姿）＋過肩鏡頭存 PNG 自檢；走動觀感靠實機。

## YAGNI（本輪不做）
- chanter/beggar 兩套 3D（只做 ascetic）。
- 跑步/攻擊/情緒等額外動畫（戰鬥是 2D）。
- 戰鬥用 3D（維持 2D 立繪）。
- 收袖版重製（除非 auto-rig 真的太糟）。
