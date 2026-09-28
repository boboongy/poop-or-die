shader_type spatial;
render_mode blend_mix, depth_draw_never, specular_schlick_ggx;
// Level 2's flood. The wetness of each 0.25 m cell comes in as a small R8 texture (see flood.gd); the lookup
// coordinates are wobbled with noise so the puddle has an uneven edge instead of square cells. Walls and the
// stall block are cut out exactly by the two rectangles below (x, z, width, depth in world metres).

uniform sampler2D wet_map : filter_nearest, repeat_disable;
uniform vec2 origin;   // world x, z of the texture's corner
uniform float extent;  // metres covered by the texture
uniform vec4 bounds;   // walkable floor: x, z, width, depth
uniform vec4 block;    // the stall block (not floor): x, z, width, depth
uniform vec3 deep_color : source_color = vec3(0.03, 0.22, 0.60);
uniform vec3 thin_color : source_color = vec3(0.15, 0.50, 0.85);
uniform float glow = 0.6; // how much the water lights itself
uniform vec3 sparkle_color : source_color = vec3(0.55, 0.85, 1.0);
uniform float sparkle_amount = 0.6;

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

bool inside(vec2 p, vec4 r) {
	return p.x >= r.x && p.y >= r.y && p.x < r.x + r.z && p.y < r.y + r.w;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	if (!inside(p, bounds) || inside(p, block)) {
		discard;
	}
	vec2 warp = vec2(vnoise(p * 5.0 + 3.7), vnoise(p * 5.0 - 11.3)) - 0.5;
	vec2 uv = (p + warp * 0.3 - origin) / extent;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		discard;
	}
	float w = texture(wet_map, uv).r;
	if (w < 0.03) {
		discard;
	}
	// Small moving ripples: a slightly tilted normal.
	vec2 q = p * 7.0;
	float t = TIME * 0.5;
	vec3 n = normalize(vec3((vnoise(q + vec2(t, 0.0)) - 0.5) * 0.3, 1.0, (vnoise(q.yx - vec2(t, 0.0)) - 0.5) * 0.3));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 water = mix(thin_color, deep_color, w);
	ALBEDO = water;
	// Self-lit: the toilet's green light washes a plain dark colour out to a smudge (owner could not see the puddle), so the water
	// glows blue by itself and glitters where the moving noise peaks.
	float sparkle = smoothstep(0.78, 1.0, vnoise(p * 11.0 + vec2(TIME * 0.7, -TIME * 0.4)));
	EMISSION = water * glow + sparkle_color * sparkle * sparkle_amount;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = clamp(0.55 + 0.4 * w, 0.0, 0.95);
}
