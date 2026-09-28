shader_type spatial;
// The flood water (desktop). The look lives in flood_water.gdshaderinc; the web build uses flood_water_web.gdshader.
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/flood_water.gdshaderinc"
