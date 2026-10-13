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
   without walls, currents, rocks, the finish, boat templates `Boat1`–`Boat6`, a fart
   cloud, a placeholder sound and a gas meter at the bottom of the screen. Your own
   `Workspace.Map` is set aside for the playtest,
   and your own boat templates and effects are used if you've made them.
3. In the test world:
   - **E** at a dock's pier spawns a boat with that dock's number of seats (dock 1 = 1 seat).
   - Walk into a seat. The boat leaves after the 30 second timer, or press **F** next to
     it to start early (party leader only, sitting in the boat).
   - Fart with **A / W / D** (or the arrow keys). Fall off a river to test wiping.
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
    Classes
    Modules
      Core                Remotes
      Game                BoatConfig, CameraConfig, CheckpointConfig, DataConfig,
                          DockConfig, FartConfig, WaterConfig
      Math                Geometry
      Platform
  Assets                you build everything in here
    Boats                 boat templates
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
    WaterService          WaterServiceServer
  Classes                 Boat, Dock, Location

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
5. On the river, players **fart to steer** (controls below). The server checks every
   fart, spends gas and pushes the boat. **WaterService** keeps boats on the water
   surface, slows them down and pushes them along currents. A boat that **falls off**
   the river freezes for `WIPE_DELAY`, then it's removed and its crew goes back to
   their checkpoint to spawn a new boat.
6. When a boat on the river enters a checkpoint's **Zone**, that checkpoint and every
   one before it are **unlocked** and saved for everyone aboard. From then on they
   respawn there.
7. Players can **teleport** to the lobby or any unlocked checkpoint. Each checkpoint
   has its own docks, so they can start a new boat from there.
8. A boat entering **Map.Finish** beats the game. It's saved, and after
   `FINISH_RETURN_DELAY` the crew is sent back to the lobby.

Every number is in the config modules in `ReplicatedStorage.Shared.Modules.Game`.

## Fart controls

| Fart | Keyboard | Controller | What it does |
| ---- | -------- | ---------- | ------------ |
| Left | `A`, `←`, `Q` | `LB` | turns the boat left (the same way from every seat) |
| Straight | `W`, `↑`, `Space` | `RT` | pushes the boat away from you |
| Right | `D`, `→`, `E` | `RB` | turns the boat right |

**Hold a key to keep farting.** A fart speeds the boat up at a set acceleration
(18 studs/s² to start) that grows by a set amount every second you keep going (+12 per
second), up to 45. Turning works the same way. Farting can't push a boat past a top speed
of 30 studs/s or a top turn speed of about 140° a second. Letting go stops, and the next
fart starts from the beginning again. If you hold two keys, the one you pressed last wins.

**Gas** drains at a flat 10 per second while you fart, however long you've been going, so a full tank
(100) lasts 10 seconds. It refills at 15 per second while you're not farting. When it runs
out you stop; let go and press again once there's gas. All of these numbers are in `FartConfig`.

Everyone farting Straight cancels out; everyone farting Left spins the boat on the spot.

**Seat Cam:** on the river the camera sits behind your seat, so Straight always pushes
up your screen. `V` (or `Y` on a controller) switches to the normal camera.
Touch devices need on-screen buttons, which are UI, so they come with the menus.

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
    Water (Folder)               every water surface part on the river, any names
      ...              Parts     the TOP face is the water surface
      Rapids           Part      named after an entry in WaterConfig.CURRENT_SPEEDS: flows toward its front face
```

- Make `Spawn`, `Launch`, `Zone`, `BoatSpawn` and `Finish` **Anchored**, **CanCollide off**
  and **Transparency 1** (they're markers, not things to stand on).
- Make `Zone` and `Finish` big enough to cover the whole river, so a boat can't miss them.
- Make water parts **Anchored** and **CanCollide off**. Boats float wherever there's a water
  part underneath and fall where there isn't, so rivers without walls can be fallen off.
- To make water flow, name the part after an entry in `WaterConfig.CURRENT_SPEEDS`
  (`Current` or `Rapids` to start with) and turn it so its front face points downstream.
  Add more names and speeds there.
- Put each `Launch` part at water level, over a water part.
- The checkpoints and their order live in `CheckpointConfig.CHECKPOINTS`. The three
  there now are placeholders: edit the list to match the map.

## Building the boats

Put one Model per size in **`ReplicatedStorage.Assets.Boats`**, named as in
`BoatConfig.TEMPLATE_NAMES` (`Boat1` … `Boat6` by default):

- Set the Model's **PrimaryPart** to a flat part in the middle of the boat, at the height
  the water should come up to, top face up. It can be invisible. Boats float with this
  part at the water surface.
- Weld every other part, Seats included, to it with **WeldConstraints** (directly or through
  other welded parts). Anchoring doesn't matter: the code sets it.
- Put in exactly as many **Seat** objects as the size (`Boat3` has 3 Seats). Space them
  around the edge, facing the middle. A one-seat boat can have its seat in the middle,
  facing forward.
- No scripts inside.

Output warns at startup about any template that's missing or doesn't follow these rules.

## Fart effects

- **`ReplicatedStorage.Assets.VFX.FartCloud`:** a ParticleEmitter for the gas cloud. Set
  its Texture, Color, Size and so on however you like. While someone farts, its Rate
  (`FartConfig.STREAM_PARTICLE_RATE`) and Speed are multiplied by their power.
- **`ReplicatedStorage.Assets.Sounds.Farts`:** a Folder of fart Sounds from the Creator
  Store. Each fart loops a random one, and its pitch and volume rise with power.
  Sounds that loop smoothly work best.

Without them farts still work, just invisible or silent, and Output warns once.

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
| Gas meter | done: `UI.HUD.GasMeter` fills `StarterGui.HUD.GasMeter.Fill` (a Frame whose width shows the gas left). Build that by hand when you make the real HUD; the test kit makes a stand-in until then |
| Touch fart buttons | call `FartServiceClient:PressFart(direction)` on press and `ReleaseFart(direction)` on release (`"Left"`, `"Straight"`, `"Right"`) |
| Farting on and off (e.g. button glow) | `FartServiceClient.FartStarted` (direction) and `FartStopped` |
| RIP screen | `BoatServiceClient.BoatWiped` |

## Saving

Progress (unlocked checkpoints, whether the game was beaten) saves with DataStores.
To test saving in Studio, publish the place and turn on **Game Settings → Security →
Enable Studio Access to API Services**. Without it, the game works but nothing saves.
