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
	vec2 g = wpos.xz / 2.2;                          // 石板 ~2.2m
	vec2 f = abs(fract(g) - 0.5);
	float line = smoothstep(0.44, 0.5, max(f.x, f.y));
	col *= mix(1.0, 0.6, line);                       // 接縫壓暗
	vec2 cell = floor(g);
	float tint = fract(sin(dot(cell, vec2(12.9, 78.2))) * 43758.5);
	col *= mix(0.93, 1.06, tint);                     // 每塊石板輕微色差
	ALBEDO = col;
	ROUGHNESS = 1.0; SPECULAR = 0.0; METALLIC = 0.0;
}
void light() {
	float ndl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	float n = vnoise(wpos * 3.2);
	float t = 0.42 + (n - 0.5) * 0.30;
	float band = smoothstep(t - 0.05, t + 0.05, ndl);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * mix(0.5, 1.0, band);
}
