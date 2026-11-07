"""Core, cardio and stretch animations (art fork B). id -> (frames, props)."""
import math

from figure import pose, plank_line, TORSO, THIGH, SHIN, UPPER, FORE

EXERCISES = {}

LEG = THIGH + SHIN
FOOT_Y = 11
FLOOR_LIMB = 12.5  # a limb lying on the floor


def sh_of(hip, t):
    r = math.radians(t)
    return (hip[0] + TORSO * math.sin(r), hip[1] + TORSO * math.cos(r))


def front_hip(x, lfx, rfx, bend=0.0):
    """Hip point for a front view with feet planted at x lfx / rfx.
    bend > 0 lowers the hip so the knees soften."""
    dx = max(abs(lfx - x), abs(rfx - x))
    h = math.sqrt(max(1.0, (LEG - 0.2) ** 2 - dx * dx)) - bend
    return (x, FOOT_Y + h)


def front(x, lfx, rfx, bend=0.0, **kw):
    """Front-view standing pose with planted feet; knees bend outward."""
    hip = front_hip(x, lfx, rfx, bend)
    kw.setdefault("lknee", "back")
    kw.setdefault("rknee", "fwd")
    return pose(hip=hip, torso=kw.pop("torso", 0), lfoot=(lfx, FOOT_Y), rfoot=(rfx, FOOT_Y), **kw)


# ---------------------------------------------------------------------------
# Core

# Standing knee raises: alternate knees to hip height, hands relaxed forward.
EXERCISES["knee_raise"] = ([
    pose(hip=(48, 49), torso=0, lthigh=0, lshin=0, rthigh=92, rshin=2, larm=-15, lfore=-5, rarm=20, rfore=60),
    pose(hip=(48, 49), torso=0, lthigh=2, lshin=2, rthigh=-2, rshin=-2, larm=5, lfore=10, rarm=8, rfore=15),
    pose(hip=(48, 49), torso=0, lthigh=92, lshin=2, rthigh=0, rshin=0, larm=20, lfore=60, rarm=-15, rfore=-5),
    pose(hip=(48, 49), torso=0, lthigh=2, lshin=2, rthigh=-2, rshin=-2, larm=5, lfore=10, rarm=8, rfore=15),
], ("floor",))

# Dead bug: on the back (head right), arms up, knees bent 90. Lower opposite arm and leg.
DB = dict(hip=(38, 14.5), torso=90, head=-22, ground=None)
EXERCISES["dead_bug"] = ([
    pose(**DB, lthigh=180, lshin=-90, rthigh=180, rshin=-90, larm=180, lfore=180, rarm=180, rfore=180),
    pose(**DB, lthigh=180, lshin=-90, rthigh=-80, rshin=-88, larm=140, lfore=140, rarm=180, rfore=180),
    pose(**DB, lthigh=180, lshin=-90, rthigh=180, rshin=-90, larm=180, lfore=180, rarm=180, rfore=180),
    pose(**DB, lthigh=-80, lshin=-88, rthigh=180, rshin=-90, larm=180, lfore=180, rarm=140, rfore=140),
], ("floor",))


def forearm_arms(shoulder, ahead=12):
    """Forearms flat on the floor, elbow under the shoulder."""
    dy = shoulder[1] - FLOOR_LIMB
    c = max(-1.0, min(1.0, dy / UPPER))
    a = -math.degrees(math.acos(c))  # elbow slightly back if the shoulder is low
    return dict(larm=a, lfore=90, rarm=a, rfore=90)


def knee_plank(t, knee=(26, FLOOR_LIMB)):
    r = math.radians(t)
    hip = (knee[0] + THIGH * math.sin(r), knee[1] + THIGH * math.cos(r))
    s = sh_of(hip, t)
    return pose(hip=hip, torso=t, ground=None, lthigh=-t, rthigh=-t, lshin=-90, rshin=-90,
                **forearm_arms(s))


# Knee plank: hold, with a gentle breathing pulse.
EXERCISES["knee_plank"] = ([knee_plank(72), knee_plank(69.5), knee_plank(72)], ("floor",))


def forearm_plank(t, foot=(12, FOOT_Y + 0.5)):
    r = math.radians(t)
    s = (foot[0] + (LEG + TORSO) * math.sin(r), foot[1] + (LEG + TORSO) * math.cos(r))
    return plank_line(foot, t, **forearm_arms(s))


EXERCISES["plank"] = ([forearm_plank(77), forearm_plank(75), forearm_plank(77)], ("floor",))

# ---------------------------------------------------------------------------
# Cardio

# March in place: knee up with the opposite arm forward.
EXERCISES["march"] = ([
    pose(hip=(48, 49), lthigh=-2, lshin=-2, rthigh=55, rshin=-8, larm=40, lfore=75, rarm=-30, rfore=-15),
    pose(hip=(48, 49), lthigh=1, lshin=1, rthigh=-1, rshin=-1, larm=5, lfore=20, rarm=5, rfore=20),
    pose(hip=(48, 49), lthigh=55, lshin=-8, rthigh=-2, rshin=-2, larm=-30, lfore=-15, rarm=40, rfore=75),
    pose(hip=(48, 49), lthigh=1, lshin=1, rthigh=-1, rshin=-1, larm=5, lfore=20, rarm=5, rfore=20),
], ("floor",))

# High-knee march: knees to hip height, big bent-arm swings.
EXERCISES["high_knee_march"] = ([
    pose(hip=(48, 49), lthigh=-4, lshin=-4, rthigh=95, rshin=0, larm=70, lfore=150, rarm=-45, rfore=-10),
    pose(hip=(48, 49), lthigh=1, lshin=1, rthigh=-1, rshin=-1, larm=10, lfore=60, rarm=10, rfore=60),
    pose(hip=(48, 49), lthigh=95, lshin=0, rthigh=-4, rshin=-4, larm=-45, lfore=-10, rarm=70, rfore=150),
    pose(hip=(48, 49), lthigh=1, lshin=1, rthigh=-1, rshin=-1, larm=10, lfore=60, rarm=10, rfore=60),
], ("floor",))

# Step jacks (front view): step one foot out while both arms rise overhead, alternate.
ARMS_DOWN = dict(larm=-30, lfore=-18, rarm=30, rfore=18)
ARMS_UP = dict(larm=-122, lfore=-148, rarm=122, rfore=148)
EXERCISES["step_jack"] = ([
    front(50, 45, 55, **ARMS_DOWN),
    front(54, 45, 66, **ARMS_UP),
    front(50, 45, 55, **ARMS_DOWN),
    front(46, 34, 55, **ARMS_UP),
], ("floor",))

# Jumping jacks (front view): together, hop, apart with arms overhead, hop.
def hop(lift=4, spread=6, arms=(-95, -100)):
    p = pose(hip=(50, 49), lthigh=-spread, lshin=-spread, rthigh=spread, rshin=spread,
             larm=arms[0], lfore=arms[1], rarm=-arms[0], rfore=-arms[1])
    return p.shift(0, lift)


EXERCISES["jumping_jack"] = ([
    pose(hip=(50, 49), lthigh=-5, lshin=-5, rthigh=5, rshin=5, **ARMS_DOWN),
    hop(),
    pose(hip=(50, 49), lthigh=-19, lshin=-19, rthigh=19, rshin=19, **ARMS_UP),
    hop(),
], ("floor",))

# Burpee: stand, crouch with hands down, jump back to a plank, crouch again.
CROUCH_F = dict(lfoot=(48, FOOT_Y), rfoot=(50, FOOT_Y), knees="fwd")
crouch = pose(hip=(42, 27), torso=62, **CROUCH_F, lhand=(64, FLOOR_LIMB), rhand=(66, FLOOR_LIMB), elbows="back")
high_plank = plank_line((10, FOOT_Y + 0.5), 65.5, lhand=(64, FLOOR_LIMB), rhand=(66, FLOOR_LIMB), elbows="back")
EXERCISES["burpee"] = ([
    pose(hip=(49, 49), torso=0, lthigh=1, lshin=1, rthigh=-1, rshin=-1, larm=122, lfore=118, rarm=118, rfore=114),
    crouch,
    high_plank,
    crouch,
], ("floor",))


# Shadow boxing (side view, facing right): jab, guard, cross, guard.
def boxer(lead_punch=False, rear_punch=False):
    hip = (44, 47)
    t = 6 if rear_punch else 2
    s = sh_of(hip, t)
    guard_l = (s[0] + 9, s[1] + 5)
    guard_r = (s[0] + 6, s[1] + 3)
    kw = dict(hip=hip, torso=t, lfoot=(54, FOOT_Y), rfoot=(36, FOOT_Y), knees="fwd")
    kw["lhand"] = (s[0] + 24, s[1] + 1) if lead_punch else guard_l
    kw["rhand"] = (s[0] + 24, s[1] + 0) if rear_punch else guard_r
    kw["elbows"] = "down"
    return pose(**kw)


EXERCISES["shadow_boxing"] = ([boxer(lead_punch=True), boxer(), boxer(rear_punch=True), boxer()], ("floor",))

# Step-touch (front view): step out, bring the other foot in, swing the arms that way.
EXERCISES["step_touch"] = ([
    front(42, 38, 46, bend=1.5, larm=-10, lfore=-8, rarm=10, rfore=8),
    front(50, 38, 62, bend=3, larm=30, lfore=55, rarm=40, rfore=70),
    front(58, 54, 62, bend=1.5, larm=-10, lfore=-8, rarm=10, rfore=8),
    front(50, 38, 62, bend=3, larm=-40, lfore=-70, rarm=-30, rfore=-55),
], ("floor",))

# ---------------------------------------------------------------------------
# Stretches (calmer)

# Neck tilts (front view): ear toward one shoulder, center, the other side.
STAND_FRONT = dict(lthigh=-6, lshin=-6, rthigh=6, rshin=6, larm=-26, lfore=-14, rarm=26, rfore=14)


def tilt(h):
    return pose(hip=(50, 49), head=h, **STAND_FRONT)


EXERCISES["neck_tilt"] = ([tilt(0), tilt(55), tilt(0), tilt(-55)], ("floor",))


# Shoulder rolls (side view): fingertips on shoulders, elbows draw big circles.
def roll(a):
    """Fingertips on the shoulders; the elbow sits at angle a on its circle."""
    return pose(hip=(48, 49), lthigh=1, lshin=1, rthigh=-1, rshin=-1,
                larm=a, lfore=a + 180, rarm=a, rfore=a + 180)


EXERCISES["shoulder_roll"] = ([roll(70), roll(125), roll(-125), roll(-60)], ("floor",))

# Chest opener (side view): hands clasped behind the back, arms lift, chest up.
STAND_SIDE = dict(lthigh=1, lshin=1, rthigh=-1, rshin=-1)
EXERCISES["chest_opener"] = ([
    pose(hip=(50, 49), torso=0, **STAND_SIDE, larm=-8, lfore=-12, rarm=-8, rfore=-12),
    pose(hip=(50, 49), torso=-4, head=-8, **STAND_SIDE, larm=-32, lfore=-32, rarm=-30, rfore=-30),
    pose(hip=(50, 49), torso=-10, head=-22, **STAND_SIDE, larm=-58, lfore=-58, rarm=-55, rfore=-55),
], ("floor",))


# Wrist stretch (side view): near arm straight forward, far hand pulls the fingers back.
def wrist(stage):
    """Far arm straight forward; the near hand comes up underneath and pulls the fingers back.
    The near arm is placed by hand (both shoulders share one point in a side view)."""
    hip = (38, 49)
    fore = (90, 90, 112)[stage]
    p = pose(hip=hip, torso=0, **STAND_SIDE, larm=90, lfore=fore, rarm=8, rfore=12)
    if stage == 0:
        return p
    s = p.p["sh"]
    tip = p.p["lhand"]
    p.p["relbow"] = (s[0] + 9, s[1] - 10)
    p.p["rhand"] = (tip[0] + 0.5, tip[1] + (1.0 if stage == 1 else 2.5))
    return p


EXERCISES["wrist_stretch"] = ([wrist(0), wrist(1), wrist(2)], ("floor",))

# Upper back stretch (side view): reach forward, round the back, head drops.
UB_F = dict(lfoot=(50, FOOT_Y), rfoot=(52, FOOT_Y), knees="fwd")
EXERCISES["upper_back_stretch"] = ([
    pose(hip=(51, 48.5), torso=0, head=0, **UB_F, larm=88, lfore=90, rarm=90, rfore=92),
    pose(hip=(46, 47), torso=16, head=32, **UB_F, larm=92, lfore=96, rarm=94, rfore=98),
    pose(hip=(42, 45.5), torso=28, head=50, **UB_F, larm=92, lfore=98, rarm=94, rfore=100),
], ("floor",))
