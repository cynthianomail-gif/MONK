# 《和尚逆天》Monk Go Rogue — 遊戲企畫書（官網／設計用）

> 本文件依 **現行程式碼與資料檔（`D:\monk\MONK\data\*.json`）＋最新美術資產** 整理，反映歷經多次改版後的「最終定案版本」。
> 用途：交給 Claude Design 製作**遊戲官網**。人名、劇情、美術風格、以及會用到的**戰鬥圖／角色圖檔案路徑**皆已寫入本文。
> 專案根目錄：`D:\monk\MONK\`。文中資產路徑一律為 **Windows 絕對路徑**，可直接定位檔案。
> 整理日期：2026-07-01

---

## 0. 一頁速覽（給官網首屏）

| 項目 | 內容 |
|---|---|
| **中文名** | 和尚逆天 |
| **英文名** | Monk Go Rogue |
| **一句話定位（Logline）** | 一名破戒和尚以凡軀佛法，逐一「超渡」化身現代財閥的希臘十二主神，奪回被奪走的舍利塔。 |
| **類型** | 3D 探索 ＋ 2D 回合制 RPG（人中之龍式開放探索 × Persona 式戰鬥演出） |
| **美術風格** | 《大神 Ōkami》日式水墨／浮世繪 —— 墨筆描邊＋和紙肌理＋金箔＋天然色（去霓虹） |
| **舞台** | 架空日本都會「**新梵京**」——被跨國巨頭「萬神殿集團」掌控的信仰之城 |
| **主角** | **無戒**（和尚，可切換三種職業修行路線） |
| **最終目標** | 超渡十二主神、奪回鎮寺聖物「**舍利塔**」，讓城市的信仰重歸眾生 |
| **引擎／平台** | Godot 4.5（Forward+），PC | 
| **目前版本** | **DEMO＝第一章（戰神阿瑞斯）**，可完整跑通；第 2～12 章為骨架 |
| **核心賣點** | ① 佛教 × 希臘神話 × 日式水墨的獨特混搭 ② 業障／功德雙修雙結局張力 ③ 三職業切換戰鬥 ④ 破戒與熱血奧義的過場演出 |

---

## 1. 世界觀與設定

### 1.1 舞台：新梵京
架空日本都會，一座被跨國巨頭「**萬神殿集團**（Pantheon Corp.）」掌控的信仰之城。表面繁華現代，實則城市的每一條命脈——物流、海運、糧食、建設、娛樂、媒體、酒業、私軍、科技、電網——都握在集團高層手中。

**核心設定（黑色反諷）：** 萬神殿集團的高層，是**降臨現代的希臘十二主神**。祂們把神力煉成資本，拿人類的**慾望與信仰**當企業能源，十二主神各據一條城市命脈。

### 1.2 地名（日式反皮，全漢字）
> 遊戲原型為台味都會，最終版把專有名詞改為日式漢字地名（保留中文文本，只換地名，讓畫風與舞台統一為日本）。

| 遊戲內地名 | 對應原型 | 性質 |
|---|---|---|
| **新梵京** | 都市總稱 | 信仰之城 |
| **櫻木町** | 西門町 | 鬧區／電車站 |
| **門前町** | 萬華舊區 | 神社前老街 |
| **歌舞坂** | 林森北路 | 花街／夜生活 |
| **神社（荒廢神社）** | 破廟／龍山寺 | 主角據點 |
| **軍火庫區** | — | 阿瑞斯地盤 |
| 電車 | 捷運 | 交通 |

### 1.3 開場前提
主角無戒的**破神社**遭萬神殿建設與保全強拆，鎮寺之寶「**舍利塔**」（貫穿全作的聖物 MacGuffin）被奪走。無戒赴保全總部討要，發現負責人竟是戰神阿瑞斯——就此以凡軀佛法向諸神宣戰。

---

## 2. 故事大綱

### 2.1 主線骨幹：跨神系「物理超渡」
無戒的復仇＝**十二章 × 十二神 × 十二因緣**。一章一神（希臘十二主神），線性推進、神力遞增；每通一章即以佛法「超渡」（擊敗＋點化）該神，並解鎖對應的十二因緣成就。舍利塔自序章被奪（`relic_stolen`）到第十二章奪回（`relic_recovered`）貫穿全程。

### 2.2 十二章一覽（章序＝敵神登場序）

| 章 | 神祇 | 掌控領域 | 迷宮／舞台 | 通章成就（十二因緣） |
|---|---|---|---|---|
| **1** | **阿瑞斯 Ares**（新梵戰神） | 武力・保全・軍火 | 萬神殿保全總部 / 軍火庫 | 無明 |
| 2 | 荷米斯 Hermes | 物流・快遞・地下情報 | 物流轉運中心 | 行 |
| 3 | 波賽頓 Poseidon | 海運・港口・走私 | 豪華郵輪 | 識 |
| 4 | 狄蜜特 Demeter | 食品・農業・糧食壟斷 | 垂直農場 | 名色 |
| 5 | 赫菲斯托斯 Hephaestus | 建設・重工・軍火（拆神社母公司） | 建案工地 / 地下兵工廠 | 六入 |
| 6 | 阿芙蘿黛蒂 Aphrodite | 娛樂・夜生活・偶像 | 巨型演唱會現場 | 觸 |
| 7 | 阿波羅 Apollo | 媒體・音樂・輿論 | 直播塔 / 電視台 | 受 |
| 8 | 戴歐尼修斯 Dionysus | 酒業・夜店・成癮經濟 | 地下夜店 | 愛 |
| 9 | 阿緹蜜絲 Artemis | 私人軍事・狩獵・賞金 | 會員制狩獵會所 | 取 |
| 10 | 雅典娜 Athena | 科技・數據・監控・AI | 演算法中心 | 有 |
| 11 | 赫拉 Hera | 政商聯姻・權勢核心（宙斯之后・二把手） | 集團宴會廳 | 生 |
| **12** | **宙斯 Zeus**（眾神之王・CEO） | 電網・能源・權力 | 奧林帕斯大廈頂樓停機坪 | 老死 |

**結局：** 第十二章攻上奧林帕斯大廈頂樓，以凡軀佛法迎戰化身現代 CEO、掌控全城電網的宙斯，於漫天狂雷中奪回舍利塔，新梵京的信仰重歸眾生（`ending_true`）。

### 2.3 第一章詳細劇情（DEMO 內容）
**〈神社的倒塌與諸神現身〉** —— 九段結構：
1. **開場強拆**：破神社遭強拆、舍利塔被奪（過場 `opening_temple_falls`）。
2. **雨夜茶屋**：落魄進城，雨夜茶攤遇斷臂修練者**了塵**；他道破萬神殿，一一引介十二主神。
3. **聚焦阿瑞斯**：了塵指點幾位知情或需援手的人，傳無戒一招**羅漢伏虎**。
4. **修為門檻**：了塵確認無戒修為（需解鎖 ≥5 招）才肯帶路。
5. **直闖總部**：了塵領路，直闖萬神殿保全總部。
6. **軍火庫第一波**：撞上第一波重武裝安保（`pantheon_guard`）。
7. **軍火庫深入**：殺穿第二波雜兵。
8. **真身現形**：軍火庫深處，負責人現出真身——戰神阿瑞斯（過場 `ares_intro`）。
9. **決戰超渡**：無戒宣戰，當場超渡戰神阿瑞斯（Boss 戰，兩階段）。

---

## 3. 角色設定

> **美術狀態說明**：全卡司已重製為 okami 水墨立繪（`game_ready` 系列）。以下每位角色附上官網最適用的**全身立繪（透明底 PNG）**與**遊戲內胸像**路徑。

### 3.1 主角：無戒（Wujie）
- **定位**：破戒和尚。名字「無戒」＝無戒律／破盡戒律，與其修行者身份形成反諷。以凡軀佛法逆天鬥神。
- **外型**：硬派成熟臉、洗舊灰袈裟／米白內襟；隨職業換裝。
- **三職業（可切換修行路線）**：
  | 職業 | 走向 | 裝束 | 戰鬥資源 |
  |---|---|---|---|
  | **苦行僧 ascetic** | 業障（暴力破壞） | 灰袈裟 | 業障 karma |
  | **念經僧 chanter** | 功德（神聖救贖） | 金黃赭金袈裟＋念珠 | 功德 merit |
  | **化緣僧 beggar** | 混合／奪金 | 褐色破補行腳衣＋缽 | 混合 |

**主角美術路徑（`game_ready` 全身透明底，官網主視覺首選）：**
- 苦行僧正面：`D:\monk\MONK\assets\art_direction\new_ink_shrine_style\characters\game_ready\wujie_ascetic_front_game_ready.png`
- 念經僧正面：`...\game_ready\wujie_chanter_front_game_ready.png`
- 化緣僧正面：`...\game_ready\wujie_beggar_front_game_ready.png`
- 表情變體（苦行/念經/化緣 × calm/angry/happy/surprised）：`...\game_ready\wujie_<job>_emote_<mood>_front_game_ready.png`
- 戰鬥背面站姿：`...\game_ready\wujie_<job>_back_game_ready.png`、受傷 `wujie_<job>_hurt_back_game_ready.png`

**遊戲內實際使用：**
- VN 對話胸像：`D:\monk\MONK\assets\2d\portraits\wujie\bust\wujie_ascetic_<mood>.png`
- 戰鬥站姿（背面）：`D:\monk\MONK\assets\2d\portraits\wujie\cut\wujie_<job>.png`、受傷 `wujie_<job>_hurt.png`

### 3.2 引路人：了塵（Liaochen）
- **定位**：斷臂還俗的修練者，戴**菅笠的斷臂浪人（rōnin）**（注意：非老和尚）。劇情登場、不參戰。第一章道破萬神殿、傳無戒羅漢拳、領路殺進軍火庫。
- 全身：`D:\monk\MONK\assets\art_direction\new_ink_shrine_style\characters\game_ready\liaochen_front_game_ready.png`
- 胸像：`D:\monk\MONK\assets\2d\portraits\npcs\bust\npc_liaochen.png`

### 3.3 女主角：櫻（Cherry）
- **定位**：花街女子（原設定酒店女公關，最終版美術改為**藝伎 geisha**）。近 30，眼帶倦與故事。有個人支線「櫻的債」，破色戒後可成為戰鬥後援。
- 全身（藝伎）：`...\game_ready\cherry_geisha_front_game_ready.png`；表情 `cherry_geisha_emote_<neutral|smile|sorrow|angry>_front_game_ready.png`
- 胸像：`D:\monk\MONK\assets\2d\portraits\cherry\bust\cherry_<neutral|smile|sorrow|angry>.png`

### 3.4 反派：萬神殿集團 · 希臘十二主神
> 現代造型（西裝／制服）＋神話特色融入服飾配飾。DEMO 只有阿瑞斯完整實作。

**第一章 Boss —— 阿瑞斯 Ares（新梵戰神）**
- 設定：集團的拳頭，掌保全、傭兵與軍火庫。油頭、黑西裝、紅戰矛徽章領針，崇尚力量、輕蔑談判。奪走舍利塔者。
- 數值：HP 2000、二階段；第二階「覺醒態」＝黑西裝＋全身紅熔岩裂紋＋背後鍛造齒輪/刀刃翼＋雙手紅焰。
- 全身：`...\game_ready\ares_front_black_red_game_ready.png`
- 攻擊/表情：`ares_attack_...`、`ares_emote_<neutral|pained|mocking_laugh>_...`
- 二階：`ares_phase2_front_black_red_game_ready.png`、`ares_phase2_attack_...`
- 戰鬥立繪（cut）：`D:\monk\MONK\assets\2d\portraits\boss\cut\ares_<base|attack|pained|mocking_laugh|phase2|phase2_attack>.png`
- **阿瑞斯特效 FX（10 張，官網動態演出可用）**：`D:\monk\MONK\assets\2d\portraits\boss\fx\` 內含 `idle_mist / ember_sparks / hit_impact / attack_burst / phase2_transform_burst / projectile_trail / attack_warning_ring / charge_aura / impact_explosion / defeat_dissolve`

**十二神立繪（官網「諸神畫廊」用）：**
- ✅ **最新 okami 概念圖（16:9 橫幅，建議官網採用）**：`D:\monk\MONK\assets\art_direction\new_ink_shrine_style\gods\concepts\<god>_concept_16x9.png`
  （`<god>` = ares / hermes / poseidon / demeter / hephaestus / aphrodite / apollo / dionysus / artemis / athena / hera / zeus）
- ⚠ 舊版半寫實立繪（遊戲內第一章 12 神介紹仍暫用，畫風較舊）：`D:\monk\MONK\assets\2d\gods\<god>.jpg`

### 3.5 支線 NPC（第一章／神社區）
| 顯示名 | 身份 | 地點 | 支線 |
|---|---|---|---|
| **翔太** | 街頭藝人 | 櫻木町站 | 街頭藝人的最後一場 |
| **澪** | 迷路背包客 | 櫻木町站 | 迷路的背包客（三選一分支） |
| **水野** | 佛具店老闆娘 | 櫻木会館 3F | 水野的念珠債（解鎖商店特殊道具） |
| **健太** | 電玩城少年 | 櫻木会館 5F | 電玩少年的挑戰書（木魚節奏對戰） |
| **大村師傅** | 老廚師 | 禪味燒肉 | 大村師傅的最後一鍋（揭露師父過去） |
| **大輔** | 失業工程師 | 禪味燒肉 | 失業工程師的第三杯 |
| **蝶子** | 媽媽桑 | 紫醉金迷俱樂部 | 媽媽桑的神秘委託 |
| **八重** | 老香客 | 荒廢神社 | 八重找孫子（真結局旗標之一） |
| **源造** | 神社前流浪漢（前董事長） | 荒廢神社 | 流浪漢源造的過去 |
| **鐵叔** | 軍火庫工人 | 軍火庫區 | 兩態（受制 locked／獲救 freed），打贏阿瑞斯前鎖互動 |

- NPC 胸像：`D:\monk\MONK\assets\2d\portraits\npcs\bust\npc_<key>.png`
  （key = ah_ming[翔太] / rei[澪] / zheng_ma[水野] / jie[健太] / ah_zhong[大村] / david[大輔] / cai_ma[蝶子] / grandma[八重] / lao_wang[源造]）
- 鐵叔：`...\npcs\bust\npc_tie_shu_locked.png`、`npc_tie_shu_freed.png`
- NPC 全身（game_ready）：`...\game_ready\<key>_front_ares_red_game_ready.png`

### 3.6 一般敵人（6 種）
| ID | 名稱 | 出沒區 | 特性 |
|---|---|---|---|
| street_punk | 櫻木町混混 | 神社區 | 叫兄弟增援 |
| corrupt_vendor | 黑心攤販 | 神社區 | 偷金、放毒 |
| night_ghost | 深夜孤魂 | 神社區 | 深夜限定、吸功德 |
| drunk_guard | 醉漢保鑣 | 神社區 | 成對出現、護主 |
| temple_ghost | 神社惡鬼 | 神社區 | **菁英**、再生、業障爆發 |
| pantheon_guard | 萬神殿重裝保全 | 軍火庫區 | 第一章雜兵、呼叫支援 |

- 敵人立繪：`D:\monk\MONK\assets\2d\portraits\enemies\enemy_<punk|vendor|ghost|guard|temple_ghost>.png`
- 全身（game_ready）：`...\game_ready\enemy_<punk|vendor|ghost|guard|shrine_ghost>_front_ares_red_game_ready.png`

---

## 4. 核心玩法系統

### 4.1 雙值系統：業障 ↔ 功德
- **業障（karma）** 0–100：暴力、奪取、破戒累積；催動苦行僧強力技。
- **功德（merit）** 0–100：救助、超渡、行善累積；催動念經僧神聖技。
- 兩值拉扯構成道德抉擇與結局走向。UI 以「拔河條」呈現。

### 4.2 三大破戒（風險×獎勵，觸發專屬過場）
| 破戒 | 觸發 | 過場 |
|---|---|---|
| 飲食戒（食） | 屋台大啖葷腥 | `break_food`（紅面鬼煞） |
| 貪戒（財） | 貪 koban 金光 | `break_greed`（金煞） |
| 色戒（色） | 花街／座敷藝伎環繞 | `break_lust`（慾煞） |

### 4.3 戰鬥系統（2D 回合制，Persona 式站立對峙）
- **呈現**：敵我去背立繪站在共用水墨背景上（程式呼吸微動）；無戒背面、敵人正面。
- **傷害屬性**：物理 physical／業障 karma／功德 merit；命中**弱點 → Down**（可續行動）。
- **技能共 21 招**（三職各 7），含 **3 招熱血奧義（處決技）**，各帶專屬過場：
  - 如來神掌 `tathagata_palm`（業障滿值，過場 `heat_tathagata`／如来巨掌）
  - 金剛薩埵超渡大陣 `diamond_sutra`（功德滿值，過場 `heat_diamond`／金剛界曼荼羅）
  - 千手化緣大法 `thousand_hands`（業障≥80＋持 3000 金，過場 `heat_thousand`／千手観音）
- 戰鬥後援：櫻（破色戒後）。

### 4.4 3D 探索（大神水墨風自由行走）
- **兩區**：
  - **神社區（shrine）**：淺墨平靜 hub，涵蓋所有商店／支線／茶攤／櫻（`ShrineStreet`）。
  - **軍火庫區（armory）**：濃墨壓迫，阿瑞斯地盤，街尾熔鑄爐＝Boss 巢（`ArmoryDistrict`）。
- 每區灑置代表性 3D NPC（了塵／水野／翔太／大村／櫻／鐵叔），資料驅動觸發地點。
- 區間移動＝手機／經書「快速移動」選單。

### 4.5 小遊戲（3 種）
- **木魚節奏 `wooden_fish_rhythm`**（賣唱／電玩少年對戰）
- **端湯上塔 `soup_carry`**（105 打工）
- **化緣托缽 `beggar_challenge`**（打工／地圖化緣）

### 4.6 選單：手機（入世）× 經書（出世）
- **手機 5 頁籤**：任務（主線入口＋十二因緣圖鑑）／情報（神祇情報碎片蒐集）／移動（電車＋計程車）／打工（105）／設定。
- **經書**：技能頁（三職 21 技、解鎖進度、「習得」）／狀態頁（三職修為雷達、業障↔功德拔河、HP/金幣/成就）。
- **技能習得（「了塵為師」）**：解鎖分三態 `condition_met → learnable → learned`，達成條件後需回經書點「習得」才會用。

### 4.7 商店（水野佛具店）
- 道具＋背包＋戰鬥「道具」指令。品項：金瘡藥（回 HP200）／業障結晶（補業障 40）／護身符（金身護盾 250）。

### 4.8 成就：十二因緣
- 十二章各對應一因緣：**無明→行→識→名色→六入→觸→受→愛→取→有→生→老死**。通章即證。

---

## 5. 美術風格指南（官網設計核心）

### 5.1 總方向：《大神 Ōkami》日式水墨／浮世繪
全遊戲統一走**日式水墨**：
- **墨筆描邊**（毛筆感輪廓、飛白、濃淡）
- **平塗 cel ＋ 和紙肌理**
- **金箔** 點綴
- **天然色系**：墨黑 / 金 / 硃紅 / 靛青 / 米白
- **明確去霓虹**（賽博龐克霓虹已全面淘汰，不要用）

### 5.2 兩種質感並存
1. **3D 探索**：幾何盒體 ＋ 水墨 toon shader（螢幕空間 Laplacian 墨描邊、兩階墨色、遠景淡入紙色）。
2. **2D 立繪／戰鬥背景**：在 okami 色盤上做**半寫實厚塗（painterly）＋風化做舊**的暗調渲染（對齊戰鬥背景 `bg_battle_ximen` 的深黑／暖燈／硃紅鳥居／濕反光／雨霧 tone）。

### 5.3 UI 色系：暗金 × 黑（karma 動態變色）
- 主色＝**暗金（gold-on-near-black）**；功德高→金光神聖；業障高→漸變墮落色（暗紅／毒紫）。
- 紅只當 accent／業障側，不當主色。金配黑取得 P5「紅配黑」同級衝擊、但更貼佛教、不撞既有作品。
- UI/選單/道具/技能/圖示皆為**純程式暗金×黑（StyleBox＋文字/emoji）**，無點陣圖示。

### 5.4 官網氛圍建議
- 主色：近黑底（`#0B0B0B` 級）＋暗金（`#C9A861` 級）＋硃紅 accent。
- 質感：和紙紋理、墨暈、金箔碎點、鳥居剪影、墨雲。
- 北極星參考圖（風格錨點）：`D:\monk\_art_review\_style1b_okami_b.png`（黑袍僧背影＋水墨樓宇＋金燈＋墨雲）。

---

## 6. 官網素材清單（可直接取用的檔案路徑）

> 以下皆為 **PNG（多數透明底）／JPG**，位於 `D:\monk\MONK\` 專案內。建議官網優先採用 `game_ready`（全身透明立繪）＋ okami 戰鬥背景 ＋ god concepts。

### 6.1 主視覺・角色全身立繪（透明底，首選）
資料夾：`D:\monk\MONK\assets\art_direction\new_ink_shrine_style\characters\game_ready\`
- 無戒三職：`wujie_ascetic_front_game_ready.png`、`wujie_chanter_front_game_ready.png`、`wujie_beggar_front_game_ready.png`
- 阿瑞斯：`ares_front_black_red_game_ready.png`、`ares_phase2_front_black_red_game_ready.png`
- 了塵：`liaochen_front_game_ready.png`　櫻：`cherry_geisha_front_game_ready.png`
- 支線 NPC：`<key>_front_ares_red_game_ready.png`
- 敵人：`enemy_<punk|vendor|ghost|guard|shrine_ghost>_front_ares_red_game_ready.png`

### 6.2 戰鬥背景（okami 水墨環境，16:9，適合區塊底圖）
資料夾：`D:\monk\MONK\assets\2d\backgrounds\`

| 檔名 | 場景 |
|---|---|
| `bg_battle_ximen.png` | 櫻木町夜街／神社參道 |
| `bg_battle_pantheon.png` | 萬神殿總部／軍火庫廠房內景 |
| `bg_battle_ares_forge.png` | 阿瑞斯 Boss 戰・軍火熔鑄爐 |
| `bg_battle_wanhua.png` | 門前町老街 |
| `bg_battle_linsen.png` | 歌舞坂花街 |
| `bg_battle_temple.png` | 荒廢神社 |
| `bg_battle_boss.png` / `bg_battle_ares_rooftop.png` | 特殊／Boss 高樓頂 |

### 6.3 十二神畫廊
- ✅ 最新 okami：`D:\monk\MONK\assets\art_direction\new_ink_shrine_style\gods\concepts\<god>_concept_16x9.png`（12 檔）
- 舊版半寫實：`D:\monk\MONK\assets\2d\gods\<god>.jpg`（12 檔）

### 6.4 Boss 阿瑞斯・戰鬥立繪＋特效
- 戰鬥立繪（cut）：`D:\monk\MONK\assets\2d\portraits\boss\cut\ares_*.png`
- 特效 FX（10 張）：`D:\monk\MONK\assets\2d\portraits\boss\fx\*.png`

### 6.5 角色胸像（VN，透明底方形）
- 無戒：`D:\monk\MONK\assets\2d\portraits\wujie\bust\wujie_ascetic_<mood>.png`
- 櫻：`D:\monk\MONK\assets\2d\portraits\cherry\bust\cherry_<mood>.png`
- NPC／了塵／鐵叔：`D:\monk\MONK\assets\2d\portraits\npcs\bust\npc_*.png`

### 6.6 過場關鍵幀（故事區塊／預告圖）
資料夾：`D:\monk\MONK\assets\cutscenes\`
- 開場神社倒塌：`opening_temple_falls\ok_01_pov.png` ～ `ok_06_lineup.png`（6 張 okami 定格，2752×1536）
- 阿瑞斯二階變身：`ares_phase2\`　雨夜遇了塵：`ch1_aftermath_wake\ok_tea_stall.png`　阿瑞斯現身：`ch1_ares\ok_ares_reveal.png`

### 6.7 3D 模型（如需 3D 展示）
- 主角：`D:\monk\MONK\assets\3d\characters\wujie\wujie_walk.glb`
- NPC：`D:\monk\MONK\assets\3d\characters\npcs\<key>.glb`（ah_ming / ah_zhong / cherry / liaochen / tie_shu / zheng_ma）

---

## 7. 技術規格

| 項目 | 內容 |
|---|---|
| 引擎 | Godot 4.5，GDScript，Forward+ 渲染 |
| 探索 | 3D 自由行走（CharacterBody3D ＋ Area3D 地點觸發），水墨 toon shader |
| 戰鬥 | 2D 回合制（獨立場景切換） |
| 對話 | Dialogic 2 插件（`.dtl` timeline／`.dch` character） |
| 過場 | PNG 逐幀序列（12/24fps）＋部分 Seedance 影片幀；per-cutscene 配音 `audio.ogg` |
| 資料驅動 | 全內容存 `data\*.json`（主線／支線／敵人／Boss／技能／道具／成就／神祇情報／地區／地圖） |
| 資產管線 | 2D 立繪＝Magnific/Higgsfield（Nano Banana Pro）；3D＝Meshy；風格化首抽＝recraft-v4-1 |

---

## 8. 現況與範圍

### 8.1 DEMO 範圍
**只做第一章（戰神阿瑞斯）**，可完整跑通：探聽十二神情報 → 認識了塵 → 修為門檻 → 突襲軍火庫雜兵 → 決戰超渡阿瑞斯。第 2～12 章保留骨架、暫不填內容。

### 8.2 已完成（系統＋美術）
- 系統：autoloads／戰鬥／3D 水墨 2 區探索／過場／全對話（26 條）／小遊戲×3／選單＋手機 5 app／主線引擎＋第一章九段／成就／神祇情報／技能習得／戰鬥美術——**全部已實作、headless 測試 ALL PASS**。
- 美術 okami 化：8 張戰鬥背景 ✅、VN 胸像／戰鬥站姿 ✅、3D 探索 ✅、`game_ready` 全卡司（含鐵叔 2 態） ✅、全 8 段過場 ✅。

### 8.3 剩餘缺口（官網設計不影響，僅記錄）
1. 第一章開場「了塵介紹 12 神」的背景仍用舊版 `assets\2d\gods\*.jpg`（新 okami concepts 已生、待換）。
2. 無戒 chanter／beggar 的 `calm` 正面表情待補。
3. 實機 GPU 完整跑一次 ch1 demo。
4. DEMO 之後（ch2–12）：11 神 in-game 立繪整合、各章 Boss 數值／迷宮／過場／對話／敵兵。

---

## 附錄：官網頁面建議（給 Claude Design）

1. **首屏 Hero**：無戒苦行僧全身立繪（透明底）＋標題「和尚逆天 Monk Go Rogue」＋ logline，背景用 `bg_battle_ximen.png` 或北極星水墨圖，暗金×黑基調。
2. **世界觀**：新梵京設定＋萬神殿集團「神即財閥」核心反諷；配墨雲／鳥居視覺。
3. **角色**：無戒三職切換（互動卡）＋了塵、櫻；用 `game_ready` 全身圖。
4. **諸神畫廊**：十二主神卡牆（用 `gods\concepts\*_concept_16x9.png`），標領域＋章序。
5. **玩法**：雙值系統／三職業／回合制戰鬥／破戒＆奧義過場／3D 水墨探索。
6. **戰鬥演出**：阿瑞斯 Boss（含二階變身圖＋ FX），配戰鬥背景。
7. **美術風格**：水墨風格說明＋色盤（墨黑/金/硃紅/靛青/米白）。
8. **Footer**：DEMO＝第一章、Godot 4.5、PC。
