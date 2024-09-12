local Gui = require "scripts.gui"

remote.add_interface("factory-search", {
  search = function(player, search_value)
    Gui.open(player, storage.players[player.index])
    local player_data = storage.players[player.index]
    player_data.refs.item_select.elem_value = search_value
    Gui.start_search(player, player_data)
  end
})
