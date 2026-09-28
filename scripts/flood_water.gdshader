shader_type spatial;
// Level 2 "The flood" (SPEC Round 2 Stage 3): the murky water that fills the toilet. NOT blue (owner refs refs/water/):
// grey-green murk that hides the floor after about `clarity` metres, the floor seen through thin water, mirror-sharp highlights,
// foam where it meets walls and bodies and a boil round every running source, caustics on whatever is under water, and a
// whirlpool at the drain while it empties. The water is one flat sheet at the level's water height (flood_water.gd).
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;

// The room's light is strong green, so anything lit turns green: the murk is a grey-brown that the green light makes grey-green,
// and the foam glows a little so it stays whitish (screenshots 2026-09-27: a green murk read as green glass).
uniform vec3 murk : source_color = vec3(0.30, 0.27, 0.21); // the colour of deep water (lit)
uniform vec3 tint : source_color = vec3(0.60, 0.58, 0.46); // what thin water does to the floor seen through it
uniform vec3 foam_color : source_color = vec3(0.92, 0.92, 0.88);
uniform float foam_glow = 0.35;
uniform float clarity = 0.28; // metres of water (along the view) before the floor is mostly hidden
uniform float wave_amp = 1.0; // 0..1: small in shallow water
uniform float cover_all = 0.0; // 1 = the whole floor is under water; below that only the spreads are
uniform vec4 spread[8]; // xyz = where water started coming out, w = how far it has spread (m)
uniform int spread_count = 0;
uniform vec4 boil[8]; // xyz = a running source, w = 1 while it runs
uniform int boil_count = 0;
uniform vec3 drain_pos = vec3(0.0);
uniform float swirl = 0.0; // 0..1 while the drain empties the room
uniform float caustic_strength = 2.2;

varying vec3 wpos;

float wave(vec2 p, float t) {
	return sin(p.x * 2.3 + t * 1.7) * 0.012 + sin(p.y * 3.1 - t * 1.3) * 0.010 + sin((p.x + p.y) * 5.3 + t * 2.6) * 0.005;
}

// A cheap tileable caustic (after Dave Hoskins' "Tileable Water Caustic"): bright wobbly lines.
float caustic(vec2 p, float t) {
	vec2 q = mod(p * 0.8, 1.0) * 6.28318 - 250.0;
	vec2 i = q;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = q + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(q.x / (sin(i.x + tt) / inten), q.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 2.0);
}

vec3 view_pos(vec2 uv, float d, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave(wpos.xz, TIME) * wave_amp;
	VERTEX.y += h;
	wpos.y += h;
}

void fragment() {
	// Where the water is: everywhere once the floor is covered, before that only round the sources.
	float cover = cover_all;
	for (int i = 0; i < spread_count; i++) {
		float d = distance(wpos.xz, spread[i].xz);
		cover = max(cover, 1.0 - smoothstep(spread[i].w - 0.4, spread[i].w, d));
	}
	if (cover < 0.01) {
		discard;
	}

	// The drain's whirlpool turns the ripples round it.
	vec2 rel = wpos.xz - drain_pos.xz;
	float r = length(rel);
	float spin = swirl * (TIME * 2.5 + 1.5 / (r + 0.15)) * exp(-r * 0.9);
	vec2 p = drain_pos.xz + mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * rel;

	// Boiling foam round every running source (a tap overflowing, the clogged toilet gushing).
	float boil_amt = 0.0;
	for (int i = 0; i < boil_count; i++) {
		float d = distance(wpos.xz, boil[i].xz);
		boil_amt = max(boil_amt, boil[i].w * (1.0 - smoothstep(0.15, 1.0, d)));
	}

	vec3 na = texture(normal_a, p * 0.22 + TIME * vec2(0.03, 0.02)).rgb;
	vec3 nb = texture(normal_b, p * 0.6 - TIME * vec2(0.025, -0.035)).rgb;
	vec3 nc = texture(normal_b, p * 1.8 + TIME * vec2(0.11, 0.07) * (1.0 + boil_amt * 3.0)).rgb;
	NORMAL_MAP = normalize(mix(mix(na, nb, 0.4), nc, 0.15 + boil_amt * 0.6));
	NORMAL_MAP_DEPTH = 0.4 + boil_amt * 1.5 + swirl * exp(-r * 0.9) * 1.5;

	// How much water we look through, and a refracted look at what is under it.
	float surf = -VERTEX.z;
	float d0 = texture(depth_tex, SCREEN_UV).r;
	vec3 scene0 = view_pos(SCREEN_UV, d0, INV_PROJECTION_MATRIX);
	vec2 bend = (NORMAL_MAP.xy - 0.5) * 0.05 * clamp((-scene0.z - surf) * 2.0, 0.0, 1.0);
	vec2 ruv = SCREEN_UV + bend;
	float d1 = texture(depth_tex, ruv).r;
	vec3 scene = view_pos(ruv, d1, INV_PROJECTION_MATRIX);
	if (-scene.z < surf) { // the bent ray hit something ABOVE the water: do not bend
		ruv = SCREEN_UV;
		scene = scene0;
	}
	float through = max(-scene.z - surf, 0.0) * length(VERTEX) / max(surf, 0.001); // along the view ray
	vec3 world_scene = (INV_VIEW_MATRIX * vec4(scene, 1.0)).xyz;
	float below = wpos.y - world_scene.y; // how deep under the surface that point is

	vec3 under = textureLod(screen_tex, ruv, 0.0).rgb;
	float c = caustic(world_scene.xz + world_scene.y * 0.3, TIME * 0.6);
	under += (under + vec3(0.08)) * c * caustic_strength * smoothstep(0.03, 0.2, below) * (1.0 - smoothstep(1.2, 2.2, below));
	float murk_t = 1.0 - exp(-through / clarity * 1.4);

	// Foam: a line where the water meets a wall or a body, broken up by the ripples, plus the boil.
	float edge = 1.0 - smoothstep(0.0, 0.2, -scene0.z - surf);
	float breakup = smoothstep(0.4, 0.7, texture(normal_b, p * 1.3 + TIME * 0.05).r);
	// streaks of scum drifting on the whole surface (ref 2: foam lines everywhere, thicker near the sources)
	float streak = smoothstep(0.62, 0.8, texture(normal_a, p * vec2(0.5, 1.4) + TIME * vec2(0.02, -0.04)).g) * 0.55;
	float foam = clamp(edge * (0.45 + breakup) + streak * wave_amp + boil_amt * smoothstep(0.3, 0.6, nc.r + nb.g * 0.5 - 0.2) * 1.3, 0.0, 1.0);

	if (FRONT_FACING) {
		ALBEDO = mix(murk * murk_t, foam_color, foam);
		EMISSION = under * tint * (1.0 - murk_t) * (1.0 - foam) + foam_color * foam * foam_glow;
		ROUGHNESS = mix(0.03, 0.55, foam);
		SPECULAR = 0.6;
	} else { // from under water: the underside is a bright murky ceiling
		ALBEDO = murk * 0.5;
		EMISSION = under * tint * 0.35 + murk * 0.3;
		ROUGHNESS = 0.2;
		SPECULAR = 0.2;
	}
	METALLIC = 0.0;
	ALPHA = cover * smoothstep(0.0, 0.015, -scene0.z - surf + 0.015);
}
