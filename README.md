# BG OmniHeal 5.0.1

BG OmniHeal is a World of Warcraft addon for battleground healers. The ally frames support click casting and show healing auras, dispellable debuffs, and crowd control. Enemy frames help you follow the opposing team.

I maintain this edition as **Faridfs**. I built on Lavet’s BG OmniHeal 4.6, with a focus on keeping healing clicks tied to the right teammate when raid slots change and making the frames easier to set up. [Lavet’s original addon on CurseForge](https://www.curseforge.com/wow/addons/battlegroundomniheal)

## What I’ve been working on

- Added a three-step setup guide so players can choose teams, preview a layout, and drag frames into position before saving.
- Separated layouts for 8-player Blitz, 10-player rated battlegrounds, and random battlegrounds with up to 15 players per team. The addon stays inactive in epic battlegrounds.
- Updated raid-slot mapping and cross-realm name matching, and fixed how the addon hands raid frames back to Blizzard and other addons after a match.

I checked these changes in a simulated WoW client, including raid-slot swaps, transitions into epic battlegrounds, and upgrades from older profiles. Live-match testing is still pending.

[Руководство на русском](README.ru.md)

## Install or update

1. Download **BG_OmniHeal-5.0.1.zip** from the [5.0.1 release](https://github.com/Faridfs/BG_OmniHeal/releases/tag/v5.0.1). Extract it and copy the inner `BG_OmniHeal` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. Check that `BG_OmniHeal.toc` sits directly inside `AddOns\BG_OmniHeal`. When updating, use the same folder name so WoW finds your existing profiles.
3. Reload the interface with `/reload`, or start WoW and enable **BG OmniHeal** in the AddOns list.

## Set up your frames

**Frame setup** opens on a fresh installation when you enter the world outside combat and battlegrounds. If you are upgrading, type `/oh setup` or select **Open frame setup** under **General** to run it for your current profile.

1. Choose ally frames, enemy frames, or both.
2. Choose the mode you want to configure. **Blitz** has 8 players per team, **Rated BG** has 10, and **Random BG** has up to 15. The random layout also applies on 10-player random maps. Its preview shows a full team of 15.
3. Click **Preview frames**. Turn off **Lock frames** and drag the panels by their headers. When they are in place, choose your preferred lock setting and click **Finish**.

**Finish** saves your choices to the current profile. **Set up later** or Escape discards changes from this session. You can reopen the guide with `/oh setup`. Each mode remembers its own frame positions. OmniHeal stays inactive in epic battlegrounds.

Assign healing spells in WoW’s **Click Casting** settings or a compatible click-casting addon. By default, left click targets a unit and right click sets focus.

## Where to find a setting

| Section | Use it for |
| --- | --- |
| **Setup** | Frame visibility and locking, the minimap button, preview options, profiles, and addon information. |
| **Frames** | Ally and enemy layout, sizing, sorting, health, range fading, and status indicators. |
| **Combat tracking** | Healing auras, dispels, crowd control, targeting indicators, flags, orbs, and premade groups. |
| **Appearance** | Fonts, countdown text, animations, and which elements draw in front. |

Use the search field to find a setting by its name or description. To keep separate layouts for different characters or roles, open **Profiles** and create a copy before making changes.

## Chat commands

| Command | Action |
| --- | --- |
| `/oh` or `/omniheal` | Open or close settings. |
| `/oh setup` | Open the guided frame setup for the active profile. |
| `/oh preview` or `/oh test` | Start or end the frame preview outside a battleground. |
| `/oh ally`, `/oh enemy`, `/oh auras`, `/oh profiles` | Open that settings page directly. |
| `/oh lock` or `/oh unlock` | Lock or unlock the frame positions. |
| `/oh reset` | Clear saved frame positions for all brackets in the active profile. |
| `/oh perf` | Print the live update rates and the number of watched units. |
| `/oh env` or `/oh probe` | Print client information or inspect which unit data is available in a match. |
| `/oh help` | List the main commands in chat. |

## Code layout

The root manifest, `BG_OmniHeal.toc`, lists the files in the order WoW loads them. The addon shares its private Lua namespace across those files.

| Folder | Where to start |
| --- | --- |
| `Core/` | `Addon.lua` manages events and combat deferral. `Defaults.lua` defines the shipped settings. `SavedVariables.lua` upgrades saved data, and `Profiles.lua` handles profile management and sharing. |
| `Battleground/` | `Roster.lua` maps players and raid slots. `Live.lua` updates health, range, and targets. The other modules track carriers and premade groups. |
| `Frames/` | `Panels.lua` lays out and binds clickable rows. `Row.lua` draws player information. Aura icons, effects, and the handling of other raid-frame addons each have a separate file. |
| `Auras/` | `SpellLists.lua` contains spell IDs grouped by purpose and class. `Tracker.lua` binds auras to units and frames. `AnimationSettings.lua` applies their visual settings. |
| `Settings/` | `Pages.lua` defines the sidebar. `Window.lua` handles controls, navigation, and search. `GuidedSetup.lua` manages the setup steps and preview choices. `SetupWindow.lua` draws the guide. |
| `Locales/` | `Loader.lua` selects the language and handles fallback. The language files contain the player-facing strings. Both Spanish locales use `esES.lua`. |
| `Tools/` and `Media/` | `Tools/` contains the preview and diagnostic commands. `Media/` holds the bundled textures. |
