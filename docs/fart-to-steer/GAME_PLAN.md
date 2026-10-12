# Fart to Steer — Game Plan

A Roblox co-op "friend slop" game based on **Boat Together**. You and up to 7 friends
hang off the edge of a round inflatable boat. There are no paddles. The only way to
move is to **fart**, and every player can fart in just three directions: **Left**,
**Straight** or **Right**. Get through rivers full of obstacles, beat bosses and reach
the treasure on the last island without sinking.

---

## 1. What Boat Together actually is (research summary)

Boat Together (Beaked Games, Steam, released 15 Nov 2025, cheap at about $4) is a co-op
paddling game. This is what I could confirm from the store listing, achievements,
update posts and player discussions:

| Boat Together                                                                                   | Fart to Steer version                                                               |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Up to **8 players** online, everyone on the same boat                                           | Up to 8 players per boat                                                            |
| Every player **paddles**, and you must coordinate or the boat goes out of control               | Every player **farts** in one of 3 directions, and you must coordinate              |
| Boats: solo kayak, 2-player kayak, **4-player boat**, 2-player **jet ski**. Bigger boats are harder to control | Solo Tube, Double Donut, **Party Ring (4)**, **Jet Toot (2)**, Mega Donut (8) |
| Water physics that need precise control                                                         | Custom water physics with drag, currents and float (section 12)                     |
| Paddle past obstacles from island to island. Each island is a new biome and harder than the last | Same structure: 10 islands, each a new biome                                       |
| **Bosses**: pirate ship (achievement "Burning Ship"), plant ("Deadly Plant"), and a **shark** added in the 2026 update | Stinkbeard's pirate galleon, Venus Fart Trap, Jaws of Gas                |
| A **fungi island**, and a **frog level** that players say is the hardest part                   | Funky Fungi Island, Croak Swamp                                                     |
| **Checkpoints** (achievement "Somewhere Safe"). Dying is so common that 97% of players have the "RIP" achievement | Checkpoint buoys, team respawns at the last one                            |
| First island has a **parkour course**                                                           | Parkour Tower in the hub                                                            |
| **3 hidden easter eggs** and a secret easter-egg achievement                                    | 3 hidden Golden Beans                                                               |
| **Hidden treasure on the final island**                                                         | The Golden Bean on Golden Bean Island                                               |
| Skins for your boat and character                                                               | Boat skins, outfits, fart trails, fart sound packs                                  |
| **Winter Update** (Dec 2025): snowy map, emotes, **punching**, checkpoint rewards, more customization, winter skins, **Galaxy Island** | Frostbutt Fjord, emotes, **Slap**, checkpoint Bean rewards, Gassy Galaxy |
| Original world is **floating water in the sky**. The 2026 update moves to a real landscape and adds new boats and the Shark Boss | We use sky rivers (cheaper to build, falling off is a clear fail) |

What I could **not** confirm: the exact list of small obstacles, the control
layout, and whether the boat has health. Those parts of this plan are designed to fit
the same style of game rather than copied from it.

---

## 2. The core mechanic: 3-way fart steering

### 2.1 The boat and the seats

The boat is a round inflatable ring. Seats are spaced evenly around the rim. Each
player sits on the rim **facing the middle**, leaning back with their butt hanging
over the water. Gas comes out the back of the player and pushes the boat the other
way.

```
                        P3  (far side)
                     .--------.
                   /     ↓      \
       P4  →     |   (center)    |    ←  P2
                   \     ↑      /
                     '--------'
                        P1   ← you. Your camera sits behind you,
                                    looking across the boat.

   Arrows = where each player's STRAIGHT fart pushes the boat (toward the center
   and out the other side).
```

### 2.2 The three farts

Every direction is relative to **your own seat**, the way you're facing.

| Fart         | What happens to the boat                                                                     |
| ------------ | -------------------------------------------------------------------------------------------- |
| **Straight** | Pushes the boat **away from you**, straight across the middle. No spin.                       |
| **Left**     | The boat **turns left**, the same way for every player. Also a small sideways push.           |
| **Right**    | The boat **turns right**, the same way for every player. Also a small sideways push.          |

Left and Right work like an outboard motor: your fart pushes your side of the boat
sideways, so the far side swings the way you chose. Because every player looks at
the boat from outside, "Left" spins the boat the same direction no matter whose seat
it comes from.

### 2.3 Why this makes good co-op chaos

This is the important design point, and it works the way you described:

- **Everyone farts Left → the boat spins left on the spot.** All the sideways pushes
  cancel out and all the spin adds up. Same for Right.
- **Everyone farts Straight → nothing happens.** Each push goes across the middle and
  the pushes cancel each other out. To move, **only the people at the back** should
  fart Straight, and the front has to hold it in.
- Since the boat is round, "the back" changes every time you spin. Someone always has
  to yell "WHO'S AT THE BACK?!". That's the same kind of coordination problem as
  paddling in Boat Together.

### 2.4 Fart formations (4-seat Party Ring)

Seats are named relative to where the team wants to go:
**Back** (farthest from the goal), **Front**, **Left side**, **Right side**.

| Move                     | Back      | Front     | Left side | Right side | Notes                                        |
| ------------------------ | --------- | --------- | --------- | ---------- | -------------------------------------------- |
| Go forward               | Straight  | —         | —         | —          | Simplest move                                |
| Full speed ahead         | Straight  | —         | Right     | Left       | The side seats' sideways pushes point forward and their spins cancel |
| Spin left on the spot    | Left      | Left      | Left      | Left       | What you asked for                           |
| Spin right on the spot   | Right     | Right     | Right     | Right      |                                              |
| Turn left while moving   | Straight  | Left      | —         | —          | Push and steer at the same time              |
| Brake                    | —         | Straight  | —         | —          | Pushes backward                              |
| Strafe right (slide sideways) | Left | Right     | Straight  | —          | Spins cancel and the boat slides sideways (advanced trick) |
| Stop a spin              | Opposite  | Opposite  | Opposite  | Opposite   | Anyone farting against the spin slows it down |

The tutorial pond in the hub teaches these one at a time (section 9).

### 2.5 Toots, Mega Farts and the Gas meter

- **Tap** = **Toot**. A small push with a short cooldown (0.35 s). Tap over and over to
  keep moving, the same rhythm as paddling.
- **Hold, then release** = **Mega Fart**. Charges for up to 1.2 s and gives up to
  3× the push. Your character goes red and shakes while charging. Big cloud, big sound,
  camera shake.
- **Gas meter** (100 per player). A toot costs 8, a Mega costs 35, and gas refills at
  12 per second. If you fart with an empty meter you get a sad little *pfft*
  (a **Dud**) and the boat doesn't move. Bean Cans refill gas (section 8).
- The meter is a small bar shaped like a stomach, shown above your character, so your
  friends can see who's out of gas.

### 2.6 Team combos (rewards for working together)

- **FARTQUAKE**: if 3 or more players (or the whole boat, if fewer than 3 are on it)
  release a Mega Fart within 0.35 s of each other, every push gets ×1.5. You also get a
  screen shake and a big "FARTQUAKE!" banner. Some gaps and bosses need one.
- **Pull My Finger**: a player holds out a finger (`G`) and the player in the
  next seat presses `G` to pull it. The first player does a free, full-power Mega
  Fart that costs no gas. 30 s cooldown. Good for emergencies.

### 2.7 Controls

| Action          | PC                  | Mobile                         | Controller |
| --------------- | ------------------- | ------------------------------ | ---------- |
| Fart Left       | `A` / `←` / `Q`     | Big ⟲ button (bottom left)     | `LB`       |
| Fart Straight   | `W` / `↑` / `Space` | Big ⬆ button (bottom middle)   | `RT`       |
| Fart Right      | `D` / `→` / `E`     | Big ⟳ button (bottom right)    | `RB`       |
| Mega Fart       | Hold any fart key   | Hold the button                | Hold       |
| Slap            | `F`                 | ✋ button                       | `X`        |
| Pull My Finger  | `G` (offer yours, or pull a neighbor's) | ☝ button     | `Y`        |
| Quick chat      | `1`–`4`             | 💬 wheel                       | D-pad      |
| Emotes          | `B`                 | 😀 button                       | `LS` click |

Normal walking controls are turned off while you're seated, so the WASD keys are free.

### 2.8 Camera

- **Seat Cam (default)**: behind and above **your** seat, looking across the boat. It
  turns with the boat (smoothed). Your Straight fart always pushes "up the screen" and
  your Left fart always turns the view left, so you never have to work out your
  controls. The only hard part is your team.
- **Chase Cam (option)**: follows behind the boat in the direction it's moving and
  doesn't spin. Use it if the spinning makes you dizzy. It shows thrust arrows so your
  controls still make sense.
- **Thrust preview**: while you hold a fart key, a faint arrow on the boat shows where
  it will push. It's always on in the tutorial and can be switched on in settings.

---

## 3. Friend-slop extras

- **Slap** (our version of Boat Together's punch): slap the player in the next seat.
  If they're charging a Mega it gets cancelled and they **toot by accident in a random
  direction**. 3 s cooldown. Party leaders can turn it off.
- **Falling off**: swinging logs, cannonballs, yetis and slaps can knock a player into
  the water. They swim back automatically after 3 s, or respawn on their seat if the
  boat is too far away. Their seat does nothing while they're off.
- **Emotes**: wave, dab, point, cry, Pull My Finger, and "Hold it in" (clenching).
- **Quick-chat pings**: "PUSH!", "SPIN LEFT!", "SPIN RIGHT!", "STOP FARTING!",
  "BEANS!", "WHO'S AT THE BACK?!". They pop up as speech bubbles. Roblox voice chat
  works on top of this.
- **Silly physics**: the ring wobbles and tilts a little when hit, and characters
  ragdoll a bit on big hits.

---

## 4. Boats

All boats are round rings except the Jet Toot. Bigger boats are slower to react, just
like in Boat Together.

| Boat            | Seats | Size (radius) | Push / Spin scale | Feel                                                         | Unlocked by           | Boat Together match |
| --------------- | ----- | ------------- | ----------------- | ------------------------------------------------------------ | --------------------- | ------------------- |
| **Solo Tube**   | 1     | 3 studs       | 1.2 / 1.5         | Twitchy. Spin to aim, then push, like a tank                 | Start                 | Solo kayak          |
| **Double Donut**| 2     | 4.5           | 1.1 / 1.2         | Players sit opposite each other. Strafe is easy              | Start                 | 2-player kayak      |
| **Party Ring**  | 4     | 6             | 1.0 / 1.0         | The main boat. Every formation works                         | Start                 | 4-player boat       |
| **Jet Toot**    | 2     | Not round     | 2.0 / 1.0         | Back seat = **Engine** (Straight only, 2× push). Front seat = **Pilot** (Left/Right only, pure turning). Very fast | Reach Croak Swamp | Jet ski |
| **Mega Donut**  | 8     | 9             | 0.6 / 0.45        | Heavy. Turns slowly. Chaos with 8 people                      | Start                 | (8-player cap)      |

Players choose a seat by standing on a seat pad at the dock. Empty seats stay empty,
so 3 players on a Party Ring get a lopsided boat (that's fine).

---

## 5. Health, death and checkpoints

- **Air** (boat health): the boat is inflatable. Bumps remove a little Air. Sharp
  things (thorns, teeth, spikes, cannonballs) make a **leak** that slowly lets Air out:
  the ring sags, sits lower in the water and gets slower. **Gum** pickups patch leaks.
- **POP!**: at 0 Air the ring bursts, everyone flies off and the team respawns at the
  last checkpoint.
- **Falling off the river**: the rivers float in the sky with no walls in some places.
  If the boat goes off the edge it falls, and the team respawns at the last checkpoint.
- **RIP screen**: a tombstone that says "RIP — Rest In Pfft", how many times the team
  has died, and who farted last ("Blame: @Player").
- **Checkpoint buoys**: 3–4 per island, plus one before every boss. They refill Air,
  gas and leaks, and give a **checkpoint reward** of 10 Beans per player (Boat Together
  added checkpoint rewards in its Winter Update).

---

## 6. World and islands

### 6.1 World style

**Sky rivers**, like Boat Together's original world. The rivers are strips of water
floating in the sky between islands. This has three benefits:

1. No terrain to build, so it's cheap and fast to make and runs well on phones.
2. Falling off the edge is an obvious way to fail.
3. It looks great: waterfalls drop from one sky river to the next.

### 6.2 Island list

Each island takes about 4–8 minutes for a good team. A first full run should take
2–4 hours, close to Boat Together's average playtime.

| #  | Island                 | Biome                                   | Based on (Boat Together)    | Difficulty |
| -- | ---------------------- | --------------------------------------- | --------------------------- | ---------- |
| 0  | **Bean Harbor** (hub)  | Seaside town, docks                     | First island + parkour      | —          |
| 1  | **Lazy Gut River**     | Grassland, wide and slow                | Early islands               | ★          |
| 2  | **Croak Swamp**        | Dark swamp, narrow channels             | The frog level              | ★★★        |
| 3  | **Funky Fungi Island** | Glowing mushroom caves                  | Fungi island                | ★★★        |
| 4  | **Venus Fart Trap**    | Boss arena in an overgrown jungle lake  | Plant boss                  | ★★★        |
| 5  | **Stinkbeard's Cove**  | Pirate bay, cliffs and cannons          | Pirate boss (Burning Ship)  | ★★★★       |
| 6  | **Frostbutt Fjord**    | Snow and ice                            | Snowy map (Winter Update)   | ★★★★       |
| 7  | **Jaws of Gas**        | Open sea                                | Shark boss (2026 update)    | ★★★★       |
| 8  | **Gassy Galaxy**       | Space, star rivers, low gravity         | Galaxy Island               | ★★★★★      |
| 9  | **Golden Bean Island** | Treasure island                         | Final island + treasure     | ★★★★★      |

I don't know Boat Together's exact island order, so this order is mine.

### 6.3 Island details

**1. Lazy Gut River (tutorial river)**
Wide, gentle bends, a few rocks, floating logs you can push out of the way, one log
gate you have to spin to line up with, a small waterfall drop and the first current.
Every new thing is introduced on its own. Ends at a checkpoint where the river
narrows.

**2. Croak Swamp (the frog level)**
In Boat Together players called this the hardest level, so it should be hard but
fair.
- **Giant frogs** on lily pads. They croak (warning) and then shoot their tongues out.
  A tongue sticks to the boat and pulls it toward the frog's mouth. You break free by
  Mega Farting away from the frog, or instantly with a FARTQUAKE.
- **Drifting lily pads** block the channel and move around.
- **Reed beds** are slow zones with lots of drag.
- **Mosquito swarms** "cork" one player for 4 s (they can't fart) unless a neighbor
  pulls the cork out with Interact.
- **Finale**: a narrow sky river with no walls and three frogs firing in turns. If a
  tongue pulls you, you fall off.

**3. Funky Fungi Island**
- **Bounce mushrooms**: hitting a mushroom cap bounces the boat back hard.
- **Confusion spores**: inside a purple cloud everyone's Left and Right are **swapped**
  for 5 s.
- **Dark caves**: your fart clouds **glow**, and they're the only light. Fart to see.
- **Mushroom ramps**: launch the boat across gaps between sky rivers. You need speed,
  usually a FARTQUAKE, to make it across.

**4. Boss: Venus Fart Trap (plant boss)**
A huge carnivorous plant in the middle of a round lake.
- **Phase 1 — Inhale**: it sucks the boat toward its mouth. Spin so one player's butt
  faces the mouth, and that player farts **Straight**. The gas goes into the plant's
  mouth (damage) and the push holds the boat away from it. Three good gulps of gas
  make it gag.
- **Phase 2 — Thorns and vines**: it spits thorn seeds (leaks) and sweeps vines across
  the water. Dodge by spinning and strafing.
- **Phase 3 — Root maze**: roots come up out of the water and make a maze, then it
  inhales harder. Finish it with a FARTQUAKE straight into its mouth.

**5. Boss: Stinkbeard's Cove (pirate boss)**
- **Approach**: cannons on the cliffs fire with red target circles on the water first
  (warning), floating **sea mines** (big knockback and leaks), and pirate grunts that
  swing onto your boat on ropes (Slap them off).
- **Boss**: Captain Stinkbeard's galleon sails around the bay firing broadsides.
  There are **torch buoys** floating around. Drive past one and the nearest player
  grabs a torch, which makes their Mega Farts **flame farts** for 8 s (a
  flamethrower). Blast the 3 powder kegs on the ship's side to set it on fire. Later
  phases: rowboats chase you, then a full cannon barrage, then the last keg.
  You're literally burning the ship, like Boat Together's "Burning Ship" achievement.

**6. Frostbutt Fjord (snow)**
- **Ice floes** drift around and can be pushed.
- **Ice sheets** have no drag, so the boat keeps sliding. Brake by farting the other
  way.
- **Falling icicles** drop from ice arches (shadow on the water first as a warning).
- **Cold water**: gas refills at half speed. **Hot springs** refill it quickly.
- **Snowball yetis** on the shore knock players off the boat.

**7. Boss: Jaws of Gas (shark boss)**
Sharks can smell farts. **The shark goes for whichever seat farted last.**
- **Phase 1**: it circles, then charges at the smelliest seat. A bite takes a lot of
  Air. Use it: one player is the **bait** and farts to pull the shark toward them,
  while the rest steer so the charge goes into the **spiked mines** around the arena.
  Three hits and it moves on.
- **Phase 2**: it jumps over the boat (watch for its shadow) and knocks players off.
- **Phase 3**: a chase down a fast river toward the next island. Whoever farts gets
  chased, so the team has to keep switching who pushes.

**8. Gassy Galaxy**
- Rivers made of stars floating in space, with **low gravity**: farts push 1.5× as
  far and ramps throw the boat much farther.
- **Black hole whirlpools** pull the boat in and spin it. Spin with it and then push
  Straight at the right moment to slingshot out.
- **Asteroid fields** and **meteor showers** (target circles first as a warning).
- **Star rings**: fly through them for bonus Beans.

**9. Golden Bean Island (final)**
A last gauntlet that mixes everything: rapids, a waterfall staircase (several drops in
a row), a frog, a cannon or two, then the **Grand Geyser**, which launches the boat
into the treasure cave. Opening the chest reveals **the Golden Bean**. Then the
credits, a badge, a golden boat skin and a golden fart trail.

---

## 7. Obstacle library

Everything here is a reusable, tagged part (section 12.6) so building new levels is
mostly placing pieces.

| Obstacle               | What it does                                    | How to beat it                    | First seen |
| ---------------------- | ----------------------------------------------- | --------------------------------- | ---------- |
| Rock                   | Bounce, −5 Air                                  | Steer around it                   | 1          |
| Spiky rock / thorns    | Bounce + leak                                   | Steer around it                   | 1          |
| Floating log           | Physics object, blocks the way                  | Push it aside or go around        | 1          |
| Log gate               | Narrow gap only slightly wider than the boat    | Line up, then push straight       | 1          |
| Spinning log / waterwheel | Rotating barrier                             | Timing                            | 1          |
| Swinging log           | Pendulum that knocks players off                | Timing, or spin your gap away     | 1          |
| Current                | Pushes the boat along an arrow on the water     | Fart against it or ride it        | 1          |
| Waterfall drop         | Drops to a lower river, speed boost             | Go in straight                    | 1          |
| No-wall edge           | Fall off = death                                | Don't                             | 1          |
| Lily pads (drifting)   | Moving blockers                                 | Push or go around                 | 2          |
| Frog                   | Tongue grabs and pulls the boat                 | Mega away, or FARTQUAKE           | 2          |
| Reeds                  | High-drag slow zone                             | Mega through                      | 2          |
| Mosquitoes             | Cork a player for 4 s                           | Neighbor pulls the cork           | 2          |
| Bounce mushroom        | Strong bounce back                              | Steer around it, or use it        | 3          |
| Confusion spores       | Left and Right swapped for 5 s                  | Talk to each other                | 3          |
| Darkness               | Can't see                                       | Glowing farts                     | 3          |
| Ramp / gap             | Need a minimum speed                            | FARTQUAKE                         | 3          |
| Whirlpool              | Pulls you in and spins you                      | Fart against the spin             | 3          |
| Cannon                 | Target circle, then a hit (leak + knock off)    | Get out of the circle             | 5          |
| Sea mine               | Explosion, big knockback                        | Don't touch                       | 5          |
| Pirate grunt           | Swings onto the boat and blocks a seat          | Slap him off                      | 5          |
| Piranhas               | Bite Air while you're in their zone             | Farts scare fish away             | 5          |
| Ice floe               | Heavy pushable block                            | Push or go around                 | 6          |
| Ice sheet              | No drag, no braking                             | Fart against the slide            | 6          |
| Icicles                | Falling, shadow warning first                   | Dodge                             | 6          |
| Yeti                   | Snowballs knock players off                     | Keep moving                       | 6          |
| Geyser                 | Timed launch upward                             | Use it, or wait for it            | 6          |
| Black hole             | Strong whirlpool                                | Slingshot out                     | 8          |
| Meteor                 | Target circle, then a hit                       | Dodge                             | 8          |

---

## 8. Pickups

Pickups float on the river. Driving through one gives it to the nearest seat.

| Pickup             | Effect                                                         |
| ------------------ | -------------------------------------------------------------- |
| **Bean Can**       | +50 gas for that player, +1 Bean (currency)                    |
| **Chili Pepper**   | Flame farts for 8 s: 1.5× push and burns vines, ropes and kegs |
| **Prune Juice**    | Half cooldown for 8 s (rapid fire)                             |
| **Cabbage**        | Whole boat: gas refills twice as fast for 10 s                 |
| **Gum**            | Patches all leaks                                              |
| **Golden Bean**    | Hidden easter egg (3 in the world). Find all 3 for a secret badge |

---

## 9. The hub: Bean Harbor

- **Docks**: one berth per boat type with seat pads. The party leader presses
  **LAUNCH** (or there's a 15 s countdown once everyone is seated). Then pick a
  starting island from any the leader has unlocked.
- **Tutorial Pond**: a short practice course with signs: (1) Straight pushes you away,
  (2) Left/Right spin, (3) everyone spin, (4) the back seat pushes, (5) Mega and
  FARTQUAKE, (6) Pull My Finger. Ends at a target you need to hit.
- **Parkour Tower** (Boat Together has a parkour course on its first island): on foot,
  rewards a hat and a badge.
- **Shop**: spend Beans on cosmetics. Changing rooms show your fart trail.
- **Hidden Golden Bean #1** is somewhere in the harbor.

---

## 10. Progression, cosmetics and badges

**Progress**: unlocked islands are saved per player. The party can start from any
island the leader has unlocked. Best times per island show on a leaderboard.

**Beans** (soft currency) come from Bean Cans, checkpoint rewards, boss clears and
the first time you finish an island.

**Cosmetics**
- Boat skins: donut, pizza, flamingo floatie, rubber duck, tire, lifebuoy, golden ring
- Fart trails: green cloud (default), rainbow, sparkles, fire, bubbles, galaxy, gold
- Fart sound packs: Classic, Squeaky, Tuba, Opera, 8-bit, Robot
- Outfits and hats, including winter skins for a Winter event
- Pop effects (what happens when your boat bursts): confetti, feathers, fireworks

**Badges** (Boat Together has 12 achievements; these match them)

| Badge               | How to get it                              | Boat Together match         |
| ------------------- | ------------------------------------------ | --------------------------- |
| First Toot          | Fart for the first time                    | First Timer                 |
| Rest In Pfft        | Die                                        | RIP                         |
| Somewhere Smelly    | Reach a checkpoint                         | Somewhere Safe              |
| Drip Check          | Equip a cosmetic                           | Equip a cosmetic            |
| Parkour Pooter      | Finish the Parkour Tower                   | First-island parkour        |
| Spore Snorter       | Reach Funky Fungi Island                   | Reach fungi island          |
| Trap Sprung         | Beat the Venus Fart Trap                   | Deadly Plant                |
| Roasted Galleon     | Beat Stinkbeard                            | Burning Ship                |
| Jet Toot Rider      | Ride the Jet Toot                          | Ride the jet ski            |
| Shark Bait          | Beat Jaws of Gas                           | (shark update)              |
| The Golden Bean     | Reach the treasure                         | Reach the end               |
| Bean Counter        | Find all 3 hidden Golden Beans (secret)    | Secret easter egg           |
| Pull My Finger      | Do a Pull My Finger with a friend          | (new)                       |
| FARTQUAKE           | Do a FARTQUAKE with 8 players              | (new)                       |

---

## 11. Monetization (light, no pay-to-win)

- **Game passes**: fart sound packs, VIP (golden name tag and trail), boat skin bundles.
- **Developer products**: Bean packs, and **Team Revive** (respawn the team where it
  died instead of at the checkpoint, at most once per island).
- **Private servers**: cheap, so friend groups can play alone.
- No paid gas or power boosts. It's co-op, but buying power still feels bad.

---

## 12. Technical plan (Roblox)

### 12.1 Main decisions

| Decision                | Choice                                                              | Why                                                                     |
| ----------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Who simulates the boat  | **Server** (`SetNetworkOwner(nil)`)                                 | Fair to every player, hard to cheat, and no single player's lag breaks the boat |
| Responsiveness          | Fart FX and sound play **on your own client right away**; the server applies the push | Feels instant even with about 100 ms of lag |
| Water                   | **Custom** float and drag using invisible water parts, not Terrain water | Predictable, works for sky rivers, and the boat falls off edges naturally |
| Staying upright         | `AlignOrientation` (keep the up axis vertical, turning left/right is free) | Stops the ring flipping but lets it wobble a little            |
| Multiple teams          | Several boats in one server; boats from different teams don't collide (collision groups) | Social and simple. "Bumper Boats" can be a private-server toggle |
| Building levels         | Hazards are **tagged parts** (`CollectionService`) with attributes  | Level builders place and tag pieces instead of writing scripts          |
| Big maps                | `StreamingEnabled`, boats with `ModelStreamingMode = Atomic`         | Runs well on phones                                                     |
| Saving                  | ProfileStore (or `DataStoreService` with session locking)           | Beans, cosmetics, unlocks, best times                                   |

### 12.2 Project layout (works with Rojo or in Studio)

```
ReplicatedStorage/
  Shared/
    Config.lua            -- every tuning number (section 13)
    FartPhysics.lua       -- fart push math, shared by server + client preview
    BoatTypes.lua         -- seat layouts and scales per boat
  Remotes/                -- Fart, FartFX, Slap, PullFinger, Emote, BoatState
  Assets/                 -- boats, fart particles, fart sounds
ServerScriptService/
  BoatService.server.lua    -- spawn boats, seat players, network ownership
  FartService.server.lua    -- check inputs, gas, cooldowns, apply pushes, combos
  WaterService.server.lua   -- float, drag, currents, falling off
  CourseService.server.lua  -- checkpoints, deaths, respawns, island progress
  HazardService/            -- Rock, Log, Current, Whirlpool, Frog, Cannon, ...
  BossService/              -- VenusFartTrap, Stinkbeard, JawsOfGas
  DataService.server.lua    -- saving, Beans, cosmetics, badges
StarterPlayerScripts/
  FartInput.client.lua      -- keyboard, controller, touch buttons
  BoatCamera.client.lua     -- Seat Cam and Chase Cam
  FartFX.client.lua         -- particles, random sounds, camera shake
  HUD.client.lua            -- gas meter, Air bar, quick chat, RIP screen
```

### 12.3 The fart push (the core of the game)

```lua
--!strict
-- ReplicatedStorage/Shared/FartPhysics.lua
-- Pure math with no side effects, so the server (real pushes) and the client
-- (thrust preview arrows) use exactly the same rules.
local Config = require(script.Parent.Config)

local FartPhysics = {}

export type Direction = "Left" | "Straight" | "Right"

-- Returns how much one fart changes the boat's velocity (studs/s) and its
-- turn speed (radians/s). Positive turn = the boat turns LEFT (counter-clockwise
-- seen from above), which is the same for every seat.
function FartPhysics.getKick(boatCFrame: CFrame, seatPos: Vector3, direction: Direction, power: number): (Vector3, number)
	local toCenter = (boatCFrame.Position - seatPos) * Vector3.new(1, 0, 1)
	if toCenter.Magnitude < 1e-3 then
		return Vector3.zero, 0
	end
	local facing = toCenter.Unit                 -- the player faces the middle
	local right = facing:Cross(Vector3.yAxis)    -- that player's right hand

	if direction == "Straight" then
		-- gas goes out behind the player, so the boat moves away from them
		return facing * Config.PUSH_SPEED * power, 0
	elseif direction == "Left" then
		-- outboard motor: shove our side right so the far side swings left
		return right * Config.PUSH_SPEED * Config.SIDE_PUSH * power, Config.SPIN_SPEED * power
	else
		return -right * Config.PUSH_SPEED * Config.SIDE_PUSH * power, -Config.SPIN_SPEED * power
	end
end

return FartPhysics
```

Check: with seats spaced evenly, all the `facing` directions add up to zero (everyone
Straight = no movement) and all the `right` directions add up to zero (everyone Left =
spin only). That's the behavior from section 2.3.

### 12.4 Server: checking and applying a fart

```lua
-- ServerScriptService/FartService.server.lua (excerpt)
FartRemote.OnServerEvent:Connect(function(player: Player, direction: any, heldTime: any)
	if direction ~= "Left" and direction ~= "Straight" and direction ~= "Right" then return end
	if typeof(heldTime) ~= "number" or heldTime ~= heldTime then return end -- reject NaN
	heldTime = math.clamp(heldTime, 0, Config.MEGA_CHARGE_TIME)

	local rider = Riders[player] -- { boat, seat: Attachment, gas, lastFart, pruneUntil, corked }
	if not rider or rider.corked then return end

	local now = os.clock()
	local cooldown = rider.pruneUntil > now and Config.TOOT_COOLDOWN / 2 or Config.TOOT_COOLDOWN
	if now - rider.lastFart < cooldown then return end

	local isMega = heldTime >= Config.MEGA_MIN_HOLD
	local cost = isMega and Config.MEGA_COST or Config.TOOT_COST
	if rider.gas < cost then
		FartFX:FireAllClients(player, "Dud") -- sad little pfft
		return
	end
	rider.gas -= cost
	rider.lastFart = now

	local charge = heldTime / Config.MEGA_CHARGE_TIME
	local power = if isMega then 1 + (Config.MEGA_MULT - 1) * charge else 1
	power *= FartCombos.register(rider.boat, player, isMega, now) -- 1.5 on a FARTQUAKE

	local boatType = BoatTypes[rider.boat:GetAttribute("BoatType")]
	local root = rider.boat.PrimaryPart
	local push, spin = FartPhysics.getKick(root.CFrame, rider.seat.WorldPosition, direction, power)
	root.AssemblyLinearVelocity += push * boatType.PushScale
	root.AssemblyAngularVelocity += Vector3.yAxis * spin * boatType.SpinScale

	FartFX:FireAllClients(player, direction, isMega, power)
	BoatSignals.Farted:Fire(rider.boat, player, direction, isMega) -- shark smell, plant gulps
end)
```

Changing velocity directly, instead of applying physical forces, means each boat's
feel comes only from `PushScale` and `SpinScale`. That's much easier to tune than
mass and inertia.

### 12.5 Server: float, drag and currents

```lua
-- ServerScriptService/WaterService.server.lua (excerpt)
local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Include
waterParams.FilterDescendantsInstances = { workspace.Course.Water } -- invisible surface parts

RunService.Heartbeat:Connect(function(dt)
	for boat in Boats do
		local root = boat.PrimaryPart
		local hit = workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), waterParams)
		if not hit then
			continue -- no water underneath: gravity takes over and the boat falls off the sky river
		end

		local v = root.AssemblyLinearVelocity
		local depth = (hit.Position.Y + Config.FLOAT_HEIGHT) - root.Position.Y
		-- spring the boat onto the surface and cancel gravity while it floats
		local vy = v.Y + (workspace.Gravity + depth * Config.FLOAT_STIFFNESS - v.Y * Config.FLOAT_DAMPING) * dt

		-- slow down toward the water's current (Vector3 attribute on the water part)
		local drag = math.exp(-Config.WATER_DRAG * dt)
		local current: Vector3 = hit.Instance:GetAttribute("Current") or Vector3.zero
		local flat = Vector3.new(v.X, 0, v.Z) * drag + current * (1 - drag)

		root.AssemblyLinearVelocity = Vector3.new(flat.X, vy, flat.Z)
		root.AssemblyAngularVelocity = Vector3.yAxis * root.AssemblyAngularVelocity.Y * math.exp(-Config.SPIN_DRAG * dt)
	end
end)
```

A kill plane below each island catches falling boats and calls
`CourseService.wipe(boat)`, which shows the RIP screen and respawns the team at the
checkpoint.

### 12.6 Tagged hazards

Level builders tag parts and set attributes. They don't write any code.

| Tag              | Attributes                                   |
| ---------------- | -------------------------------------------- |
| `Water`          | `Current: Vector3`, `Drag: number`, `Cold: boolean` |
| `Bonk`           | `AirDamage: number`, `Leak: boolean`, `Bounce: number` |
| `Whirlpool`      | `Pull: number`, `Spin: number`, `Radius: number` |
| `Geyser`         | `Interval: number`, `Launch: number`         |
| `Spores`         | `Duration: number`                           |
| `Checkpoint`     | `Island: number`, `Index: number`            |
| `Pickup`         | `Kind: string` (BeanCan, Chili, …)           |
| `KillZone`       | —                                            |

`HazardService` has one small handler per tag and connects them with
`CollectionService:GetInstanceAddedSignal`, so streamed-in parts work automatically.

### 12.7 Client input

```lua
-- StarterPlayerScripts/FartInput.client.lua (excerpt)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FartRemote = ReplicatedStorage.Remotes.Fart
local FartFX = require(script.Parent.FartFX)

local pressedAt: { [string]: number } = {}

local function onFart(actionName: string, state: Enum.UserInputState)
	local direction = string.sub(actionName, 5) -- "FartLeft" -> "Left"
	if state == Enum.UserInputState.Begin then
		pressedAt[direction] = os.clock()
		FartFX.startCharge(direction) -- red face and shaking if they keep holding
	elseif state == Enum.UserInputState.End and pressedAt[direction] then
		local held = os.clock() - pressedAt[direction]
		pressedAt[direction] = nil
		FartFX.playLocal(direction, held) -- instant feedback; server echo is skipped for us
		FartRemote:FireServer(direction, held)
	end
	return Enum.ContextActionResult.Sink
end

-- bound only while seated; unbound when the player leaves the boat
ContextActionService:BindAction("FartLeft", onFart, false, Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
ContextActionService:BindAction("FartStraight", onFart, false, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.Space, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("FartRight", onFart, false, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.E, Enum.KeyCode.ButtonR1)
```

On mobile, three big custom `ImageButton`s (bigger than the default touch buttons)
call the same `onFart` from `InputBegan` and `InputEnded`.

### 12.8 FX and sound

- Each seat has an `Attachment` with a `ParticleEmitter` (green cloud plus bubbles
  under the water) that does a burst on every fart. Megas burst more and larger.
- Use 20+ different fart sounds, picked at random with `PlaybackSpeed` between 0.85
  and 1.15, so it never sounds repetitive. Sound packs replace this folder. Only use
  sounds you made yourself or that are licensed on the Creator Store.
- Animations: Hang Idle, Toot (small butt pop), Mega Charge (shaking, red face),
  Mega Release (whole body jolt), Slap, Pull My Finger, Fall Off, Swim.
- Phones: cap particles per boat and skip the underwater bubbles on low graphics
  settings.

### 12.9 Analytics

- `AnalyticsService` funnel events for each checkpoint, to see where teams quit.
- Log where every death happens and make a heat map per island. Any spot with far
  more deaths than the rest needs fixing (most likely in Croak Swamp).

---

## 13. Starting tuning values (`Config.lua`)

| Setting               | Start value | Meaning                                                       |
| --------------------- | ----------- | ------------------------------------------------------------- |
| `PUSH_SPEED`          | 7 studs/s   | Speed added by one Straight toot (glides about 8 studs)        |
| `SIDE_PUSH`           | 0.45        | Sideways push from a Left/Right fart, compared to Straight     |
| `SPIN_SPEED`          | 0.55 rad/s  | Turn speed from one Left/Right toot (about 20° per toot; 4 players turn about 80°) |
| `TOOT_COOLDOWN`       | 0.35 s      | Time between toots                                            |
| `MEGA_MIN_HOLD`       | 0.3 s       | Hold at least this long to make it a Mega                     |
| `MEGA_CHARGE_TIME`    | 1.2 s       | Time to fully charge                                          |
| `MEGA_MULT`           | 3           | Full Mega = 3 toots of push                                   |
| `GAS_MAX`             | 100         |                                                               |
| `TOOT_COST`           | 8           |                                                               |
| `MEGA_COST`           | 35          |                                                               |
| `GAS_REGEN`           | 12 /s       | Always refilling. Nonstop tooting runs out in about 9 s       |
| `WATER_DRAG`          | 0.9 /s      | How fast the boat slows down                                  |
| `SPIN_DRAG`           | 1.6 /s      | How fast spinning stops                                       |
| `FLOAT_HEIGHT`        | 1.2 studs   | How high the ring sits above the water                        |
| `FLOAT_STIFFNESS`     | 60          | How strongly the boat snaps to the surface                    |
| `FLOAT_DAMPING`       | 8           | How quickly the bobbing stops                                 |
| `FARTQUAKE_WINDOW`    | 0.35 s      | How close together the Megas need to be                       |
| `FARTQUAKE_MULT`      | 1.5         |                                                               |
| `SLAP_COOLDOWN`       | 3 s         |                                                               |
| `PULL_FINGER_COOLDOWN`| 30 s        |                                                               |
| `AIR_MAX`             | 100         | Rock = −5, cannonball = −25 + leak, shark bite = −35          |

---

## 14. Roadmap

Boat Together launched with its main islands, then added the snow map and Galaxy
Island in a Winter Update and the Shark Boss in a later update. Doing it the same way
gets the game out sooner.

| Milestone                | What's in it                                                                                     | Done when                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| **M0 — Fun test**        | Grey-box Party Ring, 4 seats, 3-way toots, float and drag, Seat Cam, one test pond               | 4 friends can get through a gate on purpose and it's funny      |
| **M1 — Core loop**       | Gas, Mega, FARTQUAKE, FX and sounds, Air and leaks, death and respawn, checkpoints, Lazy Gut River in grey-box | Full run of island 1 with no bugs                |
| **M2 — Hub and boats**   | Bean Harbor, docks, seat pads, Solo/Double/Mega boats, Tutorial Pond, Parkour Tower, Slap, emotes, quick chat | New players learn without being told anything    |
| **M3 — Launch content**  | Croak Swamp, Funky Fungi, Venus Fart Trap, Stinkbeard's Cove, Golden Bean Island (shortened), Jet Toot | You can play start to end                              |
| **M4 — Launch polish**   | Art pass, saving, Beans, shop, badges, game passes, mobile and console testing, thumbnails and icon | **Public launch**                                            |
| **Update 1 — Winter**    | Frostbutt Fjord, Gassy Galaxy, winter skins, more emotes                                          | Winter event                                                    |
| **Update 2 — Shark**     | Jaws of Gas, new boat, full Golden Bean Island                                                    |                                                                 |
| **Later ideas**          | Race mode (teams race each other), speedrun timer, daily challenge river, level editor            |                                                                 |

**M0 is the most important step.** Build only the ring, the three farts and a pond.
If spinning and pushing with friends isn't funny in grey-box, change the numbers in
section 13 until it is, before building any islands.

The M0 prototype is in [`fart-to-steer/`](../../fart-to-steer/README.md) as a Rojo
project. Its README explains how to sync it into Roblox Studio.

---

## 15. Playtesting

- Test with real groups of 2, 4 and 8. Each boat size plays very differently.
- Watch for the moment players figure out "only the back pushes". If it takes more
  than about a minute, make the tutorial clearer.
- Track deaths per checkpoint. The frog section should be the hardest part, but no
  single spot should stop most teams.
- Try both cameras with people who get motion sick.

---

## 16. Risks and notes

- **Copying**: game mechanics and genre can't be owned, but Boat Together's name, art,
  models, music and exact level layouts can. Build your own levels and art and keep
  the fart theme. That also makes it stand out from the Roblox game already called
  "Boat Together".
- **Roblox content rules**: fart jokes count as crude humor. Fill in the Maturity &
  Compliance questionnaire honestly. Keep it cartoony: no poop, nothing below the belt
  beyond the butt.
- **Confusing directions**: covered by the Seat Cam, thrust preview and tutorial.
  Some confusion is part of the fun.
- **Lag**: covered by server physics plus instant local FX.
- **Griefing** with Slap: cooldown, and party leaders can turn it off.
- **Motion sickness**: Chase Cam option, and turn down camera shake in settings.

---

## 17. Decisions for you (my recommendation first)

1. **What does "Left" mean?** → *Turn the boat left* (recommended; makes "everyone
   Left = spin" work) or *push the boat to the left*.
2. **Default camera** → Seat Cam, with Chase Cam as an option.
3. **Seats** → players pick a seat pad at the dock, and anyone who doesn't gets one
   automatically.
4. **Do other teams' boats collide?** → No by default, with "Bumper Boats" as a
   private-server setting.
5. **Art style** → Sky rivers (Boat Together's original look).
6. **Mega Fart input** → Hold the same key (no fourth button).

---

## Sources

- [Boat Together on Steam](https://store.steampowered.com/app/3543890/Boat_Together/)
- [Boat Together achievements (Steam Community)](https://steamcommunity.com/stats/3543890/achievements)
- [Boat Together discussions (Steam Community)](https://steamcommunity.com/app/3543890/discussions/)
- [Boat Together community hub and update posts](https://steamcommunity.com/app/3543890)
- [Is It Done Yet? — Boat Together update history](https://isitdoneyet.gg/game/boat-together)
- [co-op.gg — Boat Together](https://www.co-op.gg/steam-deck/game/boat-together)
- [80.lv — preview article](https://80.lv/articles/don-t-sink-in-this-challenging-co-op-boating-game-made-with-ue)
- [RAWG — Boat Together](https://rawg.io/games/boat-together)
- [Roblox "Boat Together" (a separate Roblox game)](https://www.roblox.com/games/118579556148220/Boat-Together)
