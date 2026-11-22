# Core Round Step 1E wall-run reach (owner direction 2026-11-21): searches the wall-run body offset and the wall-side
# arm for the "raised, outward-reaching arm; only the hand and feet touch the wall" pose. Pure Python (no bpy).
# Run with Blender's bundled Python:  python -I cr_wall_reach_search.py
# Metrics are in character space for a wall on the RIGHT at x = WALL_X (the left wall is the mirror).
import itertools
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cr_anim_clips as C  # noqa: E402
from cr_anim_rig import fk, obb_penetration, qrot  # noqa: E402
import cr_anim_qa as Q  # noqa: E402

WX = C.WALL_X


def corners_x(part):
    return max(c[0] for c in Q.corners(part))


def body_metrics(P):
    parts, piv = fk(P)
    torso = max(corners_x(parts[n]) for n in ("UpperTorso", "LowerTorso", "Head", "RightUpperLeg"))
    head = parts["Head"][1]
    return parts, piv, torso, math.hypot(head[0], head[2])


def arm_metrics(P):
    parts, piv = fk(P)
    ua, la, hd = parts["RightUpperArm"], parts["RightLowerArm"], parts["RightHand"]
    sp = piv["RightShoulder"]
    hc = hd[1]
    armx = max(corners_x(ua) + 0.05, corners_x(la))  # upper arm 0.05 clear; the forearm may meet the wall at the wrist
    handx = corners_x(hd)
    up = hc[1] - sp[1]
    out = hc[0] - sp[0]
    fwd = -(hc[2] - sp[2])
    clash = max(obb_penetration(parts[a], parts[b], shrink=0.08) for a in ("RightUpperArm", "RightLowerArm", "RightHand")
                for b in ("Head", "UpperTorso") if not (a == "RightUpperArm" and b == "UpperTorso"))
    return armx, handx, up, out, fwd, clash


def limits_ok(P):
    for j in ("RightShoulder", "RightElbow", "RightWrist"):
        ex = Q.swing_twist(P[j][0])
        for k in range(3):
            lo, hi = Q.LIMITS[j][k]
            if ex[k] < lo - 0.5 or ex[k] > hi + 0.5:
                return False
    return True


def touch_out(base, fwd, tw, el, wr, press=0.03):
    """abduction (`out`) at which the wall-side hand's outermost corner is `press` past the wall plane (bisection)."""
    def hx(o):
        P = dict(base)
        C.arm(P, 1, fwd, o, twist=tw, elbow=el, wrist=wr)
        return arm_metrics(P)[1] - WX - press
    lo, hi = -40.0, 165.0
    flo, fhi = hx(lo), hx(hi)
    if flo * fhi > 0:
        return None
    for _ in range(12):
        mid = (lo + hi) / 2
        fm = hx(mid)
        if (fm > 0) == (fhi > 0):
            hi, fhi = mid, fm
        else:
            lo, flo = mid, fm
    return (lo + hi) / 2


BODIES = [(ws, tilt, nk, yaw, hip) for ws in (-0.3, -0.45, -0.6) for tilt in (6.0, 10.0, 14.0) for nk in (1.6, 2.4)
          for yaw, hip in ((25.0, 15.0), (30.0, 20.0))]


def search(phi=0.3, bodies=BODIES, head_max=0.78, min_ang=0.0, max_fwd=9.0):
    best = []
    for ws, tilt, nk, yaw, hip in bodies:
        C.WALL_SHIFT, C.WALL_TILT, C.WALL_NECK, C.WALL_YAW, C.WALL_HIP_YAW = ws, tilt, nk, yaw, hip
        base = C.wall_pose(phi)
        _, piv, torso, headoff = body_metrics(base)
        if headoff > head_max or torso > WX - 0.04:
            print("body rejected", ws, tilt, nk, round(headoff, 2), round(torso - WX, 3))
            continue
        for fwd, tw, el, wr in itertools.product(range(0, 186, 15), range(-120, 121, 30), range(15, 46, 10), (-40, -20, 0, 20, 40)):
            out = touch_out(base, fwd, tw, el, wr)
            if out is None:
                continue
            P = dict(base)
            C.arm(P, 1, fwd, out, twist=tw, elbow=el, wrist=wr)
            armx, handx, up, outw, fw, clash = arm_metrics(P)
            if armx > WX + 0.0 or up < 0.9 or outw < 0.25 or clash > 0.05 or not limits_ok(P):
                continue
            ang = math.degrees(math.atan2(outw, up))  # from vertical, toward the wall
            if ang < min_ang or fw > max_fwd:
                continue
            score = abs(ang - 38) * 0.03 + abs(fw - 0.5) * 0.3 + abs(el - 25) * 0.01 + headoff * 1.5
            best.append((round(score, 3), (ws, tilt, nk, yaw, hip), (fwd, round(out, 1), tw, el, wr), round(ang, 1), round(up, 2),
                         round(fw, 2), round(armx - WX, 3), round(handx - WX, 3), round(headoff, 2),
                         round(torso - WX, 3), round(piv["RightShoulder"][0], 2)))
    best.sort()
    return best


if __name__ == "__main__":
    res = search()
    print(len(res))
    for r in res[:15]:
        print(r)
