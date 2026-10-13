# Place scripts

The scripts for the Roblox place, organized by the project conventions: services,
classes, modules, assets, modular UI. No external tools are needed.

## Setting up a place

1. Open the place in Roblox Studio. Use a fresh place, not one synced with the old
   `fart-to-steer/` Rojo prototype.
2. **View** tab → **Command Bar**.
3. Copy all of [`ProjectSetup.luau`](ProjectSetup.luau), paste it into the Command
   Bar and press Enter.
4. The Output window lists everything it created. Running it again is safe, and
   Ctrl+Z undoes it.

## What it creates

```
ReplicatedStorage
  Shared
    Services            one folder per service: <X>Service with <X>ServiceClient
    Classes             shared and client classes
    Modules
      Core              base utilities
      Game              every <System>Config module
      Math
      Platform
  Assets                pre-made instances, no code
  UI                    ModuleScript: top-level UI initializer
    HUD                 one ModuleScript per HUD feature
    Menus               one ModuleScript per menu feature
  Packages              game-agnostic reusable scripts only

ServerScriptService
  Server                Script: startup, calls Init on every server service
  Services              one folder per service: <X>Service with <X>ServiceServer
  Classes               server-side classes

StarterPlayer
  StarterPlayerScripts
    Client              LocalScript: startup, calls Init on every client service, then UI.Init
```

## Files in this folder

Each `.luau` file here is one script in the place. The first comment line says
which instance it is.

| File                                             | Instance in Studio                                  |
| ------------------------------------------------ | --------------------------------------------------- |
| `ServerScriptService/Server.luau`                | Script `ServerScriptService.Server`                 |
| `StarterPlayer/StarterPlayerScripts/Client.luau` | LocalScript `StarterPlayer.StarterPlayerScripts.Client` |
| `ReplicatedStorage/UI.luau`                      | ModuleScript `ReplicatedStorage.UI`                 |
| `ProjectSetup.luau`                              | Not a script in the place. Paste it into the Command Bar once |

`ProjectSetup.luau` contains copies of the three scripts above. If one of them
changes, update its copy in `ProjectSetup.luau` too.

## How startup works

- **Server** requires `ServerScriptService.Services.<X>Service.<X>ServiceServer` for
  every service folder and calls `Init(self)` on it, in alphabetical order.
- **Client** waits for the game to load, then does the same with
  `ReplicatedStorage.Shared.Services.<X>Service.<X>ServiceClient`, and finally calls
  `UI.Init`.
- **UI.Init** requires every feature ModuleScript in the interface folders (`HUD`,
  `Menus`, …) and calls its `Init` if it has one.
- A service with only one half is skipped on the other side. A service whose module
  has no `Init` is skipped.
- To change the start order, add a service's folder name to `START_FIRST` at the top
  of `Server` or `Client`. If its `Init` takes parameters, add it to `START_MANUALLY`
  and call it by hand at the bottom of the script.
