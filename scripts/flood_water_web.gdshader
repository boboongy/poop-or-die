shader_type spatial;
// The flood water in the web build: WebGL cannot copy the depth buffer ("glBlitFramebuffer: Depth/stencil buffer format combination
// not allowed"), and the lamps do not light this sheet there: the water was BLACK (2026-09-28, Chrome). Same look without the
// depth read, with the room's light added as emission.
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_burley, specular_schlick_ggx;

#define NO_DEPTH_TEX
#define LIGHT_IN_EMISSION
#include "res://scripts/flood_water.gdshaderinc"
