# Core Round Step 1E: canonical R15 authoring rig, math helpers and forward kinematics (pure Python, no bpy).
#
# Rig source: the live Step 1D/1E character measured in Studio on 2026-11-21 (owner avatar, R15, AnimationConstraint
# joints; the two-client test avatars give the same posed slide head 0.19). All joint attachments are axis-aligned, so a
# joint's Roblox Transform is a rotation (plus, for Root, a translation) in the parent part's frame.
#
# Coordinate convention: ROBLOX character space (Y up, character faces -Z, right = +X), origin = HumanoidRootPart centre.
# Rotations are CFrame.Angles(rx, ry, rz) in degrees = Rx * Ry * Rz (same as the game code). Measured sign conventions:
#   shoulder / hip +X = limb forward; knee -X = bend; elbow +X = forearm forward (flexion); right limb +Z = out to the
#   right, left limb -Z = out to the left; Root +X = lean back, +Z = tilt to the character's left; Waist +Y = right
#   shoulder forward. (Re-measured in Studio 2026-11-21 by setting single joint Transforms on the live avatar and reading
#   part positions; they follow standard right-handed math. The older Step 1C comment "-Z swings the right arm out" was
#   wrong: RightShoulder Angles(0,0,-60deg) moved the right hand 1.86 studs toward the body centre.)
import math

# joint name -> (parent part, child part, pivot position in character space at rest)
# pivots derived from the measured attachments (Attachment0 world position at rest)
JOINTS = {
    "Root": ("HumanoidRootPart", "LowerTorso", (0.0, -0.900, 0.0)),
    "Waist": ("LowerTorso", "UpperTorso", (0.0, -0.462, 0.0)),
    "Neck": ("UpperTorso", "Head", (0.0, 1.378, 0.0)),
    "RightShoulder": ("UpperTorso", "RightUpperArm", (0.845, 1.105, 0.0)),
    "LeftShoulder": ("UpperTorso", "LeftUpperArm", (-0.845, 1.105, 0.0)),
    "RightElbow": ("RightUpperArm", "RightLowerArm", (1.309, 0.252, 0.0)),
    "LeftElbow": ("LeftUpperArm", "LeftLowerArm", (-1.309, 0.252, 0.0)),
    "RightWrist": ("RightLowerArm", "RightHand", (1.309, -0.638, 0.0)),
    "LeftWrist": ("LeftLowerArm", "LeftHand", (-1.309, -0.638, 0.0)),
    "RightHip": ("LowerTorso", "RightUpperLeg", (0.433, -0.900, 0.0)),
    "LeftHip": ("LowerTorso", "LeftUpperLeg", (-0.433, -0.900, 0.0)),
    "RightKnee": ("RightUpperLeg", "RightLowerLeg", (0.433, -1.990, 0.0)),
    "LeftKnee": ("LeftUpperLeg", "LeftLowerLeg", (-0.433, -1.990, 0.0)),
    "RightAnkle": ("RightLowerLeg", "RightFoot", (0.433, -3.194, 0.0)),
    "LeftAnkle": ("LeftLowerLeg", "LeftFoot", (-0.433, -3.194, 0.0)),
}
JOINT_ORDER = ["Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow",
               "LeftWrist", "RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle"]

# part -> (size, centre at rest in character space)  (measured)
PARTS = {
    "LowerTorso": ((1.73, 0.44, 1.01), (0.0, -0.681, 0.0)),
    "UpperTorso": ((1.69, 1.84, 1.01), (0.0, 0.458, 0.0)),
    "Head": ((1.06, 1.07, 1.06), (0.0, 1.825, 0.0)),
    "RightUpperArm": ((0.93, 1.37, 1.01), (1.309, 0.643, 0.0)),
    "LeftUpperArm": ((0.93, 1.37, 1.01), (-1.309, 0.643, 0.0)),
    "RightLowerArm": ((0.93, 1.23, 1.01), (1.309, -0.051, 0.0)),
    "LeftLowerArm": ((0.93, 1.23, 1.01), (-1.309, -0.051, 0.0)),
    "RightHand": ((0.88, 0.32, 1.09), (1.309, -0.770, 0.0)),
    "LeftHand": ((0.88, 0.32, 1.09), (-1.309, -0.770, 0.0)),
    "RightUpperLeg": ((0.86, 1.61, 0.91), (0.433, -1.458, 0.0)),
    "LeftUpperLeg": ((0.86, 1.61, 0.91), (-0.433, -1.458, 0.0)),
    "RightLowerLeg": ((0.86, 1.55, 0.91), (0.433, -2.483, 0.0)),
    "LeftLowerLeg": ((0.86, 1.55, 0.91), (-0.433, -2.483, 0.0)),
    "RightFoot": ((0.90, 0.33, 1.00), (0.433, -3.307, 0.0)),
    "LeftFoot": ((0.90, 0.33, 1.00), (-0.433, -3.307, 0.0)),
}
PART_JOINT = {child: j for j, (_, child, _) in JOINTS.items()}  # part -> joint that drives it
GROUND_Y = -3.472  # sole of the foot at rest (HumanoidRootPart centre is 3.47 above the floor)
HIP_TO_KNEE = 1.090
KNEE_TO_ANKLE = 1.204
ANKLE_TO_SOLE = 0.278

# ---------------------------------------------------------------- quaternion / matrix helpers (w, x, y, z)
def qmul(a, b):
    aw, ax, ay, az = a
    bw, bx, by, bz = b
    return (aw * bw - ax * bx - ay * by - az * bz,
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw)

def qaxis(axis, deg):
    h = math.radians(deg) / 2
    s = math.sin(h)
    return (math.cos(h), axis[0] * s, axis[1] * s, axis[2] * s)

def euler(rx, ry, rz):
    # CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz
    return qmul(qmul(qaxis((1, 0, 0), rx), qaxis((0, 1, 0), ry)), qaxis((0, 0, 1), rz))

def qnorm(q):
    n = math.sqrt(sum(c * c for c in q)) or 1.0
    return tuple(c / n for c in q)

def qslerp(a, b, t):
    dot = sum(x * y for x, y in zip(a, b))
    if dot < 0:
        b = tuple(-c for c in b)
        dot = -dot
    if dot > 0.9995:
        return qnorm(tuple(x + (y - x) * t for x, y in zip(a, b)))
    th = math.acos(min(1.0, dot))
    s = math.sin(th)
    wa, wb = math.sin((1 - t) * th) / s, math.sin(t * th) / s
    return tuple(wa * x + wb * y for x, y in zip(a, b))

def qrot(q, v):
    w, x, y, z = q
    p = (0.0, v[0], v[1], v[2])
    r = qmul(qmul(q, p), (w, -x, -y, -z))
    return (r[1], r[2], r[3])

def qangle(a, b):
    dot = abs(sum(x * y for x, y in zip(a, b)))
    return math.degrees(2 * math.acos(min(1.0, dot)))

def vadd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])

def vsub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])

def vlen(a):
    return math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2)

def lerp(a, b, t):
    return a + (b - a) * t

def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- forward kinematics
# pose: joint -> (quat, translation)  (translation only meaningful for Root)
def fk(pose):
    """returns part -> (world rotation quat, world centre) and joint -> world pivot"""
    rot = {"HumanoidRootPart": (1.0, 0.0, 0.0, 0.0)}
    origin = {"HumanoidRootPart": (0.0, 0.0, 0.0)}  # world position of each part's frame origin (rest-aligned)
    parts, pivots = {}, {}
    for j in JOINT_ORDER:
        parent, child, piv = JOINTS[j]
        q, tr = pose.get(j, ((1.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
        # pivot of this joint in world = parent frame transform of the rest pivot
        prest = JOINTS[PART_JOINT[parent]][2] if parent != "HumanoidRootPart" else (0.0, 0.0, 0.0)
        local_piv = vsub(piv, prest)
        wpiv = vadd(origin[parent], qrot(rot[parent], local_piv))
        wpiv = vadd(wpiv, qrot(rot[parent], tr))
        wrot = qmul(rot[parent], q)
        rot[child] = wrot
        origin[child] = wpiv
        pivots[j] = wpiv
    for part, (size, centre) in PARTS.items():
        j = PART_JOINT[part]
        local = vsub(centre, JOINTS[j][2])
        parts[part] = (rot[part], vadd(origin[part], qrot(rot[part], local)), size)
    return parts, pivots

# ---------------------------------------------------------------- oriented-box overlap (separating axis test)
def _axes(q):
    return [qrot(q, (1, 0, 0)), qrot(q, (0, 1, 0)), qrot(q, (0, 0, 1))]

def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])

def obb_penetration(a, b, shrink=0.0):
    """smallest overlap depth along the separating axes (<= 0: separated). shrink trims each half-size."""
    qa, ca, sa = a
    qb, cb, sb = b
    ha = [max(0.0, s / 2 - shrink) for s in sa]
    hb = [max(0.0, s / 2 - shrink) for s in sb]
    A, B = _axes(qa), _axes(qb)
    d = vsub(cb, ca)
    best = 1e9
    cands = A + B + [_cross(x, y) for x in A for y in B]
    for ax in cands:
        n = vlen(ax)
        if n < 1e-6:
            continue
        ax = (ax[0] / n, ax[1] / n, ax[2] / n)
        ra = sum(ha[i] * abs(_dot(A[i], ax)) for i in range(3))
        rb = sum(hb[i] * abs(_dot(B[i], ax)) for i in range(3))
        ov = ra + rb - abs(_dot(d, ax))
        if ov < best:
            best = ov
        if best <= 0:
            return best
    return best

# ---------------------------------------------------------------- 2-bone leg IK in the sagittal plane
def leg_ik(target_ankle, hip_pivot, root_pitch_deg, foot_pitch_deg=0.0):
    """angles (hipX, kneeX, ankleX) in degrees placing the ankle at target (character space).
    root_pitch_deg: the LowerTorso's X rotation (lean), which the hip angle is measured against."""
    dy = target_ankle[1] - hip_pivot[1]
    dz = target_ankle[2] - hip_pivot[2]
    d = math.sqrt(dy * dy + dz * dz)
    L1, L2 = HIP_TO_KNEE, KNEE_TO_ANKLE
    d = max(abs(L1 - L2) + 1e-3, min(L1 + L2 - 1e-3, d))
    # world angle of the hip->ankle line, measured from straight down toward forward (-Z)
    a = math.atan2(-dz, -dy)
    beta = math.acos(max(-1, min(1, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))))
    k = math.acos(max(-1, min(1, (L1 * L1 + L2 * L2 - d * d) / (2 * L1 * L2))))
    flex = math.pi - k
    thigh_world = math.degrees(a + beta)
    knee = -math.degrees(flex)
    # world rotation about X of the thigh = root pitch + hip (positive hip = forward = negative world-X rotation sense)
    # in this rig +X rotation moves a hanging limb forward, and +Root X leans the pelvis back (same rotation sense),
    # so world limb angle = rootX + hipX.
    hip = thigh_world - root_pitch_deg
    ankle = foot_pitch_deg - (thigh_world + knee)
    return hip, knee, ankle
