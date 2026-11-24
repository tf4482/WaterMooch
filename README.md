# WaterMooch

Out of combat, WaterMooch lists the mages around you in a small window; one click targets
the mage, marks them with a blue square, and whispers them your own text.

## Features

- **Mage list** - friendly mages nearby (nameplates, group, target, mouseover) appear in a
  movable window, only out of combat; mages unseen for 60 seconds drop off the list.
- **One-click request** - clicking a name targets the mage, sets the blue square marker,
  and sends your whisper.
- **Own whisper text** - the whisper is freely configurable by chat command.
- **Remembered** - settings are saved per account, or per character with one checkbox;
  default is off.
- **Settings page** - the on/off switch in the game menu under Options > AddOns, also
  opened from the addon compartment menu.
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
/wm on                  start listing nearby mages
/wm off                 stop listing nearby mages
/wm message "<text>"    set the whisper text
/wm show                show the window again after closing it
/wm character on        use settings for this character only
/wm character off       use the account settings again
/wm config              open the settings page
/wm help                list all commands
```

## Examples

- Turn it on once: `/wm on`. In a city, mages near you show up in the window; click one.
- Change the request: `/wm message "Hey, could you open a portal to Stormwind? Tip ready!"`
- Closed the window by mistake: `/wm show`.
- A fight starts: the window hides and comes back with a fresh list after combat.

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
