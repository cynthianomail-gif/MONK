# 《和尚逆天》互動式官網 — 完整技術 spec（執行版）

- 建立：2026-07-06，由 Fable 5 撰寫。**本文件的定位＝施工圖**：技術選型已鎖死、核心代碼已內附、每區有驗收條件。執行模型（Sonnet/Opus/Codex）照做即可，不需要也**不允許**重新做架構決策。
- 上游文件：`2026-07-06-pv-website-plan.md`（PV＋官網總規劃，官網章節以本文件為準）。
- 交付物：可部署的靜態互動官網，本機 `npm run dev` 可預覽、`npm run build` 產出 `dist/`。

---

## 0. 給執行模型的鐵則（開工前必讀）

1. **全域守則的「指揮官不下場」不適用於你——你就是被派下場做事的人，禁止使用 Agent 工具轉包。**（歷史教訓：轉包鏈每層燒 60k tokens 零產出）
2. **不准換技術選型**：不用 React/Vue/Svelte/Three.js/Tailwind。本文件選 Vite + 原生 TypeScript + GSAP + Lenis 是刻意的（理由見 §1），覺得「用 X 會更好」＝寫進回報的意外發現欄，不准動手。
3. 每個里程碑（§10）做完必須：`npm run build` 零錯誤 → 本機預覽實測該里程碑驗收條件 → 截圖佐證 → 才算完成。「程式碼看起來對」不算。
4. 素材缺失（影片/圖還沒產出）時：用 §8 指定的佔位方式繼續施工，**不准**自己生成美術素材、不准改設計等素材。
5. 同一做法失敗 2 次就停，換方法或升級，不硬試第 3 次。
6. Windows 環境：PowerShell 5.1 沒有 `&&`；檔案操作用 Read/Write/Edit 工具；npm 指令一條一條跑。

---

## 1. 技術選型（已鎖死）

| 項目 | 選定 | 理由（為什麼不是別的） |
|---|---|---|
| 建置 | **Vite 5 + TypeScript** | 零配置、HMR 快、build 產物純靜態。不用框架：本站是「一頁式演出」不是「狀態管理問題」，原生 DOM + GSAP 對執行模型更好驗證、bundle 更小 |
| 動畫 | **GSAP 3 + ScrollTrigger**（npm `gsap`，已完全免費） | 業界行銷網站標準（P5/Metaphor 級網站同類技術）；pin/scrub/timeline 一套解決，不自己造輪子 |
| 平滑捲動 | **Lenis**（npm `lenis`） | 與 ScrollTrigger 官方整合模式成熟（§4.1 已附代碼） |
| 水墨演出 | **原生 WebGL fragment shader**（§6.1 附完整 GLSL）＋ CSS fallback | 30 行 shader 解決墨暈揭示，零外部資產依賴；不引 Three.js（為一個 shader 拉 600KB 不划算） |
| 字體 | **Noto Serif TC**（標題）＋ **Noto Sans TC**（內文），npm `@fontsource/*` 自託管 | 避免 Google Fonts 網路依賴與 FOUT；Logo 一律用圖檔不用字體 |
| 樣式 | 手寫 CSS（design tokens + 原生 nesting） | 不用 Tailwind：斜切/遮罩/自訂動畫類設計用原生 CSS 更直接 |
| 部署 | **Vercel**（首選，零配置）或 GitHub Pages（備選，vite.config 設 `base`） | 免費、推 git 即部署 |
| 依賴總清單 | `gsap`、`lenis`、`@fontsource/noto-serif-tc`、`@fontsource/noto-sans-tc`、devDeps：`vite`、`typescript` | **超出此清單的任何 npm 套件都要在回報中說明理由** |

效能預算（§9 詳述）：JS bundle（gz）≤ 150KB、首屏影片 ≤ 8MB、Lighthouse Performance ≥ 85 / Accessibility ≥ 95。

---

## 2. 專案結構

站點獨立於 Godot 專案之外，新開目錄 `D:\monk\website\`：

```
website/
├── .claude/launch.json          # preview 工具用（§11 附內容）
├── package.json
├── tsconfig.json
├── vite.config.ts
├── index.html                   # 全部 section 的骨架都在這一頁
├── public/
│   ├── media/
│   │   ├── video/               # pv.webm/pv.mp4、各 loop webm
│   │   ├── img/                 # AVIF/WebP + PNG fallback
│   │   └── audio/               # bgm.mp3、sfx_woodfish.mp3、sfx_bell.mp3
│   └── presskit/monk_presskit.zip
└── src/
    ├── main.ts                  # 進場順序：fonts → loader → 各 section init
    ├── styles/
    │   ├── tokens.css           # §3 design tokens
    │   ├── base.css             # reset、字體、通用斜切、sr-only
    │   └── sections/*.css       # 每區一檔
    ├── core/                    # 全站系統（§4）
    │   ├── scroll.ts            # Lenis + ScrollTrigger 整合
    │   ├── audio.ts             # AudioManager
    │   ├── beads.ts             # 佛珠進度導航
    │   ├── cursor.ts            # 墨點游標
    │   ├── inkReveal.ts         # WebGL 墨暈揭示（§6.1）
    │   └── utils.ts             # prefersReducedMotion()、lazyVideo() 等
    ├── sections/                # 每區一模組（§5）
    │   ├── loader.ts  hero.ts  story.ts  characters.ts
    │   ├── gameplay.ts  parlor.ts  gallery.ts  footer.ts
    └── data/
        ├── characters.json      # §7 schema
        ├── gameplay.json
        ├── gallery.json
        └── strings.json         # 全站文案（zh-TW），文案不寫死在 HTML/TS
```

原則：**內容資料驅動**——角色、圖庫、文案全在 `data/*.json`，改內容不碰程式碼（方便日後揭曉十二神時只改 JSON）。

---

## 3. 設計系統

### 3.1 色票（tokens.css）

```css
:root {
  --ink-black:  #14120f;   /* 主底：墨黑（帶暖） */
  --paper:      #f2ead8;   /* 紙白：內文底、反白區 */
  --gold:       #e8b84b;   /* 霓虹金：主強調（承遊戲 UI 金名牌） */
  --gold-dim:   #9a7a2e;
  --vermilion:  #c73e3a;   /* 朱紅：次強調（印章、警示、CTA hover） */
  --neon-cyan:  #43d9d9;   /* 霓虹青：點綴限定（招牌、掃線），用量 <5% */
  --ink-60: rgba(20,18,15,.6);
  --paper-10: rgba(242,234,216,.1);
  --skew: -6deg;            /* 全站統一斜切角 */
  --ease-brush: cubic-bezier(.25,1,.35,1); /* 筆刷感 easing，全站動畫統一用 */
}
```

### 3.2 版式語言（承遊戲 UI，執行時不准偏離）

- **斜切面板**：區塊/卡片/按鈕用 `clip-path: polygon()` 做 −6° 斜切邊，相鄰 section 交界處以斜切互咬（P5 語言）。統一寫成 utility class `.cut-panel`、`.cut-btn`。
- **金名牌**：標題採「墨黑底＋金字＋左側朱紅印章方塊」的名牌條，斜切。
- **紙紋**：`--paper` 區塊疊一層低透明度紙紋（CSS `background-image` 用 8KB 內的 tiled webp；沒有素材前用純色）。
- **墨暈邊**：section 交界除斜切外，備選水墨暈染邊（PNG mask，素材見 §8）。
- 標題字：Noto Serif TC 900；內文：Noto Sans TC 400/500；數字/英文點綴：同字體，不另引英文字型。

### 3.3 動態語言

- 進場一律「筆刷感」：`--ease-brush`、由 clip-path 或 mask 揭示，**不用** fade-in 了事。
- 互動回饋帶「打擊感」：hover 位移 2–4px + 陰影瞬變，模仿遊戲 hit-stop 的急停感。
- `prefers-reduced-motion: reduce` → 關閉所有 pin/scrub/視差/自動輪播，內容直接靜態呈現（§9.3）。

---

## 4. 全站系統（core/，先於任何 section 施工）

### 4.1 scroll.ts — Lenis × ScrollTrigger（官方整合模式，照抄）

```ts
import Lenis from 'lenis';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

export const lenis = new Lenis({ lerp: 0.1, wheelMultiplier: 1 });
lenis.on('scroll', ScrollTrigger.update);
gsap.ticker.add((t) => lenis.raf(t * 1000));
gsap.ticker.lagSmoothing(0);

export function scrollToSection(id: string) {
  lenis.scrollTo(`#${id}`, { offset: 0, duration: 1.2 });
}
```

### 4.2 audio.ts — AudioManager

規格：
- 首次使用者手勢（loader 的木魚點擊，§5.1）才建立 `AudioContext`——瀏覽器自動播放政策所迫，這也是 loader 存在的理由之一。
- BGM：60s loop（PV 音樂的 web 剪短版），音量 0.35，`<audio loop>` 即可不必 WebAudio。
- SFX：木魚（互動回饋通用音）、鐘（section 進場）。用 WebAudio `AudioBuffer` 池避免連點延遲。
- 右上角固定「音」字按鈕：靜音切換，狀態存 `localStorage('monk-muted')`，預設**不靜音但等手勢後才播**。
- `document.visibilitychange` 隱藏時暫停 BGM。

```ts
class AudioManager {
  private ctx?: AudioContext;
  private buffers = new Map<string, AudioBuffer>();
  private bgm = new Audio('/media/audio/bgm.mp3');
  muted = localStorage.getItem('monk-muted') === '1';

  async unlock() {            // loader 木魚點擊時呼叫
    this.ctx ??= new AudioContext();
    await Promise.all(['sfx_woodfish','sfx_bell'].map(async n => {
      const ab = await fetch(`/media/audio/${n}.mp3`).then(r => r.arrayBuffer());
      this.buffers.set(n, await this.ctx!.decodeAudioData(ab));
    }));
    this.bgm.loop = true; this.bgm.volume = 0.35;
    if (!this.muted) this.bgm.play();
  }
  sfx(name: string, rate = 1) {
    if (this.muted || !this.ctx) return;
    const src = this.ctx.createBufferSource();
    src.buffer = this.buffers.get(name)!; src.playbackRate.value = rate;
    src.connect(this.ctx.destination); src.start();
  }
  toggleMute() { /* 略：反轉 muted、pause/play bgm、寫 localStorage */ }
}
export const audio = new AudioManager();
```

### 4.3 beads.ts — 佛珠進度導航（本站招牌組件）

- 桌面：畫面右緣固定一串垂直佛珠（SVG，每顆 = 一個 section，共 7 顆＋串線）。
- 當前 section 的珠子放大 1.3x 並發金光（`filter: drop-shadow`），過場時珠子沿串線滑動一顆的距離。
- 點珠子 → `scrollToSection()`＋木魚 SFX。hover 顯示 section 名（斜切 tooltip）。
- 實作：每個 section 建 `ScrollTrigger({ trigger, start:'top center', end:'bottom center', onToggle })` 更新 active index；珠子高亮用 gsap tween。
- 行動版：退化為底部細進度條（金色），不做珠串。

### 4.4 cursor.ts — 墨點游標（僅桌面、非 reduced-motion）

- 原生游標隱藏（`cursor:none` 只套在桌面 hover-capable media query）。
- 一顆 12px 墨點 div + 一層 24px 空心圈 lerp 跟隨（`x += (tx-x)*0.15` 每幀）；可點擊元素 hover 時圈變金色並放大。
- 掉幀保險：`pointerdown` 時墨點迸開小墨滴（3–4 顆 CSS 粒子）。
- **必須**保留鍵盤操作可視 focus ring（`:focus-visible` 金色 outline），游標特效不得犧牲無障礙。

### 4.5 utils.ts

- `prefersReducedMotion()`：讀 media query，全站動畫模組進場前都要查。
- `lazyVideo(el)`：`IntersectionObserver` 進視口才把 `data-src` 塞進 `<source>` 並 `load()`，離開視口 `pause()`。
- `loadJSON<T>(path)`：fetch data/*.json 的統一入口。

---

## 5. 分區實作規格（index.html 順序）

每區格式：**版面 → 互動 → 實作要點 → 素材 → 驗收條件**。

### 5.1 Loader（進站儀式）

- **版面**：滿版墨黑。中央一個木魚圖（SVG 或 PNG），下方「叩木魚，開山門」金字。資產在背景 preload（PV poster、字體、首屏圖）。
- **互動**：點擊木魚 → 木魚縮放 punch 動畫＋「叩」SFX（此點擊同時 `audio.unlock()`）→ 墨暈揭示（§6.1）從點擊座標擴散揭開 Hero → loader 移除。
- **實作要點**：資產載入完成前木魚呈灰色不可點（`aria-disabled`），完成後上金色呼吸光。**必須**提供「跳過」：3 秒後右下角出現細字「直接進入」，點了走 CSS fallback（圓形 clip-path 擴張）。reduced-motion：無動畫直接進站，但仍保留點擊（audio unlock 需要手勢）。
- **驗收**：斷網 throttle Slow 3G 下 loader 不會卡死（有 10s timeout 強制放行）；點擊後 1.5s 內看到 Hero；重整後 mute 狀態保持。

### 5.2 Hero（PV 全幅）

- **版面**：100dvh。背景 `<video>`（pv.webm + mp4 fallback、`muted autoplay loop playsinline`、`poster`）。前景：Logo 圖（水墨字）置中偏左下＋兩顆斜切 CTA：「▶ 觀看完整 PV」（開 lightbox 有聲重播）／「下載 Demo」（連結，未定前 `href="#"` 加 `data-todo`）。右上：音量鈕。
- **互動**：進站墨暈揭示即揭到本區。滑鼠移動 → Logo 與前景做 ±8px 視差（`pointermove` lerp）。往下捲 → 影片容器 `scale: 1 → 0.92` 並被下一區斜切邊咬進來（ScrollTrigger scrub）。PV lightbox：滿版黑底、關閉鈕、Esc 可關、開啟時 `lenis.stop()`。
- **實作要點**：背景 video 用 web 壓縮版（≤8MB、720p、無聲軌）；lightbox 內才載完整 1080p 版（另檔，lazy）。`onloadeddata` 前顯示 poster，避免黑閃。
- **素材**：pv_720_mute.webm/mp4、pv_1080.mp4、poster.avif、logo.png（透底）。**PV 未完成前**：用遊戲實錄 30s 任意片段當佔位，`data-placeholder` 標記。
- **驗收**：行動版 autoplay 正常（playsinline）；lightbox 開啟時背景不可捲動；LCP 元素是 poster 且 < 2.5s（本機 build 後 Lighthouse 驗）。

### 5.3 Story（水墨絵巻・橫向捲軸）— 技術重點區

- **版面**：pin 住的 100dvh 舞台，內容是一幅寬 ~400dvw 的橫向「絵巻」：新梵市天際線→神社街→萬神殿大樓，三層視差（遠景山/天際線、中景街屋、前景人物立繪與文案卡）。文案卡 3–4 張沿途出現：世界觀三句話（logline 拆解）＋「萬神殿集團」名牌。
- **互動**：直向捲動被映射為絵巻橫移（pin + scrub）；三層以 0.4x / 0.7x / 1x 速率移動成視差；文案卡進入視口中央時筆刷揭示＋鐘 SFX（節流：每卡一次）。絵巻頭尾用墨暈 mask 淡出到墨黑。
- **實作要點**（照此模式，勿自創）：

```ts
const panels = gsap.utils.toArray<HTMLElement>('.scroll-layer');
ScrollTrigger.create({
  trigger: '#story', start: 'top top',
  end: () => `+=${innerWidth * 3}`,   // 捲動距離 = 3 個視口寬
  pin: true, scrub: 0.5,
  onUpdate(self) {
    panels.forEach(p => {
      const speed = Number(p.dataset.speed);   // 0.4 / 0.7 / 1
      gsap.set(p, { x: -self.progress * innerWidth * 3 * speed });
    });
  }
});
```

- 行動版/reduced-motion：不 pin，退化為直向三張滿幅圖＋文案卡依序 reveal。
- **素材**：絵巻三層各一張長圖（遠 4096×1080、中 6144×1080、前景=現有立繪去背＋文案卡）。長圖用 Magnific 以遊戲截圖 outpaint 橫向擴展生成（素材工單見 §8）。未有素材前：三層用純色塊＋現有戰鬥背景圖拼接佔位。
- **驗收**：60fps（DevTools Performance 錄一次捲動，主執行緒無 >50ms long task）；橫移總長與捲動距離一致不「漂」；行動版不出現 pin（實測 375px 寬截圖）。

### 5.4 Characters（角色堂）

- **版面**：墨黑底。上排：主要角色大卡（無戒、了塵，之後可加）；下排：**十二神封印格**——12 個斜切小格，已揭曉的顯示立繪，未揭曉的顯示剪影＋「???」＋章節編號。全部由 `characters.json` 驅動。
- **互動**：主卡 hover → 3D tilt（±6°，`transform: rotateX/Y`，由 pointer 位置算）＋**立繪溢出卡框**（立繪 `scale:1.06 translateY(-10px)`，卡框 `overflow:visible` 的 P5 手法）＋金邊發光。點卡 → 全屏 modal：左半滿高立繪、右半名牌＋台詞引言＋三行介紹＋所屬（Dialogic 資料可抄）。modal 開啟 `lenis.stop()`、Esc/背點可關、焦點鎖在 modal 內（focus trap）。十二神已揭曉格 hover 出名字；未揭曉格 hover 微晃＋鎖 SFX（木魚低音）。
- **實作要點**：tilt 只在 hover-capable 裝置啟用；立繪 img 加 `loading="lazy"`；modal 用 `<dialog>` 元素（原生 focus 管理省工）。
- **素材**：現有水墨立繪（無戒、了塵、阿瑞斯可先當第一位揭曉神）；剪影＝立繪 `filter:brightness(0)` 即可不需新素材。
- **驗收**：鍵盤 Tab 可逐卡開 modal 並 Esc 關閉；characters.json 加一筆新角色，不改任何 TS/HTML 即出現在頁面；12 格在 1280/768/375 三寬度不破版。

### 5.5 Gameplay（玩法四象）

- **版面**：紙白底反差區。2×2 斜切大卡：戰鬥／探索／小遊戲／技能習得。每卡：名牌標題＋一句話＋背景影片 loop。
- **互動**：hover（桌面）或進入視口（行動）→ 該卡 webm loop 播放，其餘卡暫停並降飽和；點卡 → 展開為橫幅（卡 flex-grow 動畫），顯示三行特色說明。
- **實作要點**：loop 影片每支 ≤2MB、640px 寬、無聲；用 `lazyVideo()`；同時最多播 1 支（省電）。
- **素材**：PV 實錄各裁 4–6s loop ×4。
- **驗收**：四支影片不同時播放；行動版滑過每卡能自動播放當前卡。

### 5.6 Parlor（地下遊藝場・小遊戲街機廊）— 競賽展示重點區

- **版面**：整區做成霓虹遊藝場內景：墨黑底＋霓虹青/金招牌「地下遊藝場」。橫向 scroll-snap 街機櫃廊：每台街機櫃（CSS 畫的斜切櫃體）螢幕裡播一款小遊戲 loop（飛鏢/輪盤/保齡球/21點/打擊籠，改版後 +3 款只改 JSON）。
- **互動**：櫃體 hover → 螢幕亮起（brightness 提升）＋招牌閃爍；左右箭頭＋拖曳可捲。**彩蛋：電子木魚**——廊末一台特殊櫃「功德無量」，點進去是可玩的小遊戲：畫面中央木魚，點擊/按空白鍵 → 「功德 +1」飄字＋叩聲（音高隨 combo 微升），連擊有節奏判定（間隔 400–800ms 內算 combo），功德數存 localStorage，達 108 解鎖隱藏桌布下載（key art 手機桌布版）。約 120 行 TS，canvas 不必，DOM 動畫即可。
- **實作要點**：飄字用物件池（同屏上限 20 顆）避免 DOM 爆炸；scroll-snap 用原生 CSS `scroll-snap-type: x mandatory`，不用 JS 輪播庫。
- **素材**：5 款小遊戲實錄 loop（各 3–5s、480px、≤1.5MB）；木魚圖沿用 loader 的。
- **驗收**：木魚遊戲鍵盤可玩（空白鍵）；108 解鎖後重整仍保持解鎖；街機廊在觸控裝置可拖曳且 snap 對齊。

### 5.7 Gallery ＋ Press Kit

- **版面**：CSS columns 瀑布流（12–20 張：截圖、立繪、美術圖，`gallery.json` 驅動）＋ 底部 press kit 名牌條：「Press Kit 下載（zip）」＋ fact sheet 表（開發者/引擎 Godot 4/類型/平台/釋出/聯絡）。
- **互動**：點圖 → 自製 lightbox（滿版、左右鍵/滑動切換、Esc 關、預載相鄰 1 張）；圖片進場交錯筆刷 reveal。
- **實作要點**：縮圖 AVIF ≤120KB/張、lightbox 載原圖；lightbox 與 5.2 共用同一組件。zip 內容：logo 透底×2、key art、截圖 10 張原尺寸、fact sheet PDF 或 txt（不做 PDF 也可，txt 即可）。
- **驗收**：20 張全 lazy；lightbox 鍵盤可完整操作；zip 連結有效且 <40MB。

### 5.8 Footer

- 版面：墨黑，中央小 logo＋一行 tagline＋SNS 圖示（未定平台先留 X/YouTube 兩顆，`data-todo`）＋「© 2026 {團隊名}」＋「以 AI 輔助製作」署名列（工具名列點，競賽誠信展示——寫死在 strings.json 方便改）。
- 彩蛋：頁面最底再點一下木魚 icon → 鐘聲一響＋「功德圓滿」toast。

---

## 6. 核心技術組件（附完整代碼）

### 6.1 inkReveal.ts — WebGL 墨暈揭示

用途：loader→hero 進站揭示（§5.1）。原理：全屏 quad，fragment shader 以程序噪聲做 threshold 揭示，`uProgress` 0→1 由 GSAP tween 驅動；canvas 疊在最上層蓋住頁面，progress 完成即移除 canvas。**零貼圖資產依賴**。

```glsl
// fragment shader
precision mediump float;
uniform float uProgress;      // 0=全遮(墨黑) 1=全開
uniform vec2  uCenter;        // 點擊座標(0..1)
uniform vec2  uRes;
// 3-octave value noise（hash 版，約 15 行，執行模型照標準實作）
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
  vec2 i = floor(p), f = fract(p); f = f*f*(3.-2.*f);
  return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
             mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void main(){
  vec2 uv = gl_FragCoord.xy / uRes;
  vec2 asp = vec2(uRes.x / uRes.y, 1.0);
  float d = distance(uv * asp, uCenter * asp);
  float n = noise(uv * 6.0) * 0.5 + noise(uv * 18.0) * 0.35 + noise(uv * 48.0) * 0.15;
  float edge = d - uProgress * 1.6 + n * 0.35;      // 噪聲擾動的圓形前沿=墨暈
  float a = smoothstep(0.02, 0.12, edge);            // a=1 全墨 a=0 全開
  float rim = smoothstep(0.02, 0.0, abs(edge - 0.06)) * 0.6; // 前沿深墨圈
  gl_FragColor = vec4(vec3(0.08, 0.07, 0.06) * (1.0 - rim), a);
}
```

TS 側要點：`<canvas>` fixed 全屏 `z-index: 9999`、`pointer-events:none`；標準 WebGL 樣板（單 quad 兩三角形）約 60 行；`gsap.to(uniforms, { uProgress: 1, duration: 1.6, ease: 'power2.inOut', onComplete: destroy })`。**WebGL 不可用或 reduced-motion → fallback**：`clip-path: circle(0 at x y)` tween 到 `circle(150%)`，效果打折但功能等價。

### 6.2 筆刷揭示（文字/卡片通用進場）

不用 WebGL，用 CSS mask + GSAP 通用化：

```css
.brush-reveal { --p: 0%; -webkit-mask-image: linear-gradient(105deg, #000 var(--p), transparent calc(var(--p) + 12%)); mask-image: linear-gradient(105deg, #000 var(--p), transparent calc(var(--p) + 12%)); }
```

```ts
gsap.fromTo(el, { '--p': '0%' }, { '--p': '112%', duration: .9, ease: 'var-see-tokens',
  scrollTrigger: { trigger: el, start: 'top 80%', once: true } });
```

（GSAP tween CSS 變數需 `gsap.registerPlugin` 無、直接可行；ease 用 `--ease-brush` 對應的 cubic-bezier 寫進 tween。）加一層跟隨 `--p` 移動的墨紋 PNG 條（可選）會更像筆刷，無素材時省略。

### 6.3 3D tilt（角色卡）

```ts
export function tilt(card: HTMLElement, max = 6) {
  card.addEventListener('pointermove', e => {
    const r = card.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - .5, y = (e.clientY - r.top) / r.height - .5;
    gsap.to(card, { rotateY: x * max, rotateX: -y * max, duration: .4, ease: 'power2.out', transformPerspective: 700 });
  });
  card.addEventListener('pointerleave', () => gsap.to(card, { rotateX: 0, rotateY: 0, duration: .6 }));
}
```

### 6.4 電子木魚（Parlor 彩蛋）邏輯規格

狀態：`{ merit: number, combo: number, lastTapAt: number, unlocked: boolean }`（merit/unlocked 持久化 localStorage `monk-merit`）。
- tap()：`now - lastTapAt ∈ [180, 900]ms` → combo++，否則 combo=1；merit++；SFX `sfx('sfx_woodfish', 1 + min(combo,20) * 0.01)`；木魚 squash-stretch（scaleY .92→1，0.12s）；飄字「功德+1」（combo ≥5 改金色「+1 連擊×N」）從木魚上方隨機 ±30px 升起淡出（物件池）。
- merit 達 108：鐘聲＋滿版金光一閃＋出現「功德圓滿——結緣桌布」下載鈕（`/media/img/wallpaper_phone.png`）。已解鎖者進頁直接顯示下載鈕。
- 防呆：`keydown` 空白鍵等價 tap 且 `preventDefault`（防捲動）；`pointerdown` 用而非 click（延遲低）。

---

### 6.5 suminagashi.ts — 互動墨流體（2026-07-07 使用者拍板追加）

用途：**Hero 背景互動層**——墨流し（suminagashi）風格的即時流體模擬，紙白底＋墨色隨滑鼠/觸控拖出漩渦暈染。取代原本的靜態 poster 佔位成為 Hero 主視覺；PV 成片後由使用者二選一：PV 進 hero 背景（墨流退場或降為 loader 底）或 **PV 只進 lightbox、墨流保留為 hero**（互動性對競賽展示更有利，傾向此案）。

- 技術：原生 WebGL stable-fluids（半拉格朗日 advection、curl/vorticity confinement、Jacobi pressure solve、ping-pong FBO；velocity/pressure 半解析度 ≤512、dye 全解析度）。**不引 Three.js**，樣板沿用 inkReveal 的原生 WebGL 路數；需要 `OES_texture_half_float`（WebGL1）或 WebGL2，皆不可用→降級。
- 視覺：底色 `--paper`；墨色三色輪替＝墨黑 `#14120f`／朱紅 `#c73e3a`／藍灰（`#43d9d9` 調暗降飽和），dye 注入帶少量色相抖動；dissipation 調到墨痕緩慢淡出（殘留 ~20s）不糊成灰。目標觀感＝傳統墨流し：絲狀、大理石紋、緩慢優雅，**不是** party 螢光流體——黏度/衰減參數往「水面墨」調。
- 互動：pointermove 拖曳注入 dye＋velocity（力道隨速度）；pointerdown 大滴；idle 8s 起每 4–6s 自動小漩渦（隨機位置、小力道，保持畫面活著）；觸控同理。
- 效能/降級：IntersectionObserver 離屏暫停 rAF；rAF 實測 fps<30 持續 2s → sim 解析度砍半一次；`prefers-reduced-motion` 或 WebGL 失敗 → 靜態 poster（原佔位圖）；行動版 sim 上限 256。
- 介面：`initSuminagashi(container: HTMLElement): { destroy(): void }`——canvas 由模組自建插入 container（**不改 index.html**），hero.ts 呼叫。前景 Logo/CTA 疊其上（pointer 事件穿透：canvas `pointer-events:none`，改監聽 container）。
- 對 §5.2 的修正：Hero 背景層＝suminagashi（poster 降為降級路徑與 og:image 用）；「往下捲 scale 1→0.92」的 scrub 效果套在整個 hero 容器上不變。

## 7. 內容資料 schema（data/）

```jsonc
// characters.json
{
  "main": [{
    "id": "wujie", "name": "無戒", "title": "破戒僧",
    "quote": "南無……得罪了。",
    "desc": ["三行內介紹…", "…", "…"],
    "portrait": "/media/img/char_wujie.webp",   // 去背立繪
    "revealed": true
  }],
  "gods": [ // 固定 12 筆，順序=格位順序
    { "id": "ares", "name": "阿瑞斯", "chapter": 1, "revealed": true,  "portrait": "/media/img/god_ares.webp" },
    { "id": "god02", "name": "", "chapter": 2, "revealed": false, "portrait": "" }
  ]
}
// gameplay.json：[{ id, title, tagline, points: string[3], loop: "/media/video/loop_battle.webm", poster }]
// gallery.json：[{ thumb, full, alt, w, h }]（w/h 供瀑布流佔位防 CLS）
// strings.json：{ heroTagline, storyCards: string[], parlorTitle, footerCredit: string[], ... } 全站文案唯一來源
```

驗收通則：任何 JSON 加/改一筆，重整即生效，不動 TS/HTML。

---

## 8. 素材清單與轉檔管線

### 8.1 素材總表（來源｜狀態）

| 素材 | 規格 | 來源 | 佔位方式（未到位時） |
|---|---|---|---|
| pv_720_mute.webm/mp4、pv_1080.mp4、poster | 720p ≤8MB／1080p | PV 成片（上游 spec） | 遊戲實錄 30s 任意段 |
| logo.png | 透底 2000px 寬 | PV 用的 KF-07 定版圖去背 | 文字排版暫代＋`data-todo` |
| key art＋手機桌布版 | 2560×1440／1170×2532 | key art 工單（上游 spec §7） | 現有戰鬥背景暫代 |
| 絵巻三層長圖 | 遠 4096×1080、中 6144×1080 | Magnific：遊戲截圖 outpaint 橫向擴展（水墨×霓虹天際線→神社街→萬神殿大樓，出圖先給使用者確認再上站） | 純色塊＋現有背景拼接 |
| 立繪 char_*.webp | 去背 ≥1200px 高 | 遊戲 repo 現有立繪（`MONK/` 內找 okami 立繪路徑，轉 webp） | — （現成） |
| 小遊戲 loop ×5–8、gameplay loop ×4 | 480–640px ≤2MB webm | 遊戲實錄裁剪 | 靜態截圖代替 |
| bgm.mp3 | 60s loop ≤1.5MB | PV 音樂剪短 | 先無 BGM，只上 SFX |
| sfx_woodfish/sfx_bell.mp3 | <50KB | Magnific 音效生成或免版權庫 | **必備**，第一批就要 |
| 紙紋 tile、墨暈邊 PNG | ≤8KB／≤30KB | Magnific 生成一次即可 | 純色 |
| 截圖 10–20 張 | 1920×1080 png→avif | 遊戲實錄截圖 | — |

### 8.2 轉檔指令（Bash 工具執行，ffmpeg 已有使用經驗）

```bash
# 影片：webm(VP9) + mp4(H264) 雙格式
ffmpeg -i in.mp4 -an -vf scale=1280:-2 -c:v libvpx-vp9 -crf 38 -b:v 0 out.webm
ffmpeg -i in.mp4 -an -vf scale=1280:-2 -c:v libx264 -crf 26 -movflags +faststart out.mp4
# 圖：avif 縮圖 + webp fallback（用 ffmpeg 即可，不另裝工具）
ffmpeg -i in.png -vf scale=800:-2 out.avif
ffmpeg -i in.png -vf scale=800:-2 -quality 82 out.webp
```

規則：`public/media/` 只放轉檔後成品；原檔留在遊戲 repo 或素材目錄，不進站點 git。

---

## 9. 效能・相容・無障礙（驗收硬指標）

### 9.1 效能預算

- JS（gz）≤150KB；CSS ≤40KB；字體 subset 後兩檔合計 ≤600KB（`@fontsource` 的 chinese-traditional subset 已切好，按 unicode-range 自動載）。
- 首屏請求 ≤20 個；LCP <2.5s（本機 build+preview 測）；CLS <0.1（所有 img/video 寫 width/height 或 aspect-ratio）。
- Lighthouse（build 後對 preview 跑）：Performance ≥85、Accessibility ≥95、Best Practices ≥95。

### 9.2 相容

- 目標：近兩年 Chrome/Edge/Safari/Firefox＋iOS Safari。WebGL 不可用→CSS fallback（§6.1）；`dvh` 不支援→`vh` fallback 先寫。
- 斷點：≥1280 完整版／768–1279 簡化視差／<768 行動版（不 pin、珠串→進度條、tilt 關閉）。

### 9.3 無障礙（不是可選項）

- 全站鍵盤可達：珠串、卡片、lightbox、木魚遊戲皆可鍵盤操作；`:focus-visible` 金色 ring。
- 每 section `<section aria-labelledby>`；純裝飾動畫元素 `aria-hidden`。
- `prefers-reduced-motion`：pin/scrub/視差/自動播放全關，內容靜態可讀——**用 DevTools 模擬實測整頁**，不是只寫 media query。
- 影片皆無聲或有替代文字說明；色彩對比：金字在墨黑上 ≥4.5:1（`#e8b84b` on `#14120f` 通過，改色時重驗）。

---

## 10. 里程碑與派工單（給主對話調度用）

每張工單＝一次 `general-purpose`/`sonnet` 派工（M2/M3 技術密度高，優先 `opus` 或由能力較強的執行者做）。**每張工單 prompt 開頭必附**：①「指揮官不下場」不適用聲明（§0-1 原文）②本 spec 路徑＋「先完整讀完 §0/§1/§3/§4 與你負責的章節」③回報格式（改了哪些檔＋驗收逐條勾選＋截圖路徑）。

| 里程碑 | 內容 | 驗收（除各節驗收外） |
|---|---|---|
| M0 腳手架 | `D:\monk\website\` 建 Vite+TS 專案、依賴裝齊、tokens.css/base.css、launch.json、空白七 section 骨架＋斜切交界、git init | `npm run dev`/`build` 皆過；七區斜切交界在 1280/375 寬截圖確認 |
| M1 全站系統 | §4 全部（scroll/audio/beads/cursor/utils）＋§6.2 brush-reveal 通用組件 | 珠串隨捲動高亮換位；mute 持久化；reduced-motion 下珠串仍可導航 |
| M2 Loader＋Hero | §5.1＋§5.2＋§6.1 inkReveal | §5.1/5.2 驗收全過；WebGL 關閉時 fallback 可用 |
| M3 Story 絵巻 | §5.3 | §5.3 驗收全過（含 60fps 錄測） |
| M4 Characters | §5.4＋§6.3＋characters.json | §5.4 驗收全過 |
| M5 Gameplay＋Parlor | §5.5＋§5.6＋§6.4 木魚遊戲 | §5.5/5.6 驗收全過 |
| M6 Gallery＋Footer＋收尾 | §5.7＋§5.8＋效能無障礙全查（§9）＋Lighthouse | §9 硬指標全達；`_tracking.md` 結案 |
| M7 部署 | Vercel 或 GH Pages 上線＋og:image/Twitter card/favicon | 線上 URL 可開；分享卡片預覽正確 |

順序鐵律：M0→M1 必須先完成且驗收過才開 M2 之後；M2–M6 可視情況並行但**不共檔**（各 section 檔案互不相碰，core/ 只有 M1 動）。每完成一單，主對話派 fresh reviewer 對照該節驗收條件 read-back＋實跑（T5 模板）。

## 11. 本機預覽與 QC 方法

`.claude/launch.json`（M0 建立）：

```json
{ "version": "0.0.1", "configurations": [
  { "name": "monk-website", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"], "port": 5173 }
] }
```

- 執行模型用 preview 工具組（preview_start/snapshot/screenshot/inspect/resize）驗收：每條「畫面類」驗收條件至少一張截圖或一次 inspect 佐證；375px 行動版必測。
- 動畫流暢度：preview_eval 注入 rAF 計數器粗測 fps；正式用 DevTools Performance（可留給使用者裝置實測）。
- Lighthouse：`npm run build` 後 `npx vite preview`，以 Chrome 跑（或 `npx lighthouse http://localhost:4173 --view`）。

## 12. 未定項（開工時向使用者確認）

- 團隊名／版權署名文字、SNS 連結
- Demo 下載連結（或參賽平台頁）
- 網域：先用 Vercel 子網域即可，自訂網域後補
- 絵巻三層長圖的生成出圖需使用者過目（美術方向），與 M3 施工並行

---

*本 spec 由 Fable 5 於 2026-07-06 定稿。執行中發現 spec 錯誤（API 過時、代碼跑不起來）：修正實作並在回報「意外發現」欄註明，不要回頭改本文件；設計層級的偏離一律先問使用者。*
