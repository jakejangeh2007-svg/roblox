# Place scripts

The game's code, organized by the project conventions.

## Auto-sync with Rojo (recommended)

Claude pushes code changes to this branch on GitHub. On your PC, one terminal pulls them
every 10 seconds and Rojo copies them into Studio, so changes show up in your place
within about 10 seconds of being pushed.

Rojo only manages the **code** folders: `ReplicatedStorage.Shared`, `ReplicatedStorage.Packages`,
`ReplicatedStorage.UI`, `ServerScriptService.Server`, `ServerScriptService.Services`,
`ServerScriptService.Classes`, `ServerScriptService.TestKit` and `StarterPlayerScripts.Client`.
It makes sure `ReplicatedStorage.Assets` (with `Boats`, `VFX`, `Sounds.Farts`) and
`Workspace.Boats` exist, but never deletes or changes anything you build inside them.
Your map, models and UI are never touched.

**Don't edit the synced scripts in Studio.** Rojo overwrites them with the repo version. Tell
Claude what to change instead.

### One-time setup (Windows)

Use a normal PowerShell window, not "Run as administrator". Run one line at a time.

1. Install Git, then close PowerShell and open a new one:
   ```powershell
   winget install --id Git.Git -e --source winget
   ```
   (If `winget` isn't found, install Git from <https://git-scm.com/download/win> with the default options.)
2. Install Rokit, then close PowerShell and open a new one:
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
3. Check both worked: `git --version` and `rokit --version` should each print a version.
4. Download the code and install Rojo (if GitHub asks you to sign in, do it in the browser
   window that opens; when Rokit asks whether to trust Rojo, say yes):
   ```powershell
   cd ~
   git clone https://github.com/jakejangeh2007-svg/roblox.git
   cd roblox
   git checkout claude/determined-gates-6stlty
   cd place
   rokit install
   rojo plugin install
   ```
   If you already have the `roblox` folder from before, skip the clone: `cd ~\roblox`, then
   `git checkout claude/determined-gates-6stlty`, `git pull`, `cd place`, and carry on from `rokit install`.
5. Restart Roblox Studio so it loads the Rojo plugin.

### Every time you work on the game

1. **Terminal 1 (Rojo):**
   ```powershell
   cd ~\roblox\place
   rojo serve
   ```
   Make sure it's the `place` folder, not the old `fart-to-steer` one: Rojo should say it's
   serving **FartToSteerPlace**.
2. **Terminal 2 (auto-pull):**
   ```powershell
   cd ~\roblox
   while ($true) { git pull; Start-Sleep -Seconds 10 }
   ```
   It prints `Already up to date.` every 10 seconds, and a list of changed files when
   something new arrives. Any error shows up here too.
3. In Studio, open your place, then **Plugins → Rojo → Connect**. Accept the changes it lists.
4. Leave both terminals open. Close them (or press Ctrl+C) when you're done.

## Without Rojo: Command Bar installer

1. Open the place in Roblox Studio and close any open script tabs.
2. **View** tab → **Command Bar**.
3. Copy all of [`Install.luau`](Install.luau), paste it into the Command Bar and press Enter.
4. The Output window lists what it created (`+`) and updated (`~`).

The installer creates missing folders and scripts and replaces the code in existing
scripts. It never deletes anything and never touches models or parts. Ctrl+Z undoes it.

`Install.luau` is generated from the other `.luau` files in this folder. Each file is
one script; its first comment line says which instance. `X.server.luau` is a Script,
`X.client.luau` a LocalScript, `X/init.luau` is a script named X with the folder's
contents inside it, and anything else is a ModuleScript.

## Test kit (temporary)

To playtest before the real map, boats and menus exist:

1. With Rojo, the test kit (`ServerScriptService.TestKit`) is already synced. Without
   Rojo, run `Install.luau`, then paste [`TestKit/InstallTestKit.luau`](TestKit/InstallTestKit.luau)
   into the Command Bar.
2. Press **Play**. Every playtest now builds a grey-box test world at runtime (it's gone
   when you stop): a lobby and every checkpoint with docks, ponds joined by rivers
   without walls, currents, the finish, boat templates `Boat1`–`Boat6`, a fart cloud, a
   placeholder sound and a gas meter at the bottom of the screen. Your own
   `Workspace.Map` is set aside for the playtest,
   and your own boat templates, obstacle templates and effects are used if you've made them.
   - **A mock obstacle course** runs along the four rivers, built from plain blocks by
     `TestKit.MockCourse` through the real obstacle system (see *Obstacles*): swinging
     doors and spike balls, then slicing fan blades and a side fan, then a sliding gate
     and a patrolling spike ball, then a swinging mace, another side fan and more blades.
     Red parts pop your boat.
3. In the test world:
   - **E** at a dock's pier spawns a boat with that dock's number of seats (dock 1 = 1 seat).
   - Walk into a seat. The boat leaves after the 30 second timer, or press **F** next to
     it to start early (party leader only, sitting in the boat).
   - Fart with **W**, slide round the edge with **A / D** (or the arrow keys). Fall off a
     river, or hit something red, to test wiping.
   - **E** at the yellow posts on each platform teleports there, once unlocked.
   - Anything that didn't work is explained in Output, starting with `[TestKit]`.
4. Use **Test → Clients and Servers** with 2+ players to test together.

**When you're done testing:** with Rojo, ask Claude to remove the test kit from the project,
then delete `ServerScriptService.TestKit` in Studio. Without Rojo, just delete it.
Nothing else changes.
The test kit is the only code here that builds parts and prompts at runtime.

## Hierarchy

```
ReplicatedStorage
  Shared
    Services
      BoatService         BoatServiceClient, BoatServiceShared
      CameraService       CameraServiceClient
      CheckpointService   CheckpointServiceClient, CheckpointServiceShared
      DockService         DockServiceClient, DockServiceShared
      FartService         FartServiceClient, FartServiceShared, FartPhysics
      ObstacleService     ObstacleServiceShared
      RiderService        RiderServiceClient, RiderServiceShared, RiderSpots
    Classes
    Modules
      Core                Attributes, Remotes
      Game                BoatConfig, CameraConfig, CheckpointConfig, DataConfig, DockConfig,
                          FartConfig, ObstacleConfig, RiderConfig, WaterConfig
      Math                Cycle, Geometry
      Platform
  Assets                you build everything in here
    Boats                 boat templates
    Obstacles             obstacle templates (see Obstacles)
    VFX                   FartCloud (a ParticleEmitter)
    Sounds
      Farts               fart Sounds
  UI                      top-level UI initializer
    HUD
    Menus
  Packages                Signal, TableUtil

ServerScriptService
  Server                  startup script
  Services
    BoatService           BoatServiceServer
    CheckpointService     CheckpointServiceServer
    DataService           DataServiceServer
    DockService           DockServiceServer
    FartService           FartServiceServer
    ObstacleService       ObstacleServiceServer
    RiderService          RiderServiceServer
    WaterService          WaterServiceServer
  Classes                 Boat, Dock, Hull, Location
    Obstacles             ObstacleRig, Spinner, Swinger, Slider, WindFan

StarterPlayer.StarterPlayerScripts
  Client                  startup script

Workspace
  Map                     the map (you build this, see below)
  Boats                   empty; spawned boats go here
```

## How the game flow works

1. Players join in the **lobby**.
2. At one of the lobby's **docks**, a player uses the dock's prompt and picks a boat for
   1–6 players. The server checks the request: real dock, valid size, close enough,
   not on cooldown, dock free, checkpoint unlocked. Then it spawns the boat at the dock,
   with that player as its **party leader**.
3. A **`JOIN_TIME` timer** (30 seconds) starts. Players get in by sitting in a free seat,
   or by asking to join (the server checks they're close enough and a seat is free,
   then sits them down). Anyone can get up and join a different boat instead.
4. The boat leaves at the earliest of:
   - the **timer running out**, with whoever is aboard (empty seats are fine);
   - **every seat filling up**, after a `LAUNCH_DELAY` (3 second) countdown, which stops
     if someone gets up;
   - the **leader starting early** (they must be in the boat), after the same countdown.

   If nobody is aboard when it's time to leave, the boat is removed. Otherwise it moves
   to the location's **Launch** point in the river and starts **floating**. From then on
   nobody new can get in, and anyone who leaves goes back to their current checkpoint.
   - The leader can **pick a different boat size** before it leaves: the new boat
     replaces the old one, and everyone aboard moves into it (leader first, as far as the
     seats go). Each player leads at most one waiting boat.
   - If the leader **leaves the game**, someone aboard becomes leader. If nobody is
     aboard, the boat is removed.
5. On the river, players **fart and slide round the edge to steer** (controls below). The server checks every
   fart and spends gas. Every frame, **WaterService** moves each boat with its crew's
   farts, the water under it and the wind from any fans (see *How boats move*). A boat
   that **falls off** the river or is **popped** by a hazard freezes for `WIPE_DELAY`,
   then it's removed and its crew goes back to their checkpoint to spawn a new boat.
6. When a boat on the river enters a checkpoint's **Zone**, that checkpoint and every
   one before it are **unlocked** and saved for everyone aboard. From then on they
   respawn there.
7. Players can **teleport** to the lobby or any unlocked checkpoint. Each checkpoint
   has its own docks, so they can start a new boat from there.
8. A boat entering **Map.Finish** beats the game. It's saved, and after
   `FINISH_RETURN_DELAY` the crew is sent back to the lobby.

Every number is in the config modules in `ReplicatedStorage.Shared.Modules.Game`.

## Controls

| Action | Keyboard | Controller | What it does |
| ------ | -------- | ---------- | ------------ |
| Fart | `W`, `↑`, `Space` | `RT` | farts straight out behind you: pushes the boat the way you face |
| Slide left | `A`, `←`, `Q` | `LB`, left stick left | slides you left round the edge of the boat |
| Slide right | `D`, `→`, `E` | `RB`, left stick right | slides you right round the edge of the boat |

Riders **hang on to the outside of the raft**, arms over the side and legs kicking in the
water, facing its middle, and **fart straight off it**. A fart pushes the boat from where
you are toward its middle, so it moves the boat without spinning it. **To steer, slide
round the edge** to push from a different side: to go left, slide right round the boat
until you're on its right-hand side, then fart. The physics is real (see *How boats move*).

**Everyone gets their own stretch of the edge**, with blockers between them. The rim is
shared out evenly between the seats: from your seat, halfway to the next seat each way.
On a one-seat boat you can slide all the way round and push any way you like; on a
six-seat boat you only get a sixth of it, so the crew has to work together to go
anywhere. You slide at 10 studs/s (`RiderConfig.SLIDE_SPEED`), easing in and out and
easing into the blockers. The server decides where everyone is, but your own slide shows
the moment you press (your game runs the same rules and settles onto the server's answer
when you stop), and other riders glide smoothly.

| Boat | Your stretch of the edge (test kit boats) |
| ---- | ---- |
| 1 seat | all the way round (33 studs) |
| 2 seats | 157°, about 17 studs |
| 3 seats | 100°, about 12 studs |
| 4 seats | 72°, about 10 studs |
| 5 seats | 56°, about 9 studs |
| 6 seats | 45°, about 8 studs |

**Hold the fart key to keep farting.** A fart starts at 18 studs/s² and builds up by 10
every second you keep going, up to 36 (on a boat weighing `FartConfig.REFERENCE_MASS`;
heavier boats speed up slower). Letting go stops, but the built-up strength fades out
instead of resetting (3 times as fast as it built up), so a quick re-press picks up close
to where you left off. A fart's push swells in and trails off in under a tenth of a
second (`PUSH_RESPONSE_TIME`). You can slide while you fart.

**Gas** drains at a flat 10 per second while you fart, however long you've been going, so a full tank
(100) lasts 10 seconds. It refills at 15 per second while you're not farting. When it runs
out you stop; let go and press again once there's gas. All of these numbers are in `FartConfig`.

Riders on opposite sides farting at once cancel out.

**Seat Cam:** on the river the camera sits behind you and follows you as you slide, so
farting always pushes the boat up your screen. It bobs gently with the boat and shakes on
hard bumps and splashes.
`V` (or `Y` on a controller) switches to the normal camera.
Touch devices need on-screen buttons, which are UI, so they come with the menus.

## How boats move

One thing moves a boat on the river: its **Hull** (`ServerScriptService.Classes.Hull`),
which WaterService steps every frame on the server. It treats the boat as a real rigid
body and works out its whole motion in one go, so nothing fights over it and there are
no hard speed caps:

- **Farts** are forces from where the riders hang on, toward the middle of the boat.
  Together they speed the boat up by force ÷ mass and spin it by torque ÷ moment of
  inertia (pushes toward the middle hardly spin it; bumps and rapids do). The mass and
  the moment of inertia come from the boat's actual parts plus its riders, so **big,
  heavy boats are slower to get going and to spin**, and a boat is lighter once a rider
  leaves.
- **Water drag** pulls its speed toward the water's own speed. It's gentle at low speed,
  so a boat glides on for a few seconds after the crew stops, and grows with speed, so a
  boat levels off smoothly at its top speed: one rider at full strength cruises a boat of
  `REFERENCE_MASS` at about 27 studs/s (`WaterConfig.TOP_SPEED`). The same drag acting
  round the rim slows its spinning, times `WaterConfig.SPIN_DRAG_SCALE` (raise it for less
  spin from bumps and rapids).
- **Currents** carry it along, and **rapids** shove and twist it around at random.
- **Wind** from side fans pushes it through its middle (see *Obstacles*), harder on
  lighter boats; the crew can fart against it.
- **Buoyancy** holds it at the surface like a soft spring: it bobs on gentle **waves**,
  and a boat that drops in plunges, then settles in about 2 seconds without bouncing
  back out. Off the water, only gravity, a little air drag and the farts act on it.
- It **rocks** with the waves and **leans** away from the way it's speeding up, turning or
  bumping into things, then rights itself.
- Riders weigh what they weigh, but they don't bump into anything while they ride, so
  only the hull touches the world. The hull is slippery and a little bouncy, so it
  glances off rocks and banks.

With the test kit's boats and one rider farting:

| Boat | Weight (boat + rider) | Speed after 1 s / 3 s |
| ---- | ---- | ---- |
| 1 seat | 74 + 14 | 15 / 27 studs/s |
| 2 seats | 97 + 14 | 12 / 23 |
| 3 seats | 121 + 14 | 10 / 20 |
| 4 seats | 146 + 14 | 9 / 18 |
| 5 seats | 173 + 14 | 8 / 16 |
| 6 seats | 200 + 14 | 7 / 15 |

To make a boat nimbler or heavier, change its parts (their size and Material set how
much they weigh). Fart strength is in `FartConfig`; water feel (drag, spin drag, bobbing,
waves, rapids) is in `WaterConfig`; leaning and the hull's bounce are in `BoatConfig`.

The server runs boat physics, so in a live game there's a small delay (your ping)
between pressing a key and seeing the boat react. Your own fart effects start instantly.

## Building the map

Build everything by hand. The names below are what the code looks for; anything
else (decoration, water, walls) can be called anything. Missing pieces don't break
the game: they show as `Map piece missing: ...` warnings in Output.

```
Workspace
  Map (Folder)
    Lobby (Folder)
      Spawn            Part      where players appear (put it on the lobby floor)
      Launch           Part      where boats from the lobby docks appear in the river
      Docks (Folder)
        Dock1 (Model)            any name; one Model per dock
          BoatSpawn    Part      where the spawned boat waits; the boat takes its position and rotation
          ...          any parts for the dock itself
          SpawnBoatPrompt  ProximityPrompt   inside any part of the dock
        Dock2 ... Dock5
    Checkpoints (Folder)
      Checkpoint1 (Folder)       name must match an Id in CheckpointConfig.CHECKPOINTS
        Zone           Part      a boat whose middle is inside this has reached the checkpoint
        Spawn          Part      where players appear (teleports and respawns)
        Launch         Part      where boats from these docks appear in the river
        Docks (Folder)           same as the lobby's
      Checkpoint2 ...
    Finish             Part      a boat whose middle is inside this has beaten the game
    Water (Folder)               every water surface part on the river
      ...              Parts     the TOP face is the water surface; any other name is calm water
      Current          Part      named after an entry in WaterConfig.WATER_TYPES: flows toward its front face
      Rapids           Part      the same, faster, choppier and rough
    Obstacles (Folder)           every obstacle, or a marker for one (see Obstacles)
```

- Make `Spawn`, `Launch`, `Zone`, `BoatSpawn` and `Finish` **Anchored**, **CanCollide off**
  and **Transparency 1** (they're markers, not things to stand on).
- Make `Zone` and `Finish` big enough to cover the whole river, so a boat can't miss them.
- Make water parts **Anchored** and **CanCollide off**. Boats float wherever there's a water
  part underneath and fall where there isn't, so rivers without walls can be fallen off.
- To make water flow, name the part after an entry in `WaterConfig.WATER_TYPES`
  (`Current` or `Rapids` to start with) and turn it so its front face points downstream.
  Each type sets its flow speed, how big its waves are and how rough it is. Add more
  types there.
- Don't stack water parts within 8 studs of each other vertically (one surface above
  another): boats look for the water from 8 studs above them to 8 below.
- Put each `Launch` part at water level, over a water part.
- The checkpoints and their order live in `CheckpointConfig.CHECKPOINTS`. The three
  there now are placeholders: edit the list to match the map.

## Obstacles

Obstacles are built by hand (or from templates) and run by **ObstacleService** on the
server. The moving ones are driven by physics constraints the server runs, so they shove
boats properly, nothing can stop them, and they move smoothly for every player. Their
moving parts hit boats but pass through the map, riders and each other.

| Kind | What it does | For example |
| ---- | ------------ | ----------- |
| `Spinner` | turns round and round | fan blades slicing the water, spinning spike arms |
| `Swinger` | swings between two angles on a hinge, waiting at each end | swinging doors, a swinging mace |
| `Slider` | slides back and forth along a line, waiting at each end | gates that open and close, a patrolling spike ball |
| `WindFan` | blows boats in its wind zone sideways, on and off | a big fan at the side of the river |
| Hazard | any part with attribute `Hazard` = true pops a boat that touches it | spikes, blades |

**Building one:** make a Model in `Workspace.Map.Obstacles` (Folders inside are fine) with
the attribute `Obstacle` set to the kind, and these parts:

```
<any name> (Model, attribute Obstacle = "Spinner" | "Swinger" | "Slider" | "WindFan")
  Base     Part   the fixed part. Spinners, Swingers and WindFans turn around the line
                  through its middle along its front face; Sliders slide along its front face.
  Moving   Part   the part that moves. Weld everything else that moves to it (WeldConstraints).
                  Anchoring doesn't matter: the code sets it.
  Wind     Part   WindFan only: the zone that blows; boats in it are pushed toward its front
                  face. CanCollide off, see-through. (A WindFan's Base and Moving are optional:
                  they're its spinning fan.)
  ...             anything else is scenery and stays put.
```

Mark any part (in an obstacle or anywhere else in the map) with the attribute `Hazard` =
true to make it pop boats. A WindFan switches on any ParticleEmitters, Beams and Sounds
inside it while it blows, spins its fan, and sets its `Blowing` attribute for clients.

**Settings** are attributes on the Model; anything not set uses the default in
`ObstacleConfig`. Times are in seconds.

| Kind | Attributes (defaults) |
| ---- | --------------------- |
| `Spinner` | `Speed` turns a minute, negative turns the other way (12) |
| `Swinger` | `FromAngle`, `ToAngle` degrees from how it was built (0, 90), `MoveTime` (1.2), `HoldTime` at each end (1.5), `StartDelay` (0) |
| `Slider` | `Distance` studs toward Base's front face (10), `MoveTime` (1), `HoldTime` at each end (2), `StartDelay` (0) |
| `WindFan` | `Strength` push in studs/s² on a boat of `REFERENCE_MASS` (28), `OnTime` (3), `OffTime` (3), `StartDelay` (0), `Speed` of its fan (120) |

Everything runs off the server clock, so `StartDelay` staggers obstacles of the same kind.

**Templates:** to place the same obstacle many times, build it once as a Model in
**`ReplicatedStorage.Assets.Obstacles`**, and in the map put a **marker** (any Part or
Model) with the attribute `ObstacleTemplate` = the template's name. At startup each marker
is swapped for a copy of the template, with the template's pivot on the marker's pivot.
Any other attributes on the marker (like `StartDelay` or `Speed`) override the template's,
so each copy can be tuned. Swap a template's art and every copy updates. The test kit's
mock course is built this way: its templates are `SwingingDoor`, `SlidingGate`,
`FanBlades`, `SpikeBall`, `PatrolSpikeBall`, `SwingingMace` and `SideFan`. Make real
models with those names in `Assets.Obstacles` and the course uses them instead.

Output warns about any obstacle that's missing a part or has a setting of the wrong type,
and any marker whose template doesn't exist.

## Building the boats

Put one Model per size in **`ReplicatedStorage.Assets.Boats`**, named as in
`BoatConfig.TEMPLATE_NAMES` (`Boat1` … `Boat6` by default):

- Set the Model's **PrimaryPart** to a flat part in the middle of the boat, at the height
  the water should come up to, top face up. It can be invisible. Boats float with this
  part at the water surface.
- Weld every other part, Seats included, to it with **WeldConstraints** (directly or through
  other welded parts). Anchoring doesn't matter: the code sets it.
- Put in exactly as many **Seat** objects as the size (`Boat3` has 3 Seats). A seat is
  where a rider **holds on**: put them on the rim, spread evenly around the edge, facing
  the middle. Riders don't sit on them; they hang outside them, at `RiderConfig.HANG_OFFSET`
  from the seat (a little below and outward). Change that offset if riders end up too
  high, too low, or inside the hull.
- Each rider slides round a circle about the PrimaryPart, from their seat halfway to the
  next seat each way, so make the boat round. Add **blockers** between the stretches if you
  like (any parts welded on, like the test kit's dark fins); the code stops riders there
  either way.
- No scripts inside.
- Every part's friction and bounciness is set by the code (`BoatConfig.HULL_...`); its
  density (from its Material) is kept. What the parts weigh, and how far out they sit,
  decides how quickly the boat gets going and spins (see *How boats move*). Make the hull the parts that should touch rocks
  and banks; riders never touch anything.

Output warns at startup about any template that's missing or doesn't follow these rules.

## Fart effects

- **`ReplicatedStorage.Assets.VFX.FartCloud`:** a ParticleEmitter for the gas cloud. Set
  its Texture, Color, Size and so on however you like. While someone farts, its Rate
  (`FartConfig.MIN_PARTICLE_RATE` to `MAX_PARTICLE_RATE`) and Speed grow with the
  fart's strength.
- **`ReplicatedStorage.Assets.Sounds.Farts`:** a Folder of fart Sounds from the Creator
  Store. Each fart loops a random one, and its pitch and volume rise with its strength.
  Switching direction keeps the same sound going. Sounds that loop smoothly work best.

Without them farts still work, just invisible or silent, and Output warns once.

The gas comes out of each rider's butt (`FartConfig.BUTT_OFFSET`; set the emitter's
EmissionDirection to Back), straight out behind them, off the raft.

**Rider pose:** RiderService poses every rider in code (arms over the side, going hand
over hand as they slide, legs kicking), so it needs no animation assets and works for R15
and R6. Its angles are in `RiderConfig`.

## For the UI (to be built by hand)

The client halves have everything the menus need:

| What | Use |
| ---- | --- |
| Boat-size menu opens | `DockServiceClient.DockSelected` fires `(dock)` when the player uses a dock prompt |
| Spawn the picked size | `DockServiceClient:RequestSpawnBoat(dock, seatCount)` → `(success, message)` |
| Join button | `BoatServiceClient:RequestJoinBoat(boatModel)` → `(success, message)` |
| Leader's Start button | show it when `BoatServiceClient:IsLeaderOf(boatModel)`; call `BoatServiceClient:RequestStartRun()` → `(success, message)` |
| Departure timer | `BoatServiceClient:GetSecondsUntilDeparture(boatModel)` (from the boat model's `DepartureTime` attribute) |
| Who's leading | the boat model's `LeaderUserId` attribute |
| Teleport menu list | `CheckpointConfig.CHECKPOINTS` plus `CheckpointServiceClient:GetUnlockedCheckpointIds()` |
| Teleport | `CheckpointServiceClient:RequestTeleport(id)` → `(success, message)`; the lobby's id is `CheckpointConfig.LOBBY_ID` |
| List changed | `CheckpointServiceClient.UnlockedCheckpointsChanged` |
| "Checkpoint reached" / "You win" | `CheckpointServiceClient.CheckpointReached`, `CheckpointServiceClient.GameCompleted` |
| Gas meter | done: `UI.HUD.GasMeter` smoothly fills `StarterGui.HUD.GasMeter.Fill` (a Frame whose width shows the gas left). Build that by hand when you make the real HUD; the test kit makes a stand-in until then |
| Touch fart button | call `FartServiceClient:PressFart()` on press and `FartServiceClient:ReleaseFart()` on release |
| Touch slide buttons | call `RiderServiceClient:PressSlide("Left")` (or `"Right"`) on press and `RiderServiceClient:ReleaseSlide("Left")` (or `"Right"`) on release |
| Farting on and off (e.g. button glow) | `FartServiceClient.FartStarted` and `FartStopped` |
| RIP screen | `BoatServiceClient.BoatWiped` fires with why: `"Fell"` off the river or `"Popped"` by a hazard |
| A fan is blowing (e.g. a warning) | the WindFan Model's `Blowing` attribute |

## Saving

Progress (unlocked checkpoints, whether the game was beaten) saves with DataStores.
To test saving in Studio, publish the place and turn on **Game Settings → Security →
Enable Studio Access to API Services**. Without it, the game works but nothing saves.
