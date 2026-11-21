# Core Round Step 1E: animation QA on sampled poses (pure Python). Used on the baked export (cr_anim_export.py) and,
# for quick iteration, on the authored keys directly (python cr_anim_qa.py).
#
# Checks per clip (thresholds in studs / degrees):
#   ground      lowest body point vs the floor (penetration > 0.10 fails) for clips that stay on the ground
#   foot slip   run: a foot whose lowest point is within 0.10 of the floor must move backward at the run speed
#               (planted in the world). Reported as mean / max slip speed in studs/s while planted.
#   wall        wall-run: no body part past the wall plane (> 0.10 fails); wall-foot slip like the run
#   clip        limb-torso / limb-limb box overlaps (non-adjacent parts, boxes shrunk 0.08 so surface contact is allowed)
#   limits      joint angles inside the limits below
#   head        drawn head centre vs the upright head the server samples (slide clips: vs the server's posed slide head)
#   loop        loops: pose and velocity continuity across the seam
#   disc        disc-charge clips: the held disc (RightHand * (0,-0.9,-0.4), radius 1.2) must stay clear of the torso/head
import math
import sys
from cr_anim_rig import JOINT_ORDER, PARTS, GROUND_Y, fk, qrot, qangle, vsub, vlen, obb_penetration, qmul

FPS = 30

# joint limits as (swing about X, twist about the limb's Y axis, swing about Z) in degrees, from a swing-twist
# decomposition (robust: an X-then-Z leg plane rotation is not reported as a fake Y twist the way Euler angles are)
LIMITS = {
    "Root": ((-45, 45), (-30, 30), (-35, 35)),
    "Waist": ((-35, 25), (-40, 40), (-25, 25)),
    "Neck": ((-50, 45), (-65, 65), (-35, 35)),
    "RightShoulder": ((-80, 185), (-125, 125), (-100, 110)),  # twist: straight-elbow wall brace uses -120 (correction pass)
    "LeftShoulder": ((-80, 185), (-125, 125), (-110, 100)),
    "RightElbow": ((-3, 150), (-8, 8), (-8, 8)),
    "LeftElbow": ((-3, 150), (-8, 8), (-8, 8)),
    "RightWrist": ((-75, 75), (-45, 45), (-45, 45)),
    "LeftWrist": ((-75, 75), (-45, 45), (-45, 45)),
    "RightHip": ((-55, 130), (-50, 50), (-40, 80)),
    "LeftHip": ((-55, 130), (-50, 50), (-80, 40)),
    "RightKnee": ((-155, 3), (-8, 8), (-8, 8)),
    "LeftKnee": ((-155, 3), (-8, 8), (-8, 8)),
    "RightAnkle": ((-85, 50), (-35, 35), (-50, 50)),
    "LeftAnkle": ((-85, 50), (-35, 35), (-50, 50)),
}

ARM = ["UpperArm", "LowerArm", "Hand"]
LEG = ["UpperLeg", "LowerLeg", "Foot"]
CORE = ["UpperTorso", "LowerTorso", "Head"]


def pairs():
    out = []
    for s in ("Right", "Left"):
        for a in ARM:
            for c in CORE:
                if a == "UpperArm" and c == "UpperTorso":
                    continue  # adjacent (shoulder)
                out.append((s + a, c))
        for l in ("LowerLeg", "Foot"):
            for c in ("UpperTorso", "Head"):
                out.append((s + l, c))
        for a in ARM:
            for l in LEG:
                out.append((s + a, s + l))
                o = "Left" if s == "Right" else "Right"
                out.append((s + a, o + l))
    for l in LEG:
        for m in LEG:
            out.append(("Right" + l, "Left" + m))
    return out


PAIRS = pairs()


def to_euler_xyz(q):
    """q -> (x, y, z) degrees with R = Rx * Ry * Rz (CFrame.Angles order)."""
    w, x, y, z = q
    # rotation matrix
    r00 = 1 - 2 * (y * y + z * z)
    r01 = 2 * (x * y - z * w)
    r02 = 2 * (x * z + y * w)
    r12 = 2 * (y * z - x * w)
    r22 = 1 - 2 * (x * x + y * y)
    sy = max(-1.0, min(1.0, r02))
    ay = math.asin(sy)
    if abs(sy) < 0.9999:
        ax = math.atan2(-r12, r22)
        az = math.atan2(-r01, r00)
    else:
        r21 = 2 * (y * z + x * w)
        r11 = 1 - 2 * (x * x + z * z)
        ax = math.atan2(r21, r11)
        az = 0.0
    return math.degrees(ax), math.degrees(ay), math.degrees(az)


def swing_twist(q):
    """(swing X, twist Y, swing Z) degrees: q = swing * twist, twist about Y."""
    w, x, y, z = q
    if w < 0:
        w, x, y, z = -w, -x, -y, -z
    n = math.hypot(w, y) or 1.0
    tw = (w / n, 0.0, y / n, 0.0)
    twist = math.degrees(2 * math.atan2(tw[2], tw[0]))
    sw = qmul(q if q[0] >= 0 else (-q[0], -q[1], -q[2], -q[3]), (tw[0], 0.0, -tw[2], 0.0))
    if sw[0] < 0:
        sw = tuple(-c for c in sw)
    return math.degrees(2 * math.atan2(sw[1], sw[0])), twist, math.degrees(2 * math.atan2(sw[3], sw[0]))


def corners(part):
    q, c, s = part
    out = []
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            for sz in (-0.5, 0.5):
                out.append(tuple(c[i] + v for i, v in enumerate(qrot(q, (sx * s[0], sy * s[1], sz * s[2])))))
    return out


def low_point(part):
    return min(corners(part), key=lambda p: p[1])


def qa_clip(meta, frames):
    """meta: clip metadata dict; frames: list of pose dicts sampled at FPS (loops: N+1 frames, last == first)."""
    name = meta["name"]
    res = {"name": name, "frames": len(frames), "fails": []}
    fkd = [fk(P) for P in frames]
    upper = meta.get("layer") == "upper"
    # ground penetration / contact
    gfrom = meta.get("ground_from", 0)
    if meta.get("ground") and not upper:
        lows = []
        for i, (parts, _) in enumerate(fkd):
            if i < gfrom:
                continue
            lows.append(min(low_point(p)[1] for n, p in parts.items()))
        pen = GROUND_Y - min(lows)
        res["ground_pen"] = round(pen, 3)
        res["ground_gap_max"] = round(max(lows) - GROUND_Y, 3)
        if pen > 0.10:
            res["fails"].append("ground penetration %.2f" % pen)
    # foot slip on the floor (run) and on the wall (wall-run)
    speed = meta.get("speed")
    if speed and not upper:
        # planted windows come from the authored cycle (the foot's stance phase); the contact point is the foot's lowest
        # point on the floor (run) or its outermost point toward the wall (wall-run). Planted = it moves backward at the
        # authored speed, i.e. it is still in the world.
        slips = []
        wall = meta.get("wall_x") is not None
        for s_, idx in meta.get("planted", {}).items():
            for i in idx:
                a_ = fkd[i][0][s_ + "Foot"]
                b_ = fkd[i + 1][0][s_ + "Foot"]
                pa, pb = (low_point(a_), low_point(b_))
                vz = (pb[2] - pa[2]) * FPS
                vx = (pb[0] - pa[0]) * FPS
                vy = (pb[1] - pa[1]) * FPS
                slips.append(math.sqrt((vz - speed) ** 2 + (vy * vy if wall else vx * vx)))
        if slips:
            res["slip_mean"] = round(sum(slips) / len(slips), 2)
            res["slip_max"] = round(max(slips), 2)
            res["planted_steps"] = len(slips)
            if res["slip_mean"] > 0.15 * speed:
                res["fails"].append("foot slip mean %.1f studs/s" % res["slip_mean"])
        else:
            res["fails"].append("no planted frames")
    if meta.get("wall_x") is not None and not upper:
        wx = meta["wall_x"]
        body = max(max(c[0] for c in corners(p)) for parts, _ in fkd for n, p in parts.items() if "Arm" not in n and "Hand" not in n)
        armx = max(max(c[0] for c in corners(p)) for parts, _ in fkd for n, p in parts.items() if "Arm" in n or "Hand" in n)
        res["wall_pen_body"] = round(body - wx, 3)
        res["wall_pen_arm"] = round(armx - wx, 3)
        if body - wx > 0.10:
            res["fails"].append("wall penetration (body/legs) %.2f" % (body - wx))
    # self intersection
    hits = []
    for i, (parts, _) in enumerate(fkd):
        for a, b in PAIRS:
            if a in parts and b in parts:
                d = obb_penetration(parts[a], parts[b], shrink=0.08)
                if d > 0.05:
                    hits.append((i, a, b, round(d, 2)))
    res["clip_hits"] = len(hits)
    if hits:
        worst = max(hits, key=lambda h: h[3])
        res["clip_worst"] = worst
        if worst[3] > 0.12:
            res["fails"].append("limb overlap %s/%s %.2f @%d" % (worst[1], worst[2], worst[3], worst[0]))
    # joint limits
    viol = []
    for i, P in enumerate(frames):
        for j in JOINT_ORDER:
            ex = swing_twist(P[j][0])
            for k in range(3):
                lo, hi = LIMITS[j][k]
                if ex[k] < lo - 0.5 or ex[k] > hi + 0.5:
                    viol.append((i, j, "XYZ"[k], round(ex[k], 1)))
    res["limit_viol"] = len(viol)
    if viol:
        res["limit_first"] = viol[0]
        res["fails"].append("joint limit %s %s=%.0f @%d" % (viol[0][1], viol[0][2], viol[0][3], viol[0][0]))
    # head vs server head
    if not upper:
        offs = []
        for i, (parts, _) in enumerate(fkd):
            h = parts["Head"][1]
            mode = meta.get("sw")
            if mode == "in":
                # entry: the controller draws the torso as slerp(run torso, slide torso, SlideWeight); the clip only
                # moves the limbs, so the head follows the server's blend by construction
                offs.append(0.0)
            elif mode:
                # the controller draws the torso as slerp(clip torso, slide torso, SlideWeight) and the server's head
                # sphere moves from the upright head to root + (0, slideHead, 0) on the same curve
                from cr_anim_clips import SLIDE_ROOT, SLIDE_WAIST, SLIDE_NECK
                from cr_anim_rig import qslerp, smooth
                t = i / FPS
                sw = smooth(t / 0.22) if mode == "in" else 1 - smooth(t / 0.22)
                P = dict(frames[i])
                for j, tgt in (("Root", SLIDE_ROOT), ("Waist", (SLIDE_WAIST, (0, 0, 0))), ("Neck", (SLIDE_NECK, (0, 0, 0)))):
                    q0, t0 = P[j]
                    P[j] = (qslerp(q0, tgt[0], sw), tuple(t0[k] + (tgt[1][k] - t0[k]) * sw for k in range(3)))
                hd = fk(P)[0]["Head"][1]
                srv = (0.0, 1.825 + (0.194 - 1.825) * sw, 0.0)
                offs.append(vlen(vsub(hd, srv)))
            elif meta.get("slide_torso"):
                offs.append(math.hypot(h[0], h[2]))  # torso == CoreGeom.SlidePoseR15: head over the root
            else:
                offs.append(math.hypot(h[0], h[2]))
        res["head_horiz_max"] = round(max(offs), 2)
        res["head_drop_max"] = round(max(1.825 - parts["Head"][1][1] for parts, _ in fkd), 2)
    # loop seam
    if meta.get("loop"):
        a, b = frames[0], frames[-1]
        seam = max(qangle(a[j][0], b[j][0]) for j in JOINT_ORDER)
        # velocity continuity: change of per-frame rotation step across the seam vs the largest change elsewhere
        n = len(frames) - 1  # unique frames (frames[n] == frames[0])
        def step(i, j):
            return qangle(frames[(i + 1) % n][j][0], frames[i % n][j][0])
        acc = []
        for i in range(n):
            acc.append(max(abs(step(i, j) - step(i - 1, j)) for j in JOINT_ORDER))
        res["loop_seam_deg"] = round(seam, 2)
        res["loop_seam_accel"] = round(acc[0], 2)
        res["loop_accel_max_elsewhere"] = round(max(acc[1:]), 2)
        if acc[0] > 1.5 * max(acc[1:]) + 0.5:
            res["fails"].append("loop velocity jump at the seam")
        if seam > 1.0:
            res["fails"].append("loop seam %.1f deg" % seam)
    # disc clearance while charging
    if meta["name"] == "disc_charge":
        worst = 9
        for parts, _ in fkd:
            hq, hc, _s = parts["RightHand"]
            disc = tuple(hc[i] + v for i, v in enumerate(qrot(hq, (0, -0.9, -0.4))))
            for c in ("UpperTorso", "LowerTorso", "Head"):
                q, cc, s = parts[c]
                # distance from the disc centre to the box surface (approx: box as inflated sphere test along axes)
                local = qrot((q[0], -q[1], -q[2], -q[3]), vsub(disc, cc))
                dx = max(0.0, abs(local[0]) - s[0] / 2)
                dy = max(0.0, abs(local[1]) - s[1] / 2)
                dz = max(0.0, abs(local[2]) - s[2] / 2)
                worst = min(worst, math.sqrt(dx * dx + dy * dy + dz * dz))
        res["disc_clear"] = round(worst, 2)
        if worst < 0.6:
            res["fails"].append("held disc %.2f from the body" % worst)
    return res


# ------------------------------------------------------------------------------------------------ authored-key preview
def sample_keys(clip):
    """sample the authored keys at every frame (slerp + smoothstep; Blender's Bezier is close to this)."""
    from cr_anim_rig import qslerp, smooth
    keys = [k if len(k) == 3 else (k[0], k[1], "BEZIER") for k in clip["keys"]]
    out = []
    for f in range(clip["frames"] + 1):
        for i in range(len(keys) - 1):
            f0, P0, _ = keys[i]
            f1, P1, ip = keys[i + 1]
            if f0 <= f <= f1:
                t = (f - f0) / (f1 - f0)
                t = smooth(t) if (f1 - f0) > 1 else t
                P = {}
                for j in JOINT_ORDER:
                    q = qslerp(P0[j][0], P1[j][0], t)
                    ta, tb = P0[j][1], P1[j][1]
                    P[j] = (q, tuple(ta[k] + (tb[k] - ta[k]) * t for k in range(3)))
                out.append(P)
                break
    return out


if __name__ == "__main__":
    from cr_anim_clips import all_clips
    for c in all_clips():
        r = qa_clip(c, sample_keys(c))
        print(r["name"], "FAIL" if r["fails"] else "ok", r["fails"],
              {k: v for k, v in r.items() if k not in ("name", "fails")})
