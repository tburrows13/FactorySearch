# Factory Search

Have you ever asked yourself any of these questions?

"Where are the repair packs being made?"

"How many green belt machines do I have?"

"Which planet did I build my iron smelters on?"

If so, then Factory Search might be the mod for you!

Similar to [BeastFinder](https://mods.factorio.com/mod/BeastFinder) and [Where is it Made?](https://mods.factorio.com/mod/WhereIsItMade). This mod was made to provide an easy-to-use and clean-looking interface that can perform cross-surface searches and immediate viewing of search results in the map view (and across planets with Space Exploration).

Check out Xterminator's mod spotlight [here](https://youtu.be/_60XPAT3uas).

-----
## Features

- Press `Control + Shift + F` to open search interface (can be changed in Settings > Controls)
- Select any item or fluid
- Pick any combination of the following search modes
    - Product: Search for machines that produce this item or fluid
    - Storage: Search for containers that contain this item or fluid
    - Request: Search for logistic containers that are requesting this item
    - Ground: Search for this item on the ground
    - Entity: Search for built entities of this item
    - Signal: Search for entities that are sending this signal (due to API limitations, some types of entity can't be searched for by signal)
- Factory Search will present a list of machines matching the selected search modes, grouped by name and proximity
- Displays results from all surfaces (e.g. all Space Exploration planets are searched)
- Click on a result group to open it in the map
- Opens results from other planets in the Navigation Satellite if using Space Exploration
- `Control + Shift + Click` on any game object (e.g. built entity, inventory item, recipe) to open the search interface with that item selected
- Supports multiplayer

-----
## Future Updates?

- Other search modes:
    - Ingredients?
    - Map tags?
- Show recipe info in tooltips
- Pin button like in [Recipe Book](https://mods.factorio.com/mod/RecipeBook) and [Task List](https://mods.factorio.com/mod/TaskList)
- Options for admins to set when playing pvp around forces and being able to search for corpses and ground items in hidden chunks
- 'Expanded' view, with inline cameras like the train overview GUI (not for many months…)

-----
## Translation

You can help by translating this mod into your language using [CrowdIn](https://crowdin.com/project/factorio-mods-localization). Any translations made will be included in the next release.

-----
Thank you to:

- [raiguard](https://mods.factorio.com/user/raiguard) for [flib](https://mods.factorio.com/mod/flib) (GUI library) and [Quick Item Search](https://mods.factorio.com/mod/QuickItemSearch) (provided initial framework)
- [justarandomgeek](https://mods.factorio.com/user/justarandomgeek) for his excellent [mod debugger](https://github.com/justarandomgeek/vscode-factoriomod-debug)