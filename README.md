# Roblox Script Hub

A **pure client-side LocalScript-only** script hub for Roblox. No RemoteEvents, no RemoteFunctions, no server-side scripts, and no backend dependencies. Everything runs entirely in a single LocalScript environment, with additional modules loaded from this GitHub repository via `loadstring(game:HttpGet(...))`.

## ⚠️ Disclaimer

This project is intended for use in **sandboxed/private servers** or environments where the user has **explicit permission** to run custom client scripts. The authors are not responsible for any misuse or violations of any platform's Terms of Service.

---

## Design Philosophy

- **100% Client-Side** — No `RemoteEvent`, `RemoteFunction`, or `Script` anywhere in this codebase. Everything is LocalScript logic that manipulates the local player's Character, Camera, and workspace queries only.
- **Self-Contained UI** — No external UI libraries. The entire UI framework is built from scratch in `src/Core/UILibrary.lua`.
- **Module Architecture** — Each tab is a separate Lua module loaded on-demand from GitHub raw URLs. `main.lua` wires everything together.
- **Cleanup System** — A janitor-style cleanup system (`src/Core/Cleanup.lua`) tracks every Instance, RBXScriptConnection, and thread so the hub can fully unload without leaving artifacts.

---

## One-Line Loadstring

To run the hub, paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/idkgorapeme/RobloxRape/refs/heads/arena/019fafdf-robloxrape/main.lua"))()
```

> Replace `idkgorapeme/RobloxRape` and the branch name with your fork's details if you've forked this project.

---

## Repository Structure

```
/
├── main.lua                          # Entry point — loads all modules and builds the UI
├── README.md                         # This file
└── src/
    ├── Core/
    │   ├── Cleanup.lua               # Janitor system: tracks and destroys Instances, connections, threads
    │   ├── Loader.lua                # Fetches modules from GitHub with caching (also inline in main.lua)
    │   ├── State.lua                 # Shared settings table + optional writefile/readfile persistence
    │   └── UILibrary.lua             # Custom lightweight UI framework (window, tabs, controls, notifications)
    ├── Tabs/
    │   ├── Universal.lua             # Tab 1 — Cheat menu (Fly, Speed, Jump Power, ESP, Aimlock)
    │   ├── Executor.lua              # Tab 2 — Multi-line code executor with sandboxed environment
    │   ├── ExecutorViewport.lua      # Tab 3 — Sandboxed GUI output container with cleanup
    │   ├── PromptGenerator.lua       # Tab 4 — AI prompt generator for creating executor scripts
    │   └── SaveLoad.lua              # Tab 5 — Save/Load/Manage scripts for the Executor
    └── Data/
        └── executor_prompt.txt       # The AI prompt text (also embedded in PromptGenerator.lua)
```

---

## Tab Overview

### Tab 1 — Universal
Standard game-cheat menu with configurable features:
- **Fly** — Camera-relative WASD + Space/Shift flight with BodyVelocity/BodyGyro
- **Speed Hack** — Adjustable WalkSpeed with auto-reset on respawn
- **Jump Power** — Adjustable JumpPower/JumpHeight
- **ESP** — Player overlays with boxes, names, distance, tracers, team check, and color pickers (using Drawing API + BillboardGuis)
- **Aimlock** — Client-side aim assist with FOV circle, smoothness, and target selection

All settings persist via `State.lua` (in-memory + optional file save).

### Tab 2 — Executor
A multi-line Lua code editor with:
- Custom sandboxed environment exposing Roblox globals + `ExecutorGui` + `RegisterCleanup`
- Captured `print`/`warn`/`error` output in the on-screen log
- Execute, Clear Output, and Stop Script buttons
- Full cleanup pipeline integration with Tab 3

### Tab 3 — Executor Viewport
A dedicated `ScreenGui` (named `ExecutorOutputGui`) parented to `CoreGui` where executed scripts can parent their GUIs. Provides:
- `ClearAll()` — Destroys all child instances and disconnects all tracked connections
- Live preview of mounted GUI elements
- Per-script janitor for tracking and cleanup

### Tab 4 — Prompt Generator
A read-only panel containing a pre-written AI prompt. Users can copy it into any AI chat to generate Tab-2-compatible Roblox scripts. Includes "Copy to Clipboard" and selection helpers.

### Tab 5 — Save / Load
Script manager for the Executor tab:
- Save scripts by name with timestamps
- Load saved scripts back into the Executor
- Delete and rename entries
- Export all to clipboard / Import from clipboard
- Automatic persistence via `writefile`/`readfile` when available

---

## How the Executor/Viewport Cleanup System Works

1. When the user clicks **Execute** in Tab 2:
   - `ExecutorViewport.NewExecSession()` is called, which **immediately** runs `ClearAll()` to destroy everything from the previous execution.
   - A fresh janitor (`execCleanup`) is created for the new script.
   
2. The sandbox environment provides:
   - `ExecutorGui` — The ScreenGui that executed scripts should parent their GUI to.
   - `RegisterCleanup(fn)` — Scripts can register teardown functions (disconnect connections, cancel threads, etc.).
   - Custom `print`/`warn`/`error` that pipe into the output log.

3. When the code finishes (or errors), the janitor holds references to everything created. Next time Execute is clicked, `ClearAll()` destroys:
   - All child Instances of the output ScreenGui
   - All RBXScriptConnections registered via the janitor
   - All tracked threads (via `task.cancel`)
   - All custom cleanup callbacks

This ensures **zero trace** of the previous script remains.

---

## How to Add a New Tab Module

1. Create a new file in `src/Tabs/` (e.g. `MyTab.lua`).
2. Implement a `Build(tab, ui, state, cleanup)` function that returns a table (can be empty or expose an API).
3. In `main.lua`, add a new section:

```lua
-- Load Tab N — MyTab
do
    local ok, mod = pcall(function()
        return loadModule("src/Tabs/MyTab.lua")
    end)
    if ok and mod then
        local success, result = pcall(function()
            return mod.Build(tabN, ui, sharedState, mainCleanup)
        end)
        if not success then
            ui:Notify("Error", "MyTab failed: " .. tostring(result), 6, "error")
        end
    else
        ui:Notify("Error", "Failed to load MyTab module.", 6, "error")
    end
end
```

4. Create the tab button in `main.lua` with `ui:CreateTab("My Tab")`.

Use the `ui` object to add controls (Section, Toggle, Slider, Dropdown, TextBox, Button, Keybind, ColorPicker) and register all created Instances/connections with the `cleanup` janitor.

---

## UI Controls Reference

The `UILibrary` provides these controls (all called as `ui:ControlName(tab, ...)`):

| Control | Parameters | Description |
|---------|-----------|-------------|
| `Section` | `(tab, title)` | Section header for grouping controls |
| `Toggle` | `(tab, label, default, callback)` | On/off toggle with callback |
| `Slider` | `(tab, label, min, max, default, step, callback)` | Draggable slider |
| `Dropdown` | `(tab, label, options, default, callback)` | Collapsible dropdown selector |
| `TextBox` | `(tab, label, placeholder, default, callback)` | Single-line text input |
| `Keybind` | `(tab, label, defaultKey, callback)` | Keybind setter (click to listen) |
| `Button` | `(tab, label, callback)` | Clickable button |
| `ColorPicker` | `(tab, label, defaultColor, callback)` | Expandable RGB color picker |
| `Notify` | `(title, message, duration, type)` | Toast notification (info/success/warning/error) |

---

## License

This project is provided as-is for educational purposes. See the disclaimer above.
