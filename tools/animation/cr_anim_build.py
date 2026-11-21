# Core Round Step 1E: build the editable Blender source (.blend) - the R15 authoring rig, proxy body boxes and one
# action per clip - from cr_anim_clips.py.
#
#   "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b --factory-startup --python-exit-code 1 \
#       -P tools/animation/cr_anim_build.py -- C:\WORLD.EXE-Art\CoreRound\animation
#
# Rig convention (1 Blender unit = 1 stud). Roblox character space (Y up, faces -Z) maps to Blender as
# (x, y, z)_roblox -> (x, -z, y)_blender: the character faces Blender +Y and stands on Blender Z-up. Every bone points
# straight up (+Z) with roll 0, so each bone's LOCAL axes are exactly the Roblox axes (bone X = Roblox X, bone Y = Roblox
# Y, bone Z = Roblox Z). A pose bone's rotation_quaternion therefore IS the joint's Roblox Transform rotation and the
# Root bone's location IS the Root Transform translation - export needs no axis conversion, only a (w,x,y,z) ->
# CFrame(x,y,z,qx,qy,qz,qw) reorder. Bones are drawn as short up-pointing sticks; the proxy boxes show the body.
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cr_anim_rig import JOINTS, JOINT_ORDER, PARTS, PART_JOINT, GROUND_Y  # noqa: E402
import cr_anim_clips as C  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else r"C:\WORLD.EXE-Art\CoreRound\animation"
BONE_LEN = 0.25


def to_b(v):
    return (v[0], -v[2], v[1])


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = C.FPS
    sc.unit_settings.system = "NONE"
    return sc


def make_rig(sc):
    arm_data = bpy.data.armatures.new("CR_R15")
    arm = bpy.data.objects.new("CR_R15", arm_data)
    sc.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for j in JOINT_ORDER:
        parent_part, child, piv = JOINTS[j]
        b = arm_data.edit_bones.new(j)
        h = to_b(piv)
        b.head = h
        b.tail = (h[0], h[1], h[2] + BONE_LEN)
        b.roll = 0.0
        b.use_connect = False
        b.use_deform = False
        if parent_part != "HumanoidRootPart":
            b.parent = eb[PART_JOINT[parent_part]]
        eb[j] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    # check: every bone's local axes are the Roblox axes mapped to Blender
    for bone in arm_data.bones:
        m = bone.matrix_local
        ax = [tuple(round(m[r][c], 4) for r in range(3)) for c in range(3)]
        assert ax[0] == (1.0, 0.0, 0.0) and ax[1] == (0.0, 0.0, 1.0) and ax[2] == (0.0, -1.0, 0.0), (bone.name, ax)
    return arm


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    return m


def make_body(sc, arm):
    mats = {
        "core": mat("CR_Torso", (0.16, 0.18, 0.22)),
        "head": mat("CR_Head", (0.85, 0.72, 0.6)),
        "Right": mat("CR_Right", (0.15, 0.55, 0.95)),
        "Left": mat("CR_Left", (0.95, 0.45, 0.15)),
    }
    col = bpy.data.collections.new("CR_Body")
    sc.collection.children.link(col)
    for part, (size, centre) in PARTS.items():
        j = PART_JOINT[part]
        piv = JOINTS[j][2]
        me = bpy.data.meshes.new(part)
        h = [s / 2 for s in size]
        # box in bone-local (= Roblox) axes, offset from the bone TAIL (bone-parented objects attach at the tail)
        off = (centre[0] - piv[0], centre[1] - piv[1] - BONE_LEN, centre[2] - piv[2])
        verts = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    verts.append((off[0] + sx * h[0], off[1] + sy * h[1], off[2] + sz * h[2]))
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        me.from_pydata(verts, [], faces)
        ob = bpy.data.objects.new(part, me)
        col.objects.link(ob)
        ob.parent = arm
        ob.parent_type = "BONE"
        ob.parent_bone = j
        key = "head" if part == "Head" else ("Right" if part.startswith("Right") else "Left" if part.startswith("Left") else "core")
        me.materials.append(mats[key])
    return col


def make_set(sc):
    col = bpy.data.collections.new("CR_Set")
    sc.collection.children.link(col)
    me = bpy.data.meshes.new("Floor")
    s = 8
    me.from_pydata([(-s, -s, GROUND_Y), (s, -s, GROUND_Y), (s, s, GROUND_Y), (-s, s, GROUND_Y)], [], [(0, 1, 2, 3)])
    fl = bpy.data.objects.new("Floor", me)
    me.materials.append(mat("CR_Floor", (0.55, 0.57, 0.6)))
    col.objects.link(fl)
    me = bpy.data.meshes.new("Wall")
    x = C.WALL_X
    me.from_pydata([(x, -s, GROUND_Y), (x, s, GROUND_Y), (x, s, GROUND_Y + 8), (x, -s, GROUND_Y + 8)], [], [(0, 1, 2, 3)])
    wl = bpy.data.objects.new("Wall_R", me)
    me.materials.append(mat("CR_Wall", (0.3, 0.32, 0.4)))
    col.objects.link(wl)
    wl.hide_render = True
    wl.hide_viewport = True
    return col


def fcurves_of(action, arm):
    """Blender 4.4+ layered actions keep F-curves in a channel bag per slot; older ones in action.fcurves."""
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])) > 0:
        return list(action.fcurves)
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


INTERP = {"BEZIER": ("BEZIER", "AUTO"), "QUAD_OUT": ("QUAD", "EASE_OUT"), "LINEAR": ("LINEAR", "AUTO")}


def build_action(arm, clip):
    act = bpy.data.actions.new("CR_" + clip["name"])
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    prev = {}
    for f, P, ip in clip["keys"]:
        for j in JOINT_ORDER:
            pb = arm.pose.bones[j]
            q, t = P[j]
            if j in prev and sum(a * b for a, b in zip(prev[j], q)) < 0:
                q = tuple(-c for c in q)  # stay in one quaternion hemisphere so F-curves interpolate the short way
            prev[j] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=j)
            if j == "Root":
                pb.location = t
                pb.keyframe_insert("location", frame=f, group=j)
    # per-key interpolation (Blender applies a key's interpolation to the segment that STARTS at it)
    kmap = {f: ip for f, _, ip in clip["keys"]}
    for fc in fcurves_of(act, arm):
        for kp in fc.keyframe_points:
            ip = INTERP.get(kmap.get(int(round(kp.co[0])), "BEZIER"), ("BEZIER", "AUTO"))
            kp.interpolation = ip[0]
            if ip[0] != "BEZIER":
                kp.easing = ip[1]
            else:
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"
        if clip.get("loop"):
            fc.modifiers.new("CYCLES")  # cyclic F-curves: auto handles are computed across the loop seam
        fc.update()
    meta = {k: v for k, v in clip.items() if k not in ("keys",)}
    act["cr_meta"] = json.dumps(meta)
    act.frame_range = (0, clip["frames"])
    return act


def main():
    sc = reset()
    arm = make_rig(sc)
    make_body(sc, arm)
    make_set(sc)
    clips = C.all_clips()
    for clip in clips:
        build_action(arm, clip)
    arm.animation_data.action = bpy.data.actions["CR_run"]
    sc.frame_start, sc.frame_end = 0, clips[0]["frames"]
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "WorldEXE_CoreRound_Anim_Step1E.blend")
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    print("CR_BUILD saved", path, "actions", len(clips))


main()
