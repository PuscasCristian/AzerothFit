# Publishing Azeroth Fit on CurseForge

Everything needed to create the project and pass moderation. Fill the form fields with the
texts below. Rules are from CurseForge's support pages (creating a project, moderation policies,
WoW FAQ) and Blizzard's UI Add-On Development Policy, read on 2026-11-07.

## 1. Create the project (curseforge.com → Create Project → World of Warcraft)

| Field | What to enter |
|---|---|
| Name | `Azeroth Fit` (must be unique, English, no game name or version in it) |
| Summary | `Level up in real life while you level in Azeroth: short home workouts on quest turn-ins and level-ups, made for WoW Forever.` |
| Description | The text in section 3 |
| Project license | MIT License |
| Class | Addons |
| Main category | Quests & Leveling |
| Additional categories | Miscellaneous (max 4; only add ones that really fit, or moderators send it back) |
| Logo / avatar | `docs/logo.png` (400x400, original art, PNG, not webp) |
| Source / issues links | https://github.com/PuscasCristian/AzerothFit |

## 2. Upload the file (Files → Upload File)

| Field | What to enter |
|---|---|
| File | `dist/AzerothFit-0.2.0.zip` (build it with `tools/package.sh`) |
| Display name | `Azeroth Fit 0.2.0` |
| Release type | **Release** (only Release files show up in the CurseForge app) |
| Game version | **1.60.1**, flavor **Forever** (what other Forever addons use) |
| Changelog | The 0.2.0 section of `CHANGELOG.md` (a changelog is required for every file) |
| Related projects | none (no dependencies) |

The file shows "Under Review" afterwards. Moderators work 8:00 to 15:00 CET, every day, first
come first served; a file sent in the evening is usually checked the next day. If they ask for
changes, fix and resubmit in the same project. Never delete it and upload again.

## 3. Description (paste into the description editor)

---

**Level up in real life while you level in Azeroth.**

Azeroth Fit turns your leveling into short home workouts. Turn in a quest and you get a quick
exercise snack. Level up and you get a mini workout. Every 10 levels you take a Trial of Strength
and see how far you've come. Your own fitness level grows from 1 to 60 alongside your character.

No equipment needed. A wall, a chair and a bit of floor are enough.

### Made for real people

- **Pick your starting point.** Five tiers, from *Peon* (very out of shape: wall push-ups,
  standing up from a chair, nothing on the floor) to *Hero* (a full workout spread over your session).
- **It learns your level.** After each workout, tell it *Too easy*, *Just right* or *Too hard*.
  Your numbers adjust, never more than 10% a week. When an exercise gets easy, it offers the next
  one up (wall, counter, knee, then full push-ups).
- **Gentle start.** The first two weeks start lighter and build up, and so does coming back after a break.
- **Pictures for every exercise.** A small looping animation shows how each one is done.
- **Swap.** Knees or wrists sore today? Swap for a kinder exercise for the same muscles.
- **Stretching.** Eight gentle stretches for neck, shoulders, wrists, back and hips.

### Never in your way

- Never pops up in combat, waits until you leave dungeons and raids, and keeps at least five
  minutes between workouts.
- A daily limit and a weekly goal. Once you reach them, reminders only suggest standing up or a stretch.
- **Quiet mode** (no jumping) for late nights, and **pause for today** for raid night.
- Campfire nudges and stand-up reminders are small notices by the minimap that fade by themselves.
- Everything can be tuned or turned off.

### Your progress

- A real-life fitness level with titles, from *Couch Peon* to *Hero of Azeroth Fit*.
- Lifetime totals: push-ups, squats, plank time, cardio, days trained. Shared across all
  characters on your account.
- Rested bonus: days off build up bonus XP for your comeback.
- Other Azeroth Fit users can see your fitness level in your tooltip (you can turn sharing off).
  There is no leaderboard: everyone trains at their own pace.

### Commands

- `/af` opens the window (or click the minimap button; right-click it for quick options)
- `/af now` a quick set right now, `/af stretch` a stretch break
- `/af pause` pause for today, `/af quiet` quiet mode
- `/flex` shows your stats to you; `/flex guild`, `/flex party` or `/flex say` posts them

### Health note

Azeroth Fit is a motivation tool, not medical advice. Stop if anything hurts. If you have a heart,
joint or other health condition, check with your doctor before starting.

### Feedback and source

Ideas and bug reports are welcome in the comments or on GitHub:
https://github.com/PuscasCristian/AzerothFit (MIT license).

---

## 4. Screenshots to add (Images tab)

Real in-game screenshots (CurseForge requires a disclaimer on AI-edited showcase images, so use
plain game captures). Take them with Print Screen; they land in `_forever_/Screenshots/`.

1. The workout popup during a level-up workout, with the animation visible.
2. The Profile tab (fitness level, today and weekly goal).
3. The setup screen with the five tiers.
4. A campfire nudge by the minimap.
5. A tooltip on yourself showing the Azeroth Fit line.

## 5. Rule check (done)

| Rule | Status |
|---|---|
| Free, no paid features (Blizzard 1) | Yes |
| Code fully visible, not obfuscated (Blizzard 2) | Yes, plain Lua, public on GitHub |
| No harm to players or servers, no chat spam (Blizzard 3) | Addon messages are throttled (stats broadcast at most once a minute, requests rate-limited); nothing posts to public chat unless the player types `/flex <channel>` |
| No ads, no donation requests in game (Blizzard 4, 5) | Yes |
| ESRB T content (Blizzard 6) | Yes |
| Name unique and English, no versions in it (CurseForge) | "Azeroth Fit" was not found on CurseForge |
| Clear English description (CurseForge) | Section 3 |
| 400x400 avatar, original, not solid color (CurseForge) | `docs/logo.png` |
| Zip with one root folder matching the .toc (CurseForge WoW) | `AzerothFit/AzerothFit.toc` |
| At least one Release file, tagged with a game version | 0.2.0, 1.60.1 / Forever |
| Changelog with every file | `CHANGELOG.md` |
| License chosen | MIT |
| No copyrighted art or music | All pictures drawn by our own renderer; no sounds shipped (uses the game's built-in sounds) |

## 6. Later updates

1. Raise `## Version` in `AzerothFit/AzerothFit.toc` and `AF.version` in `Core/Util.lua`.
2. Add a section to `CHANGELOG.md`.
3. Run `tools/package.sh`, upload the new zip with that changelog, same game version tags.
