shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(0.72, 0.69, 0.62, 1.0);
varying vec3 wpos;
float h3(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec3 p){
	vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	float n000=h3(i),               n100=h3(i+vec3(1,0,0));
	float n010=h3(i+vec3(0,1,0)),   n110=h3(i+vec3(1,1,0));
	float n001=h3(i+vec3(0,0,1)),   n101=h3(i+vec3(1,0,1));
	float n011=h3(i+vec3(0,1,1)),   n111=h3(i+vec3(1,1,1));
	return mix(mix(mix(n000,n100,f.x), mix(n010,n110,f.x), f.y),
	           mix(mix(n001,n101,f.x), mix(n011,n111,f.x), f.y), f.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float m = vnoise(wpos * 0.5) * 0.5 + vnoise(wpos * 2.0) * 0.5;   // 墨染
	vec3 col = albedo.rgb * mix(0.82, 1.08, m);
	// 石板格：格線座標先用低頻噪聲扭曲＝手畫般的歪縫（去棋盤感）
	vec2 warp = vec2(vnoise(wpos * 0.9), vnoise(wpos * 0.9 + vec3(31.7, 0.0, 17.3))) - 0.5;
	vec2 g = wpos.xz / 2.2 + warp * 0.16;            // 石板 ~2.2m
	vec2 f = abs(fract(g) - 0.5);
	vec2 cell = floor(g);
	float cw = fract(sin(dot(cell, vec2(45.3, 91.7))) * 24634.6);
	float line = smoothstep(0.5 - mix(0.03, 0.09, cw), 0.5, max(f.x, f.y));
	col *= mix(1.0, mix(0.74, 0.56, cw), line);       // 接縫壓暗：每縫粗細/深淺不均
	float tint = fract(sin(dot(cell, vec2(12.9, 78.2))) * 43758.5);
	col *= mix(0.90, 1.08, tint);                     // 每塊石板色差
	float stain = smoothstep(0.60, 0.78, vnoise(wpos * 0.21 + vec3(7.0)));
	col *= mix(1.0, 0.84, stain * 0.8);               // 低頻大片污漬/苔痕
	ALBEDO = col;
	ROUGHNESS = 1.0; SPECULAR = 0.0; METALLIC = 0.0;
}
void light() {
	float ndl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	// 同 ink_toon：交界不加噪聲擾動(平坦地面整片都在閾值附近，噪聲會變滿地黑斑雜點)
	float band = smoothstep(0.32, 0.52, ndl);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * mix(0.5, 1.0, band);
}
