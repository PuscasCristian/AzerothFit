"""Reference poses. Each entry: id -> (frames, props). Copy this style."""
from figure import pose, plank_line

EXERCISES = {}

# Squats: feet planted at x=52; hips go back and down, knees forward, arms reach forward.
F = dict(lfoot=(50, 11), rfoot=(52, 11))
EXERCISES["squat"] = ([
    pose(hip=(50, 49), torso=3, **F, larm=10, lfore=10, rarm=6, rfore=6),
    pose(hip=(44, 40), torso=22, **F, larm=70, lfore=80, rarm=72, rfore=82),
    pose(hip=(38, 31), torso=38, **F, larm=88, lfore=90, rarm=90, rfore=92),
], ("floor",))

# Wall push-ups: body stays one straight line (plank_line), hands planted on the wall.
H = dict(lhand=(77, 62), rhand=(77, 60), elbows="down")
EXERCISES["wall_pushup"] = ([
    plank_line((31, 11), 22, **H),
    plank_line((31, 11), 30, **H),
    plank_line((31, 11), 38, **H),
], ("floor", ("wall", 78)))
