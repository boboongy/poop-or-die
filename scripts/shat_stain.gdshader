shader_type spatial;
// Stage 6d (owner 2026-09-28): Bob lost, a brown patch spreads on the seat of his shorts. Drawn as a material_overlay on a copy of the
// shorts mesh whose vertex COLOR.rgb holds the rest-pose position (shat_stain.gd): the patch sticks to the fabric in every pose and works
// in both renderers (the web build's Compatibility renderer has no decals). Dark brown, uneven edge, slightly shiny.
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform float spread : hint_range(0.0, 1.0) = 0.0; // 0 = clean, 1 = the full patch
uniform vec3 seat = vec3(0.0, 0.40, -0.10); // rest-pose model space, the back of the shorts
uniform float radius = 0.075; // m: about 15 cm across
uniform vec3 box_center = vec3(0.0, 0.42, 0.0);
uniform float box_scale = 0.6;
uniform vec3 brown : source_color = vec3(0.40, 0.22, 0.06);
uniform vec3 brown_dark : source_color = vec3(0.22, 0.11, 0.03);

varying vec3 rest;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	rest = (COLOR.rgb - vec3(0.5)) * box_scale + box_center;
}

void fragment() {
	vec3 d = rest - seat;
	d.y *= 1.15; // a little taller than wide
	float wobble = noise(rest * 38.0) * 0.6 + noise(rest * 90.0) * 0.4; // the uneven edge
	float r = radius * spread * (0.75 + 0.5 * wobble);
	float dist = length(d.xy) + max(d.z - 0.05, 0.0) * 2.0; // only the back of the shorts: toward the front it falls away fast
	float a = 1.0 - smoothstep(r * 0.85, r, dist);
	a *= step(0.001, spread);
	float core = 1.0 - smoothstep(0.0, r * 0.7, dist);
	ALBEDO = mix(brown, brown_dark, core * 0.8 + noise(rest * 140.0) * 0.2);
	ROUGHNESS = 0.2; // wet: slightly shiny
	EMISSION = ALBEDO * 0.3 * a; // a little self-light: it must read even in the crowd's shadow (player-eye pass 2026-09-28)
	SPECULAR = 0.6;
	ALPHA = a * 0.96;
}
