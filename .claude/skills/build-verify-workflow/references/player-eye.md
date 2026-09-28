# Player-eye pass (before handing over anything visible or findable)

Read this before a screenshot pass or any camera/visibility work. (Moved out of SKILL.md on 2026-09-27.)

Day 3 cost four owner round trips no test could catch: the tissue box was invisible, the puddle a dark smudge, the mop vanished after the pickup, nothing said where the flood was. Every screenshot had been from a flattering angle or a fast-forwarded state.

- Screenshot from the **game's own default camera at normal distance** (Bob in frame, so he can hide things), in the **real flow** (real level start, real time, walkers on), not a hand-placed camera or a state advanced by code.
- **Batch shots and look at them as a 2x2 contact sheet** (ffmpeg `tile`, see the cheatsheet), not 20 full-size images: same information, a quarter of the tokens.
- Can I see each prop/effect from 5 m with Bob in front of it? **This room is green-lit white tile: a plain pale or dark colour vanishes. Use a saturated colour AND emission** (`tissue_box.gd`, `puddle.gdshader`).
- Is it visible in EVERY state? (A tool that hides when not in use reads as a bug.)
- Does the HUD say WHERE to go and WHICH key?
- Look at the whole frame; write down what you saw and from which angle (the "Seen" level).
- **Look through the REAL camera in the tightest place the player will be** (2026-09-22: in a 0.95 m stall Bob's hair filled the screen; 526 checks were green). Add a test on the camera (its distance to Bob), not only on the objects.
- Never trust a light to add drama in this GI-bright room: an extra light whites out; lower the exposure.
- **Over-the-shoulder / first-person aiming:** `Camera3D.h_offset` shifts the view but the SpringArm3D never checks it (camera inside a wall); slide the pivot and clamp it with a sideways ray. Start a crosshair ray level with the player, not at the camera. Add a per-frame "no wall between head and camera" check.
- Headless does NOT compile shaders: shader errors show only in a windowed run.
- **A small floor prop: take a free-camera close-up FIRST (does it render, what colour does it read), then Bob's camera with the yaw 0.3-0.4 rad OFF the line to the prop** (2026-09-27, the Level 1 roll: two rounds of shots with Bob between the camera and the prop showed nothing; a white prop under a see-through glow also blew out to a white blob by the sinks, and the ceiling lamps' floor reflections look like glowing props: check the colour, not just a bright spot).
- **Web build look (Stage 8):** check it natively with `--rendering-method gl_compatibility` (`tests/shot_levels_compat.gd`, beside a Forward+ run): no SDFGI there, characters went black. Headless Chrome with `--virtual-time-budget` never gets past Godot's splash; `tools/web_smoke.py` drives real time over DevTools (2026-09-28).
- **Dark on dark in a crowd:** a colour change on Bob seen from behind in the kick-out crowd sits in deep shadow; the first shot of the loss patch showed nothing. Look with a magenta test colour first, then tune (2026-09-28).
