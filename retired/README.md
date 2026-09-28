# retired/

Code the game no longer uses, kept because it was never in git (owner E, 2026-09-27). Godot ignores this folder (`.gdignore`), and so do `tests/run.sh` and `tools/make_voices.py`.

- `water_fight.gd`, `test_water_fight.gd`, `shot_level4_water.gd`: Level 4's old round 3 (a third-person water fight with BOSSY). Replaced by WATER WAR (`scripts/shooter.gd`, SPEC Stage 4). Its HUD parts are still in `scripts/fight_hud.gd` (`water_mode`, `update_water`).
