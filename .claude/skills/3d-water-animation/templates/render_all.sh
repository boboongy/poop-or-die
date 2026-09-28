#!/bin/bash
# Render the static background, then every bowl crop (resumable), then compose the video.
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
E="C:/Users/bobo/Documents/mi-gaming-factory/environments/toilet-environment"
D="$E/flush/renders/final"
mkdir -p "$D/crops"
[ -f "$D/bg.png" ] || "$B" -b "$E/flush/toilet-flush.blend" --python "$E/flush/scripts/f17_background.py" -- "$D/bg.png" 1280 160 1
"$B" -b "$E/flush/toilet-flush.blend" --python "$E/flush/scripts/f20_render_crops.py" -- "$D/crops" 64 1 165
bash "$E/flush/scripts/f21_compose.sh" "$D/flush.ogv" "$D/bg.png" "$D/crops" 165
echo ALL_DONE
