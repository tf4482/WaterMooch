# WaterMooch

On a slash command or key press, WaterMooch lists the mages around you in a small window;
a left click targets the mage and marks them with a blue square, a right click whispers
them your own text, Alt+right click a second one.

## Features

- **Scan on demand** - `/wm scan` or your own key binding lists the friendly mages nearby
  (nameplates, group, target, mouseover, and mages seen in the last minute) in a movable
  window.
- **Key binding** - set the scan key on the addon's settings page or under Options >
  Keybindings > AddOns.
- **Target and mark** - left-click a name to target the mage and set the blue square marker.
- **Whisper** - right-click the name to send your whisper, Alt+right-click to send the
  second one; a left click never whispers.
- **Own whisper texts** - type both whispers on the settings page Options > AddOns >
  WaterMooch, or set them by chat command.
- **Random sentences** - give each whisper several sentences, one per line; a random one
  is sent each time.
- **Remembered** - settings are saved per account, or per character with one checkbox.
- **Settings page** - the per-character switch, the scan key, and the whisper texts in the
  game menu under Options > AddOns, also opened from the addon compartment menu.
- **Chat commands** - every option can also be changed by slash command.

Turn on friendly player nameplates (default key `Shift+V`) so mages nearby are found
without hovering or targeting them.

## Install

1. Download `WaterMooch-vX.Y.Z.zip` from the releases (or CurseForge, Wago).
2. Unzip it into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Restart the game or type `/reload`.

## Usage

```text
/wm                      show the current state
/wm scan                 list the mages nearby
/wm message "<text>"     set the right click whisper (add --add for one more sentence)
/wm altmessage "<text>"  set the Alt+right click whisper (also with --add)
/wm character on         use settings for this character only
/wm character off        use the account settings again
/wm config               open the settings page
/wm help                 list all commands
```

## Examples

- In a city, type `/wm scan`; mages near you show up in the window; left-click one, then right-click to ask.
- Bind a key under Options > Keybindings > AddOns > "WaterMooch: Scan for mages" and press
  it whenever you need water.
- Ask for food with Alt+right click: `/wm altmessage "Some mage food, please?"`
- One more random choice: `/wm message "Got any water to spare?" --add`
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
