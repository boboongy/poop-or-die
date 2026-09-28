#!/bin/bash
# Compose the flush video: static background + bowl crops, game-matched horizontal falloff, Ogg Theora.
#   bash flush/scripts/f21_compose.sh OUT.ogv [BG.png] [CROPDIR] [FRAMES]
# The falloff darkens the side walls like the game's ceiling-panel spot lights (measured from a Godot screenshot).
FF="/c/Users/bobo/AppData/Local/Microsoft/WinGet/Packages/yt-dlp.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-N-125875-g5d4d3bdc61-win64-gpl/bin/ffmpeg"
D="C:/Users/bobo/Documents/mi-gaming-factory/environments/toilet-environment/flush/renders/final"
OUT="${1:-$D/flush.ogv}"
BG="${2:-$D/bg.png}"
CROPS="${3:-$D/crops}"
FRAMES="${4:-165}"
# colour grade: the game is a saturated, deep green; the render is paler and greyer in the shadows
GRADE="${GRADE:-lutrgb=r='pow(val/maxval\,0.92)*maxval':g='pow(val/maxval\,0.72)*maxval':b='pow(val/maxval\,1.05)*maxval'}"
# brightness factor by horizontal position x (0..1): dark left wall, full in the middle, darker right partition
F="if(lt(x,0.135),lerp(0.10,0.15,x/0.135),if(lt(x,0.30),lerp(0.15,0.60,(x-0.135)/0.165),if(lt(x,0.38),lerp(0.60,0.90,(x-0.30)/0.08),if(lt(x,0.50),lerp(0.90,1.0,(x-0.38)/0.12),if(lt(x,0.65),lerp(1.0,0.95,(x-0.50)/0.15),if(lt(x,0.80),lerp(0.95,0.60,(x-0.65)/0.15),if(lt(x,0.91),lerp(0.60,0.42,(x-0.80)/0.11),lerp(0.42,0.35,(x-0.91)/0.09))))))))"
FX="${F//x/(X\/W)}"
"$FF" -y -hide_banner -loglevel error \
  -loop 1 -framerate 30 -i "$BG" \
  -framerate 30 -start_number 1 -i "$CROPS/crop_%04d.png" \
  -f lavfi -i "color=c=black:s=1280x720:r=30,format=rgb24,geq=r='255*${FX}':g='255*${FX}':b='255*${FX}'" \
  -filter_complex "[0:v][1:v]overlay=460:144:shortest=1,format=rgb24[c];[c][2:v]blend=all_mode=multiply:shortest=1,${GRADE}[o]" \
  -map "[o]" -frames:v "$FRAMES" -c:v libtheora -q:v 8 -pix_fmt yuv420p "$OUT"
echo "wrote $OUT"
