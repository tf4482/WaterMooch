# WaterMooch

On a slash command or key press, WaterMooch lists the mages around you in a small window;
one click targets the mage, marks them with a blue square, and whispers them your own text.

## Features

- **Scan on demand** - `/wm scan` or your own key binding (Options > Keybindings > AddOns)
  lists the friendly mages nearby (nameplates, group, target, mouseover) in a movable window.
- **One-click request** - clicking a name targets the mage, sets the blue square marker,
  and sends your whisper.
- **Own whisper text** - type the whisper on the page Options > AddOns > WaterMooch >
  Whisper, or set it by chat command.
- **Remembered** - settings are saved per account, or per character with one checkbox.
- **Settings page** - the per-character switch and the whisper text in the game menu
  under Options > AddOns, also opened from the addon compartment menu.
- **Chat commands** - every option can also be changed by slash command.

Turn on friendly player nameplates (default key `Shift+V`) so mages nearby are found
without hovering or targeting them.

## Install

1. Download `WaterMooch-vX.Y.Z.zip` from the releases (or CurseForge, Wago).
2. Unzip it into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Restart the game or type `/reload`.

## Usage

```text
/wm                     show the current state
/wm scan                list the mages nearby
/wm message "<text>"    set the whisper text
/wm character on        use settings for this character only
/wm character off       use the account settings again
/wm config              open the settings page
/wm help                list all commands
```

## Examples

- In a city, type `/wm scan`; mages near you show up in the window; click one.
- Bind a key under Options > Keybindings > AddOns > "WaterMooch: Scan for mages" and press
  it whenever you need water.
- Change the request: `/wm message "Hey, could you open a portal to Stormwind? Tip ready!"`
- Put `/wm scan` in a macro to scan from an action bar button.

## Develop

Check the code with [Luacheck](https://github.com/lunarmodules/luacheck) before each commit
(CI runs it on every push):

```text
luacheck .
```

Release: set the new version in `VERSION`, then push the annotated tag `v` plus that
version (e.g. `v0.1.0`, optionally `-beta`); GitHub Actions checks the tag against
`VERSION`, packages the addon with the BigWigs packager, and publishes it.

## License

All rights reserved, see [LICENSE](LICENSE).
