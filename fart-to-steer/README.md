# Fart to Steer — Roblox project

This is the code for Fart to Steer, set up with [Rojo](https://rojo.space). The
scripts live here as files. Rojo copies them into Roblox Studio live, so when the
code changes in this repo you `git pull` and Studio updates by itself.

What's in this first version is milestone **M0, the fun test** from the
[game plan](../docs/fart-to-steer/GAME_PLAN.md):

- A round 4-seat boat (the Party Ring) that you're seated on as soon as you join.
  More players get more boats.
- 3-way fart steering: Left, Straight, Right. Tap to toot, hold for a Mega Fart.
- Gas meter, and a FARTQUAKE when 3+ players Mega Fart at the same time.
- Water physics: floating, drag, currents, and falling off rivers that have no walls.
- Seat Cam, which sits behind your own seat.
- A grey-box test course: a start pond, a rock slalom, a log gate, a sky river with
  no walls and a finish with a timer.

---

## One-time setup

You need **Git**, **Rokit** (installs Rojo for you) and **Roblox Studio**.

> **Windows:** use a normal PowerShell window, **not** "Run as administrator". An
> administrator window starts in `C:\WINDOWS\system32`, which is the wrong place for
> your game files. Run one command at a time so you can see if one fails.

1. **Install Git.**
   - **Windows:** in PowerShell run
     ```powershell
     winget install --id Git.Git -e --source winget
     ```
     If `winget` isn't found, download the installer from <https://git-scm.com/download/win>
     and click Next through it with the default options.
   - **Mac:** run `git --version` in Terminal and accept the offer to install it.

   **Close the terminal and open a new one**, otherwise it won't find `git`.

2. **Install Rokit.**
   - **Windows:** in PowerShell run
     ```powershell
     Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
     ```
   - **Mac:** in Terminal run
     ```bash
     curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
     ```
   **Close the terminal and open a new one** again. Check both worked with
   `git --version` and `rokit --version`. Each should print a version number.

3. **Download the code** into your home folder. If GitHub asks you to sign in,
   sign in with your GitHub account in the browser window that opens.
   ```bash
   cd ~
   git clone https://github.com/jakejangeh2007-svg/roblox.git
   cd roblox
   git checkout claude/determined-gates-6stlty
   cd fart-to-steer
   ```

4. **Install Rojo and the other tools** listed in `rokit.toml`. Say yes when it asks
   whether to trust them:
   ```bash
   rokit install
   ```

5. **Install the Rojo plugin into Studio** (it matches the Rojo version above):
   ```bash
   rojo plugin install
   ```
   Restart Studio if it was open.

---

## Every time you work on the game

1. Open a terminal, go to the `fart-to-steer` folder and start Rojo:
   ```bash
   cd ~/roblox/fart-to-steer
   rojo serve
   ```
   Leave it running.

2. In Roblox Studio, open your place. For a first test, use a new **Baseplate**.

3. Go to the **Plugins** tab → **Rojo** → **Connect**. The scripts appear in
   ReplicatedStorage, ServerScriptService and StarterPlayer.

4. Press **Play**. You'll be placed on a boat in the test pond floating above the
   baseplate.

5. **To test with several players on one computer:** go to the **Test** tab, set
   **Clients and Servers** to 2–4 players, and press **Start**. Each player gets a
   window, and they all share the same boat.

6. Save the place (**File → Save to Roblox** or **Publish to Roblox**). Rojo puts the
   scripts into the place, but you still have to save it.

**Getting new code:** stop any running playtest, then in a second terminal run
`git pull` in the repo. Since `rojo serve` is running, Studio updates automatically.

**No Rojo running?** `rojo build -o FartToSteer.rbxlx` makes a place file that you can
open straight in Studio.

---

## Controls

| Action                | Keyboard                | Controller | Touch                     |
| --------------------- | ----------------------- | ---------- | ------------------------- |
| Fart Left (turn left) | `A`, `←`, `Q`           | `LB`       | LEFT button               |
| Fart Straight         | `W`, `↑`, `Space`       | `RT`       | FART button               |
| Fart Right (turn right) | `D`, `→`, `E`         | `RB`       | RIGHT button              |
| Mega Fart             | Hold any fart key, then let go | Hold | Hold                   |
| Switch camera         | `V`                     | `Y`        | CAM button                |

Straight pushes the boat **away from you**. Everyone farting Left spins the boat
left on the spot. Only the people at the back should fart Straight.

---

## Where things are

```
fart-to-steer/
├── default.project.json   how the files map into Studio
├── rokit.toml             tool versions (Rojo, StyLua, Selene)
└── src/
    ├── shared/            → ReplicatedStorage.Shared (server and client both use these)
    │   ├── Config.luau        ALL the tuning numbers: push, spin, gas, drag, camera...
    │   ├── FartPhysics.luau   what one fart does to the boat
    │   └── BoatTypes.luau     Solo Tube, Double Donut, Party Ring, Mega Donut
    ├── server/            → ServerScriptService.Server
    │   ├── Course.luau        finds your course, or builds the grey-box test course
    │   ├── BoatService.luau   builds boats, seats players, falling off, finish, respawn
    │   ├── WaterService.luau  floating, drag and currents
    │   └── FartService.luau   checks farts, spends gas, pushes the boat, FARTQUAKE
    └── client/            → StarterPlayer.StarterPlayerScripts.Client
        ├── FartInput.luau     keys, controller and touch buttons → farts
        ├── BoatCamera.luau    Seat Cam
        ├── FartFX.luau        fart clouds and sounds
        ├── Hud.luau           gas meter, Mega charge bar, notices
        ├── Seating.luau       turns off walking and jumping while on a boat
        └── RiderState.luau    "which boat and seat am I on?"
```

### Tuning

Change numbers in `src/shared/Config.luau`. Stop and start the playtest to try them.
To change which boat spawns, set `DEFAULT_BOAT` to `"SoloTube"`, `"DoubleDonut"`,
`"PartyRing"` or `"MegaDonut"`.

### Adding fart sounds

Right now a built-in splash sound pitched down stands in. To use real fart sounds:

1. In Studio, open the **Toolbox** → **Creator Store** → **Audio** and search "fart".
2. Pick sounds that are free to use. Right-click one → **Copy Asset ID**.
3. Paste them into `FART_SOUND_IDS` in `Config.luau`, like this:
   `FART_SOUND_IDS = { "rbxassetid://1234567", "rbxassetid://7654321" } :: { string },`

Each fart picks one at random and changes the pitch a bit. Use several so it never
sounds the same twice.

### Building your own course

The code builds a test course only if your place doesn't have one. To build your own
in Studio, make a **Folder** named `Course` in Workspace with:

- **`Water`** (Folder): parts whose **top face** is the water surface. Make them
  Anchored with CanCollide off. To make water flow, add a **Vector3 attribute** named
  `Current` (studs per second, for example `0, 0, 5`). Where there's no water part
  underneath, boats fall.
- **`Spawns`** (Folder): parts named `Spawn1`, `Spawn2`… at water level where boats
  start. Make them Anchored, CanCollide off and Transparency 1.
- **`Finish`** (optional Part): a boat whose middle gets inside it has finished.

Walls, rocks and logs are normal anchored parts. The boat bounces off anything solid.
If your water is not at height 120, change `KILL_Y` in `Config.luau` to about 40
studs below your lowest water.

---

## Troubleshooting

- **Rojo says the plugin and server versions don't match:** run `rojo plugin install`
  again and restart Studio.
- **Nothing happens when I press Play:** open **View → Output** and look for red
  errors. Copy them into the chat with Claude.
- **I'm standing on the boat instead of sitting:** it still works. Send the Output
  log if it happens so it can be fixed.
- **The boat feels too slow, too fast or too spinny:** that's what `Config.luau` is
  for. `PUSH_SPEED`, `SPIN_SPEED`, `WATER_DRAG` and `SPIN_DRAG` matter most.
