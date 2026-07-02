shader_type spatial;
// 瓦屋頂：水平瓦列（每列微傾＋列縫暗線）＋圓瓦波浪(沿屋簷方向的 sine 凹凸)
// ＋每片瓦輕微色差。標準光照；斜面用世界法線推切線，適用 PrismMesh 屋頂。
render_mode cull_back;
#include "res://assets/shaders/stylized/common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.26, 0.34, 0.50, 1.0);
uniform float row_h : hint_range(0.1, 1.5) = 0.30;      // 瓦列高(m)
uniform float col_w : hint_range(0.1, 1.5) = 0.30;      // 圓瓦寬(m)
uniform float bump : hint_range(0.0, 1.0) = 0.18;
uniform float rough : hint_range(0.0, 1.0) = 0.55;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 col = albedo.rgb;
	float vert = abs(nw.y);
	if (vert < 0.98) {   // 近垂直法線(平頂)不做瓦紋，避免切線退化
		vec3 th = normalize(cross(vec3(0.0, 1.0, 0.0), nw));   // 沿屋簷方向
		vec3 us = normalize(cross(nw, th));                    // 上坡方向
		float v = wpos.y / row_h;
		float f = fract(v);
		vec2 tile = vec2(floor(dot(wpos, th) / col_w), floor(v));
		// 列縫暗線＋每片瓦色差（縫要比瓦紋醒目，否則整面變條紋布）
		float seam = smoothstep(0.16, 0.03, f);
		col *= mix(1.0, 0.55, seam);
		col *= mix(0.96, 1.05, h2(tile));
		// 圓瓦 sine 波浪＋瓦列微傾 → 法線凹凸
		float wave = sin(dot(wpos, th) * 6.2831 / col_w);
		nw = normalize(nw + th * wave * bump * 0.4 + us * (f - 0.5) * bump * 0.5);
	}
	float m = vnoise3(wpos * 1.1);
	col *= mix(0.94, 1.06, m);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.4;
}
