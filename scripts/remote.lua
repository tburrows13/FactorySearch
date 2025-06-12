remote.add_interface("factory-search", {
  ---@param player LuaPlayer
  ---@param state SearchGuiState
  set_search_state = function(player, state)
    SearchGui.open(player, storage.players[player.index])
    local player_data = storage.players[player.index]
    local refs = player_data.refs
    SearchGui.set_state(refs, state)
  end,

  ---@param player LuaPlayer
  ---@param search_value SignalID
  search = function(player, search_value)
    SearchGui.open(player, storage.players[player.index])
    local player_data = storage.players[player.index]
    player_data.refs.item_select.elem_value = search_value
    SearchGui.start_search_immediate(player, player_data)
  end
})
