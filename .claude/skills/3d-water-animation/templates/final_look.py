"""Shared 'final look' settings for the flush render: fill light, clear water, fast Cycles setup.
Imported by the render scripts (exec'd inside Blender). Does not save anything.
"""
import bpy, math

# The bowl is only a small part of the frame; render exactly this pixel box of a 1280x720 frame for every
# frame, and composite it over ONE still of the rest of the stall (nothing else moves).
W, H = 1280, 720
BOX_X0, BOX_X1 = 460, 820          # pixels from the left
BOX_Y0_TOP, BOX_Y1_TOP = 144, 476  # pixels from the TOP (so the box is 360 x 332)


def apply(samples=48):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = 100
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 8
    sc.cycles.transmission_bounces = 8
    sc.cycles.glossy_bounces = 4
    sc.cycles.diffuse_bounces = 2
    sc.cycles.volume_bounces = 0
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.03
    # game-matched look: a spot light above the bowl gives the same pool of pale green light on the floor and
    # back wall as the game (values matched against a Godot screenshot with f19_light_match.py). The dark
    # side walls of the game are added afterwards as a horizontal falloff in the ffmpeg grade.
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.view_settings.exposure = 0.0
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGB'

    if "Key" not in bpy.data.objects:
        ld = bpy.data.lights.new("Key", 'SPOT')
        ld.energy = 120.0
        ld.spot_size = math.radians(75.0)
        ld.spot_blend = 1.0
        ld.color = (0.55, 1.0, 0.6)
        key = bpy.data.objects.new("Key", ld)
        sc.collection.objects.link(key)
        key.location = (1.5, 1.75, 2.5)
        key.rotation_euler = (math.radians(12), 0, 0)
        key.visible_camera = False

    wm = bpy.data.materials["M_FlushWater"]
    nt = wm.node_tree
    for n in list(nt.nodes):
        if n.type == 'VOLUME_ABSORPTION':
            nt.nodes.remove(n)
    for n in nt.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            n.inputs["Roughness"].default_value = 0.0
            n.inputs["Base Color"].default_value = (0.92, 1.0, 1.0, 1.0)


def set_box():
    sc = bpy.context.scene
    sc.render.use_border = True
    sc.render.use_crop_to_border = True
    sc.render.border_min_x = BOX_X0 / W
    sc.render.border_max_x = BOX_X1 / W
    sc.render.border_min_y = (H - BOX_Y1_TOP) / H
    sc.render.border_max_y = (H - BOX_Y0_TOP) / H


def clear_box():
    sc = bpy.context.scene
    sc.render.use_border = False
    sc.render.use_crop_to_border = False
