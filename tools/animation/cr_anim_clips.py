# Core Round Step 1E: original clip authoring (pure Python, no bpy). Every clip is built from key poses (and, for the
# run and wall-run loops, foot-target trajectories solved with leg IK and keyed on every frame). cr_anim_build.py turns
# these keys into Blender actions (the editable source); cr_anim_export.py bakes the Blender actions back out.
#
# All poses are ROBLOX joint Transforms (see cr_anim_rig.py). Nothing here is copied from another game or animation
# pack: the references (Sojourn slide / slide-jump, Titanfall 2 wall-run, Warframe blending) were studied for principles
# only (timing, silhouette, weight shift); the poses and curves are authored from scratch for this rig.
import math
from cr_anim_rig import (JOINTS, JOINT_ORDER, PARTS, GROUND_Y, HIP_TO_KNEE, KNEE_TO_ANKLE, euler, qmul, qaxis, qrot,
                         qnorm, vadd, vsub, fk, smooth)

FPS = 30
I = (1.0, 0.0, 0.0, 0.0)
Z3 = (0.0, 0.0, 0.0)
REST_HEAD = (0.0, 1.825, 0.0)
G = GROUND_Y
RUN_SPEED = 36.0  # studs/s the run and wall-run loops are authored for (Move.RunSpeed); playback rate = speed / 36

# Slide torso, shared with the server (CoreGeom.SlidePoseR15). The slide clips use exactly these three targets so the
# server's PosedHeadOffset stays the drawn head height. Step 1E moves the Root target forward (z 0.2 -> -1.11): with the
# Step 1C value the drawn slide head sat 1.31 studs BEHIND the root, while the server's slide head sphere is centred
# above the root (root + (0, PosedHeadOffset, 0)). The new value puts the drawn head on the server's head (z = 0.00);
# its height is unchanged (0.194), so the server's hit volumes do not change.
SLIDE_Z = -1.11
SLIDE_ROOT = (euler(38, 0, 0), (0.0, -1.35, SLIDE_Z))
SZ = SLIDE_Z - 0.2  # shift applied to Step 1C-relative slide limb targets
SLIDE_WAIST = euler(-12, -8, 0)
SLIDE_NECK = euler(-22, 0, 0)

CONTACT = {"toe": (0.0, -0.278, -0.5), "heel": (0.0, -0.278, 0.5), "mid": (0.0, -0.278, 0.0)}


def qinv(q):
    return (q[0], -q[1], -q[2], -q[3])


def E(x=0.0, y=0.0, z=0.0):
    return euler(x, y, z)


def base():
    return {j: (I, Z3) for j in JOINT_ORDER}


def copy(P):
    return dict(P)


def side_name(side):
    return "Right" if side > 0 else "Left"


def arm(P, side, fwd, out, twist=0.0, elbow=0.0, wrist=0.0):
    """shoulder forward (+) / out to the side (+) / twist, elbow flexion (+), wrist flexion. Mirrored per side."""
    n = side_name(side)
    P[n + "Shoulder"] = (E(fwd, twist * side, out * side), Z3)
    P[n + "Elbow"] = (E(elbow, 0, 0), Z3)
    P[n + "Wrist"] = (E(wrist, 0, 0), Z3)


def hip_world(P, side):
    q, t = P["Root"]
    piv = (t[0], -0.9 + t[1], t[2])
    return vadd(piv, qrot(q, (0.433 * side, 0.0, 0.0)))


def solve_leg(P, side, target, qfoot, contact="toe", bend_bias=0.0, rel_pitch=None, rel_w=0.0, roll=0.0):
    """place the foot (world rotation qfoot) so its `contact` point is at `target` (character space).
    Sets Hip / Knee / Ankle. Returns the reach shortfall in studs (0 when reachable).
    rel_pitch / rel_w: blend the foot's pitch toward (shin angle + rel_pitch) - a relaxed foot in the air."""
    if rel_pitch is not None and rel_w > 0.001:
        short = _solve_leg(P, side, target, qfoot, contact, bend_bias)
        for _ in range(3):
            n = side_name(side)
            w_shin = qmul(P["Root"][0], qmul(P[n + "Hip"][0], P[n + "Knee"][0]))
            fwd = qrot(w_shin, (0.0, -1.0, 0.0))
            shin_pitch = math.degrees(math.atan2(-fwd[2], -fwd[1]))
            base_pitch = _pitch_of(qfoot)
            pitch = base_pitch + (shin_pitch + rel_pitch - base_pitch) * rel_w
            short = _solve_leg(P, side, target, qmul(E(0, 0, roll), E(pitch, 0, 0)), contact, bend_bias)
        return short
    return _solve_leg(P, side, target, qfoot, contact, bend_bias)


def _pitch_of(q):
    f = qrot(q, (0.0, 0.0, -1.0))
    return math.degrees(math.atan2(f[1], -f[2]))


def _solve_leg(P, side, target, qfoot, contact="toe", bend_bias=0.0):
    n = side_name(side)
    hip = hip_world(P, side)
    qf0 = qfoot
    alpha = 0.0
    for _ in range(3):  # the foot follows the leg plane's sideways tilt (alpha); its contact point moves with it
        qfoot = qmul(qaxis((0, 0, 1), math.degrees(alpha)), qf0)
        ankle = vsub(target, qrot(qfoot, CONTACT[contact]))
        d = vsub(ankle, hip)
        alpha = math.atan(d[0] / max(0.35, -d[1]))
    qa = qaxis((0, 0, 1), math.degrees(alpha))
    dl = qrot(qinv(qa), d)
    y, z = dl[1], dl[2]
    L1, L2 = HIP_TO_KNEE, KNEE_TO_ANKLE
    dist = math.hypot(y, z)
    short = max(0.0, dist - (L1 + L2 - 1e-3))
    dist = max(abs(L1 - L2) + 0.05, min(L1 + L2 - 1e-3 - bend_bias, dist))
    a = math.atan2(-z, -y)
    beta = math.acos(max(-1.0, min(1.0, (L1 * L1 + dist * dist - L2 * L2) / (2 * L1 * dist))))
    k = math.acos(max(-1.0, min(1.0, (L1 * L1 + L2 * L2 - dist * dist) / (2 * L1 * L2))))
    theta = math.degrees(a + beta)
    knee = -math.degrees(math.pi - k)
    w_thigh = qmul(qa, E(theta, 0, 0))
    qroot = P["Root"][0]
    P[n + "Hip"] = (qnorm(qmul(qinv(qroot), w_thigh)), Z3)
    P[n + "Knee"] = (E(knee, 0, 0), Z3)
    w_shin = qmul(w_thigh, E(knee, 0, 0))
    P[n + "Ankle"] = (qnorm(qmul(qinv(w_shin), qfoot)), Z3)
    return short


def head_pos(P):
    parts, _ = fk(P)
    return parts["Head"][1]


def anchor_head(P, axes=(1.0, 0.0, 1.0), target=REST_HEAD):
    """translate the Root so the drawn head stays where the server's (upright) head is (per axis weight)."""
    h = head_pos(P)
    q, t = P["Root"]
    P["Root"] = (q, (t[0] + (target[0] - h[0]) * axes[0], t[1] + (target[1] - h[1]) * axes[1],
                     t[2] + (target[2] - h[2]) * axes[2]))


def mirror(P):
    out = {}
    for j, (q, t) in P.items():
        if j.startswith("Right"):
            nj = "Left" + j[5:]
        elif j.startswith("Left"):
            nj = "Right" + j[4:]
        else:
            nj = j
        out[nj] = ((q[0], q[1], -q[2], -q[3]), (-t[0], t[1], t[2]))
    return out


# ------------------------------------------------------------------------------------------------ periodic Hermite
def hermite(keys, u, period=1.0):
    """keys: [(u, value, tangent|None)] sorted, u in [0, period). Periodic cubic Hermite (Catmull-Rom tangents)."""
    n = len(keys)
    u = u % period
    ks = keys

    def tan(i):
        ui, vi, mi = ks[i % n]
        if mi is not None:
            return mi
        up, vp, _ = ks[(i - 1) % n]
        un, vn, _ = ks[(i + 1) % n]
        if i - 1 < 0:
            up -= period
        if i + 1 >= n:
            un += period
        return (vn - vp) / (un - up)

    for i in range(n):
        u0, v0, _ = ks[i]
        u1, v1, _ = ks[(i + 1) % n]
        if i + 1 >= n:
            u1 += period
        uu = u if u >= u0 else u + period
        if u0 <= uu < u1 or (i == n - 1):
            h = u1 - u0
            s = (uu - u0) / h
            m0, m1 = tan(i) * h, tan(i + 1) * h
            s2, s3 = s * s, s * s * s
            return (2 * s3 - 3 * s2 + 1) * v0 + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * v1 + (s3 - s2) * m1
    return keys[0][1]


# ================================================================================================ RUN (loop)
RUN_FRAMES = 14  # 0.467 s per cycle (two steps), authored for 36 studs/s
STANCE = 0.16  # fraction of the cycle a foot is planted (0.075 s, sprint-like ground contact)


def run_leg_keys():
    T = RUN_FRAMES / FPS
    zf = -1.0
    zb = zf + RUN_SPEED * STANCE * T
    slope = (zb - zf) / STANCE
    z = [(0.0, zf, slope), (STANCE, zb, slope), (0.30, zb + 0.45, None), (0.50, 0.70, None), (0.68, -0.95, None),
         (0.86, -1.65, None)]
    h = [(0.0, 0.0, 0.0), (STANCE, 0.0, 0.0), (0.30, 0.55, None), (0.50, 0.85, None), (0.68, 0.80, None),
         (0.86, 0.35, None)]
    p = [(0.0, -8.0, None), (STANCE, -42.0, None), (0.30, -65.0, None), (0.50, -40.0, None), (0.68, -12.0, None),
         (0.86, 2.0, None)]
    return z, h, p, zf, zb


def run_pose(phi, speed_tag=None):
    P = base()
    TAU = 2 * math.pi
    # torso: forward lean, pelvis twist with the legs, shoulders counter-rotate, head steady
    fr = math.cos(TAU * (phi - 0.80))  # right thigh forwardness (max at 0.80)
    drop = -0.20 - 0.11 * math.cos(TAU * 2 * (phi - STANCE / 2))
    roll = 2.5 * math.cos(TAU * (phi - STANCE / 2))  # tilt toward the planted side a little
    P["Root"] = (E(-12 + 1.5 * math.cos(TAU * 2 * (phi - 0.1)), 6 * fr, roll), (0.0, drop, 0.0))
    P["Waist"] = (E(-4, -13 * fr, -roll * 0.6), Z3)
    P["Neck"] = (E(15, 7 * fr, -roll * 0.4), Z3)
    anchor_head(P, (1.0, 0.0, 1.0))
    # legs from foot-contact trajectories (right foot lands at phi 0, left at 0.5)
    zk, hk, pk, _, _ = run_leg_keys()
    for side, off in ((1, 0.0), (-1, 0.5)):
        u = (phi - off) % 1.0
        z = hermite(zk, u)
        h = max(0.0, hermite(hk, u))
        pitch = hermite(pk, u)
        solve_leg(P, side, (0.433 * side, G + h, z), E(pitch, 0, 0), "toe", rel_pitch=-28, rel_w=smooth(h / 0.5))
    # arms pump opposite the legs, elbows bent ~90
    for side, off in ((1, 0.30), (-1, 0.80)):
        c = math.cos(TAU * (phi - off))
        arm(P, side, 12 + 58 * c, 9 - 3 * c, twist=-6 * c, elbow=88 + 22 * c, wrist=-8)
    return P


def stance_pairs(sides):
    """frame pairs (i, i+1) inside each foot's planted window: {side: [i, ...]}"""
    out = {}
    for s_, off in sides:
        out[s_] = [f for f in range(RUN_FRAMES) if ((f / RUN_FRAMES - off) % 1.0) + 1.0 / RUN_FRAMES <= STANCE + 1e-6]
    return out


def clip_run():
    keys = []
    for f in range(RUN_FRAMES + 1):
        keys.append((f, run_pose((f % RUN_FRAMES) / RUN_FRAMES)))
    return {"name": "run", "loop": True, "frames": RUN_FRAMES, "keys": keys, "interp": "BEZIER", "ground": True,
            "speed": RUN_SPEED, "layer": "full", "planted": stance_pairs((("Right", 0.0), ("Left", 0.5)))}


# ================================================================================================ SLIDE
def slide_base():
    P = base()
    P["Root"] = SLIDE_ROOT
    P["Waist"] = (SLIDE_WAIST, Z3)
    P["Neck"] = (SLIDE_NECK, Z3)
    return P


def rear_leg(P, thigh_world, shin_world, foot_world, out=10.0):
    """slide rear leg by WORLD angles (from straight down, + forward): thigh, shin, foot pitch; out to the side."""
    lean = 38.0  # SLIDE_ROOT pitch
    P["LeftHip"] = (E(thigh_world - lean, 0, -out), Z3)
    P["LeftKnee"] = (E(shin_world - thigh_world, 0, 0), Z3)
    P["LeftAnkle"] = (E(foot_world - shin_world, 0, 0), Z3)


def rear_leg_fit(P, shin_world, foot_world, out, touch=0.02):
    """rear leg folded under, shin lying back along the floor: pick the thigh angle so the leg's lowest point is at
    floor + touch (raising the thigh raises the knee and the whole shin, so this is monotonic)."""
    lo_a, hi_a = 0.0, 100.0
    for _ in range(30):
        mid = (lo_a + hi_a) / 2
        rear_leg(P, mid, shin_world, foot_world, out)
        parts, _ = fk(P)
        low = min(min(c[1] for c in _corners(parts[n])) for n in ("LeftUpperLeg", "LeftLowerLeg", "LeftFoot"))
        if low < G + touch:
            lo_a = mid
        else:
            hi_a = mid
    rear_leg(P, hi_a, shin_world, foot_world, out)
    return hi_a


def _corners(part):
    q, c, sz = part
    out = []
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            for s3 in (-0.5, 0.5):
                out.append(vadd(c, qrot(q, (sx * sz[0], sy * sz[1], s3 * sz[2]))))
    return out


def slide_pose(t=0.0, kick=0.0):
    """t: loop phase (0..1) for small life motion; kick: 0 = settled, 1 = lead leg thrown out further (entry)."""
    P = slide_base()
    TAU = 2 * math.pi
    # lead (right) leg out in front, heel skimming the floor, toe up
    lead_z = SZ - 2.75 - 0.25 * kick + 0.04 * math.sin(TAU * 3 * t)
    solve_leg(P, 1, (0.55, G + 0.02 + 0.25 * kick, lead_z), E(28 + 3 * math.sin(TAU * 6 * t), 0, -6), "heel")
    # rear (left) leg folded under: shin flat on the floor, foot behind and out
    rear_leg_fit(P, -94 + 2 * math.sin(TAU * 2 * t + 0.7), -160, 12, touch=0.01 + 0.015 * math.sin(TAU * 2 * t))
    # disc arm (right) forward / low for balance, free (left) hand trailing on the floor
    arm(P, 1, 48 + 3 * math.sin(TAU * t), 16, twist=4, elbow=34, wrist=-10)
    arm(P, -1, -48 + 2 * math.sin(TAU * 2 * t + 1), 26 + 3 * math.sin(TAU * 2 * t), twist=-10, elbow=10, wrist=25)  # hand trails low
    return P


def clip_slide_loop():
    n = 30
    keys = [(f, slide_pose((f % n) / n)) for f in range(0, n + 1, 3)]
    return {"name": "slide_loop", "loop": True, "frames": n, "keys": keys, "interp": "BEZIER", "ground": True,
            "layer": "full", "slide_torso": True}


def clip_slide_in():
    # timed for Slide.PoseBlendSeconds 0.22: the torso blend itself is driven by CoreGeom.SlideWeight in the
    # controller; this clip is the limb action (legs thrown forward, arms out) while the body drops
    P0 = slide_base()
    solve_leg(P0, 1, (0.5, G + 0.45, SZ - 1.9), E(-5, 0, 0), "toe")  # lead leg swinging through
    rear_leg_fit(P0, -45, -100, 8, touch=0.3)
    arm(P0, 1, 70, 22, elbow=60)
    arm(P0, -1, -20, 40, elbow=30)
    P1 = slide_pose(0.0, kick=1.0)  # lead leg overshoots
    arm(P1, 1, 54, 18, elbow=40, wrist=-10)
    P2 = slide_pose(0.0)
    keys = [(0, P0, "QUAD_OUT"), (4, P1, "BEZIER"), (7, P2, "BEZIER")]
    return {"name": "slide_in", "loop": False, "frames": 7, "keys": keys, "interp": "BEZIER", "ground": True,
            "layer": "full", "slide_torso": True, "sw": "in", "ground_from": 5}


def clip_slide_out():
    P0 = slide_pose(0.0)
    P1 = base()
    P1["Root"] = (E(4, 0, 0), (0.0, -0.75, 0.0))
    P1["Waist"] = (E(-6, 0, 0), Z3)
    P1["Neck"] = (E(2, 0, 0), Z3)
    anchor_head(P1, (1.0, 0.0, 1.0))
    solve_leg(P1, 1, (0.5, G + 0.15, -1.3), E(10, 0, 0), "heel")  # lead leg pulls back under
    solve_leg(P1, -1, (-0.5, G, 0.4), E(-30, 0, 0), "toe")  # rear foot plants to push up
    arm(P1, 1, 60, 14, elbow=70)
    arm(P1, -1, 35, 30, elbow=60)
    P2 = run_pose(0.0)  # hands over to the run (controller blends with SlideWeight)
    keys = [(0, P0, "BEZIER"), (4, P1, "BEZIER"), (8, P2, "BEZIER")]
    return {"name": "slide_out", "loop": False, "frames": 8, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "full", "sw": "out"}


# ================================================================================================ POWER SLIDE JUMP
def air_anchor(P):
    anchor_head(P, (1.0, 0.6, 1.0))


def clip_psj_push():
    # 0.167 s: explosive extension out of the slide. Frame 0 = slide pose; 2 = load (rear foot under, arms down/back);
    # 5 = full extension (legs driven down and back, toes pointed, chest up, both arms thrown up)
    P0 = slide_pose(0.0)
    P1 = slide_base()
    P1["Root"] = (E(18, 0, 0), (0.0, -1.0, 0.15 + SZ))
    solve_leg(P1, 1, (0.5, G + 0.25, SZ - 1.5), E(0, 0, 0), "heel")
    solve_leg(P1, -1, (-0.45, G, SZ + 0.2), E(-32, 0, 0), "toe")
    arm(P1, 1, -30, 18, elbow=40)
    arm(P1, -1, -30, 22, elbow=30)
    P2 = base()
    P2["Root"] = (E(-6, 0, 0), Z3)
    P2["Waist"] = (E(8, 0, 0), Z3)
    P2["Neck"] = (E(-8, 0, 0), Z3)
    air_anchor(P2)
    solve_leg(P2, 1, (0.45, G - 0.25, 0.55), E(-55, 0, 0), "toe")
    solve_leg(P2, -1, (-0.45, G - 0.1, 0.95), E(-62, 0, 0), "toe")
    arm(P2, 1, 138, 16, twist=-10, elbow=28)
    arm(P2, -1, 146, 20, twist=-10, elbow=24)
    keys = [(0, P0, "BEZIER"), (2, P1, "QUAD_OUT"), (5, P2, "BEZIER")]
    return {"name": "psj_push", "loop": False, "frames": 5, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "full", "sw": "out"}


def tuck_pose(open_=0.0):
    P = base()
    P["Root"] = (E(-4 + 6 * open_, 0, 0), Z3)
    P["Waist"] = (E(-10 + 8 * open_, 0, 0), Z3)
    P["Neck"] = (E(6 - 4 * open_, 0, 0), Z3)
    air_anchor(P)
    # knees driven up (right higher), shins folded
    P["RightHip"] = (E(88 - 40 * open_, 0, 4), Z3)
    P["RightKnee"] = (E(-118 + 60 * open_, 0, 0), Z3)
    P["RightAnkle"] = (E(-20, 0, 0), Z3)
    P["LeftHip"] = (E(62 - 70 * open_, 0, -4), Z3)
    P["LeftKnee"] = (E(-105 + 35 * open_, 0, 0), Z3)
    P["LeftAnkle"] = (E(-25, 0, 0), Z3)
    arm(P, 1, 70 - 25 * open_, 24 + 30 * open_, elbow=55 - 25 * open_)
    arm(P, -1, 55 - 20 * open_, 38 + 30 * open_, elbow=45 - 20 * open_)
    return P


def clip_psj_rise():
    P0 = clip_psj_push()["keys"][-1][1]
    keys = [(0, P0, "BEZIER"), (4, tuck_pose(0.0), "BEZIER"), (10, tuck_pose(0.1), "BEZIER")]
    return {"name": "psj_rise", "loop": False, "frames": 10, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "full"}


def apex_pose():
    P = tuck_pose(0.6)
    P["Neck"] = (E(-10, 0, 0), Z3)  # glance down for the landing spot
    P["Waist"] = (E(-6, 0, 0), Z3)
    air_anchor(P)
    return P


def clip_psj_apex():
    keys = [(0, tuck_pose(0.1), "BEZIER"), (6, apex_pose(), "BEZIER"), (12, fall_pose(0.0), "BEZIER")]
    return {"name": "psj_apex", "loop": False, "frames": 12, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "full"}


def fall_pose(t):
    TAU = 2 * math.pi
    s = math.sin(TAU * t)
    P = base()
    P["Root"] = (E(4, 0, 0), Z3)
    P["Waist"] = (E(-4, 0, 0), Z3)
    P["Neck"] = (E(-6, 0, 0), Z3)
    air_anchor(P)
    # legs reach down for the floor, slow alternating pedal
    P["RightHip"] = (E(22 + 12 * s, 0, 5), Z3)
    P["RightKnee"] = (E(-38 - 14 * s, 0, 0), Z3)
    P["RightAnkle"] = (E(-12, 0, 0), Z3)
    P["LeftHip"] = (E(4 - 12 * s, 0, -5), Z3)
    P["LeftKnee"] = (E(-30 + 12 * s, 0, 0), Z3)
    P["LeftAnkle"] = (E(-15, 0, 0), Z3)
    # arms up and out for balance
    arm(P, 1, 30 + 6 * s, 58 + 5 * math.cos(TAU * t), elbow=35)
    arm(P, -1, 30 - 6 * s, 58 - 5 * math.cos(TAU * t), elbow=35)
    return P


def clip_fall():
    n = 24
    keys = [(f, fall_pose(f / n)) for f in range(0, n + 1, 6)]
    return {"name": "fall", "loop": True, "frames": n, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "full"}


def land_pose(depth, lean, arms_fwd):
    P = base()
    P["Root"] = (E(-lean, 0, 0), (0.0, -depth, 0.0))
    P["Waist"] = (E(-lean * 0.5, 0, 0), Z3)
    P["Neck"] = (E(lean * 1.2, 0, 0), Z3)
    anchor_head(P, (1.0, 0.0, 1.0))
    solve_leg(P, 1, (0.5, G, -0.55), E(0, 0, 0), "mid")
    solve_leg(P, -1, (-0.5, G, 0.35), E(0, 0, 0), "mid")
    arm(P, 1, arms_fwd, 26, elbow=40)
    arm(P, -1, arms_fwd * 0.8, 30, elbow=40)
    return P


def clip_land():
    # 0.33 s impact + recovery with both feet planted (solved every frame). Never blocks control: there is no root
    # motion and the controller fades it out as soon as the player moves. Ends in a light ready stance.
    n = 10
    keys = []
    for f in range(n + 1):
        t = f / n
        k = smooth(t / 0.3) * (1 - smooth((t - 0.3) / 0.7))  # 0 -> 1 at 0.1 s -> 0
        keys.append((f, land_pose(0.12 + 0.56 * k, 6 + 14 * k, 25 + 20 * k)))
    return {"name": "land", "loop": False, "frames": n, "keys": keys, "interp": "BEZIER", "ground": True,
            "layer": "full"}


# ================================================================================================ WALL-RUN (wall on the right)
WALL_X = 0.90  # wall plane, character space (the root rides ~0.85-0.9 from the wall: HRP half width 0.85)
WALL_TILT = 8.0  # body lean away from the wall (the head stays within 0.4 of the server's upright head)


def wall_pose(phi):
    TAU = 2 * math.pi
    P = base()
    fr = math.cos(TAU * (phi - 0.80))
    drop = -0.12 - 0.08 * math.cos(TAU * 2 * (phi - STANCE / 2))
    P["Root"] = (E(-10, 5 * fr, WALL_TILT), (0.0, drop, 0.0))
    P["Waist"] = (E(-4, -10 * fr, 2), Z3)
    P["Neck"] = (E(12, 5 * fr, -WALL_TILT * 0.8), Z3)
    anchor_head(P, (0.0, 0.0, 1.0))  # forward only: shifting toward the wall would push the hips into it
    zk, hk, pk, zf, zb = run_leg_keys()
    # The root rides ~0.9 from the wall (the HumanoidRootPart touches it), so the body is flush with the wall: the
    # legs run the sprint cycle under the body (no floor: the cycle is lifted); the wall-side foot rolls its outer
    # edge toward the wall base while planted and runs along it (planted = moving back at the run speed)
    for side, off in ((1, 0.0), (-1, 0.5)):
        u = (phi - off) % 1.0
        z = hermite(zk, u)
        h = max(0.0, hermite(hk, u))
        pitch = hermite(pk, u)
        roll = 8.0 if side > 0 else 0.0
        x = 0.433 * side + (0.0 if side > 0 else 0.1)
        lift = 0.55 if side > 0 else 0.30
        solve_leg(P, side, (x, G + lift + 0.75 * h, z), qmul(E(0, 0, roll), E(pitch, 0, 0)), "toe", rel_pitch=-28,
                  rel_w=smooth(h / 0.5), roll=roll)
    # outer arm pumps hard; the wall-side arm drives forward and up along the wall, elbow in (it cannot swing out:
    # the wall is at the shoulder)
    c = math.cos(TAU * (phi - 0.80))
    arm(P, -1, 15 + 60 * c, 12, twist=-6 * c, elbow=90 + 20 * c, wrist=-8)
    c2 = math.cos(TAU * (phi - 0.30))
    arm(P, 1, 104 + 6 * c2, -48, twist=90, elbow=28 + 8 * c2, wrist=-10)  # searched: closest to the wall plane
    return P


def clip_wallrun():
    keys = [(f, wall_pose((f % RUN_FRAMES) / RUN_FRAMES)) for f in range(RUN_FRAMES + 1)]
    return {"name": "wallrun_r", "loop": True, "frames": RUN_FRAMES, "keys": keys, "interp": "BEZIER", "ground": False,
            "wall_x": WALL_X, "speed": RUN_SPEED, "layer": "full", "mirror": "wallrun_l",
            "planted": stance_pairs((("Right", 0.0),))}


def clip_walljump_push():
    # 0.2 s push-off from a wall on the right: wall leg and hand drive the body away, outer knee and the free hand lead
    P0 = wall_pose(0.05)
    P1 = base()
    P1["Root"] = (E(-6, -10, 24), Z3)
    P1["Waist"] = (E(4, -8, 6), Z3)
    P1["Neck"] = (E(0, 10, -22), Z3)
    air_anchor(P1)
    solve_leg(P1, 1, (WALL_X + 0.6, G + 0.65, 0.6), qmul(E(0, 0, 30), E(-40, 0, 0)), "toe")  # wall leg straight, pushing
    solve_leg(P1, -1, (-1.15, G + 1.0, -0.9), E(-10, 0, -8), "toe")  # outer knee drives up
    arm(P1, 1, 20, 48, elbow=10, wrist=30)  # wall hand shoves off
    arm(P1, -1, 140, 30, twist=-10, elbow=20)  # free hand reaches out / up (the Step 1C "reach", now in the clip)
    P2 = copy(P1)
    P2["Root"] = (E(-4, -6, 16), Z3)
    air_anchor(P2)
    solve_leg(P2, 1, (1.3, G + 0.4, 0.9), E(-50, 0, 15), "toe")
    solve_leg(P2, -1, (-0.95, G + 0.85, -0.7), E(-15, 0, -8), "toe")
    keys = [(0, P0, "BEZIER"), (3, P1, "QUAD_OUT"), (6, P2, "BEZIER")]
    return {"name": "walljump_r", "loop": False, "frames": 6, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "full", "mirror": "walljump_l"}


def clip_walljump_recover():
    P0 = clip_walljump_push()["keys"][-1][1]
    P1 = tuck_pose(0.35)
    P1["Root"] = (E(-2, -3, 6), Z3)
    air_anchor(P1)
    keys = [(0, P0, "BEZIER"), (5, P1, "BEZIER"), (12, fall_pose(0.0), "BEZIER")]
    return {"name": "walljump_recover_r", "loop": False, "frames": 12, "keys": keys, "interp": "BEZIER",
            "ground": False, "layer": "full", "mirror": "walljump_recover_l"}


# ================================================================================================ DASH (owner request)
# The regular dash is a 0.25 s burst at 104 studs/s toward the move input (camera forward if none). With the aim lock
# the body faces the camera, so the burst can go forward, back or sideways relative to the body: one clip per
# direction (side is authored to the right and mirrored), blended by the controller for diagonals. 10 frames:
# 0 = launch, 2 = full shape, 7 = held shape drifting, 10 = recovered (the controller fades back to the base layer).
# Feet skim the floor (it is a glide, not steps), the head stays on the server's head (anchored).

def dash_front(k=1.0):
    P = base()
    P["Root"] = (E(-24 * k, 0, 0), (0.0, -0.35 * k, 0.0))
    P["Waist"] = (E(-8 * k, 0, 0), Z3)
    P["Neck"] = (E(26 * k, 0, 0), Z3)
    anchor_head(P, (1.0, 0.0, 1.0))
    # long lunge: lead (left) knee forward, rear (right) leg driven back and straight, toe skimming
    solve_leg(P, -1, (-0.45, G + 0.05 + 0.2 * (1 - k), -1.6 * k - 0.2), E(-6 * k, 0, 0), "toe")
    solve_leg(P, 1, (0.45, G + 0.25 * k, 1.9 * k), E(-55 * k, 0, 0), "toe")
    # arms swept back, streamlined
    arm(P, 1, -55 * k, 18 * k, twist=-15 * k, elbow=20, wrist=-10 * k)
    arm(P, -1, -50 * k, 18 * k, twist=-15 * k, elbow=20, wrist=-10 * k)
    return P


def dash_back(k=1.0):
    P = base()
    P["Root"] = (E(12 * k, 0, 0), (0.0, -0.45 * k, 0.0))
    P["Waist"] = (E(-14 * k, 0, 0), Z3)  # chest stays over the hips, eyes forward
    P["Neck"] = (E(2 * k, 0, 0), Z3)
    anchor_head(P, (1.0, 0.0, 1.0))
    # hop-back: front (right) foot pushes off ahead, rear (left) leg reaches back to catch
    solve_leg(P, 1, (0.5, G + 0.05, -1.2 * k), E(10 * k, 0, 0), "heel")
    solve_leg(P, -1, (-0.5, G + 0.2 * k, 1.15 * k), E(-25 * k, 0, 0), "toe")
    # arms forward for balance
    arm(P, 1, 55 * k, 22 * k, twist=-8 * k, elbow=40 * k)
    arm(P, -1, 45 * k, 26 * k, twist=-8 * k, elbow=45 * k)
    return P


def dash_side(k=1.0):
    """dash to the character's RIGHT: body leans into it, lead (right) leg reaches out, trail leg pushes."""
    P = base()
    P["Root"] = (E(-6 * k, 8 * k, -21 * k), (0.0, -0.5 * k, 0.0))  # -Z rolls the top to the right
    P["Waist"] = (E(-4 * k, -6 * k, -4 * k), Z3)
    P["Neck"] = (E(6 * k, 0, 24 * k), Z3)
    anchor_head(P, (1.0, 0.0, 1.0))
    solve_leg(P, 1, (0.433 + 1.3 * k, G + 0.24 + 0.08 * k, -0.2 * k), qmul(E(0, 0, 6 * k), E(-10 * k, 0, 0)), "mid")
    solve_leg(P, -1, (-0.433 - 0.9 * k, G + 0.3, 0.15 * k), qmul(E(0, 0, -12 * k), E(-35 * k, 0, 0)), "toe")
    # trail arm swings across the chest, lead arm out low for balance
    arm(P, 1, 20 * k, 40 * k, twist=-10 * k, elbow=25 * k)
    arm(P, -1, 45 * k, -8 * k, twist=10 * k, elbow=60 * k)
    return P


def _dash_clip(name, fn, mirror_name=None):
    # keyed on every frame (feet are solved per frame, so joint-space interpolation cannot dip them into the floor)
    def k_at(f):
        if f <= 2:
            return 0.55 + 0.45 * smooth(f / 2)
        if f <= 7:
            return 1.0 - 0.08 * (f - 2) / 5
        return 0.92 - 0.67 * smooth((f - 7) / 3)
    keys = [(f, fn(k_at(f)), "BEZIER") for f in range(11)]
    c = {"name": name, "loop": False, "frames": 10, "keys": keys, "interp": "BEZIER", "ground": True,
         "layer": "full"}
    if mirror_name:
        c["mirror"] = mirror_name
    return c


def clip_dash_front():
    return _dash_clip("dash_f", dash_front)


def clip_dash_back():
    return _dash_clip("dash_b", dash_back)


def clip_dash_side():
    return _dash_clip("dash_r", dash_side, "dash_l")


# ================================================================================================ UPPER BODY: DISC
DISC_MASK = ["Waist", "RightShoulder", "RightElbow", "RightWrist"]
SHIELD_MASK = ["LeftShoulder", "LeftElbow", "LeftWrist"]


def disc_cock(k=1.0):
    """side-arm wind-up: disc arm out to the right and back, wrist cocked, chest coiled (k = how far)."""
    P = base()
    P["Waist"] = (E(0, -16 * k, 0), Z3)
    arm(P, 1, 10 - 25 * k, 30 + 52 * k, twist=-20 * k, elbow=40 + 45 * k, wrist=-35 * k)
    return P


def clip_disc_charge():
    keys = [(0, disc_cock(0.0), "BEZIER"), (3, disc_cock(0.75), "BEZIER"), (8, disc_cock(1.0), "BEZIER")]
    return {"name": "disc_charge", "loop": False, "frames": 8, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "upper", "mask": DISC_MASK}


def clip_disc_release():
    P0 = disc_cock(1.0)
    P1 = base()  # whip: arm sweeps forward across, elbow snaps straight
    P1["Waist"] = (E(0, 18, 0), Z3)
    arm(P1, 1, 75, 40, twist=10, elbow=6, wrist=20)
    P2 = base()  # follow-through across the body (arm stays in front of the chest)
    P2["Waist"] = (E(0, 22, 0), Z3)
    arm(P2, 1, 70, 5, twist=20, elbow=22, wrist=10)
    P3 = base()
    keys = [(0, P0, "BEZIER"), (2, P1, "QUAD_OUT"), (5, P2, "BEZIER"), (10, P3, "BEZIER")]
    return {"name": "disc_release", "loop": False, "frames": 10, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "upper", "mask": DISC_MASK}


# ================================================================================================ UPPER BODY: SHIELD
def shield_pose(k=1.0, t=0.0):
    """left forearm raised across the front of the chest, palm out (the projector), k = raised amount."""
    P = base()
    TAU = 2 * math.pi
    arm(P, -1, 8 + 72 * k + 2 * math.sin(TAU * t), 22 - 30 * k, twist=-35 * k, elbow=18 + 82 * k + 2 * math.sin(TAU * t + 1),
        wrist=-20 * k)
    return P


def clip_shield_raise():
    keys = [(0, shield_pose(0.0), "BEZIER"), (2, shield_pose(1.08), "QUAD_OUT"), (4, shield_pose(1.0), "BEZIER")]
    return {"name": "shield_raise", "loop": False, "frames": 4, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "upper", "mask": SHIELD_MASK}


def clip_shield_hold():
    n = 30
    keys = [(f, shield_pose(1.0, f / n)) for f in range(0, n + 1, 5)]
    return {"name": "shield_hold", "loop": True, "frames": n, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "upper", "mask": SHIELD_MASK}


def clip_shield_lower():
    keys = [(0, shield_pose(1.0), "BEZIER"), (5, shield_pose(0.0), "BEZIER")]
    return {"name": "shield_lower", "loop": False, "frames": 5, "keys": keys, "interp": "BEZIER", "ground": False,
            "layer": "upper", "mask": SHIELD_MASK}


def all_clips():
    clips = [clip_run(), clip_slide_in(), clip_slide_loop(), clip_slide_out(), clip_psj_push(), clip_psj_rise(),
             clip_psj_apex(), clip_fall(), clip_land(), clip_wallrun(), clip_walljump_push(), clip_walljump_recover(),
             clip_dash_front(), clip_dash_back(), clip_dash_side(),
             clip_disc_charge(), clip_disc_release(), clip_shield_raise(), clip_shield_hold(), clip_shield_lower()]
    # normalise keys to (frame, pose, interp)
    for c in clips:
        c["keys"] = [k if len(k) == 3 else (k[0], k[1], c["interp"]) for k in c["keys"]]
    return clips
