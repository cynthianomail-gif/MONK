shader_type spatial;
// 細膩牆面/木件：標準光照（無 toon 色階、無描邊），只做極輕的世界座標色斑
// ＋可選直向木紋(streak)。凹凸用低頻噪聲微擾法線，讓大面白牆吃光有柔和起伏。
render_mode cull_back;
#include "res://assets/shaders/stylized/common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.95, 0.93, 0.88, 1.0);
uniform float tint_amount : hint_range(0.0, 0.3) = 0.05;   // 色斑幅度（水墨版 0.32 → 這裡預設 0.05）
uniform float streak : hint_range(0.0, 1.0) = 0.0;          // 直向木紋強度（木件用）
uniform float bump : hint_range(0.0, 0.2) = 0.03;           // 法線微擾強度
uniform float rough : hint_range(0.0, 1.0) = 0.92;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float m = vnoise3(wpos * 0.6) * 0.6 + vnoise3(wpos * 2.4) * 0.4;
	vec3 col = albedo.rgb * mix(1.0 - tint_amount, 1.0 + tint_amount, m);
	if (streak > 0.001) {
		float s = vnoise3(vec3(wpos.x * 6.0, wpos.y * 0.35, wpos.z * 6.0));
		col *= mix(1.0, mix(0.86, 1.08, s), streak);
	}
	// 低頻起伏微擾法線（世界空間 → 視空間）
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float e = 0.35;
	float hc = vnoise3(wpos * 1.4);
	float hx = vnoise3((wpos + vec3(e, 0.0, 0.0)) * 1.4);
	float hy = vnoise3((wpos + vec3(0.0, e, 0.0)) * 1.4);
	float hz = vnoise3((wpos + vec3(0.0, 0.0, e)) * 1.4);
	vec3 grad = vec3(hx - hc, hy - hc, hz - hc) / e;
	grad -= nw * dot(grad, nw);   // 只留切面方向分量
	nw = normalize(nw - grad * bump);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
