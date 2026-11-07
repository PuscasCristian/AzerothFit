-- Exercises, difficulty tiers and fitness titles.
-- Every category is a ladder from easiest to hardest. You climb a ladder when an
-- exercise gets easy, and step down when it is too hard. No equipment needed;
-- a sturdy chair, a wall and a table or counter are enough.
local _, AF = ...

-- Strength and cardio categories rotate through quest snacks. Stretch is separate:
-- low tiers get it in the rotation, everyone gets it on rest days and after goals.
AF.Categories = { "push", "legs", "core", "cardio" }
AF.AllCategories = { "push", "legs", "core", "cardio", "stretch" }

AF.CategoryInfo = {
	push = { name = "Push", color = { 1.00, 0.48, 0.28 }, icon = "Interface\\Icons\\Ability_Warrior_Revenge" },
	legs = { name = "Legs", color = { 0.40, 0.85, 0.42 }, icon = "Interface\\Icons\\Ability_Kick" },
	core = { name = "Core", color = { 1.00, 0.80, 0.25 }, icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
	cardio = { name = "Cardio", color = { 0.38, 0.70, 1.00 }, icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
	stretch = { name = "Stretch", color = { 0.72, 0.55, 1.00 }, icon = "Interface\\Icons\\Spell_Nature_Tranquility" },
}

-- id: animation file (Media\Ex\<id>.tga). unit: "reps" or "seconds".
-- sec: rough seconds per rep. startMax: what a typical person on this rung can do in one go.
-- promoteAt: when your max reaches this, the addon offers the next rung.
-- minMax: your max never drops below this on this rung.
-- loud: has jumping; quiet mode swaps it for `quiet` (another cardio rung).
AF.Ladders = {
	push = {
		{ id = "wall_pushup", name = "Wall Push-ups", unit = "reps", sec = 3, startMax = 12, promoteAt = 25, minMax = 4,
			cue = "Hands on the wall at shoulder height, step your feet back. Bend your elbows to bring your chest to the wall, then push away." },
		{ id = "counter_pushup", name = "Counter Push-ups", unit = "reps", sec = 3, startMax = 10, promoteAt = 20, minMax = 4,
			cue = "Hands on a sturdy table or kitchen counter, body straight like a plank. Lower your chest to the edge, then push back up." },
		{ id = "knee_pushup", name = "Knee Push-ups", unit = "reps", sec = 3, startMax = 12, promoteAt = 20, minMax = 3,
			cue = "On your knees, hands under your shoulders. Keep hips in line with your back and lower your chest close to the floor." },
		{ id = "pushup", name = "Push-ups", unit = "reps", sec = 3, startMax = 12, minMax = 3,
			cue = "Hands under shoulders, body in one straight line from head to heels. Lower your chest near the floor and press up." },
	},
	legs = {
		{ id = "sit_to_stand", name = "Sit-to-Stand", unit = "reps", sec = 4, startMax = 10, promoteAt = 20, minMax = 3,
			cue = "Sit on a sturdy chair, feet flat. Stand up without using your hands if you can, then sit back down slowly." },
		{ id = "chair_squat", name = "Chair Squats", unit = "reps", sec = 3, startMax = 15, promoteAt = 25, minMax = 5,
			cue = "Stand in front of a chair. Push your hips back and lightly tap the seat with your bottom, then stand tall. Don't sit down." },
		{ id = "squat", name = "Squats", unit = "reps", sec = 3, startMax = 25, promoteAt = 40, minMax = 6,
			cue = "Feet shoulder-width apart, chest up. Sit back and down until your thighs are about level, knees following your toes. Stand up." },
		{ id = "reverse_lunge", name = "Reverse Lunges", unit = "reps", sec = 3, startMax = 20, minMax = 6,
			cue = "Step one foot back and lower the back knee toward the floor, then push back up. Alternate legs; every leg counts as one." },
	},
	core = {
		{ id = "knee_raise", name = "Standing Knee Raises", unit = "reps", sec = 2, startMax = 20, promoteAt = 40, minMax = 6,
			cue = "Stand tall, holding a chair if you like. Lift one knee to hip height, lower it, switch. Every knee counts as one." },
		{ id = "dead_bug", name = "Dead Bugs", unit = "reps", sec = 3, startMax = 12, promoteAt = 24, minMax = 4,
			cue = "On your back, arms up, knees bent at 90 degrees. Slowly lower the opposite arm and leg, keeping your lower back on the floor. Each side counts." },
		{ id = "knee_plank", name = "Knee Plank", unit = "seconds", startMax = 30, promoteAt = 60, minMax = 15,
			cue = "Forearms on the floor, knees down, body straight from head to knees. Tighten your belly and keep breathing." },
		{ id = "plank", name = "Plank", unit = "seconds", startMax = 40, minMax = 15,
			cue = "Forearms and toes on the floor, body in one straight line. Don't let your hips sag or stick up. Breathe steadily." },
	},
	cardio = {
		{ id = "march", name = "March in Place", unit = "seconds", startMax = 60, promoteAt = 180, minMax = 20,
			cue = "Stand tall and march on the spot, swinging your arms. Hold a chair for balance if you need to." },
		{ id = "high_knee_march", name = "High-Knee March", unit = "seconds", startMax = 60, promoteAt = 150, minMax = 20,
			cue = "March briskly with your knees up toward hip height and big arm swings." },
		{ id = "step_jack", name = "Step Jacks", unit = "seconds", startMax = 60, promoteAt = 150, minMax = 20,
			cue = "Low-impact jumping jacks: step one foot out while raising your arms, step back in, switch sides." },
		{ id = "jumping_jack", name = "Jumping Jacks", unit = "seconds", startMax = 60, promoteAt = 120, minMax = 20, loud = true, quiet = 3,
			cue = "Jump your feet out while raising your arms overhead, then jump back in. Land softly on the balls of your feet." },
		{ id = "burpee", name = "Burpees", unit = "seconds", startMax = 40, minMax = 15, loud = true, quiet = 3,
			cue = "Squat, hands to the floor, step or jump back to a plank, come back in and stand up. Go at your own pace." },
	},
	-- Stretches don't climb: they take turns. Hold each one gently, never bounce.
	stretch = {
		{ id = "neck_tilt", name = "Neck Tilts", unit = "seconds", startMax = 30,
			cue = "Sit or stand tall. Slowly tilt one ear toward your shoulder, hold, then the other side. Shoulders stay down." },
		{ id = "shoulder_roll", name = "Shoulder Rolls", unit = "seconds", startMax = 30,
			cue = "Lift your shoulders up to your ears, roll them back and down. Slow, big circles. Then a few forward." },
		{ id = "chest_opener", name = "Chest Opener", unit = "seconds", startMax = 30,
			cue = "Clasp your hands behind your back, straighten your arms and lift your chest. Great after hunching over a keyboard." },
		{ id = "wrist_stretch", name = "Wrist Stretch", unit = "seconds", startMax = 30,
			cue = "Arm straight out, palm up. With the other hand, gently pull your fingers back. Switch hands halfway. Your mouse hand will thank you." },
		{ id = "upper_back_stretch", name = "Upper Back Stretch", unit = "seconds", startMax = 30,
			cue = "Clasp your hands in front, push them away and round your upper back. Let your head drop between your arms." },
		{ id = "hip_flexor_stretch", name = "Hip Flexor Stretch", unit = "seconds", startMax = 40,
			cue = "Half-kneel, one foot forward. Tuck your hips under and press them gently forward until you feel the front of the back hip. Switch sides halfway." },
		{ id = "hamstring_reach", name = "Hamstring Reach", unit = "seconds", startMax = 40,
			cue = "Sit on the edge of a chair, one leg straight out, heel down. Lean forward from the hips with a straight back. Switch legs halfway." },
		{ id = "calf_stretch", name = "Calf Stretch", unit = "seconds", startMax = 40,
			cue = "Hands on the wall, one leg straight back with the heel down, front knee bent. Lean in gently. Switch legs halfway." },
	},
}

-- "Swap" choices: the same muscles, kinder to a sore spot. Amounts scale with your tier.
AF.Alternates = {
	push = {
		{ id = "arm_circles", name = "Arm Circles", unit = "seconds", startMax = 40, why = "No weight on your wrists",
			cue = "Arms straight out to the sides. Small circles forward, then backward, growing bigger. Keep your shoulders down." },
		{ id = "wall_pushup", name = "Wall Push-ups", unit = "reps", sec = 3, startMax = 12, why = "Lighter on wrists and shoulders",
			cue = "Hands on the wall at shoulder height, step your feet back. Bend your elbows to bring your chest to the wall, then push away." },
	},
	legs = {
		{ id = "glute_bridge", name = "Glute Bridges", unit = "reps", sec = 3, startMax = 15, why = "Easy on the knees",
			cue = "On your back, knees bent, feet flat. Squeeze your glutes and lift your hips until your body is straight from knees to shoulders. Lower slowly." },
		{ id = "calf_raise", name = "Calf Raises", unit = "reps", sec = 2, startMax = 20, why = "No knee bending",
			cue = "Stand tall, holding a chair or wall. Rise up onto your toes, pause, lower slowly." },
		{ id = "side_leg_raise", name = "Side Leg Raises", unit = "reps", sec = 2, startMax = 16, why = "Hips, without deep knee bends",
			cue = "Hold a chair, stand tall. Lift one straight leg out to the side and lower it with control. Switch legs halfway." },
	},
	core = {
		{ id = "bird_dog", name = "Bird Dogs", unit = "reps", sec = 3, startMax = 12, why = "Gentle on the lower back",
			cue = "On hands and knees. Reach one arm forward and the opposite leg back, hold a breath, return. Switch sides; each side counts." },
		{ id = "side_bend", name = "Standing Side Bends", unit = "reps", sec = 2, startMax = 20, why = "Standing, no floor needed",
			cue = "Stand tall, feet hip-width. Slide one hand down the side of your leg, come back up, switch sides. Each side counts." },
		{ id = "knee_raise", name = "Standing Knee Raises", unit = "reps", sec = 2, startMax = 20, why = "Standing, no floor needed",
			cue = "Stand tall, holding a chair if you like. Lift one knee to hip height, lower it, switch. Every knee counts as one." },
	},
	cardio = {
		{ id = "shadow_boxing", name = "Shadow Boxing", unit = "seconds", startMax = 60, why = "Quiet, no jumping",
			cue = "Light stance, fists up. Throw easy punches, alternating hands, and keep your feet moving a little." },
		{ id = "step_touch", name = "Step Touch", unit = "seconds", startMax = 60, why = "Quiet and easy on the joints",
			cue = "Step to the side and bring the other foot to meet it, then step back the other way. Swing your arms along." },
		{ id = "march", name = "March in Place", unit = "seconds", startMax = 60, why = "The gentlest option",
			cue = "Stand tall and march on the spot, swinging your arms. Hold a chair for balance if you need to." },
	},
	stretch = {},
}

-- Tiers set your starting rung on each ladder and how much the addon asks of you.
-- snackPct: share of your max asked per quest snack.
-- levelPct: share of your max per set in a level-up workout.
-- rounds: rounds in a level-up workout. gap: minimum minutes between snacks.
-- capSets: most sets per day (stretches don't count). snackSets: exercises per quest snack.
-- rotation: the order quest snacks take. altScale: how hard "Swap" alternatives are.
-- cooldown: a stretch at the end of level-up workouts.
AF.Tiers = {
	{ key = "peon", name = "Peon", tag = "Very out of shape",
		blurb = "Getting moving again. Wall push-ups, standing up from a chair, marching, lots of stretching. Nothing on the floor.",
		variants = { push = 1, legs = 1, core = 1, cardio = 1 }, max = {},
		snackPct = 0.40, levelPct = 0.55, rounds = 1, gap = 20, capSets = 8, altScale = 0.6, cooldown = true,
		rotation = { "push", "stretch", "legs", "core", "stretch", "cardio" } },
	{ key = "grunt", name = "Grunt", tag = "Starting out",
		blurb = "Some activity already. Counter push-ups, chair squats, dead bugs, and a stretch now and then.",
		variants = { push = 2, legs = 2, core = 2, cardio = 2 }, max = {},
		snackPct = 0.50, levelPct = 0.60, rounds = 2, gap = 15, capSets = 12, altScale = 0.8, cooldown = true,
		rotation = { "push", "legs", "stretch", "core", "cardio" } },
	{ key = "soldier", name = "Soldier", tag = "Normal",
		blurb = "Average fitness, wants to get in shape. Knee push-ups, squats, knee planks, step jacks.",
		variants = { push = 3, legs = 3, core = 3, cardio = 3 }, max = {},
		snackPct = 0.50, levelPct = 0.65, rounds = 2, gap = 15, capSets = 15, altScale = 1.0,
		rotation = { "push", "legs", "core", "cardio" } },
	{ key = "champion", name = "Champion", tag = "Fit",
		blurb = "Trains already. Full push-ups, squats, planks, jumping jacks.",
		variants = { push = 4, legs = 3, core = 4, cardio = 4 }, max = { push = 15, legs = 30, core = 45 },
		snackPct = 0.50, levelPct = 0.65, rounds = 3, gap = 10, capSets = 22, altScale = 1.2,
		rotation = { "push", "legs", "core", "cardio" } },
	{ key = "hero", name = "Hero", tag = "Very fit",
		blurb = "A full home workout spread over your play session. Push-ups, lunges, long planks, burpees.",
		variants = { push = 4, legs = 4, core = 4, cardio = 5 }, max = { push = 30, legs = 30, core = 75, cardio = 45 },
		snackPct = 0.55, levelPct = 0.70, rounds = 4, gap = 6, capSets = 36, altScale = 1.5, snackSets = 2,
		rotation = { "push", "legs", "core", "cardio" } },
}

-- Real-life fitness titles, unlocked by fitness level (not character level).
AF.Titles = {
	{ 1, "Couch Peon" },
	{ 3, "Stair Survivor" },
	{ 5, "Wobbly Recruit" },
	{ 8, "Sweaty Squire" },
	{ 12, "Iron Grunt" },
	{ 16, "Sergeant of Squats" },
	{ 20, "Knight of the Knee Raise" },
	{ 25, "Plank Warden" },
	{ 30, "Push-up Paladin" },
	{ 35, "Marshal of Mobility" },
	{ 40, "Champion of the Living Room" },
	{ 45, "Warlord of the Workout" },
	{ 50, "Grand Marshal of Gains" },
	{ 55, "Legend of the Floor" },
	{ 60, "Hero of Azeroth Fit" },
}

-- Short lines for popups, picked at random.
AF.Quips = {
	quest = {
		"Quest done. Your real-life quest giver has a request.",
		"The quest giver is pleased. Your body would be too.",
		"Turn in your quest, turn on your muscles.",
		"Experience gained. Now gain some in real life.",
	},
	levelup = {
		"Ding! Your character got stronger. Your turn.",
		"New level, new you. Mini workout time.",
		"The trainer is waiting. Not that one, this one.",
	},
	death = {
		"You died. Shake it off on the way back to your corpse.",
		"The spirit healer prescribes a little cardio.",
		"Running back anyway? Run in real life too.",
	},
	trial = {
		"Trial of Strength. Show how far you have come.",
	},
	stretch = {
		"A slow stretch. Breathe out and let it go.",
		"Loosen up. Your back has been holding that pose for a while.",
		"Stretch it out. No counting, no rush.",
	},
	move = {
		"You've been sitting a while. Get the blood flowing.",
	},
}
