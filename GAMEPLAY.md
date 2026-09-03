<!-- last synced from sol-conflict-revolution commit 10cdb80 -->
# Gameplay rules, from the manual

How *Star Wars: Rebellion* actually works, read from the scanned page images in
`manual/pages/` rather than the OCR'd `data/SWR_Manual.txt` (which garbles the
figures and callouts — exactly the parts that carry the rules).

**Page references are PDF pages**, matching the image filenames. Where a printed
manual number exists it is given too, as `PDF p024 / manual p025`. The offset
varies 0–2 across the book, so a bare page number is always ambiguous — see
`manual/PAGE-MAP.md`.

> **Status: COMPLETE for Chapters 1–3.** Every rendered page — **PDF p001–p135**,
> cover through the end of Chapter 3 — has been read as an image. The coverage
> table at the bottom lists them. Everything here is quoted or paraphrased from a
> page actually looked at; nothing is inferred from the OCR text.
>
> **Not covered:** Chapter 4 (Tactical), PDF p136–p153. Chapter 5 (Head-to-Head),
> PDF p152–p163, is digested at the end of this file (2026-09-03); `manual/pages/`
> now runs to PDF p167. What the strategic chapters say *about* tactical play is
> recorded in §§1, 11, 13 and 14.

**Sections marked ★** carry a rule that appears nowhere else in the manual, or
that contradicts what the code currently does. If you read nothing else, read
those.

**Quick index of the reference tables:**

| Table | Section |
|---|---|
| Everything that moves popular support | §9 |
| The 15 mission types — target, effect, attribute | §12 |
| Every GID mode, defined | §20 |
| Capital ships and their carrying capacity | §13 |
| Trooper regiment attack / bombardment / defense | §15 |
| Planetary shields and batteries | §15 |
| Victory conditions | §17, §18 |
| Garrison requirement state machine | §15 |

---

## 1. Frame of the game

**Real-time, not turn-based.** *(PDF p019 / manual p020)*

> Star Wars Rebellion is a real-time game, not turn-based like most strategic
> simulations. That is, while you are evaluating your systems and making your
> moves, your opponent is also in action.

Combat you are dragged into can be auto-resolved — the Battle Alert screen
(Fig. 2.1) offers **Simulate Results**: *"Click here to have the computer
simulate the battle and report the end results."*

**New-game parameters** *(PDF p020 / manual p021, Fig. 2.2 Shuttle Cockpit)* — the
complete set:

| Setting | Values |
|---|---|
| Difficulty | easy *(default)* / medium / hard |
| Galaxy size | standard *(default)* / larger sizes |
| Side | Alliance or Empire |
| **Headquarters Only Victory** | *"Winner is the first to capture opponent's headquarters. This makes the game shorter than fulfilling all the victory conditions."* |
| Head-to-head | modem / network / internet |

A "system" is the same thing as a planet: *"In Star Wars Rebellion and in this
manual, a system is synonymous with planetary system and planet."*
*(PDF p023 / manual p024)*

---

## 2. Colour code — control, everywhere

*(PDF p023 / manual p024, Fig. 2.6)*

| Colour | Meaning |
|---|---|
| **Red** | The Alliance |
| **Green** | The Empire |
| **Blue** | Neutral system |
| **Gray** | Unexplored system |
| **Red with white highlight** | **Alliance headquarters** |

> The color code indicates which side **controls** each system. These color codes
> apply **throughout the game**, not just for the Popular Support display.

And the sector window explicitly matches it *(PDF p024 / manual p025)*:

> Note the colors of the icons and system names are the same as those in the
> Galactic Information Display: Red Alliance, Green Empire, Blue Neutral.

Control and support are independent — a system can support your side while your
opponent controls it:

> Note that a system can support your side even if it is controlled by your
> opponent. A large green star, for example, represents a system that is
> controlled by the Empire, but supports the Alliance.

Magnitude is shown by **marker size**, not hue: *"larger stars indicate one or
more mines."*

---

## 3. Resources are capacity gauges, not stockpiles

This is the single most important mechanical point, and it is stated three
different ways across the tutorial.

### Energy = slots *(PDF p023 / manual p024)*

> Energy availability is represented as small blue squares … You can think of
> these blue squares as **"slots"** for facilities such as construction yards,
> mines, and refineries. **One energy slot is required to support each facility.**
>
> NOTE: **You cannot change the total number of energy slots available for a
> system.** … how to scrap facilities you're not using to **make room** for new
> ones.

One slot per facility, flat. The total is immutable. Running out doesn't degrade
anything — it means *you cannot build here until you scrap something*.

### Raw materials = mine slots *(PDF p026 / manual p027, Fig. 2.12)*

> Raw Materials Status Bar: … three mine **slots** (yellow); six remaining raw
> material **slots** (red). … there are enough resources for **nine mines, three
> of which have already been built**. … hovering shows the message
> **"Raw Materials 3/9."**

So a planet's raw-material figure is the **total number of mines it can ever
host**, and the bar reads *built / total*.

### The daily flow is raw → refined *(PDF p028 / manual p029)*

> You produce raw materials with mines, and then process those raw materials with
> refineries to produce refined materials. Everything you build in Star Wars
> Rebellion takes a certain amount of **refined materials** to produce.
> Furthermore, everything **except mines and refineries** also takes a certain
> amount of **maintenance capacity**. **Mines and refineries supply maintenance
> capacity.**

### Mine/refinery pairing is GALAXY-WIDE *(PDF p029 / manual p030)*

> **Each refinery can process materials from one mine you control, which can be
> anywhere in the galaxy.** Furthermore, you gain maintenance capacity by having
> **matched pairs** of mines and refineries. For these reasons, you make optimal
> use of your resources when you have a **one-to-one ratio** of mines to
> refineries.

A refinery does **not** have to sit on the same planet as its mine, or even in
the same sector. Pairing is a galaxy-wide count, which is why the advice is
simply to keep the totals equal. The Galaxy Overview exists to compare those two
numbers (the manual's example: 18 refineries against 37 mines → build refineries).

### The facility catalogue *(PDF p080 / manual p082)*

Facilities are either **manufacturing and production** or **defensive**. The
production set:

| Facility | Does | Parallelism |
|---|---|---|
| **Mine** | *"give you access to a system's raw materials"* | — |
| **Refinery** | *"refine mined materials to produce refined materials, which are used to build every type of unit"* | — |
| **Construction Yard** | builds **other facilities** | *"Two construction yards **double the speed**, three **triple** the speed, and so on."* |
| **Training Facility** | builds **troops and Special Forces** | two double, three triple, … |
| **Orbital Shipyard** | builds **capital ships and fighters** | two double, three triple, … |
| **Advanced Construction Yard** | builds facilities *"more efficiently than standard"* | **R&D-gated** |
| **Advanced Training Yard** | troops/SpecForces, more efficiently | **R&D-gated** |
| **Advanced Shipyard** | ships, more efficiently | **R&D-gated** |

> Not all of these facilities are available at the beginning of the game.
> **Advanced facilities are only available after the technology is developed from
> Research and Development.**

**Production speed scales linearly with the count** of the relevant facility on
that system — a clean, directly implementable rule.

### Refineries work galaxy-wide, stated outright *(PDF p080 / manual p082)*

> **Mines and refineries do not have to be on the same system to work together.**
> Refineries that are on **any system you control** automatically refine mined
> material **from any other system you control.**

### Building requires a free slot of the right kind *(PDF p030 / manual p031)*

Figs. 2.18 / 2.19 make the gating explicit with two contrasting worlds:

> Bortras has energy (blue squares) for three more facilities. It also has red
> squares indicating there is raw materials available for mines.
>
> Here **Denab has raw materials available, but not energy, so you couldn't build
> a mine here.**

So:

| To build | Requires |
|---|---|
| any facility | a free **energy** slot |
| a **mine** | a free energy slot **and** a free **raw-material** slot |

Both are per-system and both are capped. There is no notion of overdrawing.

### The three monitors *(PDF p029 / manual p030, Fig. 2.15)*

Above the GID, three galaxy-wide readouts:

| Monitor | Meaning |
|---|---|
| **Raw materials** | mined material *waiting to be refined*. Should ideally be **low** — that means everything is being refined as fast as it is mined. |
| **Refined materials** | on hand to build facilities, ships and troops. Starts at zero: *"You may not begin the game with any refined materials, but they will begin to accumulate immediately."* |
| **Maintenance** | how much **unallocated** maintenance is available. |

The Galaxy Overview *(Fig. 2.17)* lists every facility, SpecForce, ship and troop
type in three columns: icon, **how many you control**, and **total maintenance
requirement for those items**.

### Concrete costs, and what modulates production *(PDF p079 / manual p081)*

Chapter 3 states the economy canonically, with numbers:

> Raw materials, refined materials, and maintenance capacity are all measured in
> **units**. Each mine you build produces raw materials. **A mine costs 20 units
> of refined materials to build, but doesn't cost anything to maintain.** …
> **Refineries cost 20 units of refined materials to build** and, like mines,
> **don't cost anything to maintain**. Refineries produce refined materials from
> the raw materials produced by mines.

> Every facility, ship, troop or SpecForce unit in the game **requires refined
> materials to produce**. These materials are … **drawn from the available supply
> as needed by the construction yard, training yard, or shipyard.** … if you don't
> have enough refined materials, **building slows until the supply is sufficient**.
> Once a unit is built, the refined materials used to produce it are considered
> **"used up."**

**Two rate modifiers on production — both new, and one reverses the code's
causality:**

> The more maintenance units that a mine or refinery **has to contribute**, the
> **slower** it will be in processing raw/refined material points.
>
> Also, **the lower the popular support in the system for your side, the slower
> the mines and refineries in the system will be in processing raw/refined
> material points.**

So the causal arrow runs **support → production**. A disloyal world produces
slowly. Nothing anywhere runs the other way: production problems never cost you
loyalty.

> ⚠️ The code has this exactly backwards. `Planet.ProcessDailyTick` applies a
> support penalty when energy is short (production → support). The manual has
> support *throttling* production (support → production), and no path from
> economic trouble to loyalty at all.

### Maintenance = a one-time galaxy-wide pool

> Unlike raw and refined materials, which are generated each day like a steady
> stream, your total maintenance capacity is more like a **pool**. Each
> mine/refinery combination makes a **one-time contribution of 50 units**.
> Likewise, units, facilities, and ships make a **one-time withdrawal**.
> Maintenance units are taken **as soon as you give the order to build**.

Failure modes, in order of severity:

- Too low → *"you won't be able to build anything new except mines and refineries."*
- **Below zero** → *"your facilities, troops, or ships will begin to be scrapped."*

Because the pool comes from **matched pairs**, the manual advises keeping mines
and refineries at roughly **1:1**.

---

## 3a. Building things

*(PDF p031 / manual p032, Fig. 2.20 — the Build Selection window)*

Ordering a build goes: right-click your agent droid → **Build Facilities** →
the cursor becomes targeting crosshairs → **click the destination system** →
the Build Selection window opens.

Every buildable item carries **two costs and two times**:

| Field | Meaning |
|---|---|
| Maintenance capacity necessary | drawn from the galaxy-wide pool, **at order time** |
| Refined materials necessary | consumed to produce it |
| **Best Time To Completion** | days to build (example: 40) |
| **Best Time To Deployment** | days *"needed to deploy facility to destination system once it has been built"* (example: 9) |

So construction is a **two-stage** process — build, then ship to the destination —
and both stages take days. You also choose **Number to build** in one order.

While in progress, the destination system's Manufacturing and Production window
shows the new facility **surrounded by a grid** to mark it as still being built
*(Fig. 2.21)*.

### The two costs behave differently *(PDF p046 / manual p047)*

An important asymmetry:

> **C-3PO will tell you if you don't have the maintenance capacity** for something
> you want to build. **If you don't have the refined materials you need on hand,
> construction will take longer** but you will eventually get some materials to
> build with and can, therefore, **still initiate the build**.

| Cost | If you can't afford it |
|---|---|
| **Maintenance capacity** | **blocks** the build outright |
| **Refined materials** | build still starts, just **takes longer** |

So maintenance is a hard gate checked at order time; refined material is a rate
limiter.

### Construction yards are required *(PDF p034 / manual p035)*

> Facilities in Star Wars Rebellion **do not spring into existence
> automatically**. In order to build a facility, one of the systems you control
> **must have a construction yard**.
>
> NOTE: If the Build Facilities option doesn't let you build anything at the
> beginning of the game, **it means you don't have any construction yards.**

Using the agent's *Build Facilities* option is shorthand for *"find the nearest
available construction yard and issue a Build command to that construction
yard."* You can also command a yard directly, which gives more control — and
matters because **deployment time scales with distance**:

> it takes longer to deploy facilities to systems that are farther away. **It
> takes a very long time to deploy facilities to a system in a different
> sector.**

The destination must have the free slots for what you are sending: *"if the
original destination setting does not have enough system energy or raw material
points"* you must re-issue Destination then Build.

> ⚠️ **Conflicts with the code.** `Planet.ConstructionYards` defaults to `1`
> with the comment *"Default to 1 so planets can build!"*. The manual is explicit
> that a system without a real construction yard **cannot build at all**, and that
> starting without one is a legitimate (if awkward) game state. See
> `ECONOMY-NOTES.md`.

### Production facilities go idle *(PDF p032 / manual p033)*

> NOTE: Any time a **construction yard, shipyard, or training facility** completes
> its task — which you may have assigned directly or through your agent — the
> message system says **when that production facility is free again**.

This is what the GID's "Idle Construction Yards / Idle Shipyards / Idle Training
Facilities" modes report: a production facility with nothing queued.

### Time and speed *(PDF p032 / manual p033, Fig. 2.22)*

A **day counter** sits at the top of the screen; next to it is the Game Speed
control: **Pause, Very Slow, Slow, Medium, Fast**. One "day" is the game's tick.

### The agent droid menu *(PDF p029, p031, Figs. 2.16 / on-page)*

Right-clicking your agent droid (C-3PO for the Alliance, IMP-22 for the Empire)
gives: **Build Ships, Build Troops, Build Facilities, Galaxy Overview,
Objectives, Manage Garrisons, Manage Production, Translate Counterpart, Agent
Advice.** The message droid (R2-D2 / SD-7) carries **Messages** and **Message
Alerts**; messages other than Agent Advice eventually expire.

---

## 4. The sector window

*(PDF p024 / manual p025, Figs. 2.8 & 2.9)*

Systems are shown as planet artwork with the system name beneath, coloured by
controlling faction. Beneath each system are **three bars**:

| Bar | Left end | Right end |
|---|---|---|
| 1 | Used energy | Available energy |
| 2 | Mined materials | Raw materials ready to be mined |
| 3 | Percent loyal to the **Empire** (green) | Percent loyal to the **Alliance** (red) |

**Icons around a system, shown only when relevant** *(PDF p025 / manual p026)*:

| Icon | Position | Appears when |
|---|---|---|
| Manufacturing | top left | the system has any manufacturing facilities, mines, or refineries |
| System Defenses | lower left | the system has troops, fighter squadrons, personnel, or system-based defenses |
| Fleets | right side | the system has a fleet |

Double-clicking an icon opens the corresponding detail window.

---

## 5. Detail windows

**Manufacturing and Production** *(PDF p025 / manual p026, Fig. 2.10)* — leftmost
tab shows counts of shipyards, training facilities and construction yards, plus
progress of the current project. Five further tabs give graphic views of
shipyards, training facilities, construction yards, refineries and mines. The
construction-yard readout is a pair: *"First number is number of construction
yards in system"* / *"second number is … construction yards currently being built
or deployed onto that system."*

**Mine tab** *(PDF p026 / manual p027, Fig. 2.11)* — shows mines as mechanical
units and raw material as multicoloured piles, i.e. built vs available capacity.

**System Defenses** *(PDF p027 / manual p028, Fig. 2.13)* — tabs for Personnel,
Trooper Regiments, Fighters, Planetary Shields and Planetary Batteries. Displays
**"Garrison Requirement: N"** — *"the number of troops required to maintain
control of the system."*

**Game Options** *(PDF p028 / manual p029, Fig. 2.14)* — save/load by name, sound
options, tactical display options, return to Command Center, return to Shuttle
Cockpit to begin a new game, exit.

---

## 6. Missions

*(PDF p036 / manual p037, Mini-Mission 3)*

> A mission is a specific task a character attempts to accomplish.

**The lifecycle:**

1. You send characters on missions **from a system or fleet you control**.
2. You select the mission **and the destination**.
3. *"Once you've assigned the mission, the character immediately travels to the
   destination."*
4. *"When he or she reaches the destination, the character begins performing the
   mission."*
5. The message droid tells you when the character is ready to report.

**Outcomes**, in two layers:

> Some missions into your opponent's or neutral systems can be **foiled**, which
> means the enemy detected your personnel and thwarted their efforts. If this
> happens, your agents **may be killed, injured or captured**.
>
> Missions that aren't foiled can end in **success or failure**, depending in
> large part on the **skills of the personnel** on the mission.

So detection is resolved separately from, and before, success. Outcome depends on
*"the type of mission, the destination, and the character's strengths and
weaknesses"*, plus *"random forces at work, which means success is never
guaranteed."*

**Repeating missions:** *"On certain types of missions, the character will ask you
if you want the mission to continue, until their efforts can no longer produce
results."*

**Not everyone can do everything** *(PDF p046 / manual p047)*:

> NOTE: Each character or SpecForce is capable of performing **only some of the
> mission types**. Note that you can't send the Longprobe off on a Diplomatic
> mission; nor can you send Princess Leia to explore the far reaches of the
> galaxy.

Mission eligibility is a property of the unit type. Also, on an **unexplored**
system, *"Reconnaissance is the only mission available"* — mission availability
is filtered by the target's state as well as by the actor.

**Diplomacy raises popular support.** Picking targets: prefer neutral (blue)
systems that already lean your way, since *"diplomatic missions work by
increasing popular support"*, and prefer ones with resources (red/yellow squares)
and energy (blue/white squares) — ideally already holding manufacturing
facilities.

This is the first mechanic found that moves popular support, and it is a
**player action**, consistent with support never drifting on its own.

### Support and control, defined *(PDF p086 / manual p088)*

> Popular support in Star Wars Rebellion, **sometimes called loyalty**, is a
> measurement of how strongly a system **supports your side**. Key systems —
> **Coruscant**, for example, **Yavin**, and the **Alliance headquarters** — begin
> the game **completely in support of their sides**. In most other cases, at least
> some of the population has support for the opponent. How strongly a system
> supports your side is **susceptible to change throughout the game**.

> Tied closely with the concept of popular support is **control**: whichever side
> controls a system can **station troops** or **draw resources** from that system.

So the two are distinct: **support** is the population's sentiment; **control** is
who may garrison and extract. Colour shows control; the loyalty bar shows support.

Note the named exceptions — Coruscant, Yavin and the Alliance HQ start at
**100% for their owner**, which is the behaviour to preserve.

### What affects popular support — the canonical list *(PDF p087 / manual p089)*

> The following are the **key issues that affect popular support**:
>
> - **DIPLOMACY MISSIONS**: increase popular support for your side. **You cannot
>   send characters on Diplomacy missions to enemy systems.**
> - **SUBDUE UPRISING MISSIONS**: also increase popular support (**much more
>   slowly** than a Diplomacy mission). Can only be sent to systems **in a state of
>   uprising**, and they help end the uprising.
> - **OTHER SYSTEMS IN SECTOR**: *"Changes in support on a system can **affect
>   popular support on other systems in that sector**."* If you gain a system
>   through support alone, **others may follow suit**; if your opponent takes one
>   of yours the same way, *"other systems in that sector may become neutral, and
>   neutral systems may go over to your opponent's side."*
> - **ABANDONING A SYSTEM**: removing your last trooper regiment, when support has
>   shifted away from you.

Support **contagion within a sector** is a real modelled mechanic, not flavour.

### Control without support has costs *(PDF p087 / manual p089)*

Two routes to controlling a populated system:

1. **Raise support** — *"By increasing popular support on a neutral system, you can
   bring the planet under your control."*
2. **Occupy it** — *"If there is not enough popular support on a system for your
   side to control it, you can take control of it by **placing trooper
   regiments** on it. To do this you need to **assault** the system."*

Occupation is inferior, and the manual says exactly why:

> even though you can control a system with trooper regiments, **the speed at
> which mines and refineries produce** raw and refined material points, **and the
> chance that these points will be smuggled away** from your side, **is influenced
> by the popular support** in a system.

**Smuggling** *(new mechanic)*:

> If a system you control **does not strongly support your side**, **smugglers may
> begin to steal resources** from the mines and refineries on that system.
> **Resources stolen in this way will be turned over to your opponent.**
>
> Smuggling can be **reduced by placing trooper regiments, ships, and fighters** in
> the system.

So low support has two economic consequences: **slower production** and **theft
that funds your enemy**.

### Unpopulated systems and how to keep them *(PDF p087 / manual p089)*

> Unpopulated systems can be controlled by placing one or more trooper regiments
> on them. However, if you do this, you will **only continue to control the system
> as long as you leave one or more trooper regiments** on it, because the system
> will still be unpopulated.
>
> **Unpopulated systems attract a population 100 percent loyal to your side as
> soon as your first facility arrives at the system.** Therefore, it is a good idea
> to build a facility at an unpopulated system that you control as soon as
> possible, so that the system gains a population and **your control … doesn't
> depend on the continued presence of trooper regiments.**

A concrete colonisation loop: garrison → build a facility → population appears at
100% loyalty → garrison can leave.

### Manage Production *(PDF p086 / manual p088)*

The agent can automate expansion:

> C-3PO or IMP-22 will build **mines and refineries in any open energy and raw
> material slots** it finds. It will start with slots **closest to the construction
> yards** and expand from there. The agent will work to **balance the number of
> mines and refineries**, and to **maximize your maintenance points**, but **it
> won't scrap** mines or refineries to bring the two into balance. Once turned on,
> it will not stop **until there are no available energy and/or raw material slots
> remaining**, or until you turn it off.

Also confirms per-unit maintenance draw: the Galaxy Overview example shows
*"six X-wings are each using eight maintenance units"* — so the column is
`count × per-unit cost`.

### Support drives control *(PDF p042 / manual p043)*

Diplomacy is incremental, and when support goes far enough the system **changes
hands**:

> A diplomatic mission may have "success" in **increasing popular support** for
> the Alliance, **even if it doesn't quite sway the system to your side**. Often
> it takes an ongoing diplomatic effort to sway a system.
>
> You may need to **repeat the diplomatic mission several times** before the
> system **joins the Alliance**. When that happens, C-3PO reports "Good news
> about support for the Alliance." **The system's name changes to red.**

So control of a neutral system is *won by accumulating popular support*, not by
invasion alone — and the colour change is the visible confirmation, consistent
with colour meaning control.

The in-game report shows the granularity: *"My diplomacy mission to Tralus has
increased popular support on that system. The population does not strongly
support either side. Do you wish the mission to continue?"*

**Auto-continue:** *"If you don't respond … she will automatically continue the
mission until the system is **100 percent loyal to your side**."* So a repeating
mission's terminal condition is full loyalty.

---

## 7. Characters — where they can be

*(PDF p038 / manual p039)*

> There are **five possible locations** for characters in the game: on a
> planetary system **awaiting orders**; **on a mission** at a system; **captured**
> by your opponent on a system or fleet; **on a fleet** that is in orbit about a
> system; or **en route** between systems or fleets.

That is the complete character state model. It maps closely onto the code's
`Status` enum (`AwaitingOrders`, `Enroute`, `OnMission`, `Kidnapped`, `Dead`),
with two differences worth noting: the manual distinguishes *on a system* from
*on a fleet* as **locations** rather than statuses, and death is not in this list
(it is an outcome, covered later under "When Bad Things Happen to Good
Characters").

Special cases with **no geographic location**: Han, Luke, Leia and Chewbacca can
be at **Jabba's Palace**, and Luke goes to **Dagobah** at some point.

### ★★ Personnel only stand on ground your side holds *(confirmed — measured in the original)*

Two halves of one rule, both **observed first-hand in the original game**:

| | Rule |
|---|---|
| **Moving in** | The **Move** order refuses a neutral or enemy system. Personnel can be moved only to worlds your side controls. |
| **Being pushed out** | When a world **stops being yours** — falls to an assault, or goes neutral at the end of an uprising — the personnel standing on it **relocate to a world you still hold**. They do not stay. |

**The exception is fleets.** A character aboard a fleet goes wherever the fleet
goes, including over a world your side does not hold — that is what blockade and
assault are. Boarding and disembarking are unaffected in orbit you control.

The manual never states either half directly, so **measurement is the source**.
What it does say is consistent throughout, and none of it contradicts the
measurement:

- Control "allows you to **freely move forces to a system**" (manual p012).
- A character whose mission ends on a system **"not friendly to your side"**
  **returns to base** rather than remaining on it (manual p110) — the same fact
  seen from the mission side.
- The way personnel reach ground you do not hold is a **mission**: Diplomacy to a
  neutral world, Incite Uprising to an enemy one, Espionage to any explored
  system (manual p106).
- A refuge is chosen as **"a friendly system nearest to"** where the character
  ended up (manual p111) — used here to pick where the evicted go.

**In the code:** the move gate is `backend/OrderManager.cs` (`MoveCharacters`,
and `MoveUnits` for SpecForces — personnel is characters **and** Special Forces,
manual p126). The eviction is `MilitaryCatalog.WithdrawPersonnel`, called from
every place control changes hands: `AssaultManager`, `Planet` (uprising runs its
course), `Mission` (Diplomacy converts a neutral world).

⚠ **Troop regiments and fighter squadrons are not gated** — they are not
personnel, and the manual's route for putting troops on ground you do not hold is
a **planetary assault mounted from a fleet** (manual p057).

### ★★ Ground fighter squadrons are destroyed with the world *(confirmed — measured in the original)*

**Observed first-hand:** a world flipped by an uprising simply **lost its fighter
squadrons — they disappeared, and no other system in the sector received them.**
Destroyed, not captured by the new owner and not evacuated.

Only the ones **on the ground**. "Fighters in a system that are not part of a
fleet are considered to be in hangars on the ground rather than in orbit"
(manual p129) — a squadron aboard a carrier is in the fleet's hangars and flies
out with it.

**Trooper regiments never arise.** Neither route to a change of control can be
reached with a garrison still standing:

| Path | Precondition |
|---|---|
| **Planetary assault** | captures only when **every defending regiment is dead** |
| **Uprising** | takes the world only when the garrison is **already zero** |

So "destroyed" and "evacuated" are indistinguishable for troops — there is
nothing there either way, and nothing to implement.

**Facilities change hands with the world**, which is what makes a developed world
worth taking.

**In the code:** `MilitaryCatalog.OnControlChanged` is the single entry point for
both this and the personnel rule above, called from all three sites that reassign
`ControllingFaction`.

⚠ **Scope of the measurement:** the **uprising** path is the one observed. The
assault path runs the same rule by extension — same event, and the behaviour it
replaced was broken under any reading (squadrons left in the captor's system,
still flagged to the old faction, orderable by nobody). **If the original hands
them to the captor instead, `DisbandGroundFighters` is the one place to change.**

### The character stat block *(PDF p040 / manual p041, Fig. 2.33)*

The Character Status window lists exactly:

| Field | Example (Leia Organa) |
|---|---|
| Commanding | None |
| Attached | Yavin *(the system **or fleet** the character is attached to)* |
| Status | Awaiting Orders |
| Force Ranking | None |
| **Diplomacy Rating** | 120 |
| **Espionage Rating** | 30 |
| **Combat Rating** | 50 |
| **Leadership Rating** | 70 |
| R&D Capabilities | Ship Design: No / Troop Training: No / Facility Design: No |
| Possible Command Ranks | Admiral: No / … |

> A character's ratings are of particular interest when you're **selecting a
> character for a mission**.

This matches the shipped character data exactly — `major_characters.json` and
`minor_characters.json` carry `DiplomacyBase/Var`, `EspionageBase/Var`,
`CombatBase/Var`, `LeadershipBase/Var`, the three `*ResearchBase` fields,
`JediLevelBase/Var`, and `CanBeAdmiral` / `CanBeGeneral` / `CanBeCommander`. Note
ratings run **above 100** (Leia's Diplomacy is 120), so they are not percentages.

**Diplomacy's effect is stated twice, unambiguously:** *"Diplomacy works by
increasing popular support on the destination system."*

A **Mission icon** appears at the lower-right of a system in the sector window
while a mission is in progress there; double-clicking it opens Mission Status.
Characters in transit are shown as *"in hyperspace"*.

### Base systems and return-to-base *(PDF p044 / manual p045)*

Units — including SpecForces — *"are all assigned to specific **base systems**. At
the end of a mission, this is where the unit **automatically returns**."*

> NOTE: There are some exceptions to this general rule; **successful diplomacy
> missions end with the character remaining on the system**, for example.

You can see a unit's base via its **Status** menu ("Attached" location). A unit's
right-click menu is: **Move, Confirmed Move, Mission, Encyclopedia, Status,
Retire**.

**Alliance SpecForce types:** Bothan Spies, Infiltrators, Guerrillas, Longprobes.

### Travel time *(PDF p044 / manual p045)*

> it takes **much longer** for units to travel **between sectors** than it does to
> travel **between systems within a sector**

Two-tier travel cost, matching the facility-deployment rule. This is also why
basing matters: *"it's a good idea to establish the team's base in a sector
that's mostly unexplored."*

#### ★★★ The travel formula, measured *(confirmed — 9 readings, all exact)*

The manual's "two tiers" is literal: the two regimes read **different inputs**,
not the same formula with different constants.

```
between sectors:   days = round(distance x hyperdrive / 512)
within a sector:   days = ceil(distance / 8),  +2 if not aboard a ship
a fleet's rating = the HIGHEST hyperdrive number among its ships
```

**Hyperdrive is a time multiplier — LOWER IS FASTER**, and it does nothing at all
within a sector. Distances are Euclidean over `SYSTEMSD.DAT` map coordinates, so
they are directly comparable with ours.

| Leg | Distance | Traveller | Formula | Observed |
|---|---|---|---|---|
| Coruscant → Balmorra | 22.1 | character, no ship | 5 | **5** |
| Coruscant → Ghorman | 35.5 | character, no ship | 7 | **7** |
| Coruscant → Svivren | 44.9 | character, no ship | 8 | **8** |
| Coruscant ↔ Svivren | 44.9 | fleet, hyperdrive 80 | 6 | **6** |
| Coruscant ↔ Adega | 186.0 | Galleon (80) | 29.06 → 29 | **29** |
| Adega → Coruscant | 186.0 | Victory Destroyer (60) | 21.80 → 22 | **22** |
| Denab → Coruscant | 388.0 | Dreadnaught / ISD (80) | 60.63 → 61 | **61** |

**Slowest ship governs**, and slowest means highest-rated: a Galleon (80) flying
with a Victory Destroyer (60) took 29 days on the leg the Victory Destroyer did
alone in 22 — the Galleon's own time exactly.

**`512` and `100` were both already correct** in `Planet.DeploymentDaysTo`; the
`100` is `game_rules.json`'s **Standard Space Travel Speed**, the rate for a
traveller with no ship. What was wrong was applying it to everything: no ship
term, no sector test, and `ceil` where the original rounds (186 × 80 / 512 =
29.06 ceils to 30, and 29 was observed).

**Corroboration:** Han Solo's own entry in the same table is **50** — exactly half
the standard — which reproduces the manual's Millennium Falcon effect, *"travels
twice as fast"* (p094), out of this same law. That set-piece is **not
implemented**; it needs the party-composition condition, not just the constant.

⚠ **Two things assumed rather than measured.** Every intra-sector reading used an
80-rated ship, so `ceil(d/8)` being rating-independent is untested — a 60-rated
ship on a ~45-unit hop reads **6** if independent, **5** if it scales. And every
cross-sector reading used a ship, so an unshipped traveller crossing sectors at
Standard Speed 100 is inference from the constant, not observation.

⚠ **Fleet moves commit instantly** — *"the fleet immediately goes into hyperspace"*
(p111). Only a **character's Confirmed Move** previews the days and can be
cancelled, which is why the character legs above were free to measure and the
fleet legs each cost a real journey.

**Alliance HQ placement, confirmed:** *"the Alliance headquarters, which begins
the game at a **random system on the Galactic Rim**."* And Yavin is a bad base
because *"the Empire typically moves against that system early in the game"* —
i.e. Yavin's location is known to the Empire, unlike the HQ.

### Finding people, and intel gating

The **Personnel Finder** has a tab per side, plus separate **Character Finder**
and **SpecForces Finder** views. The opponent tab carries an explicit warning:

> Information on your opponent's personnel is **not likely to be accurate until
> your agents gather intelligence through Espionage missions**.

Second confirmation that knowledge of the enemy is espionage-gated, not free.

---

## 8. Fleets, transports and garrisons

*(PDF p048 / manual p049, Figs. 2.45–2.47)*

**Fleet structure.** A fleet has a **location** and contains **capital ships**.
The Fleet window reports, for the whole fleet: capital ships, **total fighters**,
**total troops**, and **personnel**. Selecting an individual ship and choosing the
**Troops** tab shows *"number of troops the ship can carry"* against *"number of
troops aboard"* — so **troop capacity is per ship**, and troops ride inside
capital ships and transports.

If you have no transport available, *"use the Galactic Information Display
Manufacturing menu to find an orbital shipyard, then build the transport."*

**Spotting an unpopulated world:**

> If there are **no facilities, defenses, or loyalty indicators** on a system, it
> means the system is **unpopulated**. Grab it!

Unpopulated worlds are taken by **landing troops to build a garrison** — no
diplomacy needed, since there is no population to sway. Move the transport to the
system, then use the Troops tab to land them.

### What a fleet is made of *(PDF p050 / manual p051)*

> Fleets are made up of:
>
> - **CAPITAL SHIPS**: Large ships take a lot of time and resources to build. Some
>   capital ships are heavily armed and defended, while others are designed
>   primarily to **carry fighters or troops**.
> - **FIGHTERS**: small, maneuverable ships such as the TIE fighter.
> - **TROOPS**: regiments such as stormtroopers, Fleet Regiments, and Imperial
>   Army Regiments.
> - **PERSONNEL**: characters who can take command of fleets, troops…

The Fleet window has **four tabs — capital ships, fighter squadrons, troop
regiments, personnel** *(PDF p052 / manual p053)*. *"You can have **any number** of
capital ships in a fleet."*

Each carried type shows **carried vs capacity**: *"The left number shows the
number of fighter squadrons in the fleet; the right number shows the number you
have room for."* Same for troops. Selecting an individual ship re-scopes the tabs
to that ship alone — so **capacity is a per-ship property that sums to a fleet
total**.

### Command ranks *(PDF p054 / manual p055)*

> Fleets **don't require** personnel, but they **perform much better** if commanded
> by competent characters.

> There are three possible types of command a character may have: **Commander,
> General, and Admiral.**
>
> - **Generals** enhance the strengths of **trooper regiments** for assault or
>   defense.
> - **Commanders** enhance the effectiveness of **fighters** in the tactical game.
> - **Admirals** improve a **fleet's performance** in the tactical game and improve
>   the effectiveness of **orbital bombardment**.
>
> **Ranked characters also increase the ability of their associated units to
> detect and foil enemy missions.**

That last line matters: command rank feeds the *mission detection* system, not
just combat. It ties the character layer to the espionage layer.

*"You begin the game with **seven characters**, which is enough to begin your quest
of total domination. You can **recruit more characters** as the game progresses."*

> ⚠️ Possible discrepancy with the code: day zero currently reports
> "18 Characters Deployed (42 Undiscovered)". The manual's tutorial says seven to
> start. Worth checking whether "deployed" means the same thing.

### Garrisons scale with how you took the world *(PDF p054 / manual p055)*

> **Planets that are taken over by force typically require more troops in the
> garrison to maintain order.** However, these garrison requirements are just as
> easily fulfilled by **Fleet Regiments** (which you can build rather quickly) as
> by **stormtroopers** (which take a long time to build).

So Garrison Requirement is dynamic — 0 on an unpopulated world you settled,
higher on a world you conquered. Troop *types* differ in build time and
resilience but count equally toward garrison.

### Fighters, hyperdrive and system defense *(PDF p054 / manual p055)*

> NOTE: **Some fighters don't have hyperdrive capability**; these fighters can
> only be used as **system-based defenses**, or must be placed on a capital ship
> for transport and space deployment.

> NOTE: **TIE fighters can also defend the system on which they are stationed.**

So a fighter squadron is either strategically mobile (has hyperdrive), or it is a
static system defense unless ferried. Fleet composition is editable: drag ships
between fleets, or right-click a ship → **Create New Fleet** to split one.

### Taking an unpopulated world *(PDF p050 / manual p051, Fig. 2.49)*

> **Placing troops on an unpopulated world gives you control of that system.**

The system name turns red immediately (Endor, in the example). Its **Garrison
Requirement** reads **0** — *"the minimum number of troops needed to maintain
control of system."* So unpopulated worlds cost nothing to hold, while populated
ones require a standing garrison.

**Empire equivalents:** IMP-22 Military Protocol Droid (agent) and SD-7 (message
droid) replace C-3PO and R2-D2; the manual notes the Empire side *"has the same
features as the Alliance side, but the graphics are slightly different"* — an
explicit statement that the two sides share UI and differ only in presentation
and the asymmetries called out elsewhere.

**Reconnaissance reveals the resource bars.** After a Longprobe reports,
*"you'll see the familiar white/blue and yellow/red bars under the system"* — i.e.
energy and raw-material capacity are hidden until the system is explored. That is
the concrete meaning of "unexplored" for a rim world.

---

## 9. Taking a populated world: assault and bombardment

*(PDF p056 / manual p057)*

> In order to take over a planet, you need to conduct a **planetary assault**,
> which means that the troops on your fleet **go down to the planet surface, fight
> any ground troops**, and, if successful, **establish a garrison**.

### The layered defense

The manual lists what stands in your way, in order:

1. **Fleets and fighters** to get past
2. **Defensive facilities** — shields and batteries
3. **Ground troops** — *"the last line of defense"*

**Batteries** are dual-purpose and dangerous:

> A battery can **damage or destroy ships which are bombarding**. Additionally, a
> battery can **fire at an assaulting Fleet regiment and destroy it**.

**Shields gate assault entirely:**

> Shields protect the planet from assaults and bombardments. A system with **two
> shields is called fully shielded, which means you cannot conduct an assault of
> that system.**

Two shields is a hard lockout, not a modifier — the Planetary Assault option is
greyed out. One shield is described as *"not so bad"*.

> NOTE: **Neutral systems don't have fleets, fighters, or troops, but they may
> have defensive facilities.**

### Orbital bombardment

Available **only against enemy systems, not neutral ones**:

> If you are attacking an **enemy (rather than a neutral) system**, you may choose
> to conduct an **orbital bombardment** of the system to weaken its defenses,
> particularly its **ground troops**. However, bombarding a system can be risky.
> **Any batteries on that system will shoot back** when you are bombarding.

Bombardment targeting has three modes: **Target Military Facilities / Target
Civilian Facilities / General Bombardment**.

**And it carries a political cost:**

> Furthermore, if you inadvertently **destroy any civilian facilities** on a
> system, your **popular support throughout the sector will decline**.

That is the second confirmed way popular support moves — and note the scope is
**sector-wide**, not just the bombarded system. Both known support mechanics
(diplomacy, bombardment fallout) are consequences of **player action**.

Assault results are reported immediately, with casualty breakdowns for both
sides; a failed assault can be followed up with reinforcements.

The fleet command menu is: **Move, Confirmed Move, Planetary Bombardment,
Planetary Assault, Rename, Encyclopedia, Status**.

### Blockades *(PDF p058 / manual p059)*

> **Blockaded systems become more loyal to the enemy.** Any personnel,
> facilities, or troops attempting to **cross an enemy blockade risks being
> captured or destroyed**. Furthermore, **you cannot use any of a system's
> facilities until the enemy blockade ends.**

Three distinct effects: a **support shift over time**, a **transit hazard**, and a
**total shutdown of the system's facilities**.

This is the **third** mechanic that moves popular support, and the only one that
does so *passively over time*. Note what causes it: an **enemy fleet in orbit** —
not the system's own economy. Support drifting with no enemy present and no
mission running has no basis in the manual.

### → Everything that moves popular support

Consolidated from both chapters — see §"What affects popular support" for the
canonical Chapter 3 list and the quotes.

| Cause | Direction | Scope | Source |
|---|---|---|---|
| **Diplomacy mission** | toward the mission's side | target system | manual p089, p043 |
| **Subdue Uprising mission** | toward your side, *much more slowly* | target system (must be in uprising) | manual p089 |
| **Sector contagion** — support changing on one system | either way; can cascade | **other systems in the same sector** | manual p089 |
| **Abandoning a system** — removing your last trooper regiment | away from you | that system | manual p089 |
| **Destroying civilian facilities** while bombarding | away from the bombarder | **the whole sector** | manual p057, p090 |
| **Blockade** | **amplifies whoever is already ahead** — not the blockader | the blockaded system | manual p059, **p090** |
| **Stationing the first troops after an assault** | away from you *(unless your support there is already strong)* | that system | manual p090 |
| **Empire troops present, no uprising running** | slowly **toward** the Empire | that system | manual p090 |
| **Losing a battle** | away from the loser, scaled by ships/troops lost **relative to the opponent** | **the whole sector** | manual p090 |
| **Uprising continuing on a system you control** | away from you, more the longer it runs | that system | manual p090 |
| **Death Star present in a sector** | helps the Empire *hold* systems | that sector | manual p090 |
| **Death Star destroys a planet** | away from the Empire | **the whole galaxy** | manual p090 |
| **Losing your HQ** (Coruscant captured / Rebel HQ destroyed) | severe drop, immediate | that sector | manual p090 |
| **Alliance relocating its HQ** | small drop | the system it left | manual p090 |

**Not on the list, in any chapter: the system's own economy.** No energy
shortfall, failed production or maintenance problem moves loyalty. The influence
runs the other way — low support slows production and invites smuggling.

Two corrections to earlier readings, now that manual p090 gives the full list:

1. **Blockades don't favour the blockader.** p059 only said "blockaded systems
   become more loyal to the enemy" — read in isolation that suggests the fleet in
   orbit wins hearts. p090 is explicit that a blockade **reinforces the existing
   lean**: if support favours the Alliance it moves further Alliance, if it
   favours the Empire it moves further Empire. A blockade is a pressure
   multiplier, not a persuader.
2. **Losing a battle costs support, sector-wide.** This is a fourth passive
   mover, and the largest one in practice — every capital ship lost anywhere in a
   sector bleeds loyalty across that whole sector.

**Note the asymmetry**, which matters for pack design: garrisoned Empire troops
*raise* support over time; Alliance troops do not. That is a **per-faction policy
flag**, not a code branch — see [PROJECT.md](PROJECT.md) §3.

---

## 10. Garrisons and uprisings

The manual devotes a whole section to this, and it is the single biggest
mechanic the code has no equivalent for.

### Garrison requirement *(PDF p088 / manual p090)*

> Trooper regiments stationed on a system make up a **garrison**. If a system you
> control **does not strongly support your side** (for example, because you took
> over the system by force), that system might have **garrison requirements**.
> Garrison requirements are stated in the **Trooper Regiment tab of the System
> Defenses window**. A garrison requirement of two means you need at least two
> troopers on the system to keep control. **Not meeting garrison requirements
> could cause the system to go into uprising.**

So the requirement is **a function of popular support**, not of planet size or
value. A world that loves you needs no garrison; a world you conquered needs
troops permanently parked on it. This is the mechanism that makes conquest
*expensive to hold* rather than merely expensive to achieve.

### Uprisings *(PDF p089 / manual p091)*

> A system you control may go into an uprising if you don't have enough troops to
> meet the garrison requirements. Systems in uprisings are identified by a
> **flaming icon at the lower right of the system**.

What an uprising does, all four effects:

| Effect | Detail |
|---|---|
| **Manufacturing halts** | production on that system stops entirely |
| **Some missions fail** | missions attempted on that system |
| **Garrison requirement jumps** | "a **sharp increase**" — so it self-deepens |
| **Attrition, then loss** | "If a system stays in uprising too long, you may **lose troops and facilities** there, and may ultimately **lose complete control** of the system." |

Plus the standing loyalty bleed from the support table above: the longer it runs,
the more support you lose there.

Two ways out: **send more troops**, or send a character on a **Subdue Uprising**
mission.

#### ★★ An uprising is rolled for on a timer, not triggered on the spot *(confirmed)*

Falling below the garrison requirement does **not** start a revolt. The manual
says so twice, and neither sentence describes anything automatic:

> "Not meeting garrison requirements **could** cause the system to go into
> uprising." (manual p090)
> "A system you control **may** go into an uprising if you don't have enough
> troops to meet the garrison requirements." (manual p091)

And the rules table ships the machinery those two sentences imply:

| Entry | Name | Value |
|---|---|---|
| **169** | Uprising Incident Timer: Base Delay | **30** |
| **170** | Uprising Incident Timer: Random Spread | **70** |
| **175** | Uprising: Base | **1** |
| **176** | Uprising: Max Random Extra | **9** |

So an under-garrisoned world is checked **every 30–100 days**, and at each check
a **1–10** roll decides. Between checks it sits in a warned state.

**That warned state is the original's, not ours**, and we have its exact wording.
`TEXTSTRA.DLL` at `0x00f3f6` carries the message as a title/body pair:

```
0x00f3f6   Near Uprising
0x00f408   Unrest has pushed |          <- system name substitutes at the bar
0x00f420   close to uprising.
```

So the message reads **"Near Uprising / Unrest has pushed *\<system\>* close to
uprising."** The game names the condition, warns about it, and only then rolls.

**The roll is read through `UPRIS1TB.DAT`** (→ `data/uprising_start.json`), a
threshold→value step table: `1→0`, `6→1`, `10→2`.

⚠ **Single inference, flagged:** nothing states what feeds UPRIS1TB. It is read
here with the entry 175/176 roll because the spans match exactly — lowest
threshold 1, highest 10, nothing uncovered at either end, and the roll is named
for the event the table is named for. **What values 1 and 2 mean is unknown**;
only "0 means nothing happens" is used, which holds under every reading of them.
Under this reading rolls 1–5 pass quietly and 6–10 start a revolt.

**Corroboration for the doubled requirement**, which we already had right: a
shipped droid advice string reads *"Uprisings can be subdued by placing **twice
the normal garrison** on the system or by sending a character to perform a
'Subdue Uprising' mission at that location"* — independently confirming entry
150, Uprising Active Garrison Multiplier = 2.

**In the code:** `Planet.ConsiderUprising` and `backend/UprisingTable.cs`. What
this replaced set `IsInUprising` the instant `have < need`, every day, with no
timer and no roll — so a world merely sitting under strength was in open revolt
the next morning and lost within weeks with nothing having happened to it.

#### The uprising marker on the map *(manual p091, Fig 3.7 on p070)*

> Systems in uprisings are identified by a **flaming icon at the lower right of
> the system**.

Fig 3.7's own callout repeats it: *"This icon indicates the system is in
uprising."* It shares the lower-right corner with the mission marker (p109).

⚠ Our sector window referenced `IsInUprising` **nowhere at all**, so a revolt was
invisible on the map — the only places it surfaced were the Planet window's text
suffix and the GID's Uprisings mode. That is what made Subdue Uprising look as
though it were offered against quiet worlds. Now drawn in `SectorWindow`, over
the mission marker when both apply, with the mission menu still attached so Abort
stays reachable. **The glyph is a placeholder**, in keeping with the `E`/`F`/`D`/`M`
lettering on the other three corners — not the manual's flame artwork.

#### The GID Uprisings mode has exactly two tiers *(confirmed)*

Worth stating because it was briefly claimed here to have three, on the strength
of `Near Uprising` appearing near the tier labels in an **alphabetically sorted**
string list. It does not — sorted output says nothing about position. Checked
positionally, the GID tier block reads:

```
0x01b834   Popular Support
0x01b854   Loyalty to the Alliance
0x01b884   Loyalty to the Empire
0x01b8b0   Loyal
0x01b8bc   Obedient
0x01b8ce   Disloyal
0x01b8e0   Worlds in Uprising          <- title
0x01b906   Currently in Uprising       <- tier
0x01b932   Not in Uprising             <- tier
0x01b95a   Hostile                     <- Popular Support's 4th tier, deferred
0x01b96a   Fleets                      <- next mode
```

Each record defers its **last** tier past the following record's opening fields,
which is why `Hostile` lands after the uprising rows rather than with `Loyal /
Obedient / Disloyal`. The Uprisings record carries two tiers. **`Gid.cs` being
binary is correct and needs no change.**

`Near Uprising` lives in the message-text block instead (see above), and
`Garrison Warning` in the message-**type** block below.

#### ★ The original's message types *(confirmed)*

Distinct from the tab strip. `TEXTSTRA.DLL` holds one contiguous block at
`0x0219f4`–`0x021d7a`:

> Tactical After Action Report · Tactical Pre Battle Message · **Uprising
> Message** · System Control Message · Research Report · Repair Message ·
> Blockade Message · Confirmation Message · Smuggling Message · Chat Message ·
> **Garrison Warning** · Maintenance Shortfall · Unit Arrival · Unit Deployment ·
> Operation Reports · Deployment Failed · Unit Rerouted · Evacuation Losses ·
> Personnel Arrive · Planet Destroyed · Mission Report · Mission Failed ·
> Informant Report · Character Captured · Character Health · Bounty Hunters

This is what the original's per-type notification settings switch on — *Post as
Urgent / Silently / with Alert / Block* — one level finer than the tabs, which
are the separate list *All / Popular Support / Resource / Manufacturing /
Mission / Chat / Defense / Fleet / Conflict Messages* and which `MessageCategory`
already matches.

**In the code:** `MessageType` in `backend/GameMessage.cs`, transcribed in the
original's order. ⚠ **Not wired to anything** — there is no notification-settings
model in this codebase; `MessageCategory` drives the tab filter and nothing else.
The field records what the original would file a message under so that settings,
when built, have something to switch on. Only the messages this engine actually
raises set it today.

> NOTE: An uprising is an **armed response to your presence** on the system. Your
> troops and characters are **at risk of being captured or killed**.

And the offensive counterpart: **Incite Uprising**, a character mission run
against an enemy system.

#### ★ What happens to characters on a world that rises

**Two different moments, and they must not be confused:**

| Moment | What happens |
|---|---|
| **While the uprising runs**, world still yours | *"Your troops and characters are **at risk of being captured or killed**"* (manual p091) |
| **When the world flips** and stops being yours | the personnel on it **relocate to a world you still hold** — see §7, ★★ measured in the original |

⚠ **A PREVIOUS RESEARCH PASS GOT THE SECOND ROW WRONG, and this is why the
correction is recorded rather than quietly deleted.** It searched the manual,
`TEXTSTRA.DLL`, `ENCYTEXT.DLL` and the open-rebellion decompilation for a
relocation rule, found none, and concluded *"characters do not evacuate…
whatever the player remembers as characters 'moving home' is not in any source
available here"* — explicitly writing the player's recollection off as a
misremembered capture.

**The player then measured it in the original and watched it happen.** Empirical
measurement is the bottom rung of the source hierarchy precisely because it
settles what the upper rungs are silent about. Silence in the manual is not
evidence of absence, and it must never again be written up as though it were.

The first row still stands and is **still not implemented**:
`Planet.SufferUprisingLosses` removes a trooper regiment, then facilities, and
never touches characters — so the manual's stated risk to personnel during a
revolt does not exist in this engine.

⚠ **Still unknown:** what else rides on the *moment* control changes. SDPRTB
entries 17–29 are five "Control Change" event pairs (peaceful, alternate, troop
arrival, troop withdrawal, contested presence), each a payload plus an event row —
so the original models the transition as an event with consequences, and none of
those payloads has been decoded.


Note the loop this forms — take a world by force → support drops → garrison
requirement appears → understaff it → uprising → support drops further →
requirement rises further → lose the world. Conquest without diplomacy is
self-defeating by design.

### Where the player reads support *(PDF p089 / manual p091)*

> The **Sector window** is your main source of information on popular support.
> The amount of **red and green on the Loyalty gauge** underneath each system
> shows how strong your support is, and how susceptible a neutral system may be
> to being won over to your side.
>
> To get a broader view of your support across the galaxy, select **Popular
> Support** from the **Loyalty sub-menu** of the Galactic Information Display
> control menu. **Larger stars in this view indicate systems with strong support
> for your side, regardless of who controls those systems.** You can also select
> **Uprisings** from this menu to see systems in uprisings.

Three things this pins down for our GID work:

1. **Marker size = support for *your* side**, and explicitly **not** for the
   controller. A large marker on an enemy-held world means *you* are popular
   there — which is exactly the information a player needs to pick diplomacy
   targets. This is what the current implementation does.
2. **Uprisings is its own GID mode**, sitting in the same Loyalty sub-menu.
3. The Loyalty gauge doubles as the **conversion-susceptibility** readout for
   neutral worlds.

---

## 11. Characters, the Force, and who you start with

### The roster *(PDF p089–p091 / manual p091–p093)*

- **30 possible characters per side.**
- Characters have skills in **diplomacy, espionage, combat, and leadership** —
  the same four the stat block shows (§7).
- Starting characters are the named set below, **plus extras scaled to galaxy
  size**: one extra for a standard game, **two** for large, **four** for huge.
  The extras are "randomly selected and placed."
- More can be **recruited** as a mission type.
- "Each game begins a little differently, with the characters at different
  locations."

### Starting placement is asymmetric *(PDF p090–p091 / manual p092–p093)*

The two table headers state the rule outright, and they do not match:

| Side | Placement rule |
|---|---|
| **Alliance** | "**At Yavin, Except Mon Mothma**" — the whole cast starts stacked on the one known base; Mon Mothma sits at the hidden HQ, "on a different system in an outlying sector every game" |
| **Empire** | "**Randomly Placed, Except Emperor**" — scattered across the galaxy; Palpatine "always begins the game at Coruscant" |

This is a **third** faction-shaped asymmetry (after hidden vs. fixed HQ, and
troops-raise-support), and like the others it belongs in pack data — something
like `characters.placement: "all_at_capital" | "scattered"` with a per-character
override for the leader.

**Beginning Alliance characters** (manual p092):

| Character | Noted for |
|---|---|
| Princess Leia | strong diplomacy and leadership |
| Luke Skywalker | strong combat; also espionage and diplomacy. **Force user whose skills may increase as the game progresses** |
| Han Solo | strong espionage, combat, leadership; "still has the pesky problem of having a price on his head" |
| Wedge Antilles | good combat, espionage, leadership; **can research new ship design** |
| Chewbacca | good combat and espionage |
| Jan Dodonna | combat, leadership, diplomacy |
| Mon Mothma | "president of the Alliance"; exceptional leadership and diplomacy; **at Alliance HQ** |

**Beginning Empire characters** (manual p093):

| Character | Noted for |
|---|---|
| Emperor Palpatine | exceptionally strong leadership and combat, plus diplomacy; **strong in the Force**; always at Coruscant |
| Piett | good combat and leadership; strong diplomacy |
| Veers | good combat and leadership; **can perform troop R&D missions** |
| Darth Vader | strong leadership, diplomacy, espionage and combat; **very strong in the Force** |
| Jerjerrod | strong leadership, good diplomacy |
| Ozzel | strong leadership, combat, espionage |
| Needa | strong leadership, combat, espionage |

Note that **R&D capability is a per-character property**, not a facility one:
Wedge researches ships, Veers researches troops. The stat block (§7) has a
"Research and Development capabilities" line for exactly this.

### The Force *(PDF p090–p091 / manual p092–p093)*

> The Force is a great power in the galaxy which some characters can harness to
> **increase their other abilities**.

Four distinct mechanical effects, not one:

1. **Boosts the character's other skills** (diplomacy/espionage/combat/leadership).
2. **Detects and foils enemy Force-users on missions** — "if they are located in
   the same system," and only if strong enough.
3. **Heals faster** than normal, if strong enough.
4. **Discovers latent Force potential in others.**

> There are **five levels of Force users: Novice, Trainee, Jedi Student, Jedi
> Knight, and Jedi Master.**

The discovery rule is specific and asymmetric:

- "Some characters may be **strong in the Force yet unaware of it**."
- Luke discovers **Alliance** potentials; Vader discovers **Imperial** ones.
- Discovery requires being **on the same system or ship** as the potential.
- Discovery only reveals *potential* — training is a separate **Jedi Training
  mission**.
- **Vader can discover right away; Luke cannot** — "Luke Skywalker is not strong
  enough in the Force at the start of the game." He gains discovery **before** he
  is strong enough to train anyone.

Generalised for a pack, this is: a hidden per-character `latentPotential` flag, a
`canDetectLatent` capability gated on the detector's own level, a same-location
requirement, and a training mission that promotes along a five-step ladder. None
of it needs the word "Force" in engine code.

### Becoming Force-aware, and levelling *(PDF p092–p093 / manual p094–p095)*

> Learning a character is Force-aware gives that character a Force rating of
> **Novice** and **immediately increases the character's leadership, combat, and
> espionage abilities**.

So discovery itself is a stat boost, before any training. Further levels come
from a **Jedi Training mission** run with Luke or Vader.

#### ✅ The five thresholds, recovered *(Confirmed)*

| Rank | Force points required |
|---|---|
| Novice | **10** |
| Trainee | **20** |
| Jedi Student | **80** |
| Jedi Knight | **100** |
| Jedi Master | **120** |

Published by the community (Steam guide *"A guide to Force powered Characters"*).
One source is not enough — what makes this **Confirmed** is that LucasArts' own
shipped data lands exactly on four of the five boundaries, and none of those
numbers was authored for this table:

| Shipped value | Lands on |
|---|---|
| Leia `JediLevelBase` 10 | Novice, exactly |
| every minor's `JediLevelBase` 10 / 20 / 30 | the first two **are** Novice and Trainee; nothing rolls 1–9 |
| GNPRTB entry 41, *Discovering Force User Threshold* = 80 | Jedi Student |
| GNPRTB entry 42, *Force Qualified Character Threshold* = 100 | Jedi Knight |
| Vader `JediLevelBase` 120 | Jedi Master, exactly |

And the prose falls out rather than being fitted to it: the guide says Luke
detects Force sensitivity at **Jedi Student** and cannot teach until **Jedi
Knight**, which are entries 41 and 80, 42 and 100. Dagobah takes Luke 50 → 80,
Trainee → Student: discovery gained, teaching still out of reach — exactly the
asymmetry p094 states in words.

Luke at 50 is a Trainee, which is p094's *"Luke Skywalker always begins the game
as a Trainee"*.

#### Who may teach *(Confirmed, three sources)*

`CanTrainJedi` (MJCHARSD col 36, true for exactly Luke and Vader) is **necessary
but not sufficient** — the teacher must also have reached **Jedi Knight**.

| Source | Says |
|---|---|
| `TEXTSTRA.DLL` | *"Once I reach the **rank of Jedi Knight**, I should conduct training in the use of the Force."* |
| Steam guide | Luke *"cannot conduct a Jedi Training mission until he is a Jedi Knight"* |
| `tdimino/open-rebellion`, modders-taxonomy | names *"the **Dagobah prerequisite check** in the mission manager"* as what to patch to allow multiple teachers |

The threshold is **GNPRTB entry 42 = 100**, not the community's number.

#### The Jedi Training mission — Encyclopedia, verbatim

> Jedi training missions are used to enhance the abilities of Force using
> characters. Whenever Darth Vader or Luke Skywalker is placed together with
> other Force using characters, a Jedi Training mission can be formed. **At the
> conclusion of the mission**, the character or characters **may** have increased
> their Force abilities. If the system on which the training is occurring suffers
> a planetary bombardment, or planetary assault, **or control passes over to the
> enemy**, the training mission is considered **foiled**.

Three things the manual does not give:

1. **"At the conclusion of the mission"** — it concludes. Corroborates
   MISSNSD `CanContinue = 0` and p110's list of only four persistent types.
2. **"or control passes over to the enemy"** — a third abort condition.
3. **"foiled"**, not failed — so it carries the personnel risk of p110.

#### ⚠ The gain magnitude is still Unknown

GNPRTB entry 128, *"Jedi Training success: Jedi level gain: Max Random Extra"* =
50, with **no Base entry anywhere** (ParameterIds run contiguously 6169–6177).
The name is MetasharpNet's, not LucasArts'.

Checked and failed to yield: all 20 IntTable `*.DAT` (no Jedi table exists),
MJCHARSD's 37 columns, `ENCYTEXT.DLL` (*"may have increased"* — no magnitude),
`TEXTSTRA.DLL` (reports the resulting rank, never the delta), manual p107, and
open-rebellion's Ghidra notes — which cover detection, field offsets, event ids
and notification dispatch but **not the gain**. Their `docs/mechanics/jedi.md`
invents "+1 per tick" and cites nothing for it.

**What would settle it:** a measured run in the original — a student's Force rank
before and after one training mission — or swrebellion threads 9124 and 4165,
which were returning HTTP 503 when this was written.


Additional Force XP sources, all small:

| Trigger | Gain |
|---|---|
| **Evasion bonus** — evading capture | "slight increase" |
| **Encounter bonus** — meeting the enemy's top Force-user and not being captured | "more substantial increase" |
| Any successful mission (Force-aware characters) | "small growth … usually **not enough to advance them to the next Force level**" |

Both bonuses are gated on the character already being Force-*aware*.

Two hardcoded story characters ride on top of the generic system, and they are
worth recording because they show how far the original went with scripted
exceptions:

- **Luke starts as Trainee**, then "at some point in the game … will go off alone
  to Dagobah, to be trained by Yoda" — an **unprompted, self-triggering scripted
  event** that raises his rank. It only fails if it is interrupted by Han being
  captured by bounty hunters.
- **Leia always has Force potential**, but it "can't be discovered until she
  learns about her heritage from Luke" — explicitly "unlike other potential
  Force-using characters that can be discovered."

### The scripted set-pieces *(PDF p092–p093 / manual p094–p095)*

Four named effects that are pure content, and belong in pack data as
conditional rules rather than in engine code:

| Name | Condition | Effect |
|---|---|---|
| **Millennium Falcon effect** | Han travelling alone or with characters (**no SpecForces**), **not** aboard a ship | travels **twice as fast** |
| **"Seat of Power" effect** | Emperor **on** Coruscant (not in a fleet there), uncaptured, Coruscant Empire-controlled | **every** Imperial character in the galaxy gets a leadership bonus |
| **Heritage** | Luke encounters Vader | learns his heritage; if not captured he is **badly injured** — unusable for missions or command "for a long time" |
| **Final Battle** | Luke knows his heritage **and** has a high Force value **and** is captured, **and** Vader and the Emperor are both uncaptured and not en route or on a mission | Vader tries to abduct Luke to the Emperor. Luke loses → stays captured. Luke wins → **goes free and captures both**, escaping to a friendly system or fleet |

The generic shapes underneath: a **speed modifier keyed on party composition**, a
**global buff conditioned on a leader's location and the control of one world**,
an **encounter-triggered stat/status change**, and a **scripted duel with a
multi-clause precondition and a decisive outcome**.

### Traitors and character loyalty *(PDF p092 / manual p094)*

> Like planetary systems, **characters have a loyalty rating** that depends in
> part on how strong your support is **throughout the galaxy**.

This is a second, parallel loyalty system — worlds have support, and so do
people, and the second is fed by the first galaxy-wide.

- **You cannot examine a character's loyalty directly.** Only Force-strong
  characters "can ferret out traitors in a party."
- **Key characters have strong loyalty that won't waver**; secondary characters
  may turn.
- A traitor sent on a mission **may betray it**.
- Loyalty tracks how the war is going — "they will improve as you have
  victories."

What specifically moves character loyalty:

| Event | |
|---|---|
| Destruction of the Rebel HQ | |
| The Empire gaining **or losing** control of Coruscant | |
| Losing ships, fighters or troops in battles, assaults and bombardments | |

Note that these are the same events that swing *popular* support — the two
systems are driven by the same shocks.

Handling a traitor: **retire** them from the right-click menu; or, if a losing
streak has turned most of the cast at once, "let them sit tight and hope for an
improvement in the game, so that traitorous characters become less so and you can
use them again." Treachery is **reversible**.

> NOTE: Characters in **command roles will not betray you**, even if they have a
> low loyalty.

### Improving abilities *(PDF p093 / manual p095)*

> Characters come into play with certain attributes. A character may have an
> **espionage rating of 69**, for example.

Confirms the stat block is **numeric, not tiered** — and manual p101 gives the
actual range: **0 to 150 "or even higher" for very advanced characters**, not a
percentage. See §11 "The stat block, precisely" below.

The advancement rule is unusually strict, and worth copying exactly:

- Attributes grow by **using them on successful missions** — the attributes *the
  mission used* are the ones that may improve.
- Only the character **who caused the mission to succeed** gains. Not the team.
- **"Only one character can cause a particular mission to succeed."**
- **If a SpecForce caused the success, nobody gains anything.**

So SpecForces are a deliberate trade: cheap and buildable, but using them
forfeits the experience the mission would otherwise have generated.

### Command ranks — the full effect table *(PDF p093–p094 / manual p095–p096)*

Three ranks: **Admiral, General, Commander**. A character holding one can be put
in charge of all regiments on a fleet or system, all ships in a fleet, or all
fighter squadrons assigned to a fleet or system.

| Rank | Commands | Effects |
|---|---|---|
| **Admiral** | ships in a fleet | improves ship **reaction time** in tactical; **magnifies ships' bombardment effect**; improves **capital-ship maneuverability**; helps **block enemy missions**. If several fleets fight in one battle, **the best admiral present is used** |
| **General** | trooper regiments (fleet = assault, system = defense) | enhances regiment strength; **magnifies defensive batteries**; explicitly **"no added effect in tactical battles"** |
| **Commander** | fighter squadrons | fighter effectiveness and maneuverability in tactical; can also be assigned to **system defense fighters** |

And the effect they share, which is the important one strategically:

> **All command ranks greatly enhance the ability of their associated units to
> detect enemy missions.** If an enemy mission is detected, then the command ranks
> also enhance the ability … to **capture or kill members of the enemy mission**.
> The strength of this special ability depends on the character's **espionage**
> rating. The strength of the ability to capture or kill … depends on the
> character's **combat** rating.

So a garrisoned commander is counter-intelligence, and the two halves read
different stats: **espionage detects, combat kills.**

> TIP: Assign a general or commander to any system that you want to defend.

### Injury, capture, death *(PDF p094–p095 / manual p096–p097)*

Characters have four statuses, with icons: **Ready on a system or fleet**, **In
transit between systems**, **Captured**, **Injured**.

**Assassination** is one-way — the manual says characters can be assassinated
"(if you are playing the Alliance)". A fourth faction asymmetry.

#### ★★★ Assassination has THREE outcomes, and death is one of them *(corrected)*

This section previously implied a successful assassination only ever injures.
**That was a misreading of the digest, and the page says the opposite.** Read off
the scan directly (`manual/Manual.pdf` is image-only — no text layer, so it has to
be rendered and read):

> **"A character that is assassinated is, well, dead."** — manual p096

> **"Goal is to INJURE OR KILL a target Alliance character.** Only the Empire may
> perform this mission. **(You cannot kill primary characters such as Luke
> Skywalker, but injuring them makes them easier to capture.)"** — manual p105

And injury is listed as a *separate* consequence of the same act — one of six
causes on p096 is "**as a result of an assassination attempt**" — with its own
standing risk:

> "There is **always a chance** that when a character is injured that he may be
> killed. If he is not killed, he will be healed if he rests on a system or fleet
> that you control. **Captured characters do not heal** while they are captured."

So the outcomes are **miss / injure / kill**, and **primary characters can never
be killed** — only injured, which then makes them easier to capture.

**Community corroboration** (Steam app 441550 — qualitative only, and consistent
across independent posters): major characters "can still be targeted… but it only
injures them"; a successful assassination is "more likely to injure targets than
actually kill them", with an "annoyingly low chance of actually killing"; the
chance "goes up considerably" against an already badly injured target; and small
teams with a few decoys beat large ones, which matches p103's detection rule.

⚠ **The kill/injure split is not published anywhere.** Not in the manual, not in
the rules table (188 of 213 entries remain unidentified), and not derived by the
community — players on that forum complain the game shows them the ratings but
"not the equation in which to plug them in". Our `AssassinationKillPercent` and
`InjuryProvesFatalPercent` are therefore unsourced magnitudes, set low to match
the corroborated direction and flagged as such in `Mission.cs`.

#### ★★ The character-capture victory condition *(manual p105, Abduction)*

Stated outright in the Abduction row, and worth recording since victory
conditions are otherwise unbuilt:

> "To win the game **if you are playing the Empire, you must capture Mon Mothma
> and Luke Skywalker**. If you are the **Alliance, you must capture Darth Vader
> and Emperor Palpatine**. Note that characters can also be captured if a mission
> they are on is foiled or if they try to flee a blockaded system. (This mission
> can also be used to capture **non-victory condition characters**.)"

**Injury** comes from: your ship being blown up (battle, bombardment **or
sabotage**); your system being destroyed by a Death Star; an encounter between two
Force-users; evading capture or being captured; or a failed assassination attempt.

- An injured character **cannot go on missions** and is **particularly vulnerable
  to capture**.
- "There is always a chance that when a character is injured that he may be
  killed."
- Healing requires **resting on a system or fleet you control**. **Captured
  characters do not heal.**

**Capture** comes from four routes:

1. an **abduction mission** aimed at them;
2. being **detected by a foiler** while on an enemy system;
3. the system they are on being **taken over by the enemy**;
4. trying to **escape a system under enemy blockade**.

Recovery: a **Rescue mission**, or **retaking the system** where they are held.
Blowing up the ship holding a captured character may set them adrift to be
recovered — or kill them. Transporting a prisoner requires **one character or
SpecForce acting as "jailer"**, travelling with them.

Scripted exception: if bounty hunters take Han, "Luke Skywalker, Leia Organa, and
Chewbacca will **automatically** try to rescue him" — an AI-initiated mission the
player does not order.

### Special Forces vs. troops *(PDF p095 / manual p097)*

The distinction is absolute, and the code currently has no equivalent:

| | Troops (trooper regiments) | Special Forces |
|---|---|---|
| Purpose | garrisons, defending against ground assault, **conducting planetary assaults** | **missions** — espionage, reconnaissance and the like |
| Go on missions? | **never** | yes, that is their entire purpose |
| Count toward garrison requirement? | **yes — they are the garrison** | **no** |
| Improve with success? | — | **no** — "unlike characters, they don't improve their skills" |
| Skill breadth | — | narrow: "designed for specific missions" |

Both are built at a **training facility** — right-click an *idle* one and choose
**Build** — and both appear **intermixed in the same drop-down**, which the manual
flags as a trap: "Do not confuse the two."

So SpecForces are disposable mission filler: cheap, buildable on demand,
never improving, and invisible to the garrison check.

### The SpecForce roster *(PDF p096 / manual p098)*

Eight units, four a side, each **hard-bound to a fixed list of mission types**.
This is the clearest statement in the manual that mission eligibility is a
**capability list carried by the unit**, not a universal menu:

| Side | Unit | Missions it can run |
|---|---|---|
| Alliance | **Longprobe Y-wing Recon team** | Reconnaissance |
| Alliance | **Bothan Spies** | Espionage |
| Alliance | **Guerrillas** | Incite Uprising, Subdue Uprising |
| Alliance | **Infiltrators** | Abduction, Sabotage, **Death Star Sabotage**, Rescue |
| Empire | **Imperial Probe Droid** | Reconnaissance |
| Empire | **Imperial Espionage Droid** | Espionage |
| Empire | **Imperial Commandos** | Sabotage, Subdue Uprising, Incite Uprising |
| Empire | **Noghri Death Commandos** | Abduction, **Assassination**, Rescue |

The two rosters are **near-mirrors with one asymmetric slot each**: the Alliance
gets *Death Star Sabotage* (a counter to a thing only the Empire has), the Empire
gets *Assassination* (which the Alliance cannot do at all — matching p096's
"assassinated (if you are playing the Alliance)"). Everything else pairs up
one-for-one.

For pack purposes: a spec-force def is `{ id, faction, missions: [...] }` and
nothing more. The asymmetry falls out of the data.

**★ The extracted data has a fifth Imperial entry that is not on this list.**
`military_units.json` lists **Bounty Hunters** as Empire SpecForce — and it is
the **only unit in all 57 with `ConstructionCost 0`**. It is not player-buildable:

- The roster above is the manual's, and lists **four per side**.
- Bounty hunters appear as a **scripted event** — "Han Solo may at some point be
  captured by bounty hunters" (manual p097).
- `game_rules.json` carries **`Bounty Hunter Frequency - Base 300 / Var 300`**,
  which is an event timer, not a build cost.

Excluding zero-cost entries reproduces the manual's roster exactly, and is a
data-driven filter rather than a hardcoded name — which is how the engine does
it (`MilitaryCatalog.BuildableAt`).

Building via the agent: choosing a destination system makes the agent "instruct
the **nearest available training facility** to build the unit" — the agent
resolves the factory, the player picks the destination.

### ★★ SpecForce mission ratings — `SPECFCSD.DAT` *(confirmed)*

**A SpecForce is scored on a mission exactly as a character is**, on the same
0-to-150-plus scale as the stat block (§ "The stat block, precisely", p101). The
ratings are in `SPECFCSD.DAT` — 9 records × 29 int32 — and were being dropped by
`parse_military.py`, which read only cost and maintenance from it.

| Unit | Espionage | Combat | Leadership |
|---|---|---|---|
| Guerrillas | 55 | 20 | **50** |
| Infiltrators | 60 | 55 | 0 |
| Longprobe Y-wing Recon Team | 40 | 30 | 0 |
| Bothan Spies | **70** | 0 | 0 |
| Imperial Probe Droid | 30 | 10 | 0 |
| Imperial Espionage Droid | 60 | 5 | 0 |
| Imperial Commandos | 55 | 55 | **50** |
| Noghri Death Commandos | 55 | **70** | 0 |
| Bounty Hunters | 0 | 0 | 0 |

**Columns** are `data[14]` Espionage, `data[22]` Combat, `data[24]` Leadership.
No SpecForce carries a **Diplomacy** rating — every remaining column is zero
across all nine, which is what the roster predicts, since none of them can run a
Diplomacy mission.

**How the columns were identified** — by cross-checking the nine records against
the p098 mission roster above, not by reading a figure:

- `data[24]` is nonzero (50) for **exactly** Guerrillas and Imperial Commandos —
  precisely the two units p098 gives Incite/Subdue Uprising, and those are the
  only two missions the mission table scores on **Leadership**. A clean binary
  match across all nine records.
- `data[14]`: Bothan Spies 70 and Imperial Espionage Droid 60 are the top two,
  and they are the only two units whose mission is **Espionage**.
- `data[22]`: Noghri 70, Infiltrators 55, Imperial Commandos 55 lead — the
  Abduction / Assassination / Sabotage / Rescue units, all scored on **Combat**.
- 14 and 22 cannot be swapped: that would put Bothan Spies at **0 Espionage**,
  and Espionage is the only mission they can perform.

Anchored by `data[8]`/`data[9]` in the same records already reproducing the known
construction and maintenance costs exactly.

⚠ Ratings are **not percentages** — same open-ended scale as characters. Bothan
Spies at 70 sit around Luke's Diplomacy/Espionage (75); nothing here approaches
his Combat 135.

### Finding personnel *(PDF p096–p098 / manual p098–p100)*

Two tools. The **Personnel Finder** (a button beneath the GID) has two screens:

| Screen | Shows |
|---|---|
| **Characters** | a searchable name list; type a name to jump to it; per-side tabs for Alliance / Imperial personnel |
| **SpecForces** | a **grid of counts — each SpecForce type against each system**; type a system name to scroll to it |

**Display** closes the finder and opens the System window for the selection —
"system defenses, fleet or mission — in which the character appears." And the
intel gate, stated again:

> **If you have no information about an opposing character's location, no System
> window appears.**

The **GID** is the other route, and this is the definition of its Personnel
sub-menu:

| GID mode | Shows |
|---|---|
| **Active Personnel** | your personnel **on missions or in command** |
| **Idle Personnel** | personnel **available for assignments** |

Worth noting against our implementation: "idle" here means *the person is
unassigned*, which is not the same as *the facility has an empty queue*.

Concealment applies to your own side too:

> NOTE: **You cannot locate Luke when he is at Dagobah**, or Han Solo, Luke, Leia,
> or Chewbacca **if they are at Jabba's palace**.

### Reaching a character *(PDF p098–p099 / manual p100–p101)*

The click-path is worth recording because it is not obvious: characters live
**inside the System Defenses window**, not on the map. Double-click the
**Defenses icon** at the **lower left of a system** in the Sector window, then
right-click the character's portrait.

That right-click menu (Fig. 3.45): **Move, Confirmed Move, Mission, Command,
Encyclopedia, Status**. `Command` is how a rank is assigned.

Two information sources, deliberately split: the **Encyclopedia** ("general
information and background") and the **Status window** ("more up-to-the-minute
and precise").

### The stat block, precisely *(PDF p099 / manual p101, Fig. 3.46)*

Every field the Character Status window shows:

| Field | Meaning |
|---|---|
| **Name** | |
| **Commanding** | current command rank. "Many characters have the **potential** for command, but **you must explicitly assign the rank** for it to be in effect" |
| **Attached** | current location — **or the destination, if en route** |
| **Status** | awaiting orders / on a mission / in transit / … |
| **Force Ranking** | "how well-studied the character is in the Force, **if at all**" |
| **Diplomacy / Espionage / Combat / Leadership Rating** | "how likely a character will be to succeed at various mission types" |
| **R&D Capabilities** | three yes/no flags: **Ship Design, Troop Training, Facility Design** |
| **Possible Command Ranks** | which of Admiral / General / Commander this character *could* hold |

And the scale, stated outright:

> Ratings range from **0** (Chewbacca, for example, has practically no chance at
> success on a Diplomatic mission) **to 150 or even higher** for very advanced
> characters. **Only very key characters begin the game with the highest
> ratings.**

Luke's opening block, from Fig. 3.46, as a calibration sample:

| | |
|---|---|
| Force Ranking | Trainee |
| Diplomacy | 75 |
| Espionage | 75 |
| Combat | **135** |
| Leadership | 70 |
| R&D | Ship Design **No**, Troop Training **No**, Facility Design **No** |

So ~70–75 is "good", 135 is "exceptional", and the ceiling is open-ended above
150. **Not a percentage** — any code treating these as 0–100 is wrong.

Note also that **rank is potential + assignment**: a character has a list of
ranks they *may* hold, and holds none until the player assigns one.

**R&D is three separate tracks** — Ship Design, Troop Training, Facility Design —
and a character's capability in each is a boolean. Wedge (ships) and Veers
(troops) from the starting rosters are examples.

---

## 12. Missions — the full system

§6 covered the mission lifecycle from the tutorial. This is the reference
treatment, and it is the densest rules material in the manual.

### Assembling a mission *(PDF p100 / manual p102)*

- A mission runs with **a single character, a single SpecForce, or a team**
  mixing both. Ctrl-click to multi-select.
- **All team members must be on the same system or fleet to begin together.**
- Right-click → **Mission** → the cursor becomes a crosshair → pick a target.
- **A target is not always a system.** It "can be a system, facility, characters,
  SpecForce, fighter squadron, or trooper regiment, depending on the type of
  mission."

Two gates, both stated as notes:

> **You can only send your characters into enemy-controlled systems on specific
> missions.** If you click on an invalid destination, C-3PO or IMP-22 indicates
> the error and the cursor returns to normal.

> **This dialog box only shows the missions available for that character or
> SpecForce for that target.** For example, if Bothan spies are selected,
> Diplomacy, Sabotage, etc. will not be available; only **Espionage** … since
> that's the only mission Bothan spies are able to perform.

So eligibility is the **intersection** of (what this unit can do) × (what this
target accepts). Neither list is global. That is exactly the shape a pack needs:
units carry a mission list, missions carry a target predicate, and the UI shows
the intersection.

### Decoys *(PDF p100–p101 / manual p102–p103)*

A second column on the mission team whose job is to be noticed.

- **A decoy must be qualified to perform the real mission.** Bothans can't be
  decoys on a Sabotage mission because they can't sabotage; they can be decoys on
  an Espionage mission.
- Decoys are full members of the team and are assigned on the **Decoy tab**;
  they must be chosen **before** the order is confirmed.
- **A decoy's effectiveness depends on the decoy's espionage rating**, whatever
  the mission type is.

> NOTE: **Serving as a decoy on a successful mission does not enhance a
> character's abilities.**

### Detectors and foiling *(PDF p101 / manual p103)*

> Before a mission can have a chance at success, team members must **sneak past
> enemy defenses**. **Any unit defending a system — fighters, troops, and capital
> ships — has a chance at detecting a mission team.** In this context, such units
> are called **detectors** or **foilers**.

The consequences are sharp:

- **A non-decoy member being detected foils the mission immediately.** It does
  not degrade; it fails.
- Members of a foiled team "may either be **killed, captured, or returned to
  base**."
- **A decoy being detected does *not* foil the mission.** That is the entire
  point of decoys.

And the resulting trade-off, stated explicitly:

> Generally it makes sense to keep your team size small; it's easier for two
> people to slip past a guard unit than eight. On the other hand, **if your
> mission is not detected by foilers, each team member increases the chance that
> the mission will succeed**, so you have to balance these two factors.

Team size therefore cuts both ways: **more members = more detection risk, but
higher success probability once past**. Combined with §11's rule that only *one*
character gains experience, and that a SpecForce success gives *nobody*
experience, the team-building decision has real texture.

Recall from §11 that defenders' detection strength scales with the commanding
character's **espionage**, and their capture/kill strength with **combat**.

### Missions can expire mid-flight *(PDF p102 / manual p104)*

> **If the conditions required to start a mission are lost while the mission is
> underway, the mission will end.** For example, Diplomacy missions can only be
> sent to a neutral or friendly system that is not in an uprising state. If the
> Diplomacy mission is underway, and the system should fall under enemy control
> or go into uprising, the mission will end.

The target predicate is a **continuous** requirement, not an entry check.

### Informants *(PDF p102 / manual p104)*

Free intelligence, unprompted:

> Occasionally you will receive intelligence information from **informants** on
> enemy systems… almost as if you had sent an Espionage mission there. The
> difference is that often informants will provide **incomplete** information…
> **Informants are more common in systems that are in a state of uprising.**

So unrest leaks intel — a second reason uprisings hurt the controller.

### The mission types — complete table *(PDF p103–p106 / manual p105–p108)*

Fifteen missions. "Attribute used" is the stat the success roll reads.

| Mission | Valid target | What it does | Attribute |
|---|---|---|---|
| **Abduction** | enemy character on a system or fleet; **not** in hyperspace, **not** already captured | capture a specific enemy character. **This is a victory path** — see below. Note characters can also be captured by a foiled mission or by fleeing a blockade | Combat |
| **Assassination** | enemy character on a system or fleet; not in hyperspace, not captured | injure or kill a target Alliance character. **Empire only.** "You cannot kill primary characters such as Luke Skywalker, but **injuring them makes them easier to capture**" | Combat |
| **Death Star Sabotage** | a Death Star **with a known location**; not in hyperspace; must be **built** | **Alliance only.** Success destroys the Death Star | Combat **and** Espionage |
| **Diplomacy** | **neutral or friendly** system **not in uprising** | increases popular support for your side. On neutral systems this "may (or may not) result in the system coming over to your side" | Diplomacy |
| **Espionage** | **any explored system** | gathers information. On a successful enemy/neutral mission, what the Manufacturing/Production and System Defense windows show for that system **is accurate** — a "snapshot" that can go stale. **Run on your own system it becomes counter-intelligence**: helps detect enemy missions against it and enemy personnel on blockading fleets | Espionage |
| **Facility Design Research** | friendly system **with a construction yard** | contributes R&D toward new facility design | must have **Facility Design Research** ability |
| **Incite Uprising** | **enemy-controlled** system | starts or deepens an uprising. Decreases enemy popular support; raises the chance enemy **troops and facilities are destroyed** during it; raises the chance of **injury to enemy characters** there; raises the chance any **friendly captured character escapes** | Leadership |
| **Jedi Training** | friendly system holding Force-aware characters **and Luke or Vader** | raises the Force level of the students. **Aborts and fails if the system suffers a bombardment or assault** | **The Force** |
| **Reconnaissance** | **any system not under your control — explored *or unexplored*** | reports facilities, military units, resources, popular support and controller. **Does not reveal characters or SpecForces present**, and **does not reveal Manufacturing-window information.** The **only** mission that can target an unexplored system. **Only Longprobe Y-wing Recon Teams and Imperial Probe Droids may perform it.** Same information regardless of whether the system is populated | **N/A** |
| **Recruitment** | any friendly system; **success depends in part on how strongly that system supports your side** | **only a major character can perform it**; success adds a **new minor character** to your side. Repeatable on the same system | Leadership |
| **Rescue** | captured character on an enemy fleet or system; not in hyperspace | frees a character held by the opponent | Combat |
| **Sabotage** | enemy **facility, capital ship, fighter squadron, trooper regiment, or SpecForce**; not in hyperspace; **must be completed** | destroys the target. "**Anything that can be built in the game with a manufacturing facility can be sabotaged**, as long as it is completed and not in hyperspace." A Death Star needs the dedicated mission instead — **but the Empire can sabotage the Alliance headquarters** | Combat **and** Espionage |
| **Ship Design Research** | friendly system **with a shipyard** | contributes R&D toward new ship design | must have **Ship Design Research** ability |
| **Subdue Uprising** | **friendly** system **in uprising** | suppresses the uprising and **increases popular support** there | Leadership |
| **Troop Training Research** | friendly system **with a troop training facility** | contributes R&D toward new troop types | must have **Troop Training Research** ability |

Patterns worth extracting for the engine:

- Every target spec is a **predicate over game state** — ownership, uprising
  state, explored state, presence of a facility of a given role, not-in-hyperspace.
  None of it needs faction names except the two side-locked missions.
- **Two missions are side-locked** (Assassination → Empire, Death Star Sabotage →
  Alliance), and both are locked because of an asymmetric *capability*, not
  because of identity. In pack terms they belong to the faction that owns the
  relevant unit/target.
- **Three R&D missions are gated on a character ability rather than a stat roll**
  — the "attribute used" column says *must have the ability*, not a rating.
- **Reconnaissance is the only unit-locked mission** and the only one with **no
  attribute at all** — it either happens or it doesn't.

### ★ Character victory conditions *(PDF p103 / manual p105)*

Buried in the Abduction row, and the only place the manual states it in the
pages read so far:

> **To win the game if you are playing the Empire, you must capture Mon Mothma
> and Luke Skywalker. If you are the Alliance, you must capture Darth Vader and
> Emperor Palpatine.**

Two named characters per side, captured **alive** — which is why Assassination
explicitly cannot kill primary characters, only injure them to make capture
easier. The two victory tracks are therefore *capture the enemy leadership* and
(per Chapter 1, not yet read) something territorial.

In pack terms: each faction declares a **list of enemy character ids that must be
captured**, and the engine checks captures against it. No names in code.

### Research and development *(PDF p102 / manual p104)*

> **Each facility you control contributes slightly to research in its own area**,
> so R&D happens as the game progresses, **even if you do nothing**. However,
> results are much faster if you send one of your characters on an R&D mission.

So R&D has two inputs: a **passive trickle proportional to facility count per
track**, and **mission-driven bursts**. Three tracks, each tied to a facility
role:

| Track | Passive source | Mission needs | Payoff |
|---|---|---|---|
| **Facility Design** | construction yards | friendly system with a construction yard | improved designs — e.g. yards that "let you build facilities in **less time**" |
| **Ship Design** | shipyards | friendly system with a shipyard | "helps strengthen your fleets" |
| **Troop Training** | training facilities | friendly system with a training facility | "lets you train **new types of regiments with better skills**" |

> When an R&D mission results in a new technology, the message droid will inform
> you and **the new facility (or troop or ship) will be immediately accessible**.

Research unlocks **new buildable items**, immediately, with no separate adoption
step. This is where the "**Advanced**" facility variants in the p080 catalogue
come from — they are R&D-gated unlocks, not separate build options.

### Tracking a mission in flight *(PDF p107 / manual p109)*

- A mission in progress puts a **faction icon at the lower right of the target
  system** (Fig. 3.49) — note this is the *same corner* the uprising flame uses,
  per Fig. 3.36.
- Double-click it for the **Mission window**; right-click it for the menu, which
  offers **Encyclopedia**, **Status**, and the orders to **abort or continue**.
- **More than one mission can be running on a single system** — the window lists
  them in a column.
- The window separately reports the status of **agents** and of **decoys**.

Hyperspace is a real state with real restrictions:

> Any time you send a character from one system to another, there is a period of
> time when the character is **in hyperspace**. This time is relatively short if
> the character is travelling **within a sector**, longer for journeys **between
> sectors**. … **You cannot give orders to units in hyperspace; you must wait
> until they reach their destination.**

Shown in the UI as a **starfield background behind the portrait**. A mission
cannot be aborted while the team is in hyperspace either — orders simply don't
apply. Note how many mission target specs say "cannot be in hyperspace": it is
also a **shield**, since a target in transit cannot be abducted, assassinated,
rescued or sabotaged.

### Three outcomes, not two *(PDF p108 / manual p110)*

This distinction matters and is easy to miss:

| Outcome | Meaning |
|---|---|
| **Succeeds** | "the objective was met" |
| **Foiled** | "the team members were **detected** and were **unable to attempt** the mission" |
| **Fails** | "the team **got through** but still couldn't meet the mission's objective" |

Only *foiled* carries the personnel risk — "personnel on a foiled mission are
sometimes captured, wounded, or killed." A plain failure is safe; you simply
didn't achieve anything.

> NOTE: Even if a foiled or failed mission message reports that agents haven't
> returned, it could turn out that **the decoys have made it back safely**.

### Persistent missions *(PDF p108 / manual p110)*

Four mission types don't end on a single roll — they **repeat until complete**:

| Mission | "100 percent successful" means |
|---|---|
| **Diplomacy** | the system supports your side **completely** |
| **R&D** | **all possible discoveries** have been made |
| **Incite Uprising** | the system has **changed control** |
| **Subdue Uprising** | the uprising has **ended** |

After each attempt the character reports in and asks whether to continue.

> Missions are not always successful the first time, but **perseverance
> frequently pays off**.

> NOTE: **If you don't read and respond to a message in a timely fashion, the
> character automatically continues the mission** until it can no longer be
> continued.

So the default is *keep going*. A diplomacy mission left alone grinds a system to
100% on its own. This is worth holding next to the support-drift investigation:
an unattended Diplomacy mission is a **legitimate** source of steadily climbing
support with no further player input.

### Base systems and returning *(PDF p108–p109 / manual p110–p111)*

Expands §7:

- Each character is attached to a **base system**.
- At mission end: if the mission system is **friendly**, the team **stays there**.
  If it is not, they **return to base**.
- Base changes by **moving** the character there — there is no separate "set base"
  command.
- **Confirmed Move** shows the **transit time in days** before you commit.
  Plain **Move** doesn't. Characters can also be moved by **dragging the icon**
  onto a system or fleet.
- **A character on a ship has that ship as their base.** They return to the ship —
  unless it is in hyperspace, in which case they head for "a friendly system
  nearest to where the mission concluded."

> TIP: If you change the base of important characters such as Luke and Mon
> Mothma, be sure that the new base system is **well-defended**, since the Empire
> will likely try to **abduct** those characters.

> TIP: To save time spent travelling through hyperspace, station characters at a
> base **in a sector where they are likely to perform their missions**.

---

## 13. Fleets in depth

Extends §8, which covered the tutorial's treatment.

### What a fleet is *(PDF p109 / manual p111)*

> A fleet is an organization of capital ships and the fighter squadrons, troops,
> and personnel on board. **A fleet must contain a minimum of one capital ship.**

The containment rules are strict, and asymmetric between cargo types:

| Carried | Limit |
|---|---|
| **Fighter squadrons** | only in a fleet whose capital ships have **space for them** |
| **Troops** | same — capacity comes from the capital ships |
| **Characters and SpecForces** | **"Fleets can carry any number"** — no limit at all |

Per-ship capacity is published in **the Encyclopedia entry for each capital
ship**. So carrying capacity is **ship-class data**, which is exactly where it
belongs for a pack.

A fleet can **defend a system, attack a system, engage an opponent's fleet in
space**, or **transport troops**.

**More than one fleet can orbit the same system**, and a fleet in orbit puts a
**Fleet icon in the system's upper-right corner**.

This gives the corner map for a system icon, now complete across the manual:

| Corner | Marker |
|---|---|
| **upper right** | fleet in orbit |
| **lower left** | System Defenses (the way in to characters, troops, defenses) |
| **lower right** | mission in progress **or** uprising flame |

### Reading the Fleet window *(PDF p110–p111 / manual p112–p113)*

Left column = fleets, expandable to the ships inside. Right column = detail on
the selection. Right-most column = **four tabs: capital ships, fighter squadrons,
troops, personnel.**

At-a-glance badges on the fleet entry itself:

| Badge | Means |
|---|---|
| **blue engine glow** | the fleet is **in hyperspace** |
| fighter glyph | fleet has at least one fighter |
| troop glyph | fleet has at least one troop |
| personnel glyph | fleet has at least one personnel unit assigned |

Capacity is shown as the **carried / capacity pair** noted in §8 — "Fleet contains
one fighter, but has room for two"; the same for regiments. Drilling into a
capital ship shows *which* ship is carrying them: "both of the spaces for fighters
in this fleet are on the *Victory* Destroyer."

The manual repeats the command-assignment reminder on the personnel tab —
**a character aboard a fleet is not commanding it until you right-click and pick a
rank from the Command sub-menu.**

### Building ships *(PDF p111 / manual p113)*

Requires a system with an **orbital shipyard**. Two routes, same result:

1. Right-click the **Ship Construction** area of that system's Manufacturing and
   Production window → **Build**.
2. Right-click your **agent** → **Build Ships** → crosshair → click a destination.
   "The ship will be deployed to a fleet in orbit about that system."

Both open the **Build Selection window** for ships.

> **You can select an existing fleet as the target for building a new ship. This
> is faster than building it to a system and then moving it after it is
> constructed.**

And the rule that explains why the galaxy fills with one-ship fleets:

> **As soon as you give the order to build a new capital ship, a new fleet is
> [created for it]** — unless you targeted an existing fleet.

The right-click menu on a production area (Fig. 3.57): **Build, Destination,
Encyclopedia, Status, Reserved.**

### ★ "Time to completion" is a DATE, not a duration *(PDF p112 / manual p114, Fig. 3.58)*

The Build Selection window's own callouts settle a reading that §3a left open:

| Field | Fig. 3.58 value | The manual's callout |
|---|---|---|
| Maintenance cost | 26 | — |
| Refined material cost | 24 | — |
| **Best Time To Completion** | **Days: 104** | "**Denotes the day task will be completed**" |
| **Best Time To Deployment** | Days: 0 | "**Additional** number of days until unit is deployed to destination system" |
| Number to build | 1 | "Number of units to build **consecutively**" |

So *Completion* is an **absolute game day**, and *Deployment* is a **duration
added on top of it** — travel time from the yard to the chosen destination. A
Carrack at "104" is not a 104-day build; it is done on day 104. "Best" implies
these are optimistic estimates that can slip.

"Number to build" queues **consecutive** copies — one order, N units, built in
series, not in parallel.

### New ships always create a fleet *(PDF p112 / manual p114)*

> As soon as you give the order to build a new capital ship, a new fleet is
> established in orbit about the system and **that ship is its only member**.

**Fighters are different**: "If you build a fighter squadron, the unit is
**stationed on the planet surface** until you assign it to a carrier capital
ship." So a fighter with no carrier is a planetary asset — which is the same
thing §8 described as system-defense fighters.

### The production-area menu, in full *(PDF p112–p113 / manual p114–p115)*

**The same menu serves orbital shipyards, training facilities and construction
yards** — one interaction for all three production types:

| Option | Effect |
|---|---|
| **Build** | open Build Selection |
| **Stop** | halt construction of the current item |
| **Destination** | set where the finished item goes |
| **Rename** | rename the ship. **Ships only** — "the only menu option that isn't available under Facilities Under Construction or Troops in Training" |
| **Encyclopedia** | the *ship's* entry **only while a ship is being built**; otherwise the **system's** entry |
| **Status** | when the current project will be completed |
| **Reserved** | **"Prevents your agent from using that shipyard for any of its automated management functions."** It may still be used when you explicitly pick Build Ships from the agent menu |

**Reserved** is the manual's answer to the agent automating away a facility you
were saving. Worth noting for our agent work: automation is **opt-out per
facility**, not global.

### Ship status and damage *(PDF p113–p115 / manual p115–p117)*

A built ship's right-click menu: **Move, Confirmed Move, Create Fleet, Rename,
Encyclopedia, Status, Scrap.**

The Capital Ship Status window is the fullest unit stat block in the game
(Fig. 3.61):

| Group | Fields |
|---|---|
| Assignment | **Fleet** it is assigned to, **Status** |
| Cost | **Maintenance Cost** |
| **Capacity** | Fighter Squadrons, Trooper Regiments |
| **Embarked** | Fighter Squadrons, Trooper Regiments, **Personnel** |
| Condition | **Ship Damaged: yes/no** |
| Systems | Hyperdrive Rating, Hull Value, Damage Control Rating, Shield Recharge Rate, Maximum Shield Strength, Tractor Beam Power, Sub-Light Engine Rating, Weapon Recharge |
| Ratings | **Maneuverability**, **Detection Rating**, **bombardment modifier** |
| Weapons | **arc ratings** per weapon type — **turbo laser, ion cannon, laser cannon** — × per station — **forward, aft, starboard, port** |

Eight systems are stored as **current : capacity pairs** — Hyperdrive, Hull,
Damage Control, Shield Recharge, Maximum Shield Strength, Tractor Beam Power,
Sublight Engine, Weapon Recharge. Damage is therefore **per-subsystem**, not a
single hit-point total: Fig. 3.62's ship is intact except "shield recharge …
current rate is 8 but the maximum rate is 10."

Note **Detection Rating on the ship itself** — "how well it detects enemy
missions." That is the ship's contribution to the foiling roll of §12,
independent of any commander aboard.

Damage and repair:

- Sources: **direct battle**, or **planetary batteries firing from a system's
  surface**.
- Shown as **burn marks** on the ship graphic.
- **"A damaged ship will always try to repair itself."** Repair is automatic and
  needs no order.
- **Stationing in orbit at a system with an orbital shipyard speeds repairs.**
- **"Ships do not get repaired while in hyperspace."**

**A fighter squadron is 12 fighters.** A "damaged" fighter icon means **lost
starfighters** — right-click → Status for the count remaining. So squadrons take
attrition in whole aircraft, while capital ships take subsystem damage. Two
different damage models.

> **To free up maintenance capacity, scrap ships as you would other units.**

Which confirms the pool model of §3: scrapping **returns** maintenance capacity.

### The ship roster *(PDF p115–p118 / manual p117–p120)*

> Note that **you can't build all these ships at the beginning of a game. Ship
> Design Research missions help you learn how to build better ships.**

So the roster is **partly R&D-locked** from day one. Capacities below are the
manual's; the repo's `data/military_units.json` carries the extracted stats and
should be treated as authoritative for numbers — this table is the **capacity and
role** reference.

**Alliance** (manual p117–p118):

| Ship | Fighters | Troops | Note |
|---|---|---|---|
| Alliance Dreadnaught | 1 | 2 | slow and heavy |
| Alliance Escort Carrier | 6 | 0 | |
| Assault Frigate | 0 | 0 | key Alliance warship |
| A-wing | — | — | fighter |
| Bulk Cruiser | 0 | 0 | mainstay of Alliance fleets |
| Bulk Transport | 0 | **6** | |
| Bulwark Battlecruiser | **10** | 4 | ideal for large-scale operations |
| B-wing | — | — | fighter |
| CC-7700 Frigate | 0 | 0 | **gravity well generators — prevent opposing ships from withdrawing from a battle** |
| CC-9600 Frigate | 0 | 1 | |
| Corellian Corvette | 0 | 0 | mid-sized capital ship |
| Corellian Gunship | 0 | 0 | fast and deadly |
| *Dauntless* Cruiser | 4 | 2 | |
| *Liberator* Cruiser | 6 | 3 | one of the most advanced warships |
| Medium Transport | 0 | 2 | |
| Mon Calamari Cruiser | 3 | 1 | reliable in battle but **difficult to repair** |
| Nebulon-B Frigate | 2 | 0 | **effective against fighters** |
| X-wing | — | — | fighter |
| Y-wing | — | — | fighter |

**Empire** (manual p119–p120):

| Ship | Fighters | Troops | Note |
|---|---|---|---|
| Assault Transport | 0 | 1 | |
| Carrack Light Cruiser | 0 | 0 | very fast |
| **Death Star** | **24** | **18** | its own section, later |
| Galleon | 0 | 2 | **no guns** |
| Imperial Dreadnaught | 1 | 2 | slow and heavy |
| Imperial Escort Carrier | 6 | 0 | |
| Imperial Star Destroyer | 6 | 3 | |
| Imperial II Star Destroyer | 6 | 3 | |
| Interdictor Cruiser | 0 | 0 | (the Empire's gravity-well counterpart) |
| Lancer Frigate | 0 | 0 | **designed to withstand Rebel fighters** |
| Star Galleon | 0 | 3 | |
| Strike Cruiser | 1 | 0 | **easy to mass-produce** |
| Super Star Destroyer | **12** | **9** | |
| *Victory* Star Destroyer | 2 | 2 | |
| *Victory* II Star Destroyer | 2 | 0 | |
| TIE Bomber / Defender / Fighter / Interceptor | — | — | fighters |

Roles visible in the data alone, with no lore needed: **carrier** (high fighter,
low troop), **transport** (zero fighter, high troop), **line warship** (zero/zero,
guns only), **anti-fighter** (Nebulon-B, Lancer), **battle-locker** (CC-7700 /
Interdictor gravity wells), **capital-of-capitals** (SSD, Bulwark). This is a good
argument for the pack format carrying **role tags** on ships, exactly as
[PROJECT.md](PROJECT.md) proposes for facilities.

### Rearranging fleets *(PDF p118 / manual p120)*

- **Drag** ships or troops between fleets in the open Fleet display.
- **"If you move all the ships out of a fleet, the fleet is automatically
  disbanded."** Fleets are containers, not persistent entities.
- Right-click a ship → **Create Fleet** makes a new fleet with it alone;
  Ctrl-select several first for a bigger one.

And the manual's guidance on fleet composition, which doubles as a statement of
what neutral worlds are like:

> If you're building a fleet to take over **neutral** systems, you'll include
> ships that can bombard any planetary defenses, and enough troops to establish a
> garrison; **neutral systems don't have defensive fleets or troops**, so you
> won't need fighters or extra offensive troops. On the other hand, if you're
> going after one of your **opponent's** systems, you would need a more
> heavily-armed fleet.

Note that neutral worlds *can* still have **planetary defenses** even without
fleets or troops.

### Claiming an unpopulated world, precisely *(PDF p118 / manual p120)*

Refines §8:

1. Move the fleet into orbit.
2. Open the **Troop tab** of the Fleet window.
3. Select the troops and **drag them onto the system**, or right-click → **Move**.
4. "The troops will establish the garrison and **the system name will immediately
   change to your colour**, indicating you can begin building facilities there."

> **Uninhabited systems do not have a garrison requirement as such, but you need
> to have at least one trooper regiment on them to control them.**

So the floor is 1, always, and it is not derived from support — unpopulated
worlds have no popular support to derive it from.

### Fleets can explore *(PDF p119 / manual p121)*

> Although you cannot send fleets on Reconnaissance missions *per se*, **a fleet
> can explore an unexplored system.** When you move a fleet to such a system …
> you learn the same information about the system that you do from a Recon
> mission … **except any characters or SpecForces that may be present and
> information concerning current manufacturing.**

Identical information to a Recon mission, with the same two exclusions. The
trade-offs are stated:

| | Fleet | Recon mission |
|---|---|---|
| Can claim the world immediately | **yes**, if carrying a transport | no |
| Stays after arriving | **yes** — "won't turn around and come back" | returns |
| Risk | **may be engaged by a stronger defending fleet** | the team, not a fleet |

> TIP: … base a Longprobe or Imperial probe droid **on a fleet**, move the entire
> fleet out to an unexplored Rim sector, and then send the SpecForce unit on Recon
> missions from there.

A mobile forward base — worth noting, since it means recon range is effectively
extended by fleet movement.

### The Fleet menu *(PDF p119 / manual p121, Fig. 3.64)*

| Command | |
|---|---|
| **Move** | crosshair → destination; ESC cancels. "The fleet **immediately goes into hyperspace**" |
| **Confirmed Move** | as above, with transit days shown first |
| **Planetary Bombardment ▸** | **Target Military Facilities / Target Civilian Facilities / General Bombardment** |
| **Planetary Assault** | |
| **Rename**, **Encyclopedia**, **Status**, **Scrap** | |

> NOTE: **Any time a fleet, or a ship within a fleet, is in hyperspace, it cannot
> receive orders.**

And the command-rank effects restated fleet-side, which is a slightly different
emphasis from §11:

- **Admirals** improve the fleet's **overall performance in battle**.
- **Commanders** enhance **fighters** in the tactical game.
- **Generals** improve **troops' ability to take control of a system through
  planetary assault**.

### Reinforcing a fleet across a distance *(PDF p120 / manual p122)*

> If you move a ship onto a fleet in a **different sector**, that ship will
> **immediately be considered a member of the fleet** but will **still be in
> hyperspace for several days** until it arrives.

Membership is instant; presence is not. A fleet's roster can therefore include
ships that have not physically arrived.

---

## 14. Bombardment, assault and blockade — the reference treatment

§9 covered these from the tutorial. This is the full statement.

### Bombardment resolution *(PDF p120 / manual p122)*

The sub-menu only appears **when your fleet is in orbit around an enemy or
neutral system**. The sequence is explicit:

1. **Defensive batteries fire back.** "If you bombard a system that has defensive
   batteries, **they will fire at your ships in orbit, possibly causing serious
   damage**."
2. **Shields are a gate, not armour.** "If a system has one or more planetary
   shields, the attacking ships must **first blast through the shield(s)**."
3. **The roll is a sum against a value.** "**Each ship's Bombardment Modifier**
   (shown in the ship's status) **is combined and pitted against the shield's
   defensive strength.**"
4. **Overflow reaches the ground.** "Any bombardment firepower that gets past the
   shield is used against **troops and facilities on the ground**."
5. A window then displays the effects.

**The ion cannon is a special case worth copying exactly:**

> *Exception*: The planet-based ion cannon, **KDY-150, does no physical damage. It
> robs energy from an attacking vessel, preventing it from being able to bombard
> the system during the attack.**

A **soft-lock weapon** — it doesn't kill ships, it cancels their bombardment.
This is a distinct defensive *role* from a battery, and pairs with the blockade
rule below where ion cannons also break blockades.

The four bombardment options:

| Option | Effect |
|---|---|
| **Target Military Facilities** | destroy **defensive shields and batteries**. "**Bombardment is not 100 percent accurate — targeting military facilities may cause collateral damage**" |
| **Target Civilian Facilities** | destroy non-military facilities, "such as **construction yards and refineries**". "**Destroying civilian facilities hurts loyalty**" |
| **General Bombardment** | "indiscriminately attack the planet surface" |
| **Destroy System** | **only available to the Empire, and only with the Death Star in the fleet** |

That confirms the manual's own division of facilities into **military** (shields,
batteries, ion cannons) and **civilian** (construction yards, refineries, mines,
shipyards, training) — a **role tag**, exactly what a pack needs.

### ★ Two shields block a planetary assault *(PDF p121 / manual p123)*

The precise rule, which §9 only had in outline:

> Planetary shields can protect a system from planetary assault and bombardment.
> If you are in orbit above an enemy or neutral system, **have troops in your
> fleet**, and this option is **grayed out**, it means **at least two planetary
> shields** are defending the system. You need to **destroy the shields — through
> bombardment or sabotage — before you can assault**.

So: **0–1 shields → assault allowed. 2+ shields → assault blocked entirely.** Not
a modifier, a hard gate. And two routes through it: **bombardment** (which the
shields also resist) or **Sabotage missions** (which bypass them).

### Planetary assault *(PDF p120–p121 / manual p122–p123)*

> Click here and the troops on your fleet will land on the system, **engage any
> ground defense troops, and attempt to establish a garrison. If successful, your
> side controls the system.**

Every assault raises the **Assault Summary window**, and:

> NOTE: This window **also is available as a message when your opponent assaults
> one of your systems.**

Drilling into either side's forces gives a **damage summary** with a tab per
category: **trooper regiments** (operational vs destroyed), **capital ships**,
**fighters**, **manufacturing and defensive facilities**, and **personnel**. Five
loss categories — so an assault damages the *planet's* facilities too, not just
the armies.

### Blockades — the mechanism *(PDF p122 / manual p124)*

> **Any time a fleet is in orbit above an enemy or neutral system, that fleet
> automatically sets up a blockade.**

There is no "blockade" order. It is a **passive consequence of orbit** — which
means every attacking fleet is also blockading while it sits there.

| Effect | |
|---|---|
| Units have "difficulty moving on or off the system" | |
| **Troops** attempting to move | **may be killed** |
| **Personnel** trying to cross | **may be injured, killed, or captured** |
| Loyalty | drifts, amplifying the existing lean (§ support table) |
| Facilities | unusable (manual p059) |
| **Counter** | **"ion cannons on a system allow units to move through the blockade"** |

The ion cannon is therefore the answer to *both* halves of a siege — it stops
bombardment and it breaks the blockade's transit hazard. That makes it the single
most strategically valuable defensive facility in the game, which the code's
seeding (1 ion cannon galaxy-wide) does not reflect.

### When fleets meet *(PDF p122 / manual p124)*

> Whenever your fleet meets another fleet in orbit about a system, **the two
> fleets engage in battle**.

Automatic, like the blockade. Resolution is Chapter 4 (tactical).

### The Death Star *(PDF p122 / manual p124)*

Empire-only, and the manual is unusually direct that **using it is a mistake**:

- "Takes **immense resources and a long time to deploy**. Clearly this isn't a
  project to be undertaken lightly or early in the game."
- Its best use is **not** planet-killing: "with its immense carrying capacity
  [24 fighters, 18 troops] and firepower it may be more useful strategically to
  **strengthen your offensive fleet and bombard planets in preparation for a
  planetary assault. After all, a system destroyed is a system unavailable for
  conquest.**"
- **"The Death Star works best as a threat. Merely having it available increases
  the effectiveness of garrisons in preventing uprisings."**
- Destroying a system "**decreases your popular support a great deal across the
  galaxy**" — the only galaxy-wide support effect in the game.

The counter-play, stated symmetrically:

| | |
|---|---|
| **Alliance defence against it** | **none.** "There is no way to protect a system from a Death Star attack" |
| **Alliance counters** | a **Death Star Sabotage** mission, or a fighter "**Death Star run**" in a tactical battle |
| **Empire protection** | build **Death Star shields on the system where the Death Star is located** |
| **Beating that shield** | **only** a Death Star Sabotage mission |

So it is a rock-paper-scissors with one unbeatable branch: shields stop the
fighters, sabotage beats the shields.

### Locating fleets *(PDF p122–p123 / manual p124–p125)*

Three routes: the **Fleet icon** in the Sector window, the **GID**, and the
**Fleet Finder**.

**★ The GID Fleets sub-menu, and what marker size means there:**

> Click on the Galactic Information Display control and select the **Fleets**
> sub-menu, then click on **Idle Fleets** or **Fleets En Route**. **Now the size
> of the star icon shows how many fleets are stationed on or en route to each
> system.**

This is important for our implementation and differs from the Loyalty modes:
under **Fleets**, marker size encodes a **count**, not a magnitude or a
percentage. The GID's size channel is therefore **mode-dependent** — support
strength in one mode, a raw tally in another. Any single shared threshold table
across all modes is wrong.

**Fleet Finder** (Figs. 3.68–3.70): type a fleet name or scroll; tabs for **all
fleets / Alliance fleets / Imperial fleets**; **Display** opens the Fleet window
*and* the Sector window for it. A **Ship Finder** button toggles the same dialog
to search individual ships, and a matching button toggles back.

---

## 15. Defense

> As your sphere of influence grows, it's important not to leave systems
> controlled by your side under-defended.

The manual's own list of what defense consists of *(PDF p123 / manual p125)*:

1. **garrisons**
2. **fighters**
3. **planetary batteries and shields**
4. **doubling your fleets as defensive front linesmen**
5. **anticipating attacks**
6. **protecting key systems and sectors**

All of it is reached through the **System Defenses window** — double-click the
**Defense icon at the lower left** of a system in the Sector window.

### The System Defenses window — five tabs *(PDF p124 / manual p126, Fig. 3.73)*

| Tab | Contents |
|---|---|
| **Personnel** | characters **and Special Forces** on the system |
| **Troops** | trooper regiments on the system, **and the garrison requirement if any** |
| **Fighter** | fighters **stationed on the system** |
| **Planetary Shield** | shields protecting the system |
| **Planetary Battery** | batteries protecting the system |

This is the window §11 said you must go through to reach a character, and the
window §3a's Fig. 2.13 showed the Garrison Requirement in.

### The defensive layers, and what each one stops *(PDF p124 / manual p126)*

The manual maps threat to counter one-for-one:

| Threat | Counter |
|---|---|
| **An enemy fleet establishing a blockade** | **strong defense fleets**, *or* **fighter squadrons stationed on the system** |
| **Enemy ships in orbit** | **planetary batteries** — "fire at enemy ships" |
| **Bombardment** | **shields** |
| **Planetary assault** | **troops** |
| **Sabotage and other missions** | **capital ships, fighter squadrons, and trooper regiments in the system — "preferably commanded by characters" — to foil enemy missions** |

**Fighters on the ground can prevent a blockade.** That is a rule §14 didn't have:
a blockade is automatic *only* against an undefended system.

### Attack vs. defense, and facility toughness *(PDF p125 / manual p127)*

> In the game, **attack strength is measured by firepower. Defensive game
> components are measured by how well they can withstand attack.** The
> Encyclopedia entry for each component gives its **defensive rating**. Different
> components protect against **different types of attacks**.

> A planetary bombardment can damage facilities. **Each facility has its own
> defense strength. A construction yard, for example, has a bombardment defense
> value of 3.**

So **every facility carries a bombardment defense value** — a per-facility stat
the code has no equivalent for. And defense is **typed**: "garrisoned troops on
the system can do little against orbital bombardment except duck and run for
cover."

### ★ Garrison requirements — the exact rules *(PDF p125–p126 / manual p127–p128)*

This supersedes the outline in §10:

> If a system you control **does not strongly support your side**, it may have
> certain garrison requirements. This is **the minimum number of troops you need
> on that system to prevent an uprising**.

| Situation | Result |
|---|---|
| Troops present **≥** requirement | stable |
| Troops present **> 0 but < requirement** | **the system goes into uprising** |
| **While in uprising** | **the garrison requirement DOUBLES** |
| Requirement **> 0** and troops present **= 0** | **"you will lose control of the system"** — immediately, no uprising step |
| **Unpopulated** system | no requirement "as such", but **≥ 1 regiment needed to control it** |

Note the doubling: it is a **precise ×2**, not the vague "sharp increase" of
manual p091. Which means an uprising can be self-sustaining — you were short of
*N*, and now you need *2N*.

> NOTE: **Removing troops from a system that is not strongly loyal to your side
> can send that system into uprising or push it into neutrality.**

A world can therefore fall out of your control **into neutrality**, not only into
enemy hands.

### What a garrison is, and how ground combat resolves *(PDF p125 / manual p127)*

> A garrison is an established military presence on a system. It is made up of the
> troop or troops stationed on the system **surface**.

Opening garrison troop types: **Army Regiment and Fleet Regiment** (Alliance);
**Army Regiment and Stormtrooper Regiment** (Empire).

When an assault lands, the outcome depends on:

1. **the number of trooper regiments on each side**
2. **the leadership rating of the general in command**
3. **the relative strengths and defenses of the troops** — "Stormtroopers, for
   example, are stronger than Alliance Army Regiments"

> TIP: Study the **attack and defense ratings** for your trooper regiments and
> you'll likely find each troop type has a "**best role**."

### The Manage Garrisons automation *(PDF p126 / manual p128)*

Worth recording precisely, because it is a specification for an AI helper we may
want:

> Right-click on the droid … and select **Manage Garrisons**.

Its priority order, as stated:

1. **build troops to systems in uprising first**
2. then place **at least one regiment on every system you control**
3. **add more regiments if necessary to maintain control**
4. **try to provide a stronger defense on systems that have manufacturing
   facilities**
5. **never remove excess troops from a system**

> NOTE: **The garrison manager meets requirements by BUILDING troops, not by
> moving existing ones.**

A deliberately conservative agent: it only ever adds. And **Reserved** on a
training facility exempts it from this automation while still allowing explicit
**Build Troops** orders.

### Building troops *(PDF p126–p127 / manual p128–p129)*

Same interaction as ships and facilities — right-click the **Troops in Training**
section of the Manufacturing and Production window, or use the agent's **Build
Troops**, which routes to "the **nearest available training facility**."

> Note **some of the units available to build are Special Forces, not troops.**

Fig. 3.76 gives a second cost calibration point next to the Carrack of §13:

| Alliance Army Regiment | |
|---|---|
| Maintenance cost | **6** |
| Refined material cost | **3** |
| Best Time To Completion | day **24** |
| Best Time To Deployment | **+34 days** |

Note deployment (34) exceeds completion (24) here, which only makes sense under
the "additional days" reading established in §13 — the unit is built on day 24
and takes 34 more days to reach its destination.

> **Troops with higher ratings tend to take longer to build and cost more to
> maintain. Not all will be available to you until R&D develops that troop.**

### Fighters as defense *(PDF p127 / manual p129)*

> **Fighters in a system that are not part of a fleet are considered to be in
> hangars on the ground rather than in orbit.** However, these fighter squadrons
> help your defenses because **they can engage an enemy fleet when it enters your
> system**.

So a fighter squadron has two possible homes — **aboard a carrier** (fleet member)
or **in a planetary hangar** (system defense) — and it is useful in both. This is
the same fact §13 gave from the build side: a newly built fighter sits on the
surface until assigned to a carrier.

> **Fighters and troops can also defend your system by detecting enemy agents and
> foiling their missions.**

### ★ Which stat does what, for a commander *(PDF p127 / manual p129)*

The clearest statement in the manual, and it resolves the three roles cleanly:

| Character stat | Effect when commanding on a system |
|---|---|
| **Leadership** | "**enhances the performance of the trooper regiment or fighter group. The higher the character's leadership rating, the greater the enhancement**" |
| **Espionage** | "significantly enhances your ability to **detect and foil enemy missions** at that system" |
| **Combat** | increases your ability to **capture or kill** the members of a detected mission |

Assignment for a *land* command: **move the character onto the system**, then
right-click → **Command** → rank. Admirals lead fleets, Commanders lead fighter
squadrons, Generals lead trooper regiments.

### ★ Trooper regiment stats *(PDF p128–p129 / manual p130–p131)*

Ten regiment types, five a side, each with **three** numbers. Note that
**Bombardment Defense is a separate stat from Defense Strength** — troops resist
orbital fire and ground assault differently.

**Empire:**

| Regiment | Attack | Bombardment Def. | Defense |
|---|---|---|---|
| Imperial Army Regiment | 3 | 5 | 5 |
| Stormtrooper Regiment | 6 | 6 | 6 |
| Dark Trooper Regiment | **8** | 6 | **8** |
| Imperial Fleet Regiment | 5 | 2 | 3 |
| War Droid Regiment | **8** | 2 | 2 |

**Alliance:**

| Regiment | Attack | Bombardment Def. | Defense |
|---|---|---|---|
| Alliance Army Regiment | 3 | 5 | 5 |
| Alliance Fleet Regiment | 6 | 5 | 3 |
| Mon Calamari Regiment | 2 | **9** | **8** |
| Sullustan Regiment | 1 | 2 | 4 |
| Wookiee Regiment | **8** | 4 | 4 |

The "best role" the manual's tip promises is visible immediately: **Mon Calamari
(2/9/8) is a pure garrison unit**; **War Droids and Wookiees (8/2–4/2–4) are pure
assault troops that melt under bombardment**; **Army Regiments (3/5/5) are the
balanced default**; **Stormtroopers (6/6/6) are simply better than Alliance Army
Regiments at everything**, which is the asymmetry manual p127 called out.

The two sides are **near-mirrors again**: Army↔Army identical, Fleet↔Fleet nearly
so, and one elite (Dark Trooper ↔ Wookiee) plus one specialist (War Droid ↔ Mon
Calamari / Sullustan) each.

### Defensive facilities *(PDF p129 / manual p131)*

> **Systems with a construction yard can build defensive facilities** on systems
> controlled by your side. These facilities are either **shields or batteries**.

Note the prerequisite: **defenses are built by construction yards**, so a world
with no yard cannot be fortified locally.

The two roles:

| | |
|---|---|
| **Shields** | generate a protective shield around the system, guarding against **planetary assault and bombardment** — passive |
| **Batteries** | "**fire directly at an enemy fleet in orbit if that fleet initiates a planetary bombardment, or at trooper regiments if they attempt to initiate an assault**" — active, and they fire in **both** phases |

### ★ Shields have TWO defensive numbers *(PDF p129 / manual p131)*

This is the subtlety that makes the bombardment maths work:

> **Shield strength** is the amount of bombardment firepower **against which the
> shield will defend the system**. **Combined firepower over this amount will get
> through.** **Bombardment defense** is the amount of firepower it takes to
> **knock out the shield itself**.

So a bombardment run resolves against a shielded world as:

1. Sum the attacking ships' **Bombardment Modifiers**.
2. Anything **above the shield's Shield Strength** reaches the ground.
3. Separately, damage **≥ the shield's Bombardment Defense** destroys the shield.

**Planetary shields** *(manual p132)*:

| Shield | Bombardment Def. | Shield Strength | Availability |
|---|---|---|---|
| **GenCore Level I** | 2 | **40** | **both sides, from the start** |
| **GenCore Level II** | 3 | **80** | **both sides, via R&D** |
| **Death Star Shield** | 1 | — | **Empire only.** "A **foolproof** defense against a Death Star being attacked by fighters" |

The Death Star Shield is a **single-purpose counter**, not a general shield —
which is why §14's rock-paper-scissors resolves the way it does. Note **GenCore
is explicitly available to both sides**: the shield line is *not* an asymmetry.

**Planetary batteries** *(manual p133)*:

| Battery | Bombardment Def. | Attack Strength | Notes |
|---|---|---|---|
| **LNR Series I** | 4 | **800** | turbolasers; direct damage to ships; **available at start** |
| **LNR Series II** | 3 | **5000** | turbolasers; **R&D only** |
| **KDY V-150** (ion cannon) | **5** | 2000 | **drains energy instead of damaging** |

Note **LNR II trades toughness for firepower** — Bombardment Defense drops 4 → 3
while Attack rises 800 → 5000. R&D upgrades are not strictly-better here.

### ★ The ion cannon does four things *(PDF p129–p130 / manual p131–p132)*

The most mechanically interesting facility in the game, and worth quoting in
full:

> Rather than directly damaging enemy ships, this facility **drains energy from
> the attacking ship, rendering its shields inoperative and preventing it from
> firing its weapons**. An ion cannon will **prevent a blockading fleet from
> detecting any missions, injuring characters, or destroying SpecForces that pass
> through the fleet above the ion cannon**. Ion cannons **also fire upon trooper
> regiments that are making an assault**.

| Effect | Counters |
|---|---|
| Drains attacker energy → shields down, weapons offline | **bombardment** |
| Blockading fleet **cannot detect missions** above it | **mission foiling** |
| Personnel/SpecForces cross safely; characters not injured | **the blockade transit hazard** |
| Fires on landing regiments | **assault** |

Plus manual p133's summary line: "**Having an ion cannon on a system makes it
easier for troops, characters and SpecForces to escape under blockade or
bombardment.**"

One facility that partially answers every offensive option in the game. Whatever
the code seeds, this should not be the rarest facility in the galaxy — see
[ECONOMY-NOTES.md](ECONOMY-NOTES.md) §5.

*(Naming note: the manual calls it "KDY-150" on manual p122, "KDY v-150" on p132
and "KDY V-150" in the p133 table. One facility.)*

### The Troop Finder *(PDF p130 / manual p132)*

Another button beneath the GID, same shape as the Personnel/Fleet/Ship finders:
type a **system** name or scroll; tabs for **Alliance troops / Imperial troops**;
**Display** or double-click opens the System window. Results are listed by system
**or fleet**, with a count under a Troop icon.

### ★ The GID Defense sub-menu *(PDF p130–p131 / manual p132–p133)*

Five modes, and an explicit statement of what size means in them:

> …the Galactic Information Display will display large stars to indicate the
> locations of your **Planetary Batteries, Planetary Shield Generators, Fighter
> Squadrons, Troopers, or Death Star Shields**. **The larger the star, the higher
> the concentration of defenses on that system.**

So **Defense modes size by concentration (a count)**, exactly like the Fleets
modes and unlike the Loyalty modes. Collecting what the manual has now said
across three sub-menus:

| GID sub-menu | Modes | What marker size encodes |
|---|---|---|
| **Loyalty** | Popular Support, Uprisings | **support for your side**, regardless of controller (manual p091) |
| **Fleets** | Idle Fleets, Fleets En Route | **how many fleets** are stationed on / en route to the system (manual p124) |
| **Defense** | Planetary Batteries, Planetary Shield Generators, Fighter Squadrons, Troopers, Death Star Shields | **concentration of that defense type** (manual p133) |
| **Personnel** | Active Personnel, Idle Personnel | locations (manual p100) |
| **Resources** | Energy Availability, Raw Material Availability, Mines, Refineries | (Fig. 2.7, manual p024) |

**Every mode is a count or magnitude of *your own* assets except Popular Support**,
which reads support for you on *anyone's* world. That is the one mode where the
value is not simply "how much of mine is here."

### ★ The complete GID menu *(PDF p132 / manual p134, Fig. 3.81)*

Fig. 3.81 shows the whole control open, so this is the definitive top-level list:

> **Loyalty · Fleets · Personnel · Resources · Manufacturing · Defense · Display Off**

Six categories plus **Display Off**. That matches what we implemented, and
confirms **Manufacturing** is a top-level sibling — not a Resources sub-item.

### Reading enemy intent *(PDF p132 / manual p134)*

> Use intelligence gathered from your espionage agents to identify key enemy fleet
> headquarters. **Your agents will report to you when they foil an enemy mission.
> Note whether your opponent is trying to sabotage — or succeeds in sabotaging —
> key defensive systems. This could indicate an imminent attack.**

A foiled enemy mission is itself an intelligence product. And the specific
opening-position warning for the Alliance:

> **Yavin is particularly vulnerable at the start of the game** since it contains
> key personnel, is not necessarily well defended, and **the Empire knows you've
> been using it as a base**. Consider moving your characters to a safer system
> early on.

Which is a direct consequence of the asymmetric character placement in §11 — the
whole Alliance cast starts on one publicly-known world.

---

## 16. Headquarters

### The two HQs behave completely differently *(PDF p132–p133 / manual p134–p135)*

| | **Alliance HQ** | **Imperial HQ (Coruscant)** |
|---|---|---|
| Location at start | **random system on the Galactic Rim** | **fixed — Coruscant** |
| Known to the enemy? | **no** — "the location of Rebel headquarters is **unknown** at the start of the game" | yes |
| Can it move? | **yes, at will** | **no** |
| How it is lost | **destroyed** | **captured** |
| Recoverable? | **"Once the headquarters is lost, it's destroyed"** — nothing can be done | "you might possibly be able to **regain control** of Coruscant" |

> If you are playing the part of the Alliance, the headquarters are shown on the
> **Galactic Information Display with white highlights around the system**. The
> headquarters itself is visible on the Sector window.

That is the rule our HQ highlight implements, stated in the manual: **white
highlight, GID, own side only.**

**Moving the Alliance HQ**: drag the HQ icon onto a new system, or right-click →
**Move** / **Confirmed Move** (Fig. 3.82 — the HQ's menu is just Move, Confirmed
Move, Encyclopedia, Status).

> TIP: **Bring along some of the troops, fighters, and personnel** that were
> helping defend the original HQ location to help defend the new site.

**Detecting that you've been found**, from the Alliance side:

> Pay attention to reports from your agents of enemy **Espionage and Sabotage
> missions on Alliance HQ. If it is the target of repeated missions, the Empire
> has likely discovered its location.**

### ⚠ Contradiction: the scope of the HQ support loss

The manual states this twice, differently:

- **manual p090**: losing your HQ causes "a severe drop in popular support **in
  the sector**."
- **manual p135**: "you take a **tremendous loss of popular support across the
  entire galaxy**."

Recorded as found. p135 is in the summary/strategy section and p090 is in the
rules list; if one has to be picked, **p090's "sector" is the rules statement**
and p135 is likely loose phrasing — but this is a genuine ambiguity in the
source, not a reading error.

### Defending key characters *(PDF p133 / manual p135)*

> Luke Skywalker, Mon Mothma, Darth Vader, and Emperor Palpatine are all likely to
> come under enemy attack, since **your opponent must capture your two key
> characters to fulfill the game's victory conditions**. Make sure they are based
> on systems that are well-defended, and that **when they go out on missions, you
> send decoys to help protect them**.

Which is the strategic justification for the decoy system of §12: decoys exist
mainly to protect the two characters you cannot afford to lose.

---

## 17. ★ Victory conditions

The material that was missing from every earlier reading. *(PDF p133–p135 /
manual p135–p137)*

### Three conditions per side, all required

> When you have met **all** of the victory conditions, you will have won the game.

| | **Alliance must** | **Empire must** |
|---|---|---|
| 1 | **Control Coruscant** | **Destroy Alliance Headquarters** |
| 2 | **Capture Emperor Palpatine** | **Capture Luke Skywalker** |
| 3 | **Capture Darth Vader** | **Capture Mon Mothma** |

### "Capture and hold" — the conditions are simultaneous, not cumulative

This is the crucial detail, and the manual is emphatic:

> **CAPTURING KEY CHARACTERS:** It is **not enough to capture** the key characters
> to meet your victory conditions. **You must capture *and hold*** Mon Mothma and
> Luke Skywalker, or Emperor Palpatine and Darth Vader. **These characters may
> escape with the help of a Rescue mission.** So keep them in a well-defended
> system, **or keep them moving**.

> **CAPTURING CORUSCANT:** … it is not enough to capture Coruscant. **You must
> capture and hold this stronghold until all three conditions are met.**

So victory is a **state that must hold simultaneously**, not a checklist of
events. Every condition can be undone: prisoners can be rescued, Coruscant can be
retaken. A win is the moment all three are true at once.

The one exception, and it is asymmetric:

> When the Alliance headquarters is destroyed, **it is unlike Coruscant: your
> opponent won't be able to take it back.**

**The Empire's condition 1 is irreversible; the Alliance's condition 1 is not.**

### How the Empire is meant to find and kill the Alliance HQ

> You have to **find it first!** Furthermore, the Alliance can move its
> headquarters at will. **Reconnaissance missions to unexplored systems followed
> by persistent Espionage missions may be your best strategy.** Once you locate
> Alliance HQ, your first step will be to **maintain a blockade** on the system.
> To destroy the Alliance HQ, you need to **either destroy the Alliance
> headquarters in a bombardment, and take control of the system with an assault,
> or destroy the system with a Death Star.**

The full chain: **Recon (unexplored) → Espionage (persistent) → blockade (to stop
it relocating) → bombardment + assault, or Death Star.** The blockade step is
what makes blockades matter strategically — it pins the target so it cannot move.

### The Objectives window *(PDF p134–p135 / manual p136–p137)*

Right-click the agent → **Objectives**.

> No matter which side you're playing, this window shows you the current status of
> **all three victory conditions for each side**.

Six rows, both sides always visible. Your opponent's conditions are phrased
**defensively** from your seat — Fig. 3.84, as the Alliance, reads:

| Your conditions | Denying theirs |
|---|---|
| Control Coruscant | Defend Headquarters |
| Capture Palpatine | Defend Luke |
| Capture Vader | Defend Mon Mothma |

And the label updates on state change: "the text changes from **Defend Luke** or
**Capture Vader** to **Luke Captured** or **Vader Captured**."

There is **no hidden information in the victory tracker** — both sides' progress
is always fully visible, which is a deliberate tension-building choice worth
preserving.

### What this means for the pack format

Every condition above is expressible without a faction name in engine code:

```
victory: [
  { type: "control_location",   location: <id> },          # Coruscant
  { type: "capture_character",  character: <id>, hold: true },
  { type: "destroy_hq",         faction: <opponent> }
]
```

with `hold: true` meaning *evaluated continuously*, and the engine declaring a
winner when **every** entry for one faction is simultaneously satisfied. The
Alliance/Empire asymmetry (recoverable vs. irreversible) falls out of
`control_location` being reversible and `destroy_hq` being permanent — no
special-casing needed.

### Strategic summary, in the manual's own words *(PDF p133 / manual p135)*

Listed because it is the designers' statement of the intended playstyles:

- **expand by exploring and colonising the Galactic Rim**, or **win neutral
  systems through diplomacy**;
- **strike early**, or **prepare a methodical build-up**;
- **"roam the core sectors with fleets of terror"**, or **stage persistent small
  strikes** — "possibly **sabotaging your opponent's refineries or construction
  yards to keep your opponent scrambling for maintenance and manufacturing
  capability**."

That last clause is a direct statement that **refineries and construction yards
are the economic centre of gravity** — attacking them is a named strategy, which
only works if maintenance and manufacturing are actually modelled. See
[ECONOMY-NOTES.md](ECONOMY-NOTES.md).

And the self-assessment questions the manual tells the player to ask:

> Who controls the most systems? **Is loyalty for systems you control firmly on
> your side, or will small fluctuations in support cause you to lose systems?**
> When you meet your opponent in battle, do you tend to be evenly matched?

---

## 18. Chapter 1 — the designers' own framing

Read last, and it turns out to be the cleanest statement of several things the
later chapters only imply. *(PDF p010–p014 / manual p010–p014)*

### ★ Victory conditions, verbatim *(PDF p011 / manual p011)*

The canonical statement, in its own boxed panel — this **confirms §17 exactly**:

> **The player controlling the Rebel Alliance must:**
> - **Capture and hold** Imperial headquarters at **Coruscant**.
> - **Capture and hold** the following key characters of the Empire:
>   **Emperor Palpatine**, **Darth Vader**.
>
> **The player controlling the Galactic Empire must:**
> - **Locate and destroy** Alliance headquarters.
> - **Capture and hold** the following key leaders of the Alliance:
>   **Rebel leader Mon Mothma**, **Luke Skywalker**.

Note the Empire's first condition is "**locate** and destroy" — finding it is
formally part of the objective, matching manual p136's "You have to find it
first!"

And the framing sentence, which matters for the support investigation:

> Although **defeating the opposing side in battle and increasing popular support
> throughout the galaxy will aid in winning** the game, there are **specific
> victory conditions** you must fulfill in order to be the winner.

Support and battlefield success are **instrumental, never terminal**. There is no
"control N% of the galaxy" win.

### ★ Galaxy structure *(PDF p011–p012 / manual p011–p012)*

> The setting … is a galaxy made up of **sectors**. **Each sector contains 10
> planetary systems.**

A fixed 10 systems per sector — worth checking our generator against.

**Four control states, not three:**

> Systems can be either **unoccupied**, **neutral**, **controlled by the Galactic
> Empire**, or **controlled by the Rebel Alliance**.

"Unoccupied" and "neutral" are **distinct states**. Neutral = inhabited, has a
populace with loyalties, can be won by diplomacy. Unoccupied = uninhabited, no
support to sway, taken by simply landing a regiment (§13). Our `ControllingFaction
== neutral` conflates them; the distinguishing field already exists as
`IsInhabited`.

**Core vs. Rim, stated as a rule:**

| | **Core** | **Rim** |
|---|---|---|
| Position | centre of the galaxy | the Galactic Rim |
| Explored at start? | yes | **no — "unexplored at the beginning of the game"** |
| Inhabited? | **inhabited** | **"most Rim systems are uninhabited"** |
| Infrastructure | **established infrastructures** | "the few that aren't [uninhabited] usually do not begin with as large an infrastructure" |
| Resources | **"generally have more resources than Rim systems"** | fewer |

This is the rule the `core_infrastructure.json` / `rim_infrastructure.json` split
implements.

### What "control" actually grants *(PDF p012 / manual p012)*

> **Control** allows you to **freely move forces to a system** and to **give
> orders to the facilities on that system**. Each system in the galaxy contains
> valuable resources, **which you can only use if the system is under your
> control**.

Three concrete privileges — movement, facility orders, resource extraction. And
the two routes to it, with the cost of the second stated up front:

> You can control a system by **swaying the loyalty** of a system to your cause.
> If a system is not loyal to your side, you can **use force and place troops** on
> it to take control of it. **However, systems that you take control of with
> troops may go into uprising.**

### The economy in one paragraph *(PDF p012–p013 / manual p012–p013)*

> Systems have **raw materials** you can mine and refine to support your
> manufacturing efforts, **and to maintain your troops and ships**. **Mines** draw
> raw materials from systems. **Refineries** convert the raw material you've mined
> into refined material. **Refined material is used by manufacturing facilities to
> build units.**

> **The combination of mines and refineries gives you maintenance capacity** to
> build and maintain new items. Maintenance capacity is a measure of your ability
> to provide support for all your units (like fuel, food, ammunition, replacement
> parts, etc.). **If you don't have the capacity to maintain all your units, some
> of them will have to be removed.**

Which is §3's model stated as plainly as possible: **mines → raw → refineries →
refined → units**, and **mines + refineries → maintenance capacity**, with a
capacity shortfall causing **removal of units**, not loss of loyalty. See
[ECONOMY-NOTES.md](ECONOMY-NOTES.md).

The three manufacturing facility roles are given here as a clean list:

| Facility | Builds |
|---|---|
| **Construction Yards** | mines, refineries, **system defenses**, and other manufacturing facilities |
| **Training Facilities** | troops **and Special Forces** |
| **Shipyards** | ships |

### Asymmetry, declared *(PDF p013 / manual p013)*

> Although both sides have at their disposal an arsenal of ships, troops, and
> Special Forces, **the specific types and numbers available of these units depend
> on which side you're on.**

And the two flagship asymmetric capabilities, named in the overview: the Empire
"can attempt to **assassinate** your enemies, or — if your resources are
sufficient — **rebuild the mighty Death Star**." Both match the mission table
(§12) and the ship roster (§13).

### Starting roster size *(PDF p013 / manual p013)*

> **You start the game with about seven characters on your side.** … There are
> **60 characters in all: 30 on each side.**

"About seven" reconciles with §11: the Alliance's named opening roster is exactly
seven, and galaxy size adds 1 / 2 / 4 more.

### The six unit categories *(PDF p013–p014 / manual p013–p014)*

The engine's whole unit taxonomy, from the source:

| Category | Definition |
|---|---|
| **Troops** | military personnel. **"Can be either ground-based or assigned to fleets"** |
| **Defensive facilities** | protect systems "by **shielding** them from bombardment or by **firing on** enemy fleets in orbit" |
| **Fighters** | "small, maneuverable ships that can attack other ships" |
| **Capital ships** | "large ships suited for **battle, bombardment, carrying fighters, or transporting troops, or some combination**" |
| **Characters** | personnel for **missions and command assignments** |
| **Special Forces** | built at training yards; "**can each go on limited types of missions**" |
| **Fleets** | "primarily composed of capital ships, fighters, troops, and characters" |

Note the capital-ship definition is explicitly **role-composed** — battle,
bombardment, carrier, transport, "or some combination" — which is the ship-role
tagging §13 argued for, stated by the designers.

### Where the tactical game sits *(PDF p014 / manual p014)*

> There are **two primary modes** to the game: **strategic** and **tactical**. …
> You can enter the tactical game mode when your fleet meets your opponent's fleet
> in orbit above a system. You view both forces within a **3D wireframe
> holocube**. … **In tactical mode, you are the admiral.**

Conflict occurs in exactly two places: **between a fleet and a planet's defense
forces**, or **between two fleets in orbit**.

### ★ Automation, and the honest warning *(PDF p014 / manual p014)*

> You can automate many aspects … if you don't like taking command in battle, you
> can have the game **simulate the results**. Or, if you get tired of handling
> details such as **garrisons and production**, you can turn that responsibility
> over to your **agent droid**, IMP-22 or C-3PO. **Be aware, however, that your
> agent will not necessarily play better than you would, and in fact, may
> manipulate resources differently than you would prefer.**

Three automation surfaces — **battle simulation**, **Manage Garrisons**, **Manage
Production** — and the manual is candid that the agent is a convenience, not an
optimiser. Worth preserving that framing: the agent should be *predictable*, not
*good*. Its documented behaviour (§15) is exactly that — a simple, conservative,
never-removes rule set.

---

## 19. Building facilities — the reference treatment

*(PDF p081–p085 / manual p083–p087)* This is the section §3a was missing, and it
answers most of the open questions in [ECONOMY-NOTES.md](ECONOMY-NOTES.md).

### ★ The energy and raw-material squares, defined *(PDF p082 / manual p084)*

The single clearest statement of the capacity model in the whole manual:

> In order to build on a system, however, **that system must have energy
> available**. Energy is represented in the Sector window as **blue and white
> squares**. **Each facility you build on a system changes a blue square to
> white, giving you less energy to build there.**

> NOTE: If you want to build a **mine** on a system, you also need **raw materials
> available**. They are represented as **red squares**. **Mines are yellow
> squares.**

| Colour | Meaning |
|---|---|
| **blue** | **free** energy slot |
| **white** | **occupied** energy slot (a facility sits in it) |
| **red** | **free** mine slot (unexploited raw material) |
| **yellow** | **built mine** |

Fig. 3.26's callouts make the consequence explicit: "Xyquine is **'full.' It has
no more energy available for new facilities**" while "Commenor … **has room for
two more facilities**."

So energy is **occupancy, checked at build time** — exactly as §3 concluded, and
flatly incompatible with a per-day energy balance that can go negative.

### ★ What actually throttles production *(PDF p082 / manual p084)*

> The Build Selection window gives the estimated days to completion. This is a
> "**best case**" figure — **building slows if you don't have sufficient refined
> materials**, and is **suspended if the system is under blockade or in
> uprising**.

Three throttles, and **none of them is energy**:

| Condition | Effect on production |
|---|---|
| Insufficient **refined materials** | **slows** |
| System **under blockade** | **suspended** |
| System **in uprising** | **suspended** |

This is why every build figure is labelled "**Best** Time To…". And it confirms
the causality [ECONOMY-NOTES.md](ECONOMY-NOTES.md) §4 identified as backwards in
the code: **conditions throttle production; failed production does not cost
loyalty.**

### ★ Completion really is an absolute day *(PDF p084 / manual p086)*

Settling the §13 reading beyond doubt:

> The **Status** entry for this window **tells you the day on which construction
> will be finished**.

Fig. 3.29's Construction Yard Manager shows `Location: Draf` / `Status: 60` —
a bare day number. And Fig. 3.25's callouts pair as
"**Estimated time to completion**" with "**Time to deploy facility (if
destination is different system)**", so deployment is unambiguously **travel
time**, added on.

### ★ Maintenance is charged up front, for the whole order *(PDF p082 / manual p084)*

> NOTE: When you order **multiple units** to be built, **maintenance capacity for
> all units is deducted at the time you give the order.**

And refunded on cancellation, twice stated:

> You can halt construction at any time … **The construction area clears and you
> recoup the maintenance that the units you were building took up.**

> TIP: **Starting a new project cancels the current construction and frees the
> maintenance the project was using.**

So maintenance behaves like a **reservation**: withdrawn at order time for the
full quantity, returned in full if the order is cancelled. This matches the pool
model of §3 exactly.

### ★ Scrapping returns three things *(PDF p084 / manual p086)*

> If you want to get rid of one of your facilities, you can **scrap** it. This
> returns to you the **maintenance** and **some of the refined material** the unit
> used. **Scrapping facilities frees up energy on a system.**

| Returned | How much |
|---|---|
| **Maintenance capacity** | in full |
| **Refined material** | "**some**" — partial refund |
| **Energy slot** | freed (white → blue) |

Stated uses: "scrap a mine so you can build a construction yard", or "**scrap a
training yard to replace it with an advanced training yard**" — which is how the
R&D-gated *Advanced* variants of §3's facility catalogue get adopted. **You can
scrap any facility, troop, or ship** the same way.

And the failure mode, which is the manual's own answer to a maintenance deficit:

> TIP: **If you don't have enough maintenance capacity to support all your capital
> ships, fighter squadrons, troops, and facilities, Star Wars Rebellion will start
> choosing what to scrap for you.**

Confirming §3: a maintenance shortfall **scraps your assets**. It does not brown
out, and it does not cost loyalty.

### ★ The facility status block *(PDF p083 / manual p085, Fig. 3.28)*

Every field, with the manual's own gloss:

| Field | Example | Meaning |
|---|---|---|
| **Location** | Corellia | which system |
| **Status** | Active | "**active, under construction, or en route**" |
| **Maintenance Cost** | 10 | "how many maintenance units facility uses" |
| **Standard Processing Rate** | 0 | "**Number of days to convert one refined material point**" |
| **Bombardment Value** | 3 | "facility's **resistance to orbital bombardment**" |

**Standard Processing Rate is the refinery throughput stat** — days per refined
point — and a construction yard's is 0 because it doesn't refine. This is the
number that should drive the raw→refined conversion, per-facility, rather than a
flat multiplier.

**Bombardment Value 3** for a construction yard matches manual p127's "a
construction yard … has a bombardment defense value of 3."

### The Manufacturing and Production window — six tabs *(PDF p082–p083 / manual p084–p085)*

> **Manufacturing · Shipyards · Training Yards · Construction Yards · Refineries ·
> Mines**

- The **Manufacturing** tab is the default and holds the three *queues*: Ship
  Construction, Troops in Training, Facilities Under Construction — each with its
  own **Destination:** line.
- The other five show the **facilities themselves**, and **"grayed-out tabs
  indicate no facilities of that type are on the system."**
- Right-clicking a built facility gives **Encyclopedia, Status, Scrap**.

Two display details worth copying:

> This progress bar shows how far along the current construction progress is. **If
> there is more than one unit in line to be built, this shows status of current
> unit only.**

> **The first number here is the number of construction yards at this site. The
> second number also includes the construction yard now being built.**

That is the `1:2` notation §3a flagged: **built : built + under construction**.
Worth noting against the code, where `ConstructionYards` defaults to 1 for a yard
that does not exist — see [ECONOMY-NOTES.md](ECONOMY-NOTES.md) §6.

And unit artwork carries state: **completed / under construction / en route** are
three distinct images.

### Destination and reservation *(PDF p082, p084 / manual p084, p086)*

- **Destination** lets a yard build for **any system you control**, not just its
  own — subject to that system having a free energy slot.
- **Reserve** on a construction yard means "if you turn over **Maintenance
  Production** to your agent, **the agent won't use that facility to build mines
  and refineries**."

Note what that tells us about **Manage Production**: the agent's production role
is specifically **building mines and refineries** — i.e. growing the maintenance
pool — which is consistent with mines+refineries being the *source* of maintenance
(§3).

### ★ The remaining GID sub-menus *(PDF p084–p085 / manual p086–p087)*

This completes the GID catalogue begun in §15.

**Resources** (Fig. 3.30) — "larger stars represent available energy, raw
materials, mines, or refineries":

> **Energy Availability · Raw Material Availability · Mines · Refineries**

**Manufacturing** (Fig. 3.31) — "larger stars indicate shipyards, training
facilities, or construction yards on a system", plus idle variants: "You can
further pinpoint only those shipyards, training centers, or construction yards
that are currently **idle**."

> **Shipyards · Idle Shipyards · Training Facilities · Idle Training Centers ·
> Construction Yards · Idle Construction Yards**

Six modes, in **built/idle pairs**. So the complete GID is:

| Sub-menu | Modes |
|---|---|
| **Loyalty** | Popular Support, Uprisings |
| **Fleets** | Idle Fleets, Fleets En Route |
| **Personnel** | Active Personnel, Idle Personnel |
| **Resources** | Energy Availability, Raw Material Availability, Mines, Refineries |
| **Manufacturing** | Shipyards, Idle Shipyards, Training Facilities, Idle Training Centers, Construction Yards, Idle Construction Yards |
| **Defense** | Planetary Batteries, Planetary Shield Generators, Fighter Squadrons, Troopers, Death Star Shields |
| — | **Display Off** |

**21 modes across 6 sub-menus.** Size means *magnitude of the named quantity* in
every one; only Popular Support reads a value that isn't "how much of mine is
here."

### The resource monitors and the sector image *(PDF p085 / manual p087)*

> The **Raw Materials Monitor**, **Refined Materials Monitor**, and **Maintenance
> Monitor** at the top of the screen give you the **current availability** of
> these resources.

Fig. 3.32 shows `104 | 45 | 626` — raw, refined, maintenance. Note the
maintenance figure is an order of magnitude larger, consistent with a
**one-time pool** rather than a daily flow.

Fig. 3.33 labels a single system in the Sector window with exactly four things:
**Manufacturing icon**, **Energy available**, **Raw materials**, **Mines** — the
three bars plus the icon, which is the sector-window feature still outstanding in
[GID-NOTES.md](GID-NOTES.md).

### Build Facilities from the agent *(PDF p085 / manual p087)*

> Click on the system where you want a new facility. The Build Selection window
> comes up. **This is the same window that comes up when you give a construction
> yard a direct order to build.** When you make a selection and click on the
> checkmark, **your agent will track down the closest construction yard to get the
> job done.**

Same "nearest available factory" rule as ships (§13) and troops (§15). The agent
never builds anything itself; it routes an order to a facility.

---

## 20. The Command Center and the GID — reference

*(PDF p061–p071 / manual p063–p073)* Catalogued as "lowest value" before it was
read. That was wrong: it contains the **GID legend**, the **intel reliability
model**, and the **difficulty definitions**.

### ★ Game setup parameters *(PDF p065 / manual p067, Fig. 3.3)*

| Galaxy size | Sectors | Systems |
|---|---|---|
| **Standard** | 10 | **100** |
| **Large** | 15 | **150** |
| **Huge** | 20 | **200** |

> **Your resources at the beginning of the game are proportionally increased if
> you're playing in a larger size galaxy.**

Ten systems per sector at every size, matching Chapter 1.

**★ Difficulty is a starting-position handicap, not smarter AI:**

> In an **Easy** game, **each side begins with four loyal systems**. In a
> **Medium** game, **your opponent starts with more**. In a **Hard** game, **your
> opponent begins with a lot more**.

That is the whole definition. Easy is the default. It also tells us the intended
day-zero baseline: **four loyal systems per side** at Easy — everything else in
the galaxy is neutral or unexplored.

> ★ The exact rule is the original's table, not the round number: SDPRTB.DAT
> entries 30/31 give each side a **percentage of populated core worlds** per
> human side and difficulty (data/side_lottery.json), Coruscant consumes one
> Empire strong slot, and Yavin plus the hidden Alliance HQ are **rim** worlds
> outside the buckets (TheArchitect2018, initial_game_seeding_logic/seed.js).
> On a Standard galaxy at Easy that is **5 Alliance v 4 Empire**. Until
> 2026-09-03 the code also charged Yavin and the HQ to the Alliance's core
> bucket and started it two worlds short (3 v 4); fixed in DayZeroGenerator.

**Headquarters Only Victory** — the third difficulty lever:

> …lets you play until you capture Coruscant or destroy Alliance headquarters.
> This can **shorten gameplay considerably**, since you don't have to
> additionally capture and hold your opponent's key characters.

So victory conditions are **configurable at setup**: full (3 conditions) or
HQ-only (1). Another reason to model victory as a declared list (§17) rather than
hardcoded checks.

### ★ The GID legend *(PDF p066 / manual p068, Fig. 3.5)*

The legend the player opens from a **Show Legend icon**, reproduced in the manual.
Its title is **dynamic** — the figure shows "**Loyalty to the Alliance**".

**Size tiers, largest to smallest, with the game's own names:**

| Tier | |
|---|---|
| **Loyal** | largest |
| **Obedient** | |
| **Disloyal** | |
| **Hostile** | smallest |

Four named tiers, not an arbitrary count — worth matching in `GidTier`.

**Colour swatches in the legend:** **Alliance · Empire · Independent · Neutral**.

And the title callout restates the size rule:

> **Galactic Information Display Title:** This shows the meaning of the size of the
> stars in the display. For example, in the Popular Support display, **larger-sized
> stars indicate stronger support for your side.**

⚠ Note a **naming tension** between two pages: the legend (manual p068) lists
*Independent* and *Neutral* as separate swatches, while the GID colour key
(manual p070) lists **BLUE = Neutral** and **GRAY = Unexplored**. Most likely
*Independent* ↔ blue (populated, self-governing) and *Neutral* ↔ gray (no
information). Recorded as found; the p070 list is the one stated as a rule.

### The canonical colour key *(PDF p068 / manual p070)*

> The color of the star indicates which side controls the system:
> - **RED** — Alliance
> - **GREEN** — Empire
> - **BLUE** — Neutral (Neither side controls.)
> - **GRAY** — Unexplored (**You have no information about this system. It could
>   be neutral, unpopulated, or colonized by the enemy.**)

Note what gray means: not "empty" but "**unknown**" — and explicitly it *could be
enemy-held*. This is the same key as Fig. 2.6 (§2), stated as a rule rather than
a figure caption.

### ★ The intelligence model *(PDF p067 / manual p069)*

The most important thing in this chapter, and it is not in any other chapter.

> The inner sectors — the Galactic Core — have well-developed infrastructures and
> communications. … In the Galactic Rim … infrastructures and communications are
> not highly developed. **Therefore, whereas in the Galactic Core a change in
> popular support on one system is known to you right away, in the Galactic Rim,
> changes in popular support are only apparent if you send a fleet or a mission to
> a system to investigate.**

And the fuller statement of what the Sector window can be trusted about:

> At the start of the game, the Sector window **reliably** gives you information
> about your opponent's and neutral systems' **resources, popular support, and
> production facilities — for core systems only**. However, information on
> **defensive facilities and troops, personnel, and ships is likely to be
> inaccurate and/or incomplete**. Also, even where the information is reliable,
> **you won't know when things on that system change** … **One exception is who
> controls core systems, and the level of popular support on core systems. These
> are always up to date.**

Which gives a three-tier knowledge model:

| Data | Core systems | Rim systems |
|---|---|---|
| **Controller** | **live** | scout to learn |
| **Popular support** | **live** | scout to learn |
| Resources, production facilities | reliable **at game start**, then **stale** | scout to learn |
| Defenses, troops, personnel, ships | **"inaccurate and/or incomplete"** even at start | scout to learn |

So the display is not "what is true", it is "**what you last knew**", with
freshness varying by data type and by region. That is a substantially richer
fog-of-war than a simple explored/unexplored boolean, and it is the mechanism
that makes Espionage missions worth repeating (§12: a successful Espionage
mission makes the windows accurate — "a snapshot [that] can change").

### Seeded starting state *(PDF p067 / manual p069)*

> **Most systems in core sectors begin the game with one or more mines and
> refineries**; some have other production facilities as well. These systems are
> well populated. In the Galactic Rim, systems have small or no populations.

Direct evidence against the current seeding — see
[ECONOMY-NOTES.md](ECONOMY-NOTES.md) §5, where one full generation produced
**one mine** galaxy-wide against 55 refineries. The manual's baseline is
**one or more mines *and* refineries on most core systems**.

And what is fixed versus randomised:

> NOTE: **The game begins differently every time you play, except for who controls
> Coruscant, Yavin, Rebel headquarters and the locations of certain key
> characters.**

| Fixed every game | Randomised |
|---|---|
| Coruscant → Empire | everything else |
| **Yavin → Alliance, 100% loyal**, in the **Sumitra** sector | |
| Rebel HQ **exists on a random Rim system** (the fact, not the place) | its actual location |
| the locations of "certain key characters" | the rest of the roster |

> **Yavin, in the Sumitra sector, always begins the game under your control and
> 100 percent loyal to your side.** … the Empire is likely to strike back at this
> system soon. At the beginning of the game, you should either **remove your key
> characters from Yavin or build up its defense**.

**Yavin starts at 100% Alliance support** — a concrete day-zero value to check the
generator against, alongside Coruscant's 100% Empire.

And the HQ marker, stated a third time:

> This system is indicated on the GID by a **white star around the System icon**.
> **The Empire does not know the location of Alliance headquarters.**

### The Sector window, fully labelled *(PDF p068 / manual p070, Fig. 3.7)*

| Element | Action |
|---|---|
| **Sector name** | title bar |
| **Manufacturing icon** | double-click → Manufacturing and Production window |
| **Defenses icon** (lower left) | double-click → System Defenses window |
| **Mission icon** (lower right) | shows *which side* is running a mission there; double-click → Mission window |
| **Uprising icon** (lower right) | system is in uprising |
| **Fleet icon** (upper right) | **separate Imperial and Alliance fleet icons**; double-click → that side's Fleet window |
| **the star itself** | see below |
| Window controls | Close, and **flip between left and right side of screen** |

**★ And the star in the Sector window tracks the GID mode:**

> **The size of this star corresponds to current Galactic Information Display.
> So, if the display is Construction Yards, this large star means this system has
> a construction yard.**

The GID mode therefore drives **both** views simultaneously — the galaxy map and
the sector window. Worth knowing for the sector-window work in
[GID-NOTES.md](GID-NOTES.md): the marker is not a galaxy-map-only concept.

Note also the mission icon is **side-attributed** ("indicates Empire is undergoing
a mission on that system"), so an enemy mission you have detected is visible on
the map.

### Time does not wait *(PDF p066 / manual p068)*

> **Unlike many other strategic games, the computer does not "wait" for you to
> move before advancing to the next day. The game progresses (and your opponent
> keeps busy) whether you are issuing orders or not.**

Real-time-with-speed-control, not turn-based. This is why every long action is
quoted in **days** and why Pause is a first-class command.

### Window behaviour *(PDF p061–p062 / manual p063–p064)*

- **Sector windows cannot be moved or minimized** — only closed, or flipped to
  the other side of the screen. **At most two Sector windows at a time.**
- **Any number of System windows** may be open.
- **Up to 12 windows can be minimized**, parked in slots on the **Window
  Reference Bar** down the side of the screen.
- **Modal windows** — must be dismissed before anything else: **Status windows,
  Finder windows, the Battle Summary window, the Encyclopedia window, and Message
  windows.** Identifiable by a distinct Close button.

### Keyboard commands *(PDF p062–p064 / manual p064–p066)*

**Command Center:**

| Key | |
|---|---|
| F1 | Game Options |
| F2 | Planetary System Finder |
| F3 | Fleet/Ship Finder |
| F4 | Troop Finder |
| F5 | Personnel Finder |
| F6 | Message Window (Display Message Index) |
| F7 | Encyclopedia |
| PgUp / PgDn | scroll lists |
| Ctrl+Tab | cycle open windows |
| arrows | cycle entries |
| Enter / Esc | accept / cancel — Esc also **skips animations and the agent intro** |
| Alt+W | close all windows |
| Alt+**+** / Alt+**−** | speed up / down (Very Slow · Slow · Medium · Fast) |
| Alt+P | Pause |

**Agent** — note the three build commands each name the routing rule:

| Key | | |
|---|---|---|
| Alt+B | Build Ships | "using the **nearest available shipyard**" |
| Alt+T | Build Troops | "nearest available **training facility**" |
| Alt+F | Build Facilities | "nearest available **construction yard**" |
| Alt+O | Galaxy Overview | |
| Alt+G | **Manage Garrisons** | "fulfill garrison requirements" — **toggle** |
| Alt+U | **Manage Production** | "**build mines and refineries to maximize resources**" — **toggle** |
| Alt+V | Translate Counterpart | toggle |
| Alt+A | Agent Advice | toggle |
| Alt+H | Game Objectives | "both sides' victory conditions" |
| Alt+M / Alt+S / Alt+I | Mission / Status / View Index | |

**Both management options are toggles** — standing modes, not one-shot actions.
And **Manage Production is specifically "build mines and refineries"**, confirming
§19: the agent's production job is growing the maintenance pool.

**★ GID shortcuts** — the nine modes the designers thought worth a hotkey:

| Key | Mode |
|---|---|
| Alt+1 | Popular Support |
| Alt+2 | Uprisings |
| Alt+3 | Idle Fleets |
| Alt+4 | Fleets En Route |
| Alt+5 | Idle Personnel |
| Alt+6 | Active Personnel |
| Alt+7 | Idle Shipyards |
| Alt+8 | Idle Training Facilities |
| Alt+9 | Idle Construction Yards |

Notably **Resources and Defense modes have no shortcuts**, and among Manufacturing
only the **idle** variants do. The nine hotkeyed modes are the ones answering
"what needs my attention right now" — a reasonable priority ordering to copy.

### A second stat calibration point *(PDF p061 / manual p063, Fig. 3.2)*

Leia's opening block, next to Luke's from §11:

| | Leia | Luke |
|---|---|---|
| Force Ranking | None | Trainee |
| **Diplomacy** | **120** | 75 |
| Espionage | 90 | 75 |
| Combat | 50 | **135** |
| Leadership | 70 | 70 |
| R&D | all No | all No |

Confirming the 0–150+ scale and showing how sharply specialised the key
characters are: Leia 120 diplomacy / 50 combat, Luke 135 combat / 75 diplomacy.

### ★★ Every GID mode, defined by the manual *(PDF p069–p070 / manual p071–p072)*

The authoritative list. This supersedes the partial tables in §15 and §19 —
each line is the manual's own sentence for what that mode's star size means.

**Loyalty**

| Mode | Size means |
|---|---|
| **Popular Support** | "how strongly the systems **support your side**" |
| **Uprisings** | "**A large star icon indicates the system is in uprising**" |

**Fleets**

| Mode | Size means |
|---|---|
| **Idle Fleets** | "**how many fleets are stationed on** that system" |
| **Fleets En Route** | "**how many fleets are en route to** that system" |

**Personnel**

| Mode | Size means |
|---|---|
| **Idle Personnel** | "A large star icon indicates personnel on the system who **aren't occupying a command post or engaged in a mission**" |
| **Active Personnel** | "…personnel on the system who **are engaged in a mission or in command of troops, fighters, or fleets**" |

#### ★ "On the system" includes personnel aboard a fleet in orbit *(confirmed)*

Both Personnel modes count a character riding a fleet stationed at that system.
Three independent sources:

1. **Same page, same list:** "IDLE FLEETS: … how many fleets are **stationed on
   that system**" (manual p072). "On the system" is the manual's own
   system-scope wording and it demonstrably covers a fleet in orbit.
2. **The mode's own definition:** Idle Personnel shows "the locations of
   personnel who are **available for assignments**" (manual p100) — and a
   mission is launched "from a system **or fleet** you control" (manual p037).
   A character on a fleet is available by definition.
3. **The shipped string table.** `TEXTSTRA.DLL`, GID tier region
   `0x01ba28`–`0x01bb40`, carries a ships readout parallel to the worlds one:

   | Worlds | Ships |
   |---|---|
   | `Personnel on Worlds` | `Personnel on Ships` |
   | `Personnel are on Worlds` | `Personnel are on Ships` |
   | `No Personnel on Worlds` | `No Personnel on Ships` |

   and the sector-window legend at `0x01c54c`–`0x01c62e` names six system icons,
   two of them personnel: **`Characters in System`** and **`Characters on Fleets
   in System`** (the others: Manufacturing and Production, System Defenses,
   Fleets in System, Units Enroute to System). The original tracks fleet-borne
   personnel per system and ships display text for them.

   ⚠ **Not yet built:** we draw four placeholder corner buttons
   (`frontend/SectorWindow.cs:161`, `E`/`F`/`D`/`M`) against the original's six
   named icons. `Characters in System`, `Characters on Fleets in System` and
   `Units Enroute to System` have no equivalent.

The tier labels are confirmed verbatim from the same region: Idle Personnel is
`Idle` / `None`, Active Personnel is `Active` / `None` (`0x01bc36`–`0x01bc98`).

**The System Defenses window is the exception and excludes them.** The Personnel
Finder's Display button opens "the System Window — **system defenses, fleet or
mission** — in which the character appears" (manual p100). A character on a fleet
appears in the **Fleet** window, so the System Defenses Personnel tab is correct
to list only those on the world itself. Map and window are *supposed* to disagree
here.

**Resources**

| Mode | Size means |
|---|---|
| **Energy Availability** | "how much energy **remains available** to the system" |
| **Raw Material Availability** | "**how many potential mine sites remain available**" |
| **Mines** | "how many mines are **on** the system" |
| **Refineries** | "how many refineries are on the system" |

**Manufacturing**

| Mode | Size means |
|---|---|
| **Shipyards** / **Idle Shipyards** | how many (idle) shipyards are on the system |
| **Training Facilities** / **Idle Training Facilities** | how many (idle) training facilities |
| **Construction Yards** / **Idle Construction Yards** | how many (idle) construction yards |

**Defense**

| Mode | Size means |
|---|---|
| **Planetary Batteries** | how many are on the system |
| **Planetary Shield Generators** | how many |
| **Fighter Squadrons** | how many |
| **Troops** | how many troop regiments |
| **Death Star Shields** | how many |

**Display Off**

> **This turns off the Legend display of the individual systems, showing instead
> the murky mass of galactic matter.** Select any other option on this menu to
> turn the display back on.

Confirms Display Off shows **the plain galaxy**, not an "unknown" state.

Three observations that matter for our implementation:

1. **Two modes are binary, not graduated.** *Uprisings* and both *Personnel*
   modes are phrased as "**a large star icon indicates**" — presence/absence —
   while every other mode is "how many/how much". Tier thresholds should not be
   applied uniformly across all 21 modes.
2. **★ Raw Material Availability is *remaining* mine sites, not total.** "How
   many potential mine sites **remain available**" — i.e. the **red squares**, the
   unbuilt portion, not the gauge's denominator. Likewise **Energy Availability**
   is what **remains** — the blue squares. Both count *free capacity*, not
   capacity.
3. **The GID is subject to fog of war**, stated on the Defense modes:

> NOTE: If you are playing the role of the Alliance, this will only be **as
> accurate as the last information you received** regarding the systems. If the
> information about a Death Star shield **was not found out by either informants
> or through espionage, it will not be reflected on the display.**

So the GID renders **remembered** state, not true state — consistent with the
intel model above. A mode showing nothing on an enemy world means *you don't
know*, not *there is nothing*.

Finally, the interaction details: the GID control opens the menu, **the current
mode is marked with a checkmark**, and the **Legend icon sits in the display's
top left** and is opened by **double-clicking** it.

### The Command Center controls *(PDF p069 / manual p071, Fig. 3.8)*

The full control strip: **Speed Control** (right-click → Very Slow / Slow /
Medium / Fast, plus Pause), **Game Options**, **System Finder**, **Fleet Finder**,
**Troop Finder**, the **GID control**, **Personnel Finder**, **Encyclopedia**.

Pause is modal: "an alert box comes up, **locking you out of game controls until
you resume play**."

### ★ "Independent" is the game's other word for neutral *(PDF p072 / manual p074)*

The System Finder resolves the p068/p070 naming tension. Its tabs are:

> **All Systems · Rebel Systems · Imperial Systems · Independent Systems ·
> Unexplored Systems**

Five categories, matching the four control states of Chapter 1 plus "all". So:

| State | GID colour | Words the manual uses |
|---|---|---|
| Alliance-controlled | **red** | Alliance, Rebel |
| Empire-controlled | **green** | Empire, Imperial |
| Not controlled by either | **blue** | **Neutral** *and* **Independent** — same state |
| No information | **gray** | **Unexplored** |

### The Encyclopedia *(PDF p071–p072 / manual p073–p074)*

Six databases: **System, Ship, Facilities, Mission, Troop, Personnel**, plus an
"All Databases" tab.

> The Encyclopedia gives you a description of the item, and, **if applicable,
> tells you how many resources it takes to build and maintain the item.**

So the Encyclopedia is where the **per-item cost and stat data** lives — the
ship carrying capacities (§13), the facility defensive ratings (§15), the troop
attack/defense numbers (§15). It is the in-game equivalent of our JSON tables.

Two views — **Index** (list, no detail) and **Topic** (picture + full text) — and
the selected database persists between them. Reachable three ways: the
Encyclopedia control, right-click → Encyclopedia on any item, or the **ℹ icon
present in many windows**, which jumps to the entry for the current context.

### The two droids *(PDF p076 / manual p078)*

Two distinct droids per side, with different jobs — a detail easy to conflate:

| Role | Alliance | Empire | Job |
|---|---|---|---|
| **Agent** | **C-3PO** | **IMP-22** | game controls, galaxy info, automation, translates the message droid |
| **Message droid** | **R2-D2** | **SD-7** | announces every event; owns the Display Message Index |

The agent menu's own descriptions:

| Option | Manual's wording |
|---|---|
| Build Ships / Troops / Facilities | routes to "the **closest idle** construction yard that can do the task" |
| **Galaxy Overview** | "see **how many facilities, troops, and fleets you control**" |
| **Game Objectives** | "check on which victory conditions have been met **on both sides**" |
| **Manage Garrisons** | "will try, to the best of their abilities, to make sure **garrison requirements are met**" |
| **Manage Production** | "will try to the best of their abilities to **maximize the output of mines and refineries**" |
| **Translate Counterpart** | on by default |
| **Agent Advice** | on by default; periodic tips **through the message system** |

### Message categories *(PDF p077 / manual p079)*

Nine tabs, and the definitions double as a list of **what the game considers an
event worth reporting**:

| Category | Reports |
|---|---|
| **Loyalty** | a system **changes sides**, **goes into uprising**, or **has a change in garrison requirements** |
| **Fleet** | ships deployed; fleets **arrived at their destination** |
| **Mission** | your agents' mission results — **and news of enemy missions your forces have foiled** |
| **Resource** | available resources change, "for example, a mine or refinery has been deployed" |
| **Manufacturing** | facility status changes — a yard finishes its task, a shipyard is deployed |
| **Defense** | troops or defensive facilities deployed |
| **Conflict** | results of any conflict, **or when a fleet is blockading a planet** |
| **Chat** | head-to-head only |
| **Advice** | agent tips — **the only category not also shown under All Messages** |

> Messages are **eventually deleted whether or not you read them**, except for
> agent advice messages.

Note that a **garrison-requirement change is a first-class notification** — the
game tells you when a world's requirement moves, which is how a player is meant
to catch an impending uprising.

### Save/load and options *(PDF p073–p075 / manual p075–p077)*

**Six save slots**, each with a name field and an icon showing whether the save
was **Empire, Alliance, or head-to-head**. Tactical display toggles (Show
Starfield, Show Planet, Show Pyrotechnics, Use High Detail Models, Display
Holocube) **default to on** and **cannot be changed mid-battle**.

One design note worth remembering:

> Once you begin a game, **there is no way to return to the Shuttle Cockpit** to
> check whether you selected Headquarters Only Victory, or another challenge
> level.

The setup parameters are **not queryable in-game** — which is why the manual
suggests encoding them in the save name.

---

## 21. Chapter 2 gap-fill

The Chapter 2 pages not opened during the first pass. Most is tutorial narration
already covered; the following are the genuinely new facts.

### ★ A mine's maintenance cost is zero *(PDF p035 / manual p036, Fig. 2.27)*

The status block for a mine **en route**:

| | |
|---|---|
| Location | Bainorra |
| **ETA Destination** | **Day 199** — "**ETA shows day on which unit is estimated to arrive**" |
| Status | Enroute |
| **Maintenance Cost** | **0** |
| Standard Processing Rate | 0 |
| **Bombardment Value** | **5** |

Two things settled:

1. **A mine costs 0 maintenance.** This is the direct confirmation of manual
   p030's rule that mines and refineries are exempt from *requiring* maintenance
   — they are what *supplies* it. Compare the construction yard's 10 (§19).
2. **Every deployment figure in the game is an absolute day number.** "ETA
   Destination: Day 199" alongside "the day on which construction will be
   finished" (§19) and "Denotes the day task will be completed" (§13).

A mine's **Bombardment Value is 5**, against a construction yard's 3 — mines are
harder to bomb out than yards.

### Mines and refineries raise both meters *(PDF p035 / manual p036)*

> After you've built some mines and refineries, check back at the **Refined
> Materials Monitor and Maintenance Monitor** and note how your refined material
> **and maintenance capacity** values have **increased**.

> …**how mining and refining your raw materials increases your manufacturing
> capacity throughout your systems.**

Both meters, and the effect is explicitly **galaxy-wide**. Consistent with §3.

### The game does not wait, restated *(PDF p035 / manual p036)*

> NOTE: At this point you may wish to restart the game, particularly if the Empire
> has been pestering you. **Star Wars Rebellion is a real-time game; this means as
> you've been casually perusing the manual, the Empire has been aggressively
> building up its forces, exploring the galaxy, and trying to fulfill its victory
> conditions.**

### Deployment is a separate phase from completion *(PDF p033 / manual p034)*

> If a construction yard on one system builds a facility on a **different**
> system, **there will be a period of time after the facility is completed before
> it is deployed to its destination.** Note that the message from R2-D2 tells you
> the construction yard is **idle** [during that period].

Which is why "idle" and "has nothing queued" are the same thing (§20's GID modes)
— the yard is free the moment the item is *built*, not when it *arrives*.

### Small interface facts *(PDF p021 / manual p022)*

- **The game has tool tips** — hover any control for a description.
- The Command Center screen's own labels: **Number of days since the game began**,
  **Legend**, **Game Speed and Pause Menu**, **Control Panel**, **Message Alert
  bar**, **Game Options**, the **GID**, the **GID state control**, the **agent
  droid**, and the **message droid**.
- After the opening briefing, the Display Message Index **opens on the Agent
  Advice tab**.
- The **Window Reference Bar has twelve slots** for minimized System windows; the
  name of the system sits next to an icon showing **what kind of window** it is.

### ★ The definitive starting roster *(PDF p037 / manual p038)*

Stated more precisely here than in Chapter 3, and it supersedes §11's summary:

> NOTE: **Each side begins the game with seven "core" characters.** For the
> Alliance, these characters are: **Mon Mothma, on the system containing the
> Alliance headquarters, and Luke Skywalker, Leia Organa, Han Solo, Chewbacca,
> Jan Dodonna, and Wedge Antilles on Yavin.** The Empire always begins the game
> with: **Emperor Palpatine on Coruscant, and Darth Vader, Jerjerrod, Ozzel,
> Piett, Veers, and Needa, each located on a randomly selected Imperial-controlled
> system or fleet.** There is also **one additional, randomly chosen character
> available to each side at the start of the game for a small galaxy, two extra for
> a medium galaxy and four extra for a large galaxy.**

| | Alliance | Empire |
|---|---|---|
| Fixed count | **7 core** | **7 core** |
| Leader | Mon Mothma → **at the HQ** | Palpatine → **at Coruscant** |
| The other six | **all at Yavin** | **each on a randomly selected Imperial-controlled system *or fleet*** |
| Extras by galaxy size | **+1 / +2 / +4**, randomly chosen and placed | same |

Two refinements over §11: the Empire's six can start **on a fleet**, not only on
a world; and the extras scale is confirmed at 1/2/4. (Manual p038 labels the
sizes "small / medium / large" where manual p067 calls them "standard / large /
huge" — the same three sizes, loose wording.)

Also stated: **60 characters, evenly split**, "each … has different
characteristics, strengths, and weaknesses."

And SpecForces get the same treatment: "**Each side begins the game with several
Special Forces regiments randomly placed.** Often, Longprobe Y-wing Recon Teams
are available at the game's start."

### Missions are object-specific *(PDF p039, p041 / manual p040, p042)*

> **Missions are object-specific.** That is, missions require you, for example, to
> select a particular **facility** to sabotage or **character** to capture. In this
> case the target is a system, so click on **any area of blank space** in the
> neutral system's window.

The UI convention: **blank space in a system window = the system itself** as a
target. Everything else is targeted by clicking the object.

The **Create Mission** window (Fig. 2.34) has exactly: a **Select Mission tab**
and a **Decoy tab**; the currently selected mission; a **drop-down of available
mission types**; the **target**; and Encyclopedia / assign / cancel. The
**Mission Status** window (Fig. 2.35) mirrors it with **separate tabs for agents
and decoys** and the **moving starfield** hyperspace indicator.

### The standing risk warning *(PDF p043 / manual p044)*

> NOTE: **Any time you send a character on a mission to a system that you don't
> control, you put that character at risk.** Even if the system is **neutral**,
> the mission may be foiled by enemy forces at that system, **or if the Empire
> takes control of that system while the character is there.** Obviously, a
> character sent on a mission to an enemy system … **is at even greater risk of
> being captured or of having the mission foiled.**

Neutral is not safe — a mission target can become hostile underneath the team,
which is the same continuous-precondition rule as §12.

### Converting a neutral world hands you its facilities *(PDF p037 / manual p038)*

Fig. 2.29's callout on a neutral system worth converting: "This system is
desirable because **it already has a construction yard and two shipyards you can
press into service**."

So diplomacy is not just territory — **you inherit the existing infrastructure
intact**, which is what makes winning a developed neutral world so much cheaper
than building from nothing.

### Garrison, defined early *(PDF p043 / manual p044)*

> **A troop occupying a planet is called a garrison, and can defend a planet from
> attack and keep a system on your side, even if the system does not have strong
> popular support for your cause.**

The plain statement of what §15 formalises: troops substitute for consent.

### ★★ Colonisation completes when the first facility lands *(PDF p049 / manual p050)*

The most important thing in Chapter 2's later pages, and it **corrects** the
simpler rule given at manual p120 (§13):

> Note the message that says, **Garrison Requirement: 0.** … In this case, the
> system is unpopulated. **Newly colonized systems don't have garrison
> requirements per se, but in order to maintain control of them you have to keep a
> regiment there UNTIL YOU BUILD AND DEPLOY YOUR FIRST FACILITY to that system, at
> which time the system becomes 100 PERCENT LOYAL and you can remove the
> regiment.**

The colonisation loop in full:

1. Recon or move a fleet to an **unexplored** system.
2. Land a regiment → the system's name **turns your colour**; you may now build.
3. The regiment must **stay** — it is the only thing holding the world.
4. **Build and deploy the first facility there.**
5. The system becomes **100 percent loyal**, permanently. **The regiment is free
   to leave.**

So the troop requirement on an unpopulated world is **temporary, and ends at a
specific, checkable event.** Not "at least one regiment forever." That single
rule is what makes Rim expansion affordable — otherwise every colony would
permanently consume a regiment.

> Most of the systems you explore will be **unpopulated**, but many will be
> populated and **neutral**. … **Don't forget your opponent has this same
> technology** to explore and garrison the outer reaches of the galaxy, **so you
> may be racing to lay claim to these systems.**

### ★★ An uprising stops ALL income from that system *(PDF p057 / manual p058)*

Stronger than §10's "manufacturing halts":

> NOTE: If you don't deal with an uprising, a system could **swing to the other
> side**. In the meantime, you may **lose system resources to smuggling, which
> directly aids the other side**. Also, **an uprising prevents you from getting
> raw/refined materials or maintenance points, or from using the facilities.**

| An uprising blocks | |
|---|---|
| **Raw materials** from that system | |
| **Refined materials** from that system | |
| **Maintenance points** from that system | |
| **Use of the facilities** at all | |
| Plus: **smuggling diverts its resources to the enemy** | |

So an uprising is a **total economic blackout plus a transfer to the opponent** —
not a production pause. Combined with the doubling garrison requirement (§15) and
the ongoing support bleed, it is the harshest state in the game.

### ★ Diplomacy lowers the garrison requirement *(PDF p057 / manual p058)*

> A **successful diplomacy mission will increase popular support, thereby
> lowering the system's garrison requirements**.

Direct confirmation that **garrison requirement is a function of popular
support** — the same causal link §15 stated from the other direction. Fig. 2.59
shows conquered Duros with **Garrison Requirement: 2** and three regiments
stationed.

> Systems acquired by force tend to have **high garrison requirements**.

### Taking a defended world needs preparation *(PDF p057 / manual p058)*

> …particularly well-defended systems will be harder to take over. **You may need
> to send teams out for preliminary missions, especially Espionage or Sabotage
> missions to take out planetary defense systems.**

And:

> …**if an Alliance fleet is nearby, it will intercept your fleet.** At that point
> you'll need to go to tactical mode to engage the fleet.

**Nearby enemy fleets intercept** — an attack can be met before it arrives.

### Day-zero facts from the tutorial *(PDF p053, p055 / manual p054, p056)*

> **Coruscant, as Imperial headquarters and base location of Emperor Palpatine,
> always begins the game with a fleet.**

Another fixed starting condition, alongside Coruscant/Yavin/HQ (§20).

> You begin the game with a **random assortment of ships, fleets, and troops**.

> NOTE: When you're playing the Empire, **reconnaissance is carried out by
> Imperial probe droids rather than Longprobes.**

### The three build prerequisites, together *(PDF p053 / manual p054)*

> If your fleet base is missing one or the other, see if you have enough **energy
> units (blue squares), refined material, and maintenance capacity** to fill the
> gap.

The complete gate on any build, in one sentence: **a free energy slot on the
target system**, **refined material**, and **maintenance capacity**. Three
resources, three different scopes — per-system, stockpile, galaxy-wide pool.

### Command rank must be assigned, restated *(PDF p055 / manual p056)*

> NOTE: **It is not enough to station a character on a ship or system. You must
> assign a command rank for the character to be effective.**

> TIP: Right-click on a character and select **Status** to see which command
> ranks that character **can** hold.

### A third cost calibration point *(PDF p045 / manual p046, Fig. 2.42)*

| Longprobe Y-wing Recon Team | |
|---|---|
| Maintenance cost | **2** |
| Refined material cost | **1** |
| Best Time To Completion | day **8** |
| Best Time To Deployment | **+88 days** |

Cheapest thing seen so far. The cost ladder across the manual's four examples:

| Item | Maintenance | Refined |
|---|---|---|
| Longprobe Y-wing Recon Team | 2 | 1 |
| Alliance Army Regiment | 6 | 3 |
| Construction Yard | 10 | 10 |
| Carrack Light Cruiser | 26 | 24 |
| **Mine** | **0** | — |

Maintenance and refined cost track each other roughly, and **mines are free of
maintenance** because they *supply* it.

### Small facts *(PDF p045–p051 / manual p046–p052)*

- **Each troop icon represents one regiment** — a group, not an individual.
- **All ships are part of a fleet**; a fleet in a sector shows as a **Fleet icon
  on the right of the system**.
- Anything movable — character, fleet, troop, SpecForce — can be **dragged** to
  its destination instead of using Move.
- The **↔ arrows at the top right of a Sector window flip it to the other side of
  the screen**.
- Don't confuse **Longprobe Y-wing Recon Teams** (a SpecForce) with **Y-wing
  fighters** (a ship).
- Galleons "carry two troops each and are **well-defended, but don't have
  offensive capability**" — the manual's own example of a role-specialised hull.
- NOTE: "Because the *Star Wars Rebellion* galaxy is different every time you
  play, **it is possible you don't have any training yards available**" at the
  start.

### Interface conventions *(PDF p060 / manual p062)*

The whole interaction grammar, in four rules:

| Input | Result |
|---|---|
| **single-click** | select |
| **double-click** | open the window associated with the item |
| **right-click** | that item's menu — "**most elements … from facilities to characters — have menus you access this way**" |
| **drag-and-drop** | move an item to a new destination |

Plus **tool tips on most screen elements**.

---

## Coverage

Pages read as images so far. This document only claims what these pages say.

| PDF pages | manual | section | status |
|---|---|---|---|
| p003, p005–p007 | — | cover blurb, table of contents | read |
| p019–p020 | 020–021 | Ch2 opener, Mini-Mission 1 start | read |
| p022–p032 | 023–033 | GID, sector window, detail windows, MM2 economy, build, speed | read |
| p034 | 035 | construction yards, deployment distance | read |
| p036 | 037 | Mini-Mission 3, mission lifecycle | read |
| p038 | 039 | character locations, Personnel Finder, intel gating | read |
| p040 | 041 | character stat block, diplomacy effect | read |
| p042 | 043 | support drives control, auto-continue missions | read |
| p044 | 045 | base systems, travel time, HQ on random rim | read |
| p046 | 047 | mission eligibility, maintenance vs refined-material costs | read |
| p048 | 049 | fleet structure, transports, unpopulated worlds, recon reveal | read |
| p050, p052 | 051, 053 | fleet composition, four tabs, capacity, taking unpopulated worlds | read |
| p054 | 055 | **command ranks**, garrison scaling, fighter hyperdrive | read |
| p056 | 057 | **planetary assault, shields lockout, bombardment** | read |
| p058 | 059 | **blockades**, Ch2 summary | read |
| p078–p080 | 080–082 | Key Concepts opener, economy numbers, facility catalogue | read |
| p086–p087 | 088–089 | **support & control defined, smuggling, contagion, colonisation** | read |
| p088–p091 | 090–093 | **garrisons, uprisings, the Force, starting rosters** | read |
| p092–p095 | 094–097 | **traitors, set-pieces, advancement, command ranks, capture, SpecForces** | read |
| p096–p099 | 098–101 | **SpecForce roster, finders, the stat block and its scale** | read |
| p100–p107 | 102–109 | **missions: teams, decoys, detectors, the 15-mission table, R&D, tracking** | read |
| p108–p111 | 110–113 | **three outcomes, persistent missions, bases, fleet structure, building ships** | read |
| p112–p115 | 114–117 | **build window semantics, production menu, ship status and damage** | read |
| p116–p119 | 118–121 | **the ship roster, rearranging fleets, fleet exploration, fleet menu** | read |
| p120–p123 | 122–125 | **bombardment resolution, assault, blockades, the Death Star, fleet finders** | read |
| p124–p127 | 126–129 | **defense layers, garrison rules, Manage Garrisons, building troops** | read |
| p128–p131 | 130–133 | **trooper stats, shields, batteries, the ion cannon, GID Defense menu** | read |
| p132–p135 | 134–137 | **★ headquarters, and the complete victory conditions** — end of Ch3 | read |
| p008–p014 | 008–014 | **★ Ch1 overview — victory conditions, galaxy structure, the economy in one paragraph, unit taxonomy** | read |
| p015–p018 | 015–019 | installation, system requirements, troubleshooting — **no gameplay rules** | read |
| p061–p072 | 063–074 | **★ Ch3 UI — the GID legend, the intel model, difficulty, all 21 GID modes, the Encyclopedia** | read |
| p073–p077 | 075–079 | game options, save slots, the two droids, message categories | read |
| p081–p085 | 083–087 | **★ building detail — the blue/white/red/yellow squares, what throttles production, scrapping, facility status block** | read |
| p021, p033, p035, p037, p039, p041, p043 | 022–044 | Ch2 continuation — the definitive starting roster, mine maintenance = 0, mission targeting | read |
| p045, p047, p049, p051, p053, p055, p057, p060 | 046–062 | **★ Ch2 continuation — colonisation completes at first facility, uprisings block all income, diplomacy lowers garrison requirement** | read |
| p001–p007, p019, p059 | — | cover, credits, flavour crawls, contents, chapter openers — **no rules** | read |

**Every rendered page (PDF p001–p135) has been read.** Nothing above needs
re-reading.

| p136–p167 | 138–169 | Ch4 Tactical, Ch5 Multiplayer | **not rendered** — `manual/pages/` stops at p135 |

**Chapters 4 and 5 were never rasterised**, per the original scope ("we will read
as images through PDF p135, skip tactical and multiplayer for now"). The PDF has
them. To pick them up later, re-run the PyMuPDF render at 150 dpi over pages
136–167 and continue the same pattern. What is known about tactical from the
strategic chapters is collected in §§1, 11, 13 and 14 — the holocube, the admiral
role, command-rank effects, the Death Star run, and Simulate Results.

---

## Chapter 5 — Head-to-Head Games *(manual p156–p167 / PDF p152–p163; the offset is +4 in this chapter)*

Read 2026-09-03 for the multiplayer plan (schmitz-wars `docs/multiplayer-plan.md`).
Figures 5.1–5.11. Quotes are the manual's words.

**Scope.** "Star Wars Rebellion allows **two players** to compete head-to-head over
a Local Area Network (LAN), via modem, direct serial connection (using a null
modem cable), or over the Internet." DirectPlay (DirectX 5.0) underneath.

**Entry.** "In the Shuttle Cockpit, click on the small panel at the lower left
that depicts a Rebel soldier and an Imperial stormtrooper facing off (Fig. 5.1).
This will take you to the Multiplayer Configuration screen (Fig. 5.2)."

**Multiplayer Configuration screen (Fig 5.2).** A list of service providers —
IPX, TCP/IP, Modem, Direct Serial "for DirectPlay" — "the provider that is
currently selected appears in red"; then "**Setup Game** to host a game, or
**Connect to Game** to join an existing game. The currently selected option will
be depressed and the text will appear dark." Right arrow proceeds, left arrow
goes back, **X** cancels to the Shuttle Cockpit.

**Host Game screen (Fig 5.3).** "In the **Player Name** box, type a name or
nickname for yourself. If you do not specify a name, it will default to your
Windows 95 user's name." "In the **Game Name** box, type in what you would like
to name your game. If you do not specify a name, it will default to your
computer's name." Right arrow → Multiplayer Options.

**Joining (Figs 5.6–5.8).** TCP/IP: "Enter the computer name or IP address of
the session host, or leave blank to search." "NOTE: If you are playing on a
TCP/IP LAN, leave the box blank and click OK. DirectPlay will search for TCP/IP
configured hosts over your local network." **Join Game screen**: Player Name;
"Select the game you wish to join. Unless you are playing on a LAN where others
may be playing, there will only be one game name listed." Right arrow →
Multiplayer Options.

**Multiplayer Options screen (Fig 5.9) — host only.** "1 Choose which side you
want to play... Click the red symbol for the Rebel Alliance or the green symbol
for the Galactic Empire. 2 Choose a galaxy size. The choices are standard, large,
and huge" (100 / 150 / 200 systems). "3 Choose **Standard Game** or **HQ Only
Victory**." Standard: "Rebel Win Conditions: Capture Coruscant and capture
Emperor Palpatine and Darth Vader. Imperial Win Conditions: Destroy the Rebel
headquarters and capture President Mon Mothma and Luke Skywalker." HQ only:
"Capture Coruscant" / "Destroy the Rebel headquarters." "4 Use the Compose Chat
Message window (Fig. 5.11) to exchange messages back and forth with your opponent.
To chat, click your mouse in the space to the right of **Chat>**, then type your
message. Press **Enter** to send it." "5 When finished, click on the checkmark
button at the bottom of the screen to start the game." Also a **Load Game**
button: "will only be available if you have saved a game from a previous session
with your current opponent. If you are loading a saved game, it will use the
game size and difficulty settings from your previous game."

> ★ No difficulty choice on this screen. Head-to-head uses the **Multiplayer**
> column of the rule tables (`Difficulty.Multiplayer`, `side_lottery.json` "mp").

**Multiplayer Game Features (p162–p163).**
- **Messages (Chat)**: "the ability to send messages or taunts to your opponent
  while in the Galactic Information Display. These chat messages are processed
  through SD-7 or R2-D2's messaging system." "Click the **Chat Messages** tab to
  display any incoming chat messages. Double-click a message to view it. Click
  the button on the bottom right-hand side of the window to send a message" →
  **Compose Chat Message** window (Fig 5.11): type, **Send message**, **Cancel**,
  close, return to Display Message Index.
- **Game Speed**: "can be adjusted by either player during head-to-head play.
  However, the game plays at the **slowest speed set on either computer**. The
  available speeds are: Pause, Very Slow, Slow, Medium, and Fast."
- **Pausing**: "bring up the Game Options Screen. Your opponent will receive a
  **Waiting for Opponent** message, until you return to the game. Alternately,
  you can choose to pause on the Game Speed menu until you are ready to play.
  Then just click on the checkbox to resume play."
- **Saving**: "follow the same procedure as you would to save a single player
  game... In multiplayer games, **only the host player can save** the game. Star
  Wars Rebellion will create a saved game on **both computers in the same saved
  game slots**."

**p164–p167** are the Internet Gaming Zone, WINIPCFG and PING instructions for
Windows 95 — historical, no game rules.
