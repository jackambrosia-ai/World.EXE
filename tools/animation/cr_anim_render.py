# Core Round Step 1E: render preview contact sheets of the clips (Workbench, local PNGs, not committed).
#   blender -b <blend> -P tools/animation/cr_anim_render.py -- <outdir> [clip ...]
import math
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.path.join(os.path.dirname(bpy.data.filepath), "previews")
ONLY = set(args[1:])
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_shadows = False
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 260, 340
sc.render.film_transparent = False
sc.world = sc.world or bpy.data.worlds.new("W")
sc.world.color = (0.92, 0.93, 0.95)
arm = bpy.data.objects["CR_R15"]

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam

VIEWS = {
    # name: (location, look-at, ortho scale)
    "side": ((14.0, 0.0, 0.2), (0.0, 0.0, -0.6), 9.0),
    "front34": ((7.5, 9.0, 1.2), (0.0, 0.0, -0.6), 9.0),
    "back": ((0.0, -14.0, 1.0), (0.0, 0.0, -0.6), 9.0),
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


def sheet(name, frames, views):
    rows = []
    for v in views:
        loc, tgt, scale = VIEWS[v]
        aim(loc, tgt, scale)
        tiles = []
        for f in frames:
            sc.frame_set(f)
            tiles.append(render_png(os.path.join(OUT, "_tmp.png")))
        rows.append(np.concatenate(tiles, axis=1))
    # rows were rendered bottom-up in Blender pixel order; stack so the first view is on top
    full = np.concatenate(rows[::-1], axis=0)
    h, w = full.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = full.ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("CR_RENDER", img.filepath_raw)


wall = bpy.data.objects.get("Wall_R")
for act in bpy.data.actions:
    if not act.name.startswith("CR_"):
        continue
    clip = act.name[3:]
    if ONLY and clip not in ONLY:
        continue
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and act.slots:
        arm.animation_data.action_slot = act.slots[0]
    n = int(act.frame_range[1])
    step = max(1, n // 7)
    frames = list(range(0, n + 1, step))[:8]
    if wall:
        wall.hide_render = not clip.startswith("wall")
    sheet(clip, frames, ["side", "front34"] if not clip.startswith("wall") else ["back", "front34"])
