// 共用噪聲：世界座標 value noise（stylized 套件全員引用）
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

float vnoise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float n000 = h3(i),                 n100 = h3(i + vec3(1, 0, 0));
	float n010 = h3(i + vec3(0, 1, 0)), n110 = h3(i + vec3(1, 1, 0));
	float n001 = h3(i + vec3(0, 0, 1)), n101 = h3(i + vec3(1, 0, 1));
	float n011 = h3(i + vec3(0, 1, 1)), n111 = h3(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}
