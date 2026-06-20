shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex  : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 ink : source_color = vec4(0.05, 0.04, 0.06, 1.0);
uniform float thickness = 1.9;
uniform float depth_rel = 0.018;
uniform float normal_thr = 0.30;
float h2(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	float a=h2(i), b=h2(i+vec2(1,0)), c=h2(i+vec2(0,1)), d=h2(i+vec2(1,1));
	return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
float lin(vec2 uv, mat4 ip){
	float d = texture(depth_tex, uv).r;
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}
void fragment() {
	float jw = mix(0.85, 1.25, n2(SCREEN_UV * 6.0));             // 筆鋒：緩變粗細(低頻不破壞 sobel)
	vec2 px = thickness * jw / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float dc = lin(SCREEN_UV, INV_PROJECTION_MATRIX);
	float dl = lin(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float dr = lin(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float du = lin(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dd = lin(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float lap = abs(dl + dr - 2.0 * dc) + abs(du + dd - 2.0 * dc);   // 二階差分(曲率)：平面斜坡不誤判,只抓真深度跳變
	float de = step(depth_rel, lap / max(dc, 0.001));
	vec3 nc = texture(normal_tex, SCREEN_UV).xyz;
	vec3 nl = texture(normal_tex, SCREEN_UV - vec2(px.x, 0.0)).xyz;
	vec3 nr = texture(normal_tex, SCREEN_UV + vec2(px.x, 0.0)).xyz;
	vec3 nu = texture(normal_tex, SCREEN_UV - vec2(0.0, px.y)).xyz;
	vec3 nd = texture(normal_tex, SCREEN_UV + vec2(0.0, px.y)).xyz;
	float nedge = (1.0-dot(nc,nl)) + (1.0-dot(nc,nr)) + (1.0-dot(nc,nu)) + (1.0-dot(nc,nd));
	float ne = step(normal_thr, nedge);
	float e = clamp(max(de, ne), 0.0, 1.0);
	e *= 1.0 - smoothstep(24.0, 34.0, dc);   // 遠景墨線淡入紙色(去遠處 normal 雜訊+水墨遠淡)
	float dry = n2(SCREEN_UV * vec2(230.0, 200.0));             // 飛白：乾筆斷墨
	e *= mix(0.78, 1.0, smoothstep(0.30, 0.7, dry));
	vec3 inkv = ink.rgb * mix(0.78, 1.18, n2(SCREEN_UV * 55.0)); // 墨色濃淡
	ALBEDO = mix(col, inkv, e);
}
