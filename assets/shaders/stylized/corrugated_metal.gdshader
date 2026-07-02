shader_type spatial;
// 浪板鐵皮（軍火庫）：直向波浪真凹凸＋橫向板接縫＋鏽斑，帶金屬高光。
// 標準光照取代舊 ink_corrugated 的畫線壓暗。
render_mode cull_back;
#include "res://assets/shaders/stylized/common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.30, 0.30, 0.33, 1.0);
uniform float rib_w : hint_range(0.05, 1.0) = 0.22;     // 波浪間距(m)
uniform float panel_h : hint_range(0.4, 3.0) = 1.15;    // 橫向板高(m)
uniform float bump : hint_range(0.0, 1.0) = 0.5;
uniform float rust : hint_range(0.0, 1.0) = 0.35;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 col = albedo.rgb;
	float rough = 0.55;
	float metal = 0.35;
	if (abs(nw.y) < 0.9) {   // 牆面才有浪板；頂面留素鐵皮
		vec3 th = normalize(cross(vec3(0.0, 1.0, 0.0), nw));
		float u = dot(wpos, th);
		float wave = sin(u * 6.2831 / rib_w);
		nw = normalize(nw + th * cos(u * 6.2831 / rib_w) * bump * 0.6);
		col *= mix(0.92, 1.05, wave * 0.5 + 0.5);
		// 橫向板接縫（暗線＋輕微階差）
		float pf = fract(wpos.y / panel_h);
		float seam = smoothstep(0.05, 0.0, pf) + smoothstep(0.95, 1.0, pf);
		col *= mix(1.0, 0.55, seam);
		// 鏽斑往下流（低頻遮罩 × 直向拉絲）
		float rmask = smoothstep(0.55, 0.85, vnoise3(wpos * 0.55))
			* mix(0.6, 1.0, vnoise3(vec3(wpos.x * 8.0, wpos.y * 0.6, wpos.z * 8.0)));
		col = mix(col, vec3(0.38, 0.22, 0.14), rmask * rust);
		rough = mix(rough, 0.9, rmask * rust);
		metal = mix(metal, 0.05, rmask * rust);
	}
	float m = vnoise3(wpos * 1.3);
	col *= mix(0.95, 1.05, m);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
}
