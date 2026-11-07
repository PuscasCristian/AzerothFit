"""Fork A poses: push, legs, swap alternatives and lower-body stretches.

Each entry: id -> (frames, props). Side views face right unless noted.
"""
import math

from figure import pose, plank_line, THIGH, SHIN, TORSO

EXERCISES = {}


# ---------------------------------------------------------------------------
# Helpers
def hips_on(hip):
    """Hand targets resting on the hips (side view)."""
    return dict(lhand=(hip[0] + 2, hip[1] + 3), rhand=(hip[0] + 4, hip[1] + 3), elbows="back")


def lying_torso(hip, shoulder_y):
    """Torso angle for a body lying on its back, head to the left, shoulders resting
    at shoulder_y, with the hip at `hip` (used by the glute bridge)."""
    c = max(-1.0, min(1.0, (shoulder_y - hip[1]) / TORSO))
    return -math.degrees(math.acos(c))


def thigh_to(hip, knee):
    """Absolute limb angle from hip to a knee point."""
    return math.degrees(math.atan2(knee[0] - hip[0], -(knee[1] - hip[1])))


def kneel_hip(knee, dx):
    """Hip directly above-and-forward of a knee on the floor, dx units in front of it."""
    return (knee[0] + dx, knee[1] + math.sqrt(THIGH * THIGH - dx * dx))


# ---------------------------------------------------------------------------
# Legs
F = dict(lfoot=(50, 11), rfoot=(52, 11))
EXERCISES["squat"] = ([
    pose(hip=(50, 49), torso=3, **F, larm=10, lfore=10, rarm=6, rfore=6),
    pose(hip=(44, 40), torso=22, **F, larm=70, lfore=80, rarm=72, rfore=82),
    pose(hip=(38, 31), torso=38, **F, larm=88, lfore=90, rarm=90, rfore=92),
], ("floor",))

# Sit-to-stand: from sitting on the chair to standing tall, arms forward for balance.
F = dict(lfoot=(58, 11), rfoot=(60, 11))
EXERCISES["sit_to_stand"] = ([
    pose(hip=(40, 36), torso=8, **F, larm=60, lfore=75, rarm=62, rfore=78),
    pose(hip=(47, 40), torso=38, **F, larm=85, lfore=88, rarm=88, rfore=90),
    pose(hip=(57, 48.5), torso=3, **F, larm=8, lfore=8, rarm=5, rfore=5),
], ("floor", ("chair", 50, 1)))

# Chair squat: hips back until they just touch the seat, then stand. Never sit down.
F = dict(lfoot=(56, 11), rfoot=(58, 11))
EXERCISES["chair_squat"] = ([
    pose(hip=(55, 49), torso=3, **F, larm=70, lfore=80, rarm=72, rfore=82),
    pose(hip=(48, 42), torso=20, **F, larm=82, lfore=86, rarm=84, rfore=88),
    pose(hip=(41, 37), torso=34, **F, larm=90, lfore=92, rarm=92, rfore=94),
], ("floor", ("chair", 44, 1)))

# Reverse lunge: step the near foot back and lower the back knee toward the floor.
def _lunge(hip, back_foot, back_bend="down"):
    return pose(hip=hip, torso=2, lfoot=(60, 11), rfoot=back_foot, lknee="fwd", rknee=back_bend,
                **hips_on(hip))


EXERCISES["reverse_lunge"] = ([
    pose(hip=(58, 49), torso=2, lfoot=(60, 11), rfoot=(56, 11), **hips_on((58, 49))),
    _lunge((52, 41), (36, 12)),
    _lunge((49, 33), (26, 12)),
], ("floor",))

# Glute bridge: lying on the back, knees up, feet planted; lift the hips.
def _bridge(hip_y):
    hip_x = 52
    t = lying_torso((hip_x, hip_y), 15)
    sh_x = hip_x + TORSO * math.sin(math.radians(t))
    hip = (hip_x + (30 - sh_x), hip_y)  # keep the shoulders at x = 30
    t = lying_torso(hip, 15)
    return pose(hip=hip, torso=t, head=-45 - t, lfoot=(70, 11), rfoot=(72, 11), knees="up",
                larm=90, lfore=90, rarm=92, rfore=92, ground=None)


EXERCISES["glute_bridge"] = ([_bridge(15), _bridge(22), _bridge(29)], ("floor", ("mat", 14, 86)))

# Calf raise: rise onto the toes holding a chair back for balance.
def _calf(up):
    hip = (46, 49 + up)
    return pose(hip=hip, torso=0, lfoot=(45, 11 + up), rfoot=(47, 11 + up),
                lhand=(66, 60), rhand=(66, 60), elbows="down")


EXERCISES["calf_raise"] = ([_calf(0), _calf(2.5), _calf(5)], ("floor", ("chair", 44, -1)))

# Side leg raise (front view): stand tall, hands on hips, lift one leg out to the side.
def _side_leg(angle, lean):
    hip = (50, 49)
    return pose(hip=hip, torso=-lean, lfoot=(44, 11), lknee="back",
                rthigh=6 + angle, rshin=6 + angle,
                lhand=(45, 52), rhand=(55, 52), lelbow="back", relbow="fwd", ground=None)


EXERCISES["side_leg_raise"] = ([_side_leg(0, 0), _side_leg(18, 3), _side_leg(36, 6)], ("floor",))

# ---------------------------------------------------------------------------
# Push
# Wall push-ups: body one straight line, hands planted on the wall.
H = dict(lhand=(77, 62), rhand=(77, 60), elbows="down")
EXERCISES["wall_pushup"] = ([
    plank_line((26, 11), 26, **H),
    plank_line((26, 11), 30, **H),
    plank_line((26, 11), 34, **H),
], ("floor", ("wall", 78)))

# Counter push-ups: hands on a table edge, body straight, lower the chest to the edge.
H = dict(lhand=(71, 43.5), rhand=(72, 43.5), elbows="down")
EXERCISES["counter_pushup"] = ([
    plank_line((10, 11), 45, **H),
    plank_line((10, 11), 50, **H),
    plank_line((10, 11), 56, **H),
], ("floor", ("table", 70, 42, 1)))


# Knee push-ups: knees on the floor, body straight from knees to head.
def _knee_push(t):
    knee = (26, 12.5)
    r = math.radians(t)
    hip = (knee[0] + THIGH * math.sin(r), knee[1] + THIGH * math.cos(r))
    return pose(hip=hip, torso=t, lthigh=-t, rthigh=-t, lshin=-100, rshin=-100,
                lhand=(63, 11), rhand=(65, 11), elbows="up", ground=None)


EXERCISES["knee_pushup"] = ([_knee_push(58), _knee_push(68), _knee_push(78)], ("floor",))

# Push-ups: full plank on the toes.
H = dict(lhand=(70, 11), rhand=(72, 11), elbows="up")
EXERCISES["pushup"] = ([
    plank_line((12, 12), 67, **H),
    plank_line((12, 12), 74, **H),
    plank_line((12, 12), 81, **H),
], ("floor",))


# Arm circles (front view): arms straight out to the sides, small circles shown as
# the arms sweeping a little up and down.
def _circles(a, bend):
    return pose(hip=(50, 49), torso=0, lfoot=(45, 11), rfoot=(55, 11), lknee="back", rknee="fwd",
                larm=-a, lfore=-(a + bend), rarm=a, rfore=a + bend)


EXERCISES["arm_circles"] = ([
    _circles(84, 4), _circles(96, 6), _circles(106, 4), _circles(96, -4),
], ("floor",))

# ---------------------------------------------------------------------------
# Core alternatives
# Bird dog: on hands and knees, reach the near arm forward and the far leg back.
# The head looks down at the floor so the reaching arm passes clearly above it.
def _bird(f):
    hip = (36, 31.5)
    arm = {0: 0, 0.5: 60, 1: 106}[f]
    leg = {0: 0, 0.5: -62, 1: -90}[f]
    return pose(hip=hip, torso=90, head=45, lthigh=leg, lshin=leg if f > 0 else -95,
                rthigh=0, rshin=-95, larm=0, lfore=0, rarm=arm, rfore=arm, ground=None)


EXERCISES["bird_dog"] = ([_bird(0), _bird(0.5), _bird(1)], ("floor", ("mat", 14, 86)))


# Side bend (front view): one hand on the hip, the other arm over the head, lean sideways.
def _side_bend(lean, arm, fore):
    hip = (50, 49)
    return pose(hip=hip, torso=-lean, lfoot=(44, 11), rfoot=(56, 11), lknee="back", rknee="fwd",
                lhand=(45, 52), lelbow="back", rarm=arm, rfore=fore)


EXERCISES["side_bend"] = ([
    _side_bend(0, 155, 180), _side_bend(12, 167, -148), _side_bend(24, 179, -130),
], ("floor",))

# ---------------------------------------------------------------------------
# Stretches (calm: start, stretch, deeper)
# Hip flexor stretch: half-kneeling, back knee down, press the hips forward.
def _hipflex(dx, lean, arms_up=False):
    knee = (36, 12.5)
    hip = kneel_hip(knee, dx)
    kw = dict(rarm=-160, rfore=-165, larm=-162, lfore=-168) if arms_up else hips_on(hip)
    return pose(hip=hip, torso=-lean, lfoot=(66, 11), lknee="fwd",
                rthigh=thigh_to(hip, knee), rshin=-96, ground=None, **kw)


EXERCISES["hip_flexor_stretch"] = ([
    _hipflex(5, 0), _hipflex(9, 3), _hipflex(12, 6, arms_up=True),
], ("floor", ("mat", 14, 86)))


# Hamstring reach: sit on the front of a chair, near leg straight out, heel down, reach for the toes.
def _ham(t, hand):
    hip = (40, 36)
    return pose(hip=hip, torso=t, lfoot=(54, 11), lknee="fwd", rfoot=(73, 12), rknee="up",
                lhand=hand, rhand=(hand[0] + 1, hand[1] - 1), elbows="down", ground=None)


EXERCISES["hamstring_reach"] = ([
    _ham(6, (52, 38)), _ham(30, (62, 30)), _ham(50, (70, 20)),
], ("floor", ("chair", 46, 1)))


# Calf stretch: hands on the wall, front knee bent, back leg straight with the heel down.
def _calf_stretch(hip, t):
    return pose(hip=hip, torso=t, lfoot=(60, 11), lknee="fwd", rfoot=(28, 11), rknee="fwd",
                lhand=(77, 64), rhand=(77, 62), elbows="down", ground=None)


EXERCISES["calf_stretch"] = ([
    _calf_stretch((46, 45), 22), _calf_stretch((49, 44), 26), _calf_stretch((51.5, 43), 30),
], ("floor", ("wall", 78)))
