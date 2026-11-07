# Azeroth Fit roadmap

Decisions and ideas from the owner's play-testing. Newest first within each section.

## Done

### v0.2.0 (2026-11-07)
- Looping 4-frame animations for all 33 exercises (stick figure, gold on dark), shown in the popup.
- **Swap** button: a kinder exercise for the same muscles (knees, wrists, back), or another stretch.
- **Quiet mode** (no jumping): jumping jacks and burpees become step jacks.
- **Pause for today** and quiet mode in the minimap right-click menu.
- **Stretching** category (8 stretches): in the snack rotation for Peon and Grunt, a cooldown after
  their level-up workouts, stretch breaks on demand, and the only thing nudges offer once goals are done.
- **Weekly goal** in training days (a day with 3+ sets), default 3. Reward toast + XP once a week.
- **Daily limit in sets** instead of minutes (people take different times for the same sets).
  Stretches don't use it up.
- **Gentle start**: 70% -> 100% over the first 14 days, again after 10+ days off.
- Lighter defaults: Soldier level-ups 2 rounds, quest snacks 15 minutes apart.
- Two "Too hard" in a row offers an easier exercise.
- First set right after setup.
- Text and window size setting (80-150%).
- Main window: Profile, Exercises, **Pacing**, **Options**, **Buddies** (no ranks).

### v0.1.x (2026-11-07)
- Quest snacks, level-up workouts, Trials every 10 levels, death sets (off by default).
- Tiers Peon -> Hero, exercise ladders, max-based reps, feedback tuning, 10%/week growth limit.
- Fitness level 1-60, titles, rested XP for days off.
- Account-wide stats with per-character breakdown; alts count as one person for others.
- Stats sharing, tooltips, /flex (private by default).
- 5-minute break after any workout; campfire nudge; stand-up reminder; save level-ups for campfires.

## Next (agreed with the owner)

1. **Progress you can see:** 14-day bar chart on Profile; a Monday summary ("Last week: 3 days,
   41 minutes, push-ups +12%"); milestone toasts (first 100 push-ups, first rung up, first full week).
2. **Group workouts:** when someone in your party with the addon dings, everyone gets a set.
   Fun, not competitive.
3. **Equipment and custom exercises:** checkboxes in setup (dumbbells, kettlebell, bands, pull-up
   bar, step, walking pad). Each adds exercises to the ladders and a "Pull" category. Walking-pad
   mode counts walking time as cardio. A small editor for your own exercises.
4. **Translations:** German, French, Spanish first.

Dropped: weekly guild leaderboard (the owner: rankings would be lies).

## Before publishing on CurseForge

- Test stats sharing with a real second player (only the echo of our own messages is verified).
- Release zip with only the `AzerothFit/` folder (no tests, no tools), TOC limited to 16001 until
  regular Classic (11509) is tested.
- Description with a health disclaimer, screenshots, an icon.

## Art polish (low priority)

Readable but weaker: calf_raise (no feet, looks like a hop), wrist_stretch, chest_opener (subtle),
dead_bug and glute_bridge (busy), neck_tilt (small motion). Adding a foot segment to `figure.py`
would fix calf_raise.
