# HD-2D 探索場景原型（西門街）設計

> 日期：2026-06-18　狀態：設計待使用者覆核
> 關聯：記憶 `project-2d-map`、`project-mapscreen-areas`、`project-3d-environment`（退役）、`project-art-direction`；引擎 Godot 4.5 **Forward+**、GDScript。

## 1. 目標與範圍

**目標**：在不丟掉遊戲既有厚塗美術的前提下，讓探索場景拿到「走動的立體感＋景深＋運鏡」。做法＝**HD-2D（八方旅人式）**：把厚塗 2D 畫板擺進真正的 3D 景深，用固定俯角相機＋移軸景深後製，呈現精緻箱庭感。

**範圍＝原型先行（一個場景）**：只做**西門街**一個 HD-2D 原型，獨立場景驗證觀感。**滿意才**擴張到其他探索場景；不滿意則回頭調整或改採別路線（2.5D 視差／風格化 low-poly）。呼應上次 3D 探索悶頭燒 8 版的教訓。

**非目標**：本原型不重做後端（地點觸發/傳送點/MapHUD/存檔/城市地圖/內景），不改戰鬥/對話/選單，不全面轉換所有場景，不引入新畫風。

## 2. 美術鐵則（最高優先）

**所有 HD-2D 視覺元素一律用本遊戲既有的「半寫實厚塗」風格**，與全遊戲 2D 美術（立繪/戰鬥背景/12 神設定集）統一。建築立板、遠景背板、主角 sprite、道具皆然。**不得**改成卡通色塊/cel/描邊或任何其他畫風——選 HD-2D 的全部意義就是「拿到 3D 景深又保留厚塗」。新生成的補充素材必須先對齊既有畫風錨點再用。

## 3. 核心概念

所有東西都是「立著的 2D 畫板」，但擺在真正的 3D 不同深度（Z）上：
- 深度與運鏡是**真的**（相機在 3D 空間移動，各深度層自然視差）。
- 畫是**平的**（建築＝厚塗 PNG 貼在直立 quad），但刻意的箱庭美學＋移軸景深讓「平」變成高級而非「假」。
- 之前「貼盒子很假」的根因是「寫實貼圖貼在簡單 3D 盒幾何、貼街掃掠角」；HD-2D 改成固定俯角看箱庭、畫板靠燈光打亮，根本避開該問題。

## 4. 架構

### 4.1 原型場景樹（獨立 Node3D）
```
Hd2dStreet (Node3D)               # 建構器腳本 Hd2dStreet.gd
├─ Ground (MeshInstance3D 平面)    # 濕柏油，XZ 平面
├─ Backdrop (直立 quad)            # 遠景天際線厚塗背板（壓暗/模糊）
├─ Buildings (Node3D)
│   ├─ NearRow/  (z 近，街兩側近處店面)
│   └─ FarRow/   (z 遠，街兩側遠處樓)   # 每棟＝一張厚塗 PNG 貼直立 quad
├─ Props (Node3D)                  # 可選：2D 立板或現有 Meshy 道具
├─ Player (CharacterBody3D)
│   └─ Sprite3D                    # Wujie 厚塗 sprite，Y 軸 billboard
├─ CameraRig (Node3D) + Camera3D   # 固定 3/4 俯角，跟隨 Player 沿街
└─ WorldEnvironment                # 移軸景深/輝光/調色/霧；DirectionalLight + OmniLight 霓虹光池
```

### 4.2 與既有 MapScreen 整合（原型驗證後才做）
MapScreen 是 2D Control 協調者（三層：CityMap→DistrictScene→LocationInterior）。把 3D 箱庭塞進 2D 流程的方式：
```
MapScreen (2D)
└─ 西門 DistrictScene → 改用 SubViewportContainer
     └─ SubViewport (render 3D)
          └─ Hd2dStreet (Node3D)
   MapHUD (2D) 疊在上層不變
```
SubViewport 把 3D 場景當一張「2D 畫面」輸出，MapScreen 三層流程、地點觸發、傳送點、MapHUD、存檔**全沿用**。觸發點可用 3D Area3D 或維持資料＋UI 觸發。

## 5. 元件細節

### 5.1 Hd2dStreet.gd（建構器）
`_ready` 程式化建場景（沿用 XimenStreet.gd 的組裝思路，但元件是直立 billboard 不是盒體）：
- **Ground**：PlaneMesh，貼現有 `assets/3d/environments/ximen/ground_wet.png`（無縫柏油版），roughness ~0.34 吃霓虹反射。
- **建築立板**：每棟 = QuadMesh（直立、固定朝向，**非** camera-facing），貼一張厚塗建築 PNG（見 §6），`StandardMaterial3D` 設 `billboard = DISABLED`、`shading_mode` 視需要 unshaded 或靠燈光、`transparency` 視 PNG 而定。沿街以 rng 洗牌排列、近列/遠列不同 Z、兩側不同 X，樓高依圖比例縮放避免拉伸。
- **Player**：CharacterBody3D（group `player`）+ Sprite3D（Wujie sprite，`billboard = Y`，`texture_filter` 依厚塗質感選 linear）。沿用/改寫 `PlayerController.gd`（方向鍵 ui_*），walk 時切 idle/walk 幀（`assets/2d/characters/wujie/sprite/` 的 idle_0、walk_0..7）。
- **CameraRig + Camera3D**：透視，固定俯角 pitch ≈ −28~−35°，`target` 抓 group `player`（沿用 CameraRig 的 fallback 抓法，避開 NodePath export 載入掉值雷），沿街跟隨平移＋輕微浮動。

### 5.2 WorldEnvironment（HD-2D 的魔法）
- **移軸景深 DOF**：`Environment` DOF Blur Far + Near，清晰帶鎖主角深度 → 箱庭微縮感（最關鍵）。
- **輝光 glow**：霓虹招牌發光，沿用 `project-3d-environment` 調好的閾值方向（glow_hdr_threshold ~1.25，避免 bloom floor 抬白）。
- **調色 tonemap**：暖色霓虹夜。⚠ 避開 ACES 把霓虹去飽和成白的雷（霓虹自發光壓低、或用 FILMIC）。
- **暈影 vignette ＋ 薄霧 ＋ 雨 GPUParticles**：沿用既有值（雨量/alpha 別太濃以免糊白）。

## 6. 資產重用與前置
- ♻️ **建築**：直接重用 `assets/3d/environments/ximen/bldg_01..12.png`（之前做的「整棟、招牌烤進圖、fills frame」厚塗圖）＝終於有對的用途。原型先用**整張矩形立板**（快）；要更漂亮再去背成建築輪廓（透明 PNG）。
- ♻️ **主角**：`assets/2d/characters/wujie/sprite/`（idle_0、walk_0..7，已從 3D 渲好的厚塗 sprite）。
- ♻️ **地面**：`ground_wet.png`（無縫版）。
- ♻️ **道具**（可選）：現有 Meshy GLB（販賣機/立牌/腳踏車）需過 `_fix_meshy_materials` 透明修正；或之後補 2D 立板。
- **遠景背板**：若現有素材不足，生一張厚塗天際線（對齊畫風錨點）。
- 新增/匯入的 PNG/GLB 要先 `Godot --headless --path D:/monk/MONK --import` 才能 runtime 載入。

## 7. 建置順序（每步用視窗截圖自檢）
1. **地面＋建築景深層**（先不後製）：bldg 立板排近/遠列＋背板，相機固定俯角。📸 讀起來像「有深度的街」？
2. **相機跟隨＋主角 billboard**：Wujie sprite 進場、走動、相機跟隨。📸 視差/景深感對？
3. **移軸景深＋輝光＋調色＋暈影**：WorldEnvironment 調到「精緻箱庭」非「紙板」。📸 反覆迭代。
4. **氛圍**：雨/霧/霓虹 omni 光池。
5. **（滿意後才）接進 MapScreen 西門區**：SubViewport 整合、觸發/傳送/MapHUD 串接。

## 8. 驗證與成功判準
- **驗證工具**：沿用 `test/CaptureProto.gd` 那套（視窗版 `tools/godot/Godot_v4.5-stable_win64.exe` 載入場景→等 ~180 frame→存 PNG→Read 自檢）。HD-2D 的 DOF/glow 一定要 GPU 視窗才看得到，headless 只能驗腳本/節點/屬性。
- **成功判準**：使用者實機走西門街，**有明顯景深＋運鏡＋箱庭精緻感、且不覺得「假」**＝過關，再決定照樣轉其他場景。不過＝回頭調或考慮別條路線。

## 9. 風險與既有踩坑（取自 project-3d-environment）
- **掠角糊白**：本案風險低（固定俯角看箱庭、非貼街掃掠角；立板靠燈光不靠強自發光）。仍守「自發光壓低、ACES 去飽和、bloom floor 抬白」三戒。
- **CameraRig NodePath export 載入掉值**：用 group fallback 抓 player（既有解法）。
- **Meshy 透明材質 bug**：道具/角色若用 GLB 需 `_fix_meshy_materials`（本案主角改用 2D sprite 可免）。
- **runtime 不自動匯入**：新素材先 `--import`。
- **SubViewport 整合**：輸入/滑鼠事件、解析度、MapHUD 疊層需驗證（整合階段才處理，原型獨立場景不涉及）。

## 10. 非範圍 / 後續
- 其他探索場景（破廟/茶攤/軍火庫/其餘街區）轉 HD-2D ＝原型過關後另開計畫。
- 建築去背輪廓化、更多建築變體、人群 NPC billboard、過肩鏡頭微調＝精緻化階段。
- 卡通描邊 depth-only shader：與本案無關（HD-2D 不需描邊）。
