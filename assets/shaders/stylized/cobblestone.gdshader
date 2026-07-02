shader_type spatial;
// 圓石板路（參考圖風格）：交錯排列的圓潤石塊＋灰漿縫，法線凹凸讓每顆石頭
// 真的「鼓起來」吃光。標準光照；濕地面（軍火庫夜街）把 rough_stone 調低即可。
render_mode cull_back;
#include "res://assets/shaders/stylized/common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.72, 0.70, 0.66, 1.0);
uniform float stone_size : hint_range(0.3, 3.0) = 0.55;      // 石塊間距(m)
uniform float bump : hint_range(0.0, 3.0) = 0.75;            // 凹凸強度
uniform float mortar_darken : hint_range(0.0, 1.0) = 0.42;   // 縫隙壓暗
uniform float tint_variation : hint_range(0.0, 0.4) = 0.14;  // 每顆石頭色差
uniform float rough_stone : hint_range(0.0, 1.0) = 0.62;
uniform float rough_mortar : hint_range(0.0, 1.0) = 0.95;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

// 石塊 dome 高度場（0=縫底, 1=石頂）；row 交錯＋每顆抖動圓心/半徑＝手鋪感
float stone_h(vec2 xz, out vec2 cell_id) {
	vec2 g = xz / stone_size;
	g += (vec2(vnoise3(vec3(xz.x, 0.0, xz.y) * 0.33),
	           vnoise3(vec3(xz.x, 7.7, xz.y) * 0.33)) - 0.5) * 0.35;   // 低頻扭曲去棋盤感
	float row = floor(g.y);
	g.x += fract(row * 0.5);
	cell_id = vec2(floor(g.x), row);
	vec2 lc = fract(g) - 0.5;
	vec2 cj = (vec2(h2(cell_id + 7.3), h2(cell_id + 3.1)) - 0.5) * 0.14;
	float r = mix(0.40, 0.50, h2(cell_id));
	float t = clamp(length((lc - cj) * vec2(1.0, 1.08)) / r, 0.0, 1.0);
	return sqrt(max(1.0 - t * t, 0.0));
}

void fragment() {
	vec2 cell;
	float e = stone_size * 0.07;
	float hc = stone_h(wpos.xz, cell);
	vec2 c2;
	float hx = stone_h(wpos.xz + vec2(e, 0.0), c2);
	float hz = stone_h(wpos.xz + vec2(0.0, e), c2);
	vec2 grad = vec2(hx - hc, hz - hc) / e;

	float stone = smoothstep(0.05, 0.30, hc);                 // 石面/縫 遮罩
	float tint = mix(1.0 - tint_variation, 1.0 + tint_variation, h2(cell + 1.7));
	vec3 col = albedo.rgb * tint;
	// 每顆石頭輕微冷暖偏移（乘法，暗色地面才不會加成彩虹糖果色）
	col *= vec3(1.0) + (vec3(h2(cell + 11.0), h2(cell + 23.0), h2(cell + 37.0)) - 0.5) * 0.08;
	col = mix(albedo.rgb * (1.0 - mortar_darken), col, stone);
	// 低頻污漬/苔痕
	float stain = smoothstep(0.60, 0.80, vnoise3(wpos * 0.20 + vec3(7.0)));
	col *= mix(1.0, 0.86, stain);

	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	nw = normalize(nw + vec3(-grad.x, 0.0, -grad.y) * bump * 0.35);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	ALBEDO = col;
	ROUGHNESS = mix(rough_mortar, rough_stone, stone);
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
