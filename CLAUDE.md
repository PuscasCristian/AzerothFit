# Azeroth Fit

A World of Warcraft **Forever** addon (client 1.60.x, interface 16001) that turns leveling into
short home workouts: a snack per quest turn-in, a mini workout per level-up, a Trial of Strength
every 10 levels, and a real-life fitness level 1-60. The owner designs it, plays it daily and
gives feedback; read `ROADMAP.md` for what's done, what's next and why.
Public repo: https://github.com/PuscasCristian/AzerothFit (branch main). Commits use the GitHub no-reply email;
tests use made-up character names (Tamsin/Gideon Oakhart). Keep the owner's real character names out of the repo.

## Layout

- `AzerothFit/`: the addon. It is **symlinked** into
  `~/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzerothFit`,
  so edits are live after `/reload`. New files (TOC entries, textures) need a **full game restart**.
- `AzerothFit/Data/Exercises.lua`: exercises (ladders per category), swap alternatives,
  stretches, tiers, titles, popup lines. Most tuning happens here.
- `AzerothFit/Core/Engine.lua`: all the math, no game API (testable).
- `AzerothFit/Core/Core.lua`: game events -> workout queue, nudges, pause, slash commands.
- `AzerothFit/UI/`: popup (workout card), main window (5 tabs), toasts + minimap nudges, setup, minimap button.
- `AzerothFit/Social/Comm.lua`: stats sharing between players, tooltips, /flex.
- `AzerothFit/Media/Ex/<id>.tga`: exercise animations (512x128, 4 frames, RLE 32-bit TGA).
  `AzerothFit/Data/Art.lua` is generated and lists them.
- `tools/art/`: the stick-figure renderer. `figure.py` (forward and two-bone IK poses, props),
  `poses_a.py` / `poses_b.py` (one entry per exercise id), `build.py` (renders all, writes Art.lua,
  previews in `tools/art/preview/`).
- `tests/`: `wowmock.lua` (fake WoW API), `run_tests.lua` (core behaviour), `run_v02.lua`
  (v0.2 features), `simulate.lua` (1-60 leveling simulation per tier).

## Commands

    lua5.1 tests/run_tests.lua && lua5.1 tests/run_v02.lua   # must both pass
    lua5.1 tests/simulate.lua                                 # sanity-check tier numbers
    python3 -I tools/art/build.py [id ...]                    # re-render animations (+ Art.lua when no ids)

## Forever client quirks (verified in game)

- Player names are "First Surname" with a **space** (addon message senders look like
  "Tamsin Oakhart"). `UnitName` returns the surname where the realm usually goes.
  Compare names with `AF.Comm.Norm` (ignores spaces, dashes, case).
- Guild chat echoes addon messages back to the sender; own messages are recognised by the
  account-wide `profileId` in the payload.
- Values can be "secret" (Midnight engine): guard with `AF.Safe` / `AF.IsSecret`.
- `C_VoiceChat.SpeakText(voice, text, rate, volume)` takes 4 arguments on Forever.
- Check `C_ChatInfo.InChatMessagingLockdown()` before sending chat or addon messages.
- RLE 32-bit TGA textures work (other Forever addons ship them).
- Campfire = player aura 1229739 or 1289723 (Welcoming Campfire).

## Rules the owner set (don't undo without asking)

- **No leaderboards.** People can press Done without exercising; rankings would be lies.
  The Buddies tab lists people, sorted by last seen, no ranks.
- **Everything is per account**, not per character (one SavedVariables table; `chars` keeps each
  character's share).
- **Plain /flex only prints to the player**; posting needs `/flex guild|party|say`.
- **Nudges must be quiet**: small notice by the minimap, fades in seconds. Once today's sets or the
  weekly goal are done, nudges only suggest standing up, walking or stretching, never a workout.
- **At least 5 minutes between any two workouts** (setting "Break after any workout").
- Players are mostly 30+: gentle defaults, easy steps down, stretching for low tiers, quiet mode.
- Stop-if-it-hurts wording; never medical claims.

## Working style

- The owner talks by voice-to-text; read for intent. Explain in plain words.
- Ask before committing or pushing. Back up before risky edits (a careless script once
  emptied `UI/Popup.lua`; never `open(p, 'w')` and read `p` in the same expression).
