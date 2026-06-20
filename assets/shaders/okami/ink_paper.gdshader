shader_type canvas_item;
uniform float strength = 0.16;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	float a=hash(i), b=hash(i+vec2(1,0)), c=hash(i+vec2(0,1)), d=hash(i+vec2(1,1));
	return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
void fragment(){
	float fib = noise(SCREEN_UV * vec2(130.0, 38.0));
	float spk = noise(SCREEN_UV * vec2(720.0, 430.0));
	float a = (smoothstep(0.62, 0.95, spk) * 0.6 + (fib-0.5)*0.5 + 0.5) * strength;
	COLOR = vec4(vec3(0.10, 0.08, 0.07), clamp(a, 0.0, 1.0));
}
