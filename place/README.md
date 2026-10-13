# Place scripts

The game's code, organized by the project conventions. No external tools are needed.

## Installing or updating the code

1. Open the place in Roblox Studio and close any open script tabs.
2. **View** tab → **Command Bar**.
3. Copy all of [`Install.luau`](Install.luau), paste it into the Command Bar and press Enter.
4. The Output window lists what it created (`+`) and updated (`~`).

The installer creates missing folders and scripts and replaces the code in existing
scripts. It never deletes anything and never touches models or parts. Run it again
whenever the code changes. Ctrl+Z undoes it.

`Install.luau` is generated from the other `.luau` files in this folder. Each file is
one script; its first comment line says which instance. `X.server.luau` is a Script,
`X.client.luau` a LocalScript, anything else a ModuleScript.

## Hierarchy

```
ReplicatedStorage
  Shared
    Services
      BoatService         BoatServiceClient, BoatServiceShared
      CheckpointService   CheckpointServiceClient, CheckpointServiceShared
      DockService         DockServiceClient, DockServiceShared
    Classes
    Modules
      Core                Remotes
      Game                BoatConfig, CheckpointConfig, DataConfig, DockConfig
      Math                Geometry
      Platform
  Assets
    Boats                 boat templates (you build these)
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
   not on cooldown, dock free, checkpoint unlocked. Then it spawns the boat at the dock.
   Each player can have one waiting boat; picking again replaces it.
3. Players sit in the boat's seats. When **every seat is full**, a `LAUNCH_DELAY`
   countdown starts. If anyone gets up, it stops. When it finishes, the boat moves to
   the location's **Launch** point in the river. From then on nobody new can get in.
   Anyone who leaves goes back to their current checkpoint.
4. When a boat on the river enters a checkpoint's **Zone**, that checkpoint and every
   one before it are **unlocked** and saved for everyone aboard. From then on they
   respawn there.
5. Players can **teleport** to the lobby or any unlocked checkpoint. Each checkpoint
   has its own docks, so they can start a new boat from there.
6. A boat entering **Map.Finish** beats the game. It's saved, and after
   `FINISH_RETURN_DELAY` the crew is sent back to the lobby.

Every number is in the config modules in `ReplicatedStorage.Shared.Modules.Game`.

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
```

- Make `Spawn`, `Launch`, `Zone`, `BoatSpawn` and `Finish` **Anchored**, **CanCollide off**
  and **Transparency 1** (they're markers, not things to stand on).
- Make `Zone` and `Finish` big enough to cover the whole river, so a boat can't miss them.
- The checkpoints and their order live in `CheckpointConfig.CHECKPOINTS`. The three
  there now are placeholders: edit the list to match the map.

## Building the boats

Put one Model per size in **`ReplicatedStorage.Assets.Boats`**, named as in
`BoatConfig.TEMPLATE_NAMES` (`Boat1` … `Boat6` by default):

- Set the Model's **PrimaryPart**.
- Weld every other part to it with **WeldConstraints**.
- Put in exactly as many **Seat** objects as the size (`Boat3` has 3 Seats).
- No scripts inside.

Output warns at startup about any template that's missing or doesn't follow these rules.

## For the UI (to be built by hand)

The client halves have everything the menus need:

| What | Use |
| ---- | --- |
| Boat-size menu opens | `DockServiceClient.DockSelected` fires `(dock)` when the player uses a dock prompt |
| Spawn the picked size | `DockServiceClient:RequestSpawnBoat(dock, seatCount)` → `(success, message)` |
| Countdown | the boat model's `LaunchTime` attribute (server time) while its `State` attribute is `"Launching"` |
| Teleport menu list | `CheckpointConfig.CHECKPOINTS` plus `CheckpointServiceClient:GetUnlockedCheckpointIds()` |
| Teleport | `CheckpointServiceClient:RequestTeleport(id)` → `(success, message)`; the lobby's id is `CheckpointConfig.LOBBY_ID` |
| List changed | `CheckpointServiceClient.UnlockedCheckpointsChanged` |
| "Checkpoint reached" / "You win" | `CheckpointServiceClient.CheckpointReached`, `CheckpointServiceClient.GameCompleted` |

## Saving

Progress (unlocked checkpoints, whether the game was beaten) saves with DataStores.
To test saving in Studio, publish the place and turn on **Game Settings → Security →
Enable Studio Access to API Services**. Without it, the game works but nothing saves.
