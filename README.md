# Smart Camp Picker

[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-Smart%20Camp%20Picker-orange)](https://www.nexusmods.com/monsterhunterwilds/mods/4036)

Automatically picks the closest camp when accepting a quest, using navmesh distances that account for terrain, elevation, and actual travel paths.

## Features

- Selects the nearest camp based on actual in-game travel distance
- Navmesh distance data for all 5 field stages
- Handles multi-target quests (considers all target monsters)
- Filters out town departure points
- Toggle on/off via REFramework menu

## How It Works

The game's navigation mesh measures real walking distances between every camp and every area. These distances are shipped with the mod — no runtime performance cost, just a table lookup.

## Requirements

- [REFramework](https://www.nexusmods.com/monsterhunterwilds/mods/39)

## Installation

1. Install REFramework if you haven't already
2. Extract the mod archive into your Monster Hunter Wilds game directory
3. File structure:
   - `<game folder>/reframework/autorun/smart_camp_picker.lua`
   - `<game folder>/reframework/data/SmartCampPicker/navmesh_distances/stage_*.json`

## Usage

The mod is enabled by default. To toggle:

1. Open REFramework menu (`Insert` key)
2. Find **Smart Camp Picker** section
3. Check/uncheck **Enabled**

## Credits

Inspired by [Auto-Select Nearest Camp](https://www.nexusmods.com/monsterhunterwilds/mods/571) by Armarui.

## License

[MIT](LICENSE)

## Author

**JCubic** — [Nexus Mods](https://www.nexusmods.com/monsterhunterwilds/mods/4036)
