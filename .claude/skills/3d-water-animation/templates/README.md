# Templates (copied from the working toilet-flush run, 2026-09-20)

These are the scripts that produced `mi-godot/video/flush.ogv`. They are TESTED ONLY on that one effect and hard-wired to it:
absolute paths to `environments/toilet-environment/flush/`, bowl axis (1.50, 2.11), camera (1.50, 1.55, 1.10), crop box 460..820 x 144..476 px.
Copy to `environments/<slug>/<effect>/scripts/`, change the numbers at the top of each, and run in the order below. Do not run them unedited on another asset.

| Order | Template | Was | Purpose |
|---|---|---|---|
| 1 | camera_still.py | f01 | still from the game camera (compare with a Godot screenshot) |
| 2 | probe_cavity.py | f03 | ray-cast height map of the container (its inside shape) |
| 3 | fluid_smoke_test.py | f04 | tiny bake to prove Mantaflow works headless and time it |
| 4 | EXAMPLE_build_flush_scene.py | f10 | derive the scene: prune, metres, proxy, emitters, domain (env FLUSH_RES) |
| 5 | bake.py | f12 | data bake then mesh bake |
| 6 | inspect_cache.py | f13 | vertex counts and bounds per frame: did anything simulate |
| 7 | lookdev_closeup.py | f14 | bright close-up frames for judging water (not for delivery) |
| 8 | light_match.py + color_compare.py | f19 / f18 | match colours against an engine screenshot |
| 9 | final_look.py, background.py, render_crops.py | f16 / f17 / f20 | final render settings, static background, crops (resumable) |
| 10 | compose.sh | f21 | overlay, falloff, grade, Ogg Theora |
| all | render_all.sh | f22 | background + crops + compose in one background job |
