# Manual element checklists

This is the Step 3 research ledger for the C# frontend. It compares the manual text and labelled illustrations copied at sync `11c1b36` with the current `sol-conflict-revolution/frontend` implementation. It describes code state; it does not claim runtime verification.

Status legend: **Present** = named element and its interaction are represented; **Partial** = information or interaction exists but differs materially from the manual; **Missing** = the manual element is not represented; **Disabled** = the named control is visible but intentionally unavailable.

## 1. Galaxy Map and Galactic Information Display (GID)

Manual passages: Command Center, PDF pp. 21, 23 and 61–62 (manual pp. 22, 24 and 63–64); GID key and modes, PDF pp. 66 and 69–70 (manual pp. 68 and 71–72). Labelled figures: `manual/ILLUSTRATIONS.md`, figs. 2.3, 2.6, 2.7 and 3.8–3.10.

| Manual element, in the manual's words | C# frontend state |
|---|---|
| “Galaxy Map” in the Command Center | **Present.** `GalaxyMap.cs` supplies clickable system targets over the strategic map. |
| “Galactic Information Display” with the categories “LOYALTY”, “FLEETS”, “PERSONNEL”, “RESOURCES”, “MANUFACTURING”, “DEFENSE” | **Present.** `GidBar.cs` builds all six category buttons from `Gid.Categories`. |
| “Display Off” | **Present.** It is a real selectable GID mode and suppresses the information flare. |
| “Show Legend” icon / GID key | **Partial.** `GidKey.cs` builds a legend and updates it with the selected mode, but `GidBar.cs` creates it automatically as a taskbar-stowed window; the manual's explicit Show Legend control is absent. |
| The key's changing heading, such as “GALACTIC INFORMATION DISPLAY — POPULAR SUPPORT” | **Present.** `Gid.TitleFor(mode)` drives the legend heading. |
| Star “size corresponds to the amount” of the selected information | **Present, stylized.** `GalaxyMap.cs` uses tier-sized `+` flares. This is a text-glyph approximation rather than the manual artwork. |
| Popular-support sizes “LOYAL”, “OBEDIENT”, “DISLOYAL”, “HOSTILE” | **Present.** These are the four loyalty-tier labels in `Gid.cs`. |
| Color key: “RED — Alliance”, “GREEN — Empire”, “BLUE — Neutral”, “GRAY — Unexplored” | **Present.** The faction/unexplored colors are centralized in `Gid.cs` and used by the map and key. |
| Alliance Headquarters marked by a “white star”; only the Alliance player sees the hidden Alliance Headquarters | **Present.** `GalaxyMap.cs` draws the Alliance-HQ burst independently of Display Off and only for the Alliance player. |
| Select a GID category, then select one item from its pull-down list | **Present.** The category buttons open mode menus and set the shared active mode. |
| The GID selection applies to both Galaxy and Sector views | **Present.** Both `GalaxyMap.cs` and `SectorWindow.cs` read `Gid.ActiveMode`. |
| Loyalty: “Popular Support”, “Uprisings” | **Present.** Both modes are defined. |
| Fleets: “Idle Fleets”, “Fleets En Route” | **Present.** Both modes are defined. |
| Personnel: “Idle Personnel”, “Active Personnel” | **Present.** Both modes are defined. |
| Resources: “Mines”, “Refineries”, “Energy”, “Maintenance” | **Present.** All four modes are defined. |
| Manufacturing: “Idle Shipyards”, “Idle Training Facilities”, “Idle Construction Yards”, plus shipyard/training/construction capacity | **Present.** Six manufacturing modes are defined. |
| Defense: “Shield Generators”, “Ion Cannons”, “Laser Batteries”, “LNR Series I”, “Death Star Shields” | **Partial.** All five named choices exist, but `Death Star Shields` currently reports a constant zero; defense visibility uses current exploration rather than the manual's stale-intelligence model. |
| Keyboard shortcuts Alt+1 through Alt+9 for the first nine displayed modes | **Missing.** `UIManager._UnhandledInput` implements Alt+H and Alt+O only; no Alt+1…Alt+9 mappings exist. |
| Click a system on the Galaxy Map to open its Sector/System information | **Present.** Invisible planet buttons provide the click targets. |

Research confidence: **high** for named controls/modes, **medium** for exact visual fidelity because this pass is source inspection rather than a rendered comparison.

## 2. Fleet Window

Manual passages: fleet window overview, PDF pp. 48, 50 and 52 (manual pp. 49, 51 and 53); “Reading the Fleet Window,” PDF pp. 110–111 (manual pp. 112–113); fleet/ship commands and rearranging fleets, PDF pp. 114–123 (manual pp. 116–125). Labelled figures: `manual/ILLUSTRATIONS.md`, figs. 2.45, 2.46, 2.50, 2.54–2.56 and 3.54–3.55.

| Manual element, in the manual's words | C# frontend state |
|---|---|
| Open a fleet by double-clicking the Fleet icon in a system window | **Present.** The sector Fleet corner opens `FleetWindow`; the window lists fleets at that system. |
| “Fleets in System” list and selected fleet name | **Present.** The left column lists fleets; selecting one fills the right side. |
| Four tabs: “Capital Ships”, “Fighters”, “Troops”, “Personnel” | **Present.** All four named tabs are declared in `FleetWindow.tscn` and populated by `FleetWindow.cs`. |
| Capital Ships tab: each ship and the fighters/troops it can carry | **Partial.** Ships are listed, but the manual's carried-versus-capacity figures are not shown beside each ship. |
| Fighters tab: “number of fighter squadrons carried / total fighter capacity” | **Missing.** Fighter rows are listed without the paired carried/capacity total. |
| Troops tab: “number of troop regiments carried / total troop capacity” | **Missing.** Troop rows are listed without the paired carried/capacity total. |
| Personnel tab: characters assigned to the fleet | **Present.** Fleet characters are populated in the Personnel tab. |
| Double-click a ship/fighter/troop/personnel entry to “drill down” to its information | **Partial.** Information is reachable through each row's **Status** command, but the manual's double-click drill-down gesture is not implemented consistently. |
| A fleet or ship “in hyperspace” is shown by moving stars / a glow around its icon | **Partial.** Rows say “Enroute — arrives Day …” and are darkened; the moving-star field and icon glow are absent. |
| “Any time a fleet, or a ship within a fleet, is in hyperspace, it cannot receive orders” | **Present.** Order items are disabled while `Status.Enroute`. |
| Drag ships between fleets; drag a ship to blank space to create/rearrange a fleet | **Present.** Fleet and unit drag/drop paths support detaching, combining, and moving contents. |
| Drag fighters, troops, or characters onto a fleet that can carry them | **Present.** The fleet row accepts character/unit drops and loading logic enforces capacity. |
| Fleet menu: “Move”, “Confirmed Move” | **Present.** Both use target selection; Confirmed Move requests confirmation. |
| Fleet menu: “Planetary Bombardment” → “Target Military Facilities”, “Target Civilian Facilities”, “General Bombardment”, “Destroy System” | **Present.** All four named choices exist, with eligibility and Death Star gates. |
| Fleet menu: “Planetary Assault” | **Present.** It is enabled only when assault conditions permit and resolves through `AssaultManager`. |
| Fleet menu: “Rename” | **Disabled.** The item is visible but no rename implementation exists. |
| Fleet menu: “Encyclopedia” | **Disabled.** The item is visible but no Encyclopedia window exists. |
| Fleet menu: “Status” | **Present.** It opens `FleetStatusWindow`. |
| Fleet menu: “Scrap” and the confirmation “Are you sure you want to scrap the following units?” | **Present.** It opens a confirmation and reports the refined-material return. |
| Built-ship menu: “Move”, “Confirmed Move”, “Create Fleet”, “Rename”, “Encyclopedia”, “Status”, “Scrap” | **Partial.** Move, Confirmed Move, Create Fleet, Status, and Scrap work; Rename and Encyclopedia are visible but disabled. |

Research confidence: **high** for controls and command wiring, **medium** for drag gesture parity because it has not yet been exercised in a running build.

## 3. Create Mission and Mission Status windows

Manual passages: assembling a mission, PDF pp. 100–101 (manual pp. 102–103); mission table, PDF pp. 103–106 (manual pp. 105–108); tracking missions, PDF p. 107 (manual p. 109); persistent missions, PDF p. 108 (manual p. 110). Labelled figures: `manual/ILLUSTRATIONS.md`, figs. 2.34–2.35 and 3.47–3.51.

| Manual element, in the manual's words | C# frontend state |
|---|---|
| Right-click selected character(s) or SpecForces and choose “Mission” | **Present.** Character and eligible unit menus launch mission targeting. |
| “the cursor changes to cross hairs”; select a target system by clicking “any area of blank space” in its window, or select the particular character/facility/unit required | **Present.** `StartMissionTargeting` accepts a system or object target and resolves fleets to their system. |
| “Create Mission” window | **Present, simplified.** It is a generated `ConfirmationDialog`, not a dedicated manual-layout scene. |
| Create Mission “Target” field | **Present.** It names the system and, for object-specific missions, the selected person/facility/unit. |
| Create Mission team/agent portraits or names | **Present as text.** The dialog lists the selected team by name rather than using the original portrait treatment. |
| “Select Mission” tab and mission list showing only missions available to that character/SpecForce for that target | **Partial.** The legal-filter behavior is present in an OptionButton, but there is no Select Mission tab or manual-style mission list. |
| “Decoy” tab and assignment of qualified team members as decoys | **Partial.** Decoy checkboxes work and are set before launch, but they are inline rather than on the manual's Decoy tab. |
| “Encyclopedia” control in Create Mission | **Missing.** No Encyclopedia control/window is provided. |
| “Assign” and “Cancel” | **Partial.** ConfirmationDialog provides accept/cancel behavior, but the accept button is not explicitly labelled “Assign” in code. |
| Transit time / units in hyperspace after assignment | **Present.** The dialog reports transit days and launch creates real mission travel time. |
| Double-click the Mission icon to bring up the Mission window | **Present.** The sector Mission corner opens `MissionWindow`. |
| Mission window may contain “more than one mission on a given system” | **Present.** It lists every unfinished player mission against the system and names each team. |
| Separate status for “AGENTS” and “DECOYS” | **Present.** Dedicated tabs/labels separately list operatives and decoys. |
| Mission progress/status, including hyperspace and persistent-mission progress | **Present.** Rows show travel days, attempt count, and Diplomacy support percentage. |
| Moving-star field indicates the mission team is “in hyperspace” | **Partial.** Status text reports “in hyperspace, …d out”; the moving-star visual is absent. |
| Right-click Mission icon: “Status”, “Encyclopedia”, “Abort” (and continue a persistent mission when applicable) | **Partial.** Status and per-mission Abort exist; Encyclopedia is visible but disabled. Persistent missions continue automatically, but there is no separately named Continue command. |
| “you cannot give orders to units in hyperspace” | **Present.** Abort is disabled until the team arrives, both in the icon menu and status rows. |
| Aborting/continuing applies to the selected mission when several share a system | **Present for Abort.** Each Abort entry names its mission/team. Continue is automatic rather than a selectable control. |

Research confidence: **high** for create/status controls and mission-menu wiring, **medium** for original visual arrangement because it has not yet been rendered side by side.

---

Priority pass delivered first at Lord Vader's request. The remaining fifteen window checklists follow below as the source/manual sweep continues.

## 4. Character Status Window

Manual passages: PDF pp. 40 and 94, 99 (manual pp. 41 and 96, 101); figs. 2.33 and 3.46.

| Manual element | C# frontend state |
|---|---|
| Name; “Commanding”; “Attached”; “Status”; “Force Ranking” | **Present.** The title names the character; all four fields update, including destination/days while in transit and captured/injured/mission states. |
| “Diplomacy Rating”; “Espionage Rating”; “Combat Rating”; “Leadership Rating” | **Present.** Raw ratings are displayed without incorrectly clamping the 0–150+ scale. |
| “R&D Capabilities”: Ship Design, Troop Training, Facility Design, each Yes/No | **Partial.** Capable tracks are listed; incapable tracks collapse to “None” instead of three explicit Yes/No rows. |
| “Possible Command Ranks”: Admiral, General, Commander, each Yes/No | **Partial.** Eligible ranks are listed; the original explicit Yes/No matrix is condensed. |
| Character portrait and Ready / In transit / Captured / Injured icon treatment | **Partial.** A portrait placeholder and status text exist; the manual's artwork/status icons are absent. |
| Status window is modal with its distinct Close button | **Partial.** Close exists, but the scene inherits movable/minimizable `DraggableWindow` behavior rather than the manual's modal behavior. |

Confidence: **high**.

## 5. Unit / Capital Ship Status Window

Manual passages: PDF pp. 113–115 (manual pp. 115–117), figs. 3.61–3.62; fighter and ground-unit status descriptions in the same passage.

| Manual element | C# frontend state |
|---|---|
| Assignment: fleet/attached location and “Status” | **Present.** Attached and Status rows are shown, including transit destination and days. |
| “Maintenance Cost” | **Present.** |
| Capital-ship Capacity: Fighter Squadrons, Trooper Regiments; Embarked: Fighters, Troops, Personnel | **Partial.** Fighter/Troop capacity exists, but the status window does not show the full embarked block or assigned fleet with the manual's grouping. |
| “Ship Damaged: yes/no” and burn-mark graphic | **Missing/partial.** Some current statistics are displayed, but there is no explicit Ship Damaged field or burn-mark rendering. |
| Current:capacity subsystem pairs: Hyperdrive, Hull, Damage Control, Shield Recharge, Maximum Shield, Tractor Beam, Sub-Light Engine, Weapon Recharge | **Partial.** Hyperdrive, hull, shield, and sub-light values exist; Damage Control, Shield Recharge, Tractor Beam, Weapon Recharge and most paired current:max semantics are missing. |
| Maneuverability, Detection Rating, Bombardment Modifier | **Present in simplified form.** |
| Weapon arc ratings by turbo laser / ion cannon / laser cannon × forward / aft / starboard / port | **Missing.** The implementation shows aggregate Laser, Ion Cannon and Torpedoes, not station-by-arc ratings. |
| Fighter “Squadron Size” (12 fighters) and remaining craft | **Partial.** It prints a fixed `12:12`; casualties/current strength are not modelled there. |
| Troop/SpecForce “Attack Strength”, “Defense Strength”, “Bombardment Defense”, “Detection Value” | **Present.** |
| 3D unit model / original unit artwork | **Missing.** The scene contains a `[ 3D Model ]` placeholder. |
| Modal Close behavior | **Partial.** Close exists; movable/minimizable behavior remains. |

Confidence: **high** for fields, **medium** for type-specific manual variants.

## 6. Fleet Status Window

Manual passage: fleet status block documented with fleet movement/command material, PDF pp. 54–55 and 93–95 (manual pp. 55–56 and 95–97); current source also records the photographed original wording.

| Manual element | C# frontend state |
|---|---|
| “Status”; “ETA Destination” as arrival Day N; destination/location | **Present.** ETA is calculated as an absolute game day. |
| “Admiral”; “General”; “Commander” | **Present.** Each independent command post is resolved separately. |
| “Number Of Ships” | **Present.** |
| “Capacity” — Fighter Squadrons, Trooper Regiments | **Present.** Values are summed across ships. |
| “Embarked” — Fighter Squadrons, Trooper Regiments, Personnel | **Present.** |
| “Damaged Ships” | **Partial.** The row exists, but the source notes damage modelling is incomplete and its test is only a proxy. |
| “Hyperdrive Rating” as Yes/No fleet capability | **Present.** |
| Modal status-window behavior | **Partial.** The close control exists, but the common draggable/minimizable chrome differs. |

Confidence: **high**.

## 7. Defense Facility Status Window

Manual passages: production/facility status, PDF pp. 82–85 and 125 (manual pp. 84–87 and 127); figs. 3.28–3.29.

| Manual element | C# frontend state |
|---|---|
| Location; “Status: ACTIVE, UNDER CONSTRUCTION, OR EN ROUTE” | **Partial.** Location and Active/Damaged exist; this window does not represent Under Construction or En Route variants. |
| “Maintenance Cost” in maintenance units | **Present.** Correctly labelled as maintenance, not credits/turn. |
| “Standard Processing Rate” for economic facilities | **Present.** It reports days per refined point. |
| “Weapons Rating” for batteries | **Present.** |
| “Bombardment Value” / per-facility bombardment defense | **Present.** |
| Facility type and level/tier | **Present.** |
| Original facility art/status image | **Partial.** Type glyphs substitute for the original art. |
| Status control for a project reports the day construction finishes | **Missing here.** Build completion is reported in `EconomyWindow` instead. |

Confidence: **medium-high**; the manual defines several facility status variants rather than one universal scene.

## 8. System Defenses Window

Manual passages: PDF pp. 27 and 99, 124–126 (manual pp. 28 and 101, 126–128); figs. 2.13, 3.45 and 3.73.

| Manual element | C# frontend state |
|---|---|
| Five tabs: “Personnel”, “Troops”, “Fighter”, “Planetary Shield”, “Planetary Battery” | **Partial.** Personnel, Troops and Fighters exist, but Shield and Battery are combined into one “Orbital Defenses” tab, yielding four tabs. |
| Personnel contains characters and Special Forces on the system, excluding personnel aboard fleets | **Present.** Own and known enemy personnel are gated and listed; SpecForces are kept out of Troops. |
| Troops contains trooper regiments and “Garrison Requirement” | **Present.** It shows requirement, present count, uprising warning and pending arrivals. |
| Fighter contains squadrons stationed on the system | **Present.** |
| Planetary Shield and Planetary Battery entries, including active/armed/damaged state | **Present but combined.** Both facility types are listed with state in the shared tab. |
| Right-click unit: “Move”, “Confirmed Move”, “Mission”, “Encyclopedia”, “Status”, “Retire” | **Partial.** Move, confirmation, eligible Mission, Status and Retire work; Encyclopedia is named but only logs/has no window. |
| Right-click character: “Move”, “Confirmed Move”, “Mission”, “Command”, “Encyclopedia”, “Status” | **Partial.** Core commands and rank assignment exist; Encyclopedia remains unavailable. |
| Double-click/status gesture for unit detail | **Partial.** Status is reachable from the menu, not consistently through the original double-click. |
| Espionage snapshot / uncertain enemy information | **Present.** Enemy sections use the intel view instead of exposing live state. |

Confidence: **high**.

## 9. Manufacturing and Production / Economy Window

Manual passages: PDF pp. 25–26, 31 and 82–85 (manual pp. 26–27, 32 and 84–87); figs. 2.10–2.12, 2.20 and 3.24–3.29.

| Manual element | C# frontend state |
|---|---|
| Six tabs: “Manufacturing”, “Shipyards”, “Training Yards”, “Construction Yards”, “Refineries”, “Mines” | **Present with one wording change.** The scene says “Training Facilities”; all six functional groups exist. |
| Default Manufacturing tab: “Ship Construction”, “Troops in Training”, “Facilities Under Construction” | **Present.** |
| Each queue's “Destination:” line and current-project progress bar | **Present.** Progress is for the current unit and tooltips report percentage/days. |
| Built : built-plus-under-construction number pair | **Present.** Capacity labels use the manual's `N:N` form. |
| Grayed-out tabs indicate none of that facility type | **Present.** Empty facility tabs are disabled. |
| Built-facility menu: “Encyclopedia”, “Status”, “Scrap” | **Partial.** Status and Scrap work; Encyclopedia is visible but unavailable. |
| Production menu: “Build”, “Stop”, “Destination”, “Rename” (ships only), “Encyclopedia”, “Status”, “Reserved” | **Partial.** Build/Stop/Destination/Status are wired; Rename and Encyclopedia are unavailable; Reserve is implemented for construction yards. |
| Build Selection: item; “Number to build”; “Refined materials necessary”; “Maintenance capacity necessary”; “Best Time To Completion”; “Best Time To Deployment”; Destination; accept/cancel | **Present.** The generated chooser calculates/gates all named fields. |
| Best Time To Completion is an absolute day; Deployment is additional days | **Present.** |
| Completed / under construction / en route use distinct images | **Missing.** Text/status/progress substitute for the original artwork states. |
| Enemy information may be an Espionage snapshot and become stale | **Present.** Intel views gate queues/facilities rather than exposing current state. |

Confidence: **high**.

## 10. Planet / System Data Window

Manual passages: sector-system close-up and economic/defense detail, PDF pp. 24–27 and 48 (manual pp. 25–28 and 49); figs. 2.9–2.13 and 2.47.

| Manual element | C# frontend state |
|---|---|
| System name and control/support information | **Partial.** The window shows name, holder and known support, but its layout is not one of the manual's primary labelled detail windows. |
| Energy and raw-material availability | **Partial.** Base Energy and Materials are text, not the manual's used/available colored bars. |
| Facilities present | **Present as a simple list.** |
| Unexplored system conceals detail | **Present.** It says “Unexplored Planet” and clears resource/facility detail. |
| Unpopulated-system treatment: no facilities/defenses/loyalty bars | **Partial.** The simplified text panel does not reproduce the manual's specific unpopulated artwork/layout. |
| Manual interactions through Manufacturing, Defenses, Fleet and Mission icons | **Missing from this scene.** Those actions live in `SectorWindow`, making `PlanetWindow` an extra simplified view rather than a faithful manual window. |

Confidence: **medium** because the scene has no exact one-to-one manual counterpart.

## 11. Sector Window

Manual passages: PDF pp. 24–25 and 61–62, 68, 85 (manual pp. 25–26 and 63–64, 70, 87); figs. 2.8–2.9 and 3.7, 3.33.

| Manual element | C# frontend state |
|---|---|
| Sector name title and system names colored by control | **Present.** |
| Each system's three bars: energy used/available, mined/raw materials, loyalty | **Present/partial.** The source builds resource/support indicators, but exact art fidelity is unverified. |
| Manufacturing icon; double-click/open Manufacturing and Production | **Present.** |
| Defenses icon at lower left; double-click/open System Defenses | **Present.** |
| Mission icon at lower right, side-attributed; double-click Status and right-click orders | **Partial.** Appearance, Status and Abort are present; Encyclopedia is disabled and no explicit Continue item is offered. |
| Uprising icon at lower right | **Present.** An uprising substitutes a triangle/flame-like marker and warning tooltip. |
| Separate Imperial and Alliance Fleet icons at upper right; open that side's Fleet window | **Present.** Side-specific icons/tooltips are built. |
| Star size follows the current GID mode | **Present, stylized.** A tier-sized `+` glyph is used. |
| Sector window cannot move or minimize; at most two; Close and flip-left/right arrows | **Missing/incorrect.** The scene inherits draggable/minimizable chrome, exposes Minimize, has no flip control, and no two-window invariant is evident. |
| Double-click gesture on detail icons | **Partial.** Buttons open on press; they do not consistently require the manual's double-click. |

Confidence: **high**.

## 12. Personnel Finder

Manual passages: PDF pp. 38, 44 and 96–98 (manual pp. 39, 45 and 98–100); figs. 2.31, 2.39, 3.42–3.43.

| Manual element | C# frontend state |
|---|---|
| “Characters” screen: searchable name list and Alliance / Imperial tabs | **Present.** Search filters live; two side tabs list name and known location. |
| Separate “Character Finder” / “SpecForces Finder” views | **Missing.** Only characters are represented. |
| SpecForces grid: each SpecForce type against each system, searchable by system | **Missing.** |
| Opponent-information warning and stale/unknown intelligence | **Partial.** Intel gating is enforced, but the manual's explicit warning text is absent. |
| “Display” closes finder and opens the system Defense/Fleet/Mission window containing the selection | **Partial.** Clicking a character on a planet opens Defenses; there is no Display button, the finder does not close, and characters aboard fleets only log a TODO. |
| Dagobah/Jabba concealment | **Present.** Off-map characters are omitted. |
| Finder is modal | **Missing/incorrect.** It uses draggable/minimizable common chrome. |

Confidence: **high**.

## 13. Planetary System Finder

Manual passage: PDF p. 73 (manual p. 75), fig. 3.12.

| Manual element | C# frontend state |
|---|---|
| Search/scroll by “System Name” | **Present.** Text filters the lists live. |
| Tabs: “All Systems”, “Rebel Systems”, “Imperial Systems”, “Independent Systems”, “Unexplored Systems” | **Present with terminology differences.** Tabs are All, Alliance, Empire, Neutral, Unexplored; Neutral is the same state the manual also calls Independent. |
| Color-coded systems | **Present.** Buttons use the system faction/exploration color. |
| “Display” or double-click opens the selected system/sector | **Partial.** A single press opens the containing Sector window; there is no explicit Display button or double-click requirement, and selection is sector-level rather than directly focusing the system. |
| Finder is modal | **Missing/incorrect.** Common draggable/minimizable chrome is used. |

Confidence: **high**.

## 14. Confirm Transit Window

Manual passages: movement/“Confirmed Move,” PDF pp. 44–45 and 109–111 (manual pp. 45–46 and 111–113).

| Manual element | C# frontend state |
|---|---|
| Confirmed Move reports “Transit time in days” for the selected person/group | **Present.** It names one character or `N Personnel` and the travel duration. |
| Yes / No confirmation | **Present.** Buttons are labelled `Y` and `N`; Yes executes and No cancels. |
| Modal accept/cancel behavior | **Partial.** It is functionally blocking for the order, but inherits a normal title bar with minimize/close rather than strict modal chrome. |
| If selected personnel cease to be eligible while confirmation is open, do not issue stale orders | **Present.** Refresh removes already-enroute people and closes when none remain. |

Confidence: **high**.

## 15. In-Game Menu / Game Options Window

Manual passages: PDF pp. 28 and 73–75 (manual pp. 29 and 75–77); figs. 2.14 and 3.13–3.16.

| Manual element | C# frontend state |
|---|---|
| Game Options via F1/control strip | **Partial.** This scene is a basic Game Menu, not the manual's Game Options screen. |
| Six save slots with names and side/head-to-head icons; Save/Load/Delete | **Missing.** |
| Sound controls and tactical toggles: Show Starfield, Show Planet, Show Pyrotechnics, Use High Detail Models, Display Holocube | **Missing.** |
| Resume/close | **Present.** “Resume Game” and X close the window. |
| Exit to Main Menu / Exit to Desktop | **Present, extra.** Both controls are wired, though they are not a replacement for manual save/options controls. |

Confidence: **high**.

## 16. Display Message Index / Message Window

Manual passages: PDF pp. 32, 42 and 76–77 (manual pp. 33, 43 and 78–79); figs. 2.23, 2.36–2.38 and 3.18.

| Manual element | C# frontend state |
|---|---|
| Nine categories: “Loyalty”, “Fleet”, “Mission”, “Resource”, “Manufacturing”, “Defense”, “Conflict”, “Chat”, “Advice” | **Present.** Scene tabs map to all nine; plural internal names are retitled for Fleet/Mission where needed. |
| “All Messages,” excluding Agent Advice | **Present.** A generated All tab excludes Advice. |
| Opens on “Agent Advice” after the opening briefing | **Unknown/partial.** Advice exists, but this source pass did not find the startup selection guarantee. |
| Message list plus selected report/detail and portrait | **Partial.** List/detail work; portrait is a placeholder. |
| Posting options / select messages / delete selected | **Present.** Select All and Delete Selected Messages controls are generated. |
| “Go To” associated system | **Present.** Enabled only when the message carries a location. |
| Persistent mission result asks whether to “Continue Mission” or “Abort Mission” | **Present.** Both buttons are generated for applicable reports. |
| Delete individual message | **Present.** |
| Unread/read visual distinction | **Present.** Selected/read messages are recolored. |
| Message windows are modal | **Missing/incorrect.** Common movable/minimizable chrome is used. |

Confidence: **high**.

## 17. Military Data Editor

Manual passage: **none**. This is a developer tool, not a player-facing Rebellion window.

| Manual element | C# frontend state |
|---|---|
| No corresponding manual window/control | **Out of scope for fidelity.** The scene provides a filter, military-unit tree, generated property editor, status label, “Save Changes,” and “Back to Menu.” It should be ported only if developer tooling is intentionally in the 18-scene target. |
| Player access | **Extra/non-manual.** The root menu exposes “View Military Data”; faithful production UI should hide or clearly classify it as tooling. |

Confidence: **high**.

## 18. Shuttle Cockpit / Root Main Menu

Manual passage: PDF p. 20 (manual p. 21), fig. 2.2; save/options elaboration PDF pp. 73–75 (manual pp. 75–77).

| Manual element | C# frontend state |
|---|---|
| New-game difficulty / challenge level | **Present.** Easy, Medium and Hard are exclusive selections; Medium defaults. |
| Galaxy size | **Present.** Small, Medium and Large are exclusive selections; Medium defaults. |
| Choose Alliance/Rebel or Empire/Imperial side | **Present.** Side buttons start the game using pack-order factions. |
| “Headquarters Only Victory” | **Present.** Checkbox feeds game settings. |
| Head-to-head / two-player choice | **Missing.** |
| Load game / six save slots | **Missing.** |
| Exit | **Present.** |
| Shuttle Cockpit artwork and original side/difficulty controls | **Present (2026-09-22).** The pack's `menu` picture with one clickable region per Fig. 2.2 label (`packs/<id>/pack.json`, `src/ui/menu.gd`); selection shown as corner brackets, the victory readout painted under the centre screen. A pack without a picture keeps the labelled buttons. |
| “View credits” | **Present (2026-09-22).** A region on the picture; the lines are the pack's `menu.credits`. |
| “View Military Data” | **Extra/non-manual.** Developer-tool entry. |

Confidence: **high**.

## Cross-window fidelity risks

- The 18-scene count is the 16 `frontend/*.tscn` scenes plus root `Main.tscn` and `Menu.tscn`; the Galaxy Map/GID checklist covers `Main.tscn`.
- Most System, Status, Finder and Message scenes inherit `DraggableWindow`, so the manual's modal-vs.-nonmodal rules are not preserved.
- The manual's Window Reference Bar allows twelve minimized System windows; current taskbar behavior should be verified as a separate cross-scene acceptance test.
- Manual double-click gestures are frequently implemented as single button presses. Porting scene structure alone would preserve that mismatch unless gestures are explicitly corrected.
- Encyclopedia controls are repeatedly named but disabled or unwired because no Encyclopedia window exists.

Overall checklist confidence: **high for named fields and code wiring; medium for visual fidelity and runtime gestures pending a rendered/play-tested pass.**
