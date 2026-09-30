# Plan: desktop releases for Windows, macOS and Linux

Status: **charter, waiting for TeeJ's sign-off (2026-09-23).** Nothing is built yet.
Stop after every phase with a go/no-go read-out.

## Charter

| | |
|---|---|
| **The one thing** | A player downloads Faction Wars for Windows, macOS or Linux, opens it with a double-click, and plays: single player, and multiplayer against web players through the production relay. Owners of the original get its look through the same art-set import as the web. |
| **Wrong if shipped without** | The OS trusts it: the Windows exe carries an Azure Trusted Signing signature, and the macOS app is signed with Developer ID, notarized and stapled, so it opens with no SmartScreen or Gatekeeper override. Multiplayer from a desktop build works, which has never been tested (see "Known risks"). A desktop player and a web player on different builds cannot silently desync: prod web and desktop release together, but a download that was never updated falls behind, so a mismatch is refused with a message naming both versions. The in-game exporter link still works after a game release is published. The game has a version number, shown in the game and on the release. |
| **Off-limits** | **Any exporter that isn't the Windows one: no port, and no extraction inside the game.** The original only runs on Windows, so Mac and Linux players run the exporter on the Windows PC where Rebellion is installed and import the file it writes (TeeJ, 2026-09-23). Original art in any build or release asset. Embedding the `.pck` in the Windows exe. Shipping Windows or macOS unsigned "for now". Telling players to get past SmartScreen or Gatekeeper. An installer, self-extractor or elevation prompt. The game starting other programs. Claude connecting to TeeJ's Mac or Linux machines: TeeJ runs those steps from a script. |
| **Deploy target** | A GitHub Release on TeeJS/faction-wars, tag `v<version>`, with one asset per platform plus `SHA256SUMS.txt`. Built locally into `build\desktop\<version>\` (already gitignored). |
| **Backup** | Git covers the code and export presets. Signing material stays where it is and is never committed: `.signing\` (gitignored) on Windows, the keychain on the Mac. Nothing outside the repo is changed. |
| **Done when** | See "Verification" at the end. |

## What each platform gets

| | Arch | Asset | Built and signed on | Signed with |
|---|---|---|---|---|
| Windows | x86_64 | `FactionWars-<v>-windows.zip`: the exe and `FactionWars.pck` side by side | this PC | Azure Trusted Signing: signtool and the dlib, the same `.signing\` pair `tools\FactionWarsExporter\build.ps1` uses |
| macOS | Universal 2 (Intel and Apple Silicon) | `FactionWars-<v>-macos.zip`: the notarized, stapled `.app` | **the Mac** (TeeJ runs one script) | Developer ID Application, hardened runtime, `notarytool`, `stapler` |
| Linux | x86_64 | `FactionWars-<v>-linux.tar.gz`: the binary and the `.pck` | this PC | none (no standard exists); covered by `SHA256SUMS.txt` |

Defaults I took (all reversible, say if you want any changed):

- **No embedded `.pck` on Windows.** Signing breaks it: Godot finds the embedded pack at the end of the file, and the signature lands after it ([godot#32310](https://github.com/godotengine/godot/issues/32310)).
- **The macOS app is exported on the Mac, not here.** A `.app` exported from Windows loses its executable flag, and signing it from Windows needs a separate tool, rcodesign ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)). This means Godot 4.7.1 (non-Mono) and its templates get installed on the Mac.
- **The macOS asset is a zip, not a dmg.** That is one fewer thing to sign and notarize.
- **x86_64 only on Windows and Linux.** Windows on Arm runs x64 through emulation. arm64 builds can come later.
- **Exports use the non-Mono 4.7.1 editor** (`D:\Downloads\godot-4.7.1-web\`), as the web export does. The Mono build is for tests only.
- **CI is out of scope for this plan.** The first release is made by hand on the three machines. A GitHub Actions matrix is a follow-up once that release works.

## Separate release streams (the exporter link)

**The code:** the game links players to
`releases/latest/download/FactionWarsExporter.exe` (`src/ui/pack_picker.gd:31`).
GitHub treats the newest published release that is not a draft or pre-release as
"latest" ([REST docs](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)),
so the first game release would take over "latest", and that link would return 404.

**The fix:** the game and the exporter release separately, and the exporter gets a
fixed link that doesn't depend on "latest".

| | Tag | Latest? | Holds |
|---|---|---|---|
| Game release | `vX.Y.Z` | yes | the three platform assets and `SHA256SUMS.txt` |
| Exporter release | `exporter-vX.Y.Z` (as now) | no: `--latest=false` | that version's signed exe (history) |
| Exporter link target | `exporter` (one permanent release) | no | the newest signed exe, replaced with `gh release upload exporter FactionWarsExporter.exe --clobber` |

- The game links to `releases/download/exporter/FactionWarsExporter.exe`. That's a one-line change in Phase 1.
- `tools/FactionWarsExporter/build.ps1` and its README describe the new two-step exporter release.
- Stakes are low: four people know the game exists, and there are no desktop builds out yet.

## Known risks

| Risk | Why it is a risk | Where it gets settled |
|---|---|---|
| Secure websocket (wss) to the relay from a desktop build | HANDOFF: Godot's TLS module did not start headless on this PC, so wss was only checked with curl and the browser. No desktop build has ever joined `wss://wars.schmitzplex.com/ws` (`src/net/mp_setup.gd:13`) | Phase 2 |
| Mixed-build games | A player who never updates their download ends up behind prod web. Spot-checked only, not read in full: I found no build check in the relay join or the game's `hello`. That has to be read in full before it is claimed | Phase 3 |
| macOS notarization | Where first attempts usually fail: hardened runtime and entitlements (the debugging entitlement has to be off) | Phase 4 |
| macOS input and scaling | Ctrl vs Cmd shortcuts; Retina scaling of window chrome matched to the original's pixels | Phase 2 |

## Phases

### Phase 1: presets, version, unsigned builds

- Add Windows, macOS and Linux presets to `export_presets.cfg`, with the `.pck` not embedded and the macOS preset Universal.
- Give the game a version number (`application/config/version`) and show it in the game.
- Point the game's exporter link at the fixed `exporter` release, and create that release holding exporter 2.2.0. Creating it is outward-facing, so it waits for TeeJ's yes.
- Export unsigned Windows and Linux builds into `build\desktop\<v>\`, and write the Mac export script.
- **Gate:** the Windows build boots to the menu here. TeeJ boots the Linux build, and the Mac build from the script.

### Phase 2: test pass on each platform

- TeeJ, on each platform:
  - start a single-player game
  - import an art set through the native file dialog
  - save, quit, reopen and load
  - play a multiplayer game against a browser through the production relay
- On the Mac, also: shortcuts and Retina scaling.
- **Gate:** every row passes, or each failure is written down with its cause.

### Phase 3: refuse mixed builds

- Read the relay's join path and the game's `hello` in full.
- If neither checks the build, the game sends its version, and a mismatch is refused with a message naming both versions.
- **Gate:** `tools/lockstep-local.ps1` and `tools/mp-flow-local.ps1` still pass, and a forced mismatch is refused with the message.

### Phase 4: signing

- A Windows script signs the exe.
- A Mac script signs with Developer ID and the hardened runtime, submits with `notarytool submit --wait`, then staples.
- **Gate:**
  - Windows: `Get-AuthenticodeSignature` reports `Valid`.
  - Mac: `spctl -a -vv` reports `accepted, source=Notarized Developer ID`, and `stapler validate` passes.
  - Each opens with a double-click on a machine that has never seen it.

### Phase 5: the release

- Tag `v<version>`, then publish the three assets and `SHA256SUMS.txt`.
- **Gate:** each download link resolves, `releases/download/exporter/FactionWarsExporter.exe` still resolves, and the checksums match.

## Verification

1. Windows: download the zip from the release onto a machine that has never run it, extract and double-click. No SmartScreen block, and Defender is quiet.
2. macOS: the same from the zip. It opens with no Gatekeeper prompt beyond the standard "downloaded from the internet" confirmation.
3. Linux: extract, run, and it reaches the menu.
4. On each platform: an art set made by the exporter on the Windows PC imports and shows the original look.
5. On each platform: a multiplayer game against a browser player on the same version runs through `wss://wars.schmitzplex.com/ws`.
6. A desktop build on an older version trying to join a web game is refused with a message naming both versions.
7. The exporter link in the game still downloads `FactionWarsExporter.exe`.

## Not in this plan

- **The prod web system.** Today's web build, which updates on every push, is the dev system. A prod web system will ship on the same cadence as desktop, and needs its own plan. Until it exists, desktop builds use the one relay there is (`wss://wars.schmitzplex.com/ws`). When it does, they point at its relay.
- **The GUI pack editor.** It ships from its own repo with its own releases, so it never competes for "latest" here.

## Open for TeeJ

- **The first version number.** The default is `0.9.0`, because the web game is still a beta. It is a label only and changes nothing else.
