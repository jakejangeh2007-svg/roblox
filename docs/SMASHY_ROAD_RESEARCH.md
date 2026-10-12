# Smashy Road Series — Gameplay Research

Reference notes on how Bearbit Studios' *Smashy Road* games play, so we can design an
**original** police-chase game with a similar feel. This is a study of mechanics only.
No code, art, audio, names or vehicle designs from the real games are used or wanted.

> **Sourcing.** The games are closed-source, so everything here comes from public
> material: store listings, fan wikis, guides and reviews (see [Sources](#sources)).
> Fan sources often mix up the different games and versions. Numbers marked
> **(unverified)** conflict between sources or come from a single one.

---

## 1. The series at a glance

| Game | Year | One-line summary |
| ---- | ---- | ---------------- |
| Smashy Road | 2014 | Auto-scrolling single straight road. Dodge traffic and police, collect coins, buy cars. |
| **Smashy Road: Wanted** | 2015 | The big one. Free-roam procedural world, a wanted level that climbs, a slot machine for unlocking cars. |
| Smashy Road: Arena | 2016 | *Wanted* plus online multiplayer, weapons, 8 themed environments, up to 7 wanted levels. |
| **Smashy Road: Wanted 2** | 2018 (Switch 2021) | Full sandbox. You can get out on foot and steal any car. Adds missions, airdropped power-ups and secret events. |

All of them are mobile-first, with blocky voxel-style art, a high angled chase camera
looking down at the car, and very short runs (often under a minute).

---

## 2. Core loop (Wanted / Wanted 2)

```
Spawn in car ─► police start chasing ─► survive, smash scenery, grab cash
      ▲                                              │
      │                       heat rises over time, tougher pursuers arrive
      │                                              │
 spend cash on ◄── run ends (BUSTED or WASTED) ◄─────┘
 slot-machine spins → new vehicle
```

- There's no finish line. The only goal is to **survive as long as possible** and beat
  your high score.
- Each run is short, intense and different every time, because the world is procedurally
  generated.
- Between runs, cash from pickups goes into a random unlock. That's the "one more go" hook.

---

## 3. Controls & driving feel

- **Two-input steering.** Tap or hold the left half of the screen to steer left, the right
  half to steer right. On keyboard ports that's A/D or the arrow keys.
- **The car accelerates on its own.** You don't control speed, you only steer. Some ports
  add reverse on the down key **(unverified)**.
- **Physics are arcadey and floppy.** Cars bounce, spin out, catch air off ramps and can
  **flip over**, which ends the run.
- **Each vehicle handles differently.** Some are fast but fragile, others slow but tanky,
  and heavy vehicles plough through scenery.
- **Breakable scenery doesn't slow you down.** Trees, light poles, fences and bushes shatter
  on impact without costing speed, and they add score. Other cars and trucks are solid and
  *do* slow you down.
- **Steering is twitchy on purpose.** Reviewers complain that runs end fast because steering
  is sensitive and cars die in 2–3 hits. That fragility is part of the appeal.

---

## 4. Wanted level (heat) — the escalation system

Heat is the backbone of the game. It rises on its own as your score climbs, and each new
level adds more pursuers and tougher ones.

### Smashy Road: Wanted (6 levels, shown as police lights/stars)

| Level | Triggered at score | What's added |
| ----- | ------------------ | ------------ |
| 1 | start | 2 police cars |
| 2 | 30 | more police cars, police helicopter (spotter), roadblocks |
| 3 | 80 | SWAT vans/jeeps (heavier, more durable), roadblocks upgrade |
| 4 | 150 | more SWAT; some sources put military Humvees here **(unverified)** |
| 5 | 250 | Army: military jeeps/Humvees (can kill you in one hit), army helicopter |
| 6 | 400+ | **Tanks** that fire explosive shells, the toughest ground enemy |

Arena adds a 7th level with tank barricades **(unverified)**.

### Smashy Road: Wanted 2 ("sirens", score-rate based)

- Score goes up by **points per second**, and the rate climbs with heat: about 1/s at
  siren 1, 2/s at siren 2, 10/s around siren 6. The rate tops out at 50/s once your score
  reaches about 4,500.
- The roster ramps the same way: police cars, then SUVs and roadblocks, special agents and
  their helicopter, then the army (Humvees with mounted guns, **landmines**, a helicopter
  dropping armed soldiers, **military boats** on water), then tanks.
- **Siren 10 sets off an "alien invasion"** event. The siren icons change to alien heads,
  most military units are replaced by alien forces, and it unlocks a secret driver.

### What makes the escalation work

1. **Readable, discrete steps.** You always know your heat level, and each step up is a
   visible event.
2. **New enemy types, not just more of them.** Each level changes how you have to drive:
   - roadblocks mean you pick a different route
   - helicopters mean you can't hide
   - tanks mean you zig-zag to dodge shells
   - landmines mean you watch the ground
3. **One-hit-kill threats show up late,** so early game is a forgiving warm-up.

---

## 5. Pursuer AI (as players describe it)

- The cops are **not smart**. They steer straight at you and ram. That's exploitable: weave
  around buildings and the cops get stuck or pile into each other.
- **Cop-on-cop collisions destroy cops,** and every enemy destroyed is worth score (30 pts
  in *Wanted*).
- Standing still or getting boxed in gets you **arrested ("BUSTED")**. Keeping moving and
  staying in open space is the core survival skill.
- In *Wanted 2*, cops **get out of their cars** and run at you. If one reaches your car,
  you're arrested.
- Tanks and armed helicopters fire projectiles, so you have to **zig-zag** to dodge them.

---

## 6. Scoring

| Source | Points |
| ------ | ------ |
| Survival time | +1 per second in *Wanted*; a ramping rate in *Wanted 2* |
| Smashing scenery (bush, tree, pole, fence) | small bonus each (5 per bush **(unverified)**) |
| Destroying an enemy | 30 (*Wanted*) |
| Stunts / missions (*Wanted 2*) | e.g. ~150 for a flip off a ramp |

Score also **drives heat** in *Wanted*. Playing aggressively (smashing stuff, wrecking cops)
makes the game harder faster. That's a nice risk/reward loop.

---

## 7. Damage & losing

- **WASTED:** the car's durability (health) hits 0. Durability varies per vehicle.
- **BUSTED:** you stay close to police for too long (they pin you), or, in *Wanted 2*, a cop
  on foot reaches your car.
- **Water:** instant death in *Wanted*. In *Wanted 2* your character can swim out.
- **Flipping over** ends the run.
- *Wanted 2* only:
  - your character has **hearts**. If your car is destroyed and you bail out, you keep
    playing on foot until the hearts run out.
  - **camping** in one small area for too long is penalised (it counts as a loss).

---

## 8. World

- **Procedurally generated** every run, made of tiles/chunks streamed around the player.
- **Biomes** in *Wanted*: City, Grassland/countryside, Desert. *Arena* adds 8 themed
  environments (western town, snow village, candy land, lava land, medieval, …). *Wanted 2*
  has country-themed maps (USA, UK, Middle East, Japan, Netherlands, Iceland) with local
  landmarks.
- **Hazards and features:**
  - water/lakes
  - ramps, cliffs and tunnels that launch you
  - traffic
  - breakable props everywhere
- **Secret areas** with big rewards are scattered through the world. They give you a reason
  to explore instead of only fleeing.
- **Cash pickups** lie around the map, so collecting them pulls you into risky routes.

---

## 9. Meta progression & economy

- **Cash** is collected during runs. A **slot machine / prize machine** costs 100 cash per
  spin and gives you a random vehicle. Paid upgrades reduce the cost to 50 or 25.
- **Rarity tiers:** Common, Rare, Epic, Legendary.
- **Mystery vehicles** can't be won from the slot machine. You unlock them by doing
  something special in the world. Examples from *Wanted 2*:
  - collect 10 letters scattered across runs
  - run over 40 zombies in 50 seconds near a "corrupted" building
  - find the carnival and drive the clown car
  - rob the bank: get in a cop car, then chase and wreck a cash truck before the timer runs out
  - fire truck: put out 6 fires in 60 seconds
  - win a race on a hidden race track
  - find the military base and steal the tank
- **Cosmetics:** free recolouring. *Wanted 2* adds unlockable characters/drivers.
- **Roster size:** *Wanted* ~30+ vehicles. *Wanted 2* claims 60–90 vehicles, 12–16 mystery
  vehicles and ~60 characters (sources conflict).

---

## 10. What *Wanted 2* added over *Wanted*

1. **On-foot play.** Get out of your car, run, and **steal any vehicle**, including empty
   police cars (but not occupied ones).
2. **Cops on foot** who can arrest you by reaching your car.
3. **Supply helicopter airdrops.** A friendly helicopter drops crates containing power-ups,
   tiered Common to Legendary:
   - extra heart, more durability, running speed, vehicle speed
   - at Legendary: a **jetpack** or a **gravity gun**

   You can hold at most **2 power-ups**. Later drops stack onto the ones you already have.
4. **Missions and secret events** woven into the open world (see §9). Most of them unlock
   mystery vehicles.
5. **Character health (hearts)**, separate from vehicle durability.
6. **More heat levels** (10, ending in the alien invasion), plus military boats, landmines
   and soldier drops.
7. **Per-vehicle upgrades** (paid "toolboxes") and free colour customisation.
8. **Themed world maps** with landmarks.

*Arena*'s distinguishing features were **online multiplayer**, **10 unlockable weapons**
mounted on cars, and **online leaderboards**.

---

## 11. Design takeaways — why it's fun

1. **Instant start, instant restart.** You're in a chase within a second of tapping.
2. **One verb.** Steering is the only skill, so it's easy to learn and hard to master.
3. **Escalation does the pacing.** Heat levels give every run a rising curve: calm, then
   tense, then chaos.
4. **Physics comedy.** Floppy crashes, pile-ups and flips are fun to watch even when you lose.
5. **Smashing is rewarded.** Scenery is satisfying to break and gives score, which pushes
   you to play aggressively.
6. **The world is the puzzle.** Buildings, water and ramps are what you use to shake the cops.
7. **Collection meta.** Random unlocks plus secret mystery vehicles give long-term goals.
8. **Secrets and missions** (*Wanted 2*) reward curiosity, not just survival.

---

## 12. Keeping our version original

Mechanics aren't protected, but expression is. To stay clearly on our own side:

- **Our own name, logo, UI and sounds.** Nothing called "Smashy", no copied siren icons or
  "BUSTED/WASTED" screens.
- **Our own vehicle and character designs.** No recreations of their specific cars, mystery
  vehicles or drivers.
- **Our own missions, secrets, maps and enemy lineup.** Use the *idea* of escalating
  pursuers and hidden unlocks, but with different content and numbers.
- **Never use extracted assets or decompiled code** from the real games.

---

## 13. Fit with this codebase

This repo already has a mobile-first Three.js voxel engine. A lot of it maps directly onto
a chase game:

| Need | Existing piece we can build on |
| ---- | ------------------------------ |
| Infinite procedural world | `ChunkManager` + `genWorker` (worker-based chunk streaming, biomes via noise) |
| Mobile rendering at 60 fps | `core/Engine.ts`, chunk mesher/material |
| Touch input | `input/TouchControls.ts` (would become left/right-half steering) |
| Persistence (unlocks, high score) | `storage/Database.ts` (IndexedDB) |
| Day/night, lighting | `sim/DayNight.ts`, voxel light |

What would be new:
- vehicle physics (arcade raycast-wheel car or simplified rigid body)
- a road/city tile generator on top of the terrain
- pursuit AI and the heat director
- breakable props and pickups
- a chase camera
- run/score UI
- an unlock screen

---

## 14. Open questions (can't verify without playing)

- Exact durability values and per-vehicle stats (speed, turn rate, mass).
- Exact heat thresholds for *Wanted 2* (only partial numbers were found).
- How "busted" timing works (how long you can stay boxed in before arrest).
- Spawn distances and spawn rates for pursuers at each heat level.

These are tuning numbers we'd pick ourselves anyway, by playtesting.

---

## Sources

- Smashy Road fan wiki: [Gameplay](https://smashy-road.fandom.com/wiki/Gameplay), [Enemies](https://smashy-road.fandom.com/wiki/Enemies), [Wanted Level](https://smashy-road.fandom.com/wiki/Wanted_Level), [Score](https://smashy-road.fandom.com/wiki/Score), [Losing the game](https://smashy-road.fandom.com/wiki/Losing_the_game), [Airdrop](https://smashy-road.fandom.com/wiki/Airdrop), [Slot machine](https://smashy-road.fandom.com/wiki/Slot_machine), [Cars](https://smashy-road.fandom.com/wiki/Cars), [Smashy Road Wanted 2](https://smashy-road.fandom.com/wiki/Smashy_Road_Wanted_2), [SRW 2 Mystery Vehicles](https://smashy-road.fandom.com/wiki/Smashy_Road_Wanted_2_Mystery_Vehicles), [SRW 2 Missions](https://smashy-road.fandom.com/wiki/SRW_2_Missions)
- Smashy Road Wanted wiki: [Wanted stars](https://smashyroadwanted.fandom.com/wiki/Wanted_stars), [Police Car](https://smashyroadwanted.fandom.com/wiki/Police_Car)
- NamuWiki: [Smashy Road: Wanted](https://en.namu.wiki/w/Smashy%20Road:%20Wanted), [Smashy Road: Wanted 2](https://en.namu.wiki/w/Smashy%20Road:%20Wanted%202)
- [TV Tropes — Smashy Road](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/SmashyRoad)
- Store listings: [Wanted (App Store)](https://apps.apple.com/us/app/smashy-road-wanted/id1020119327), [Wanted (Google Play)](https://play.google.com/store/apps/details?id=com.rkgames.smashywanted&hl=en_US), [Wanted 2 (App Store)](https://apps.apple.com/us/app/smashy-road-wanted-2/id1371501878), [Arena (App Store)](https://apps.apple.com/app/id1073476012), [Wanted 2 (Nintendo)](https://www.nintendo.com/us/store/products/smashy-road-wanted-2-switch/)
- Guides & reviews: [Level Winner — Wanted guide](https://www.levelwinner.com/smashy-road-wanted-ultimate-guide-10-tips-tricks-cheats-for-all-occasions/), [Level Winner — Wanted 2 guide](https://www.levelwinner.com/smashy-road-wanted-2-guide-tips-cheats-tricks-to-survive-longer-and-get-a-high-score/), [Touch Tap Play — Wanted 2 guide](https://www.touchtapplay.com/smashy-road-wanted-2-guide-tips-cheats-to-escape-the-police/), [Prima Games tips](https://primagames.com/tips/smashy-road-wanted-tips-and-tricks), [148Apps guide](https://www.148apps.com/wanted/smashy-road-guide-tips-and-tricks-to-help-you-outwit-the-law/), [Supercheats — Wanted Level](https://www.supercheats.com/iphoneipad/smashy-road-wanted/7987/wanted-level), [ChapterCheats — Wanted 2](https://www.chaptercheats.com/cheats/iphone-ipod/488486/smashy-road-wanted-2-cheat-codes), [TimesLive — Wanted 2 review](https://www.timeslive.co.za/news/gamers-live/2021-08-16-game-review-smashy-road-wanted-2-drive-till-you-die/), [GamingOnPhone — Wanted 2 review](https://gamingonphone.com/reviews/smashy-road-wanted-2-review/)
