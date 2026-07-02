shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;
uniform vec4 albedo : source_color = vec4(0.8, 0.78, 0.7, 1.0);
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
	float m = vnoise(wpos * 0.55) * 0.5 + vnoise(wpos * 2.3) * 0.5;   // 墨染斑駁
	float rib = 0.5 + 0.5 * sin((wpos.x + wpos.z) * 7.0);             // 浪板鐵皮：一條條直紋
	ALBEDO = albedo.rgb * mix(0.80, 1.12, m) * mix(0.70, 1.12, rib);
	ROUGHNESS = 1.0; SPECULAR = 0.0; METALLIC = 0.0;
}
void light() {
	float ndl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	// 同 ink_toon：交界不加噪聲擾動(避免大面黑斑雜點)，乾淨柔和過渡
	float band = smoothstep(0.32, 0.52, ndl);
	float tone = mix(0.5, 1.0, band);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * tone;
}
