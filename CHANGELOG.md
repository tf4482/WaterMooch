# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `/wmooch reset` restores the default settings of the active profile.
- `/wmooch debug on|off` shows what the addon does in chat, until `/reload`.
- German texts for the shared chat messages (help, errors, on/off).

### Changed

- Short slash command is now `/wmooch`; `/wm` belongs to the game's world markers.
- The scan key binding has its own section WaterMooch in Options > Keybindings.

### Fixed

- Nameplate settings switched by a scan are restored on the next login after a
  disconnect or crash, and after a logout in combat.

## [0.1.0] - 2026-11-24

### Added

- Window listing nearby friendly mages on `/wm scan` or a key binding
- Scan key binding on the settings page
- Scan switches friendly nameplates on briefly and restores them afterwards
- Sliders for the nameplate time and the minimum mage level
- Nameplate time from 0.01 seconds, with a number field next to the slider
- German localization for German clients, English for all others
- Level and <guild> after each name in the list
- Alt+left click on a name targets the mage and opens a trade
- Left click on a name targets the mage and sets the blue square marker
- Right click on a name whispers the mage, Alt+right click sends a second text
- Configurable whisper texts on the settings page and by `/wm message`, `/wm altmessage`
- Several sentences per whisper, one picked at random (`--add` in chat)
