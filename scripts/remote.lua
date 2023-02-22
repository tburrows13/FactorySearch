local Gui = require "scripts.gui"

remote.add_interface("factory-search", {
  search = function(player, search_value)
    local gui = Gui.open(player, global.players[player.index])
    gui.refs.item_select.elem_value = search_value
    Gui.start_search(player, gui)
  end
})
