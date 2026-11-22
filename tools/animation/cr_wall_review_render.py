# Core Round Step 1E wall-run review renders (local PNGs, not committed): the wall-run clip from the OPEN side, where
# a player actually sees it - third-person (behind / above / open side), front three-quarter, straight from the open
# side (silhouette against the wall) and from above (separation from the wall plane).
#   blender -b <blend> -P tools/animation/cr_wall_review_render.py -- <outdir> [clip] [frames...]
import math
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0]
CLIP = args[1] if len(args) > 1 else "wallrun_r"
FRAMES = [int(a) for a in args[2:]] or [0, 4, 7, 11]
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 300, 360
sc.world = sc.world or bpy.data.worlds.new("W")
sc.world.color = (0.92, 0.93, 0.95)
rig = bpy.data.objects["CR_R15"]
wall = bpy.data.objects.get("Wall_R")
if wall:
    wall.hide_render = False
    if CLIP.endswith("_l"):
        wall.scale.x = -1.0  # mirror the wall plane to the left side
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
side = -1.0 if CLIP.endswith("_l") else 1.0
VIEWS = {  # Blender coords (x right, y forward, z up); the open side is -x for a right-hand wall
    "third_person": ((-4.5 * side, -11.0, 3.0), (0.3 * side, 0.0, 0.2), 8.5),
    "front34_open": ((-6.0 * side, 11.0, 1.2), (0.3 * side, 0.0, 0.0), 8.5),
    "open_side": ((-14.0 * side, 0.0, 0.5), (0.0, 0.0, 0.0), 8.5),
    "top": ((0.0, 0.0, 14.0), (0.0, 0.0001, 0.0), 6.0),
}


def aim(loc, target, scale):
    cam.location = loc
    d = [target[i] - loc[i] for i in range(3)]
    yaw = math.atan2(d[1], d[0])
    pitch = math.atan2(d[2], math.hypot(d[0], d[1]))
    cam.rotation_euler = (math.pi / 2 + pitch, 0.0, yaw - math.pi / 2)
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = scale


def render_png(path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    os.remove(path)
    return px


act = bpy.data.actions["CR_" + CLIP]
rig.animation_data.action = act
if hasattr(rig.animation_data, "action_slot") and act.slots:
    rig.animation_data.action_slot = act.slots[0]
rows = []
for v, (loc, tgt, scale) in VIEWS.items():
    aim(loc, tgt, scale)
    tiles = []
    for f in FRAMES:
        sc.frame_set(f)
        tiles.append(render_png(os.path.join(OUT, "_tmp_" + CLIP + ".png")))
    rows.append(np.concatenate(tiles, axis=1))
full = np.concatenate(rows[::-1], axis=0)
h, w = full.shape[:2]
img = bpy.data.images.new("review", w, h, alpha=True)
img.pixels = full.ravel()
img.filepath_raw = os.path.join(OUT, "review_" + CLIP + ".png")
img.file_format = "PNG"
img.save()
print("CR_RENDER", img.filepath_raw)
