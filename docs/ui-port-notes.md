# UI port notes — step 3

How `frontend/*.cs` becomes `src/ui/*.gd`. Read this before translating a window.
The backend translation rules in HANDOFF.md §4 still apply; this page adds the
UI-specific ones and the places the ported backend API differs from the C#.

## Files

| Source | Port |
|---|---|
| `frontend/FooWindow.cs` | `src/ui/foo_window.gd` (snake_case of the C# class), `class_name FooWindow` |
| `frontend/FooWindow.tscn` | `src/ui/FooWindow.tscn` — **already copied**, byte-identical except the script `ext_resource` path. Do not edit the scene. |
| `frontend/Buttons/*.cs` | `src/ui/buttons/*.gd` |
| `GameManager.cs`, `Menu.cs` | `src/ui/game_manager.gd`, `src/ui/menu.gd` (Main.tscn / Menu.tscn at the root) |

Foundation already built: `draggable_window.gd`, `ui_manager.gd`, `gid.gd`,
`gid_bar.gd`, `gid_key.gd`, `galaxy_map.gd`, `game_manager.gd`, `menu.gd`,
`debug_keys.gd`, `buttons/*.gd`, and the five code-built windows
(`objectives_window.gd`, `galaxy_overview_window.gd`, `battle_alert_window.gd`,
`battle_results_window.gd`, `tactical_view.gd`). Read `draggable_window.gd` and
`ui_manager.gd` first — every scene window extends the former and calls the latter.

## Translation rules (UI)

| C# | GDScript |
|---|---|
| `public partial class X : PanelContainer` | `class_name X` / `extends DraggableWindow` (or the C# base) |
| `[Export] PackedScene Foo` | `@export var Foo: PackedScene` |
| `GetNode<Label>("%Title")` | `get_node("%Title")` with a typed var: `var title: Label = get_node("%Title")` |
| `btn.Pressed += Handler` | `btn.pressed.connect(Handler)` |
| `btn.Pressed += () => Foo(x)` | `btn.pressed.connect(func() -> void: Foo(x))` |
| `popup.IdPressed += (long id) => ...` | `popup.id_pressed.connect(func(id: int) -> void: ...)` |
| `Action<T>` parameter / field | `Callable`; call with `.call(...)`; test with `.is_valid()`; empty is `Callable()` |
| `event Action<X> OnFoo` | `signal OnFoo(x)`; raise with `OnFoo.emit(x)` |
| `Callable.From(() => f()).CallDeferred()` | `f.call_deferred()` / `call_deferred("f")` |
| `_Ready / _Process / _GuiInput / _Draw / _GetDragData / _CanDropData / _DropData / _UnhandledInput` | `_ready / _process / _gui_input / _draw / _get_drag_data / _can_drop_data / _drop_data / _unhandled_input` |
| `@event is InputEventMouseButton mb && mb.Pressed && mb.ButtonIndex == MouseButton.Right` | `event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT` |
| `Key.H`, `Key.Escape` | `KEY_H`, `KEY_ESCAPE` |
| `Colors.Yellow`, `Colors.DarkGray` | `Color.YELLOW`, `Color.DARK_GRAY` |
| `new Color(0.4f, 0.6f, 0.9f)` | `Color(0.4, 0.6, 0.9)` |
| `new Vector2I(x, y)` | `Vector2i(x, y)` |
| `HorizontalAlignment.Center` | `HORIZONTAL_ALIGNMENT_CENTER` |
| `TextServer.AutowrapMode.WordSmart` | `TextServer.AUTOWRAP_WORD_SMART` |
| `Control.SizeFlags.ExpandFill` | `Control.SIZE_EXPAND_FILL` |
| `MouseFilterEnum.Stop` | `Control.MOUSE_FILTER_STOP` |
| `LayoutPreset.TopLeft` | `Control.PRESET_TOP_LEFT` |
| `GodotObject.IsInstanceValid(x)` | `is_instance_valid(x)` |
| `x.GetHashCode()` (for unique window names) | `x.get_instance_id()` |
| `new ConfirmationDialog { Title = .., DialogText = .., Exclusive = true }` | `var d := ConfirmationDialog.new(); d.title = ..; d.dialog_text = ..; d.exclusive = true` |
| `dialog.Confirmed += ...; dialog.Canceled += dialog.QueueFree` | `d.confirmed.connect(...); d.canceled.connect(d.queue_free)` |
| `GD.Print($"...{x}...")` | `print("...%s..." % x)` (use `%d` for ints) |
| `string.Join(", ", xs.Select(u => u.Name))` | `", ".join(Lq.select(xs, func(u) -> String: return u.Name))` |
| `xs.Where(p).ToList()`, `.Any(p)`, `.All(p)`, `.Count(p)`, `.Sum(s)`, `.OrderBy(k)`, `.FirstOrDefault(p)` | `Lq.where`, `Lq.any`, `Lq.all`, `Lq.count`, `Lq.sum`, `Lq.order_by`, `Lq.first_or_null` (all in `src/core/lq.gd`) |
| `xs.OfType<Character>()` | `Lq.where(xs, func(x) -> bool: return x is Character)` |
| `x as Planet`, `x is Fleet f` | `x as Planet`, `x is Fleet` then use `x` |
| `SetupMenuButton<T>(btn, data, list, popup, (id, targets) => ...)` | `SetupMenuButton(btn, data, list, popup, func(id: int, targets: Array) -> void: ...)` |
| `bool ok = Mgr.Try(..., out string err)` | `var r: Result = Mgr.Try(...)`; `r.ok`, `r.error` (`""` when none), `r.value` |
| `enum.ToString()` | `JsonUtil.enum_name(Enums.TheEnum, value)` |
| `Enum.GetValues<MissionType>()` | `Enums.MissionType.values()` |
| `Enum.TryParse(name, out Cat c)` | `Enums.Cat.has(name)` then `Enums.Cat[name]` |
| `List<T>` field | `var xs: Array = []` (typed `Array[T]` only when nothing untyped is ever assigned to it) |
| `null` string / `?? ""` | `""` and `is_empty()` |
| `x?.Foo` | `x.Foo if x != null else <default>` |

Keep every C# member name (PascalCase) on the GDScript side. Keep every comment
that quotes the manual. Do not rename, reorder or "improve" anything the C# does.

## Where the ported backend API differs from the C#

The backend was translated first; these are the names a window must use.

| C# | GDScript port |
|---|---|
| `GameManager.ActiveRoster`, `GameManager.ActiveGalaxy` | `GameState.ActiveRoster`, `GameState.ActiveGalaxy`, plus `GameState.AllPlanets()` |
| `EventBus.OnDayAdvanced += H` / `-= H` | `EventBus.OnDayAdvanced.append(H)` / `.erase(H)` — the four events are `Array[Callable]`: `OnGameNotification`, `OnDayAdvanced`, `OnStateChanged`, `OnMessageReceived` |
| `EventBus.MessageLog`, `UnreadCount(cat)`, `DeleteMessage(m)`, `BroadcastChanged()` | same names |
| `character.IsCaptured`, `IsInjured`, `CanTakeOrders`, `CanHoldAnyRank`, `IsOffMap`, `ForceRank` (properties) | **functions**: `IsCaptured()`, `IsInjured()`, `CanTakeOrders()`, `CanHoldAnyRank()`, `IsOffMap()`, `ForceRank()` |
| `character.TryTakeCommand(rank, out why)` | `TryTakeCommand(rank) -> Result` |
| `planet.Mines`, `Refineries`, `Shipyards`, `TrainingFacilities`, `ConstructionYards`, `PlanetaryShields`, `TurbolaserBatteries`, `IonCannons`, `HasHeadquarters`, `HasIdleShipyards`, `HasIdleTroopTraining`, `HasIdleConstructionYards`, `SpecForces`, `GarrisonRequirement`, `GetFactionColor` | **functions** with `()` |
| `planet.BaseEnergy`, `BaseRawMaterials`, `ControllingFaction`, `IsExplored`, `Garrison`, `FighterSquadrons`, `Facilities`, `OrbitingFleets`, `IsInUprising`, `MapX`, `MapY`, `Name` | vars, as in C# |
| `facility.Name` | **function** `Name()`; `Facility.NameOf(type)` static |
| `fleet.Name` | var (on `Location`) |
| `mission.DisplayName` | **function** `DisplayName()` |
| `MissionManager.Active` | **function** `Active()` |
| `MissionManager.CanTarget(t, actor, target, out why)` and the other `out string` methods | return `Result` |
| `FleetBattleManager.HasPendingBattle`, `AwaitingOrders`, `Unreported` | **functions** with `()` |
| `FleetBattleManager.BattleReport.Casualties` | `FleetBattleManager.Casualties` (sibling inner class) |
| `VictoryManager.IsOver` | `IsOver()`; `StatusFor` returns `[[label, met], ...]` |
| `Gid.ActiveMode` (get/set), `Gid.Default`, `Gid.CNeutral`, `Gid.CUnexplored` | `Gid.ActiveMode()`, `Gid.SetActiveMode(m)`, `Gid.Default()`, `Gid.CNeutral()`, `Gid.CUnexplored()` |
| `GidMode.Label`, `GidTier.Label` | `LabelText` (`Label` shadows the Control class) |
| `GidMode.Magnitude(p)`, `Reveal(p)` | `Magnitude.call(p)`, `Reveal.call(p)` |
| `IntelManager.View(f, p, IntelSection.X)` | `IntelManager.View(f, p, Enums.IntelSection.X)` → `IntelManager.IntelView` with `Known`, `Lines` |
| `UIManager.StartTargeting(onPlanet, onObject)` (two-arg overload) | `StartTargetingObject(onPlanet, onObject)` |
| `UIManager.ExecuteFleetMove(Fleet, ...)` (single-fleet overload) | `ExecuteSingleFleetMove(fleet, planet, confirm)` |
| `UIManager.IsTargetingObject` (property) | `IsTargetingObject()` |
| `UIManager.DraggedCharacters` etc. (null when idle) | `[]` when idle |
| `Economy.For(f).RefinedMaterials` | same; `Economy.FactionEconomy` is the inner class |
| `ResearchTrackKind.Count` | `Enums.ResearchTrackKind.size()` |
| `Rank.Admiral`, `Status.Enroute`, `UnitType.Fighter`, `MessageCategory.Fleets` | `Enums.Rank.Admiral`, `Enums.Status.Enroute`, `Enums.UnitType.Fighter`, `Enums.MessageCategory.Fleets` |
| `TacticalUnit.Alive`, `Destroyed`, `IsSquadron`, `Name` | functions; `TacticalBattle.TacticalState.Docked` for the enum |

When a window needs a backend member you cannot find under `src/game/`, grep
for the C# name first (`grep -rn "func Foo\|var Foo" src/game`). If it is
genuinely absent, say so in your report — do not invent it and do not stub it.

## Recorded deviations (C3PO review #64)

- `UIManager._exit_tree` also erases `ShowHudNotification` from
  `EventBus.OnMessageReceived`; the C# left that subscription behind (a leak).
  Kept deliberately.
- `GameSignature.For(x)` overloads are `ForPlanet` / `ForSector` /
  `ForCharacter` / `ForMessages` in the port.
- `MissionWindow.Label(m)` is `LabelText(m)` (same reason as `GidMode.LabelText`).
- `Mission.Arrived`, `ConstructionTask.PercentComplete/DisplayName`,
  `GameMessage.AwaitsDecision`, `Planet.Troopers/TrooperRegiments` are functions.
- MilitaryDataEditor: the C# save path writes only the 23 fields its own
  `MilitaryUnit` model carries and drops the other 32 keys of
  `military_units.json` (research order/cost, arcs, ranges, SpecForce
  ratings). Reproduced faithfully; **do not use Save until that is fixed at the
  source.**

## Gate per window

1. `tests/ui_compile.gd` loads every `src/ui/*.gd`: zero failures.
2. `tests/ui_smoke.gd` instantiates the window over the seed-12345 galaxy and
   calls its `Populate`/`Setup`: zero `SCRIPT ERROR` lines.
3. The window's section of `docs/window-checklists.md` re-read against the
   `.gd`: every **Present** item is present in the port; every Partial/Missing
   item is carried over unchanged (fixing them is feature work, not the port).

Compile check, from the repo root (Bash; the Mono editor runs GDScript fine):

```
G=/d/Downloads/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe
timeout 120 "$G" --headless --path . -s tests/ui_compile.gd
```

Run `timeout 300 "$G" --headless --path . --import` once first if a
`class_name` you added is reported as not found (the class cache is stale until
the import runs).
