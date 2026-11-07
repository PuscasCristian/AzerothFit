# Azeroth Fit

A WoW addon (Forever 1.60.1, interface 16001) that turns leveling into home workouts.
You get a short exercise "snack" when you turn in a quest, a mini workout when you level up,
and a Trial of Strength every 10 levels. Your real-life fitness level (1-60) grows with every set,
and other players with the addon can see your level and totals in your tooltip.

## Layout

- `AzerothFit/` is the addon. It is symlinked into
  `~/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzerothFit`.
- `AzerothFit/Data/Exercises.lua` holds the exercises, tiers, titles and popup lines.
- `AzerothFit/Core/Engine.lua` holds all the math (no game API calls).
- `tests/` has a fake WoW API, a test suite and a 1-60 leveling simulation.

## Testing

    lua5.1 tests/run_tests.lua     # behaviour tests
    lua5.1 tests/simulate.lua      # 1-60 simulation per tier

## In game

    /af                 open the window
    /af now             a quick set right now
    /af trial           Trial of Strength
    /af preview levelup preview a popup (also quest, death, trial)
    /flex               post your stats to guild/party/say
