"""Stick-figure renderer for Azeroth Fit exercise animations.

Each exercise is 4 frames (some use 3 and repeat one) of 128x128, stored side by side
in a 512x128 RLE-compressed 32-bit TGA, the same format other Forever addons ship.
The addon loops the frames with SetTexCoord.

A pose is built with forward kinematics, so limbs always keep their length:

    pose(hip=(x, y), torso=deg,
         lthigh, lshin, rthigh, rshin,      # legs
         larm, lfore, rarm, rfore,          # arms
         head=deg (optional tilt relative to torso), ground="feet"|"lowest"|None)

Coordinates: a 100x100 box, y up, floor at y = FLOOR.
Angles are absolute, in degrees:
  * limbs: 0 = straight down, +90 = pointing right (forward), -90 = pointing left, 180 = up
  * torso: 0 = straight up from the hip, +90 = lying toward the right (head to the right)
Side views face right. "l" limbs are the far side (drawn darker, behind),
"r" limbs the near side. In front views "l" is the figure's right (image left).

Planted hands and feet (recommended): give a target point instead of angles and the
knee/elbow is solved automatically (two-bone IK), so feet stay planted between frames:

    pose(hip=(40, 34), torso=35, lfoot=(52, 11), rfoot=(54, 11), knees="fwd",
         lhand=(80, 60), rhand=(82, 60), elbows="down", ground=None)

knees / elbows: which way the joint points: "fwd" (right), "back" (left), "up", "down".
Defaults: knees "fwd", elbows "down". When foot targets are given, ground is ignored.

Props are drawn behind the figure: floor, wall, chair, table, mat, step.
"""
import math
from PIL import Image, ImageDraw

FRAME = 128
SS = 4  # supersampling
FLOOR = 10

# Palette: warm gold figure, dark outline, muted props. Reads well on the dark popup.
NEAR = (238, 204, 128, 255)
FAR = (170, 136, 74, 255)
OUTLINE = (24, 16, 8, 255)
PROP = (112, 98, 80, 255)
PROP_DARK = (92, 80, 64, 255)
ACCENT = (255, 226, 150, 255)

# Segment lengths (units of the 100 box)
TORSO = 24
NECK = 4
HEAD_R = 6.5
THIGH = 19
SHIN = 19
UPPER = 13
FORE = 12

LIMB_W = 4.6
TORSO_W = 6.0
OUT_W = 2.2  # outline thickness added on each side


def _dir_limb(a):
    r = math.radians(a)
    return math.sin(r), -math.cos(r)


def _dir_torso(a):
    r = math.radians(a)
    return math.sin(r), math.cos(r)


def _ik(root, target, l1, l2, bend):
    """Two-bone IK: returns (joint, end). bend: 'fwd','back','up','down'."""
    ax, ay = root
    tx, ty = target
    dx, dy = tx - ax, ty - ay
    d = math.hypot(dx, dy)
    d = max(abs(l1 - l2) + 0.01, min(l1 + l2 - 0.01, d))
    base = math.atan2(dy, dx)
    a = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    cands = []
    for sgn in (1, -1):
        j = (ax + l1 * math.cos(base + sgn * a), ay + l1 * math.sin(base + sgn * a))
        cands.append(j)
    key = {"fwd": lambda j: j[0], "back": lambda j: -j[0], "up": lambda j: j[1], "down": lambda j: -j[1]}[bend]
    joint = max(cands, key=key)
    # end point: from joint toward target, length l2
    ex, ey = tx - joint[0], ty - joint[1]
    n = math.hypot(ex, ey) or 1
    end = (joint[0] + ex / n * l2, joint[1] + ey / n * l2)
    return joint, end


class Pose:
    def __init__(self, hip=(50, 48), torso=0, head=0,
                 lthigh=0, lshin=0, rthigh=0, rshin=0,
                 larm=0, lfore=0, rarm=0, rfore=0, ground="feet",
                 lfoot=None, rfoot=None, lhand=None, rhand=None,
                 knees="fwd", elbows="down", lknee=None, rknee=None, lelbow=None, relbow=None):
        self.p = {}
        hx, hy = hip
        tx, ty = _dir_torso(torso)
        sh = (hx + tx * TORSO, hy + ty * TORSO)
        neck = (sh[0] + tx * NECK, sh[1] + ty * NECK)
        hx2, hy2 = _dir_torso(torso + head)
        headc = (neck[0] + hx2 * HEAD_R, neck[1] + hy2 * HEAD_R)
        self.p.update(hip=(hx, hy), sh=sh, neck=neck, head=headc)
        targets = {"l": (lfoot, lknee or knees, lhand, lelbow or elbows),
                   "r": (rfoot, rknee or knees, rhand, relbow or elbows)}
        for side, th, sn in (("l", lthigh, lshin), ("r", rthigh, rshin)):
            ft, kb = targets[side][0], targets[side][1]
            if ft:
                knee, foot = _ik((hx, hy), ft, THIGH, SHIN, kb)
            else:
                kx, ky = _dir_limb(th)
                knee = (hx + kx * THIGH, hy + ky * THIGH)
                fx, fy = _dir_limb(sn)
                foot = (knee[0] + fx * SHIN, knee[1] + fy * SHIN)
            self.p[side + "knee"], self.p[side + "foot"] = knee, foot
        for side, up, fo in (("l", larm, lfore), ("r", rarm, rfore)):
            ht, eb = targets[side][2], targets[side][3]
            if ht:
                elbow, hand = _ik(sh, ht, UPPER, FORE, eb)
            else:
                ex, ey = _dir_limb(up)
                elbow = (sh[0] + ex * UPPER, sh[1] + ey * UPPER)
                wx, wy = _dir_limb(fo)
                hand = (elbow[0] + wx * FORE, elbow[1] + wy * FORE)
            self.p[side + "elbow"], self.p[side + "hand"] = elbow, hand
        if lfoot or rfoot:
            ground = None
        if ground:
            keys = ("lfoot", "rfoot") if ground == "feet" else tuple(self.p)
            low = min(self.p[k][1] - (HEAD_R if k == "head" else 0) for k in keys)
            dy = FLOOR + 1.5 - low
            self.p = {k: (v[0], v[1] + dy) for k, v in self.p.items()}

    def shift(self, dx=0, dy=0):
        self.p = {k: (v[0] + dx, v[1] + dy) for k, v in self.p.items()}
        return self


def pose(**kw):
    return Pose(**kw)


def plank_line(foot, t, **kw):
    """A body in one straight line from the feet (planks, push-ups, wall push-ups).
    foot: planted foot point, t: torso angle (90 = flat, head to the right)."""
    r = math.radians(t)
    leg = THIGH + SHIN
    hip = (foot[0] + leg * math.sin(r), foot[1] + leg * math.cos(r))
    kw.setdefault("lthigh", -t)
    kw.setdefault("lshin", -t)
    kw.setdefault("rthigh", -t)
    kw.setdefault("rshin", -t)
    kw.setdefault("ground", None)
    return Pose(hip=hip, torso=t, **kw)


# ---------------------------------------------------------------------------
# Drawing
def _xy(pt, ox):
    x, y = pt
    return ((x + ox) * FRAME / 100 * SS, (100 - y) * FRAME / 100 * SS)


def _line(d, a, b, width, color, ox):
    w = int(width * FRAME / 100 * SS)
    pa, pb = _xy(a, ox), _xy(b, ox)
    d.line([pa, pb], fill=color, width=w)
    r = w / 2
    for p in (pa, pb):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def _circle(d, c, radius, color, ox):
    x, y = _xy(c, ox)
    r = radius * FRAME / 100 * SS
    d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def _rect(d, x0, y0, x1, y1, color, ox):
    a, b = _xy((x0, y1), ox), _xy((x1, y0), ox)
    d.rectangle([a, b], fill=color)


def draw_props(d, props, ox=0):
    for prop in props:
        if isinstance(prop, str):
            prop = (prop,)
        kind = prop[0]
        if kind == "floor":
            _rect(d, 4, FLOOR - 1.6, 96, FLOOR, PROP_DARK, ox)
        elif kind == "mat":
            _rect(d, prop[1], FLOOR, prop[2], FLOOR + 1.6, PROP, ox)
        elif kind == "wall":
            x = prop[1]
            _rect(d, x, FLOOR, x + 4, 96, PROP, ox)
        elif kind == "chair":  # ("chair", x_front_of_seat, facing): facing +1 = seat extends left of x
            x, facing = prop[1], prop[2] if len(prop) > 2 else 1
            seat_y = 33
            back = x - 22 * facing
            _rect(d, min(x, back), seat_y - 2.5, max(x, back), seat_y, PROP, ox)
            _rect(d, x - 1.5 if facing > 0 else x - 1.5, FLOOR, x + 1.5, seat_y, PROP, ox)
            _rect(d, back - 1.5, FLOOR, back + 1.5, seat_y + 26, PROP, ox)
        elif kind == "table":  # ("table", x_edge, height, facing)
            x, h = prop[1], prop[2] if len(prop) > 2 else 42
            facing = prop[3] if len(prop) > 3 else 1
            far = x + 30 * facing
            _rect(d, min(x, far), h - 3, max(x, far), h, PROP, ox)
            _rect(d, x + 2 * facing - 1.5, FLOOR, x + 2 * facing + 1.5, h, PROP, ox)
            _rect(d, far - 2 * facing - 1.5, FLOOR, far - 2 * facing + 1.5, h, PROP, ox)
        elif kind == "step":
            x0, x1, h = prop[1], prop[2], prop[3]
            _rect(d, x0, FLOOR, x1, FLOOR + h, PROP, ox)


def draw_figure(d, P, ox=0, outline=True):
    p = P.p
    far = [("hip", "lknee"), ("lknee", "lfoot"), ("sh", "lelbow"), ("lelbow", "lhand")]
    near = [("hip", "rknee"), ("rknee", "rfoot"), ("sh", "relbow"), ("relbow", "rhand")]
    torso = [("hip", "sh"), ("sh", "neck")]
    # far limbs (outline + fill), then torso and head, then near limbs on top
    for group, color, w in ((far, FAR, LIMB_W), (torso, NEAR, TORSO_W), (near, NEAR, LIMB_W)):
        if outline:
            for a, b in group:
                _line(d, p[a], p[b], w + OUT_W * 2, OUTLINE, ox)
        for a, b in group:
            _line(d, p[a], p[b], w, color, ox)
        if group is torso:
            if outline:
                _circle(d, p["head"], HEAD_R + OUT_W, OUTLINE, ox)
            _circle(d, p["head"], HEAD_R, NEAR, ox)


def render(frames, props=("floor",)):
    """frames: list of Pose (3 or 4). Returns the 512x128 strip image."""
    if len(frames) == 3:
        frames = list(frames) + [frames[1]]  # ping-pong: 1 2 3 2
    assert len(frames) == 4, "need 3 or 4 frames"
    strip = Image.new("RGBA", (FRAME * 4, FRAME), (0, 0, 0, 0))
    for i, P in enumerate(frames):
        big = Image.new("RGBA", (FRAME * SS, FRAME * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        draw_props(d, props)
        draw_figure(d, P)
        small = big.resize((FRAME, FRAME), Image.LANCZOS)
        strip.paste(small, (i * FRAME, 0))
    return strip


def save_tga(img, path):
    img.save(path, format="TGA", compression="tga_rle")


def preview(img, path, bg=(14, 14, 18)):
    """Preview on the popup's dark background, 2x size, frames separated."""
    w, h = img.size
    out = Image.new("RGB", (w * 2 + 3 * 6, h * 2), bg)
    for i in range(4):
        fr = img.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME)).resize((FRAME * 2, FRAME * 2), Image.NEAREST)
        out.paste(fr, (i * (FRAME * 2 + 6), 0), fr)
    out.save(path)
