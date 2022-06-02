util = require "__core__.lualib.util"
event = require "scripts.event"
search = require "scripts.search"
local gui = require "scripts.gui"


script.on_init(
  function()
    global.players = {}
  end
)

script.on_configuration_changed(
  function()
    -- Destroy all GUIs
    for player_index, player_data in pairs(global.players) do
      local player = game.get_player(player_index)
      if player then
        gui.destroy_gui(player, player_data)
      else
        global.players[player_index] = nil
      end
    end
  end
)